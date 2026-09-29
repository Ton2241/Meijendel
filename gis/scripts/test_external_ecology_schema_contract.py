#!/usr/bin/env python3
"""Contracttest voor de generieke externe ecologiebron-tabellen."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis" / "database" / "external_ecology_schema.sql"


def main() -> int:
    sql = SCHEMA.read_text(encoding="utf-8")
    required_tables = (
        "lvd_dataset",
        "lvd_event",
        "lvd_resultaat",
        "lvd_overlap",
    )
    for table in required_tables:
        assert f"CREATE TABLE IF NOT EXISTS {table}" in sql, table
    assert "CREATE TABLE IF NOT EXISTS externe_ecologie_" not in sql
    for field in (
        "bron_event_id",
        "bron_occurrence_id",
        "wetenschappelijke_naam_bron",
        "ruimtelijke_klasse",
        "analyse_status",
        "coordinate_uncertainty_m",
        "occurrence_status",
        "hoeveelheid_eenheid",
        "bronmetadata",
        "event_datum_tot",
        "datum_precisie",
    ):
        assert field in sql, field
    assert "CREATE OR REPLACE VIEW v_externe_ecologie_analyse" in sql
    assert "Meijendel_bronnen" not in sql
    print("OK: LVD-schemacontract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
