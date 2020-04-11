#' @title Query the National Flood Hazard Layers
#' @description  Subset any NFHL layer to a bounding box
#' @param AOI the spatial area to subset to
#' @param layer the NFHL ID
#' @return a sf object
#' @export
#' @importFrom sf st_transform st_bbox read_sf st_crs
#' @importFrom dplyr mutate %>% 

nfhl_get = function(AOI, layer = 28){
  
  bb = sf::st_transform(AOI, 4269) %>% 
    sf::st_bbox()
  
  bb.ordered =  paste(bb[1],bb[2],bb[3],bb[4], sep = "%2C")
  
  url = paste0('https://hazards.fema.gov/gis/nfhl/rest/services/public/',
               'NFHL/MapServer/',
               layer,
               '/query?',
               '&geometry=',
               bb.ordered,
               '&geometryType=esriGeometryEnvelope',
               '&outFields=*',
               '&returnGeometry=true',
               '&returnZ=false',
               '&returnM=false',
               '&returnExtentOnly=false',
               '&f=geoJSON')
  
  tryCatch({ 
    sf::read_sf(url) %>% 
      sf::st_transform(sf::st_crs(AOI)) %>% 
      dplyr::mutate(LAYER = layer)
    },
      warning = function(w) { NULL },
      error = function(e) { NULL }
    )
}

#' @title Query meta data of NFHL by layer ID
#' @param layer the layer ID to query 
#' @return a list containg the layer Name, Description, and bounding box
#' @export
#' @importFrom jsonlite read_json
#' @importFrom stats setNames
#' @importFrom sf st_as_sfc st_bbox st_crs

nfhl_describe = function(layer = 28){
  . <- NULL
  ll = readLines(paste0('https://hazards.fema.gov/gis/nfhl/rest/services/public/NFHL/MapServer/', layer))
  
  des  = grep("Description", ll, value = T)[1]
  des  = gsub('<b>Description: </b> ', "", des)
  des  = gsub('"', "", des)
  des  = gsub('<br/>', "", des)
  
  name = grep("Layer", ll, value = T)[1]
  name = gsub('<title>', "", name)
  name = gsub('</title>', "", name)
  name = gsub('Layer: ', "", name)
  
 url2 =  paste0('https://hazards.fema.gov/gis/nfhl/rest/services/public/NFHL/MapServer/', layer,
         '?f=pjson&returnUpdates=true&')
 
  ext = url2 %>% 
    jsonlite::read_json(, simplifyVector = T) %>% 
    unlist() %>% 
    t() %>% 
    as.data.frame() %>%  
    setNames(c("layerID", 
               ext_extract(names(.))[2:ncol(.)]))

  bbox = sf::st_bbox(c(xmin = ext$xmin, 
                   xmax = ext$xmax, 
                   ymax = ext$ymax, 
                   ymin = ext$ymin), 
                 crs = sf::st_crs(ext$wkid)) %>% 
    st_as_sfc() 
  
  return(list(Layer = name, 
              Description = des, 
              #Spatial = ext,
              bbox = bbox))
}

#' @title Extact last string after '.'
#' @title Extact last string after '.'
#' @noRd
#' @param x 

ext_extract = function (x) {
  pos <- regexpr("\\.([[:alnum:]]+)$", x)
  ifelse(pos > -1L, substring(x, pos + 1L), "")
}
