#!/usr/bin/env python3

import importlib.util
import unittest
from pathlib import Path

import pandas as pd


SCRIPT = Path(__file__).with_name("analyseer_ahn1_gevoeligheid.py")


def load_module():
    spec = importlib.util.spec_from_file_location("analyseer_ahn1_gevoeligheid", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class SensitivityTest(unittest.TestCase):
    def test_reports_direction_and_absolute_method_difference(self):
        module = load_module()
        base = {"plot_id": [1, 2]}
        for metric in module.METRICS:
            base[metric] = [1.0, 2.0]
        mean = pd.DataFrame(base)
        maximum = mean.copy()
        maximum["aandeel_bomen"] += [0.2, 0.4]
        _, summary = module.compare(mean, maximum)
        row = summary[summary["maat"] == "aandeel_bomen"].iloc[0]
        self.assertAlmostEqual(row["gemiddeld_verschil"], 0.3)
        self.assertAlmostEqual(row["mediaan_absoluut_verschil"], 0.3)


if __name__ == "__main__":
    unittest.main()
