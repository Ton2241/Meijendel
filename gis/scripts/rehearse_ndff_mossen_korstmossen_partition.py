#!/usr/bin/env python3
"""Proef voor de gesplitste NDFF-opslag. Wijzigt uitsluitend een eigen proefschema."""

from __future__ import annotations

import argparse

from import_external_ecology_sources import central_query_routes, central_query_triggers_sql
from migrate_ndff_mossen_korstmossen import new_table_sql, preflight, query, swap_procedure_sql


SCRATCH = "Meijendel_blwg_partitieproef_20261023"
GROUPS = (("mossen", "ndff_mossen"), ("korstmossen", "ndff_korstmossen"))


def scalar(sql: str) -> int:
    return int(query(sql)[0][0])


def expect_rejected(sql: str, message: str) -> None:
    try:
        query(sql)
    except RuntimeError as error:
        if message not in str(error):
            raise RuntimeError(f"Andere MySQL-fout dan de bedoelde blokkade: {error}") from error
        return
    raise RuntimeError(f"Onveilige wijziging werd toch aanvaard: {sql}")


def copy_uncomputed(table: str, predicate: str) -> None:
    """Kopieer bronwaarden; laat MySQL gegenereerde taxonkolommen herberekenen."""
    columns = query("SELECT COLUMN_NAME,EXTRA FROM information_schema.COLUMNS "
                    "WHERE TABLE_SCHEMA='Meijendel' "
                    f"AND TABLE_NAME='{table}' ORDER BY ORDINAL_POSITION")
    names = [f"`{name}`" for name, extra in columns if "GENERATED" not in extra.upper()]
    if not names:
        raise RuntimeError(f"Geen kopieerbare kolommen voor {table}")
    fields = ",".join(names)
    query(f"INSERT INTO `{SCRATCH}`.`{table}` ({fields}) "
          f"SELECT {fields} FROM Meijendel.`{table}` WHERE {predicate}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true",
                        help="Maak alleen het nauw begrensde proefschema aan")
    args = parser.parse_args()
    preflight()
    if not args.apply:
        print(f"DRY RUN: proefschema {SCRATCH}; levende tabellen blijven ongemoeid")
        return
    if scalar("SELECT COUNT(*) FROM information_schema.SCHEMATA "
              f"WHERE SCHEMA_NAME='{SCRATCH}'"):
        raise RuntimeError(f"Proefschema {SCRATCH} bestaat al; niets overschreven")
    samples = {}
    for group, index in GROUPS:
        samples[group] = scalar(f"SELECT MIN(waarneming_id) FROM Meijendel.{index}")
    other = scalar("SELECT MIN(o.waarneming_id) FROM Meijendel.ndff_open_waarneming o "
                   "LEFT JOIN Meijendel.ndff_mossen m USING(waarneming_id) "
                   "LEFT JOIN Meijendel.ndff_korstmossen k USING(waarneming_id) "
                   "WHERE m.waarneming_id IS NULL AND k.waarneming_id IS NULL")
    ids = [*samples.values(), other]
    query(f"CREATE SCHEMA `{SCRATCH}`")
    succeeded = False
    try:
        for table in ("taxa", "taxa_bronkoppeling", "ndff_open_import_batch",
                      "ndff_soorten", "ndff_open_waarneming",
                      "ndff_open_soortgroep_koppeling"):
            query(f"CREATE TABLE `{SCRATCH}`.`{table}` LIKE Meijendel.`{table}`")
        selected = ",".join(map(str, ids))
        query(f"INSERT INTO `{SCRATCH}`.ndff_open_waarneming "
              f"SELECT * FROM Meijendel.ndff_open_waarneming "
              f"WHERE waarneming_id IN ({selected})")
        query(f"INSERT INTO `{SCRATCH}`.ndff_open_import_batch "
              "SELECT b.* FROM Meijendel.ndff_open_import_batch b "
              f"WHERE b.batch_id IN (SELECT batch_id FROM `{SCRATCH}`.ndff_open_waarneming)")
        query(f"INSERT INTO `{SCRATCH}`.ndff_soorten "
              "SELECT s.* FROM Meijendel.ndff_soorten s "
              f"WHERE s.soort_key IN (SELECT soort_key FROM `{SCRATCH}`.ndff_open_waarneming)")
        copy_uncomputed("taxa_bronkoppeling", "koppeling_id IN "
                        f"(SELECT taxon_bronkoppeling_id FROM `{SCRATCH}`.ndff_soorten)")
        copy_uncomputed("taxa", "taxon_id IN "
                        f"(SELECT taxon_id FROM `{SCRATCH}`.taxa_bronkoppeling)")
        query(f"INSERT INTO `{SCRATCH}`.ndff_open_soortgroep_koppeling "
              "SELECT c.* FROM Meijendel.ndff_open_soortgroep_koppeling c "
              f"WHERE c.waarneming_id IN ({selected})")
        for statement in new_table_sql(SCRATCH):
            query(statement)
        for group, index in GROUPS:
            query(f"CREATE TABLE `{SCRATCH}`.`{index}` "
                  "(`waarneming_id` BIGINT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB")
            query(f"INSERT INTO `{SCRATCH}`.`{index}` VALUES ({samples[group]})")
        query(f"INSERT INTO `{SCRATCH}`.ndff_open_waarneming_register "
              "(waarneming_id,opslag_tabel,identiteit_sha256) "
              "SELECT waarneming_id,'ndff_open_waarneming',identiteit_sha256 "
              f"FROM `{SCRATCH}`.ndff_open_waarneming")
        query(f"ALTER TABLE `{SCRATCH}`.ndff_open_soortgroep_koppeling "
              "ADD CONSTRAINT fk_partitieproef_groep FOREIGN KEY (waarneming_id) "
              f"REFERENCES `{SCRATCH}`.ndff_open_waarneming_register(waarneming_id)")
        columns = query("SELECT TABLE_NAME,COLUMN_NAME FROM information_schema.COLUMNS "
                        f"WHERE TABLE_SCHEMA='{SCRATCH}' ORDER BY TABLE_NAME,ORDINAL_POSITION")
        schema = {}
        for table, column in columns:
            schema.setdefault(table, set()).add(column)
        routes = central_query_routes(schema)
        trigger_sql = central_query_triggers_sql({"routes": routes})
        # DELIMITER is a mysql-client command; run in one selected scratch session.
        from migrate_ndff_mossen_korstmossen import MYSQL_CLIENT, MYSQL_ARGS
        import subprocess
        result = subprocess.run(
            [MYSQL_CLIENT, *MYSQL_ARGS, SCRATCH], input=trigger_sql,
            text=True, capture_output=True,
        )
        if result.returncode:
            raise RuntimeError(result.stderr.strip())
        for group, _ in GROUPS:
            sample = samples[group]
            query(f"INSERT INTO `{SCRATCH}`.`{group}_waarneming` "
                  f"SELECT * FROM `{SCRATCH}`.ndff_open_waarneming "
                  f"WHERE waarneming_id={sample}")
        wrong_swap = swap_procedure_sql(SCRATCH, original=4, mosses=1, lichens=1)
        result = subprocess.run([MYSQL_CLIENT, *MYSQL_ARGS, SCRATCH],
                                input=wrong_swap, text=True, capture_output=True)
        if result.returncode == 0 or "NDFF-restbron telt onjuist" not in result.stderr:
            raise RuntimeError(f"Foutieve omschakeling werd niet correct afgewezen: {result.stderr}")
        if scalar(f"SELECT COUNT(*) FROM `{SCRATCH}`.ndff_open_waarneming") != 3:
            raise RuntimeError("Foutieve omschakeling is niet volledig teruggedraaid")
        query(f"DROP PROCEDURE IF EXISTS `{SCRATCH}`.sp_ndff_blwg_swap_20261023")
        result = subprocess.run([MYSQL_CLIENT, *MYSQL_ARGS, SCRATCH],
                                input=swap_procedure_sql(SCRATCH, original=3, mosses=1, lichens=1),
                                text=True, capture_output=True)
        if result.returncode:
            raise RuntimeError(result.stderr.strip())
        for group, _ in GROUPS:
            sample = samples[group]
            expect_rejected(f"DELETE FROM `{SCRATCH}`.`{group}_waarneming` "
                            f"WHERE waarneming_id={sample}",
                            "NDFF-bronregel mag niet verdwijnen")
            expect_rejected(f"UPDATE `{SCRATCH}`.ndff_open_waarneming_register "
                            "SET opslag_tabel='ndff_open_waarneming' "
                            f"WHERE waarneming_id={sample}",
                            "NDFF-register verwijst niet naar volledige bronregel")
        counts = [scalar(f"SELECT COUNT(*) FROM `{SCRATCH}`.{table}") for table in
                  ("ndff_open_waarneming", "mossen_waarneming",
                   "korstmossen_waarneming", "ndff_open_waarneming_register")]
        if counts != [1, 1, 1, 3]:
            raise RuntimeError(f"Onverwachte proefverdeling: {counts}")
        expect_rejected(f"DELETE FROM `{SCRATCH}`.ndff_open_waarneming_register "
                        f"WHERE waarneming_id={samples['mossen']}",
                        "NDFF-bronregel is nog aanwezig")
        print("GROEN: 3 openbare bronregels logisch eenmalig; beide fysieke verhuizingen "
              "en de verliesblokkades werken in het geïsoleerde proefschema")
        succeeded = True
    finally:
        if succeeded:
            query(f"DROP SCHEMA `{SCRATCH}`")


if __name__ == "__main__":
    main()
