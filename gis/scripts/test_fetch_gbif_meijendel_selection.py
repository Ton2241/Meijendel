#!/usr/bin/env python3
"""Unit tests voor de gepartitioneerde GBIF-selectie."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("fetch_gbif_meijendel_selection.py")
SPEC = importlib.util.spec_from_file_location("fetch_gbif_meijendel_selection", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(MODULE)


class BboxTests(unittest.TestCase):
    def test_bbox_wkt_is_closed(self):
        self.assertEqual(
            MODULE.bbox_wkt((1.0, 2.0, 3.0, 4.0)),
            "POLYGON((1.0 2.0,3.0 2.0,3.0 4.0,1.0 4.0,1.0 2.0))",
        )


if __name__ == "__main__":
    unittest.main()
