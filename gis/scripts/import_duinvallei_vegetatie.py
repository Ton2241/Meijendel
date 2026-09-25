#!/usr/bin/env python3
"""Importeer de niet-geolokaliseerde duinvalleireeks in Meijendel_bronnen."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
import tempfile
from collections import namedtuple
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CORE_SCHEMA = ROOT / "gis" / "database" / "meijendel_bronnen_schema.sql"
SCHEMA = ROOT / "gis" / "database" / "duinvallei_vegetatie_schema.sql"
DATABASE = "Meijendel_bronnen"
BRON_SLEUTEL = "duinvallei-vegetatie-2001-2018"
IMPORT_VERSION = "duinvallei-vegetatie-v1"
DATASET_TITLE = "21 years of restoration of dune slack communities after 42 years of river water infiltration in Meijendel, the Netherlands"
DATASET_DOI = "10.5281/zenodo.21796880"
DATASET_DATE = "2026-08-04"
METADATA_FILE = "Data_Schoon.csv"
MATRIX_FILE = "Table_complete_v3.csv"
SCRIPT_FILE = "2026_Analyse_Meijendel_V3.R"
SOIL_PARAMETERS = ("OM", "Moist", "pH", "NO3", "NH4", "PO4", "K", "Na", "Ntot", "Ptot")
EXPECTED_CODES = {0, 1, 2, 3, 4, 6, 8, 9, 18, 38, 68, 88}
SOURCE_EXCLUSIONS = {
    "18I01": "159 van 208 taxa positief; vergelijkbare opnamen bevatten maximaal 40 taxa",
}
EXPECTED_HASHES = {
    "metadata": "e1e13016bcb426d9cb6108c379b936b60b81764246cee4d779acbea640777ba9",
    "matrix": "410cf5fc049324d3e6c309f4bde62eb57e9085aaa7178176d76c7f9414e52937",
    "script": "56212ff1d1a26f0f8e3a18b6b521461a585da17901d85699b4e3467ff38dc040",
}
EXPECTED_PROFILE = {
    "metadata_rows": 488,
    "matrix_rows": 488,
    "stable_plots": 186,
    "taxa": 208,
    "matrix_cells": 101504,
    "positive_cells": 10989,
    "zero_cells": 90515,
    "excluded_observations": 1,
    "analysis_observations": 487,
    "analysis_matrix_cells": 101296,
    "analysis_positive_cells": 10830,
    "analysis_zero_cells": 90466,
}
SourceData = namedtuple("SourceData", "metadata matrix taxa")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalized_location(value: str) -> str:
    return "KV_2018" if value == "KV-2018" else value


def observation_status(source_id: str) -> tuple[str, str | None]:
    reason = SOURCE_EXCLUSIONS.get(source_id)
    return ("uitgesloten_bronanomalie", reason) if reason else ("toegelaten", None)


def read_sources(metadata_path: Path, matrix_path: Path) -> SourceData:
    with metadata_path.open(encoding="utf-8-sig", newline="") as handle:
        metadata_rows = list(csv.DictReader(handle))
    with matrix_path.open(encoding="utf-8-sig", newline="") as handle:
        matrix_rows = list(csv.DictReader(handle, delimiter=";"))
    if not metadata_rows or not matrix_rows:
        raise ValueError("Bronbestanden bevatten geen gegevensregels")
    metadata_ids = [row["id"] for row in metadata_rows]
    matrix_ids = [row["id"] for row in matrix_rows]
    if len(set(metadata_ids)) != len(metadata_ids):
        raise ValueError("Dubbele id in Data_Schoon.csv")
    if len(set(matrix_ids)) != len(matrix_ids):
        raise ValueError("Dubbele id in Table_complete_v3.csv")
    if set(metadata_ids) != set(matrix_ids):
        raise ValueError("De id-verzamelingen van metadata en soortenmatrix verschillen")
    matrix_by_id = {row["id"]: row for row in matrix_rows}
    matrix_rows = [matrix_by_id[source_id] for source_id in metadata_ids]
    taxa = tuple(name for name in matrix_rows[0] if name != "id")
    for row in matrix_rows:
        if tuple(name for name in row if name != "id") != taxa:
            raise ValueError("Taxonkolommen verschillen binnen de soortenmatrix")
        for taxon in taxa:
            try:
                code = int(row[taxon])
            except (TypeError, ValueError) as exc:
                raise ValueError(f"Ongeldige bedekkingscode bij {row['id']} / {taxon}") from exc
            if code not in EXPECTED_CODES:
                raise ValueError(f"Onbekende bedekkingscode {code} bij {row['id']} / {taxon}")
    return SourceData(metadata_rows, matrix_rows, taxa)


def iter_matrix_rows(source: SourceData):
    for row in source.matrix:
        for taxon in source.taxa:
            code = int(row[taxon])
            yield row["id"], taxon, code, int(code > 0)


def profile_source(source: SourceData) -> dict[str, int]:
    all_rows = list(iter_matrix_rows(source))
    excluded = set(SOURCE_EXCLUSIONS) & {row["id"] for row in source.metadata}
    analysis_rows = [row for row in all_rows if row[0] not in excluded]
    return {
        "metadata_rows": len(source.metadata),
        "matrix_rows": len(source.matrix),
        "stable_plots": len({row["Site"] for row in source.metadata}),
        "taxa": len(source.taxa),
        "matrix_cells": len(all_rows),
        "positive_cells": sum(row[3] for row in all_rows),
        "zero_cells": sum(not row[3] for row in all_rows),
        "excluded_observations": len(excluded),
        "analysis_observations": len(source.metadata) - len(excluded),
        "analysis_matrix_cells": len(analysis_rows),
        "analysis_positive_cells": sum(row[3] for row in analysis_rows),
        "analysis_zero_cells": sum(not row[3] for row in analysis_rows),
    }


def validate_expected_source(profile: dict[str, int], hashes: dict[str, str]) -> None:
    if hashes != EXPECTED_HASHES:
        raise ValueError(f"SHA-256 van bronbestanden wijkt af: {hashes}")
    if profile != EXPECTED_PROFILE:
        raise ValueError(f"Bronprofiel wijkt af: verwacht {EXPECTED_PROFILE}, ontvangen {profile}")


def mysql_field(value) -> str:
    if value is None:
        return r"\N"
    return str(value).replace("\\", "\\\\").replace("\t", r"\t").replace("\n", r"\n").replace("\r", r"\r")


def write_tsv(path: Path, header: tuple[str, ...], rows) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write("\t".join(header) + "\n")
        for row in rows:
            handle.write("\t".join(mysql_field(value) for value in row) + "\n")


def location_type(row: dict[str, str]) -> str:
    prefix = normalized_location(row["Location"]).split("_", 1)[0]
    if prefix not in {"KV", "PP", "LV"}:
        raise ValueError(f"Onbekend locatietype bij {row['id']}: {prefix}")
    return prefix


def create_import_files(source: SourceData, target: Path) -> dict[str, Path]:
    target.mkdir(parents=True, exist_ok=True)
    meta_by_id = {row["id"]: row for row in source.metadata}
    plot_types: dict[str, set[str]] = {}
    for row in source.metadata:
        plot_types.setdefault(row["Site"], set()).add(location_type(row))
    conflicts = {key: value for key, value in plot_types.items() if len(value) != 1}
    if conflicts:
        raise ValueError(f"Plotcodes met meerdere locatietypen: {conflicts}")

    paths = {name: target / f"{name}.tsv" for name in ("plots", "observations", "taxa", "cover", "soil")}
    descriptions = {"KV": "Kikkervalleien", "PP": "Parnassiapad", "LV": "Libellenvallei"}
    write_tsv(
        paths["plots"],
        ("site_code", "locatietype", "omschrijving"),
        ((site, next(iter(types)), descriptions[next(iter(types))]) for site, types in sorted(plot_types.items())),
    )
    observation_rows = []
    for row in source.metadata:
        status, reason = observation_status(row["id"])
        observation_rows.append(
            (
                row["id"], row["Site"], row["Year"], row["Block"], row["Plot"],
                row["Grouping_Code"], row["Location"], normalized_location(row["Location"]),
                status, reason, json.dumps(row, ensure_ascii=False, separators=(",", ":")),
            )
        )
    write_tsv(
        paths["observations"],
        ("bron_opname_id", "site_code", "jaar", "blok_raw", "plotnummer_raw", "grouping_code_raw", "locatie_raw", "locatie_genormaliseerd", "analyse_status", "uitsluitingsreden", "bronmetadata"),
        observation_rows,
    )
    write_tsv(paths["taxa"], ("wetenschappelijke_naam_raw",), ((taxon,) for taxon in source.taxa))
    write_tsv(
        paths["cover"],
        ("bron_opname_id", "wetenschappelijke_naam_raw", "bedekkingscode", "aanwezig"),
        iter_matrix_rows(source),
    )
    soil_rows = []
    for source_id, row in meta_by_id.items():
        for parameter in SOIL_PARAMETERS:
            value = row[parameter].strip()
            if value:
                soil_rows.append((source_id, parameter, value))
    write_tsv(paths["soil"], ("bron_opname_id", "parameter_sleutel", "waarde"), soil_rows)
    return paths


def mysql_args(login_path: str, host: str, port: int) -> list[str]:
    return [
        f"--login-path={login_path}", "--protocol=tcp", f"--host={host}", f"--port={port}",
        "--local-infile=1", "--binary-mode", "--batch", "--raw", "--skip-column-names",
    ]


def run_mysql(client: Path, args: list[str], sql: str) -> str:
    result = subprocess.run([str(client), *args], input=sql, text=True, capture_output=True, check=True)
    return result.stdout.strip()


def run_with_local_infile(client: Path, args: list[str], sql: str) -> None:
    previous = run_mysql(client, args, "SELECT @@GLOBAL.local_infile")
    if previous == "0":
        run_mysql(client, args, "SET GLOBAL local_infile=ON")
    try:
        run_mysql(client, args, sql)
    finally:
        if previous == "0":
            run_mysql(client, args, "SET GLOBAL local_infile=OFF")


def sql_quote(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"


def load_sql(paths: dict[str, Path], source_dir: Path, hashes: dict[str, str]) -> str:
    files = {key: str(path.resolve()).replace("\\", "\\\\").replace("'", "''") for key, path in paths.items()}
    return f"""
USE {DATABASE};
START TRANSACTION;
INSERT INTO bron (
  bron_sleutel,bron_type,titel,omschrijving,bronorganisatie,jaar_van,jaar_tot,
  soortgroep,geografische_status,geografische_toelichting,analyse_status,
  rechten_status,regelversie
) VALUES (
  {sql_quote(BRON_SLEUTEL)},'dataset','Duinvalleivegetatie Meijendel 2001-2018',
  'Volledige soortenmatrix en bodemmetingen op 186 stabiele locatiecodes.',
  'Openbare onderzoeksdataset',2001,2018,'Vaatplanten en vegetatie',
  'niet_geolokaliseerd',
  'De 488 opnamen hebben stabiele locatiecodes, maar nog geen geometrie per opname.',
  'context_alleen','geregistreerde_onderzoekers','meijendel-bronnen-v1'
)
ON DUPLICATE KEY UPDATE titel=VALUES(titel),omschrijving=VALUES(omschrijving),
  geografische_status=VALUES(geografische_status),
  geografische_toelichting=VALUES(geografische_toelichting),
  analyse_status=VALUES(analyse_status),regelversie=VALUES(regelversie);
SET @bron_id = (SELECT bron_id FROM bron WHERE bron_sleutel={sql_quote(BRON_SLEUTEL)});
INSERT INTO duinvallei_import_batch (
  bron_id,dataset_titel,dataset_doi,dataset_publicatiedatum,
  metadata_bestand,metadata_bronbestand_sha256,
  matrix_bestand,matrix_bronbestand_sha256,
  analysescript_bestand,analysescript_bronbestand_sha256,
  bronopname_aantal,taxon_aantal,importversie
) VALUES (
  @bron_id,{sql_quote(DATASET_TITLE)},{sql_quote(DATASET_DOI)},{sql_quote(DATASET_DATE)},
  {sql_quote(METADATA_FILE)},{sql_quote(hashes['metadata'])},
  {sql_quote(MATRIX_FILE)},{sql_quote(hashes['matrix'])},
  {sql_quote(SCRIPT_FILE)},{sql_quote(hashes['script'])},
  488,208,{sql_quote(IMPORT_VERSION)}
);
SET @batch_id = LAST_INSERT_ID();

CREATE TEMPORARY TABLE tmp_duinvallei_plot (
  site_code VARCHAR(32), locatietype VARCHAR(2), omschrijving VARCHAR(255)
);
LOAD DATA LOCAL INFILE '{files['plots']}' INTO TABLE tmp_duinvallei_plot
CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\'
LINES TERMINATED BY '\\n' IGNORE 1 LINES;
INSERT INTO duinvallei_plot (batch_id,site_code,locatietype,omschrijving)
SELECT @batch_id,site_code,locatietype,omschrijving FROM tmp_duinvallei_plot;

CREATE TEMPORARY TABLE tmp_duinvallei_opname (
  bron_opname_id VARCHAR(32), site_code VARCHAR(32), jaar SMALLINT,
  blok_raw VARCHAR(16), plotnummer_raw SMALLINT, grouping_code_raw VARCHAR(64),
  locatie_raw VARCHAR(64), locatie_genormaliseerd VARCHAR(64), analyse_status VARCHAR(64),
  uitsluitingsreden VARCHAR(500), bronmetadata LONGTEXT
);
LOAD DATA LOCAL INFILE '{files['observations']}' INTO TABLE tmp_duinvallei_opname
CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\'
LINES TERMINATED BY '\\n' IGNORE 1 LINES;
INSERT INTO duinvallei_opname (
  batch_id,plot_id,bron_opname_id,jaar,blok_raw,plotnummer_raw,grouping_code_raw,
  locatie_raw,locatie_genormaliseerd,analyse_status,uitsluitingsreden,bronmetadata
)
SELECT @batch_id,p.plot_id,t.bron_opname_id,t.jaar,t.blok_raw,t.plotnummer_raw,
       t.grouping_code_raw,t.locatie_raw,t.locatie_genormaliseerd,t.analyse_status,
       NULLIF(t.uitsluitingsreden,'\\N'),CAST(t.bronmetadata AS JSON)
FROM tmp_duinvallei_opname t
JOIN duinvallei_plot p ON p.batch_id=@batch_id AND p.site_code=t.site_code;

CREATE TEMPORARY TABLE tmp_duinvallei_taxon (wetenschappelijke_naam_raw VARCHAR(500));
LOAD DATA LOCAL INFILE '{files['taxa']}' INTO TABLE tmp_duinvallei_taxon
CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\'
LINES TERMINATED BY '\\n' IGNORE 1 LINES;
INSERT INTO duinvallei_taxon (batch_id,wetenschappelijke_naam_raw)
SELECT @batch_id,wetenschappelijke_naam_raw FROM tmp_duinvallei_taxon;

CREATE TEMPORARY TABLE tmp_duinvallei_bedekking (
  bron_opname_id VARCHAR(32), wetenschappelijke_naam_raw VARCHAR(500),
  bedekkingscode SMALLINT, aanwezig TINYINT
);
LOAD DATA LOCAL INFILE '{files['cover']}' INTO TABLE tmp_duinvallei_bedekking
CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\'
LINES TERMINATED BY '\\n' IGNORE 1 LINES;
INSERT INTO duinvallei_bedekking (opname_id,taxon_id,bedekkingscode,aanwezig)
SELECT o.opname_id,x.taxon_id,t.bedekkingscode,t.aanwezig
FROM tmp_duinvallei_bedekking t
JOIN duinvallei_opname o ON o.batch_id=@batch_id AND o.bron_opname_id=t.bron_opname_id
JOIN duinvallei_taxon x ON x.batch_id=@batch_id AND x.wetenschappelijke_naam_raw=t.wetenschappelijke_naam_raw;

CREATE TEMPORARY TABLE tmp_duinvallei_bodem (
  bron_opname_id VARCHAR(32), parameter_sleutel VARCHAR(16), waarde DECIMAL(20,9)
);
LOAD DATA LOCAL INFILE '{files['soil']}' INTO TABLE tmp_duinvallei_bodem
CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\'
LINES TERMINATED BY '\\n' IGNORE 1 LINES;
INSERT INTO duinvallei_bodemmeting (opname_id,parameter_sleutel,waarde)
SELECT o.opname_id,t.parameter_sleutel,t.waarde
FROM tmp_duinvallei_bodem t
JOIN duinvallei_opname o ON o.batch_id=@batch_id AND o.bron_opname_id=t.bron_opname_id;
COMMIT;
"""


def live_counts(client: Path, args: list[str]) -> dict[str, int]:
    query = """
USE Meijendel_bronnen;
SELECT 'batches',COUNT(*) FROM duinvallei_import_batch
UNION ALL SELECT 'plots',COUNT(*) FROM duinvallei_plot
UNION ALL SELECT 'observations',COUNT(*) FROM duinvallei_opname
UNION ALL SELECT 'excluded',COUNT(*) FROM duinvallei_opname WHERE analyse_status='uitgesloten_bronanomalie'
UNION ALL SELECT 'analysis_observations',COUNT(*) FROM v_duinvallei_analyse_opname
UNION ALL SELECT 'taxa',COUNT(*) FROM duinvallei_taxon
UNION ALL SELECT 'cover',COUNT(*) FROM duinvallei_bedekking
UNION ALL SELECT 'analysis_cover',COUNT(*) FROM v_duinvallei_analyse_bedekking
UNION ALL SELECT 'analysis_positive',COUNT(*) FROM v_duinvallei_analyse_bedekking WHERE aanwezig=1
UNION ALL SELECT 'analysis_zero',COUNT(*) FROM v_duinvallei_analyse_bedekking WHERE aanwezig=0
UNION ALL SELECT 'soil',COUNT(*) FROM duinvallei_bodemmeting;
"""
    output = run_mysql(client, args, query)
    return {line.split("\t")[0]: int(line.split("\t")[1]) for line in output.splitlines()}


def assert_live_counts(counts: dict[str, int]) -> None:
    expected = {
        "batches": 1,
        "plots": 186,
        "observations": 488,
        "excluded": 1,
        "analysis_observations": 487,
        "taxa": 208,
        "cover": 101504,
        "analysis_cover": 101296,
        "analysis_positive": 10830,
        "analysis_zero": 90466,
        "soil": 855,
    }
    if counts != expected:
        raise ValueError(f"Live telling wijkt af: verwacht {expected}, ontvangen {counts}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path)
    parser.add_argument("--mysql-client", type=Path, default=Path("/usr/local/mysql/bin/mysql"))
    parser.add_argument("--login-path", default="meijendel_root")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3306)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--execute", action="store_true")
    mode.add_argument("--audit-live", action="store_true")
    options = parser.parse_args()
    connection = mysql_args(options.login_path, options.host, options.port)
    if options.audit_live:
        counts = live_counts(options.mysql_client, connection)
        assert_live_counts(counts)
        print(json.dumps({"status": "PASS", "counts": counts}, indent=2))
        return 0
    if not options.source_dir:
        parser.error("--source-dir is verplicht voor --dry-run en --execute")
    paths = {name: options.source_dir / filename for name, filename in {
        "metadata": METADATA_FILE, "matrix": MATRIX_FILE, "script": SCRIPT_FILE,
    }.items()}
    for path in paths.values():
        if not path.is_file():
            raise SystemExit(f"Ontbrekend bronbestand: {path}")
    source = read_sources(paths["metadata"], paths["matrix"])
    profile = profile_source(source)
    hashes = {name: sha256_file(path) for name, path in paths.items()}
    validate_expected_source(profile, hashes)
    report = {"status": "VALID", "import_version": IMPORT_VERSION, "hashes": hashes, "profile": profile}
    if options.dry_run:
        print(json.dumps(report, indent=2, ensure_ascii=False))
        return 0
    run_mysql(options.mysql_client, connection, CORE_SCHEMA.read_text(encoding="utf-8"))
    run_mysql(options.mysql_client, connection, SCHEMA.read_text(encoding="utf-8"))
    existing = run_mysql(
        options.mysql_client,
        connection,
        f"USE {DATABASE}; SELECT COUNT(*) FROM duinvallei_import_batch "
        f"WHERE metadata_bronbestand_sha256={sql_quote(hashes['metadata'])} "
        f"AND matrix_bronbestand_sha256={sql_quote(hashes['matrix'])} "
        f"AND analysescript_bronbestand_sha256={sql_quote(hashes['script'])};",
    )
    if int(existing) == 0:
        with tempfile.TemporaryDirectory(prefix="duinvallei-import-") as tmp:
            staging = create_import_files(source, Path(tmp))
            run_with_local_infile(
                options.mysql_client,
                connection,
                load_sql(staging, options.source_dir, hashes),
            )
    counts = live_counts(options.mysql_client, connection)
    assert_live_counts(counts)
    report["status"] = "PASS"
    report["live_counts"] = counts
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
