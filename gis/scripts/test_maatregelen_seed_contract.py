#!/usr/bin/env python3
"""Integratiecontract voor de eerste bronvaste maatregeleninvoer."""

from __future__ import annotations

import subprocess
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis" / "database" / "maatregelen_schema.sql"
SEED = ROOT / "gis" / "database" / "maatregelen_seed.sql"
TEST_DB = f"meijendel_maatregelen_seed_{uuid.uuid4().hex[:12]}"
MYSQL = "/usr/local/mysql/bin/mysql"


def mysql(sql: str, database: str | None = None) -> str:
    command = [MYSQL, "--login-path=meijendel_root", "--host=127.0.0.1", "--protocol=TCP", "--batch", "--skip-column-names"]
    if database:
        command.append(database)
    result = subprocess.run(command, input=sql, text=True, capture_output=True, check=False)
    if result.returncode:
        raise AssertionError(result.stderr.strip() or result.stdout.strip())
    return result.stdout.strip()


def apply(path: Path) -> None:
    sql = path.read_text(encoding="utf-8").replace("USE Meijendel;", f"USE {TEST_DB};", 1)
    mysql(sql)


def scalar(sql: str) -> int:
    return int(mysql(sql, TEST_DB))


def main() -> int:
    assert SEED.is_file(), f"seed ontbreekt: {SEED}"
    assert int(mysql(f"SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='{TEST_DB}';")) == 0
    mysql(f"CREATE DATABASE {TEST_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;")
    try:
        mysql(
            """
            CREATE TABLE maatregelen (
              id INT NOT NULL,
              code VARCHAR(50) NOT NULL,
              omschrijving TEXT NOT NULL,
              PRIMARY KEY (id),
              UNIQUE KEY uq_maatregelen_code (code)
            ) ENGINE=InnoDB;
            INSERT INTO maatregelen (id, code, omschrijving) VALUES
              (1,'zeereepbeheer','Zeereepbeheer'),
              (2,'maaibeheer_aanvullend','Aanvullend maaibeheer'),
              (3,'begrazing','Begrazing'),
              (4,'exotenbestrijding','Exotenbestrijding'),
              (5,'plaggen_chopperen_afgraven','Plaggen/chopperen/afgraven'),
              (6,'hydrologie_optimaliseren','Optimaliseren hydrologie'),
              (7,'bosreductie_struweelbeheer','Bos- en struweelbeheer'),
              (8,'geomorfologie_herstel_stortplaatsen','Herstel geomorfologie'),
              (9,'strandreservaten','Strandreservaten'),
              (10,'predatorenbeheer','Predatorenbeheer'),
              (11,'rust_en_recreatiebeheer','Rust- en recreatiebeheer');
            CREATE TABLE plots (plot_id INT NOT NULL, PRIMARY KEY (plot_id)) ENGINE=InnoDB;
            """,
            TEST_DB,
        )
        apply(SCHEMA)
        apply(SEED)
        expected = {
            "maatregel_bron": 12,
            "maatregel_project": 12,
            "maatregel_uitvoering": 33,
            "maatregel_uitvoering_jaar": 58,
        }
        before = {table: scalar(f"SELECT COUNT(*) FROM {table};") for table in expected}
        assert before == expected, before
        assert scalar("SELECT COUNT(*) FROM maatregel_uitvoering u LEFT JOIN maatregel_uitvoering_bron b USING (uitvoering_id) WHERE b.uitvoering_id IS NULL;") == 0
        assert scalar("SELECT COUNT(*) FROM maatregel_plot_koppeling;") == 0
        assert scalar("SELECT COUNT(*) FROM maatregel_geometrie;") == 0
        assert scalar("SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast;") == 0
        assert scalar("SELECT COUNT(*) FROM maatregel_uitvoering_jaar uj JOIN maatregel_uitvoering u USING (uitvoering_id) WHERE u.uitvoering_code='pas_23_maaibeheer' AND uj.jaar BETWEEN 2016 AND 2019 AND uj.jaarstatus='niet_uitgevoerd';") == 4
        assert scalar("SELECT COUNT(*) FROM maatregel_uitvoering_jaar uj JOIN maatregel_uitvoering u USING (uitvoering_id) WHERE u.uitvoering_code='pas_23_vogelkers_2020' AND uj.jaar=2020 AND uj.jaarstatus='uitgevoerd';") == 1
        assert scalar("SELECT COUNT(*) FROM maatregel_uitvoering u WHERE u.uitvoering_code='bendel_nabeheer_2026' AND u.uitvoering_status_code='gepland';") == 1
        assert scalar("SELECT COUNT(*) FROM maatregel_uitvoering_jaar uj JOIN maatregel_uitvoering u USING (uitvoering_id) WHERE u.uitvoering_code='bendel_nabeheer_2026';") == 0
        apply(SEED)
        after = {table: scalar(f"SELECT COUNT(*) FROM {table};") for table in expected}
        assert after == before, (before, after)
    finally:
        mysql(f"DROP DATABASE {TEST_DB};")
    print("OK: maatregelen-seed, brondekking en idempotentie")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
