#!/usr/bin/env python3

import importlib.util
import math
import unittest
from pathlib import Path

import numpy as np
import geopandas as gpd
from shapely.geometry import box


SCRIPT = Path(__file__).with_name("ahn_vegetatiestructuur.py")


def load_module():
    spec = importlib.util.spec_from_file_location("ahn_vegetatiestructuur", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class HeightMetricsTest(unittest.TestCase):
    def test_dominant_acquisition_date_uses_largest_overlap(self):
        module = load_module()
        plots = gpd.GeoDataFrame(
            {"plotid": [10, 20]},
            geometry=[box(0, 0, 10, 10), box(20, 0, 30, 10)],
            crs="EPSG:28992",
        )
        flights = gpd.GeoDataFrame(
            {"datum": ["2014-01-29", "2014-02-03"]},
            geometry=[box(0, 0, 4, 10), box(4, 0, 10, 10)],
            crs="EPSG:28992",
        )
        dates = module.dominant_acquisition_dates(plots, flights, "datum")

        self.assertEqual(dates.loc[10, "inwinningsdatum"], "2014-02-03")
        self.assertAlmostEqual(dates.loc[10, "datum_dekkingsaandeel"], 0.6)
        self.assertEqual(dates.loc[10, "datum_methode"], "vlakoverlap")
        self.assertEqual(dates.loc[20, "inwinningsdatum"], "2014-02-03")
        self.assertEqual(dates.loc[20, "datum_methode"], "dichtstbijzijnde_vlieglijn")
        self.assertAlmostEqual(dates.loc[20, "afstand_vlieglijn_m"], 10.0)

    def test_height_classes_and_edges_use_valid_pixels_only(self):
        module = load_module()
        dsm = np.array(
            [[0.0, 1.0, 3.0], [6.0, 8.0, np.nan], [-0.2, 50.0, 1.5]],
            dtype=float,
        )
        dtm = np.zeros_like(dsm)
        metrics = module.calculate_height_metrics(dsm, dtm, pixel_size=2.0)

        self.assertEqual(metrics["geldige_pixels"], 7)
        self.assertEqual(metrics["uitbijter_pixels"], 1)
        self.assertAlmostEqual(metrics["aandeel_open"], 2 / 7)
        self.assertAlmostEqual(metrics["aandeel_lage_vegetatie"], 2 / 7)
        self.assertAlmostEqual(metrics["aandeel_struweel"], 1 / 7)
        self.assertAlmostEqual(metrics["aandeel_bomen"], 2 / 7)
        self.assertAlmostEqual(metrics["hoogte_mediaan_m"], 1.5)
        self.assertAlmostEqual(metrics["hoogte_max_m"], 8.0)
        self.assertGreater(metrics["randlengte_m_per_ha"], 0.0)

    def test_no_valid_height_returns_explicit_missing_metrics(self):
        module = load_module()
        dsm = np.array([[np.nan, 80.0]], dtype=float)
        dtm = np.array([[np.nan, 0.0]], dtype=float)
        metrics = module.calculate_height_metrics(dsm, dtm, pixel_size=2.0)

        self.assertEqual(metrics["geldige_pixels"], 0)
        self.assertTrue(math.isnan(metrics["hoogte_mediaan_m"]))
        self.assertTrue(math.isnan(metrics["aandeel_bomen"]))


if __name__ == "__main__":
    unittest.main()
