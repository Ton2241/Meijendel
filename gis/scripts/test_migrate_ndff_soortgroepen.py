#!/usr/bin/env python3
"""Contracttests voor de alleen-lezen NDFF-reeksinventarisatie."""

import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


MODULE = Path(__file__).with_name("migrate_ndff_soortgroepen.py")


def load_module():
    spec = importlib.util.spec_from_file_location("ndff_reeksinventarisatie", MODULE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class NdffReeksinventarisatieTest(unittest.TestCase):
    def setUp(self):
        self.module = load_module()

    def test_brede_tabelgenerator_is_niet_meer_beschikbaar(self):
        self.assertFalse(hasattr(self.module, "new_table_sql"))
        self.assertFalse(hasattr(self.module, "destination_for"))
        self.assertFalse(hasattr(self.module, "GROUP_CODES"))

    def test_twee_bronlabels_zijn_alleen_auditinformatie(self):
        self.assertTrue(self.module.source_group_matches(
            "Geleedpotigen (overig)|Kreeftachtigen", "kreeftachtigen"))
        self.assertFalse(self.module.source_group_matches(
            "Geleedpotigen (overig)|Kreeftachtigen", "libellen"))
        with self.assertRaises(ValueError):
            self.module.source_group_matches("onbekende groep", "kreeftachtigen")

    def test_alleen_aantoonbaar_geschikte_reeks_is_kandidaat(self):
        series = {
            "deelreeks_sleutel": "vaste-plots:protocol-1",
            "analyse_type_code": "TV", "eindbesluit": "toegelaten",
            "bezoekstructuur_status": "volledig", "methode_status": "volledig",
            "nulwaarneming_status": "betrouwbaar_afleidbaar",
            "ruimtelijke_status": "exact_of_eenduidig",
            "jaar_van": 2010, "jaar_tot": 2020,
        }
        self.assertTrue(self.module.trend_candidate(series))
        for change in (
            {"eindbesluit": "voorlopig_toegelaten"},
            {"bezoekstructuur_status": "gereconstrueerd"},
            {"methode_status": "alleen_protocol_bekend"},
            {"nulwaarneming_status": "gedeeltelijk_afleidbaar"},
            {"ruimtelijke_status": "onzekerheidspolygoon"},
            {"jaar_tot": 2010},
            {"deelreeks_sleutel": ""},
            {"analyse_type_code": "V"},
        ):
            with self.subTest(change=change):
                self.assertFalse(self.module.trend_candidate(series | change))

    def test_nul_alleen_voor_tv_verplicht(self):
        series = {
            "deelreeks_sleutel": "vaste-plots:protocol-1",
            "analyse_type_code": "TA", "eindbesluit": "toegelaten",
            "bezoekstructuur_status": "volledig", "methode_status": "volledig",
            "nulwaarneming_status": "ontbreekt",
            "ruimtelijke_status": "exact_of_eenduidig",
            "jaar_van": 2010, "jaar_tot": 2020,
        }
        self.assertTrue(self.module.trend_candidate(series))

    def test_preflight_rapporteert_groepen_maar_geen_tabelplan(self):
        source = [["Geleedpotigen (overig)|Kreeftachtigen", "kreeftachtigen", "179"]]
        catalog = [["vaste-plots:protocol-1", "TV", "voorlopig_toegelaten",
                    "gereconstrueerd", "gedeeltelijk_afleidbaar",
                    "alleen_protocol_bekend", "onzekerheidspolygoon", "2010", "2020"]]
        with patch.object(self.module, "query", side_effect=[source, [["179", "1700", "2025"]], catalog]):
            result = self.module.preflight()
        self.assertEqual(result["bronregels"], 179)
        self.assertEqual(result["per_centrale_groep"], {"kreeftachtigen": 179})
        self.assertEqual(result["mogelijke_trendreeksen"], [])
        self.assertNotIn("doeltabellen", result)
        self.assertFalse(result["levende_database_gewijzigd"])

    def test_preflight_toont_alleen_een_echt_toegelaten_reeks(self):
        source = [["Kreeftachtigen", "kreeftachtigen", "2"]]
        candidate = ["vaste-plots:protocol-1", "TV", "toegelaten",
                     "volledig", "expliciet", "volledig", "exact_of_eenduidig",
                     "2010", "2020"]
        rejected = candidate.copy()
        rejected[2] = "voorlopig_toegelaten"
        with patch.object(self.module, "query", side_effect=[
            source, [["2", "2010", "2020"]], [candidate, rejected]
        ]):
            result = self.module.preflight()
        self.assertEqual(result["mogelijke_trendreeksen"], [
            {"deelreeks_sleutel": "vaste-plots:protocol-1", "analyse_type_code": "TV"}
        ])

    def test_apply_meldt_dat_de_brede_migratie_is_vervallen(self):
        result = subprocess.run(
            [sys.executable, "-B", str(MODULE), "--apply"],
            capture_output=True, text=True, check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("vervallen", result.stderr)


if __name__ == "__main__":
    unittest.main()
