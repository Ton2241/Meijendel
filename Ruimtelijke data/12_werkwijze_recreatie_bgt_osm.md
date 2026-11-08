# Werkwijze recreatiedata uit BGT en OSM

De actieve route gebruikt gedateerde OSM-snapshots voor voetpaden, fietspaden,
wegen en parkeerplaatsen. BGT blijft alleen een onafhankelijke geometrische
controlebron. De oude CSV- en SQL-import uit 2024 is verwijderd.

## Uitgangspunt

De database bewaart de lijn- en voorzieningsobjecten zelf en leidt drie
kavelvariabelen af:

- `afstand_pad_m`
- `padlengte_m_per_ha`
- `afstand_parkeerplaats_m`

## Bronkeuze

Gebruik de twee gedateerde OSM-snapshots en hun Overpass-querybestanden in
`Recreatie/OSM`. Bewaar query, bronmoment, bestandshash en ODbL-vermelding. BGT
wordt alleen gebruikt om de OSM-geometrie te vergelijken, niet om haar
automatisch te vervangen.

Gebruik niet direct:

- Dunea-rapport 2022 voor `plot_jaar_infra`

Reden:

- dat rapport geeft gebieds- en bezoekersinformatie, niet automatisch een betrouwbare plotafstand

## Voorwaarden vooraf

Controleer eerst:

1. het actuele basisgebied en de 55 actieve plotgeometrieën staan in EPSG:28992;
2. het OSM-snapshotjaar bestaat voor alle 55 plots in `plot_jaar_oppervlak`;
3. de T7 is gemount voor de verplichte herstelkopie.

## Benodigde bronbestanden

Gebruik:

- `osm_highways_meijendel_YYYYMMDD.json` en de gelijknamige query;
- `osm_parkeerplaatsen_meijendel_YYYYMMDD.json` en de gelijknamige query.

## Script

Gebruik `gis/scripts/import_osm_fietspaden.py`.

Dit script importeert de bronobjecten en berekent voor elk van 55 kavels:

- minimale afstand tot een voet- of fietspad;
- totale voet- en fietspadlengte per hectare;
- minimale afstand tot een OSM-parkeerplaats.

## Voorbeeldcommando

```bash
python3 gis/scripts/import_osm_fietspaden.py --apply
```

De eerste lijn- en voorzieningsversies beginnen voorlopig op 1 januari 1955 met
grondslag `inschatting` en zonder einddatum. Het werkelijke OSM-bronmoment blijft
afzonderlijk bewaard. Een latere snapshot sluit de voorafgaande stand op het
nieuwe bronmoment.

## Controle na draaien

Controleer daarna:

1. Heeft elk van 55 plots precies drie afgeleide variabelen?
2. Zijn alle afstanden groter dan of gelijk aan 0?
3. Is `padlengte_m_per_ha` logisch en niet extreem hoog?
4. Zijn de lijn- en voorzieningsversies geldig en herleidbaar tot snapshot en hash?
5. Zijn plotdoorsnijdingen opnieuw opgebouwd?

## Daarna pas

Dezelfde import vervangt bij herhaling alleen de drie aggregaten van dezelfde
snapshot. De eerste aggregaatstand begint, gelijk aan de objectversies, op
1 januari 1955. Een latere snapshot voegt een nieuwe stand toe in haar werkelijke
ingangsjaar. Shiny en de statische browser gebruiken uitsluitend de laatste
stand op of vóór het analysejaar. Wegen blijven afzonderlijke lijnversies, maar
tellen niet als pad. `afstand_hoofdtoegang_m` wordt niet meer gevuld.
