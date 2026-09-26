#!/usr/bin/env python3
"""Contracttest voor de contexttabellen van fase 2."""

from pathlib import Path


SCHEMA = Path(__file__).parents[1] / "database" / "phase2_context_schema.sql"


def main() -> int:
    sql = SCHEMA.read_text(encoding="utf-8").lower()
    for fragment in (
        "use meijendel_bronnen",
        "create table if not exists bijen_proefvlak",
        "create table if not exists bijen_bezoek",
        "create table if not exists aquatisch_monsterpunt",
        "create table if not exists aquatisch_monsterprotocol",
        "foreign key (bron_id, proefvlak_code)",
        "foreign key (bron_id, monsterpunt_code)",
    ):
        assert fragment in sql, fragment
    assert "geometry" not in sql
    print("OK: fase-2-contextschema")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
