#!/usr/bin/env python3
"""Selecteer en importeer geografisch toegelaten openbare ecologiebronnen.

De ruwe Darwin Core-archieven blijven buiten Git. Dit script leest de eerder
met ``profile_external_dwca.py`` gemaakte Meijendelselecties en schrijft een
herhaalbare, transactionele import voor de analytische database ``Meijendel``.
"""

from __future__ import annotations

import argparse
import calendar
import csv
import json
import re
import subprocess
import tempfile
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis" / "database" / "external_ecology_schema.sql"
DATABASE = "Meijendel"
IMPORT_VERSION = "externe-ecologie-v1"

SOURCE_CONFIG = {
    "stowa": {
        "dataset_sleutel": "stowa-limnodata-meijendel",
        "titel": "STOWA Limnodata binnen Meijendel",
        "organisatie": "STOWA; Hoogheemraadschap van Delfland en Rijnland",
        "doi": "10.15468/ennulm",
        "licentie": "CC BY 4.0",
        "bestand": "stowa_limnodata.zip",
        "sha256": "a77a07107ed7c196777b7290d50f83d8114e41ff131c12879755d95c3efd1717",
        "versie": "2020-04-14",
        "selectie": "Exacte puntselectie binnen het Meijendel-basisgebied; positieve resultaten per bemonstering en meeteenheid.",
    },
    "endure": {
        "dataset_sleutel": "endure-helmduinfauna-meijendel-2018",
        "titel": "ENDURE helmduinfauna Meijendel 2018",
        "organisatie": "Universiteit Gent en ENDURE",
        "doi": "10.15468/xx2gcp",
        "licentie": "CC BY 4.0",
        "bestand": "endure.zip",
        "sha256": "9f7a4d95da6f04e9aa4f5eeae61a17dd9d5a0d5b4ff099248a9861075826a1fc",
        "versie": "1.8 / 2026-08-10",
        "selectie": "Vijftien exacte meetpunten binnen het basisgebied; veertien complete aanwezigheids-afwezigheidsmatrices.",
    },
    "nmr": {
        "dataset_sleutel": "nmr-vlinders-meijendel",
        "titel": "NMR vlinder- en motcollectie Meijendel",
        "organisatie": "Natuurhistorisch Museum Rotterdam",
        "doi": "10.15468/czfn9y",
        "licentie": "CC BY 4.0",
        "bestand": "nmr_observations.zip",
        "sha256": "4791aafa76259643b7045d927f1d39f995532e24cc4dcdeccf30e173446b0673",
        "versie": "download 2026-09-26",
        "selectie": "Alleen gedateerde, unieke records met een expliciete Meijendel- of Bierlap-etiketplaats binnen het basisgebied.",
    },
    "botany": {
        "dataset_sleutel": "naturalis-botany-meijendel",
        "titel": "Naturalis Botany specimens Meijendel",
        "organisatie": "Naturalis Biodiversity Center",
        "doi": "10.15468/ib5ypt",
        "licentie": "CC0 1.0",
        "bestand": "naturalis_botany.zip",
        "sha256": "2d40dde338bac879499dbe5ff68da7ef56aca04401541b87d813bbd4af3175b5",
        "versie": "2026-09-24",
        "selectie": "Alleen gedateerde, unieke specimens met een expliciete Meijendel-deelgebied-etiketplaats binnen het basisgebied.",
    },
    "coleoptera": {
        "dataset_sleutel": "naturalis-coleoptera-meijendel",
        "titel": "Naturalis Coleoptera specimens Meijendel",
        "organisatie": "Naturalis Biodiversity Center",
        "doi": "10.15468/jrjojf",
        "licentie": "CC0 1.0",
        "bestand": "naturalis_coleoptera.zip",
        "sha256": "19611eead96004ff51e12f8415159e23a6e75e23a30cfb190fcb89262f282ebc",
        "versie": "2026-09-24",
        "selectie": "Alleen gedateerde, unieke specimens met een expliciete Meijendel-deelgebied-etiketplaats binnen het basisgebied.",
    },
    "lvd": {
        "dataset_sleutel": "lvd-meijendel-v1-6",
        "titel": "Landelijke Vegetatie Databank Meijendelselectie",
        "organisatie": "Wageningen Environmental Research",
        "doi": "10.15468/ksqxep",
        "licentie": "CC BY 4.0",
        "bestand": "lvd.zip",
        "sha256": "84095fedcf3e13e1b7fc8888a5e7fea136360bbb4db7836d560faffb7f869886",
        "versie": "1.6 / 2016-07-14",
        "selectie": "Alleen opnamen waarvan de gepubliceerde coördinaatonzekerheid maximaal 50 meter is en het punt binnen het basisgebied ligt.",
    },
}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def stowa_event_key(row: dict[str, str]) -> str:
    return "|".join(
        (row.get("fieldNumber", ""), row.get("eventDate", ""), row.get("decimalLatitude", ""), row.get("decimalLongitude", ""))
    )


def admit_museum_row(row: dict[str, str]) -> bool:
    return bool(
        row.get("_binnen_basisgebied") == "1"
        and row.get("_expliciet_meijendel") == "1"
        and (row.get("eventDate") or row.get("_jaar"))
        and (row.get("occurrenceID") or row.get("_core_id"))
    )


def admit_lvd_event(row: dict[str, str]) -> bool:
    try:
        return float(row.get("coordinateUncertaintyInMeters", "")) <= 50
    except (TypeError, ValueError):
        return False


def as_float(value: str | None):
    if value in (None, ""):
        return None
    try:
        return float(value)
    except ValueError:
        return None


def as_int(value: str | None):
    number = as_float(value)
    return int(number) if number is not None else None


def event_period(value: str | None, year: str | None):
    value = (value or "").strip()
    exact = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})", value)
    if exact:
        return value, value, "exact"
    interval = re.fullmatch(r"(\d{4}-\d{2}-\d{2})/(\d{4}-\d{2}-\d{2})", value)
    if interval:
        return interval.group(1), interval.group(2), "interval"
    month = re.fullmatch(r"(\d{4})-(\d{2})-?", value)
    if month:
        last = calendar.monthrange(int(month.group(1)), int(month.group(2)))[1]
        prefix = f"{month.group(1)}-{month.group(2)}"
        return f"{prefix}-01", f"{prefix}-{last:02d}", "maand"
    if year and str(year).isdigit():
        return f"{year}-01-01", f"{year}-12-31", "jaar"
    return None, None, "onbekend"


def compact_json(row: dict[str, str]) -> str:
    return json.dumps(row, ensure_ascii=False, separators=(",", ":"))


def museum_canonical_name(row: dict[str, str]) -> str:
    source = (row.get("scientificName") or row.get("verbatimIdentification") or "onbekend").strip()
    authorship = (row.get("scientificNameAuthorship") or "").strip()
    if authorship and source.endswith(authorship):
        source = source[: -len(authorship)].strip()
    source = re.sub(r"^([A-ZÀ-ÖØ-Þ][^\s]+)\s+\([A-ZÀ-ÖØ-Þ][^)]+\)\s+", r"\1 ", source)
    rank = (row.get("taxonRank") or "").lower()
    if rank in {"species", "sp."}:
        words = source.split()
        if len(words) >= 2:
            return " ".join(words[:2])
    source = re.sub(r"\s+\([^)]*,?\s*\d{4}\)\s*$", "", source)
    source = re.sub(r"\s+[A-ZÀ-ÖØ-Þ][^,]*,?\s*\d{4}\s*$", "", source)
    return source.strip()


def mysql_field(value) -> str:
    if value is None:
        return r"\N"
    return str(value).replace("\\", "\\\\").replace("\t", r"\t").replace("\n", r"\n").replace("\r", r"\r")


def write_tsv(path: Path, header: tuple[str, ...], rows) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write("\t".join(header) + "\n")
        for row in rows:
            handle.write("\t".join(mysql_field(value) for value in row) + "\n")


def museum_event_row(source_key: str, row: dict[str, str]):
    config = SOURCE_CONFIG[source_key]
    occurrence_id = row.get("occurrenceID") or row.get("_core_id")
    return (
        config["dataset_sleutel"], occurrence_id, *event_period(row.get("eventDate"), row.get("_jaar")),
        as_int(row.get("_jaar")), as_float(row.get("decimalLatitude")),
        as_float(row.get("decimalLongitude")), as_float(row.get("coordinateUncertaintyInMeters")),
        row.get("locality") or row.get("verbatimLocality") or None,
        "meijendel_gebiedslabel", row.get("samplingProtocol") or None, None, None,
        "collectiecontext", compact_json(row),
    )


def museum_result_row(source_key: str, row: dict[str, str]):
    config = SOURCE_CONFIG[source_key]
    occurrence_id = row.get("occurrenceID") or row.get("_core_id")
    source_name = row.get("scientificName") or row.get("verbatimIdentification") or "onbekend"
    return (
        config["dataset_sleutel"], occurrence_id, occurrence_id,
        museum_canonical_name(row), source_name,
        row.get("vernacularName") or None, row.get("taxonRank") or None, "present",
        as_float(row.get("individualCount") or row.get("organismQuantity")),
        row.get("individualCount") or row.get("organismQuantity") or None,
        row.get("organismQuantityType") or "individuals",
        row.get("basisOfRecord") or None, row.get("catalogNumber") or None, compact_json(row),
    )


def dataset_row(config: dict[str, str]):
    return (
        config["dataset_sleutel"], config["titel"], config["organisatie"], config["doi"],
        config["licentie"], config["bestand"], config["sha256"], config["versie"],
        config["selectie"], IMPORT_VERSION,
    )


def write_import_files(
    target: Path,
    *,
    stowa_rows: list[dict[str, str]],
    stowa_measurements: dict[str, tuple[str, str, str]],
    endure_events: list[dict[str, str]],
    endure_results: list[dict[str, str]],
    museum_sources: dict[str, tuple[list[dict[str, str]], dict[str, str]]],
    lvd_events: list[dict[str, str]],
    lvd_releves: dict[str, dict[str, str]],
    lvd_occurrences: list[dict[str, str]],
) -> dict[str, Path]:
    target.mkdir(parents=True, exist_ok=True)
    used_configs = []
    events = []
    results = []

    if stowa_rows:
        used_configs.append(SOURCE_CONFIG["stowa"])
        seen_events = set()
        for row in stowa_rows:
            key = stowa_event_key(row)
            if key not in seen_events:
                seen_events.add(key)
                events.append((
                    SOURCE_CONFIG["stowa"]["dataset_sleutel"], key,
                    *event_period(row.get("eventDate"), row.get("_jaar")),
                    as_int(row.get("_jaar")), as_float(row.get("decimalLatitude")),
                    as_float(row.get("decimalLongitude")), as_float(row.get("coordinateUncertaintyInMeters")),
                    row.get("locality") or None, "punt_binnen_50m", row.get("samplingProtocol") or None,
                    None, None, "positieve_resultaten_alleen", compact_json(row),
                ))
            occurrence_id = row.get("occurrenceID") or row.get("_core_id")
            measurement = stowa_measurements.get(row.get("_core_id", ""), ("", "", ""))
            results.append((
                SOURCE_CONFIG["stowa"]["dataset_sleutel"], key, occurrence_id,
                row.get("scientificName") or "onbekend", row.get("scientificName") or "onbekend",
                None, row.get("taxonRank") or None,
                "present", as_float(measurement[0] or row.get("individualCount")),
                measurement[0] or row.get("individualCount") or None,
                measurement[1] or measurement[2] or None, row.get("basisOfRecord") or None,
                row.get("catalogNumber") or None, compact_json(row),
            ))

    if endure_events:
        used_configs.append(SOURCE_CONFIG["endure"])
        result_events = {row.get("_core_id") for row in endure_results}
        for row in endure_events:
            source_id = row.get("eventID") or row.get("_core_id")
            events.append((
                SOURCE_CONFIG["endure"]["dataset_sleutel"], source_id,
                *event_period(row.get("eventDate"), row.get("_jaar")), as_int(row.get("_jaar")),
                as_float(row.get("decimalLatitude")), as_float(row.get("decimalLongitude")),
                as_float(row.get("coordinateUncertaintyInMeters")), None, "punt_binnen_50m",
                row.get("samplingProtocol") or None, as_float(row.get("sampleSizeValue")),
                row.get("sampleSizeUnit") or None,
                "volledig_bezoek" if source_id in result_events else "geen_resultaatmatrix",
                compact_json(row),
            ))
        for row in endure_results:
            source_id = row.get("eventID") or row.get("_core_id")
            results.append((
                SOURCE_CONFIG["endure"]["dataset_sleutel"], source_id,
                row.get("occurrenceID") or f"{source_id}|{row.get('scientificName','')}",
                row.get("scientificName") or row.get("verbatimIdentification") or "onbekend",
                row.get("scientificName") or row.get("verbatimIdentification") or "onbekend",
                None, row.get("taxonRank") or None,
                "absent" if row.get("occurrenceStatus") == "absent" else "present",
                as_float(row.get("individualCount")), row.get("individualCount") or None,
                "individuals", row.get("basisOfRecord") or None, None, compact_json(row),
            ))

    for source_key, (source_rows, config) in museum_sources.items():
        admitted = [row for row in source_rows if admit_museum_row(row)]
        if not admitted:
            continue
        used_configs.append(config)
        seen = set()
        for row in admitted:
            occurrence_id = row.get("occurrenceID") or row.get("_core_id")
            if occurrence_id in seen:
                continue
            seen.add(occurrence_id)
            events.append(museum_event_row(source_key, row))
            results.append(museum_result_row(source_key, row))

    admitted_lvd = [row for row in lvd_events if admit_lvd_event(row)]
    if admitted_lvd:
        used_configs.append(SOURCE_CONFIG["lvd"])
        admitted_ids = {row.get("eventID") or row.get("_core_id") for row in admitted_lvd}
        for row in admitted_lvd:
            event_id = row.get("eventID") or row.get("_core_id")
            metadata = dict(row)
            metadata["releve"] = lvd_releves.get(event_id, {})
            events.append((
                SOURCE_CONFIG["lvd"]["dataset_sleutel"], event_id,
                *event_period(row.get("eventDate"), row.get("_jaar")),
                as_int(row.get("_jaar")), as_float(row.get("decimalLatitude")),
                as_float(row.get("decimalLongitude")), as_float(row.get("coordinateUncertaintyInMeters")),
                None, "punt_binnen_50m", row.get("samplingProtocol") or None,
                as_float(row.get("sampleSizeValue")), row.get("sampleSizeUnit") or None,
                "volledig_bezoek", compact_json(metadata),
            ))
        for row in lvd_occurrences:
            event_id = row.get("eventID") or row.get("_core_id")
            if event_id not in admitted_ids:
                continue
            results.append((
                SOURCE_CONFIG["lvd"]["dataset_sleutel"], event_id,
                row.get("occurrenceID") or f"{event_id}|{row.get('scientificName','')}",
                row.get("scientificName") or "onbekend", row.get("scientificName") or "onbekend",
                row.get("vernacularName") or None,
                row.get("taxonomicStatus") or None, "present",
                as_float(row.get("organismQuantity") or row.get("individualCount")),
                row.get("organismQuantity") or row.get("individualCount") or None,
                row.get("organismQuantityType") or None, row.get("basisOfRecord") or None,
                None, compact_json(row),
            ))

    unique_configs = {config["dataset_sleutel"]: config for config in used_configs}
    paths = {name: target / f"{name}.tsv" for name in ("datasets", "events", "results")}
    write_tsv(paths["datasets"], (
        "dataset_sleutel", "titel", "bronorganisatie", "doi", "licentie",
        "bronbestand_naam", "bronbestand_sha256", "bronversie", "selectie_omschrijving", "importversie",
    ), (dataset_row(config) for config in unique_configs.values()))
    write_tsv(paths["events"], (
        "dataset_sleutel", "bron_event_id", "event_datum", "event_datum_tot", "datum_precisie",
        "jaar", "latitude", "longitude",
        "coordinate_uncertainty_m", "bron_locatie", "ruimtelijke_klasse", "sampling_protocol",
        "inspanning_waarde", "inspanning_eenheid", "analyse_status", "bronmetadata",
    ), events)
    write_tsv(paths["results"], (
        "dataset_sleutel", "bron_event_id", "bron_occurrence_id", "wetenschappelijke_naam",
        "wetenschappelijke_naam_bron",
        "nederlandse_naam", "taxonrang", "occurrence_status", "hoeveelheid",
        "hoeveelheid_oorspronkelijk", "hoeveelheid_eenheid", "basis_of_record",
        "catalogusnummer", "bronmetadata",
    ), results)
    return paths


def sql_path(path: Path) -> str:
    return str(path.resolve()).replace("\\", "\\\\").replace("'", "''")


def load_sql(paths: dict[str, Path], database: str = DATABASE) -> str:
    datasets, events, results = (sql_path(paths[key]) for key in ("datasets", "events", "results"))
    return f"""
USE {database};
START TRANSACTION;
CREATE TEMPORARY TABLE tmp_external_dataset LIKE externe_ecologie_dataset;
ALTER TABLE tmp_external_dataset DROP COLUMN dataset_id, DROP COLUMN geimporteerd_op;
LOAD DATA LOCAL INFILE '{datasets}' INTO TABLE tmp_external_dataset
CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\'
LINES TERMINATED BY '\\n' IGNORE 1 LINES;
INSERT INTO externe_ecologie_dataset (
  dataset_sleutel,titel,bronorganisatie,doi,licentie,bronbestand_naam,
  bronbestand_sha256,bronversie,selectie_omschrijving,importversie
) SELECT dataset_sleutel,titel,bronorganisatie,doi,licentie,bronbestand_naam,
  bronbestand_sha256,bronversie,selectie_omschrijving,importversie
FROM tmp_external_dataset
ON DUPLICATE KEY UPDATE titel=VALUES(titel),bronorganisatie=VALUES(bronorganisatie),
  doi=VALUES(doi),licentie=VALUES(licentie),bronbestand_naam=VALUES(bronbestand_naam),
  bronbestand_sha256=VALUES(bronbestand_sha256),bronversie=VALUES(bronversie),
  selectie_omschrijving=VALUES(selectie_omschrijving),importversie=VALUES(importversie);

DELETE e FROM externe_ecologie_event e
JOIN externe_ecologie_dataset d ON d.dataset_id=e.dataset_id
JOIN tmp_external_dataset t ON t.dataset_sleutel=d.dataset_sleutel;

CREATE TEMPORARY TABLE tmp_external_event (
  dataset_sleutel VARCHAR(128), bron_event_id VARCHAR(512), event_datum DATE,
  event_datum_tot DATE, datum_precisie VARCHAR(16),
  jaar SMALLINT UNSIGNED, latitude DECIMAL(10,7), longitude DECIMAL(10,7),
  coordinate_uncertainty_m DECIMAL(12,2), bron_locatie VARCHAR(1000),
  ruimtelijke_klasse VARCHAR(64), sampling_protocol VARCHAR(1000),
  inspanning_waarde DECIMAL(18,6), inspanning_eenheid VARCHAR(128),
  analyse_status VARCHAR(64), bronmetadata JSON
);
LOAD DATA LOCAL INFILE '{events}' INTO TABLE tmp_external_event
CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\'
LINES TERMINATED BY '\\n' IGNORE 1 LINES;
INSERT INTO externe_ecologie_event (
  dataset_id,bron_event_id,event_datum,event_datum_tot,datum_precisie,jaar,latitude,longitude,
  coordinate_uncertainty_m,bron_locatie,ruimtelijke_klasse,sampling_protocol,
  inspanning_waarde,inspanning_eenheid,analyse_status,bronmetadata
) SELECT d.dataset_id,t.bron_event_id,t.event_datum,t.event_datum_tot,t.datum_precisie,t.jaar,t.latitude,t.longitude,
  t.coordinate_uncertainty_m,t.bron_locatie,t.ruimtelijke_klasse,t.sampling_protocol,
  t.inspanning_waarde,t.inspanning_eenheid,t.analyse_status,t.bronmetadata
FROM tmp_external_event t
JOIN externe_ecologie_dataset d ON d.dataset_sleutel=t.dataset_sleutel;

CREATE TEMPORARY TABLE tmp_external_result (
  dataset_sleutel VARCHAR(128), bron_event_id VARCHAR(512), bron_occurrence_id VARCHAR(512),
  wetenschappelijke_naam VARCHAR(500), wetenschappelijke_naam_bron VARCHAR(500),
  nederlandse_naam VARCHAR(500), taxonrang VARCHAR(128),
  occurrence_status VARCHAR(16), hoeveelheid DECIMAL(24,8), hoeveelheid_oorspronkelijk VARCHAR(255),
  hoeveelheid_eenheid VARCHAR(128), basis_of_record VARCHAR(128), catalogusnummer VARCHAR(255),
  bronmetadata JSON
);
LOAD DATA LOCAL INFILE '{results}' INTO TABLE tmp_external_result
CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\'
LINES TERMINATED BY '\\n' IGNORE 1 LINES;
INSERT INTO externe_ecologie_resultaat (
  event_id,bron_occurrence_id,wetenschappelijke_naam,wetenschappelijke_naam_bron,nederlandse_naam,taxonrang,
  occurrence_status,hoeveelheid,hoeveelheid_oorspronkelijk,hoeveelheid_eenheid,
  basis_of_record,catalogusnummer,bronmetadata
) SELECT e.event_id,t.bron_occurrence_id,t.wetenschappelijke_naam,t.wetenschappelijke_naam_bron,t.nederlandse_naam,t.taxonrang,
  t.occurrence_status,t.hoeveelheid,t.hoeveelheid_oorspronkelijk,t.hoeveelheid_eenheid,
  t.basis_of_record,t.catalogusnummer,t.bronmetadata
FROM tmp_external_result t
JOIN externe_ecologie_dataset d ON d.dataset_sleutel=t.dataset_sleutel
JOIN externe_ecologie_event e ON e.dataset_id=d.dataset_id AND e.bron_event_id=t.bron_event_id;
COMMIT;
"""


def mysql_args(login_path: str) -> list[str]:
    return [f"--login-path={login_path}", "--protocol=tcp", "--host=127.0.0.1", "--port=3306", "--local-infile=1", "--binary-mode"]


def run_mysql(client: Path, args: list[str], sql: str) -> str:
    result = subprocess.run([str(client), *args], input=sql, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f"mysql stopte met code {result.returncode}")
    return result.stdout.strip()


def apply_sql_with_local_infile(client: Path, args: list[str], sql: str) -> None:
    original = run_mysql(client, args, "SELECT @@GLOBAL.local_infile;")
    changed = original.strip() != "1"
    if changed:
        run_mysql(client, args, "SET GLOBAL local_infile=1;")
    try:
        run_mysql(client, args, sql)
    finally:
        if changed:
            run_mysql(client, args, "SET GLOBAL local_infile=0;")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profiles-dir", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--mysql-client", type=Path, default=Path("/usr/local/mysql/bin/mysql"))
    parser.add_argument("--login-path", default="meijendel_root")
    parser.add_argument("--database", default=DATABASE)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source = args.profiles_dir
    stowa_measurements = {
        row["_core_id"]: (row.get("measurementValue", ""), row.get("measurementUnit", ""), row.get("measurementType", ""))
        for row in read_csv(source / "stowa_limnodata_extension_basisgebied.csv")
    }
    lvd_releves = {row["_core_id"]: row for row in read_csv(source / "lvd_releve_basisgebied.csv")}
    museum_sources = {
        "nmr": (read_csv(source / "nmr_observations_basisgebied.csv"), SOURCE_CONFIG["nmr"]),
        "botany": (read_csv(source / "naturalis_botany_basisgebied.csv"), SOURCE_CONFIG["botany"]),
        "coleoptera": (read_csv(source / "naturalis_coleoptera_basisgebied.csv"), SOURCE_CONFIG["coleoptera"]),
    }
    with tempfile.TemporaryDirectory(prefix="external-ecology-import-") as tmp:
        paths = write_import_files(
            Path(tmp),
            stowa_rows=read_csv(source / "stowa_limnodata_basisgebied.csv"),
            stowa_measurements=stowa_measurements,
            endure_events=read_csv(source / "endure_basisgebied.csv"),
            endure_results=read_csv(source / "endure_extension_basisgebied.csv"),
            museum_sources=museum_sources,
            lvd_events=read_csv(source / "lvd_events_basisgebied.csv"),
            lvd_releves=lvd_releves,
            lvd_occurrences=read_csv(source / "lvd_occurrence_basisgebied.csv"),
        )
        counts = {key: sum(1 for _ in path.open(encoding="utf-8")) - 1 for key, path in paths.items()}
        print(json.dumps(counts, ensure_ascii=False))
        if not args.apply:
            return 0
        schema = SCHEMA.read_text(encoding="utf-8").replace("USE Meijendel;", f"USE {args.database};", 1)
        sql = schema + "\n" + load_sql(paths, database=args.database)
        apply_sql_with_local_infile(args.mysql_client, mysql_args(args.login_path), sql)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
