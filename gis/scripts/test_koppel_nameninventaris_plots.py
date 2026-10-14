#!/usr/bin/env python3
"""Contracttests voor de ruimtelijke koppeling van namen aan vogelkavels."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).parents[2]
SCRIPT = ROOT / "gis" / "scripts" / "koppel_nameninventaris_plots.py"
SCHEMA = ROOT / "gis" / "database" / "nameninventaris_plotkoppeling_schema.sql"
SOVON_SHP = Path(
    "/Volumes/T7 Data/Home_Ton/Meijendel data/SOVON/Per jaar/2025/"
    "avimap_252_diversen__gebieden.shp"
)


def load_script():
    spec = importlib.util.spec_from_file_location("koppel_nameninventaris_plots", SCRIPT)
    if spec is None or spec.loader is None:
        raise AssertionError(f"Script niet laadbaar: {SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_external_importer():
    path = ROOT / "gis" / "scripts" / "import_external_ecology_sources.py"
    spec = importlib.util.spec_from_file_location("import_external_ecology_sources", path)
    if spec is None or spec.loader is None:
        raise AssertionError(f"Script niet laadbaar: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PlotbronContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.module = load_script()

    def test_laatste_sovon_shapefile_levert_55_meijendelplots(self) -> None:
        levering = self.module.read_plot_delivery(SOVON_SHP)

        self.assertEqual(levering.bron_datum.isoformat(), "2026-10-02")
        self.assertEqual(levering.bron_objecten, 56)
        self.assertEqual(len(levering.plots), 55)
        self.assertEqual(len({plot.plot_id for plot in levering.plots}), 55)
        self.assertEqual(levering.uitgesloten_plot_id, 29945)
        self.assertEqual(levering.uitgesloten_naam, "De Horsten")
        self.assertNotIn(29945, {plot.plot_id for plot in levering.plots})
        self.assertTrue(all(plot.srid == 28992 for plot in levering.plots))
        self.assertTrue(all(plot.is_valid for plot in levering.plots))

    def test_schema_gebruikt_plots_geom_en_geen_ndff_tabellen(self) -> None:
        schema = SCHEMA.read_text(encoding="utf-8")

        self.assertIn("ALTER TABLE plots", schema)
        self.assertIn("geom_bron_import_id", schema)
        self.assertIn("nameninventaris_plot_koppeling", schema)
        self.assertIn("REFERENCES plots (plot_id)", schema)
        self.assertNotIn("ADD COLUMN IF NOT EXISTS", schema)
        self.assertNotRegex(schema.lower(), r"\bndff_")

    def test_sql_schrijft_plots_geom_en_raakt_ndff_niet(self) -> None:
        levering = self.module.read_plot_delivery(SOVON_SHP)
        sql = self.module.build_import_sql(levering, "Meijendel")

        self.assertIn("UPDATE plots", sql)
        self.assertIn("geom=ST_GeomFromWKB", sql)
        self.assertIn("plot_id=29945", sql)
        self.assertNotRegex(sql.lower(), r"\bndff_")
        self.assertIn("START TRANSACTION", sql)
        self.assertIn("COMMIT", sql)

    def test_centrale_schema_contract_kent_plotbron_en_koppeling(self) -> None:
        external = load_external_importer()

        self.assertEqual(
            external.CENTRAL_QUERY_SCHEMA["plots"],
            frozenset({
                "plot_id", "plot_nr", "plot_wv", "plot_naam", "kavel_nummer",
                "geom", "in_gebruik", "geom_bron_import_id", "geom_sha256",
            }),
        )
        self.assertIn("plot_geometrie_import", external.CENTRAL_QUERY_SCHEMA)
        self.assertIn("nameninventaris_plot_koppeling", external.CENTRAL_QUERY_SCHEMA)

    def test_bestaande_bronversie_met_andere_bundelhash_wordt_geweigerd(self) -> None:
        levering = self.module.read_plot_delivery(SOVON_SHP)

        with patch.object(self.module, "mysql_run", return_value="0" * 64):
            with self.assertRaisesRegex(ValueError, "andere bundelhash"):
                self.module.validate_existing_import(
                    levering,
                    database="Meijendel",
                    mysql_client=Path("/niet/gebruikt/mysql"),
                    login_path="niet_gebruikt",
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
