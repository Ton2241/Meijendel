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
SCOPE_RULE_VERSION = "ndff-protocolbereik-v1"
DECISION_RULE_VERSION = "ndff-analysebesluit-v3"
SOURCE_XLSX_SHA256 = "12cccb8bf8408fae9a7819f798f4f8748c19c46211dac9f3ab0069086e565592"
SOURCE_DOCX_SHA256 = "b7dc432d59aaf3a8288873d813825d8c5448a335782fb82e1f9d01deb1b33a75"
ANALYSIS_TYPES = ("V", "I", "TV", "TA", "TK")

GENERAL_SOURCE_PROTOCOLS = {"102.004", "102.006", "104.000", "105.000"}
BYCATCH_COMBINATIONS = {
    ("03.201", "Nachtvlinders"),
    ("03.201", "Vliesvleugeligen"),
    ("14.204", "Zoogdieren (overig)"),
    ("17.204", "Vleermuizen"),
}
MIXED_COMBINATIONS = {
    ("17.204", "Zoogdieren (overig)"),
    ("17.209", "Zoogdieren (overig)"),
}
TARGET_DEPENDENT_COMBINATIONS = {
    ("02.204", "Mossen"),
    ("04.006", "Weekdieren"),
    ("10.002", "Amfibieën"),
    ("11.201", "Schimmels"),
    ("11.202", "Schimmels"),
    ("12.015", "Kranswieren, wieren en algen"),
    ("12.205", "Dagvlinders"),
    ("12.205", "Korstmossen"),
    ("12.205", "Kranswieren, wieren en algen"),
    ("12.205", "Libellen"),
    ("12.205", "Mossen"),
    ("12.205", "Sprinkhanen en krekels"),
    ("12.205", "Vaatplanten"),
    ("13.201", "Vissen"),
    ("13.202", "Amfibieën"),
    ("13.202", "Vissen"),
    ("17.202", "Vleermuizen"),
    ("17.505", "Vleermuizen"),
    ("17.506", "Vleermuizen"),
}
DAZ_TARGET_SPECIES = {
    "Oryctolagus cuniculus", "Lepus europaeus", "Vulpes vulpes",
    "Capreolus capreolus", "Sciurus vulgaris", "Erinaceus europaeus",
    "Ondatra zibethicus",
}
RABBIT_TARGET_SPECIES = {"Oryctolagus cuniculus"}
CBS_DAZ_URL = "https://longreads.cbs.nl/meetprogrammas-flora-en-fauna-2025/meetprogrammas/"
NDFF_PROTOCOL_URL = "https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/"


def classify_protocol_group(protocol_sleutel: str, soortgroep_raw: str) -> dict[str, str]:
    key = (protocol_sleutel, soortgroep_raw)
    if protocol_sleutel in GENERAL_SOURCE_PROTOCOLS:
        return {"doelrelatie": "algemene_bron", "toegestane_typen": "V"}
    if key in BYCATCH_COMBINATIONS:
        return {"doelrelatie": "bijvangst", "toegestane_typen": "V"}
    if key in MIXED_COMBINATIONS:
        return {"doelrelatie": "gemengd", "toegestane_typen": "V"}
    if key in TARGET_DEPENDENT_COMBINATIONS:
        return {"doelrelatie": "doelsoortafhankelijk", "toegestane_typen": "V"}
    return {"doelrelatie": "doelgroep", "toegestane_typen": "PROTOCOL"}


def classify_protocol_species(protocol_sleutel: str, scientific_name: str) -> dict[str, str]:
    if protocol_sleutel not in {"17.204", "17.209"}:
        raise ValueError(f"Geen soortclassificatie voor niet-gemengd protocol {protocol_sleutel}")
    targets = DAZ_TARGET_SPECIES if protocol_sleutel == "17.204" else RABBIT_TARGET_SPECIES
    if scientific_name in targets:
        return {"doelrelatie": "doelsoort", "toegestane_typen": "V,TA"}
    return {"doelrelatie": "bijvangst", "toegestane_typen": "V"}


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


def _pair_condition(protocol_alias: str, group_alias: str, pairs: set[tuple[str, str]]) -> str:
    return " OR ".join(
        f"({protocol_alias}={sql_text(protocol)} AND {group_alias}={sql_text(group)})"
        for protocol, group in sorted(pairs)
    ) or "FALSE"


def _protocol_types_sql(gebruik_alias: str = "g") -> str:
    return "CONCAT_WS(','," + ",".join(
        f"IF({sql_text(kind)}='V' OR {gebruik_alias}.hoofdtype={sql_text(kind)} "
        f"OR FIND_IN_SET({sql_text(kind)},{gebruik_alias}.aanvullende_typen)>0,{sql_text(kind)},NULL)"
        for kind in ANALYSIS_TYPES
    ) + ")"


def protocol_scope_sql() -> str:
    general_codes = ",".join(sql_text(value) for value in sorted(GENERAL_SOURCE_PROTOCOLS))
    bycatch = _pair_condition("p.protocol_sleutel", "c.soortgroep_raw", BYCATCH_COMBINATIONS)
    mixed = _pair_condition("p.protocol_sleutel", "c.soortgroep_raw", MIXED_COMBINATIONS)
    dependent = _pair_condition("p.protocol_sleutel", "c.soortgroep_raw", TARGET_DEPENDENT_COMBINATIONS)
    protocol_types = _protocol_types_sql()
    daz_targets = ",".join(sql_text(value) for value in sorted(DAZ_TARGET_SPECIES))
    rabbit_targets = ",".join(sql_text(value) for value in sorted(RABBIT_TARGET_SPECIES))
    return f"""
INSERT INTO ndff_protocol_soortgroep_geschiktheid
  (protocol_id,soortgroep_raw,doelrelatie,toegestane_typen,
   recordaantal_bij_classificatie,reden,bron_urls,regelversie,beoordeeld_op)
SELECT p.protocol_id,c.soortgroep_raw,
       CASE WHEN p.protocol_sleutel IN ({general_codes}) THEN 'algemene_bron'
            WHEN {bycatch} THEN 'bijvangst'
            WHEN {mixed} THEN 'gemengd'
            WHEN {dependent} THEN 'doelsoortafhankelijk'
            ELSE 'doelgroep' END,
       CASE WHEN p.protocol_sleutel IN ({general_codes}) OR {bycatch} OR {mixed} OR {dependent}
            THEN 'V' ELSE {protocol_types} END,
       c.recordaantal,
       CASE WHEN p.protocol_sleutel IN ({general_codes})
              THEN 'De protocolwaarde duidt een algemene bron, app of publicatievorm aan en niet een afgebakende doelsoortensurvey. Alleen positieve voorkomensinformatie (V) is op protocolbasis toegestaan.'
            WHEN {bycatch}
              THEN 'Deze soortgroep valt buiten het doelbereik van het opgegeven protocol. De records zijn bijvangst en ondersteunen alleen positieve voorkomensinformatie (V).'
            WHEN {mixed}
              THEN 'Deze combinatie bevat zowel doelsoorten als bijvangsten. Niet-V-analyses vereisen de afzonderlijke soortclassificatie.'
            WHEN {dependent}
              THEN 'Dit protocol werkt met een beperkte of projectspecifieke doelsoortenlijst die niet per NDFF-record is meegeleverd. Voorlopig is alleen positieve voorkomensinformatie (V) toegestaan.'
            ELSE 'De soortgroep valt binnen het inhoudelijke doelbereik van het protocol. De protocoltypen blijven voorlopig bruikbaar, met afzonderlijke beoordeling van leveringsgeschiktheid.' END,
       CASE WHEN {mixed} THEN JSON_ARRAY({sql_text(CBS_DAZ_URL)},{sql_text(NDFF_PROTOCOL_URL)})
            ELSE p.bron_urls END,
       {sql_text(SCOPE_RULE_VERSION)},'2026-09-11'
FROM (
  SELECT soortgroep_raw,TRIM(protocol) AS protocol_raw,COUNT(*) AS recordaantal
  FROM Meijendel.ndff_open_waarneming
  WHERE protocol IS NOT NULL AND TRIM(protocol)<>'' AND TRIM(protocol)<>'Losse waarnemingen'
  GROUP BY soortgroep_raw,TRIM(protocol)
) AS c
JOIN ndff_protocol_mapping AS m
  ON m.bron_scope='openbaar' AND m.protocol_raw=c.protocol_raw AND m.regelversie={sql_text(RULE_VERSION)}
JOIN ndff_protocol AS p ON p.protocol_id=m.protocol_id
JOIN ndff_protocol_gebruik AS g
  ON g.protocol_id=p.protocol_id AND g.regelversie={sql_text(RULE_VERSION)}
ON DUPLICATE KEY UPDATE
  doelrelatie=VALUES(doelrelatie),toegestane_typen=VALUES(toegestane_typen),
  recordaantal_bij_classificatie=VALUES(recordaantal_bij_classificatie),
  reden=VALUES(reden),bron_urls=VALUES(bron_urls),beoordeeld_op=VALUES(beoordeeld_op);

INSERT INTO ndff_protocol_soort_geschiktheid
  (protocol_id,soortgroep_raw,wetenschappelijke_naam,doelrelatie,
   toegestane_typen,recordaantal_bij_classificatie,reden,regelversie,beoordeeld_op)
SELECT p.protocol_id,w.soortgroep_raw,w.wetenschappelijke_naam,
       CASE WHEN (p.protocol_sleutel='17.204' AND w.wetenschappelijke_naam IN ({daz_targets}))
                  OR (p.protocol_sleutel='17.209' AND w.wetenschappelijke_naam IN ({rabbit_targets}))
            THEN 'doelsoort' ELSE 'bijvangst' END,
       CASE WHEN (p.protocol_sleutel='17.204' AND w.wetenschappelijke_naam IN ({daz_targets}))
                  OR (p.protocol_sleutel='17.209' AND w.wetenschappelijke_naam IN ({rabbit_targets}))
            THEN 'V,TA' ELSE 'V' END,
       COUNT(*),
       CASE WHEN (p.protocol_sleutel='17.204' AND w.wetenschappelijke_naam IN ({daz_targets}))
                  OR (p.protocol_sleutel='17.209' AND w.wetenschappelijke_naam IN ({rabbit_targets}))
            THEN 'De soort behoort tot de expliciete doelsoorten van dit telprogramma; TA blijft voorlopig toegestaan onder de algemene validatievoorbehouden.'
            ELSE 'De soort is binnen dit protocol bijvangst en ondersteunt alleen positieve voorkomensinformatie (V).' END,
       {sql_text(SCOPE_RULE_VERSION)},'2026-09-11'
FROM Meijendel.ndff_open_waarneming AS w
JOIN Meijendel.ndff_open_waarneming_protocol AS l
  ON l.waarneming_id=w.waarneming_id AND l.regelversie={sql_text(RULE_VERSION)}
JOIN Meijendel.ndff_protocol AS p ON p.protocol_id=l.protocol_id
WHERE (p.protocol_sleutel='17.204' AND w.soortgroep_raw='Zoogdieren (overig)')
   OR (p.protocol_sleutel='17.209' AND w.soortgroep_raw='Zoogdieren (overig)')
GROUP BY p.protocol_id,p.protocol_sleutel,w.soortgroep_raw,w.wetenschappelijke_naam
ON DUPLICATE KEY UPDATE
  doelrelatie=VALUES(doelrelatie),toegestane_typen=VALUES(toegestane_typen),
  recordaantal_bij_classificatie=VALUES(recordaantal_bij_classificatie),
  reden=VALUES(reden),beoordeeld_op=VALUES(beoordeeld_op);
"""


def decisions_sql() -> str:
    type_rows = " UNION ALL ".join(f"SELECT {sql_text(value)} AS analysetype" for value in ANALYSIS_TYPES)
    return f"""
INSERT IGNORE INTO ndff_analysebesluit
  (bron_scope,soortgroep_raw,protocol_id,analysetype,protocolgeschiktheid,
   gegevensgeschiktheid,eindbesluit,vereist_ruimtelijke_toets,vereist_pq_toets,
   recordaantal_bij_besluit,reden,regelversie,besloten_op)
SELECT c.bron_scope,c.soortgroep_raw,m.protocol_id,a.analysetype,
       CASE WHEN COALESCE(s.doelrelatie,'algemene_bron')='doelgroep' AND a.analysetype=g.hoofdtype THEN 'primair'
            WHEN a.analysetype='V' THEN 'voorwaardelijk'
            WHEN COALESCE(s.doelrelatie,'algemene_bron') IN ('doelgroep','gemengd','doelsoortafhankelijk')
                 AND (a.analysetype=g.hoofdtype OR FIND_IN_SET(a.analysetype,g.aanvullende_typen)>0)
              THEN 'voorwaardelijk'
            ELSE 'niet_onderbouwd' END,
       'niet_beoordeeld',
       CASE WHEN a.analysetype='V' THEN 'voorlopig_toegelaten'
            WHEN COALESCE(s.doelrelatie,'algemene_bron')='doelgroep'
                 AND FIND_IN_SET(a.analysetype,s.toegestane_typen)>0
              THEN 'voorlopig_toegelaten'
            WHEN s.doelrelatie='gemengd'
                 AND (a.analysetype=g.hoofdtype OR FIND_IN_SET(a.analysetype,g.aanvullende_typen)>0)
              THEN 'alleen_na_doelsoortselectie'
            WHEN s.doelrelatie='doelsoortafhankelijk'
                 AND (a.analysetype=g.hoofdtype OR FIND_IN_SET(a.analysetype,g.aanvullende_typen)>0)
              THEN 'wacht_op_doelsoortafbakening'
            ELSE 'uitgesloten_huidige_levering' END,
       1,1,c.recordaantal,
       CASE WHEN a.analysetype='V' OR (s.doelrelatie='doelgroep' AND FIND_IN_SET(a.analysetype,s.toegestane_typen)>0)
              THEN CONCAT('Voorlopig resultaat op basis van protocolgeschiktheid en doelbereik. ',COALESCE(s.reden,'Losse waarneming of algemene bron: alleen positieve voorkomensinformatie. '),' De leveringsgeschiktheid (telobjecten, bezoeken, inspanning, nulwaarnemingen en meeteenheden) en verdere validatie zijn nog niet beoordeeld. Gebruik de uitkomst daarom verkennend en niet als definitief bewijs van trend, afwezigheid of beheereffect.')
            WHEN s.doelrelatie='gemengd'
              THEN 'De combinatie bevat doelsoorten en bijvangsten. Gebruik voor niet-V-analyses uitsluitend soorten die in ndff_protocol_soort_geschiktheid als doelsoort zijn vastgelegd; de leveringsgeschiktheid blijft niet beoordeeld.'
            WHEN s.doelrelatie='doelsoortafhankelijk'
              THEN 'De doelsoortstatus is niet uit het NDFF-record afleidbaar. Alleen V is nu bruikbaar; andere analysetypen wachten op een gezaghebbende doelsoortenafbakening.'
            ELSE 'Het protocol onderbouwt dit analysetype niet voor de huidige levering.' END,
       {sql_text(DECISION_RULE_VERSION)},'2026-09-11'
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
LEFT JOIN ndff_protocol_soortgroep_geschiktheid AS s
  ON s.protocol_id=m.protocol_id AND s.soortgroep_raw=c.soortgroep_raw
 AND s.regelversie={sql_text(SCOPE_RULE_VERSION)}
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


def restore_legacy_decisions_sql() -> str:
    """Behoud de oorspronkelijke v1-besluiten als historische auditlaag."""
    return f"""
UPDATE ndff_analysebesluit
SET gegevensgeschiktheid=CASE WHEN analysetype='V' THEN 'voorwaardelijk' ELSE 'onvoldoende' END,
    eindbesluit=CASE
      WHEN analysetype='V' THEN 'alleen_verspreidingscontext'
      WHEN protocolgeschiktheid IN ('primair','voorwaardelijk') THEN 'wacht_op_brondata'
      ELSE 'uitgesloten_huidige_levering' END,
    reden=CASE
      WHEN analysetype='V' THEN 'Alleen positieve verspreidingscontext na afzonderlijke ruimtelijke en PQ-toets.'
      WHEN protocolgeschiktheid IN ('primair','voorwaardelijk')
        THEN 'Protocol is kandidaat, maar de huidige levering mist volledige telobjecten, bezoeken, inspanning en niet-detecties.'
      ELSE 'Het protocol onderbouwt dit analysetype niet voor de huidige levering.' END
WHERE regelversie={sql_text(RULE_VERSION)};
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
SELECT 'scope_combinations',COUNT(*) FROM Meijendel.ndff_protocol_soortgroep_geschiktheid WHERE regelversie={sql_text(SCOPE_RULE_VERSION)};
SELECT 'mixed_species',COUNT(*) FROM Meijendel.ndff_protocol_soort_geschiktheid WHERE regelversie={sql_text(SCOPE_RULE_VERSION)};
SELECT 'scope_missing',COUNT(*) FROM (
  SELECT DISTINCT l.protocol_id,w.soortgroep_raw
  FROM Meijendel.ndff_open_waarneming w
  JOIN Meijendel.ndff_open_waarneming_protocol l ON l.waarneming_id=w.waarneming_id AND l.regelversie={sql_text(RULE_VERSION)}
  JOIN Meijendel.ndff_protocol p ON p.protocol_id=l.protocol_id
  LEFT JOIN Meijendel.ndff_protocol_soortgroep_geschiktheid s
    ON s.protocol_id=l.protocol_id AND s.soortgroep_raw=w.soortgroep_raw AND s.regelversie={sql_text(SCOPE_RULE_VERSION)}
  WHERE p.protocol_sleutel<>'LOS' AND s.protocol_soortgroep_id IS NULL
) q;
SELECT 'decisions',COUNT(*) FROM Meijendel.ndff_analysebesluit WHERE regelversie={sql_text(DECISION_RULE_VERSION)};
SELECT 'protocolbesluit_mismatch',COUNT(*) FROM Meijendel.ndff_analysebesluit
WHERE regelversie={sql_text(DECISION_RULE_VERSION)} AND (
  (analysetype='V' AND eindbesluit<>'voorlopig_toegelaten') OR
  (protocolgeschiktheid='niet_onderbouwd' AND analysetype<>'V' AND eindbesluit<>'uitgesloten_huidige_levering') OR
  (protocolgeschiktheid IN ('primair','voorwaardelijk') AND analysetype<>'V'
    AND eindbesluit NOT IN ('voorlopig_toegelaten','alleen_na_doelsoortselectie','wacht_op_doelsoortafbakening'))
);
SELECT 'validatie_niet_geparkeerd',COUNT(*) FROM Meijendel.ndff_analysebesluit
WHERE regelversie={sql_text(DECISION_RULE_VERSION)} AND gegevensgeschiktheid<>'niet_beoordeeld';
"""


def validate_metrics(metrics: dict[str, int]) -> None:
    required = {
        "protocols", "uses", "mappings", "unmapped_open", "unmapped_secure",
        "open_records", "secure_records", "open_protocol_links", "secure_protocol_links",
        "open_loose_records", "open_loose_links", "secure_loose_records", "secure_loose_links",
        "blank_open_protocol", "blank_secure_protocol", "invalid_protocol_evidence",
        "spatial", "scope_combinations", "mixed_species", "scope_missing",
        "decisions", "protocolbesluit_mismatch", "validatie_niet_geparkeerd",
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
    if metrics["scope_combinations"] != 114 or metrics["mixed_species"] != 32 or metrics["scope_missing"]:
        raise ValueError("Protocol-doelbereik is niet volledig of niet op het verwachte gegevensprofiel gebaseerd.")
    if metrics["decisions"] == 0 or metrics["protocolbesluit_mismatch"]:
        raise ValueError("Analysebesluiten ontbreken of wijken af van de protocolgeschiktheid.")
    if metrics["validatie_niet_geparkeerd"]:
        raise ValueError("Leveringsgeschiktheid is ten onrechte als beoordeeld vastgelegd.")


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

    sql = "\n".join((SCHEMA.read_text(encoding="utf-8"), catalog_insert_sql(rows, SOURCE_XLSX_SHA256), mapping_sql(), record_protocol_link_sql(), spatial_sql(), protocol_scope_sql(), restore_legacy_decisions_sql(), decisions_sql()))
    client_args = mysql_args(args.login_path, args.host, args.port)
    run_mysql(args.mysql_client, client_args, sql)
    output = run_mysql(args.mysql_client, client_args + ["--batch", "--raw", "--skip-column-names"], validation_sql(), capture=True)
    metrics = {key: int(value) for key, value in (line.split("\t", 1) for line in output.splitlines())}
    validate_metrics(metrics)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
