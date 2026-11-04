#!/usr/bin/env python3
"""Gecontroleerde fysieke verhuizing van openbare NDFF-mossen en -korstmossen."""

import argparse
import json
import re
import subprocess
from collections import defaultdict
from pathlib import Path


MYSQL_CLIENT = "/usr/local/mysql/bin/mysql"
MYSQL_ARGS = (
    "--login-path=meijendel_root", "--protocol=TCP", "--host=127.0.0.1",
    "--batch", "--raw", "--skip-column-names",
)
EXPECTED = {"ndff_open_waarneming": 810830,
            "ndff_mossen": 32353, "ndff_korstmossen": 28643}


def query(sql: str) -> list[list[str]]:
    result = subprocess.run(
        [MYSQL_CLIENT, *MYSQL_ARGS, "-e", sql],
        capture_output=True, text=True, check=False,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f"MySQL stopte met {result.returncode}")
    return [line.split("\t") for line in result.stdout.splitlines() if line]


def preflight() -> dict:
    """Read-only live gate; any source or schema drift blocks execution."""
    rows = query("SELECT TABLE_NAME FROM information_schema.TABLES "
                 "WHERE TABLE_SCHEMA='Meijendel' AND TABLE_NAME IN "
                 "('ndff_open_waarneming','ndff_mossen','ndff_korstmossen',"
                 "'ndff_open_waarneming_register','mossen_waarneming',"
                 "'korstmossen_waarneming') ORDER BY TABLE_NAME")
    names = {row[0] for row in rows}
    if names != set(EXPECTED):
        raise RuntimeError(f"Onverwachte tabellen bij voorbereidingscontrole: {sorted(names)}")
    counts = {table: int(query(f"SELECT COUNT(*) FROM `Meijendel`.{_identifier(table)}")[0][0])
              for table in EXPECTED}
    if counts != EXPECTED:
        raise RuntimeError(f"Bronomvang gewijzigd: {counts!r}")
    overlap = int(query("SELECT COUNT(*) FROM Meijendel.ndff_mossen m "
                        "JOIN Meijendel.ndff_korstmossen k USING(waarneming_id)")[0][0])
    if overlap:
        raise RuntimeError(f"Mos en korstmos delen {overlap} openbare IDs")
    missing = int(query("SELECT COUNT(*) FROM ("
                        "SELECT waarneming_id FROM Meijendel.ndff_mossen UNION ALL "
                        "SELECT waarneming_id FROM Meijendel.ndff_korstmossen) g "
                        "LEFT JOIN Meijendel.ndff_open_waarneming o USING(waarneming_id) "
                        "WHERE o.waarneming_id IS NULL")[0][0])
    if missing:
        raise RuntimeError(f"{missing} groepsregels missen hun openbare bronregel")
    fk = query("SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE "
               "WHERE TABLE_SCHEMA='Meijendel' AND REFERENCED_TABLE_SCHEMA='Meijendel' "
               "AND REFERENCED_TABLE_NAME='ndff_open_waarneming'")
    if int(fk[0][0]) != 32:
        raise RuntimeError(f"Aantal bestaande ouder-FK's gewijzigd: {fk[0][0]}")
    return {"status": "alleen_lezen_voorcontrole_geslaagd", "aantallen": counts,
            "te_verhuizen": counts["ndff_mossen"] + counts["ndff_korstmossen"],
            "oude_ouder_fk": 32, "levende_database_gewijzigd": False}


def _identifier(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", value):
        raise ValueError(f"Ongeldige SQL-identificatie: {value!r}")
    return f"`{value}`"


def new_table_sql(schema: str = "Meijendel") -> list[str]:
    """Create only the shared locator and two physical, source-faithful tables."""
    target = _identifier(schema)
    register = f"{target}.`ndff_open_waarneming_register`"
    statements = [
        f"CREATE TABLE {register} ("
        "`waarneming_id` BIGINT UNSIGNED NOT NULL, "
        "`opslag_tabel` ENUM('ndff_open_waarneming','mossen_waarneming',"
        "'korstmossen_waarneming') NOT NULL, "
        "`identiteit_sha256` CHAR(64) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL, "
        "PRIMARY KEY (`waarneming_id`), "
        "UNIQUE KEY `uq_ndff_open_register_identity` (`identiteit_sha256`), "
        "KEY `ix_ndff_open_register_opslag` (`opslag_tabel`)"
        ") ENGINE=InnoDB;"
    ]
    for group in ("mossen", "korstmossen"):
        table = f"{target}.{_identifier(group + '_waarneming')}"
        statements.extend([
            f"CREATE TABLE {table} LIKE {target}.`ndff_open_waarneming`;",
            f"ALTER TABLE {table} MODIFY `waarneming_id` BIGINT UNSIGNED NOT NULL, "
            f"ADD CONSTRAINT `fk_{group}_waarneming_register` "
            f"FOREIGN KEY (`waarneming_id`) REFERENCES {register} (`waarneming_id`) "
            "ON UPDATE NO ACTION ON DELETE NO ACTION, "
            f"ADD CONSTRAINT `fk_{group}_waarneming_batch` "
            f"FOREIGN KEY (`batch_id`) REFERENCES {target}.`ndff_open_import_batch` (`batch_id`) "
            "ON UPDATE NO ACTION ON DELETE NO ACTION, "
            f"ADD CONSTRAINT `fk_{group}_waarneming_soort` "
            f"FOREIGN KEY (`soort_key`) REFERENCES {target}.`ndff_soorten` (`soort_key`) "
            "ON UPDATE NO ACTION ON DELETE NO ACTION;",
        ])
    return statements


def fk_retarget_sql(rows):
    """Behoud iedere restrictieve FK, maar wijzig zijn fysieke ouder."""
    by_table = defaultdict(list)
    for table, constraint, column, update_rule, delete_rule in rows:
        for value in (table, constraint, column):
            _identifier(value)
        if (update_rule, delete_rule) != ("NO ACTION", "NO ACTION"):
            raise ValueError(f"Niet-restrictieve bestaande verwijzing: {table}.{column}")
        by_table[table].append((constraint, column))
    statements = []
    for table, constraints in sorted(by_table.items()):
        drops = [f"DROP FOREIGN KEY {_identifier(name)}" for name, _ in constraints]
        additions = [
            f"ADD CONSTRAINT {_identifier(name + '_mk')} FOREIGN KEY ({_identifier(column)}) "
            "REFERENCES `Meijendel`.`ndff_open_waarneming_register` (`waarneming_id`) "
            "ON UPDATE NO ACTION ON DELETE NO ACTION"
            for name, column in constraints
        ]
        if any(len(name + '_mk') > 64 for name, _ in constraints):
            raise ValueError(f"Nieuwe FK-naam te lang: {table}")
        statements.append(
            f"ALTER TABLE `Meijendel`.{_identifier(table)} " + ", ".join(additions) + ";"
        )
        statements.append(
            f"ALTER TABLE `Meijendel`.{_identifier(table)} " + ", ".join(drops) + ";"
        )
    return statements


def swap_procedure_sql(schema: str, *, original: int, mosses: int,
                       lichens: int) -> str:
    """Atomic pointer switch and source deletion; all checks precede COMMIT."""
    db = _identifier(schema)
    if min(original, mosses, lichens) < 1 or mosses + lichens >= original:
        raise ValueError("Ongeldige verwachte bronverdeling")
    procedure = f"{db}.`sp_ndff_blwg_swap_20261023`"
    parent = f"{db}.`ndff_open_waarneming`"
    register = f"{db}.`ndff_open_waarneming_register`"
    moss_table = f"{db}.`mossen_waarneming`"
    lichen_table = f"{db}.`korstmossen_waarneming`"
    return f"""
DELIMITER $$
CREATE PROCEDURE {procedure}()
BEGIN
  DECLARE cq_n BIGINT UNSIGNED DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  START TRANSACTION;
  UPDATE {register} r JOIN {db}.`ndff_mossen` i
    ON i.waarneming_id=r.waarneming_id
    SET r.opslag_tabel='mossen_waarneming';
  UPDATE {register} r JOIN {db}.`ndff_korstmossen` i
    ON i.waarneming_id=r.waarneming_id
    SET r.opslag_tabel='korstmossen_waarneming';
  DELETE o FROM {parent} o JOIN {register} r
    ON r.waarneming_id=o.waarneming_id
    WHERE r.opslag_tabel<>'ndff_open_waarneming';
  SELECT COUNT(*) INTO cq_n FROM {parent};
  IF cq_n<>{original-mosses-lichens} THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='NDFF-restbron telt onjuist';
  END IF;
  SELECT COUNT(*) INTO cq_n FROM {moss_table};
  IF cq_n<>{mosses} THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='NDFF-mossen tellen onjuist';
  END IF;
  SELECT COUNT(*) INTO cq_n FROM {lichen_table};
  IF cq_n<>{lichens} THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='NDFF-korstmossen tellen onjuist';
  END IF;
  SELECT COUNT(*) INTO cq_n FROM {register};
  IF cq_n<>{original} THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='NDFF-register telt onjuist';
  END IF;
  SELECT COUNT(*) INTO cq_n FROM {register} r
    LEFT JOIN {parent} o ON o.waarneming_id=r.waarneming_id
      AND r.opslag_tabel='ndff_open_waarneming'
    LEFT JOIN {moss_table} m ON m.waarneming_id=r.waarneming_id
      AND r.opslag_tabel='mossen_waarneming'
    LEFT JOIN {lichen_table} k ON k.waarneming_id=r.waarneming_id
      AND r.opslag_tabel='korstmossen_waarneming'
    WHERE COALESCE(o.waarneming_id,m.waarneming_id,k.waarneming_id) IS NULL
       OR r.identiteit_sha256<>COALESCE(o.identiteit_sha256,
                                        m.identiteit_sha256,k.identiteit_sha256);
  IF cq_n<>0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='NDFF-register mist bronregel';
  END IF;
  COMMIT;
END$$
DELIMITER ;
CALL {procedure}();
DROP PROCEDURE {procedure};
"""


def prepared_counts() -> dict:
    """Read-only gate for the still-reversible, fully copied preparation."""
    expected = {
        "ndff_open_waarneming_register": EXPECTED["ndff_open_waarneming"],
        "mossen_waarneming": EXPECTED["ndff_mossen"],
        "korstmossen_waarneming": EXPECTED["ndff_korstmossen"],
    }
    actual = {table: int(query(f"SELECT COUNT(*) FROM Meijendel.{_identifier(table)}")[0][0])
              for table in expected}
    if actual != expected:
        raise RuntimeError(f"Voorbereide kopieën zijn onvolledig: {actual}")
    for group in ("mossen", "korstmossen"):
        table = group + "_waarneming"
        index = "ndff_" + group
        mismatch = int(query(
            f"SELECT COUNT(*) FROM Meijendel.{_identifier(index)} i "
            f"LEFT JOIN Meijendel.{_identifier(table)} g USING(waarneming_id) "
            "JOIN Meijendel.ndff_open_waarneming o ON o.waarneming_id=i.waarneming_id "
            "WHERE g.waarneming_id IS NULL OR g.identiteit_sha256<>o.identiteit_sha256 "
            "OR NOT (ST_AsWKB(g.openbare_geometrie)<=>ST_AsWKB(o.openbare_geometrie))"
        )[0][0])
        if mismatch:
            raise RuntimeError(f"{table}: {mismatch} bron- of geometrieverschillen")
    return actual


def prepare_live() -> dict:
    """Create and fill target copies; never delete or redirect live source rows."""
    preflight()
    for statement in new_table_sql():
        query(statement)
    query("INSERT INTO Meijendel.ndff_open_waarneming_register "
          "(waarneming_id,opslag_tabel,identiteit_sha256) "
          "SELECT waarneming_id,'ndff_open_waarneming',identiteit_sha256 "
          "FROM Meijendel.ndff_open_waarneming")
    for group in ("mossen", "korstmossen"):
        query(f"INSERT INTO Meijendel.{_identifier(group + '_waarneming')} "
              "SELECT o.* FROM Meijendel.ndff_open_waarneming o "
              f"JOIN Meijendel.{_identifier('ndff_' + group)} i "
              "ON i.waarneming_id=o.waarneming_id")
    return {"status": "voorbereid_bron_blijft_ongewijzigd",
            "aantallen": prepared_counts()}


def _mysql_script(script: str, database: str) -> None:
    result = subprocess.run([MYSQL_CLIENT, *MYSQL_ARGS, database], input=script,
                            text=True, capture_output=True, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "MySQL-script mislukt")


def _fk_rows() -> list[list[str]]:
    return query("SELECT k.TABLE_NAME,k.CONSTRAINT_NAME,k.COLUMN_NAME,"
                 "rc.UPDATE_RULE,rc.DELETE_RULE "
                 "FROM information_schema.KEY_COLUMN_USAGE k "
                 "JOIN information_schema.REFERENTIAL_CONSTRAINTS rc "
                 "ON rc.CONSTRAINT_SCHEMA=k.CONSTRAINT_SCHEMA "
                 "AND rc.TABLE_NAME=k.TABLE_NAME "
                 "AND rc.CONSTRAINT_NAME=k.CONSTRAINT_NAME "
                 "WHERE k.TABLE_SCHEMA='Meijendel' "
                 "AND k.REFERENCED_TABLE_SCHEMA='Meijendel' "
                 "AND k.REFERENCED_TABLE_NAME='ndff_open_waarneming' "
                 "ORDER BY k.TABLE_NAME,k.CONSTRAINT_NAME")


def _install_central_guards() -> None:
    from import_external_ecology_sources import (central_query_routes,
                                                  central_query_triggers_sql)
    rows = query("SELECT TABLE_NAME,COLUMN_NAME FROM information_schema.COLUMNS "
                 "WHERE TABLE_SCHEMA='Meijendel' AND TABLE_NAME IN "
                 "(SELECT TABLE_NAME FROM information_schema.TABLES "
                 "WHERE TABLE_SCHEMA='Meijendel' AND TABLE_TYPE='BASE TABLE') "
                 "ORDER BY TABLE_NAME,ORDINAL_POSITION")
    schema = defaultdict(set)
    for table, column in rows:
        schema[table].add(column)
    _mysql_script(central_query_triggers_sql({"routes": central_query_routes(schema)}),
                  "Meijendel")


def _update_secure_canonical_view() -> None:
    source = (Path(__file__).parents[1] / "database" / "ndff_secure_schema.sql").read_text()
    marker = "CREATE OR REPLACE VIEW v_ndff_canonieke_waarneming AS"
    end = "CREATE OR REPLACE VIEW v_ndff_analyse_record AS"
    sql = marker + source.split(marker, 1)[1].split(end, 1)[0]
    sql = sql.rsplit(";", 1)[0].strip() + ";"
    query("USE Meijendel_ndff_secure; " + sql)


def switch_live() -> dict:
    """Checked, recoverable DDL first; one transactional physical switch last."""
    prepared_counts()
    baseline = {table: int(query(f"SELECT COUNT(*) FROM Meijendel.{_identifier(table)}")[0][0])
                for table in EXPECTED}
    if baseline != EXPECTED:
        raise RuntimeError(f"Bronverdeling is sinds de voorbereiding veranderd: {baseline}")
    old_fks = _fk_rows()
    new_fk_count = int(query("SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE "
                             "WHERE TABLE_SCHEMA='Meijendel' AND "
                             "REFERENCED_TABLE_NAME='ndff_open_waarneming_register'")[0][0])
    if (len(old_fks), new_fk_count) not in ((32, 2), (0, 34)):
        raise RuntimeError(f"FK-voorcontrole: {len(old_fks)} oude, {new_fk_count} nieuwe")
    secure_before = int(query("SELECT COUNT(*) FROM "
                              "Meijendel_ndff_secure.v_ndff_canonieke_waarneming")[0][0])
    if old_fks:
        for statement in fk_retarget_sql(old_fks):
            query(statement)
    if _fk_rows():
        raise RuntimeError("Er verwijzen nog externe sleutels naar de oude ouder")
    _install_central_guards()
    _update_secure_canonical_view()
    secure_ready = int(query("SELECT COUNT(*) FROM "
                             "Meijendel_ndff_secure.v_ndff_canonieke_waarneming")[0][0])
    if secure_ready != secure_before:
        raise RuntimeError(f"Beveiligde logische selectie wijkt vóór omschakeling af: "
                           f"{secure_before}->{secure_ready}")
    _mysql_script(swap_procedure_sql("Meijendel", original=EXPECTED["ndff_open_waarneming"],
                                     mosses=EXPECTED["ndff_mossen"],
                                     lichens=EXPECTED["ndff_korstmossen"]), "Meijendel")
    physical = {table: int(query(f"SELECT COUNT(*) FROM Meijendel.{_identifier(table)}")[0][0])
                for table in ("ndff_open_waarneming", "mossen_waarneming",
                              "korstmossen_waarneming", "ndff_open_waarneming_register")}
    if physical != {"ndff_open_waarneming": 749834,
                    "mossen_waarneming": 32353,
                    "korstmossen_waarneming": 28643,
                    "ndff_open_waarneming_register": 810830}:
        raise RuntimeError(f"Fysieke eindverdeling wijkt af: {physical}")
    secure_after = int(query("SELECT COUNT(*) FROM "
                             "Meijendel_ndff_secure.v_ndff_canonieke_waarneming")[0][0])
    if secure_after != secure_before:
        raise RuntimeError(f"Beveiligde logische selectie wijkt na omschakeling af: "
                           f"{secure_before}->{secure_after}")
    # The ID-only indexes have now been proved redundant. Remove them last.
    for group in ("mossen", "korstmossen"):
        query(f"DROP TABLE Meijendel.{_identifier('ndff_' + group)}")
    _install_central_guards()
    return {"status": "fysiek_verhuisd_en_gecontroleerd", "aantallen": physical,
            "beveiligde_logische_waarnemingen": secure_after,
            "oude_groepsindexen_verwijderd": True}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preflight", action="store_true",
                        help="Controleer de levende bronnen; schrijf niets")
    parser.add_argument("--prepare-live", action="store_true",
                        help="Maak en controleer kopieën; verplaats nog geen bronregels")
    parser.add_argument("--check-prepared", action="store_true",
                        help="Controleer voorbereide kopieën zonder wijziging")
    parser.add_argument("--switch-live", action="store_true",
                        help="Verplaats bronregels atomair en verwijder ID-indexen als laatste")
    options = parser.parse_args()
    if sum((options.preflight, options.prepare_live, options.check_prepared,
            options.switch_live)) != 1:
        parser.error("Kies precies één expliciete migratiefase")
    result = (preflight() if options.preflight else
              prepare_live() if options.prepare_live else
              switch_live() if options.switch_live else prepared_counts())
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
