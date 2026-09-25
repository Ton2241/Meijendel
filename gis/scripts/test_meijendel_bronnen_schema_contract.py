#!/usr/bin/env python3
"""Contracttest voor de afzonderlijke bron- en literatuurdatabase."""

from __future__ import annotations

from pathlib import Path


SCHEMA = Path(__file__).parents[1] / "database" / "meijendel_bronnen_schema.sql"


def main() -> int:
    sql = SCHEMA.read_text(encoding="utf-8")
    folded = " ".join(sql.casefold().split())
    for fragment in (
        "create database if not exists meijendel_bronnen",
        "create table if not exists bron",
        "create table if not exists bron_bestand",
        "create table if not exists literatuur",
        "create table if not exists literatuur_auteur",
        "create table if not exists jachtspin_locatie",
        "create table if not exists jachtspin_soort",
        "create table if not exists jachtspin_vangst",
        "create or replace view v_bron_catalogus",
        "create or replace view v_literatuur_overzicht",
        "create or replace view v_contextdataset_overzicht",
    ):
        assert fragment in folded, fragment

    for forbidden in (
        "absolute_pad",
        "longblob",
        "mediumblob",
        "attachment_path",
        "/users/ton/",
        "/volumes/",
    ):
        assert forbidden not in sql.casefold(), forbidden

    assert "check (jaar_tot is null or jaar_van is null or jaar_tot >= jaar_van)" in folded
    assert "unique key uq_literatuur_zotero_item_key (zotero_item_key)" in folded
    assert "primary key (bron_id, volgnummer)" in folded
    print("OK: Meijendel_bronnen-schemacontract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
