#!/usr/bin/env python3
"""Contract voor de bronvaste OSM-infrastructuurimport."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from tempfile import TemporaryDirectory

from osgeo import ogr


ROOT = Path(__file__).resolve().parents[2]
IMPORTER = ROOT / "gis/scripts/import_osm_fietspaden.py"
SCHEMA = ROOT / "gis/database/meijendel_ruimtelijke_lagen_schema.sql"
SNAPSHOT = ROOT / "Recreatie/OSM/osm_highways_meijendel_20261108.json"
PARKING_SNAPSHOT = ROOT / "Recreatie/OSM/osm_parkeerplaatsen_meijendel_20261108.json"
ACTIVE_CONSUMERS = (
    ROOT / "shiny_meijendel/helpers.R",
    ROOT / "shiny_meijendel/app.R",
    ROOT / "bmp_meijendel_index.html",
)


def load(path: Path):
    spec = importlib.util.spec_from_file_location("osm_fietspaden", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def line(wkt: str) -> ogr.Geometry:
    geometry = ogr.CreateGeometryFromWkt(wkt)
    assert geometry is not None
    return geometry


def main() -> int:
    assert IMPORTER.is_file(), "importscript ontbreekt"
    importer = load(IMPORTER)

    assert importer.classify_tags({"highway": "cycleway"}) == (
        "fietspad", "openbaar", "osm_highway_cycleway"
    )
    assert importer.classify_tags(
        {"highway": "cycleway", "access": "private"}
    ) == ("fietspad", "afgesloten", "osm_access_private")
    assert importer.classify_tags(
        {"highway": "cycleway", "access": "private", "bicycle": "yes"}
    ) == ("fietspad", "openbaar", "osm_bicycle_yes_override")
    assert importer.classify_tags(
        {"highway": "path", "bicycle": "permissive"}
    ) == ("fietspad", "beperkt_toegankelijk", "osm_bicycle_permissive")
    assert importer.classify_tags(
        {"highway": "footway", "bicycle": "designated"}
    ) == ("fietspad", "openbaar", "osm_bicycle_designated")
    assert importer.classify_tags(
        {"highway": "residential", "cycleway": "lane"}
    ) == ("weg", "openbaar", "osm_highway_residential")
    assert importer.classify_tags(
        {"highway": "footway", "access": "private"}
    ) == ("voetpad", "afgesloten", "osm_access_private")
    assert importer.classify_tags(
        {"highway": "footway", "access": "private", "foot": "yes"}
    ) == ("voetpad", "openbaar", "osm_foot_yes_override")
    assert importer.classify_tags(
        {"highway": "path", "bicycle": "no"}
    ) == ("voetpad", "openbaar", "osm_highway_path")
    assert importer.classify_tags(
        {"highway": "service", "access": "private"}
    ) == ("weg", "afgesloten", "osm_access_private")
    assert importer.classify_tags(
        {"highway": "track", "access": "permissive"}
    ) == ("weg", "beperkt_toegankelijk", "osm_access_permissive")
    assert importer.classify_tags({"highway": "platform"}) is None

    clipped = importer.clip_line(
        line("LINESTRING(-5 5,15 5)"),
        line("POLYGON((0 0,10 0,10 10,0 10,0 0))"),
    )
    assert clipped.GetGeometryName().upper() == "MULTILINESTRING"
    assert round(clipped.Length(), 6) == 10

    overlaps = importer.derive_plot_overlaps(
        line("MULTILINESTRING((0 5,20 5))"),
        {
            1: ("M1", line("POLYGON((0 0,10 0,10 10,0 10,0 0))"), "a" * 64),
            2: ("M2", line("POLYGON((10 0,20 0,20 10,10 10,10 0))"), "b" * 64),
        },
    )
    assert [(row[0], round(row[1], 3)) for row in overlaps] == [(1, 10.0), (2, 10.0)]

    comparison = importer.compare_records(
        [
            {"object_id": 1, "geometry_hash": "a", "length": 10.0, "status": "openbaar", "type": "voetpad"},
            {"object_id": 2, "geometry_hash": "b", "length": 20.0, "status": "openbaar", "type": "weg"},
        ],
        [
            {"object_id": 2, "geometry_hash": "c", "length": 25.0, "status": "openbaar", "type": "weg"},
            {"object_id": 3, "geometry_hash": "d", "length": 5.0, "status": "beperkt_toegankelijk", "type": "fietspad"},
        ],
    )
    assert comparison == {
        "vorige_segmenten": 2,
        "nieuwe_segmenten": 2,
        "in_beide": 1,
        "alleen_vorig": 1,
        "alleen_nieuw": 1,
        "geometrie_gewijzigd": 1,
        "status_gewijzigd": 0,
        "statuswijzigingen": [],
        "type_gewijzigd": 0,
        "vorige_lengte_m": 30.0,
        "nieuwe_lengte_m": 30.0,
    }
    bgt = importer.compare_with_bgt(
        [
            {"geometry": line("MULTILINESTRING((0 5,10 5))"), "length": 10.0},
            {"geometry": line("MULTILINESTRING((20 5,30 5))"), "length": 10.0},
        ],
        line("MULTIPOLYGON(((0 0,10 0,10 10,0 10,0 0)))"),
        buffer_m=0,
    )
    assert bgt == {
        "segmenten": 2,
        "segmenten_met_bgt_dekking": 1,
        "segmenten_zonder_bgt_dekking": 1,
        "totale_lengte_m": 20.0,
        "lengte_binnen_bgt_buffer_m": 10.0,
        "dekking_pct": 50.0,
        "buffer_m": 0,
    }
    bgt_union = importer.union_polygons([
        line("POLYGON((0 0,10 0,10 10,0 10,0 0))"),
        line("POLYGON((10 0,20 0,20 10,10 10,10 0))"),
    ])
    assert round(bgt_union.GetArea(), 3) == 200.0

    aggregates = importer.calculate_plot_aggregates(
        [
            {"type": "voetpad", "geometry": line("MULTILINESTRING((0 5,10 5))")},
            {"type": "weg", "geometry": line("MULTILINESTRING((20 5,30 5))")},
        ],
        {
            1: ("M1", line("POLYGON((0 0,10 0,10 10,0 10,0 0))"), "a" * 64),
            2: ("M2", line("POLYGON((20 0,30 0,30 10,20 10,20 0))"), "b" * 64),
        },
        [line("POINT(15 5)")],
    )
    assert aggregates == [
        (1, "afstand_pad_m", 0.0),
        (1, "afstand_parkeerplaats_m", 5.0),
        (1, "padlengte_m_per_ha", 1000.0),
        (2, "afstand_pad_m", 10.0),
        (2, "afstand_parkeerplaats_m", 5.0),
        (2, "padlengte_m_per_ha", 0.0),
    ]

    node = importer.parking_geometry({"type": "node", "lat": 52.1, "lon": 4.3})
    assert node.GetGeometryName().upper() == "POINT"
    parking_way = importer.parking_geometry({
        "type": "way",
        "geometry": [
            {"lat": 52.1, "lon": 4.3}, {"lat": 52.1, "lon": 4.301},
            {"lat": 52.101, "lon": 4.301}, {"lat": 52.1, "lon": 4.3},
        ],
    })
    assert parking_way.GetGeometryName().upper() == "POLYGON"
    parking_relation = importer.parking_geometry({
        "type": "relation",
        "members": [{"role": "outer", "geometry": [
            {"lat": 52.1, "lon": 4.3}, {"lat": 52.1, "lon": 4.301},
            {"lat": 52.101, "lon": 4.301}, {"lat": 52.1, "lon": 4.3},
        ]}],
    })
    assert parking_relation.GetGeometryName().upper() == "POLYGON"

    with TemporaryDirectory() as temporary_directory:
        temporary = Path(temporary_directory)
        basis = line("POLYGON((4 52,5 52,5 53,4 53,4 52))")
        plot_geometry = line("POLYGON((4.30 52.10,4.31 52.10,4.31 52.11,4.30 52.11,4.30 52.10))")
        basis.Transform(importer.wgs84_to_rd())
        plot_geometry.Transform(importer.wgs84_to_rd())
        plots = {1: ("M1", plot_geometry, "a" * 64)}

        line_snapshot = temporary / "lijnen.json"
        line_snapshot.write_text(json.dumps({
            "osm3s": {"timestamp_osm_base": "2026-11-08T10:22:35Z"},
            "elements": [
                {"type": "way", "id": 1, "tags": {"highway": "footway"}, "geometry": [
                    {"lon": 4.302, "lat": 52.102}, {"lon": 4.308, "lat": 52.108},
                ]},
                {"type": "way", "id": 2, "tags": {"highway": "footway"}, "geometry": [
                    {"lon": 4.320, "lat": 52.102}, {"lon": 4.328, "lat": 52.108},
                ]},
            ],
        }), encoding="utf-8")
        line_metadata, retained_lines = importer.prepare(line_snapshot, basis, plots)
        assert line_metadata["selected"] == 2
        assert line_metadata["imported"] == 1
        assert [record["object_id"] for record in retained_lines] == [1]

        parking_snapshot = temporary / "parkeren.json"
        parking_snapshot.write_text(json.dumps({
            "osm3s": {"timestamp_osm_base": "2026-11-08T10:31:51Z"},
            "elements": [
                {"type": "node", "id": 11, "lat": 52.105, "lon": 4.305, "tags": {"amenity": "parking"}},
                {"type": "node", "id": 12, "lat": 52.105, "lon": 4.325, "tags": {"amenity": "parking"}},
            ],
        }), encoding="utf-8")
        parking_metadata, retained_parking = importer.prepare_parking(
            parking_snapshot, basis, plots
        )
        assert parking_metadata["selected"] == 2
        assert parking_metadata["imported"] == 1
        assert [record["object_id"] for record in retained_parking] == [11]

    payload = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
    selected = [
        element for element in payload["elements"]
        if importer.classify_tags(element.get("tags", {})) is not None
    ]
    assert payload["osm3s"]["timestamp_osm_base"] == "2026-11-08T10:22:35Z"
    assert len(payload["elements"]) == 4475
    assert len(selected) > 4000
    parking_payload = json.loads(PARKING_SNAPSHOT.read_text(encoding="utf-8"))
    assert parking_payload["osm3s"]["timestamp_osm_base"] == "2026-11-08T10:31:51Z"
    assert len(parking_payload["elements"]) == 341

    sql = SCHEMA.read_text(encoding="utf-8")
    for table in (
        "infrastructuurbron_snapshot",
        "infrastructuursegment",
        "infrastructuursegment_versie",
        "infrastructuursegment_plot_afleiding",
        "infrastructuurvoorziening",
        "infrastructuurvoorziening_versie",
    ):
        assert f"CREATE TABLE IF NOT EXISTS {table}" in sql
    assert "CREATE OR REPLACE VIEW v_infrastructuursegment_actueel" in sql
    assert "CREATE OR REPLACE VIEW v_infrastructuursegment_historie" in sql
    importer_text = IMPORTER.read_text(encoding="utf-8")
    assert "geldig_tot=(SELECT MIN(s2.bron_timestamp)" in importer_text
    assert "LAST_INSERT_ID" not in importer_text
    assert "upsert_plot_aggregates" in importer_text
    assert "1955-01-01 00:00:00" in importer_text
    assert "geldig_vanaf_grondslag" in sql
    assert "MAX(YEAR(geldig_vanaf))" in importer_text
    assert "DELETE FROM plot_jaar_infra WHERE bron=" in importer_text
    for consumer in ACTIVE_CONSUMERS:
        assert "afstand_hoofdtoegang_m" not in consumer.read_text(encoding="utf-8")
    helpers = ACTIVE_CONSUMERS[0].read_text(encoding="utf-8")
    browser = ACTIVE_CONSUMERS[2].read_text(encoding="utf-8")
    assert "add_infrastructure_covariate <- function" in helpers
    assert "start_year <= dat$jaar[[i]]" in helpers
    assert "const start=toYear(r.geldig_vanaf)||toYear(r.jaar);" in browser
    print("OK: OSM-infrastructuurcontract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
