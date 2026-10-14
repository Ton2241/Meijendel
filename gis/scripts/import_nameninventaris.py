#!/usr/bin/env python3
"""Valideer en importeer het bronvaste namenregister voor Meijendel."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import NamedTuple

from shapely import wkt
from shapely.geometry import shape


ROOT = Path(__file__).parents[2]
SCHEMA = ROOT / "gis" / "database" / "nameninventaris_schema.sql"
DEFAULT_MYSQL = Path("/usr/local/mysql/bin/mysql")
DEFAULT_OSM = ROOT / "Recreatie" / "OSM" / "osm_highways_lijnen.geojson"
DELIVERY_VERSION = "meijendel_nameninventaris_2026-10-14"
RULE_VERSION = "nameninventaris-import-v1"
ZOTERO_KEYS = {
    "SRC-VANLEEUWEN-1992": "NZWRNSSI",
    "SRC-NEEFJES-2010": "7Y38WFF3",
    "SRC-VANDERMEIJDEN-2012": "DB82S8IR",
}

REQUIRED_FILES = {
    "README.md",
    "VALIDATIE.txt",
    "meijendel_bronlacunes.csv",
    "meijendel_bronnen.csv",
    "meijendel_bronregister.md",
    "meijendel_namen_epsg4326.geojson",
    "meijendel_namen_rdnew.csv",
    "meijendel_vermeldingen.csv",
    "mysql_staging.sql",
}

CSV_COLUMNS = {
    "meijendel_bronnen.csv": {
        "source_id", "title", "author", "year", "source_type", "location",
        "access_date", "spatial_basis", "rights", "quality",
    },
    "meijendel_namen_rdnew.csv": {
        "object_id", "canonical_name", "object_class", "name_status",
        "first_mention", "last_mention", "mention_count", "source_ids",
        "geometry_status", "geometry_source_id", "location_precision_m",
        "location_uncertainty", "wkt_rdnew",
    },
    "meijendel_vermeldingen.csv": {
        "mention_id", "object_id", "name_as_source", "canonical_name",
        "object_class", "name_status", "mention_start", "mention_end",
        "source_id", "page_or_map", "subarea", "evidence_note",
    },
    "meijendel_bronlacunes.csv": {
        "object_id", "canonical_name", "object_class", "name_status",
        "source_ids", "missing", "consequence", "smallest_next_source",
    },
}


class ObjectRecord(NamedTuple):
    object_id: str
    voorkeursnaam: str
    aangeleverde_naam: str
    objectklasse: str
    bronobjecttype: str | None
    bewijsstatus: str
    source_ids: tuple[str, ...]
    nauwkeurigheid_m: float | None
    nauwkeurigheidsstatus: str
    geometriebron_id: str | None
    wkt_rdnew: str | None
    raw: dict[str, str]


class MentionRecord(NamedTuple):
    mention_id: str
    object_id: str
    bronnaam: str
    source_id: str
    periode_letterlijk: str
    periode_einde_letterlijk: str | None
    jaar_van: int
    jaar_tot: int
    datumprecisie: str
    raw: dict[str, str]


class GeometryRecord(NamedTuple):
    object_id: str
    source_id: str
    wkt_rdnew: str
    wkt_sha256: str
    mapped_date: str
    bronobjecttype: str | None
    nauwkeurigheid_m: float | None
    nauwkeurigheidsstatus: str
    selectiegrondslag: str
    opmerking: str | None


class GeometrySourceObject(NamedTuple):
    object_id: str
    source_id: str
    bronobject_systeem: str
    bronobject_id: str


class ImportPlan:
    def __init__(
        self,
        *,
        delivery: Path,
        delivery_hash: str,
        sources: dict[str, dict[str, str]],
        objects: dict[str, ObjectRecord],
        mentions: dict[str, MentionRecord],
        geometries: dict[str, GeometryRecord],
        geometry_source_objects: list[GeometrySourceObject],
        assessments: dict[str, dict[str, str]],
    ) -> None:
        self.delivery = delivery
        self.delivery_hash = delivery_hash
        self.sources = sources
        self.objects = objects
        self.mentions = mentions
        self.geometries = geometries
        self.geometry_source_objects = geometry_source_objects
        self.assessments = assessments
        self.counts = {
            "bronnen": len(sources),
            "objecten": len(objects),
            "vermeldingen": len(mentions),
            "geometrieen": len(geometries),
            "ontbrekende_geometrie": len(assessments),
            "top10nl_ids": len({link.bronobject_id for link in geometry_source_objects
                                 if link.bronobject_systeem == "TOP10NL"}),
            "osm_ids": len({link.bronobject_id for link in geometry_source_objects
                             if link.bronobject_systeem == "OSM"}),
        }


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        fields = set(reader.fieldnames or [])
        missing = CSV_COLUMNS[path.name] - fields
        if missing:
            raise ValueError(f"Ontbrekende kolom(men) in {path.name}: {', '.join(sorted(missing))}")
        return [{key: (value or "").strip() for key, value in row.items()} for row in reader]


def verify_delivery_checksums(delivery: Path) -> dict[str, str]:
    manifest_path = delivery / "SHA256SUMS.txt"
    if not manifest_path.is_file():
        raise ValueError("Checksummanifest SHA256SUMS.txt ontbreekt")
    expected: dict[str, str] = {}
    for line in manifest_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        digest, relative = line.split(maxsplit=1)
        expected[Path(relative.strip()).name] = digest
    if set(expected) != REQUIRED_FILES:
        missing = REQUIRED_FILES - set(expected)
        extra = set(expected) - REQUIRED_FILES
        raise ValueError(f"Onvolledig checksummanifest; ontbreekt={sorted(missing)}, extra={sorted(extra)}")
    for name, digest in expected.items():
        path = delivery / name
        if not path.is_file() or sha256_file(path) != digest:
            raise ValueError(f"Afwijkende checksum voor {name}")
    return expected


def normalize_object_name(value: str) -> tuple[str, str | None]:
    corrections = {
        "Blankenburgh|Buitenplaats": ("Blankenburgh", "Buitenplaats"),
        "Voorlinden|Buitenplaats": ("Voorlinden", "Buitenplaats"),
    }
    return corrections.get(value, (value, None))


def normalize_evidence_status(value: str) -> str:
    mapping = {
        "huidig": "actueel_bronbewijs",
        "historisch": "historisch_bronbewijs",
        "huidig_en_historisch": "actueel_en_historisch_bronbewijs",
    }
    try:
        return mapping[value]
    except KeyError as exc:
        raise ValueError(f"Onbekende name_status: {value}") from exc


def parse_period(value: str, end_value: str = "") -> tuple[int, int, str]:
    value = value.strip()
    end_value = end_value.strip()
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        year = int(value[:4])
        precision = "dag"
        start_year = year
        end_year = year
    elif re.fullmatch(r"\d{4}", value):
        start_year = end_year = int(value)
        precision = "jaar"
    elif re.fullmatch(r"\d{4}/\d{4}", value):
        start_year, end_year = map(int, value.split("/"))
        if end_year < start_year:
            raise ValueError(f"Ongeldige periode: {value}")
        precision = "decennium" if start_year % 10 == 0 and end_year == start_year + 9 else "jaarbereik"
    else:
        raise ValueError(f"Ongeldige periode: {value}")
    if end_value:
        if not re.fullmatch(r"\d{4}(?:-\d{2}-\d{2})?", end_value):
            raise ValueError(f"Ongeldige periode-eindwaarde: {end_value}")
        explicit_end = int(end_value[:4])
        if explicit_end < start_year:
            raise ValueError(f"Ongeldige periode: {value} tot {end_value}")
        end_year = explicit_end
        if precision != "decennium":
            precision = "jaarbereik"
    return start_year, end_year, precision


def parse_precision(value: str) -> tuple[float | None, str]:
    value = value.strip()
    if not value or value == "bron niet opgegeven":
        return None, "niet_opgegeven"
    try:
        numeric = float(value)
    except ValueError as exc:
        raise ValueError(f"Ongeldige location_precision_m: {value}") from exc
    if numeric < 0:
        raise ValueError(f"Ongeldige location_precision_m: {value}")
    return numeric, "opgegeven"


def split_source_codes(value: str) -> tuple[str, ...]:
    return tuple(part.strip() for part in value.split(";") if part.strip())


def split_native_feature_ids(value: str) -> tuple[str, ...]:
    return tuple(part.strip() for part in re.split(r"[;,]", value) if part.strip())


def reject_duplicates(rows: list[dict[str, str]], key: str, label: str) -> None:
    values = [row[key] for row in rows]
    if len(values) != len(set(values)):
        raise ValueError(f"Dubbel {label}: {key}")


def projected_geojson_wkts(path: Path) -> dict[str, str]:
    ogr2ogr = shutil.which("ogr2ogr") or "/Applications/Postgres.app/Contents/Versions/latest/bin/ogr2ogr"
    with tempfile.TemporaryDirectory(prefix="nameninventaris-ogr-") as temp:
        target = Path(temp) / "projected.csv"
        result = subprocess.run(
            [ogr2ogr, "-f", "CSV", str(target), str(path), "-t_srs", "EPSG:28992",
             "-lco", "GEOMETRY=AS_WKT"],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode:
            raise ValueError(f"GeoJSON-herprojectie mislukt: {result.stderr.strip()}")
        with target.open(encoding="utf-8-sig", newline="") as handle:
            return {row["object_id"]: row.get("WKT", "") for row in csv.DictReader(handle)}


def validate_geometry_pair(
    rd_rows: list[dict[str, str]], geojson: dict, *, compare_projection: bool
) -> tuple[dict[str, str], dict[str, dict]]:
    crs_name = geojson.get("crs", {}).get("properties", {}).get("name")
    if crs_name != "urn:ogc:def:crs:OGC:1.3:CRS84":
        raise ValueError(f"GeoJSON moet CRS84 gebruiken; gevonden: {crs_name}")
    features = geojson.get("features")
    if not isinstance(features, list):
        raise ValueError("GeoJSON-features ontbreken")
    geo_features: dict[str, dict] = {}
    for feature in features:
        object_id = str(feature.get("properties", {}).get("object_id", ""))
        if not object_id or object_id in geo_features:
            raise ValueError(f"Dubbel of leeg object_id in GeoJSON: {object_id}")
        geometry_data = feature.get("geometry")
        if geometry_data is not None:
            geometry = shape(geometry_data)
            if geometry.is_empty:
                raise ValueError(f"Lege geometrie voor {object_id}")
            if not geometry.is_valid:
                raise ValueError(f"Ongeldige geometrie in GeoJSON voor {object_id}")
        geo_features[object_id] = feature
    rd_wkts: dict[str, str] = {}
    for row in rd_rows:
        text = row["wkt_rdnew"]
        if text:
            geometry = wkt.loads(text)
            if geometry.is_empty:
                raise ValueError(f"Lege geometrie voor {row['object_id']}")
            if not geometry.is_valid:
                raise ValueError(f"Ongeldige geometrie voor {row['object_id']}")
            rd_wkts[row["object_id"]] = text
        if (geo_features.get(row["object_id"], {}).get("geometry") is None) != (not text):
            raise ValueError(f"GeoJSON/RD-geometriestatus verschilt voor {row['object_id']}")
    if set(geo_features) != {row["object_id"] for row in rd_rows}:
        raise ValueError("GeoJSON- en RD-objectpopulatie verschillen")
    if compare_projection:
        projected = projected_geojson_wkts(Path(geojson["_path"]))
        for object_id, rd_text in rd_wkts.items():
            projected_text = projected.get(object_id, "")
            if not projected_text:
                raise ValueError(f"Ontbrekende herprojectie voor {object_id}")
            distance = wkt.loads(rd_text).hausdorff_distance(wkt.loads(projected_text))
            if distance > 1e-6:
                raise ValueError(f"GeoJSON/RD-geometrie verschilt voor {object_id}: {distance} m")
    return rd_wkts, geo_features


def osm_ids(path: Path) -> set[str]:
    document = json.loads(path.read_text(encoding="utf-8"))
    return {str(feature.get("properties", {}).get("osm_id"))
            for feature in document.get("features", [])}


def build_import_plan(
    delivery: Path | str,
    *,
    verify_checksums: bool = True,
    osm_source: Path = DEFAULT_OSM,
) -> ImportPlan:
    delivery = Path(delivery).resolve()
    if delivery.name != DELIVERY_VERSION:
        raise ValueError(f"Onverwachte leveringsmap: {delivery.name}")
    if verify_checksums:
        manifest = verify_delivery_checksums(delivery)
    else:
        manifest = {name: sha256_file(delivery / name) for name in REQUIRED_FILES
                    if (delivery / name).is_file()}
    for name in REQUIRED_FILES:
        if not (delivery / name).is_file():
            raise ValueError(f"Vereist bestand ontbreekt: {name}")

    source_rows = read_csv(delivery / "meijendel_bronnen.csv")
    object_rows = read_csv(delivery / "meijendel_namen_rdnew.csv")
    mention_rows = read_csv(delivery / "meijendel_vermeldingen.csv")
    assessment_rows = read_csv(delivery / "meijendel_bronlacunes.csv")
    reject_duplicates(source_rows, "source_id", "source_id")
    reject_duplicates(object_rows, "object_id", "object_id")
    reject_duplicates(mention_rows, "mention_id", "mention_id")
    reject_duplicates(assessment_rows, "object_id", "lacune-object_id")

    sources = {row["source_id"]: row for row in source_rows}
    objects: dict[str, ObjectRecord] = {}
    for row in object_rows:
        source_ids = split_source_codes(row["source_ids"])
        if not source_ids or set(source_ids) - set(sources):
            raise ValueError(f"Onbekende broncode voor object {row['object_id']}")
        name, object_type = normalize_object_name(row["canonical_name"])
        precision, precision_status = parse_precision(row["location_precision_m"])
        objects[row["object_id"]] = ObjectRecord(
            row["object_id"], name, row["canonical_name"], row["object_class"],
            object_type, normalize_evidence_status(row["name_status"]), source_ids,
            precision, precision_status, row["geometry_source_id"] or None,
            row["wkt_rdnew"] or None, row,
        )

    mentions: dict[str, MentionRecord] = {}
    for row in mention_rows:
        if row["object_id"] not in objects:
            raise ValueError(f"Verweesde vermelding {row['mention_id']}: {row['object_id']}")
        if row["source_id"] not in sources:
            raise ValueError(f"Verweesde bronvermelding {row['mention_id']}: {row['source_id']}")
        normalize_evidence_status(row["name_status"])
        year_from, year_to, precision = parse_period(row["mention_start"], row["mention_end"])
        mentions[row["mention_id"]] = MentionRecord(
            row["mention_id"], row["object_id"], row["name_as_source"], row["source_id"],
            row["mention_start"], row["mention_end"] or None, year_from, year_to,
            precision, row,
        )

    geojson_path = delivery / "meijendel_namen_epsg4326.geojson"
    geojson = json.loads(geojson_path.read_text(encoding="utf-8"))
    geojson["_path"] = str(geojson_path)
    rd_wkts, geo_features = validate_geometry_pair(
        object_rows, geojson, compare_projection=verify_checksums
    )

    links: list[GeometrySourceObject] = []
    for mention in mentions.values():
        if mention.source_id == "SRC-PDOK-TOP10NL-2026":
            system = "TOP10NL"
        elif mention.source_id == "SRC-OSM-2026-04-03":
            system = "OSM"
        else:
            continue
        if mention.object_id not in rd_wkts:
            raise ValueError(f"Bronobject gekoppeld aan object zonder geometrie: {mention.object_id}")
        for native_id in split_native_feature_ids(mention.raw["page_or_map"]):
            links.append(GeometrySourceObject(
                mention.object_id, mention.source_id, system, native_id
            ))
    unique_links = {(link.bronobject_systeem, link.bronobject_id): link for link in links}
    if len(unique_links) != len(links):
        raise ValueError("Dubbele geometrie-bronobjectkoppeling")
    links = sorted(links, key=lambda link: (link.bronobject_systeem, link.bronobject_id))

    top10_geo_ids = {
        native_id
        for feature in geo_features.values()
        for native_id in split_native_feature_ids(
            str(feature.get("properties", {}).get("top10nl_lokaal_id", ""))
        )
    }
    top10_link_ids = {link.bronobject_id for link in links if link.bronobject_systeem == "TOP10NL"}
    if top10_link_ids != top10_geo_ids:
        raise ValueError("TOP10NL-bronobject-ID's verschillen tussen vermeldingen en GeoJSON")
    available_osm_ids = osm_ids(osm_source)
    missing_osm = {link.bronobject_id for link in links if link.bronobject_systeem == "OSM"} - available_osm_ids
    if missing_osm:
        raise ValueError(f"OSM-bronobject ontbreekt in lokale export: {sorted(missing_osm)}")

    geometries: dict[str, GeometryRecord] = {}
    for object_id, text in rd_wkts.items():
        feature_props = geo_features[object_id]["properties"]
        obj = objects[object_id]
        source_id = obj.geometriebron_id
        if not source_id or source_id not in sources:
            raise ValueError(f"Geometriebron ontbreekt voor {object_id}")
        source = sources[source_id]
        geometries[object_id] = GeometryRecord(
            object_id, source_id, text, hashlib.sha256(text.encode("utf-8")).hexdigest(),
            feature_props.get("mapped_date", ""),
            obj.bronobjecttype or feature_props.get("top10nl_type") or feature_props.get("osm_highway"),
            obj.nauwkeurigheid_m, obj.nauwkeurigheidsstatus, source["spatial_basis"],
            obj.raw["location_uncertainty"] or None,
        )

    assessments = {row["object_id"]: row for row in assessment_rows}
    if set(assessments) - set(objects):
        raise ValueError("Bronlacune verwijst naar onbekend object")
    missing_geometry_ids = set(objects) - set(geometries)
    if set(assessments) != missing_geometry_ids:
        raise ValueError("Bronlacunes en objecten zonder geometrie verschillen")

    expected_counts = {
        "bronnen": 8,
        "objecten": 182,
        "vermeldingen": 299,
        "geometrieen": 71,
        "ontbrekende_geometrie": 111,
        "top10nl_ids": 47,
        "osm_ids": 60,
    }
    delivery_hash = hashlib.sha256(
        "\n".join(f"{name}:{manifest[name]}" for name in sorted(manifest)).encode("utf-8")
    ).hexdigest()
    plan = ImportPlan(
        delivery=delivery,
        delivery_hash=delivery_hash,
        sources=sources,
        objects=objects,
        mentions=mentions,
        geometries=geometries,
        geometry_source_objects=links,
        assessments=assessments,
    )
    if plan.counts != expected_counts:
        raise ValueError(f"Onverwachte leveringsaantallen: {plan.counts}")
    return plan


def sql_text(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"


def sql_nullable(value: str | None) -> str:
    return "NULL" if value is None or value == "" else sql_text(value)


def sql_number(value: float | int | None) -> str:
    return "NULL" if value is None else format(value, ".15g")


def database_identifier(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]{0,63}", value):
        raise ValueError(f"Ongeldige databasenaam: {value}")
    return f"`{value}`"


def logical_source_reference(source_id: str, value: str) -> tuple[str, str | None]:
    if source_id in ZOTERO_KEYS:
        key = ZOTERO_KEYS[source_id]
        return f"zotero:{key}", key
    if source_id == "SRC-OSM-2026-04-03":
        return "project:Recreatie/OSM/osm_highways_lijnen.geojson", None
    if value.startswith("/"):
        raise ValueError(f"Absolute bronverwijzing niet toegestaan voor {source_id}: {value}")
    return value, None


def values_sql(rows: list[tuple[str, ...]]) -> str:
    return ",\n".join("(" + ",".join(row) + ")" for row in rows)


def build_import_sql(plan: ImportPlan, database: str) -> str:
    database_sql = database_identifier(database)
    parts = [
        f"USE {database_sql};",
        "SET NAMES utf8mb4;",
        "START TRANSACTION;",
        "INSERT INTO nameninventaris_import "
        "(versiesleutel,leveringsdatum,bronreferentie,archief_sha256,regelversie,"
        "verwacht_bronnen,verwacht_objecten,verwacht_vermeldingen,"
        "verwacht_geometrieen,verwacht_lacunes) VALUES "
        f"({sql_text(DELIVERY_VERSION)},'2026-10-14',"
        f"{sql_text('codex-delivery:' + DELIVERY_VERSION)},{sql_text(plan.delivery_hash)},"
        f"{sql_text(RULE_VERSION)},8,182,299,71,111);",
        "SET @nameninventaris_import_id := LAST_INSERT_ID();",
    ]

    source_values: list[tuple[str, ...]] = []
    for source_id in sorted(plan.sources):
        row = plan.sources[source_id]
        reference, zotero_key = logical_source_reference(source_id, row["location"])
        source_values.append((
            "@nameninventaris_import_id",
            sql_text(source_id),
            sql_text(row["title"]),
            sql_nullable(row["author"] or None),
            sql_number(int(row["year"])) if row["year"] else "NULL",
            sql_text(row["source_type"]),
            sql_text(reference),
            sql_nullable(zotero_key),
            sql_text(row["access_date"]),
            sql_text(row["spatial_basis"]),
            sql_text(row["rights"]),
            sql_text(row["quality"]),
        ))
    parts.append(
        "INSERT INTO nameninventaris_bron "
        "(import_id,source_id,titel,auteur_beheerder,bronjaar,brontype,bronverwijzing,"
        "zotero_item_key,raadpleegdatum,ruimtelijke_grondslag,rechten,kwaliteitsbeoordeling) VALUES\n"
        + values_sql(source_values) + ";"
    )

    object_values: list[tuple[str, ...]] = []
    for object_id in sorted(plan.objects):
        row = plan.objects[object_id]
        object_values.append((
            sql_text(object_id),
            "@nameninventaris_import_id",
            sql_text(row.voorkeursnaam),
            sql_text(row.aangeleverde_naam),
            sql_text(row.objectklasse),
            sql_nullable(row.bronobjecttype),
            sql_text(row.bewijsstatus),
            sql_number(row.nauwkeurigheid_m),
            sql_text(row.nauwkeurigheidsstatus),
        ))
    parts.append(
        "INSERT INTO nameninventaris_object "
        "(object_id,import_id,voorkeursnaam,aangeleverde_naam,objectklasse,bronobjecttype,"
        "bewijsstatus,nauwkeurigheid_m,nauwkeurigheidsstatus) VALUES\n"
        + values_sql(object_values) + ";"
    )

    mention_values: list[tuple[str, ...]] = []
    for mention_id in sorted(plan.mentions):
        row = plan.mentions[mention_id]
        mention_values.append((
            sql_text(mention_id),
            "@nameninventaris_import_id",
            sql_text(row.object_id),
            sql_text(row.source_id),
            sql_text(row.bronnaam),
            sql_text(row.periode_letterlijk),
            sql_nullable(row.periode_einde_letterlijk),
            str(row.jaar_van),
            str(row.jaar_tot),
            sql_text(row.datumprecisie),
            sql_nullable(row.raw["page_or_map"] or None),
            sql_nullable(row.raw["subarea"] or None),
            sql_text(row.raw["evidence_note"]),
        ))
    parts.append(
        "INSERT INTO nameninventaris_vermelding "
        "(mention_id,import_id,object_id,source_id,bronnaam,periode_letterlijk,"
        "periode_einde_letterlijk,jaar_van,jaar_tot,datumprecisie,pagina_kaart_bronobject,"
        "deelgebied,bewijsnotitie) VALUES\n" + values_sql(mention_values) + ";"
    )

    geometry_values: list[tuple[str, ...]] = []
    for object_id in sorted(plan.geometries):
        row = plan.geometries[object_id]
        geometry_values.append((
            "@nameninventaris_import_id",
            sql_text(row.object_id),
            sql_text(row.source_id),
            sql_text(RULE_VERSION),
            sql_text(row.mapped_date),
            sql_nullable(row.bronobjecttype),
            sql_text(row.wkt_sha256),
            sql_number(row.nauwkeurigheid_m),
            sql_text(row.nauwkeurigheidsstatus),
            sql_text(row.selectiegrondslag),
            sql_nullable(row.opmerking),
            f"ST_GeomFromText({sql_text(row.wkt_rdnew)},28992)",
        ))
    parts.append(
        "INSERT INTO nameninventaris_geometrie "
        "(import_id,object_id,source_id,geometrieversie,peildatum,bronobjecttype,wkt_sha256,"
        "nauwkeurigheid_m,nauwkeurigheidsstatus,ruimtelijke_selectiegrondslag,"
        "geometrieopmerking,geometry) VALUES\n" + values_sql(geometry_values) + ";"
    )

    link_values: list[tuple[str, ...]] = []
    for link in plan.geometry_source_objects:
        link_values.append((
            "(SELECT geometrie_id FROM nameninventaris_geometrie "
            f"WHERE import_id=@nameninventaris_import_id AND object_id={sql_text(link.object_id)} "
            f"AND source_id={sql_text(link.source_id)} AND geometrieversie={sql_text(RULE_VERSION)})",
            sql_text(link.bronobject_systeem),
            sql_text(link.bronobject_id),
        ))
    parts.append(
        "INSERT INTO nameninventaris_geometrie_bronobject "
        "(geometrie_id,bronobject_systeem,bronobject_id) VALUES\n"
        + values_sql(link_values) + ";"
    )

    assessment_values: list[tuple[str, ...]] = []
    for object_id in sorted(plan.assessments):
        row = plan.assessments[object_id]
        assessment_values.append((
            "@nameninventaris_import_id",
            sql_text(object_id),
            sql_text(RULE_VERSION),
            sql_text("bronlacune_geometrie"),
            sql_text(row["missing"]),
            sql_text(row["consequence"]),
            sql_text(row["smallest_next_source"]),
            "1",
        ))
    parts.append(
        "INSERT INTO nameninventaris_beoordeling "
        "(import_id,object_id,regelversie,beoordelingsstatus,ontbreekt,gevolg,"
        "kleinste_volgende_bron,actueel) VALUES\n" + values_sql(assessment_values) + ";"
    )
    parts.append("COMMIT;")
    return "\n".join(parts) + "\n"


def mysql_connection_args(login_path: str, database: str | None = None) -> list[str]:
    args = [f"--login-path={login_path}", "--protocol=TCP", "--batch", "--raw",
            "--skip-column-names"]
    if database:
        args.append(database)
    return args


def run_mysql(client: Path, args: list[str], sql: str) -> str:
    result = subprocess.run(
        [str(client), *args], input=sql, text=True, capture_output=True, check=False
    )
    if result.returncode:
        raise RuntimeError(result.stderr or result.stdout)
    return result.stdout.strip()


def schema_for_database(database: str) -> str:
    schema = SCHEMA.read_text(encoding="utf-8")
    return re.sub(r"\bUSE\s+Meijendel\s*;", f"USE {database_identifier(database)};",
                  schema, count=1, flags=re.IGNORECASE)


def apply_delivery(
    delivery: Path | str,
    *,
    database: str,
    mysql_client: Path = DEFAULT_MYSQL,
    login_path: str = "meijendel_root",
    verify_checksums: bool = True,
    mysql_runner=run_mysql,
) -> str:
    plan = build_import_plan(delivery, verify_checksums=verify_checksums)
    args = mysql_connection_args(login_path)
    mysql_runner(mysql_client, args, schema_for_database(database))
    existing = mysql_runner(
        mysql_client,
        mysql_connection_args(login_path, database),
        "SELECT archief_sha256 FROM nameninventaris_import "
        f"WHERE versiesleutel={sql_text(DELIVERY_VERSION)}",
    ).strip()
    if existing:
        if existing != plan.delivery_hash:
            raise ValueError(
                f"Versiesleutel {DELIVERY_VERSION} bestaat met afwijkende inhoudshash"
            )
        return "already_present"
    mysql_runner(mysql_client, args, build_import_sql(plan, database))
    return "imported"


TABLES = (
    "nameninventaris_import",
    "nameninventaris_bron",
    "nameninventaris_object",
    "nameninventaris_vermelding",
    "nameninventaris_geometrie",
    "nameninventaris_geometrie_bronobject",
    "nameninventaris_beoordeling",
)


def database_fingerprint(
    *, database: str, mysql_client: Path = DEFAULT_MYSQL, login_path: str = "meijendel_root"
) -> dict[str, dict[str, int | str]]:
    args = mysql_connection_args(login_path, database)
    result: dict[str, dict[str, int | str]] = {}
    for table in TABLES:
        count = int(run_mysql(mysql_client, args, f"SELECT COUNT(*) FROM `{table}`"))
        checksum_row = run_mysql(mysql_client, args, f"CHECKSUM TABLE `{table}`")
        checksum = checksum_row.split("\t")[-1]
        result[table] = {"count": count, "checksum": checksum}
    return result


def grouped_counts(client: Path, args: list[str], sql: str) -> dict[str, int]:
    output = run_mysql(client, args, sql)
    result: dict[str, int] = {}
    for line in output.splitlines():
        if not line:
            continue
        key, value = line.split("\t", 1)
        result[key] = int(value)
    return result


def audit_database(
    *, database: str, mysql_client: Path = DEFAULT_MYSQL, login_path: str = "meijendel_root"
) -> dict:
    args = mysql_connection_args(login_path, database)
    counts = {table: int(run_mysql(mysql_client, args, f"SELECT COUNT(*) FROM `{table}`"))
              for table in TABLES}
    invalid_geometry = int(run_mysql(
        mysql_client, args,
        "SELECT COUNT(*) FROM nameninventaris_geometrie "
        "WHERE NOT ST_IsValid(geometry) OR ST_SRID(geometry)<>28992 OR ST_IsEmpty(geometry)",
    ))
    orphan_sql = """
SELECT
  (SELECT COUNT(*) FROM nameninventaris_vermelding v LEFT JOIN nameninventaris_object o
     ON o.import_id=v.import_id AND o.object_id=v.object_id WHERE o.object_id IS NULL) +
  (SELECT COUNT(*) FROM nameninventaris_vermelding v LEFT JOIN nameninventaris_bron b
     ON b.import_id=v.import_id AND b.source_id=v.source_id WHERE b.source_id IS NULL) +
  (SELECT COUNT(*) FROM nameninventaris_geometrie g LEFT JOIN nameninventaris_object o
     ON o.import_id=g.import_id AND o.object_id=g.object_id WHERE o.object_id IS NULL) +
  (SELECT COUNT(*) FROM nameninventaris_geometrie_bronobject l LEFT JOIN nameninventaris_geometrie g
     ON g.geometrie_id=l.geometrie_id WHERE g.geometrie_id IS NULL) +
  (SELECT COUNT(*) FROM nameninventaris_beoordeling b LEFT JOIN nameninventaris_object o
     ON o.import_id=b.import_id AND o.object_id=b.object_id WHERE o.object_id IS NULL)
"""
    orphan_rows = int(run_mysql(mysql_client, args, orphan_sql))
    duplicate_rows = int(run_mysql(
        mysql_client, args,
        "SELECT COUNT(*) FROM ("
        "SELECT object_id,regelversie,COUNT(*) n FROM nameninventaris_beoordeling "
        "GROUP BY object_id,regelversie HAVING n>1) d",
    ))
    missing_output = run_mysql(
        mysql_client, args,
        "SELECT o.voorkeursnaam FROM nameninventaris_object o "
        "LEFT JOIN nameninventaris_geometrie g ON g.object_id=o.object_id "
        "WHERE o.voorkeursnaam IN ('Bunkerpad','Klippad') AND g.geometrie_id IS NULL "
        "ORDER BY o.voorkeursnaam",
    )
    return {
        "counts": counts,
        "invalid_geometry": invalid_geometry,
        "orphan_rows": orphan_rows,
        "duplicate_rows": duplicate_rows,
        "top10nl_ids": int(run_mysql(
            mysql_client, args,
            "SELECT COUNT(DISTINCT bronobject_id) FROM nameninventaris_geometrie_bronobject "
            "WHERE bronobject_systeem='TOP10NL'",
        )),
        "osm_ids": int(run_mysql(
            mysql_client, args,
            "SELECT COUNT(DISTINCT bronobject_id) FROM nameninventaris_geometrie_bronobject "
            "WHERE bronobject_systeem='OSM'",
        )),
        "missing_named_geometry": missing_output.splitlines() if missing_output else [],
        "evidence_statuses": grouped_counts(
            mysql_client, args,
            "SELECT bewijsstatus,COUNT(*) FROM nameninventaris_object GROUP BY bewijsstatus ORDER BY bewijsstatus",
        ),
        "period_precisions": grouped_counts(
            mysql_client, args,
            "SELECT datumprecisie,COUNT(*) FROM nameninventaris_vermelding GROUP BY datumprecisie ORDER BY datumprecisie",
        ),
        "batch_hash": run_mysql(
            mysql_client, args,
            f"SELECT archief_sha256 FROM nameninventaris_import WHERE versiesleutel={sql_text(DELIVERY_VERSION)}",
        ),
        "fingerprint": database_fingerprint(
            database=database, mysql_client=mysql_client, login_path=login_path
        ),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--delivery", type=Path, required=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--validate", action="store_true")
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--audit-live", action="store_true")
    parser.add_argument("--database", default="Meijendel")
    parser.add_argument("--login-path", default="meijendel_root")
    parser.add_argument("--mysql-client", type=Path, default=DEFAULT_MYSQL)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    plan = build_import_plan(args.delivery)
    if args.apply:
        status = apply_delivery(
            args.delivery,
            database=args.database,
            mysql_client=args.mysql_client,
            login_path=args.login_path,
        )
        print(json.dumps({"status": status, "counts": plan.counts}, ensure_ascii=False, indent=2))
        return 0
    if args.audit_live:
        audit = audit_database(
            database=args.database,
            mysql_client=args.mysql_client,
            login_path=args.login_path,
        )
        print(json.dumps(audit, ensure_ascii=False, indent=2, sort_keys=True))
        return 0
    print(json.dumps({"version": DELIVERY_VERSION, "counts": plan.counts,
                      "delivery_sha256": plan.delivery_hash}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
