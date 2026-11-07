#!/usr/bin/env python3
"""Contract voor gebiedsgebonden toegankelijkheid zonder databasewijziging."""

from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis/database/maatregelen_schema.sql"
MIGRATION = ROOT / "gis/scripts/migrate_toegankelijkheidsgebieden.py"
CENTRAL = ROOT / "gis/scripts/import_external_ecology_sources.py"
FEATURE_ID = "2b3ae5c9-1ef6-4d82-9247-470fcc8054f6"


def load(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    assert MIGRATION.is_file(), "migratiescript ontbreekt"
    migration = load(MIGRATION, "toegankelijkheidsgebieden_migration")
    central = load(CENTRAL, "toegankelijkheidsgebieden_central")
    sql = SCHEMA.read_text(encoding="utf-8")
    assert "--skip-column-names" in migration.Client("Meijendel").command()

    required_tables = {
        "toegankelijkheidsstatus",
        "toegankelijkheidsgebied",
        "toegankelijkheidsgebied_versie",
        "toegankelijkheidsgebied_plot_afleiding",
    }
    for table in required_tables:
        assert f"CREATE TABLE IF NOT EXISTS {table}" in sql, table
        assert table in central.CENTRAL_QUERY_SCHEMA, table
    assert "CREATE TABLE IF NOT EXISTS maatregel_toegankelijkheid_registratie" not in sql
    assert "toegang_registratie_id" not in central.CENTRAL_QUERY_SCHEMA["maatregel_registratie_herkomst"]

    assert "DEFAULT '1955-01-01'" in sql
    assert "geldig_tot DATE NULL" in sql
    for status in migration.STATUS_CODES:
        assert status in sql
    assert migration.STATUS_CODES == (
        "afgesloten",
        "toegankelijk",
        "toegankelijk_met_toegangskaart",
    )
    migration.validate_retirement_counts(55, 55)
    migration.validate_retirement_counts(55, 0)
    try:
        migration.validate_retirement_counts(54, 0)
    except RuntimeError:
        pass
    else:
        raise AssertionError("Onvolledige oude tabel werd toegelaten")

    feature = migration.read_area_feature(migration.DEFAULT_GPKG, FEATURE_ID)
    assert feature["status_code"] == "afgesloten"
    assert feature["epsg"] == 28992
    assert feature["geometry_type"] == "MULTIPOLYGON"
    assert feature["is_valid"]
    assert 4_484_000 < feature["oppervlakte_m2"] < 4_485_000
    assert len(feature["geometrie_sha256"]) == 64

    statements = migration.build_migration_statements(feature)
    joined = "\n".join(statements)
    assert "1955-01-01" in joined
    assert FEATURE_ID in joined
    assert "DELETE FROM maatregel_registratie_herkomst" in joined
    assert "DROP TABLE maatregel_toegankelijkheid_registratie" in joined
    assert "maatregel_plot_jaar_registratie" not in joined
    assert "DELETE FROM maatregel_bron" not in joined
    assert "ST_Dimension(ST_Intersection(v.geometrie,p.geom))=2" in joined
    assert "AND ST_Area(ST_Intersection(v.geometrie,p.geom))>0" not in joined

    print("OK: toegankelijkheidsgebieden-contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
