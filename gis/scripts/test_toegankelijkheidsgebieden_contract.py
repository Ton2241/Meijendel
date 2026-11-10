#!/usr/bin/env python3
"""Contract voor gebiedsgebonden toegankelijkheid zonder databasewijziging."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile


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
        "toegankelijk_buiten_broedseizoen",
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
        "toegankelijkheidsstatus",
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
    assert feature["interne_ringen"] == 0

    plot_areas = migration.read_plot_areas(migration.DEFAULT_REFERENCE_GPKG)
    assert [(area["gebied_code"], area["status_code"], area["kavels"]) for area in plot_areas] == [
        ("buitenduin_noord_1955", "afgesloten", ("M13", "M13s", "M14", "M15", "M16", "M16s", "M17a")),
        ("haagsche_golfclub_1955", "toegankelijk", ("M66",)),
        ("hertenkamp_1955", "toegankelijk", ("M105",)),
        ("buitenduin_noord_toegankelijk_1955", "toegankelijk", ("M77", "M78/79", "M75a")),
        ("kavel_m31_1955", "toegankelijk", ("M31",)),
        ("buitenduin_zuid_broedseizoen_1955", "toegankelijk_buiten_broedseizoen", ("M35", "M36")),
        ("ruygenhoek_afgesloten_1955", "afgesloten", ("M32", "M33")),
        ("kavel_m34_1955", "toegankelijk", ("M34",)),
    ]
    for plot_area in plot_areas:
        assert plot_area["geometry_type"] == "MULTIPOLYGON"
        assert plot_area["is_valid"]
        assert plot_area["oppervlakte_m2"] > 0
        assert plot_area["interne_ringen"] == 0

    # Een smalle, naar de buitenrand open naad tussen twee kavels is geen
    # statusgrens. De gerichte sluiting moet die naad vullen zonder een
    # binnenring achter te laten.
    seamed = migration.ogr.CreateGeometryFromWkt(
        "POLYGON((0 0,10 0,10 10,6.5 10,6.5 2,3.5 2,3.5 10,0 10,0 0))"
    )
    closed = migration.close_narrow_seams(seamed, 2.0)
    seam_point = migration.ogr.CreateGeometryFromWkt("POINT(5 5)")
    assert closed.Contains(seam_point)
    assert sum(
        max(0, part.GetGeometryCount() - 1)
        for part in migration._polygon_parts(closed)
    ) == 0

    north = plot_areas[0]
    assert north["naad_sluiting_m"] == 2.0
    assert 50 < north["naad_oppervlakte_m2"] < 53
    north_geometry = migration.ogr.CreateGeometryFromWkt(north["wkt"])
    assert 7_800 < north_geometry.Boundary().Length() < 8_000

    mixed = migration.ogr.CreateGeometryFromWkt(
        "GEOMETRYCOLLECTION(POLYGON((0 0,10 0,10 10,0 10,0 0)),LINESTRING(0 0,10 10))"
    )
    assert migration.polygonal_area(mixed) == 100
    assert not migration.storable_intersection(0.0004, 100)
    assert not migration.storable_intersection(0.001, 500_000)
    assert migration.storable_intersection(1.0, 500_000)

    with tempfile.TemporaryDirectory() as temporary_directory:
        gpx_path = Path(temporary_directory) / "boundary.gpx"
        gpx_path.write_text(
            """<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="contract" xmlns="http://www.topografix.com/GPX/1/1">
  <trk><name>grens</name><trkseg>
    <trkpt lat="52.1327" lon="4.3559"><time>2026-11-09T14:07:58Z</time></trkpt>
    <trkpt lat="52.1340" lon="4.3400"><time>2026-11-09T14:40:00Z</time></trkpt>
    <trkpt lat="52.1352" lon="4.3310"><time>2026-11-09T15:02:32Z</time></trkpt>
  </trkseg></trk>
</gpx>
""",
            encoding="utf-8",
        )
        boundary_source = migration.read_gpx_boundary(gpx_path)
        selected_boundary = migration.read_gpx_boundary(
            gpx_path,
            start_point_id=1,
            end_point_id=2,
        )
    assert boundary_source["punt_aantal"] == 3
    assert boundary_source["start_punt_id"] == 0
    assert boundary_source["eind_punt_id"] == 2
    assert boundary_source["start_tijd"] == "2026/11/09 14:07:58+00"
    assert boundary_source["eind_tijd"] == "2026/11/09 15:02:32+00"
    assert boundary_source["geometry"].GetSpatialReference().GetAuthorityCode(None) == "28992"
    boundary_x, boundary_y, _ = boundary_source["geometry"].GetPoint(0)
    assert 80_000 < boundary_x < 90_000
    assert 460_000 < boundary_y < 470_000
    assert len(boundary_source["bron_sha256"]) == 64
    assert selected_boundary["punt_aantal"] == 2
    assert selected_boundary["start_punt_id"] == 1
    assert selected_boundary["eind_punt_id"] == 2
    assert migration.BIERLAP_BOUNDARY_START_POINT_ID == 0
    assert migration.BIERLAP_BOUNDARY_END_POINT_ID == 396
    assert migration.BIERLAP_CURVE_CONTROL_POINTS_RD == (
        (83095.6, 461162.4),
        (83020.1, 461316.3),
    )
    assert migration.BIERLAP_M6_ENDPOINT_RD == (83147.280, 461439.310)
    assert migration.BIERLAP_CURVE_SAMPLES == 96

    land_boundary = migration.ogr.CreateGeometryFromWkt("LINESTRING(10 0,5 0)")
    water_closure = migration.ogr.CreateGeometryFromWkt("LINESTRING(5 0,3 2,0 2)")
    composite = migration.compose_boundary_with_closure(land_boundary, water_closure)
    assert composite.GetPointCount() == 4
    assert composite.GetPoint(0)[:2] == (10.0, 0.0)
    assert composite.GetPoint(3)[:2] == (0.0, 2.0)
    # Een bevestigd grenssegment van oost naar west snijdt alleen de
    # gedeeltelijke kavel. De volledige noordelijke kavels blijven geheel
    # behouden; van de doorsneden kavel blijft uitsluitend het noorddeel over.
    full_plot = migration.ogr.CreateGeometryFromWkt(
        "POLYGON((10 0,20 0,20 10,10 10,10 0))"
    )
    split_plot = migration.ogr.CreateGeometryFromWkt(
        "POLYGON((0 0,10 0,10 10,0 10,0 0))"
    )
    boundary = migration.ogr.CreateGeometryFromWkt("LINESTRING(12 4,-2 4)")
    north_area = migration.build_north_of_boundary_area(full_plot, split_plot, boundary)
    assert north_area.IsValid()
    assert abs(north_area.GetArea() - 160) < 0.000001
    assert north_area.Contains(migration.ogr.CreateGeometryFromWkt("POINT(5 8)"))
    assert not north_area.Contains(migration.ogr.CreateGeometryFromWkt("POINT(5 2)"))
    assert north_area.Contains(migration.ogr.CreateGeometryFromWkt("POINT(15 5)"))

    slivered = migration.ogr.CreateGeometryFromWkt(
        "MULTIPOLYGON(((0 0,10 0,10 10,0 10,0 0)),"
        "((20 20,20.5 20,20.5 20.5,20 20.5,20 20)))"
    )
    single = migration.single_polygon_without_slivers(slivered, 1.0)
    assert len(list(migration._polygon_parts(single))) == 1
    assert abs(single.GetArea() - 100) < 0.000001

    bierlap = migration.derive_bierlap_kijfhoek_area(
        migration.DEFAULT_REFERENCE_GPKG,
        migration.DEFAULT_BIERLAP_BOUNDARY_GPX,
    )
    bierlap_geometry = migration.ogr.CreateGeometryFromWkt(bierlap["wkt"])
    intended = set(bierlap["kavels"])
    all_plots = migration.read_all_plot_geometries(migration.DEFAULT_REFERENCE_GPKG)
    assert bierlap["grens_punt_aantal"] == 397
    assert bierlap["waterlijn_punt_aantal"] == 97
    assert bierlap["waterlijn_m6_aansluiting_m"] < 0.001
    assert abs(bierlap["oppervlakte_m2"] - 5_551_561.507) < 0.01
    assert bierlap["geometrie_sha256"] == "e9310c6713f4da9acd273ec75880f944631f81f728d00c13013ff19d159e1d0d"
    assert abs(bierlap["gedeeltelijke_kavel_aandelen_pct"]["M4-5"] - 31.502056) < 0.00001, bierlap["gedeeltelijke_kavel_aandelen_pct"]
    assert abs(bierlap["gedeeltelijke_kavel_aandelen_pct"]["M62"] - 96.539888) < 0.00001, bierlap["gedeeltelijke_kavel_aandelen_pct"]
    for kavel in bierlap["volledige_kavels"]:
        coverage = 100 * migration.polygonal_area(
            bierlap_geometry.Intersection(all_plots[kavel])
        ) / all_plots[kavel].GetArea()
        assert coverage > 99.9999, (kavel, coverage)
    assert intended == set(bierlap["volledige_kavels"]) | {"M62", "M4-5"}

    m45 = migration.derive_m45_closed_area(
        migration.DEFAULT_REFERENCE_GPKG,
        migration.DEFAULT_M45_ACCEPTED_GPKG,
    )
    assert m45["gebied_code"] == "m4_5_afgesloten_1955"
    assert m45["naam"] == "Afgesloten gebied bij M4-5"
    assert m45["status_code"] == "afgesloten"
    assert m45["kavels"] == ("M4-5",)
    assert m45["volledige_kavels"] == ()
    assert m45["gedeeltelijke_kavels"] == ("M4-5",)
    assert abs(m45["oppervlakte_m2"] - 166_459.008781) < 0.01
    assert m45["bron_geometrie_sha256"] == "37d0cbaf52ac03dfb3309c53b9c51fa77c6d4a92d51defeeda0a1d6935d30af4"
    assert m45["geometrie_sha256"] == "e525ca53664e1941a2ec6c232ab10fc1a180f36d5775dd86ee6e9a2cc0c78b11"
    assert abs(m45["gedeeltelijke_kavel_aandelen_pct"]["M4-5"] - 61.446186) < 0.00001

    harstenhoek = migration.derive_harstenhoek_closed_area(
        migration.DEFAULT_REFERENCE_GPKG,
        migration.DEFAULT_HARSTENHOEK_ACCEPTED_GPKG,
    )
    assert harstenhoek["gebied_code"] == "harstenhoek_afgesloten_1955"
    assert harstenhoek["naam"] == "Afgesloten gebied Harstenhoek"
    assert harstenhoek["status_code"] == "afgesloten"
    assert harstenhoek["kavels"] == ("M42",)
    assert harstenhoek["volledige_kavels"] == ()
    assert harstenhoek["gedeeltelijke_kavels"] == ("M42",)
    assert abs(harstenhoek["oppervlakte_m2"] - 322_677.870557) < 0.01
    assert harstenhoek["bron_geometrie_sha256"] == "49d49027a5fccdbeb418b7993b43bcf3e0133c3f8598c1d3354207f26a836f90"
    assert harstenhoek["geometrie_sha256"] == "0984642f609bd45ba2a0cf92e032cd456ea3f0e24224b7ff3e44fadd651ce8e9"
    assert abs(harstenhoek["gedeeltelijke_kavel_aandelen_pct"]["M42"] - 78.824723) < 0.00001

    adjusted_feature, adjusted_areas = migration.apply_accepted_fietspad_corridor(
        feature,
        plot_areas + [bierlap, m45, harstenhoek],
        migration.DEFAULT_FIETSPAD_CORRIDOR_GPKG,
    )
    corridor = next(
        area for area in adjusted_areas
        if area["gebied_code"] == migration.FIETSPAD_CORRIDOR_AREA_CODE
    )
    assert adjusted_feature["corridor_adjusted"]
    assert len(adjusted_areas) == 12
    assert corridor["status_code"] == "toegankelijk"
    assert corridor["bron_code"] == migration.FIETSPAD_CORRIDOR_SOURCE_CODE
    assert abs(corridor["oppervlakte_m2"] - 94_579.891) < 0.01
    assert corridor["interne_ringen"] == 0
    corridor_geometry = migration.ogr.CreateGeometryFromWkt(corridor["wkt"])
    unchanged_codes = {"haagsche_golfclub_1955", "hertenkamp_1955"}
    for area in [adjusted_feature, *adjusted_areas]:
        if area["gebied_code"] == migration.FIETSPAD_CORRIDOR_AREA_CODE:
            continue
        assert area["corridor_adjusted"] == (area["gebied_code"] not in unchanged_codes)
        geometry = migration.ogr.CreateGeometryFromWkt(area["wkt"])
        assert migration.polygonal_area(geometry.Intersection(corridor_geometry)) < 0.001
    assert sum(area.get("corridor_adjusted", False) for area in [adjusted_feature, *adjusted_areas]) == 10

    statements = migration.build_migration_statements(adjusted_feature, adjusted_areas)
    joined = "\n".join(statements)
    assert "1955-01-01" in joined
    assert adjusted_feature["feature_id"] in joined
    assert "DELETE FROM maatregel_registratie_herkomst" in joined
    assert "DROP TABLE maatregel_toegankelijkheid_registratie" in joined
    assert "maatregel_plot_jaar_registratie" not in joined
    assert "DELETE FROM maatregel_bron" not in joined
    assert "buitenduin_noord_1955" in joined
    assert "haagsche_golfclub_1955" in joined
    assert "hertenkamp_1955" in joined
    assert "buitenduin_noord_toegankelijk_1955" in joined
    assert "DELETE FROM v USING toegankelijkheidsgebied_versie" in joined
    assert (
        "DELETE FROM v USING toegankelijkheidsgebied_versie v "
        "JOIN toegankelijkheidsgebied g USING(gebied_id) "
        "WHERE g.gebied_code='bierlap_kijfhoek_dagkaart_1955'"
    ) in statements
    assert (
        "DELETE FROM v USING toegankelijkheidsgebied_versie v "
        "JOIN toegankelijkheidsgebied g USING(gebied_id) "
        "WHERE g.gebied_code='m4_5_afgesloten_1955'"
    ) in statements
    assert "mymaps_grensregistratie_20261110" in joined
    assert "m4_5_afgesloten_1955" in joined
    assert "37d0cbaf52ac03dfb3309c53b9c51fa77c6d4a92d51defeeda0a1d6935d30af4" in joined
    assert "mymaps_harstenhoek_20261110" in joined
    assert "harstenhoek_afgesloten_1955" in joined
    assert "49d49027a5fccdbeb418b7993b43bcf3e0133c3f8598c1d3354207f26a836f90" in joined
    assert migration.FIETSPAD_CORRIDOR_SOURCE_CODE in joined
    assert migration.FIETSPAD_CORRIDOR_AREA_CODE in joined
    assert "kavel_m77_1955" in joined
    assert "kavel_m78_79_1955" in joined
    assert "kavel_m75a_1955" in joined
    assert "kavel_m31_1955" in joined
    assert "buitenduin_zuid_broedseizoen_1955" in joined
    assert "plots:M35,M36" in joined
    assert "ruygenhoek_afgesloten_1955" in joined
    assert "plots:M32,M33" in joined
    assert "kavel_m34_1955" in joined
    assert "plots:M34" in joined
    assert "plots:M13,M13s,M14,M15,M16,M16s,M17a" in joined

    print("OK: toegankelijkheidsgebieden-contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
