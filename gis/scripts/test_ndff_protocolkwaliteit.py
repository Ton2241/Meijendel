#!/usr/bin/env python3
"""Contract- en unitchecks voor de NDFF-protocolkwaliteitslaag."""

from __future__ import annotations

import csv
import importlib.util
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).parents[2]
SCHEMA = ROOT / "gis" / "database" / "ndff_protocolkwaliteit_schema.sql"
SEED = ROOT / "gis" / "database" / "ndff_protocolkwaliteit_seed.csv"
IMPORTER = ROOT / "gis" / "scripts" / "import_ndff_protocolkwaliteit.py"
README = ROOT / "README.md"
DECISIONS = ROOT / "DECISIONS.md"
AUDIT = ROOT / "docs" / "NDFF_PROTOCOLAUDIT.md"
WORK_INSTRUCTION = ROOT / "AGENTS.md"
ARCHITECTURE = ROOT / "ARCHITECTURE.md"


def load_importer():
    spec = importlib.util.spec_from_file_location("ndff_protocolkwaliteit", IMPORTER)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    sql = SCHEMA.read_text(encoding="utf-8")
    folded = " ".join(sql.casefold().split())
    compact = "".join(sql.casefold().split())
    for table in (
        "ndff_protocol",
        "ndff_protocol_mapping",
        "ndff_protocol_gebruik",
        "ndff_protocol_soortgroep_geschiktheid",
        "ndff_protocol_soort_geschiktheid",
        "ndff_open_ruimtelijke_beoordeling",
        "ndff_open_pq_koppeling",
        "ndff_snl_waarneming_context",
        "ndff_analysebesluit",
    ):
        assert f"create table if not exists {table}" in folded, table
    assert "create table if not exists meijendel.ndff_open_waarneming_protocol" in folded
    assert "create table if not exists meijendel_ndff_secure.ndff_waarneming_protocol" in folded
    for table in (
        "meijendel.ndff_vlinder_routefamilie",
        "meijendel.ndff_vlinder_routegeometrie",
        "meijendel.ndff_vlinder_bezoek",
        "meijendel.ndff_vlinder_bezoek_taxon",
        "meijendel.ndff_vliesvleugel_routefamilie",
        "meijendel.ndff_vliesvleugel_routegeometrie",
        "meijendel.ndff_vliesvleugel_bezoek",
        "meijendel.ndff_vliesvleugel_bezoek_taxon",
        "meijendel.ndff_libel_routefamilie",
        "meijendel.ndff_libel_routegeometrie",
        "meijendel.ndff_libel_bezoek",
        "meijendel.ndff_libel_bezoek_taxon",
        "meijendel.ndff_reptiel_routefamilie",
        "meijendel.ndff_reptiel_routegeometrie",
        "meijendel.ndff_reptiel_bezoek",
        "meijendel.ndff_reptiel_bezoek_taxon",
        "meijendel.ndff_amfibie_waterfamilie",
        "meijendel.ndff_amfibie_watergeometrie",
        "meijendel.ndff_amfibie_bezoek",
        "meijendel.ndff_amfibie_waterbezoek",
        "meijendel.ndff_amfibie_waterbezoek_taxon",
        "meijendel.ndff_vleermuis_recordselectie",
        "meijendel.ndff_vleermuis_routefamilie",
        "meijendel.ndff_vleermuis_routegeometrie",
        "meijendel.ndff_vleermuis_bezoek",
        "meijendel.ndff_vleermuis_bezoek_taxon",
        "meijendel.ndff_konijn_recordselectie",
        "meijendel.ndff_konijn_hokdatum_taxon",
        "meijendel.ndff_daz_bmp_recordselectie",
        "meijendel.ndff_daz_bmp_recordkandidaat",
        "meijendel.ndff_daz_bmp_bezoek",
        "meijendel.ndff_daz_bmp_bezoek_taxon",
        "meijendel.ndff_zeereep_kilometerhok",
        "meijendel.ndff_zeereep_bezoek",
        "meijendel.ndff_zeereep_bezoek_taxon",
        "meijendel.ndff_bospaddenstoel_meetpunt",
        "meijendel.ndff_bospaddenstoel_geometrie",
        "meijendel.ndff_bospaddenstoel_recordselectie",
        "meijendel.ndff_bospaddenstoel_doelbereik",
        "meijendel.ndff_bospaddenstoel_bezoek",
        "meijendel.ndff_bospaddenstoel_bezoek_taxon",
        "meijendel.ndff_bospaddenstoel_jaar_taxon",
        "meijendel.ndff_hns_inventarisatie",
        "meijendel.ndff_hns_recordselectie",
        "meijendel.ndff_hns_doelbereik",
        "meijendel.ndff_hns_inventarisatie_taxon",
        "meijendel.ndff_hns_hok_jaar_taxon",
        "meijendel.ndff_korstmos_meetlocatie",
        "meijendel.ndff_korstmos_bezoek",
        "meijendel.ndff_korstmos_recordselectie",
        "meijendel.ndff_korstmos_doelbereik",
        "meijendel.ndff_korstmos_bezoek_taxon",
    ):
        assert f"create table if not exists {table}" in folded, table
    assert "meijendel_ndff_secure.ndff_vlinder_" not in folded
    assert "meijendel_ndff_secure.ndff_libel_" not in folded
    assert "meijendel_ndff_secure.ndff_reptiel_" not in folded
    assert "meijendel_ndff_secure.ndff_amfibie_" not in folded
    assert "meijendel_ndff_secure.ndff_vleermuis_" not in folded
    assert "meijendel_ndff_secure.ndff_konijn_" not in folded
    assert "meijendel_ndff_secure.ndff_daz_bmp_" not in folded
    assert "meijendel_ndff_secure.ndff_zeereep_" not in folded
    assert "meijendel_ndff_secure.ndff_bospaddenstoel_" not in folded
    assert "meijendel_ndff_secure.ndff_hns_" not in folded
    assert "meijendel_ndff_secure.ndff_korstmos_" not in folded
    assert "fk_ndff_vliesvleugel_geometrie_route" in folded
    assert "fk_ndff_vliesvleugel_bezoek_route" in folded
    assert "fk_ndff_vliesvleugel_taxon_bezoek" in folded
    assert "fk_ndff_libel_geometrie_route" in folded
    assert "fk_ndff_libel_bezoek_route" in folded
    assert "fk_ndff_libel_taxon_bezoek" in folded
    assert "fk_ndff_reptiel_geometrie_route" in folded
    assert "fk_ndff_reptiel_bezoek_route" in folded
    assert "fk_ndff_reptiel_taxon_bezoek" in folded
    assert "fk_ndff_amfibie_geometrie_water" in folded
    assert "fk_ndff_amfibie_waterbezoek_bezoek" in folded
    assert "fk_ndff_amfibie_waterbezoek_water" in folded
    assert "fk_ndff_amfibie_taxon_waterbezoek" in folded
    assert "fk_ndff_vleermuis_selectie_route" in folded
    assert "fk_ndff_vleermuis_geometrie_route" in folded
    assert "fk_ndff_vleermuis_bezoek_route" in folded
    assert "fk_ndff_vleermuis_taxon_bezoek" in folded
    assert "alleen_positieve_bezoeken" in folded
    assert "niet_afleidbaar" in folded
    assert "enum('waargenomen','echte_nul')" in folded
    assert "ndff-vlinderroute-v1" in folded
    assert "enum('expliciete_code','expliciet_losse_waarneming')" in folded
    assert "'voorlopig_toegelaten'" in folded
    assert "wetenschappelijke_naam varchar(255) not null" in folded
    assert "enum('doelsoort','bijvangst','onbepaald')" in folded
    assert "enum('overlap_bevestigd','overlap_mogelijk','geen_overlap_gevonden','onvoldoende_onderzocht')" in compact

    for required in (
        "regelversie",
        "bronbestand_sha256",
        "protocolgeschiktheid",
        "gegevensgeschiktheid",
        "eindbesluit",
        "is_plotcontext_ruimtelijk_toelaatbaar",
        "eenduidig_plot_id",
    ):
        assert required in folded, required

    for forbidden in (
        "alter table ndff_open_waarneming",
        "alter table territoria",
        "alter table pq_",
        "create table if not exists ndff_telobject",
        "create table if not exists ndff_bezoek",
        "create or replace view",
        "truncate ",
        "delete from ",
        "check (eindbesluit <> 'toegelaten')",
    ):
        assert forbidden not in folded, forbidden

    with SEED.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    assert len(rows) == 54
    assert len({row["protocol_sleutel"] for row in rows}) == 54
    assert len({row["protocol_naam"] for row in rows}) == 54
    assert Counter(row["hoofdtype"] for row in rows) == {
        "V": 14,
        "I": 14,
        "TV": 9,
        "TA": 13,
        "TK": 4,
    }
    assert {row["levering_scope"] for row in rows} == {"beide", "alleen_openbaar"}
    loose = [row for row in rows if row["protocol_sleutel"] == "LOS"]
    assert len(loose) == 1 and loose[0]["protocol_code"] == ""

    module = load_importer()
    assert module.RULE_VERSION == "ndff-protocolkwaliteit-v1"
    assert module.SCOPE_RULE_VERSION == "ndff-protocolbereik-v2"
    assert module.DECISION_RULE_VERSION == "ndff-analysebesluit-v4"
    assert module.SNL_OVERLAP_RULE_VERSION == "ndff-snl-overlap-v1"
    assert module.ANALYSIS_CHAIN_VERSION == "ndff-analyseketen-v1"
    parsed = module.read_seed(SEED)
    assert len(parsed) == 54
    assert module.protocol_key("Geen code") == "LOS"
    assert module.protocol_key("03.201") == "03.201"
    assert module.protocol_code_from_raw("03.201 Landelijk Meetnet Vlinders (NEM)") == "03.201"
    assert module.protocol_code_from_raw("Losse waarnemingen") == "LOS"
    for missing in (None, ""):
        try:
            module.protocol_code_from_raw(missing)
        except ValueError:
            pass
        else:
            raise AssertionError("Een lege protocolwaarde mag niet als LOS worden behandeld")
    assert module.conditional_types("TV / TA met volledige geschikte bezoekgegevens") == {"TV", "TA"}
    assert module.conditional_types(None) == set()
    assert module.sql_text("", empty_as_null=False) == "''"

    # Een routeversie mag alleen aan een andere versie worden gekoppeld als
    # minstens de helft van de kleinste geometrieset ruimtelijk overeenkomt.
    # Eén nabij kruispunt tussen twee routes mag ze niet samenvoegen.
    route_rows = []
    for visit, year, prefix, offset in (
        ("a-2020", 2020, "a", 0.0),
        ("a-2021", 2021, "a", 0.0),
        ("a-2022", 2022, "a2", 0.5),
        ("b-2020", 2020, "b", 1000.0),
    ):
        for section in range(1, 5):
            route_rows.append({
                "visit": visit,
                "geometry": f"{prefix}-{section}",
                "x": offset + section * 50.0,
                "y": 0.0,
                "area": 500.0,
                "year": year,
                "records": 1,
            })
    # Eén punt van route C ligt vlak bij route A, de overige punten niet.
    for section, x in enumerate((200.0, 2000.0, 2050.0, 2100.0), 1):
        route_rows.append({
            "visit": "c-2020", "geometry": f"c-{section}", "x": x,
            "y": 0.0, "area": 500.0, "year": 2020, "records": 1,
        })
    route_rows.append({
        "visit": "coarse-only", "geometry": "km", "x": 0.0, "y": 0.0,
        "area": 1_000_000.0, "year": 2020, "records": 3,
    })
    reconstruction = module.reconstruct_route_families(route_rows)
    assert reconstruction["family_count"] == 3
    assert reconstruction["component_count"] == 4
    assert reconstruction["fine_visit_count"] == 5
    assert reconstruction["coarse_only_visit_count"] == 1
    assert reconstruction["coarse_only_record_count"] == 3
    assert reconstruction["visit_to_family"]["a-2020"] == reconstruction["visit_to_family"]["a-2022"]
    assert reconstruction["visit_to_family"]["a-2020"] != reconstruction["visit_to_family"]["c-2020"]

    matrix = module.build_visit_taxon_matrix(
        visits={"v1": 1, "v2": None, "v3": 2},
        target_taxa=("Aglais urticae", "Pieris napi"),
        observations={
            ("v1", "Aglais urticae"): 3,
            ("v2", "Pieris napi"): 2,
        },
    )
    assert len(matrix) == 6
    assert {(row["visit"], row["taxon"]): (row["count"], row["status"])
            for row in matrix} == {
        ("v1", "Aglais urticae"): (3, "waargenomen"),
        ("v1", "Pieris napi"): (0, "echte_nul"),
        ("v2", "Aglais urticae"): (0, "echte_nul"),
        ("v2", "Pieris napi"): (2, "waargenomen"),
        ("v3", "Aglais urticae"): (0, "echte_nul"),
        ("v3", "Pieris napi"): (0, "echte_nul"),
    }
    scoped_matrix = module.build_visit_taxon_matrix(
        visits={"algemeen": 1, "onbepaald": None},
        target_taxa=("Aeshna mixta", "Sympetrum vulgatum"),
        observations={
            ("algemeen", "Aeshna mixta"): 2,
            ("onbepaald", "Sympetrum vulgatum"): 1,
        },
        visit_target_taxa={
            "algemeen": {"Aeshna mixta", "Sympetrum vulgatum"},
            "onbepaald": {"Sympetrum vulgatum"},
        },
    )
    assert len(scoped_matrix) == 3
    assert not any(
        row["visit"] == "onbepaald" and row["taxon"] == "Aeshna mixta"
        for row in scoped_matrix
    )
    assert module.VLINDER_ROUTE_RULE_VERSION == "ndff-vlinderroute-v1"
    assert module.LIBEL_ROUTE_RULE_VERSION == "ndff-libellenroute-v1"
    assert module.REPTILE_ROUTE_RULE_VERSION == "ndff-reptielroute-v1"
    assert module.AMPHIBIAN_WATER_RULE_VERSION == "ndff-amfibiewater-v1"
    assert module.BAT_TRANSECT_RULE_VERSION == "ndff-vleermuistransect-v1"
    assert module.RABBIT_COUNT_RULE_VERSION == "ndff-konijnentelling-v1"
    assert module.DAZ_BMP_RULE_VERSION == "ndff-daz-bmp-v1"
    assert module.ZEEREEP_RULE_VERSION == "ndff-zeereep-v1"
    assert module.ZEEREEP_TABLE_PREFIX == "Meijendel.ndff_zeereep"
    assert module.HNS_TABLE_PREFIX == "Meijendel.ndff_hns"
    assert module.KORSTMOS_RULE_VERSION == "ndff-korstmos-v1"
    assert module.KORSTMOS_TABLE_PREFIX == "Meijendel.ndff_korstmos"

    korstmos_records = module.classify_korstmos_records([
        {"observation_id": 1, "visit": "v1", "taxon": "Taxon a",
         "abundance": "0.01 - 0.1"},
        {"observation_id": 2, "visit": "v1", "taxon": "Taxon a",
         "abundance": "0.01 - 0.1"},
        {"observation_id": 3, "visit": "v1", "taxon": "Taxon b",
         "abundance": "0.01 - 0.1"},
        {"observation_id": 4, "visit": "v1", "taxon": "Taxon b",
         "abundance": "minimaal 0.1"},
        {"observation_id": 5, "visit": "v2", "taxon": "Taxon a",
         "abundance": "minimaal 0.1"},
    ])
    assert korstmos_records[1]["selectiestatus"] == "opgenomen"
    assert korstmos_records[2]["selectiestatus"] == "dubbele_registratie_onderdrukt"
    assert korstmos_records[2]["canonieke_waarneming_id"] == 1
    assert korstmos_records[3]["selectiestatus"] == "abundantieconflict_bewaard"
    assert korstmos_records[4]["selectiestatus"] == "abundantieconflict_bewaard"
    assert korstmos_records[5]["selectiestatus"] == "opgenomen"

    korstmos_matrix = module.build_korstmos_visit_matrix(
        visits={"v1", "v2"},
        target_taxa={"Taxon a", "Taxon b"},
        records=[
            {"visit": "v1", "taxon": "Taxon a", "abundance": "0.01 - 0.1"},
            {"visit": "v1", "taxon": "Taxon b", "abundance": "0.01 - 0.1"},
            {"visit": "v1", "taxon": "Taxon b", "abundance": "minimaal 0.1"},
            {"visit": "v2", "taxon": "Taxon a", "abundance": "minimaal 0.1"},
        ],
    )
    korstmos_by_key = {(row["visit"], row["taxon"]): row for row in korstmos_matrix}
    assert korstmos_by_key[("v1", "Taxon a")]["status"] == "waargenomen"
    assert korstmos_by_key[("v1", "Taxon a")]["bedekkingsrang"] == 1
    assert korstmos_by_key[("v1", "Taxon b")]["status"] == "waargenomen_abundantieconflict"
    assert korstmos_by_key[("v1", "Taxon b")]["bedekkingsrang"] is None
    assert korstmos_by_key[("v2", "Taxon a")]["bedekkingsrang"] == 2
    assert korstmos_by_key[("v2", "Taxon b")]["status"] == "echte_nul"
    assert korstmos_by_key[("v2", "Taxon b")]["bedekkingsrang"] == 0

    hns_rows = [
        {
            "observation_id": index,
            "date": "2024-07-18",
            "stop_date": "2024-07-18",
            "hok": "82 - 462",
            "taxon": f"Taxon {index:02d}",
            "blurred": False,
        }
        for index in range(1, 56)
    ]
    hns_rows += [
        {
            "observation_id": 56,
            "date": "2024-07-18",
            "stop_date": "2024-07-18",
            "hok": "82 - 461",
            "taxon": "Taxon spillover",
            "blurred": False,
        },
        {
            "observation_id": 57,
            "date": "2024-01-01",
            "stop_date": "2025-01-01",
            "hok": "82 - 462",
            "taxon": "Taxon vervaagd",
            "blurred": True,
        },
        {
            "observation_id": 58,
            "date": "2024-09-19",
            "stop_date": "2024-09-19",
            "hok": "86 - 463",
            "taxon": "Taxon fragment",
            "blurred": False,
        },
    ]
    hns = module.reconstruct_hns_candidates(hns_rows)
    assert len(hns["inventories"]) == 2
    complete = next(
        inventory for inventory in hns["inventories"].values()
        if inventory["status"] == "volledige_lijst_aannemelijk"
    )
    assert complete["target_hok"] == "82 - 462"
    assert complete["taxa_count"] == 56
    assert complete["source_record_count"] == 56
    fragment = next(
        inventory for inventory in hns["inventories"].values()
        if inventory["status"] == "fragment"
    )
    assert fragment["source_record_count"] == 1
    assert hns["record_status"][57] == "vervaagd_jaarrecord_niet_toegewezen"
    assert hns["record_inventory"][1] in hns["inventories"]
    assert hns["record_inventory"][57] is None

    hns_matrix = module.build_hns_visit_matrix(
        complete_inventories={"visit-a": {"Taxon a"}, "visit-b": {"Taxon b"}},
        target_taxa={"Taxon a", "Taxon b"},
    )
    assert hns_matrix == [
        {"visit": "visit-a", "taxon": "Taxon a", "status": "waargenomen"},
        {"visit": "visit-a", "taxon": "Taxon b", "status": "echte_nul"},
        {"visit": "visit-b", "taxon": "Taxon a", "status": "echte_nul"},
        {"visit": "visit-b", "taxon": "Taxon b", "status": "waargenomen"},
    ]

    assert module.classify_zeereep_abundance("NMV-aantalsklassen", "1.0 - 3.0") == "klasse_1_3"
    assert module.classify_zeereep_abundance("NMV-aantalsklassen", "4.0 - 20.0") == "klasse_4_20"
    assert module.classify_zeereep_abundance("NMV-aantalsklassen", "minimaal 21.0") == "klasse_21_plus"
    assert module.classify_zeereep_abundance("voorkomen", "minimaal 1.0") == "aanwezig"
    assert module.classify_zeereep_abundance("exact aantal", "1") == "exact_1"

    assert module.normalize_bospaddenstoel_date(
        "exact aantal", "1999-08-26 22:00:00", "1999-08-27 22:00:00"
    ) == "1999-08-27"
    assert module.normalize_bospaddenstoel_date(
        "voorkomen", "1999-08-27 00:00:00", "1999-08-28 00:00:00"
    ) == "1999-08-27"
    assert module.parse_bospaddenstoel_count("exact aantal", "78") == 78
    assert module.parse_bospaddenstoel_count("voorkomen", "minimaal 1.0") is None
    bospaddenstoel_selection = module.select_bospaddenstoel_records([
        {"identity": "exact", "plot": 1, "date": "1999-08-27", "taxon": "Taxon a",
         "scale": "exact aantal", "raw": "5"},
        {"identity": "presence", "plot": 1, "date": "1999-08-27", "taxon": "Taxon a",
         "scale": "voorkomen", "raw": "minimaal 1.0"},
        {"identity": "presence-only", "plot": 1, "date": "1999-09-27", "taxon": "Taxon b",
         "scale": "voorkomen", "raw": "minimaal 1.0"},
    ])
    assert bospaddenstoel_selection["exact"]["selectiestatus"] == "opgenomen_exact"
    assert bospaddenstoel_selection["presence"]["selectiestatus"] == "dubbele_presentie_onderdrukt"
    assert bospaddenstoel_selection["presence"]["canonieke_identiteit"] == "exact"
    assert bospaddenstoel_selection["presence-only"]["selectiestatus"] == "opgenomen_presentie"

    assert module.classify_rabbit_season("2020-03-15") == "voorjaar_huidig_venster"
    assert module.classify_rabbit_season("2020-04-07") == "voorjaar_huidig_venster"
    assert module.classify_rabbit_season("2020-09-15") == "najaar_huidig_venster"
    assert module.classify_rabbit_season("2020-10-15") == "najaar_huidig_venster"
    assert module.classify_rabbit_season("2020-04-08") == "buiten_huidig_venster"
    assert module.classify_rabbit_record_signal(1, 1) == "uniek_binnen_hokdatum_taxon"
    assert module.classify_rabbit_record_signal(2, 1) == "meerdere_sectieregels_binnen_hokdatum_taxon"
    assert module.classify_rabbit_record_signal(2, 2) == "gelijke_telwaarde_binnen_hokdatum_taxon"

    daz_matrix = module.build_daz_bmp_matrix(
        confirmed_visits={101, 102},
        positive_counts={(101, "Oryctolagus cuniculus"): (3, 1),
                         (101, "Dama dama"): (2, 1)},
        ambiguous_counts={(101, "Oryctolagus cuniculus"): 1,
                          (102, "Lepus europaeus"): 2},
    )
    daz_by_key = {(row["visit_id"], row["taxon"]): row for row in daz_matrix}
    assert daz_by_key[(101, "Oryctolagus cuniculus")]["status"] == "waargenomen"
    assert daz_by_key[(101, "Oryctolagus cuniculus")]["value_status"] == "minimum_door_ambiguiteit"
    assert daz_by_key[(101, "Dama dama")]["relation"] == "bijvangst"
    assert (102, "Dama dama") not in daz_by_key
    assert daz_by_key[(102, "Lepus europaeus")]["status"] == "onbepaald_ambigu"
    assert daz_by_key[(102, "Capreolus capreolus")]["status"] == "echte_nul"

    assert module.classify_bat_route(83_999.0) == {
        "routefamilie_id": 2,
        "methodevariant": "vleermus_fiets",
        "routecode": "vleerMUS_zuid",
    }
    assert module.classify_bat_route(84_000.0) == {
        "routefamilie_id": 1,
        "methodevariant": "nem_vtt_auto",
        "routecode": "NEM_VTT_noord",
    }
    assert module.bat_target_taxa("nem_vtt_auto") == {
        "Pipistrellus pipistrellus", "Pipistrellus nathusii",
        "Eptesicus serotinus", "Nyctalus noctula",
    }
    assert module.bat_target_taxa("vleermus_fiets") == {
        "Pipistrellus pipistrellus", "Pipistrellus nathusii",
        "Eptesicus serotinus",
    }
    bat_rows = [
        {"identity": "midnight", "taxon": "Pipistrellus pipistrellus",
         "start": "2019-09-09 00:00:00", "visit_date": "2019-09-09",
         "geometry": "g1", "x": 82_000.0},
        {"identity": "timed-a", "taxon": "Pipistrellus pipistrellus",
         "start": "2019-09-09 21:45:00", "visit_date": "2019-09-09",
         "geometry": "g1", "x": 82_000.0},
        {"identity": "timed-b", "taxon": "Pipistrellus pipistrellus",
         "start": "2019-09-09 21:46:00", "visit_date": "2019-09-09",
         "geometry": "g1", "x": 82_000.0},
        {"identity": "north", "taxon": "Nyctalus noctula",
         "start": "2019-07-23 00:00:00", "visit_date": "2019-07-23",
         "geometry": "g2", "x": 86_000.0},
    ]
    bat_selection = module.classify_bat_records(bat_rows)
    assert bat_selection["midnight"]["selectiestatus"] == "dubbele_aanlevering_onderdrukt"
    assert bat_selection["midnight"]["canonieke_identiteit"] == "timed-a"
    assert bat_selection["timed-a"]["selectiestatus"] == "opgenomen"
    assert bat_selection["timed-b"]["selectiestatus"] == "opgenomen"
    assert bat_selection["north"]["selectiestatus"] == "opgenomen"

    # Alleen nabijgelegen geometrieversies met niet-overlappende gebruiksjaren
    # vormen één waterfamilie. Nabije gelijktijdig gebruikte wateren blijven
    # afzonderlijke meeteenheden.
    amphibian_waters = module.reconstruct_amphibian_water_families([
        {"geometry": "oud", "x": 100.0, "y": 100.0, "area": 25.0,
         "year": 2010, "records": 2},
        {"geometry": "nieuw", "x": 112.0, "y": 100.0, "area": 30.0,
         "year": 2012, "records": 3},
        {"geometry": "buur", "x": 120.0, "y": 100.0, "area": 20.0,
         "year": 2012, "records": 1},
    ])
    assert amphibian_waters["family_count"] == 2
    assert amphibian_waters["geometry_to_family"]["oud"] == amphibian_waters["geometry_to_family"]["nieuw"]
    assert amphibian_waters["geometry_to_family"]["oud"] != amphibian_waters["geometry_to_family"]["buur"]

    assert module.parse_amphibian_measurement("exact aantal", "17") == {
        "meetwaarde_type": "exact", "aantal_exact": 17,
        "ondergrens": 17, "bovengrens": 17, "presentieklasse": None,
    }
    assert module.parse_amphibian_measurement(
        "presentieklasse (Ravon)", "11.0 - 100.0"
    ) == {
        "meetwaarde_type": "presentieklasse", "aantal_exact": None,
        "ondergrens": 11, "bovengrens": 100, "presentieklasse": 2,
    }
    assert module.parse_amphibian_measurement("minimum aantal", "minimaal 20") == {
        "meetwaarde_type": "minimum", "aantal_exact": None,
        "ondergrens": 20, "bovengrens": None, "presentieklasse": None,
    }
    assert module.parse_amphibian_measurement("geschat aantal", "8 - 12") == {
        "meetwaarde_type": "schatting", "aantal_exact": None,
        "ondergrens": 8, "bovengrens": 12, "presentieklasse": None,
    }
    assert module.amphibian_analysis_taxon("Pelophylax kl. esculentus") == "Pelophylax esculentus synklepton"
    repeated_pair = [
        {"date": f"2020-05-{day:02d}", "geometry": geometry, "x": x, "y": 0.0, "area": area, "year": 2020, "records": 1}
        for day in range(1, 11)
        for geometry, x, area in (("a", 0.0, 10_000.0), ("b", 750.0, 12_000.0))
    ]
    reptile_routes = module.reconstruct_reptile_route_families(
        repeated_pair + [
            {"date": "2020-05-01", "geometry": "c", "x": 4_000.0, "y": 0.0, "area": 11_000.0, "year": 2020, "records": 1},
            {"date": "2021-05-01", "geometry": "p", "x": 10.0, "y": 0.0, "area": 25.0, "year": 2021, "records": 1},
            {"date": "2021-05-02", "geometry": "km", "x": 0.0, "y": 0.0, "area": 1_000_000.0, "year": 2021, "records": 1},
        ],
        small_to_anchor={"p": "a"},
    )
    assert reptile_routes["family_count"] == 2
    assert reptile_routes["geometry_to_family"]["a"] == reptile_routes["geometry_to_family"]["b"]
    assert reptile_routes["geometry_to_family"]["a"] != reptile_routes["geometry_to_family"]["c"]
    assert reptile_routes["geometry_to_family"]["p"] == reptile_routes["geometry_to_family"]["a"]
    assert "km" not in reptile_routes["geometry_to_family"]
    importer_text = IMPORTER.read_text(encoding="utf-8")
    assert "--reconstruct-vlinders" in importer_text
    assert "--audit-vlinders" in importer_text
    assert "--reconstruct-vliesvleugelen" in importer_text
    assert "--audit-vliesvleugelen" in importer_text
    assert "--reconstruct-libellen" in importer_text
    assert "--audit-libellen" in importer_text
    assert "--reconstruct-reptielen" in importer_text
    assert "--audit-reptielen" in importer_text
    assert "--reconstruct-amfibieen" in importer_text
    assert "--audit-amfibieen" in importer_text
    assert "--reconstruct-vleermuizen" in importer_text
    assert "--audit-vleermuizen" in importer_text
    assert "--reconstruct-konijnen" in importer_text
    assert "--audit-konijnen" in importer_text
    assert "--reconstruct-daz-bmp" in importer_text
    assert "--audit-daz-bmp" in importer_text
    assert "--reconstruct-zeereeppaddenstoelen" in importer_text
    assert "--audit-zeereeppaddenstoelen" in importer_text
    assert "--reconstruct-bospaddenstoelen" in importer_text
    assert "--audit-bospaddenstoelen" in importer_text
    assert "--reconstruct-hns" in importer_text
    assert "--audit-hns" in importer_text
    assert "03.201" in importer_text
    assert "soortgroep_raw='Dagvlinders'" in importer_text
    source_sql = " ".join(module.vlinder_source_sql().split())
    assert "EXISTS ( SELECT 1" in source_sql
    assert "doel.soortgroep_raw='Dagvlinders'" in source_sql
    assert "meijendel_ndff_secure.ndff_vlinder_" not in importer_text.casefold()
    assert module.VLINDER_TABLE_PREFIX == "Meijendel.ndff_vlinder"
    assert module.VLIESVLEUGEL_TABLE_PREFIX == "Meijendel.ndff_vliesvleugel"
    assert module.LIBEL_TABLE_PREFIX == "Meijendel.ndff_libel"
    assert module.REPTILE_TABLE_PREFIX == "Meijendel.ndff_reptiel"
    assert module.AMPHIBIAN_TABLE_PREFIX == "Meijendel.ndff_amfibie"
    assert module.BAT_TABLE_PREFIX == "Meijendel.ndff_vleermuis"
    assert module.RABBIT_TABLE_PREFIX == "Meijendel.ndff_konijn"
    assert module.DAZ_BMP_TABLE_PREFIX == "Meijendel.ndff_daz_bmp"
    libel_source_sql = " ".join(module.libel_source_sql().split())
    assert "o.protocol LIKE '07.201%'" in libel_source_sql
    assert "o.soortgroep_raw='Libellen'" in libel_source_sql
    assert "Meijendel_ndff_secure" not in libel_source_sql
    reptile_source_sql = " ".join(module.reptile_source_sql().split())
    assert "o.protocol LIKE '10.201%'" in reptile_source_sql
    assert "o.soortgroep_raw='Reptielen'" in reptile_source_sql
    assert "Meijendel_ndff_secure" not in reptile_source_sql
    assert "DATE(o.periode_start)" in reptile_source_sql
    amphibian_source_sql = " ".join(module.amphibian_source_sql().split())
    assert "o.protocol LIKE '01.201%'" in amphibian_source_sql
    assert "o.soortgroep_raw='Amfibieën'" in amphibian_source_sql
    assert "o.vervaagd=0" in amphibian_source_sql
    assert "Meijendel_ndff_secure" not in amphibian_source_sql
    amphibian_excluded_sql = " ".join(module.amphibian_excluded_sql().split())
    assert "o.vervaagd=0" not in amphibian_excluded_sql
    assert "vervaagd=1" in amphibian_excluded_sql
    assert "TIMESTAMPDIFF(HOUR,periode_start,periode_stop)>=8000" in amphibian_excluded_sql
    bat_source_sql = " ".join(module.bat_source_sql().split())
    assert "o.protocol LIKE '17.208%'" in bat_source_sql
    assert "o.soortgroep_raw='Vleermuizen'" in bat_source_sql
    assert "o.vervaagd=0" in bat_source_sql
    assert "Meijendel_ndff_secure" not in bat_source_sql
    rabbit_source_sql = " ".join(module.rabbit_source_sql().split())
    assert "o.protocol LIKE '17.209%'" in rabbit_source_sql
    assert "o.soortgroep_raw='Zoogdieren (overig)'" in rabbit_source_sql
    assert "Meijendel_ndff_secure" not in rabbit_source_sql
    daz_source_sql = " ".join(module.daz_bmp_source_sql().split())
    assert "o.protocol LIKE '17.204%'" in daz_source_sql
    assert "Meijendel_ndff_secure" not in daz_source_sql
    daz_candidate_sql = " ".join(module.daz_bmp_candidate_sql().split())
    assert "Meijendel.dagbezoeken_bmp" in daz_candidate_sql
    assert "ST_Intersects" in daz_candidate_sql
    zeereep_source_sql = " ".join(module.zeereep_source_sql().split())
    assert "o.protocol LIKE '11.202%'" in zeereep_source_sql
    assert "o.soortgroep_raw='Schimmels'" in zeereep_source_sql
    assert "o.vervaagd=0" in zeereep_source_sql
    assert "Meijendel_ndff_secure" not in zeereep_source_sql
    bospaddenstoel_source_sql = " ".join(module.bospaddenstoel_source_sql().split())
    assert "o.protocol LIKE '11.201%'" in bospaddenstoel_source_sql
    assert "o.soortgroep_raw='Schimmels'" in bospaddenstoel_source_sql
    assert "o.vervaagd=0" in bospaddenstoel_source_sql
    assert "Meijendel_ndff_secure" not in bospaddenstoel_source_sql
    hns_source_sql = " ".join(module.hns_source_sql().split())
    assert "o.protocol LIKE '12.204%'" in hns_source_sql
    assert "o.soortgroep_raw='Vaatplanten'" in hns_source_sql
    assert "Meijendel_ndff_secure" not in hns_source_sql
    korstmos_source_sql = " ".join(module.korstmos_source_sql().split())
    assert "o.protocol LIKE '02.202%'" in korstmos_source_sql
    assert "o.soortgroep_raw='Korstmossen'" in korstmos_source_sql
    assert "o.vervaagd=0" in korstmos_source_sql
    assert "Meijendel_ndff_secure" not in korstmos_source_sql
    assert "Er is een 03.201-bezoek zonder waargenomen dagvlinder aangetroffen." not in importer_text
    module.validate_vlinder_reconstruction(dict(module.VLINDER_RECONSTRUCTION_EXPECTED))
    broken_vlinder = dict(module.VLINDER_RECONSTRUCTION_EXPECTED)
    broken_vlinder["zero_rows"] -= 1
    try:
        module.validate_vlinder_reconstruction(broken_vlinder)
    except ValueError:
        pass
    else:
        raise AssertionError("Een afwijkende vlinderreconstructie is niet geblokkeerd")
    module.validate_vliesvleugel_reconstruction(
        dict(module.VLIESVLEUGEL_RECONSTRUCTION_EXPECTED)
    )
    broken_vliesvleugel = dict(module.VLIESVLEUGEL_RECONSTRUCTION_EXPECTED)
    broken_vliesvleugel["positive_rows"] -= 1
    try:
        module.validate_vliesvleugel_reconstruction(broken_vliesvleugel)
    except ValueError:
        pass
    else:
        raise AssertionError("Een afwijkende vliesvleugelreconstructie is niet geblokkeerd")
    module.validate_libel_reconstruction(dict(module.LIBEL_RECONSTRUCTION_EXPECTED))
    broken_libel = dict(module.LIBEL_RECONSTRUCTION_EXPECTED)
    broken_libel["coarse_only_visits"] -= 1
    try:
        module.validate_libel_reconstruction(broken_libel)
    except ValueError:
        pass
    else:
        raise AssertionError("Een afwijkende libellenreconstructie is niet geblokkeerd")
    module.validate_reptile_reconstruction(dict(module.REPTILE_RECONSTRUCTION_EXPECTED))
    broken_reptile = dict(module.REPTILE_RECONSTRUCTION_EXPECTED)
    broken_reptile["zero_rows"] -= 1
    try:
        module.validate_reptile_reconstruction(broken_reptile)
    except ValueError:
        pass
    else:
        raise AssertionError("Een afwijkende reptielenreconstructie is niet geblokkeerd")
    module.validate_amphibian_reconstruction(dict(module.AMPHIBIAN_RECONSTRUCTION_EXPECTED))
    broken_amphibian = dict(module.AMPHIBIAN_RECONSTRUCTION_EXPECTED)
    broken_amphibian["year_aggregate_records"] -= 1
    try:
        module.validate_amphibian_reconstruction(broken_amphibian)
    except ValueError:
        pass
    else:
        raise AssertionError("Een afwijkende amfibieënreconstructie is niet geblokkeerd")
    module.validate_bat_reconstruction(dict(module.BAT_RECONSTRUCTION_EXPECTED))
    broken_bats = dict(module.BAT_RECONSTRUCTION_EXPECTED)
    broken_bats["suppressed_duplicates"] -= 1
    try:
        module.validate_bat_reconstruction(broken_bats)
    except ValueError:
        pass
    else:
        raise AssertionError("Een afwijkende vleermuisreconstructie is niet geblokkeerd")
    module.validate_rabbit_reconstruction(dict(module.RABBIT_RECONSTRUCTION_EXPECTED))
    broken_rabbit = dict(module.RABBIT_RECONSTRUCTION_EXPECTED)
    broken_rabbit["derived_zero_rows"] += 1
    try:
        module.validate_rabbit_reconstruction(broken_rabbit)
    except ValueError:
        pass
    else:
        raise AssertionError("Een afwijkende konijnentellingclassificatie is niet geblokkeerd")
    module.validate_daz_bmp_reconstruction(dict(module.DAZ_BMP_RECONSTRUCTION_EXPECTED))
    broken_daz = dict(module.DAZ_BMP_RECONSTRUCTION_EXPECTED)
    broken_daz["true_zero_rows"] -= 1
    try:
        module.validate_daz_bmp_reconstruction(broken_daz)
    except ValueError:
        pass
    else:
        raise AssertionError("Een afwijkende DAZ-BMP-reconstructie is niet geblokkeerd")
    module.validate_zeereep_reconstruction(dict(module.ZEEREEP_RECONSTRUCTION_EXPECTED))
    broken_zeereep = dict(module.ZEEREEP_RECONSTRUCTION_EXPECTED)
    broken_zeereep["true_zero_rows"] -= 1
    try:
        module.validate_zeereep_reconstruction(broken_zeereep)
    except ValueError:
        pass
    else:
        raise AssertionError("Een afwijkende zeereeppaddenstoelenreconstructie is niet geblokkeerd")
    module.validate_bospaddenstoel_reconstruction(
        dict(module.BOSPADDENSTOEL_RECONSTRUCTION_EXPECTED)
    )
    broken_bospaddenstoel = dict(module.BOSPADDENSTOEL_RECONSTRUCTION_EXPECTED)
    broken_bospaddenstoel["duplicate_presence_records"] -= 1
    try:
        module.validate_bospaddenstoel_reconstruction(broken_bospaddenstoel)
    except ValueError:
        pass
    else:
        raise AssertionError("Een afwijkende bospaddenstoelenreconstructie is niet geblokkeerd")
    module.validate_hns_reconstruction(dict(module.HNS_RECONSTRUCTION_EXPECTED))
    broken_hns = dict(module.HNS_RECONSTRUCTION_EXPECTED)
    broken_hns["true_zero_rows"] -= 1
    try:
        module.validate_hns_reconstruction(broken_hns)
    except ValueError:
        pass
    else:
        raise AssertionError("Een afwijkende HNS-reconstructie is niet geblokkeerd")
    module.validate_korstmos_reconstruction(dict(module.KORSTMOS_RECONSTRUCTION_EXPECTED))
    broken_korstmos = dict(module.KORSTMOS_RECONSTRUCTION_EXPECTED)
    broken_korstmos["true_zero_rows"] -= 1
    try:
        module.validate_korstmos_reconstruction(broken_korstmos)
    except ValueError:
        pass
    else:
        raise AssertionError("Een afwijkende korstmosreconstructie is niet geblokkeerd")

    # Deze gevallen bewaken de grens tussen doeldata en bijvangst. Een fout in
    # de classificatieregel zou niet-V-analyses ten onrechte toelaten.
    assert module.classify_protocol_group("03.201", "Dagvlinders")["doelrelatie"] == "doelgroep"
    vliesvleugelen = module.classify_protocol_group("03.201", "Vliesvleugeligen")
    assert vliesvleugelen["doelrelatie"] == "doelgroep"
    assert vliesvleugelen["toegestane_typen"] == "PROTOCOL"
    vlies_source_sql = " ".join(module.vliesvleugel_source_sql().split())
    assert "o.soortgroep_raw='Vliesvleugeligen'" in vlies_source_sql
    assert "doel.soortgroep_raw='Vliesvleugeligen'" in vlies_source_sql
    assert "doel.soortgroep_raw='Dagvlinders'" not in vlies_source_sql
    assert module.classify_protocol_group("03.201", "Nachtvlinders")["toegestane_typen"] == "V"
    assert module.classify_protocol_group("14.204", "Zoogdieren (overig)")["doelrelatie"] == "bijvangst"
    assert module.classify_protocol_group("17.204", "Vleermuizen")["doelrelatie"] == "bijvangst"
    assert module.classify_protocol_group("17.204", "Zoogdieren (overig)")["doelrelatie"] == "gemengd"
    assert module.classify_protocol_group("17.209", "Zoogdieren (overig)")["doelrelatie"] == "gemengd"
    assert module.classify_protocol_group("17.208", "Vleermuizen")["doelrelatie"] == "gemengd"
    assert module.classify_protocol_group("102.006", "Vaatplanten")["doelrelatie"] == "algemene_bron"
    assert module.classify_protocol_group("02.204", "Mossen")["doelrelatie"] == "doelgroep"
    assert module.classify_protocol_group("04.006", "Weekdieren")["doelrelatie"] == "gemengd"
    assert module.classify_protocol_group("13.202", "Amfibieën")["doelrelatie"] == "gemengd"
    assert module.classify_protocol_group("10.002", "Amfibieën")["doelrelatie"] == "doelsoortafhankelijk"
    assert module.classify_protocol_group("12.205", "Dagvlinders")["doelrelatie"] == "doelsoortafhankelijk"
    assert len(module.TARGET_DEPENDENT_COMBINATIONS) == 11
    assert len(module.MIXED_COMBINATIONS) == 10
    assert len(module.BOSPADDENSTOEL_TARGET_SPECIES) == 49

    daz_target = module.classify_protocol_species("17.204", "Oryctolagus cuniculus")
    daz_bycatch = module.classify_protocol_species("17.204", "Dama dama")
    rabbit_target = module.classify_protocol_species("17.209", "Oryctolagus cuniculus")
    rabbit_bycatch = module.classify_protocol_species("17.209", "Capreolus capreolus")
    assert daz_target["doelrelatie"] == "doelsoort" and "TA" in daz_target["toegestane_typen"]
    assert daz_bycatch == {"doelrelatie": "bijvangst", "toegestane_typen": "V"}
    assert rabbit_target["doelrelatie"] == "doelsoort" and "TA" in rabbit_target["toegestane_typen"]
    assert rabbit_bycatch == {"doelrelatie": "bijvangst", "toegestane_typen": "V"}
    assert module.classify_protocol_species("04.006", "Vertigo angustior", "Weekdieren")["doelrelatie"] == "doelsoort"
    assert module.classify_protocol_species("04.006", "Punctum pygmaeum", "Weekdieren")["doelrelatie"] == "bijvangst"
    assert module.classify_protocol_species("11.201", "Amanita citrina", "Schimmels")["doelrelatie"] == "doelsoort"
    assert module.classify_protocol_species("11.201", "Fungi sp. indet.", "Schimmels")["doelrelatie"] == "bijvangst"
    assert module.classify_protocol_species("11.202", "Psathyrella ammophila", "Schimmels")["doelrelatie"] == "doelsoort"
    assert module.classify_protocol_species("11.202", "Tulostoma brumale", "Schimmels")["doelrelatie"] == "bijvangst"
    assert module.classify_protocol_species("13.201", "Cobitis taenia", "Vissen")["doelrelatie"] == "doelsoort"
    assert module.classify_protocol_species("13.201", "Perca fluviatilis", "Vissen")["doelrelatie"] == "bijvangst"
    assert module.classify_protocol_species("13.202", "Triturus cristatus", "Amfibieën")["doelrelatie"] == "doelsoort"
    assert module.classify_protocol_species("13.202", "Bufo bufo", "Amfibieën")["doelrelatie"] == "bijvangst"
    assert module.classify_protocol_species("17.202", "Plecotus auritus/austriacus", "Vleermuizen")["doelrelatie"] == "onbepaald"
    assert module.classify_protocol_species("17.202", "Pipistrellus", "Vleermuizen")["doelrelatie"] == "bijvangst"
    assert module.classify_protocol_species("17.208", "Nyctalus noctula", "Vleermuizen")["doelrelatie"] == "doelsoort"
    assert module.classify_protocol_species("17.208", "Myotis daubentonii", "Vleermuizen")["doelrelatie"] == "bijvangst"
    try:
        module.classify_protocol_species("03.201", "Oryctolagus cuniculus")
    except ValueError:
        pass
    else:
        raise AssertionError("Soortclassificatie mag alleen voor gemengde protocollen worden gebruikt")
    assert "not exists" in module.spatial_sql().casefold()
    mapping_sql = module.mapping_sql().casefold()
    assert "expliciet_losse_waarneming" in mapping_sql
    assert "expliciete_code" in mapping_sql
    assert "coalesce(nullif(trim(protocol),''),'losse waarnemingen')" not in mapping_sql
    record_link_sql = module.record_protocol_link_sql().casefold()
    assert "insert into meijendel.ndff_open_waarneming_protocol" in record_link_sql
    assert "insert into meijendel_ndff_secure.ndff_waarneming_protocol" in record_link_sql
    assert "analyse_status" not in record_link_sql
    assert "on duplicate key update" in record_link_sql
    decision_sql = module.decisions_sql().casefold()
    assert "then 'voorlopig_toegelaten'" in decision_sql
    assert "alleen_na_doelsoortselectie" in decision_sql
    assert "ndff_protocol_soortgroep_geschiktheid" in decision_sql
    assert "'niet_beoordeeld'" in decision_sql
    assert "wacht_op_brondata" not in decision_sql
    assert "on duplicate key update" in decision_sql
    assert "ndff-analysebesluit-v4" in decision_sql
    snl_overlap_sql = module.snl_overlap_sql().casefold()
    assert "ndff_snl_waarneming_context" in snl_overlap_sql
    assert "then 'overlap_mogelijk'" in snl_overlap_sql
    assert "then 'onvoldoende_onderzocht'" in snl_overlap_sql
    assert "else 'geen_overlap_gevonden'" in snl_overlap_sql
    assert "overlap_bevestigd" in snl_overlap_sql
    assert "onafhankelijk" not in snl_overlap_sql
    public_pq_sql = module.public_pq_gate_sql().casefold()
    assert "insert into meijendel.ndff_open_pq_koppeling" in public_pq_sql
    assert "update meijendel.ndff_open_waarneming" not in public_pq_sql
    assert "12.007" in public_pq_sql and "12.202" in public_pq_sql
    assert "bronhouder" not in public_pq_sql
    assert "niet_beoordeelbaar" in public_pq_sql
    assert "niet_van_toepassing" in public_pq_sql
    assert "'exact'" not in public_pq_sql
    assert "'onafhankelijk'" not in public_pq_sql
    chain_sql = module.analysis_chain_validation_sql().casefold()
    for required in (
        "v_ndff_canonieke_waarneming",
        "v_ndff_analyse_record",
        "v_ndff_verspreiding_plot_jaar_taxon",
        "v_ndff_trendkandidaat_plot_jaar_taxon",
        "v_ndff_gebruiksdekking_soortgroep_protocol",
        "v_ndff_soortenrijkdom_plot_jaar",
        "v_ndff_eerste_laatste_plot_taxon",
        "v_ndff_verspreidingsverandering_taxon_jaar",
        "v_ndff_dekking_intensiteit_plot_jaar_soortgroep",
        "information_schema.table_privileges",
        "ndff-analyseketen-v1",
    ):
        assert required in chain_sql, required
    module.validate_analysis_chain_metrics(dict(module.ANALYSIS_CHAIN_EXPECTED))
    assert module.parse_analysis_chain_output(
        '{"canonical_records": 810983}\n{"canonical_duplicates": 0}'
    ) == {"canonical_records": 810983, "canonical_duplicates": 0}
    try:
        module.parse_analysis_chain_output('{"duplicate": 1}\n{"duplicate": 1}')
    except ValueError:
        pass
    else:
        raise AssertionError("Dubbele auditmetriek is niet geblokkeerd")
    broken_chain = dict(module.ANALYSIS_CHAIN_EXPECTED)
    broken_chain["canonical_duplicates"] = 1
    try:
        module.validate_analysis_chain_metrics(broken_chain)
    except ValueError:
        pass
    else:
        raise AssertionError("Een afwijkende analyseketen is niet geblokkeerd")
    assert "--audit-live" in IMPORTER.read_text(encoding="utf-8")
    scope_sql = module.protocol_scope_sql().casefold()
    assert "ndff_protocol_soortgroep_geschiktheid" in scope_sql
    assert "ndff_protocol_soort_geschiktheid" in scope_sql
    assert "handleiding-paddenstoelen.pdf" in scope_sql
    assert "handleiding-meetnet-amfibieen-en-vissen" in scope_sql
    legacy_sql = module.restore_legacy_decisions_sql().casefold()
    assert "ndff-protocolkwaliteit-v1" in legacy_sql
    assert "wacht_op_brondata" in legacy_sql
    validation_sql = module.validation_sql().casefold()
    assert "protocolbesluit_mismatch" in validation_sql
    assert "validatie_niet_geparkeerd" in validation_sql
    module.validate_metrics({
        "protocols": 54,
        "uses": 54,
        "mappings": 91,
        "unmapped_open": 0,
        "unmapped_secure": 0,
        "open_records": 810830,
        "secure_records": 14573,
        "open_protocol_links": 810830,
        "secure_protocol_links": 14573,
        "open_loose_records": 430166,
        "open_loose_links": 430166,
        "secure_loose_records": 9660,
        "secure_loose_links": 9660,
        "blank_open_protocol": 0,
        "blank_secure_protocol": 0,
        "invalid_protocol_evidence": 0,
        "spatial": 810830,
        "scope_combinations": 114,
        "mixed_species": 620,
        "dependent_combinations": 11,
        "mixed_species_missing": 0,
        "secure_mixed_species_missing": 0,
        "ambiguous_species": 1,
        "scope_missing": 0,
        "decisions": 1040,
        "protocolbesluit_mismatch": 0,
        "validatie_niet_geparkeerd": 0,
        "snl_records": 6273,
        "snl_overlap_context": 6273,
        "snl_overlap_bevestigd": 0,
        "snl_overlap_mogelijk": 97,
        "snl_geen_overlap_gevonden": 6176,
        "snl_onvoldoende_onderzocht": 0,
        "snl_overlap_ongeldig": 0,
        "open_pq_blocked": 97318,
        "open_pq_not_applicable": 713512,
        "open_pq_unassessed": 0,
    })
    try:
        module.validate_metrics({
            "protocols": 54, "uses": 54, "mappings": 90,
            "unmapped_open": 1, "unmapped_secure": 0,
            "open_records": 810830, "secure_records": 14573,
            "open_protocol_links": 810829, "secure_protocol_links": 14573,
            "open_loose_records": 430166, "open_loose_links": 430165,
            "secure_loose_records": 9660, "secure_loose_links": 9660,
            "blank_open_protocol": 1, "blank_secure_protocol": 0,
            "invalid_protocol_evidence": 1, "spatial": 810829,
            "scope_combinations": 113, "mixed_species": 605, "scope_missing": 1,
            "dependent_combinations": 12, "mixed_species_missing": 1,
            "secure_mixed_species_missing": 1,
            "ambiguous_species": 0,
            "decisions": 1040, "protocolbesluit_mismatch": 1,
            "validatie_niet_geparkeerd": 1,
            "snl_records": 6273, "snl_overlap_context": 6272,
            "snl_overlap_bevestigd": 0, "snl_overlap_mogelijk": 97,
            "snl_geen_overlap_gevonden": 6175,
            "snl_onvoldoende_onderzocht": 0, "snl_overlap_ongeldig": 1,
            "open_pq_blocked": 97317, "open_pq_not_applicable": 713512,
            "open_pq_unassessed": 1,
        })
    except ValueError:
        pass
    else:
        raise AssertionError("Onvolledige kwaliteitslaag is niet geblokkeerd")

    insert_sql = module.catalog_insert_sql(parsed, "abc123")
    assert insert_sql.count("INSERT INTO ndff_protocol ") == 54
    assert insert_sql.count("INSERT INTO ndff_protocol_gebruik ") == 54
    assert "FROM ndff_protocol WHERE protocol_sleutel='01.201' AS nieuw" not in insert_sql
    assert "bronregistratie_niet_toegelaten" not in insert_sql
    assert "ndff-protocolkwaliteit-v1" in insert_sql

    documentation = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (README, DECISIONS, AUDIT, WORK_INSTRUCTION)
    )
    documentation_normalized = " ".join(documentation.split())
    for required_text in (
        "ndff_open_waarneming_protocol",
        "Meijendel_ndff_secure.ndff_waarneming_protocol",
        "expliciete_code",
        "expliciet_losse_waarneming",
        "protocol_sleutel",
        "overlap_bevestigd",
        "overlap_mogelijk",
        "geen_overlap_gevonden",
        "onvoldoende_onderzocht",
        "ndff-analyseketen-v1",
        "--audit-live",
        "verkennende berekeningen",
        "niet als een gevalideerde populatietrend",
        "zeer hoge uitzondering",
        "voorafgaande uitdrukkelijke toestemming",
        "ndff-libellenroute-v1",
        "--audit-libellen",
        "ndff-reptielroute-v1",
        "--audit-reptielen",
        "ndff-amfibiewater-v1",
        "--audit-amfibieen",
        "ndff-vleermuistransect-v1",
        "--audit-vleermuizen",
        "ndff-konijnentelling-v1",
        "--audit-konijnen",
        "geen route- of sectie-id",
        "akoestische detecties",
        "73",
        "ndff-zeereep-v1",
        "--audit-zeereeppaddenstoelen",
        "ndff-hns-v1",
        "--audit-hns",
        "ndff-korstmos-v1",
        "--audit-korstmossen",
    ):
        assert required_text in documentation_normalized, required_text
    assert "analyse_status is geen protocolstatus" in documentation.casefold().replace("`", "")
    architecture = ARCHITECTURE.read_text(encoding="utf-8")
    assert "ndff_open_waarneming_protocol" in architecture
    assert "Meijendel_ndff_secure.ndff_waarneming_protocol" in architecture
    assert "ndff_libel_*" in architecture
    assert "ndff_reptiel_*" in architecture
    assert "ndff_vleermuis_*" in architecture
    assert "ndff_konijn_*" in architecture
    print("OK: NDFF-protocolkwaliteitscontract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
