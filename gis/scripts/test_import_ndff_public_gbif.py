#!/usr/bin/env python3
"""Gerichte tests voor de openbare FFV- en GBIF-importeur."""

from __future__ import annotations

import importlib.util
import copy
from argparse import Namespace
from unittest.mock import patch
from pathlib import Path


SCRIPT = Path(__file__).with_name("import_ndff_public_gbif.py")


def load_module():
    spec = importlib.util.spec_from_file_location("ndff_public_import", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    module = load_module()
    assert hasattr(module, 'resolve_vangblik_links'), 'Centrale vangblikresolver ontbreekt'
    row = dict(vangblik_soort_id=7, taxon_key='a'*64, scientific_name='Test taxon',
               kingdom='Animalia', phylum='Arthropoda', class_name='Insecta',
               order_name='Coleoptera', family='Carabidae', taxon_rank='species')
    link = dict(koppeling_id=91, bron_systeem='Meijendel', bron_dataset='vangblik_soorten',
                bron_versie='snapshot-sha256:'+'b'*64, bron_taxon_id='a'*64,
                ingetrokken_op=None, taxon_id=45, koppelstatus='kandidaat', bronmetadata=row)
    assert module.resolve_vangblik_links([row], [link]) == {7: 91}
    for bad in ([], [link, link], [dict(link,taxon_id=None)],
                [dict(link,koppelstatus='afgewezen')], [dict(link,ingetrokken_op='2026-09-28')],
                [dict(link,bron_systeem='andere bron')], [dict(link,bron_versie='')],
                [dict(link,bronmetadata=dict(row,family='Andere familie'))]):
        try:
            module.resolve_vangblik_links([row], bad)
        except ValueError:
            pass
        else:
            raise AssertionError('Onveilige of niet-brongetrouwe koppeling aanvaard')
    extra = copy.deepcopy(row)
    extra['nieuw_bronveld'] = 'mag niet verdwijnen'
    try:
        module.resolve_vangblik_links([extra], [link])
    except ValueError:
        pass
    else:
        raise AssertionError('Extra bronveld verdwijnt ongemerkt')
    before = {'vangst_sha256':'a','unchanged_tables':{'taxa':'123'}}
    proof = dict(status='verified',rollback_verified=True,database='Meijendel_vangblik_proef_20260928',
                 before=before,code_sha256='code',plan_sha256='plan',backup_sha256='backup')
    restore = dict(status='restored',database=proof['database'],snapshot=before,
                   plan_sha256='plan',backup_sha256='backup')
    module.validate_vangblik_proofs(proof,restore,before,'plan','code','backup')
    for bad_proof,bad_restore in [({},restore),(proof,{}),
            (dict(proof,rollback_verified=False),restore),
            (dict(proof,code_sha256='andere code'),restore),
            (dict(proof,backup_sha256='andere backup'),restore),
            (dict(proof,before={}),restore),
            (dict(proof,database='Meijendel'),restore),
            (proof,dict(restore,plan_sha256='catalogus ontbreekt')),
            (proof,dict(restore,database='andere proef')),
            (proof,dict(restore,snapshot={}))]:
        try:
            module.validate_vangblik_proofs(bad_proof,bad_restore,before,'plan','code','backup')
        except ValueError:
            pass
        else:
            raise AssertionError('Ongeldig proef- of herstelbewijs aanvaard')
    # Controleer de volgorde van de CLI-grens zonder echte schrijfacties.
    import import_external_ecology_sources as central
    for execute,sync in [(True,False),(False,True)]:
        args = Namespace(vangblik_integratie=False,execute=execute,sync_secure_metadata=sync,
                         mysql_client=Path('/unused'),login_path='test',host='127.0.0.1',port=3306)
        with patch.object(module,'parse_args',return_value=args), \
             patch.object(central,'central_query_gate',return_value={'status':'verified'}) as gate, \
             patch.object(module,'mysql_scalar',return_value='1'), \
             patch.object(module,'run_mysql',side_effect=AssertionError('Schrijven vóór guard')) as writer:
            try:
                module.main()
            except RuntimeError as error:
                assert 'historische bulkimport geblokkeerd' in str(error)
            else:
                raise AssertionError('Gemigreerde database niet geblokkeerd')
            writer.assert_not_called()
            gate.assert_called_once_with('Meijendel','test',Path('/unused'),'127.0.0.1',3306)
    assert module.group_codes("Geleedpotigen (overig)|Kreeftachtigen") == (
        "geleedpotigen_overig",
        "kreeftachtigen",
    )
    assert module.group_codes("Kranswieren, wieren en algen") == (
        "kranswieren_wieren_algen",
    )
    assert module.group_codes("Amfibieën") == ("amfibieen",)
    assert module.ffv_species_key("Amfibieën", "Rugstreeppad", "Epidalea calamita") == module.sha256_text(
        "Amfibieën\x1fRugstreeppad\x1fEpidalea calamita"
    )
    existing_hash = "a" * 64
    assert module.open_identity_hash(existing_hash) == existing_hash
    assert module.open_identity_hash("https://example.test/waarneming/1") == module.sha256_text(
        "https://example.test/waarneming/1"
    )

    moved = module.gbif_event_flags(
        {
            "locationID": "pf12",
            "eventDate": "05/08/1956",
            "eventRemarks": "number of mammals unreliable; state not fully described",
        }
    )
    assert moved == {
        "is_verplaatst_blok_7_18": 1,
        "is_vergelijkingsblik_1959": 0,
        "heeft_predatie_of_zoogdierrisico": 1,
        "geen_harde_nul": 1,
    }
    comparison = module.gbif_event_flags(
        {"locationID": "pf115", "eventDate": "01/06/1959", "eventRemarks": ""}
    )
    assert comparison["is_vergelijkingsblik_1959"] == 1
    assert comparison["heeft_predatie_of_zoogdierrisico"] == 0

    valid = module.gbif_occurrence_status("event-1", {"event-1"})
    orphan = module.gbif_occurrence_status("missing", {"event-1"})
    assert valid == {"event_id": "event-1", "is_verweesd": 0, "referentieel_geldig": 1}
    assert orphan == {"event_id": None, "is_verweesd": 1, "referentieel_geldig": 0}

    assert module.mysql_field(None) == r"\N"
    assert module.mysql_field("a\tb\nc\\d") == r"a\tb\nc\\d"
    assert module.mysql_connection_args("meijendel_root", "127.0.0.1", 3306) == [
        "--login-path=meijendel_root",
        "--protocol=tcp",
        "--host=127.0.0.1",
        "--port=3306",
        "--local-infile=1",
        "--binary-mode",
    ]
    assert "join ndff_sovon_plot p" in module.gbif_plot_link_sql().casefold()
    assert "plots-huidig" not in module.gbif_plot_link_sql().casefold()
    enrichment = module.secure_metadata_enrichment_sql().casefold()
    assert "insert into meijendel.ndff_open_leveringsverrijking" in enrichment
    assert "meijendel_ndff_secure.ndff_waarneming_bron" in enrichment
    assert "meijendel_ndff_secure.ndff_open_secure_koppeling" in enrichment
    assert "on duplicate key update" in enrichment
    assert "st_equals" in enrichment
    assert "sha2(s.ndff_identity,256)" in enrichment.replace(" ", "")
    assert "cast(b.raw_payload->>'$.aantal_min' as char)" in enrichment
    assert "cast(b.raw_payload->>'$.aantal_max' as char)" in enrichment
    assert "json_type(json_extract(b.raw_payload,'$.aantal_max'))='null'" in enrichment.replace(" ", "")
    insert_columns = enrichment.split("select", 1)[0]
    for forbidden in (
        "exacte_geometrie",
        "centrumx",
        "centrumy",
        "area_m2",
    ):
        assert forbidden not in insert_columns, f"gevoelig veld wordt openbaar opgeslagen: {forbidden}"
    print("OK: openbare FFV/GBIF-importlogica")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
