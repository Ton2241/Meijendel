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
    for table in (
        "ndff_protocol",
        "ndff_protocol_mapping",
        "ndff_protocol_gebruik",
        "ndff_open_ruimtelijke_beoordeling",
        "ndff_analysebesluit",
    ):
        assert f"create table if not exists {table}" in folded, table
    assert "create table if not exists meijendel.ndff_open_waarneming_protocol" in folded
    assert "create table if not exists meijendel_ndff_secure.ndff_waarneming_protocol" in folded
    assert "enum('expliciete_code','expliciet_losse_waarneming')" in folded
    assert "'voorlopig_toegelaten'" in folded

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
    assert module.DECISION_RULE_VERSION == "ndff-analysebesluit-v2"
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
    assert "'niet_beoordeeld'" in decision_sql
    assert "wacht_op_brondata" not in decision_sql
    assert "on duplicate key update" in decision_sql
    assert "ndff-analysebesluit-v2" in decision_sql
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
        "decisions": 1040,
        "protocolbesluit_mismatch": 0,
        "validatie_niet_geparkeerd": 0,
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
            "decisions": 1040, "protocolbesluit_mismatch": 1,
            "validatie_niet_geparkeerd": 1,
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
    for required_text in (
        "ndff_open_waarneming_protocol",
        "Meijendel_ndff_secure.ndff_waarneming_protocol",
        "expliciete_code",
        "expliciet_losse_waarneming",
        "protocol_sleutel",
    ):
        assert required_text in documentation, required_text
    assert "analyse_status is geen protocolstatus" in documentation.casefold().replace("`", "")
    architecture = ARCHITECTURE.read_text(encoding="utf-8")
    assert "ndff_open_waarneming_protocol" in architecture
    assert "Meijendel_ndff_secure.ndff_waarneming_protocol" in architecture
    print("OK: NDFF-protocolkwaliteitscontract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
