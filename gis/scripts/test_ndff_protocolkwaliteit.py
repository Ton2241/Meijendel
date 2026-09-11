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
        "meijendel_ndff_secure.ndff_vlinder_routefamilie",
        "meijendel_ndff_secure.ndff_vlinder_routegeometrie",
        "meijendel_ndff_secure.ndff_vlinder_bezoek",
        "meijendel_ndff_secure.ndff_vlinder_bezoek_taxon",
    ):
        assert f"create table if not exists {table}" in folded, table
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
        visits={"v1": 1, "v2": None},
        target_taxa=("Aglais urticae", "Pieris napi"),
        observations={
            ("v1", "Aglais urticae"): 3,
            ("v2", "Pieris napi"): 2,
        },
    )
    assert len(matrix) == 4
    assert {(row["visit"], row["taxon"]): (row["count"], row["status"])
            for row in matrix} == {
        ("v1", "Aglais urticae"): (3, "waargenomen"),
        ("v1", "Pieris napi"): (0, "echte_nul"),
        ("v2", "Aglais urticae"): (0, "echte_nul"),
        ("v2", "Pieris napi"): (2, "waargenomen"),
    }
    assert module.VLINDER_ROUTE_RULE_VERSION == "ndff-vlinderroute-v1"
    importer_text = IMPORTER.read_text(encoding="utf-8")
    assert "--reconstruct-vlinders" in importer_text
    assert "--audit-vlinders" in importer_text
    assert "03.201" in importer_text
    assert "soortgroep_raw='Dagvlinders'" in importer_text
    module.validate_vlinder_reconstruction(dict(module.VLINDER_RECONSTRUCTION_EXPECTED))
    broken_vlinder = dict(module.VLINDER_RECONSTRUCTION_EXPECTED)
    broken_vlinder["zero_rows"] -= 1
    try:
        module.validate_vlinder_reconstruction(broken_vlinder)
    except ValueError:
        pass
    else:
        raise AssertionError("Een afwijkende vlinderreconstructie is niet geblokkeerd")

    # Deze gevallen bewaken de grens tussen doeldata en bijvangst. Een fout in
    # de classificatieregel zou niet-V-analyses ten onrechte toelaten.
    assert module.classify_protocol_group("03.201", "Dagvlinders")["doelrelatie"] == "doelgroep"
    assert module.classify_protocol_group("03.201", "Vliesvleugeligen")["doelrelatie"] == "bijvangst"
    assert module.classify_protocol_group("03.201", "Nachtvlinders")["toegestane_typen"] == "V"
    assert module.classify_protocol_group("14.204", "Zoogdieren (overig)")["doelrelatie"] == "bijvangst"
    assert module.classify_protocol_group("17.204", "Vleermuizen")["doelrelatie"] == "bijvangst"
    assert module.classify_protocol_group("17.204", "Zoogdieren (overig)")["doelrelatie"] == "gemengd"
    assert module.classify_protocol_group("17.209", "Zoogdieren (overig)")["doelrelatie"] == "gemengd"
    assert module.classify_protocol_group("102.006", "Vaatplanten")["doelrelatie"] == "algemene_bron"
    assert module.classify_protocol_group("02.204", "Mossen")["doelrelatie"] == "doelgroep"
    assert module.classify_protocol_group("04.006", "Weekdieren")["doelrelatie"] == "gemengd"
    assert module.classify_protocol_group("13.202", "Amfibieën")["doelrelatie"] == "gemengd"
    assert module.classify_protocol_group("10.002", "Amfibieën")["doelrelatie"] == "doelsoortafhankelijk"
    assert module.classify_protocol_group("12.205", "Dagvlinders")["doelrelatie"] == "doelsoortafhankelijk"
    assert len(module.TARGET_DEPENDENT_COMBINATIONS) == 11
    assert len(module.MIXED_COMBINATIONS) == 9
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
        "mixed_species": 606,
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
    ):
        assert required_text in documentation_normalized, required_text
    assert "analyse_status is geen protocolstatus" in documentation.casefold().replace("`", "")
    architecture = ARCHITECTURE.read_text(encoding="utf-8")
    assert "ndff_open_waarneming_protocol" in architecture
    assert "Meijendel_ndff_secure.ndff_waarneming_protocol" in architecture
    print("OK: NDFF-protocolkwaliteitscontract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
