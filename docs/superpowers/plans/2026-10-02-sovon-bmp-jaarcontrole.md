# SOVON-BMP Jaarcontrole Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Voeg een brongetrouwe, versieerbare SOVON-BMP-ontvangstlaag toe en voer daarna de eerste gecontroleerde jaarvergelijking voor 1984 uit, zonder VWG-jaarverslaggegevens te wijzigen.

**Architecture:** Jaarwerkboeken worden eerst genormaliseerd onder `sovon_bmp_*`. `sovon_bmp_plotjaar` bewaart de vijf nulvoorwaarden en de formele beoordelingsstatus; `sovon_bmp_plotjaar_taxon` bewaart positieve waarden, expliciete nullen en lege broncellen. Canonieke vogeltabellen worden pas na een afzonderlijk jaarbesluit verrijkt. Alle taxonregels blijven bereikbaar via `soorten`, `taxa_bronkoppeling`, `taxa` en `taxon_groepen`.

**Tech Stack:** MySQL 9.7.1, Python 3, openpyxl, bestaande `gis/scripts/import_ndff_protocolkwaliteit.py`, pytest/unittest, Markdown/DOCX-bronregister.

**Spec:** `docs/superpowers/specs/2026-10-02-sovon-bmp-jaarcontrole-design.md`

## Global Constraints

- De levende lokale database is canoniek; `Meijendel.sql` is alleen een afgeleide.
- SOVON-bronregels en VWG-jaarverslagregels blijven inhoudelijk en technisch onderscheiden.
- Een lege matrixcel is geen nul en formele afkeuring wordt nooit uit alleen een leegtepatroon afgeleid.
- Broedcode 0 blijft een positieve waarneming.
- De vijf nulvoorwaarden worden afzonderlijk opgeslagen; een nul wordt pas analyseerbaar wanneer alle vijf positief zijn.
- Alle nieuwe soortregels hebben een werkende centrale taxonroute; onbekende of strijdige identificatie blokkeert de jaarimport.
- Tracks en actuele SOVON-polygonen worden niet ingevoerd.
- Geen bestaande bronregel wordt verwijderd omdat hij in een jaarwerkboek ontbreekt.
- Geen VPS-publicatie zonder nieuw, expliciet akkoord.
- Werk eerst met falende tests, daarna minimale implementatie, daarna volledige regressie en herstelbewijs.

## Review Focus

- Onderscheid `expliciete_nul`, `leeg` en ontbrekende rij ook na export/import.
- Bewaar formeel afgekeurde positieve resultaten, maar sluit ze uit van gewone analyse en `territoria`.
- Een standaard AVIMAP-tellercode wijzigt `plot_jaar_teller` niet automatisch.
- Een jaarimport is herhaalbaar en maakt geen dubbele bronrijen.
- Nieuwe tabellen en afgeleide nulregels zijn volledig bereikbaar vanuit het centrale taxonregister.
- De bestaande 600.959 dagwaarnemingen en alle niet-SOVON-territoria blijven onaangetast bij aanleg van de ontvangststructuur.

---

### Task 1: Contracttests voor SOVON-BMP-ontvangst

**Files:**
- Modify: `gis/scripts/test_ndff_protocolkwaliteit.py`
- Modify: `gis/database/ndff_protocolkwaliteit_schema.sql`

**Interfaces:**
- Consumes: het bestaande schema-contract en centrale taxonroutes.
- Produces: falende tests voor tien `sovon_bmp_*`-tabellen, vijf nulvoorwaarden, formele afkeuring, puntwaarnemingen en centrale taxonkoppeling.

- [x] **Step 1: Voeg falende schemacontracttests toe**

Controleer minimaal:

```python
for table in (
    "sovon_bmp_jaarlevering",
    "sovon_bmp_soortenlijstversie",
    "sovon_bmp_soortenlijst_taxon",
    "sovon_bmp_plotjaar",
    "sovon_bmp_plotjaar_tellercode",
    "sovon_bmp_bezoek",
    "sovon_bmp_bezoek_taxon",
    "sovon_bmp_waarneming",
    "sovon_bmp_territoriumpunt",
    "sovon_bmp_plotjaar_taxon",
):
    assert f"create table if not exists meijendel.{table}" in schema
```

Test daarnaast CHECKs voor `expliciete_nul` met aantal 0, `leeg` met NULL,
positief met aantal boven 0, en de status `formeel_afgekeurd`.

- [x] **Step 2: Draai de gerichte test en bevestig de verwachte fout**

Run: `python3 -m pytest gis/scripts/test_ndff_protocolkwaliteit.py -q -k sovon_bmp`

Expected: FAIL omdat het nieuwe schema nog ontbreekt.

- [x] **Step 3: Commit alleen wanneer test en foutoorzaak controleerbaar zijn**

Geen commit van uitsluitend een rood tussenstadium; ga direct door naar Task 2.

### Task 2: Minimale ontvangststructuur en analyseviews

**Files:**
- Modify: `gis/database/ndff_protocolkwaliteit_schema.sql`
- Modify: `gis/scripts/import_ndff_protocolkwaliteit.py`
- Modify: `gis/scripts/test_ndff_protocolkwaliteit.py`

**Interfaces:**
- Consumes: centrale `soorten`- en `taxa_bronkoppeling`-routes.
- Produces: tien tabellen, `v_sovon_bmp_analyse` en `v_sovon_bmp_formeel_afgekeurd`.

- [x] **Step 1: Implementeer de tabellen met restrictieve foreign keys en CHECKs**

Gebruik een versieerbare jaarlevering; bewaar per plotjaar BMP-type,
soortenbereik, volledigheid, beoordeling en soortenlijstversie afzonderlijk.
Bewaar broncelstatus en bronwaarden zonder afleiding.

- [x] **Step 2: Implementeer analyseviews**

`v_sovon_bmp_analyse` laat alleen positief/expliciete nul toe wanneer het
plotjaar volledig, goedgekeurd en aan een toepasselijke officiële lijst
gekoppeld is. `v_sovon_bmp_formeel_afgekeurd` toont de verworpen bronregels en
reden, maar levert geen analyse-uitkomst.

- [x] **Step 3: Draai contract- en regressietests**

Run:

```bash
python3 -m pytest gis/scripts/test_ndff_protocolkwaliteit.py -q -k 'sovon_bmp or sovon_avimap'
python3 -m pytest gis/scripts/test_ndff_protocolkwaliteit.py -q
```

Expected: PASS; bestaande AVIMAP/DAZ-regels blijven ongewijzigd.

### Task 3: Parser en droge jaarvergelijking

**Files:**
- Modify: `gis/scripts/import_ndff_protocolkwaliteit.py`
- Modify: `gis/scripts/test_ndff_protocolkwaliteit.py`

**Interfaces:**
- Consumes: één jaarmap met standaardexports, territoriummatrix,
  bezoektotalen, bezoekstippen en territoriumpunten.
- Produces: genormaliseerde bronrijen en een deterministisch vergelijkingsrapport; standaard uitsluitend dry-run.

- [x] **Step 1: Schrijf tests met tijdelijke werkboeken**

Test positieve waarde, expliciete nul, lege cel, ontbrekende Excel-dimensie,
variabel aantal bezoeken, bezoekopmerking, broedcode 0 en meervoudige
tellercodes. Test dat een leegtepatroon niet automatisch
`formeel_afgekeurd` wordt.

- [x] **Step 2: Implementeer parsers**

Voeg afzonderlijke functies toe voor matrix, bezoektotalen, standaardbezoeken,
standaardresultaten, bezoekstippen en territoriumpunten. Gebruik Euring-code en
plot-ID als bronkeys; naam is alleen bronwaarde. Negeer tracks en
gebiedspolygonen.

- [x] **Step 3: Implementeer vergelijking met levende database**

Rapporteer per plotjaar:

- bronbezoeken en ontbrekende/bijkomende databasebezoeken;
- standaardpositieven versus matrixpositieven;
- expliciete nullen en lege cellen;
- verschillen in aantallen;
- reeds bekende formele afkeuring;
- tellercodes en relatie tot `plot_jaar_teller`;
- taxon- en referentiële-integriteitsfouten.

- [x] **Step 4: Draai parsertests en algemene dry-run**

Run: gerichte pytest plus een dry-run over 1984–2025. Expected: 42 jaren,
telkens 5.306 matrixregels, zonder dubbele plot-Euring-jaarsleutel.

### Task 4: Geïsoleerde schema- en herstelproef

**Files:**
- Modify: `gis/scripts/import_ndff_protocolkwaliteit.py`
- Modify: `docs/database/TAXONREGISTER.md`

**Interfaces:**
- Consumes: nieuwe schemafamilie en bestaande volledige taxonaudit.
- Produces: bewijs dat aanleg en rollback geen bestaande vogel- of taxonrij wijzigt.

- [x] **Step 1: Maak een verse lokale back-up buiten Git en iCloud**

Leg hash, MySQL-versie, schema-aantallen en kernrijtellingen vast.

- [x] **Step 2: Test het schema eerst in een afzonderlijke database**

Controleer tabellen, views, constraints, ongeldige nul-/leegproeven en volledige
ROLLBACK. Vergelijk bestaande kernrijtellingen en centrale taxonroutes voor en
na de proef.

- [x] **Step 3: Bewijs volledig herstel uit dezelfde back-up**

Een schemawijziging gaat niet naar de levende database zonder geslaagde
herstelproef.

### Task 5: Ontvangststructuur in de levende lokale database

**Files:**
- Modify: `gis/database/ndff_protocolkwaliteit_schema.sql`
- Modify: `docs/database/TAXONREGISTER.md`
- Modify: `DECISIONS.md`

**Interfaces:**
- Consumes: exact geteste schemahash en ongewijzigde levende bronstand.
- Produces: lege, gebruiksklare `sovon_bmp_*`-structuur; nog geen canonieke jaarcorrecties.

- [ ] **Step 1: Herhaal preflight en bronstandcontrole**
- [ ] **Step 2: Pas exact het bewezen schema transactioneel toe**
- [ ] **Step 3: Controleer databasebreed centrale taxonbereikbaarheid**
- [ ] **Step 4: Controleer dat bestaande vogelrijen, sommen en bronnen gelijk zijn**

Expected: alleen nieuwe lege tabellen/views; `dagbezoeken_bmp`,
`dagwaarnemingen_bmp`, `territoria`, `plot_jaar_teller` en niet-SOVON-bronnen
zijn inhoudelijk onveranderd.

### Task 6: Eerste jaarcontrole 1984

**Files:**
- Modify: `gis/scripts/import_ndff_protocolkwaliteit.py`
- Modify: `docs/MEIJENDEL_BRONREGISTER.md`
- Modify: `docs/MEIJENDEL_BRONREGISTER.docx`

**Interfaces:**
- Consumes: de vier SOVON-werkboeken in jaarmap 1984 en de levende database.
- Produces: bronimport 1984 in `sovon_bmp_*`, verschilrapport en afzonderlijk voorstel voor canonieke verrijking.

- [ ] **Step 1: Importeer alleen de bronlaag voor 1984**

Bewaar 5.306 matrixregels, zestien plotsecties en 230 bezoeken. Wijs geen lege
cel als nul aan. Neem de plot met bezoeken maar uitsluitend lege matrixcellen
op als `te_beoordelen`, niet automatisch als afgekeurd.

- [ ] **Step 2: Beoordeel de vijf nulvoorwaarden per plotjaar**

Koppel de toepasselijke officiële BMP-soortenlijst. Iedere nog ontbrekende
voorwaarde houdt de nul buiten de analyseview.

- [ ] **Step 3: Presenteer het 1984-verschilbesluit vóór canonieke wijziging**

Noem concrete aantallen, plots, soorten en gevolgen. Splits toevoegen,
corrigeren, behouden en formeel uitsluiten. Wacht met wijziging van
`territoria` of andere canonieke tabellen tot het jaarbesluit inhoudelijk is
bevestigd.

### Task 7: Documentatie, verificatie en versiebeheer

**Files:**
- Modify: `README.md`
- Modify: `ARCHITECTURE.md`
- Modify: `DECISIONS.md`
- Modify: `TODO.md`
- Modify: `docs/database/TAXONREGISTER.md`
- Modify: `docs/MEIJENDEL_BRONREGISTER.md`
- Modify: `docs/MEIJENDEL_BRONREGISTER.docx`

- [ ] **Step 1: Werk besluit-, architectuur- en brondocumentatie bij**
- [ ] **Step 2: Render en controleer de Wordversie visueel**
- [ ] **Step 3: Draai volledige relevante tests en workspace-preflight**
- [ ] **Step 4: Controleer werkbomen en upstreams in alle drie repositories**
- [ ] **Step 5: Commit en push afgeronde wijzigingen**

Geen dumpgeneratie, cachevernieuwing of VPS-publicatie in deze fase.
