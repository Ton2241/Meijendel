#!/usr/bin/env python3
"""Analyseer de complete NDFF-stagingdataset zonder de life-database te wijzigen.

Het script maakt een compact analysebestand en een canoniek rapport-artifact.
De MySQL-query op de PQ-tabellen is uitsluitend-lezen.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import unicodedata
from collections import Counter, defaultdict
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Iterable

from osgeo import ogr


NDFF_HEADLINE_SOURCE_ID = "src_ndff_headline"
NDFF_SPATIAL_SOURCE_ID = "src_ndff_spatial"
NDFF_GROUP_SOURCE_ID = "src_ndff_groups"
NDFF_STRUCTURE_SOURCE_ID = "src_ndff_structure"
NDFF_TEMPORAL_SOURCE_ID = "src_ndff_temporal"
NDFF_BLUR_SOURCE_ID = "src_ndff_blur"
PQ_SOURCE_ID = "src_pq_overlap"


def normalized_name(value: str | None) -> str:
    return " ".join(unicodedata.normalize("NFKC", value or "").casefold().split())


def parse_ogr_date(value: Any) -> date:
    return date.fromisoformat(str(value)[:10].replace("/", "-"))


def ogr_rows(dataset: ogr.DataSource, sql: str) -> list[dict[str, Any]]:
    layer = dataset.ExecuteSQL(sql, dialect="SQLITE")
    if layer is None:
        raise RuntimeError("OGR-SQL leverde geen resultaat op")
    try:
        definition = layer.GetLayerDefn()
        fields = [definition.GetFieldDefn(i).GetName() for i in range(definition.GetFieldCount())]
        return [{field: feature.GetField(field) for field in fields} for feature in layer]
    finally:
        dataset.ReleaseResultSet(layer)


def first(rows: Iterable[dict[str, Any]]) -> dict[str, Any]:
    return next(iter(rows))


def analyse_pq_overlap(
    dataset: ogr.DataSource,
    mysql_client: Path,
    mysql_database: str,
) -> dict[str, Any]:
    vegetation_protocol = "12.007 Vegetatieopnamen"
    nem_protocol = "12.202 Landelijk Meetnet Flora- Milieu- en Natuurkwaliteit (NEM)"
    structured_protocols = [vegetation_protocol, nem_protocol]
    query = (
        "SELECT o.opname_id,o.pq_nummer,o.jaar,o.opname_datum,o.x_rd,o.y_rd,"
        "w.waarneming_id,"
        "t.nederlandse_naam,COALESCE(NULLIF(t.wetenschappelijke_naam_officieel,''),"
        "t.latijnse_naam_bron) "
        "FROM pq_vegetatie_opname o "
        "JOIN pq_vegetatie_waarneming w USING(opname_id) "
        "JOIN pq_vegetatie_taxon t USING(taxon_id)"
    )
    command = [
        str(mysql_client),
        "--login-path=meijendel_root",
        "-D",
        mysql_database,
        "--batch",
        "--raw",
        "--skip-column-names",
        "-e",
        query,
    ]
    result = subprocess.run(command, check=True, capture_output=True, text=True)

    by_scientific: dict[tuple[str, str], dict[int, tuple[Any, ...]]] = defaultdict(dict)
    by_dutch: dict[tuple[str, str], dict[int, tuple[Any, ...]]] = defaultdict(dict)
    recording_observations: dict[int, set[int]] = defaultdict(set)
    recording_meta: dict[int, dict[str, Any]] = {}
    observation_year: dict[int, int] = {}
    observation_recording: dict[int, int] = {}
    pq_row_count = 0
    for line in result.stdout.splitlines():
        values = line.split("\t")
        if len(values) != 9:
            continue
        (
            opname_id,
            pq_number,
            year,
            opname_date,
            x_rd,
            y_rd,
            observation_id,
            dutch,
            scientific,
        ) = values
        record = (
            int(opname_id),
            int(pq_number),
            int(year),
            float(x_rd),
            float(y_rd),
            int(observation_id),
        )
        recording_meta[record[0]] = {
            "pq_number": record[1],
            "year": record[2],
            "date": opname_date,
        }
        recording_observations[record[0]].add(record[5])
        observation_year[record[5]] = record[2]
        observation_recording[record[5]] = record[0]
        by_scientific[(opname_date, normalized_name(scientific))][record[5]] = record
        by_dutch[(opname_date, normalized_name(dutch))][record[5]] = record
        pq_row_count += 1

    layer = dataset.GetLayerByName("ndff_waarnemingen")
    matched_observations_by_protocol: dict[str, set[int]] = defaultdict(set)
    matched_recordings_by_protocol: dict[str, set[int]] = defaultdict(set)
    matched_ndff_by_protocol: dict[str, set[str]] = defaultdict(set)
    source_holders_by_protocol: dict[str, Counter[str]] = defaultdict(Counter)
    areas_by_protocol: dict[str, Counter[str]] = defaultdict(Counter)
    ambiguous_ndff = 0

    for feature in layer:
        observed_date = parse_ogr_date(feature.GetField("Periode start"))
        date_key = observed_date.isoformat()
        candidates: dict[int, tuple[Any, ...]] = {}
        candidates.update(
            by_scientific.get(
                (date_key, normalized_name(feature.GetField("Wetenschappelijke naam"))), {}
            )
        )
        candidates.update(
            by_dutch.get((date_key, normalized_name(feature.GetField("Naam soort"))), {})
        )
        if not candidates:
            continue
        geometry = feature.GetGeometryRef()
        matches: list[tuple[Any, ...]] = []
        for candidate in candidates.values():
            point = ogr.Geometry(ogr.wkbPoint)
            point.AddPoint_2D(candidate[3], candidate[4])
            if geometry is not None and geometry.Distance(point) <= 1e-8:
                matches.append(candidate)
        if not matches:
            continue
        protocol = str(feature.GetField("Protocol"))
        matched_ndff_by_protocol[protocol].add(str(feature.GetField("Identiteit")))
        source_holders_by_protocol[protocol][str(feature.GetField("Bronhouder"))] += 1
        area = geometry.GetArea() if geometry is not None else 0
        area_class = "<1 ha" if area < 10_000 else "1-99 ha" if area < 1_000_000 else ">=1 km2"
        areas_by_protocol[protocol][area_class] += 1
        ambiguous_ndff += int(len(matches) > 1)
        for candidate in matches:
            matched_observations_by_protocol[protocol].add(candidate[5])
            matched_recordings_by_protocol[protocol].add(candidate[0])

    def union_summary(protocols: list[str]) -> dict[str, Any]:
        observations = set().union(
            *(matched_observations_by_protocol[protocol] for protocol in protocols)
        )
        matched_by_recording: dict[int, set[int]] = defaultdict(set)
        for observation_id in observations:
            matched_by_recording[observation_recording[observation_id]].add(observation_id)

        coverage = {
            recording_id: len(observation_ids) / len(recording_observations[recording_id])
            for recording_id, observation_ids in matched_by_recording.items()
        }
        coverage_classes = Counter(
            "100%"
            if value == 1
            else "90-99%"
            if value >= 0.9
            else "50-89%"
            if value >= 0.5
            else "<50%"
            for value in coverage.values()
        )

        years: list[dict[str, Any]] = []
        for year in sorted({meta["year"] for meta in recording_meta.values()}):
            recording_ids = [
                recording_id
                for recording_id, meta in recording_meta.items()
                if meta["year"] == year
            ]
            total_observations = sum(
                len(recording_observations[recording_id]) for recording_id in recording_ids
            )
            matched_recording_ids = [
                recording_id for recording_id in recording_ids if recording_id in matched_by_recording
            ]
            matched_observations = sum(
                len(matched_by_recording.get(recording_id, ()))
                for recording_id in recording_ids
            )
            years.append(
                {
                    "year": year,
                    "recordings": len(recording_ids),
                    "matched_recordings": len(matched_recording_ids),
                    "recording_pct": round(
                        100 * len(matched_recording_ids) / len(recording_ids), 2
                    ),
                    "observations": total_observations,
                    "matched_observations": matched_observations,
                    "observation_pct": round(
                        100 * matched_observations / total_observations, 2
                    ),
                }
            )

        periods: list[dict[str, Any]] = []
        for label, start_year, stop_year in [
            ("1981-2017", 1981, 2017),
            ("2018-2025", 2018, 2025),
        ]:
            rows = [row for row in years if start_year <= row["year"] <= stop_year]
            total_recordings = sum(row["recordings"] for row in rows)
            matched_recordings = sum(row["matched_recordings"] for row in rows)
            total_observations = sum(row["observations"] for row in rows)
            matched_observations = sum(row["matched_observations"] for row in rows)
            periods.append(
                {
                    "period": label,
                    "recordings": total_recordings,
                    "matched_recordings": matched_recordings,
                    "recording_pct": round(100 * matched_recordings / total_recordings, 2),
                    "observations": total_observations,
                    "matched_observations": matched_observations,
                    "observation_pct": round(100 * matched_observations / total_observations, 2),
                }
            )

        pre2018_locations: dict[int, dict[str, int]] = defaultdict(
            lambda: {"recordings": 0, "matched": 0}
        )
        for recording_id, meta in recording_meta.items():
            if meta["year"] > 2017:
                continue
            bucket = pre2018_locations[meta["pq_number"]]
            bucket["recordings"] += 1
            bucket["matched"] += int(recording_id in matched_by_recording)
        location_classes = Counter(
            "altijd"
            if values["matched"] == values["recordings"]
            else "nooit"
            if values["matched"] == 0
            else "wisselend"
            for values in pre2018_locations.values()
        )

        return {
            "protocols": protocols,
            "matched_pq_observations": len(observations),
            "matched_pq_recordings": len(matched_by_recording),
            "matched_pq_observation_share": len(observations) / pq_row_count,
            "matched_pq_recording_share": len(matched_by_recording) / len(recording_meta),
            "recordings_at_least_90_pct": sum(value >= 0.9 for value in coverage.values()),
            "recordings_100_pct": sum(value == 1 for value in coverage.values()),
            "coverage_classes": dict(sorted(coverage_classes.items())),
            "periods": periods,
            "years": years,
            "pre2018_locations": len(pre2018_locations),
            "pre2018_location_classes": dict(sorted(location_classes.items())),
        }

    protocol_breakdown: list[dict[str, Any]] = []
    for protocol, observations in matched_observations_by_protocol.items():
        years = [observation_year[observation_id] for observation_id in observations]
        protocol_breakdown.append(
            {
                "protocol": protocol,
                "matched_pq_observations": len(observations),
                "matched_pq_recordings": len(matched_recordings_by_protocol[protocol]),
                "matched_ndff_records": len(matched_ndff_by_protocol[protocol]),
                "post2017_observations": sum(year >= 2018 for year in years),
                "first_year": min(years),
                "last_year": max(years),
                "geometry_area_classes": dict(sorted(areas_by_protocol[protocol].items())),
                "source_holders": dict(sorted(source_holders_by_protocol[protocol].items())),
            }
        )
    protocol_breakdown.sort(key=lambda row: row["matched_pq_observations"], reverse=True)

    vegetation_only = union_summary([vegetation_protocol])
    structured = union_summary(structured_protocols)
    all_protocols = union_summary(list(matched_observations_by_protocol))
    return {
        "mysql_query": query,
        "pq_observations_total": pq_row_count,
        "pq_recordings_total": len(recording_meta),
        "vegetation_protocol_only": vegetation_only,
        "structured_protocols": structured,
        "all_protocols_upper_bound": all_protocols,
        "protocol_breakdown": protocol_breakdown,
        "ambiguous_ndff_matches": ambiguous_ndff,
        "match_rule": (
            "gelijke datum en genormaliseerde Nederlandse of wetenschappelijke naam, "
            "waarbij het PQ-punt afstand 0 tot de NDFF-geometrie heeft"
        ),
        "interpretation": (
            "Vegetatieopnamen plus NEM is de primaire gestructureerde kandidaatset. "
            "Alle protocollen vormen alleen een bovengrens; losse meldingen en grove "
            "geometrie kunnen toevallig datum, taxon en locatie delen."
        ),
    }


def analyse(staging_path: Path, mysql_client: Path, mysql_database: str) -> dict[str, Any]:
    ogr.UseExceptions()
    dataset = ogr.Open(str(staging_path), 0)
    if dataset is None:
        raise RuntimeError(f"Kon stagingdataset niet openen: {staging_path}")

    headline = first(
        ogr_rows(
            dataset,
            """
            SELECT COUNT(*) AS records,
                   SUM(vervaagd) AS blurred,
                   SUM(CASE WHEN vervaagd=0 AND ST_Area(geom)<1000000 THEN 1 ELSE 0 END) AS plot_candidates,
                   SUM(CASE WHEN vervaagd=0 AND ST_Area(geom)>=1000000 THEN 1 ELSE 0 END) AS large_unblurred,
                   SUM(Protocol='Losse waarnemingen') AS loose_records,
                   SUM(Protocol LIKE '%(NEM)%') AS nem_records,
                   SUM(Protocol LIKE '%ObsIdentify%') AS obsidentify_records,
                   SUM(Protocol='12.007 Vegetatieopnamen') AS vegetation_records,
                   COUNT(DISTINCT Bronhouder) AS source_holders,
                   COUNT(DISTINCT Protocol) AS protocols
            FROM ndff_waarnemingen
            """,
        )
    )
    total = headline["records"]
    headline.update(
        {
            "blurred_share": headline["blurred"] / total,
            "plot_candidate_share": headline["plot_candidates"] / total,
            "large_unblurred_share": headline["large_unblurred"] / total,
            "loose_share": headline["loose_records"] / total,
        }
    )

    spatial_overall = ogr_rows(
        dataset,
        """
        SELECT CASE
                 WHEN vervaagd=1 THEN 'Vervaagd'
                 WHEN ST_Area(geom)>=1000000 THEN 'Niet-vervaagd, >=1 km2'
                 ELSE 'Voorlopige plotkandidaat'
               END AS category,
               COUNT(*) AS records,
               ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM ndff_waarnemingen),2) AS pct
        FROM ndff_waarnemingen GROUP BY category ORDER BY records DESC
        """,
    )

    group_spatial = ogr_rows(
        dataset,
        """
        WITH first_group AS (
          SELECT p.staging_fid,b.aanvraag_soortgroep
          FROM ndff_waarneming_bron p JOIN ndff_bronbestanden b USING(bestand_id)
          WHERE p.is_eerste=1
        )
        SELECT f.aanvraag_soortgroep AS group_name, COUNT(*) AS records,
               SUM(CASE WHEN w.vervaagd=0 AND ST_Area(w.geom)<1000000 THEN 1 ELSE 0 END) AS plot_candidates,
               ROUND(100.0*SUM(CASE WHEN w.vervaagd=0 AND ST_Area(w.geom)<1000000 THEN 1 ELSE 0 END)/COUNT(*),2) AS candidate_pct,
               SUM(CASE WHEN w.vervaagd=0 AND ST_Area(w.geom)>=1000000 THEN 1 ELSE 0 END) AS large_unblurred,
               ROUND(100.0*SUM(CASE WHEN w.vervaagd=0 AND ST_Area(w.geom)>=1000000 THEN 1 ELSE 0 END)/COUNT(*),2) AS large_pct,
               SUM(w.vervaagd) AS blurred,
               ROUND(100.0*SUM(w.vervaagd)/COUNT(*),2) AS blurred_pct,
               ROUND(100.0*SUM(w.Protocol='Losse waarnemingen')/COUNT(*),2) AS loose_pct
        FROM ndff_waarnemingen w JOIN first_group f USING(staging_fid)
        GROUP BY f.aanvraag_soortgroep ORDER BY records DESC
        """,
    )

    structure = ogr_rows(
        dataset,
        """
        WITH classified AS (
          SELECT CASE
                   WHEN Protocol='Losse waarnemingen' THEN 'Losse waarnemingen'
                   WHEN Protocol LIKE '%ObsIdentify%' THEN 'Automatische herkenning (ObsIdentify)'
                   WHEN Protocol LIKE '%(NEM)%' THEN 'NEM-protocol'
                   WHEN Protocol LIKE '%Vegetatieopnamen%' THEN 'Vegetatieopnamen'
                   ELSE 'Overig protocol'
                 END AS structure, vervaagd
          FROM ndff_waarnemingen
        )
        SELECT structure,COUNT(*) AS records,
               ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM classified),2) AS pct,
               ROUND(100.0*SUM(vervaagd)/COUNT(*),2) AS blurred_pct
        FROM classified GROUP BY structure ORDER BY records DESC
        """,
    )

    temporal = ogr_rows(
        dataset,
        """
        WITH base AS (
          SELECT CASE
                   WHEN CAST(substr("Periode start",1,4) AS INT)<1950 THEN 'Voor 1950 gestart'
                   WHEN CAST(substr("Periode start",1,4) AS INT)>=2020 THEN '2020-2025'
                   ELSE printf('%d-%d',(CAST(substr("Periode start",1,4) AS INT)/10)*10,
                                      (CAST(substr("Periode start",1,4) AS INT)/10)*10+9)
                 END AS period,
                 CASE
                   WHEN Protocol='Losse waarnemingen' THEN 'Losse waarnemingen'
                   WHEN Protocol LIKE '%ObsIdentify%' THEN 'ObsIdentify'
                   WHEN Protocol LIKE '%(NEM)%' THEN 'NEM-protocol'
                   WHEN Protocol LIKE '%Vegetatieopnamen%' THEN 'Vegetatieopnamen'
                   ELSE 'Overig protocol'
                 END AS structure,
                 CAST(substr("Periode start",1,4) AS INT) AS year_value,
                 vervaagd, Determinatiemethode
          FROM ndff_waarnemingen
        ), totals AS (
          SELECT period,COUNT(*) AS period_total FROM base GROUP BY period
        )
        SELECT b.period,b.structure,COUNT(*) AS records,t.period_total,
               ROUND(100.0*COUNT(*)/t.period_total,2) AS share_pct,
               MIN(b.year_value) AS sort_year
        FROM base b JOIN totals t USING(period)
        GROUP BY b.period,b.structure ORDER BY sort_year,records DESC
        """,
    )

    temporal_summary = ogr_rows(
        dataset,
        """
        WITH base AS (
          SELECT CASE
                   WHEN CAST(substr("Periode start",1,4) AS INT)<1950 THEN 'Voor 1950 gestart'
                   WHEN CAST(substr("Periode start",1,4) AS INT)>=2020 THEN '2020-2025'
                   ELSE printf('%d-%d',(CAST(substr("Periode start",1,4) AS INT)/10)*10,
                                      (CAST(substr("Periode start",1,4) AS INT)/10)*10+9)
                 END AS period,
                 CAST(substr("Periode start",1,4) AS INT) AS year_value,
                 vervaagd,Protocol,Determinatiemethode
          FROM ndff_waarnemingen
        )
        SELECT period,COUNT(*) AS records,
               ROUND(100.0*SUM(vervaagd)/COUNT(*),2) AS blurred_pct,
               ROUND(100.0*SUM(Protocol='Losse waarnemingen')/COUNT(*),2) AS loose_pct,
               ROUND(100.0*SUM(Protocol LIKE '%ObsIdentify%')/COUNT(*),2) AS obsidentify_pct,
               ROUND(100.0*SUM(Determinatiemethode='onbekend')/COUNT(*),2) AS unknown_determination_pct,
               MIN(year_value) AS sort_year
        FROM base GROUP BY period ORDER BY sort_year
        """,
    )

    blur_taxa_status = ogr_rows(
        dataset,
        """
        WITH per_taxon AS (
          SELECT Soortgroep,"Naam soort" AS common_name,
                 "Wetenschappelijke naam" AS scientific_name,
                 COUNT(*) AS records,SUM(vervaagd) AS blurred
          FROM ndff_waarnemingen GROUP BY Soortgroep,common_name,scientific_name
        )
        SELECT CASE WHEN blurred=0 THEN 'Geen vervaging'
                    WHEN blurred=records THEN 'Alleen vervaagd'
                    ELSE 'Gemengd' END AS status,
               COUNT(*) AS taxa,SUM(records) AS records
        FROM per_taxon GROUP BY status ORDER BY taxa DESC
        """,
    )

    high_blur_taxa = ogr_rows(
        dataset,
        """
        WITH per_taxon AS (
          SELECT Soortgroep AS group_name,"Naam soort" AS common_name,
                 "Wetenschappelijke naam" AS scientific_name,
                 COUNT(*) AS records,SUM(vervaagd) AS blurred
          FROM ndff_waarnemingen GROUP BY Soortgroep,common_name,scientific_name
        )
        SELECT group_name,common_name,scientific_name,records,blurred,
               ROUND(100.0*blurred/records,1) AS blurred_pct
        FROM per_taxon WHERE records>=100 AND blurred>0
        ORDER BY blurred_pct DESC,records DESC LIMIT 30
        """,
    )

    missingness = ogr_rows(
        dataset,
        """
        SELECT 'Determinatiemethode = onbekend' AS field,
               SUM(Determinatiemethode='onbekend') AS missing,
               ROUND(100.0*SUM(Determinatiemethode='onbekend')/COUNT(*),2) AS pct
        FROM ndff_waarnemingen
        UNION ALL SELECT 'Zoek- of vangmethode leeg',
               SUM(trim(COALESCE("Zoek- of vangmethode",''))=''),
               ROUND(100.0*SUM(trim(COALESCE("Zoek- of vangmethode",''))='')/COUNT(*),2)
        FROM ndff_waarnemingen
        UNION ALL SELECT 'Apparatuur leeg',SUM(trim(COALESCE(Apparatuur,''))=''),
               ROUND(100.0*SUM(trim(COALESCE(Apparatuur,''))='')/COUNT(*),2)
        FROM ndff_waarnemingen
        """,
    )

    date_quality = first(
        ogr_rows(
            dataset,
            """
            SELECT MIN(substr("Periode start",1,10)) AS min_start,
                   MAX(substr("Periode start",1,10)) AS max_start,
                   MAX(substr("Periode stop",1,10)) AS max_stop,
                   SUM(CAST(substr("Periode start",1,4) AS INT)<1950) AS starts_before_1950,
                   SUM(julianday("Periode stop")-julianday("Periode start")>366) AS longer_than_year,
                   SUM(julianday("Periode stop")-julianday("Periode start")<=1) AS zero_or_one_day
            FROM ndff_waarnemingen
            """,
        )
    )

    cross_group = ogr_rows(
        dataset,
        """
        WITH grouped AS (
          SELECT p.staging_fid,COUNT(DISTINCT b.aanvraag_soortgroep) AS group_count,
                 group_concat(DISTINCT b.aanvraag_soortgroep) AS groups_seen
          FROM ndff_waarneming_bron p JOIN ndff_bronbestanden b USING(bestand_id)
          GROUP BY p.staging_fid
        )
        SELECT groups_seen,COUNT(*) AS records
        FROM grouped WHERE group_count>1 GROUP BY groups_seen ORDER BY records DESC
        """,
    )

    pq_overlap = analyse_pq_overlap(dataset, mysql_client, mysql_database)
    dataset = None
    return {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "staging_file": staging_path.name,
        "headline": headline,
        "spatial_overall": spatial_overall,
        "group_spatial": group_spatial,
        "structure": structure,
        "temporal_method_mix": temporal,
        "temporal_summary": temporal_summary,
        "blur_taxa_status": blur_taxa_status,
        "high_blur_taxa": high_blur_taxa,
        "method_missingness": missingness,
        "date_quality": date_quality,
        "cross_request_group_membership": cross_group,
        "pq_overlap": pq_overlap,
    }


def source_specs(created_at: str, pq_query: str) -> list[dict[str, Any]]:
    def ndff_source(
        source_id: str,
        label: str,
        sql: str,
        tables: list[str] | None = None,
        metric_definitions: list[str] | None = None,
    ) -> dict[str, Any]:
        return {
            "id": source_id,
            "label": label,
            "query": {
                "engine": "SQLite/GeoPackage",
                "sql": sql.strip(),
                "description": "Query op de gevalideerde, op Identiteit ontdubbelde NDFF-stagingdataset",
                "executed_at": created_at,
                "language": "SQL en OGR-SQL",
                "tables_used": tables or ["ndff_waarnemingen"],
                "filters": ["periode van aanvragen 1950-2025", "geen vogels"],
                "metric_definitions": metric_definitions or [],
            },
        }

    return [
        ndff_source(
            NDFF_HEADLINE_SOURCE_ID,
            "NDFF-staging: kerncijfers",
            """
            SELECT COUNT(*) AS records,SUM(vervaagd) AS blurred,
                   SUM(CASE WHEN vervaagd=0 AND ST_Area(geom)<1000000 THEN 1 ELSE 0 END) AS plot_candidates,
                   SUM(CASE WHEN vervaagd=0 AND ST_Area(geom)>=1000000 THEN 1 ELSE 0 END) AS large_unblurred,
                   SUM(Protocol='Losse waarnemingen') AS loose_records
            FROM ndff_waarnemingen
            """,
            metric_definitions=[
                "Voorlopige plotkandidaat: niet vervaagd en geometrie kleiner dan 1 km2",
                "Groot niet-vervaagd: niet vervaagd en geometrie minstens 1 km2",
            ],
        ),
        ndff_source(
            NDFF_SPATIAL_SOURCE_ID,
            "NDFF-staging: ruimtelijke voorselectie",
            """
            SELECT CASE WHEN vervaagd=1 THEN 'Vervaagd'
                        WHEN ST_Area(geom)>=1000000 THEN 'Niet-vervaagd, >=1 km2'
                        ELSE 'Voorlopige plotkandidaat' END AS category,
                   COUNT(*) AS records,
                   ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM ndff_waarnemingen),2) AS pct
            FROM ndff_waarnemingen GROUP BY category ORDER BY records DESC
            """,
            metric_definitions=[
                "Voorlopige plotkandidaat is een voorselectie en nog geen SOVON-plottoewijzing"
            ],
        ),
        ndff_source(
            NDFF_GROUP_SOURCE_ID,
            "NDFF-staging: ruimtelijke voorselectie per FFV-groep",
            """
            WITH first_group AS (
              SELECT p.staging_fid,b.aanvraag_soortgroep
              FROM ndff_waarneming_bron p JOIN ndff_bronbestanden b USING(bestand_id)
              WHERE p.is_eerste=1)
            SELECT f.aanvraag_soortgroep AS group_name,COUNT(*) AS records,
                   ROUND(100.0*SUM(w.vervaagd=0 AND ST_Area(w.geom)<1000000)/COUNT(*),2) AS candidate_pct,
                   ROUND(100.0*SUM(w.vervaagd=0 AND ST_Area(w.geom)>=1000000)/COUNT(*),2) AS large_pct,
                   ROUND(100.0*SUM(w.vervaagd)/COUNT(*),2) AS blurred_pct,
                   ROUND(100.0*SUM(w.Protocol='Losse waarnemingen')/COUNT(*),2) AS loose_pct
            FROM ndff_waarnemingen w JOIN first_group f USING(staging_fid)
            GROUP BY f.aanvraag_soortgroep ORDER BY records DESC
            """,
            tables=["ndff_waarnemingen", "ndff_waarneming_bron", "ndff_bronbestanden"],
        ),
        ndff_source(
            NDFF_STRUCTURE_SOURCE_ID,
            "NDFF-staging: protocolstructuur",
            """
            WITH classified AS (
              SELECT CASE WHEN Protocol='Losse waarnemingen' THEN 'Losse waarnemingen'
                          WHEN Protocol LIKE '%ObsIdentify%' THEN 'Automatische herkenning (ObsIdentify)'
                          WHEN Protocol LIKE '%(NEM)%' THEN 'NEM-protocol'
                          WHEN Protocol LIKE '%Vegetatieopnamen%' THEN 'Vegetatieopnamen'
                          ELSE 'Overig protocol' END AS structure,vervaagd
              FROM ndff_waarnemingen)
            SELECT structure,COUNT(*) AS records,
                   ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM classified),2) AS pct,
                   ROUND(100.0*SUM(vervaagd)/COUNT(*),2) AS blurred_pct
            FROM classified GROUP BY structure ORDER BY records DESC
            """,
        ),
        ndff_source(
            NDFF_TEMPORAL_SOURCE_ID,
            "NDFF-staging: methodeverschuiving per tijdvak",
            """
            WITH base AS (
              SELECT CASE WHEN CAST(substr("Periode start",1,4) AS INT)<1950 THEN 'Voor 1950 gestart'
                          WHEN CAST(substr("Periode start",1,4) AS INT)>=2020 THEN '2020-2025'
                          ELSE printf('%d-%d',(CAST(substr("Periode start",1,4) AS INT)/10)*10,
                                             (CAST(substr("Periode start",1,4) AS INT)/10)*10+9) END AS period,
                     CASE WHEN Protocol='Losse waarnemingen' THEN 'Losse waarnemingen'
                          WHEN Protocol LIKE '%ObsIdentify%' THEN 'ObsIdentify'
                          WHEN Protocol LIKE '%(NEM)%' THEN 'NEM-protocol'
                          WHEN Protocol LIKE '%Vegetatieopnamen%' THEN 'Vegetatieopnamen'
                          ELSE 'Overig protocol' END AS structure,
                     vervaagd,Protocol,Determinatiemethode
              FROM ndff_waarnemingen)
            SELECT period,structure,COUNT(*) AS records FROM base GROUP BY period,structure
            """,
        ),
        ndff_source(
            NDFF_BLUR_SOURCE_ID,
            "NDFF-staging: vervaging per taxon",
            """
            WITH per_taxon AS (
              SELECT Soortgroep AS group_name,"Naam soort" AS common_name,
                     "Wetenschappelijke naam" AS scientific_name,
                     COUNT(*) AS records,SUM(vervaagd) AS blurred
              FROM ndff_waarnemingen GROUP BY Soortgroep,common_name,scientific_name)
            SELECT group_name,common_name,scientific_name,records,blurred,
                   ROUND(100.0*blurred/records,1) AS blurred_pct
            FROM per_taxon WHERE records>=100 AND blurred>0
            ORDER BY blurred_pct DESC,records DESC LIMIT 30
            """,
        ),
        {
            "id": PQ_SOURCE_ID,
            "label": "NDFF-PQ-overlapcontrole",
            "query": {
                "engine": "MySQL plus OGR",
                "sql": pq_query,
                "description": "Kandidaatmatching op datum, taxonnaam en ruimtelijke afstand nul, uitgesplitst naar protocol",
                "executed_at": created_at,
                "language": "SQL en Python/OGR",
                "tables_used": [
                    "Meijendel.pq_vegetatie_opname",
                    "Meijendel.pq_vegetatie_waarneming",
                    "Meijendel.pq_vegetatie_taxon",
                    "ndff_waarnemingen",
                ],
                "filters": [
                    "primaire kandidaatset: 12.007 Vegetatieopnamen plus 12.202 NEM",
                    "overige protocollen uitsluitend als bovengrens",
                ],
                "metric_definitions": [
                    "Herkenbare PQ-opname: minstens één gelijke datum en Nederlandse of wetenschappelijke taxonnaam, met PQ-punt op afstand 0 van de NDFF-geometrie",
                    "Bijna volledig: minstens 90% van de PQ-soortenlijst heeft een kandidaatmatch",
                ],
            },
        },
    ]


def build_artifact(result: dict[str, Any]) -> dict[str, Any]:
    created_at = result["created_utc"]
    headline = dict(result["headline"])
    pq_structured = result["pq_overlap"]["structured_protocols"]
    headline.update(
        {
            "pq_recording_coverage": pq_structured["matched_pq_recording_share"],
            "pq_high_coverage_share": (
                pq_structured["recordings_at_least_90_pct"]
                / result["pq_overlap"]["pq_recordings_total"]
            ),
        }
    )
    sources = source_specs(created_at, result["pq_overlap"]["mysql_query"])
    cards = [
        {
            "id": "records",
            "description": "Unieke NDFF-identiteiten na ontdubbeling",
            "dataset": "headline",
            "sourceId": NDFF_HEADLINE_SOURCE_ID,
            "metrics": [{"label": "Waarnemingen", "field": "records", "format": "compact"}],
        },
        {
            "id": "plot-candidates",
            "description": "Voorlopige ruimtelijke kandidaten; plotintersectie volgt nog",
            "dataset": "headline",
            "sourceId": NDFF_HEADLINE_SOURCE_ID,
            "metrics": [
                {"label": "Voorlopige plotkandidaten", "field": "plot_candidate_share", "format": "percent"}
            ],
        },
        {
            "id": "loose",
            "description": "Records met protocol Losse waarnemingen",
            "dataset": "headline",
            "sourceId": NDFF_HEADLINE_SOURCE_ID,
            "metrics": [{"label": "Losse meldingen", "field": "loose_share", "format": "percent"}],
        },
        {
            "id": "pq-matches",
            "description": "PQ-opnamen met minstens één kandidaatmatch onder Vegetatieopnamen of NEM",
            "dataset": "headline",
            "sourceId": PQ_SOURCE_ID,
            "metrics": [
                {"label": "Herkenbare PQ-opnamen", "field": "pq_recording_coverage", "format": "percent"}
            ],
        },
    ]

    charts = [
        {
            "id": "spatial-readiness",
            "title": "Ruimtelijke voorselectie van NDFF-waarnemingen",
            "subtitle": "Alle 810.830 records; een plotintersectie is nog niet uitgevoerd",
            "type": "horizontalBar",
            "intent": "composition",
            "dataset": "spatial_overall",
            "sourceId": NDFF_SPATIAL_SOURCE_ID,
            "encodings": {
                "x": {"field": "category", "type": "nominal", "label": "Ruimtelijke klasse"},
                "y": {"field": "records", "type": "quantitative", "label": "Records", "format": "compact"},
                "tooltip": [
                    {"field": "records", "type": "quantitative", "label": "Records", "format": "number"},
                    {"field": "pct", "type": "quantitative", "label": "Aandeel", "unit": "%"},
                ],
            },
            "valueFormat": "compact",
            "layout": "full",
            "palette": {"kind": "categorical"},
            "settings": {"sort": "descending", "showValues": True},
        },
        {
            "id": "structure-mix",
            "title": "Herkomst naar protocolstructuur",
            "subtitle": "Losse meldingen zijn de grootste categorie; protocolgebonden is niet automatisch een trendmeetnet",
            "type": "horizontalBar",
            "intent": "composition",
            "dataset": "structure",
            "sourceId": NDFF_STRUCTURE_SOURCE_ID,
            "encodings": {
                "x": {"field": "structure", "type": "nominal", "label": "Structuur"},
                "y": {"field": "records", "type": "quantitative", "label": "Records", "format": "compact"},
                "tooltip": [
                    {"field": "pct", "type": "quantitative", "label": "Aandeel", "unit": "%"},
                    {"field": "blurred_pct", "type": "quantitative", "label": "Vervaagd", "unit": "%"},
                ],
            },
            "valueFormat": "compact",
            "layout": "full",
            "palette": {"kind": "categorical"},
            "settings": {"sort": "descending", "showValues": True},
        },
        {
            "id": "method-drift",
            "title": "Samenstelling van protocollen door de tijd",
            "subtitle": "Aandeel per periode; 2020-2025 bevat een sterke opkomst van ObsIdentify",
            "type": "stackedBar100",
            "intent": "composition",
            "dataset": "temporal_method_mix",
            "sourceId": NDFF_TEMPORAL_SOURCE_ID,
            "encodings": {
                "x": {"field": "period", "type": "ordinal", "label": "Periode"},
                "y": {"field": "records", "type": "quantitative", "label": "Records"},
                "color": {"field": "structure", "type": "nominal", "label": "Structuur"},
                "tooltip": [
                    {"field": "records", "type": "quantitative", "label": "Records", "format": "number"},
                    {"field": "share_pct", "type": "quantitative", "label": "Periode-aandeel", "unit": "%"},
                ],
            },
            "layout": "full",
            "palette": {"kind": "categorical"},
            "legend": {"position": "bottom", "sort": "spec"},
            "settings": {"groupMode": "stacked100", "showPercent": True},
        },
    ]
    # De vijfdelige legenda van de tijdgrafiek overschrijdt de 390px-weergave
    # van de draagbare lezer. De tijdvakken blijven volledig in het JSON en de
    # kernverschuiving staat expliciet in de begeleidende tekst.
    charts = [chart for chart in charts if chart["id"] != "method-drift"]

    tables = [
        {
            "id": "group-spatial",
            "title": "Ruimtelijke voorselectie per FFV-aanvraagsoortgroep",
            "subtitle": "Kandidaat betekent alleen: niet vervaagd en kleiner dan 1 km2",
            "dataset": "group_spatial",
            "sourceId": NDFF_GROUP_SOURCE_ID,
            "defaultSort": {"field": "records", "direction": "desc"},
            "density": "dense",
            "layout": "full",
            "columns": [
                {"field": "group_name", "label": "Soortgroep", "type": "text"},
                {"field": "records", "label": "Records", "format": "number"},
                {"field": "candidate_pct", "label": "Kandidaat %", "format": "number"},
                {"field": "large_pct", "label": "Groot niet-vervaagd %", "format": "number"},
                {"field": "blurred_pct", "label": "Vervaagd %", "format": "number"},
                {"field": "loose_pct", "label": "Losse meldingen %", "format": "number"},
            ],
        },
        {
            "id": "temporal-summary",
            "title": "Tijdvakken en methodeverschuiving",
            "subtitle": "Percentages gelden binnen ieder tijdvak; 2020-2025 is een gedeeltelijk decennium",
            "dataset": "temporal_summary",
            "sourceId": NDFF_TEMPORAL_SOURCE_ID,
            "defaultSort": {"field": "sort_year", "direction": "asc"},
            "density": "spacious",
            "layout": "full",
            "columns": [
                {"field": "period", "label": "Periode", "type": "text"},
                {"field": "records", "label": "Records", "format": "number"},
                {"field": "blurred_pct", "label": "Vervaagd %", "format": "number"},
                {"field": "loose_pct", "label": "Losse meldingen %", "format": "number"},
                {"field": "obsidentify_pct", "label": "ObsIdentify %", "format": "number"},
                {"field": "unknown_determination_pct", "label": "Determinatie onbekend %", "format": "number"},
                {"field": "sort_year", "label": "Sorteerjaar", "format": "number"},
            ],
        },
        {
            "id": "high-blur-taxa",
            "title": "Taxa met veel vervaging",
            "subtitle": "Alleen taxa met minstens 100 records en minimaal één vervaagd record",
            "dataset": "high_blur_taxa",
            "sourceId": NDFF_BLUR_SOURCE_ID,
            "defaultSort": {"field": "blurred_pct", "direction": "desc"},
            "density": "dense",
            "layout": "full",
            "columns": [
                {"field": "group_name", "label": "Soortgroep", "type": "text"},
                {"field": "common_name", "label": "Soort", "type": "text"},
                {"field": "scientific_name", "label": "Wetenschappelijke naam", "type": "text"},
                {"field": "records", "label": "Records", "format": "number"},
                {"field": "blurred", "label": "Vervaagd", "format": "number"},
                {"field": "blurred_pct", "label": "Vervaagd %", "format": "number"},
            ],
        },
    ]
    # De volledige detailtabellen blijven in het resultaten-JSON. De draagbare
    # rapportlezer laat brede interactieve tabellen op 390 px buiten het
    # document doorlopen; het hoofdrapport gebruikt daarom alleen compacte
    # grafieken en tekstuele kernbevindingen.
    tables = []

    blocks = [
        {"id": "title", "type": "markdown", "body": "# Kwaliteitsanalyse NDFF Meijendel 1950-2025"},
        {
            "id": "technical-summary",
            "type": "markdown",
            "sourceId": NDFF_HEADLINE_SOURCE_ID,
            "body": (
                "## Technische samenvatting\n\n"
                "De stagingdataset is geschikt als controleerbare bronlaag, maar nog niet als directe plot- of trenddataset. "
                "Van 810.830 unieke waarnemingen is 68,38% voorlopig ruimtelijk kandidaat; 25,87% is niet vervaagd maar heeft een geometrie van minstens 1 km² en 5,75% is vervaagd. "
                "Daarnaast bestaat 53,05% uit losse meldingen. Vergelijkingen van ruwe aantallen door de tijd zouden daarom vooral veranderingen in bron, methode en waarnemingsinspanning meten."
            ),
        },
        {
            "id": "pq-summary",
            "type": "markdown",
            "sourceId": PQ_SOURCE_ID,
            "body": (
                "**De NDFF bevat een selectieve, geen volledige kopie van de bestaande PQ-data.** Onder de gestructureerde protocollen Vegetatieopnamen en NEM is 1.039 van 2.007 PQ-opnamen (51,77%) herkenbaar via minstens één gelijke datum-, taxon- en locatiematch; 24.804 van 53.122 PQ-soortwaarnemingen (46,69%) matchen. "
                "Bij 650 opnamen matcht minstens 90% van de soortenlijst. De dekking daalt van 70,40% van de opnamen in 1981-2017 naar 15,09% in 2018-2025; voor 2025 is onder deze protocollen geen opname gevonden."
            ),
        },
        {"id": "headline-metrics", "type": "metric-strip", "cardIds": ["records", "plot-candidates", "loose", "pq-matches"]},
        {
            "id": "spatial-finding",
            "type": "markdown",
            "sourceId": NDFF_GROUP_SOURCE_ID,
            "body": (
                "## Vervaging verklaart slechts een deel van de ruimtelijke onzekerheid\n\n"
                "Een record is hier alleen een *voorlopige plotkandidaat* als het niet vervaagd is en de geometrie kleiner is dan 1 km². "
                "Dat is nog geen bewijs van aanwezigheid in een SOVON-plot: de geometrie kan nog steeds meerdere plots raken. Vooral Schimmels (67,80% groot niet-vervaagd), Zoogdieren overig (49,68%) en Kreeftachtigen (33,19%) vragen een aparte gebiedsbehandeling."
            ),
        },
        {"id": "spatial-chart", "type": "chart", "chartId": "spatial-readiness", "layout": "full"},
        {
            "id": "method-finding",
            "type": "markdown",
            "sourceId": NDFF_TEMPORAL_SOURCE_ID,
            "body": (
                "## De meetmethode verandert sterk door de tijd\n\n"
                "Losse waarnemingen vormen 53,05% van alle records. NEM-protocollen leveren 16,55%, vegetatieopnamen 10,14% en ObsIdentify 9,11%. "
                "In 2020-2025 komt 25,24% uit ObsIdentify en is bij 70,46% de determinatiemethode als onbekend geregistreerd. "
                "Ruwe jaartotalen, soortenrijkdom of meldingsfrequenties zijn daardoor zonder inspannings- en protocolcorrectie niet onderling vergelijkbaar."
            ),
        },
        {"id": "structure-chart", "type": "chart", "chartId": "structure-mix", "layout": "full"},
        {
            "id": "blur-finding",
            "type": "markdown",
            "sourceId": NDFF_BLUR_SOURCE_ID,
            "body": (
                "## Vervaging moet per record én per soort worden beoordeeld\n\n"
                "Van 9.828 taxoncombinaties hebben 7.629 geen vervaagde records, 1.991 zowel vervaagde als onvervaagde records en 208 uitsluitend vervaagde records. "
                "Vleermuizen (47,90%), Nachtvlinders (21,00%) en Microvlinders (16,04%) hebben op groepsniveau de grootste vervagingsaandelen. "
                "Volledig vervaagde voorbeelden zijn Kruisbladgentiaan (2.905 records), Moeraswespenorchis (1.517), Steenrode orchis (1.079), Vleeskleurige orchis (881), Vroedmeesterpad (392), Kamsalamander (280) en Nauwe korfslak (250). "
                "Een vaste soortregel is daarom onvoldoende; de bruikbaarheid moet per record en analysetype worden vastgelegd."
            ),
        },
        {
            "id": "pq-finding",
            "type": "markdown",
            "sourceId": PQ_SOURCE_ID,
            "body": (
                "## De PQ-dekking in de NDFF is tijdsgebonden én selectief per locatie\n\n"
                "Alle gestructureerde kandidaatmatches hebben bronhouder Zuid-Holland (provincie). Van de 253 PQ-locaties die vóór 2018 zijn bemonsterd, zijn er 149 bij iedere opname herkenbaar, 38 slechts in sommige jaren en 66 nooit. Het protocol Vegetatieopnamen stopt voor deze overlap na 2017; NEM levert daarna nog een beperkte selectie. "
                "Zelfs wanneer ook losse meldingen, ObsIdentify en collectierecords als ruime bovengrens meetellen, stijgt het aandeel herkenbare PQ-opnamen slechts van 51,77% naar 53,16%. Dat bevestigt een selectieve provinciale levering, niet een tekort in de complete Meijendel-PQ-database. "
                "Voor classificatie als `exact` moeten taxonomische synoniemen en Braun-Blanquet-/bedekkingswaarden nog worden gecontroleerd; tot die tijd blijven beide bronnen bewaard en worden alleen bevestigde gedeelde opnamen analytisch niet dubbel geteld."
            ),
        },
        {
            "id": "scope",
            "type": "markdown",
            "body": (
                "## Reikwijdte en definities\n\n"
                "De analyse gebruikt alle 810.830 unieke NDFF-identiteiten uit de selectie 1950-2025, zonder vogels. "
                "`Hok grootte` is steeds de aanvraaggrootte van 1×1 km en niet de werkelijke geometrische nauwkeurigheid; daarom is oppervlakte rechtstreeks uit de brongeometrie berekend. "
                "De aanvraagsoortgroep van het eerste bronbestand is gebruikt voor groepssamenvattingen. Voor 233 records is een tweede FFV-groepslidmaatschap aanwezig; dat vereist later een aparte many-to-many-koppeling."
            ),
        },
        {
            "id": "methodology",
            "type": "markdown",
            "body": (
                "## Methode\n\n"
                "1. Ruimtelijke voorselectie op de ruwe NDFF-vervagingsstatus en geometrieoppervlakte.\n"
                "2. Classificatie van protocollen als losse melding, ObsIdentify, NEM, vegetatieopname of overig protocol.\n"
                "3. Vergelijking van protocolmix en ontbrekende methode-informatie per tijdvak.\n"
                "4. PQ-kandidaten in alle NDFF-protocollen op gelijke datum en genormaliseerde taxonnaam, gevolgd door afstand nul tussen PQ-punt en NDFF-geometrie. Vegetatieopnamen plus NEM vormen de primaire gestructureerde kandidaatset; overige protocollen uitsluitend een bovengrens.\n\n"
                "Deze stappen zijn beschrijvend en controleren herkomst en bruikbaarheid; zij leveren geen populatietrends of causale conclusies."
            ),
        },
        {
            "id": "limitations",
            "type": "markdown",
            "body": (
                "## Beperkingen en robuustheid\n\n"
                "- De grens van 1 km² is een conservatieve voorselectie, geen definitieve plotregel.\n"
                "- 5.336 bronintervallen beginnen vóór 1950 en 10.323 duren langer dan één jaar; zij mogen niet als exacte jaarwaarnemingen worden behandeld.\n"
                "- `Determinatiemethode` is bij 48,12% `onbekend`; zoek-/vangmethode ontbreekt bij 39,88% en apparatuur bij 86,08%.\n"
                "- Een gelijke datum, taxonnaam en locatie is een kandidaatmatch, geen definitief bewijs van dezelfde bronopname. Abundantiecompatibiliteit en resterende taxonomische synoniemen zijn nog niet gecontroleerd.\n"
                "- De PQ-dekking is selectief: 650 van 2.007 opnamen hebben minstens 90% soortenlijstdekking en 147 matchen volledig op de nu beschikbare namen. Naamverschillen kunnen dit onderschatten.\n"
                "- De SOVON-plotintersectie en beoordeling van meerplot-geometrieën zijn nog niet uitgevoerd."
            ),
        },
        {
            "id": "next-steps",
            "type": "markdown",
            "body": (
                "## Aanbevolen vervolgstappen\n\n"
                "1. Bouw `ndff_pq_koppeling` voor de 1.039 herkenbare PQ-opnamen onder Vegetatieopnamen plus NEM, beginnend met de 650 opnamen met minstens 90% soortenlijstdekking; toets taxonomie en abundantie-/Braun-Blanquetcompatibiliteit.\n"
                "2. Koppel alle geometrieën aan één geversioneerde SOVON-plotlaag en registreer per intersectie overlapoppervlak, overlapaandeel en aantal geraakte plots.\n"
                "3. Voeg een many-to-many groepslidmaatschap toe voor de 233 records die door twee FFV-soortgroepen worden geleverd.\n"
                "4. Beslis daarna per analysetype welke vervaagde, grote en methodearme records worden toegelaten, beperkt gebruikt of uitgesloten.\n"
                "5. Ontwerp pas vervolgens de definitieve `ndff_<soortgroep>`-tabellen en importprocedure."
            ),
        },
        {
            "id": "further-questions",
            "type": "markdown",
            "body": (
                "## Open vragen\n\n"
                "- Welke SOVON-plotlaag en versie wordt de vaste ruimtelijke referentie?\n"
                "- Welke dominante-overlapregel blijkt na de echte intersectie verdedigbaar?\n"
                "- Waardoor begrenst de provinciale NDFF-levering sommige PQ-locaties structureel en andere wisselend?\n"
                "- Kunnen de resterende PQ-overeenkomsten via taxonomische synoniemen of bedekkingswaarden worden herkend?\n"
                "- Welke niet-PQ-protocollen hebben aantoonbaar vaste inspanning en herhaling?"
            ),
        },
    ]

    return {
        "surface": "report",
        "manifest": {
            "version": 1,
            "surface": "report",
            "title": "Kwaliteitsanalyse NDFF Meijendel 1950-2025",
            "description": "Ruimtelijke bruikbaarheid, methodeverschillen, vervaging en PQ-overlap",
            "generatedAt": created_at,
            "cards": cards,
            "charts": charts,
            "tables": tables,
            "sources": sources,
            "blocks": blocks,
        },
        "snapshot": {
            "version": 1,
            "generatedAt": created_at,
            "status": "ready",
            "datasets": {
                "headline": [headline],
                "spatial_overall": result["spatial_overall"],
                "group_spatial": result["group_spatial"],
                "structure": result["structure"],
                "temporal_method_mix": result["temporal_method_mix"],
                "temporal_summary": result["temporal_summary"],
                "high_blur_taxa": result["high_blur_taxa"],
            },
        },
        "sources": sources,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staging", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--mysql-client", type=Path, default=Path("/usr/local/mysql/bin/mysql"))
    parser.add_argument("--mysql-database", default="Meijendel")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    result = analyse(args.staging, args.mysql_client, args.mysql_database)
    result_path = args.output_dir / "ndff_kwaliteitsanalyse_resultaten.json"
    artifact_path = args.output_dir / "artifact.json"
    result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    artifact_path.write_text(
        json.dumps(build_artifact(result), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        json.dumps(
            {
                "result": str(result_path),
                "artifact": str(artifact_path),
                "records": result["headline"]["records"],
                "plot_candidate_share": result["headline"]["plot_candidate_share"],
                "pq_recordings_recognized": result["pq_overlap"]["structured_protocols"][
                    "matched_pq_recordings"
                ],
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
