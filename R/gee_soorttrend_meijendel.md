# GEE-soorttrend voor Meijendel

Dit script voert een `GEE`-analyse uit voor één broedvogelsoort op basis van de echte structuur van `Meijendel.sql`.

- telinspanning wordt afgeleid uit de combinatie van `plot_jaar_teller` en aanwezige records in `territoria`
- soortnamen komen uit `soorten.id`, `soorten.soort_naam` en `soorten.engelse_naam`
- plots gebruiken `plots.plot_id`, `plots.plot_naam` en `plots.kavel_nummer`
- oppervlak komt uit `plot_jaar_oppervlak.oppervlakte_km2`
- tellingen komen uit `territoria.territoria`

## Wat het script doet

1. Leest de tabellen `plots`, `soorten`, `plot_jaar_oppervlak`, `plot_jaar_teller` en `territoria` uit de SQL-dump.
2. Selecteert geldige `plot x jaar`-combinaties op basis van `plot_jaar_oppervlak`.
3. Markeert een plotjaar als geteld als het voorkomt in `plot_jaar_teller` of in `territoria`.
4. Bouwt voor één soort een volledige matrix van geselecteerde plot-jaren.
5. Zet ontbrekende tellingen in getelde plot-jaren om naar `0`.
6. Laat niet-getelde plot-jaren buiten het model door daar `NA` te gebruiken.
7. Fit een Poisson-`GEE` met `plot_id` als cluster en `log(oppervlakte_km2)` als offset.
8. Schrijft een jaarsamenvatting, coëfficiënten, indexreeks en modeldataset weg naar CSV.

## Analyse-sets

Het script ondersteunt drie selecties via `analysis_set`:

- `uitgebreid`
  Alle kavels met oppervlaktegegevens in de gekozen jaren.
- `lange_reeks`
  Alleen de historische kavels uit de bestaande TRIM-logica:
  `1, 1a, 1b, 2, 3, 4, 4-5, 5, 6, 7, 8, 8/9, 8/11, 9, 10, 10-12-76, 11, 12, 12a, 13, 13s, 14, 15, 16, 16s, 17, 17a`
- `sandra`
  Alleen de Sandra-selectie:
  `1a, 1b, 3, 4-5, 6, 7, 8, 10-12-76, 12a, 13, 13s, 14, 15, 16, 17a, 17b, 45, 54a, 62, 71, 72, 73, 74, 75, 83`

## Argumenten

Volgorde van command line argumenten:

1. `sql_path`
2. `species_name`
3. `output_dir`
4. `year_min`
5. `year_max`
6. `analysis_set`
7. `gee_corstr`

Standaardwaarden:

- `sql_path`: `/Users/ton/Documents/GitHub/Meijendel/Meijendel.sql`
- `species_name`: `Nachtegaal`
- `output_dir`: `/Users/ton/Documents/GitHub/Meijendel/output_gee`
- `year_min`: `1984`
- `year_max`: `2025`
- `analysis_set`: `uitgebreid`
- `gee_corstr`: `exchangeable`

## Benodigde packages

Het script installeert packages niet automatisch. Installeer ontbrekende packages vooraf:

```r
install.packages(c("geepack", "broom"))
```

## Uitvoer

Bij uitvoering maakt het script deze bestanden aan in `output_dir`:

- `gee_index_<soort>.csv`
  Jaarlijkse indexreeks met 95%-banden, geschaald op basisjaar `100`.
- `gee_coef_<soort>.csv`
  Tidy coëfficiëntentabel van het `GEE`-model.
- `gee_samenvatting_<soort>.csv`
  Compacte modelsamenvatting met jaarlijkse trend en betrouwbaarheidsinterval.
- `gee_dataset_<soort>.csv`
  De feitelijke modeldataset na selectie en omzetting van `0` en `NA`.

## Voorbeeld

```sh
Rscript /Users/ton/Documents/GitHub/Meijendel/R/gee_soorttrend_meijendel.R \
  /Users/ton/Documents/GitHub/Meijendel/Meijendel.sql \
  Nachtegaal \
  /Users/ton/Documents/GitHub/Meijendel/output_gee \
  1984 \
  2025 \
  uitgebreid \
  exchangeable
```

## Belangrijke aannames

- `plot_jaar_oppervlak` bepaalt welke plot-jaren inhoudelijk bestaan.
- Een record in `territoria` impliceert in deze context ook telactiviteit voor dat plotjaar.
- Het model gebruikt oppervlakte als offset in `km2`, conform de bestaande tabellen.
- Het script is bewust zelfstandig gehouden en hergebruikt daarom de parserlogica uit de bestaande R-scripts in plaats van een aparte package-helper.

## Nog niet gedaan

Het script is toegevoegd, maar niet gedraaid of gevalideerd op echte uitvoer. Mogelijke vervolgstappen zijn:

- één of twee soorten proefmatig draaien
- controleren of `predict.geeglm(..., se.fit = TRUE)` in jouw lokale R-setup werkt zoals verwacht
- beoordelen of voor zeldzame soorten een negatief-binomiaal of eenvoudiger model robuuster is
