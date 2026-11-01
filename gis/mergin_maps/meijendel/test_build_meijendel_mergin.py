#!/usr/bin/env python3
"""Contracttests voor het offline Mergin Maps-project Meijendel."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import unittest
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BUILDER = HERE / "build_meijendel_mergin.py"
QGIS_PROCESS = Path("/Applications/QGIS.app/Contents/MacOS/qgis_process")
PLOTS = ROOT / "Plots_2025" / "avimap_252_diversen__gebieden.shp"
COLORS = [
    "#25a244",
    "#f4a261",
    "#d62828",
    "#8b5a2b",
    "#277da1",
    "#111111",
    "#ffffff",
]


def run_builder(output_dir: Path, raster: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            str(QGIS_PROCESS),
            "run",
            str(BUILDER),
            "--",
            f"PLOTS={PLOTS}",
            f"OUTPUT_DIR={output_dir}",
            f"RASTER={raster or ''}",
        ],
        check=False,
        capture_output=True,
        text=True,
        env={**os.environ, "QGIS_PREFIX_PATH": "/Applications/QGIS.app"},
    )


def project_xml(project: Path) -> str:
    with zipfile.ZipFile(project) as archive:
        qgs = [name for name in archive.namelist() if name.endswith(".qgs")]
        if len(qgs) != 1:
            raise AssertionError(f"Verwacht precies een .qgs in {project}: {qgs}")
        return archive.read(qgs[0]).decode("utf-8")


def layer_info(dataset: Path, layer: str) -> dict:
    result = subprocess.run(
        ["ogrinfo", "-json", "-so", str(dataset), layer],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)["layers"][0]


class MerginPackageContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._tmp = tempfile.TemporaryDirectory()
        cls.output_dir = Path(cls._tmp.name) / "meijendel"
        cls.result = run_builder(cls.output_dir)

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    def test_builder_creates_separate_mergin_project(self):
        combined = self.result.stdout + self.result.stderr
        self.assertEqual(self.result.returncode, 0, combined)
        for relative in (
            "meijendel.qgz",
            "referentie.gpkg",
            "veldwerk.gpkg",
            "map_sketches.gpkg",
            "tracking_layer.gpkg",
            "photos",
        ):
            self.assertTrue((self.output_dir / relative).exists(), relative)

        expected = (
            ("referentie.gpkg", "onderzoekskavels", 55, "Polygon"),
            ("veldwerk.gpkg", "afscheidingen", 0, "LineString"),
            ("veldwerk.gpkg", "bijzonderheden", 0, "Point"),
            ("veldwerk.gpkg", "gebieden", 0, "Polygon"),
            ("map_sketches.gpkg", "Map sketches", 0, "MultiLineStringZM"),
            ("tracking_layer.gpkg", "tracking_layer", 0, "LineStringZM"),
        )
        for filename, layer, count, geometry in expected:
            info = layer_info(self.output_dir / filename, layer)
            self.assertEqual(info["featureCount"], count, layer)
            self.assertIn(geometry, info["geometryFields"][0]["type"], layer)

    def test_project_contains_live_mergin_layer_ids_settings_and_relative_paths(self):
        combined = self.result.stdout + self.result.stderr
        self.assertEqual(self.result.returncode, 0, combined)
        xml = project_xml(self.output_dir / "meijendel.qgz")
        root = ET.fromstring(xml)

        self.assertNotIn("/Users/ton/", xml)
        self.assertIn("./map_sketches.gpkg", xml)
        self.assertIn("./tracking_layer.gpkg", xml)
        layers = {
            layer.findtext("layername"): layer.findtext("id")
            for layer in root.findall(".//projectlayers/maplayer")
        }
        properties = root.find("./properties/Mergin")
        self.assertIsNotNone(properties)
        self.assertEqual(properties.findtext("./MapSketching/Enabled"), "1")
        self.assertEqual(
            properties.findtext("./MapSketching/Layer"), layers["Map sketches"]
        )
        self.assertEqual(
            [value.text for value in properties.findall("./MapSketching/Colors/value")],
            COLORS,
        )
        self.assertEqual(properties.findtext("./PositionTracking/Enabled"), "1")
        self.assertEqual(
            properties.findtext("./PositionTracking/TrackingLayer"),
            layers["tracking_layer"],
        )
        self.assertEqual(properties.findtext("./PositionTracking/UpdateFrequency"), "1")
        self.assertEqual(properties.findtext("./SortLayersMethod/Method"), "0")


class RebuildProtectionContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._tmp = tempfile.TemporaryDirectory()
        cls.pristine = Path(cls._tmp.name) / "pristine"
        result = run_builder(cls.pristine)
        if result.returncode != 0:
            raise AssertionError(result.stdout + result.stderr)

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    def _copy_pristine(self, name: str) -> Path:
        destination = Path(self._tmp.name) / name
        shutil.copytree(self.pristine, destination)
        return destination

    def _assert_rebuild_refused(self, package: Path) -> None:
        result = run_builder(package)
        combined = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0, combined)
        self.assertIn("bestaande veldwerkgegevens", combined)

    def _append_feature(
        self,
        package: Path,
        filename: str,
        layer: str,
        crs: str,
        geometry: dict,
        properties: dict,
    ) -> None:
        source = package / f"test-{layer.replace(' ', '-')}.geojson"
        source.write_text(
            json.dumps(
                {
                    "type": "FeatureCollection",
                    "crs": {
                        "type": "name",
                        "properties": {"name": f"urn:ogc:def:crs:{crs}"},
                    },
                    "features": [
                        {
                            "type": "Feature",
                            "properties": properties,
                            "geometry": geometry,
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
                layer,
                str(package / filename),
                str(source),
            ],
            check=True,
            capture_output=True,
            text=True,
        )

    def test_rebuild_refuses_records_in_every_editable_layer(self):
        cases = (
            (
                "afscheidingen",
                "veldwerk.gpkg",
                "afscheidingen",
                "EPSG::28992",
                {"type": "LineString", "coordinates": [[82000, 461000], [82010, 461010]]},
                {"id": "test"},
            ),
            (
                "bijzonderheden",
                "veldwerk.gpkg",
                "bijzonderheden",
                "EPSG::28992",
                {"type": "Point", "coordinates": [82000, 461000]},
                {"id": "test"},
            ),
            (
                "gebieden",
                "veldwerk.gpkg",
                "gebieden",
                "EPSG::28992",
                {
                    "type": "Polygon",
                    "coordinates": [[[82000, 461000], [82010, 461000], [82010, 461010], [82000, 461000]]],
                },
                {"id": "test"},
            ),
            (
                "schetsen",
                "map_sketches.gpkg",
                "Map sketches",
                "EPSG::4326",
                {"type": "MultiLineString", "coordinates": [[[4.3, 52.1, 0, 0], [4.31, 52.11, 0, 1]]]},
                {"color": "#111111"},
            ),
            (
                "tracks",
                "tracking_layer.gpkg",
                "tracking_layer",
                "EPSG::4326",
                {"type": "LineString", "coordinates": [[4.3, 52.1, 0, 0], [4.31, 52.11, 0, 1]]},
                {"tracked_by": "test"},
            ),
        )
        for name, filename, layer, crs, geometry, properties in cases:
            with self.subTest(layer=name):
                package = self._copy_pristine(name)
                self._append_feature(
                    package, filename, layer, crs, geometry, properties
                )
                self._assert_rebuild_refused(package)

    def test_rebuild_refuses_existing_photo(self):
        package = self._copy_pristine("photo")
        (package / "photos" / "test.jpg").write_bytes(b"veldwaarneming")
        self._assert_rebuild_refused(package)


if __name__ == "__main__":
    unittest.main()
