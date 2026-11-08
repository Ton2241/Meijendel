#!/usr/bin/env python3
"""Schema- en selectiegate voor fysieke openbare soortgroepopslag."""

import importlib.util
import unittest
from pathlib import Path


MODULE = Path(__file__).with_name("migrate_ndff_soortgroepen.py")


def load_module():
    if not MODULE.exists():
        return None
    spec = importlib.util.spec_from_file_location("soortgroepen_migratie", MODULE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class SoortgroepMigratieTest(unittest.TestCase):
    def test_alle_id_only_groepen_krijgen_een_volledige_eigen_tabel(self):
        module = load_module()
        self.assertIsNotNone(module, "de soortgroepmigratie ontbreekt")
        self.assertEqual(len(module.GROUP_CODES), 24)
        self.assertNotIn("mossen", module.GROUP_CODES)
        self.assertNotIn("korstmossen", module.GROUP_CODES)
        sql = "\n".join(module.new_table_sql("Meijendel_soortgroep_proef"))
        for group in module.GROUP_CODES:
            self.assertIn(
                f"CREATE TABLE `Meijendel_soortgroep_proef`.`{group}_waarneming` LIKE ",
                sql,
            )
        self.assertNotIn("FOREIGN_KEY_CHECKS=0", sql)

    def test_bronlabel_met_twee_groepen_krijgt_een_primaire_bestemming(self):
        module = load_module()
        self.assertIsNotNone(module, "de soortgroepmigratie ontbreekt")
        self.assertEqual(
            module.destination_for("Geleedpotigen (overig)|Kreeftachtigen", "kreeftachtigen"),
            "kreeftachtigen_waarneming",
        )
        with self.assertRaises(ValueError):
            module.destination_for("Geleedpotigen (overig)|Kreeftachtigen", None)
        with self.assertRaises(ValueError):
            module.destination_for("Geleedpotigen (overig)|Kreeftachtigen", "libellen")


if __name__ == "__main__":
    unittest.main()
