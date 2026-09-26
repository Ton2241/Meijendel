#!/usr/bin/env python3
"""Profileer en selecteer externe Darwin Core-bronnen voor Meijendel.

De veldbetekenis wordt uit ``meta.xml`` gelezen. De uitvoer bevat uitsluitend
een controleerbare bronselectie; toelating tot de analytische database volgt
pas na de afzonderlijke overlap- en kwaliteitscontrole.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import xml.etree.ElementTree as ET
import zipfile
from collections import Counter
from pathlib import Path
from typing import Iterator


MEIJENDEL_LOCALITIES = re.compile(
    r"\b(meijendel|bierlap|kijfhoek|ganzenhoek|kikkervallei(?:en)?|"
    r"parnassiapad|scheepje|de loopert|helmduin(?:en)?|pan\s*17(?:\.1)?|"
    r"pan\s*26(?:\.1\.1)?|kwelplas\s*(?:k10|g15|g21))\b",
    re.IGNORECASE,
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _local_name(value: str) -> str:
    return value.rsplit("/", 1)[-1]


def _decoded_separator(value: str | None, default: str) -> str:
    if value is None:
        return default
    return value.replace("\\t", "\t").replace("\\n", "\n").replace("\\r", "\r")


def _parse_section(section: ET.Element) -> tuple[str, str, int, dict[int, str]]:
    filename = next(node for node in section.iter() if node.tag.rsplit("}", 1)[-1] == "location").text
    delimiter = _decoded_separator(section.attrib.get("fieldsTerminatedBy"), "\t")
    ignore_headers = int(section.attrib.get("ignoreHeaderLines", "0"))
    fields: dict[int, str] = {}
    for node in section:
        kind = node.tag.rsplit("}", 1)[-1]
        if kind in {"id", "coreid"}:
            fields[int(node.attrib["index"])] = "_core_id"
        elif kind == "field":
            fields[int(node.attrib["index"])] = _local_name(node.attrib["term"])
    return filename, delimiter, ignore_headers, fields


def dwca_section(archive: zipfile.ZipFile, section_name: str = "core") -> tuple[str, str, int, dict[int, str]]:
    root = ET.fromstring(archive.read("meta.xml"))
    section = next((node for node in root if node.tag.rsplit("}", 1)[-1] == section_name), None)
    if section is None:
        raise ValueError(f"Darwin Core Archive bevat geen sectie {section_name}")
    return _parse_section(section)


def dwca_section_by_file(archive: zipfile.ZipFile, filename: str) -> tuple[str, str, int, dict[int, str]]:
    root = ET.fromstring(archive.read("meta.xml"))
    for section in root:
        location = next(
            (node.text for node in section.iter() if node.tag.rsplit("}", 1)[-1] == "location"),
            None,
        )
        if location == filename:
            return _parse_section(section)
    raise ValueError(f"Darwin Core Archive bevat geen sectie voor {filename}")


def iter_section_rows(path: Path, section_name: str = "core") -> Iterator[dict[str, str]]:
    with zipfile.ZipFile(path) as archive:
        filename, delimiter, ignore_headers, fields = dwca_section(archive, section_name)
        with archive.open(filename) as binary:
            import io

            text = io.TextIOWrapper(binary, encoding="utf-8-sig", errors="replace", newline="")
            reader = csv.reader(text, delimiter=delimiter)
            for _ in range(ignore_headers):
                next(reader, None)
            for values in reader:
                if not values:
                    continue
                yield {name: values[index] if index < len(values) else "" for index, name in fields.items()}


def iter_named_section_rows(path: Path, filename: str) -> Iterator[dict[str, str]]:
    with zipfile.ZipFile(path) as archive:
        source, delimiter, ignore_headers, fields = dwca_section_by_file(archive, filename)
        with archive.open(source) as binary:
            import io

            text = io.TextIOWrapper(binary, encoding="utf-8-sig", errors="replace", newline="")
            reader = csv.reader(text, delimiter=delimiter)
            for _ in range(ignore_headers):
                next(reader, None)
            for values in reader:
                if values:
                    yield {name: values[index] if index < len(values) else "" for index, name in fields.items()}


def iter_core_rows(path: Path) -> Iterator[dict[str, str]]:
    return iter_section_rows(path, "core")


def _point_on_segment(x: float, y: float, a: list[float], b: list[float], epsilon: float = 1e-12) -> bool:
    cross = (x - a[0]) * (b[1] - a[1]) - (y - a[1]) * (b[0] - a[0])
    if abs(cross) > epsilon:
        return False
    return min(a[0], b[0]) - epsilon <= x <= max(a[0], b[0]) + epsilon and min(a[1], b[1]) - epsilon <= y <= max(a[1], b[1]) + epsilon


def point_in_ring(x: float, y: float, ring: list[list[float]]) -> bool:
    inside = False
    for index in range(len(ring) - 1):
        first, second = ring[index], ring[index + 1]
        if _point_on_segment(x, y, first, second):
            return True
        if (first[1] > y) != (second[1] > y):
            crossing_x = first[0] + (y - first[1]) * (second[0] - first[0]) / (second[1] - first[1])
            if crossing_x > x:
                inside = not inside
    return inside


def point_in_geometry(x: float, y: float, geometry: dict) -> bool:
    if geometry["type"] == "Polygon":
        polygons = [geometry["coordinates"]]
    elif geometry["type"] == "MultiPolygon":
        polygons = geometry["coordinates"]
    else:
        raise ValueError(f"Niet-ondersteund begrenzingstype: {geometry['type']}")
    for polygon in polygons:
        if point_in_ring(x, y, polygon[0]) and not any(point_in_ring(x, y, hole) for hole in polygon[1:]):
            return True
    return False


def geometry_bounds(geometry: dict) -> tuple[float, float, float, float]:
    if geometry["type"] == "Polygon":
        polygons = [geometry["coordinates"]]
    elif geometry["type"] == "MultiPolygon":
        polygons = geometry["coordinates"]
    else:
        raise ValueError(f"Niet-ondersteund begrenzingstype: {geometry['type']}")
    points = (point for polygon in polygons for ring in polygon for point in ring)
    first = next(points)
    minimum_x = maximum_x = first[0]
    minimum_y = maximum_y = first[1]
    for x, y in points:
        minimum_x = min(minimum_x, x)
        maximum_x = max(maximum_x, x)
        minimum_y = min(minimum_y, y)
        maximum_y = max(maximum_y, y)
    return minimum_x, minimum_y, maximum_x, maximum_y


def explicit_meijendel_locality(value: str | None) -> bool:
    return bool(value and MEIJENDEL_LOCALITIES.search(value))


def coordinates(row: dict[str, str]) -> tuple[float, float] | None:
    try:
        latitude = float(row.get("decimalLatitude", ""))
        longitude = float(row.get("decimalLongitude", ""))
    except (TypeError, ValueError):
        return None
    return longitude, latitude


def event_year(row: dict[str, str]) -> str:
    if row.get("year"):
        return row["year"]
    match = re.search(r"(?:18|19|20)\d{2}", row.get("eventDate", ""))
    return match.group(0) if match else ""


def load_geometry(path: Path) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("type") == "FeatureCollection":
        return payload["features"][0]["geometry"]
    if payload.get("type") == "Feature":
        return payload["geometry"]
    return payload


def classify_row(
    row: dict[str, str],
    geometry: dict,
    bounds: tuple[float, float, float, float] | None = None,
) -> dict[str, str]:
    point = coordinates(row)
    bounds = bounds or geometry_bounds(geometry)
    in_bounds = bool(
        point
        and bounds[0] <= point[0] <= bounds[2]
        and bounds[1] <= point[1] <= bounds[3]
    )
    within = bool(in_bounds and point_in_geometry(point[0], point[1], geometry))
    locality = " | ".join(filter(None, (row.get("locality"), row.get("verbatimLocality"), row.get("locationRemarks"))))
    explicit = explicit_meijendel_locality(locality)
    uncertainty = row.get("coordinateUncertaintyInMeters", "")
    admitted = within and explicit
    return {
        **row,
        "_binnen_basisgebied": "1" if within else "0",
        "_expliciet_meijendel": "1" if explicit else "0",
        "_voorlopig_toelaatbaar": "1" if admitted else "0",
        "_jaar": event_year(row),
        "_coordinaten_onzekerheid_m": uncertainty,
    }


def profile(path: Path, geometry: dict) -> tuple[list[dict[str, str]], dict]:
    selected: list[dict[str, str]] = []
    years: Counter[str] = Counter()
    total = inside = explicit = admitted = missing_coordinates = 0
    bounds = geometry_bounds(geometry)
    for source_row in iter_core_rows(path):
        total += 1
        row = classify_row(source_row, geometry, bounds)
        if coordinates(source_row) is None:
            missing_coordinates += 1
        if row["_binnen_basisgebied"] == "1":
            inside += 1
            selected.append(row)
            if row["_jaar"]:
                years[row["_jaar"]] += 1
        if row["_expliciet_meijendel"] == "1":
            explicit += 1
        if row["_voorlopig_toelaatbaar"] == "1":
            admitted += 1
    result = {
        "bestand": path.name,
        "sha256": sha256_file(path),
        "bronregels": total,
        "zonder_coordinaten": missing_coordinates,
        "binnen_basisgebied": inside,
        "expliciet_meijendel_alle_regels": explicit,
        "voorlopig_toelaatbaar": admitted,
        "jaar_van_binnen_basisgebied": min(years) if years else None,
        "jaar_tot_binnen_basisgebied": max(years) if years else None,
    }
    return selected, result


def select_first_extension(path: Path, selected_core_ids: set[str]) -> list[dict[str, str]]:
    try:
        return [row for row in iter_section_rows(path, "extension") if row.get("_core_id") in selected_core_ids]
    except ValueError:
        return []


def select_named_section(path: Path, filename: str, selected_core_ids: set[str]) -> list[dict[str, str]]:
    return [row for row in iter_named_section_rows(path, filename) if row.get("_core_id") in selected_core_ids]


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = sorted({key for row in rows for key in row})
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--boundary", type=Path, required=True)
    parser.add_argument("--output-csv", type=Path, required=True)
    parser.add_argument("--output-profile", type=Path, required=True)
    parser.add_argument("--output-extension-csv", type=Path)
    parser.add_argument(
        "--named-extension",
        nargs=2,
        action="append",
        metavar=("ARCHIVE_FILE", "OUTPUT_CSV"),
        help="Selecteer een specifieke extensiontabel op de geselecteerde core-ID's.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    rows, result = profile(args.archive, load_geometry(args.boundary))
    write_csv(args.output_csv, rows)
    if args.output_extension_csv:
        extension = select_first_extension(args.archive, {row.get("_core_id", "") for row in rows})
        write_csv(args.output_extension_csv, extension)
        result["geselecteerde_extensionregels"] = len(extension)
    for filename, output in args.named_extension or []:
        extension = select_named_section(args.archive, filename, {row.get("_core_id", "") for row in rows})
        write_csv(Path(output), extension)
        result[f"geselecteerde_{filename}_regels"] = len(extension)
    args.output_profile.parent.mkdir(parents=True, exist_ok=True)
    args.output_profile.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
