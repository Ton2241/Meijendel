#!/usr/bin/env python3
"""Gerichte tests voor de import van fase-1-bronnen."""

import importlib.util
import tempfile
import sys
import re
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


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == '--pq-schema':
        raise SystemExit(check_pq_schema(sys.argv[2]))
    if len(sys.argv) == 3 and sys.argv[1] == '--pq-migratie':
        raise SystemExit(check_pq_migration(sys.argv[2]))
    if len(sys.argv) == 3 and sys.argv[1] == '--pq-afronding':
        raise SystemExit(check_pq_finalize(sys.argv[2]))
    raise SystemExit(main())
