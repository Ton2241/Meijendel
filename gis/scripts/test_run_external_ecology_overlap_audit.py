#!/usr/bin/env python3
"""Contracttest voor de uitvoerbare overlapaudit."""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("run_external_ecology_overlap_audit.py")


class AuditRunnerTests(unittest.TestCase):
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
