#!/usr/bin/env python3

import importlib.util
import unittest
from pathlib import Path

import pandas as pd


SCRIPT = Path(__file__).with_name("analyseer_ahn_harmonisatie.py")


def load_module():
    spec = importlib.util.spec_from_file_location("analyseer_ahn_harmonisatie", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class HarmonisationSummaryTest(unittest.TestCase):
    def test_transition_is_paired_by_plot(self):
        module = load_module()
        rows = []
        for cycle, moment, offset in (("AHN2", 2008, 0.0), ("AHN3", 2014, 1.0)):
            for plot_id in (1, 2):
                row = {
                    "ahn_cyclus": cycle,
                    "structuurmoment": moment,
                    "inwinningsperiode": str(moment),
                    "plot_id": plot_id,
                }
                row.update({metric: plot_id + offset for metric in module.METRICS})
                rows.append(row)
        result = module.transition_summary(pd.DataFrame(rows))
        self.assertTrue((result["gemiddelde_verandering"] == 1.0).all())
        self.assertTrue((result["plots_toename"] == 2).all())


if __name__ == "__main__":
    unittest.main()
