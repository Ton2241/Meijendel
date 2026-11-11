#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable
from zoneinfo import ZoneInfo


LAYERS = ("gebied", "fietspad", "voetpad", "weg")
DATABASE_VIEWS = (
    "v_toegankelijkheidsgebied_actueel",
    "toegankelijkheidsgebied_plot_afleiding",
    "v_infrastructuursegment_actueel",
    "infrastructuursegment_plot_afleiding",
    "plots",
)


def canonical_geojson(collection: dict[str, Any]) -> bytes:
    return (
        json.dumps(collection, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def _plot_ids(links: dict[str, Iterable[int]], source_id: str) -> list[int]:
    return sorted({int(value) for value in links.get(source_id, [])})


def build_feature_collection(
    area_rows: list[dict[str, Any]],
    line_rows: list[dict[str, Any]],
    area_links: dict[str, Iterable[int]],
    line_links: dict[str, Iterable[int]],
) -> dict[str, Any]:
    features: list[dict[str, Any]] = []
    for row in area_rows:
        source_id = str(row["source_id"])
        plot_ids = _plot_ids(area_links, source_id)
        if not plot_ids:
            continue
        features.append(
            {
                "type": "Feature",
                "properties": {
                    "layer": "gebied",
                    "source_id": source_id,
                    "plot_ids": plot_ids,
                    "status_code": str(row["status_code"]),
                },
                "geometry": row["geometry"],
            }
        )
    for row in line_rows:
        source_id = str(row["source_id"])
        plot_ids = _plot_ids(line_links, source_id)
        if not plot_ids:
            continue
        layer = str(row["layer"])
        if layer not in LAYERS[1:]:
            raise ValueError(f"Onbekend infrastructuurtype: {layer}")
        properties = {
            "layer": layer,
            "source_id": source_id,
            "plot_ids": plot_ids,
            "toegankelijkheidsstatus": str(row["toegankelijkheidsstatus"]),
        }
        if row.get("naam"):
            properties["naam"] = str(row["naam"])
        features.append(
            {
                "type": "Feature",
                "properties": properties,
                "geometry": row["geometry"],
            }
        )
    layer_order = {layer: index for index, layer in enumerate(LAYERS)}
    features.sort(
        key=lambda feature: (
            layer_order[feature["properties"]["layer"]],
            feature["properties"]["source_id"],
        )
    )
    return {"type": "FeatureCollection", "features": features}


def build_manifest(
    collection: dict[str, Any], source_metadata: dict[str, Any]
) -> dict[str, Any]:
    counts = Counter(
        feature["properties"]["layer"] for feature in collection.get("features", [])
    )
    return {
        **source_metadata,
        "feature_count": len(collection.get("features", [])),
        "counts": {layer: counts.get(layer, 0) for layer in LAYERS},
        "geojson_sha256": hashlib.sha256(canonical_geojson(collection)).hexdigest(),
    }


class MysqlClient:
    def __init__(self, database: str) -> None:
        self.database = database
        self.executable = shutil.which("mysql") or "/usr/local/mysql/bin/mysql"

    def rows(self, sql: str) -> list[list[str]]:
        result = subprocess.run(
            [
                self.executable,
                "--login-path=meijendel_root",
                "--batch",
                "--raw",
                "--skip-column-names",
                self.database,
                "-e",
                sql,
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        return [line.split("\t") for line in result.stdout.splitlines() if line]

    def scalar(self, sql: str) -> str:
        rows = self.rows(sql)
        if len(rows) != 1 or len(rows[0]) != 1:
            raise ValueError(f"Query leverde geen enkele scalar op: {sql}")
        return rows[0][0]


def _linked(rows: list[list[str]]) -> dict[str, list[int]]:
    result: dict[str, list[int]] = {}
    for source_id, plot_id in rows:
        result.setdefault(source_id, []).append(int(plot_id))
    return result


def read_live(client: MysqlClient) -> tuple[dict[str, Any], dict[str, Any]]:
    area_rows = [
        {
            "source_id": source_id,
            "status_code": status_code,
            "geometry": json.loads(geometry),
        }
        for source_id, status_code, geometry in client.rows(
            "SELECT CONCAT('gebied:',gebied_versie_id),status_code,"
            "ST_AsGeoJSON(ST_Transform(geometrie,4326),6) "
            "FROM v_toegankelijkheidsgebied_actueel ORDER BY gebied_versie_id"
        )
    ]
    line_rows = [
        {
            "source_id": source_id,
            "layer": layer,
            "toegankelijkheidsstatus": status,
            "geometry": json.loads(geometry),
        }
        for source_id, layer, status, geometry in client.rows(
            "SELECT CONCAT(bron_code,':',bron_objecttype,':',bron_object_id),"
            "infrastructuurtype,toegankelijkheidsstatus,"
            "ST_AsGeoJSON(ST_Transform(geometrie,4326),6) "
            "FROM v_infrastructuursegment_actueel "
            "ORDER BY infrastructuurtype,bron_code,bron_objecttype,bron_object_id"
        )
    ]
    area_links = _linked(
        client.rows(
            "SELECT CONCAT('gebied:',a.gebied_versie_id),a.plot_id "
            "FROM toegankelijkheidsgebied_plot_afleiding a "
            "JOIN v_toegankelijkheidsgebied_actueel v USING(gebied_versie_id) "
            "JOIN plots p ON p.plot_id=a.plot_id AND p.in_gebruik=1 "
            "WHERE a.doorsnijding_m2>0 ORDER BY a.gebied_versie_id,a.plot_id"
        )
    )
    line_links = _linked(
        client.rows(
            "SELECT CONCAT(v.bron_code,':',v.bron_objecttype,':',v.bron_object_id),a.plot_id "
            "FROM infrastructuursegment_plot_afleiding a "
            "JOIN v_infrastructuursegment_actueel v USING(segment_versie_id) "
            "JOIN plots p ON p.plot_id=a.plot_id AND p.in_gebruik=1 "
            "WHERE a.doorsnijding_m>0 ORDER BY v.bron_code,v.bron_objecttype,v.bron_object_id,a.plot_id"
        )
    )
    collection = build_feature_collection(area_rows, line_rows, area_links, line_links)
    metadata = {
        "generated_at": datetime.now(ZoneInfo("Europe/Amsterdam")).isoformat(
            timespec="seconds"
        ),
        "area_source_moment": client.scalar(
            "SELECT DATE_FORMAT(MAX(aangemaakt_op),'%Y-%m-%dT%H:%i:%s') "
            "FROM v_toegankelijkheidsgebied_actueel"
        ),
        "line_source_moment": client.scalar(
            "SELECT DATE_FORMAT(MAX(s.bron_timestamp),'%Y-%m-%dT%H:%i:%sZ') "
            "FROM v_infrastructuursegment_actueel v "
            "JOIN infrastructuurbron_snapshot s USING(snapshot_id)"
        ),
        "database_views": list(DATABASE_VIEWS),
    }
    return collection, metadata


def _atomic_write(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def verify_files(
    collection: dict[str, Any], metadata: dict[str, Any], output: Path, manifest_path: Path
) -> dict[str, Any]:
    stored_collection = json.loads(output.read_text(encoding="utf-8"))
    stored_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    metadata = {**metadata, "generated_at": stored_manifest.get("generated_at")}
    expected_manifest = build_manifest(collection, metadata)
    if canonical_geojson(stored_collection) != canonical_geojson(collection):
        raise ValueError("GeoJSON wijkt af van de levende database")
    if stored_manifest != expected_manifest:
        raise ValueError("Manifest wijkt af van de levende database of GeoJSON-hash")
    return {"status": "verified", **expected_manifest}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Exporteer actuele gebieds- en infrastructuurlagen voor VWG_M."
    )
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--database", default="Meijendel")
    parser.add_argument("--verify", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    collection, metadata = read_live(MysqlClient(args.database))
    if args.verify:
        print(
            json.dumps(
                verify_files(collection, metadata, args.output, args.manifest),
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0
    manifest = build_manifest(collection, metadata)
    _atomic_write(args.output, canonical_geojson(collection))
    _atomic_write(
        args.manifest,
        (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8"),
    )
    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
