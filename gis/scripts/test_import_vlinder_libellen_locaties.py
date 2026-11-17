#!/usr/bin/env python3
"""Controleer selectie en ruimtelijke toelating van Tove's routekaart."""

from __future__ import annotations

import importlib.util
from pathlib import Path


SCRIPT = Path(__file__).with_name("import_vlinder_libellen_locaties.py")
SOURCE = Path("/Volumes/T7 Data/Home_Ton/Meijendel data/Vlinderstichting")
BASIS = Path(__file__).parents[1] / "vectors/meijendel_bereik/meijendel_ruimtelijke_lagen.gpkg"


def load_module():
    spec = importlib.util.spec_from_file_location("vlinder_libellen_locaties", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    module = load_module()
    rows = module.build_location_rows(SOURCE, BASIS)
    dag = rows["vlinders_dag_telobject"]
    libel = rows["libellen_telobject"]
    dag_geom = rows["vlinders_dag_geometrie"]
    libel_geom = rows["libellen_geometrie"]

    assert {row["bron_code"] for row in dag} == {
        393, 635, 638, 640, 929, 1149, 4439, 4410, 4588, 4615, 5169
    }
    assert len(libel) == 11
    assert len({row["bronnaam"] for row in libel}) == 11
    assert len(dag_geom) == 194
    assert len(libel_geom) == 24
    assert sum(row["geometrie_type"] == "POINT" for row in dag_geom) == 21
    assert sum(row["geometrie_type"] == "LINESTRING" for row in dag_geom) == 173
    assert all(row["geometrie_type"] == "LINESTRING" for row in libel_geom)
    assert all(row["binnen_basisgebied"] for row in dag_geom + libel_geom)
    assert not any("Pan van Persijn" in str(row) for group in rows.values() for row in group)

    sql = module.build_insert_sql(rows)
    assert sql.count("ST_GeomFromWKB(") == 218
    assert "Pan van Persijn" not in sql
    assert "ndff_open_waarneming" not in sql
    print("OK: 22 geselecteerde locaties, 218 RD-kaartcomponenten, geen overige locaties")


if __name__ == "__main__":
    main()
