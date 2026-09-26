#!/usr/bin/env python3
"""Installeer de bronoverstijgende analysegeschiktheidslaag in MySQL."""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis" / "database" / "analysegeschiktheid_schema.sql"
SERIES = ROOT / "gis" / "database" / "analyse_datareeks_seed.csv"
DECISIONS = ROOT / "gis" / "database" / "analyse_geschiktheid_seed.csv"
RULE_VERSION = "analyse-catalogus-v1"


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def sql_value(value: str) -> str:
    if value == "":
        return "NULL"
    return "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"


def validate(
    series: list[dict[str, str]], decisions: list[dict[str, str]]
) -> dict[str, int | str]:
    keys = {row["datareeks_sleutel"] for row in series}
    if len(keys) != len(series):
        raise ValueError("datareeks_sleutel is niet uniek")
    if {row["regelversie"] for row in series + decisions} != {RULE_VERSION}:
        raise ValueError("onverwachte regelversie")
    if any(row["datareeks_sleutel"] not in keys for row in decisions):
        raise ValueError("besluit verwijst naar onbekende gegevensreeks")
    ndff_keys = {
        row["datareeks_sleutel"]
        for row in series
        if row["classificatiebron"] == "ndff_v4"
    }
    if any(row["datareeks_sleutel"] in ndff_keys for row in decisions):
        raise ValueError("NDFF-besluiten mogen niet worden gekopieerd")
    return {
        "analyse_types": 5,
        "datareeksen": len(series),
        "generieke_besluiten": len(decisions),
        "ndff_besluiten_gekopieerd": 0,
        "regelversie": RULE_VERSION,
    }


def seed_sql(
    series: list[dict[str, str]], decisions: list[dict[str, str]]
) -> str:
    series_columns = list(series[0])
    decision_columns = [
        "analyse_type_code",
        "protocolgeschiktheid",
        "gegevensgeschiktheid",
        "eindbesluit",
        "voorwaarden",
        "kwaliteitsmelding",
        "regelversie",
        "beoordeeld_op",
    ]
    statements = ["USE Meijendel;", "START TRANSACTION;"]
    for row in series:
        values = ",".join(sql_value(row[column]) for column in series_columns)
        updates = ",".join(
            f"{column}=VALUES({column})"
            for column in series_columns
            if column != "datareeks_sleutel"
        )
        statements.append(
            "INSERT INTO analyse_datareeks ("
            + ",".join(series_columns)
            + f") VALUES ({values}) ON DUPLICATE KEY UPDATE {updates};"
        )
    for row in decisions:
        values = ",".join(sql_value(row[column]) for column in decision_columns)
        updates = ",".join(
            f"{column}=VALUES({column})"
            for column in decision_columns
            if column not in {"analyse_type_code", "regelversie"}
        )
        statements.append(
            "INSERT INTO analyse_datareeks_geschiktheid "
            "(datareeks_id," + ",".join(decision_columns) + ") "
            "SELECT datareeks_id," + values + " FROM analyse_datareeks "
            f"WHERE datareeks_sleutel={sql_value(row['datareeks_sleutel'])} "
            f"ON DUPLICATE KEY UPDATE {updates};"
        )
    statements.extend(
        [
            "COMMIT;",
            "SELECT CASE WHEN (SELECT COUNT(*) FROM analyse_datareeks "
            f"WHERE regelversie='{RULE_VERSION}')={len(series)} "
            "AND (SELECT COUNT(*) FROM analyse_datareeks_geschiktheid "
            f"WHERE regelversie='{RULE_VERSION}')={len(decisions)} "
            "THEN 'OK' ELSE 'FOUT' END AS importstatus;",
        ]
    )
    return "\n".join(statements) + "\n"


def mysql_command(args: argparse.Namespace) -> list[str]:
    return [
        "/usr/local/mysql/bin/mysql",
        f"--login-path={args.login_path}",
        "--protocol=tcp",
        f"--host={args.host}",
        f"--port={args.port}",
        "--batch",
        "--skip-column-names",
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--apply", action="store_true")
    parser.add_argument("--login-path", default="meijendel_root")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3306)
    args = parser.parse_args()

    series = read_rows(SERIES)
    decisions = read_rows(DECISIONS)
    summary = validate(series, decisions)
    if args.dry_run:
        print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
        return 0

    command = mysql_command(args)
    subprocess.run(command, input=SCHEMA.read_text(encoding="utf-8"), text=True, check=True)
    applied = subprocess.run(
        command,
        input=seed_sql(series, decisions),
        text=True,
        capture_output=True,
        check=True,
    )
    if applied.stdout.strip().splitlines()[-1:] != ["OK"]:
        raise RuntimeError(f"importcontrole mislukt: {applied.stdout.strip()}")
    print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
