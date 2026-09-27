#!/usr/bin/env python3
"""Contracttest voor de uitvoerbare overlapaudit."""

from __future__ import annotations

import subprocess
import importlib.util
import json
import tempfile
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("run_external_ecology_overlap_audit.py")


class AuditRunnerTests(unittest.TestCase):
    def test_inventory_uses_central_names_and_both_source_locations(self):
        spec = importlib.util.spec_from_file_location('pq_audit', SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertNotIn('JOIN pq_vegetatie_taxon', module.PQ_INVENTORY_SQL)
        self.assertIn('taxa_bronkoppeling', module.PQ_INVENTORY_SQL)
        self.assertIn('pq_vegetatie_bronopname', module.PQ_INVENTORY_SQL)
        self.assertIn('pq_vegetatie_bronresultaat', module.PQ_INVENTORY_SQL)

    def test_read_only_inventory_cli_uses_transaction_and_writes_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            client = Path(tmp) / "mysql-fixture"
            report = Path(tmp) / "inventory.json"
            client.write_text(
                f"#!{sys.executable}\nimport sys\n"
                "query = sys.stdin.read()\n"
                "assert 'START TRANSACTION READ ONLY' in query\n"
                "assert 'WITH CONSISTENT SNAPSHOT' in query\n"
                "assert query.rstrip().endswith('ROLLBACK;')\n"
                "assert all(word not in query.upper() for word in ('DELETE ', 'INSERT ', 'UPDATE ', 'ALTER '))\n"
                "print('{\"kind\":\"province\",\"data\":{\"opname_id\":1,\"year\":2000,\"name\":\"Fagus sylvatica\",\"code\":\"4\",\"quantity\":\"63\"}}')\n",
                encoding="utf-8",
            )
            client.chmod(0o700)
            result = subprocess.run([sys.executable, str(SCRIPT), "--pq-inventarisatie",
                "--mysql-client", str(client), "--output", str(report)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(report.read_text())["province"]["rows"], 1)
            self.assertIn("READ-ONLY", result.stdout)

    def test_read_only_inventory_cannot_be_combined_with_apply(self):
        result = subprocess.run([sys.executable, str(SCRIPT), "--pq-inventarisatie", "--apply"],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("not allowed", result.stderr)

    def test_pq_inventory_reports_whole_recordings_not_a_species_match(self):
        spec = importlib.util.spec_from_file_location("pq_audit", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertTrue(callable(getattr(module, "pq_inventory_from_rows", None)),
                        "Inventarisatie volledige opnamen ontbreekt")
        rows = [
            {"kind": "province", "data": {"opname_id": 1, "year": 2000,
                "name": "Fagus sylvatica", "code": "4", "quantity": "63"}},
            {"kind": "lvd", "data": {"event_id": 2, "year": 2000,
                "name": "Fagus sylvatica", "code": "4", "quantity": "68", "layer": "tree"}},
            {"kind": "pair", "data": {"opname_id": 1, "event_id": 2, "distance_m": 0.3}},
        ]
        result = module.pq_inventory_from_rows(rows)
        self.assertEqual(result["province"], {"recordings": 1, "rows": 1, "period": [2000, 2000]})
        self.assertEqual(result["candidate_pairs"], 1)
        self.assertEqual(result["same_names_and_codes"], 1)
        self.assertEqual(result["same_quantities"], 0)
        self.assertEqual(result["pairs"][0]["quantity_differences"], 1)
        self.assertFalse(result["pairs"][0]["identity_proven"])
        # A subset match must stop looking like a full opname match.
        rows.insert(2, {"kind": "lvd", "data": {"event_id": 2, "year": 2000,
            "name": "Quercus robur", "code": "+", "quantity": "2", "layer": "herb"}})
        result = module.pq_inventory_from_rows(rows)
        self.assertEqual(result["same_names_and_codes"], 0)
        self.assertEqual(result["lvd"]["rows"], 2)

    def test_pq_comparison_preserves_source_values_and_never_proves_identity(self):
        spec = importlib.util.spec_from_file_location("pq_audit", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertTrue(callable(getattr(module, "compare_pq_recordings", None)),
                        "Volledige opnamevergelijking ontbreekt")
        province = [{"name": "Fagus sylvatica", "code": "4", "quantity": "63.00"}]
        lvd = [{"name": "Fagus sylvatica", "code": "4", "quantity": "68.00000000", "layer": "tree"}]
        result = module.compare_pq_recordings(province, lvd)
        self.assertTrue(result["same_names_and_codes"])
        self.assertFalse(result["same_quantities"])
        self.assertFalse(result["identity_proven"])
        self.assertEqual(result["quantity_differences"], 1)
        self.assertEqual(province[0]["quantity"], "63.00")
        self.assertEqual(lvd[0]["quantity"], "68.00000000")

    def test_pq_comparison_keeps_layers_and_duplicate_rows(self):
        spec = importlib.util.spec_from_file_location("pq_audit", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertTrue(callable(getattr(module, "compare_pq_recordings", None)),
                        "Volledige opnamevergelijking ontbreekt")
        province = [{"name": "Acer campestre", "code": "+", "quantity": "2"}]
        lvd = [dict(province[0], layer="tree"), dict(province[0], layer="herb")]
        result = module.compare_pq_recordings(province, lvd)
        self.assertFalse(result["same_names_and_codes"])
        self.assertEqual(result["lvd_layers"], ["herb", "tree"])
        self.assertFalse(result["identity_proven"])
        result = module.compare_pq_recordings([], [])
        self.assertFalse(result["same_names_and_codes"])
        self.assertFalse(result["same_quantities"])

    def test_dry_run_executes_without_database_write(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT)],
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertIn("DRY-RUN", result.stdout)
        self.assertIn("audit_external_ecology_overlap.sql", result.stdout)


if __name__ == "__main__":
    unittest.main()
