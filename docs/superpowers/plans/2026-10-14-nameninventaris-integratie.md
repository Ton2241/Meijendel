# Meijendel-nameninventaris Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Voeg de gecontroleerde levering `meijendel_nameninventaris_2026-10-14` als bronvast, idempotent namen- en geometrieënregister toe aan de levende lokale database `Meijendel`.

**Architecture:** Eén importbatch verbindt acht bronsnapshots met 182 stabiele naamobjecten, 299 letterlijke vermeldingen, 71 geometrieën en 111 actuele beoordelingen van ontbrekende geometrie. Een afzonderlijke koppeltabel bewaart de 47 TOP10NL-feature-ID's en 60 OSM-way-ID's zonder lijstvelden. De import valideert en normaliseert de levering vóór iedere schrijfactie, wordt eerst in een wegwerpdatabase bewezen en raakt geen bestaande plot-, grens-, taxon-, waarnemings- of webtabellen.

**Tech Stack:** MySQL 9.7.1, Python 3 standaardbibliotheek, GDAL/OGR uit Postgres.app, bestaande MySQL-login-path `meijendel_root`, Markdown/DOCX-bronregister.

**Spec:** `docs/superpowers/specs/2026-10-14-nameninventaris-integratie-design.md`

## Global Constraints

- De levende lokale database `Meijendel` is de canonieke schrijfbron.
- Accepteer alleen de levering met de vastgelegde SHA-256-checksums en de aantallen 182 objecten, 299 vermeldingen, 8 bronnen, 71 geometrieën en 111 objecten zonder geometrie.
- Bewaar absolute T7-paden niet in database, code of documentatie; gebruik Zotero-item-keys of logische bronverwijzingen.
- Geef Bunkerpad, Klippad en de overige 109 objecten zonder brongeometrie geen afgeleide geometrie.
- Maak geen automatische naamkoppeling naar `plot_gebied`, `meijendel_basisgebied`, `meijendel_natura2000` of andere bestaande objecttabellen.
- De nieuwe laag bevat geen taxa of waarnemingen. Voer na wijziging toch de bestaande databasebrede taxoncontrole uit en bewijs dat centrale taxonroutes ongewijzigd blijven.
- Maak vlak vóór de levende import een terugleesbare, gehashte back-up van de betrokken databaseobjecten; gebruik geen oudere algemene dump als herstelbasis.
- Genereer niet automatisch `Meijendel.sql`, bouw geen Shiny-cache en publiceer niets naar de VPS.
- Werk met falende tests, minimale implementatie, geïsoleerde databaseproef, herstelbewijs en pas daarna live uitvoering.

## Review Focus

- Zijn bewijsstatus, officiële status en naamgebruik strikt van elkaar onderscheiden?
- Blijven letterlijke perioden, namen en bron-ID's bewaard naast getypeerde velden?
- Zijn samengestelde bronvelden volledig genormaliseerd en controleerbaar terug te voeren?
- Is een tweede import aantoonbaar een no-op op aantallen én inhoud?
- Kan de import vóór de eerste databasewrite volledig blokkeren op bestand-, checksum-, geometrie- of referentiële fouten?
- Blijven alle bestaande databaseobjecten buiten `nameninventaris_*` inhoudelijk ongewijzigd?

---

### Task 1: Rode contracttests voor levering en normalisatie

**Files:**
- Create: `gis/scripts/test_import_nameninventaris.py`
- Create: `gis/scripts/import_nameninventaris.py`

**Interfaces:**
- Consumes: de acht geleverde bestanden onder een expliciet opgegeven leveringsmap.
- Produces: een gevalideerd Python-importplan; standaard geen databasewrite.

- [x] **Step 1: Leg fixtures en verwachte transformaties in tests vast**

Test met tijdelijke CSV/GeoJSON-fixtures minimaal:

```python
assert plan.counts == {
    "bronnen": 8,
    "objecten": 182,
    "vermeldingen": 299,
    "geometrieen": 71,
    "ontbrekende_geometrie": 111,
    "top10nl_ids": 47,
    "osm_ids": 60,
}
assert plan.objects["OBJ-FB0E7E2F03"].voorkeursnaam == "Blankenburgh"
assert plan.objects["OBJ-FB0E7E2F03"].bronobjecttype == "Buitenplaats"
assert plan.objects["OBJ-AC70DD4C7A"].voorkeursnaam == "Voorlinden"
assert plan.objects["OBJ-AC70DD4C7A"].bronobjecttype == "Buitenplaats"
```

Controleer ook jaar, jaarbereik, decennium, letterlijke periode, onbekende nauwkeurigheid, gesplitste broncodes en gesplitste TOP10NL-/OSM-ID's.

- [x] **Step 2: Voeg blokkerende negatieve tests toe**

Laat validatie falen bij gewijzigde checksum, ontbrekende header, dubbele object-ID, verweesde vermelding, onbekende status, ongeldige periode, lege geometrie, verkeerde SRID, ongeldige geometrie en een niet-bestaand bronfeature-ID.

- [x] **Step 3: Draai de test en bevestig de verwachte fout**

Run:

```bash
python3 gis/scripts/test_import_nameninventaris.py
```

Expected: FAIL omdat de importerfuncties nog ontbreken. Commit geen uitsluitend rode tussenstand.

### Task 2: Validator en deterministisch importplan

**Files:**
- Modify: `gis/scripts/import_nameninventaris.py`
- Modify: `gis/scripts/test_import_nameninventaris.py`

**Interfaces:**
- Consumes: `README.md`, GeoJSON, RD-CSV, vermeldingen-CSV, bronregister, bronlacunes en het manifest/checksumbewijs uit de levering.
- Produces: genormaliseerde records met stabiele sleutels en een samenvattend validatierapport.

- [x] **Step 1: Implementeer bestands- en checksumvalidatie**

Gebruik `pathlib`, `csv`, `json` en `hashlib`. Vereis de verwachte bestandsnamen, kolommen, hashes en recordaantallen voordat SQL kan worden opgebouwd.

- [x] **Step 2: Implementeer expliciete normalisatiefuncties**

Maak kleine functies voor:

```python
normalize_object_name(...)
normalize_evidence_status(...)
parse_period(...)
parse_precision(...)
split_source_codes(...)
split_native_feature_ids(...)
```

Beperk correcties tot de acht regels uit het goedgekeurde ontwerp. Bewaar iedere letterlijke bronwaarde naast de afleiding.

- [x] **Step 3: Valideer geometrieën en bronobjecten met OGR**

Lees WKT in EPSG:28992, eis niet-leeg en geldig, vergelijk de 71 RD-geometrieën met de GeoJSON-geometrieën na transformatie en controleer alle 47 TOP10NL- en 60 OSM-ID's tegen de meegeleverde/lokale bronbestanden.

- [x] **Step 4: Maak de CLI standaard read-only**

Ondersteun minimaal:

```text
--delivery PATH
--validate
--database NAME
--login-path NAME
--mysql-client PATH
--apply
--audit-live
```

Zonder `--apply` mag geen schrijvende MySQL-opdracht worden uitgevoerd.

- [x] **Step 5: Draai de gerichte tests**

Run:

```bash
PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH" \
  python3 gis/scripts/test_import_nameninventaris.py
```

Expected: PASS met exact de afgesproken aantallen en normalisaties.

### Task 3: Schema en schemacontract

**Files:**
- Create: `gis/database/nameninventaris_schema.sql`
- Modify: `gis/scripts/test_import_nameninventaris.py`

**Interfaces:**
- Consumes: het genormaliseerde importplan.
- Produces: zeven `nameninventaris_*`-tabellen met restrictieve sleutels, constraints en ruimtelijke index.

- [x] **Step 1: Voeg eerst falende schema-asserties toe**

Controleer alle tabellen en kerneigenschappen:

```python
for table in (
    "nameninventaris_import",
    "nameninventaris_bron",
    "nameninventaris_object",
    "nameninventaris_vermelding",
    "nameninventaris_geometrie",
    "nameninventaris_geometrie_bronobject",
    "nameninventaris_beoordeling",
):
    assert f"create table if not exists {table}" in schema
```

Eis foreign keys, unieke importsleutel, `GEOMETRY NOT NULL SRID 28992`, spatial index, drie bewijsstatussen, datumprecisie, nauwkeurigheidsstatus en regelversie.

- [x] **Step 2: Draai de test en bevestig dat alleen het schema ontbreekt**

Run: `python3 gis/scripts/test_import_nameninventaris.py`

Expected: FAIL op de nieuwe schema-asserties.

- [x] **Step 3: Implementeer het minimale schema**

Gebruik InnoDB, `utf8mb4_0900_ai_ci`, betekenisvolle unieke sleutels en expliciete CHECKs. Sla ontbrekende geometrie uitsluitend op als beoordeling zonder rij in `nameninventaris_geometrie`.

- [x] **Step 4: Draai alle gerichte tests opnieuw**

Expected: PASS.

### Task 4: Transactionele, idempotente importer en audit

**Files:**
- Modify: `gis/scripts/import_nameninventaris.py`
- Modify: `gis/scripts/test_import_nameninventaris.py`

**Interfaces:**
- Consumes: gevalideerd importplan en `nameninventaris_schema.sql`.
- Produces: één transactionele import en een read-only auditrapport.

- [ ] **Step 1: Test SQL-opbouw vóór implementatie**

Assert dat SQL pas na volledige validatie ontstaat, `START TRANSACTION`/`COMMIT` bevat, foreign-keyvolgorde respecteert en geen absoluut bronpad bevat. Simuleer een validatiefout en bewijs dat de MySQL-runner nul keer is aangeroepen.

- [ ] **Step 2: Implementeer geparametriseerde SQL-opbouw**

Schrijf schema en data via de lokale MySQL-client. Koppel iedere rij aan de importsleutel en gebruik unieke natuurlijke/importsleutels zodat een gelijke levering geen duplicaten maakt. Verander een reeds geïmporteerde batch niet stilzwijgend wanneer de inhoudshash verschilt.

- [ ] **Step 3: Implementeer `--audit-live`**

Rapporteer minimaal aantallen, dubbele sleutels, verweesde foreign keys, bewijsstatussen, periodetypen, geometrievaliditeit/SRID, bronfeaturedekking, Bunkerpad/Klippad zonder geometrie en batchhash.

- [ ] **Step 4: Test een tweede identieke import als no-op**

Vergelijk vóór en na de tweede run rijtellingen en een deterministische inhoudshash per nieuwe tabel.

- [ ] **Step 5: Draai de tests**

Run: `python3 gis/scripts/test_import_nameninventaris.py`

Expected: PASS.

### Task 5: Geïsoleerde databaseproef en herstelbewijs

**Files:**
- Modify: `gis/scripts/test_import_nameninventaris.py`
- Modify: `gis/scripts/import_nameninventaris.py`

**Interfaces:**
- Consumes: exact de te importeren levering en het nieuwe schema.
- Produces: bewijs van constraints, aantallen, idempotentie en herstel vóór live wijziging.

- [ ] **Step 1: Herhaal repository- en databasepreflight**

Run vanuit de taakworktree:

```bash
/Users/ton/Documents/GitHub/VWG_Project/scripts/workspace_preflight.sh
scripts/check_local_workspace.sh
/usr/local/mysql/bin/mysql --login-path=meijendel_root --protocol=TCP \
  --batch --skip-column-names -e "SELECT VERSION(), @@GLOBAL.innodb_redo_log_capacity"
```

Expected: branches/upstreams geldig, werkboom alleen met taakwijzigingen, MySQL 9.7.1 en redo-capaciteit 536870912 bytes.

- [ ] **Step 2: Maak en vul een expliciete wegwerpdatabase**

Maak `Meijendel_nameninventaris_test`, pas het schema toe en importeer dezelfde levering. Gebruik nooit de levende databasenaam in deze proef.

- [ ] **Step 3: Bewijs constraints en acceptatieaantallen**

Expected:

```text
bronnen=8
objecten=182
vermeldingen=299
geometrieen=71
beoordelingen_zonder_geometrie=111
top10nl_bronobjecten=47
osm_bronobjecten=60
ongeldige_geometrie=0
verweesde_koppelingen=0
```

Voer daarnaast negatieve INSERT-proeven uit voor ongeldige SRID, ontbrekende foreign key en dubbele importsleutel.

- [ ] **Step 4: Bewijs idempotentie in de testdatabase**

Importeer dezelfde levering opnieuw en vergelijk rijtellingen plus inhoudshashes. Expected: geen verschil.

- [ ] **Step 5: Maak een testback-up en bewijs herstel**

Dump uitsluitend de zeven nieuwe tabellen plus hun schema naar een tijdelijke lokale map buiten Git en iCloud, leg SHA-256 vast, verwijder de testdatabase, herstel naar een tweede wegwerpdatabase en herhaal de audit.

- [ ] **Step 6: Verwijder alleen de twee expliciete wegwerpdatabases**

Controleer namen vóór `DROP DATABASE`. Bewaar het gehashte proefbewijs tot afronding van de levende import.

### Task 6: Levende lokale import

**Files:**
- Modify: `gis/scripts/import_nameninventaris.py`

**Interfaces:**
- Consumes: exact het geteste schema, dezelfde leveringshash en een vlak vóór uitvoering gemaakte back-up.
- Produces: gevalideerde `nameninventaris_*`-tabellen in de levende lokale database `Meijendel`.

- [ ] **Step 1: Leg de levende nulmeting vast**

Bewaar schema-aantallen, tabelaantallen en deterministische checksums van geselecteerde bestaande referentietabellen en taxonroutes. Controleer expliciet dat nog geen afwijkende `nameninventaris_*`-objecten bestaan.

- [ ] **Step 2: Maak de live herstelback-up**

Maak vlak vóór de import een logisch dumpbestand in een lokale tijdelijke map buiten Git en iCloud. Omdat de zeven tabellen nieuw zijn, bevat het herstelpakket minimaal hun eventuele voorstand/schema plus een manifest van de levende nulmeting, MySQL-versie, codecommit, leveringshash en dumphash.

- [ ] **Step 3: Voer exact de bewezen import uit**

Run:

```bash
PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH" \
  python3 gis/scripts/import_nameninventaris.py \
  --delivery /Users/ton/Documents/Codex/2026-10-14/referenced-chatgpt-conversation-this-is-an/outputs/meijendel_nameninventaris_2026-10-14 \
  --database Meijendel \
  --login-path meijendel_root \
  --mysql-client /usr/local/mysql/bin/mysql \
  --apply
```

- [ ] **Step 4: Audit de levende import en herhaal idempotent**

Run `--audit-live`, voer daarna dezelfde `--apply` nog eenmaal uit en controleer opnieuw. Expected: exact 8/182/299/71/111 en 47/60 bronobject-ID's; tweede run verandert niets.

- [ ] **Step 5: Bewijs dat bestaande inhoud ongewijzigd bleef**

Vergelijk de nulmeting met de eindmeting voor alle gekozen bestaande tabellen en centrale taxonroutes. Voer bovendien uit:

```bash
python3 gis/scripts/test_taxonregister_live_schema.py
```

Expected: PASS; alle soortwaarnemingen blijven via `taxa`, `taxa_bronkoppeling` en `taxon_groepen` bereikbaar.

- [ ] **Step 6: Stop en herstel bij iedere afwijking**

Gebruik uitsluitend de zojuist gemaakte gehashte back-up en bijbehorende codeversie. Ga niet door naar documentatie of versiebeheer zolang audit of referentiechecks afwijken.

### Task 7: Bronregister, DOCX en inhoudelijke gelijkheid

**Files:**
- Modify: `docs/MEIJENDEL_BRONREGISTER.md`
- Modify: `docs/MEIJENDEL_BRONREGISTER.docx`

**Interfaces:**
- Consumes: de bewezen levende database-eindstand.
- Produces: gelijkluidende registratie van levering, omvang, periode, locatiekwaliteit, rechten, overlap, validatiestatus en analytische bruikbaarheid.

- [ ] **Step 1: Werk het Markdown-register bij met de feitelijke importstatus**

Noem concreet: 182 naamobjecten, 299 vermeldingen uit 1602-2026, 8 bronnen, 71 geometrieën en 111 expliciete lacunes; vermeld 47 TOP10NL-features, 60 OSM-segmenten/25 namen en het ontbreken van geometrie voor Bunkerpad en Klippad. Leg vast dat dit een namen-/locatieregister is en geen ecologische waarnemingslaag.

- [ ] **Step 2: Neem de gebruikerswijzigingen zorgvuldig over**

Vergelijk de reeds lokaal gewijzigde registerbestanden in de canonieke checkout met de taakbranch. Neem alleen de inhoud over die bij deze levering hoort; overschrijf geen niet-door-ons gemaakte tekst of opmaak.

- [ ] **Step 3: Werk de DOCX inhoudelijk gelijk bij**

Behoud bestaande stijlen, paginering en tabellen. De Markdown-versie blijft leidend.

- [ ] **Step 4: Render en controleer alle pagina's**

Run:

```bash
scripts/render_docx_local.sh docs/MEIJENDEL_BRONREGISTER.docx \
  --output_dir /tmp/meijendel-bronregister-render
```

Expected: succesvolle render van het volledige document. Controleer de gewijzigde pagina's op tekst, tabellen, afbrekingen en overloop, en controleer het totale pagina-aantal.

- [ ] **Step 5: Controleer MD/DOCX-inhoudelijke gelijkheid**

Vergelijk standdatum, aantallen, status, rechten, ruimtelijke dekking en bronlacunes expliciet.

### Task 8: Volledige verificatie, review en versiebeheer

**Files:**
- Modify: `docs/superpowers/plans/2026-10-14-nameninventaris-integratie.md`

**Interfaces:**
- Consumes: code, schema, levende database-audit en beide bronregisters.
- Produces: gereviewde, gecommitte en gepushte taakbranch zonder publicatie.

- [ ] **Step 1: Draai alle gerichte en repositorycontroles**

```bash
python3 gis/scripts/test_import_nameninventaris.py
python3 gis/scripts/test_taxonregister_live_schema.py
scripts/check_local_workspace.sh
/Users/ton/Documents/GitHub/VWG_Project/scripts/workspace_preflight.sh
```

Expected: alle controles PASS.

- [ ] **Step 2: Herhaal de levende read-only audit**

Leg de exacte eindstanden en nulbevindingen vast. Controleer dat geen dashboard-, Shiny-, website- of VPS-afnemer is gewijzigd en dat daarom geen publicatie nodig is.

- [ ] **Step 3: Review de diff tegen ontwerp en plan**

Controleer scope, absolute paden, geheimen, herstelbaarheid, idempotentie, documentgelijkheid en onbedoelde wijzigingen. Vraag een code-review vóór integratie.

- [ ] **Step 4: Commit en push de afgeronde wijziging**

```bash
git add gis/database/nameninventaris_schema.sql \
  gis/scripts/import_nameninventaris.py \
  gis/scripts/test_import_nameninventaris.py \
  docs/MEIJENDEL_BRONREGISTER.md \
  docs/MEIJENDEL_BRONREGISTER.docx \
  docs/superpowers/plans/2026-10-14-nameninventaris-integratie.md
git commit -m "Importeer Meijendel-nameninventaris"
git push
```

- [ ] **Step 5: Rond repositorycontrole af**

Bevestig `branch == upstream`, een schone taakworktree en ongewijzigde schone toestand van `VWG_Project` en `VWG_M`. Behandel de twee vooraf bestaande registerwijzigingen in de canonieke Meijendel-checkout als gebruikerswerk; verwijder of overschrijf ze niet.

- [ ] **Step 6: Rapporteer en vraag afzonderlijk naar de zware afgeleiden**

Rapporteer live databaseaantallen, tests, back-up/hash, bronregisterrender en Git-commit. Vraag Ton daarna expliciet of ook `Meijendel.sql`-export, proefimport en Shiny-cachebouw gewenst zijn. Start die keten niet zonder afzonderlijk akkoord.
