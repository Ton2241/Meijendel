#!/usr/bin/env python3
"""Bouw de geversioneerde project- en Natura 2000-lagen voor Meijendel.

De projectgrens volgt de door de VWG vastgestelde straatnamen en de officiële
gemiddelde hoogwaterlijn. De officiële Natura 2000-laag blijft daarvan bewust
gescheiden. Alle geometrieën worden geschreven in EPSG:28992.
"""

from __future__ import annotations

import argparse
import hashlib
import heapq
import json
import math
import tempfile
import urllib.parse
import urllib.request
from collections import defaultdict
from datetime import date
from pathlib import Path
from typing import Iterable

from osgeo import ogr, osr


ogr.UseExceptions()

ROOT = Path(__file__).parents[2]
DEFAULT_OUTPUT = ROOT / "gis" / "vectors" / "meijendel_bereik" / "meijendel_ruimtelijke_lagen.gpkg"
DEFAULT_MANIFEST = ROOT / "gis" / "vectors" / "meijendel_bereik" / "meijendel_ruimtelijke_lagen_manifest.json"
VERSION = "2026-09-24.1"

BOUNDARY_ROADS = (
    "De Wassenaarse Slag",
    "Katwijkseweg",
    "Storm van 's-Gravesandeweg",
    "Jagerslaan",
    "Groot Haesebroekseweg",
    "Buurtweg",
    "Landscheidingsweg",
    "Zwolsestraat",
    "Groningsestraat",
    "Gevers Deynootweg",
)

ROAD_ALIASES = {
    "Jagerslaan (noord)": "Jagerslaan",
    "Jagerslaan (zuid)": "Jagerslaan",
}

NWB_WFS = "https://service.pdok.nl/rws/nationaal-wegenbestand-wegen/wfs/v1_0"
NATURA_API = "https://api.pdok.nl/rvo/natura2000/ogc/v1/collections/natura2000/items"
COAST_API = "https://api.pdok.nl/kadaster/brt-zeegebieden/ogc/v1/collections/coastline/items"
RD_URI = "http://www.opengis.net/def/crs/EPSG/0/28992"
BBOX = "79000,457000,89000,469000"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fetch_json(url: str, params: dict[str, str | int]) -> tuple[dict, bytes]:
    request_url = f"{url}?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(request_url, headers={"User-Agent": "VWG-Meijendel/1.0"})
    with urllib.request.urlopen(request, timeout=120) as response:
        raw = response.read()
    return json.loads(raw), raw


def geometry_from_json(value: dict) -> ogr.Geometry:
    geometry = ogr.CreateGeometryFromJson(json.dumps(value))
    if geometry is None:
        raise ValueError("GeoJSON-geometrie kon niet worden gelezen")
    geometry.AssignSpatialReference(rd_srs())
    return geometry


def rd_srs() -> osr.SpatialReference:
    spatial_reference = osr.SpatialReference()
    spatial_reference.ImportFromEPSG(28992)
    spatial_reference.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    return spatial_reference


def fetch_selected_roads() -> tuple[dict[str, list[ogr.Geometry]], list[str]]:
    selected = set(BOUNDARY_ROADS)
    selected.update(ROAD_ALIASES)
    grouped: dict[str, list[ogr.Geometry]] = defaultdict(list)
    hashes: list[str] = []
    start_index = 0
    while True:
        payload, raw = fetch_json(
            NWB_WFS,
            {
                "service": "WFS",
                "version": "2.0.0",
                "request": "GetFeature",
                "typeNames": "nwbwegen:wegvakken",
                "srsName": "EPSG:28992",
                "bbox": f"{BBOX},EPSG:28992",
                "startIndex": start_index,
                "outputFormat": "application/json",
            },
        )
        hashes.append(sha256_bytes(raw))
        features = payload.get("features", [])
        for feature in features:
            original_name = feature.get("properties", {}).get("sttNaam")
            if original_name not in selected:
                continue
            name = ROAD_ALIASES.get(original_name, original_name)
            grouped[name].append(geometry_from_json(feature["geometry"]))
        if len(features) < 1000:
            break
        start_index += len(features)
    missing = [name for name in BOUNDARY_ROADS if not grouped.get(name)]
    if missing:
        raise ValueError(f"Ontbrekende grenswegen in NWB: {', '.join(missing)}")
    return grouped, hashes


def fetch_natura2000() -> tuple[ogr.Geometry, dict, str]:
    payload, raw = fetch_json(
        NATURA_API,
        {
            "f": "json",
            "limit": 100,
            "crs": RD_URI,
            "bbox": BBOX,
            "bbox-crs": RD_URI,
        },
    )
    matches = [feature for feature in payload.get("features", []) if feature.get("properties", {}).get("nr") == 97]
    if len(matches) != 1:
        raise ValueError(f"Verwacht één Natura 2000-object met nummer 97; gevonden: {len(matches)}")
    feature = matches[0]
    return geometry_from_json(feature["geometry"]), feature.get("properties", {}), sha256_bytes(raw)


def fetch_coastline() -> tuple[ogr.Geometry, str]:
    payload, raw = fetch_json(
        COAST_API,
        {
            "f": "json",
            "limit": 100,
            "crs": RD_URI,
            "bbox": BBOX,
            "bbox-crs": RD_URI,
        },
    )
    geometries = [geometry_from_json(feature["geometry"]) for feature in payload.get("features", [])]
    if not geometries:
        raise ValueError("Geen kustlijn gevonden")
    merged = geometries[0].Clone()
    for geometry in geometries[1:]:
        merged = merged.Union(geometry)
    return merged, sha256_bytes(raw)


def iter_lines(geometry: ogr.Geometry) -> Iterable[ogr.Geometry]:
    name = geometry.GetGeometryName().upper()
    if name == "LINESTRING":
        yield geometry
        return
    for index in range(geometry.GetGeometryCount()):
        child = geometry.GetGeometryRef(index)
        yield from iter_lines(child)


def build_graph(geometries: list[ogr.Geometry], connector_distance: float) -> tuple[list[tuple[float, float]], dict[int, list[tuple[int, float]]]]:
    vertices: list[tuple[float, float]] = []
    index: dict[tuple[float, float], int] = {}
    adjacency: dict[int, list[tuple[int, float]]] = defaultdict(list)

    def node(x: float, y: float) -> int:
        key = (round(x, 2), round(y, 2))
        if key not in index:
            index[key] = len(vertices)
            vertices.append((x, y))
        return index[key]

    for geometry in geometries:
        for line in iter_lines(geometry):
            nodes = [node(*line.GetPoint_2D(i)) for i in range(line.GetPointCount())]
            for left, right in zip(nodes, nodes[1:]):
                distance = math.dist(vertices[left], vertices[right])
                adjacency[left].append((right, distance))
                adjacency[right].append((left, distance))

    buckets: dict[tuple[int, int], list[int]] = defaultdict(list)
    for i, (x, y) in enumerate(vertices):
        buckets[(int(x // connector_distance), int(y // connector_distance))].append(i)
    for i, (x, y) in enumerate(vertices):
        bx, by = int(x // connector_distance), int(y // connector_distance)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for j in buckets[(bx + dx, by + dy)]:
                    if j <= i:
                        continue
                    distance = math.dist((x, y), vertices[j])
                    if distance <= connector_distance:
                        adjacency[i].append((j, distance))
                        adjacency[j].append((i, distance))
    return vertices, adjacency


def closest_nodes(left: list[tuple[float, float]], right: list[tuple[float, float]]) -> tuple[float, int, int]:
    return min((math.dist(a, b), i, j) for i, a in enumerate(left) for j, b in enumerate(right))


def shortest_path(
    vertices: list[tuple[float, float]],
    adjacency: dict[int, list[tuple[int, float]]],
    start: int,
    end: int,
) -> list[tuple[float, float]]:
    distances = {start: 0.0}
    previous: dict[int, int] = {}
    queue = [(0.0, start)]
    while queue:
        distance, node = heapq.heappop(queue)
        if distance != distances[node]:
            continue
        if node == end:
            break
        for neighbour, weight in adjacency[node]:
            candidate = distance + weight
            if candidate < distances.get(neighbour, float("inf")):
                distances[neighbour] = candidate
                previous[neighbour] = node
                heapq.heappush(queue, (candidate, neighbour))
    if end not in distances:
        raise ValueError("Een grenssegment vormt geen aaneengesloten lijn")
    nodes = [end]
    while nodes[-1] != start:
        nodes.append(previous[nodes[-1]])
    return [vertices[node] for node in reversed(nodes)]


def make_line(coordinates: list[tuple[float, float]]) -> ogr.Geometry:
    line = ogr.Geometry(ogr.wkbLineString)
    for x, y in coordinates:
        line.AddPoint_2D(x, y)
    line.AssignSpatialReference(rd_srs())
    return line


def build_project_boundary(
    roads: dict[str, list[ogr.Geometry]], coastline: ogr.Geometry
) -> tuple[ogr.Geometry, list[dict]]:
    road_graphs = {name: build_graph(roads[name], 35.0) for name in BOUNDARY_ROADS}
    coast_graph = build_graph([coastline], 10.0)
    _, coast_start, road_start = closest_nodes(coast_graph[0], road_graphs[BOUNDARY_ROADS[0]][0])

    road_coordinates = [coast_graph[0][coast_start], road_graphs[BOUNDARY_ROADS[0]][0][road_start]]
    segment_rows: list[dict] = []
    current = road_start
    coast_end = -1
    for sequence, name in enumerate(BOUNDARY_ROADS, start=1):
        vertices, adjacency = road_graphs[name]
        if sequence < len(BOUNDARY_ROADS):
            next_name = BOUNDARY_ROADS[sequence]
            gap, end_here, start_next = closest_nodes(vertices, road_graphs[next_name][0])
        else:
            gap, coast_end, end_here = closest_nodes(coast_graph[0], vertices)
            start_next = None
        path = shortest_path(vertices, adjacency, current, end_here)
        road_coordinates.extend(path[1:])
        segment_rows.append(
            {
                "volgorde": sequence,
                "naam": name,
                "type": "officiele_wegas",
                "aansluitafstand_m": gap,
                "geometry": make_line(path),
            }
        )
        if sequence < len(BOUNDARY_ROADS):
            next_point = road_graphs[next_name][0][start_next]
            if gap > 0.01:
                connector = make_line([vertices[end_here], next_point])
                segment_rows.append(
                    {
                        "volgorde": sequence,
                        "naam": f"aansluiting {name} - {next_name}",
                        "type": "gedocumenteerde_aansluiting",
                        "aansluitafstand_m": gap,
                        "geometry": connector,
                    }
                )
            road_coordinates.append(next_point)
            current = start_next
        else:
            road_coordinates.append(coast_graph[0][coast_end])

    coast_path = shortest_path(coast_graph[0], coast_graph[1], coast_end, coast_start)
    segment_rows.append(
        {
            "volgorde": 0,
            "naam": "gemiddelde hoogwaterlijn",
            "type": "officiele_kustlijn",
            "aansluitafstand_m": 0.0,
            "geometry": make_line(coast_path),
        }
    )
    coordinates = road_coordinates + coast_path[1:]
    ring = ogr.Geometry(ogr.wkbLinearRing)
    for x, y in coordinates:
        ring.AddPoint_2D(x, y)
    ring.CloseRings()
    polygon = ogr.Geometry(ogr.wkbPolygon)
    polygon.AddGeometry(ring)
    polygon.AssignSpatialReference(rd_srs())
    if not polygon.IsValid():
        polygon = polygon.MakeValid()
    if polygon.GetGeometryName().upper() == "MULTIPOLYGON":
        polygon = max(
            (polygon.GetGeometryRef(i).Clone() for i in range(polygon.GetGeometryCount())),
            key=lambda item: item.GetArea(),
        )
        polygon.AssignSpatialReference(rd_srs())
    if polygon.GetGeometryName().upper() != "POLYGON" or not polygon.IsValid():
        raise ValueError("De opgebouwde projectgrens is geen geldige enkelvoudige polygoon")
    return polygon, segment_rows


def classify_relation(geometry: ogr.Geometry | None, area: ogr.Geometry) -> str:
    if geometry is None:
        return "geen_geometrie"
    if not geometry.IsValid():
        return "ongeldig"
    if geometry.Within(area) or geometry.Equals(area):
        return "volledig_binnen"
    if geometry.Intersects(area):
        return "raakt_grens"
    return "buiten"


def add_field(layer: ogr.Layer, name: str, field_type: int, width: int = 0) -> None:
    field = ogr.FieldDefn(name, field_type)
    if width:
        field.SetWidth(width)
    layer.CreateField(field)


def write_feature(layer: ogr.Layer, values: dict, geometry: ogr.Geometry) -> None:
    feature = ogr.Feature(layer.GetLayerDefn())
    for key, value in values.items():
        feature.SetField(key, value)
    feature.SetGeometry(geometry)
    layer.CreateFeature(feature)


def write_geopackage(
    output: Path,
    project: ogr.Geometry,
    natura: ogr.Geometry,
    natura_properties: dict,
    segments: list[dict],
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        ogr.GetDriverByName("GPKG").DeleteDataSource(str(output))
    dataset = ogr.GetDriverByName("GPKG").CreateDataSource(str(output))
    spatial_reference = rd_srs()

    basis = dataset.CreateLayer("meijendel_basisgebied", spatial_reference, ogr.wkbPolygon)
    add_field(basis, "versie", ogr.OFTString, 32)
    add_field(basis, "status", ogr.OFTString, 32)
    add_field(basis, "oppervlakte_ha", ogr.OFTReal)
    add_field(basis, "omschrijving", ogr.OFTString, 1000)
    write_feature(
        basis,
        {
            "versie": VERSION,
            "status": "vastgesteld_projectgebied",
            "oppervlakte_ha": project.GetArea() / 10000.0,
            "omschrijving": "Ruime ecologische projectgrens; geen juridische of meetkundige telplotgrens.",
        },
        project,
    )

    n2000 = dataset.CreateLayer("meijendel_natura2000", spatial_reference, ogr.wkbMultiPolygon)
    add_field(n2000, "versie", ogr.OFTString, 32)
    add_field(n2000, "n2000_nr", ogr.OFTInteger)
    add_field(n2000, "naam", ogr.OFTString, 255)
    add_field(n2000, "oppervlakte_ha", ogr.OFTReal)
    natura_multi = natura.Clone()
    if natura_multi.GetGeometryName().upper() == "POLYGON":
        wrapper = ogr.Geometry(ogr.wkbMultiPolygon)
        wrapper.AddGeometry(natura_multi)
        natura_multi = wrapper
    natura_multi.AssignSpatialReference(spatial_reference)
    write_feature(
        n2000,
        {
            "versie": VERSION,
            "n2000_nr": int(natura_properties.get("nr", 97)),
            "naam": natura_properties.get("naam_n2k", "Meijendel & Berkheide"),
            "oppervlakte_ha": natura_multi.GetArea() / 10000.0,
        },
        natura_multi,
    )

    boundaries = dataset.CreateLayer("meijendel_grenssegmenten", spatial_reference, ogr.wkbLineString)
    add_field(boundaries, "versie", ogr.OFTString, 32)
    add_field(boundaries, "volgorde", ogr.OFTInteger)
    add_field(boundaries, "naam", ogr.OFTString, 255)
    add_field(boundaries, "segmenttype", ogr.OFTString, 64)
    add_field(boundaries, "aansluitafstand_m", ogr.OFTReal)
    for row in segments:
        write_feature(
            boundaries,
            {
                "versie": VERSION,
                "volgorde": row["volgorde"],
                "naam": row["naam"],
                "segmenttype": row["type"],
                "aansluitafstand_m": row["aansluitafstand_m"],
            },
            row["geometry"],
        )
    dataset = None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args()

    roads, road_hashes = fetch_selected_roads()
    coastline, coastline_hash = fetch_coastline()
    natura, natura_properties, natura_hash = fetch_natura2000()
    project, segments = build_project_boundary(roads, coastline)
    write_geopackage(args.output, project, natura, natura_properties, segments)

    manifest = {
        "versie": VERSION,
        "aangemaakt_op": date.today().isoformat(),
        "crs_epsg": 28992,
        "projectgebied_oppervlakte_ha": round(project.GetArea() / 10000.0, 6),
        "natura2000_oppervlakte_ha": round(natura.GetArea() / 10000.0, 6),
        "projectgebied_sha256_wkb": hashlib.sha256(bytes(project.ExportToWkb())).hexdigest(),
        "natura2000_sha256_wkb": hashlib.sha256(bytes(natura.ExportToWkb())).hexdigest(),
        "bronnen": {
            "nwb_wfs": {"url": NWB_WFS, "pagina_sha256": road_hashes},
            "kustlijn": {"url": COAST_API, "sha256": coastline_hash},
            "natura2000": {"url": NATURA_API, "sha256": natura_hash, "gebiedsnummer": 97},
        },
        "grenswegen": list(BOUNDARY_ROADS),
        "aansluitingen": [
            {
                "naam": row["naam"],
                "afstand_m": round(row["aansluitafstand_m"], 3),
            }
            for row in segments
            if row["type"] == "gedocumenteerde_aansluiting"
        ],
    }
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
