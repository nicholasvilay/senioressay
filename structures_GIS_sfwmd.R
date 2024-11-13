# By Nick Vilay 10/28/2024
# This code will load in the arcGIS data from SFWMD (South Florida Water Management District) Website
# It will filter the spatial data to only include structures within Miami-Dade County
# Then, it will merge the spatial data with the general data for each set by "name" of structure

library(readr)
library(tidyverse)
library(httr)
library(sf)
library(ggplot2)
library(tigris)

wms <- read_csv("./senior essay/datasets/All WMS Structures.csv")
prim <- read_csv("./senior essay/datasets/Primary Structures.csv")
other <- read_csv("./senior essay/datasets/Water Control District _ Other Structures.csv")

### get spatial data from 
urls <- list(
  wms_url = "https://geoweb.sfwmd.gov/agsext1/rest/services/WaterManagementSystem/All_Structures/MapServer/4/query",
  prim_url = "https://geoweb.sfwmd.gov/agsext1/rest/services/WaterManagementSystem/All_Structures/MapServer/1/query",
  other_url = "https://geoweb.sfwmd.gov/agsext1/rest/services/WaterManagementSystem/All_Structures/MapServer/8/query"
)

# Initialize a empty list to store spatial datasets
spatial_datasets <- list()

# Loop through each sfwmd URL, fetch data, and store the spatial arcgis dataset
for (name in names(urls)) {
  response <- GET(urls[[name]], query = list(where = "1=1", f = "geojson"))
  
  if (status_code(response) == 200) {
    geojson_data <- content(response, as = "text", encoding = "UTF-8")
    spatial_datasets[[name]] <- st_read(geojson_data)
    print(paste("Loaded data from:", name))
  } else {
    print(paste("Failed to load data from:", name, "- Status code:", status_code(response)))
  }
}


### use Tigris to create base map of Miami Dade county
miamibase <- counties(state = "12", cb = TRUE) %>%
  filter(COUNTYFP == "086")
# Ensure the CRS of basemap is consistent w/ the CRS of the spatial datasets 
crs_target <- st_crs(spatial_datasets$wms_url) # assuming all datasets share the same CRS
miamibase <- st_transform(miamibase, crs = crs_target)

# Loop through each spatial dataset and filter to keep only points within Miami-Dade County
filtered_datasets <- list()
for (name in names(spatial_datasets)) {
  spatial_data <- spatial_datasets[[name]]
  
  # spatial intersection will keep only points within Miami-Dade border
  filtered_data <- st_intersection(spatial_data, miamibase)
  
  # Store the filtered dataset in a new list
  filtered_datasets[[name]] <- filtered_data
}


# at this point, each dataset in filtered_datasets list has geometric data of SFWMD structures
# and only includes Miami-Dade structures. 


### Merge spatial with general data for each dataset
# Ensure both datasets have a common column name for joining
for (i in names(filtered_datasets)) {
  filtered_datasets[[i]] <- filtered_datasets[[i]] %>%
    rename(name = NAME)
}


# Perform a left join to add the geometry from spatial dataset filtered_datasets$prim_url to general dataset prim
prim_with_geometry <- prim %>%
  left_join(filtered_datasets$prim_url %>% select(name, geometry), by = "name")
# and repeat for the others
wms_with_geometry <- wms %>%
  left_join(filtered_datasets$wms_url %>% select(name, geometry), by = "name") %>%
  distinct(geometry, .keep_all = TRUE)
## this next one doesnt work just yet; to make it work, I must use different match key than 'name' since 'other' doesn't have a name column
# other_with_geometry <- other %>%
#   left_join(filtered_datasets$other_url %>% select(name, geometry), by = "name")
# for now, I will not use "other structures" as the sfwmd dataset lacks startup dates, which is important for my spatial-temporal analysis
# if/when I can find startup dates for these structures, I will try again


# Now we have data about the structures AND where they are on the map
# If I want, I can now remove structures that have startup dates that are too early or late (many are more than 45 years ago)



### save the resulting datasets with geometry data
# Specify path
output_dir <- "./senior essay/datasets/"

# Save them as a Shapefile (to retain geometric data)
st_write(prim_with_geometry, paste0(output_dir, "prim_with_geometry.shp"), delete_dsn = TRUE) # so it can overwrite if it must
st_write(wms_with_geometry, paste0(output_dir, "wms_with_geometry.shp"), delete_dsn = TRUE)

# make sure that the files were saved correctly ;) 
list.files(output_dir)
prim_with_geometry <- st_read("./senior essay/datasets/prim_with_geometry.shp")
wms_with_geometry <- st_read("./senior essay/datasets/wms_with_geometry.shp")


