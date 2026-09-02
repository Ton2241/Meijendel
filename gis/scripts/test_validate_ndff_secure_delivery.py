#!/usr/bin/env python3
"""Gerichte end-to-endtest voor validate_ndff_secure_delivery.py."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

from osgeo import gdal, ogr, osr


SCRIPT = Path(__file__).with_name("validate_ndff_secure_delivery.py")


def write_xlsx(path: Path, rows: list[list[str]]) -> None:
    cells = []
    for row_number, row in enumerate(rows, 1):
        row_cells = []
        for column_number, value in enumerate(row, 1):
            column = chr(64 + column_number)
            row_cells.append(
                f'<c r="{column}{row_number}" t="inlineStr"><is><t>{value}</t></is></c>'
            )
        cells.append(f'<row r="{row_number}">{"".join(row_cells)}</row>')
    worksheet = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        f'<sheetData>{"".join(cells)}</sheetData></worksheet>'
    )
    workbook = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="Waarnemingen" sheetId="1" r:id="rId1"/></sheets></workbook>'
    )
    relationships = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '</Relationships>'
    )
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("xl/workbook.xml", workbook)
        archive.writestr("xl/_rels/workbook.xml.rels", relationships)
        archive.writestr("xl/worksheets/sheet1.xml", worksheet)


def write_shapefile_zip(path: Path, workdir: Path) -> None:
    gdal.UseExceptions()
    shp = workdir / "waarnemingen.shp"
    driver = ogr.GetDriverByName("ESRI Shapefile")
    dataset = driver.CreateDataSource(str(shp))
    spatial_reference = osr.SpatialReference()
    spatial_reference.ImportFromEPSG(28992)
    layer = dataset.CreateLayer("waarnemingen", spatial_reference, ogr.wkbPoint)
    layer.CreateField(ogr.FieldDefn("Identiteit", ogr.OFTString))
    layer.CreateField(ogr.FieldDefn("Wetenschap", ogr.OFTString))
    for index, name in enumerate(("Taxon alpha", "Taxon beta"), 1):
        feature = ogr.Feature(layer.GetLayerDefn())
        feature.SetField("Identiteit", f"id-{index}")
        feature.SetField("Wetenschap", name)
        geometry = ogr.Geometry(ogr.wkbPoint)
        geometry.AddPoint_2D(80000 + index, 460000 + index)
        feature.SetGeometry(geometry)
        layer.CreateFeature(feature)
    dataset = None
    with zipfile.ZipFile(path, "w") as archive:
        for component in workdir.glob("waarnemingen.*"):
            archive.write(component, component.name)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="ndff secure test ") as temporary:
        root = Path(temporary)
        original = root / "original"
        original.mkdir()
        zip_path = original / "levering.zip"
        xlsx_path = original / "levering.xlsx"
        target_path = root / "doelsoorten.xlsx"
        manifest = root / "manifest.json"
        citation = root / "citatie.txt"
        write_shapefile_zip(zip_path, root)
        rows = [
            ["Identiteit", "Wetenschappelijke naam"],
            ["id-1", "Taxon alpha"],
            ["id-2", "Taxon beta"],
        ]
        write_xlsx(xlsx_path, rows)
        write_xlsx(target_path, [["wetenschappelijke_naam"], ["Taxon alpha"], ["Taxon beta"]])
        citation.write_text("Testcitatie\n", encoding="utf-8")
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--delivery-dir", str(original),
                "--manifest", str(manifest),
                "--expected-species-xlsx", str(target_path),
                "--citation-file", str(citation),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise AssertionError(result.stdout + result.stderr)
        report = json.loads(manifest.read_text(encoding="utf-8"))
        assert report["status"] == "PASS"
        assert report["shapefile_archives"][0]["layers"][0]["records"] == 2
        assert report["excel_workbooks"][0]["sheets"][0]["data_rows"] == 2
        assert report["species_check"]["unexpected_count"] == 0

        unsafe_original = root / "unsafe_original"
        unsafe_original.mkdir()
        unsafe_zip = unsafe_original / "onveilig.zip"
        with zipfile.ZipFile(unsafe_zip, "w") as archive:
            archive.writestr("../buiten_map.txt", "niet uitpakken")
        write_xlsx(unsafe_original / "levering.xlsx", rows)
        unsafe_manifest = root / "unsafe_manifest.json"
        unsafe_result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--delivery-dir", str(unsafe_original),
                "--manifest", str(unsafe_manifest),
                "--expected-species-xlsx", str(target_path),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        assert unsafe_result.returncode == 1
        unsafe_report = json.loads(unsafe_manifest.read_text(encoding="utf-8"))
        assert unsafe_report["status"] == "FAIL"
        assert "unsafe_zip_path" in {issue["code"] for issue in unsafe_report["issues"]}
    print("OK: beveiligde NDFF-ontvangstvalidatie")
    return 0


if __name__ == "__main__":
    sys.exit(main())
