#!/usr/bin/env python3
"""Tests voor de fase-2-contextimport."""

import importlib.util
from pathlib import Path


SCRIPT = Path(__file__).with_name("import_phase2_context_sources.py")


def load_module():
    spec = importlib.util.spec_from_file_location("phase2_context", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    module = load_module()
    assert len(module.BEE_PLOTS) == 18
    assert len(module.AQUATIC_POINTS) == 7
    assert {row[0] for row in module.AQUATIC_POINTS} == {f"MP{i}" for i in range(1, 8)}
    assert module.BEE_PLOTS["M01"] == "Vallei Meijendel"
    assert module.BEE_PLOTS["M18"] == "Binnenduinen"
    assert any(row[0] == "MP7" and row[3] == 2.0 for row in module.AQUATIC_PROTOCOLS)
    sql = module.build_sql([
        {"proefvlak_code": "M01", "deelgebied": "Vallei Meijendel", "bezoekdatum": "2019-04-22", "ronde": "1", "duur_minuten": "45"}
    ], database="Meijendel_bronnen_phase12_test")
    assert "USE Meijendel_bronnen_phase12_test" in sql
    assert "START TRANSACTION" in sql and "COMMIT" in sql
    assert "162 gestandaardiseerde bezoeken" in sql
    assert "vrs-ringgegevens-meijendel-kandidaat" in sql
    assert "droge-duinvegetatieplots-1952-2012" in sql
    print("OK: fase-2-contextimport")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
