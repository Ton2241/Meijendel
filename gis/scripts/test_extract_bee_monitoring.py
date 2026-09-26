#!/usr/bin/env python3
"""Tests voor het reconstrueren van de EIS-bijenbezoeken."""

import importlib.util
from pathlib import Path


SCRIPT = Path(__file__).with_name("extract_bee_monitoring.py")


def load_module():
    spec = importlib.util.spec_from_file_location("bee_extract", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    module = load_module()
    fixture = """
Tabel 1 Onderzoeksdagen in       M01  22 april, 27 mei, 3 juli    24 april, 28 mei, 7 juli   19 april, 26 mei, 30 juni
vlak.                            M04  18 april, 23 mei, 30 juni   20 april, 18 mei, 5 juli   19 april, 26 mei, 30 juni
M18  16 april, 22 mei, 28 juni   18 april, 16 mei, 2 juli   30 april, 31 mei, 10 juli
"""
    visits = module.parse_visits(fixture)
    assert len(visits) == 27
    assert visits[0] == ("M01", "Vallei Meijendel", "2019-04-22", 1, 45)
    assert visits[-1] == ("M18", "Binnenduinen", "2023-07-10", 3, 45)
    assert module.area_for_plot("M05") == "De Loopert"
    assert module.area_for_plot("M11") == "Buitenduinen"
    print("OK: reconstructie EIS-bijenbezoeken")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
