#!/usr/bin/env python3
"""Gedragstest voor de idempotente import van de analysecatalogus."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "gis" / "scripts" / "import_analysegeschiktheid.py"


def main() -> int:
    result = subprocess.run(
        ["python3", str(SCRIPT), "--dry-run"],
        check=True,
        capture_output=True,
        text=True,
    )
    summary = json.loads(result.stdout)
    assert summary == {
        "analyse_types": 5,
        "datareeksen": 18,
        "generieke_besluiten": 85,
        "ndff_besluiten_gekopieerd": 0,
        "regelversie": "analyse-catalogus-v1",
    }
    print("OK: import analysegeschiktheid dry-run")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
