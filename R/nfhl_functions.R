#' @title National Flood Hazard Layer Endpoint
#' @description A character string specifying the base URL for the NFHL web service.
#' @export
nhfl_end_point <- "https://hazards.fema.gov/arcgis/rest/services/public/NFHLWMS/MapServer"

#' @title Query the National Flood Hazard Layers (NFHL)
#' @description Subset a specific NFHL layer within a defined bounding box (AOI).
#' @param AOI An `sf` object representing the spatial area of interest (must have a valid CRS).
#' @param layer Integer. The NFHL layer ID to query. Default is 28.
#' @return An `sf` object containing the NFHL subset or `NULL` if the query fails.
#' @details
#' This function queries the National Flood Hazard Layers (NFHL) web service
#' to retrieve a specific layer, clipped to a given area of interest (AOI).
#' The result is transformed to match the CRS of the AOI.
#'
#' @export
#' @importFrom sf st_transform st_bbox st_crs
#' @importFrom httr parse_url build_url
#' @importFrom geojsonsf geojson_sf
#' @examples
#' \dontrun{
#' library(sf)
#' # Define an AOI
#' AOI <- st_as_sf(data.frame(x = -105, y = 40), coords = c("x", "y"), crs = 4326) |> 
#'        st_buffer(0.01)
#'
#' # Query NFHL layer 28
#' nfhl_data <- nfhl_get(AOI, layer = 28)
#'
#' # Inspect result
#' print(nfhl_data)
#' }

nfhl_get <- function(AOI, layer = 28) {
  # Input validation
  if (!inherits(AOI, "sf"))
    stop("AOI must be an sf object.")
  
  if (!layer %in% nfhl_meta$layerID)
    stop("Layer ID not present, check nfhl_meta")
  
  # Transform AOI to NAD83 (EPSG:4269) for NFHL compatibility
  AOI_nad83 <- sf::st_transform(AOI, 4269)
  bbox <- sf::st_bbox(AOI_nad83)
  
  # Define query URL and parameters
  base_url <- nhfl_end_point # Ensure nhfl_end_point is defined globally
  url <- httr::parse_url(base_url)
  url$path <- paste(url$path, layer, "query", sep = "/")
  url$query <- list(
    geometry = paste(bbox["xmin"], bbox["ymin"], bbox["xmax"], bbox["ymax"], sep = ","),
    geometryType = "esriGeometryEnvelope",
    outFields = "*",
    returnGeometry = "true",
    f = "geoJSON"
  )
  
  # Perform the query
  result <- tryCatch({
    suppressWarnings({
      # Convert the URL and fetch the data as an sf object
      x = geojsonsf::geojson_sf(httr::build_url(url)) |>
        sf::st_transform(sf::st_crs(AOI))
      
      x$LAYER = layer
    })
  }, warning = function(w) {
    message("Warning during NFHL query: ", w$message)
    return(NULL)
  }, error = function(e) {
    message("Error during NFHL query: ", e$message)
    return(NULL)
  })
  
  # Return the result or NULL
  return(x)
}


#' @title Query Metadata of NFHL Layer by ID
#' @description Retrieves metadata for a specific layer in the National Flood Hazard Layers (NFHL).
#' @param layer Integer. The NFHL layer ID to query. Default is 28.
#' @return A list containing:
#' \itemize{
#'   \item \code{Layer}: The name of the queried layer.
#'   \item \code{Description}: A brief description of the layer.
#'   \item \code{bbox}: A bounding box of the layer's extent as an \code{sf} object.
#' }
#' @export
#' @importFrom httr GET content
#' @importFrom sf st_as_sfc st_bbox st_crs
#' @importFrom stringr str_remove str_extract
#' @examples
#' \dontrun{
#' metadata <- nfhl_describe(layer = 28)
#' print(metadata$Layer)
#' print(metadata$Description)
#' plot(metadata$bbox)
#' }
nfhl_describe <- function(layer = 28) {
  # Input validation
  if (!is.numeric(layer) ||
      layer <= 0)
    stop("Layer ID must be a positive integer.")
  
  if (!layer %in% nfhl_meta$layerID)
    stop("Layer ID not present, check nfhl_meta")
  
  # Build the URLs
  url <- paste0(nhfl_end_point, "/", layer)
  json_url <- paste0(url, "?f=pjson&returnUpdates=true&")
  
  # Extract Layer Name and Description
  tryCatch({
    # Fetch HTML lines
    html_lines <- readLines(url, warn = FALSE)
    
    # Extract description
    description <- html_lines[grep("Description", html_lines)][1]
    description <- stringr::str_remove(description, '<b>Description: </b> ')
    description <- stringr::str_remove_all(description, '<br/>|\"')
    
    # Extract layer name
    title <- html_lines[grep("Layer", html_lines)][1]
    layer_name <- stringr::str_remove_all(title, "<title>|</title>|Layer: ")
    
    # Fetch JSON metadata using httr
    response <- httr::GET(json_url)
    if (httr::status_code(response) != 200)
      stop("Failed to fetch metadata for the specified layer.")
    
    json_text <- httr::content(response, as = "text")
    
    # Extract bounding box values using regular expressions
    xmin <- as.numeric(
      stringr::str_extract(json_text, '"xmin":\\s*-?\\d+\\.?\\d*')  |>
        stringr::str_remove('"xmin":\\s*')
    )
    
    xmax <- as.numeric(
      stringr::str_extract(json_text, '"xmax":\\s*-?\\d+\\.?\\d*') |>
        stringr::str_remove('"xmax":\\s*')
    )
    
    ymin <- as.numeric(
      stringr::str_extract(json_text, '"ymin":\\s*-?\\d+\\.?\\d*')  |>
        stringr::str_remove('"ymin":\\s*')
    )
    
    ymax <- as.numeric(
      stringr::str_extract(json_text, '"ymax":\\s*-?\\d+\\.?\\d*') |>
        stringr::str_remove('"ymax":\\s*')
    )
    
    wkid <- as.integer(
      stringr::str_extract(json_text, '"wkid":\\s*\\d+')  |>
        stringr::str_remove('"wkid":\\s*')
    )
    
    # Validate bounding box
    if (any(is.na(c(xmin, xmax, ymin, ymax, wkid))))
      stop("Failed to extract bounding box data from the JSON response.")
    
    # Convert bounding box to sf object
    bbox <- sf::st_as_sfc(sf::st_bbox(c(
      xmin = xmin,
      xmax = xmax,
      ymin = ymin,
      ymax = ymax
    ),
    crs = sf::st_crs(wkid)))
    
    # Return the metadata as a list
    return(list(
      Layer = layer_name,
      Description = description,
      bbox = bbox
    ))
  }, error = function(e) {
    message("Error querying NFHL layer: ", e$message)
    return(NULL)
  })
}
