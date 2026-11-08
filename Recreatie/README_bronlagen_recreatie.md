# Bronlagen recreatie

Deze map bevat de eerste bronlagen voor recreatie.

## Aangemaakt

- [`bgt_padvlakken.gpkg`](/Users/ton/Documents/GitHub/Meijendel/Recreatie/BGT/bgt_padvlakken.gpkg)
- [`osm_highways_meijendel_20261108.json`](/Users/ton/Documents/GitHub/Meijendel/Recreatie/OSM/osm_highways_meijendel_20261108.json)
- [`osm_highways_meijendel_20261108.overpassql`](/Users/ton/Documents/GitHub/Meijendel/Recreatie/OSM/osm_highways_meijendel_20261108.overpassql)
- [`osm_parkeerplaatsen_meijendel_20261108.json`](/Users/ton/Documents/GitHub/Meijendel/Recreatie/OSM/osm_parkeerplaatsen_meijendel_20261108.json)
- [`osm_parkeerplaatsen_meijendel_20261108.overpassql`](/Users/ton/Documents/GitHub/Meijendel/Recreatie/OSM/osm_parkeerplaatsen_meijendel_20261108.overpassql)
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

De gedateerde JSON-snapshot bevat 341 OSM-objecten met `amenity=parking` en
bronmoment 8 november 2026 10:31:51 UTC. De import bewaart uitsluitend de 16
objecten die minstens één van de 55 kavels raken. De 253 eerder opgenomen
objecten zonder kavelrelatie zijn op 8 november 2026 verwijderd.

Belangrijk:

- nodes blijven punten; gesloten ways en multipolygonrelaties blijven vlakken
- de import berekent `afstand_parkeerplaats_m` voor alle 55 kavels opnieuw

### OSM-lijninfrastructuur

De JSON-snapshot bevat 4.475 OSM-way-objecten met bronmoment 8 november 2026
10:22:35 UTC. Daarvan zijn 2.232 bronlijnen binnen het ruimere technische
basisgebied als fietspad, voetpad of weg geclassificeerd. De levende database
neemt uitsluitend de 1.319 lijnen met een positieve kaveldoorsnijding op; de
toegang wordt afgeleid als openbaar, beperkt toegankelijk of afgesloten.

De actuele lijnstand omvat 59 fietspaden, 872 voetpaden en 388 wegen, samen
235.264,661 meter. Alle huidige versies beginnen voorlopig op 1 januari 1955 op
basis van Tons inschatting; het werkelijke OSM-bronmoment blijft afzonderlijk
bewaard. De vergelijking met BGT is controle, geen geometrische vervanging.

## Nog open

- beoordeling van de vier OSM-segmenten zonder BGT-fietspadvlak binnen tien meter
- visuele controle van de BGT-padselectie in QGIS
- inhoudelijke beoordeling van parkeerobjecten met private of beperkte toegang
