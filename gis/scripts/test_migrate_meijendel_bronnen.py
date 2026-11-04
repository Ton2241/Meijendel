#!/usr/bin/env python3
"""Integriteitscontract voor de gecontroleerde bronmigratie."""

from __future__ import annotations

import importlib.util
from pathlib import Path


SCRIPT = Path(__file__).with_name("migrate_meijendel_bronnen.py")
ROOT = Path(__file__).parents[2]


def load_module():
    spec = importlib.util.spec_from_file_location("migrate_meijendel_bronnen", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    module = load_module()
    blocked = module.MigrationState(
        counts_match=True,
        hashes_match=True,
        foreign_keys_ok=True,
        restore_ok=False,
    )
    assert module.may_finalize(blocked) is False
    valid = module.MigrationState(
        counts_match=True,
        hashes_match=True,
        foreign_keys_ok=True,
        restore_ok=True,
    )
    assert module.may_finalize(valid) is True
    assert "drop table" not in module.build_finalize_sql(validated=False).casefold()
    final_sql = module.build_finalize_sql(validated=True)
    assert "drop table" in final_sql.casefold()
    assert final_sql.casefold().index("drop view") < final_sql.casefold().index("drop table")

    profile = module.read_spider_matrix(
        ROOT / "kandidaatbronnen" / "jachtspinnen_1969_1970" / "jachtspinnen_28_locaties.csv"
    )
    assert len(profile.locations) == 28
    assert len(profile.species) == 12
    assert sum(row["aantal"] for row in profile.catches) == 3337
    assert profile.locations[0]["locatie_nummer"] == 1

    source = SCRIPT.read_text(encoding="utf-8")
    assert "'jachtspinnen_28_locaties.csv','text/csv','repository',336" in source
    assert "336 soort-locatieregels met samen 3.337 exemplaren" in source
    assert "101.992 geregistreerde regels bestaan uit 488 opnamen en 101.504 bedekkingsregels" in source

    print("OK: migratiecontract Meijendel_bronnen")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
