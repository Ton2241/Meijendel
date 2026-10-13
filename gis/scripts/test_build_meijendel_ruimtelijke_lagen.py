#!/usr/bin/env python3
"""Contracttests voor de ruimtelijke basislagen van Meijendel."""

from __future__ import annotations

import importlib.util
from pathlib import Path

from osgeo import gdal, ogr


ROOT = Path(__file__).parents[2]
BUILDER = ROOT / "gis" / "scripts" / "build_meijendel_ruimtelijke_lagen.py"
IMPORTER = ROOT / "gis" / "scripts" / "import_meijendel_ruimtelijke_lagen.py"
SCHEMA = ROOT / "gis" / "database" / "meijendel_ruimtelijke_lagen_schema.sql"
DOC = ROOT / "docs" / "bronnen" / "importbesluiten" / "MEIJENDEL_RUIMTELIJKE_LAGEN.md"


def load_builder():
    spec = importlib.util.spec_from_file_location("meijendel_ruimtelijke_lagen", BUILDER)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_importer():
    spec = importlib.util.spec_from_file_location("import_meijendel_ruimtelijke_lagen", IMPORTER)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def polygon(xmin: float, ymin: float, xmax: float, ymax: float) -> ogr.Geometry:
    ring = ogr.Geometry(ogr.wkbLinearRing)
    for x, y in (
        (xmin, ymin),
        (xmax, ymin),
        (xmax, ymax),
        (xmin, ymax),
        (xmin, ymin),
    ):
        ring.AddPoint_2D(x, y)
    geometry = ogr.Geometry(ogr.wkbPolygon)
    geometry.AddGeometry(ring)
    return geometry


def main() -> int:
    module = load_builder()
    importer = load_importer()

    assert module.BOUNDARY_ROADS == (
        "De Wassenaarse Slag",
        "Katwijkseweg",
        "Storm van 's-Gravesandeweg",
        "Jagerslaan",
        "Groot Haesebroekseweg",
        "Buurtweg",
        "Landscheidingsweg",
        "Van Alkemadelaan",
        "Zwolsestraat",
        "Groningsestraat",
        "Gevers Deynootweg",
    )

    area = polygon(0, 0, 10, 10)
    inside = ogr.Geometry(ogr.wkbPoint)
    inside.AddPoint_2D(5, 5)
    outside = ogr.Geometry(ogr.wkbPoint)
    outside.AddPoint_2D(20, 20)
    crossing = polygon(9, 9, 11, 11)
    assert module.classify_relation(inside, area) == "volledig_binnen"
    assert module.classify_relation(crossing, area) == "raakt_grens"
    assert module.classify_relation(outside, area) == "buiten"
    assert module.classify_relation(None, area) == "geen_geometrie"

    official_natura = polygon(5, 5, 15, 15)
    meijendel_natura = module.clip_natura_to_project(official_natura, area)
    assert round(meijendel_natura.GetArea(), 6) == 25.0
    assert meijendel_natura.Within(area)

    plot_west = polygon(-2, 2, 2, 4)
    plot_north = polygon(6, 8, 8, 12)
    expanded = module.expand_project_with_plots(area, [plot_west, plot_north])
    assert round(area.GetArea(), 6) == 100.0
    assert 108.0 < expanded.GetArea() < 109.0
    assert area.Within(expanded)
    assert plot_west.Within(expanded)
    assert plot_north.Within(expanded)
    assert module.VERSION == "2026-09-24.3"

    overlap_a = polygon(0, 0, 10, 10)
    overlap_b = polygon(5, 5, 15, 15)
    rows = [
        (20, overlap_b.ExportToWkb().hex()),
        (10, overlap_a.ExportToWkb().hex()),
    ]
    union = importer.union_plot_geometries(rows)
    reversed_union = importer.union_plot_geometries(list(reversed(rows)))
    assert union.GetGeometryName().upper() == "MULTIPOLYGON"
    assert union.IsValid()
    assert round(union.GetArea(), 6) == 175.0
    assert union.ExportToWkb() == reversed_union.ExportToWkb()

    expected_counts = {
        "buitenduin_noord": 9,
        "buitenduin_zuid": 7,
        "kijfhoek_en_bierlap": 16,
        "vallei_meijendel": 9,
        "zuid_oosthoek": 11,
        "haagsche_golfclub": 1,
        "voorlinden": 1,
        "hertenkamp": 1,
    }
    importer.validate_plot_gebied_counts(expected_counts)
    for invalid_counts in (
        {**expected_counts, "vallei_meijendel": 8},
        {**expected_counts, "extra_gebied": 1},
        {},
    ):
        try:
            importer.validate_plot_gebied_counts(invalid_counts)
        except ValueError:
            pass
        else:
            raise AssertionError(f"ongeldige gebiedsdekking geaccepteerd: {invalid_counts}")

    source_rows = []
    next_plot_id = 1
    for gebied_code, count in expected_counts.items():
        for offset in range(count):
            source_geometry = polygon(
                next_plot_id * 20,
                offset * 20,
                next_plot_id * 20 + 10,
                offset * 20 + 10,
            )
            source_rows.append(
                (gebied_code, next_plot_id, source_geometry.ExportToWkb().hex())
            )
            next_plot_id += 1
    writes = []

    def source_loader(_mysql, _mysql_args):
        return "vogelplot-gebiedsindeling-v1", 1, source_rows

    def writer(_mysql, _mysql_args, sql):
        writes.append(sql)

    summary = importer.apply_plot_gebieden_only(
        "mysql", ["--login-path=test"], source_loader=source_loader, writer=writer
    )
    assert summary == (
        "OK: vogelplot-gebiedsindeling-v1, plotversie 1, "
        "55 geldige bronplots en 8 gebiedsgeometrieën geschreven"
    )
    assert len(writes) == 1
    assert writes[0].count("ST_GeomFromWKB") == 8

    mysql_args = [
        "--login-path=meijendel_root",
        "--protocol=TCP",
        "--host=127.0.0.1",
        "--port=3306",
    ]
    _, _, live_rows = importer.load_plot_gebied_source(
        "/usr/local/mysql/bin/mysql", mysql_args
    )
    kijfhoek_rows = [
        (plot_id, wkb_hex)
        for gebied_code, plot_id, wkb_hex in live_rows
        if gebied_code == "kijfhoek_en_bierlap"
    ]
    kijfhoek_union = importer.union_plot_geometries(kijfhoek_rows)
    kijfhoek_hex = bytes(kijfhoek_union.ExportToWkb()).hex()
    mysql_valid = importer.query_mysql(
        "/usr/local/mysql/bin/mysql",
        mysql_args,
        "SELECT ST_IsValid(ST_GeomFromWKB(UNHEX('%s'),28992));" % kijfhoek_hex,
    )
    assert mysql_valid == "1"

    invalid = ogr.CreateGeometryFromWkt(
        "POLYGON ((0 0, 10 10, 0 10, 10 0, 0 0))"
    )
    gdal.PushErrorHandler("CPLQuietErrorHandler")
    try:
        assert not invalid.IsValid()
        for invalid_rows in ([], [(1, invalid.ExportToWkb().hex())], [(1, "00")]):
            try:
                importer.union_plot_geometries(invalid_rows)
            except ValueError:
                pass
            else:
                raise AssertionError("ontbrekende of ongeldige brongeometrie geaccepteerd")
    finally:
        gdal.PopErrorHandler()

    sql = " ".join(SCHEMA.read_text(encoding="utf-8").casefold().split())
    for table in (
        "meijendel_basisgebied_versie",
        "meijendel_basisgebied",
        "meijendel_natura2000_versie",
        "meijendel_natura2000",
        "meijendel_waarneming_ruimtelijke_status",
    ):
        assert f"create table if not exists {table}" in sql, table
    for view in (
        "v_meijendel_basisgebied_actueel",
        "v_meijendel_natura2000_actueel",
        "v_meijendel_sovon_plot_actueel",
    ):
        assert f"create or replace view {view}" in sql, view
    assert "volledig_binnen" in sql
    assert "raakt_grens" in sql
    assert "toegelaten" in sql
    assert "ruimtelijk_dubbelzinnig" in sql

    documentation = DOC.read_text(encoding="utf-8")
    assert "Projectgebied" in documentation
    assert "Natura 2000" in documentation
    assert "SOVON" in documentation
    assert "alle 55" in documentation
    assert "toelatingspoort" in documentation
    assert "geen bewijs" in documentation

    importer = IMPORTER.read_text(encoding="utf-8")
    assert 'RULE_VERSION = "meijendel-ruimtelijke-poort-v3"' in importer
    assert "meijendel-ruimtelijke-poort-v1" not in importer
    assert "meijendel-ruimtelijke-poort-v2" not in importer
    for source in (
        "ndff_open_waarneming",
        "dagwaarnemingen_bmp",
        "dagwaarnemingen_wv",
        "pq_vegetatie_opname",
        "sovon_avimap_waarneming",
        "vangblik_event",
        "territoria",
        "duinvallei_opname",
        "vogelstand_1924",
    ):
        assert source in importer, source
    assert "tmp_meijendel_plotmatch" in importer
    assert "UPDATE tmp_meijendel_ruimtelijke_bron" not in importer
    assert "FROM tmp_meijendel_ruimtelijke_bron t" not in importer
    assert "CAST(t.id AS CHAR)=s.bron_record_id" not in importer

    print("OK: contract ruimtelijke Meijendel-lagen")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
