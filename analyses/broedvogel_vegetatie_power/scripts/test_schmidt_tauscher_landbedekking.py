#!/usr/bin/env python3

import importlib.util
import math
from pathlib import Path
import tempfile
import unittest

import numpy as np

SCRIPT = Path(__file__).with_name("schmidt_tauscher_landbedekking.py")
SOURCE_DIR = Path(__file__).parents[3] / "Landgebruik" / "schmidt_tauscher_2025" / "bron"
PUBLISHED = (
    Path(__file__).parents[1]
    / "resultaten"
    / "vegetatiesamenstelling_laatste_landbedekking.csv"
)


def load_module():
    spec = importlib.util.spec_from_file_location("schmidt_tauscher_landbedekking", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class SchmidtTauscherLandcoverTest(unittest.TestCase):
    def test_class_codes_include_year_specific_aliases(self):
        module = load_module()

        codes_2001 = module.class_codes(2001)
        self.assertEqual(codes_2001[137], "laag")
        self.assertEqual(codes_2001[2005], "water")
        self.assertEqual(codes_2001[8004], "bos")

        codes_2022 = module.class_codes(2022)
        self.assertEqual(codes_2022[141], "laag")
        self.assertEqual(codes_2022[69], "bos")
        self.assertEqual(codes_2022[79], "boomgroep")
        self.assertEqual(codes_2022[212], "water")

    def test_raster_totals_translate_every_valid_pixel(self):
        module = load_module()
        cases = [
        (
            2001,
            "classification2001_25k_grove.tif",
            {
                "struik": 308.1875,
                "bos": 106.0675,
                "boomgroep": 90.3550,
                "laag": 291.2825,
                "riet": 23.6775,
                "zand": 46.5825,
                "water": 58.1225,
            },
        ),
        (
            2022,
            "classification2022_grove_25k.tif",
            {
                "struik": 214.19535156729495,
                "bos": 76.6628101600179,
                "boomgroep": 99.34864173424181,
                "laag": 344.76763783872894,
                "riet": 26.72847976196032,
                "zand": 88.8957585722592,
                "water": 73.59019753000673,
            },
        ),
        ]
        for year, filename, expected in cases:
            with self.subTest(year=year):
                totals, unknown = module.raster_class_totals(SOURCE_DIR / filename, year)
                self.assertEqual(unknown, {})
                self.assertEqual(set(totals), set(expected))
                for class_name, expected_area in expected.items():
                    self.assertAlmostEqual(totals[class_name], expected_area, places=9)

    def test_invalid_year_is_rejected(self):
        module = load_module()
        with self.assertRaisesRegex(ValueError, "2001 of 2022"):
            module.class_codes(2010)

    def test_all_valid_pixels_are_assigned_to_the_25_source_plots(self):
        module = load_module()
        raster = SOURCE_DIR / "classification2001_25k_grove.tif"
        plots = SOURCE_DIR / "kacheln25.shp"

        rows, unknown, unassigned = module.raster_plot_summary(raster, plots, 2001)

        self.assertEqual(unknown, {})
        self.assertEqual(unassigned, 0)
        self.assertEqual(rows["plot"].nunique(), 25)
        self.assertEqual(len(rows), 25 * 7)
        totals = rows.groupby("klasse", sort=False)["raster_ha"].sum().to_dict()
        raster_totals, _ = module.raster_class_totals(raster, 2001)
        self.assertEqual(set(totals), set(raster_totals))
        for class_name, expected_area in raster_totals.items():
            self.assertAlmostEqual(totals[class_name], expected_area, places=9)

    def test_spatial_metrics_count_patches_and_internal_edges(self):
        module = load_module()
        classes = np.array([[1, 1, 2], [1, 3, 2]], dtype=np.int16)
        valid = np.ones_like(classes, dtype=bool)

        landscape, class_rows = module.calculate_spatial_metrics(
            classes, valid, pixel_size=5.0
        )

        self.assertEqual(landscape["geldige_pixels"], 6)
        self.assertAlmostEqual(landscape["oppervlak_ha"], 0.015)
        self.assertAlmostEqual(
            landscape["shannon"],
            -(0.5 * math.log(0.5) + (2 / 6) * math.log(2 / 6) + (1 / 6) * math.log(1 / 6)),
        )
        self.assertAlmostEqual(landscape["interne_rand_m_per_ha"], 20 / 0.015)
        by_class = {row["klasse_code"]: row for row in class_rows}
        self.assertEqual(by_class[1]["patches"], 1)
        self.assertEqual(by_class[2]["patches"], 1)
        self.assertEqual(by_class[3]["patches"], 1)
        self.assertAlmostEqual(by_class[1]["grootste_patch_aandeel"], 1.0)

    def test_spatial_summary_keeps_zero_classes_for_every_plot(self):
        module = load_module()
        landscape, classes, unknown, unassigned = module.raster_spatial_summary(
            SOURCE_DIR / "classification2022_grove_25k.tif",
            SOURCE_DIR / "kacheln25.shp",
            2022,
        )

        self.assertEqual(unknown, {})
        self.assertEqual(unassigned, 0)
        self.assertEqual(len(landscape), 25)
        self.assertEqual(len(classes), 25 * 7)
        shares = classes.groupby("plot", sort=False)["aandeel"].sum()
        self.assertTrue(np.allclose(shares.to_numpy(), 1.0))
        self.assertGreater((classes["pixels"] == 0).sum(), 0)

    def test_raster_areas_reproduce_the_published_plot_table(self):
        module = load_module()
        rows, _, _ = module.raster_plot_summary(
            SOURCE_DIR / "classification2001_25k_grove.tif",
            SOURCE_DIR / "kacheln25.shp",
            2001,
        )

        comparison = module.compare_with_published(rows, PUBLISHED)

        self.assertEqual(len(comparison), 25 * 7)
        status_counts = comparison["koppelstatus"].value_counts()
        self.assertEqual(int(status_counts["gekoppeld"]), 175)
        self.assertEqual(int(status_counts.get("alleen_raster", 0)), 0)
        self.assertEqual(int(status_counts.get("alleen_tabel", 0)), 0)
        self.assertLess(comparison["absoluut_verschil_ha"].mean(), 0.004)
        self.assertLessEqual(comparison["absoluut_verschil_ha"].max(), 0.031)

    def test_delivery_analysis_writes_all_auditable_outputs(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            output_dir = Path(directory)
            manifest = module.run_delivery_analysis(SOURCE_DIR, PUBLISHED, output_dir)

            expected = {
                "landbedekking_raster_laatste_oppervlaktecontrole.csv",
                "landbedekking_raster_laatste_landscapemetrics.csv",
                "landbedekking_raster_laatste_klassemetrics.csv",
                "landbedekking_raster_laatste_verandering.csv",
                "landbedekking_raster_laatste_manifest.json",
            }
            self.assertEqual({path.name for path in output_dir.iterdir()}, expected)
            self.assertEqual(manifest["plots"], 25)
            self.assertEqual(manifest["jaren"], [2001, 2022])
            self.assertEqual(manifest["onbekende_codes"], {"2001": {}, "2022": {}})
            self.assertEqual(manifest["niet_toegewezen_pixels"], {"2001": 0, "2022": 0})


if __name__ == "__main__":
    unittest.main()
