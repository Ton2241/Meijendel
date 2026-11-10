# Ontvlechten dubbel afgesloten gebieden Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ontvlecht de twee dubbel afgesloten zones door alleen Ruygenhoek uit te snijden, zonder status- of dekkingswijziging.

**Architecture:** Voeg na de bestaande fietspadcorridorcorrectie één pure geometriefunctie toe. Die behoudt Garmin en Harstenhoek byte-identiek, trekt beide geometrieën van Ruygenhoek af en geeft dezelfde records terug met alleen een nieuwe Ruygenhoek-geometrie en herkomst. De bestaande migratie blijft de enige schrijfroutine voor tabellen en afleidingen.

**Tech Stack:** Python 3, GDAL/OGR, MySQL 9, R/sf voor onafhankelijke geometriecontrole, bestaande DOCX-synchronisatie.

**Spec:** `docs/superpowers/specs/2026-11-10-ontvlechten-dubbel-afgesloten-design.md`

## Global Constraints

- Garmin en Harstenhoek blijven geometrisch en inhoudelijk ongewijzigd.
- Alleen `ruygenhoek_afgesloten_1955` wordt uitgesneden.
- Alle drie statussen blijven `afgesloten`; datums blijven 1955-01-01 tot NULL.
- De zeven overlapparen met verschillende statussen veranderen niet.
- Databaseback-up gaat vooraf aan iedere schrijfactie.
- Geen zware export, proefimport, volledige cachebouw, merge of VPS-publicatie.

## Review Focus

- De correctie mag de gezamenlijke afgesloten unie niet verkleinen.
- De correctie mag Garmin en Harstenhoek niet wijzigen.
- De correctie moet beide Ruygenhoek-overlappen volledig verwijderen.
- De nieuwe bronketen moet de eerdere Ruygenhoek-herkomst behouden.
- Herhaald uitvoeren moet dezelfde geometrie en afleidingen opleveren.

---

### Task 1: Topologiecorrectie en contracttest

**Files:**
- Modify: `gis/scripts/test_toegankelijkheidsgebieden_contract.py`
- Modify: `gis/scripts/migrate_toegankelijkheidsgebieden.py`

**Interfaces:**
- Consumes: `apply_accepted_fietspad_corridor(feature, areas)` met actuele Garmin-, Harstenhoek- en Ruygenhoekrecords.
- Produces: `disentangle_same_status_closed_areas(feature, areas) -> tuple[dict, list[dict]]`.

- [ ] **Step 1: Schrijf de falende contracttest**

Test dat de invoer 92.880,406 m² Garmin–Ruygenhoek-overlap en 0,384 m² Harstenhoek–Ruygenhoek-overlap bevat. Roep daarna de nieuwe functie aan en eis: beide overlaps < 0,001 m²; Garmin- en Harstenhoekhash ongewijzigd; alle statussen afgesloten; gezamenlijke unie binnen 0,01 m² gelijk; Ruygenhoek gebruikt de technische broncode.

- [ ] **Step 2: Voer de contracttest uit en bevestig RED**

Run: `python3 gis/scripts/test_toegankelijkheidsgebieden_contract.py`
Expected: FAIL omdat `disentangle_same_status_closed_areas` nog niet bestaat.

- [ ] **Step 3: Implementeer de minimale topologiecorrectie**

Voeg de functie, broncode, bronregel, migratievolgorde en verificatie toe. Verhoog `MIGRATION_VERSION` naar `toegankelijkheidsgebieden-v13`.

- [ ] **Step 4: Voer de contracttest uit en bevestig GREEN**

Run: `python3 gis/scripts/test_toegankelijkheidsgebieden_contract.py`
Expected: `OK: toegankelijkheidsgebieden-contract`.

### Task 2: Levende database, bronregister en kaart

**Files:**
- Modify: `docs/MEIJENDEL_BRONREGISTER.md`
- Modify: `docs/MEIJENDEL_BRONREGISTER.docx`
- Modify: `scripts/sync_bronregister_toegankelijkheidsgebieden.py`
- Create on registered T7 task directory: database backup, verification evidence and control map.

**Interfaces:**
- Consumes: the v13 migration output from Task 1.
- Produces: corrected live database, synchronized source register, inspectable map and recovery evidence.

- [ ] **Step 1: Maak de geregistreerde T7-taakmap en voer een droge migratie uit**

Expected: 13 gebieden, ongewijzigde statuses, nul overlap in beide gelijk-statusparen.

- [ ] **Step 2: Pas de migratie toe met voorafgaande back-up**

Run: `python3 gis/scripts/migrate_toegankelijkheidsgebieden.py --apply`
Expected: back-upmetadata plus geslaagde verificatie.

- [ ] **Step 3: Controleer de levende database onafhankelijk**

Controleer gebiedsaantallen, datums, hashes, gezamenlijke unie, beide verwijderde overlaps en de zeven onaangeroerde conflicterende overlapparen met R/sf.

- [ ] **Step 4: Actualiseer en render het bronregister**

Synchroniseer Markdown en DOCX, render via `t7_work.py render` en controleer alle gewijzigde pagina’s visueel.

- [ ] **Step 5: Genereer en inspecteer de gecorrigeerde kaart**

Toon de actuele statusgebieden; markeer alleen de zeven resterende conflicterende overlapzones.

- [ ] **Step 6: Voer eindcontroles uit en commit/push de taakbranch**

Run contracttest, migratie `--verify`, `git diff --check`, documentrendercontrole en Git-upstreamcontrole. Commit en push alleen de taakbranch; niet mergen of publiceren.
