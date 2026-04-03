# Bronlagen recreatie

Deze map bevat de eerste bronlagen voor recreatie.

## Aangemaakt

- [`bgt_padvlakken.gpkg`](/Users/ton/Documents/GitHub/Meijendel/Recreatie/BGT/bgt_padvlakken.gpkg)
- [`osm_parkeerplaatsen.geojson`](/Users/ton/Documents/GitHub/Meijendel/Recreatie/OSM/osm_parkeerplaatsen.geojson)
- [`hoofdtoegangen_meijendel.csv`](/Users/ton/Documents/GitHub/Meijendel/Recreatie/hoofdtoegangen_meijendel.csv)

## Inhoud

### BGT padlaag

`bgt_padvlakken.gpkg` bevat BGT-wegdelen met functie:

- `voetpad`
- `fietspad`
- `voetpad op trap`

Belangrijk:

- dit is nu een vlaklaag
- dit bestand is geschikt voor selectie en visuele controle van paden
- voor `padlengte_m_per_ha` is later nog een verdedigbare lijnafleiding nodig

### OSM parkeerlaag

`osm_parkeerplaatsen.geojson` bevat OSM-objecten met `amenity=parking` binnen de Meijendel-bounding box.

Belangrijk:

- punten zijn node-locaties of centrum-punten van way/relation-objecten
- dit bestand is geschikt als eerste bron voor `afstand_parkeerplaats_m`

## Nog open

- padlijn-afleiding uit BGT voor lengteberekening
- visuele controle van de BGT-padselectie in QGIS
- visuele controle van de OSM-parkeerselectie in QGIS
