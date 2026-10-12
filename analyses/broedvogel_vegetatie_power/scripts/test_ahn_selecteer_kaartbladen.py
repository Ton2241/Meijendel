#!/usr/bin/env python3

import importlib.util
import tempfile
import unittest
from pathlib import Path

import geopandas as gpd
from shapely.geometry import box


SCRIPT = Path(__file__).with_name("ahn_selecteer_kaartbladen.py")


def load_module():
    spec = importlib.util.spec_from_file_location("ahn_selecteer_kaartbladen", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class SelectTilesTest(unittest.TestCase):
    def test_selects_only_tiles_touching_plots_and_preserves_provenance(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tiles = gpd.GeoDataFrame(
                {
                    "file": ["https://example.test/a.tif", "https://example.test/b.tif"],
                    "size": [101, 202],
                    "sha256": ["a" * 64, "b" * 64],
                },
                geometry=[box(0, 0, 10, 10), box(20, 0, 30, 10)],
                crs="EPSG:28992",
            )
            plots = gpd.GeoDataFrame(
                {"plotid": [1]}, geometry=[box(1, 1, 2, 2)], crs="EPSG:28992"
            )
            index = root / "index.geojson"
            plot_file = root / "plots.geojson"
            tiles.to_file(index, driver="GeoJSON")
            plots.to_file(plot_file, driver="GeoJSON")

            result = module.select_tiles(str(index), str(plot_file))

            self.assertEqual(result["bestand"].tolist(), ["a.tif"])
            self.assertEqual(result["omvang_bytes"].tolist(), [101])
            self.assertEqual(result["sha256"].tolist(), ["a" * 64])


if __name__ == "__main__":
    unittest.main()
