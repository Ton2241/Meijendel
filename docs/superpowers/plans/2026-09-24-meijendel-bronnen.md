# Meijendel_bronnen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Maak `Meijendel` strikt analytisch, verplaats niet-geolokaliseerbare Meijendelgegevens naar de afzonderlijke database `Meijendel_bronnen`, voeg het Meijendel-literatuuroverzicht uit Zotero toe en ontsluit de broncatalogus in het afgeschermde Analysecentrum.

**Architecture:** `Meijendel` en `Meijendel_bronnen` staan als afzonderlijke databases in dezelfde MySQL 9.7.1-instance, met gescheiden dumps en rechten. De website leest uitsluitend vastgelegde read-only views uit `Meijendel_bronnen`; Shiny en de statistische keten blijven uitsluitend `Meijendel` gebruiken. Zotero wordt lokaal eenrichtings gesynchroniseerd en levert alleen bibliografische metadata en Chicago-verwijzingen, geen bestanden of lokale paden.

**Tech Stack:** MySQL 9.7.1, Python 3, PyMySQL, FastAPI, Jinja2, PostgreSQL, pytest, shellscripts, Zotero Local API.

**Spec:** `docs/superpowers/specs/2026-09-24-meijendel-bronnen-design.md`

## Global Constraints

- De levende lokale MySQL-database is canoniek; dumps zijn gecontroleerde afgeleiden.
- Server, `mysql`, `mysqldump` en productiecontainer gebruiken exact MySQL 9.7.1.
- `Meijendel` bevat alleen waarnemingsfeiten waarvan de Meijendel-locatie per record beschikbaar of betrouwbaar herleidbaar is.
- `Meijendel_bronnen.sql` wordt nooit via `/Meijendel.sql`, `/meijendel.sql` of een andere publieke route aangeboden.
- Zotero-bijlagen, volledige teksten en absolute lokale paden komen niet in MySQL of op de VPS.
- De website gebruikt voor `Meijendel_bronnen` uitsluitend `SELECT` op goedgekeurde views.
- Bestaande literatuurdocumenten worden pas uit het ledenarchief verwijderd nadat ieder document aan een Zotero-item is gekoppeld.
- Geen bronfamilie wordt uit `Meijendel` verwijderd voordat aantallen, relaties, hashes en een hersteltest van `Meijendel_bronnen` slagen.
- De ruwe beveiligde NDFF-geometrieën blijven uitsluitend in `Meijendel_ndff_secure` en vallen buiten deze migratie.
- Productiedeploys gebeuren uitsluitend vanaf schone, actuele `main`-branches volgens preflight, tests, back-up, kandidaatvalidatie, deploy, smoketest en releaseregistratie.

## Review Focus

- Een gedeeltelijk mislukte migratie mag geen bronfamilie uit `Meijendel` verwijderen; de migratietest simuleert een fout vóór de deletefase.
- Een Zotero-item zonder auteur, jaar, DOI of URL moet wel veilig en leesbaar in de catalogus verschijnen; de Zotero-importtest bevat zo'n minimaal item.
- Een niet-ingelogde of verlopen externe gebruiker mag `/analysecentrum/bronnen` niet openen; de routetest controleert redirect en toegangsweigering.
- Een oud literatuurdocument zonder bevestigde Zotero-koppeling mag niet worden verwijderd; de opschoontest controleert een gemengde, onvolledige mapping.
- `Meijendel_bronnen.sql` mag niet via Caddy, webroot of een openbare symlink uitlekken; deploy- en smoketests controleren expliciet 404/403 en afwezige symlinks.

---

### Task 1: Schema en contract van Meijendel_bronnen

**Files:**
- Create: `gis/database/meijendel_bronnen_schema.sql`
- Create: `gis/scripts/test_meijendel_bronnen_schema_contract.py`

**Interfaces:**
- Consumes: MySQL 9.7.1 en de tabelnamen uit `gis/database/duinvallei_vegetatie_schema.sql`.
- Produces: database `Meijendel_bronnen`; tabellen `bron`, `bron_bestand`, `literatuur`, `literatuur_auteur`, `jachtspin_locatie`, `jachtspin_soort`, `jachtspin_vangst`, de volledige `duinvallei_*`-familie en views `v_bron_catalogus`, `v_literatuur_overzicht`, `v_contextdataset_overzicht`.

- [ ] **Step 1: Schrijf de falende contracttest**

```python
from pathlib import Path

SCHEMA = Path(__file__).parents[1] / "database" / "meijendel_bronnen_schema.sql"

def test_schema_separates_catalog_literature_and_context_data():
    sql = SCHEMA.read_text(encoding="utf-8").casefold()
    for fragment in (
        "create database if not exists meijendel_bronnen",
        "create table if not exists bron",
        "create table if not exists bron_bestand",
        "create table if not exists literatuur",
        "create table if not exists literatuur_auteur",
        "create table if not exists jachtspin_locatie",
        "create table if not exists jachtspin_soort",
        "create table if not exists jachtspin_vangst",
        "create or replace view v_bron_catalogus",
        "create or replace view v_literatuur_overzicht",
        "create or replace view v_contextdataset_overzicht",
    ):
        assert fragment in sql

def test_schema_cannot_store_local_paths_or_binary_attachments():
    sql = SCHEMA.read_text(encoding="utf-8").casefold()
    assert "absolute_pad" not in sql
    assert "longblob" not in sql
    assert "mediumblob" not in sql
```

- [ ] **Step 2: Controleer dat de test faalt**

Run: `python3 -m pytest gis/scripts/test_meijendel_bronnen_schema_contract.py -q`  
Expected: FAIL omdat `meijendel_bronnen_schema.sql` nog niet bestaat.

- [ ] **Step 3: Maak het minimale schema**

Gebruik deze kernkolommen en vaste waarden:

```sql
CREATE DATABASE IF NOT EXISTS Meijendel_bronnen CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE Meijendel_bronnen;

CREATE TABLE bron (
  bron_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bron_sleutel VARCHAR(128) NOT NULL,
  bron_type ENUM('dataset','literatuur','kandidaatbron') NOT NULL,
  titel VARCHAR(1000) NOT NULL,
  omschrijving TEXT NULL,
  bronorganisatie VARCHAR(500) NULL,
  jaar_van SMALLINT UNSIGNED NULL,
  jaar_tot SMALLINT UNSIGNED NULL,
  soortgroep VARCHAR(255) NULL,
  geografische_status ENUM('niet_geolokaliseerd','gedeeltelijk_geolokaliseerd','nvt') NOT NULL,
  geografische_toelichting TEXT NOT NULL,
  analyse_status ENUM('context_alleen','kandidaat','gepromoveerd') NOT NULL,
  rechten_status ENUM('intern','geregistreerde_onderzoekers','open_metadata') NOT NULL,
  regelversie VARCHAR(64) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (bron_id),
  UNIQUE KEY uq_bron_sleutel (bron_sleutel)
) ENGINE=InnoDB;
```

Voeg `bron_bestand` toe met `bestand_naam`, `bestandstype`, `opslagklasse`, `recordaantal` en `sha256`; voeg geen absoluut pad of bestandsinhoud toe. Modelleer `literatuur` één-op-één met `bron`, en auteurs geordend in `literatuur_auteur(bron_id, volgnummer, familienaam, voornamen, naam_letterlijk)`.

- [ ] **Step 4: Voer contract- en syntaxcontrole uit**

Run:

```bash
python3 -m pytest gis/scripts/test_meijendel_bronnen_schema_contract.py -q
mysql --login-path=meijendel_root -e "DROP DATABASE IF EXISTS Meijendel_bronnen_test; CREATE DATABASE Meijendel_bronnen_test;"
sed 's/Meijendel_bronnen/Meijendel_bronnen_test/g' gis/database/meijendel_bronnen_schema.sql | mysql --login-path=meijendel_root
mysql --login-path=meijendel_root -NBe "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='Meijendel_bronnen_test';"
mysql --login-path=meijendel_root -e "DROP DATABASE Meijendel_bronnen_test;"
```

Expected: pytest PASS; schema laadt zonder fout; tijdelijke database wordt weer verwijderd.

- [ ] **Step 5: Commit**

```bash
git add gis/database/meijendel_bronnen_schema.sql gis/scripts/test_meijendel_bronnen_schema_contract.py
git commit -m "Voeg schema voor Meijendel_bronnen toe"
```

### Task 2: Reproduceerbare audit van niet-geolokaliseerbare waarnemingsfeiten

**Files:**
- Create: `gis/scripts/audit_meijendel_bronnen_candidates.py`
- Create: `gis/scripts/test_audit_meijendel_bronnen_candidates.py`
- Create: `docs/MEIJENDEL_BRONNEN_AUDIT.md`

**Interfaces:**
- Consumes: `information_schema`, `Meijendel.meijendel_waarneming_ruimtelijke_status`, regelversie `meijendel-ruimtelijke-poort-v3`.
- Produces: CSV met `bron_tabel`, `recordaantal`, `jaar_van`, `jaar_tot`, `locatiemethode`, `ruimtelijke_status`, `migratieadvies`; exitcode 1 wanneer een bekende bronfamilie ontbreekt.

- [ ] **Step 1: Schrijf tests voor bekende kandidaten en onbekende status**

```python
def test_classify_known_context_sources():
    rows = classify_rows([
        {"bron_tabel": "duinvallei_opname", "recordaantal": 488, "ruimtelijke_status": "geen_lokalisatie"},
        {"bron_tabel": "vogelstand_1924", "recordaantal": 204, "ruimtelijke_status": "context_alleen"},
    ])
    assert [row["migratieadvies"] for row in rows] == ["verplaatsen", "verplaatsen"]

def test_unknown_source_is_blocked_for_manual_decision():
    rows = classify_rows([
        {"bron_tabel": "onbekende_tabel", "recordaantal": 2, "ruimtelijke_status": "geen_lokalisatie"}
    ])
    assert rows[0]["migratieadvies"] == "afzonderlijk_besluit_nodig"
```

- [ ] **Step 2: Controleer dat de tests falen**

Run: `python3 -m pytest gis/scripts/test_audit_meijendel_bronnen_candidates.py -q`  
Expected: FAIL omdat script en functies ontbreken.

- [ ] **Step 3: Implementeer audit en machineleesbare uitvoer**

Maak functies `fetch_spatial_status(mysql_login_path: str, database: str) -> list[dict]`, `classify_rows(rows: list[dict]) -> list[dict]` en `write_csv(rows, output_path)`. Neem alleen waarnemingsfeiten op; dimensie- en referentietabellen worden met `nvt_referentietabel` gemarkeerd.

- [ ] **Step 4: Draai unit- en live-audit**

Run:

```bash
python3 -m pytest gis/scripts/test_audit_meijendel_bronnen_candidates.py -q
python3 gis/scripts/audit_meijendel_bronnen_candidates.py \
  --mysql-login-path meijendel_root \
  --database Meijendel \
  --output /tmp/meijendel_bronnen_audit.csv
```

Expected: tests PASS; CSV noemt ten minste `duinvallei_opname` met 488 records en `vogelstand_1924` met 204 records. Iedere extra kandidaat wordt vóór migratie expliciet aan de gebruiker voorgelegd.

- [ ] **Step 5: Documenteer de vastgestelde audituitkomst en commit**

```bash
git add gis/scripts/audit_meijendel_bronnen_candidates.py \
  gis/scripts/test_audit_meijendel_bronnen_candidates.py docs/MEIJENDEL_BRONNEN_AUDIT.md
git commit -m "Audit niet-geolokaliseerbare Meijendelbronnen"
```

### Task 3: Transactionele migratie van bronfamilies en jachtspinmatrix

**Files:**
- Create: `gis/scripts/migrate_meijendel_bronnen.py`
- Create: `gis/scripts/test_migrate_meijendel_bronnen.py`
- Modify: `gis/database/duinvallei_vegetatie_schema.sql`
- Modify: `gis/scripts/import_duinvallei_vegetatie.py`
- Modify: `gis/scripts/test_import_duinvallei_vegetatie.py`
- Modify: `kandidaatbronnen/jachtspinnen_1969_1970/README.md`

**Interfaces:**
- Consumes: audit-CSV uit Task 2, schema uit Task 1, `Meijendel.duinvallei_*`, `Meijendel.vogelstand_1924`, `kandidaatbronnen/jachtspinnen_1969_1970/jachtspinnen_28_locaties.csv`.
- Produces: volledige bronfamilies in `Meijendel_bronnen`; JSON-migratiemanifest met bron/doelaantallen en SHA-256; alleen `--finalize --yes` verwijdert goedgekeurde tabellen uit `Meijendel`.

- [ ] **Step 1: Schrijf tests voor kopiëren, blokkeren en rollback**

```python
def test_finalize_requires_matching_counts_and_restore_check():
    state = MigrationState(counts_match=True, foreign_keys_ok=True, restore_ok=False)
    assert may_finalize(state) is False

def test_finalize_accepts_only_complete_validation():
    state = MigrationState(counts_match=True, foreign_keys_ok=True, restore_ok=True)
    assert may_finalize(state) is True

def test_failure_before_finalize_never_emits_drop_statements():
    sql = build_finalize_sql(validated=False)
    assert "drop table" not in sql.casefold()
```

- [ ] **Step 2: Controleer dat de tests falen**

Run: `python3 -m pytest gis/scripts/test_migrate_meijendel_bronnen.py -q`  
Expected: FAIL omdat migratiescript en dataclasses ontbreken.

- [ ] **Step 3: Implementeer de migratie in twee onomkeerbaar gescheiden fasen**

`--copy` maakt schema en kopieert data met expliciete kolomlijsten. `--validate` controleert tabellen, views, foreign keys, aantallen en deterministische rijhashes. `--finalize --yes --manifest <pad>` accepteert uitsluitend een manifest met `counts_match=true`, `foreign_keys_ok=true` en `restore_ok=true`, en verwijdert daarna de bronfamilie uit `Meijendel`.

Gebruik voor de jachtspinmatrix:

```python
for row in csv.DictReader(source.open(encoding="utf-8-sig")):
    location_id = int(row["site"])
    # zes milieuvariabelen naar jachtspin_locatie;
    # twaalf soortkolommen naar jachtspin_vangst.
```

Pas de duinvallei-import aan zodat nieuwe imports rechtstreeks naar `Meijendel_bronnen` gaan.

- [ ] **Step 4: Test eerst in tijdelijke databases**

Run:

```bash
python3 -m pytest gis/scripts/test_migrate_meijendel_bronnen.py gis/scripts/test_import_duinvallei_vegetatie.py -q
python3 gis/scripts/migrate_meijendel_bronnen.py --copy --source Meijendel --target Meijendel_bronnen_test
python3 gis/scripts/migrate_meijendel_bronnen.py --validate --source Meijendel --target Meijendel_bronnen_test --manifest /tmp/meijendel_bronnen_migration.json
```

Expected: bron- en doelaantallen zijn gelijk; `duinvallei_opname=488`, `duinvallei_bedekking=101504`, `duinvallei_bodemmeting=855`, `vogelstand_1924=204`, `jachtspin_locatie=28`, som `jachtspin_vangst.aantal=3337`.

- [ ] **Step 5: Maak dumps en voer geïsoleerde hersteltest uit**

```bash
mysqldump --login-path=meijendel_root --no-tablespaces --single-transaction Meijendel_bronnen_test > /tmp/Meijendel_bronnen_test.sql
mysql --login-path=meijendel_root -e "DROP DATABASE IF EXISTS Meijendel_bronnen_restore; CREATE DATABASE Meijendel_bronnen_restore;"
mysql --login-path=meijendel_root Meijendel_bronnen_restore < /tmp/Meijendel_bronnen_test.sql
python3 gis/scripts/migrate_meijendel_bronnen.py --validate --source Meijendel_bronnen_test --target Meijendel_bronnen_restore --mark-restore-ok /tmp/meijendel_bronnen_migration.json
```

Expected: herstelvalidatie slaagt en zet pas dan `restore_ok=true` in het manifest.

- [ ] **Step 6: Commit zonder de levende database al te wijzigen**

```bash
git add gis/scripts/migrate_meijendel_bronnen.py gis/scripts/test_migrate_meijendel_bronnen.py \
  gis/database/duinvallei_vegetatie_schema.sql gis/scripts/import_duinvallei_vegetatie.py \
  gis/scripts/test_import_duinvallei_vegetatie.py kandidaatbronnen/jachtspinnen_1969_1970/README.md
git commit -m "Bouw gecontroleerde migratie naar Meijendel_bronnen"
```

### Task 4: Zotero-synchronisatie met Chicago-verwijzingen

**Files:**
- Create: `gis/scripts/sync_zotero_meijendel_bronnen.py`
- Create: `gis/scripts/test_sync_zotero_meijendel_bronnen.py`
- Create: `gis/scripts/fixtures/zotero_meijendel_items.json`

**Interfaces:**
- Consumes: Zotero Local API op `http://127.0.0.1:23119`, collectie met exacte naam `Meijendel`, schema uit Task 1.
- Produces: upsert in `bron`, `literatuur`, `literatuur_auteur`; `citation_chicago` volgens `chicago-fullnote-bibliography`; synchronisatierapport zonder attachmentpaden.

- [ ] **Step 1: Schrijf tests voor filtering, minimale metadata en privacy**

```python
def test_normalize_keeps_minimal_item_without_author_or_year():
    item = {"key": "ABCD1234", "data": {"itemType": "report", "title": "Ongetitelde reeks"}}
    normalized = normalize_item(item, citation="Ongetitelde reeks.")
    assert normalized["titel"] == "Ongetitelde reeks"
    assert normalized["jaar"] is None
    assert normalized["auteurs"] == []

def test_children_and_local_paths_are_excluded():
    assert is_bibliographic({"data": {"itemType": "attachment"}}) is False
    payload = normalize_item(FIXTURE_ITEM, citation="Voorbeeld.")
    assert "path" not in json.dumps(payload).casefold()
```

- [ ] **Step 2: Controleer dat de tests falen**

Run: `python3 -m pytest gis/scripts/test_sync_zotero_meijendel_bronnen.py -q`  
Expected: FAIL omdat synchronisatiescript ontbreekt.

- [ ] **Step 3: Implementeer paginering, collectiecontrole en upsert**

Maak `find_collection(base_url, name)`, `fetch_top_items(base_url, collection_key)`, `fetch_chicago_citation(base_url, item_key)` en `sync_items(connection, items)`. Filter `attachment`, `note` en `annotation`. Breek af wanneer meer dan één collectie exact `Meijendel` heet. Verwijder bij synchronisatie geen bestaand item dat tijdelijk niet door de API wordt teruggegeven; markeer het pas `niet_meer_in_export` na een volledige succesvolle run.

- [ ] **Step 4: Test met fixture en lokale Zotero-status**

Run:

```bash
python3 -m pytest gis/scripts/test_sync_zotero_meijendel_bronnen.py -q
/opt/homebrew/bin/python3 /Users/ton/.codex/plugins/cache/openai-curated-remote/zotero/0.1.2/skills/zotero/scripts/zotero.py status --json
python3 gis/scripts/sync_zotero_meijendel_bronnen.py --dry-run --collection Meijendel
```

Expected: tests PASS; dry-run meldt aantallen bibliografische items en nul attachments. Als Zotero niet draait, stopt het script vóór een databaseverbinding met de concrete melding `Zotero Local API niet bereikbaar`.

- [ ] **Step 5: Commit**

```bash
git add gis/scripts/sync_zotero_meijendel_bronnen.py \
  gis/scripts/test_sync_zotero_meijendel_bronnen.py gis/scripts/fixtures/zotero_meijendel_items.json
git commit -m "Synchroniseer Meijendelliteratuur uit Zotero"
```

### Task 5: Read-only broncatalogus in de websitecode

**Files:**
- Modify: `website/vwg-m-linux-app/app/settings.py`
- Modify: `website/vwg-m-linux-app/app/meijendel_db.py`
- Create: `website/vwg-m-linux-app/app/source_catalog.py`
- Create: `website/vwg-m-linux-app/tests/test_source_catalog.py`

**Interfaces:**
- Consumes: views `Meijendel_bronnen.v_bron_catalogus`, `v_literatuur_overzicht`, `v_contextdataset_overzicht`.
- Produces: `source_catalog_all(search: str, source_type: str, year: int | None) -> dict[str, list[dict]]`; instelling `MEIJENDEL_SOURCES_MYSQL_DATABASE` met standaard `Meijendel_bronnen`.

- [ ] **Step 1: Schrijf tests voor databasekeuze en parameterbinding**

```python
def test_sources_connection_uses_separate_database(monkeypatch):
    captured = {}
    monkeypatch.setattr(pymysql, "connect", lambda **kwargs: captured.update(kwargs) or FakeConnection())
    with mysql_connection(database="Meijendel_bronnen"):
        pass
    assert captured["database"] == "Meijendel_bronnen"

def test_catalog_query_uses_bound_search_parameter(fake_mysql):
    source_catalog_all("konijn", "literatuur", 2020)
    sql, params = fake_mysql.last_execute
    assert "konijn" not in sql
    assert params["search"] == "%konijn%"
```

- [ ] **Step 2: Controleer dat de tests falen**

Run: `cd website/vwg-m-linux-app && pytest tests/test_source_catalog.py -q`  
Expected: FAIL omdat generieke verbinding en broncatalogus ontbreken.

- [ ] **Step 3: Generaliseer de bestaande verbinding en voeg catalogusqueries toe**

Behoud `meijendel_all()` als compatibele wrapper. Voeg toe:

```python
@contextmanager
def mysql_connection(database: str) -> Iterator[pymysql.Connection]: ...

def mysql_all(database: str, sql: str, params: dict | None = None) -> list[dict]: ...
```

`source_catalog.py` mag uitsluitend uit de drie views selecteren en valideert `source_type` tegen `{"", "dataset", "literatuur", "kandidaatbron"}`.

- [ ] **Step 4: Draai gerichte en bestaande MySQL-querytests**

Run: `cd website/vwg-m-linux-app && pytest tests/test_source_catalog.py tests/test_species_index.py tests/test_plot_maps.py -q`  
Expected: PASS.

- [ ] **Step 5: Commit in de VWG_M-featurebranch**

```bash
git add website/vwg-m-linux-app/app/settings.py website/vwg-m-linux-app/app/meijendel_db.py \
  website/vwg-m-linux-app/app/source_catalog.py website/vwg-m-linux-app/tests/test_source_catalog.py
git commit -m "Voeg read-only toegang tot Meijendel_bronnen toe"
```

### Task 6: Bronnenpagina in het Analysecentrum

**Files:**
- Modify: `website/vwg-m-linux-app/app/main.py`
- Modify: `website/vwg-m-linux-app/app/templates/member_analysis_center.html`
- Create: `website/vwg-m-linux-app/app/templates/analysis_sources.html`
- Modify: `website/vwg-m-linux-app/app/static/css/site.css`
- Create: `website/vwg-m-linux-app/tests/test_analysis_sources.py`
- Modify: `website/vwg-m-linux-app/tests/test_member_manuals.py`

**Interfaces:**
- Consumes: `source_catalog_all()` uit Task 5 en `_current_analysis_principal()` uit `app/main.py`.
- Produces: GET `/analysecentrum/bronnen`; knop `Meijendel_bronnen` op de startpagina; filters `zoek`, `type`, `jaar`.

- [ ] **Step 1: Schrijf routetests voor toegang en inhoud**

```python
def test_sources_redirects_anonymous_user(monkeypatch):
    monkeypatch.setattr(main, "_current_analysis_principal", lambda request: None)
    response = main.analysis_sources_get(_request("/analysecentrum/bronnen"))
    assert response.status_code == 303
    assert response.headers["location"].endswith("/analysecentrum/login")

def test_sources_page_labels_context_as_non_analytic(monkeypatch):
    monkeypatch.setattr(main, "_current_analysis_principal", lambda request: VALID_PRINCIPAL)
    monkeypatch.setattr(main, "source_catalog_all", lambda **kwargs: EMPTY_CATALOG)
    response = main.analysis_sources_get(_request("/analysecentrum/bronnen"))
    assert "niet automatisch geschikt voor statistische analyse" in response.body.decode().casefold()
```

- [ ] **Step 2: Controleer dat de tests falen**

Run: `cd website/vwg-m-linux-app && pytest tests/test_analysis_sources.py -q`  
Expected: FAIL omdat route en template ontbreken.

- [ ] **Step 3: Implementeer route en templates**

Voeg aan de bestaande actienavigatie toe:

```html
<a class="analysis-action-button" href="{{ base_path }}/analysecentrum/bronnen">
  <strong>Meijendel_bronnen</strong>
  <span>Contextdata en literatuur die buiten de analytische database blijven</span>
</a>
```

De detailpagina toont per dataset periode, aantal, geografische status,
analysestatus en toelichting. Literatuur toont `citation_chicago`; DOI en URL
worden alleen als `https://`-link gerenderd.

- [ ] **Step 4: Draai route-, template- en regressietests**

Run:

```bash
cd website/vwg-m-linux-app
pytest tests/test_analysis_sources.py tests/test_member_manuals.py tests/test_external_analysis_access.py -q
```

Expected: PASS; anonieme en verlopen accounts krijgen geen catalogus.

- [ ] **Step 5: Commit**

```bash
git add website/vwg-m-linux-app/app/main.py website/vwg-m-linux-app/app/templates/member_analysis_center.html \
  website/vwg-m-linux-app/app/templates/analysis_sources.html website/vwg-m-linux-app/app/static/css/site.css \
  website/vwg-m-linux-app/tests/test_analysis_sources.py website/vwg-m-linux-app/tests/test_member_manuals.py
git commit -m "Ontsluit Meijendel_bronnen in Analysecentrum"
```

### Task 7: Literatuur uit het ledenarchief verwijderen

**Files:**
- Modify: `website/vwg-m-linux-app/app/main.py`
- Modify: `website/vwg-m-linux-app/app/templates/member.html`
- Modify: `website/vwg-m-linux-app/app/queries.py`
- Modify: `website/vwg-m-linux-app/tests/test_member_archive.py`
- Create: `website/vwg-m-linux-app/scripts/remove_archive_literature.py`
- Create: `website/vwg-m-linux-app/tests/test_remove_archive_literature.py`

**Interfaces:**
- Consumes: PostgreSQL `app.member_archive_documents`, archiefmap `app/data/member_archive/literatuur`, Zotero-itemkeys uit `Meijendel_bronnen.v_literatuur_overzicht`.
- Produces: controlemanifest CSV met `archive_document_id`, `original_filename`, `sha256`, `zotero_item_key`; verwijdering alleen met `--apply --yes` wanneer iedere rij gekoppeld is.

- [ ] **Step 1: Schrijf tests voor verbergen en blokkerende koppeling**

```python
def test_literature_is_not_an_archive_category():
    assert "literatuur" not in {row["key"] for row in main.MEMBER_ARCHIVE_CATEGORIES}

def test_cleanup_blocks_when_one_document_has_no_zotero_match(tmp_path):
    rows = [archive_row(1, "gevonden.pdf"), archive_row(2, "niet-gevonden.pdf")]
    matches = {1: "ZOTERO001"}
    result = validate_mapping(rows, matches)
    assert result.complete is False
    assert result.unmatched_ids == [2]
```

- [ ] **Step 2: Controleer dat de tests falen**

Run: `cd website/vwg-m-linux-app && pytest tests/test_member_archive.py tests/test_remove_archive_literature.py -q`  
Expected: FAIL omdat literatuur nog categorie is en opschoonscript ontbreekt.

- [ ] **Step 3: Verwijder de categorie uit alle gebruikerskeuzes**

Haal `{"key": "literatuur", "label": "Literatuur"}` uit
`MEMBER_ARCHIVE_CATEGORIES`, maar behoud de labelmapping tijdelijk voor het
opschoonscript. Wijzig op de ledenpagina de tekst in
`Telverslagen, rapporten en vergaderstukken.`

- [ ] **Step 4: Bouw dry-run en destructieve apply met herstelbewijs**

Het script maakt eerst een manifest en weigert `--apply` als een document geen
Zotero-itemkey heeft, het bestand ontbreekt of de SHA-256 na de dry-run is
gewijzigd. Bij apply worden de bestanden eerst naar een afgeschermde tijdelijke
quarantainemap op hetzelfde bestandssysteem verplaatst. Daarna worden de
database-rijen in één transactie verwijderd. Bij een databasefout gaan de
bestanden terug; pas na een geslaagde commit worden de quarantainestukken
verwijderd. Aantal en manifesthash komen in het releasebewijs.

- [ ] **Step 5: Draai tests en productie-dry-run**

Run:

```bash
cd website/vwg-m-linux-app
pytest tests/test_member_archive.py tests/test_remove_archive_literature.py -q
python3 scripts/remove_archive_literature.py \
  --manifest /tmp/archive_literature_manifest.csv \
  --mysql-database Meijendel_bronnen
```

Expected: tests PASS; dry-run noemt ieder bestaand literatuurdocument en blokkeert zolang één Zotero-koppeling ontbreekt.

- [ ] **Step 6: Commit zonder productie al op te schonen**

```bash
git add website/vwg-m-linux-app/app/main.py website/vwg-m-linux-app/app/templates/member.html \
  website/vwg-m-linux-app/app/queries.py website/vwg-m-linux-app/tests/test_member_archive.py \
  website/vwg-m-linux-app/scripts/remove_archive_literature.py \
  website/vwg-m-linux-app/tests/test_remove_archive_literature.py
git commit -m "Verplaats literatuur uit ledenarchief naar broncatalogus"
```

### Task 8: Gescheiden dumps, rechten, back-up en deploy

**Files:**
- Modify: `deploy/Archivering_en_Dump_Meijendel.sh`
- Modify: `deploy/update_en_deploy_meijendel.sh`
- Modify: `deploy/deploy_meijendel_vps.sh`
- Modify: `scripts/test_workspace_guard.sh`
- Create: `scripts/test_meijendel_bronnen_deploy_guard.sh`
- Modify: `deploy/README_DEPLOY.md`
- Modify: `website/vwg-m-linux-app/app/settings.py`
- Modify: `website/vwg-m-linux-app/scripts/smoke_vps.sh`
- Modify: `website/vwg-m-linux-app/tests/test_settings.py`

**Interfaces:**
- Consumes: databases `Meijendel`, `Meijendel_bronnen`; lokale dumps `meijendel.sql`, `meijendel_bronnen.sql`.
- Produces: niet-publieke `/srv/vwgm/data/Meijendel_bronnen.sql`; MySQL-grant `SELECT` op alleen de drie catalogusviews; release-manifest met afzonderlijke hashes en objectaantallen.

- [ ] **Step 1: Schrijf falende guardtests**

```bash
assert_contains "$DEPLOY" 'Meijendel_bronnen.sql'
assert_not_contains "$DEPLOY" "ln -sfn.*Meijendel_bronnen.sql.*REMOTE_WWW"
assert_contains "$DEPLOY" 'GRANT SELECT ON Meijendel_bronnen.v_bron_catalogus'
assert_contains "$SMOKE" '/Meijendel_bronnen.sql'
```

De smoke verwacht voor publieke toegang 404 of 403, nooit 200.

- [ ] **Step 2: Controleer dat de guard faalt**

Run: `bash scripts/test_meijendel_bronnen_deploy_guard.sh`  
Expected: FAIL omdat tweede dump, grants en smokecheck ontbreken.

- [ ] **Step 3: Breid dump en archivering uit**

Maak `meijendel_bronnen.sql` met dezelfde MySQL-versieguard en transactionele
opties als `meijendel.sql`. Archiveer beide bestanden op de T7 met afzonderlijke
SHA-256. Publiceer alleen `Meijendel.sql` via de bestaande symlinks.

- [ ] **Step 4: Breid kandidaatdeploy en grants uit**

Upload `Meijendel_bronnen.sql` uitsluitend naar `/srv/vwgm/data`. Herstel beide
databases in de kandidaatcontainer. Geef het websiteaccount:

```sql
GRANT SELECT ON Meijendel_bronnen.v_bron_catalogus TO 'meijendel_read'@'%';
GRANT SELECT ON Meijendel_bronnen.v_literatuur_overzicht TO 'meijendel_read'@'%';
GRANT SELECT ON Meijendel_bronnen.v_contextdataset_overzicht TO 'meijendel_read'@'%';
```

Geef geen recht op ruwe brontabellen en geen recht aan het Shiny-account.

- [ ] **Step 5: Draai guard-, versie- en deploytests**

Run:

```bash
bash scripts/test_meijendel_bronnen_deploy_guard.sh
bash scripts/test_workspace_guard.sh
bash scripts/test_mysql_version_guard.sh
cd website/vwg-m-linux-app && pytest tests/test_settings.py -q
```

Expected: PASS; geen openbare symlink of Caddy-route naar de bronnendump.

- [ ] **Step 6: Commit per repository**

Meijendel:

```bash
git add deploy/Archivering_en_Dump_Meijendel.sh deploy/update_en_deploy_meijendel.sh \
  deploy/deploy_meijendel_vps.sh deploy/README_DEPLOY.md scripts/test_workspace_guard.sh \
  scripts/test_meijendel_bronnen_deploy_guard.sh
git commit -m "Deploy Meijendel_bronnen als afgeschermde database"
```

VWG_M:

```bash
git add website/vwg-m-linux-app/app/settings.py website/vwg-m-linux-app/scripts/smoke_vps.sh \
  website/vwg-m-linux-app/tests/test_settings.py
git commit -m "Controleer afgeschermde broncatalogus op VPS"
```

### Task 9: Documentatie, database-uitvoering en lokale eindvalidatie

**Files:**
- Modify: `README.md`
- Modify: `ARCHITECTURE.md`
- Modify: `DECISIONS.md`
- Modify: `TODO.md`
- Modify: `MDs/handboek.md`
- Create: `docs/MEIJENDEL_BRONNEN.md`
- Modify: `/Users/ton/Documents/GitHub/VWG_Project/START_HERE.md`

**Interfaces:**
- Consumes: gevalideerde scripts en tests uit Tasks 1–8.
- Produces: actuele lokale databases, twee gevalideerde dumps, bijgewerkte werkinstructies en een gesloten migratiemanifest.

- [ ] **Step 1: Werk de beslis- en werkinstructies bij**

Leg letterlijk vast:

```text
Meijendel is strikt analytisch. Niet-geolokaliseerbare Meijendelgegevens en het
Meijendel-literatuuroverzicht uit Zotero worden beheerd in Meijendel_bronnen en
mogen niet zonder afzonderlijk promotiebesluit in analyses uit Meijendel worden
gebruikt.
```

Documenteer ook herstel, Zotero-synchronisatie, archiefopschoning en promotie.

- [ ] **Step 2: Draai alle lokale tests vóór datamutatie**

Run:

```bash
python3 -m pytest gis/scripts/test_meijendel_bronnen_schema_contract.py \
  gis/scripts/test_audit_meijendel_bronnen_candidates.py \
  gis/scripts/test_migrate_meijendel_bronnen.py \
  gis/scripts/test_sync_zotero_meijendel_bronnen.py -q
bash scripts/test_meijendel_bronnen_deploy_guard.sh
cd /Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app && pytest -q
```

Expected: alle tests PASS.

- [ ] **Step 3: Synchroniseer Zotero en migreer de levende lokale databases**

Run:

```bash
python3 gis/scripts/sync_zotero_meijendel_bronnen.py --execute --collection Meijendel --yes
python3 gis/scripts/migrate_meijendel_bronnen.py --copy --source Meijendel --target Meijendel_bronnen
python3 gis/scripts/migrate_meijendel_bronnen.py --validate --source Meijendel --target Meijendel_bronnen --manifest /tmp/meijendel_bronnen_migration.json
```

Maak beide dumps, herstel ze in tijdelijke databases, zet `restore_ok=true` en voer pas daarna:

```bash
python3 gis/scripts/migrate_meijendel_bronnen.py --finalize --yes --manifest /tmp/meijendel_bronnen_migration.json
```

Expected: de gevalideerde bronfamilies ontbreken daarna in `Meijendel`, staan volledig in `Meijendel_bronnen` en alle bestaande analytische tests blijven slagen.

- [ ] **Step 4: Verwijder gekoppelde archiefliteratuur lokaal**

Run vanuit VWG_M na een PostgreSQL-back-up:

```bash
python3 website/vwg-m-linux-app/scripts/remove_archive_literature.py \
  --manifest /tmp/archive_literature_manifest.csv \
  --mysql-database Meijendel_bronnen \
  --apply --yes
```

Expected: nul resterende rijen met `category='literatuur'`, lege map `app/data/member_archive/literatuur`, alle manifestregels hebben een Zotero-itemkey.

- [ ] **Step 5: Genereer dumps en controleer beide herstelpaden**

Run:

```bash
deploy/Archivering_en_Dump_Meijendel.sh
shasum -a 256 meijendel.sql meijendel_bronnen.sql
```

Expected: beide dumps bestaan; alleen `meijendel.sql` voldoet aan de bestaande publieke-dumpcontroles; bronnendump bevat geen lokale paden of blobs.

- [ ] **Step 6: Commit documentatie en sluit lokale preflight**

```bash
git add README.md ARCHITECTURE.md DECISIONS.md TODO.md MDs/handboek.md docs/MEIJENDEL_BRONNEN.md
git commit -m "Documenteer scheiding analyse- en brongegevens"
/Users/ton/Documents/GitHub/VWG_Project/scripts/workspace_preflight.sh
```

### Task 10: Productiedeploy en verificatie

**Files:**
- Modify: release-manifest via bestaande gecontroleerde releaseprocedure.

**Interfaces:**
- Consumes: schone, gemergde en gepushte `main`-branches van `Meijendel`, `VWG_M` en `VWG_Project`.
- Produces: productie met twee herstelde MySQL-databases, afgeschermde bronnenpagina en verwijderd literatuurarchief.

- [ ] **Step 1: Controleer werkruimten en maak productiedataback-ups**

Run:

```bash
/Users/ton/Documents/GitHub/VWG_Project/scripts/workspace_preflight.sh
cd /Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app
deploy/preflight_deploy_vps.sh --full
```

Expected: alle drie repositories schoon; lokale `main == origin/main`; preflight PASS.

- [ ] **Step 2: Draai Meijendel-deploy eerst als dry-run**

Run: `cd /Users/ton/Documents/GitHub/Meijendel && deploy/deploy_meijendel_vps.sh`  
Expected: kandidaat herstelt beide databases; manifest toont twee hashes en twee objectaantallen; geen productie-mutatie.

- [ ] **Step 3: Deploy databases met expliciete verwijdertoestemming**

Run: `deploy/deploy_meijendel_vps.sh --apply --yes --allow-delete`  
Expected: productie-MySQL bevat beide databases; websiteaccount kan alleen drie views lezen; Shiny-account kan `Meijendel_bronnen` niet lezen.

- [ ] **Step 4: Deploy VWG_M en ruim het productiearchief op**

Volg de bestaande VWG_M-deployprocedure. Voer de opschoning pas uit nadat de nieuwe cataloguspagina op de kandidaatversie de Zotero-items toont. Gebruik het gevalideerde manifest en `--apply --yes`.

- [ ] **Step 5: Voer functionele en beveiligingssmoke uit**

Controleer:

```text
/analysecentrum/bronnen zonder sessie -> redirect naar login
/analysecentrum/bronnen met geldige sessie -> 200
/Meijendel_bronnen.sql -> 404 of 403, nooit 200
Analysecentrum -> knop Meijendel_bronnen zichtbaar
Ledenarchief -> geen literatuurtegel, filter of uploadkeuze
Shiny -> bestaande analyses laden zonder bronnendatabase
```

- [ ] **Step 6: Registreer release en voer eindpreflight uit**

Registreer beide databasehashes, objectaantallen, het archiefopschoonmanifest en de drie productiecommits in het bestaande release-manifest. Run daarna:

```bash
/Users/ton/Documents/GitHub/VWG_Project/scripts/workspace_preflight.sh
/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app/scripts/smoke_vps.sh
```

Expected: PASS; productie en repositories zijn aantoonbaar gelijk aan de geregistreerde release.
