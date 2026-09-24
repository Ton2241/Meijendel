#!/usr/bin/env python3
"""Kopieer en valideer contextbronnen zonder de analytische database te mengen."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import NamedTuple


ROOT = Path(__file__).resolve().parents[2]
CORE_SCHEMA = ROOT / "gis" / "database" / "meijendel_bronnen_schema.sql"
DUINVALLEI_SCHEMA = ROOT / "gis" / "database" / "duinvallei_vegetatie_schema.sql"
SPIDER_CSV = ROOT / "kandidaatbronnen" / "jachtspinnen_1969_1970" / "jachtspinnen_28_locaties.csv"
RULE_VERSION = "meijendel-bronnen-v1"

SPIDER_SPECIES = {
    "Alopacce": "Alopecosa accentuata",
    "Alopcune": "Alopecosa cuneata",
    "Alopfabr": "Alopecosa fabrilis",
    "Arctlute": "Arctosa lutetiana",
    "Arctperi": "Arctosa perita",
    "Auloalbi": "Aulonia albimana",
    "Pardlugu": "Pardosa lugubris",
    "Pardmont": "Pardosa monticola",
    "Pardnigr": "Pardosa nigriceps",
    "Pardpull": "Pardosa pullata",
    "Trocterr": "Trochosa terricola",
    "Zoraspin": "Zora spinimana",
}

DUINVALLEI_TABLES = (
    "duinvallei_import_batch",
    "duinvallei_plot",
    "duinvallei_opname",
    "duinvallei_taxon",
    "duinvallei_bedekkingscode",
    "duinvallei_bedekking",
    "duinvallei_bodemparameter",
    "duinvallei_bodemmeting",
)

EXPECTED_COUNTS = {
    "duinvallei_import_batch": 1,
    "duinvallei_plot": 186,
    "duinvallei_opname": 488,
    "duinvallei_taxon": 208,
    "duinvallei_bedekkingscode": 12,
    "duinvallei_bedekking": 101504,
    "duinvallei_bodemparameter": 10,
    "duinvallei_bodemmeting": 855,
    "vogelstand_1924": 204,
    "jachtspin_locatie": 28,
    "jachtspin_soort": 12,
    "jachtspin_vangst": 336,
}


class MigrationState(NamedTuple):
    counts_match: bool
    hashes_match: bool
    foreign_keys_ok: bool
    restore_ok: bool


class SpiderProfile(NamedTuple):
    locations: list[dict]
    species: list[dict]
    catches: list[dict]


def may_finalize(state: MigrationState) -> bool:
    return all(state)


def build_finalize_sql(validated: bool) -> str:
    if not validated:
        return "SELECT 'finalize geblokkeerd: validatie onvolledig';"
    return """
USE Meijendel;
START TRANSACTION;
DELETE FROM meijendel_waarneming_ruimtelijke_status
WHERE bron_tabel IN ('duinvallei_opname','vogelstand_1924')
  AND regelversie='meijendel-ruimtelijke-poort-v3';
COMMIT;
DROP VIEW IF EXISTS v_duinvallei_analyse_bedekking;
DROP VIEW IF EXISTS v_duinvallei_analyse_opname;
DROP TABLE IF EXISTS duinvallei_bodemmeting;
DROP TABLE IF EXISTS duinvallei_bodemparameter;
DROP TABLE IF EXISTS duinvallei_bedekking;
DROP TABLE IF EXISTS duinvallei_bedekkingscode;
DROP TABLE IF EXISTS duinvallei_taxon;
DROP TABLE IF EXISTS duinvallei_opname;
DROP TABLE IF EXISTS duinvallei_plot;
DROP TABLE IF EXISTS duinvallei_import_batch;
DROP TABLE IF EXISTS vogelstand_1924;
"""


def validate_identifier(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_]+", value):
        raise ValueError(f"Ongeldige MySQL-identificatie: {value}")
    return value


def sql_quote(value: str | None) -> str:
    if value is None:
        return "NULL"
    return "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"


def mysql_command(login_path: str) -> list[str]:
    return [
        "/usr/local/mysql/bin/mysql",
        f"--login-path={login_path}",
        "--batch",
        "--skip-column-names",
    ]


def run_mysql(login_path: str, sql: str) -> str:
    result = subprocess.run(
        mysql_command(login_path),
        input=sql,
        text=True,
        capture_output=True,
        check=True,
    )
    return result.stdout.rstrip("\n")


def scalar(login_path: str, sql: str) -> str:
    output = run_mysql(login_path, sql)
    lines = output.splitlines()
    if len(lines) != 1:
        raise ValueError(f"Verwacht één MySQL-resultaat, ontvangen {len(lines)}")
    return lines[0]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def digest_query(login_path: str, sql: str) -> str:
    return hashlib.sha256(run_mysql(login_path, sql).encode("utf-8")).hexdigest()


def read_spider_matrix(path: Path) -> SpiderProfile:
    locations: list[dict] = []
    catches: list[dict] = []
    with path.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 28:
        raise ValueError(f"Verwacht 28 jachtspinlocaties, ontvangen {len(rows)}")
    for row in rows:
        location_id = int(row["locatie_nummer"])
        locations.append(
            {
                "locatie_nummer": location_id,
                "soil_dry": row["soil.dry"],
                "bare_sand": row["bare.sand"],
                "fallen_leaves": row["fallen.leaves"],
                "moss": row["moss"],
                "herb_layer": row["herb.layer"],
                "reflection": row["reflection"],
                "totaal_exemplaren": int(row["totaal_exemplaren"]),
            }
        )
        for species_code in SPIDER_SPECIES:
            catches.append(
                {
                    "locatie_nummer": location_id,
                    "soort_code": species_code,
                    "aantal": int(row[species_code]),
                }
            )
    if sum(row["totaal_exemplaren"] for row in locations) != 3337:
        raise ValueError("Jachtspinmatrix telt niet op tot 3.337 exemplaren")
    if sum(row["aantal"] for row in catches) != 3337:
        raise ValueError("Jachtspinvangsten tellen niet op tot 3.337 exemplaren")
    species = [
        {"soort_code": code, "wetenschappelijke_naam": name}
        for code, name in SPIDER_SPECIES.items()
    ]
    return SpiderProfile(locations, species, catches)


def schema_for_target(path: Path, target: str) -> str:
    validate_identifier(target)
    return path.read_text(encoding="utf-8").replace("Meijendel_bronnen", target)


def catalog_insert_sql(target: str) -> str:
    return f"""
INSERT INTO {target}.bron
  (bron_sleutel,bron_type,titel,omschrijving,bronorganisatie,jaar_van,jaar_tot,
   soortgroep,geografische_status,geografische_toelichting,analyse_status,
   rechten_status,regelversie)
VALUES
  ('duinvallei-vegetatie-2001-2018','dataset',
   'Duinvalleivegetatie Meijendel 2001-2018',
   'Volledige soortenmatrix en bodemmetingen op 186 stabiele locatiecodes.',
   'Openbare onderzoeksdataset',2001,2018,'Vaatplanten en vegetatie',
   'niet_geolokaliseerd',
   'De 488 opnamen hebben stabiele locatiecodes, maar nog geen geometrie per opname.',
   'context_alleen','geregistreerde_onderzoekers','{RULE_VERSION}'),
  ('vogelstand-1924','dataset','Vogelstand Meijendel 1924',
   'Historische soort- en tekstregels zonder afzonderlijke waarnemingslocatie.',
   'Vogelwerkgroep Meijendel',1924,1924,'Vogels','niet_geolokaliseerd',
   'De 204 regels hebben geen gestructureerde locatie per regel.',
   'context_alleen','geregistreerde_onderzoekers','{RULE_VERSION}'),
  ('jachtspinnen-1969-1970','kandidaatbron','Jachtspinnen Meijendel 1969-1970',
   'Geaggregeerde vangstmatrix van 28 genummerde locaties.',
   'Van der Aart en Smeenk-Enserink',1969,1970,'Jachtspinnen',
   'niet_geolokaliseerd',
   'De 28 locatienummers zijn niet naar werkelijke plekken te vertalen.',
   'kandidaat','geregistreerde_onderzoekers','{RULE_VERSION}')
ON DUPLICATE KEY UPDATE
  titel=VALUES(titel),omschrijving=VALUES(omschrijving),bronorganisatie=VALUES(bronorganisatie),
  jaar_van=VALUES(jaar_van),jaar_tot=VALUES(jaar_tot),soortgroep=VALUES(soortgroep),
  geografische_status=VALUES(geografische_status),
  geografische_toelichting=VALUES(geografische_toelichting),
  analyse_status=VALUES(analyse_status),rechten_status=VALUES(rechten_status),
  regelversie=VALUES(regelversie);
"""


def spider_insert_sql(target: str, profile: SpiderProfile, bron_id: int) -> str:
    species_values = ",\n".join(
        f"({bron_id},{sql_quote(row['soort_code'])},{sql_quote(row['wetenschappelijke_naam'])})"
        for row in profile.species
    )
    location_values = ",\n".join(
        "({bron_id},{locatie_nummer},{soil_dry},{bare_sand},{fallen_leaves},{moss},"
        "{herb_layer},{reflection},{totaal_exemplaren})".format(bron_id=bron_id, **row)
        for row in profile.locations
    )
    catch_values = ",\n".join(
        f"({bron_id},{row['locatie_nummer']},{sql_quote(row['soort_code'])},{row['aantal']})"
        for row in profile.catches
    )
    return f"""
INSERT INTO {target}.jachtspin_soort (bron_id,soort_code,wetenschappelijke_naam)
VALUES {species_values};
INSERT INTO {target}.jachtspin_locatie
  (bron_id,locatie_nummer,bodem_droogte_getransformeerd,kaal_zand_getransformeerd,
   gevallen_blad_getransformeerd,mos_getransformeerd,kruidlaag_getransformeerd,
   bodemreflectie_getransformeerd,totaal_exemplaren)
VALUES {location_values};
INSERT INTO {target}.jachtspin_vangst (bron_id,locatie_nummer,soort_code,aantal)
VALUES {catch_values};
"""


def copy_sql(
    login_path: str,
    source: str,
    target: str,
    spider_profile: SpiderProfile,
    spider_hash: str,
) -> str:
    source, target = validate_identifier(source), validate_identifier(target)
    duin_id = int(scalar(login_path, f"SELECT bron_id FROM {target}.bron WHERE bron_sleutel='duinvallei-vegetatie-2001-2018'"))
    bird_id = int(scalar(login_path, f"SELECT bron_id FROM {target}.bron WHERE bron_sleutel='vogelstand-1924'"))
    spider_id = int(scalar(login_path, f"SELECT bron_id FROM {target}.bron WHERE bron_sleutel='jachtspinnen-1969-1970'"))
    spider_sql = spider_insert_sql(target, spider_profile, spider_id)
    return f"""
SET FOREIGN_KEY_CHECKS=1;
START TRANSACTION;
DELETE FROM {target}.duinvallei_bodemmeting;
DELETE FROM {target}.duinvallei_bedekking;
DELETE FROM {target}.duinvallei_taxon;
DELETE FROM {target}.duinvallei_opname;
DELETE FROM {target}.duinvallei_plot;
DELETE FROM {target}.duinvallei_import_batch;
DELETE FROM {target}.vogelstand_1924;
DELETE FROM {target}.jachtspin_vangst;
DELETE FROM {target}.jachtspin_locatie;
DELETE FROM {target}.jachtspin_soort;
DELETE FROM {target}.bron_bestand
WHERE bron_id IN ({duin_id},{bird_id},{spider_id});

INSERT INTO {target}.duinvallei_bedekkingscode
SELECT * FROM {source}.duinvallei_bedekkingscode
ON DUPLICATE KEY UPDATE bronlabel=VALUES(bronlabel),aanwezig=VALUES(aanwezig),toelichting=VALUES(toelichting);
INSERT INTO {target}.duinvallei_bodemparameter
SELECT * FROM {source}.duinvallei_bodemparameter
ON DUPLICATE KEY UPDATE parameter_naam=VALUES(parameter_naam),eenheid=VALUES(eenheid),eenheid_bevestigd=VALUES(eenheid_bevestigd);
INSERT INTO {target}.duinvallei_import_batch
  (batch_id,bron_id,dataset_titel,dataset_doi,dataset_publicatiedatum,
   metadata_bestand,metadata_bronbestand_sha256,matrix_bestand,matrix_bronbestand_sha256,
   analysescript_bestand,analysescript_bronbestand_sha256,bronopname_aantal,taxon_aantal,
   importversie,geimporteerd_op)
SELECT batch_id,{duin_id},dataset_titel,dataset_doi,dataset_publicatiedatum,
       metadata_bestand,metadata_bronbestand_sha256,matrix_bestand,matrix_bronbestand_sha256,
       analysescript_bestand,analysescript_bronbestand_sha256,bronopname_aantal,taxon_aantal,
       importversie,geimporteerd_op
FROM {source}.duinvallei_import_batch;
INSERT INTO {target}.duinvallei_plot SELECT * FROM {source}.duinvallei_plot;
INSERT INTO {target}.duinvallei_opname SELECT * FROM {source}.duinvallei_opname;
INSERT INTO {target}.duinvallei_taxon SELECT * FROM {source}.duinvallei_taxon;
INSERT INTO {target}.duinvallei_bedekking SELECT * FROM {source}.duinvallei_bedekking;
INSERT INTO {target}.duinvallei_bodemmeting SELECT * FROM {source}.duinvallei_bodemmeting;

INSERT INTO {target}.vogelstand_1924
  (id,bron_id,soort_id_bron,soort_naam,latijnse_naam,beschrijving)
SELECT v.id,{bird_id},v.soort_id,s.soort_naam,s.latijnse_naam,v.beschrijving
FROM {source}.vogelstand_1924 v
LEFT JOIN {source}.soorten s ON s.id=v.soort_id;

{spider_sql}

INSERT INTO {target}.bron_bestand
  (bron_id,bestand_naam,bestandstype,opslagklasse,recordaantal,sha256,toelichting)
SELECT {duin_id},metadata_bestand,'text/csv','t7',bronopname_aantal,metadata_bronbestand_sha256,
       'Oorspronkelijke metadata' FROM {target}.duinvallei_import_batch
UNION ALL
SELECT {duin_id},matrix_bestand,'text/csv','t7',101504,matrix_bronbestand_sha256,
       'Volledige soortenmatrix' FROM {target}.duinvallei_import_batch
UNION ALL
SELECT {duin_id},analysescript_bestand,'text/x-r','t7',NULL,analysescript_bronbestand_sha256,
       'Oorspronkelijk analysescript' FROM {target}.duinvallei_import_batch;
INSERT INTO {target}.bron_bestand
  (bron_id,bestand_naam,bestandstype,opslagklasse,recordaantal,sha256,toelichting)
VALUES
  ({bird_id},'vogelstand_1924','mysql-tabel','overig',204,NULL,'Historische tabel uit Meijendel'),
  ({spider_id},'jachtspinnen_28_locaties.csv','text/csv','repository',28,{sql_quote(spider_hash)},
   'Afgeleide openbare matrix; som 3.337 exemplaren');
COMMIT;
"""


def copy_sources(login_path: str, source: str, target: str) -> None:
    source, target = validate_identifier(source), validate_identifier(target)
    run_mysql(login_path, schema_for_target(CORE_SCHEMA, target))
    run_mysql(login_path, schema_for_target(DUINVALLEI_SCHEMA, target))
    run_mysql(login_path, catalog_insert_sql(target))
    profile = read_spider_matrix(SPIDER_CSV)
    sql = copy_sql(login_path, source, target, profile, sha256_file(SPIDER_CSV))
    run_mysql(login_path, sql)


def table_exists(login_path: str, database: str, table: str) -> bool:
    value = scalar(
        login_path,
        "SELECT COUNT(*) FROM information_schema.tables "
        f"WHERE table_schema={sql_quote(database)} AND table_name={sql_quote(table)}",
    )
    return int(value) == 1


def count_table(login_path: str, database: str, table: str) -> int:
    return int(scalar(login_path, f"SELECT COUNT(*) FROM {validate_identifier(database)}.{validate_identifier(table)}"))


def source_target_queries(source: str, target: str) -> dict[str, tuple[str, str]]:
    queries: dict[str, tuple[str, str]] = {}
    for table, order in (
        ("duinvallei_plot", "plot_id"),
        ("duinvallei_opname", "opname_id"),
        ("duinvallei_taxon", "taxon_id"),
        ("duinvallei_bedekkingscode", "bedekkingscode"),
        ("duinvallei_bedekking", "opname_id,taxon_id"),
        ("duinvallei_bodemparameter", "parameter_sleutel"),
        ("duinvallei_bodemmeting", "opname_id,parameter_sleutel"),
    ):
        queries[table] = (
            f"SELECT * FROM {source}.{table} ORDER BY {order}",
            f"SELECT * FROM {target}.{table} ORDER BY {order}",
        )
    batch_columns = (
        "batch_id,dataset_titel,dataset_doi,dataset_publicatiedatum,metadata_bestand,"
        "metadata_bronbestand_sha256,matrix_bestand,matrix_bronbestand_sha256,"
        "analysescript_bestand,analysescript_bronbestand_sha256,bronopname_aantal,"
        "taxon_aantal,importversie,geimporteerd_op"
    )
    queries["duinvallei_import_batch"] = (
        f"SELECT {batch_columns} FROM {source}.duinvallei_import_batch ORDER BY batch_id",
        f"SELECT {batch_columns} FROM {target}.duinvallei_import_batch ORDER BY batch_id",
    )
    queries["vogelstand_1924"] = (
        f"SELECT v.id,v.soort_id,s.soort_naam,s.latijnse_naam,v.beschrijving "
        f"FROM {source}.vogelstand_1924 v LEFT JOIN {source}.soorten s ON s.id=v.soort_id ORDER BY v.id",
        f"SELECT id,soort_id_bron,soort_naam,latijnse_naam,beschrijving "
        f"FROM {target}.vogelstand_1924 ORDER BY id",
    )
    return queries


def restored_database_queries(source: str, target: str, login_path: str) -> dict[str, tuple[str, str]]:
    tables = [
        "bron", "bron_bestand", "literatuur", "literatuur_auteur",
        "jachtspin_locatie", "jachtspin_soort", "jachtspin_vangst", "vogelstand_1924",
        *DUINVALLEI_TABLES,
    ]
    queries: dict[str, tuple[str, str]] = {}
    for table in tables:
        columns_output = run_mysql(
            login_path,
            "SELECT column_name FROM information_schema.columns "
            f"WHERE table_schema={sql_quote(source)} AND table_name={sql_quote(table)} "
            "ORDER BY ordinal_position",
        )
        columns = [line for line in columns_output.splitlines() if line]
        if not columns:
            raise ValueError(f"Tabel ontbreekt in herstelde bron: {source}.{table}")
        quoted = ",".join(f"`{column}`" for column in columns)
        order = quoted
        queries[table] = (
            f"SELECT {quoted} FROM {source}.{table} ORDER BY {order}",
            f"SELECT {quoted} FROM {target}.{table} ORDER BY {order}",
        )
    return queries


def validate_databases(login_path: str, source: str, target: str) -> dict:
    source, target = validate_identifier(source), validate_identifier(target)
    restored_mode = table_exists(login_path, source, "bron")
    counts: dict[str, dict[str, int]] = {}
    hashes: dict[str, dict[str, str]] = {}
    if restored_mode:
        query_pairs = restored_database_queries(source, target, login_path)
        for table in query_pairs:
            counts[table] = {
                "source": count_table(login_path, source, table),
                "target": count_table(login_path, target, table),
            }
    else:
        query_pairs = source_target_queries(source, target)
        for table in EXPECTED_COUNTS:
            if table.startswith("jachtspin_"):
                target_count = count_table(login_path, target, table)
                counts[table] = {"source": EXPECTED_COUNTS[table], "target": target_count}
            else:
                counts[table] = {
                    "source": count_table(login_path, source, table),
                    "target": count_table(login_path, target, table),
                }
    for table, (source_query, target_query) in query_pairs.items():
        hashes[table] = {
            "source": digest_query(login_path, source_query),
            "target": digest_query(login_path, target_query),
        }
    counts_match = all(row["source"] == row["target"] for row in counts.values())
    expected_match = restored_mode or all(
        counts[table]["target"] == expected for table, expected in EXPECTED_COUNTS.items()
    )
    hashes_match = all(row["source"] == row["target"] for row in hashes.values())
    spider_sum = int(scalar(login_path, f"SELECT COALESCE(SUM(aantal),0) FROM {target}.jachtspin_vangst"))
    orphan_queries = (
        f"SELECT COUNT(*) FROM {target}.duinvallei_plot p LEFT JOIN {target}.duinvallei_import_batch b ON b.batch_id=p.batch_id WHERE b.batch_id IS NULL",
        f"SELECT COUNT(*) FROM {target}.duinvallei_opname o LEFT JOIN {target}.duinvallei_plot p ON p.plot_id=o.plot_id WHERE p.plot_id IS NULL",
        f"SELECT COUNT(*) FROM {target}.duinvallei_bedekking d LEFT JOIN {target}.duinvallei_opname o ON o.opname_id=d.opname_id LEFT JOIN {target}.duinvallei_taxon t ON t.taxon_id=d.taxon_id WHERE o.opname_id IS NULL OR t.taxon_id IS NULL",
        f"SELECT COUNT(*) FROM {target}.duinvallei_bodemmeting m LEFT JOIN {target}.duinvallei_opname o ON o.opname_id=m.opname_id WHERE o.opname_id IS NULL",
        f"SELECT COUNT(*) FROM {target}.vogelstand_1924 v LEFT JOIN {target}.bron b ON b.bron_id=v.bron_id WHERE b.bron_id IS NULL",
        f"SELECT COUNT(*) FROM {target}.jachtspin_vangst v LEFT JOIN {target}.jachtspin_locatie l ON l.bron_id=v.bron_id AND l.locatie_nummer=v.locatie_nummer LEFT JOIN {target}.jachtspin_soort s ON s.bron_id=v.bron_id AND s.soort_code=v.soort_code WHERE l.locatie_nummer IS NULL OR s.soort_code IS NULL",
    )
    orphan_counts = [int(scalar(login_path, query)) for query in orphan_queries]
    foreign_keys_ok = all(value == 0 for value in orphan_counts)
    return {
        "source_database": source,
        "target_database": target,
        "mode": "restore" if restored_mode else "migration",
        "rule_version": RULE_VERSION,
        "counts": counts,
        "hashes": hashes,
        "spider_total": spider_sum,
        "orphan_counts": orphan_counts,
        "counts_match": counts_match and expected_match and spider_sum == 3337,
        "hashes_match": hashes_match,
        "foreign_keys_ok": foreign_keys_ok,
        "restore_ok": False,
    }


def write_manifest(report: dict, path: Path) -> None:
    path.write_text(json.dumps(report, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")


def finalize(login_path: str, manifest_path: Path, confirmed: bool) -> None:
    if not confirmed:
        raise ValueError("--finalize vereist --yes")
    report = json.loads(manifest_path.read_text(encoding="utf-8"))
    state = MigrationState(
        counts_match=bool(report.get("counts_match")),
        hashes_match=bool(report.get("hashes_match")),
        foreign_keys_ok=bool(report.get("foreign_keys_ok")),
        restore_ok=bool(report.get("restore_ok")),
    )
    if report.get("source_database") != "Meijendel" or report.get("target_database") != "Meijendel_bronnen":
        raise ValueError("Finalize accepteert alleen het gevalideerde live bron/doelpaar")
    if not may_finalize(state):
        raise ValueError(f"Finalize geblokkeerd door migratiestatus: {state}")
    current = validate_databases(login_path, "Meijendel", "Meijendel_bronnen")
    current["restore_ok"] = True
    if any(current[key] != report[key] for key in ("counts", "hashes", "counts_match", "hashes_match", "foreign_keys_ok")):
        raise ValueError("Database-inhoud wijzigde sinds het migratiemanifest; valideer opnieuw")
    run_mysql(login_path, build_finalize_sql(validated=True))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--login-path", default="meijendel_root")
    parser.add_argument("--source", default="Meijendel")
    parser.add_argument("--target", default="Meijendel_bronnen")
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--mark-restore-ok", type=Path)
    parser.add_argument("--yes", action="store_true")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--copy", action="store_true")
    mode.add_argument("--validate", action="store_true")
    mode.add_argument("--finalize", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.copy:
        copy_sources(args.login_path, args.source, args.target)
        print(f"Bronfamilies gekopieerd: {args.source} -> {args.target}; niets verwijderd")
        return 0
    if args.validate:
        report = validate_databases(args.login_path, args.source, args.target)
        state = MigrationState(
            report["counts_match"], report["hashes_match"], report["foreign_keys_ok"], False
        )
        if not all(state[:3]):
            print(json.dumps(report, indent=2, ensure_ascii=False))
            return 1
        if args.mark_restore_ok:
            manifest = json.loads(args.mark_restore_ok.read_text(encoding="utf-8"))
            manifest["restore_ok"] = True
            manifest["restore_validation"] = report
            write_manifest(manifest, args.mark_restore_ok)
            print(f"Herstelvalidatie geslaagd: {args.mark_restore_ok}")
        else:
            if not args.manifest:
                raise ValueError("--validate vereist --manifest of --mark-restore-ok")
            write_manifest(report, args.manifest)
            print(f"Migratie gevalideerd: {args.manifest}")
        return 0
    if not args.manifest:
        raise ValueError("--finalize vereist --manifest")
    finalize(args.login_path, args.manifest, args.yes)
    print("Gevalideerde bronfamilies uit Meijendel verwijderd")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
