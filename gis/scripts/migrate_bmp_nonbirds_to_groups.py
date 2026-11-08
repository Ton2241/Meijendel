#!/usr/bin/env python3
"""Verplaats afgeronde BMP-niet-vogelgegevens naar soortgroeptabellen.

De lokale levende database is de bron. De originele jaarlijkse SOVON-
bezoektotalen worden rechtstreeks van de T7 gelezen. Zonder --apply is dit
uitsluitend een broncontrole. De zware export- en VPS-keten worden niet gestart.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from collections import Counter
from pathlib import Path

from import_ndff_protocolkwaliteit import (
    read_sovon_bmp_matrix,
    read_sovon_bmp_visit_totals,
    sovon_avimap_analysis_views_sql,
    sql_text,
)
from import_external_ecology_sources import (
    CentralQueryDatabase,
    central_query_audit,
    central_query_routes,
    central_query_triggers_sql,
)


MYSQL = Path("/usr/local/mysql/bin/mysql")
LOGIN = ("--login-path=meijendel_root", "--protocol=tcp", "--host=127.0.0.1", "--port=3306")
SOURCE = Path("/Volumes/T7 Data/Home_Ton/Meijendel data/SOVON/Per jaar")
GROUPS = ("zoogdieren", "amfibieen", "reptielen", "dagvlinders", "vliesvleugeligen")
RULE = "bmp-niet-vogel-complete-lijst-v1"


def query(sql: str) -> list[list[str]]:
    result = subprocess.run(
        [str(MYSQL), *LOGIN, "--batch", "--raw", "--skip-column-names", "-e", sql],
        text=True, capture_output=True, check=False,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "MySQL-query mislukt")
    return [line.split("\t") for line in result.stdout.splitlines() if line]


def run_sql(statements: list[str], database: str = "Meijendel") -> None:
    result = subprocess.run(
        [str(MYSQL), *LOGIN, f"--database={database}"],
        input="\n".join(statements), text=True, capture_output=True, check=False,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "MySQL-migratie mislukt")


def destination(group: str | None, scientific_name: str) -> str:
    if group in ("zoogdieren_overig", "vleermuizen"):
        return "zoogdieren"
    if group in GROUPS[1:]:
        return group
    if group is None and scientific_name in (
        "Microtus arvalis/agrestis", "Martes", "Sorex araneus spec."
    ):
        return "zoogdieren"
    raise ValueError(f"Geen vastgelegde soortgroeproute: {scientific_name}/{group}")


def literal(value: str | int | None) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, int):
        return str(value)
    # Hex houdt ook apostrofs, backslashes, regeleinden en Unicode brongetrouw.
    return f"CONVERT(X'{value.encode('utf-8').hex()}' USING utf8mb4)"


def visit_and_taxon_map() -> tuple[dict[int, int], dict[int, tuple[int, int, str]]]:
    visits = {int(row[0]): int(row[1]) for row in query(
        "SELECT bezoek_id,jaar FROM Meijendel.dagbezoeken_bmp WHERE jaar BETWEEN 2005 AND 2025"
    )}
    code_map: dict[int, tuple[int, int, str]] = {}
    rows = query("""
        SELECT s.euring_code,b.taxon_id,b.koppeling_id,g.groep_code,t.wetenschappelijke_naam
        FROM Meijendel.soorten s
        JOIN Meijendel.taxa_bronkoppeling b ON b.koppeling_id=s.taxon_bronkoppeling_id
        JOIN Meijendel.taxa t ON t.taxon_id=b.taxon_id
        LEFT JOIN Meijendel.taxon_groepen g ON g.groep_id=t.groep_id
    """)
    for code, taxon, link, group, name in rows:
        if group == "vogels":
            continue
        code_map[int(code)] = (int(taxon), int(link), destination(None if group == "NULL" else group, name))
    return visits, code_map


def annual_rows(source_dir: Path, visits: dict[int, int], code_map: dict[int, tuple[int, int, str]]) -> tuple[list[dict], dict]:
    result: list[dict] = []
    manifest: dict[str, str] = {}
    for year in range(2005, 2026):
        year_dir = source_dir / str(year)
        matrix_files = list(year_dir.glob("Avimap_totalen_territoria*.xlsx"))
        total_files = list(year_dir.glob("Avimap_bezoektotalen*.xlsx"))
        if len(matrix_files) != 1 or len(total_files) != 1:
            raise RuntimeError(f"SOVON {year}: matrix of bezoektotalen niet uniek aanwezig")
        matrix = read_sovon_bmp_matrix(matrix_files[0], year)
        totals = read_sovon_bmp_visit_totals(total_files[0], matrix)
        manifest[str(year)] = hashlib.sha256(total_files[0].read_bytes()).hexdigest()
        for row in totals["visit_taxa"]:
            code = int(row["euring_code"])
            if code not in code_map:
                continue  # vogel: hoort niet bij deze migratie
            visit = int(row["bron_bezoek_id"])
            if visit not in visits:
                if int(row["plot_id"]) == 29945:
                    continue  # De Horsten, buiten Meijendel
                raise RuntimeError(f"SOVON-bezoek {visit} uit {year} ontbreekt in dagbezoeken_bmp")
            if visits[visit] != year:
                raise RuntimeError(f"SOVON-bezoek {visit} heeft een afwijkend jaar")
            taxon, link, group = code_map[code]
            result.append({
                "year": year, "visit": visit, "taxon": taxon, "link": link,
                "group": group, "inside": int(row["aantal_waarnemingen"]),
                "outside": int(row["aantal_buiten_plot"]),
                "source": {"bronbestand_sha256": manifest[str(year)],
                           "euring_code": code, "bron_naam": row["bron_naam"],
                           "bronwaarde_raw": row["bronwaarde_raw"],
                           "plot_id": row["plot_id"], "jaar": year},
            })
    keys = [(r["visit"], r["taxon"]) for r in result]
    if len(keys) != len(set(keys)):
        raise RuntimeError("Dubbele SOVON-bezoek/taxoncel in jaarbestanden")
    return result, manifest


def source_metrics(rows: list[dict]) -> dict:
    groups = Counter(row["group"] for row in rows)
    return {"bezoektotalen": len(rows), "bezoeken": len({r["visit"] for r in rows}),
            "per_groep": dict(sorted(groups.items()))}


def schema_sql(group: str) -> str:
    return f"""
CREATE TABLE Meijendel.`{group}` (
  rij_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  regeltype ENUM('bronpunt','brontotaal','ndff_reconstructie',
                 'sovon_reconstructie','sovon_jaarreconstructie','meetuitkomst') NOT NULL,
  bron_sleutel VARCHAR(120) NOT NULL,
  bezoek_id INT NOT NULL,
  taxon_id BIGINT UNSIGNED NOT NULL,
  taxon_bronkoppeling_id BIGINT UNSIGNED NOT NULL,
  waarnemingsstatus ENUM('waargenomen','afgeleide_nul','onbepaald_ambigu') NOT NULL,
  aantal INT NULL,
  aantal_buiten_plot INT NULL,
  zelfstandig_meetellen TINYINT(1) NOT NULL DEFAULT 0,
  regelversie VARCHAR(100) NOT NULL,
  bronwaarden JSON NULL,
  geom POINT SRID 28992 NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  UNIQUE KEY uq_{group}_bron (regeltype,bron_sleutel),
  KEY ix_{group}_taxon_bezoek (taxon_id,bezoek_id),
  KEY ix_{group}_bronlink (taxon_bronkoppeling_id),
  CONSTRAINT fk_{group}_bezoek FOREIGN KEY (bezoek_id)
      REFERENCES Meijendel.dagbezoeken_bmp(bezoek_id),
  CONSTRAINT fk_{group}_taxon FOREIGN KEY (taxon_id)
      REFERENCES Meijendel.taxa(taxon_id),
  CONSTRAINT fk_{group}_bronlink FOREIGN KEY (taxon_bronkoppeling_id)
      REFERENCES Meijendel.taxa_bronkoppeling(koppeling_id),
  CONSTRAINT chk_{group}_telling CHECK (
    (regeltype='meetuitkomst' AND zelfstandig_meetellen=1
     AND waarnemingsstatus IN ('waargenomen','afgeleide_nul'))
    OR (regeltype<>'meetuitkomst' AND zelfstandig_meetellen=0)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
"""


def preflight(rows: list[dict]) -> dict:
    if query("SELECT VERSION()")[0][0] != "9.7.4":
        raise RuntimeError("De lokale MySQL-versie is niet 9.7.4")
    existing = query("SELECT table_name FROM information_schema.tables WHERE table_schema='Meijendel' "
                     "AND table_name IN ('zoogdieren','amfibieen','reptielen','dagvlinders','vliesvleugeligen')")
    if existing:
        raise RuntimeError(f"Doeltabellen bestaan al: {existing}")
    baseline = query("""
      SELECT COUNT(*),COUNT(DISTINCT w.bron_waarneming_id)
      FROM Meijendel.sovon_avimap_waarneming w
      JOIN Meijendel.sovon_avimap_import_batch b ON b.batch_id=w.batch_id AND b.actueel=1
      WHERE w.jaar BETWEEN 2009 AND 2025
    """)[0]
    if [int(x) for x in baseline] != [19153, 19153]:
        raise RuntimeError(f"Primaire SOVON-uitgangsstand gewijzigd: {baseline}")
    if len(rows) != 7399:
        raise RuntimeError(f"SOVON-jaartotalen gewijzigd: {len(rows)}")
    ungrouped = query("SELECT taxon_id,wetenschappelijke_naam,groep_id FROM Meijendel.taxa "
                      "WHERE taxon_id IN (39891,39903,43144) ORDER BY taxon_id")
    if ungrouped != [["39891", "Microtus arvalis/agrestis", "NULL"],
                     ["39903", "Martes", "NULL"],
                     ["43144", "Sorex araneus spec.", "NULL"]]:
        raise RuntimeError("Drie BMP-zoogdiertaxa hebben onverwachte identiteit of groepsindeling")
    return {"mysql": "9.7.4", "primaire_punten_2009_2025": 19153,
            **source_metrics(rows), "doeltabellen": list(GROUPS), "wijziging": False}


def json_object_sql(alias: str, table: str) -> str:
    columns = [row[0] for row in query(
        "SELECT COLUMN_NAME FROM information_schema.COLUMNS "
        f"WHERE TABLE_SCHEMA='Meijendel' AND TABLE_NAME={sql_text(table)} "
        "AND COLUMN_NAME<>'geom' ORDER BY ORDINAL_POSITION"
    )]
    pairs = ",".join(f"{literal(column)},{alias}.`{column}`" for column in columns)
    if table == "sovon_avimap_waarneming":
        pairs += f",{literal('geom_wkt')},ST_AsText({alias}.geom)"
    return f"JSON_OBJECT({pairs})"


def apply_sql(annual: list[dict]) -> list[str]:
    """Bouw brongetrouwe rijen en één analyse-uitkomst per bezoek/taxon."""
    statements = [schema_sql(group) for group in GROUPS]
    statements.append("START TRANSACTION;")
    statements.append(
        "UPDATE Meijendel.taxa SET groep_id=(SELECT groep_id FROM Meijendel.taxon_groepen "
        "WHERE groep_code='zoogdieren_overig') "
        "WHERE taxon_id IN (39891,39903,43144) AND groep_id IS NULL;"
    )
    point_json = json_object_sql("w", "sovon_avimap_waarneming")
    group_codes: dict[str, list[int]] = {group: [] for group in GROUPS}
    _, code_map = visit_and_taxon_map()
    for code, (_, _, group) in code_map.items():
        group_codes[group].append(code)
    for group in GROUPS:
        codes = ",".join(str(code) for code in sorted(group_codes[group]))
        statements.append(f"""
INSERT INTO Meijendel.`{group}`
  (regeltype,bron_sleutel,bezoek_id,taxon_id,taxon_bronkoppeling_id,
   waarnemingsstatus,aantal,aantal_buiten_plot,zelfstandig_meetellen,
   regelversie,bronwaarden,geom)
SELECT 'bronpunt',CONCAT('sovon:',w.bron_waarneming_id),w.bron_bezoek_id,
       b.taxon_id,s.taxon_bronkoppeling_id,'waargenomen',
       IF(w.in_plot=1,w.aantal,0),IF(w.in_plot=0,w.aantal,0),0,
       'sovon-avimap-252-v1',{point_json},w.geom
FROM Meijendel.sovon_avimap_waarneming w
JOIN Meijendel.sovon_avimap_import_batch x ON x.batch_id=w.batch_id AND x.actueel=1
JOIN Meijendel.sovon_avimap_taxon s ON s.batch_id=w.batch_id
  AND s.soortgroep_code=w.soortgroep_code AND s.soortnr=w.soortnr
JOIN Meijendel.taxa_bronkoppeling b ON b.koppeling_id=s.taxon_bronkoppeling_id
JOIN Meijendel.dagbezoeken_bmp v ON v.bezoek_id=w.bron_bezoek_id
WHERE w.jaar BETWEEN 2009 AND 2025 AND w.soortnr IN ({codes});
""")
    for start in range(0, len(annual), 300):
        batch = annual[start:start + 300]
        by_group: dict[str, list[str]] = {group: [] for group in GROUPS}
        for row in batch:
            key = f"sovonjaar:{row['visit']}:{row['taxon']}"
            source_json = json.dumps(row["source"], ensure_ascii=False, sort_keys=True)
            by_group[row["group"]].append(
                f"('brontotaal',{literal(key)},{row['visit']},{row['taxon']},{row['link']},"
                f"'waargenomen',{row['inside']},{row['outside']},0,"
                f"'sovon-bmp-jaarbestanden-v1',CAST({literal(source_json)} AS JSON))"
            )
        for group, values in by_group.items():
            if values:
                statements.append(
                    f"INSERT INTO Meijendel.`{group}` "
                    "(regeltype,bron_sleutel,bezoek_id,taxon_id,taxon_bronkoppeling_id,"
                    "waarnemingsstatus,aantal,aantal_buiten_plot,zelfstandig_meetellen,regelversie,bronwaarden) VALUES "
                    + ",".join(values) + ";"
                )
    ndff_json = json_object_sql("d", "daz_bmp_bezoek_taxon")
    sovon_json = json_object_sql("d", "sovon_avimap_daz_bezoek_taxon")
    statements.append(f"""
INSERT INTO Meijendel.zoogdieren
  (regeltype,bron_sleutel,bezoek_id,taxon_id,taxon_bronkoppeling_id,
   waarnemingsstatus,aantal,aantal_buiten_plot,zelfstandig_meetellen,
   regelversie,bronwaarden)
SELECT 'ndff_reconstructie',CONCAT('ndff-daz:',d.bezoek_id,':',b.taxon_id),
       d.bezoek_id,b.taxon_id,d.taxon_bronkoppeling_id,
       CASE WHEN d.waarnemingsstatus='waargenomen' THEN 'waargenomen'
            WHEN d.waarnemingsstatus='onbepaald_ambigu' THEN 'onbepaald_ambigu'
            ELSE 'afgeleide_nul' END,
       d.aantal,COALESCE(d.aantal_buiten_plot,0),0,d.reconstructieversie,
       {ndff_json}
FROM Meijendel.daz_bmp_bezoek_taxon d
JOIN Meijendel.taxa_bronkoppeling b ON b.koppeling_id=d.taxon_bronkoppeling_id
WHERE d.reconstructieversie='ndff-daz-bmp-v1';
""")
    statements.append(f"""
INSERT INTO Meijendel.zoogdieren
  (regeltype,bron_sleutel,bezoek_id,taxon_id,taxon_bronkoppeling_id,
   waarnemingsstatus,aantal,aantal_buiten_plot,zelfstandig_meetellen,
   regelversie,bronwaarden)
SELECT 'sovon_reconstructie',CONCAT('sovon-daz:',d.batch_id,':',d.bron_bezoek_id,
       ':',b.taxon_id),d.bron_bezoek_id,b.taxon_id,d.taxon_bronkoppeling_id,
       IF(d.waarnemingsstatus='waargenomen','waargenomen','afgeleide_nul'),
       d.aantal,0,0,d.reconstructieversie,{sovon_json}
FROM Meijendel.sovon_avimap_daz_bezoek_taxon d
JOIN Meijendel.sovon_avimap_bezoek v ON v.batch_id=d.batch_id
  AND v.bron_bezoek_id=d.bron_bezoek_id
JOIN Meijendel.taxa_bronkoppeling b ON b.koppeling_id=d.taxon_bronkoppeling_id
WHERE v.jaar BETWEEN 2009 AND 2025;
""")
    statements.append(f"""
INSERT INTO Meijendel.zoogdieren
  (regeltype,bron_sleutel,bezoek_id,taxon_id,taxon_bronkoppeling_id,
   waarnemingsstatus,aantal,aantal_buiten_plot,zelfstandig_meetellen,
   regelversie,bronwaarden)
SELECT 'sovon_jaarreconstructie',CONCAT('sovon-jaar-daz:',d.bezoek_id,':',b.taxon_id),
       d.bezoek_id,b.taxon_id,d.taxon_bronkoppeling_id,
       IF(d.waarnemingsstatus='waargenomen','waargenomen','afgeleide_nul'),
       d.aantal,d.aantal_buiten_plot,0,d.reconstructieversie,{ndff_json}
FROM Meijendel.daz_bmp_bezoek_taxon d
JOIN Meijendel.taxa_bronkoppeling b ON b.koppeling_id=d.taxon_bronkoppeling_id
WHERE d.reconstructieversie='sovon-bmp-jaarbestanden-v1';
""")
    source_columns = ("bezoek_id,taxon_id,taxon_bronkoppeling_id,regeltype,"
                      "waarnemingsstatus,aantal,aantal_buiten_plot")
    statements.extend([
        f"CREATE TEMPORARY TABLE bmp_source AS SELECT {source_columns} "
        "FROM Meijendel.`zoogdieren` WHERE regeltype<>'meetuitkomst';",
    ])
    for group in GROUPS[1:]:
        statements.append(
            f"INSERT INTO bmp_source SELECT {source_columns} "
            f"FROM Meijendel.`{group}` WHERE regeltype<>'meetuitkomst';"
        )
    statements.extend([
        "CREATE TEMPORARY TABLE bmp_visits AS SELECT DISTINCT bezoek_id FROM bmp_source;",
        "CREATE TEMPORARY TABLE bmp_taxa AS SELECT taxon_id,MIN(taxon_bronkoppeling_id) AS link_id "
        "FROM bmp_source GROUP BY taxon_id;",
        "CREATE TEMPORARY TABLE bmp_points AS SELECT bezoek_id,taxon_id,"
        "SUM(aantal) AS aantal,SUM(aantal_buiten_plot) AS buiten "
        "FROM bmp_source WHERE regeltype='bronpunt' GROUP BY bezoek_id,taxon_id;",
        "CREATE TEMPORARY TABLE bmp_annual AS SELECT bezoek_id,taxon_id,aantal,"
        "aantal_buiten_plot AS buiten FROM bmp_source WHERE regeltype='brontotaal';",
        "CREATE TEMPORARY TABLE bmp_ndff AS SELECT bezoek_id,taxon_id,aantal,"
        "aantal_buiten_plot AS buiten FROM bmp_source "
        "WHERE regeltype='ndff_reconstructie' AND waarnemingsstatus='waargenomen';",
        "CREATE TEMPORARY TABLE bmp_positive_raw AS "
        "SELECT bezoek_id,taxon_id,aantal,buiten,1 AS prioriteit,'sovon_punt' AS bron "
        "FROM bmp_points UNION ALL "
        "SELECT bezoek_id,taxon_id,aantal,buiten,2,'sovon_jaartotaal' "
        "FROM bmp_annual UNION ALL "
        "SELECT bezoek_id,taxon_id,aantal,buiten,3,'ndff_historisch' FROM bmp_ndff;",
        "CREATE TEMPORARY TABLE bmp_positive AS SELECT bezoek_id,taxon_id,aantal,buiten,bron "
        "FROM (SELECT p.*,ROW_NUMBER() OVER (PARTITION BY bezoek_id,taxon_id "
        "ORDER BY prioriteit) AS rn FROM bmp_positive_raw p) z WHERE rn=1;",
    ])
    # Een centrale taxon-ID hoort in precies één fysieke soortgroeptabel.
    union_taxa = " UNION ALL ".join(
        f"SELECT taxon_id,{literal(group)} AS groep FROM Meijendel.`{group}` "
        "WHERE regeltype<>'meetuitkomst'" for group in GROUPS
    )
    statements.append(f"CREATE TEMPORARY TABLE bmp_group_taxa AS SELECT taxon_id,MIN(groep) AS groep,"
                      f"COUNT(DISTINCT groep) AS groepen FROM ({union_taxa}) z GROUP BY taxon_id;")
    for group in GROUPS:
        statements.append(f"""
INSERT INTO Meijendel.`{group}`
  (regeltype,bron_sleutel,bezoek_id,taxon_id,taxon_bronkoppeling_id,
   waarnemingsstatus,aantal,aantal_buiten_plot,zelfstandig_meetellen,
   regelversie,bronwaarden)
SELECT 'meetuitkomst',CONCAT('bmp:',v.bezoek_id,':',t.taxon_id),
       v.bezoek_id,t.taxon_id,t.link_id,
       IF(p.bron IS NULL,'afgeleide_nul','waargenomen'),
       COALESCE(p.aantal,0),COALESCE(p.buiten,0),1,{literal(RULE)},
       JSON_OBJECT('gekozen_bron',p.bron,'nulregel',{literal(RULE)})
FROM bmp_visits v CROSS JOIN bmp_taxa t
JOIN bmp_group_taxa g ON g.taxon_id=t.taxon_id AND g.groep={literal(group)}
LEFT JOIN bmp_positive p ON p.bezoek_id=v.bezoek_id AND p.taxon_id=t.taxon_id;
""")
    # SQL-fouten breken de sessie af en rollen de data-invoer terug.
    statements.extend([
        "CREATE TEMPORARY TABLE bmp_guard (bad BIGINT NOT NULL CHECK (bad=0));",
        "INSERT INTO bmp_guard SELECT (SELECT COUNT(*) FROM bmp_group_taxa WHERE groepen<>1)"
        " + ABS((SELECT COUNT(*) FROM bmp_taxa)-37)"
        " + ABS((SELECT COUNT(*) FROM Meijendel.taxa WHERE taxon_id IN (39891,39903,43144) "
        "AND groep_id=(SELECT groep_id FROM Meijendel.taxon_groepen "
        "WHERE groep_code='zoogdieren_overig'))-3)"
        " + ABS((SELECT COUNT(*) FROM bmp_visits)-4598)"
        " + ABS((SELECT COUNT(*) FROM Meijendel.zoogdieren WHERE regeltype='bronpunt')-19071)"
        " + ABS((SELECT COUNT(*) FROM Meijendel.zoogdieren WHERE regeltype='ndff_reconstructie')-10374)"
        " + ABS((SELECT COUNT(*) FROM Meijendel.zoogdieren WHERE regeltype='sovon_reconstructie')-28422)"
        " + ABS((SELECT COUNT(*) FROM Meijendel.zoogdieren WHERE regeltype='sovon_jaarreconstructie')-5452)"
        " + ABS((SELECT SUM(c) FROM ("
        + " UNION ALL ".join(
            f"SELECT COUNT(*) c FROM Meijendel.`{group}` WHERE regeltype='meetuitkomst'"
            for group in GROUPS
        ) + ") z)-170126);",
        "COMMIT;",
    ])
    return statements


def validate_new_tables(database: str = "Meijendel") -> dict[str, dict[str, int]]:
    result: dict[str, dict[str, int]] = {}
    for group in GROUPS:
        rows = query(f"SELECT regeltype,COUNT(*) FROM `{database}`.`{group}` GROUP BY regeltype")
        result[group] = {name: int(count) for name, count in rows}
    if sum(values.get("bronpunt", 0) for values in result.values()) != 19153:
        raise RuntimeError("Niet alle SOVON-punten 2009–2025 zijn in soortgroeptabellen aanwezig")
    if sum(values.get("brontotaal", 0) for values in result.values()) != 7399:
        raise RuntimeError("Niet alle SOVON-bezoektotalen zijn in soortgroeptabellen aanwezig")
    if result["zoogdieren"].get("ndff_reconstructie") != 10374:
        raise RuntimeError("De historische NDFF-uitkomsten zijn niet compleet")
    if result["zoogdieren"].get("sovon_reconstructie") != 28422:
        raise RuntimeError("De SOVON-bezoekuitkomsten 2009–2025 zijn niet compleet")
    if result["zoogdieren"].get("sovon_jaarreconstructie") != 5452:
        raise RuntimeError("De reeds opgeslagen SOVON-jaaruitkomsten zijn niet compleet")
    if sum(values.get("meetuitkomst", 0) for values in result.values()) != 170126:
        raise RuntimeError("De bezoek-soortmatrix is niet compleet")
    if query(f"SELECT COUNT(*) FROM `{database}`.sovon_avimap_waarneming WHERE jaar=2026")[0][0] != "807":
        raise RuntimeError("De 2026-bronpunten zijn onverwacht gewijzigd")
    return result


def source_parity(database: str) -> None:
    """Bronidentiteit, alle bronvelden en puntgeometrie vóór verwijdering."""
    db = f"`{database}`"
    points = " UNION ALL ".join(
        f"SELECT bron_sleutel,bronwaarden,geom FROM {db}.`{group}` WHERE regeltype='bronpunt'"
        for group in GROUPS
    )
    point_json = json_object_sql("w", "sovon_avimap_waarneming")
    point_check = query(f"""
SELECT COUNT(*),COALESCE(SUM(z.bron_sleutel IS NULL),0),
       COALESCE(SUM(NOT (z.bronwaarden <=> {point_json})),0),
       COALESCE(SUM(w.geom IS NOT NULL AND
         (z.geom IS NULL OR NOT ST_Equals(w.geom,z.geom))),0)
FROM {db}.sovon_avimap_waarneming w
LEFT JOIN ({points}) z ON z.bron_sleutel=CONCAT('sovon:',w.bron_waarneming_id)
WHERE w.jaar BETWEEN 2009 AND 2025;
""")[0]
    if [int(n) for n in point_check] != [19153, 0, 0, 0]:
        raise RuntimeError(f"SOVON-punten ontbreken of verschillen van hun bron: {point_check}")
    sovon_json = json_object_sql("d", "sovon_avimap_daz_bezoek_taxon")
    ndff_json = json_object_sql("d", "daz_bmp_bezoek_taxon")
    checks = (
        ("sovon_avimap_daz_bezoek_taxon", "sovon_reconstructie", 28422,
         "CONCAT('sovon-daz:',d.batch_id,':',d.bron_bezoek_id,':',b.taxon_id)",
         "JOIN " + db + ".sovon_avimap_bezoek v ON v.batch_id=d.batch_id "
         "AND v.bron_bezoek_id=d.bron_bezoek_id", "v.jaar BETWEEN 2009 AND 2025", sovon_json),
        ("daz_bmp_bezoek_taxon", "ndff_reconstructie", 10374,
         "CONCAT('ndff-daz:',d.bezoek_id,':',b.taxon_id)", "",
         "d.reconstructieversie='ndff-daz-bmp-v1'", ndff_json),
        ("daz_bmp_bezoek_taxon", "sovon_jaarreconstructie", 5452,
         "CONCAT('sovon-jaar-daz:',d.bezoek_id,':',b.taxon_id)", "",
         "d.reconstructieversie='sovon-bmp-jaarbestanden-v1'", ndff_json),
    )
    for table, kind, expected, key, extra_join, scope, source_json in checks:
        actual = query(f"""
SELECT COUNT(*),COALESCE(SUM(z.rij_id IS NULL),0),
       COALESCE(SUM(NOT (z.bronwaarden <=> {source_json})),0)
FROM {db}.`{table}` d {extra_join}
JOIN {db}.taxa_bronkoppeling b ON b.koppeling_id=d.taxon_bronkoppeling_id
LEFT JOIN {db}.zoogdieren z ON z.regeltype='{kind}' AND z.bron_sleutel={key}
WHERE {scope};
""")[0]
        if [int(n) for n in actual] != [expected, 0, 0]:
            raise RuntimeError(f"{kind}: bronvelden ontbreken of verschillen: {actual}")


def switch_views(database: str) -> None:
    sql = sovon_avimap_analysis_views_sql(migrated_nonbirds=True)
    run_sql([sql.replace("Meijendel.", f"`{database}`.")], database)
    expected = ("19960", "30657")
    actual = tuple(query(f"SELECT COUNT(*) FROM `{database}`.{view}")[0][0]
                   for view in ("v_sovon_avimap_niet_vogel_analyse",
                                "v_sovon_avimap_daz_analyse"))
    if actual != expected:
        raise RuntimeError(f"SOVON-analyseviews hebben gewijzigde rijtellingen: {actual}")


def cleanup_old_trend_rows(database: str) -> None:
    """Verwijder alleen de bewezen gekopieerde trendrijen, met 2026 intact."""
    db = f"`{database}`"
    run_sql([
        "START TRANSACTION;",
        "CREATE TEMPORARY TABLE bmp_cleanup_guard (bad BIGINT NOT NULL CHECK (bad=0));",
        f"INSERT INTO bmp_cleanup_guard SELECT "
        f"ABS((SELECT COUNT(*) FROM {db}.sovon_avimap_waarneming WHERE jaar BETWEEN 2009 AND 2025)-19153) + "
        f"ABS((SELECT COUNT(*) FROM {db}.sovon_avimap_daz_bezoek_taxon d JOIN {db}.sovon_avimap_bezoek v "
        "ON v.batch_id=d.batch_id AND v.bron_bezoek_id=d.bron_bezoek_id "
        "WHERE v.jaar BETWEEN 2009 AND 2025)-28422) + "
        f"ABS((SELECT COUNT(*) FROM {db}.daz_bmp_bezoek_taxon WHERE reconstructieversie="
        "'ndff-daz-bmp-v1')-10374) + "
        f"ABS((SELECT COUNT(*) FROM {db}.daz_bmp_bezoek_taxon WHERE reconstructieversie="
        "'sovon-bmp-jaarbestanden-v1')-5452);",
        f"DELETE FROM {db}.sovon_avimap_waarneming WHERE jaar BETWEEN 2009 AND 2025;",
        f"DELETE d FROM {db}.sovon_avimap_daz_bezoek_taxon d JOIN {db}.sovon_avimap_bezoek v "
        "ON v.batch_id=d.batch_id AND v.bron_bezoek_id=d.bron_bezoek_id "
        "WHERE v.jaar BETWEEN 2009 AND 2025;",
        f"DELETE FROM {db}.daz_bmp_bezoek_taxon WHERE reconstructieversie "
        "IN ('ndff-daz-bmp-v1','sovon-bmp-jaarbestanden-v1');",
        f"INSERT INTO bmp_cleanup_guard SELECT (SELECT COUNT(*) FROM {db}.sovon_avimap_waarneming "
        "WHERE jaar BETWEEN 2009 AND 2025) + (SELECT COUNT(*) FROM "
        f"{db}.sovon_avimap_daz_bezoek_taxon d JOIN {db}.sovon_avimap_bezoek v "
        "ON v.batch_id=d.batch_id AND v.bron_bezoek_id=d.bron_bezoek_id "
        "WHERE v.jaar BETWEEN 2009 AND 2025) + (SELECT COUNT(*) FROM "
        f"{db}.daz_bmp_bezoek_taxon WHERE reconstructieversie "
        "IN ('ndff-daz-bmp-v1','sovon-bmp-jaarbestanden-v1'));",
        "COMMIT;",
    ], database)
    remaining = query(f"SELECT COUNT(*) FROM {db}.sovon_avimap_waarneming WHERE jaar=2026")[0][0]
    if remaining != "807":
        raise RuntimeError("SOVON-2026-bronpunten zijn niet intact")


def install_and_check_central_guards(database: str) -> dict:
    db = CentralQueryDatabase(database, writable=True)
    routes = central_query_routes(db.schema())
    db.sql(central_query_triggers_sql({'routes': routes}), write=True)
    result = central_query_audit(CentralQueryDatabase(database))
    if result['errors']:
        raise RuntimeError('Centrale taxonpoort blokkeert: ' + '; '.join(result['errors']))
    return {'tabellen': result['tables'], 'taxonroutes': len(result['routes']),
            'fouten': len(result['errors'])}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=SOURCE)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--rehearse-db", choices=("Meijendel_bmp_restore_20261108",))
    parser.add_argument("--backup", type=Path)
    parser.add_argument("--backup-sha256")
    args = parser.parse_args()
    if args.apply and args.rehearse_db:
        parser.error("Kies de tijdelijke herstelproef of de levende database, niet beide")
    visits, code_map = visit_and_taxon_map()
    annual, manifest = annual_rows(args.source_dir, visits, code_map)
    report = preflight(annual)
    report["bronhashes"] = manifest
    if args.rehearse_db:
        statements = [sql.replace("Meijendel.", f"{args.rehearse_db}.")
                      for sql in apply_sql(annual)]
        run_sql(statements, args.rehearse_db)
        report["nieuwe_tabellen"] = validate_new_tables(args.rehearse_db)
        source_parity(args.rehearse_db)
        switch_views(args.rehearse_db)
        cleanup_old_trend_rows(args.rehearse_db)
        report["centrale_taxonpoort"] = install_and_check_central_guards(args.rehearse_db)
        report["herstelproef"] = args.rehearse_db
        report["wijziging"] = False
    if args.apply:
        if not args.backup or not args.backup_sha256:
            parser.error("--apply vereist een gecontroleerde volledige --backup en --backup-sha256")
        backup_root = Path("/Volumes/T7 Data/Home_Ton/Meijendel data/Backups-archief/Meijendel")
        if args.backup.parent != backup_root or not args.backup.name.endswith(".sql.gz"):
            parser.error("Herstelback-up moet op de aangewezen T7-locatie staan")
        digest = hashlib.sha256()
        with args.backup.open('rb') as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b''):
                digest.update(chunk)
        if digest.hexdigest() != args.backup_sha256:
            raise RuntimeError("Herstelback-up heeft een afwijkende SHA-256")
        run_sql(apply_sql(annual))
        report["nieuwe_tabellen"] = validate_new_tables()
        source_parity("Meijendel")
        switch_views("Meijendel")
        cleanup_old_trend_rows("Meijendel")
        report["centrale_taxonpoort"] = install_and_check_central_guards("Meijendel")
        report["wijziging"] = True
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
