#!/usr/bin/env python3
"""Bouw de niet-gevoelige NDFF-protocolkwaliteitslaag in lokale MySQL."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).parents[2]
SCHEMA = ROOT / "gis" / "database" / "ndff_protocolkwaliteit_schema.sql"
DEFAULT_SEED = ROOT / "gis" / "database" / "ndff_protocolkwaliteit_seed.csv"
SOURCE_XLSX = ROOT / "Natuurprotocollen" / "Natuurprotocollen_gebruiksmatrix.xlsx"
SOURCE_DOCX = ROOT / "Natuurprotocollen" / "Classificatie_natuurprotocollen_wetenschappelijk_gebruik.docx"
RULE_VERSION = "ndff-protocolkwaliteit-v1"
SOURCE_XLSX_SHA256 = "12cccb8bf8408fae9a7819f798f4f8748c19c46211dac9f3ab0069086e565592"
SOURCE_DOCX_SHA256 = "b7dc432d59aaf3a8288873d813825d8c5448a335782fb82e1f9d01deb1b33a75"
ANALYSIS_TYPES = ("V", "I", "TV", "TA", "TK")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def protocol_key(code: str | None) -> str:
    value = str(code or "").strip()
    return "LOS" if not value or value.casefold() == "geen code" else value


def protocol_code_from_raw(value: str | None) -> str:
    raw = str(value or "").strip()
    if not raw:
        raise ValueError("Een lege protocolwaarde is geen bewijs voor een losse waarneming.")
    if raw.casefold() == "losse waarnemingen":
        return "LOS"
    match = re.match(r"^(\d{2,3}\.\d{3})(?:\s|$)", raw)
    if not match:
        raise ValueError(f"Protocoltekst zonder herkenbare code: {raw!r}")
    return match.group(1)


def conditional_types(value: str | None) -> set[str]:
    return set(re.findall(r"(?<![A-Z])(TV|TA|TK|I|V)(?![A-Z])", str(value or "")))


def read_seed(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    required = {
        "protocol_sleutel", "protocol_code", "protocol_naam", "levering_scope",
        "hoofdtype", "aanvullend_gebruik", "aanvullende_typen",
        "wetenschappelijk_gebruik", "passende_analyse",
        "benodigde_onderzoekscontext", "begrenzing", "bron_nummers", "bron_urls",
    }
    if not rows or set(rows[0]) != required:
        raise ValueError("Onverwachte kolommen in protocolseed.")
    if len(rows) != 54 or len({row["protocol_sleutel"] for row in rows}) != 54:
        raise ValueError("Protocolseed moet exact 54 unieke protocollen bevatten.")
    for row in rows:
        if row["protocol_sleutel"] != protocol_key(row["protocol_code"]):
            raise ValueError(f"Protocolcode en sleutel verschillen: {row['protocol_sleutel']}")
        if row["hoofdtype"] not in ANALYSIS_TYPES:
            raise ValueError(f"Onbekend hoofdtype: {row['hoofdtype']}")
        if set(filter(None, row["aanvullende_typen"].split(","))) != conditional_types(row["aanvullend_gebruik"]):
            raise ValueError(f"Aanvullende typen verschillen: {row['protocol_sleutel']}")
        json.loads(row["bron_urls"])
    return rows


def sql_text(value: str | None, *, empty_as_null: bool = True) -> str:
    if value is None or (value == "" and empty_as_null):
        return "NULL"
    return "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"


def catalog_insert_sql(rows: Iterable[dict[str, str]], source_hash: str) -> str:
    statements: list[str] = []
    for row in rows:
        code = sql_text(row["protocol_code"] or None)
        statements.append(
            "INSERT INTO ndff_protocol "
            "(protocol_sleutel,protocol_code,protocol_naam,levering_scope,bron_nummers,bron_urls,bronbestand,bronbestand_sha256,broncontrole_datum) VALUES "
            f"({sql_text(row['protocol_sleutel'])},{code},{sql_text(row['protocol_naam'])},{sql_text(row['levering_scope'])},"
            f"{sql_text(row['bron_nummers'])},CAST({sql_text(row['bron_urls'])} AS JSON),'Natuurprotocollen_gebruiksmatrix.xlsx',"
            f"{sql_text(source_hash)},'2026-09-11') AS nieuw "
            "ON DUPLICATE KEY UPDATE protocol_naam=nieuw.protocol_naam,levering_scope=nieuw.levering_scope,"
            "bron_nummers=nieuw.bron_nummers,bron_urls=nieuw.bron_urls,bronbestand_sha256=nieuw.bronbestand_sha256,"
            "broncontrole_datum=nieuw.broncontrole_datum;"
        )
        statements.append(
            "INSERT INTO ndff_protocol_gebruik "
            "(protocol_id,hoofdtype,aanvullend_gebruik,aanvullende_typen,wetenschappelijk_gebruik,passende_analyse,"
            "benodigde_onderzoekscontext,begrenzing,regelversie,bronbestand_sha256,toelichting_sha256,broncontrole_datum) "
            "SELECT protocol_id,"
            f"{sql_text(row['hoofdtype'])},{sql_text(row['aanvullend_gebruik'])},{sql_text(row['aanvullende_typen'], empty_as_null=False)},"
            f"{sql_text(row['wetenschappelijk_gebruik'])},{sql_text(row['passende_analyse'])},"
            f"{sql_text(row['benodigde_onderzoekscontext'])},{sql_text(row['begrenzing'])},{sql_text(RULE_VERSION)},"
            f"{sql_text(source_hash)},{sql_text(SOURCE_DOCX_SHA256)},'2026-09-11' "
            f"FROM ndff_protocol WHERE protocol_sleutel={sql_text(row['protocol_sleutel'])} "
            "ON DUPLICATE KEY UPDATE hoofdtype=VALUES(hoofdtype),aanvullend_gebruik=VALUES(aanvullend_gebruik),"
            "aanvullende_typen=VALUES(aanvullende_typen),wetenschappelijk_gebruik=VALUES(wetenschappelijk_gebruik),"
            "passende_analyse=VALUES(passende_analyse),benodigde_onderzoekscontext=VALUES(benodigde_onderzoekscontext),"
            "begrenzing=VALUES(begrenzing),bronbestand_sha256=VALUES(bronbestand_sha256),"
            "toelichting_sha256=VALUES(toelichting_sha256),broncontrole_datum=VALUES(broncontrole_datum);"
        )
    return "\n".join(statements)


def mapping_sql() -> str:
    return f"""
INSERT INTO ndff_protocol_mapping
  (bron_scope,protocol_raw,protocol_id,mapping_methode,regelversie)
SELECT bron_scope, protocol_raw, p.protocol_id,
       IF(protocol_sleutel='LOS','expliciet_losse_waarneming','expliciete_code'), {sql_text(RULE_VERSION)}
FROM (
  SELECT DISTINCT 'openbaar' AS bron_scope,
    TRIM(protocol) AS protocol_raw,
    CASE WHEN TRIM(protocol)='Losse waarnemingen'
         THEN 'LOS' ELSE SUBSTRING_INDEX(TRIM(protocol),' ',1) END AS protocol_sleutel
  FROM ndff_open_waarneming
  WHERE protocol IS NOT NULL AND TRIM(protocol)<>''
  UNION
  SELECT DISTINCT 'beveiligd' AS bron_scope,
    TRIM(protocol) AS protocol_raw,
    CASE WHEN TRIM(protocol)='Losse waarnemingen'
         THEN 'LOS' ELSE SUBSTRING_INDEX(TRIM(protocol),' ',1) END AS protocol_sleutel
  FROM Meijendel_ndff_secure.ndff_waarneming_register
  WHERE protocol IS NOT NULL AND TRIM(protocol)<>''
) AS bron
JOIN ndff_protocol AS p USING (protocol_sleutel)
ON DUPLICATE KEY UPDATE
  protocol_id=VALUES(protocol_id),
  mapping_methode=VALUES(mapping_methode);
"""


def record_protocol_link_sql() -> str:
    return f"""
INSERT INTO Meijendel.ndff_open_waarneming_protocol
  (waarneming_id,protocol_id,bewijsmethode,regelversie)
SELECT w.waarneming_id,m.protocol_id,m.mapping_methode,{sql_text(RULE_VERSION)}
FROM Meijendel.ndff_open_waarneming AS w
JOIN Meijendel.ndff_protocol_mapping AS m
  ON m.bron_scope='openbaar'
 AND m.protocol_raw=TRIM(w.protocol)
 AND m.regelversie={sql_text(RULE_VERSION)}
WHERE w.protocol IS NOT NULL AND TRIM(w.protocol)<>''
ON DUPLICATE KEY UPDATE
  protocol_id=VALUES(protocol_id),
  bewijsmethode=VALUES(bewijsmethode),
  regelversie=VALUES(regelversie);

INSERT INTO Meijendel_ndff_secure.ndff_waarneming_protocol
  (waarneming_id,protocol_id,bewijsmethode,regelversie)
SELECT w.waarneming_id,m.protocol_id,m.mapping_methode,{sql_text(RULE_VERSION)}
FROM Meijendel_ndff_secure.ndff_waarneming_register AS w
JOIN Meijendel.ndff_protocol_mapping AS m
  ON m.bron_scope='beveiligd'
 AND m.protocol_raw=TRIM(w.protocol)
 AND m.regelversie={sql_text(RULE_VERSION)}
WHERE w.protocol IS NOT NULL AND TRIM(w.protocol)<>''
ON DUPLICATE KEY UPDATE
  protocol_id=VALUES(protocol_id),
  bewijsmethode=VALUES(bewijsmethode),
  regelversie=VALUES(regelversie);
"""


def spatial_sql() -> str:
    return f"""
SET @ndff_plotversie := (SELECT MAX(plotversie_id) FROM ndff_sovon_plotversie);
INSERT IGNORE INTO ndff_open_ruimtelijke_beoordeling
  (waarneming_id,regelversie,plotversie_id,geometrie_type,geometrie_oppervlakte_m2,
   vervaagd,vervagingsniveau_km,plot_match_count,eenduidig_plot_id,
   ruimtelijke_klasse,toewijzingskwaliteit,is_plotcontext_ruimtelijk_toelaatbaar)
SELECT w.waarneming_id, {sql_text(RULE_VERSION)}, @ndff_plotversie,
       UPPER(ST_GeometryType(w.openbare_geometrie)), ST_Area(w.openbare_geometrie),
       w.vervaagd, w.vervagingsniveau_km, COUNT(p.plot_id),
       CASE WHEN COUNT(p.plot_id)=1 THEN MAX(p.plot_id) ELSE NULL END,
       CASE WHEN NOT ST_IsValid(w.openbare_geometrie) THEN 'ongeldig'
            WHEN COUNT(p.plot_id)=0 THEN 'outside'
            WHEN COUNT(p.plot_id)=1 THEN 'single' ELSE 'multiple' END,
       CASE WHEN NOT ST_IsValid(w.openbare_geometrie) THEN 'ongeldig'
            WHEN COUNT(p.plot_id)=0 THEN 'outside'
            WHEN COUNT(p.plot_id)>1 THEN 'multiple'
            WHEN MAX(ST_Within(w.openbare_geometrie,p.plot_geometrie))=1 THEN 'single_volledig_binnen'
            ELSE 'single_deels' END,
       CASE WHEN w.vervaagd=0 AND COUNT(p.plot_id)=1
                  AND MAX(ST_Within(w.openbare_geometrie,p.plot_geometrie))=1
            THEN 1 ELSE 0 END
FROM ndff_open_waarneming AS w
LEFT JOIN ndff_sovon_plot AS p
  ON p.plotversie_id=@ndff_plotversie
 AND ST_Intersects(w.openbare_geometrie,p.plot_geometrie)
WHERE NOT EXISTS (
  SELECT 1 FROM ndff_open_ruimtelijke_beoordeling AS bestaand
  WHERE bestaand.waarneming_id=w.waarneming_id
    AND bestaand.regelversie={sql_text(RULE_VERSION)}
)
GROUP BY w.waarneming_id;
"""


def decisions_sql() -> str:
    type_rows = " UNION ALL ".join(f"SELECT {sql_text(value)} AS analysetype" for value in ANALYSIS_TYPES)
    return f"""
INSERT IGNORE INTO ndff_analysebesluit
  (bron_scope,soortgroep_raw,protocol_id,analysetype,protocolgeschiktheid,
   gegevensgeschiktheid,eindbesluit,vereist_ruimtelijke_toets,vereist_pq_toets,
   recordaantal_bij_besluit,reden,regelversie,besloten_op)
SELECT c.bron_scope,c.soortgroep_raw,m.protocol_id,a.analysetype,
       CASE WHEN a.analysetype=g.hoofdtype THEN 'primair'
            WHEN a.analysetype='V' OR FIND_IN_SET(a.analysetype,g.aanvullende_typen)>0 THEN 'voorwaardelijk'
            ELSE 'niet_onderbouwd' END,
       CASE WHEN a.analysetype='V' THEN 'voorwaardelijk' ELSE 'onvoldoende' END,
       CASE WHEN a.analysetype='V' THEN 'alleen_verspreidingscontext'
            WHEN a.analysetype=g.hoofdtype OR FIND_IN_SET(a.analysetype,g.aanvullende_typen)>0
              THEN 'wacht_op_brondata'
            ELSE 'uitgesloten_huidige_levering' END,
       1,1,c.recordaantal,
       CASE WHEN a.analysetype='V'
            THEN 'Alleen positieve verspreidingscontext na afzonderlijke ruimtelijke en PQ-toets.'
            WHEN a.analysetype=g.hoofdtype OR FIND_IN_SET(a.analysetype,g.aanvullende_typen)>0
              THEN 'Protocol is kandidaat, maar de huidige levering mist volledige telobjecten, bezoeken, inspanning en niet-detecties.'
            ELSE 'Het protocol onderbouwt dit analysetype niet voor de huidige levering.' END,
       {sql_text(RULE_VERSION)},'2026-09-11'
FROM (
  SELECT 'openbaar' AS bron_scope,soortgroep_raw,
         TRIM(protocol) AS protocol_raw,
         COUNT(*) AS recordaantal
  FROM ndff_open_waarneming
  WHERE protocol IS NOT NULL AND TRIM(protocol)<>''
  GROUP BY soortgroep_raw,TRIM(protocol)
  UNION ALL
  SELECT 'beveiligd' AS bron_scope,s.oorspronkelijke_ffv_soortgroep,
         TRIM(w.protocol) AS protocol_raw,
         COUNT(*) AS recordaantal
  FROM Meijendel_ndff_secure.ndff_waarneming_register AS w
  JOIN Meijendel_ndff_secure.ndff_soorten AS s ON s.ndff_soort_id=w.ndff_soort_id
  WHERE w.protocol IS NOT NULL AND TRIM(w.protocol)<>''
  GROUP BY s.oorspronkelijke_ffv_soortgroep,TRIM(w.protocol)
) AS c
JOIN ndff_protocol_mapping AS m
  ON m.bron_scope=c.bron_scope AND m.protocol_raw=c.protocol_raw AND m.regelversie={sql_text(RULE_VERSION)}
JOIN ndff_protocol_gebruik AS g
  ON g.protocol_id=m.protocol_id AND g.regelversie={sql_text(RULE_VERSION)}
CROSS JOIN ({type_rows}) AS a
WHERE 1=1
ON DUPLICATE KEY UPDATE
  protocolgeschiktheid=VALUES(protocolgeschiktheid),
  gegevensgeschiktheid=VALUES(gegevensgeschiktheid),
  eindbesluit=VALUES(eindbesluit),
  vereist_ruimtelijke_toets=VALUES(vereist_ruimtelijke_toets),
  vereist_pq_toets=VALUES(vereist_pq_toets),
  recordaantal_bij_besluit=VALUES(recordaantal_bij_besluit),
  reden=VALUES(reden),
  besloten_op=VALUES(besloten_op);
"""


def mysql_args(login_path: str, host: str, port: int) -> list[str]:
    return [f"--login-path={login_path}", "--protocol=tcp", f"--host={host}", f"--port={port}", "--binary-mode"]


def run_mysql(client: Path, args: list[str], sql: str, capture: bool = False) -> str:
    result = subprocess.run([str(client), *args], input=sql, text=True, capture_output=True, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f"MySQL stopte met code {result.returncode}")
    return result.stdout.strip() if capture else ""


def validation_sql() -> str:
    return f"""
SELECT 'protocols',COUNT(*) FROM Meijendel.ndff_protocol;
SELECT 'uses',COUNT(*) FROM Meijendel.ndff_protocol_gebruik WHERE regelversie={sql_text(RULE_VERSION)};
SELECT 'mappings',COUNT(*) FROM Meijendel.ndff_protocol_mapping WHERE regelversie={sql_text(RULE_VERSION)};
SELECT 'unmapped_open',COUNT(*) FROM (SELECT DISTINCT TRIM(w.protocol) raw_protocol FROM Meijendel.ndff_open_waarneming w LEFT JOIN Meijendel.ndff_protocol_mapping m ON m.bron_scope='openbaar' AND m.protocol_raw=TRIM(w.protocol) AND m.regelversie={sql_text(RULE_VERSION)} WHERE w.protocol IS NOT NULL AND TRIM(w.protocol)<>'' AND m.mapping_id IS NULL) q;
SELECT 'unmapped_secure',COUNT(*) FROM (SELECT DISTINCT TRIM(w.protocol) raw_protocol FROM Meijendel_ndff_secure.ndff_waarneming_register w LEFT JOIN Meijendel.ndff_protocol_mapping m ON m.bron_scope='beveiligd' AND m.protocol_raw=TRIM(w.protocol) AND m.regelversie={sql_text(RULE_VERSION)} WHERE w.protocol IS NOT NULL AND TRIM(w.protocol)<>'' AND m.mapping_id IS NULL) q;
SELECT 'open_records',COUNT(*) FROM Meijendel.ndff_open_waarneming;
SELECT 'secure_records',COUNT(*) FROM Meijendel_ndff_secure.ndff_waarneming_register;
SELECT 'open_protocol_links',COUNT(*) FROM Meijendel.ndff_open_waarneming_protocol WHERE regelversie={sql_text(RULE_VERSION)};
SELECT 'secure_protocol_links',COUNT(*) FROM Meijendel_ndff_secure.ndff_waarneming_protocol WHERE regelversie={sql_text(RULE_VERSION)};
SELECT 'open_loose_records',COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE TRIM(protocol)='Losse waarnemingen';
SELECT 'open_loose_links',COUNT(*) FROM Meijendel.ndff_open_waarneming_protocol l JOIN Meijendel.ndff_protocol p ON p.protocol_id=l.protocol_id WHERE l.regelversie={sql_text(RULE_VERSION)} AND p.protocol_sleutel='LOS' AND l.bewijsmethode='expliciet_losse_waarneming';
SELECT 'secure_loose_records',COUNT(*) FROM Meijendel_ndff_secure.ndff_waarneming_register WHERE TRIM(protocol)='Losse waarnemingen';
SELECT 'secure_loose_links',COUNT(*) FROM Meijendel_ndff_secure.ndff_waarneming_protocol l JOIN Meijendel.ndff_protocol p ON p.protocol_id=l.protocol_id WHERE l.regelversie={sql_text(RULE_VERSION)} AND p.protocol_sleutel='LOS' AND l.bewijsmethode='expliciet_losse_waarneming';
SELECT 'blank_open_protocol',COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol IS NULL OR TRIM(protocol)='';
SELECT 'blank_secure_protocol',COUNT(*) FROM Meijendel_ndff_secure.ndff_waarneming_register WHERE protocol IS NULL OR TRIM(protocol)='';
SELECT 'invalid_protocol_evidence',COUNT(*) FROM (
  SELECT l.waarneming_id FROM Meijendel.ndff_open_waarneming_protocol l JOIN Meijendel.ndff_protocol p ON p.protocol_id=l.protocol_id
  WHERE (p.protocol_sleutel='LOS')<>(l.bewijsmethode='expliciet_losse_waarneming')
  UNION ALL
  SELECT l.waarneming_id FROM Meijendel_ndff_secure.ndff_waarneming_protocol l JOIN Meijendel.ndff_protocol p ON p.protocol_id=l.protocol_id
  WHERE (p.protocol_sleutel='LOS')<>(l.bewijsmethode='expliciet_losse_waarneming')
) q;
SELECT 'spatial',COUNT(*) FROM Meijendel.ndff_open_ruimtelijke_beoordeling WHERE regelversie={sql_text(RULE_VERSION)};
SELECT 'decisions',COUNT(*) FROM Meijendel.ndff_analysebesluit WHERE regelversie={sql_text(RULE_VERSION)};
SELECT 'admitted_non_distribution',COUNT(*) FROM Meijendel.ndff_analysebesluit WHERE regelversie={sql_text(RULE_VERSION)} AND analysetype<>'V' AND eindbesluit='toegelaten';
"""


def validate_metrics(metrics: dict[str, int]) -> None:
    required = {
        "protocols", "uses", "mappings", "unmapped_open", "unmapped_secure",
        "open_records", "secure_records", "open_protocol_links", "secure_protocol_links",
        "open_loose_records", "open_loose_links", "secure_loose_records", "secure_loose_links",
        "blank_open_protocol", "blank_secure_protocol", "invalid_protocol_evidence",
        "spatial", "decisions", "admitted_non_distribution",
    }
    if set(metrics) != required:
        raise ValueError(f"Onvolledige validatie-uitvoer: {sorted(set(metrics) ^ required)}")
    if metrics["protocols"] != 54 or metrics["uses"] != 54 or metrics["mappings"] != 91:
        raise ValueError("Protocolcatalogus, gebruiksmatrix of tekstkoppeling is onvolledig.")
    if metrics["unmapped_open"] or metrics["unmapped_secure"]:
        raise ValueError("Niet alle NDFF-protocolteksten zijn gekoppeld.")
    if metrics["blank_open_protocol"] or metrics["blank_secure_protocol"]:
        raise ValueError("Een lege protocolwaarde mag niet stilzwijgend als LOS worden gekwalificeerd.")
    if metrics["open_protocol_links"] != metrics["open_records"] or metrics["secure_protocol_links"] != metrics["secure_records"]:
        raise ValueError("Niet ieder NDFF-record heeft precies één protocolkoppeling.")
    if metrics["open_loose_links"] != metrics["open_loose_records"] or metrics["secure_loose_links"] != metrics["secure_loose_records"]:
        raise ValueError("Niet iedere expliciete losse waarneming is aan LOS gekoppeld.")
    if metrics["invalid_protocol_evidence"]:
        raise ValueError("Protocol_sleutel en bewijsmethode zijn niet consistent.")
    if metrics["spatial"] != metrics["open_records"]:
        raise ValueError("Niet ieder openbaar NDFF-record heeft een ruimtelijke beoordeling.")
    if metrics["decisions"] == 0 or metrics["admitted_non_distribution"]:
        raise ValueError("Analysebesluiten ontbreken of laten niet-verspreidingsgebruik toe.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=Path, default=DEFAULT_SEED)
    parser.add_argument("--mysql-client", type=Path, default=Path("/usr/local/mysql/bin/mysql"))
    parser.add_argument("--login-path", default="meijendel_root")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3306)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if sha256_file(SOURCE_XLSX) != SOURCE_XLSX_SHA256 or sha256_file(SOURCE_DOCX) != SOURCE_DOCX_SHA256:
        raise ValueError("Een protocolbrondocument wijkt af van de beoordeelde versie.")
    rows = read_seed(args.seed)
    if args.dry_run:
        print(f"OK: {len(rows)} protocollen, bronhashes en invoercontract gevalideerd")
        return 0

    sql = "\n".join((SCHEMA.read_text(encoding="utf-8"), catalog_insert_sql(rows, SOURCE_XLSX_SHA256), mapping_sql(), record_protocol_link_sql(), spatial_sql(), decisions_sql()))
    client_args = mysql_args(args.login_path, args.host, args.port)
    run_mysql(args.mysql_client, client_args, sql)
    output = run_mysql(args.mysql_client, client_args + ["--batch", "--raw", "--skip-column-names"], validation_sql(), capture=True)
    metrics = {key: int(value) for key, value in (line.split("\t", 1) for line in output.splitlines())}
    validate_metrics(metrics)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
