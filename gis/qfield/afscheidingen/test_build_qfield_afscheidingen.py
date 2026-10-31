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
DOWNLOADER = HERE / "download_pdok_luchtfoto.sh"
GUIDE = HERE / "README.md"
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

    def test_processing_builder_refuses_to_overwrite_existing_fieldwork(self):
        with tempfile.TemporaryDirectory() as tmp:
            output_dir = Path(tmp) / "pakket"
            command = [
                str(QGIS_PROCESS),
                "run",
                str(BUILDER),
                "--",
                f"PLOTS={PLOTS}",
                f"OUTPUT_DIR={output_dir}",
                "RASTER=",
            ]
            environment = {
                **os.environ,
                "QGIS_PREFIX_PATH": "/Applications/QGIS.app",
            }
            first = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
                env=environment,
            )
            self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
            feature_path = Path(tmp) / "testlijn.geojson"
            feature_path.write_text(
                json.dumps(
                    {
                        "type": "FeatureCollection",
                        "name": "afscheidingen",
                        "crs": {
                            "type": "name",
                            "properties": {"name": "urn:ogc:def:crs:EPSG::28992"},
                        },
                        "features": [
                            {
                                "type": "Feature",
                                "properties": {"id": "test-id", "type": "hek"},
                                "geometry": {
                                    "type": "LineString",
                                    "coordinates": [[82000, 461000], [82010, 461010]],
                                },
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            subprocess.run(
                [
                    "ogr2ogr",
                    "-update",
                    "-append",
                    "-nln",
                    "afscheidingen",
                    str(output_dir / "veldwerk.gpkg"),
                    str(feature_path),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            second = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
                env=environment,
            )
            with sqlite3.connect(output_dir / "veldwerk.gpkg") as connection:
                count = connection.execute(
                    "SELECT COUNT(*) FROM afscheidingen"
                ).fetchone()[0]
        combined = second.stdout + second.stderr
        self.assertNotEqual(second.returncode, 0, combined)
        self.assertIn("bestaande veldwerkgegevens", combined)
        self.assertEqual(count, 1)

    def test_processing_builder_writes_portable_paths_for_relative_output_dir(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            relative_output = Path("nested") / "meijendel_afscheidingen"
            result = subprocess.run(
                [
                    str(QGIS_PROCESS),
                    "run",
                    str(BUILDER),
                    "--",
                    f"PLOTS={PLOTS}",
                    f"OUTPUT_DIR={relative_output}",
                    "RASTER=",
                ],
                cwd=tmp_path,
                check=False,
                capture_output=True,
                text=True,
                env={**os.environ, "QGIS_PREFIX_PATH": "/Applications/QGIS.app"},
            )
            combined = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, combined)
            project = relative_output / "meijendel_afscheidingen.qgz"
            with zipfile.ZipFile(tmp_path / project) as archive:
                qgs = next(name for name in archive.namelist() if name.endswith(".qgs"))
                xml = archive.read(qgs).decode("utf-8")

        self.assertNotIn("nested/meijendel_afscheidingen/", xml)
        self.assertIn(
            "<datasource>./veldwerk.gpkg|layername=afscheidingen</datasource>", xml
        )
        self.assertIn(
            "<datasource>./veldwerk.gpkg|layername=bijzonderheden</datasource>", xml
        )
        self.assertIn(
            "<datasource>./referentie.gpkg|layername=onderzoekskavels</datasource>", xml
        )


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


class RasterPackageContractTest(unittest.TestCase):
    def test_download_script_pins_final_2025_25cm_layer(self):
        script = DOWNLOADER.read_text(encoding="utf-8")
        self.assertIn("WMTS:https://service.pdok.nl", script)
        self.assertIn("layer=2025_ortho25", script)
        self.assertNotIn("Actueel_ortho25", script)
        self.assertIn("tilematrixset=EPSG:28992", script)
        self.assertIn("zoom_level=14", script)
        self.assertIn("-b 1", script)
        self.assertIn("-b 2", script)
        self.assertIn("-b 3", script)
        self.assertIn("GDAL_HTTP_MAX_RETRY 10", script)
        self.assertIn("GDAL_HTTP_RETRY_CODES 500,502,503,504", script)
        self.assertIn("GDAL_DEFAULT_WMS_CACHE_PATH", script)
        self.assertIn("NUM_THREADS=1", script)
        self.assertNotIn("NUM_THREADS=ALL_CPUS", script)
        self.assertIn("RAW_RASTER=", script)
        self.assertIn("gdaladdo", script)
        self.assertIn("OVERVIEWS=FORCE_USE_EXISTING", script)
        self.assertIn("download_base_raster()", script)
        self.assertIn("for ATTEMPT in 1 2 3 4 5", script)
        self.assertLess(script.index("RAW_RASTER="), script.index("gdaladdo"))
        self.assertLess(script.index("gdaladdo"), script.index("OVERVIEWS=FORCE_USE_EXISTING"))

    def test_builder_adds_local_raster_with_relative_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            raster = tmp_path / "luchtfoto_pdok_2025_25cm.tif"
            subprocess.run(
                [
                    "gdal_create",
                    "-of",
                    "GTiff",
                    "-a_srs",
                    "EPSG:28992",
                    "-a_ullr",
                    "79497",
                    "464492",
                    "86575",
                    "458256",
                    "-outsize",
                    "64",
                    "64",
                    "-bands",
                    "3",
                    str(raster),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            output_dir = tmp_path / "pakket"
            result = subprocess.run(
                [
                    str(QGIS_PROCESS),
                    "run",
                    str(BUILDER),
                    "--",
                    f"PLOTS={PLOTS}",
                    f"OUTPUT_DIR={output_dir}",
                    f"RASTER={raster}",
                ],
                check=False,
                capture_output=True,
                text=True,
                env={**os.environ, "QGIS_PREFIX_PATH": "/Applications/QGIS.app"},
            )
            combined = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, combined)
            project = output_dir / "meijendel_afscheidingen.qgz"
            with zipfile.ZipFile(project) as archive:
                qgs = next(name for name in archive.namelist() if name.endswith(".qgs"))
                xml = archive.read(qgs).decode("utf-8")
            self.assertIn("luchtfoto_pdok_2025_25cm.tif", xml)
            self.assertNotIn("service.pdok.nl", xml)
            self.assertNotIn(str(tmp_path), xml)


@unittest.skipUnless(
    os.environ.get("QFIELD_PACKAGE_DIR"),
    "alleen voor de daadwerkelijk gedownloade offline luchtfoto",
)
class ActualRasterContractTest(unittest.TestCase):
    def test_actual_aerial_is_complete_cog_in_rd(self):
        package_dir = Path(os.environ["QFIELD_PACKAGE_DIR"])
        raster = package_dir / "luchtfoto_pdok_2025_25cm.tif"
        manifest = json.loads(
            (package_dir / "pakket_manifest.json").read_text(encoding="utf-8")
        )
        result = subprocess.run(
            ["gdalinfo", "-json", str(raster)],
            check=True,
            capture_output=True,
            text=True,
        )
        info = json.loads(result.stdout)
        self.assertEqual(len(info["bands"]), 3)
        self.assertGreater(info["size"][0], 0)
        self.assertGreater(info["size"][1], 0)
        self.assertEqual(info["stac"]["proj:epsg"], 28992)
        self.assertAlmostEqual(info["geoTransform"][1], 0.25, places=6)
        self.assertAlmostEqual(info["geoTransform"][5], -0.25, places=6)
        self.assertEqual(info["metadata"]["IMAGE_STRUCTURE"]["LAYOUT"], "COG")
        xmin, ymin, xmax, ymax = manifest["bbox_rd_buffered"]
        upper_left = info["cornerCoordinates"]["upperLeft"]
        lower_right = info["cornerCoordinates"]["lowerRight"]
        self.assertLessEqual(upper_left[0], xmin)
        self.assertGreaterEqual(upper_left[1], ymax)
        self.assertGreaterEqual(lower_right[0], xmax)
        self.assertLessEqual(lower_right[1], ymin)


class FieldGuideContractTest(unittest.TestCase):
    def test_guide_covers_transfer_gns_offline_trial_and_return(self):
        guide = GUIDE.read_text(encoding="utf-8")
        required = (
            "outputs/qfield_afscheidingen/meijendel_afscheidingen",
            "AirDrop",
            "QFieldCloud",
            "GNS 3000",
            "iPadOS",
            "vliegtuigmodus",
            "punt",
            "lijn",
            "foto",
            "offset_m",
            "terugkopiëren",
            "iMac",
        )
        for phrase in required:
            self.assertIn(phrase, guide)


if __name__ == "__main__":
    unittest.main()
