#!/usr/bin/env python3
"""Bouw een beveiligde, reproduceerbare biodiversiteit-hotspotanalyse.

De analyse combineert drie strikt gescheiden lagen per SOVON-plot en tijdvak:
broedvogels, provinciale PQ-vegetatie en uitsluitend toegelaten NDFF-
verspreidingscontext. NDFF wordt nooit als afwezigheid of populatietrend gelezen.
De afgeleide uitvoer mag alleen onder de beveiligde ticket-58679-zone op de T7
worden geschreven.
"""

from __future__ import annotations

import argparse
import csv
import html
import json
import subprocess
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


PERIODS = (
    ("1950-1969", 1950, 1969),
    ("1970-1989", 1970, 1989),
    ("1990-2004", 1990, 2004),
    ("2005-2014", 2005, 2014),
    ("2015-2025", 2015, 2025),
)
SECURE_OUTPUT_ROOT = Path(
    "/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/secure/ticket_58679/derived"
)
SAFE_REPORT_FIELDS = {
    "plot_id",
    "plotnaam",
    "periode",
    "bird_years",
    "bird_richness_mean",
    "bird_territories_mean",
    "bird_rank",
    "pq_years",
    "pq_recordings",
    "pq_richness_mean",
    "pq_shannon_mean",
    "pq_rank",
    "ndff_years",
    "ndff_taxa",
    "ndff_groups",
    "ndff_records",
    "ndff_rank",
    "valid_sources",
    "high_sources",
    "hotspot_class",
}

PLOT_QUERY = """
SELECT p.plot_id,p.plotnaam,ST_AsGeoJSON(p.plot_geometrie) AS geometry_json
FROM Meijendel.ndff_sovon_plot p
WHERE p.plotversie_id=1
ORDER BY p.plot_id
"""
BIRD_COVERAGE_QUERY = """
SELECT DISTINCT p.plot_id,t.jaar
FROM Meijendel.ndff_sovon_plot p
JOIN Meijendel.plot_jaar_teller t ON t.plot_id=p.plot_id
WHERE p.plotversie_id=1 AND t.jaar BETWEEN 1950 AND 2025
ORDER BY p.plot_id,t.jaar
"""
BIRD_QUERY = """
SELECT p.plot_id,t.jaar,COUNT(DISTINCT t.soort_id) AS bird_taxa,
       SUM(t.territoria) AS bird_territories
FROM Meijendel.ndff_sovon_plot p
JOIN Meijendel.territoria t ON t.plot_id=p.plot_id
WHERE p.plotversie_id=1 AND t.jaar BETWEEN 1950 AND 2025
GROUP BY p.plot_id,t.jaar
ORDER BY p.plot_id,t.jaar
"""
PQ_QUERY = """
SELECT p.plot_id,p.jaar,p.n_pq,p.n_opnamen,p.taxa_aantal,
       p.soortenrijkdom_gem,p.shannon_gem,p.dekking_kwaliteit
FROM Meijendel.pq_plot_jaar_vegetatie p
JOIN Meijendel.ndff_sovon_plot s ON s.plot_id=p.plot_id AND s.plotversie_id=1
WHERE p.jaar BETWEEN 1950 AND 2025
ORDER BY p.plot_id,p.jaar
"""
NDFF_QUERY = """
SELECT plot_id,jaar,ndff_soort_id,soortgroep,
       SUM(positieve_waarnemingen) AS positieve_waarnemingen
FROM Meijendel_ndff_secure.v_ndff_lokale_plot_jaar_taxon
WHERE jaar BETWEEN 1950 AND 2025
GROUP BY plot_id,jaar,ndff_soort_id,soortgroep
ORDER BY plot_id,jaar,ndff_soort_id,soortgroep
"""


def assign_period(year: int) -> str | None:
    for label, start, end in PERIODS:
        if start <= int(year) <= end:
            return label
    return None


def percentile_ranks(values: dict[Any, float]) -> dict[Any, float]:
    """Geef gemiddelde percentielrangen; gelijke waarden krijgen dezelfde rang."""
    if not values:
        return {}
    ordered = sorted(values.items(), key=lambda item: (item[1], str(item[0])))
    if len(ordered) == 1:
        return {ordered[0][0]: 1.0}
    positions: dict[float, list[int]] = defaultdict(list)
    for position, (_, value) in enumerate(ordered):
        positions[value].append(position)
    return {
        key: round(sum(positions[value]) / len(positions[value]) / (len(ordered) - 1), 6)
        for key, value in ordered
    }


def classify_multisource_signal(
    *,
    bird_rank: float | None,
    bird_years: int,
    pq_rank: float | None,
    pq_years: int,
    ndff_rank: float | None,
    ndff_records: int,
    ndff_years: int,
) -> str:
    valid = []
    if bird_rank is not None and bird_years >= 3:
        valid.append(bird_rank)
    if pq_rank is not None and pq_years >= 2:
        valid.append(pq_rank)
    if ndff_rank is not None and ndff_records >= 10 and ndff_years >= 2:
        valid.append(ndff_rank)
    if len(valid) < 2:
        return "onvoldoende_meerbronnendekking"
    high = sum(value >= 0.75 for value in valid)
    if high >= 2:
        return "meerdere_bronnen_hoog"
    if high == 1:
        return "een_bron_hoog"
    return "geen_meerbronnen_hotspotsignaal"


def safe_report_row(row: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in row.items() if key in SAFE_REPORT_FIELDS}


def assert_secure_output_path(output_dir: Path) -> None:
    resolved = output_dir.expanduser().resolve(strict=False)
    secure_root = SECURE_OUTPUT_ROOT.resolve(strict=False)
    if resolved != secure_root and secure_root not in resolved.parents:
        raise ValueError("Uitvoer moet in de beveiligde NDFF-afleidingsmap op de T7 staan.")


def mysql_rows(query: str, database: str, login_path: str) -> list[dict[str, str]]:
    command = [
        "/usr/local/mysql/bin/mysql",
        f"--login-path={login_path}",
        "--protocol=tcp",
        "--host=127.0.0.1",
        "--port=3306",
        "--batch",
        "--raw",
        "--default-character-set=utf8mb4",
        database,
        "--execute",
        query.strip(),
    ]
    completed = subprocess.run(command, check=True, capture_output=True, text=True)
    return list(csv.DictReader(completed.stdout.splitlines(), delimiter="\t"))


def mean(values: Iterable[float]) -> float | None:
    data = list(values)
    return sum(data) / len(data) if data else None


def rounded(value: float | None, digits: int = 3) -> float | None:
    return None if value is None else round(value, digits)


def analyse(login_path: str = "meijendel_root") -> dict[str, Any]:
    plot_rows = mysql_rows(PLOT_QUERY, "Meijendel", login_path)
    plots = {
        int(row["plot_id"]): {
            "plot_id": int(row["plot_id"]),
            "plotnaam": row["plotnaam"],
            "geometry": json.loads(row["geometry_json"]),
        }
        for row in plot_rows
    }

    bird_coverage: dict[tuple[int, str], set[int]] = defaultdict(set)
    for row in mysql_rows(BIRD_COVERAGE_QUERY, "Meijendel", login_path):
        period = assign_period(int(row["jaar"]))
        if period:
            bird_coverage[(int(row["plot_id"]), period)].add(int(row["jaar"]))

    bird_annual: dict[tuple[int, int], tuple[int, int]] = {}
    for row in mysql_rows(BIRD_QUERY, "Meijendel", login_path):
        bird_annual[(int(row["plot_id"]), int(row["jaar"]))] = (
            int(row["bird_taxa"]),
            int(row["bird_territories"]),
        )

    pq_period: dict[tuple[int, str], list[dict[str, str]]] = defaultdict(list)
    for row in mysql_rows(PQ_QUERY, "Meijendel", login_path):
        period = assign_period(int(row["jaar"]))
        if period:
            pq_period[(int(row["plot_id"]), period)].append(row)

    ndff_period: dict[tuple[int, str], dict[str, Any]] = defaultdict(
        lambda: {"years": set(), "taxa": set(), "groups": set(), "records": 0}
    )
    for row in mysql_rows(NDFF_QUERY, "Meijendel_ndff_secure", login_path):
        period = assign_period(int(row["jaar"]))
        if not period:
            continue
        value = ndff_period[(int(row["plot_id"]), period)]
        value["years"].add(int(row["jaar"]))
        value["taxa"].add(int(row["ndff_soort_id"]))
        value["groups"].add(row["soortgroep"])
        value["records"] += int(row["positieve_waarnemingen"])

    rows: list[dict[str, Any]] = []
    for period, start, end in PERIODS:
        for plot_id, plot in plots.items():
            survey_years = sorted(bird_coverage.get((plot_id, period), set()))
            bird_values = [bird_annual.get((plot_id, year), (0, 0)) for year in survey_years]
            pq_values = pq_period.get((plot_id, period), [])
            ndff = ndff_period.get(
                (plot_id, period), {"years": set(), "taxa": set(), "groups": set(), "records": 0}
            )
            rows.append(
                {
                    "plot_id": plot_id,
                    "plotnaam": plot["plotnaam"],
                    "periode": period,
                    "period_start": start,
                    "period_end": end,
                    "bird_years": len(survey_years),
                    "bird_richness_mean": rounded(mean(value[0] for value in bird_values)),
                    "bird_territories_mean": rounded(mean(value[1] for value in bird_values)),
                    "pq_years": len({int(value["jaar"]) for value in pq_values}),
                    "pq_recordings": sum(int(value["n_opnamen"]) for value in pq_values),
                    "pq_richness_mean": rounded(
                        mean(float(value["soortenrijkdom_gem"]) for value in pq_values)
                    ),
                    "pq_shannon_mean": rounded(
                        mean(
                            float(value["shannon_gem"])
                            for value in pq_values
                            if value["shannon_gem"] not in ("", "NULL")
                        )
                    ),
                    "ndff_years": len(ndff["years"]),
                    "ndff_taxa": len(ndff["taxa"]),
                    "ndff_groups": len(ndff["groups"]),
                    "ndff_records": ndff["records"],
                }
            )

    for period, _, _ in PERIODS:
        period_rows = [row for row in rows if row["periode"] == period]
        bird_ranks = percentile_ranks(
            {
                row["plot_id"]: row["bird_richness_mean"]
                for row in period_rows
                if row["bird_years"] >= 3 and row["bird_richness_mean"] is not None
            }
        )
        pq_ranks = percentile_ranks(
            {
                row["plot_id"]: row["pq_richness_mean"]
                for row in period_rows
                if row["pq_years"] >= 2 and row["pq_richness_mean"] is not None
            }
        )
        ndff_ranks = percentile_ranks(
            {
                row["plot_id"]: float(row["ndff_taxa"])
                for row in period_rows
                if row["ndff_records"] >= 10 and row["ndff_years"] >= 2
            }
        )
        for row in period_rows:
            row["bird_rank"] = bird_ranks.get(row["plot_id"])
            row["pq_rank"] = pq_ranks.get(row["plot_id"])
            row["ndff_rank"] = ndff_ranks.get(row["plot_id"])
            valid_sources = sum(
                (
                    row["bird_rank"] is not None and row["bird_years"] >= 3,
                    row["pq_rank"] is not None and row["pq_years"] >= 2,
                    row["ndff_rank"] is not None
                    and row["ndff_records"] >= 10
                    and row["ndff_years"] >= 2,
                )
            )
            high_sources = sum(
                value is not None and value >= 0.75
                for value in (row["bird_rank"], row["pq_rank"], row["ndff_rank"])
            )
            row["valid_sources"] = valid_sources
            row["high_sources"] = high_sources
            row["hotspot_class"] = classify_multisource_signal(
                bird_rank=row["bird_rank"],
                bird_years=row["bird_years"],
                pq_rank=row["pq_rank"],
                pq_years=row["pq_years"],
                ndff_rank=row["ndff_rank"],
                ndff_records=row["ndff_records"],
                ndff_years=row["ndff_years"],
            )

    safe_rows = [safe_report_row(row) for row in rows]
    period_summary = []
    for period, _, _ in PERIODS:
        selected = [row for row in safe_rows if row["periode"] == period]
        classes = defaultdict(int)
        for row in selected:
            classes[row["hotspot_class"]] += 1
        period_summary.append(
            {
                "periode": period,
                "bird_covered_plots": sum(row["bird_years"] >= 3 for row in selected),
                "pq_covered_plots": sum(row["pq_years"] >= 2 for row in selected),
                "ndff_covered_plots": sum(
                    row["ndff_records"] >= 10 and row["ndff_years"] >= 2 for row in selected
                ),
                "ndff_records": sum(row["ndff_records"] for row in selected),
                "ndff_taxa": len(
                    set().union(
                        *(
                            ndff_period.get((plot_id, period), {"taxa": set()})["taxa"]
                            for plot_id in plots
                        )
                    )
                ),
                "multi_high": classes["meerdere_bronnen_hoog"],
                "one_high": classes["een_bron_hoog"],
                "no_multi_signal": classes["geen_meerbronnen_hotspotsignaal"],
                "insufficient": classes["onvoldoende_meerbronnendekking"],
            }
        )

    current = [row for row in safe_rows if row["periode"] == "2015-2025"]
    previous = {row["plot_id"]: row for row in safe_rows if row["periode"] == "2005-2014"}
    change_rows = []
    for row in current:
        before = previous[row["plot_id"]]
        change_rows.append(
            {
                "plot_id": row["plot_id"],
                "plotnaam": row["plotnaam"],
                "bird_richness_2005_2014": before["bird_richness_mean"],
                "bird_richness_2015_2025": row["bird_richness_mean"],
                "bird_richness_delta": rounded(
                    row["bird_richness_mean"] - before["bird_richness_mean"]
                    if row["bird_richness_mean"] is not None
                    and before["bird_richness_mean"] is not None
                    else None
                ),
                "pq_richness_2005_2014": before["pq_richness_mean"],
                "pq_richness_2015_2025": row["pq_richness_mean"],
                "pq_richness_delta": rounded(
                    row["pq_richness_mean"] - before["pq_richness_mean"]
                    if row["pq_richness_mean"] is not None
                    and before["pq_richness_mean"] is not None
                    else None
                ),
                "ndff_taxa_2005_2014": before["ndff_taxa"],
                "ndff_taxa_2015_2025": row["ndff_taxa"],
                "ndff_records_2005_2014": before["ndff_records"],
                "ndff_records_2015_2025": row["ndff_records"],
                "hotspot_class_2005_2014": before["hotspot_class"],
                "hotspot_class_2015_2025": row["hotspot_class"],
            }
        )

    return {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "periods": [label for label, _, _ in PERIODS],
        "plots": {plot_id: {"plotnaam": row["plotnaam"], "geometry": row["geometry"]} for plot_id, row in plots.items()},
        "plot_period": safe_rows,
        "period_summary": period_summary,
        "change": change_rows,
        "quality_rules": {
            "bird": "minimaal 3 getelde jaren binnen het tijdvak",
            "pq": "minimaal 2 gemeten plotjaren binnen het tijdvak",
            "ndff": "minimaal 10 toegelaten positieve records in minimaal 2 jaren",
            "high": "bovenste kwartiel binnen bron en tijdvak",
            "multisource": "minimaal twee geldige bronnen, waarvan minimaal twee hoog",
            "interpretation": "signaalklasse; geen biodiversiteitsindex, afwezigheid, trend of causaliteit",
        },
    }


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]) if rows else [])
        writer.writeheader()
        writer.writerows(rows)


def geometry_rings(geometry: dict[str, Any]) -> list[list[list[float]]]:
    if geometry["type"] == "Polygon":
        return geometry["coordinates"]
    if geometry["type"] == "MultiPolygon":
        return [ring for polygon in geometry["coordinates"] for ring in polygon]
    raise ValueError(f"Niet-ondersteund geometrie-type: {geometry['type']}")


def render_map_series(result: dict[str, Any], output_path: Path, mode: str) -> None:
    coordinates = [
        point
        for plot in result["plots"].values()
        for ring in geometry_rings(plot["geometry"])
        for point in ring
    ]
    min_x = min(point[0] for point in coordinates)
    max_x = max(point[0] for point in coordinates)
    min_y = min(point[1] for point in coordinates)
    max_y = max(point[1] for point in coordinates)
    panel_width, panel_height = 480, 540
    margin, title_height = 24, 72
    width, height = panel_width * 3, panel_height * 2 + 120
    by_key = {(row["plot_id"], row["periode"]): row for row in result["plot_period"]}
    class_colors = {
        "meerdere_bronnen_hoog": "#2f6690",
        "een_bron_hoog": "#d5a021",
        "geen_meerbronnen_hotspotsignaal": "#b8bec5",
        "onvoldoende_meerbronnendekking": "#f3f4f5",
    }
    coverage_colors = {0: "#f3f4f5", 1: "#dbe8f3", 2: "#83b3d3", 3: "#245b80"}

    def scaled(point: list[float], x0: float, y0: float) -> tuple[float, float]:
        usable_w = panel_width - 2 * margin
        usable_h = panel_height - title_height - 2 * margin
        scale = min(usable_w / (max_x - min_x), usable_h / (max_y - min_y))
        px = x0 + margin + (point[0] - min_x) * scale
        py = y0 + title_height + margin + (max_y - point[1]) * scale
        return px, py

    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        '<style>text{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;fill:#20252b}.period{font-size:22px;font-weight:700}.note{font-size:14px;fill:#59636e}.plot{stroke:#ffffff;stroke-width:1.2;fill-rule:evenodd}.legend{font-size:14px}</style>',
    ]
    heading = (
        "Meerdere bronnen wijzen op hoge ecologische waarde"
        if mode == "hotspot"
        else "Aantal bronnen met voldoende dekking"
    )
    svg.append(f'<text x="24" y="36" class="period">{html.escape(heading)}</text>')
    svg.append(
        '<text x="24" y="62" class="note">SOVON-kavels per tijdvak; NDFF is uitsluitend positieve verspreidingscontext.</text>'
    )
    for index, (period, _, _) in enumerate(PERIODS):
        column, row_index = index % 3, index // 3
        x0, y0 = column * panel_width, 80 + row_index * panel_height
        svg.append(f'<text x="{x0 + margin}" y="{y0 + 32}" class="period">{period}</text>')
        for plot_id, plot in result["plots"].items():
            value = by_key[(plot_id, period)]
            color = (
                class_colors[value["hotspot_class"]]
                if mode == "hotspot"
                else coverage_colors[value["valid_sources"]]
            )
            path_parts = []
            for ring in geometry_rings(plot["geometry"]):
                points = [scaled(point, x0, y0) for point in ring]
                path_parts.append(
                    "M " + " L ".join(f"{x:.2f},{y:.2f}" for x, y in points) + " Z"
                )
            tooltip = (
                f"{plot['plotnaam']}: {value['hotspot_class'].replace('_', ' ')}"
                if mode == "hotspot"
                else f"{plot['plotnaam']}: {value['valid_sources']} geldige bronnen"
            )
            svg.append(
                f'<path class="plot" fill="{color}" d="{" ".join(path_parts)}"><title>{html.escape(tooltip)}</title></path>'
            )
    legend_y = height - 42
    legend = (
        [
            ("#2f6690", "minimaal twee bronnen hoog"),
            ("#d5a021", "een bron hoog"),
            ("#b8bec5", "geen meerbronnen-hotspotsignaal"),
            ("#f3f4f5", "onvoldoende dekking"),
        ]
        if mode == "hotspot"
        else [(coverage_colors[value], f"{value} geldige bronnen") for value in range(4)]
    )
    x = 24
    for color, label in legend:
        svg.append(f'<rect x="{x}" y="{legend_y - 14}" width="18" height="18" fill="{color}" stroke="#8a939c"/>')
        svg.append(f'<text x="{x + 26}" y="{legend_y}" class="legend">{html.escape(label)}</text>')
        x += 300
    svg.append("</svg>")
    output_path.write_text("\n".join(svg) + "\n", encoding="utf-8")


def source_spec(source_id: str, label: str, sql: str, tables: list[str], executed_at: str) -> dict[str, Any]:
    return {
        "id": source_id,
        "label": label,
        "query": {
            "engine": "MySQL 9.7.1",
            "sql": sql.strip(),
            "description": label,
            "executed_at": executed_at,
            "language": "SQL",
            "tables_used": tables,
            "filters": ["SOVON-plotversie 2025", "tijdvakken binnen 1950-2025"],
            "metric_definitions": [],
        },
    }


def build_reviewed_snapshot(result: dict[str, Any]) -> dict[str, Any]:
    """Maak de actuele Data App-snapshot zonder beveiligde detailvelden."""
    common_filters = [
        "SOVON-plotversie 2025 met 55 kavels",
        "vijf vaste tijdvakken binnen 1950-2025",
        "NDFF alleen na ruimtelijke en PQ-analysepoort",
    ]
    tables = [
        "Meijendel.territoria",
        "Meijendel.plot_jaar_teller",
        "Meijendel.pq_plot_jaar_vegetatie",
        "Meijendel_ndff_secure.v_ndff_lokale_plot_jaar_taxon",
    ]
    metric_definitions = [
        {
            "label": "Voldoende vogeldekking",
            "definition": "Minimaal drie geregistreerde teljaren in het tijdvak; rijkdom is het gemiddelde aantal territoriumhoudende soorten per teljaar.",
            "componentIds": ["coverage-chart", "current-signals-table", "change-table"],
            "sourceLineage": [{"tables": ["Meijendel.territoria", "Meijendel.plot_jaar_teller"]}],
        },
        {
            "label": "Voldoende PQ-dekking",
            "definition": "Minimaal twee werkelijk gemeten PQ-plotjaren in het tijdvak; ontbrekende jaren zijn niet geïnterpoleerd.",
            "componentIds": ["coverage-chart", "current-signals-table", "change-table"],
            "sourceLineage": [{"tables": ["Meijendel.pq_plot_jaar_vegetatie"]}],
        },
        {
            "label": "Voldoende NDFF-contextdekking",
            "definition": "Minimaal tien toegelaten positieve records in minimaal twee jaren; dit is registratie-intensiteit en geen afwezigheids- of trendmaat.",
            "componentIds": ["coverage-chart", "current-signals-table", "change-table"],
            "sourceLineage": [{"tables": ["Meijendel_ndff_secure.v_ndff_lokale_plot_jaar_taxon"]}],
        },
        {
            "label": "Meerbronnen-hotspotsignaal",
            "definition": "Minimaal twee voldoende gedekte bronnen behoren voor dezelfde kavel en hetzelfde tijdvak tot het bovenste kwartiel van hun eigen bronverdeling.",
            "componentIds": ["class-chart", "current-signals-table"],
            "sourceLineage": [{"tables": tables}],
        },
    ]

    def query(rows: list[dict[str, Any]], label: str, sql: str) -> dict[str, Any]:
        return {
            "rows": rows,
            "source": {
                "label": label,
                "sql": sql.strip(),
                "tables": tables,
                "filters": common_filters,
                "metricDefinitions": metric_definitions,
            },
        }

    return {
        "surface": "report",
        "title": "Biodiversiteitssignalen in Meijendel door de tijd",
        "generatedAt": result["created_utc"],
        "status": "ready",
        "buildStatus": "creating",
        "filters": [],
        "queries": {
            "period_summary": query(
                result["period_summary"],
                "Dekking en hotspotsignaalklassen per tijdvak",
                "SELECT periode, brondekking, hotspotsignaalklasse FROM afgeleide_plot_periode_samenvatting",
            ),
            "plot_period": query(
                result["plot_period"],
                "Geaggregeerde bronmetingen per SOVON-kavel en tijdvak",
                "SELECT plot_id, periode, vogel-, PQ- en NDFF-contextmaten FROM afgeleide_plot_periode",
            ),
            "change": query(
                result["change"],
                "Beschrijvende vergelijking 2005-2014 met 2015-2025",
                "SELECT plot_id, bronmaten_2005_2014, bronmaten_2015_2025 FROM afgeleide_vergelijking",
            ),
        },
    }


def build_artifact(result: dict[str, Any]) -> dict[str, Any]:
    created = result["created_utc"]
    current = [row for row in result["plot_period"] if row["periode"] == "2015-2025"]
    current_multi = sum(row["hotspot_class"] == "meerdere_bronnen_hoog" for row in current)
    current_full_coverage = sum(row["valid_sources"] == 3 for row in current)
    coverage_rows = [
        {"periode": row["periode"], "bron": source, "plots": row[field]}
        for row in result["period_summary"]
        for source, field in (
            ("Vogels", "bird_covered_plots"),
            ("Provinciale PQ", "pq_covered_plots"),
            ("NDFF-context", "ndff_covered_plots"),
        )
    ]
    class_labels = {
        "multi_high": "Minimaal twee bronnen hoog",
        "one_high": "Eén bron hoog",
        "no_multi_signal": "Geen meerbronnen-hotspotsignaal",
        "insufficient": "Onvoldoende dekking",
    }
    class_rows = [
        {"periode": row["periode"], "klasse": label, "plots": row[field]}
        for row in result["period_summary"]
        for field, label in class_labels.items()
    ]
    current_table = sorted(
        current,
        key=lambda row: (-row["high_sources"], -row["valid_sources"], row["plotnaam"]),
    )
    sources = [
        source_spec("src_birds", "Broedvogelrijkdom en territoria per geteld plotjaar", BIRD_QUERY, ["Meijendel.territoria", "Meijendel.plot_jaar_teller"], created),
        source_spec("src_pq", "Provinciale PQ-vegetatie per plotjaar", PQ_QUERY, ["Meijendel.pq_plot_jaar_vegetatie"], created),
        source_spec("src_ndff", "Toegelaten positieve NDFF-verspreidingscontext", NDFF_QUERY, ["Meijendel_ndff_secure.v_ndff_lokale_plot_jaar_taxon"], created),
        source_spec("src_combined", "Gecombineerde signaalklasse na afzonderlijke bronrangschikking", "SELECT 'afgeleid in reproduceerbaar analysescript' AS methode", ["Meijendel.territoria", "Meijendel.pq_plot_jaar_vegetatie", "Meijendel_ndff_secure.v_ndff_lokale_plot_jaar_taxon"], created),
    ]
    charts = [
        {
            "id": "coverage-period",
            "title": "Kavels met voldoende dekking per bron",
            "subtitle": "Vogels minimaal 3 jaren; PQ minimaal 2 jaren; NDFF minimaal 10 records in 2 jaren",
            "type": "bar",
            "intent": "comparison",
            "dataset": "coverage_period",
            "sourceId": "src_combined",
            "encodings": {
                "x": {"field": "periode", "type": "ordinal", "label": "Tijdvak"},
                "y": {"field": "plots", "type": "quantitative", "label": "Kavels"},
                "color": {"field": "bron", "type": "nominal", "label": "Bron"},
            },
            "layout": "full",
            "palette": {"kind": "categorical"},
            "settings": {"groupMode": "grouped", "showValues": True},
        },
        {
            "id": "classes-period",
            "title": "Hotspotsignaalklassen per tijdvak",
            "subtitle": "Een hoge klasse vereist het bovenste kwartiel binnen minimaal twee voldoende gedekte bronnen",
            "type": "stackedBar100",
            "intent": "composition",
            "dataset": "classes_period",
            "sourceId": "src_combined",
            "encodings": {
                "x": {"field": "periode", "type": "ordinal", "label": "Tijdvak"},
                "y": {"field": "plots", "type": "quantitative", "label": "Kavels"},
                "color": {"field": "klasse", "type": "nominal", "label": "Signaalklasse"},
            },
            "layout": "full",
            "palette": {"kind": "categorical"},
            "settings": {"groupMode": "stacked100", "showPercent": True},
        },
    ]
    tables = [
        {
            "id": "current-plots",
            "title": "Kaveloverzicht 2015-2025",
            "subtitle": "Bronmetingen blijven afzonderlijk zichtbaar; NDFF is uitsluitend positieve context",
            "dataset": "current_plots",
            "sourceId": "src_combined",
            "defaultSort": {"field": "high_sources", "direction": "desc"},
            "density": "dense",
            "layout": "full",
            "columns": [
                {"field": "plotnaam", "label": "Kavel", "type": "text"},
                {"field": "bird_richness_mean", "label": "Gem. vogelsoorten/jaar", "format": "number"},
                {"field": "bird_years", "label": "Vogeljaren", "format": "number"},
                {"field": "pq_richness_mean", "label": "Gem. PQ-soortenrijkdom", "format": "number"},
                {"field": "pq_years", "label": "PQ-jaren", "format": "number"},
                {"field": "ndff_taxa", "label": "NDFF-doeltaxa", "format": "number"},
                {"field": "ndff_records", "label": "NDFF-records", "format": "number"},
                {"field": "valid_sources", "label": "Geldige bronnen", "format": "number"},
                {"field": "high_sources", "label": "Hoge bronnen", "format": "number"},
                {"field": "hotspot_class", "label": "Signaalklasse", "type": "text"},
            ],
        }
    ]
    blocks = [
        {"id": "title", "type": "markdown", "body": "# Biodiversiteitssignalen in Meijendel door de tijd"},
        {
            "id": "executive-summary",
            "type": "markdown",
            "body": (
                "## Executive Summary\n\n"
                f"- **Een ruimtelijke tijdanalyse is mogelijk, maar niet als één absolute biodiversiteitsindex.** De drie bronnen meten verschillende onderdelen en hebben sterk verschillende dekking.\n"
                f"- **In 2015-2025 wijzen bij {current_multi} van 55 kavels minimaal twee voldoende gedekte bronnen op een hoge relatieve waarde.** Dit is een signaal voor nadere ecologische beoordeling, geen formele natuurwaardering.\n"
                f"- **Slechts {current_full_coverage} kavels hebben in 2015-2025 volgens de vooraf vastgelegde drempels voldoende dekking in alle drie bronnen.** Kaarten zonder dekkingskaart zouden daarom misleidend zijn.\n"
                "- **NDFF ondersteunt de ruimtelijke duiding, maar bewijst geen afname, toename of afwezigheid.** Alleen toegelaten positieve contextrecords zijn gebruikt; provinciale PQ-records zijn niet dubbel geteld."
            ),
        },
        {
            "id": "definitions",
            "type": "markdown",
            "body": (
                "## Wat de kaarten meten\n\n"
                "Per bron en tijdvak worden alleen kavels met minimale dekking onderling gerangschikt. *Hoog* betekent het bovenste kwartiel binnen die bron en periode. De klasse *meerdere bronnen hoog* vereist minimaal twee voldoende gedekte, hoog gerangschikte bronnen. Dit voorkomt dat veel losse NDFF-meldingen automatisch tot een hoge biodiversiteitswaardering leiden."
            ),
        },
        {
            "id": "coverage-finding",
            "type": "markdown",
            "body": (
                "## De onderzoeksdekking bepaalt wat door de tijd vergelijkbaar is\n\n"
                "Vogelgegevens bieden vanaf de jaren zeventig de breedste ruimtelijke tijdreeks. PQ-metingen beginnen in 1981 en blijven tot 36 kavels beperkt. De toegelaten NDFF-context groeit sterk vanaf 2005 en vooral na 2015. Daarom zijn veranderingen in NDFF-taxa zonder de registratie-intensiteit ernaast niet ecologisch als trend te interpreteren."
            ),
        },
        {"id": "coverage-chart", "type": "chart", "chartId": "coverage-period", "layout": "full"},
        {
            "id": "classification-finding",
            "type": "markdown",
            "body": (
                "## Meerdere bronnen leveren een sterker hotspotsignaal dan één bron\n\n"
                "De signaalklasse markeert waar onafhankelijke informatie samenvalt. Een kavel met uitsluitend veel NDFF-meldingen blijft een éénbronsignaal. Een kavel met hoge vogelrijkdom én hoge PQ-rijkdom, of met één daarvan plus goed gedekte NDFF-context, krijgt een meerbronnensignaal."
            ),
        },
        {"id": "class-chart", "type": "chart", "chartId": "classes-period", "layout": "full"},
        {
            "id": "map-note",
            "type": "markdown",
            "body": (
                "## Ruimtelijke kaartreeksen\n\n"
                "Naast dit rapport zijn twee beveiligde SVG-kaartreeksen gemaakt: één voor hotspotsignalen en één voor brondekking. Door met de muis over een kavel te bewegen verschijnt de kavelnaam en klasse. De kaarten blijven in dezelfde beveiligde T7-map als dit rapport."
            ),
        },
        {
            "id": "current-finding",
            "type": "markdown",
            "body": (
                "## Het actuele tijdvak blijft per bron controleerbaar\n\n"
                "De tabel toont de bronmetingen naast elkaar. Verschillen tussen 2005-2014 en 2015-2025 zijn beschrijvend opgeslagen in een afzonderlijke CSV. Voor vogels en PQ kunnen die verschillen nader statistisch worden getoetst; voor NDFF blijven het veranderingen in geregistreerde aanwezigheid."
            ),
        },
        {"id": "current-table", "type": "table", "tableId": "current-plots", "layout": "full"},
        {
            "id": "next-steps",
            "type": "markdown",
            "body": (
                "## Aanbevolen vervolgstappen\n\n"
                "1. Beoordeel de meerbronnen-hotspots ecologisch op soortensamenstelling, niet alleen op aantallen taxa.\n"
                "2. Toets voor vogels en provinciale PQ’s of verschillen tussen de laatste twee tijdvakken statistisch robuust zijn.\n"
                "3. Leg beheermaatregelen met volledige geometrie en datum vast voordat een effectanalyse wordt uitgevoerd.\n"
                "4. Gebruik NDFF om hypothesen en veldcontrole te richten, niet als bewijs van populatietrends."
            ),
        },
        {
            "id": "questions",
            "type": "markdown",
            "body": (
                "## Open vragen\n\n"
                "- Welke meerbronnen-hotspots bevatten vooral karakteristieke duinsoorten en welke vooral algemene soorten?\n"
                "- Zijn veranderingen in vogel- en PQ-rijkdom ook zichtbaar na correctie voor kavel, jaar en meetdekking?\n"
                "- Welke beheermaatregelen kunnen betrouwbaar aan behandelde en referentiekavels worden gekoppeld?"
            ),
        },
        {
            "id": "caveats",
            "type": "markdown",
            "body": (
                "## Beperkingen en aannames\n\n"
                "- De rangschikking is relatief binnen elk tijdvak en geen absolute natuurwaardering.\n"
                "- Vogelrijkdom is gemiddeld over geregistreerde teljaren; verschillen in telmethode en kavelhistorie blijven relevant.\n"
                "- PQ-rijkdom geldt alleen voor werkelijk gemeten plotjaren; ontbrekende jaren zijn niet geïnterpoleerd.\n"
                "- NDFF bevat uitsluitend positieve registraties van 158 geselecteerde taxa; weinig records betekenen niet dat een kavel soortenarm is.\n"
                "- Samenhang tussen bronnen bewijst geen oorzaak. Vegetatie, voedsel, water, bodem, weer, beheer, begrazing, predatie, verstuiving en rust kunnen tegelijk en per plaats verschillend werken."
            ),
        },
    ]
    return {
        "surface": "report",
        "manifest": {
            "version": 1,
            "surface": "report",
            "title": "Biodiversiteitssignalen in Meijendel door de tijd",
            "description": "Hotspotsignalen, brondekking en verandering per SOVON-kavel en tijdvak",
            "generatedAt": created,
            "charts": charts,
            "tables": tables,
            "cards": [],
            "sources": sources,
            "blocks": blocks,
        },
        "snapshot": {
            "version": 1,
            "generatedAt": created,
            "status": "ready",
            "datasets": {
                "coverage_period": coverage_rows,
                "classes_period": class_rows,
                "current_plots": current_table,
            },
        },
        "sources": sources,
    }


def write_outputs(result: dict[str, Any], output_dir: Path) -> dict[str, str]:
    assert_secure_output_path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    plot_period_path = output_dir / "biodiversiteit_hotspots_plot_periode.csv"
    change_path = output_dir / "biodiversiteit_hotspots_verandering_2005_2025.csv"
    summary_path = output_dir / "biodiversiteit_hotspots_samenvatting.json"
    artifact_path = output_dir / "artifact.json"
    hotspot_map = output_dir / "biodiversiteit_hotspots_kaartreeks.svg"
    coverage_map = output_dir / "biodiversiteit_brondekking_kaartreeks.svg"
    write_csv(plot_period_path, result["plot_period"])
    write_csv(change_path, result["change"])
    safe_summary = {key: value for key, value in result.items() if key != "plots"}
    summary_path.write_text(json.dumps(safe_summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    artifact_path.write_text(json.dumps(build_reviewed_snapshot(result), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    render_map_series(result, hotspot_map, "hotspot")
    render_map_series(result, coverage_map, "coverage")
    return {
        "plot_period": str(plot_period_path),
        "change": str(change_path),
        "summary": str(summary_path),
        "artifact": str(artifact_path),
        "hotspot_map": str(hotspot_map),
        "coverage_map": str(coverage_map),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--login-path", default="meijendel_root")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = analyse(args.login_path)
    paths = write_outputs(result, args.output_dir)
    print(json.dumps({"status": "PASS", "outputs": paths}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
