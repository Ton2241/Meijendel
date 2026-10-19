# Maatregelen Datamodel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bouw een bronvast, tijd- en ruimtelijk expliciet werkzaamhedenmodel in de levende lokale Meijendel-database, voeg een volledige versieerbare gebiedsindeling toe en vul beide met uitsluitend veilig bewezen Meijendel-records.

**Architecture:** Nieuwe project-, uitvoerings-, jaar-, bron-, geometrie- en plotkoppelingstabellen staan naast de bestaande maatregelclassificatie. Een versieerbare indeling koppelt alle 69 plots aan vijf Meijendel-deelgebieden of drie speciale gebieden; uit de 55 geldige SOVON-geometrieën van 2025 worden acht topologisch samengevoegde gebiedsgeometrieën afgeleid. Alleen expliciete uitvoeringsjaren en geverifieerde plotkoppelingen voeden de bronvaste plot-jaarview; een maatregel–gebiedrelatie wordt nooit automatisch naar alle plots uitgebreid.

**Tech Stack:** MySQL 9.7.1, SQL, Python 3 contracttests, Markdown/DOCX-documentatie.

**Spec:** `docs/superpowers/specs/2026-10-13-maatregelen-datamodel-design.md`

## Global Constraints

- De levende lokale MySQL-database is de canonieke schrijfbron.
- Geen automatische `Meijendel.sql`-export, proefimport, Shiny-cachebouw of VPS-publicatie.
- Geen plotkoppeling zonder expliciete bron of aantoonbare geometrische relatie.
- Alleen Meijendel-records; zuiver Berkheidse maatregelen blijven buiten de eerste invoer.
- Plannen, onbekende uitvoering en feitelijke uitvoering blijven afzonderlijke statussen.
- De 55 actuele plots gebruiken uitsluitend SOVON-plotversie 2025 in EPSG:28992; voor de 14 historische plots wordt zonder historische bron geen geometrie gereconstrueerd.
- Een gebiedsrelatie en een plotrelatie blijven verschillende bewijslagen.

## Review Focus

- Een plan- of subsidiebron mag nooit als feitelijke uitvoering verschijnen.
- `jaarlijks` mag niet stilzwijgend tot alle tussenliggende uitvoeringsjaren worden uitgebreid.
- Een benoemde locatie zonder geometrie mag geen plotkoppeling opleveren.
- Herhaald uitvoeren van schema en seed moet dezelfde rijaantallen behouden.
- Bestaande `plot_jaar_maatregel`- en dashboardcontracten moeten onveranderd blijven.
- Alle 69 plots moeten exact één gebiedslidmaatschap krijgen; dubbele of ontbrekende lidmaatschappen blokkeren de migratie.
- Geometrische samenvoeging moet acht geldige gebiedsgeometrieën opleveren uit precies 55 actuele bronplots, zonder dubbel oppervlak binnen een gebied.
- Historische plots mogen niet ongemerkt een actuele of afgeleide geometrie krijgen.
- M54a moet de door Ton gebruikte aanduiding M54q normaliseren zonder een niet-bestaand plotrecord te creëren.
- De koppeling Voorlinden–M91 mag de onbekende uitvoering in 2025 niet als uitgevoerd in de plot-jaarview laten verschijnen.

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

### Task 6: Versieerbare gebiedsindeling

**Files:**
- Modify: `gis/database/maatregelen_schema.sql`
- Modify: `gis/database/maatregelen_seed.sql`
- Modify: `gis/scripts/test_maatregelen_schema_contract.py`
- Modify: `gis/scripts/test_maatregelen_seed_contract.py`
- Modify: `gis/scripts/import_external_ecology_sources.py`

**Interfaces:**
- Consumes: `plots`, `ndff_sovon_plotversie`, `ndff_sovon_plot` en het bestaande maatregelenmodel.
- Produces: `plot_gebied`, `plot_gebiedsindeling`, `plot_gebied_lidmaatschap`, `plot_gebied_geometrie`, `maatregel_uitvoering_gebied`, `v_plot_gebied_actueel` en `v_plot_gebied_geometrie_actueel`.

- [ ] **Schrijf de falende schematest.** Eis de vijf nieuwe tabellen, twee views, foreign keys, centrale-schemaregistratie en idempotentie.
- [ ] **Voer de schematest uit.** Verwacht een fout omdat `plot_gebied` nog niet bestaat.
- [ ] **Implementeer het minimale schema.** Leg gebiedstype, indelingsversie, één lidmaatschap per plot, geometrieherkomst en de afzonderlijke maatregel–gebiedrelatie vast.
- [ ] **Voer de schematest opnieuw uit.** Verwacht een volledig groene contracttest.
- [ ] **Schrijf de falende seedtest.** Eis 8 gebieden, 69 unieke lidmaatschappen, verdeling 12/7/23/12/12/1/1/1, 55 actuele en 14 historische statussen, M17 in Buitenduin Noord, M63 in Kijfhoek en Bierlap, M85 en M54a in Vallei Meijendel en geen record M54q.
- [ ] **Voer de seedtest uit.** Verwacht een fout omdat de gebiedsseed ontbreekt.
- [ ] **Voeg de minimale idempotente gebiedsseed toe.** Gebruik uitsluitend bestaande `plot_id`-waarden en leg de bevestiging van 13 oktober 2026 als besluitnotitie vast.
- [ ] **Voer de seedtest tweemaal uit.** Verwacht gelijke rijaantallen en exact één lidmaatschap per plot.

### Task 7: Afgeleide gebiedsgeometrieën

**Files:**
- Modify: `gis/scripts/import_meijendel_ruimtelijke_lagen.py`
- Modify: `gis/scripts/test_build_meijendel_ruimtelijke_lagen.py`

**Interfaces:**
- Consumes: de 55 actuele lidmaatschappen en WKB-geometrieën uit SOVON-plotversie 2025.
- Produces: acht geldige MULTIPOLYGON-geometrieën in EPSG:28992 met bronplotaantal, oppervlakte en SHA-256-hash.

- [ ] **Schrijf eerst falende geometrische functietests.** Gebruik overlappende testpolygonen en eis een topologische union zonder dubbel oppervlak, deterministische sortering, een geldige multipolygon en foutafhandeling voor ontbrekende of ongeldige brongeometrie.
- [ ] **Voer de ruimtelijke contracttest uit.** Verwacht een fout omdat de unionfunctie ontbreekt.
- [ ] **Implementeer de minimale unionfunctie en SQL-opbouw.** Lees de actuele bronpolygonen in vaste plotvolgorde, voeg ze met GDAL/OGR topologisch samen en schrijf alleen volledige acht-gebiedssets transactioneel terug.
- [ ] **Voer de ruimtelijke contracttest opnieuw uit.** Verwacht groen en een expliciete oppervlaktecontrole voor overlappende testpolygonen.
- [ ] **Voeg een droge-live-audit toe.** Eis plotversie 2025, 55 aanwezige en geldige brongeometrieën en bronplotaantallen 9/7/16/9/11/1/1/1 voordat `--apply` mag schrijven.

### Task 8: Eerste veilige gebieds- en plotkoppeling

**Files:**
- Modify: `gis/database/maatregelen_seed.sql`
- Modify: `gis/scripts/test_maatregelen_seed_contract.py`

**Interfaces:**
- Consumes: gebied Voorlinden, plot M91, uitvoering `pas_24c_voorlinden` en bron `zotero_n2000_ontwerp_2026`.
- Produces: één geverifieerde maatregel–gebiedrelatie en één geverifieerde plotkoppeling zonder ingevuld doorsnijdingspercentage.

- [ ] **Schrijf de falende koppelingstest.** Eis Voorlinden–M91 via `benoemd_gebied_gevalideerd`, `doorsnijding_pct IS NULL`, behoud van `jaarstatus='onbekend'` voor 2025 en nul rijen voor deze uitvoering in `v_plot_jaar_maatregel_bronvast`.
- [ ] **Voer de seedtest uit.** Verwacht een fout omdat de koppelingen ontbreken.
- [ ] **Voeg uitsluitend de bewezen Voorlinden-koppelingen toe.** Breid Vallei Meijendel, Kijfhoek en Bierlap of andere benoemde locaties niet automatisch uit naar alle onderliggende plots.
- [ ] **Voer de seedtest opnieuw en tweemaal uit.** Verwacht één plotkoppeling, één gebiedsrelatie en ongewijzigd nul uitvoeringsrijen voor Voorlinden in de bronvaste plot-jaarview.

### Task 9: Levende migratie, documentatie en afronding gebiedsmodel

**Files:**
- Modify: `docs/database/MEIJENDEL_TABELINVENTARIS.md`
- Modify: `docs/database/MEIJENDEL_TABELINVENTARIS.docx`
- Modify: `MDs/handboek.md`
- Modify: `docs/MEIJENDEL_BRONREGISTER.md`
- Modify: `docs/MEIJENDEL_BRONREGISTER.docx`

**Interfaces:**
- Consumes: Tasks 6–8 en de bestaande tabelgerichte back-uproute.
- Produces: gevalideerde levende database, actuele documentatie en een schone gepushte taakbranch.

- [ ] **Leg vóór wijziging de live stand vast.** Controleer 69 plots, 55 actuele SOVON-geometrieën uit 2025, 14 historische plots, 33 uitvoeringen, 58 uitvoeringsjaren, nul bestaande geometrieën en nul plotkoppelingen.
- [ ] **Maak een tabelgerichte lokale back-up en pas schema plus seed gecontroleerd toe.** Start geen zware `Meijendel.sql`-export, proefimport of cachebouw.
- [ ] **Bouw en schrijf de acht gebiedsgeometrieën.** Controleer geldigheid, SRID, bronplotaantallen, hashes en dat geen historische plot als geometriebron is gebruikt.
- [ ] **Voer de centrale audit en databasebrede taxoncontrole uit.** De nieuwe niet-taxonomische tabellen mogen geen bestaande waarneming of taxonbereik wijzigen.
- [ ] **Werk Markdown en beide Worddocumenten bij.** Noteer de concrete datasets, aantallen, versie 2025 en de beperking voor 14 historische grenzen.
- [ ] **Bouw en render beide DOCX-bestanden met de bestaande projectroute.** Controleer alle pagina's visueel op inhoudsgelijkheid, afbreking en tabellen.
- [ ] **Voer alle relevante contracttests, workspacecontrole en Git-controle uit.** Commit en push pas na volledig groene verificatie.
