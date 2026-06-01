# Spatial Analyse in R op een iMac M1
Praktische inrichting voor geolocatie- en GIS-werkstromen

## Doel

Een stabiele, reproduceerbare omgeving opzetten voor:

- ruimtelijke analyses;
- vogelmonitoring;
- rasteranalyse;
- koppeling met MySQL/PostGIS;
- statistische analyse in R;
- publicatie via Shiny/Leaflet.

---

# 1. Controleer architectuur en macOS

Controleer eerst of alles native op Apple Silicon draait.

## Controle architectuur

In Terminal:

```bash
uname -m
```

Uitkomst moet zijn:

```text
arm64
```

## Controle R-architectuur

In R:

```r
R.version$arch
```

Uitkomst moet zijn:

```text
aarch64
```

Indien nog Intel/Rosetta-R actief is:
- verwijder oude Intel-versies;
- installeer native ARM-versies.

---

# 2. Installeer Homebrew

Website:

https://brew.sh

Installatie:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Controle:

```bash
brew doctor
```

Uitkomst:

```text
Your system is ready to brew.
```

---

# 3. Installeer spatial libraries

Dit is de cruciale stap voor `sf` en `terra`.

Installatie:

```bash
brew install \
gdal \
geos \
proj \
sqlite \
udunits \
netcdf \
cmake
```

Controle GDAL:

```bash
gdalinfo --version
```

Bijvoorbeeld:

```text
GDAL 3.x.x
```

Controle PROJ:

```bash
proj
```

---

# 4. Installeer actuele R

Gebruik de Apple Silicon-versie.

Download:

https://cran.r-project.org/bin/macosx/

Gebruik:
- laatste release;
- Apple Silicon build.

---

# 5. Installeer RStudio

Download:

https://posit.co/download/rstudio-desktop/

Gebruik:
- Apple Silicon-versie.

---

# 6. Installeer ruimtelijke R-packages

In RStudio:

```r
install.packages(c(
  "sf",
  "terra",
  "stars",
  "exactextractr",
  "tmap",
  "leaflet",
  "mapview",
  "osmdata",
  "tidyverse",
  "DBI",
  "RPostgres",
  "duckdb"
))
```

---

# 7. Test `sf`

```r
library(sf)

nc <- st_read(system.file("shape/nc.shp", package="sf"))

plot(st_geometry(nc))
```

Als dit werkt:
- GDAL;
- GEOS;
- PROJ;
- `sf`;
- Apple Silicon;

zijn correct gekoppeld.

---

# 8. Test rasterverwerking (`terra`)

```r
library(terra)

r <- rast(nrows=100, ncols=100)

plot(r)
```

---

# 9. Aanbevolen projectstructuur

Gebruik geen losse bestanden in Downloads.

Voorbeeld:

```text
GIS/
├── data_raw/
├── data_processed/
├── rasters/
├── vectors/
├── scripts/
├── outputs/
├── maps/
├── shiny/
└── database/
```

---

# 10. Gebruik GeoPackage in plaats van shapefiles

Voorkeur:

```text
.gpkg
```

Niet:

```text
.shp
```

## Waarom GeoPackage beter is

Voordelen:
- één bestand;
- stabieler;
- sneller;
- betere Unicode-ondersteuning;
- geen beperkingen op kolomnamen;
- moderner formaat.

---

# 11. Spatial analyse in R: concept

## Twee typen ruimtelijke data

| Type | Voorbeeld | Pakket |
|---|---|---|
| Vector | punten, lijnen, polygonen | sf |
| Raster | hoogte, stikstof, NDVI | terra |

---

# 12. Basis spatial workflow

## Inlezen van vectorlagen

```r
library(sf)

plots <- st_read("data/plots.gpkg")
territoria <- st_read("data/territoria.gpkg")
```

## Inlezen van rasterlagen

```r
library(terra)

hoogte <- rast("rasters/ahn.tif")
```

---

# 13. Coördinatenstelsel gelijk maken

Voor Nederland meestal:

```text
EPSG:28992
RD New
```

Omzetten:

```r
plots <- st_transform(plots, 28992)
territoria <- st_transform(territoria, 28992)
```

Dit is essentieel voor:
- afstanden;
- oppervlaktes;
- intersecties;
- buffers.

---

# 14. Spatial join

Voorbeeld:
welke territoria liggen in welk plot?

```r
territoria_per_plot <- st_join(
  territoria,
  plots,
  join = st_intersects
)
```

Daarna:

```r
library(dplyr)

aantallen <- territoria_per_plot |>
  count(plot_id, soort, jaar)
```

---

# 15. Oppervlaktes berekenen

```r
plots <- plots |>
  mutate(
    oppervlakte_ha =
      as.numeric(st_area(geometry)) / 10000
  )
```

---

# 16. Rasterwaarden per plot berekenen

Bijvoorbeeld:
- AHN;
- stikstof;
- NDVI;
- landgebruik.

```r
plots_vect <- vect(plots)

gem_hoogte <- terra::extract(
  hoogte,
  plots_vect,
  fun = mean,
  na.rm = TRUE
)

plots$gem_hoogte <- gem_hoogte[,2]
```

---

# 17. Kaarten maken

## Statische kaarten (`tmap`)

```r
library(tmap)

tm_shape(plots) +
  tm_polygons("gem_hoogte")
```

## Interactieve kaarten (`leaflet`)

```r
library(leaflet)

leaflet(plots) |>
  addTiles() |>
  addPolygons(label = ~plot_id)
```

---

# 18. Waarom dit geschikt is voor Meijendel

Met deze workflow kunt u reproduceerbaar:

- territoria per plot berekenen;
- dichtheden per hectare berekenen;
- afstand tot paden bepalen;
- habitatoppervlaktes bepalen;
- AHN koppelen;
- stikstofdepositie koppelen;
- beheermaatregelen spatial analyseren;
- NDFF/SOVON-data koppelen;
- G.E.E.-modellen direct voeden.

---

# 19. Aanbevolen architectuur

Niet ideaal:

```text
QGIS → handmatig exporteren → Excel → R
```

Wel ideaal:

```text
PostGIS/MySQL
      ↓
R spatial analyse
      ↓
G.E.E./statistiek
      ↓
Shiny/PWA/Leaflet
```

---

# 20. Overweeg PostGIS

Installatie:

```bash
brew install postgresql@16 postgis
```

Voordelen:
- centrale opslag;
- schaalbaarheid;
- snelle spatial queries;
- meerdere gebruikers;
- directe koppeling met R/Shiny.

---

# 21. Vermijden

## Niet doen

- Intel/Rosetta-R;
- oude shapefiles;
- handmatige CSV-workflows;
- analyses buiten scripts;
- QGIS als primaire analyseomgeving.

## Wel doen

- script-based workflows;
- GeoPackage/PostGIS;
- reproduceerbare analyses;
- versiebeheer;
- centrale opslag.

---

# 22. Strategische conclusie

Voor complexe ecologische analyse is R vaak robuuster dan QGIS.

QGIS blijft nuttig voor:
- visuele inspectie;
- handmatige correcties;
- snelle kaartcontrole.

De kern van de analyse hoort beter thuis in:

- R;
- sf;
- terra;
- PostGIS;
- Shiny.
