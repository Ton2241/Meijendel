#!/usr/bin/env python3
"""Contracttests voor de ruimtelijke basislagen van Meijendel."""

from __future__ import annotations

import importlib.util
from pathlib import Path

from osgeo import ogr


ROOT = Path(__file__).parents[2]
BUILDER = ROOT / "gis" / "scripts" / "build_meijendel_ruimtelijke_lagen.py"
IMPORTER = ROOT / "gis" / "scripts" / "import_meijendel_ruimtelijke_lagen.py"
SCHEMA = ROOT / "gis" / "database" / "meijendel_ruimtelijke_lagen_schema.sql"
DOC = ROOT / "docs" / "MEIJENDEL_RUIMTELIJKE_LAGEN.md"


def load_builder():
    spec = importlib.util.spec_from_file_location("meijendel_ruimtelijke_lagen", BUILDER)
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
    assert module.VERSION == "2026-09-24.2"

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
    assert "toelatingspoort" in documentation
    assert "geen bewijs" in documentation

    importer = IMPORTER.read_text(encoding="utf-8")
    assert 'RULE_VERSION = "meijendel-ruimtelijke-poort-v2"' in importer
    assert "meijendel-ruimtelijke-poort-v1" not in importer
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
