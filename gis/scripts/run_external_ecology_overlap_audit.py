#!/usr/bin/env python3
"""Bouw de overlapclassificatie voor externe ecologiebronnen opnieuw op."""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter, defaultdict
from datetime import datetime, timezone
from decimal import Decimal
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
AUDIT_SQL = ROOT / "gis" / "scripts" / "audit_external_ecology_overlap.sql"
PQ_INVENTORY_SQL = """
SET NAMES utf8mb4;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION READ ONLY, WITH CONSISTENT SNAPSHOT;
SELECT JSON_OBJECT('kind','province','data',JSON_OBJECT(
  'opname_id',w.opname_id,'year',p.jaar,'name',b.bronmetadata->>'$.latijnse_naam_bron',
  'code',w.abundantie_code,'quantity',CAST(w.abundantie_percentage AS CHAR)))
FROM pq_vegetatie_waarneming w
JOIN pq_vegetatie_opname p USING(opname_id)
JOIN taxa_bronkoppeling b ON b.koppeling_id=w.taxon_bronkoppeling_id
ORDER BY w.waarneming_id;
SELECT JSON_OBJECT('kind','lvd','data',JSON_OBJECT(
  'event_id',r.event_id,'year',e.jaar,'name',r.wetenschappelijke_naam,
  'code',JSON_UNQUOTE(JSON_EXTRACT(
    CAST(REPLACE(JSON_UNQUOTE(JSON_EXTRACT(r.bronmetadata,'$.dynamicProperties')),
      CHAR(39),CHAR(34)) AS JSON),'$.coverScaleCode')),
  'quantity',CAST(r.hoeveelheid AS CHAR),
  'layer',JSON_UNQUOTE(JSON_EXTRACT(r.bronmetadata,'$.layer'))))
FROM externe_ecologie_resultaat r
JOIN externe_ecologie_event e USING(event_id)
JOIN externe_ecologie_dataset d USING(dataset_id)
WHERE d.dataset_sleutel='lvd-meijendel-v1-6'
ORDER BY r.resultaat_id;
SELECT JSON_OBJECT('kind','pair','data',JSON_OBJECT(
  'event_id',e.event_id,'opname_id',p.opname_id,'date',p.opname_datum,
  'date_precision',e.datum_precisie,
  'distance_m',ROUND(ST_Distance(p.geom,
    ST_Transform(ST_SRID(Point(e.longitude,e.latitude),4326),28992)),3),
  'source_uncertainty_m',e.coordinate_uncertainty_m))
FROM externe_ecologie_event e
JOIN externe_ecologie_dataset d USING(dataset_id)
JOIN pq_vegetatie_opname p ON p.opname_datum BETWEEN e.event_datum AND e.event_datum_tot
  AND ST_Distance(p.geom,ST_Transform(ST_SRID(Point(e.longitude,e.latitude),4326),28992))
    <= GREATEST(COALESCE(e.coordinate_uncertainty_m,0),5)
WHERE d.dataset_sleutel='lvd-meijendel-v1-6'
ORDER BY e.event_id,p.opname_id;
ROLLBACK;
"""
# Expliciete bronkolommen: de verplaatste tabellen hebben extra beheervelden.
for _table, _columns in {
    'resultaat': 'resultaat_id,event_id,wetenschappelijke_naam,hoeveelheid,bronmetadata',
    'event': 'event_id,dataset_id,jaar,datum_precisie,coordinate_uncertainty_m,longitude,latitude,event_datum,event_datum_tot',
}.items():
    _target = 'bronresultaat' if _table == 'resultaat' else 'bronopname'
    PQ_INVENTORY_SQL = PQ_INVENTORY_SQL.replace(
        f'FROM externe_ecologie_{_table} ',
        f'FROM (SELECT {_columns} FROM externe_ecologie_{_table} UNION ALL '
        f'SELECT {_columns} FROM pq_vegetatie_{_target}) ')
    PQ_INVENTORY_SQL = PQ_INVENTORY_SQL.replace(
        f'JOIN externe_ecologie_{_table} ',
        f'JOIN (SELECT {_columns} FROM externe_ecologie_{_table} UNION ALL '
        f'SELECT {_columns} FROM pq_vegetatie_{_target}) ')


def compare_pq_recordings(province: list[dict], lvd: list[dict]) -> dict:
    """Vergelijk complete bronopnamen, niet slechts overlappende soorten.

    Naam/code-gelijkheid bewijst geen gedeelde eventID of locationID. Lagen,
    aantallen bronregels en verschillende percentageconversies blijven zichtbaar.
    De uitvoer is uitsluitend bewijs voor beoordeling, nooit een migratiebesluit.
    """
    def key(row):
        return (row["name"].strip().casefold(), row["code"])

    def values(rows):
        return Counter((key(row), Decimal(str(row["quantity"]))) for row in rows)

    same = bool(province and lvd) and Counter(map(key, province)) == Counter(map(key, lvd))
    complete = all(row.get("quantity") is not None for row in province + lvd)
    different = sum((values(province) - values(lvd)).values()) if same and complete else None
    return {
        "province_rows": len(province),
        "lvd_rows": len(lvd),
        "lvd_layers": sorted({row.get("layer") or "onbekend" for row in lvd}),
        "same_names_and_codes": same,
        "same_quantities": same and complete and different == 0,
        "quantity_differences": different,
        "identity_proven": False,
    }


def pq_inventory_from_rows(rows) -> dict:
    province, lvd = defaultdict(list), defaultdict(list)
    pairs = []
    for row in rows:
        kind, data = row["kind"], row["data"]
        if kind == "province":
            province[data["opname_id"]].append(data)
        elif kind == "lvd":
            lvd[data["event_id"]].append(data)
        elif kind == "pair":
            pairs.append(data)
        else:
            raise ValueError(f"Onbekend opnameformaat: {kind}")
    comparisons = []
    for pair in pairs:
        if pair["opname_id"] not in province or pair["event_id"] not in lvd:
            raise ValueError("Kandidaatpaar mist een volledige bronopname")
        comparisons.append(dict(pair, **compare_pq_recordings(
            province[pair["opname_id"]], lvd[pair["event_id"]])))

    def summary(recordings):
        years = [row["year"] for values in recordings.values() for row in values if row["year"] is not None]
        return {"recordings": len(recordings), "rows": sum(map(len, recordings.values())),
                "period": [min(years), max(years)] if years else None}

    return {
        "province": summary(province), "lvd": summary(lvd),
        "candidate_pairs": len(comparisons),
        "same_names_and_codes": sum(p["same_names_and_codes"] for p in comparisons),
        "same_quantities": sum(p["same_quantities"] for p in comparisons),
        "pairs": comparisons,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--apply", action="store_true")
    modes.add_argument("--pq-inventarisatie", action="store_true",
                       help="Lees volledige PQ/LVD-opnamen zonder databasewijziging")
    parser.add_argument("--output", type=Path, help="Nieuw JSON-bewijsbestand buiten Git")
    parser.add_argument("--mysql-client", type=Path, default=Path("/usr/local/mysql/bin/mysql"))
    parser.add_argument("--login-path", default="meijendel_root")
    parser.add_argument("--database", default="Meijendel")
    args = parser.parse_args()
    if args.output and not args.pq_inventarisatie:
        parser.error("--output vereist --pq-inventarisatie")
    if args.pq_inventarisatie:
        if args.output and args.output.exists():
            parser.error("Het bewijsbestand bestaat al; kies een nieuwe naam")
        started = datetime.now(timezone.utc).isoformat()
        raw = subprocess.run(
            [str(args.mysql_client), f"--login-path={args.login_path}", "--protocol=TCP",
             "--host=127.0.0.1", "--port=3306", "--batch", "--raw",
             "--skip-column-names", "--default-character-set=utf8mb4", args.database],
            input=PQ_INVENTORY_SQL, text=True, check=True, capture_output=True,
        ).stdout
        report = pq_inventory_from_rows(json.loads(line) for line in raw.splitlines() if line)
        report.update({"started_utc": started, "database": args.database,
                       "query_sha256": hashlib.sha256(PQ_INVENTORY_SQL.encode()).hexdigest(),
                       "input_sha256": hashlib.sha256(raw.encode()).hexdigest(),
                       "rule_version": "pq-opnamevergelijking-v1",
                       "interpretation": "Letterlijke namen en bedekkingscodes; geen synoniemenmapping, "
                         "geen bewijs van gedeelde PQ-identiteit en geen invoer- of verwijderbesluit."})
        if args.output:
            with args.output.open("x", encoding="utf-8") as handle:
                json.dump(report, handle, ensure_ascii=False, indent=2)
                handle.write("\n")
        print("READ-ONLY:", json.dumps({k: v for k, v in report.items() if k != "pairs"}, ensure_ascii=False))
        return 0

    sql = AUDIT_SQL.read_text(encoding="utf-8")
    if not args.apply:
        print(f"DRY-RUN: {AUDIT_SQL}; {len(sql.encode('utf-8'))} bytes SQL")
        return 0
    if args.database != 'Meijendel':
        parser.error('--database is uitsluitend instelbaar voor de read-only inventarisatie')

    subprocess.run(
        [str(args.mysql_client), f"--login-path={args.login_path}"],
        input=sql,
        text=True,
        check=True,
    )
    print("IMPORT: overlapaudit externe ecologiebronnen opnieuw opgebouwd")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
