#!/usr/bin/env python3
"""Valideer een beveiligde NDFF-levering zonder bronbestanden te wijzigen.

Het script schrijft uitsluitend een JSON-ontvangstmanifest. Het pakt de ZIP niet
uit en neemt geen waarnemingswaarden of geometrieën in het manifest op.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any
from xml.etree import ElementTree as ET

from osgeo import ogr


VERSION = "1.0"
XLSX_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
EXPECTED_CELLS = [
    "79-459", "80-458", "80-459", "80-460", "81-458", "81-459",
    "81-460", "81-461", "82-458", "82-459", "82-460", "82-461",
    "82-462", "82-463", "83-458", "83-459", "83-460", "83-461",
    "83-462", "83-463", "83-464", "84-459", "84-460", "84-461",
    "84-462", "84-463", "84-464", "85-460", "85-461", "85-462",
    "85-463", "85-464", "86-461", "86-463",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalized(value: str | None) -> str:
    return re.sub(r"[^a-z0-9]", "", (value or "").casefold())


def column_index(reference: str) -> int:
    letters = re.match(r"[A-Z]+", reference.upper())
    if not letters:
        return 0
    result = 0
    for char in letters.group(0):
        result = result * 26 + ord(char) - 64
    return result - 1


def xlsx_cell_value(cell: ET.Element, shared: list[str]) -> str:
    cell_type = cell.get("t", "")
    if cell_type == "inlineStr":
        inline = cell.find(f"{{{XLSX_NS}}}is")
        return "" if inline is None else "".join(inline.itertext())
    value = cell.find(f"{{{XLSX_NS}}}v")
    if value is None or value.text is None:
        return ""
    if cell_type == "s":
        try:
            return shared[int(value.text)]
        except (ValueError, IndexError):
            return value.text
    return value.text


def inspect_xlsx(path: Path) -> dict[str, Any]:
    with zipfile.ZipFile(path) as workbook:
        names = set(workbook.namelist())
        if "xl/workbook.xml" not in names:
            raise ValueError(f"Geen geldige XLSX-werkmap: {path.name}")

        shared: list[str] = []
        if "xl/sharedStrings.xml" in names:
            root = ET.fromstring(workbook.read("xl/sharedStrings.xml"))
            shared = ["".join(item.itertext()) for item in root]

        workbook_root = ET.fromstring(workbook.read("xl/workbook.xml"))
        relationships: dict[str, str] = {}
        rel_path = "xl/_rels/workbook.xml.rels"
        if rel_path in names:
            rel_root = ET.fromstring(workbook.read(rel_path))
            for rel in rel_root:
                target = rel.get("Target", "")
                relationships[rel.get("Id", "")] = (
                    target.lstrip("/") if target.startswith("/") else "xl/" + target
                )

        sheets: list[dict[str, Any]] = []
        for sheet in workbook_root.findall(f".//{{{XLSX_NS}}}sheet"):
            relationship_id = sheet.get(f"{{{REL_NS}}}id", "")
            target = relationships.get(relationship_id)
            if not target or target not in names:
                continue
            root = ET.fromstring(workbook.read(target))
            rows: list[tuple[int, list[str]]] = []
            for row in root.findall(f".//{{{XLSX_NS}}}row"):
                values: list[str] = []
                for cell in row.findall(f"{{{XLSX_NS}}}c"):
                    index = column_index(cell.get("r", "A1"))
                    while len(values) <= index:
                        values.append("")
                    values[index] = xlsx_cell_value(cell, shared).strip()
                if any(values):
                    rows.append((int(row.get("r", len(rows) + 1)), values))

            header_index: int | None = None
            headers: list[str] = []
            markers = {
                "identiteit", "ndffidentity", "wetenschappelijkenaam",
                "nederlandsenaam", "naamsoort",
            }
            for index, (_, row) in enumerate(rows):
                if markers.intersection(normalized(value) for value in row):
                    header_index = index
                    headers = row
                    break
            data_rows = 0 if header_index is None else sum(
                1 for _, row in rows[header_index + 1 :] if any(row)
            )
            sheets.append(
                {
                    "name": sheet.get("name", ""),
                    "nonempty_rows": len(rows),
                    "header_row": None if header_index is None else rows[header_index][0],
                    "headers": headers,
                    "data_rows": data_rows,
                }
            )
        return {"filename": path.name, "sheets": sheets}


def xlsx_scientific_names(path: Path) -> set[str]:
    result: set[str] = set()
    with zipfile.ZipFile(path) as workbook:
        names = set(workbook.namelist())
        shared: list[str] = []
        if "xl/sharedStrings.xml" in names:
            root = ET.fromstring(workbook.read("xl/sharedStrings.xml"))
            shared = ["".join(item.itertext()) for item in root]
        for filename in sorted(name for name in names if name.startswith("xl/worksheets/sheet") and name.endswith(".xml")):
            root = ET.fromstring(workbook.read(filename))
            rows: list[list[str]] = []
            for row in root.findall(f".//{{{XLSX_NS}}}row"):
                values: list[str] = []
                for cell in row.findall(f"{{{XLSX_NS}}}c"):
                    index = column_index(cell.get("r", "A1"))
                    while len(values) <= index:
                        values.append("")
                    values[index] = xlsx_cell_value(cell, shared).strip()
                rows.append(values)
            for header_index, row in enumerate(rows):
                normalized_headers = [normalized(value) for value in row]
                candidates = {"wetenschappelijkenaam", "scientificname", "scientific"}
                matches = [i for i, value in enumerate(normalized_headers) if value in candidates]
                if not matches:
                    continue
                column = matches[0]
                for data_row in rows[header_index + 1 :]:
                    if column < len(data_row) and data_row[column]:
                        result.add(data_row[column].casefold().strip())
                break
    return result


def inspect_shapefile_zip(path: Path, expected_crs: int) -> tuple[dict[str, Any], list[dict[str, str]], set[str]]:
    issues: list[dict[str, str]] = []
    scientific_names: set[str] = set()
    with zipfile.ZipFile(path) as archive:
        members = [name for name in archive.namelist() if not name.endswith("/")]
        unsafe = [
            name for name in members
            if PurePosixPath(name).is_absolute() or ".." in PurePosixPath(name).parts
        ]
        if unsafe:
            issues.append({"level": "error", "code": "unsafe_zip_path", "detail": f"{len(unsafe)} onveilige ZIP-paden"})

        by_stem: dict[str, set[str]] = {}
        for name in members:
            suffix = PurePosixPath(name).suffix.casefold()
            if suffix in {".shp", ".shx", ".dbf", ".prj", ".cpg"}:
                stem = str(PurePosixPath(name).with_suffix(""))
                by_stem.setdefault(stem, set()).add(suffix)
        shapefiles = [stem for stem, suffixes in by_stem.items() if ".shp" in suffixes]
        if not shapefiles:
            issues.append({"level": "error", "code": "missing_shapefile", "detail": "Geen .shp in ZIP"})
        for stem in shapefiles:
            missing = {".shp", ".shx", ".dbf", ".prj"} - by_stem[stem]
            if missing:
                issues.append({"level": "error", "code": "incomplete_shapefile", "detail": f"{stem}: ontbreekt {sorted(missing)}"})

    if any(issue["level"] == "error" for issue in issues):
        return {"filename": path.name, "members": len(members), "layers": []}, issues, scientific_names

    ogr.UseExceptions()
    dataset = ogr.Open(f"/vsizip/{path.resolve()}", 0)
    layers: list[dict[str, Any]] = []
    if dataset is None:
        issues.append({"level": "error", "code": "ogr_open_failed", "detail": "GDAL kan ZIP niet openen"})
        return {"filename": path.name, "members": len(members), "layers": layers}, issues, scientific_names

    for layer_index in range(dataset.GetLayerCount()):
        layer = dataset.GetLayerByIndex(layer_index)
        definition = layer.GetLayerDefn()
        fields = [definition.GetFieldDefn(i).GetName() for i in range(definition.GetFieldCount())]
        field_lookup = {normalized(name): name for name in fields}
        identity_field = next((field_lookup[key] for key in ("identiteit", "ndffidentity") if key in field_lookup), None)
        scientific_field = next(
            (
                original
                for key, original in field_lookup.items()
                if key.startswith("wetensch") or key in {"scientific", "scientificname"}
            ),
            None,
        )
        srs = layer.GetSpatialRef()
        authority = None
        if srs is not None:
            try:
                srs.AutoIdentifyEPSG()
            except RuntimeError:
                pass
            authority = srs.GetAuthorityCode(None) or srs.GetAuthorityCode("PROJCS")
        if str(authority or "") != str(expected_crs):
            issues.append({"level": "error", "code": "unexpected_crs", "detail": f"Laag {layer.GetName()}: {authority!r}, verwacht {expected_crs}"})
        if identity_field is None:
            issues.append({"level": "error", "code": "missing_identity", "detail": f"Laag {layer.GetName()}: geen Identiteit"})

        empty = invalid = null_identity = duplicate_identity = 0
        identities: set[str] = set()
        for feature in layer:
            geometry = feature.GetGeometryRef()
            if geometry is None or geometry.IsEmpty():
                empty += 1
            elif not geometry.IsValid():
                invalid += 1
            if identity_field:
                identity = str(feature.GetField(identity_field) or "").strip()
                if not identity:
                    null_identity += 1
                elif identity in identities:
                    duplicate_identity += 1
                else:
                    identities.add(identity)
            if scientific_field:
                value = str(feature.GetField(scientific_field) or "").casefold().strip()
                if value:
                    scientific_names.add(value)
        if empty:
            issues.append({"level": "error", "code": "empty_geometry", "detail": f"Laag {layer.GetName()}: {empty}"})
        if invalid:
            issues.append({"level": "error", "code": "invalid_geometry", "detail": f"Laag {layer.GetName()}: {invalid}"})
        if null_identity:
            issues.append({"level": "error", "code": "null_identity", "detail": f"Laag {layer.GetName()}: {null_identity}"})
        if duplicate_identity:
            issues.append({"level": "error", "code": "duplicate_identity", "detail": f"Laag {layer.GetName()}: {duplicate_identity}"})
        layers.append(
            {
                "name": layer.GetName(),
                "records": layer.GetFeatureCount(),
                "geometry_type": ogr.GeometryTypeToName(definition.GetGeomType()),
                "crs_authority": authority,
                "fields": fields,
                "identity_field": identity_field,
                "scientific_name_field": scientific_field,
                "empty_geometries": empty,
                "invalid_geometries": invalid,
                "null_identities": null_identity,
                "duplicate_identities": duplicate_identity,
            }
        )
    dataset = None
    return {"filename": path.name, "members": len(members), "layers": layers}, issues, scientific_names


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--delivery-dir", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--expected-species-xlsx", type=Path)
    parser.add_argument("--citation-file", type=Path)
    parser.add_argument("--expected-crs", type=int, default=28992)
    parser.add_argument("--ticket", default="58679")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    issues: list[dict[str, str]] = []
    delivery_dir = args.delivery_dir.resolve()
    if "Downloads" in delivery_dir.parts:
        issues.append({"level": "error", "code": "temporary_storage", "detail": "Levering staat nog in Downloads"})
    if not delivery_dir.is_dir():
        raise SystemExit(f"Leveringsmap bestaat niet: {delivery_dir}")

    files = sorted(path for path in delivery_dir.iterdir() if path.is_file() and not path.name.startswith("."))
    zip_files = [path for path in files if path.suffix.casefold() == ".zip"]
    xlsx_files = [path for path in files if path.suffix.casefold() == ".xlsx"]
    if not zip_files:
        issues.append({"level": "error", "code": "missing_zip", "detail": "Geen gezipte shapefile ontvangen"})
    if not xlsx_files:
        issues.append({"level": "error", "code": "missing_xlsx", "detail": "Geen Excel ontvangen"})
    if len(zip_files) > 1:
        issues.append({"level": "warning", "code": "multiple_zip", "detail": f"{len(zip_files)} ZIP-bestanden"})
    if len(xlsx_files) > 1:
        issues.append({"level": "warning", "code": "multiple_xlsx", "detail": f"{len(xlsx_files)} Excelbestanden"})

    zip_reports: list[dict[str, Any]] = []
    delivered_scientific: set[str] = set()
    for path in zip_files:
        try:
            report, zip_issues, names = inspect_shapefile_zip(path, args.expected_crs)
            zip_reports.append(report)
            issues.extend(zip_issues)
            delivered_scientific.update(names)
        except (RuntimeError, zipfile.BadZipFile) as exc:
            issues.append({"level": "error", "code": "invalid_zip", "detail": f"{path.name}: {exc}"})

    xlsx_reports: list[dict[str, Any]] = []
    for path in xlsx_files:
        try:
            xlsx_reports.append(inspect_xlsx(path))
            delivered_scientific.update(xlsx_scientific_names(path))
        except (ValueError, zipfile.BadZipFile, ET.ParseError) as exc:
            issues.append({"level": "error", "code": "invalid_xlsx", "detail": f"{path.name}: {exc}"})

    expected_species: set[str] = set()
    if args.expected_species_xlsx:
        if not args.expected_species_xlsx.is_file():
            issues.append({"level": "error", "code": "missing_target_list", "detail": str(args.expected_species_xlsx)})
        else:
            expected_species = xlsx_scientific_names(args.expected_species_xlsx)
            if not expected_species:
                issues.append({"level": "error", "code": "empty_target_list", "detail": "Geen wetenschappelijke namen gevonden"})

    unexpected_species = delivered_scientific - expected_species if expected_species else set()
    if unexpected_species:
        issues.append({"level": "error", "code": "unexpected_species", "detail": f"{len(unexpected_species)} taxa buiten doelsoortenlijst"})
    if expected_species and not delivered_scientific:
        issues.append({"level": "warning", "code": "species_fields_not_detected", "detail": "Geen herkenbare wetenschappelijke-naamkolom in levering"})

    citation_report: dict[str, Any] | None = None
    if args.citation_file:
        if args.citation_file.is_file():
            citation_report = {"filename": args.citation_file.name, "sha256": sha256(args.citation_file)}
        else:
            issues.append({"level": "warning", "code": "missing_citation", "detail": str(args.citation_file)})
    else:
        issues.append({"level": "warning", "code": "citation_not_supplied", "detail": "Leg standaardcitatie voor gebruik vast"})

    manifest = {
        "manifest_version": VERSION,
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "status": "FAIL" if any(issue["level"] == "error" for issue in issues) else "PASS",
        "scope": {
            "ticket": args.ticket,
            "period_start": 1950,
            "period_end": 2025,
            "birds_requested": False,
            "expected_crs": args.expected_crs,
            "expected_grid_cells": EXPECTED_CELLS,
        },
        "files": [
            {"filename": path.name, "size_bytes": path.stat().st_size, "sha256": sha256(path)}
            for path in files
        ],
        "shapefile_archives": zip_reports,
        "excel_workbooks": xlsx_reports,
        "species_check": {
            "expected_scientific_names": len(expected_species),
            "delivered_scientific_names_detected": len(delivered_scientific),
            "unexpected_count": len(unexpected_species),
        },
        "citation": citation_report,
        "issues": issues,
    }
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{manifest['status']}: {len(files)} bestanden; {len(issues)} aandachtspunten")
    return 1 if manifest["status"] == "FAIL" else 0


if __name__ == "__main__":
    sys.exit(main())
