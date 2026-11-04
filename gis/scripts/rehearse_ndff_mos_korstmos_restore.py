#!/usr/bin/env python3
"""Prove a lossless moss/lichen move and restore in an isolated MySQL schema.

No statement in this script changes Meijendel or Meijendel_ndff_secure.
Only the exact scratch schema below is created and, after success, removed.
"""

from __future__ import annotations

import argparse
import re
import subprocess


SCRATCH = "Meijendel_blwg_herstelproef_20261023"
CLIENT = "/usr/local/mysql/bin/mysql"
BASE = "Meijendel"
GROUPS = ("mossen", "korstmossen")


def sql(query: str) -> list[list[str]]:
    result = subprocess.run(
        [CLIENT, "--login-path=meijendel_root", "--protocol=TCP",
         "--host=127.0.0.1", "--batch", "--raw", "--skip-column-names", "-e", query],
        check=True, capture_output=True, text=True,
    )
    return [line.split("\t") for line in result.stdout.splitlines() if line]


def ident(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", value):
        raise ValueError(f"Ongeldige SQL-identificatie: {value!r}")
    return value


def count(table: str) -> int:
    return int(sql(f"SELECT COUNT(*) FROM {SCRATCH}.{ident(table)}")[0][0])


def checksum(table: str) -> str:
    rows = sql(f"CHECKSUM TABLE {SCRATCH}.{ident(table)}")
    value = rows[0][-1]
    if value in ("NULL", ""):
        raise RuntimeError(f"Geen checksum voor {table}")
    return value


def child_filter(alias: str, columns: tuple[str, ...]) -> str:
    return " OR ".join(
        f"EXISTS (SELECT 1 FROM {SCRATCH}.target_ids i "
        f"WHERE i.waarneming_id={alias}.{ident(column)})"
        for column in columns
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Maak uitsluitend het proefschema aan")
    args = parser.parse_args()
    if not args.apply:
        print(f"DRY RUN: alleen {SCRATCH}; gebruik --apply voor de herstelproef")
        return
    if int(sql(f"SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='{SCRATCH}'")[0][0]):
        raise RuntimeError(f"Proefschema {SCRATCH} bestaat al; niets overschreven")

    sql(f"CREATE SCHEMA {SCRATCH}")
    succeeded = False
    try:
        sql(f"CREATE TABLE {SCRATCH}.target_ids ("
            "waarneming_id BIGINT UNSIGNED NOT NULL PRIMARY KEY, "
            "groep VARCHAR(20) NOT NULL, opslag VARCHAR(40) NOT NULL) ENGINE=InnoDB")
        for group in GROUPS:
            sql(f"INSERT INTO {SCRATCH}.target_ids "
                f"SELECT waarneming_id,'{group}','ndff_open_waarneming' "
                f"FROM {BASE}.ndff_{group}")
        expected = count("target_ids")
        if expected != 60996:
            raise RuntimeError(f"Bronomvang gewijzigd: {expected} in plaats van 60996")

        sql(f"CREATE TABLE {SCRATCH}.backup_parent LIKE {BASE}.ndff_open_waarneming")
        sql(f"INSERT INTO {SCRATCH}.backup_parent "
            f"SELECT o.* FROM {BASE}.ndff_open_waarneming o "
            f"JOIN {SCRATCH}.target_ids i USING(waarneming_id)")
        sql(f"CREATE TABLE {SCRATCH}.working_parent LIKE {BASE}.ndff_open_waarneming")
        sql(f"INSERT INTO {SCRATCH}.working_parent SELECT * FROM {SCRATCH}.backup_parent")
        parent_checksum = checksum("backup_parent")
        if count("backup_parent") != expected or checksum("working_parent") != parent_checksum:
            raise RuntimeError("Eerste bronkopie wijkt af")

        for group in GROUPS:
            sql(f"CREATE TABLE {SCRATCH}.{group}_waarneming LIKE {BASE}.ndff_open_waarneming")

        references = sql(
            "SELECT table_name,column_name FROM information_schema.key_column_usage "
            "WHERE table_schema='Meijendel' AND referenced_table_schema='Meijendel' "
            "AND referenced_table_name='ndff_open_waarneming' "
            "ORDER BY table_name,column_name"
        )
        children: dict[str, list[str]] = {}
        for table, column in references:
            children.setdefault(ident(table), []).append(ident(column))
        for table in ("ndff_mossen", "ndff_korstmossen", "ndff_schimmels", "daz_bmp_recordkandidaat"):
            children.setdefault(table, ["waarneming_id"])

        copied: list[tuple[str, str, str, int]] = []
        for index, (table, columns) in enumerate(sorted(children.items())):
            condition = child_filter("c", tuple(columns))
            relevant = int(sql(f"SELECT COUNT(*) FROM {BASE}.{table} c WHERE {condition}")[0][0])
            if not relevant:
                continue
            backup = f"child_backup_{index:02d}"
            working = f"child_work_{index:02d}"
            sql(f"CREATE TABLE {SCRATCH}.{backup} LIKE {BASE}.{table}")
            sql(f"INSERT INTO {SCRATCH}.{backup} SELECT c.* FROM {BASE}.{table} c WHERE {condition}")
            sql(f"CREATE TABLE {SCRATCH}.{working} LIKE {BASE}.{table}")
            sql(f"INSERT INTO {SCRATCH}.{working} SELECT * FROM {SCRATCH}.{backup}")
            for column in columns:
                sql(f"ALTER TABLE {SCRATCH}.{working} ADD CONSTRAINT fk_test_{index:02d}_{column[:30]} "
                    f"FOREIGN KEY ({column}) REFERENCES {SCRATCH}.target_ids(waarneming_id)")
            if count(backup) != relevant or checksum(backup) != checksum(working):
                raise RuntimeError(f"Kindkopie wijkt af: {table}")
            copied.append((table, backup, working, relevant))

        for group in GROUPS:
            sql(f"INSERT INTO {SCRATCH}.{group}_waarneming "
                f"SELECT p.* FROM {SCRATCH}.working_parent p "
                f"JOIN {SCRATCH}.target_ids i USING(waarneming_id) WHERE i.groep='{group}'")
            original = int(sql(f"SELECT COUNT(*) FROM {BASE}.ndff_{group}")[0][0])
            if count(f"{group}_waarneming") != original:
                raise RuntimeError(f"Fysieke proefverhuizing onvolledig: {group}")
            sql(f"UPDATE {SCRATCH}.target_ids SET opslag='{group}_waarneming' WHERE groep='{group}'")
        sql(f"DELETE FROM {SCRATCH}.working_parent")
        if count("working_parent") or sum(count(f"{g}_waarneming") for g in GROUPS) != expected:
            raise RuntimeError("Proefverhuizing bevat verlies of dubbeling")

        # Herstel de oude parent en alle kinderen uit onafhankelijke proefkopieën.
        sql(f"INSERT INTO {SCRATCH}.working_parent SELECT * FROM {SCRATCH}.backup_parent")
        for _, backup, working, relevant in copied:
            sql(f"DELETE FROM {SCRATCH}.{working}")
            sql(f"INSERT INTO {SCRATCH}.{working} SELECT * FROM {SCRATCH}.{backup}")
            if count(working) != relevant or checksum(backup) != checksum(working):
                raise RuntimeError(f"Kindherstel faalde: {working}")
        for group in GROUPS:
            sql(f"DELETE FROM {SCRATCH}.{group}_waarneming")
        sql(f"UPDATE {SCRATCH}.target_ids SET opslag='ndff_open_waarneming'")
        if count("working_parent") != expected or checksum("working_parent") != parent_checksum:
            raise RuntimeError("Herstel van de oorspronkelijke waarnemingen faalde")
        if any(count(f"{g}_waarneming") for g in GROUPS):
            raise RuntimeError("Na herstel staan nog dubbele proefwaarnemingen")
        print(f"GESLAAGD: {expected} waarnemingen fysiek verhuisd en hersteld; "
              f"{len(copied)} geraakte kindtabellen hersteld; parent-checksum={parent_checksum}")
        for table, _, _, relevant in copied:
            print(f"  {table}: {relevant} koppelregels")
        succeeded = True
    finally:
        if succeeded:
            sql(f"DROP SCHEMA {SCRATCH}")
            print(f"Proefschema {SCRATCH} gecontroleerd verwijderd")
        else:
            print(f"STOP: proefschema {SCRATCH} bewaard voor foutonderzoek; "
                  "levende Meijendel-tabellen zijn niet gewijzigd")


if __name__ == "__main__":
    main()
