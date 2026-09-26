#!/usr/bin/env python3
"""Bouw de overlapclassificatie voor externe ecologiebronnen opnieuw op."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
AUDIT_SQL = ROOT / "gis" / "scripts" / "audit_external_ecology_overlap.sql"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--mysql-client", type=Path, default=Path("/usr/local/mysql/bin/mysql"))
    parser.add_argument("--login-path", default="meijendel_root")
    args = parser.parse_args()

    sql = AUDIT_SQL.read_text(encoding="utf-8")
    if not args.apply:
        print(f"DRY-RUN: {AUDIT_SQL}; {len(sql.encode('utf-8'))} bytes SQL")
        return 0

    subprocess.run(
        [str(args.mysql_client), f"--login-path={args.login_path}"],
        input=sql,
        text=True,
        check=True,
    )
    print("IMPORT: overlapaudit externe ecologiebronnen opnieuw opgebouwd")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
