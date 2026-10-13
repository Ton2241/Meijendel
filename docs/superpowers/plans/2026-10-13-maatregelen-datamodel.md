# Maatregelen Datamodel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bouw een bronvast, tijd- en ruimtelijk expliciet werkzaamhedenmodel in de levende lokale Meijendel-database en vul het met uitsluitend veilig bewezen Meijendel-records.

**Architecture:** Nieuwe project-, uitvoerings-, jaar-, bron-, geometrie- en plotkoppelingstabellen staan naast de bestaande maatregelclassificatie. Alleen expliciete uitvoeringsjaren en geverifieerde plotkoppelingen voeden de nieuwe bronvaste plot-jaarview; de bestaande dashboardlaag blijft intact.

**Tech Stack:** MySQL 9.7.1, SQL, Python 3 contracttests, Markdown/DOCX-documentatie.

**Spec:** `docs/superpowers/specs/2026-10-13-maatregelen-datamodel-design.md`

## Global Constraints

- De levende lokale MySQL-database is de canonieke schrijfbron.
- Geen automatische `Meijendel.sql`-export, proefimport, Shiny-cachebouw of VPS-publicatie.
- Geen plotkoppeling zonder expliciete bron of aantoonbare geometrische relatie.
- Alleen Meijendel-records; zuiver Berkheidse maatregelen blijven buiten de eerste invoer.
- Plannen, onbekende uitvoering en feitelijke uitvoering blijven afzonderlijke statussen.

## Review Focus

- Een plan- of subsidiebron mag nooit als feitelijke uitvoering verschijnen.
- `jaarlijks` mag niet stilzwijgend tot alle tussenliggende uitvoeringsjaren worden uitgebreid.
- Een benoemde locatie zonder geometrie mag geen plotkoppeling opleveren.
- Herhaald uitvoeren van schema en seed moet dezelfde rijaantallen behouden.
- Bestaande `plot_jaar_maatregel`- en dashboardcontracten moeten onveranderd blijven.

---

### Task 1: Schemacontract en idempotent schema

**Files:**
- Create: `gis/scripts/test_maatregelen_schema_contract.py`
- Create: `gis/database/maatregelen_schema.sql`

**Interfaces:**
- Produces: referentietabellen, project/uitvoering/jaar/bron/geometrie/plotkoppeling en `v_plot_jaar_maatregel_bronvast`.

- [ ] Schrijf eerst een contracttest die het schema in een tijdelijke MySQL-database toepast en sleutels, checks, idempotentie en de lege bronvaste view controleert.
- [ ] Voer de test uit en bevestig dat hij faalt omdat het schema ontbreekt.
- [ ] Implementeer het minimale idempotente schema.
- [ ] Voer de contracttest tweemaal uit en bevestig gelijke rijaantallen.

### Task 2: Bronvaste eerste invoer

**Files:**
- Create: `gis/database/maatregelen_seed.sql`
- Create: `gis/scripts/test_maatregelen_seed_contract.py`

**Interfaces:**
- Consumes: tabellen uit Task 1.
- Produces: idempotente bronnen, projecten, uitvoeringen en uitsluitend letterlijk bewezen uitvoeringsjaren.

- [ ] Schrijf eerst een test met handmatig verwachte codes, statussen en rijaantallen.
- [ ] Voer de test uit en bevestig dat hij faalt omdat de seed ontbreekt.
- [ ] Voeg de beoordeelde Meijendel-bronnen en uitvoeringen toe; voeg geen plotkoppelingen toe zonder geometrie.
- [ ] Voer schema en seed tweemaal uit en controleer idempotentie, brondekking en nul plotkoppelingen.

### Task 3: Levende database veilig migreren

**Files:**
- Modify: `Ruimtelijke data/15_herstel_datamodel_maatregelen_toegankelijkheid.sql`

**Interfaces:**
- Consumes: schema en seed uit Tasks 1–2.
- Produces: controlequery voor de levende database.

- [ ] Maak een tijdelijke tabelgerichte back-up van de drie bestaande maatregelentabellen.
- [ ] Leg beginrijtellingen en checksums vast.
- [ ] Pas schema en seed in één gecontroleerde lokale transactie toe.
- [ ] Voer de audit tweemaal uit en controleer bestaande rijaantallen, nieuwe sleutels, nul verweesde relaties en nul ongefundeerde plotkoppelingen.

### Task 4: Documentatie en bronregister

**Files:**
- Modify: `docs/database/MEIJENDEL_TABELINVENTARIS.md`
- Modify: `docs/database/MEIJENDEL_TABELINVENTARIS.docx`
- Modify: `MDs/handboek.md`
- Modify: `docs/MEIJENDEL_BRONREGISTER.md`
- Modify: `docs/MEIJENDEL_BRONREGISTER.docx`

**Interfaces:**
- Consumes: definitief schema, seed en live-audit uit Tasks 1–3.
- Produces: inhoudelijk gelijke Markdown- en Worddocumentatie.

- [ ] Werk de Markdown-documentatie bij met tabellen, bewijsregels, aantallen en standdatum 13 oktober 2026.
- [ ] Bouw beide DOCX-bestanden met de bestaande projectroute opnieuw op.
- [ ] Render de DOCX-bestanden en controleer alle pagina’s visueel.

### Task 5: Regressiecontrole en Git-afronding

**Files:**
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: alle voorgaande taken.
- Produces: geteste, gedocumenteerde taakbranch met upstream.

- [ ] Voer de nieuwe contracttests, relevante bestaande dashboard-/Shinytests en workspacecontrole uit.
- [ ] Controleer databasebrede integriteit en bevestig dat bestaande `plot_jaar_maatregel` 144 rijen behoudt.
- [ ] Controleer diff op tijdelijke of gegenereerde bestanden.
- [ ] Commit de samenhangende wijziging en push de taakbranch.
