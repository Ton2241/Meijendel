# Werkwijze recreatiedata uit BGT en OSM

Doel: de ruimtelijke bronnen eerst buiten MySQL samenvatten en daarna alleen de uitkomsten per `plot_id` en `jaar` importeren in `plot_jaar_infra`.

## Uitgangspunt

Je database is al voorbereid op deze 4 variabelen:

- `afstand_pad_m`
- `padlengte_m_per_ha`
- `afstand_parkeerplaats_m`
- `afstand_hoofdtoegang_m`

De output moet terechtkomen in:

- [`plot_jaar_infra_recreatie_import.csv`](/Users/ton/Documents/GitHub/Meijendel/Recreatie/plot_jaar_infra_recreatie_import.csv)

## Bronkeuze

Gebruik:

- BGT voor paden en wegen
- OSM voor parkeerplaatsen
- handmatig vastgelegde hoofdtoegangen voor hoofdtoegangen

Gebruik niet direct:

- Dunea-rapport 2022 voor `plot_jaar_infra`

Reden:

- dat rapport geeft gebieds- en bezoekersinformatie, niet automatisch een betrouwbare plotafstand

## Voorwaarden vooraf

Controleer eerst:

1. De plotlaag staat in `EPSG:28992`.
2. De BGT/OSM-lagen staan ook in `EPSG:28992` of worden daarnaar omgerekend.
3. Het gekozen `jaar` bestaat al in `plot_jaar_oppervlak`.

In deze repository is al gecontroleerd:

- de plotlaag [`avimap_252_diversen__gebieden.shp`](/Users/ton/Documents/GitHub/Meijendel/Plots_2025/avimap_252_diversen__gebieden.shp) gebruikt `EPSG:28992`
- het plot-id-veld heet `plotid`

## Hoofdtoegangen eerst vastleggen

Vul eerst handmatig:

- [`hoofdtoegangen_meijendel.csv`](/Users/ton/Documents/GitHub/Meijendel/Recreatie/hoofdtoegangen_meijendel.csv)

Kolommen:

- `naam`
- `x_rd`
- `y_rd`
- `opmerking`

Gebruik RD-coordinaten in meters.

## Benodigde bronbestanden

Je hebt straks nodig:

- een lijnenlaag met paden/wegen uit BGT
- een punten- of polygonenlaag met parkeerplaatsen uit OSM
- een puntenlaag met hoofdtoegangen

## Script

Gebruik:

- [`recreatie_bgt_osm.py`](/Users/ton/Documents/GitHub/Meijendel/Ruimtelijke%20data/recreatie_bgt_osm.py)

Dit script berekent:

- minimale afstand van elk plot tot de dichtstbijzijnde padgeometrie
- totale padlengte binnen elk plot, omgerekend naar meter per hectare
- minimale afstand van elk plot tot de dichtstbijzijnde parkeerplaats
- minimale afstand van elk plot tot de dichtstbijzijnde hoofdtoegang

## Voorbeeldcommando

Pas paden, parkeerplaatsen en hoofdtoegangen eerst aan naar jouw echte bestandsnamen.

```bash
python3 "Ruimtelijke data/recreatie_bgt_osm.py" \
  --plots "Plots_2025/avimap_252_diversen__gebieden.shp" \
  --plot-id-field plotid \
  --jaar 2024 \
  --paden "/pad/naar/bgt_paden.gpkg" \
  --paden-layer bgt_paden \
  --paden-bron BGT \
  --parkeerplaatsen "/pad/naar/osm_parkeerplaatsen.gpkg" \
  --parkeer-layer parkeerplaatsen \
  --parkeer-bron OSM \
  --hoofdtoegangen "/pad/naar/hoofdtoegangen.gpkg" \
  --hoofdtoegang-layer hoofdtoegangen \
  --hoofdtoegang-bron HANDMATIG \
  --output "Recreatie/plot_jaar_infra_recreatie_import.csv"
```

## Verwachte output

Het outputbestand krijgt deze kolommen:

- `plot_id`
- `jaar`
- `bron`
- `variabele`
- `waarde`

## Controle na draaien

Controleer daarna:

1. Heeft elk plot records voor de verwachte variabelen?
2. Zijn alle afstanden groter dan of gelijk aan 0?
3. Is `padlengte_m_per_ha` logisch en niet extreem hoog?
4. Bestaan alle combinaties van `plot_id` en `jaar` al in `plot_jaar_oppervlak`?

## Daarna pas

Importeer de output met:

- [`10_import_recreatie_infra.sql`](/Users/ton/Documents/GitHub/Meijendel/Ruimtelijke%20data/10_import_recreatie_infra.sql)
