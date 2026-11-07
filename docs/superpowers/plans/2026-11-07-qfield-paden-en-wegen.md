# QField paden en wegen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Het offline QField-project Meijendel uitbreiden met veilige GNSS-registratie van voetpaden, fietspaden en wegen en hun toegankelijkheid.

**Architecture:** De bestaande QField-bouwer maakt naast `veldwerk.gpkg` een afzonderlijk `routes.gpkg` met één gecategoriseerde lijnlaag. Het QGIS-project verwijst relatief naar beide GeoPackages; een kleine upgradebundel vervangt alleen het projectbestand en voegt `routes.gpkg` toe, zodat bestaande veldwaarnemingen behouden blijven.

**Tech Stack:** Python 3, PyQGIS/QGIS 3.44, GeoPackage, QField, GDAL/OGR, `unittest`

**Spec:** `docs/superpowers/specs/2026-11-07-qfield-paden-en-wegen-design.md`

## Global Constraints

- Project-CRS en routelaag gebruiken `EPSG:28992`.
- De laag heet `paden_en_wegen` en staat in `routes.gpkg`.
- `type` bevat exact `voetpad`, `fietspad`, `weg`.
- `toegankelijkheid` bevat exact `openbaar`, `beperkt toegankelijk`, `afgesloten`.
- `veldwerk.gpkg`, de luchtfoto, `referentie.gpkg` en `photos/` worden bij de iPad-upgrade niet vervangen.
- Bestaande routeobjecten mogen nooit door een herbouw worden overschreven.

## Review Focus

- Een bestaande `routes.gpkg` met één of meer objecten moet de herbouw blokkeren.
- Het project mag geen absolute paden naar de iMac bevatten.
- De upgradebundel mag geen `veldwerk.gpkg` of fotomap bevatten.
- Beide verplichte keuzelijsten moeten exact de drie afgesproken waarden bevatten.
- Alle bestaande afscheidingen-, bijzonderheden- en gebiedencontracten moeten groen blijven.

---

### Task 1: Contracttests voor de routelaag

**Files:**
- Modify: `gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py`

**Interfaces:**
- Consumes: bestaand uitvoerpakket van `BuildQFieldAfscheidingen`
- Produces: contracten voor `routes.gpkg`, `paden_en_wegen`, formulieren, renderer, relatieve paden en overschrijfbeveiliging

- [ ] **Step 1: Voeg falende schema- en projectcontracten toe**

Controleer exact de negen velden uit het ontwerp, beide ValueMaps, drie renderercategorieën, `EPSG:28992`, een relatieve datasource en opname in het manifest.

- [ ] **Step 2: Voeg een falende overschrijftest toe**

Bouw een pakket, voeg één lijn toe aan `routes.gpkg`, bouw opnieuw en verwacht de bestaande melding over veldwerkgegevens plus behoud van die ene lijn.

- [ ] **Step 3: Voeg een falend upgradebundelcontract toe**

Controleer dat de bundel uitsluitend `meijendel.qgz`, `routes.gpkg` en een korte instructie bevat.

- [ ] **Step 4: Voer de gerichte tests uit**

Run: `python3 -m unittest gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py`

Expected: FAIL uitsluitend op de nog ontbrekende routefunctionaliteit.

### Task 2: Routelaag en veilige pakketbouw

**Files:**
- Modify: `gis/qfield/afscheidingen/build_qfield_afscheidingen.py`

**Interfaces:**
- Consumes: `plot_layer`, `output_dir` en optionele bestaande luchtfoto
- Produces: `routes.gpkg`, projectlaag `Paden en wegen`, bijgewerkt manifest en gegevensbehoudende upgradebundel

- [ ] **Step 1: Maak en configureer `paden_en_wegen`**

Voeg een `LineString`-laag toe met de negen velden, bestaande gemeenschappelijke standaardwaarden, verplichte `type`- en `toegankelijkheid`-constraints en een gecategoriseerde renderer op `type`.

- [ ] **Step 2: Voeg de laag met relatief pad aan het project toe**

Plaats `Paden en wegen` boven de onderzoekskavels en onder de bestaande veldwerklagen en voeg `routes.gpkg` toe aan `field_layers` in het manifest.

- [ ] **Step 3: Breid de overschrijfbeveiliging uit**

Laat `_ensure_rebuild_is_safe` stoppen wanneer `paden_en_wegen` in een bestaande `routes.gpkg` één of meer objecten bevat.

- [ ] **Step 4: Bouw de kleine upgradebundel**

Maak na een geslaagde bouw een ZIP met uitsluitend `meijendel.qgz`, `routes.gpkg` en `UPGRADE_IPAD.txt`; vermeld expliciet dat `veldwerk.gpkg` niet vervangen mag worden.

- [ ] **Step 5: Voer de contracttests uit**

Run: `python3 -m unittest gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py`

Expected: alle tests groen, behoudens de bestaande luchtfoto-afhankelijke skip.

### Task 3: Veldinstructie en werkelijk pakket

**Files:**
- Modify: `gis/qfield/afscheidingen/README.md`
- Modify: `docs/superpowers/specs/2026-10-31-qfield-afscheidingen-design.md`
- Generated, ignored: `outputs/qfield_afscheidingen/meijendel_afscheidingen/`
- Generated, ignored: `outputs/qfield_afscheidingen/meijendel_qfield.zip`
- Generated, ignored: `outputs/qfield_afscheidingen/meijendel_routes_upgrade.zip`

**Interfaces:**
- Consumes: groene bouwer en bestaande offline luchtfoto 2025 van 25 cm
- Produces: volledige verse installatie, gegevensbehoudende iPad-upgrade en concrete Engelse QField-bedieningsstappen

- [ ] **Step 1: Werk ontwerp en veldhandleiding bij**

Beschrijf `Side Dashboard` → lang indrukken op `Paden en wegen` → `Setup tracking` → instellingen 2 meter en 1 seconde → `Start tracking` → attributen kiezen → badge lang indrukken → `Stop tracking`. Leg uit dat een wijziging van type of toegankelijkheid een nieuw object vereist.

- [ ] **Step 2: Bouw het werkelijke pakket met de bestaande luchtfoto**

Gebruik de al aanwezige lokale luchtfoto uit het bestaande pakket als
`RASTER`-invoer voor `qgis_process`; download de 205 MB luchtfoto niet opnieuw.

Expected: volledig pakket, volledige ZIP en kleine upgrade-ZIP zonder verlies van bestaande veldgegevens.

- [ ] **Step 3: Valideer het werkelijke pakket**

Run: `QFIELD_PACKAGE_DIR=outputs/qfield_afscheidingen/meijendel_afscheidingen python3 -m unittest gis/qfield/afscheidingen/test_build_qfield_afscheidingen.py`

Expected: alle tests groen inclusief de luchtfotocontrole.

- [ ] **Step 4: Controleer ZIP-inhoud en GeoPackage**

Gebruik `unzip -l`, `ogrinfo -so` en project-XML-controle om exact de upgrade-inhoud, nul beginobjecten en relatieve paden vast te stellen.

- [ ] **Step 5: Commit, integreer en push**

Commit de bron-, test- en documentatiewijzigingen op de taakbranch, controleer de diff, merge naar actuele `main`, push GitHub en verifieer dat `main == origin/main`.
