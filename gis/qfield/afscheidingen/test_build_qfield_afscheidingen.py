#!/usr/bin/env python3
"""Contracttests voor het offline QField-pakket Afscheidingen."""

from __future__ import annotations

import importlib.util
import json
import os
import sqlite3
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BUILDER = HERE / "build_qfield_afscheidingen.py"
QGIS_PROCESS = Path("/Applications/QGIS.app/Contents/MacOS/qgis_process")
PLOTS = ROOT / "Plots_2025" / "avimap_252_diversen__gebieden.shp"


def load_builder():
    spec = importlib.util.spec_from_file_location("build_qfield_afscheidingen", BUILDER)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Kan builder niet laden: {BUILDER}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class BuilderContractTest(unittest.TestCase):
    def test_plot_label_preserves_simple_and_compound_plot_numbers(self):
        builder = load_builder()
        cases = {
            "Meijendel k 17a": "M17a",
            "Meijendel k 4-5": "M4-5",
            "Meijendel k 10-12-76": "M10-12-76",
            "Meijendel k 78/79": "M78/79",
        }
        self.assertEqual(
            {source: builder.plot_label(source) for source in cases},
            cases,
        )

    def test_processing_builder_rejects_plot_source_with_wrong_feature_count(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            invalid = tmp_path / "plots_onvolledig.gpkg"
            subprocess.run(
                [
                    "ogr2ogr",
                    "-f",
                    "GPKG",
                    str(invalid),
                    str(PLOTS),
                    "-limit",
                    "1",
                    "-nln",
                    "plots",
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            result = subprocess.run(
                [
                    str(QGIS_PROCESS),
                    "run",
                    str(BUILDER),
                    "--",
                    f"PLOTS={invalid}|layername=plots",
                    f"OUTPUT_DIR={tmp_path / 'pakket'}",
                    "RASTER=",
                ],
                check=False,
                capture_output=True,
                text=True,
                env={**os.environ, "QGIS_PREFIX_PATH": "/Applications/QGIS.app"},
            )
        combined = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0, combined)
        self.assertIn("precies 55 polygonen", combined)


class VectorPackageContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._tmp = tempfile.TemporaryDirectory()
        cls.output_dir = Path(cls._tmp.name) / "meijendel_afscheidingen"
        cls.result = subprocess.run(
            [
                str(QGIS_PROCESS),
                "run",
                str(BUILDER),
                "--",
                f"PLOTS={PLOTS}",
                f"OUTPUT_DIR={cls.output_dir}",
                "RASTER=",
            ],
            check=False,
            capture_output=True,
            text=True,
            env={**os.environ, "QGIS_PREFIX_PATH": "/Applications/QGIS.app"},
        )

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    def test_builder_creates_expected_package_files(self):
        combined = self.result.stdout + self.result.stderr
        self.assertEqual(self.result.returncode, 0, combined)
        for relative in (
            "referentie.gpkg",
            "veldwerk.gpkg",
            "meijendel_afscheidingen.qgz",
            "photos",
        ):
            self.assertTrue((self.output_dir / relative).exists(), relative)

    def _ogr_layer_info(self, dataset: Path, layer: str) -> dict:
        result = subprocess.run(
            ["ogrinfo", "-json", "-so", str(dataset), layer],
            check=True,
            capture_output=True,
            text=True,
        )
        return json.loads(result.stdout)["layers"][0]

    def test_reference_layer_contains_all_plots_in_rd(self):
        info = self._ogr_layer_info(
            self.output_dir / "referentie.gpkg", "onderzoekskavels"
        )
        self.assertEqual(info["featureCount"], 55)
        self.assertIn("Polygon", info["geometryFields"][0]["type"])
        self.assertEqual(
            info["geometryFields"][0]["coordinateSystem"]["projjson"]["id"]["code"],
            28992,
        )

    def test_field_layers_are_empty_and_have_the_agreed_fields(self):
        expected = {
            "afscheidingen": [
                "id",
                "type",
                "materiaal",
                "datum_tijd",
                "bron",
                "ontvanger",
                "nauwkeurigheid_m",
                "offset_m",
                "foto",
                "opmerking",
            ],
            "bijzonderheden": [
                "id",
                "afscheiding_id",
                "soort",
                "datum_tijd",
                "bron",
                "ontvanger",
                "nauwkeurigheid_m",
                "offset_m",
                "foto",
                "opmerking",
            ],
        }
        for layer, fields in expected.items():
            info = self._ogr_layer_info(self.output_dir / "veldwerk.gpkg", layer)
            self.assertEqual(info["featureCount"], 0, layer)
            self.assertEqual([field["name"] for field in info["fields"]], fields)

    def test_project_is_relative_read_only_for_plots_and_contains_form_contract(self):
        project = self.output_dir / "meijendel_afscheidingen.qgz"
        with zipfile.ZipFile(project) as archive:
            qgs_names = [name for name in archive.namelist() if name.endswith(".qgs")]
            self.assertEqual(len(qgs_names), 1)
            xml = archive.read(qgs_names[0]).decode("utf-8")
        self.assertNotIn("/Users/ton/", xml)
        self.assertIn("referentie.gpkg|layername=onderzoekskavels", xml)
        self.assertIn("veldwerk.gpkg|layername=afscheidingen", xml)
        self.assertIn("veldwerk.gpkg|layername=bijzonderheden", xml)
        self.assertIn("readOnly=\"1\"", xml)
        self.assertIn("uuid()", xml)
        self.assertIn("@position_horizontal_accuracy", xml)
        self.assertIn("GNS 3000 via iPadOS", xml)
        for choice in (
            "hek",
            "raster",
            "sloot",
            "wal",
            "haag",
            "poort/doorgang",
            "onderbreking",
            "typewijziging",
        ):
            self.assertIn(choice, xml)
        self.assertIn("EPSG:28992", xml)

    def test_field_database_has_uuid_defaults_and_no_fixed_plot_column(self):
        with sqlite3.connect(self.output_dir / "veldwerk.gpkg") as connection:
            for layer in ("afscheidingen", "bijzonderheden"):
                columns = {
                    row[1]: row[4]
                    for row in connection.execute(f'PRAGMA table_info("{layer}")')
                }
                self.assertNotIn("kavel", columns)
                self.assertNotIn("plot", columns)
                self.assertIn("id", columns)


if __name__ == "__main__":
    unittest.main()
