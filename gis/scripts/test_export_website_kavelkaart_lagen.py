#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path


SCRIPT = Path(__file__).with_name("export_website_kavelkaart_lagen.py")
SPEC = importlib.util.spec_from_file_location("export_website_kavelkaart_lagen", SCRIPT)
assert SPEC and SPEC.loader
exporter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(exporter)


def polygon(x: float) -> dict:
    return {
        "type": "Polygon",
        "coordinates": [[[x, 52.0], [x + 0.01, 52.0], [x + 0.01, 52.01], [x, 52.0]]],
    }


def line(x: float) -> dict:
    return {
        "type": "LineString",
        "coordinates": [[x, 52.0], [x + 0.01, 52.01]],
    }


def test_feature_collection_keeps_full_geometries_and_only_linked_features() -> None:
    area_rows = [
        {
            "source_id": "gebied-2",
            "status_code": "toegankelijk_met_toegangskaart",
            "geometry": polygon(4.2),
        },
        {
            "source_id": "gebied-zonder-kavel",
            "status_code": "afgesloten",
            "geometry": polygon(4.4),
        },
    ]
    line_rows = [
        {"source_id": "weg-1", "layer": "weg", "geometry": line(4.1), "toegankelijkheidsstatus": "openbaar"},
        {"source_id": "fiets-1", "layer": "fietspad", "geometry": line(4.2), "toegankelijkheidsstatus": "openbaar"},
        {"source_id": "voet-1", "layer": "voetpad", "geometry": line(4.3), "toegankelijkheidsstatus": "beperkt_toegankelijk"},
        {"source_id": "weg-zonder-kavel", "layer": "weg", "geometry": line(4.4), "toegankelijkheidsstatus": "afgesloten"},
    ]
    collection = exporter.build_feature_collection(
        area_rows,
        line_rows,
        {"gebied-2": [3504, 3504, 3503]},
        {"weg-1": [3504], "fiets-1": [3504], "voet-1": [3503, 3504]},
    )

    assert collection["type"] == "FeatureCollection"
    assert {feature["properties"]["layer"] for feature in collection["features"]} == {
        "gebied",
        "weg",
        "fietspad",
        "voetpad",
    }
    assert [feature["properties"]["source_id"] for feature in collection["features"]] == [
        "gebied-2",
        "fiets-1",
        "voet-1",
        "weg-1",
    ]
    by_source = {feature["properties"]["source_id"]: feature for feature in collection["features"]}
    assert by_source["gebied-2"]["properties"]["plot_ids"] == [3503, 3504]
    assert by_source["voet-1"]["properties"]["plot_ids"] == [3503, 3504]
    assert by_source["gebied-2"]["properties"]["status_code"] == "toegankelijk_met_toegangskaart"
    assert by_source["gebied-2"]["geometry"] == polygon(4.2)
    assert by_source["weg-1"]["geometry"] == line(4.1)
    assert "gebied-zonder-kavel" not in by_source
    assert "weg-zonder-kavel" not in by_source


def test_manifest_counts_layers_and_hashes_canonical_geojson() -> None:
    collection = exporter.build_feature_collection(
        [{"source_id": "gebied-1", "status_code": "toegankelijk", "geometry": polygon(4.1)}],
        [
            {"source_id": "weg-1", "layer": "weg", "geometry": line(4.1), "toegankelijkheidsstatus": "openbaar"},
            {"source_id": "fiets-1", "layer": "fietspad", "geometry": line(4.2), "toegankelijkheidsstatus": "openbaar"},
            {"source_id": "voet-1", "layer": "voetpad", "geometry": line(4.3), "toegankelijkheidsstatus": "afgesloten"},
        ],
        {"gebied-1": [3504]},
        {"weg-1": [3504], "fiets-1": [3504], "voet-1": [3504]},
    )
    metadata = {
        "generated_at": "2026-11-08T13:00:00+01:00",
        "area_source_moment": "2026-11-08",
        "line_source_moment": "2026-11-08T10:22:35Z",
        "database_views": [
            "v_toegankelijkheidsgebied_actueel",
            "v_infrastructuursegment_actueel",
        ],
    }
    manifest = exporter.build_manifest(collection, metadata)
    canonical = json.dumps(collection, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8") + b"\n"

    assert manifest == {
        **metadata,
        "feature_count": 4,
        "counts": {"gebied": 1, "weg": 1, "fietspad": 1, "voetpad": 1},
        "geojson_sha256": hashlib.sha256(canonical).hexdigest(),
    }


if __name__ == "__main__":
    test_feature_collection_keeps_full_geometries_and_only_linked_features()
    test_manifest_counts_layers_and_hashes_canonical_geojson()
    print("OK: publieke kavelkaartlagen-exportcontract")
