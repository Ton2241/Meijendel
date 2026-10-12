#!/usr/bin/env python3

import importlib.util
import unittest
from pathlib import Path

import numpy as np


SCRIPT = Path(__file__).with_name("ahn1_historische_rasters.py")


def load_module():
    spec = importlib.util.spec_from_file_location("ahn1_historische_rasters", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class HistoricalRasterTest(unittest.TestCase):
    def test_mean_and_max_methods_make_method_sensitivity_visible(self):
        accumulator = load_module().RasterAccumulator((0, 0, 10, 10), 5)
        accumulator.add(
            np.array([1.0, 2.0, 6.0]),
            np.array([9.0, 8.0, 9.0]),
            np.array([1.0, 3.0, 2.0]),
            ground=True,
        )
        accumulator.add(
            np.array([1.5, 6.5]),
            np.array([8.5, 8.5]),
            np.array([9.0, 8.0]),
            ground=False,
        )
        dtm, dsm_mean, dsm_max = accumulator.arrays()

        self.assertAlmostEqual(dtm[0, 0], 2.0)
        self.assertAlmostEqual(dsm_mean[0, 0], 13 / 3)
        self.assertAlmostEqual(dsm_max[0, 0], 9.0)
        self.assertGreater(dsm_max[0, 0] - dtm[0, 0], dsm_mean[0, 0] - dtm[0, 0])
        self.assertEqual(accumulator.ground_points, 3)
        self.assertEqual(accumulator.nonground_points, 2)


if __name__ == "__main__":
    unittest.main()
