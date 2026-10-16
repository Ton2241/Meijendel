#!/usr/bin/env python3
"""Contracttest voor het idempotente classificatieherstel van maatregelen."""

from __future__ import annotations

import subprocess
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MIGRATION = ROOT / "Ruimtelijke data" / "15_herstel_datamodel_maatregelen_toegankelijkheid.sql"
TEST_DB = f"meijendel_maatregelen_migratie_{uuid.uuid4().hex[:12]}"
MYSQL = "/usr/local/mysql/bin/mysql"


def mysql(sql: str, database: str | None = None) -> str:
    command = [MYSQL, "--login-path=meijendel_root", "--host=127.0.0.1", "--protocol=TCP", "--batch", "--skip-column-names"]
    if database:
        command.append(database)
    result = subprocess.run(command, input=sql, text=True, capture_output=True, check=False)
    if result.returncode:
        raise AssertionError(result.stderr.strip() or result.stdout.strip())
    return result.stdout.strip()


def apply_migration() -> None:
    sql = MIGRATION.read_text(encoding="utf-8").replace("USE Meijendel;", f"USE {TEST_DB};", 1)
    mysql(sql)


def scalar(sql: str) -> str:
    return mysql(sql, TEST_DB)


def main() -> int:
    assert MIGRATION.is_file(), f"migratie ontbreekt: {MIGRATION}"
    assert int(mysql(f"SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='{TEST_DB}';")) == 0
    mysql(f"CREATE DATABASE {TEST_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;")
    try:
        mysql(
            """
            CREATE TABLE maatregelen (
              id INT NOT NULL AUTO_INCREMENT,
              code VARCHAR(50) NOT NULL,
              maatregelgroep_code VARCHAR(50),
              omschrijving TEXT NOT NULL,
              druk_aandachtspunt TEXT,
              PRIMARY KEY (id), UNIQUE KEY uq_maatregelen_code (code)
            ) ENGINE=InnoDB;
            INSERT INTO maatregelen (id,code,maatregelgroep_code,omschrijving,druk_aandachtspunt) VALUES
              (1,'zeereepbeheer','dynamiek','Zeereepbeheer','Onvoldoende dynamiek'),
              (2,'maaibeheer_aanvullend','vegetatiebeheer','Aanvullend maaibeheer','OVergrassing en\nverstruweling'),
              (3,'begrazing','vegetatiebeheer','Begrazing','Vergrassing'),
              (4,'exotenbestrijding','soortbeheer','Exotenbestrijding','Exotendruk'),
              (5,'plaggen_chopperen_afgraven','bodem_en_vegetatie','Afgraven','Vergrassing'),
              (6,'hydrologie_optimaliseren','hydrologie','Hydrologie','Hydrologie'),
              (7,'bosreductie_struweelbeheer','bos_en_struweel','Bosreductie','Bos'),
              (8,'geomorfologie_herstel_stortplaatsen','geomorfologie','Geomorfologie','Geomorfologie'),
              (9,'strandreservaten','rustmaatregel','Strandreservaten','Onvoldoende rust'),
              (10,'predatorenbeheer','soortbeheer','Predatorenbeheer','Predatiedruk');
            CREATE TABLE maatregelen_kernwoorden (
              id INT NOT NULL AUTO_INCREMENT,
              code VARCHAR(80) NOT NULL,
              kernwoord VARCHAR(120) NOT NULL,
              parent_maatregel_id INT,
              actief TINYINT(1) NOT NULL DEFAULT 1,
              PRIMARY KEY (id), UNIQUE KEY uq_mk_code (code),
              CONSTRAINT fk_mk_parent FOREIGN KEY (parent_maatregel_id) REFERENCES maatregelen(id)
            ) ENGINE=InnoDB;
            INSERT INTO maatregelen_kernwoorden (code,kernwoord,parent_maatregel_id) VALUES
              ('recreatiezonering','Recreatiezonering',9),
              ('honden_aanlijnplicht','HondenAanlijnplicht',9),
              ('parkeerreductie','Parkeerreductie',9),
              ('routing','Routing',9),
              ('kerven_zeereep','KervenZeereep',1);
            CREATE TABLE plot_jaar_maatregel (id INT PRIMARY KEY, maatregel_id INT NOT NULL);
            INSERT INTO plot_jaar_maatregel VALUES (1,3);
            CREATE TABLE plot_jaar_toegankelijkheid_deel (id INT PRIMARY KEY);
            """,
            TEST_DB,
        )
        apply_migration()
        apply_migration()
        assert scalar("SELECT COUNT(*) FROM maatregelen;") == "11"
        assert scalar("SELECT COUNT(*) FROM maatregelen_kernwoorden;") == "6"
        assert scalar("SELECT COUNT(*) FROM plot_jaar_maatregel;") == "1"
        assert scalar("SELECT druk_aandachtspunt FROM maatregelen WHERE code='maaibeheer_aanvullend';") == r"Overgrassing en\nverstruweling"
        assert scalar("SELECT COUNT(*) FROM maatregelen_kernwoorden mk JOIN maatregelen m ON m.id=mk.parent_maatregel_id WHERE mk.code IN ('recreatiezonering','honden_aanlijnplicht','parkeerreductie','routing') AND m.code='rust_en_recreatiebeheer';") == "4"
        assert scalar("SELECT COUNT(*) FROM maatregelen_kernwoorden mk JOIN maatregelen m ON m.id=mk.parent_maatregel_id WHERE mk.code='strandreservaat' AND m.code='strandreservaten';") == "1"
        mysql("DROP TABLE plot_jaar_maatregel; DROP TABLE plot_jaar_toegankelijkheid_deel;", TEST_DB)
        apply_migration()  # De classificatieroute werkt ook na definitieve verwijdering.
    finally:
        mysql(f"DROP DATABASE {TEST_DB};")
    print("OK: classificatieherstel is idempotent en behoudt plot-jaarregels")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
