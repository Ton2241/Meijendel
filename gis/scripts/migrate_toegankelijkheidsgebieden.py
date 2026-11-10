#!/usr/bin/env python3
"""Vervang voorlopige kaveltoegang door bronvaste gebiedspolygonen."""

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
SCHEMA = ROOT / "gis/database/maatregelen_schema.sql"
_QFIELD_ROOT = Path("/Users/ton/Documents/GitHub/Meijendel/outputs/qfield_afscheidingen/meijendel_afscheidingen")
DEFAULT_ROUTE_GPKG = _QFIELD_ROOT / "routes.gpkg"
DEFAULT_REFERENCE_GPKG = _QFIELD_ROOT / "referentie.gpkg"
DEFAULT_BIERLAP_BOUNDARY_GPX = Path(
    "/Volumes/T7 Data/Home_Ton/Proefomgevingen/bierlap-kijfhoek-dagkaart-2026-11-09/"
    "downloads/activity_25020262638.gpx"
)
DEFAULT_BIERLAP_ACCEPTED_GPKG = Path(
    "/Volumes/T7 Data/Home_Ton/Proefomgevingen/bierlap-kijfhoek-dagkaart-2026-11-09/"
    "outputs/expliciete-ring-proef/proef-kijfhoek-bierlap-totaal.gpkg"
)
DEFAULT_M45_ACCEPTED_GPKG = Path(
    "/Volumes/T7 Data/Home_Ton/Proefomgevingen/kavel-m4-5-afgesloten-vlak-2026-11-10/"
    "outputs/afgesloten-m4-5-goedgekeurd.gpkg"
)
DEFAULT_FEATURE_ID = "garmin_activity_24999201739_routepunten_160_5470"
BACKUP_ROOT = Path("/Volumes/T7 Data/Home_Ton/Meijendel data/Backups-archief/Meijendel")
T7_TRIAL_ROOT = Path("/Volumes/T7 Data/Home_Ton/Proefomgevingen")
STATUS_CODES = (
    "afgesloten",
    "toegankelijk",
    "toegankelijk_buiten_broedseizoen",
    "toegankelijk_met_toegangskaart",
)
MIGRATION_VERSION = "toegankelijkheidsgebieden-v10"
SOURCE_CODE = "garmin_veldregistratie_20261107"
AREA_CODE = "garmin_24999201739_omsloten_gebied"
PLOT_SOURCE_CODE = "handmatige_plotselectie_20261107"
BIERLAP_SOURCE_CODE = "garmin_grensregistratie_20261109"
M45_SOURCE_CODE = "mymaps_grensregistratie_20261110"
BIERLAP_BOUNDARY_START_POINT_ID = 0
BIERLAP_BOUNDARY_END_POINT_ID = 396
BIERLAP_CURVE_CONTROL_POINTS_RD = (
    (83095.6, 461162.4),
    (83020.1, 461316.3),
)
BIERLAP_M6_ENDPOINT_RD = (83147.280, 461439.310)
BIERLAP_CURVE_SAMPLES = 96
BIERLAP_AREA_SPEC = {
    "gebied_code": "bierlap_kijfhoek_dagkaart_1955",
    "naam": "Bierlap-Kijfhoek toegankelijk met dagkaart",
    "status_code": "toegankelijk_met_toegangskaart",
    "volledige_kavels": (
        "M6", "M61", "M63", "M64", "M65", "M71", "M72",
        "M73", "M74", "M75", "M10-12-76", "M12a", "M8", "M7",
    ),
    "gedeeltelijke_kavels": ("M62", "M4-5"),
    "vastgesteld_op": "2026-11-09",
}
M45_AREA_SPEC = {
    "gebied_code": "m4_5_afgesloten_1955",
    "naam": "Afgesloten gebied bij M4-5",
    "status_code": "afgesloten",
    "kavels": ("M4-5",),
    "vastgesteld_op": "2026-11-10",
}
PLOT_AREA_SPECS = (
    {
        "gebied_code": "buitenduin_noord_1955",
        "naam": "Afgesloten gebied M13-M17a",
        "status_code": "afgesloten",
        "kavels": ("M13", "M13s", "M14", "M15", "M16", "M16s", "M17a"),
        "naad_sluiting_m": 2.0,
    },
    {
        "gebied_code": "haagsche_golfclub_1955",
        "naam": "Haagsche Golf- en Countryclub",
        "status_code": "toegankelijk",
        "kavels": ("M66",),
    },
    {
        "gebied_code": "hertenkamp_1955",
        "naam": "Hertenkamp",
        "status_code": "toegankelijk",
        "kavels": ("M105",),
    },
    {
        "gebied_code": "buitenduin_noord_toegankelijk_1955",
        "naam": "Toegankelijk gebied M77-M75a",
        "status_code": "toegankelijk",
        "kavels": ("M77", "M78/79", "M75a"),
    },
    {
        "gebied_code": "kavel_m31_1955",
        "naam": "Kavel M31",
        "status_code": "toegankelijk",
        "kavels": ("M31",),
    },
    {
        "gebied_code": "buitenduin_zuid_broedseizoen_1955",
        "naam": "Toegankelijk buiten broedseizoen M35-M36",
        "status_code": "toegankelijk_buiten_broedseizoen",
        "kavels": ("M35", "M36"),
        "vastgesteld_op": "2026-11-09",
    },
    {
        "gebied_code": "ruygenhoek_afgesloten_1955",
        "naam": "Afgesloten gebied M32-M33",
        "status_code": "afgesloten",
        "kavels": ("M32", "M33"),
        "vastgesteld_op": "2026-11-09",
    },
    {
        "gebied_code": "kavel_m34_1955",
        "naam": "Kavel M34",
        "status_code": "toegankelijk",
        "kavels": ("M34",),
        "vastgesteld_op": "2026-11-09",
    },
)
OBSOLETE_PLOT_AREA_CODES = ("kavel_m77_1955", "kavel_m78_79_1955", "kavel_m75a_1955")
ROUTE_START_INDEX = 159
ROUTE_END_INDEX = 5470
ACCESS_SPUR_CHECK_INDEX = 79


def sql_literal(value: Any) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("\\", "\\\\").replace("'", "''") + "'"


def read_area_feature(path: Path, feature_id: str) -> dict[str, Any]:
    dataset = ogr.Open(str(path), 0)
    if dataset is None:
        raise ValueError(f"GeoPackage niet leesbaar: {path}")
    layer = dataset.GetLayerByName("gebieden")
    if layer is None:
        raise ValueError("Laag gebieden ontbreekt")
    layer.SetAttributeFilter(f"id = '{feature_id.replace(chr(39), chr(39) * 2)}'")
    features = list(layer)
    if len(features) != 1:
        raise ValueError(f"Verwacht één gebied {feature_id}, gevonden {len(features)}")
    feature = features[0]
    geometry = feature.GetGeometryRef().Clone()
    srs = layer.GetSpatialRef()
    epsg = int(srs.GetAuthorityCode(None)) if srs and srs.GetAuthorityCode(None) else None
    if epsg != 28992:
        raise ValueError(f"Gebied heeft EPSG:{epsg}, verwacht EPSG:28992")
    if not geometry.IsValid():
        raise ValueError("Gebiedsgeometrie is ongeldig")
    geometry = ogr.ForceToMultiPolygon(geometry)
    if geometry is None or geometry.GetGeometryName().upper() != "MULTIPOLYGON":
        raise ValueError("Gebiedsgeometrie is geen vlak")
    status = feature.GetField("categorie")
    if status not in STATUS_CODES:
        raise ValueError(f"Ongeldige gebiedsstatus: {status}")
    wkb = bytes(geometry.ExportToWkb(ogr.wkbNDR))
    return {
        "feature_id": feature_id,
        "status_code": status,
        "epsg": epsg,
        "geometry_type": geometry.GetGeometryName().upper(),
        "is_valid": bool(geometry.IsValid()),
        "wkt": geometry.ExportToIsoWkt(),
        "geometrie_sha256": hashlib.sha256(wkb).hexdigest(),
        "oppervlakte_m2": float(geometry.GetArea()),
        "datum_tijd": feature.GetFieldAsString("datum_tijd"),
        "bron": feature.GetFieldAsString("bron"),
        "ontvanger": feature.GetFieldAsString("ontvanger"),
        "nauwkeurigheid_m": feature.GetField("nauwkeurigheid_m"),
        "opmerking": feature.GetFieldAsString("opmerking"),
    }


def _polygon_parts(geometry: ogr.Geometry):
    name = geometry.GetGeometryName().upper()
    if name == "POLYGON":
        yield geometry
        return
    for index in range(geometry.GetGeometryCount()):
        yield from _polygon_parts(geometry.GetGeometryRef(index))


def polygonal_area(geometry: ogr.Geometry) -> float:
    """Som uitsluitend de vlakdelen, ook binnen een GeometryCollection."""
    return float(sum(part.GetArea() for part in _polygon_parts(geometry)))


def storable_intersection(intersection_area: float, plot_area: float) -> bool:
    if intersection_area <= 0 or plot_area <= 0:
        return False
    percentage = min(100.0, 100.0 * intersection_area / plot_area)
    return round(intersection_area, 3) > 0 and round(percentage, 6) > 0


def exterior_boundaries_only(geometry: ogr.Geometry) -> tuple[ogr.Geometry, int]:
    """Behoud per vlak alleen de buitenring; statusgebieden hebben geen interne grenzen."""
    polygons = []
    removed = 0
    for part in _polygon_parts(geometry):
        if part.GetGeometryCount() < 1:
            continue
        polygon = ogr.Geometry(ogr.wkbPolygon)
        polygon.AddGeometry(part.GetGeometryRef(0).Clone())
        polygons.append(polygon)
        removed += max(0, part.GetGeometryCount() - 1)
    if not polygons:
        raise ValueError("Gebiedsgeometrie bevat geen polygonen")
    result = ogr.Geometry(ogr.wkbMultiPolygon)
    for polygon in polygons:
        result.AddGeometry(polygon)
    return result.MakeValid(), removed


def close_narrow_seams(
    geometry: ogr.Geometry,
    tolerance_m: float,
    source_geometries: list[ogr.Geometry] | None = None,
) -> ogr.Geometry:
    """Sluit alleen smalle, naar de buitenrand open topologische naden."""
    if tolerance_m <= 0:
        return ogr.ForceToMultiPolygon(geometry.Clone())
    morphological_close = geometry.Buffer(tolerance_m).Buffer(-tolerance_m).MakeValid()
    if source_geometries:
        additions = morphological_close.Difference(geometry)
        closed = geometry.Clone()
        for part in _polygon_parts(additions):
            touching_sources = sum(
                part.Distance(source) < 1e-7 for source in source_geometries
            )
            if touching_sources >= 2:
                closed = closed.Union(part)
        closed = closed.MakeValid()
    else:
        closed = morphological_close
    closed, _ = exterior_boundaries_only(closed)
    closed = ogr.ForceToMultiPolygon(closed)
    if closed is None or not closed.IsValid():
        raise ValueError("Naadsluiting levert geen geldige multipolygoon op")
    return closed


def read_gpx_boundary(
    path: Path,
    start_point_id: int | None = None,
    end_point_id: int | None = None,
) -> dict[str, Any]:
    """Lees één Garmin-GPX-spoor als RD-grenslijn met bronmetadata."""
    dataset = ogr.Open(str(path), 0)
    if dataset is None:
        raise ValueError(f"GPX niet leesbaar: {path}")
    layer = dataset.GetLayerByName("track_points")
    if layer is None:
        raise ValueError("GPX-laag track_points ontbreekt")
    features = list(layer)
    if len(features) < 2:
        raise ValueError("GPX-grens bevat minder dan twee trackpunten")
    features.sort(key=lambda feature: feature.GetFieldAsInteger("track_seg_point_id"))
    if len({feature.GetFieldAsInteger("track_fid") for feature in features}) != 1:
        raise ValueError("GPX-grens bevat meer dan één track")
    if len({feature.GetFieldAsInteger("track_seg_id") for feature in features}) != 1:
        raise ValueError("GPX-grens bevat meer dan één tracksegment")
    if start_point_id is not None or end_point_id is not None:
        lower = features[0].GetFieldAsInteger("track_seg_point_id") if start_point_id is None else start_point_id
        upper = features[-1].GetFieldAsInteger("track_seg_point_id") if end_point_id is None else end_point_id
        features = [
            feature for feature in features
            if lower <= feature.GetFieldAsInteger("track_seg_point_id") <= upper
        ]
        if len(features) < 2:
            raise ValueError("Geselecteerd GPX-grenssegment bevat minder dan twee trackpunten")
        if features[0].GetFieldAsInteger("track_seg_point_id") != lower:
            raise ValueError(f"GPX-startpunt {lower} ontbreekt")
        if features[-1].GetFieldAsInteger("track_seg_point_id") != upper:
            raise ValueError(f"GPX-eindpunt {upper} ontbreekt")

    source_srs = osr.SpatialReference()
    source_srs.ImportFromEPSG(4326)
    source_srs.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    target_srs = osr.SpatialReference()
    target_srs.ImportFromEPSG(28992)
    target_srs.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    transform = osr.CoordinateTransformation(source_srs, target_srs)
    line = ogr.Geometry(ogr.wkbLineString)
    line.AssignSpatialReference(target_srs)
    for feature in features:
        point = feature.GetGeometryRef().Clone()
        point.Transform(transform)
        line.AddPoint_2D(point.GetX(), point.GetY())

    return {
        "geometry": line,
        "punt_aantal": len(features),
        "start_punt_id": features[0].GetFieldAsInteger("track_seg_point_id"),
        "eind_punt_id": features[-1].GetFieldAsInteger("track_seg_point_id"),
        "start_tijd": features[0].GetFieldAsString("time"),
        "eind_tijd": features[-1].GetFieldAsString("time"),
        "bron_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def rd_linestring(points: tuple[tuple[float, float], ...]) -> ogr.Geometry:
    """Bouw één RD-lijn uit een expliciet vastgelegde coördinatenreeks."""
    if len(points) < 2:
        raise ValueError("RD-lijn bevat minder dan twee punten")
    line = ogr.Geometry(ogr.wkbLineString)
    srs = osr.SpatialReference()
    srs.ImportFromEPSG(28992)
    srs.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    line.AssignSpatialReference(srs)
    for x, y in points:
        line.AddPoint_2D(x, y)
    return line


def compose_boundary_with_closure(
    land_boundary: ogr.Geometry,
    water_closure: ogr.Geometry,
    maximum_join_distance_m: float = 0.01,
) -> ogr.Geometry:
    """Verbind Garmin-landgrens en afzonderlijk gedigitaliseerde waterlijn."""
    if land_boundary.GetGeometryName().upper() != "LINESTRING":
        raise ValueError("Garmin-landgrens is geen lijn")
    if water_closure.GetGeometryName().upper() != "LINESTRING":
        raise ValueError("Waterlijn is geen lijn")
    land_end = land_boundary.GetPoint(land_boundary.GetPointCount() - 1)[:2]
    closure_start = water_closure.GetPoint(0)[:2]
    join_distance = ((land_end[0] - closure_start[0]) ** 2 + (land_end[1] - closure_start[1]) ** 2) ** 0.5
    if join_distance > maximum_join_distance_m:
        raise ValueError(f"Garmin-landgrens en waterlijn sluiten niet aan: {join_distance:.3f} m")
    line = ogr.Geometry(ogr.wkbLineString)
    line.AssignSpatialReference(land_boundary.GetSpatialReference())
    for index in range(land_boundary.GetPointCount()):
        x, y = land_boundary.GetPoint(index)[:2]
        line.AddPoint_2D(x, y)
    for index in range(1, water_closure.GetPointCount()):
        x, y = water_closure.GetPoint(index)[:2]
        line.AddPoint_2D(x, y)
    return line


def cubic_bezier_linestring(
    start: tuple[float, float],
    control1: tuple[float, float],
    control2: tuple[float, float],
    end: tuple[float, float],
    samples: int,
) -> ogr.Geometry:
    """Digitaliseer de bevestigde vloeiende verbinding als RD-lijn."""
    if samples < 2:
        raise ValueError("Bezierlijn bevat te weinig deelpunten")
    points = []
    for index in range(samples + 1):
        t = index / samples
        u = 1.0 - t
        points.append((
            u**3 * start[0] + 3 * u**2 * t * control1[0] + 3 * u * t**2 * control2[0] + t**3 * end[0],
            u**3 * start[1] + 3 * u**2 * t * control1[1] + 3 * u * t**2 * control2[1] + t**3 * end[1],
        ))
    return rd_linestring(tuple(points))


def build_north_of_boundary_area(
    full_plot_union: ogr.Geometry,
    split_plot: ogr.Geometry,
    boundary: ogr.Geometry,
) -> ogr.Geometry:
    """Behoud volledige kavels plus het deel van één kavel noord van de grenslijn."""
    if boundary.GetGeometryName().upper() != "LINESTRING" or boundary.GetPointCount() < 2:
        raise ValueError("Grenssegment moet één lijn met minstens twee punten zijn")
    points = [boundary.GetPoint(index)[:2] for index in range(boundary.GetPointCount())]
    if points[0][0] < points[-1][0]:
        points.reverse()

    combined = full_plot_union.Union(split_plot)
    xmin, xmax, ymin, ymax = combined.GetEnvelope()
    margin = max(xmax - xmin, ymax - ymin, 100.0)
    ring = ogr.Geometry(ogr.wkbLinearRing)
    for x, y in points:
        ring.AddPoint_2D(x, y)
    ring.AddPoint_2D(xmin - margin, ymax + margin)
    ring.AddPoint_2D(xmax + margin, ymax + margin)
    ring.AddPoint_2D(points[0][0], points[0][1])
    north_polygon = ogr.Geometry(ogr.wkbPolygon)
    north_polygon.AddGeometry(ring)
    north_polygon = north_polygon.MakeValid(["METHOD=STRUCTURE"])

    linework = combined.Boundary().Union(boundary)
    faces = linework.Polygonize()
    northern_split = split_plot.Intersection(north_polygon).MakeValid()
    result = full_plot_union.Union(northern_split).MakeValid()
    for face in _polygon_parts(faces):
        outside = face.Difference(combined)
        addition = outside.Intersection(north_polygon).MakeValid()
        if polygonal_area(addition) > 0.001:
            result = result.Union(addition).MakeValid()
    result, _ = exterior_boundaries_only(result)
    result = ogr.ForceToMultiPolygon(result)
    if result is None or not result.IsValid():
        raise ValueError("Grenssegment levert geen geldig noordelijk gebied op")
    return result


def single_polygon_without_slivers(
    geometry: ogr.Geometry,
    maximum_sliver_area_m2: float,
) -> ogr.Geometry:
    """Behoud één hoofdvlak en weiger onverwachte tweede gebiedsdelen."""
    parts = sorted(
        (part.Clone() for part in _polygon_parts(geometry)),
        key=lambda part: part.GetArea(),
        reverse=True,
    )
    if not parts:
        raise ValueError("Gebiedsgeometrie bevat geen vlak")
    unexpected = [part.GetArea() for part in parts[1:] if part.GetArea() > maximum_sliver_area_m2]
    if unexpected:
        raise ValueError(f"Gebiedsgeometrie bevat meerdere relevante vlakken: {unexpected}")
    result = ogr.Geometry(ogr.wkbMultiPolygon)
    result.AddGeometry(parts[0])
    return result


def _area_record(geometry: ogr.Geometry, **metadata: Any) -> dict[str, Any]:
    if not geometry.IsValid():
        raise ValueError("Gebiedsgeometrie is ongeldig")
    geometry, removed_rings = exterior_boundaries_only(geometry.Clone())
    geometry = ogr.ForceToMultiPolygon(geometry)
    if geometry is not None and not geometry.IsValid():
        geometry = geometry.Buffer(0).MakeValid(["METHOD=STRUCTURE"])
        geometry, additionally_removed = exterior_boundaries_only(geometry)
        removed_rings += additionally_removed
        geometry = ogr.ForceToMultiPolygon(geometry)
    if geometry is None or geometry.GetGeometryName().upper() != "MULTIPOLYGON":
        raise ValueError("Gebiedsgeometrie is geen multipolygoon")
    # MySQL beoordeelt een op een knooppunt zelfaanrakende ring strenger dan
    # OGR. Een nulbuffer normaliseert uitsluitend die ringtopologie.
    geometry = ogr.ForceToMultiPolygon(geometry.Buffer(0))
    geometry = ogr.CreateGeometryFromWkt(geometry.ExportToIsoWkt()).Buffer(0)
    geometry = ogr.ForceToMultiPolygon(geometry)
    if not geometry.IsValid():
        raise ValueError("Opgeschoonde gebiedsgeometrie is ongeldig")
    wkb = bytes(geometry.ExportToWkb(ogr.wkbNDR))
    return {
        "status_code": "afgesloten",
        "epsg": 28992,
        "geometry_type": "MULTIPOLYGON",
        "is_valid": True,
        "wkt": geometry.ExportToIsoWkt(),
        "geometrie_sha256": hashlib.sha256(wkb).hexdigest(),
        "oppervlakte_m2": float(geometry.GetArea()),
        "interne_ringen": sum(max(0, part.GetGeometryCount() - 1) for part in _polygon_parts(geometry)),
        "verwijderde_interne_ringen": removed_rings,
        **metadata,
    }


def derive_route_area(path: Path) -> dict[str, Any]:
    """Leid het omsloten vlak af zonder het heen-en-weer gelopen toegangsspoor."""
    dataset = ogr.Open(str(path), 0)
    if dataset is None:
        raise ValueError(f"GeoPackage niet leesbaar: {path}")
    layer = dataset.GetLayerByName("paden_en_wegen")
    if layer is None or layer.GetFeatureCount() != 1:
        raise ValueError("Verwacht precies één Garmin-route in paden_en_wegen")
    feature = next(iter(layer))
    route = feature.GetGeometryRef()
    if route is None or route.GetGeometryName().upper() != "LINESTRING":
        raise ValueError("Garmin-route is geen lijn")
    if route.GetPointCount() < ROUTE_END_INDEX:
        raise ValueError("Garmin-route bevat te weinig punten voor de bevestigde lus")

    ring = ogr.Geometry(ogr.wkbLinearRing)
    for index in range(ROUTE_START_INDEX, ROUTE_END_INDEX):
        point = route.GetPoint(index)
        ring.AddPoint_2D(point[0], point[1])
    first = route.GetPoint(ROUTE_START_INDEX)
    last = route.GetPoint(ROUTE_END_INDEX - 1)
    ring.AddPoint_2D(first[0], first[1])
    polygon = ogr.Geometry(ogr.wkbPolygon)
    polygon.AddGeometry(ring)
    valid = polygon.MakeValid(["METHOD=STRUCTURE"])
    parts = list(_polygon_parts(valid))
    if not parts:
        raise ValueError("De bevestigde routelus levert geen vlak op")
    largest = max(parts, key=lambda part: part.GetArea()).Clone()
    access_point = ogr.Geometry(ogr.wkbPoint)
    access = route.GetPoint(ACCESS_SPUR_CHECK_INDEX)
    access_point.AddPoint_2D(access[0], access[1])
    closure = ((last[0] - first[0]) ** 2 + (last[1] - first[1]) ** 2) ** 0.5
    return _area_record(
        largest,
        feature_id=DEFAULT_FEATURE_ID,
        sluitafstand_m=closure,
        toegangsspoor_afstand_m=float(access_point.Distance(largest)),
        datum_tijd=feature.GetFieldAsString("datum_tijd"),
        bron=feature.GetFieldAsString("bron"),
        ontvanger=feature.GetFieldAsString("ontvanger"),
        nauwkeurigheid_m=feature.GetField("nauwkeurigheid_m"),
        opmerking=(
            "Gesloten lus uit Garmin-routepunten 160-5470; het heen-en-weer "
            "gelopen toegangsspoor is geen gebiedsgrens en is uitgesloten."
        ),
    )


def read_plot_geometries(path: Path, wanted: set[str]) -> dict[str, ogr.Geometry]:
    """Lees de gevraagde onderzoekskavels uit de vaste referentielaag."""
    dataset = ogr.Open(str(path), 0)
    if dataset is None:
        raise ValueError(f"GeoPackage niet leesbaar: {path}")
    layer = dataset.GetLayerByName("onderzoekskavels")
    if layer is None:
        raise ValueError("Laag onderzoekskavels ontbreekt")
    found: dict[str, ogr.Geometry] = {}
    for feature in layer:
        name = feature.GetFieldAsString("naam")
        suffix = name.replace("Meijendel  k ", "", 1).replace("Meijendel k ", "", 1)
        kavel = "M" + suffix.split(maxsplit=1)[0]
        if kavel in wanted:
            found[kavel] = feature.GetGeometryRef().Clone()
    if set(found) != wanted:
        raise ValueError(f"Kavelgeometrie ontbreekt: {sorted(wanted - set(found))}")
    return found


def read_accepted_area_geometry(path: Path, area_name: str) -> ogr.Geometry:
    """Lees exact één door Ton visueel goedgekeurd statusvlak."""
    dataset = ogr.Open(str(path), 0)
    if dataset is None:
        raise ValueError(f"Goedgekeurd GeoPackage niet leesbaar: {path}")
    layer = dataset.GetLayerByName("statusgebied")
    if layer is None or layer.GetFeatureCount() != 1:
        raise ValueError("Goedgekeurd GeoPackage bevat niet precies één statusgebied")
    feature = next(iter(layer))
    geometry = feature.GetGeometryRef().Clone()
    if geometry.GetGeometryName().upper() != "MULTIPOLYGON" or not geometry.IsValid():
        raise ValueError(f"Goedgekeurd {area_name}-vlak is geen geldige multipolygoon")
    if sum(max(0, part.GetGeometryCount() - 1) for part in _polygon_parts(geometry)):
        raise ValueError(f"Goedgekeurd {area_name}-vlak bevat interne ringen")
    return geometry


def read_accepted_bierlap_geometry(path: Path) -> ogr.Geometry:
    """Lees exact het door Ton visueel goedgekeurde Bierlap-Kijfhoek-vlak."""
    return read_accepted_area_geometry(path, "Bierlap-Kijfhoek")


def read_all_plot_geometries(path: Path) -> dict[str, ogr.Geometry]:
    """Lees alle onderzoekskavels met dezelfde normalisatie als de selectiehelper."""
    dataset = ogr.Open(str(path), 0)
    if dataset is None:
        raise ValueError(f"GeoPackage niet leesbaar: {path}")
    layer = dataset.GetLayerByName("onderzoekskavels")
    if layer is None:
        raise ValueError("Laag onderzoekskavels ontbreekt")
    found: dict[str, ogr.Geometry] = {}
    for feature in layer:
        name = feature.GetFieldAsString("naam")
        suffix = name.replace("Meijendel  k ", "", 1).replace("Meijendel k ", "", 1)
        found["M" + suffix.split(maxsplit=1)[0]] = feature.GetGeometryRef().Clone()
    return found


def derive_bierlap_kijfhoek_area(
    reference_path: Path,
    gpx_path: Path,
    accepted_path: Path = DEFAULT_BIERLAP_ACCEPTED_GPKG,
) -> dict[str, Any]:
    """Vorm Bierlap-Kijfhoek uit de bevestigde expliciete buitenring."""
    full_kavels = BIERLAP_AREA_SPEC["volledige_kavels"]
    partial_kavels = BIERLAP_AREA_SPEC["gedeeltelijke_kavels"]
    selected_kavels = full_kavels + partial_kavels
    found = read_plot_geometries(reference_path, set(selected_kavels))

    boundary_source = read_gpx_boundary(
        gpx_path,
        start_point_id=BIERLAP_BOUNDARY_START_POINT_ID,
        end_point_id=BIERLAP_BOUNDARY_END_POINT_ID,
    )
    land_end = boundary_source["geometry"].GetPoint(
        boundary_source["geometry"].GetPointCount() - 1
    )[:2]
    water_closure = cubic_bezier_linestring(
        land_end,
        BIERLAP_CURVE_CONTROL_POINTS_RD[0],
        BIERLAP_CURVE_CONTROL_POINTS_RD[1],
        BIERLAP_M6_ENDPOINT_RD,
        BIERLAP_CURVE_SAMPLES,
    )
    boundary = compose_boundary_with_closure(boundary_source["geometry"], water_closure)
    closure_endpoint = ogr.Geometry(ogr.wkbPoint)
    closure_endpoint.AddPoint_2D(*BIERLAP_M6_ENDPOINT_RD)
    closure_to_m6_m = closure_endpoint.Distance(found["M6"].Boundary())
    if closure_to_m6_m > 0.01:
        raise ValueError(f"Vloeiende lijn eindigt niet op de M6-grens: {closure_to_m6_m:.3f} m")

    geometry = read_accepted_bierlap_geometry(accepted_path)
    coverages = {
        kavel: 100.0 * polygonal_area(geometry.Intersection(found[kavel])) / found[kavel].GetArea()
        for kavel in selected_kavels
    }
    if min(coverages[kavel] for kavel in full_kavels) <= 99.99:
        raise ValueError(f"Goedgekeurd vlak dekt niet alle volledige kavels: {coverages!r}")
    if not all(0 < coverages[kavel] < 100 for kavel in partial_kavels):
        raise ValueError(f"Goedgekeurd vlak snijdt de gedeeltelijke kavels niet: {coverages!r}")
    partial_percentages = {kavel: coverages[kavel] for kavel in partial_kavels}
    record = _area_record(
        geometry,
        gebied_code=BIERLAP_AREA_SPEC["gebied_code"],
        naam=BIERLAP_AREA_SPEC["naam"],
        status_code=BIERLAP_AREA_SPEC["status_code"],
        feature_id=(
            "garmin:25020262638:punten:"
            f"{boundary_source['start_punt_id']}-{boundary_source['eind_punt_id']}"
            "|vloeiende-lijn:pdok2025:m6-oeverknik"
        ),
        kavels=selected_kavels,
        volledige_kavels=full_kavels,
        gedeeltelijke_kavels=partial_kavels,
        gedeeltelijke_kavel_aandelen_pct=partial_percentages,
        grens_punt_aantal=boundary_source["punt_aantal"],
        grens_start_tijd=boundary_source["start_tijd"],
        grens_eind_tijd=boundary_source["eind_tijd"],
        grens_lengte_m=float(boundary_source["geometry"].Length()),
        waterlijn_lengte_m=float(water_closure.Length()),
        waterlijn_punt_aantal=water_closure.GetPointCount(),
        waterlijn_m6_aansluiting_m=closure_to_m6_m,
        bronbestand_sha256=boundary_source["bron_sha256"],
        bron_code=BIERLAP_SOURCE_CODE,
        vastgesteld_op=BIERLAP_AREA_SPEC["vastgesteld_op"],
        inwinningsmethode=(
            "Garmin-GPS-landgrens; vloeiende lijn gedigitaliseerd op PDOK-luchtfoto 2025 "
            "en aangesloten op onderzoekskavel M6"
        ),
        nauwkeurigheid_m=None,
        opmerking=(
            "Volledige kavels " + ", ".join(full_kavels) + "; gedeeltelijke kavels "
            + ", ".join(partial_kavels) + ". De grens volgt Garmin-punten 0-396 en "
            "de door Ton bevestigde vloeiende lijn door het water tot de oeverknik van M6. "
            "Door Ton bevestigd als gebied dat alleen met een dagkaart toegankelijk is."
        ),
    )
    exact_wkb = bytes(geometry.ExportToWkb(ogr.wkbNDR))
    record.update(
        wkt=geometry.ExportToIsoWkt(),
        geometrie_sha256=hashlib.sha256(exact_wkb).hexdigest(),
        oppervlakte_m2=float(geometry.GetArea()),
    )
    return record


def derive_m45_closed_area(
    reference_path: Path,
    accepted_path: Path = DEFAULT_M45_ACCEPTED_GPKG,
) -> dict[str, Any]:
    """Lees het bevestigde afgesloten vlak dat een deel van M4-5 beslaat."""
    geometry = read_accepted_area_geometry(accepted_path, "M4-5")
    plot = read_plot_geometries(reference_path, {"M4-5"})["M4-5"]
    outside_area = polygonal_area(geometry.Difference(plot))
    if outside_area > 0.01:
        raise ValueError(f"Goedgekeurd M4-5-vlak ligt {outside_area:.3f} m2 buiten M4-5")
    coverage = 100.0 * polygonal_area(geometry.Intersection(plot)) / plot.GetArea()
    if not 0 < coverage < 100:
        raise ValueError(f"Goedgekeurd M4-5-vlak dekt M4-5 niet gedeeltelijk: {coverage:.6f}%")
    source_wkb = bytes(geometry.ExportToWkb(ogr.wkbNDR))
    record = _area_record(
        geometry,
        gebied_code=M45_AREA_SPEC["gebied_code"],
        naam=M45_AREA_SPEC["naam"],
        status_code=M45_AREA_SPEC["status_code"],
        feature_id="google-mymaps:1BU0etZpLjh0YLg3E_nJ2tZW7Z71HBF4:extra-gebied:lijn-2",
        kavels=M45_AREA_SPEC["kavels"],
        volledige_kavels=(),
        gedeeltelijke_kavels=M45_AREA_SPEC["kavels"],
        gedeeltelijke_kavel_aandelen_pct={"M4-5": coverage},
        bron_geometrie_sha256=hashlib.sha256(source_wkb).hexdigest(),
        bron_oppervlakte_m2=float(geometry.GetArea()),
        bron_code=M45_SOURCE_CODE,
        vastgesteld_op=M45_AREA_SPEC["vastgesteld_op"],
        inwinningsmethode=(
            "Google My Maps-lijn gesloten langs de actuele grens van Bierlap-Kijfhoek, "
            "beperkt tot onderzoekskavel M4-5"
        ),
        nauwkeurigheid_m=None,
        opmerking=(
            "Door Ton visueel bevestigd als formeel afgesloten vlak. De open My Maps-lijn "
            "is gesloten met de aangrenzende grens van Bierlap-Kijfhoek en beperkt tot M4-5. "
            "De databasegeometrie is topologisch genormaliseerd voor MySQL; de oppervlakte "
            "is daardoor niet materieel gewijzigd."
        ),
    )
    return record


def read_plot_areas(path: Path) -> list[dict[str, Any]]:
    """Vorm de door Ton bevestigde gebieden uit volledige kavelgeometrieën."""
    wanted = {kavel for spec in PLOT_AREA_SPECS for kavel in spec["kavels"]}
    found = read_plot_geometries(path, wanted)
    areas = []
    for spec in PLOT_AREA_SPECS:
        kavels = spec["kavels"]
        union = found[kavels[0]].Clone()
        for kavel in kavels[1:]:
            union = union.Union(found[kavel])
        union = union.MakeValid()
        tolerance_m = float(spec.get("naad_sluiting_m", 0.0))
        seam_area_m2 = 0.0
        removed_rings = None
        if tolerance_m:
            exterior, removed_rings = exterior_boundaries_only(union)
            corrected = close_narrow_seams(
                exterior,
                tolerance_m,
                [found[kavel] for kavel in kavels],
            )
            seam_area_m2 = float(corrected.GetArea() - exterior.GetArea())
            union = corrected
        areas.append(_area_record(
            union,
            gebied_code=spec["gebied_code"],
            naam=spec["naam"],
            status_code=spec["status_code"],
            feature_id="plots:" + ",".join(kavels),
            kavels=kavels,
            naad_sluiting_m=tolerance_m,
            naad_oppervlakte_m2=seam_area_m2,
            **(
                {"verwijderde_interne_ringen": removed_rings}
                if removed_rings is not None
                else {}
            ),
            nauwkeurigheid_m=None,
            opmerking=(
                f"Volledige {'kavels' if len(kavels) > 1 else 'kavel'} {', '.join(kavels)}; "
                f"door Ton bevestigd als {spec['status_code']} gebied."
                + (
                    f" Een topologische naad van minder dan {2 * tolerance_m:g} meter "
                    "tussen de kavelpolygonen is gesloten; dit is geen statusgrens."
                    if tolerance_m
                    else ""
                )
            ),
        ))
    return areas


def area_schema_sql() -> str:
    sql = SCHEMA.read_text(encoding="utf-8")
    start = sql.index("CREATE TABLE IF NOT EXISTS toegankelijkheidsstatus")
    end = sql.index("-- Uitsluitend herkomstmetadata", start)
    return sql[start:end].strip()


def build_migration_statements(feature: dict[str, Any], plot_areas: list[dict[str, Any]]) -> list[str]:
    accuracy = feature["nauwkeurigheid_m"]
    statements = [
        "INSERT INTO maatregel_brontype (brontype_code,landelijke_broncategorie,omschrijving) "
        "VALUES ('veldregistratie','IBC99','Veldregistratie of daarvan afgeleide geometrie') "
        "ON DUPLICATE KEY UPDATE omschrijving=VALUES(omschrijving)",
        area_schema_sql(),
        "INSERT INTO maatregel_bron "
        "(bron_code,brontype_code,titel,bron_datum,raadpleegdatum,bronstatus,opmerking) VALUES ("
        f"'{SOURCE_CODE}','veldregistratie','Garmin-veldregistratie omsloten gebied',"
        "'2026-11-07','2026-11-07','door gebruiker bevestigd',"
        "'Garmin Connect-activiteit 24999201739; gesloten routelus zonder toegangsspoor') "
        "ON DUPLICATE KEY UPDATE titel=VALUES(titel),bronstatus=VALUES(bronstatus),opmerking=VALUES(opmerking)",
        "INSERT INTO maatregel_bron "
        "(bron_code,brontype_code,titel,bron_datum,raadpleegdatum,bronstatus,opmerking) VALUES ("
        f"'{M45_SOURCE_CODE}','handmatige_registratie','Google My Maps-grens afgesloten vlak M4-5',"
        "'2026-11-10','2026-11-10','door gebruiker bevestigd',"
        "'Google My Maps-kaart 1BU0etZpLjh0YLg3E_nJ2tZW7Z71HBF4, laag extra gebied, Lijn 2; "
        "open lijn gesloten langs de bevestigde grens van Bierlap-Kijfhoek en beperkt tot M4-5; "
        "bron-WKB-SHA-256 37d0cbaf52ac03dfb3309c53b9c51fa77c6d4a92d51defeeda0a1d6935d30af4') "
        "ON DUPLICATE KEY UPDATE titel=VALUES(titel),bronstatus=VALUES(bronstatus),opmerking=VALUES(opmerking)",
        "INSERT INTO toegankelijkheidsgebied (gebied_code,naam,opmerking) VALUES ("
        f"'{AREA_CODE}','Omsloten gebied Garmin-route 7 november 2026',"
        "'Door Ton bevestigd als daadwerkelijk omsloten gebied') "
        "ON DUPLICATE KEY UPDATE naam=VALUES(naam),opmerking=VALUES(opmerking)",
        "INSERT INTO toegankelijkheidsgebied_versie "
        "(gebied_id,versienummer,status_code,geldig_vanaf,geldig_tot,vastgesteld_op,bron_id,"
        "bron_object_id,inwinningsmethode,nauwkeurigheid_m,geometrie,geometrie_wkt,"
        "geometrie_sha256,oppervlakte_m2,geometrie_opmerking) SELECT "
        f"g.gebied_id,1,{sql_literal(feature['status_code'])},'1955-01-01',NULL,'2026-11-07',"
        f"b.bron_id,{sql_literal(feature['feature_id'])},'Garmin-route; gesloten routelus',"
        f"{sql_literal(accuracy)},ST_GeomFromText({sql_literal(feature['wkt'])},28992),"
        f"{sql_literal(feature['wkt'])},{sql_literal(feature['geometrie_sha256'])},"
        f"{feature['oppervlakte_m2']:.3f},{sql_literal(feature['opmerking'])} "
        "FROM toegankelijkheidsgebied g JOIN maatregel_bron b "
        f"ON b.bron_code='{SOURCE_CODE}' WHERE g.gebied_code='{AREA_CODE}' "
        "ON DUPLICATE KEY UPDATE status_code=VALUES(status_code),geldig_vanaf=VALUES(geldig_vanaf),"
        "geldig_tot=VALUES(geldig_tot),vastgesteld_op=VALUES(vastgesteld_op),bron_id=VALUES(bron_id),"
        "bron_object_id=VALUES(bron_object_id),inwinningsmethode=VALUES(inwinningsmethode),"
        "geometrie=VALUES(geometrie),geometrie_wkt=VALUES(geometrie_wkt),"
        "geometrie_sha256=VALUES(geometrie_sha256),oppervlakte_m2=VALUES(oppervlakte_m2),"
        "geometrie_opmerking=VALUES(geometrie_opmerking)",
        "INSERT INTO maatregel_bron "
        "(bron_code,brontype_code,titel,bron_datum,raadpleegdatum,bronstatus,opmerking) VALUES ("
        f"'{PLOT_SOURCE_CODE}','handmatige_registratie','Handmatig bevestigde toegankelijkheidsgebieden',"
        "'2026-11-07','2026-11-09','door gebruiker bevestigd',"
        "'Bevestigingen 7 en 9 november 2026; volledige kavels volgens de gebiedsspecificaties') "
        "ON DUPLICATE KEY UPDATE titel=VALUES(titel),bronstatus=VALUES(bronstatus),opmerking=VALUES(opmerking)",
        "INSERT INTO maatregel_bron "
        "(bron_code,brontype_code,titel,bron_datum,raadpleegdatum,bronstatus,opmerking) VALUES ("
        f"'{BIERLAP_SOURCE_CODE}','veldregistratie','Garmin-grens Bierlap-Kijfhoek',"
        "'2026-11-09','2026-11-09','door gebruiker bevestigd',"
        "'Garmin Connect-activiteit 25020262638, punten 0-396; vloeiende lijn op PDOK-luchtfoto "
        "2025 door het water tot de oeverknik van M6') "
        "ON DUPLICATE KEY UPDATE titel=VALUES(titel),bronstatus=VALUES(bronstatus),opmerking=VALUES(opmerking)",
    ]
    obsolete_codes = ",".join(sql_literal(code) for code in OBSOLETE_PLOT_AREA_CODES)
    statements.extend((
        "DELETE FROM v USING toegankelijkheidsgebied_versie v "
        "JOIN toegankelijkheidsgebied g USING(gebied_id) "
        f"WHERE g.gebied_code IN ({obsolete_codes})",
        f"DELETE FROM toegankelijkheidsgebied WHERE gebied_code IN ({obsolete_codes})",
    ))
    for plot_area in plot_areas:
        source_code = plot_area.get("bron_code", PLOT_SOURCE_CODE)
        method = plot_area.get("inwinningsmethode", "vereniging van volledige onderzoekskavels")
        statements.append(
            "INSERT INTO toegankelijkheidsgebied (gebied_code,naam,opmerking) VALUES ("
            f"{sql_literal(plot_area['gebied_code'])},{sql_literal(plot_area['naam'])},"
            f"{sql_literal(plot_area['opmerking'])}) "
            "ON DUPLICATE KEY UPDATE naam=VALUES(naam),opmerking=VALUES(opmerking)"
        )
        if plot_area["gebied_code"] in (BIERLAP_AREA_SPEC["gebied_code"], M45_AREA_SPEC["gebied_code"]):
            statements.append(
                "DELETE FROM v USING toegankelijkheidsgebied_versie v "
                "JOIN toegankelijkheidsgebied g USING(gebied_id) "
                f"WHERE g.gebied_code={sql_literal(plot_area['gebied_code'])}"
            )
        statements.append(
            "INSERT INTO toegankelijkheidsgebied_versie "
            "(gebied_id,versienummer,status_code,geldig_vanaf,geldig_tot,vastgesteld_op,bron_id,"
            "bron_object_id,inwinningsmethode,nauwkeurigheid_m,geometrie,geometrie_wkt,"
            "geometrie_sha256,oppervlakte_m2,geometrie_opmerking) SELECT "
            f"g.gebied_id,1,{sql_literal(plot_area['status_code'])},'1955-01-01',NULL,"
            f"{sql_literal(plot_area.get('vastgesteld_op', '2026-11-07'))},b.bron_id,"
            f"{sql_literal(plot_area['feature_id'])},{sql_literal(method)},{sql_literal(plot_area.get('nauwkeurigheid_m'))},"
            f"ST_GeomFromText({sql_literal(plot_area['wkt'])},28992),{sql_literal(plot_area['wkt'])},"
            f"{sql_literal(plot_area['geometrie_sha256'])},{plot_area['oppervlakte_m2']:.3f},"
            f"{sql_literal(plot_area['opmerking'])} FROM toegankelijkheidsgebied g JOIN maatregel_bron b "
            f"ON b.bron_code={sql_literal(source_code)} WHERE g.gebied_code={sql_literal(plot_area['gebied_code'])} "
            "ON DUPLICATE KEY UPDATE status_code=VALUES(status_code),geldig_vanaf=VALUES(geldig_vanaf),"
            "geldig_tot=VALUES(geldig_tot),vastgesteld_op=VALUES(vastgesteld_op),bron_id=VALUES(bron_id),"
            "bron_object_id=VALUES(bron_object_id),inwinningsmethode=VALUES(inwinningsmethode),"
            "geometrie=VALUES(geometrie),geometrie_wkt=VALUES(geometrie_wkt),"
            "geometrie_sha256=VALUES(geometrie_sha256),oppervlakte_m2=VALUES(oppervlakte_m2),"
            "geometrie_opmerking=VALUES(geometrie_opmerking)"
        )
    statements.extend((
        "DELETE FROM maatregel_registratie_herkomst WHERE toegang_registratie_id IS NOT NULL",
        "DROP TABLE maatregel_toegankelijkheid_registratie",
    ))
    return statements


class Client:
    def __init__(self, database: str) -> None:
        self.database = database
        self.mysql = shutil.which("mysql") or "/usr/local/mysql-9.7.4-macos15-arm64/bin/mysql"
        self.mysqldump = shutil.which("mysqldump") or "/usr/local/mysql-9.7.4-macos15-arm64/bin/mysqldump"

    def command(self, executable: str | None = None) -> list[str]:
        return [executable or self.mysql, "--login-path=meijendel_root", "--batch", "--raw", "--skip-column-names", self.database]

    def dump_command(self) -> list[str]:
        return [self.mysqldump, "--login-path=meijendel_root"]

    def sql(self, statement: str) -> str:
        result = subprocess.run(self.command(), input=statement, text=True, capture_output=True, check=False)
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip())
        return result.stdout.strip()

    def scalar(self, statement: str) -> str:
        result = subprocess.run(
            self.command() + ["-e", statement],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip())
        return result.stdout.strip()


def ensure_backup_dir(path: Path) -> Path:
    resolved = path.expanduser().resolve()
    if not os.path.ismount("/Volumes/T7 Data"):
        raise RuntimeError("T7 is niet gemount")
    task_root_raw = os.getenv("MEIJENDEL_T7_WORK_ROOT", "").strip()
    approved_root = Path(task_root_raw).expanduser().resolve() if task_root_raw else BACKUP_ROOT.resolve()
    if task_root_raw and approved_root != T7_TRIAL_ROOT.resolve() and T7_TRIAL_ROOT.resolve() not in approved_root.parents:
        raise RuntimeError(f"Taakwerkmap moet onder {T7_TRIAL_ROOT} staan")
    if resolved != approved_root and approved_root not in resolved.parents:
        raise RuntimeError(f"Back-up moet onder {approved_root} staan")
    resolved.mkdir(parents=True, exist_ok=True)
    return resolved


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def backup_tables(old_model_exists: bool) -> tuple[str, ...]:
    if old_model_exists:
        return ("maatregel_toegankelijkheid_registratie", "maatregel_registratie_herkomst")
    return (
        "maatregel_bron",
        "toegankelijkheidsstatus",
        "toegankelijkheidsgebied",
        "toegankelijkheidsgebied_versie",
        "toegankelijkheidsgebied_plot_afleiding",
    )


def backup(client: Client, backup_dir: Path, feature: dict[str, Any], plot_areas: list[dict[str, Any]]) -> Path:
    backup_dir = ensure_backup_dir(backup_dir)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    sql_path = backup_dir / f"meijendel-toegankelijkheid-voor-migratie-{stamp}.sql"
    old_model_exists = int(client.scalar(
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() "
        "AND table_name='maatregel_toegankelijkheid_registratie' AND table_type='BASE TABLE'"
    )) == 1
    tables = backup_tables(old_model_exists)
    command = client.dump_command() + [
        "--no-tablespaces",
        "--single-transaction",
        "--quick",
        "--complete-insert",
        "--set-gtid-purged=OFF",
        client.database,
        *tables,
    ]
    with sql_path.open("wb") as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.PIPE, check=False)
    if result.returncode or sql_path.stat().st_size == 0:
        sql_path.unlink(missing_ok=True)
        raise RuntimeError(result.stderr.decode("utf-8", "replace").strip() or "Back-up is leeg")
    digest = sha256(sql_path)
    metadata = {
        "database": client.database,
        "gemaakt_op": dt.datetime.now().astimezone().isoformat(),
        "sql_bestand": sql_path.name,
        "sql_sha256": digest,
        "sql_bytes": sql_path.stat().st_size,
        "tabellen": tables,
        "beheerregistraties": int(client.scalar("SELECT COUNT(*) FROM maatregel_plot_jaar_registratie")),
        "qfield_feature_id": feature["feature_id"],
        "qfield_geometrie_sha256": feature["geometrie_sha256"],
        "plotgebieden": [
            {
                "gebied_code": area["gebied_code"],
                "feature_id": area["feature_id"],
                "status_code": area["status_code"],
                "geometrie_sha256": area["geometrie_sha256"],
            }
            for area in plot_areas
        ],
    }
    metadata_path = sql_path.with_suffix(".json")
    metadata_path.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    sql_path.with_suffix(".sha256").write_text(f"{digest}  {sql_path.name}\n", encoding="ascii")
    if sha256(sql_path) != digest:
        raise RuntimeError("Back-uphash is niet reproduceerbaar")
    return metadata_path


def validate_retirement_counts(old_rows: int, origins: int) -> None:
    if old_rows != 55 or origins not in (0, 55):
        raise RuntimeError(f"Verwacht 55 voorlopige regels en 55 of reeds verwijderde herkomsten, gevonden {old_rows}/{origins}")


def retire_old_model(client: Client) -> None:
    if int(client.scalar("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='maatregel_toegankelijkheid_registratie' AND table_type='BASE TABLE'")) == 0:
        return
    old_rows = int(client.scalar("SELECT COUNT(*) FROM maatregel_toegankelijkheid_registratie"))
    origins = int(client.scalar("SELECT COUNT(*) FROM maatregel_registratie_herkomst WHERE toegang_registratie_id IS NOT NULL"))
    validate_retirement_counts(old_rows, origins)
    if origins:
        client.sql("DELETE FROM maatregel_registratie_herkomst WHERE toegang_registratie_id IS NOT NULL")
    fk_rows = client.sql(
        "SELECT CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='maatregel_registratie_herkomst' "
        "AND COLUMN_NAME='toegang_registratie_id' AND REFERENCED_TABLE_NAME IS NOT NULL"
    ).splitlines()
    for name in fk_rows:
        client.sql(f"ALTER TABLE maatregel_registratie_herkomst DROP FOREIGN KEY `{name}`")
    checks = client.sql(
        "SELECT tc.CONSTRAINT_NAME FROM information_schema.TABLE_CONSTRAINTS tc "
        "JOIN information_schema.CHECK_CONSTRAINTS cc USING(CONSTRAINT_SCHEMA,CONSTRAINT_NAME) "
        "WHERE tc.CONSTRAINT_SCHEMA=DATABASE() AND tc.TABLE_NAME='maatregel_registratie_herkomst' "
        "AND cc.CHECK_CLAUSE LIKE '%toegang_registratie_id%'"
    ).splitlines()
    for name in checks:
        client.sql(f"ALTER TABLE maatregel_registratie_herkomst DROP CHECK `{name}`")
    client.sql("ALTER TABLE maatregel_registratie_herkomst DROP COLUMN toegang_registratie_id")
    client.sql(
        "ALTER TABLE maatregel_registratie_herkomst ADD CONSTRAINT chk_mrh_precies_een_doel "
        "CHECK ((beheer_registratie_id IS NOT NULL)+(uitvoering_id IS NOT NULL)=1)"
    )
    client.sql("DROP TABLE maatregel_toegankelijkheid_registratie")


def rebuild_plot_derivations(client: Client) -> int:
    """Bouw ruimtelijke plotdoorsnijdingen op zonder MySQL-ST_Area op collections."""
    versions = []
    for line in client.sql(
        "SELECT gebied_versie_id,status_code,HEX(ST_AsBinary(geometrie)),geometrie_sha256 "
        "FROM toegankelijkheidsgebied_versie WHERE geldig_tot IS NULL"
    ).splitlines():
        version_id, status, geometry_hex, geometry_hash = line.split("\t")
        versions.append((int(version_id), status, ogr.CreateGeometryFromWkb(bytes.fromhex(geometry_hex)), geometry_hash))
    plots = []
    for line in client.sql(
        "SELECT plot_id,HEX(ST_AsBinary(geom)),geom_sha256 FROM plots "
        "WHERE geom IS NOT NULL AND ST_IsValid(geom)"
    ).splitlines():
        plot_id, geometry_hex, geometry_hash = line.split("\t")
        geometry = ogr.CreateGeometryFromWkb(bytes.fromhex(geometry_hex))
        plots.append((int(plot_id), geometry, geometry_hash))

    values = []
    for version_id, status, area_geometry, area_hash in versions:
        for plot_id, plot_geometry, plot_hash in plots:
            if not area_geometry.Intersects(plot_geometry):
                continue
            intersection_area = polygonal_area(area_geometry.Intersection(plot_geometry))
            plot_area = float(plot_geometry.GetArea())
            if not storable_intersection(intersection_area, plot_area):
                continue
            percentage = min(100.0, 100.0 * intersection_area / plot_area)
            values.append(
                "(" + ",".join((
                    str(version_id), str(plot_id), sql_literal(status),
                    f"{intersection_area:.3f}", f"{plot_area:.3f}", f"{percentage:.6f}",
                    sql_literal(area_hash), sql_literal(plot_hash),
                )) + ")"
            )
    client.sql("DELETE FROM toegankelijkheidsgebied_plot_afleiding")
    if values:
        client.sql(
            "INSERT INTO toegankelijkheidsgebied_plot_afleiding "
            "(gebied_versie_id,plot_id,status_code,doorsnijding_m2,plot_oppervlakte_m2,aandeel_pct,"
            "gebied_geometrie_sha256,plot_geometrie_sha256) VALUES " + ",".join(values)
        )
    return len(values)


def apply(client: Client, feature: dict[str, Any], plot_areas: list[dict[str, Any]]) -> None:
    statements = build_migration_statements(feature, plot_areas)
    for statement in statements:
        if statement.startswith("DELETE FROM maatregel_registratie_herkomst") or statement.startswith("DROP TABLE"):
            continue
        client.sql(statement)
    retire_old_model(client)
    rebuild_plot_derivations(client)


def verify(client: Client, feature: dict[str, Any], plot_areas: list[dict[str, Any]]) -> dict[str, Any]:
    interior_rings = 0
    for geometry_hex in client.sql(
        "SELECT HEX(ST_AsBinary(geometrie)) FROM toegankelijkheidsgebied_versie WHERE geldig_tot IS NULL"
    ).splitlines():
        geometry = ogr.CreateGeometryFromWkb(bytes.fromhex(geometry_hex))
        interior_rings += sum(max(0, part.GetGeometryCount() - 1) for part in _polygon_parts(geometry))
    obsolete_codes = ",".join(sql_literal(code) for code in OBSOLETE_PLOT_AREA_CODES)
    result = {
        "oude_tabel": int(client.scalar("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='maatregel_toegankelijkheid_registratie' AND table_type='BASE TABLE'")),
        "oude_herkomstkolom": int(client.scalar("SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name='maatregel_registratie_herkomst' AND column_name='toegang_registratie_id'")),
        "beheerregistraties": int(client.scalar("SELECT COUNT(*) FROM maatregel_plot_jaar_registratie")),
        "herkomsten": int(client.scalar("SELECT COUNT(*) FROM maatregel_registratie_herkomst")),
        "gebieden": int(client.scalar("SELECT COUNT(*) FROM toegankelijkheidsgebied")),
        "gebiedsversies": int(client.scalar("SELECT COUNT(*) FROM toegankelijkheidsgebied_versie")),
        "plotdoorsnijdingen": int(client.scalar("SELECT COUNT(*) FROM toegankelijkheidsgebied_plot_afleiding")),
        "bron101_beheer": int(client.scalar("SELECT COUNT(*) FROM maatregel_plot_jaar_registratie WHERE bron_id=101")),
        "interne_ringen": interior_rings,
        "vervangen_gebiedsrecords": int(client.scalar(
            f"SELECT COUNT(*) FROM toegankelijkheidsgebied WHERE gebied_code IN ({obsolete_codes})"
        )),
    }
    if result["oude_tabel"] or result["oude_herkomstkolom"]:
        raise AssertionError(result)
    if result["interne_ringen"] or result["vervangen_gebiedsrecords"]:
        raise AssertionError(result)
    if result["beheerregistraties"] != 139 or result["herkomsten"] != 144 or result["bron101_beheer"] != 139:
        raise AssertionError(result)
    expected_areas = 1 + len(plot_areas)
    if result["gebieden"] != expected_areas or result["gebiedsversies"] != expected_areas or result["plotdoorsnijdingen"] < 18:
        raise AssertionError(result)
    row = client.sql(
        "SELECT status_code,geldig_vanaf,IF(geldig_tot IS NULL,'NULL',geldig_tot),"
        "ST_SRID(geometrie),ST_IsValid(geometrie),ROUND(ST_Area(geometrie),3),geometrie_sha256 "
        "FROM toegankelijkheidsgebied_versie v JOIN toegankelijkheidsgebied g USING(gebied_id) "
        f"WHERE g.gebied_code='{AREA_CODE}'"
    ).split("\t")
    if row[:5] != ["afgesloten", "1955-01-01", "NULL", "28992", "1"]:
        raise AssertionError(row)
    if row[6] != feature["geometrie_sha256"] or abs(float(row[5]) - feature["oppervlakte_m2"]) > 0.01:
        raise AssertionError(row)
    for plot_area in plot_areas:
        plot_row = client.sql(
            "SELECT status_code,geldig_vanaf,IF(geldig_tot IS NULL,'NULL',geldig_tot),"
            "ST_SRID(geometrie),ST_IsValid(geometrie),ROUND(ST_Area(geometrie),3),geometrie_sha256 "
            "FROM toegankelijkheidsgebied_versie v JOIN toegankelijkheidsgebied g USING(gebied_id) "
            f"WHERE g.gebied_code={sql_literal(plot_area['gebied_code'])}"
        ).split("\t")
        if plot_row[:5] != [plot_area["status_code"], "1955-01-01", "NULL", "28992", "1"]:
            raise AssertionError(plot_row)
        if plot_row[6] != plot_area["geometrie_sha256"] or abs(float(plot_row[5]) - plot_area["oppervlakte_m2"]) > 0.01:
            raise AssertionError(plot_row)
        full_kavels = plot_area.get("volledige_kavels", plot_area["kavels"])
        if full_kavels:
            kavel_sql = ",".join(sql_literal(kavel) for kavel in full_kavels)
            covered = int(client.scalar(
                "SELECT COUNT(*) FROM toegankelijkheidsgebied_plot_afleiding a "
                "JOIN toegankelijkheidsgebied_versie v USING(gebied_versie_id) "
                "JOIN toegankelijkheidsgebied g USING(gebied_id) JOIN plots p USING(plot_id) "
                f"WHERE g.gebied_code={sql_literal(plot_area['gebied_code'])} "
                f"AND p.kavel_nummer IN ({kavel_sql}) AND a.status_code={sql_literal(plot_area['status_code'])} "
                "AND a.aandeel_pct>99.9999"
            ))
            if covered != len(full_kavels):
                raise AssertionError(f"Niet alle kavels volledig gedekt voor {plot_area['gebied_code']}: {covered}")
        for partial_kavel in plot_area.get("gedeeltelijke_kavels", ()):
            partial = float(client.scalar(
                "SELECT a.aandeel_pct FROM toegankelijkheidsgebied_plot_afleiding a "
                "JOIN toegankelijkheidsgebied_versie v USING(gebied_versie_id) "
                "JOIN toegankelijkheidsgebied g USING(gebied_id) JOIN plots p USING(plot_id) "
                f"WHERE g.gebied_code={sql_literal(plot_area['gebied_code'])} "
                f"AND p.kavel_nummer={sql_literal(partial_kavel)}"
            ))
            if not 0 < partial < 100:
                raise AssertionError(
                    f"Gedeeltelijke kavel {partial_kavel} is niet gedeeltelijk gedekt: {partial}"
                )
    if result["plotdoorsnijdingen"] < 1:
        raise AssertionError("Geen kavels door gebied doorsneden")
    bad = int(client.scalar("SELECT COUNT(*) FROM toegankelijkheidsgebied_plot_afleiding WHERE aandeel_pct<=0 OR aandeel_pct>100"))
    if bad:
        raise AssertionError(f"Ongeldige afgeleide percentages: {bad}")
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", default="Meijendel")
    parser.add_argument("--route-gpkg", type=Path, default=DEFAULT_ROUTE_GPKG)
    parser.add_argument("--reference-gpkg", type=Path, default=DEFAULT_REFERENCE_GPKG)
    parser.add_argument(
        "--bierlap-boundary-gpx",
        type=Path,
        default=DEFAULT_BIERLAP_BOUNDARY_GPX,
    )
    parser.add_argument(
        "--bierlap-accepted-gpkg",
        type=Path,
        default=DEFAULT_BIERLAP_ACCEPTED_GPKG,
    )
    parser.add_argument(
        "--m45-accepted-gpkg",
        type=Path,
        default=DEFAULT_M45_ACCEPTED_GPKG,
    )
    parser.add_argument("--backup-dir", type=Path, default=BACKUP_ROOT)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--verify", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    feature = derive_route_area(args.route_gpkg)
    plot_areas = read_plot_areas(args.reference_gpkg)
    plot_areas.append(
        derive_bierlap_kijfhoek_area(
            args.reference_gpkg,
            args.bierlap_boundary_gpx,
            args.bierlap_accepted_gpkg,
        )
    )
    plot_areas.append(derive_m45_closed_area(args.reference_gpkg, args.m45_accepted_gpkg))
    client = Client(args.database)
    if args.apply:
        metadata = backup(client, args.backup_dir, feature, plot_areas)
        apply(client, feature, plot_areas)
        print(f"BACKUP_METADATA={metadata}")
    if args.apply or args.verify:
        print(json.dumps(verify(client, feature, plot_areas), sort_keys=True))
    if not args.apply and not args.verify:
        print(json.dumps({
            "garmin": {k: v for k, v in feature.items() if k != "wkt"},
            "plotgebieden": [{k: v for k, v in area.items() if k != "wkt"} for area in plot_areas],
        }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
