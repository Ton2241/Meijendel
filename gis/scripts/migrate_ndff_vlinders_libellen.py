#!/usr/bin/env python3
"""Gecontroleerde fysieke NDFF-verhuizing van vlinders en libellen."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import re
import subprocess
from collections import defaultdict
from pathlib import Path


BUTTERFLY_GROUPS = frozenset(("Dagvlinders", "Nachtvlinders", "Microvlinders"))
DAY_ROUTE_TO_TOVE = {
    1: 929,
    2: 393,
    3: 4588,
    4: 638,
    5: 640,
    6: 1149,
    8: 4615,
    9: 4439,
    10: 635,
    11: 4410,
}
LIBEL_ROUTE_TO_TOVE = {
    1: 8,
    3: 7,
    4: 6,
    5: 3,
    6: 5,
    7: 4,
    8: 5,
    9: 3,
}
MYSQL_CLIENT = "/usr/local/mysql/bin/mysql"
MYSQL_ARGS = (
    "--login-path=meijendel_root", "--protocol=TCP", "--host=127.0.0.1",
    "--batch", "--raw", "--skip-column-names",
)
INDEX_COUNTS = {
    "ndff_dagvlinders": 129_238,
    "ndff_nachtvlinders": 72_978,
    "ndff_microvlinders": 22_849,
    "ndff_libellen": 32_325,
}
EXPECTED_PARENT_BEFORE = 749_834
EXPECTED_PARENT_AFTER = 492_444
EXPECTED_BUTTERFLIES = 225_065
EXPECTED_LIBELS = 32_325
EXPECTED_REGISTER = 810_830
EXPECTED_CANONICAL = 810_983
TARGET_TABLES = ("vlinders_waarneming", "libellen_waarneming")
LINK_TABLES = ("vlinders_waarneming_routekoppeling", "libellen_waarneming_routekoppeling")


def partition_for_group(group: str) -> str | None:
    if group in BUTTERFLY_GROUPS:
        return "vlinders_waarneming"
    if group == "Libellen":
        return "libellen_waarneming"
    return None


def classify_vlinder_family(
    family_id: int | None, year: int, dutch_name: str
) -> tuple[int | None, str]:
    if family_id is None:
        return None, "geen_ndff_route"
    if family_id == 7:
        return None, "voorlinden_aannemelijk"
    if family_id == 3 and dutch_name == "Eikenpage":
        if year in (2017, 2022):
            return 5169, "tove_routejaar_aannemelijk"
        return None, "geen_tove_object"
    code = DAY_ROUTE_TO_TOVE.get(family_id)
    return (code, "tove_routejaar_aannemelijk") if code is not None else (None, "geen_tove_object")


def classify_libel_family(family_id: int | None) -> tuple[int | None, str]:
    if family_id is None:
        return None, "geen_ndff_route"
    if family_id == 2:
        return None, "twee_poelen_onbeslist"
    code = LIBEL_ROUTE_TO_TOVE.get(family_id)
    return (code, "tove_locatiejaar_aannemelijk") if code is not None else (None, "geen_tove_object")


def ident(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", value):
        raise ValueError(f"Ongeldige SQL-identificatie: {value!r}")
    return f"`{value}`"


def query(sql: str) -> list[list[str]]:
    result = subprocess.run([MYSQL_CLIENT, *MYSQL_ARGS, "-e", sql],
                            capture_output=True, text=True, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f"MySQL stopte met {result.returncode}")
    return [line.split("\t") for line in result.stdout.splitlines() if line]


def scalar(sql: str) -> int:
    return int(query(sql)[0][0])


def mysql_script(script: str, database: str = "Meijendel") -> None:
    result = subprocess.run([MYSQL_CLIENT, *MYSQL_ARGS, database], input=script,
                            capture_output=True, text=True, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "MySQL-script mislukt")


def table_names() -> set[str]:
    return {row[0] for row in query(
        "SELECT TABLE_NAME FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA='Meijendel' AND TABLE_TYPE='BASE TABLE'"
    )}


def group_counts() -> dict[str, int]:
    return {name: scalar(f"SELECT COUNT(*) FROM Meijendel.{ident(name)}")
            for name in INDEX_COUNTS}


def preflight() -> dict:
    names = table_names()
    needed = set(INDEX_COUNTS) | {"ndff_open_waarneming", "ndff_open_waarneming_register"}
    if not needed <= names or set(TARGET_TABLES + LINK_TABLES) & names:
        raise RuntimeError("Onverwachte fysieke tabellen voor de voorcontrole")
    referencing = query(
        "SELECT TABLE_NAME,CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE "
        "WHERE REFERENCED_TABLE_SCHEMA='Meijendel' "
        "AND REFERENCED_TABLE_NAME='ndff_open_waarneming'"
    )
    if referencing:
        raise RuntimeError(f"Nog foreign keys naar de oude NDFF-bron: {referencing}")
    counts = group_counts()
    if counts != INDEX_COUNTS:
        raise RuntimeError(f"Bronindexen zijn veranderd: {counts}")
    if scalar("SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming") != EXPECTED_PARENT_BEFORE:
        raise RuntimeError("NDFF-ouderomvang is veranderd")
    if scalar("SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming_register") != EXPECTED_REGISTER:
        raise RuntimeError("NDFF-registeromvang is veranderd")
    union = " UNION ALL ".join(
        f"SELECT waarneming_id FROM Meijendel.{ident(table)}" for table in INDEX_COUNTS
    )
    if scalar(f"SELECT COUNT(DISTINCT waarneming_id) FROM ({union}) i") != sum(INDEX_COUNTS.values()):
        raise RuntimeError("Een waarneming staat in meer dan één te verhuizen groepsindex")
    missing = scalar(
        f"SELECT COUNT(*) FROM ({union}) i "
        "LEFT JOIN Meijendel.ndff_open_waarneming o USING(waarneming_id) "
        "LEFT JOIN Meijendel.ndff_open_waarneming_register r USING(waarneming_id) "
        "WHERE o.waarneming_id IS NULL OR r.opslag_tabel<>'ndff_open_waarneming' "
        "OR r.identiteit_sha256<>o.identiteit_sha256"
    )
    if missing:
        raise RuntimeError(f"{missing} bron- of registerkoppelingen ontbreken")
    if scalar("SELECT COUNT(*) FROM Meijendel_ndff_secure.v_ndff_canonieke_waarneming") != EXPECTED_CANONICAL:
        raise RuntimeError("De canonieke beveiligde selectie is veranderd")
    return {"status": "voorcontrole_geslaagd", "groepen": counts,
            "te_verhuizen": sum(counts.values()), "database_gewijzigd": False}


def check_backup(path: Path, expected_sha256: str) -> dict:
    if path.parent.resolve() != Path(
        "/Volumes/T7 Data/Home_Ton/Meijendel data/Backups-archief/Meijendel"
    ).resolve():
        raise RuntimeError("Herstelkopie staat niet op de afgesproken T7-locatie")
    sha = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            sha.update(block)
    if sha.hexdigest() != expected_sha256:
        raise RuntimeError("Herstelkopie heeft een andere SHA-256")
    with gzip.open(path, "rb") as source:
        while source.read(1024 * 1024):
            pass
    return {"pad": str(path), "bytes": path.stat().st_size, "sha256": sha.hexdigest()}


def new_source_table_sql(group: str) -> list[str]:
    table = f"Meijendel.{ident(group + '_waarneming')}"
    return [
        f"CREATE TABLE {table} LIKE Meijendel.ndff_open_waarneming",
        f"ALTER TABLE {table} MODIFY waarneming_id BIGINT UNSIGNED NOT NULL, "
        f"ADD CONSTRAINT {ident('fk_' + group + '_w_register')} "
        "FOREIGN KEY (waarneming_id) REFERENCES Meijendel.ndff_open_waarneming_register(waarneming_id), "
        f"ADD CONSTRAINT {ident('fk_' + group + '_w_batch')} "
        "FOREIGN KEY (batch_id) REFERENCES Meijendel.ndff_open_import_batch(batch_id), "
        f"ADD CONSTRAINT {ident('fk_' + group + '_w_soort')} "
        "FOREIGN KEY (soort_key) REFERENCES Meijendel.ndff_soorten(soort_key)",
    ]


def _route_case(column: str, mapping: dict[int, int]) -> str:
    parts = " ".join(f"WHEN {key} THEN {value}" for key, value in sorted(mapping.items()))
    return f"CASE {column} {parts} ELSE NULL END"


def route_link_schema_sql() -> list[str]:
    return [
        """CREATE TABLE Meijendel.vlinders_waarneming_routekoppeling (
          waarneming_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
          reconstructieversie VARCHAR(64) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
          bezoek_sleutel CHAR(64) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
          bron_code SMALLINT UNSIGNED NULL,
          jaar SMALLINT UNSIGNED NULL,
          koppelstatus ENUM('tove_routejaar_aannemelijk','voorlinden_aannemelijk',
            'ndff_route_zonder_tove_jaar','geen_ndff_route') NOT NULL,
          geometriebewijs ENUM('eigen_geometrie','alleen_bezoekinterval') NOT NULL,
          KEY ix_vlinders_waarneming_tove (bron_code,jaar),
          CONSTRAINT fk_vlinders_waarneming_route_bron FOREIGN KEY (waarneming_id)
            REFERENCES Meijendel.vlinders_waarneming(waarneming_id),
          CONSTRAINT fk_vlinders_waarneming_route_bezoek FOREIGN KEY (reconstructieversie,bezoek_sleutel)
            REFERENCES Meijendel.ndff_vlinder_bezoek(reconstructieversie,bezoek_sleutel),
          CONSTRAINT fk_vlinders_waarneming_route_jaar FOREIGN KEY (bron_code,jaar)
            REFERENCES Meijendel.vlinders_dag_routejaar(bron_code,jaar),
          CONSTRAINT ck_vlinders_tove_pair CHECK ((bron_code IS NULL AND jaar IS NULL)
            OR (bron_code IS NOT NULL AND jaar IS NOT NULL))
        ) ENGINE=InnoDB""",
        """CREATE TABLE Meijendel.libellen_waarneming_routekoppeling (
          waarneming_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
          reconstructieversie VARCHAR(64) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
          bezoek_sleutel CHAR(64) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
          telobject_id SMALLINT UNSIGNED NULL,
          jaar SMALLINT UNSIGNED NULL,
          koppelstatus ENUM('tove_locatiejaar_aannemelijk','twee_poelen_onbeslist',
            'ndff_route_zonder_tove_jaar','geen_ndff_route') NOT NULL,
          geometriebewijs ENUM('eigen_geometrie','alleen_bezoekinterval') NOT NULL,
          KEY ix_libellen_waarneming_tove (telobject_id,jaar),
          CONSTRAINT fk_libellen_waarneming_route_bron FOREIGN KEY (waarneming_id)
            REFERENCES Meijendel.libellen_waarneming(waarneming_id),
          CONSTRAINT fk_libellen_waarneming_route_bezoek FOREIGN KEY (reconstructieversie,bezoek_sleutel)
            REFERENCES Meijendel.ndff_libel_bezoek(reconstructieversie,bezoek_sleutel),
          CONSTRAINT fk_libellen_waarneming_route_jaar FOREIGN KEY (telobject_id,jaar)
            REFERENCES Meijendel.libellen_routejaar(telobject_id,jaar),
          CONSTRAINT ck_libellen_tove_pair CHECK ((telobject_id IS NULL AND jaar IS NULL)
            OR (telobject_id IS NOT NULL AND jaar IS NOT NULL))
        ) ENGINE=InnoDB""",
    ]


def visit_key_expr(alias: str) -> str:
    return ("SHA2(CONCAT(DATE_FORMAT(" + alias + ".periode_start,'%Y-%m-%d %H:%i:%s'),"
            "'|',DATE_FORMAT(" + alias + ".periode_stop,'%Y-%m-%d %H:%i:%s')),256)")


def route_link_insert_sql() -> list[str]:
    day_case = _route_case("b.routefamilie_id", DAY_ROUTE_TO_TOVE)
    eikenpage = ("CASE WHEN b.routefamilie_id=3 AND o.nederlandse_naam='Eikenpage' "
                 "AND o.jaar IN (2017,2022) THEN 5169 "
                 "WHEN b.routefamilie_id=3 AND o.nederlandse_naam='Eikenpage' THEN NULL "
                 "ELSE " + day_case + " END")
    libel_case = _route_case("b.routefamilie_id", LIBEL_ROUTE_TO_TOVE)
    return [
        f"""INSERT INTO Meijendel.vlinders_waarneming_routekoppeling
            (waarneming_id,reconstructieversie,bezoek_sleutel,bron_code,jaar,koppelstatus,geometriebewijs)
          SELECT o.waarneming_id,b.reconstructieversie,b.bezoek_sleutel,y.bron_code,y.jaar,
            CASE WHEN b.routefamilie_id=7 THEN 'voorlinden_aannemelijk'
                 WHEN b.routefamilie_id IS NULL THEN 'geen_ndff_route'
                 WHEN y.bron_code IS NOT NULL THEN 'tove_routejaar_aannemelijk'
                 ELSE 'ndff_route_zonder_tove_jaar' END,
            CASE WHEN g.geometrie_sha256 IS NOT NULL THEN 'eigen_geometrie'
                 ELSE 'alleen_bezoekinterval' END
          FROM Meijendel.vlinders_waarneming o
          JOIN Meijendel.ndff_vlinder_bezoek b
            ON b.reconstructieversie='ndff-vlinderroute-v2'
           AND b.bezoek_sleutel={visit_key_expr('o')}
          LEFT JOIN Meijendel.ndff_vlinder_routegeometrie g
            ON g.reconstructieversie=b.reconstructieversie
           AND g.routefamilie_id=b.routefamilie_id
           AND g.geometrie_sha256=o.openbare_geometrie_sha256
          LEFT JOIN Meijendel.vlinders_dag_routejaar y
            ON y.bron_code={eikenpage} AND y.jaar=o.jaar
          WHERE o.protocol LIKE '03.201%'
            AND o.soortgroep_raw IN ('Dagvlinders','Nachtvlinders')""",
        f"""INSERT INTO Meijendel.libellen_waarneming_routekoppeling
            (waarneming_id,reconstructieversie,bezoek_sleutel,telobject_id,jaar,koppelstatus,geometriebewijs)
          SELECT o.waarneming_id,b.reconstructieversie,b.bezoek_sleutel,y.telobject_id,y.jaar,
            CASE WHEN b.routefamilie_id=2 THEN 'twee_poelen_onbeslist'
                 WHEN b.routefamilie_id IS NULL THEN 'geen_ndff_route'
                 WHEN y.telobject_id IS NOT NULL THEN 'tove_locatiejaar_aannemelijk'
                 ELSE 'ndff_route_zonder_tove_jaar' END,
            CASE WHEN g.geometrie_sha256 IS NOT NULL THEN 'eigen_geometrie'
                 ELSE 'alleen_bezoekinterval' END
          FROM Meijendel.libellen_waarneming o
          JOIN Meijendel.ndff_libel_bezoek b
            ON b.reconstructieversie='ndff-libellenroute-v1'
           AND b.bezoek_sleutel={visit_key_expr('o')}
          LEFT JOIN Meijendel.ndff_libel_routegeometrie g
            ON g.reconstructieversie=b.reconstructieversie
           AND g.routefamilie_id=b.routefamilie_id
           AND g.geometrie_sha256=o.openbare_geometrie_sha256
          LEFT JOIN Meijendel.libellen_routejaar y
            ON y.telobject_id={libel_case} AND y.jaar=o.jaar
          WHERE o.protocol LIKE '07.201%' AND o.soortgroep_raw='Libellen'""",
    ]


def prepared_counts() -> dict:
    expected = {
        "vlinders_waarneming": EXPECTED_BUTTERFLIES,
        "libellen_waarneming": EXPECTED_LIBELS,
        "vlinders_waarneming_routekoppeling": 80_998,
        "libellen_waarneming_routekoppeling": 3_280,
    }
    names = table_names()
    if not set(expected) <= names:
        raise RuntimeError("De voorbereidende bron- en koppeltabellen ontbreken")
    actual = {table: scalar(f"SELECT COUNT(*) FROM Meijendel.{ident(table)}")
              for table in expected}
    if actual != expected:
        raise RuntimeError(f"Voorbereide tabellen zijn onvolledig: {actual}")
    for group, table in (("Dagvlinders", "vlinders_waarneming"),
                         ("Nachtvlinders", "vlinders_waarneming"),
                         ("Microvlinders", "vlinders_waarneming"),
                         ("Libellen", "libellen_waarneming")):
        index = "ndff_" + group.lower()
        mismatch = scalar(
            f"SELECT COUNT(*) FROM Meijendel.{ident(index)} i "
            f"JOIN Meijendel.ndff_open_waarneming o USING(waarneming_id) "
            f"LEFT JOIN Meijendel.{ident(table)} g USING(waarneming_id) "
            "WHERE g.waarneming_id IS NULL OR g.identiteit_sha256<>o.identiteit_sha256 "
            "OR NOT (g.raw_payload<=>o.raw_payload) "
            "OR NOT (ST_AsWKB(g.openbare_geometrie)<=>ST_AsWKB(o.openbare_geometrie)) "
            "OR NOT (g.analyse_status<=>o.analyse_status) OR NOT (g.pq_status<=>o.pq_status) "
            "OR NOT (g.soort_key<=>o.soort_key) OR NOT (g.periode_start<=>o.periode_start)"
        )
        if mismatch:
            raise RuntimeError(f"{group}: {mismatch} ontbrekende of gewijzigde bronregels")
    if scalar("SELECT COUNT(*) FROM Meijendel.vlinders_waarneming_routekoppeling "
              "WHERE koppelstatus='voorlinden_aannemelijk'") != 2_219:
        raise RuntimeError("Voorlinden-koppeling bevat niet alle 2.219 NDFF-regels")
    if scalar("SELECT COUNT(*) FROM Meijendel.libellen_waarneming_routekoppeling "
              "WHERE koppelstatus='twee_poelen_onbeslist'") != 526:
        raise RuntimeError("De Hertenkamp-poelen zijn onterecht samengevoegd")
    if scalar("SELECT COUNT(*) FROM Meijendel.vlinders_waarneming_routekoppeling "
              "WHERE koppelstatus='voorlinden_aannemelijk' AND bron_code IS NOT NULL"):
        raise RuntimeError("Voorlinden mag niet aan een niet-geleverde Tove-reeks hangen")
    return actual


def prepare_live(backup: Path, backup_sha256: str) -> dict:
    preflight()
    proof = check_backup(backup, backup_sha256)
    for group in ("vlinders", "libellen"):
        for statement in new_source_table_sql(group):
            query(statement)
    for group in ("dagvlinders", "nachtvlinders", "microvlinders"):
        query("INSERT INTO Meijendel.vlinders_waarneming "
              "SELECT o.* FROM Meijendel.ndff_open_waarneming o "
              f"JOIN Meijendel.{ident('ndff_' + group)} i USING(waarneming_id)")
    query("INSERT INTO Meijendel.libellen_waarneming "
          "SELECT o.* FROM Meijendel.ndff_open_waarneming o "
          "JOIN Meijendel.ndff_libellen i USING(waarneming_id)")
    for statement in route_link_schema_sql() + route_link_insert_sql():
        query(statement)
    return {"status": "bronkopie_voorbereid_nog_niets_verwijderd",
            "aantallen": prepared_counts(), "herstelkopie": proof}


def install_central_guards() -> None:
    from import_external_ecology_sources import central_query_routes, central_query_triggers_sql

    schema = defaultdict(set)
    for table, column in query(
        "SELECT c.TABLE_NAME,c.COLUMN_NAME FROM information_schema.COLUMNS c "
        "JOIN information_schema.TABLES t ON t.TABLE_SCHEMA=c.TABLE_SCHEMA "
        "AND t.TABLE_NAME=c.TABLE_NAME "
        "WHERE c.TABLE_SCHEMA='Meijendel' AND t.TABLE_TYPE='BASE TABLE' "
        "ORDER BY c.TABLE_NAME,c.ORDINAL_POSITION"
    ):
        schema[table].add(column)
    mysql_script(central_query_triggers_sql({"routes": central_query_routes(schema)}))


def update_secure_canonical_view() -> None:
    source = (Path(__file__).parents[1] / "database" / "ndff_secure_schema.sql").read_text()
    marker = "CREATE OR REPLACE VIEW v_ndff_canonieke_waarneming AS"
    end = "CREATE OR REPLACE VIEW v_ndff_analyse_record AS"
    sql = marker + source.split(marker, 1)[1].split(end, 1)[0]
    query("USE Meijendel_ndff_secure; " + sql.rsplit(";", 1)[0].strip() + ";")


def switch_sql() -> str:
    butterfly_updates = "\n".join(
        "  UPDATE Meijendel.ndff_open_waarneming_register r "
        f"JOIN Meijendel.{ident(table)} i USING(waarneming_id) "
        "SET r.opslag_tabel='vlinders_waarneming';"
        for table in ("ndff_dagvlinders", "ndff_nachtvlinders", "ndff_microvlinders")
    )
    return f"""
DROP PROCEDURE IF EXISTS Meijendel.sp_ndff_vlinder_libel_swap_20261117;
DELIMITER $$
CREATE PROCEDURE Meijendel.sp_ndff_vlinder_libel_swap_20261117()
BEGIN
  DECLARE n BIGINT UNSIGNED DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
{butterfly_updates}
  UPDATE Meijendel.ndff_open_waarneming_register r
    JOIN Meijendel.ndff_libellen i USING(waarneming_id)
    SET r.opslag_tabel='libellen_waarneming';
  DELETE o FROM Meijendel.ndff_open_waarneming o
    JOIN Meijendel.ndff_open_waarneming_register r USING(waarneming_id)
    WHERE r.opslag_tabel IN ('vlinders_waarneming','libellen_waarneming');
  SELECT COUNT(*) INTO n FROM Meijendel.ndff_open_waarneming;
  IF n<>{EXPECTED_PARENT_AFTER} THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='NDFF-restbron heeft verkeerde omvang';
  END IF;
  SELECT COUNT(*) INTO n FROM Meijendel.ndff_open_waarneming_register r
    LEFT JOIN Meijendel.ndff_open_waarneming o ON o.waarneming_id=r.waarneming_id
      AND r.opslag_tabel='ndff_open_waarneming'
    LEFT JOIN Meijendel.vlinders_waarneming v ON v.waarneming_id=r.waarneming_id
      AND r.opslag_tabel='vlinders_waarneming'
    LEFT JOIN Meijendel.libellen_waarneming l ON l.waarneming_id=r.waarneming_id
      AND r.opslag_tabel='libellen_waarneming'
    LEFT JOIN Meijendel.mossen_waarneming m ON m.waarneming_id=r.waarneming_id
      AND r.opslag_tabel='mossen_waarneming'
    LEFT JOIN Meijendel.korstmossen_waarneming k ON k.waarneming_id=r.waarneming_id
      AND r.opslag_tabel='korstmossen_waarneming'
    WHERE COALESCE(o.waarneming_id,v.waarneming_id,l.waarneming_id,
                   m.waarneming_id,k.waarneming_id) IS NULL
       OR r.identiteit_sha256<>COALESCE(o.identiteit_sha256,v.identiteit_sha256,
                                        l.identiteit_sha256,m.identiteit_sha256,k.identiteit_sha256);
  IF n<>0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='NDFF-register mist bronregel';
  END IF;
  COMMIT;
END$$
DELIMITER ;
CALL Meijendel.sp_ndff_vlinder_libel_swap_20261117();
DROP PROCEDURE Meijendel.sp_ndff_vlinder_libel_swap_20261117;
"""


def final_audit(*, expect_old_indexes: bool) -> dict:
    names = table_names()
    expected = {"ndff_open_waarneming": EXPECTED_PARENT_AFTER,
                "vlinders_waarneming": EXPECTED_BUTTERFLIES,
                "libellen_waarneming": EXPECTED_LIBELS,
                "mossen_waarneming": 32_353,
                "korstmossen_waarneming": 28_643,
                "ndff_open_waarneming_register": EXPECTED_REGISTER}
    actual = {table: scalar(f"SELECT COUNT(*) FROM Meijendel.{ident(table)}")
              for table in expected}
    if actual != expected:
        raise RuntimeError(f"Fysieke NDFF-verdeling wijkt af: {actual}")
    if (set(INDEX_COUNTS) <= names) != expect_old_indexes:
        raise RuntimeError("Groepsindexstatus wijkt af")
    if scalar("SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming "
              "WHERE soortgroep_raw IN ('Dagvlinders','Nachtvlinders','Microvlinders','Libellen')"):
        raise RuntimeError("Er staan nog vlinders of libellen in de oude NDFF-bron")
    if scalar("SELECT COUNT(*) FROM Meijendel_ndff_secure.v_ndff_canonieke_waarneming") != EXPECTED_CANONICAL:
        raise RuntimeError("Canonieke beveiligde waarnemingen tellen niet meer gelijk")
    orphan = scalar(
        "SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming_register r "
        "LEFT JOIN Meijendel.ndff_open_waarneming o ON o.waarneming_id=r.waarneming_id "
        "AND r.opslag_tabel='ndff_open_waarneming' "
        "LEFT JOIN Meijendel.vlinders_waarneming v ON v.waarneming_id=r.waarneming_id "
        "AND r.opslag_tabel='vlinders_waarneming' "
        "LEFT JOIN Meijendel.libellen_waarneming l ON l.waarneming_id=r.waarneming_id "
        "AND r.opslag_tabel='libellen_waarneming' "
        "LEFT JOIN Meijendel.mossen_waarneming m ON m.waarneming_id=r.waarneming_id "
        "AND r.opslag_tabel='mossen_waarneming' "
        "LEFT JOIN Meijendel.korstmossen_waarneming k ON k.waarneming_id=r.waarneming_id "
        "AND r.opslag_tabel='korstmossen_waarneming' "
        "WHERE COALESCE(o.waarneming_id,v.waarneming_id,l.waarneming_id,"
        "m.waarneming_id,k.waarneming_id) IS NULL"
    )
    if orphan:
        raise RuntimeError(f"Register heeft {orphan} bronloze waarnemingen")
    return {"status": "eindcontrole_geslaagd", "fysiek": actual,
            "tove_vlinders": scalar("SELECT COUNT(*) FROM Meijendel.vlinders_waarneming_routekoppeling "
                                      "WHERE koppelstatus='tove_routejaar_aannemelijk'"),
            "voorlinden": scalar("SELECT COUNT(*) FROM Meijendel.vlinders_waarneming_routekoppeling "
                                     "WHERE koppelstatus='voorlinden_aannemelijk'"),
            "tove_libellen": scalar("SELECT COUNT(*) FROM Meijendel.libellen_waarneming_routekoppeling "
                                     "WHERE koppelstatus='tove_locatiejaar_aannemelijk'")}


def switch_live(backup: Path, backup_sha256: str) -> dict:
    proof = check_backup(backup, backup_sha256)
    prepared_counts()
    if scalar("SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming") != EXPECTED_PARENT_BEFORE:
        raise RuntimeError("Bronouder is gewijzigd sinds de voorbereiding")
    query("ALTER TABLE Meijendel.ndff_open_waarneming_register "
          "MODIFY opslag_tabel ENUM('ndff_open_waarneming','mossen_waarneming',"
          "'korstmossen_waarneming','vlinders_waarneming','libellen_waarneming') NOT NULL")
    install_central_guards()
    update_secure_canonical_view()
    if scalar("SELECT COUNT(*) FROM Meijendel_ndff_secure.v_ndff_canonieke_waarneming") != EXPECTED_CANONICAL:
        raise RuntimeError("Canonieke selectie wijkt vóór de omschakeling af")
    mysql_script(switch_sql())
    final_audit(expect_old_indexes=True)
    for table in INDEX_COUNTS:
        query(f"DROP TABLE Meijendel.{ident(table)}")
    install_central_guards()
    result = final_audit(expect_old_indexes=False)
    result["herstelkopie"] = proof
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--preflight", action="store_true")
    modes.add_argument("--prepare-live", action="store_true")
    modes.add_argument("--check-prepared", action="store_true")
    modes.add_argument("--switch-live", action="store_true")
    modes.add_argument("--audit-live", action="store_true")
    parser.add_argument("--backup", type=Path)
    parser.add_argument("--backup-sha256")
    options = parser.parse_args()
    if options.prepare_live or options.switch_live:
        if not options.backup or not options.backup_sha256:
            parser.error("Voor een levende migratie zijn --backup en --backup-sha256 verplicht")
    result = (preflight() if options.preflight else
              prepare_live(options.backup, options.backup_sha256) if options.prepare_live else
              prepared_counts() if options.check_prepared else
              switch_live(options.backup, options.backup_sha256) if options.switch_live else
              final_audit(expect_old_indexes=False))
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
