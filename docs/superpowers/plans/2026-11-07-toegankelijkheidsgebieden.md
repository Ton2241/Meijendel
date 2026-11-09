# Toegankelijkheidsgebieden Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Vervang voorlopige kavelstatussen door versieerbare toegankelijkheidspolygonen en leid de kavelpercentages daar reproduceerbaar uit af.

**Architecture:** Native polygonen en geldigheid vormen de bronlaag; een opnieuw opbouwbare doorsnijdingstabel voedt plotanalyses. Shiny en het browserdashboard lezen uitsluitend het nieuwe contract. De levende migratie verwijdert de oude 55 feiten pas nadat back-up, schema en eerste polygon zijn gevalideerd.

**Tech Stack:** MySQL 9.7.4 spatial, Python 3, GDAL/OGR, R/Shiny, JavaScript.

**Spec:** `docs/superpowers/specs/2026-11-07-toegankelijkheidsgebieden-design.md`

## Global Constraints

- `geldig_vanaf` is `1955-01-01` tenzij expliciet overschreven.
- `geldig_tot IS NULL` betekent actueel.
- De drie bronstatussen zijn exact `afgesloten`, `toegankelijk` en `toegankelijk_met_toegangskaart`.
- De 55 oude kavelregistraties en hun 55 herkomstdoelen verdwijnen volledig uit het actieve model.
- Bron 101 en de 139 beheerregistraties blijven behouden.
- Geen zware SQL-export, volledige cachebouw of VPS-publicatie zonder afzonderlijk akkoord.

## Review Focus

- Een tweede open versie van hetzelfde gebied moet worden geweigerd.
- Ongedekt kaveloppervlak moet `onbekend` blijven en mag niet als toegankelijk worden geïmputeerd.
- Een gedeeltelijke doorsnijding mag niet als status van het hele kavel worden gepresenteerd.
- De migratie mag geen beheerregistratie of uitvoeringsherkomst verwijderen.
- Een ongeldige of niet-RD-geometrie moet vóór import worden geweigerd.

---

### Task 1: Eindtoestandschema en migratiecontract

**Files:**
- Modify: `gis/database/maatregelen_schema.sql`
- Create: `gis/scripts/migrate_toegankelijkheidsgebieden.py`
- Create: `gis/scripts/test_toegankelijkheidsgebieden_contract.py`
- Modify: `gis/scripts/import_external_ecology_sources.py`

**Interfaces:**
- Consumes: `plots.geom`, `maatregel_bron`, het QField-GeoPackage.
- Produces: `toegankelijkheidsgebied*` en een idempotente migratie met back-up en verificatie.

- [ ] Schrijf eerst contracttests voor statuswaarden, standaarddatum, open-einduniciteit, ruimtelijke afleiding, exacte verwijderomvang en behoud van beheer/herkomst.
- [ ] Voer de contracttest uit en bevestig dat zij faalt doordat schema en migratie ontbreken.
- [ ] Implementeer het eindtoestandschema en de kleinste idempotente migratie.
- [ ] Voer de contracttests opnieuw uit en bevestig groen resultaat.

### Task 2: Shiny- en browsercontract

**Files:**
- Modify: `shiny_meijendel/helpers.R`
- Modify: `shiny_meijendel/app.R`
- Modify: `R/build_dashboard_browser_data.R`
- Modify: `bmp_meijendel_index.html`
- Modify: `R/test_meijendel_cache_contract.R`
- Modify: `scripts/test_dashboard_browser_data_contract.sh`
- Modify: `scripts/test_dashboard_browser_data_loader.js`

**Interfaces:**
- Consumes: actuele gebiedsversies en `toegankelijkheidsgebied_plot_afleiding`.
- Produces: vier oppervlakteaandelen en een uitsluitend afgeleide presentatiestatus.

- [ ] Vervang eerst de tests van het oude kavelcontract door falende tests voor percentages, onbekend restoppervlak en gemengde kavels.
- [ ] Verwijder de oude leesroute en implementeer de nieuwe tabel- en covariaatcontracten.
- [ ] Voer de gerichte R- en browsertests uit en bevestig groen resultaat.

### Task 3: Levende migratie en documentatie

**Files:**
- Modify: `docs/MEIJENDEL_BRONREGISTER.md`
- Modify: `docs/MEIJENDEL_BRONREGISTER.docx`
- Modify: `docs/database/MEIJENDEL_TABELINVENTARIS.md`
- Modify: `MDs/handboek.md`
- Modify: `R/shiny_berekenlogica.md`
- Modify: `Recreatie/README_recreatie_import.md`

**Interfaces:**
- Consumes: gevalideerde migratie en QField-object `2b3ae5c9-1ef6-4d82-9247-470fcc8054f6`.
- Produces: levende lokale database met één actueel afgesloten gebied en zonder voorlopige kavelregistraties.

- [ ] Maak vóór iedere databasewijziging een leesbare herstelback-up op de aangewezen T7-locatie en registreer SHA-256.
- [ ] Voer de migratie uit, importeer het vlak en bouw de afleiding opnieuw op.
- [ ] Verifieer rijtellingen, geometrie, geldigheid, statussen, percentages en behoud van de 139 beheerregistraties en overige 144 herkomstdoelen.
- [ ] Werk documentatie en beide bronregisterformaten bij; render en controleer de Wordversie.

### Task 4: Integrale verificatie en Git-afronding

**Files:**
- Modify: tests en documentatie uitsluitend wanneer een gerichte regressie dat vereist.

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: geteste taakbranch, commit en push zonder VPS-publicatie.

- [ ] Voer schema-, migratie-, R-, JavaScript- en documentcontroles uit.
- [ ] Controleer dat actieve code nergens meer naar `maatregel_toegankelijkheid_registratie` verwijst.
- [ ] Laat een verse eindreview uitvoeren en herstel Critical/Important-bevindingen met RED→GREEN.
- [ ] Commit en push de afgeronde taakbranch; meld de zware afgeleide keten als afzonderlijk resterend besluit.

### Task 5: Gecorrigeerde samengestelde grens Bierlap-Kijfhoek

**Files:**
- Modify: `gis/scripts/migrate_toegankelijkheidsgebieden.py`
- Modify: `gis/scripts/test_toegankelijkheidsgebieden_contract.py`
- Modify: `docs/MEIJENDEL_BRONREGISTER.md`
- Modify: `docs/MEIJENDEL_BRONREGISTER.docx`
- Modify: `R/shiny_berekenlogica.md`

**Interfaces:**
- Consumes: Garmin-activiteit 25020262638, de PDOK-luchtfoto 2025 en de geometrie van M6.
- Produces: één herleidbare land-water-kavelgrens voor `bierlap_kijfhoek_dagkaart_1955`.

- [x] Leg met een falende test vast dat het Garmin-deel bij de wit-zwarte marker stopt en dat het sluitsegment afzonderlijke bronmetadata heeft.
- [x] Digitaliseer het watersegment via het korte landstuk tot de oeverknik van M6 en render een proefkaart.
- [x] Controleer dat de proefgeometrie één geldig vlak zonder interne ringen vormt en uitsluitend het bedoelde deel van M4-5 afsnijdt.
- [x] Maak een T7-herstelkopie, vervang de levende gebiedsversie en herbereken alle plotdoorsnijdingen.
- [x] Werk het bronregister en de berekeningsdocumentatie bij; render de Word-versie en voer de volledige contracttestset uit.
- [x] Commit en push de correctie zonder SQL-export, cachebouw of VPS-publicatie.

### Task 6: Definitief akkoordvlak en één databaseversie

**Files:**
- Modify: `gis/scripts/migrate_toegankelijkheidsgebieden.py`
- Modify: `gis/scripts/test_toegankelijkheidsgebieden_contract.py`
- Modify: bronregister, berekeningsdocumentatie en ontwerp

- [x] Vergrendel Garmin-punten 0–396, de vloeiende lijn en het visueel goedgekeurde GeoPackage-vlak met contracttests.
- [x] Toon de volledige buitengrens in blauw.
- [x] Maak een gerichte T7-herstelkopie en vervang alle eerdere Bierlap-Kijfhoek-versies door precies één actuele versie.
- [x] Synchroniseer en render het bronregister; voer de volledige gerichte verificatie uit.
- [x] Commit en push de taakbranch zonder SQL-export, cachebouw, merge of VPS-publicatie.
