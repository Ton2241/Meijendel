# Mergin Maps-project Meijendel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Een afzonderlijk, getest en offline bruikbaar Mergin Maps-project `meijendel` bouwen uit de bestaande Meijendel-veldwerklagen.

**Architecture:** Een nieuwe QGIS Processing-builder hergebruikt de bestaande QField-builder voor luchtfoto, kavels, formulieren en drie meetlagen en voegt daarna de officieel gedocumenteerde Mergin Maps-projectinstellingen, schetslaag en trackinglaag toe. De uitvoer staat los van het QField-pakket en wordt alleen via het Mergin Maps-account gesynchroniseerd nadat de lokale controles slagen.

**Tech Stack:** Python 3.12, QGIS 3.44.7 PyQGIS, GeoPackage, GeoTIFF, `unittest`, GDAL/OGR, Mergin Maps QGIS-plugin.

**Spec:** `docs/superpowers/specs/2026-11-01-mergin-maps-meijendel-design.md`

## Global Constraints

- Projectnaam en uitvoermap eindigen op `meijendel`, niet op `meijendel_afscheidingen`.
- Het bestaande pakket `outputs/qfield_afscheidingen/meijendel_afscheidingen` blijft onaangeroerd.
- De builder overschrijft geen punten, lijnen, polygonen, schetsen, tracks of foto's.
- De lokale PDOK-luchtfoto 2025 en alle gegevenspaden blijven relatief.
- Deze taak wijzigt de levende Meijendel-database niet.
- De kaart gebruikt QGIS 3-projectinstellingen; QGIS 4 schrijft incompatibele plug-ininstellingen voor QGIS 3.

## Review Focus

- Bestaande veldgegevens in een van de vijf lagen of `photos/`: de builder stopt zonder wijziging.
- Ontbrekende of ongeldige luchtfoto: de builder stopt met een concrete fout.
- Mergin-laag-ID's in `meijendel.qgz`: zij verwijzen naar werkelijk aanwezige lagen.
- Projectpaden: geen absolute gebruikers- of worktreepaden in het QGIS-project.
- Schetskleurvolgorde: de zes afgesproken betekenissen blijven stabiel en een zevende neutrale notitiekleur blijft beschikbaar.

---

### Task 1: Mergin-projectbuilder en contracttests

**Files:**
- Create: `gis/mergin_maps/meijendel/build_meijendel_mergin.py`
- Create: `gis/mergin_maps/meijendel/test_build_meijendel_mergin.py`
- Reuse: `gis/qfield/afscheidingen/build_qfield_afscheidingen.py`

**Interfaces:**
- Consumes: `_build_vector_package(plot_layer, output_dir: Path, raster_source: Path | None) -> Path` uit de bestaande builder.
- Produces: QGIS Processing-algoritme `BuildMeijendelMergin`, `map_sketches.gpkg`, `tracking_layer.gpkg` en `meijendel.qgz` met Mergin-projectinstellingen.

- [ ] **Step 1: Schrijf falende tests**

Test dat de builder de vijf verwachte vectorlagen en drie bestaande veldwerklagen maakt, de Mergin-instellingen en zeven kleuren in `meijendel.qgz` vastlegt, relatieve paden gebruikt en herbouw bij inhoud in iedere veldlaag, schetslaag, trackinglaag of fotomap weigert.

- [ ] **Step 2: Voer de nieuwe tests uit en bevestig dat zij falen**

Run: `/Applications/QGIS.app/Contents/MacOS/qgis_process --version && python3 -m unittest gis/mergin_maps/meijendel/test_build_meijendel_mergin.py -v`

Expected: FAIL omdat builder en Mergin-uitvoer nog ontbreken.

- [ ] **Step 3: Implementeer de minimale builder**

Maak `BuildMeijendelMergin` met parameters `PLOTS`, `OUTPUT_DIR` en `RASTER`. Hergebruik de bestaande basisbuilder. Maak de officiële Mergin-lagen met respectievelijk `MultiLineStringZM` en `LineStringZM` in EPSG:4326 en schrijf deze projectwaarden:

- `Mergin/MapSketching/Enabled = true`;
- `Mergin/MapSketching/Layer = <laag-ID>`;
- `Mergin/MapSketching/Colors = #25a244,#f4a261,#d62828,#8b5a2b,#277da1,#111111,#ffffff`;
- `Mergin/PositionTracking/Enabled = true`;
- `Mergin/PositionTracking/TrackingLayer = <laag-ID>`;
- `Mergin/PositionTracking/UpdateFrequency = 1`;
- `Mergin/SortLayersMethod/Method = 0`.

- [ ] **Step 4: Voer tests uit en bevestig groen resultaat**

Run: `python3 -m unittest gis/mergin_maps/meijendel/test_build_meijendel_mergin.py -v`

Expected: alle nieuwe tests PASS.

- [ ] **Step 5: Commit de builder en tests**

Run: `git add gis/mergin_maps/meijendel docs/superpowers/specs/2026-11-01-mergin-maps-meijendel-design.md docs/superpowers/plans/2026-11-01-mergin-maps-meijendel.md && git commit -m "feat: build Meijendel project for Mergin Maps"`

### Task 2: Handleiding, werkelijk pakket en eindcontrole

**Files:**
- Create: `gis/mergin_maps/meijendel/README.md`
- Generate, ignored: `outputs/mergin_maps/meijendel/`

**Interfaces:**
- Consumes: `BuildMeijendelMergin` uit Task 1 en de bestaande luchtfoto `outputs/qfield_afscheidingen/meijendel_afscheidingen/luchtfoto_pdok_2025_25cm.tif`.
- Produces: een lokaal gecontroleerd project dat via de Mergin Maps QGIS-plugin kan worden geupload.

- [ ] **Step 1: Schrijf een falende handleidingstest**

Test op concrete stappen voor accountkoppeling, upload, downloaden op iPad, vliegtuigmodus, GNS 3000, punt/lijn/polygoon, GPS-streaming, Map Sketching, synchronisatie en bescherming van niet-gesynchroniseerde invoer.

- [ ] **Step 2: Voer de handleidingstest uit en bevestig dat zij faalt**

Run: `python3 -m unittest gis/mergin_maps/meijendel/test_build_meijendel_mergin.py -v`

Expected: FAIL omdat `README.md` ontbreekt.

- [ ] **Step 3: Schrijf de compacte gebruikershandleiding**

Beschrijf uitsluitend de Mergin Maps-knoppen en de veilige volgorde. Leg het onderscheid vast tussen vrije schets, definitieve afscheiding, position track en polygoon.

- [ ] **Step 4: Bouw en controleer het werkelijke project**

Run: `/Applications/QGIS.app/Contents/MacOS/qgis_process run gis/mergin_maps/meijendel/build_meijendel_mergin.py -- PLOTS=Plots_2025/avimap_252_diversen__gebieden.shp OUTPUT_DIR=outputs/mergin_maps/meijendel RASTER=outputs/qfield_afscheidingen/meijendel_afscheidingen/luchtfoto_pdok_2025_25cm.tif`

Controleer met `ogrinfo`, `gdalinfo` en inspectie van `meijendel.qgz`: 55 kavels; 0 records in vijf invoerlagen; 3-band COG in EPSG:28992; relatieve paden; juiste laag-ID's en Mergin-instellingen.

- [ ] **Step 5: Voer alle relevante regressietests uit**

Run: `python3 -m unittest gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py gis/mergin_maps/meijendel/test_build_meijendel_mergin.py -v`

Expected: alle tests PASS; alleen de bestaande expliciet overgeslagen luchtfoto-integratietest mag SKIP zijn als haar omgevingsvariabele niet is gezet.

- [ ] **Step 6: Commit, push en controleer de taakbranch**

Run: `git add gis/mergin_maps/meijendel && git commit -m "docs: add Mergin Maps field workflow" && git push -u origin codex/mergin-maps-meijendel`

Controleer dat de taakbranch schoon is en exact gelijkloopt met `origin/codex/mergin-maps-meijendel`. Upload naar Mergin Maps wacht op de accountkoppeling door Ton.
