#!/usr/bin/env python3
"""Contracttest voor het openbare complement van actuele statusvlakken."""

from __future__ import annotations

import importlib.util
from pathlib import Path

from osgeo import ogr


SCRIPT = Path(__file__).with_name("add_accessible_remainder.py")
spec = importlib.util.spec_from_file_location("add_accessible_remainder", SCRIPT)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)


def main() -> int:
    plot = ogr.CreateGeometryFromWkt(
        "MULTIPOLYGON(((0 0,10 0,10 10,0 10,0 0)))"
    )
    occupied = ogr.CreateGeometryFromWkt(
        "MULTIPOLYGON(((2 2,8 2,8 8,2 8,2 2)))"
    )
    record = module.build_remainder_record(
        {"Mtest": plot},
        [occupied],
        expected_area_m2=64.0,
    )
    remainder = ogr.CreateGeometryFromWkt(record["wkt"])
    assert record["gebied_code"] == "overig_meijendel_toegankelijk_1955"
    assert record["status_code"] == "toegankelijk"
    assert record["bron_code"] == "handmatige_statusaanvulling_20261110"
    assert abs(record["oppervlakte_m2"] - 64.0) < 0.000001
    assert record["interne_ringen"] == 1
    assert remainder.IsValid()
    assert remainder.Contains(ogr.CreateGeometryFromWkt("POINT(1 1)"))
    assert not remainder.Contains(ogr.CreateGeometryFromWkt("POINT(5 5)"))
    assert module.migration.polygonal_area(remainder.Intersection(occupied)) < 0.000001
    assert module.migration.polygonal_area(plot.Difference(remainder.Union(occupied))) < 0.000001
    print("OK: openbaar-restgebied-contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
