#!/usr/bin/env python3
"""Integratiecontract voor het bronvaste maatregelenmodel."""

from __future__ import annotations

import subprocess
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis" / "database" / "maatregelen_schema.sql"
TEST_DB = f"meijendel_maatregelen_test_{uuid.uuid4().hex[:12]}"
MYSQL = "/usr/local/mysql/bin/mysql"


def mysql(sql: str, database: str | None = None) -> str:
    command = [MYSQL, "--login-path=meijendel_root", "--host=127.0.0.1", "--protocol=TCP", "--batch", "--skip-column-names"]
    if database:
        command.append(database)
    result = subprocess.run(command, input=sql, text=True, capture_output=True, check=False)
    if result.returncode:
        raise AssertionError(result.stderr.strip() or result.stdout.strip())
    return result.stdout.strip()


def apply_schema() -> None:
    sql = SCHEMA.read_text(encoding="utf-8").replace("USE Meijendel;", f"USE {TEST_DB};", 1)
    mysql(sql)


def scalar(sql: str) -> int:
    return int(mysql(sql, TEST_DB))


def main() -> int:
    assert SCHEMA.is_file(), f"schema ontbreekt: {SCHEMA}"
    assert int(mysql(f"SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='{TEST_DB}';")) == 0
    mysql(f"CREATE DATABASE {TEST_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;")
    try:
        mysql(
            """
            CREATE TABLE maatregelen (
              id INT NOT NULL AUTO_INCREMENT,
              code VARCHAR(50) NOT NULL,
              omschrijving TEXT NOT NULL,
              PRIMARY KEY (id),
              UNIQUE KEY uq_maatregelen_code (code)
            ) ENGINE=InnoDB;
            CREATE TABLE plots (
              plot_id INT NOT NULL,
              PRIMARY KEY (plot_id)
            ) ENGINE=InnoDB;
            """,
            TEST_DB,
        )
        apply_schema()
        required = {
            "maatregel_werkcategorie",
            "maatregel_type",
            "maatregel_activiteit_type",
            "maatregel_uitvoering_status",
            "maatregel_brontype",
            "maatregel_project",
            "maatregel_bron",
            "maatregel_uitvoering",
            "maatregel_uitvoering_jaar",
            "maatregel_uitvoering_bron",
            "maatregel_geometrie",
            "maatregel_plot_koppeling",
        }
        rows = mysql("SHOW FULL TABLES WHERE Table_type='BASE TABLE';", TEST_DB).splitlines()
        actual = {row.split("\t", 1)[0] for row in rows}
        assert required <= actual, sorted(required - actual)
        assert scalar("SELECT COUNT(*) FROM information_schema.views WHERE table_schema=DATABASE() AND table_name='v_plot_jaar_maatregel_bronvast';") == 1
        assert scalar("SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast;") == 0
        assert scalar("SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_schema=DATABASE() AND constraint_type='FOREIGN KEY';") >= 12
        before = scalar("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE();")
        apply_schema()
        after = scalar("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE();")
        assert before == after, (before, after)
        assert scalar("SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast;") == 0
    finally:
        mysql(f"DROP DATABASE {TEST_DB};")
    print("OK: maatregelen-schemacontract en idempotentie")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
