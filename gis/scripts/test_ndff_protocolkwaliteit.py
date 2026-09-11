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
    parsed = module.read_seed(SEED)
    assert len(parsed) == 54
    assert module.protocol_key("Geen code") == "LOS"
    assert module.protocol_key("03.201") == "03.201"
    assert module.protocol_code_from_raw("03.201 Landelijk Meetnet Vlinders (NEM)") == "03.201"
    assert module.protocol_code_from_raw(None) == "LOS"
    assert module.protocol_code_from_raw("") == "LOS"
    assert module.protocol_code_from_raw("Losse waarnemingen") == "LOS"
    assert module.conditional_types("TV / TA met volledige geschikte bezoekgegevens") == {"TV", "TA"}
    assert module.conditional_types(None) == set()
    assert module.sql_text("", empty_as_null=False) == "''"
    assert "not exists" in module.spatial_sql().casefold()
    decision_sql = module.decisions_sql().casefold()
    assert "then 'wacht_op_brondata'" in decision_sql
    assert "on duplicate key update" in decision_sql
    assert "analysetype<>'v' and eindbesluit='toegelaten'" in module.validation_sql().casefold()
    module.validate_metrics({
        "protocols": 54,
        "uses": 54,
        "mappings": 91,
        "unmapped_open": 0,
        "unmapped_secure": 0,
        "open_records": 810830,
        "spatial": 810830,
        "decisions": 1040,
        "admitted_non_distribution": 0,
    })
    try:
        module.validate_metrics({
            "protocols": 54, "uses": 54, "mappings": 90,
            "unmapped_open": 1, "unmapped_secure": 0,
            "open_records": 810830, "spatial": 810829,
            "decisions": 1040, "admitted_non_distribution": 0,
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
    print("OK: NDFF-protocolkwaliteitscontract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
