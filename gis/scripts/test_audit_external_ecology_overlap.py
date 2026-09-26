#!/usr/bin/env python3
"""Contracttest voor de overlapaudit van externe ecologiebronnen."""

from pathlib import Path


SQL = Path(__file__).with_name("audit_external_ecology_overlap.sql")


def main() -> int:
    text = SQL.read_text(encoding="utf-8").lower()
    for fragment in (
        "doelsysteem='provinciale_pq'",
        "doelsysteem='ndff'",
        "datum_precisie='exact'",
        "st_distance",
        "st_transform",
        "st_intersects",
        "zekerheid",
        "commit",
    ):
        assert fragment in text, fragment
    print("OK: externe ecologie-overlapaudit")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
