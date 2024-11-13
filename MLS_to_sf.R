### This is a first attempt to convert my mls_dade file to a shape file using the sf package
# Nick Vilay, 11/11/2024

library(readr)
library(arrow)
library(tidyverse)
library(sf)
library(ggplot2)
library(tigris)
library(lubridate)
setwd("/home/nv238/senior essay")

mls_dade <- read_csv("./datasets/mls_dade.csv")

# Remove rows with missing values in longitude or latitude, so that we can use st_as_sf successfully
mls_dade <- mls_dade %>%
  filter(!is.na(`PARCEL LEVEL LONGITUDE`) & !is.na(`PARCEL LEVEL LATITUDE`))

# Make mls an sf object: mls_sf
mls_sf <- mls_dade %>%
  st_as_sf(coords = c("PARCEL LEVEL LONGITUDE", "PARCEL LEVEL LATITUDE"), 
           crs = 4326) # 4326 for WGS84

# Remove unnecessary column(s) that don't give useful info
mls_sf <- mls_sf %>% select(-`MAP COORDINATE`)

# Save the new MLS with shape data. I save it as a geopackage (.gpkg)
st_write(mls_sf, "./datasets/mls_dade.gpkg")


### To plot:
# Now use tigris to create base map of Miami-Dade County
miamibase <- counties(state = "12", cb = TRUE) %>%
  filter(COUNTYFP == "086") %>%
  st_transform(crs = st_crs(mls_sf))


# Map our new mls_sf onto the base map
ggplot() +
  geom_sf(data = miamibase, fill = NA, color = "black") +
  geom_sf(data = mls_sf, color = "blue", size = 0.5) +
  labs(title = "Parcel Locations in Miami-Dade County",
       x = "Longitude", y = "Latitude") +
  theme_minimal()



