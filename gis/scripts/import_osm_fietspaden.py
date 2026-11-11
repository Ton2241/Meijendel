#!/usr/bin/env python3
"""Importeer een gedateerde OSM-snapshot van paden en wegen."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from typing import Any

from osgeo import ogr, osr


ogr.UseExceptions()
ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis/database/meijendel_ruimtelijke_lagen_schema.sql"
DEFAULT_JSON = ROOT / "Recreatie/OSM/osm_highways_meijendel_20261108.json"
DEFAULT_QUERY = ROOT / "Recreatie/OSM/osm_highways_meijendel_20261108.overpassql"
DEFAULT_PREVIOUS = ROOT / "Recreatie/OSM/osm_highways_lijnen.geojson"
DEFAULT_BGT = ROOT / "Recreatie/BGT/bgt_padvlakken.gpkg"
DEFAULT_PARKING_JSON = ROOT / "Recreatie/OSM/osm_parkeerplaatsen_meijendel_20261108.json"
DEFAULT_PARKING_QUERY = ROOT / "Recreatie/OSM/osm_parkeerplaatsen_meijendel_20261108.overpassql"
BACKUP_ROOT = Path("/Volumes/T7 Data/Home_Ton/Meijendel data/Backups-archief/Meijendel")
SOURCE_URL = "https://lz4.overpass-api.de/api/interpreter"
LICENSE = "OpenStreetMap contributors, ODbL 1.0"


def sql_literal(value: Any) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("\\", "\\\\").replace("'", "''") + "'"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _access_status(tags: dict[str, str], mode: str, default_rule: str) -> tuple[str, str]:
    mode_key = {"fietspad": "bicycle", "voetpad": "foot", "weg": "motor_vehicle"}[mode]
    mode_value = tags.get(mode_key, "")
    access = tags.get("access", "")
    if mode_value in {"yes", "designated"}:
        suffix = "_override" if access in {"no", "private"} else ""
        return "openbaar", f"osm_{mode_key}_{mode_value}{suffix}"
    if mode_value in {"no", "private", "dismount"}:
        return "afgesloten", f"osm_{mode_key}_{mode_value}"
    if mode_value in {"permissive", "destination", "customers", "delivery", "agricultural", "forestry", "permit"}:
        return "beperkt_toegankelijk", f"osm_{mode_key}_{mode_value}"
    if access in {"no", "private"}:
        return "afgesloten", f"osm_access_{access}"
    if access in {"permissive", "destination", "customers", "delivery", "agricultural", "forestry", "permit"}:
        return "beperkt_toegankelijk", f"osm_access_{access}"
    if tags.get(f"{mode_key}:conditional") or tags.get("access:conditional"):
        return "beperkt_toegankelijk", f"osm_{mode_key}_conditional"
    return "openbaar", default_rule


def classify_tags(tags: dict[str, str]) -> tuple[str, str, str] | None:
    """Deel actuele OSM-highways in als fietspad, voetpad of weg."""
    highway = tags.get("highway")
    bicycle = tags.get("bicycle", "")
    if highway == "cycleway" or (
        highway in {"path", "footway"}
        and bicycle in {"yes", "designated", "permissive"}
    ):
        status, rule = _access_status(tags, "fietspad", "osm_highway_cycleway")
        return "fietspad", status, rule
    if highway in {"footway", "path", "steps", "pedestrian", "bridleway"}:
        status, rule = _access_status(tags, "voetpad", f"osm_highway_{highway}")
        return "voetpad", status, rule
    if highway in {
        "motorway", "motorway_link", "trunk", "trunk_link", "primary", "primary_link",
        "secondary", "secondary_link", "tertiary", "tertiary_link", "residential",
        "service", "track", "unclassified", "living_street", "road", "busway",
    }:
        status, rule = _access_status(tags, "weg", f"osm_highway_{highway}")
        if highway == "busway" and status == "openbaar":
            status, rule = "beperkt_toegankelijk", "osm_highway_busway"
        return "weg", status, rule
    return None


def _line_parts(geometry: ogr.Geometry):
    name = geometry.GetGeometryName().upper()
    if name in {"LINESTRING", "LINEARRING"}:
        yield geometry
        return
    for index in range(geometry.GetGeometryCount()):
        yield from _line_parts(geometry.GetGeometryRef(index))


def as_multiline(geometry: ogr.Geometry) -> ogr.Geometry | None:
    result = ogr.Geometry(ogr.wkbMultiLineString)
    for part in _line_parts(geometry):
        if part.Length() > 0.001:
            result.AddGeometry(ogr.ForceToLineString(part.Clone()))
    return result if result.GetGeometryCount() else None


def clip_line(line: ogr.Geometry, boundary: ogr.Geometry) -> ogr.Geometry:
    clipped = as_multiline(line.Intersection(boundary))
    if clipped is None:
        return ogr.Geometry(ogr.wkbMultiLineString)
    return clipped


def derive_plot_overlaps(
    segment: ogr.Geometry,
    plots: dict[int, tuple[str, ogr.Geometry, str]],
) -> list[tuple[int, float, float, str]]:
    total = float(segment.Length())
    rows = []
    for plot_id, (_kavel, plot, plot_hash) in plots.items():
        if not segment.Intersects(plot):
            continue
        overlap = as_multiline(segment.Intersection(plot))
        length = float(overlap.Length()) if overlap is not None else 0.0
        if round(length, 3) <= 0:
            continue
        rows.append((plot_id, length, min(100.0, 100.0 * length / total), plot_hash))
    return sorted(rows)


def calculate_plot_aggregates(
    records: list[dict[str, Any]],
    plots: dict[int, tuple[str, ogr.Geometry, str]],
    parking_geometries: list[ogr.Geometry],
) -> list[tuple[int, str, float]]:
    paths = [record["geometry"] for record in records if record["type"] in {"fietspad", "voetpad"}]
    if not paths:
        raise ValueError("Geen voet- of fietspaden voor aggregatie")
    if not parking_geometries:
        raise ValueError("Geen parkeerplaatsen voor aggregatie")
    rows = []
    for plot_id, (_kavel, plot, _plot_hash) in sorted(plots.items()):
        distance = min(float(plot.Distance(path)) for path in paths)
        length = 0.0
        for path in paths:
            if not plot.Intersects(path):
                continue
            overlap = as_multiline(plot.Intersection(path))
            if overlap is not None:
                length += float(overlap.Length())
        area_ha = float(plot.GetArea()) / 10000.0
        parking_distance = min(float(plot.Distance(parking)) for parking in parking_geometries)
        rows.extend((
            (plot_id, "afstand_pad_m", round(distance, 3)),
            (plot_id, "afstand_parkeerplaats_m", round(parking_distance, 3)),
            (plot_id, "padlengte_m_per_ha", round(length / area_ha if area_ha else 0.0, 3)),
        ))
    return rows


def parking_geometry(element: dict[str, Any]) -> ogr.Geometry:
    object_type = element.get("type")
    if object_type == "node":
        geometry = ogr.Geometry(ogr.wkbPoint)
        geometry.AddPoint_2D(float(element["lon"]), float(element["lat"]))
    elif object_type == "way" and len(element.get("geometry", [])) >= 3:
        coordinates = element["geometry"]
        closed = coordinates[0] == coordinates[-1]
        if closed:
            ring = ogr.Geometry(ogr.wkbLinearRing)
            for point in coordinates:
                ring.AddPoint_2D(float(point["lon"]), float(point["lat"]))
            geometry = ogr.Geometry(ogr.wkbPolygon)
            geometry.AddGeometry(ring)
        else:
            center = element.get("center")
            if not center:
                raise ValueError(f"Open parkeer-way {element.get('id')} heeft geen centrum")
            geometry = ogr.Geometry(ogr.wkbPoint)
            geometry.AddPoint_2D(float(center["lon"]), float(center["lat"]))
    elif object_type == "relation" and element.get("members"):
        polygons = []
        inner_rings = []
        for member in element["members"]:
            coordinates = member.get("geometry", [])
            if len(coordinates) < 4 or coordinates[0] != coordinates[-1]:
                continue
            ring = ogr.Geometry(ogr.wkbLinearRing)
            for point in coordinates:
                ring.AddPoint_2D(float(point["lon"]), float(point["lat"]))
            if member.get("role") == "outer":
                polygon = ogr.Geometry(ogr.wkbPolygon)
                polygon.AddGeometry(ring)
                polygons.append(polygon)
            elif member.get("role") == "inner":
                inner_rings.append(ring)
        for inner in inner_rings:
            point = ogr.Geometry(ogr.wkbPoint)
            x, y, *_ = inner.GetPoint(0)
            point.AddPoint_2D(x, y)
            for polygon in polygons:
                if polygon.Contains(point):
                    polygon.AddGeometry(inner)
                    break
        if not polygons:
            raise ValueError(f"Parkeerrelatie {element.get('id')} heeft geen gesloten buitenring")
        if len(polygons) == 1:
            geometry = polygons[0]
        else:
            geometry = ogr.Geometry(ogr.wkbMultiPolygon)
            for polygon in polygons:
                geometry.AddGeometry(polygon)
    else:
        center = element.get("center")
        if not center:
            raise ValueError(f"Parkeerobject {element.get('id')} heeft geen geometrie of centrum")
        geometry = ogr.Geometry(ogr.wkbPoint)
        geometry.AddPoint_2D(float(center["lon"]), float(center["lat"]))
    geometry.Transform(wgs84_to_rd())
    return geometry


def intersects_any_plot(
    geometry: ogr.Geometry,
    plots: dict[int, tuple[str, ogr.Geometry, str]],
) -> bool:
    return any(geometry.Intersects(plot) for _kavel, plot, _plot_hash in plots.values())


def prepare_parking(
    snapshot: Path,
    basis: ogr.Geometry,
    plots: dict[int, tuple[str, ogr.Geometry, str]],
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    payload = json.loads(snapshot.read_text(encoding="utf-8"))
    records = []
    selected = 0
    for element in payload.get("elements", []):
        if element.get("tags", {}).get("amenity") != "parking":
            continue
        selected += 1
        geometry = parking_geometry(element)
        if not intersects_any_plot(geometry, plots):
            continue
        distance = float(geometry.Distance(basis))
        wkb = bytes(geometry.ExportToWkb(ogr.wkbNDR))
        tags = element.get("tags", {})
        records.append({
            "object_type": element["type"],
            "object_id": int(element["id"]),
            "version": element.get("version"),
            "timestamp": element.get("timestamp"),
            "changeset": element.get("changeset"),
            "name": tags.get("name"),
            "tags": tags,
            "geometry": geometry,
            "geometry_hex": wkb.hex(),
            "wkt": geometry.ExportToIsoWkt(),
            "geometry_hash": hashlib.sha256(wkb).hexdigest(),
            "inside": int(distance == 0.0 and geometry.Intersects(basis)),
            "distance": distance,
        })
    return ({
        "timestamp": payload["osm3s"]["timestamp_osm_base"],
        "objects": len(payload.get("elements", [])),
        "selected": selected,
        "imported": len(records),
    }, records)


def wgs84_to_rd() -> osr.CoordinateTransformation:
    source = osr.SpatialReference()
    source.ImportFromEPSG(4326)
    source.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    target = osr.SpatialReference()
    target.ImportFromEPSG(28992)
    target.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    return osr.CoordinateTransformation(source, target)


def way_geometry(element: dict[str, Any]) -> ogr.Geometry:
    coordinates = element.get("geometry", [])
    if len(coordinates) < 2:
        raise ValueError(f"OSM-way {element.get('id')} heeft geen bruikbare geometrie")
    line = ogr.Geometry(ogr.wkbLineString)
    for point in coordinates:
        line.AddPoint_2D(float(point["lon"]), float(point["lat"]))
    line.Transform(wgs84_to_rd())
    return line


class Client:
    def __init__(self, database: str) -> None:
        self.database = database
        self.mysql = shutil.which("mysql") or "/usr/local/mysql-9.7.4-macos15-arm64/bin/mysql"
        self.mysqldump = shutil.which("mysqldump") or "/usr/local/mysql-9.7.4-macos15-arm64/bin/mysqldump"

    def command(self, executable: str | None = None) -> list[str]:
        return [executable or self.mysql, "--login-path=meijendel_root", "--batch", "--raw", "--skip-column-names", self.database]

    def sql(self, statement: str) -> str:
        result = subprocess.run(self.command(), input=statement, text=True, capture_output=True, check=False)
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip())
        return result.stdout.strip()

    def scalar(self, statement: str) -> str:
        return self.sql(statement)


def read_db_geometries(client: Client) -> tuple[int, ogr.Geometry, dict[int, tuple[str, ogr.Geometry, str]]]:
    basis_row = client.sql(
        "SELECT basisgebiedversie_id,HEX(ST_AsBinary(gebied_geometrie)) "
        "FROM v_meijendel_basisgebied_actueel"
    ).split("\t")
    if len(basis_row) != 2:
        raise RuntimeError("Actueel basisgebied ontbreekt of is niet uniek")
    basis_id = int(basis_row[0])
    basis = ogr.CreateGeometryFromWkb(bytes.fromhex(basis_row[1]))
    plots: dict[int, tuple[str, ogr.Geometry, str]] = {}
    for row in client.sql(
        "SELECT plot_id,kavel_nummer,HEX(ST_AsBinary(geom)),geom_sha256 "
        "FROM plots WHERE in_gebruik=1 AND geom IS NOT NULL ORDER BY plot_id"
    ).splitlines():
        plot_id, kavel, geometry_hex, geometry_hash = row.split("\t")
        plots[int(plot_id)] = (kavel, ogr.CreateGeometryFromWkb(bytes.fromhex(geometry_hex)), geometry_hash)
    if len(plots) != 55:
        raise RuntimeError(f"Verwacht 55 actieve kavels, gevonden {len(plots)}")
    return basis_id, basis, plots


def prepare(
    snapshot: Path,
    basis: ogr.Geometry,
    plots: dict[int, tuple[str, ogr.Geometry, str]],
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    payload = json.loads(snapshot.read_text(encoding="utf-8"))
    records = []
    selected = 0
    for element in payload.get("elements", []):
        classification = classify_tags(element.get("tags", {}))
        if classification is None:
            continue
        selected += 1
        geometry = clip_line(way_geometry(element), basis)
        if geometry.GetGeometryCount() == 0 or round(geometry.Length(), 3) <= 0:
            continue
        if not derive_plot_overlaps(geometry, plots):
            continue
        wkb = bytes(geometry.ExportToWkb(ogr.wkbNDR))
        tags = element.get("tags", {})
        records.append({
            "object_id": int(element["id"]),
            "version": element.get("version"),
            "timestamp": element.get("timestamp"),
            "changeset": element.get("changeset"),
            "type": classification[0],
            "status": classification[1],
            "rule": classification[2],
            "name": tags.get("name"),
            "surface": tags.get("surface"),
            "tags": tags,
            "geometry": geometry,
            "wkt": geometry.ExportToIsoWkt(),
            "geometry_hex": wkb.hex(),
            "geometry_hash": hashlib.sha256(wkb).hexdigest(),
            "length": float(geometry.Length()),
        })
    metadata = {
        "timestamp": payload["osm3s"]["timestamp_osm_base"],
        "objects": len(payload.get("elements", [])),
        "selected": selected,
        "imported": len(records),
    }
    return metadata, records


def read_previous(
    path: Path,
    basis: ogr.Geometry,
    plots: dict[int, tuple[str, ogr.Geometry, str]],
) -> list[dict[str, Any]]:
    dataset = ogr.Open(str(path), 0)
    if dataset is None:
        raise ValueError(f"Vorige OSM-laag niet leesbaar: {path}")
    layer = dataset.GetLayer(0)
    records = []
    for feature in layer:
        tags = {
            name: feature.GetFieldAsString(name)
            for name in (
                "highway", "bicycle", "foot", "motor_vehicle", "vehicle", "access",
                "bicycle:conditional", "foot:conditional", "motor_vehicle:conditional",
                "access:conditional",
            )
            if feature.GetFieldIndex(name) >= 0 and feature.GetFieldAsString(name)
        }
        classification = classify_tags(tags)
        if classification is None:
            continue
        geometry = feature.GetGeometryRef().Clone()
        geometry.Transform(wgs84_to_rd())
        geometry = clip_line(geometry, basis)
        if geometry.GetGeometryCount() == 0 or round(geometry.Length(), 3) <= 0:
            continue
        if not derive_plot_overlaps(geometry, plots):
            continue
        wkb = bytes(geometry.ExportToWkb(ogr.wkbNDR))
        records.append({
            "object_id": int(feature.GetField("osm_id")),
            "geometry_hash": hashlib.sha256(wkb).hexdigest(),
            "length": float(geometry.Length()),
            "status": classification[1],
            "type": classification[0],
        })
    return records


def compare_records(previous: list[dict[str, Any]], current: list[dict[str, Any]]) -> dict[str, Any]:
    old = {int(record["object_id"]): record for record in previous}
    new = {int(record["object_id"]): record for record in current}
    common = old.keys() & new.keys()
    status_changes = [
        {"osm_way_id": key, "vorig": old[key]["status"], "nieuw": new[key]["status"]}
        for key in sorted(common)
        if old[key]["status"] != new[key]["status"]
    ]
    return {
        "vorige_segmenten": len(old),
        "nieuwe_segmenten": len(new),
        "in_beide": len(common),
        "alleen_vorig": len(old.keys() - new.keys()),
        "alleen_nieuw": len(new.keys() - old.keys()),
        "geometrie_gewijzigd": sum(old[key]["geometry_hash"] != new[key]["geometry_hash"] for key in common),
        "status_gewijzigd": len(status_changes),
        "statuswijzigingen": status_changes[:20],
        "type_gewijzigd": sum(old[key]["type"] != new[key]["type"] for key in common),
        "vorige_lengte_m": round(sum(float(record["length"]) for record in old.values()), 3),
        "nieuwe_lengte_m": round(sum(float(record["length"]) for record in new.values()), 3),
    }


def read_bgt_cycleway_union(path: Path) -> ogr.Geometry:
    dataset = ogr.Open(str(path), 0)
    if dataset is None:
        raise ValueError(f"BGT-laag niet leesbaar: {path}")
    layer = dataset.GetLayerByName("bgt_padvlakken")
    if layer is None:
        raise ValueError("BGT-laag bgt_padvlakken ontbreekt")
    layer.SetAttributeFilter("functie = 'fietspad'")
    polygons = []
    transformation = wgs84_to_rd()
    for feature in layer:
        geometry = feature.GetGeometryRef().Clone()
        geometry.Transform(transformation)
        polygons.append(geometry)
    union = union_polygons(polygons)
    if union is None or union.IsEmpty():
        raise ValueError("BGT bevat geen fietspadvlakken")
    return union


def union_polygons(geometries: list[ogr.Geometry]) -> ogr.Geometry:
    multipolygon = ogr.Geometry(ogr.wkbMultiPolygon)
    for geometry in geometries:
        name = geometry.GetGeometryName().upper()
        if name == "POLYGON":
            multipolygon.AddGeometry(geometry)
        elif name == "MULTIPOLYGON":
            for index in range(geometry.GetGeometryCount()):
                multipolygon.AddGeometry(geometry.GetGeometryRef(index))
        else:
            raise ValueError(f"Geen vlakgeometrie: {name}")
    if multipolygon.GetGeometryCount() == 0:
        raise ValueError("Geen polygonen om samen te voegen")
    return multipolygon.UnionCascaded()


def compare_with_bgt(
    records: list[dict[str, Any]],
    bgt_cycleways: ogr.Geometry,
    buffer_m: float = 10.0,
) -> dict[str, Any]:
    coverage = bgt_cycleways.Buffer(buffer_m) if buffer_m else bgt_cycleways
    total = sum(float(record["length"]) for record in records)
    covered = 0.0
    matched = 0
    for record in records:
        overlap = as_multiline(record["geometry"].Intersection(coverage))
        length = float(overlap.Length()) if overlap is not None else 0.0
        covered += length
        if round(length, 3) > 0:
            matched += 1
    return {
        "segmenten": len(records),
        "segmenten_met_bgt_dekking": matched,
        "segmenten_zonder_bgt_dekking": len(records) - matched,
        "totale_lengte_m": round(total, 3),
        "lengte_binnen_bgt_buffer_m": round(covered, 3),
        "dekking_pct": round(100.0 * covered / total, 3) if total else 0.0,
        "buffer_m": buffer_m,
    }


def existing_guard(client: Client) -> dict[str, str]:
    return {
        "toegankelijkheidsgebieden": client.scalar(
            "SELECT CONCAT(COUNT(*),'|',COALESCE(GROUP_CONCAT(geometrie_sha256 ORDER BY geometrie_sha256 SEPARATOR ','),'')) FROM toegankelijkheidsgebied_versie"
        ),
    }


def ensure_schema_extensions(client: Client) -> None:
    snapshot_exists = int(client.scalar(
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() "
        "AND table_name='infrastructuurbron_snapshot' AND table_type='BASE TABLE'"
    ))
    if snapshot_exists and int(client.scalar(
        "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=DATABASE() "
        "AND table_name='infrastructuurbron_snapshot' AND column_name='snapshottype'"
    )) == 0:
        client.sql(
            "ALTER TABLE infrastructuurbron_snapshot ADD COLUMN snapshottype "
            "ENUM('lijnen','voorzieningen') NOT NULL DEFAULT 'lijnen' AFTER snapshot_code"
        )
    versions_exist = int(client.scalar(
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() "
        "AND table_name='infrastructuursegment_versie' AND table_type='BASE TABLE'"
    ))
    if versions_exist and int(client.scalar(
        "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=DATABASE() "
        "AND table_name='infrastructuursegment_versie' AND column_name='geldig_vanaf_grondslag'"
    )) == 0:
        client.sql(
            "ALTER TABLE infrastructuursegment_versie ADD COLUMN geldig_vanaf_grondslag "
            "ENUM('inschatting','bron') NOT NULL DEFAULT 'bron' AFTER geldig_vanaf"
        )
    plot_infra_extensions = (
        ("geldig_vanaf", "DATE NULL AFTER waarde"),
        ("geldig_vanaf_grondslag", "ENUM('inschatting','bron') NULL AFTER geldig_vanaf"),
        ("geldig_tot", "DATE NULL AFTER geldig_vanaf_grondslag"),
    )
    for column, definition in plot_infra_extensions:
        if int(client.scalar(
            "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=DATABASE() "
            f"AND table_name='plot_jaar_infra' AND column_name='{column}'"
        )) == 0:
            client.sql(f"ALTER TABLE plot_jaar_infra ADD COLUMN {column} {definition}")


def backup(client: Client, backup_dir: Path, guard: dict[str, str]) -> Path:
    if not os.path.ismount("/Volumes/T7 Data"):
        raise RuntimeError("T7 is niet gemount")
    resolved = backup_dir.resolve()
    if resolved != BACKUP_ROOT.resolve() and BACKUP_ROOT.resolve() not in resolved.parents:
        raise RuntimeError(f"Back-up moet onder {BACKUP_ROOT} staan")
    resolved.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    target = resolved / f"meijendel-voor-osm-fietspaden-{stamp}.sql"
    tables = [
        "meijendel_basisgebied_versie", "meijendel_basisgebied", "plots",
        "plot_jaar_infra", "toegankelijkheidsgebied", "toegankelijkheidsgebied_versie",
        "toegankelijkheidsgebied_plot_afleiding",
    ]
    infrastructure_tables = [
        "infrastructuurbron_snapshot", "infrastructuursegment",
        "infrastructuursegment_versie", "infrastructuursegment_plot_afleiding",
        "infrastructuurvoorziening", "infrastructuurvoorziening_versie",
    ]
    existing_names = client.sql(
        "SELECT table_name FROM information_schema.tables WHERE table_schema=DATABASE() "
        "AND table_type='BASE TABLE' AND table_name IN ("
        + ",".join(sql_literal(name) for name in infrastructure_tables) + ") ORDER BY table_name"
    ).splitlines()
    if len(existing_names) not in {0, 4, 6}:
        raise RuntimeError(f"Onvolledig infrastructuurmodel: {len(existing_names)}/6 tabellen")
    tables.extend(existing_names)
    command = [
        client.mysqldump, "--login-path=meijendel_root", "--no-tablespaces",
        "--single-transaction", "--quick", "--complete-insert", "--set-gtid-purged=OFF",
        client.database, *tables,
    ]
    with target.open("wb") as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.PIPE, check=False)
    if result.returncode or target.stat().st_size == 0:
        target.unlink(missing_ok=True)
        raise RuntimeError(result.stderr.decode("utf-8", "replace") or "Back-up is leeg")
    digest = sha256(target)
    target.with_suffix(".sha256").write_text(f"{digest}  {target.name}\n", encoding="ascii")
    target.with_suffix(".json").write_text(json.dumps({
        "database": client.database,
        "gemaakt_op": dt.datetime.now().astimezone().isoformat(),
        "sql_bestand": target.name,
        "sql_sha256": digest,
        "sql_bytes": target.stat().st_size,
        "bestaande_controle": guard,
        "tabellen": tables,
        "infrastructuurtabellen_vooraf": existing_names,
    }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return target.with_suffix(".json")


def apply_import(
    client: Client,
    snapshot: Path,
    query: Path,
    basis_id: int,
    metadata: dict[str, Any],
    records: list[dict[str, Any]],
    parking_snapshot: Path,
    parking_query: Path,
    parking_metadata: dict[str, Any],
    parking_records: list[dict[str, Any]],
    plots: dict[int, tuple[str, ogr.Geometry, str]],
) -> tuple[int, int]:
    ensure_schema_extensions(client)
    client.sql(SCHEMA.read_text(encoding="utf-8"))
    snapshot_hash = sha256(snapshot)
    query_text = query.read_text(encoding="utf-8")
    query_hash = hashlib.sha256(query_text.encode("utf-8")).hexdigest()
    timestamp = metadata["timestamp"].replace("T", " ").removesuffix("Z")
    downloaded = dt.datetime.fromtimestamp(snapshot.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S.%f")
    code = "osm_meijendel_fietspaden_" + timestamp[:10].replace("-", "")
    client.sql(
        "INSERT INTO infrastructuurbron_snapshot "
        "(snapshot_code,snapshottype,bron_code,bron_url,licentie,querytekst,query_sha256,bron_timestamp,gedownload_op,bronbestand,bronbestand_sha256,bron_objecten,geselecteerde_objecten,geimporteerde_segmenten,basisgebiedversie_id) VALUES ("
        + ",".join((sql_literal(code), "'lijnen'", "'OSM'", sql_literal(SOURCE_URL), sql_literal(LICENSE),
                    sql_literal(query_text), sql_literal(query_hash), sql_literal(timestamp), sql_literal(downloaded),
                    sql_literal(str(snapshot.relative_to(ROOT))), sql_literal(snapshot_hash), str(metadata["objects"]),
                    str(metadata["selected"]), str(metadata["imported"]), str(basis_id)))
        + ") ON DUPLICATE KEY UPDATE bron_timestamp=VALUES(bron_timestamp),gedownload_op=VALUES(gedownload_op),bronbestand=VALUES(bronbestand),bronbestand_sha256=VALUES(bronbestand_sha256),querytekst=VALUES(querytekst),query_sha256=VALUES(query_sha256),bron_objecten=VALUES(bron_objecten),geselecteerde_objecten=VALUES(geselecteerde_objecten),geimporteerde_segmenten=VALUES(geimporteerde_segmenten),basisgebiedversie_id=VALUES(basisgebiedversie_id)"
    )
    snapshot_id = int(client.scalar(f"SELECT snapshot_id FROM infrastructuurbron_snapshot WHERE bronbestand_sha256={sql_literal(snapshot_hash)}"))
    client.sql(f"DELETE FROM infrastructuursegment_versie WHERE snapshot_id={snapshot_id}")
    identities = [f"('OSM','way',{record['object_id']})" for record in records]
    client.sql(
        "INSERT INTO infrastructuursegment (bron_code,bron_objecttype,bron_object_id) VALUES "
        + ",".join(identities)
        + " ON DUPLICATE KEY UPDATE bron_object_id=VALUES(bron_object_id)"
    )
    segment_ids = {
        int(object_id): int(segment_id)
        for object_id, segment_id in (
            row.split("\t") for row in client.sql(
                "SELECT bron_object_id,segment_id FROM infrastructuursegment "
                "WHERE bron_code='OSM' AND bron_objecttype='way'"
            ).splitlines()
        )
    }
    version_values = []
    for record in records:
        segment_id = segment_ids[record["object_id"]]
        tags_hex = json.dumps(record["tags"], sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode("utf-8").hex()
        changed = str(record["timestamp"]).replace("T", " ").removesuffix("Z") if record["timestamp"] else None
        version_values.append("(" + ",".join(
            (str(segment_id), str(snapshot_id), sql_literal(record["version"]), sql_literal(changed),
             sql_literal(record["changeset"]), sql_literal(record["type"]), sql_literal(record["status"]),
             "'bron_afgeleid'", sql_literal(record["rule"]), sql_literal(record["name"]), sql_literal(record["surface"]),
             f"CAST(CONVERT(UNHEX('{tags_hex}') USING utf8mb4) AS JSON)", sql_literal(timestamp), "NULL",
             f"ST_GeomFromWKB(UNHEX('{record['geometry_hex']}'),28992)", sql_literal(record["wkt"]),
             sql_literal(record["geometry_hash"]), f"{record['length']:.3f}")) + ")")
    for start in range(0, len(version_values), 200):
        client.sql(
            "INSERT INTO infrastructuursegment_versie "
            "(segment_id,snapshot_id,bron_versie,bron_gewijzigd_op,bron_changeset,infrastructuurtype,toegankelijkheidsstatus,beoordelingsstatus,classificatieregel,naam,oppervlak,bron_tags,geldig_vanaf,geldig_tot,geometrie,geometrie_wkt,geometrie_sha256,lengte_m) VALUES "
            + ",".join(version_values[start:start + 200])
        )
    version_ids = {
        int(object_id): int(version_id)
        for object_id, version_id in (
            row.split("\t") for row in client.sql(
                "SELECT s.bron_object_id,v.segment_versie_id "
                "FROM infrastructuursegment_versie v JOIN infrastructuursegment s USING(segment_id) "
                f"WHERE v.snapshot_id={snapshot_id}"
            ).splitlines()
        )
    }
    overlap_values = []
    for record in records:
        version_id = version_ids[record["object_id"]]
        for plot_id, length, percentage, plot_hash in derive_plot_overlaps(record["geometry"], plots):
            overlap_values.append("(" + ",".join((str(version_id), str(plot_id), sql_literal(record["type"]),
                sql_literal(record["status"]), f"{length:.3f}", f"{record['length']:.3f}", f"{percentage:.6f}",
                sql_literal(record["geometry_hash"]), sql_literal(plot_hash))) + ")")
    for start in range(0, len(overlap_values), 500):
        client.sql(
            "INSERT INTO infrastructuursegment_plot_afleiding "
            "(segment_versie_id,plot_id,infrastructuurtype,toegankelijkheidsstatus,doorsnijding_m,segmentlengte_m,aandeel_pct,segment_geometrie_sha256,plot_geometrie_sha256) VALUES "
            + ",".join(overlap_values[start:start + 500])
        )
    client.sql(
        "DELETE s FROM infrastructuursegment s "
        "WHERE NOT EXISTS (SELECT 1 FROM infrastructuursegment_versie v WHERE v.segment_id=s.segment_id)"
    )
    client.sql(
        "UPDATE infrastructuursegment_versie v "
        "JOIN infrastructuurbron_snapshot s USING(snapshot_id) "
        "SET v.geldig_vanaf=IF(s.bron_timestamp=(SELECT MIN(s0.bron_timestamp) FROM infrastructuurbron_snapshot s0 WHERE s0.snapshottype='lijnen'),'1955-01-01 00:00:00',s.bron_timestamp),"
        "v.geldig_vanaf_grondslag=IF(s.bron_timestamp=(SELECT MIN(s0.bron_timestamp) FROM infrastructuurbron_snapshot s0 WHERE s0.snapshottype='lijnen'),'inschatting','bron'),"
        "v.geldig_tot=(SELECT MIN(s2.bron_timestamp) FROM infrastructuurbron_snapshot s2 WHERE s2.snapshottype='lijnen' AND s2.bron_timestamp>s.bron_timestamp)"
    )
    parking_snapshot_id = apply_parking(
        client, parking_snapshot, parking_query, basis_id, parking_metadata, parking_records
    )
    upsert_plot_aggregates(
        client, metadata, parking_metadata, snapshot_id, parking_snapshot_id,
        records, plots, parking_records,
    )
    return snapshot_id, parking_snapshot_id


def apply_parking(
    client: Client,
    snapshot: Path,
    query: Path,
    basis_id: int,
    metadata: dict[str, Any],
    records: list[dict[str, Any]],
) -> int:
    snapshot_hash = sha256(snapshot)
    query_text = query.read_text(encoding="utf-8")
    query_hash = hashlib.sha256(query_text.encode("utf-8")).hexdigest()
    timestamp = metadata["timestamp"].replace("T", " ").removesuffix("Z")
    downloaded = dt.datetime.fromtimestamp(snapshot.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S.%f")
    code = "osm_meijendel_parkeerplaatsen_" + timestamp[:10].replace("-", "")
    client.sql(
        "INSERT INTO infrastructuurbron_snapshot "
        "(snapshot_code,snapshottype,bron_code,bron_url,licentie,querytekst,query_sha256,bron_timestamp,gedownload_op,bronbestand,bronbestand_sha256,bron_objecten,geselecteerde_objecten,geimporteerde_segmenten,basisgebiedversie_id) VALUES ("
        + ",".join((sql_literal(code), "'voorzieningen'", "'OSM'", sql_literal(SOURCE_URL), sql_literal(LICENSE),
                    sql_literal(query_text), sql_literal(query_hash), sql_literal(timestamp), sql_literal(downloaded),
                    sql_literal(str(snapshot.relative_to(ROOT))), sql_literal(snapshot_hash), str(metadata["objects"]),
                    str(metadata["selected"]), str(metadata["imported"]), str(basis_id)))
        + ") ON DUPLICATE KEY UPDATE snapshottype=VALUES(snapshottype),bron_timestamp=VALUES(bron_timestamp),gedownload_op=VALUES(gedownload_op),bronbestand=VALUES(bronbestand),bronbestand_sha256=VALUES(bronbestand_sha256),querytekst=VALUES(querytekst),query_sha256=VALUES(query_sha256),bron_objecten=VALUES(bron_objecten),geselecteerde_objecten=VALUES(geselecteerde_objecten),geimporteerde_segmenten=VALUES(geimporteerde_segmenten),basisgebiedversie_id=VALUES(basisgebiedversie_id)"
    )
    snapshot_id = int(client.scalar(
        f"SELECT snapshot_id FROM infrastructuurbron_snapshot WHERE bronbestand_sha256={sql_literal(snapshot_hash)}"
    ))
    client.sql(f"DELETE FROM infrastructuurvoorziening_versie WHERE snapshot_id={snapshot_id}")
    identities = [
        "('OSM'," + sql_literal(record["object_type"]) + f",{record['object_id']})"
        for record in records
    ]
    client.sql(
        "INSERT INTO infrastructuurvoorziening (bron_code,bron_objecttype,bron_object_id) VALUES "
        + ",".join(identities)
        + " ON DUPLICATE KEY UPDATE bron_object_id=VALUES(bron_object_id)"
    )
    object_ids = {
        (object_type, int(object_id)): int(voorziening_id)
        for object_type, object_id, voorziening_id in (
            row.split("\t") for row in client.sql(
                "SELECT bron_objecttype,bron_object_id,voorziening_id FROM infrastructuurvoorziening WHERE bron_code='OSM'"
            ).splitlines()
        )
    }
    values = []
    for record in records:
        tags_hex = json.dumps(record["tags"], sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode("utf-8").hex()
        changed = str(record["timestamp"]).replace("T", " ").removesuffix("Z") if record["timestamp"] else None
        values.append("(" + ",".join((
            str(object_ids[(record["object_type"], record["object_id"])]), str(snapshot_id),
            sql_literal(record["version"]), sql_literal(changed), sql_literal(record["changeset"]),
            "'parkeerplaats'", sql_literal(record["name"]),
            f"CAST(CONVERT(UNHEX('{tags_hex}') USING utf8mb4) AS JSON)",
            "'1955-01-01 00:00:00'", "'inschatting'", "NULL", str(record["inside"]),
            f"{record['distance']:.3f}", f"ST_GeomFromWKB(UNHEX('{record['geometry_hex']}'),28992)",
            sql_literal(record["wkt"]), sql_literal(record["geometry_hash"]),
        )) + ")")
    for start in range(0, len(values), 250):
        client.sql(
            "INSERT INTO infrastructuurvoorziening_versie "
            "(voorziening_id,snapshot_id,bron_versie,bron_gewijzigd_op,bron_changeset,voorzieningstype,naam,bron_tags,geldig_vanaf,geldig_vanaf_grondslag,geldig_tot,binnen_basisgebied,afstand_basisgebied_m,geometrie,geometrie_wkt,geometrie_sha256) VALUES "
            + ",".join(values[start:start + 250])
        )
    client.sql(
        "DELETE o FROM infrastructuurvoorziening o "
        "WHERE NOT EXISTS (SELECT 1 FROM infrastructuurvoorziening_versie v WHERE v.voorziening_id=o.voorziening_id)"
    )
    client.sql(
        "UPDATE infrastructuurvoorziening_versie v "
        "JOIN infrastructuurbron_snapshot s USING(snapshot_id) "
        "SET v.geldig_vanaf=IF(s.bron_timestamp=(SELECT MIN(s0.bron_timestamp) FROM infrastructuurbron_snapshot s0 WHERE s0.snapshottype='voorzieningen'),'1955-01-01 00:00:00',s.bron_timestamp),"
        "v.geldig_vanaf_grondslag=IF(s.bron_timestamp=(SELECT MIN(s0.bron_timestamp) FROM infrastructuurbron_snapshot s0 WHERE s0.snapshottype='voorzieningen'),'inschatting','bron'),"
        "v.geldig_tot=(SELECT MIN(s2.bron_timestamp) FROM infrastructuurbron_snapshot s2 WHERE s2.snapshottype='voorzieningen' AND s2.bron_timestamp>s.bron_timestamp)"
    )
    return snapshot_id


def upsert_plot_aggregates(
    client: Client,
    metadata: dict[str, Any],
    parking_metadata: dict[str, Any],
    snapshot_id: int,
    parking_snapshot_id: int,
    records: list[dict[str, Any]],
    plots: dict[int, tuple[str, ogr.Geometry, str]],
    parking_records: list[dict[str, Any]],
) -> int:
    geometry_year = int(metadata["timestamp"][:4])
    plot_years = int(client.scalar(
        f"SELECT COUNT(*) FROM plot_jaar_oppervlak WHERE jaar={geometry_year} AND plot_id IN ("
        + ",".join(str(plot_id) for plot_id in sorted(plots)) + ")"
    ))
    if plot_years != len(plots):
        raise RuntimeError(
            f"Verwacht {len(plots)} plotoppervlakken voor {geometry_year}, gevonden {plot_years}"
        )
    line_year = int(client.scalar(
        "SELECT MAX(YEAR(geldig_vanaf)) FROM infrastructuursegment_versie "
        f"WHERE snapshot_id={snapshot_id}"
    ))
    parking_year = int(client.scalar(
        "SELECT MAX(YEAR(geldig_vanaf)) FROM infrastructuurvoorziening_versie "
        f"WHERE snapshot_id={parking_snapshot_id}"
    ))
    valid_from_year = max(line_year, parking_year)
    year = geometry_year
    rows = calculate_plot_aggregates(
        records, plots, [record["geometry"] for record in parking_records]
    )
    source_timestamp = max(metadata["timestamp"], parking_metadata["timestamp"])
    source = f"OSM_SNAPSHOT_{source_timestamp[:10].replace('-', '')}"
    client.sql("DELETE FROM plot_jaar_infra WHERE jaar=2024")
    client.sql(
        "UPDATE plot_jaar_infra SET geldig_tot="
        f"'{valid_from_year}-01-01' WHERE variabele IN "
        "('afstand_pad_m','afstand_parkeerplaats_m','padlengte_m_per_ha') "
        f"AND geldig_vanaf<'{valid_from_year}-01-01' "
        f"AND (geldig_tot IS NULL OR geldig_tot>'{valid_from_year}-01-01')"
    )
    client.sql(
        f"DELETE FROM plot_jaar_infra WHERE bron={sql_literal(source)} "
        "AND variabele IN ('afstand_pad_m','afstand_parkeerplaats_m','padlengte_m_per_ha')"
    )
    values = [
        "(" + ",".join((
            str(plot_id), str(year), sql_literal(source), sql_literal(variable), f"{value:.3f}",
            f"'{valid_from_year}-01-01'", "'inschatting'" if valid_from_year == 1955 else "'bron'", "NULL",
        )) + ")"
        for plot_id, variable, value in rows
    ]
    client.sql(
        "INSERT INTO plot_jaar_infra "
        "(plot_id,jaar,bron,variabele,waarde,geldig_vanaf,geldig_vanaf_grondslag,geldig_tot) VALUES "
        + ",".join(values)
    )
    return len(rows)


def verify(
    client: Client,
    snapshot_id: int,
    parking_snapshot_id: int,
    metadata: dict[str, Any],
    parking_metadata: dict[str, Any],
    guard: dict[str, str],
) -> dict[str, Any]:
    if existing_guard(client) != guard:
        raise AssertionError("Bestaande infrastructuur- of toegankelijkheidsgegevens zijn gewijzigd")
    result = {
        "snapshot_id": snapshot_id,
        "bron_objecten": int(client.scalar(f"SELECT bron_objecten FROM infrastructuurbron_snapshot WHERE snapshot_id={snapshot_id}")),
        "geselecteerde_objecten": int(client.scalar(f"SELECT geselecteerde_objecten FROM infrastructuurbron_snapshot WHERE snapshot_id={snapshot_id}")),
        "segmenten": int(client.scalar(f"SELECT COUNT(*) FROM infrastructuursegment_versie WHERE snapshot_id={snapshot_id}")),
        "openbaar": int(client.scalar(f"SELECT COUNT(*) FROM infrastructuursegment_versie WHERE snapshot_id={snapshot_id} AND toegankelijkheidsstatus='openbaar'")),
        "beperkt": int(client.scalar(f"SELECT COUNT(*) FROM infrastructuursegment_versie WHERE snapshot_id={snapshot_id} AND toegankelijkheidsstatus='beperkt_toegankelijk'")),
        "afgesloten": int(client.scalar(f"SELECT COUNT(*) FROM infrastructuursegment_versie WHERE snapshot_id={snapshot_id} AND toegankelijkheidsstatus='afgesloten'")),
        "totale_lengte_m": float(client.scalar(f"SELECT ROUND(SUM(lengte_m),3) FROM infrastructuursegment_versie WHERE snapshot_id={snapshot_id}")),
        "plotdoorsnijdingen": int(client.scalar("SELECT COUNT(*) FROM infrastructuursegment_plot_afleiding")),
        "plots_met_infrastructuur": int(client.scalar("SELECT COUNT(DISTINCT plot_id) FROM infrastructuursegment_plot_afleiding")),
        "parkeerplaatsen": int(client.scalar(f"SELECT COUNT(*) FROM infrastructuurvoorziening_versie WHERE snapshot_id={parking_snapshot_id}")),
        "lijnversies_zonder_kavel": int(client.scalar(
            f"SELECT COUNT(*) FROM infrastructuursegment_versie v WHERE v.snapshot_id={snapshot_id} "
            "AND NOT EXISTS (SELECT 1 FROM infrastructuursegment_plot_afleiding a "
            "WHERE a.segment_versie_id=v.segment_versie_id)"
        )),
        "parkeerversies_zonder_kavel": int(client.scalar(
            f"SELECT COUNT(*) FROM infrastructuurvoorziening_versie v WHERE v.snapshot_id={parking_snapshot_id} "
            "AND NOT EXISTS (SELECT 1 FROM plots p WHERE p.in_gebruik=1 AND p.geom IS NOT NULL "
            "AND ST_Intersects(v.geometrie,p.geom))"
        )),
        "lijnversies_geschat_vanaf_1955": int(client.scalar(
            f"SELECT COUNT(*) FROM infrastructuursegment_versie WHERE snapshot_id={snapshot_id} "
            "AND geldig_vanaf='1955-01-01 00:00:00' AND geldig_vanaf_grondslag='inschatting' AND geldig_tot IS NULL"
        )),
        "parkeerversies_geschat_vanaf_1955": int(client.scalar(
            f"SELECT COUNT(*) FROM infrastructuurvoorziening_versie WHERE snapshot_id={parking_snapshot_id} "
            "AND geldig_vanaf='1955-01-01 00:00:00' AND geldig_vanaf_grondslag='inschatting' AND geldig_tot IS NULL"
        )),
        "oude_infra_2024": int(client.scalar("SELECT COUNT(*) FROM plot_jaar_infra WHERE jaar=2024")),
        "aggregaat_startjaar": int(client.scalar(
            f"SELECT YEAR(MIN(geldig_vanaf)) FROM plot_jaar_infra WHERE bron='OSM_SNAPSHOT_{max(metadata['timestamp'], parking_metadata['timestamp'])[:10].replace('-', '')}'"
        )),
        "nieuwe_aggregaten": int(client.scalar(
            f"SELECT COUNT(*) FROM plot_jaar_infra WHERE bron='OSM_SNAPSHOT_{max(metadata['timestamp'], parking_metadata['timestamp'])[:10].replace('-', '')}' "
            "AND variabele IN ('afstand_pad_m','afstand_parkeerplaats_m','padlengte_m_per_ha')"
        )),
    }
    if result["bron_objecten"] != metadata["objects"] or result["geselecteerde_objecten"] != metadata["selected"]:
        raise AssertionError(result)
    if result["segmenten"] != metadata["imported"]:
        raise AssertionError(result)
    if result["openbaar"] + result["beperkt"] + result["afgesloten"] != result["segmenten"]:
        raise AssertionError(result)
    if result["parkeerplaatsen"] != parking_metadata["imported"]:
        raise AssertionError(result)
    if result["lijnversies_zonder_kavel"] != 0 or result["parkeerversies_zonder_kavel"] != 0:
        raise AssertionError(result)
    if result["lijnversies_geschat_vanaf_1955"] != result["segmenten"]:
        raise AssertionError(result)
    if result["parkeerversies_geschat_vanaf_1955"] != result["parkeerplaatsen"]:
        raise AssertionError(result)
    if result["aggregaat_startjaar"] != 1955:
        raise AssertionError(result)
    if result["oude_infra_2024"] != 0 or result["nieuwe_aggregaten"] != 165:
        raise AssertionError(result)
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", default="Meijendel")
    parser.add_argument("--snapshot", type=Path, default=DEFAULT_JSON)
    parser.add_argument("--query", type=Path, default=DEFAULT_QUERY)
    parser.add_argument("--previous", type=Path, default=DEFAULT_PREVIOUS)
    parser.add_argument("--bgt", type=Path, default=DEFAULT_BGT)
    parser.add_argument("--parking-snapshot", type=Path, default=DEFAULT_PARKING_JSON)
    parser.add_argument("--parking-query", type=Path, default=DEFAULT_PARKING_QUERY)
    parser.add_argument("--backup-dir", type=Path, default=BACKUP_ROOT)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--verify", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    client = Client(args.database)
    basis_id, basis, plots = read_db_geometries(client)
    metadata, records = prepare(args.snapshot, basis, plots)
    parking_metadata, parking_records = prepare_parking(args.parking_snapshot, basis, plots)
    guard = existing_guard(client)
    report: dict[str, Any] = {
        **metadata,
        "totale_lengte_m": round(sum(r["length"] for r in records), 3),
        "parkeerplaatsen_bron": parking_metadata["objects"],
        "parkeerplaatsen_met_kavelrelatie": parking_metadata["imported"],
        "parkeerplaatsen_bronmoment": parking_metadata["timestamp"],
    }
    if args.previous.is_file():
        report["vergelijking_vorige_osm_laag"] = compare_records(
            read_previous(args.previous, basis, plots), records
        )
    if args.bgt.is_file():
        cycleways = [record for record in records if record["type"] == "fietspad"]
        report["vergelijking_bgt_fietspadvlakken"] = compare_with_bgt(
            cycleways, read_bgt_cycleway_union(args.bgt)
        )
    if args.apply:
        report["backup_metadata"] = str(backup(client, args.backup_dir, guard))
        snapshot_id, parking_snapshot_id = apply_import(
            client, args.snapshot, args.query, basis_id, metadata, records,
            args.parking_snapshot, args.parking_query, parking_metadata, parking_records, plots,
        )
        report.update(verify(
            client, snapshot_id, parking_snapshot_id, metadata, parking_metadata, guard
        ))
    elif args.verify:
        snapshot_hash = sha256(args.snapshot)
        snapshot_id = int(client.scalar(f"SELECT snapshot_id FROM infrastructuurbron_snapshot WHERE bronbestand_sha256={sql_literal(snapshot_hash)}"))
        parking_hash = sha256(args.parking_snapshot)
        parking_snapshot_id = int(client.scalar(f"SELECT snapshot_id FROM infrastructuurbron_snapshot WHERE bronbestand_sha256={sql_literal(parking_hash)}"))
        report.update(verify(
            client, snapshot_id, parking_snapshot_id, metadata, parking_metadata, guard
        ))
    print(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
