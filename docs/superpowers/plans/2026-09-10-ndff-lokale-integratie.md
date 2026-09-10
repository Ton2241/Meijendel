# NDFF lokale beveiligde integratie Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Importeer de openbare FFV-staging en historische GBIF-vangblikreeks reproduceerbaar in `Meijendel`, behoud ticket 58679 in `Meijendel_ndff_secure` en ontsluit uitsluitend veilige analyseviews.

**Architecture:** De originele bronbestanden blijven op de T7. Open FFV- en GBIF-data worden in nieuwe, brongetrouwe tabellen binnen `Meijendel` opgenomen; beveiligde exacte NDFF-data blijven fysiek en logisch gescheiden in `Meijendel_ndff_secure`. Een hashkoppeling in het beveiligde schema verbindt de beveiligde verrijking aan de openbare bron zonder gevoelige velden naar `Meijendel` te kopieren.

**Tech Stack:** Python 3, GDAL/OGR, MySQL 9.7.1, R 4.6.1, Shiny, DBI/RMariaDB of lokale MySQL-client, shelltests.

**Spec:** `DECISIONS.md` en het in deze draad goedgekeurde ontwerp van 10 september 2026.

## Global Constraints

- Wijzig bestaande vogel- en provinciale PQ-tabellen niet; voeg alleen nieuwe openbare brontabellen aan `Meijendel` toe.
- Zet geen beveiligde NDFF-data, exacte geometrie, recordidentiteit of afgeleide detaildata in Git.
- Bewaar alle beveiligde bestanden onder `/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/secure/ticket_58679` met bestandenmodus `0600`.
- Geef `meijendel_read` geen rechten op `Meijendel_ndff_secure`.
- Activeer Shiny alleen met `NDFF_SECURE_LOCAL=1`; blokkeer activering bij productieruntime of onder `/srv/shiny-server`.
- Shiny leest alleen views zonder coördinaten, dagdatums, NDFF-identiteiten of bronpayload.
- Label positieve NDFF-regels niet als nul, afwezigheid, dichtheid of populatietrend.
- Behandel Provincie Zuid-Holland als oorspronkelijke en gezaghebbende PQ-bron; registreer NDFF-PQ uitsluitend als secundaire controlebron en blokkeer die records uit alle analyseviews.
- Voer geen VPS-deploy uit.
- Open FFV-records blijven positieve bronregistraties en krijgen standaard geen toelating voor trend, abundantie, afwezigheid of beheer-effectanalyse.
- De GBIF-vangblikreeks bewaart events, vangsten, locaties, inspanning en kwaliteitsvlaggen afzonderlijk; verweesde occurrences blijven bewaard maar uitgesloten.

---

### Task 1: Schema- en veiligheidscontract

**Files:**
- Modify: `gis/database/ndff_secure_schema.sql`
- Create: `gis/scripts/test_ndff_secure_schema_contract.py`

**Interfaces:**
- Consumes: beslisregel `ndff-secure-58679-v1` en bestaande voorbereidende tabellen.
- Produces: veilige views `v_ndff_lokale_overzicht`, `v_ndff_lokale_plot_jaar_taxon` en `v_ndff_lokale_protocolstatus`.

- [x] Schrijf een test die de vereiste tabellen/views, uitsluitingsfilters en afwezigheid van gevoelige kolommen in veilige views controleert.
- [x] Voer de test uit en controleer dat deze faalt omdat de veilige views ontbreken.
- [x] Voeg de minimale views en noodzakelijke statuskolommen/indexen aan het schema toe.
- [x] Voer de contracttest opnieuw uit en controleer dat deze slaagt.

### Task 2: Reproduceerbare importeur

**Files:**
- Create: `gis/scripts/import_ndff_secure_delivery.py`
- Create: `gis/scripts/test_import_ndff_secure_delivery.py`

**Interfaces:**
- Consumes: GeoPackage, ontvangstmanifest, analysepoort-, ruimtelijke-, plotmatch- en PQ-CSV's.
- Produces: transactionele MySQL-import en een beveiligd importmanifest met aantallen/hashes maar zonder locaties of identiteiten.

- [x] Schrijf een synthetische end-to-endtest voor invoercontrole, mapping, toelatingsstatus en manifesttelling.
- [x] Voer de test uit en controleer dat deze faalt omdat de importeur ontbreekt.
- [x] Implementeer validatie, droge controle en transactionele batchimport met `--login-path`.
- [x] Controleer dat bronrecords, soorten, geometrieën, groepsrecords, plotmatches, PQ-status en uitsluitingen volledig worden geschreven.
- [x] Voer de test en bestaande NDFF-ontvangsttest uit.

### Task 3: Lokaal Shiny-profiel

**Files:**
- Create: `shiny_meijendel/ndff_local.R`
- Create: `R/check_ndff_local_contract.R`
- Create: `shiny_meijendel/start_shiny_ndff_local.sh`
- Modify: `shiny_meijendel/app.R`
- Modify: `shiny_meijendel/README_shiny_meijendel.md`

**Interfaces:**
- Consumes: uitsluitend de drie veilige MySQL-views via login-path `meijendel_ndff_shiny`.
- Produces: lokale overzichtstab voor kwaliteits-, protocol- en plotjaarcontext zonder ruwe download.

- [x] Schrijf een R-contracttest voor featureflag, productieblokkade, view-allowlist en verboden velden.
- [x] Voer de test uit en controleer dat deze faalt omdat de module ontbreekt.
- [x] Implementeer de lokale module en conditionele tab zonder downloadhandlers.
- [x] Voeg een lokaal startscript toe dat alleen op `127.0.0.1` luistert en de featureflag zet.
- [x] Controleer dat de gewone app zonder featureflag ongewijzigd start en dat productie-activering hard wordt geweigerd.

### Task 4: Lokale database-inname

**Files:**
- Modify: `/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/secure/ticket_58679/manifests/analysis_manifest.json`
- Create: `/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/secure/ticket_58679/manifests/mysql_import_manifest.json`

**Interfaces:**
- Consumes: groen geteste schema- en importcode.
- Produces: lokaal schema `Meijendel_ndff_secure` en read-only account/login-path voor Shiny.

- [x] Start of controleer de lokale MySQL-server via het standaard macOS Terminal-venster als daarvoor sudo of een wachtwoord nodig is.
- [x] Voer het schema uit en importeer alle 14.573 bronrecords.
- [x] Controleer exact 14.573 bronrecords, 158 taxa, 8.494 verspreidingskandidaten, 1.274 trendkandidaten, 162 exacte en 163 niet-beoordeelbare PQ-records.
- [x] Maak een localhost-only Shiny-account met uitsluitend `SELECT` op de drie veilige views en leg het login-path interactief vast zonder wachtwoord in chat of Git.
- [x] Controleer dat `meijendel_read` geen rechten heeft en dat de life-database ongewijzigd is.

### Task 5: Documentatie en eindverificatie

**Files:**
- Modify: `ARCHITECTURE.md`
- Modify: `DECISIONS.md`
- Modify: `TODO.md`
- Modify: `STATUS.md`
- Modify: `docs/NDFF_SECURE_ONTVANGST.md`

**Interfaces:**
- Consumes: importmanifest en testresultaten.
- Produces: reproduceerbare lokale werkwijze en expliciete productiegrens.

- [x] Documenteer schema, importcommand, featureflag, veilige views en resterende wetenschappelijke beperkingen.
- [x] Voer alle Python- en R-contracttests, schema-uitvoering, Shiny-startcontrole en `git diff --check` uit.
- [x] Controleer bestandsrechten en hashes op de T7.
- [x] Voer workspace-preflight uit, commit en push naar de bestaande featurebranch.

### Task 6: Openbare FFV- en GBIF-schema's in Meijendel

**Files:**
- Create: `gis/database/ndff_public_schema.sql`
- Create: `gis/scripts/test_ndff_public_schema_contract.py`

**Interfaces:**
- Consumes: openbare FFV-staging, GBIF Darwin Core event/occurrence en de bestaande `Meijendel.plots`.
- Produces: genormaliseerde openbare brontabellen, fysieke soortgroeptabellen en analysepoorten zonder wijziging van bestaande tabellen.

- [x] Schrijf een contracttest die de databasescheiding, bronkorrel, kwaliteitsvlaggen en standaarduitsluitingen afdwingt.
- [x] Voer de test uit en controleer dat deze faalt omdat het schema ontbreekt.
- [x] Implementeer het minimale idempotente schema.
- [x] Voer de contracttest opnieuw uit en controleer dat deze slaagt.

### Task 7: Reproduceerbare openbare bulkimport

**Files:**
- Create: `gis/scripts/import_ndff_public_gbif.py`
- Create: `gis/scripts/test_import_ndff_public_gbif.py`
- Modify: `gis/database/ndff_secure_schema.sql`

**Interfaces:**
- Consumes: 810.830 FFV-records, 9.828 FFV-taxa, 37.770 GBIF-events en 60.560 GBIF-occurrences.
- Produces: transactionele bronimport, beveiligde hashkoppeling en een niet-gevoelig importmanifest.

- [x] Schrijf synthetische tests voor soortgroeptoewijzing, verplaatste blikken, vergelijkingsblikken, lege events, verweesde occurrences en beveiligde hashkoppeling.
- [x] Voer de tests uit en controleer dat zij op de ontbrekende implementatie falen.
- [x] Implementeer streaming TSV-generatie en gecontroleerde MySQL-bulkimport.
- [x] Voer de tests opnieuw uit en controleer dat zij slagen.

### Task 8: Volledige lokale inname en bewijs

**Files:**
- Modify: `ARCHITECTURE.md`
- Modify: `DECISIONS.md`
- Modify: `TODO.md`
- Modify: `STATUS.md`
- Modify: `docs/NDFF_STAGINGDATASET.md`
- Modify: `docs/NDFF_SECURE_ONTVANGST.md`
- Create: `/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/manifests/full_mysql_import_manifest.json`

**Interfaces:**
- Consumes: groen geteste schema's en importeur.
- Produces: controleerbare lokale import en actuele projectdocumentatie.

- [x] Importeer alle openbare FFV- en GBIF-rijen en maak de beveiligde hashkoppeling.
- [x] Controleer exacte aantallen, unieke sleutels, quarantaineregels, bronhashes en onveranderde bestaande PQ-/vogeltabellen.
- [x] Werk documentatie en manifest bij met de feitelijke uitkomst en analysebeperkingen.
- [x] Voer alle gerichte tests, `git diff --check` en de afsluitende workspace-preflight uit; commit en push de afgeronde wijziging.
