#!/usr/bin/env python3
"""Gerichte tests voor de import van fase-1-bronnen."""

import importlib.util
import tempfile
import sys
import re
import os
import shlex
import subprocess
from pathlib import Path


SCRIPT = Path(__file__).with_name("import_external_ecology_sources.py")


def load_module():
    spec = importlib.util.spec_from_file_location("external_import", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    module = load_module()
    assert callable(getattr(module, 'guard_legacy_import', None)), 'Oude import mist bescherming tegen herinvoer'
    real_run = module.run_mysql
    try:
        module.run_mysql = lambda *args: '0'
        module.guard_legacy_import(None, [])
        module.run_mysql = lambda *args: '1'
        try:
            module.guard_legacy_import(None, [])
        except RuntimeError as exc:
            assert 'PQ' in str(exc)
        else:
            raise AssertionError('Historische import moet stoppen na PQ-migratie')
    finally:
        module.run_mysql = real_run
    assert callable(getattr(module, 'resolve_pq_taxon_links', None)), 'Centrale PQ-bronkoppeling ontbreekt'
    catalogue = [{'taxon_id': 7, 'srtnum': 123, 'latijnse_naam_bron': 'Fagus sylvatica'}]
    links = [{'koppeling_id': 18, 'taxon_id': 999, 'bron_systeem': 'Meijendel',
              'bron_dataset': 'pq_vegetatie_taxon', 'bron_taxon_id': '123',
              'bron_versie': 'snapshot:v1', 'bronmetadata': catalogue[0],
              'koppelstatus': 'kandidaat', 'ingetrokken_op': None}]
    assert module.resolve_pq_taxon_links(catalogue, links) == {7: 18}
    for bad in [[], links + links, [{**links[0], 'taxon_id': None}],
                [{**links[0], 'bronmetadata': {**catalogue[0], 'srtnum': 124}}],
                [{**links[0], 'koppelstatus': 'afgewezen'}]]:
        try:
            module.resolve_pq_taxon_links(catalogue, bad)
        except ValueError:
            pass
        else:
            raise AssertionError('Onvolledige of ambigue koppeling moet blokkeren')
    assert callable(getattr(module, 'resolve_external_taxon_links', None)), 'Centrale LVD-koppeling ontbreekt'
    fields = ['taxonID', 'taxonKey', 'scientificNameID', 'acceptedNameUsageID',
              'nameAccordingTo', 'nameAccordingToID', 'scientificName', 'scientificNameAuthorship',
              'kingdom', 'phylum', 'class', 'order', 'family', 'genus', 'taxonRank',
              'verbatimTaxonRank', 'taxonomicStatus', 'nomenclaturalCode', 'taxonRemarks',
              'higherClassification']
    metadata = dict.fromkeys(fields)
    metadata.update(scientificName='Fagus sylvatica', taxonomicStatus='accepted')
    usage = {**metadata, 'dataset': 'lvd-meijendel-v1-6', 'name': 'Fagus sylvatica',
             'raw_name': 'Fagus sylvatica', 'nl': 'Beuk', 'rank': 'accepted'}
    result_row = {'resultaat_id': 17, 'wetenschappelijke_naam': 'Fagus sylvatica',
                  'wetenschappelijke_naam_bron': 'Fagus sylvatica', 'nederlandse_naam': 'Beuk',
                  'taxonrang': 'accepted', 'bronmetadata': metadata}
    ext_link = {**links[0], 'bron_dataset': 'lvd-meijendel-v1-6', 'bron_versie': '1.6; sha256:abc',
                'bronmetadata': usage}
    assert module.resolve_external_taxon_links([result_row], [ext_link],
        'lvd-meijendel-v1-6', '1.6; sha256:abc') == {17: 18}
    for bad in [{**result_row, 'bronmetadata': {**metadata, 'scientificNameID': 'anders'}},
                {**result_row, 'wetenschappelijke_naam_bron': 'Andere bronnaam'}]:
        try:
            module.resolve_external_taxon_links([bad], [ext_link], 'lvd-meijendel-v1-6', '1.6; sha256:abc')
        except ValueError:
            pass
        else:
            raise AssertionError('Naamgelijkheid zonder gelijke broncontext moet blokkeren')

    stowa = {
        "_core_id": "496163",
        "occurrenceID": "496163",
        "fieldNumber": "HHD-950-010",
        "eventDate": "2007-02-19",
        "_jaar": "2007",
        "decimalLatitude": "52.12383334",
        "decimalLongitude": "4.30933692",
        "coordinateUncertaintyInMeters": "10",
        "locality": "Meijendel, infiltratieplas 13",
        "samplingProtocol": "catch",
        "scientificName": "Asterionella formosa",
        "taxonRank": "species",
        "basisOfRecord": "HumanObservation",
        "catalogNumber": "496163",
    }
    assert module.stowa_event_key(stowa) == "HHD-950-010|2007-02-19|52.12383334|4.30933692"

    explicit_museum = {
        "_binnen_basisgebied": "1",
        "_expliciet_meijendel": "1",
        "eventDate": "1955-07-01",
        "occurrenceID": "NMR1",
    }
    assert module.admit_museum_row(explicit_museum)
    assert not module.admit_museum_row({**explicit_museum, "eventDate": ""})
    assert not module.admit_museum_row({**explicit_museum, "_expliciet_meijendel": "0"})

    assert module.admit_lvd_event({"coordinateUncertaintyInMeters": "50"})
    assert not module.admit_lvd_event({"coordinateUncertaintyInMeters": "100"})
    assert module.event_period("1955-07-", "1955") == ("1955-07-01", "1955-07-31", "maand")
    assert module.event_period("1938-07-01/1938-07-31", "1938") == (
        "1938-07-01", "1938-07-31", "interval"
    )
    assert module.event_period("2018-09-19", "2018") == ("2018-09-19", "2018-09-19", "exact")
    assert module.museum_canonical_name({
        "scientificName": "Agrotis puta (Hübner, 1803)", "taxonRank": "species"
    }) == "Agrotis puta"
    assert module.museum_canonical_name({
        "scientificName": "Cercyon (Cercyon) bifenestratus Küster, 1851",
        "scientificNameAuthorship": "Küster, 1851", "taxonRank": "species"
    }) == "Cercyon bifenestratus"

    with tempfile.TemporaryDirectory(prefix="external-ecology-test-") as tmp:
        target = Path(tmp)
        files = module.write_import_files(
            target,
            stowa_rows=[stowa],
            stowa_measurements={"496163": ("107", "aantal/ml", "occurrenceDensity")},
            endure_events=[{
                "_core_id": "E1", "eventID": "E1", "eventDate": "2018-09-19",
                "_jaar": "2018", "decimalLatitude": "52.15", "decimalLongitude": "4.33",
                "coordinateUncertaintyInMeters": "10", "samplingProtocol": "sweep",
                "sampleSizeValue": "5", "sampleSizeUnit": "minute",
            }],
            endure_results=[{
                "_core_id": "E1", "occurrenceID": "O1", "scientificName": "Acaridae",
                "occurrenceStatus": "absent", "individualCount": "0", "taxonRank": "FAMILY",
                "basisOfRecord": "HumanObservation",
            }],
            museum_sources={"nmr": ([explicit_museum | {
                "_core_id": "NMR1", "_jaar": "1955", "decimalLatitude": "52.13",
                "decimalLongitude": "4.32", "coordinateUncertaintyInMeters": "111",
                "locality": "Wassenaar, Meijendel, Bierlap", "scientificName": "Testus alba",
            }], module.SOURCE_CONFIG["nmr"])},
            lvd_events=[],
            lvd_releves={},
            lvd_occurrences=[],
        )
        assert set(files) == {"datasets", "events", "results"}
        assert files["datasets"].read_text(encoding="utf-8").count("\n") == 4
        assert files["events"].read_text(encoding="utf-8").count("\n") == 4
        assert files["results"].read_text(encoding="utf-8").count("\n") == 4
        sql = module.load_sql(files, database="Meijendel_phase12_test")
        assert "USE Meijendel_phase12_test" in sql
        assert "externe_ecologie_dataset" in sql
        assert "START TRANSACTION" in sql and "COMMIT" in sql

    print("OK: externe ecologie-importlogica")
    return 0


def check_pq_schema(database: str) -> int:
    if not re.fullmatch(r'Meijendel_pq_proef_[0-9]+', database):
        raise ValueError('Integratietest mag uitsluitend in een expliciete PQ-proefdatabase')
    module = load_module()
    assert callable(getattr(module, 'pq_schema_sql', None)), 'PQ-bronvariantenschema ontbreekt'
    client = Path('/usr/local/mysql/bin/mysql')
    args = module.mysql_args('meijendel_root') + ['--batch', '--skip-column-names', database]
    module.run_mysql(client, args, module.pq_schema_sql())
    rows = module.run_mysql(client, args,
        "SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=DATABASE() "
        "AND REFERENCED_TABLE_NAME='taxa_bronkoppeling' AND TABLE_NAME IN "
        "('pq_vegetatie_waarneming','pq_vegetatie_bronresultaat')")
    assert rows == '2', rows
    # Het bronmodel mag geen zelfstandige telling toestaan en geen ontbrekende bron accepteren.
    for sql in [
        "INSERT INTO pq_vegetatie_opname_bronkoppeling(event_id,opname_id,koppelstatus,regelversie,bewijs) "
        "VALUES(9999999999,1,'vermoedelijk','test',JSON_OBJECT())",
        "INSERT INTO pq_vegetatie_bronopname SELECT e.*,1 FROM externe_ecologie_event e LIMIT 1",
    ]:
        try:
            module.run_mysql(client, args, sql)
        except RuntimeError:
            pass
        else:
            raise AssertionError('Ongeldige PQ-bronvariant ten onrechte toegelaten')
    print('OK: PQ-schema, centrale foreign keys en uitsluiting zelfstandig meetellen')
    return 0


def check_pq_migration(database: str) -> int:
    if not re.fullmatch(r'Meijendel_pq_proef_[0-9]+', database):
        raise ValueError('Migratieproef mag nooit de levende database gebruiken')
    module = load_module()
    assert callable(getattr(module, 'prepare_pq_migration', None)), 'PQ-migratievoorbereiding ontbreekt'
    assert callable(getattr(module, 'pq_migration_sql', None)), 'Transactionele PQ-migratie ontbreekt'
    client = Path('/usr/local/mysql/bin/mysql')
    args = module.mysql_args('meijendel_root') + ['--batch', '--raw', '--skip-column-names', database]
    plan = module.prepare_pq_migration(client, args)
    assert len(plan['tables']['externe_ecologie_event']) == 644
    assert len(plan['tables']['externe_ecologie_resultaat']) == 16627
    assert len(plan['tables']['externe_ecologie_overlap']) == 32657
    assert len(plan['pairs']) == 652
    # De default is terugdraaien, met daadwerkelijke inserts en deletes binnen de proef.
    before = module.run_mysql(client, args, 'CHECKSUM TABLE externe_ecologie_event,externe_ecologie_resultaat,externe_ecologie_overlap,pq_vegetatie_waarneming')
    module.run_mysql(client, args, module.pq_migration_sql(plan))
    after = module.run_mysql(client, args, 'CHECKSUM TABLE externe_ecologie_event,externe_ecologie_resultaat,externe_ecologie_overlap,pq_vegetatie_waarneming')
    assert after == before, 'Terugdraaien moet alle oorspronkelijke tabelinhoud herstellen'
    assert module.run_mysql(client, args, 'SELECT COUNT(*) FROM pq_vegetatie_bronopname') == '0'
    assert module.run_mysql(client, args, 'SELECT COUNT(*) FROM pq_vegetatie_waarneming WHERE taxon_bronkoppeling_id IS NOT NULL') == '0'
    # Commit uitsluitend in de proefdatabase; onafhankelijke telling en waardencontrole.
    module.run_mysql(client, args, module.pq_migration_sql(plan, commit=True))
    assert module.run_mysql(client, args, 'SELECT COUNT(*) FROM pq_vegetatie_bronopname') == '644'
    assert module.run_mysql(client, args, 'SELECT COUNT(*) FROM pq_vegetatie_bronresultaat') == '16627'
    assert module.run_mysql(client, args, 'SELECT COUNT(*) FROM pq_vegetatie_bronoverlap') == '32657'
    assert module.run_mysql(client, args, 'SELECT COUNT(*) FROM pq_vegetatie_opname_bronkoppeling') == '652'
    assert module.run_mysql(client, args, 'SELECT COUNT(*) FROM pq_vegetatie_bronopname WHERE zelfstandig_meetellen<>0') == '0'
    assert module.run_mysql(client, args, 'SELECT COUNT(*) FROM pq_vegetatie_waarneming WHERE taxon_bronkoppeling_id IS NULL') == '0'
    assert module.run_mysql(client, args,
        'SELECT COUNT(*) FROM externe_ecologie_event e JOIN pq_vegetatie_bronopname p USING(event_id)') == '0'
    assert module.run_mysql(client, args,
        'SELECT COUNT(*) FROM externe_ecologie_resultaat e JOIN pq_vegetatie_bronresultaat p USING(resultaat_id)') == '0'
    try:
        module.run_mysql(client, args, module.pq_migration_sql(plan, commit=True))
    except RuntimeError:
        pass
    else:
        raise AssertionError('Herhaald toepassen moet blokkeren zonder nieuwe bronregels te maken')
    print('OK: volledige PQ-bronverplaatsing, centrale taxa, rollback en bescherming tegen dubbele invoer')
    return 0


def check_pq_finalize(database: str) -> int:
    if not re.fullmatch(r'Meijendel_pq_proef_[0-9]+', database):
        raise ValueError('Afrondingsproef mag nooit de levende database gebruiken')
    module = load_module()
    assert callable(getattr(module, 'pq_finalize_sql', None)), 'Centrale PQ-afronding ontbreekt'
    client = Path('/usr/local/mysql/bin/mysql')
    args = module.mysql_args('meijendel_root') + ['--batch', '--raw', '--skip-column-names', database]
    public_query = 'SELECT * FROM website_plot_vegetatie_jaar ORDER BY plot_id,jaar'
    before = module.run_mysql(client, args, public_query)
    calculated_query = 'SELECT * FROM pq_plot_jaar_vegetatie_berekend ORDER BY plot_id,jaar'
    calculated_before = module.run_mysql(client, args, calculated_query)
    module.run_mysql(client, args, module.pq_finalize_sql())
    assert module.run_mysql(client, args, public_query) == before
    assert module.run_mysql(client, args,
        "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='pq_vegetatie_taxon'") == '0'
    assert module.run_mysql(client, args,
        "SELECT COUNT(*) FROM v_externe_ecologie_analyse WHERE dataset_sleutel='lvd-meijendel-v1-6'") == '81310'
    assert module.run_mysql(client, args,
        "SELECT COUNT(*) FROM v_externe_ecologie_analyse a JOIN pq_vegetatie_bronresultaat b USING(resultaat_id) "
        "WHERE a.heeft_bekende_overlap<>1") == '0'
    assert module.run_mysql(client, args,
        'SELECT COUNT(*) FROM pq_plot_jaar_vegetatie_berekend') == '513'
    assert module.run_mysql(client, args, calculated_query) == calculated_before
    assert module.run_mysql(client, args,
        'SELECT COUNT(*) FROM pq_vegetatie_waarneming w LEFT JOIN taxa_bronkoppeling b '
        'ON b.koppeling_id=w.taxon_bronkoppeling_id LEFT JOIN taxa t ON t.taxon_id=b.taxon_id '
        'WHERE b.koppeling_id IS NULL OR t.taxon_id IS NULL') == '0'
    print('OK: catalogus verwijderd, centrale taxa en exact gelijke 513 publieke plot-jaarresultaten')
    return 0


def check_pq_release_retirement() -> int:
    """Voer de echte release-opruiming uit op een eigen wegwerpdatabase."""
    source = (SCRIPT.parents[2] / 'deploy/deploy_meijendel_release_vps_remote.sh').read_text()
    match = re.search(r'^retire_pq_taxon_catalog\(\) \{\n.*?^\}', source, re.M | re.S)
    assert match, 'Release laat de opgeheven PQ-catalogus achter'
    module = load_module()
    client = Path('/usr/local/mysql/bin/mysql')
    database = f'codex_pq_retirement_{os.getpid()}'
    args = module.mysql_args('meijendel_root') + ['--batch', '--raw', '--skip-column-names']
    module.run_mysql(client, args, f'CREATE DATABASE `{database}` CHARACTER SET utf8mb4')
    args += [database]
    query = lambda sql: module.run_mysql(client, args, sql)
    # Alleen de Docker-/VPS-transportgrens wordt vervangen; SQL en MySQL zijn echt.
    command = shlex.join([str(client), *args])
    shell = ('set -euo pipefail\nCONTAINER=test\n'
             'die() { echo "$*" >&2; exit 1; }\n'
             'docker() {\n'
             '  if [[ "$*" == *"-NBe"* ]]; then\n'
             f'    {command} -e "${{@: -1}}"\n'
             '  else\n'
             f'    {command}\n'
             '  fi\n}\n' + match.group() + '\nretire_pq_taxon_catalog\n')
    def run():
        return subprocess.run(['bash'], input=shell, text=True, capture_output=True)
    exists = ("SELECT COUNT(*) FROM information_schema.tables WHERE "
              "table_schema=DATABASE() AND table_name='pq_vegetatie_taxon'")
    try:
        query("CREATE TABLE taxa_bronkoppeling AS SELECT * FROM Meijendel.taxa_bronkoppeling "
              "WHERE bron_dataset='pq_vegetatie_taxon' AND ingetrokken_op IS NULL")
        fields = [('taxon_id', 'INT'), ('nederlandse_naam', 'VARCHAR(500)'),
                  ('latijnse_naam_bron', 'VARCHAR(500)'), ('srtnum', 'INT'),
                  ('taxonlijst_versie', 'VARCHAR(500)'), ('taxoncode_officieel', 'VARCHAR(500)'),
                  ('wetenschappelijke_naam_officieel', 'VARCHAR(500)'),
                  ('taxon_koppeling_status', 'VARCHAR(500)')]
        columns = ','.join(f"{name} {kind} PATH '$.{name}'" for name, kind in fields)
        query('CREATE TABLE pq_vegetatie_taxon AS SELECT j.* FROM taxa_bronkoppeling b, '
              f"JSON_TABLE(b.bronmetadata,'$' COLUMNS({columns})) j")
        # Ook ingetrokken oorspronkelijke bronvermeldingen bewijzen celbehoud.
        query("UPDATE taxa_bronkoppeling SET ingetrokken_op='2026-09-27' WHERE bron_taxon_id='1071'")
        before = query('CHECKSUM TABLE taxa_bronkoppeling')
        query("UPDATE pq_vegetatie_taxon SET nederlandse_naam='NIET BEWAARD' WHERE taxon_id=1")
        assert run().returncode != 0, 'Afwijkende oorspronkelijke cel moet verwijdering blokkeren'
        assert query(exists) == '1'
        query("UPDATE pq_vegetatie_taxon SET nederlandse_naam='Aalbes' WHERE taxon_id=1")
        query('ALTER TABLE pq_vegetatie_taxon ADD COLUMN onbekend_bronveld TEXT')
        assert run().returncode != 0, 'Extra bronveld mag niet verloren gaan'
        assert query(exists) == '1'
        query('ALTER TABLE pq_vegetatie_taxon DROP COLUMN onbekend_bronveld')
        query('CREATE VIEW oude_afnemer AS SELECT * FROM pq_vegetatie_taxon')
        assert run().returncode != 0, 'Nog bestaande afnemer moet verwijdering blokkeren'
        assert query(exists) == '1'
        query('DROP VIEW oude_afnemer')
        query('ALTER TABLE pq_vegetatie_taxon ADD PRIMARY KEY(taxon_id); '
              'CREATE TABLE oude_verwijzer(id INT, FOREIGN KEY(id) REFERENCES pq_vegetatie_taxon(taxon_id))')
        assert run().returncode != 0, 'Foreign key moet verwijdering blokkeren'
        assert query(exists) == '1'
        query('DROP TABLE oude_verwijzer')
        result = run()
        assert result.returncode == 0, result.stderr
        assert query(exists) == '0', 'Volledig bewaarde catalogus moet ook op productie verdwijnen'
        assert query('CHECKSUM TABLE taxa_bronkoppeling') == before
        assert run().returncode == 0, 'Volgende release zonder oude catalogus moet werken'
    finally:
        module.run_mysql(client, args[:-1], f'DROP DATABASE `{database}`')
    print('OK: echte MySQL-releaseopruiming, celbehoud, extra velden, afnemers en herhaling')
    return 0


def check_pq_release_schema() -> int:
    """Test echte schemapoort en behoud van productie-eigen data, buiten Meijendel."""
    source = (SCRIPT.parents[2] / 'deploy/deploy_meijendel_release_vps_remote.sh').read_text()
    functions = []
    for name in ('manifest_value', 'production_only_objects', 'release_schema_objects',
                 'check_release_schema', 'production_only_fingerprint'):
        match = re.search(r'^' + name + r'\(\) \{\n.*?^\}', source, re.M | re.S)
        assert match, f'Release mist beveiliging {name}'
        functions.append(match.group())
    tables = ['vogelstand_1924', 'website_plot_mapping', 'website_species_mapping']
    views = ['website_plot_mapping_public', 'website_plot_species_totals',
             'website_plot_year_totals', 'website_species_mapping_public',
             'website_species_territoria', 'website_species_trends']
    module = load_module()
    client = Path('/usr/local/mysql/bin/mysql')
    database = f'codex_pq_schema_{os.getpid()}'
    args = module.mysql_args('meijendel_root')
    query = lambda sql: module.run_mysql(client, args + [database], sql)
    command = shlex.join([str(client), *args, '--batch', '--raw', '--skip-column-names', database])
    dump_args = [arg for arg in args if arg not in ('--local-infile=1', '--binary-mode')]
    dump_command = shlex.join([str(client.with_name('mysqldump')), '--no-defaults', *dump_args])
    # Transport vervangen; beide clients, de SQL en alle guards blijven echt.
    shell = ('set -euo pipefail\nCONTAINER=test\n'
             'die() { echo "$*" >&2; exit 1; }\n'
             'docker() {\n'
             '  if [[ "$*" == *"exec mysqldump"* ]]; then\n'
             '    shift 6\n'
             f'    {dump_command} --no-tablespaces --single-transaction --set-gtid-purged=OFF '
             f'--skip-comments --skip-dump-date --order-by-primary {database} "$@"\n'
             '  else\n'
             f'    {command} -e "${{@: -1}}"\n'
             '  fi\n}\n' + '\n'.join(functions) + '\n')
    run = lambda action: subprocess.run(['bash'], input=shell + action, text=True, capture_output=True)
    module.run_mysql(client, args, f'CREATE DATABASE `{database}` CHARACTER SET utf8mb4')
    try:
        query('CREATE TABLE core(id INT PRIMARY KEY); INSERT INTO core VALUES(1); '
              'CREATE VIEW core_view AS SELECT * FROM core')
        for table in tables:
            query(f'CREATE TABLE {table}(id INT PRIMARY KEY, label TEXT); '
                  f"INSERT INTO {table} VALUES(1,'bewaren')")
        for view in views:
            query(f'CREATE VIEW {view} AS SELECT * FROM website_plot_mapping')
        with tempfile.TemporaryDirectory(prefix='pq-release-schema-') as directory:
            dump = Path(directory) / 'export.sql'
            manifest = Path(directory) / 'export.manifest'
            # Werkelijke mysqldump, inclusief tijdelijke view-stand-in en data.
            exported = subprocess.run(
                [str(client.with_name('mysqldump')), '--no-defaults', *dump_args,
                 '--no-tablespaces', '--set-gtid-purged=OFF', database, 'core', 'core_view'],
                text=True, capture_output=True, check=True)
            fixture = exported.stdout
            dump.write_text(fixture)
            manifest.write_text('base_tables=1\nviews=1\n')
            action = f'check_release_schema {shlex.quote(str(dump))} {shlex.quote(str(manifest))}\n'
            result = run(action)
            assert result.returncode == 0, result.stderr
            # Zelfde totaalaantal maar andere identiteit moet blokkeren, zonder mutatie.
            query('RENAME TABLE core TO onverwacht')
            before = query('CHECKSUM TABLE onverwacht, vogelstand_1924, website_plot_mapping')
            assert run(action).returncode != 0, 'Verwisselde tabel niet gedetecteerd'
            assert query('CHECKSUM TABLE onverwacht, vogelstand_1924, website_plot_mapping') == before
            query('RENAME TABLE onverwacht TO core')
            query('DROP VIEW website_species_trends; CREATE TABLE website_species_trends(id INT)')
            assert run(action).returncode != 0, 'Verkeerd objecttype niet gedetecteerd'
            query('DROP TABLE website_species_trends')
            assert run(action).returncode != 0, 'Ontbrekende view niet gedetecteerd'
            query('CREATE VIEW website_species_trends AS SELECT * FROM website_plot_mapping')
            query('CREATE TABLE onverwacht(id INT)')
            assert run(action).returncode != 0, 'Onbekende extra tabel niet gedetecteerd'
            query('DROP TABLE onverwacht')
            for bad_dump, bad_manifest in [
                (fixture + '-- Table structure for table `website_plot_mapping`\n', 'base_tables=2\nviews=1\n'),
                (fixture + '-- Table structure for table `core`\n', 'base_tables=2\nviews=1\n'),
                (fixture, 'base_tables=2\nviews=1\n'),
                (fixture, 'base_tables=1\nviews=1\nviews=1\n'),
                ('-- Table structure for table `bad-name`\n', 'base_tables=1\nviews=0\n'),
            ]:
                dump.write_text(bad_dump)
                manifest.write_text(bad_manifest)
                assert run(action).returncode != 0, 'Ongeldige export of manifest geaccepteerd'
            dump.write_text(fixture)
            manifest.write_text('base_tables=1\nviews=1\n')
            assert run(action).returncode == 0
            assert run('docker() { return 71; }\n' + action).returncode != 0
            assert run('docker() { printf "partial dump"; return 71; }\n'
                       'production_only_fingerprint\n').returncode != 0
            result = run('production_only_fingerprint\n')
            assert result.returncode == 0, result.stderr
            digest = result.stdout.strip()
            assert re.fullmatch('[0-9a-f]{64}', digest), result.stdout
            assert run(f'production_only_fingerprint {digest}\n').returncode == 0
            for change, restore in [
                ("UPDATE vogelstand_1924 SET label='gewijzigd'", "UPDATE vogelstand_1924 SET label='bewaren'"),
                ('ALTER TABLE website_species_mapping ADD COLUMN nieuw INT',
                 'ALTER TABLE website_species_mapping DROP COLUMN nieuw'),
                ('ALTER VIEW website_species_trends AS SELECT id FROM website_plot_mapping',
                 'ALTER VIEW website_species_trends AS SELECT * FROM website_plot_mapping'),
            ]:
                query(change)
                assert run(f'production_only_fingerprint {digest}\n').returncode != 0, change
                query(restore)
                result = run(f'production_only_fingerprint {digest}\n')
                assert result.returncode == 0, result.stderr
    finally:
        module.run_mysql(client, args, f'DROP DATABASE `{database}`')
    print('OK: exacte releaseobjecten, foutgevallen en ongewijzigde productie-eigen inhoud/schema')
    return 0


def check_pq_release_cache() -> int:
    """De vergelijkingsstap moet dezelfde gevalideerde cache gebruiken als productie."""
    source = (SCRIPT.parents[2] / 'deploy/deploy_meijendel_vps.sh').read_text()
    match = re.search(r'^check_dashboard_parity\(\) \{\n.*?^\}', source, re.M | re.S)
    assert match, 'Lokale paritycontrole mist verplichte kandidaatcache'
    # Alleen R als procesgrens vervangen; test de echte shellaanroep en alle argumenten.
    shell = r'''set -euo pipefail
LOCAL_REPO='/test/repo met spaties'
SQL_LOCAL='/test/export met spaties.sql'
SQL_MANIFEST_LOCAL='/test/export met spaties.sql.manifest'
CACHE_MANIFEST_LOCAL='/test/kandidaat met spaties.manifest'
MEIJENDEL_REQUIRE_PREBUILT_CACHE=0
MEIJENDEL_SQL_MANIFEST_PATH='/oude/export'
MEIJENDEL_CACHE_MANIFEST_PATH='/oude/cache'
Rscript() {
  [[ "$MEIJENDEL_REQUIRE_PREBUILT_CACHE" == 1 ]] || exit 91
  [[ "$MEIJENDEL_SQL_MANIFEST_PATH" == '/test/export met spaties.sql.manifest' ]] || exit 92
  [[ "$MEIJENDEL_CACHE_MANIFEST_PATH" == '/test/kandidaat met spaties.manifest' ]] || exit 93
  [[ "$#" == 6 && "$1" == '/test/repo met spaties/R/check_shiny_dashboard_parity.R' ]] || exit 94
  [[ "$2" == '/test/repo met spaties' && "$3" == '/test/export met spaties.sql' ]] || exit 95
  [[ "$4" == '/test/repo met spaties/trim_msi_evg/msi_per_groep_per_jaar.csv' ]] || exit 96
  [[ "$5" == 1958 && "$6" == 2025 ]] || exit 97
  return "${R_STATUS:-0}"
}
'''
    for status in (0, 37):
        result = subprocess.run(['bash'], input=shell + match.group() +
                                f'\nR_STATUS={status}\ncheck_dashboard_parity\n',
                                text=True, capture_output=True)
        assert result.returncode == status, (result.returncode, result.stderr)
    print('OK: parity gebruikt verplicht kandidaatmanifest/cache en geeft R-fouten door')
    return 0


if __name__ == "__main__":
    if sys.argv[1:] == ['--pq-release-cache']:
        raise SystemExit(check_pq_release_cache())
    if sys.argv[1:] == ['--pq-release-schema']:
        raise SystemExit(check_pq_release_schema())
    if sys.argv[1:] == ['--pq-release-opruiming']:
        raise SystemExit(check_pq_release_retirement())
    if len(sys.argv) == 3 and sys.argv[1] == '--pq-schema':
        raise SystemExit(check_pq_schema(sys.argv[2]))
    if len(sys.argv) == 3 and sys.argv[1] == '--pq-migratie':
        raise SystemExit(check_pq_migration(sys.argv[2]))
    if len(sys.argv) == 3 and sys.argv[1] == '--pq-afronding':
        raise SystemExit(check_pq_finalize(sys.argv[2]))
    raise SystemExit(main())
