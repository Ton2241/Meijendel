#!/usr/bin/env python3

import importlib.util
import unittest
from pathlib import Path

import pandas as pd


SCRIPT = Path(__file__).with_name("controleer_ahn_harmonisatie.py")


def load_module():
    spec = importlib.util.spec_from_file_location("controleer_ahn_harmonisatie", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class HarmonisationValidationTest(unittest.TestCase):
    def make_data(self):
        rows = []
        for cycle in ("AHN2", "AHN3", "AHN4", "AHN5"):
            for plot_id in range(1, 56):
                rows.append(
                    {
                        "plot_id": plot_id,
                        "ahn_cyclus": cycle,
                        "structuurmoment": {
                            "AHN2": 2008,
                            "AHN3": 2014,
                            "AHN4": 2020,
                            "AHN5": 2023,
                        }[cycle],
                        "resolutie_m": 2.0,
                        "harmonisatie": "gelijk",
                        "inwinningsdatum": None if cycle == "AHN2" else "2023-02-07",
                        "inwinningsperiode": "2008" if cycle == "AHN2" else "2023-02-07",
                        "respons_startjaar": 2009 if cycle == "AHN2" else 2023,
                        "aandeel_open": 0.25,
                        "aandeel_lage_vegetatie": 0.25,
                        "aandeel_struweel": 0.25,
                        "aandeel_bomen": 0.25,
                    }
                )
        return pd.DataFrame(rows)

    def test_complete_three_cycle_layer_passes(self):
        result = load_module().validate(self.make_data())
        self.assertTrue(result["geslaagd"].all())

    def test_missing_plot_fails(self):
        with self.assertRaisesRegex(ValueError, "55_plots_per_cyclus"):
            load_module().validate(self.make_data().iloc[:-1])


if __name__ == "__main__":
    unittest.main()
