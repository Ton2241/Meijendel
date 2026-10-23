#!/usr/bin/env python3
"""Read-only audit of NDFF moss/lichen PQ candidates against provincial PQ rows.

No database writes, no geometry or vulnerable-species names in the output.
A unique source signature is date, central taxon, original geometry, and
original cover class. Distinct NDFF identities under 12.007 and 12.202 remain
separate source rows but share a signature in this audit.
"""
import argparse
import collections
import csv
import subprocess
from pathlib import Path


RULE_VERSION = "pq-mos-korstmos-audit-v1"
SQL = r"""WITH src AS (
 SELECT 'mossen' groep,m.waarneming_id,m.protocol,DATE(m.periode_start) d,b.taxon_id,m.openbare_geometrie,m.openbare_geometrie_sha256 geom_hash,m.aantal_raw,m.bronhouder
 FROM Meijendel.mossen_waarneming m JOIN Meijendel.ndff_open_pq_koppeling k ON k.waarneming_id=m.waarneming_id AND k.regelversie='ndff-open-pq-poort-v2' AND k.classificatie='niet_beoordeelbaar'
 JOIN Meijendel.ndff_soorten n ON n.soort_key=m.soort_key
 JOIN Meijendel.taxa_bronkoppeling b ON b.koppeling_id=n.taxon_bronkoppeling_id
 UNION ALL
 SELECT 'korstmossen',m.waarneming_id,m.protocol,DATE(m.periode_start),b.taxon_id,m.openbare_geometrie,m.openbare_geometrie_sha256,m.aantal_raw,m.bronhouder
 FROM Meijendel.korstmossen_waarneming m JOIN Meijendel.ndff_open_pq_koppeling k ON k.waarneming_id=m.waarneming_id AND k.regelversie='ndff-open-pq-poort-v2' AND k.classificatie='niet_beoordeelbaar'
 JOIN Meijendel.ndff_soorten n ON n.soort_key=m.soort_key
 JOIN Meijendel.taxa_bronkoppeling b ON b.koppeling_id=n.taxon_bronkoppeling_id
), sig AS (
 SELECT groep,MIN(waarneming_id) sig_id,COUNT(*) n_source,COUNT(DISTINCT protocol) n_protocol,d,taxon_id,geom_hash,aantal_raw,MIN(bronhouder) bronhouder,ST_GeomFromWKB(ANY_VALUE(ST_AsWKB(openbare_geometrie)),28992) geom
 FROM src GROUP BY groep,d,taxon_id,geom_hash,aantal_raw
), pairs AS (
 SELECT sig.groep,sig.sig_id,sig.n_source,sig.n_protocol,p.opname_id,w.waarneming_id pq_waarneming_id,
 ST_Distance(sig.geom,p.geom) dist,
 CASE
 WHEN sig.aantal_raw='0.1 - 5.0' AND w.abundantie_code IN ('r','+') THEN 1
 WHEN sig.aantal_raw='0.5 - 5.0' AND w.abundantie_code='1' THEN 1
 WHEN sig.aantal_raw='1.0 - 5.0' AND w.abundantie_code='2m' THEN 1
 WHEN sig.aantal_raw='5.0 - 12.5' AND w.abundantie_code='2a' THEN 1
 WHEN sig.aantal_raw='12.5 - 25.0' AND w.abundantie_code='2b' THEN 1
 WHEN sig.aantal_raw='25.0 - 50.0' AND w.abundantie_code='3' THEN 1
 WHEN sig.aantal_raw='50.0 - 75.0' AND w.abundantie_code='4' THEN 1
 WHEN sig.aantal_raw='75.0 - 100.0' AND w.abundantie_code='5' THEN 1
 ELSE 0 END abundance_match
 FROM sig JOIN Meijendel.pq_vegetatie_opname p ON p.opname_datum=sig.d
 JOIN Meijendel.pq_vegetatie_waarneming w ON w.opname_id=p.opname_id
 JOIN Meijendel.taxa_bronkoppeling pb ON pb.koppeling_id=w.taxon_bronkoppeling_id AND pb.taxon_id=sig.taxon_id
), good AS (SELECT * FROM pairs WHERE dist<=8 AND abundance_match=1),
n_matches AS (SELECT sig_id,COUNT(DISTINCT pq_waarneming_id) n FROM good GROUP BY sig_id),
pq_matches AS (SELECT pq_waarneming_id,COUNT(DISTINCT sig_id) n FROM good GROUP BY pq_waarneming_id),
one_to_one AS (
 SELECT g.* FROM good g
 JOIN n_matches n ON n.sig_id=g.sig_id AND n.n=1
 JOIN pq_matches p ON p.pq_waarneming_id=g.pq_waarneming_id AND p.n=1
),
flags AS (
 SELECT s.groep,s.sig_id,
 MAX(CASE WHEN p.sig_id IS NOT NULL THEN 1 ELSE 0 END) date_taxon,
 MAX(COALESCE(p.dist<=8,0)) spatial_hit,
 MAX(COALESCE(p.dist<=8 AND p.abundance_match=1,0)) spatial_abundance_hit,
 MAX(COALESCE(o.dist=0,0)) unique_strict,
 MAX(COALESCE(o.dist>0,0)) unique_near,
 MAX(o.opname_id) pq_opname_id,
 MAX(o.pq_waarneming_id) pq_waarneming_id,
 ROUND(MAX(o.dist),2) afstand_meter
 FROM sig s
 LEFT JOIN pairs p ON p.sig_id=s.sig_id
 LEFT JOIN one_to_one o ON o.sig_id=s.sig_id AND o.pq_waarneming_id=p.pq_waarneming_id
 GROUP BY s.groep,s.sig_id
)
SELECT src.groep,src.waarneming_id,YEAR(src.d),src.protocol,src.bronhouder,
 s.sig_id,s.n_source,s.n_protocol,
 f.unique_strict,f.unique_near,f.spatial_abundance_hit,f.spatial_hit,f.date_taxon,
 f.pq_opname_id,f.pq_waarneming_id,f.afstand_meter
FROM src JOIN sig s ON s.groep=src.groep AND s.d=src.d AND s.taxon_id=src.taxon_id
 AND s.geom_hash=src.geom_hash AND s.aantal_raw=src.aantal_raw
JOIN flags f ON f.groep=s.groep AND f.sig_id=s.sig_id
ORDER BY src.groep,src.waarneming_id;"""


def classify(unique_strict, unique_near, spatial_abundance_hit, spatial_hit, date_taxon):
    if int(unique_strict):
        return "sterk_strikt"
    if int(unique_near):
        return "nabij_kandidaat"
    if int(spatial_abundance_hit):
        return "meervoudige_kandidaat"
    if int(spatial_hit):
        return "locatie_gelijk_bedekking_afwijkend"
    if int(date_taxon):
        return "datum_taxon_gelijk_locatie_niet"
    return "geen_datum_taxon_match"


def nullable_mysql_value(value):
    return "" if value in ("NULL", r"\N") else value


def audit(mysql_client: Path, output: Path, expected_rows: int = 13901):
    command = [
        str(mysql_client), "--login-path=meijendel_root", "--protocol=TCP",
        "--host=127.0.0.1", "--batch", "--raw", "--skip-column-names", "-e", SQL,
    ]
    rows = subprocess.check_output(command, text=True).splitlines()
    if len(rows) != expected_rows:
        raise RuntimeError(f"verwacht {expected_rows} kandidaten, gevonden {len(rows)}")
    output.parent.mkdir(parents=True, exist_ok=True)
    totals = collections.Counter()
    header = [
        "regelversie", "soortgroep", "ndff_waarneming_id", "jaar",
        "ndff_protocol", "bronhouder", "signatuur_representant_id",
        "ndff_regels_zelfde_signatuur", "aantal_protocollen_signatuur",
        "matchklasse", "pq_opname_id", "pq_waarneming_id", "afstand_meter",
    ]
    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(header)
        for line in rows:
            cols = line.split("\t")
            if len(cols) != 16:
                raise RuntimeError(f"onverwacht aantal uitvoervelden: {len(cols)}")
            group, ndff_id, year, protocol, holder, signature_id, source_count, protocol_count, strict, near, abundance, spatial, date_taxon, opname_id, result_id, distance = cols
            status = classify(strict, near, abundance, spatial, date_taxon)
            totals[group, status] += 1
            writer.writerow([
                RULE_VERSION, group, ndff_id, year, protocol, holder,
                signature_id, source_count, protocol_count, status,
                nullable_mysql_value(opname_id),
                nullable_mysql_value(result_id),
                nullable_mysql_value(distance),
            ])
    return totals


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mysql-client", type=Path, default=Path("/usr/local/mysql/bin/mysql"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-rows", type=int, default=13901)
    args = parser.parse_args()
    counts = audit(args.mysql_client, args.output, args.expected_rows)
    for (group, status), count in sorted(counts.items()):
        print(f"{group}\t{status}\t{count}")


if __name__ == "__main__":
    main()
