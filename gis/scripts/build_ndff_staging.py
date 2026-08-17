#!/usr/bin/env python3
"""Bouw een geintegreerde, ontdubbelde NDFF/FFV-staging-GeoPackage.

De bron-GeoPackages blijven ongewijzigd. Ontdubbeling gebeurt uitsluitend op
de NDFF-bronwaarde ``Identiteit``. Iedere fysieke bronvermelding blijft via de
laag ``ndff_waarneming_bron`` controleerbaar.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sqlite3
import sys
import tempfile
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from osgeo import ogr, osr


BUILD_VERSION = "1.0"
SOURCE_PATTERN = "ndff_*1950_2025*.gpkg"
EXPECTED_REQUEST_GROUPS = {
    "Amfibieen",
    "Dagvlinders",
    "Eencelligen",
    "Geleedpotigen (overig)",
    "Insecten (overig)",
    "Kevers",
    "Korstmossen",
    "Kranswieren, wieren en algen",
    "Kreeftachtigen",
    "Libellen",
    "Microvlinders",
    "Mossen",
    "Nachtvlinders",
    "Ongewervelden (overig)",
    "Reptielen",
    "Schimmels",
    "Snavelinsecten",
    "Spinachtigen",
    "Sprinkhanen en krekels",
    "Vaatplanten",
    "Vissen",
    "Vleermuizen",
    "Vliegen en muggen",
    "Vliesvleugeligen",
    "Weekdieren",
    "Zoogdieren (overig)",
}
SOURCE_FIELDS = [
    "Identiteit",
    "Soortgroep",
    "Naam soort",
    "Wetenschappelijke naam",
    "Periode start",
    "Periode stop",
    "Vervaging",
    "Hoknummer",
    "Hok grootte",
    "Telonderwerp",
    "Beleidsstatus",
    "Aantal",
    "Schaal (telmethode)",
    "Bronhouder",
    "Protocol",
    "Stadium",
    "Sekse",
    "Gedrag",
    "Doodsoorzaak",
    "Determinatiemethode",
    "Zoek- of vangmethode",
    "Apparatuur",
    "Oorsprong",
    "Biotoop",
    "Substraat",
    "Verblijfplaats",
]
PAYLOAD_FIELDS = [name for name in SOURCE_FIELDS if name != "Hoknummer"]


def ascii_label(value: str) -> str:
    return (
        value.replace("ë", "e")
        .replace("é", "e")
        .replace("ï", "i")
        .replace("ö", "o")
        .replace("ä", "a")
    )


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def payload_sha256(feature: ogr.Feature) -> str:
    # Hoknummer is de 1x1-km-exportcontext. Dezelfde Identiteit en geometrie kan
    # daardoor in aangrenzende aangevraagde hokken met een ander Hoknummer staan.
    values = [feature.GetField(name) for name in PAYLOAD_FIELDS]
    geom = feature.GetGeometryRef()
    digest = hashlib.sha256(
        json.dumps(values, ensure_ascii=False, default=str, separators=(",", ":")).encode(
            "utf-8"
        )
    )
    digest.update(b"\x00")
    if geom is not None:
        digest.update(bytes(geom.ExportToWkb()))
    return digest.hexdigest()


def parse_description(description: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in (description or "").splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            result[key.strip()] = value.strip()
    return result


def parse_bundle(filename: str) -> tuple[int, str]:
    match = re.search(r"(?:bundel_?|bundle_)(0?[123])([ab])?", filename, re.I)
    if not match:
        raise ValueError(f"Geen bundelnummer in bestandsnaam: {filename}")
    return int(match.group(1)), (match.group(2) or "")


def normalize_request_group(value: str) -> str:
    return ascii_label(value.strip())


def inspect_sources(source_dir: Path) -> tuple[list[dict[str, Any]], list[tuple[str, str]]]:
    files = sorted(
        path for path in source_dir.glob(SOURCE_PATTERN)
        if "_staging_" not in path.name.lower()
    )
    if not files:
        raise RuntimeError(f"Geen bronbestanden gevonden met {SOURCE_PATTERN} in {source_dir}")

    inspected: list[dict[str, Any]] = []
    reference_schema: list[tuple[str, str]] | None = None
    coverage: dict[str, set[int]] = defaultdict(set)

    for file_id, path in enumerate(files, 1):
        connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        try:
            contents = connection.execute(
                "SELECT description FROM gpkg_contents WHERE table_name = 'waarnemingen'"
            ).fetchone()
            geometry = connection.execute(
                "SELECT srs_id FROM gpkg_geometry_columns "
                "WHERE table_name = 'waarnemingen'"
            ).fetchone()
            schema = [
                (row[1], row[2])
                for row in connection.execute("PRAGMA table_info('waarnemingen')")
            ]
            record_count = connection.execute(
                "SELECT COUNT(*) FROM waarnemingen"
            ).fetchone()[0]
            null_identity = connection.execute(
                "SELECT COUNT(*) FROM waarnemingen "
                "WHERE Identiteit IS NULL OR trim(Identiteit) = ''"
            ).fetchone()[0]
            duplicate_identity = connection.execute(
                "SELECT COALESCE(SUM(n - 1), 0) FROM ("
                "SELECT COUNT(*) AS n FROM waarnemingen "
                "WHERE Identiteit IS NOT NULL AND trim(Identiteit) <> '' "
                "GROUP BY Identiteit HAVING COUNT(*) > 1)"
            ).fetchone()[0]
        finally:
            connection.close()

        if reference_schema is None:
            reference_schema = schema
        elif schema != reference_schema:
            raise RuntimeError(f"Afwijkend schema in {path.name}")
        if geometry is None or geometry[0] != 28992:
            raise RuntimeError(f"Verwacht EPSG:28992 in {path.name}, kreeg {geometry}")

        metadata = parse_description(contents[0] if contents else "")
        requested_group = normalize_request_group(metadata.get("Gevraagde soortgroep", ""))
        bundle, part = parse_bundle(path.name)
        coverage[requested_group].add(bundle)
        inspected.append(
            {
                "file_id": file_id,
                "path": path,
                "filename": path.name,
                "sha256": file_sha256(path),
                "size_bytes": path.stat().st_size,
                "record_count": record_count,
                "null_identity": null_identity,
                "within_file_duplicate_identity": duplicate_identity,
                "requested_group": requested_group,
                "bundle": bundle,
                "part": part,
                "request_time": metadata.get("Tijd aanvraag", ""),
                "requested_cells": metadata.get("Gevraagde hokken", ""),
                "requested_cell_size": metadata.get("Gevraagde hok grootte", ""),
                "requested_period": metadata.get("Gevraagde periode", ""),
                "description": contents[0] if contents else "",
            }
        )

    missing_groups = EXPECTED_REQUEST_GROUPS - set(coverage)
    extra_groups = set(coverage) - EXPECTED_REQUEST_GROUPS
    incomplete = {group: sorted({1, 2, 3} - bundles) for group, bundles in coverage.items() if bundles != {1, 2, 3}}
    if missing_groups or extra_groups or incomplete:
        raise RuntimeError(
            "Onvolledige of onverwachte dekking: "
            f"ontbrekende groepen={sorted(missing_groups)}, "
            f"extra groepen={sorted(extra_groups)}, onvolledige bundels={incomplete}"
        )
    if any(item["null_identity"] or item["within_file_duplicate_identity"] for item in inspected):
        raise RuntimeError("Lege of binnen een bestand dubbele Identiteit aangetroffen")
    return inspected, (reference_schema or [])


def add_field(layer: ogr.Layer, name: str, field_type: int, width: int = 0) -> None:
    definition = ogr.FieldDefn(name, field_type)
    if width:
        definition.SetWidth(width)
    if layer.CreateField(definition) != ogr.OGRERR_NONE:
        raise RuntimeError(f"Kon veld {name} niet maken in {layer.GetName()}")


def create_output(path: Path) -> tuple[ogr.DataSource, dict[str, ogr.Layer]]:
    driver = ogr.GetDriverByName("GPKG")
    dataset = driver.CreateDataSource(str(path))
    if dataset is None:
        raise RuntimeError(f"Kon GeoPackage niet maken: {path}")

    srs = osr.SpatialReference()
    srs.ImportFromEPSG(28992)
    observations = dataset.CreateLayer(
        "ndff_waarnemingen", srs=srs, geom_type=ogr.wkbUnknown,
        options=["GEOMETRY_NAME=geom", "FID=staging_fid", "SPATIAL_INDEX=YES"],
    )
    source_types = {
        "Periode start": ogr.OFTDateTime,
        "Periode stop": ogr.OFTDateTime,
    }
    for name in SOURCE_FIELDS:
        add_field(observations, name, source_types.get(name, ogr.OFTString))
    add_field(observations, "ontdubbel_sleutel", ogr.OFTString, 96)
    add_field(observations, "bronbestand_eerste", ogr.OFTString, 254)
    add_field(observations, "bronbestand_aantal", ogr.OFTInteger)
    add_field(observations, "bronrecord_aantal", ogr.OFTInteger)
    add_field(observations, "payload_conflict", ogr.OFTInteger)
    add_field(observations, "vervaagd", ogr.OFTInteger)
    add_field(observations, "vervagingsniveau_km", ogr.OFTInteger)
    add_field(observations, "bouwversie", ogr.OFTString, 16)

    sources = dataset.CreateLayer("ndff_bronbestanden", geom_type=ogr.wkbNone)
    for name, field_type, width in [
        ("bestand_id", ogr.OFTInteger, 0), ("bestandsnaam", ogr.OFTString, 254),
        ("sha256", ogr.OFTString, 64), ("grootte_bytes", ogr.OFTInteger64, 0),
        ("record_aantal", ogr.OFTInteger64, 0), ("aanvraag_soortgroep", ogr.OFTString, 128),
        ("bundel", ogr.OFTInteger, 0), ("deel", ogr.OFTString, 8),
        ("aanvraag_tijd", ogr.OFTString, 32), ("aanvraag_hokken", ogr.OFTString, 1024),
        ("aanvraag_hokgrootte", ogr.OFTString, 32), ("aanvraag_periode", ogr.OFTString, 32),
        ("laag", ogr.OFTString, 64), ("epsg", ogr.OFTInteger, 0),
    ]:
        add_field(sources, name, field_type, width)

    provenance = dataset.CreateLayer("ndff_waarneming_bron", geom_type=ogr.wkbNone)
    for name, field_type, width in [
        ("staging_fid", ogr.OFTInteger64, 0), ("bestand_id", ogr.OFTInteger, 0),
        ("bron_fid", ogr.OFTInteger64, 0), ("Identiteit", ogr.OFTString, 96),
        ("bron_hoknummer", ogr.OFTString, 1024),
        ("payload_sha256", ogr.OFTString, 64), ("is_eerste", ogr.OFTInteger, 0),
        ("payload_gelijk_canoniek", ogr.OFTInteger, 0),
    ]:
        add_field(provenance, name, field_type, width)

    conflicts = dataset.CreateLayer("ndff_conflicten", geom_type=ogr.wkbNone)
    for name, field_type, width in [
        ("Identiteit", ogr.OFTString, 96), ("staging_fid", ogr.OFTInteger64, 0),
        ("bestand_id", ogr.OFTInteger, 0), ("bron_fid", ogr.OFTInteger64, 0),
        ("canonieke_sha256", ogr.OFTString, 64), ("bron_sha256", ogr.OFTString, 64),
    ]:
        add_field(conflicts, name, field_type, width)

    taxa = dataset.CreateLayer("ndff_soorten", geom_type=ogr.wkbNone)
    for name, field_type, width in [
        ("soort_key", ogr.OFTString, 64), ("Soortgroep", ogr.OFTString, 128),
        ("Naam soort", ogr.OFTString, 254), ("Wetenschappelijke naam", ogr.OFTString, 254),
        ("waarneming_aantal", ogr.OFTInteger64, 0),
    ]:
        add_field(taxa, name, field_type, width)

    quality = dataset.CreateLayer("ndff_kwaliteitscontrole", geom_type=ogr.wkbNone)
    for name, field_type, width in [
        ("controle", ogr.OFTString, 128), ("waarde", ogr.OFTString, 254),
        ("status", ogr.OFTString, 16), ("toelichting", ogr.OFTString, 2048),
    ]:
        add_field(quality, name, field_type, width)

    return dataset, {
        "observations": observations, "sources": sources, "provenance": provenance,
        "conflicts": conflicts, "taxa": taxa, "quality": quality,
    }


def set_fields(feature: ogr.Feature, values: dict[str, Any]) -> None:
    for key, value in values.items():
        if value is not None:
            feature.SetField(key, value)


def add_row(layer: ogr.Layer, values: dict[str, Any]) -> int:
    feature = ogr.Feature(layer.GetLayerDefn())
    set_fields(feature, values)
    if layer.CreateFeature(feature) != ogr.OGRERR_NONE:
        raise RuntimeError(f"Kon record niet schrijven naar {layer.GetName()}")
    fid = feature.GetFID()
    feature = None
    return fid


def blur_values(raw: Any) -> tuple[int, int | None]:
    value = str(raw or "").strip()
    if not value:
        return 0, None
    match = re.search(r"(\d+)\s*km", value, re.I)
    return 1, int(match.group(1)) if match else None


def build(source_dir: Path, output_path: Path, report_path: Path, replace: bool) -> dict[str, Any]:
    sources, _schema = inspect_sources(source_dir)
    if output_path.exists() and not replace:
        raise FileExistsError(f"Uitvoer bestaat al; gebruik --replace: {output_path}")
    if report_path.exists() and not replace:
        raise FileExistsError(f"Rapport bestaat al; gebruik --replace: {report_path}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    temp_handle = tempfile.NamedTemporaryFile(
        prefix=output_path.stem + "-", suffix=".gpkg", dir=output_path.parent, delete=False
    )
    temp_path = Path(temp_handle.name)
    temp_handle.close()
    temp_path.unlink()

    ogr.UseExceptions()
    dataset: ogr.DataSource | None = None
    try:
        dataset, layers = create_output(temp_path)
        if dataset.StartTransaction() != ogr.OGRERR_NONE:
            raise RuntimeError("Kon GeoPackage-transactie niet starten")

        for source in sources:
            add_row(layers["sources"], {
                "bestand_id": source["file_id"], "bestandsnaam": source["filename"],
                "sha256": source["sha256"], "grootte_bytes": source["size_bytes"],
                "record_aantal": source["record_count"],
                "aanvraag_soortgroep": source["requested_group"], "bundel": source["bundle"],
                "deel": source["part"], "aanvraag_tijd": source["request_time"],
                "aanvraag_hokken": source["requested_cells"],
                "aanvraag_hokgrootte": source["requested_cell_size"],
                "aanvraag_periode": source["requested_period"], "laag": "waarnemingen", "epsg": 28992,
            })

        seen: dict[str, tuple[int, str, set[int], int, bool, str]] = {}
        taxa_counts: Counter[tuple[str, str, str]] = Counter()
        blur_counts: Counter[str] = Counter()
        physical_rows = 0
        conflict_rows = 0
        export_context_variations = 0

        for index, source in enumerate(sources, 1):
            source_ds = ogr.Open(str(source["path"]), 0)
            source_layer = source_ds.GetLayerByName("waarnemingen")
            if source_layer is None:
                raise RuntimeError(f"Laag waarnemingen ontbreekt in {source['filename']}")
            for source_feature in source_layer:
                physical_rows += 1
                identity = str(source_feature.GetField("Identiteit") or "").strip()
                if not identity:
                    raise RuntimeError(f"Lege Identiteit in {source['filename']} fid={source_feature.GetFID()}")
                digest = payload_sha256(source_feature)
                current = seen.get(identity)
                is_first = current is None
                if is_first:
                    output_feature = ogr.Feature(layers["observations"].GetLayerDefn())
                    for name in SOURCE_FIELDS:
                        value = source_feature.GetField(name)
                        if value is not None:
                            output_feature.SetField(name, value)
                    geometry = source_feature.GetGeometryRef()
                    if geometry is not None:
                        output_feature.SetGeometry(geometry.Clone())
                    blurred, level = blur_values(source_feature.GetField("Vervaging"))
                    set_fields(output_feature, {
                        "ontdubbel_sleutel": identity,
                        "bronbestand_eerste": source["filename"],
                        "bronbestand_aantal": 1, "bronrecord_aantal": 1,
                        "payload_conflict": 0, "vervaagd": blurred,
                        "vervagingsniveau_km": level, "bouwversie": BUILD_VERSION,
                    })
                    if layers["observations"].CreateFeature(output_feature) != ogr.OGRERR_NONE:
                        raise RuntimeError(f"Kon waarneming {identity} niet schrijven")
                    staging_fid = output_feature.GetFID()
                    output_feature = None
                    canonical_hok = str(source_feature.GetField("Hoknummer") or "")
                    seen[identity] = (
                        staging_fid, digest, {source["file_id"]}, 1, False, canonical_hok
                    )
                    taxa_counts[(
                        str(source_feature.GetField("Soortgroep") or ""),
                        str(source_feature.GetField("Naam soort") or ""),
                        str(source_feature.GetField("Wetenschappelijke naam") or ""),
                    )] += 1
                    blur_counts[str(source_feature.GetField("Vervaging") or "")] += 1
                    same_payload = 1
                else:
                    (
                        staging_fid, canonical_digest, file_ids, count,
                        had_conflict, canonical_hok,
                    ) = current
                    same_payload = int(digest == canonical_digest)
                    export_context_variations += int(
                        str(source_feature.GetField("Hoknummer") or "") != canonical_hok
                    )
                    file_ids.add(source["file_id"])
                    had_conflict = had_conflict or not same_payload
                    seen[identity] = (
                        staging_fid, canonical_digest, file_ids, count + 1,
                        had_conflict, canonical_hok,
                    )
                    if not same_payload:
                        conflict_rows += 1
                        add_row(layers["conflicts"], {
                            "Identiteit": identity, "staging_fid": staging_fid,
                            "bestand_id": source["file_id"], "bron_fid": source_feature.GetFID(),
                            "canonieke_sha256": canonical_digest, "bron_sha256": digest,
                        })

                add_row(layers["provenance"], {
                    "staging_fid": staging_fid, "bestand_id": source["file_id"],
                    "bron_fid": source_feature.GetFID(), "Identiteit": identity,
                    "bron_hoknummer": str(source_feature.GetField("Hoknummer") or ""),
                    "payload_sha256": digest, "is_eerste": int(is_first),
                    "payload_gelijk_canoniek": same_payload,
                })
            source_ds = None
            print(
                f"[{index:02d}/{len(sources)}] {source['filename']}: "
                f"{source['record_count']} bronrecords; {len(seen)} uniek",
                flush=True,
            )

        duplicate_identities = 0
        duplicate_records = 0
        conflict_identities = 0
        for identity, (
            staging_fid, _digest, file_ids, count, had_conflict, _canonical_hok
        ) in seen.items():
            if count <= 1:
                continue
            duplicate_identities += 1
            duplicate_records += count - 1
            conflict_identities += int(had_conflict)
            feature = layers["observations"].GetFeature(staging_fid)
            feature.SetField("bronbestand_aantal", len(file_ids))
            feature.SetField("bronrecord_aantal", count)
            feature.SetField("payload_conflict", int(had_conflict))
            if layers["observations"].SetFeature(feature) != ogr.OGRERR_NONE:
                raise RuntimeError(f"Kon duplicaatmetadata niet bijwerken voor {identity}")
            feature = None

        for key, count in sorted(taxa_counts.items()):
            group, common_name, scientific_name = key
            taxon_key = hashlib.sha256("\x1f".join(key).encode("utf-8")).hexdigest()
            add_row(layers["taxa"], {
                "soort_key": taxon_key, "Soortgroep": group, "Naam soort": common_name,
                "Wetenschappelijke naam": scientific_name, "waarneming_aantal": count,
            })

        checks = [
            ("bronbestanden", len(sources), "OK", "Alle geselecteerde fysieke bronbestanden"),
            ("aanvraag_soortgroepen", len(EXPECTED_REQUEST_GROUPS), "OK", "Alle 26 niet-vogelgroepen"),
            ("logische_bundels", len(EXPECTED_REQUEST_GROUPS) * 3, "OK", "Drie bundels per aanvraagsoortgroep"),
            ("fysieke_bronrecords", physical_rows, "OK", "Som van alle bronbestanden"),
            ("unieke_waarnemingen", len(seen), "OK", "Ontdubbeld op Identiteit"),
            ("verwijderde_exportoverlap", duplicate_records, "OK", "Extra fysieke voorkomens"),
            ("identiteiten_met_exportoverlap", duplicate_identities, "OK", "Identiteit in meer dan een bronrecord"),
            ("afwijkend_bron_hoknummer", export_context_variations, "OK", "Legitieme exportcontext; per bronrecord bewaard"),
            ("lege_identiteiten", 0, "OK", "Geen lege Identiteit aangetroffen"),
            ("payload_conflict_records", conflict_rows, "AANDACHT" if conflict_rows else "OK", "Zelfde Identiteit met afwijkende velden of geometrie"),
            ("payload_conflict_identiteiten", conflict_identities, "AANDACHT" if conflict_identities else "OK", "Canonieke eerste bron behouden en conflict apart geregistreerd"),
            ("epsg", 28992, "OK", "Amersfoort / RD New"),
            ("taxa", len(taxa_counts), "OK", "Unieke combinatie soortgroep, naam en wetenschappelijke naam"),
        ]
        for control, value, status, detail in checks:
            add_row(layers["quality"], {
                "controle": control, "waarde": str(value), "status": status, "toelichting": detail,
            })

        if dataset.CommitTransaction() != ogr.OGRERR_NONE:
            raise RuntimeError("Kon GeoPackage-transactie niet vastleggen")
        dataset = None

        os.replace(temp_path, output_path)
        output_sha = file_sha256(output_path)
        report = {
            "build_version": BUILD_VERSION,
            "created_utc": datetime.now(timezone.utc).isoformat(),
            "source_directory": str(source_dir),
            "source_pattern": SOURCE_PATTERN,
            "output": str(output_path),
            "output_sha256": output_sha,
            "source_files": len(sources),
            "request_groups": len(EXPECTED_REQUEST_GROUPS),
            "logical_bundles": len(EXPECTED_REQUEST_GROUPS) * 3,
            "physical_source_records": physical_rows,
            "unique_observations": len(seen),
            "removed_export_overlap": duplicate_records,
            "duplicate_identities": duplicate_identities,
            "export_context_hoknummer_variations": export_context_variations,
            "payload_conflict_records": conflict_rows,
            "payload_conflict_identities": conflict_identities,
            "taxa": len(taxa_counts),
            "blur_counts_canonical": dict(sorted(blur_counts.items())),
            "crs_epsg": 28992,
            "deduplication_key": "Identiteit",
            "canonical_rule": "Eerste bronbestand in alfabetische bestandsvolgorde; Hoknummer is exportcontext en staat per voorkomen in ndff_waarneming_bron; overige afwijkingen staan in ndff_conflicten",
            "source_file_manifest": [
                {key: value for key, value in item.items() if key not in {"path", "description"}}
                for item in sources
            ],
        }
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        return report
    except Exception:
        if dataset is not None:
            try:
                dataset.RollbackTransaction()
            except Exception:
                pass
            dataset = None
        if temp_path.exists():
            temp_path.unlink()
        raise


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--replace", action="store_true")
    parser.add_argument("--inventory-only", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.inventory_only:
        sources, schema = inspect_sources(args.source_dir)
        print(json.dumps({
            "source_files": len(sources),
            "physical_source_records": sum(item["record_count"] for item in sources),
            "request_groups": sorted({item["requested_group"] for item in sources}),
            "schema": schema,
        }, ensure_ascii=False, indent=2))
        return 0
    report_path = args.report or args.output.with_suffix(".json")
    report = build(args.source_dir, args.output, report_path, args.replace)
    summary = {key: value for key, value in report.items() if key != "source_file_manifest"}
    summary["report"] = str(report_path)
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
