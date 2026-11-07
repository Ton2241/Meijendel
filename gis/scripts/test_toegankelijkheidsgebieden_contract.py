#!/usr/bin/env python3
"""Contract voor gebiedsgebonden toegankelijkheid zonder databasewijziging."""

from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis/database/maatregelen_schema.sql"
MIGRATION = ROOT / "gis/scripts/migrate_toegankelijkheidsgebieden.py"
CENTRAL = ROOT / "gis/scripts/import_external_ecology_sources.py"
FEATURE_ID = "garmin_activity_24999201739_routepunten_160_5470"


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

    assert migration.backup_tables(False) == (
        "maatregel_bron",
        "toegankelijkheidsgebied",
        "toegankelijkheidsgebied_versie",
        "toegankelijkheidsgebied_plot_afleiding",
    )

    feature = migration.derive_route_area(migration.DEFAULT_ROUTE_GPKG)
    assert feature["status_code"] == "afgesloten"
    assert feature["epsg"] == 28992
    assert feature["geometry_type"] == "MULTIPOLYGON"
    assert feature["is_valid"]
    assert 4_483_000 < feature["oppervlakte_m2"] < 4_484_000
    assert feature["sluitafstand_m"] < 5
    assert feature["toegangsspoor_afstand_m"] > 50
    assert len(feature["geometrie_sha256"]) == 64

    plot_areas = migration.read_plot_areas(migration.DEFAULT_REFERENCE_GPKG)
    assert [(area["gebied_code"], area["status_code"], area["kavels"]) for area in plot_areas] == [
        ("buitenduin_noord_1955", "afgesloten", ("M13", "M13s", "M14", "M15", "M16", "M16s", "M17a")),
        ("haagsche_golfclub_1955", "toegankelijk", ("M66",)),
        ("hertenkamp_1955", "toegankelijk", ("M105",)),
        ("kavel_m77_1955", "toegankelijk", ("M77",)),
        ("kavel_m78_79_1955", "toegankelijk", ("M78/79",)),
        ("kavel_m75a_1955", "toegankelijk", ("M75a",)),
        ("kavel_m31_1955", "toegankelijk", ("M31",)),
    ]
    for plot_area in plot_areas:
        assert plot_area["geometry_type"] == "MULTIPOLYGON"
        assert plot_area["is_valid"]
        assert plot_area["oppervlakte_m2"] > 0

    mixed = migration.ogr.CreateGeometryFromWkt(
        "GEOMETRYCOLLECTION(POLYGON((0 0,10 0,10 10,0 10,0 0)),LINESTRING(0 0,10 10))"
    )
    assert migration.polygonal_area(mixed) == 100
    assert not migration.storable_intersection(0.0004, 100)
    assert not migration.storable_intersection(0.001, 500_000)
    assert migration.storable_intersection(1.0, 500_000)

    statements = migration.build_migration_statements(feature, plot_areas)
    joined = "\n".join(statements)
    assert "1955-01-01" in joined
    assert FEATURE_ID in joined
    assert "DELETE FROM maatregel_registratie_herkomst" in joined
    assert "DROP TABLE maatregel_toegankelijkheid_registratie" in joined
    assert "maatregel_plot_jaar_registratie" not in joined
    assert "DELETE FROM maatregel_bron" not in joined
    assert "buitenduin_noord_1955" in joined
    assert "haagsche_golfclub_1955" in joined
    assert "hertenkamp_1955" in joined
    assert "kavel_m77_1955" in joined
    assert "kavel_m78_79_1955" in joined
    assert "kavel_m75a_1955" in joined
    assert "kavel_m31_1955" in joined
    assert "plots:M13,M13s,M14,M15,M16,M16s,M17a" in joined

    print("OK: toegankelijkheidsgebieden-contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
