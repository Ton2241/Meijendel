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

from osgeo import ogr

ogr.UseExceptions()


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis/database/maatregelen_schema.sql"
_QFIELD_ROOT = Path("/Users/ton/Documents/GitHub/Meijendel/outputs/qfield_afscheidingen/meijendel_afscheidingen")
DEFAULT_ROUTE_GPKG = _QFIELD_ROOT / "routes.gpkg"
DEFAULT_REFERENCE_GPKG = _QFIELD_ROOT / "referentie.gpkg"
DEFAULT_FEATURE_ID = "garmin_activity_24999201739_routepunten_160_5470"
BACKUP_ROOT = Path("/Volumes/T7 Data/Home_Ton/Meijendel data/Backups-archief/Meijendel")
STATUS_CODES = ("afgesloten", "toegankelijk", "toegankelijk_met_toegangskaart")
MIGRATION_VERSION = "toegankelijkheidsgebieden-v7"
SOURCE_CODE = "garmin_veldregistratie_20261107"
AREA_CODE = "garmin_24999201739_omsloten_gebied"
PLOT_SOURCE_CODE = "handmatige_plotselectie_20261107"
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


def _area_record(geometry: ogr.Geometry, **metadata: Any) -> dict[str, Any]:
    if not geometry.IsValid():
        raise ValueError("Gebiedsgeometrie is ongeldig")
    geometry, removed_rings = exterior_boundaries_only(geometry.Clone())
    geometry = ogr.ForceToMultiPolygon(geometry)
    if geometry is None or geometry.GetGeometryName().upper() != "MULTIPOLYGON":
        raise ValueError("Gebiedsgeometrie is geen multipolygoon")
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


def read_plot_areas(path: Path) -> list[dict[str, Any]]:
    """Vorm de door Ton bevestigde gebieden uit volledige kavelgeometrieën."""
    dataset = ogr.Open(str(path), 0)
    if dataset is None:
        raise ValueError(f"GeoPackage niet leesbaar: {path}")
    layer = dataset.GetLayerByName("onderzoekskavels")
    if layer is None:
        raise ValueError("Laag onderzoekskavels ontbreekt")
    wanted = {kavel for spec in PLOT_AREA_SPECS for kavel in spec["kavels"]}
    found: dict[str, ogr.Geometry] = {}
    for feature in layer:
        name = feature.GetFieldAsString("naam")
        suffix = name.replace("Meijendel  k ", "", 1).replace("Meijendel k ", "", 1)
        kavel = "M" + suffix.split(maxsplit=1)[0]
        if kavel in wanted:
            found[kavel] = feature.GetGeometryRef().Clone()
    if set(found) != wanted:
        raise ValueError(f"Kavelgeometrie ontbreekt: {sorted(wanted - set(found))}")
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
        "'2026-11-07','2026-11-07','door gebruiker bevestigd',"
        "'Volledige kavels M13, M13s, M14, M15, M16, M16s, M17a, M66, M105, M77, M78/79, M75a en M31') "
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
        statements.extend((
            "INSERT INTO toegankelijkheidsgebied (gebied_code,naam,opmerking) VALUES ("
            f"{sql_literal(plot_area['gebied_code'])},{sql_literal(plot_area['naam'])},"
            f"{sql_literal(plot_area['opmerking'])}) "
            "ON DUPLICATE KEY UPDATE naam=VALUES(naam),opmerking=VALUES(opmerking)",
            "INSERT INTO toegankelijkheidsgebied_versie "
            "(gebied_id,versienummer,status_code,geldig_vanaf,geldig_tot,vastgesteld_op,bron_id,"
            "bron_object_id,inwinningsmethode,nauwkeurigheid_m,geometrie,geometrie_wkt,"
            "geometrie_sha256,oppervlakte_m2,geometrie_opmerking) SELECT "
            f"g.gebied_id,1,{sql_literal(plot_area['status_code'])},'1955-01-01',NULL,'2026-11-07',b.bron_id,"
            f"{sql_literal(plot_area['feature_id'])},'vereniging van volledige onderzoekskavels',NULL,"
            f"ST_GeomFromText({sql_literal(plot_area['wkt'])},28992),{sql_literal(plot_area['wkt'])},"
            f"{sql_literal(plot_area['geometrie_sha256'])},{plot_area['oppervlakte_m2']:.3f},"
            f"{sql_literal(plot_area['opmerking'])} FROM toegankelijkheidsgebied g JOIN maatregel_bron b "
            f"ON b.bron_code='{PLOT_SOURCE_CODE}' WHERE g.gebied_code={sql_literal(plot_area['gebied_code'])} "
            "ON DUPLICATE KEY UPDATE status_code=VALUES(status_code),geldig_vanaf=VALUES(geldig_vanaf),"
            "geldig_tot=VALUES(geldig_tot),vastgesteld_op=VALUES(vastgesteld_op),bron_id=VALUES(bron_id),"
            "bron_object_id=VALUES(bron_object_id),inwinningsmethode=VALUES(inwinningsmethode),"
            "geometrie=VALUES(geometrie),geometrie_wkt=VALUES(geometrie_wkt),"
            "geometrie_sha256=VALUES(geometrie_sha256),oppervlakte_m2=VALUES(oppervlakte_m2),"
            "geometrie_opmerking=VALUES(geometrie_opmerking)",
        ))
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
    if resolved != BACKUP_ROOT.resolve() and BACKUP_ROOT.resolve() not in resolved.parents:
        raise RuntimeError(f"Back-up moet onder {BACKUP_ROOT} staan")
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
    if result["gebieden"] != 6 or result["gebiedsversies"] != 6 or result["plotdoorsnijdingen"] < 13:
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
        kavel_sql = ",".join(sql_literal(kavel) for kavel in plot_area["kavels"])
        covered = int(client.scalar(
            "SELECT COUNT(*) FROM toegankelijkheidsgebied_plot_afleiding a "
            "JOIN toegankelijkheidsgebied_versie v USING(gebied_versie_id) "
            "JOIN toegankelijkheidsgebied g USING(gebied_id) JOIN plots p USING(plot_id) "
            f"WHERE g.gebied_code={sql_literal(plot_area['gebied_code'])} "
            f"AND p.kavel_nummer IN ({kavel_sql}) AND a.status_code={sql_literal(plot_area['status_code'])} "
            "AND a.aandeel_pct>99.9999"
        ))
        if covered != len(plot_area["kavels"]):
            raise AssertionError(f"Niet alle kavels volledig gedekt voor {plot_area['gebied_code']}: {covered}")
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
    parser.add_argument("--backup-dir", type=Path, default=BACKUP_ROOT)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--verify", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    feature = derive_route_area(args.route_gpkg)
    plot_areas = read_plot_areas(args.reference_gpkg)
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
