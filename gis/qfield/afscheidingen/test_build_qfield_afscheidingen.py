#!/usr/bin/env python3
"""Contracttests voor het offline QField-pakket Afscheidingen."""

from __future__ import annotations

import importlib.util
import os
import subprocess
import tempfile
import unittest
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


if __name__ == "__main__":
    unittest.main()
