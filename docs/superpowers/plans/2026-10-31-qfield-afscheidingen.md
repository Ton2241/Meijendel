# Offline QField-project Afscheidingen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Een herhaalbaar gebouwd en lokaal overdraagbaar QField-pakket maken voor offline registratie van afscheidingen en bijzonderheden in de 55 Meijendel-kavels.

**Architecture:** Een kleine PyQGIS Processing-builder maakt twee GeoPackages en een relatief QGIS-project. Een afzonderlijke rasterstap haalt de vaste PDOK-laag `2025_ortho25` als lokale COG binnen; het resultaat komt in de genegeerde uitvoermap `outputs/qfield_afscheidingen/`, terwijl builder, tests en handleiding in Git blijven.

**Tech Stack:** QGIS/qgis_process 3.44.7, PyQGIS, GDAL/OGR, GeoPackage, Cloud Optimized GeoTIFF, Python unittest.

**Spec:** `docs/superpowers/specs/2026-10-31-qfield-afscheidingen-design.md`

## Global Constraints

- Project-CRS is RD New, EPSG:28992.
- De 55 bronpolygonen uit `Plots_2025/avimap_252_diversen__gebieden.shp` blijven ongewijzigd en worden als alleen-lezen kopie verpakt.
- De offline luchtfoto gebruikt de vaste definitieve PDOK-laag `2025_ortho25`; `Actueel` wordt niet gebruikt.
- Het veld `ontvanger` krijgt standaard `GNS 3000 via iPadOS`.
- Alle projectpaden en fotopaden zijn relatief.
- Het pakket is lokaal overdraagbaar en vereist geen QFieldCloud.
- Geen invoer in de levende Meijendel-database en geen gebruik van T7 of NAS.

## Review Focus

- Een bronlaag met niet precies 55 geldige polygonen moet de bouw stoppen, niet een onvolledig pakket opleveren; test in Task 1.
- Samengestelde kavelnummers zoals `4-5`, `10-12-76` en `78/79` moeten als `M4-5`, `M10-12-76` en `M78/79` worden gelabeld; test in Task 1.
- Een offlinepakket mag nergens een absolute lokale gebruikersmap als gegevensbron bevatten; test in Task 2.
- De meetlagen moeten leeg maar direct bewerkbaar zijn, met unieke UUID-defaults en exact de goedgekeurde keuzelijsten; tests in Task 2 en Task 5.
- Een onvolledige of onleesbare luchtfoto mag niet als geslaagde bouw worden gemeld; test in Task 3.

---

### Task 1: Buildercontract en ruimtelijke broncontrole

**Files:**
- Create: `gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py`
- Create: `gis/qfield/afscheidingen/build_qfield_afscheidingen.py`

**Interfaces:**
- Consumes: de 2025-SOVON-shapefile en een uitvoermap.
- Produces: `validate_plot_source(layer)`, `plot_label(name)` en Processing-algoritme `BuildQFieldAfscheidingen`.

- [x] **Step 1: Write the failing unit tests**

Maak tests die `plot_label()` voor gewone en samengestelde namen vastleggen en die via `qgis_process` aantonen dat een bron met een fout featureaantal wordt geweigerd.

- [x] **Step 2: Run tests to verify RED**

Run: `python3 -m unittest gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py -v`

Expected: FAIL omdat de builder en functies nog ontbreken.

- [x] **Step 3: Implement the minimal builder contract**

Implementeer de labelnormalisatie, validatie van 55 geldige polygonen in EPSG:28992 en de benodigde Processing-parameters voor bron, uitvoermap en optionele rasterbron.

- [x] **Step 4: Run tests to verify GREEN**

Run: `python3 -m unittest gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py -v`

Expected: PASS voor label- en bronvalidatie.

- [x] **Step 5: Commit**

Commit: `feat: add qfield fieldwork builder contract`

### Task 2: GeoPackages, formulieren, styling en relatief QGIS-project

**Files:**
- Modify: `gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py`
- Modify: `gis/qfield/afscheidingen/build_qfield_afscheidingen.py`

**Interfaces:**
- Consumes: gevalideerde plotlaag en builderparameters uit Task 1.
- Produces: `referentie.gpkg`, `veldwerk.gpkg`, `photos/` en `meijendel_afscheidingen.qgz`.

- [x] **Step 1: Write the failing package-contract tests**

Test laag- en featureaantallen, geometrieën, velden, defaults, keuzevelden, stijlen, project-CRS, relatieve bronpaden, alleen-lezen plotlaag en afwezigheid van absolute `/Users/ton/`-paden in de QGZ-inhoud.

- [x] **Step 2: Run tests to verify RED**

Run: `python3 -m unittest gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py -v`

Expected: FAIL omdat de pakketbestanden nog niet worden gemaakt.

- [x] **Step 3: Implement the package build**

Maak de plotkopie, beide lege meetlagen met de in de spec vastgelegde velden en widgets, de stijlen, QField-defaults en het relatieve QGIS-project.

- [x] **Step 4: Run tests to verify GREEN**

Run: `python3 -m unittest gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py -v`

Expected: PASS; QGIS leest het project en alle drie vectorlagen geldig terug.

- [x] **Step 5: Commit**

Commit: `feat: build offline qfield vector package`

### Task 3: Vaste PDOK-luchtfoto en volledig offlinepakket

**Files:**
- Create: `gis/qfield/afscheidingen/download_pdok_luchtfoto.sh`
- Modify: `gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py`
- Modify: `gis/qfield/afscheidingen/build_qfield_afscheidingen.py`

**Interfaces:**
- Consumes: gebufferde kavelextent en PDOK WMS-laag `2025_ortho25`.
- Produces: `luchtfoto_pdok_2025_25cm.tif` als geldige COG en een QGIS-project dat deze laag relatief en standaard zichtbaar gebruikt.

- [x] **Step 1: Write the failing raster-contract tests**

Test vaste laagnaam, EPSG:28992, volledige gebufferde extent, rasterafmetingen groter dan nul, drie beeldbanden, COG-layout en geldige rasterlaag in QGIS.

- [x] **Step 2: Run tests to verify RED**

Run: `python3 -m unittest gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py -v`

Expected: FAIL omdat de lokale luchtfoto ontbreekt.

- [x] **Step 3: Implement and run the raster download**

Maak een GDAL-WMS-configuratie voor `2025_ortho25`, download op 25 cm-resolutie, schrijf JPEG-gecomprimeerde COG-overviews en bouw het QGIS-project opnieuw met de lokale rasterlaag.

- [x] **Step 4: Run tests to verify GREEN**

Run: `python3 -m unittest gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py -v`

Expected: PASS; `gdalinfo` en QGIS lezen de volledige offline luchtfoto zonder netwerkbron.

- [x] **Step 5: Commit**

Commit: `feat: add fixed pdok aerial basemap`

### Task 4: Gebruikershandleiding en eindcontrole

**Files:**
- Create: `gis/qfield/afscheidingen/README.md`
- Modify: `docs/superpowers/plans/2026-10-31-qfield-afscheidingen.md`

**Interfaces:**
- Consumes: het voltooide lokale pakket en de GNS 3000-veldconfiguratie.
- Produces: concrete overdrachts-, koppel-, offline- en proefmeetstappen voor iPad/QField.

- [x] **Step 1: Write the documentation contract test**

Test dat de handleiding de pakketlocatie, lokale overdracht, iPadOS-koppeling, offlinecontrole, punt/lijn/foto-proef, `offset_m` en terugkopiëren naar de iMac benoemt.

- [x] **Step 2: Run tests to verify RED**

Run: `python3 -m unittest gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py -v`

Expected: FAIL omdat de handleiding ontbreekt.

- [x] **Step 3: Write the compact field guide**

Beschrijf installatie van QField, overdracht zonder cloud, koppeling van de GNS 3000, eerste offlineproef, veldinvoer en veilig terugzetten van het bijgewerkte pakket.

- [x] **Step 4: Run full verification**

Run: `python3 -m unittest gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py -v`

Expected: alle tests PASS.

Run: `/Applications/QGIS.app/Contents/MacOS/qgis_process run gis/qfield/afscheidingen/build_qfield_afscheidingen.py -- PLOTS=Plots_2025/avimap_252_diversen__gebieden.shp OUTPUT_DIR=outputs/qfield_afscheidingen/meijendel_afscheidingen RASTER=outputs/qfield_afscheidingen/meijendel_afscheidingen/luchtfoto_pdok_2025_25cm.tif`

Expected: succesvolle bouw met 55 plots en twee lege veldlagen.

- [x] **Step 5: Commit**

Commit: `docs: add qfield gns 3000 field guide`

### Task 5: Projectnaam en veldkeuzen actualiseren

**Files:**
- Modify: `docs/superpowers/specs/2026-10-31-qfield-afscheidingen-design.md`
- Modify: `gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py`
- Modify: `gis/qfield/afscheidingen/build_qfield_afscheidingen.py`
- Modify: `gis/qfield/afscheidingen/README.md`

**Interfaces:**
- Consumes: de bestaande pakketbouwer en de twee ongewijzigde GeoPackage-tabellen.
- Produces: `meijendel.qgz` met projecttitel `Meijendel`, zes typen voor `afscheidingen.type` en drie aanvullende waarden voor `bijzonderheden.soort`.

- [x] **Step 1: Write the failing contract tests**

Test exact de zes typen `hekwerk`, `hoge draad`, `lage draad`, `wildrooster`, `muur` en `regelgebaseerd`; test de aanvullende bijzonderheden `inclosure`, `exclosure` en `dierenverzamelplek`; test dat het pakket `meijendel.qgz` bevat en niet `meijendel_afscheidingen.qgz`.

- [x] **Step 2: Run tests to verify RED**

Run: `python3 -m unittest gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py -v`

Expected: FAIL op de oude projectnaam en oude keuzelijst.

- [x] **Step 3: Implement the minimal builder and guide changes**

Vervang uitsluitend de waardenlijst van `afscheidingen.type`, voeg de drie waarden toe aan `bijzonderheden.soort`, schrijf `meijendel.qgz`, stel de projecttitel in op `Meijendel` en pas de pakketnaam in de veldhandleiding aan. Wijzig geen velden of GeoPackage-tabellen.

- [x] **Step 4: Rebuild and verify**

Run de volledige unittest-suite en de afzonderlijke rastertest. Bouw alleen opnieuw als `afscheidingen` en `bijzonderheden` elk 0 records bevatten en `photos/` 0 bestanden bevat. Controleer in een verplaatste proefmap alle vier relatieve bronnen.

- [x] **Step 5: Commit and integrate**

Commit de specificatie, het plan, de builder, tests en handleiding; integreer na groene eindcontrole in `main` en push naar GitHub.

### Task 6: Zes afscheidingstypen afzonderlijk in de legenda tonen

**Files:**
- Modify: `docs/superpowers/specs/2026-10-31-qfield-afscheidingen-design.md`
- Modify: `gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py`
- Modify: `gis/qfield/afscheidingen/build_qfield_afscheidingen.py`

**Interfaces:**
- Consumes: de zes waarden van `afscheidingen.type` uit Task 5.
- Produces: een `QgsCategorizedSymbolRenderer` op veld `type` met exact zes legenda-items en per type een eigen kleur en lijnpatroon.

- [x] **Step 1: Write the failing renderer test**

Test dat de QGZ voor `Afscheidingen` een gecategoriseerde renderer op `type` bevat met exact `hekwerk`, `hoge draad`, `lage draad`, `wildrooster`, `muur` en `regelgebaseerd`.

- [x] **Step 2: Run tests to verify RED**

Run: `python3 -m unittest gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py -v`

Expected: FAIL omdat `Afscheidingen` nog een enkel rood lijnsymbool gebruikt.

- [x] **Step 3: Implement the six line categories**

Vervang uitsluitend de renderer van `Afscheidingen` door zes `QgsRendererCategory`-objecten op veld `type`, met de in de specificatie vastgelegde kleuren en patronen. Laat invoervelden en waardenlijst ongewijzigd.

- [x] **Step 4: Rebuild and verify**

Run de volledige unittest-suite inclusief de actuele rastertest. Bouw uitsluitend een leeg pakket opnieuw en controleer in de QGZ de zes categorieën en de vier relatieve bronnen.

- [x] **Step 5: Commit and integrate**

Commit specificatie, plan, builder en test; integreer na groene eindcontrole in `main` en push naar GitHub.

### Task 7: Poort als lijn en schaalafhankelijke puntsymbolen

**Files:**
- Modify: `docs/superpowers/specs/2026-10-31-qfield-afscheidingen-design.md`
- Modify: `gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py`
- Modify: `gis/qfield/afscheidingen/build_qfield_afscheidingen.py`
- Modify: `gis/qfield/afscheidingen/README.md`

**Interfaces:**
- Consumes: de bestaande lijnlaag `afscheidingen` en puntlaag `bijzonderheden`.
- Produces: `poort/doorgang` als zevende lijncategorie en puntsymbolen van 10 kaartmeter, begrensd op 1,2–4,2 mm.

- [x] **Step 1: Write the failing contract test**

Test dat `poort/doorgang` uitsluitend in de lijnkeuzelijst en lijnrenderer staat en dat alle puntsymbolen kaartmeters met de afgesproken begrenzing gebruiken.

- [x] **Step 2: Run tests to verify RED**

Run de volledige unittest-suite; verwacht FAIL op de ontbrekende lijncategorie.

- [x] **Step 3: Implement the minimal model and symbol changes**

Verplaats de waarde zonder tabelwijziging, voeg de lijnstijl toe en stel uitsluitend voor de puntlaag kaartmeters met minimum- en maximumschermmaat in.

- [x] **Step 4: Rebuild and verify**

Run de volledige tests. Bouw uitsluitend een leeg pakket opnieuw en controleer de QGZ, relatieve bronnen en ZIP.

- [x] **Step 5: Commit and integrate**

Commit specificatie, plan, builder, test en handleiding; integreer na groene eindcontrole in `main` en push naar GitHub.

