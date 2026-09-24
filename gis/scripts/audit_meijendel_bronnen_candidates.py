#!/usr/bin/env python3
"""Audit bronnen zonder betrouwbare locatie per waarneming in Meijendel."""

from __future__ import annotations

import argparse
import csv
import re
import subprocess
from pathlib import Path


RULE_VERSION = "meijendel-ruimtelijke-poort-v3"
KNOWN_CONTEXT_SOURCES = {"duinvallei_opname", "vogelstand_1924"}
REFERENCE_TABLES = {
    "soorten",
    "protocollen",
    "ndff_protocol",
    "richtlijnen",
}
FIELDS = (
    "bron_tabel",
    "recordaantal",
    "jaar_van",
    "jaar_tot",
    "locatiemethode",
    "ruimtelijke_status",
    "tabelrol",
    "migratieadvies",
)


def mysql_command(mysql_login_path: str, database: str, query: str) -> list[str]:
    if not re.fullmatch(r"[A-Za-z0-9_]+", database):
        raise ValueError(f"Ongeldige databasenaam: {database}")
    command = [
        "/usr/local/mysql/bin/mysql",
        f"--login-path={mysql_login_path}",
        "--batch",
        "--skip-column-names",
        "--database",
        database,
        "--execute",
        query,
    ]
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return [line for line in result.stdout.splitlines() if line.strip()]


def fetch_spatial_status(mysql_login_path: str, database: str) -> list[dict]:
    query = f"""
SELECT bron_tabel, COUNT(*), GROUP_CONCAT(DISTINCT locatiemethode),
       GROUP_CONCAT(DISTINCT toelatingsstatus)
FROM meijendel_waarneming_ruimtelijke_status
WHERE regelversie='{RULE_VERSION}'
  AND toelatingsstatus IN ('geen_lokalisatie','context_alleen')
GROUP BY bron_tabel
ORDER BY bron_tabel
"""
    rows: list[dict] = []
    for line in mysql_command(mysql_login_path, database, query):
        table, count, method, status = line.split("\t")
        rows.append(
            {
                "bron_tabel": table,
                "recordaantal": int(count),
                "jaar_van": None,
                "jaar_tot": None,
                "locatiemethode": method,
                "ruimtelijke_status": status,
                "tabelrol": "waarnemingsfeit",
            }
        )

    for row in rows:
        if row["bron_tabel"] == "duinvallei_opname":
            values = mysql_command(
                mysql_login_path,
                database,
                "SELECT MIN(jaar),MAX(jaar),COUNT(*) FROM duinvallei_opname",
            )[0].split("\t")
            row["jaar_van"], row["jaar_tot"] = int(values[0]), int(values[1])
            if int(values[2]) != row["recordaantal"]:
                raise ValueError("Aantal duinvallei_opname wijkt af van ruimtelijke audit")
        elif row["bron_tabel"] == "vogelstand_1924":
            row["jaar_van"] = 1924
            row["jaar_tot"] = 1924
            table_count = int(
                mysql_command(
                    mysql_login_path,
                    database,
                    "SELECT COUNT(*) FROM vogelstand_1924",
                )[0]
            )
            if table_count != row["recordaantal"]:
                raise ValueError("Aantal vogelstand_1924 wijkt af van ruimtelijke audit")
    return rows


def classify_rows(rows: list[dict]) -> list[dict]:
    classified: list[dict] = []
    for source in rows:
        row = dict(source)
        role = row.get("tabelrol") or (
            "referentie" if row.get("bron_tabel") in REFERENCE_TABLES else "waarnemingsfeit"
        )
        row["tabelrol"] = role
        if role == "referentie":
            advice = "nvt_referentietabel"
        elif row.get("bron_tabel") in KNOWN_CONTEXT_SOURCES:
            advice = "verplaatsen"
        else:
            advice = "afzonderlijk_besluit_nodig"
        row["migratieadvies"] = advice
        classified.append(row)
    return classified


def validate_known_sources(rows: list[dict]) -> None:
    found = {str(row.get("bron_tabel")) for row in rows}
    missing = sorted(KNOWN_CONTEXT_SOURCES - found)
    if missing:
        raise ValueError("Bekende bronfamilies ontbreken in audit: " + ", ".join(missing))


def write_csv(rows: list[dict], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mysql-login-path", default="meijendel_root")
    parser.add_argument("--database", default="Meijendel")
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    rows = classify_rows(fetch_spatial_status(args.mysql_login_path, args.database))
    validate_known_sources(rows)
    write_csv(rows, args.output)
    unresolved = [row for row in rows if row["migratieadvies"] == "afzonderlijk_besluit_nodig"]
    print(f"Audit geschreven: {args.output} ({len(rows)} bronfamilies)")
    if unresolved:
        print("BLOKKADE: afzonderlijk besluit nodig voor " + ", ".join(row["bron_tabel"] for row in unresolved))
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
