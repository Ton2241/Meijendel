#!/usr/bin/env python3
"""Bouw de niet-gevoelige NDFF-protocolkwaliteitslaag in lokale MySQL."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import re
import subprocess
from collections import defaultdict
from datetime import date
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).parents[2]
SCHEMA = ROOT / "gis" / "database" / "ndff_protocolkwaliteit_schema.sql"
DEFAULT_SEED = ROOT / "gis" / "database" / "ndff_protocolkwaliteit_seed.csv"
SOURCE_XLSX = ROOT / "Natuurprotocollen" / "Natuurprotocollen_gebruiksmatrix.xlsx"
SOURCE_DOCX = ROOT / "Natuurprotocollen" / "Classificatie_natuurprotocollen_wetenschappelijk_gebruik.docx"
RULE_VERSION = "ndff-protocolkwaliteit-v1"
SCOPE_RULE_VERSION = "ndff-protocolbereik-v2"
DECISION_RULE_VERSION = "ndff-analysebesluit-v4"
SNL_OVERLAP_RULE_VERSION = "ndff-snl-overlap-v1"
PUBLIC_PQ_RULE_VERSION = "ndff-open-pq-poort-v1"
ANALYSIS_CHAIN_VERSION = "ndff-analyseketen-v1"
SOURCE_XLSX_SHA256 = "12cccb8bf8408fae9a7819f798f4f8748c19c46211dac9f3ab0069086e565592"
SOURCE_DOCX_SHA256 = "b7dc432d59aaf3a8288873d813825d8c5448a335782fb82e1f9d01deb1b33a75"
ANALYSIS_TYPES = ("V", "I", "TV", "TA", "TK")
VLINDER_ROUTE_RULE_VERSION = "ndff-vlinderroute-v1"
VLIESVLEUGEL_ROUTE_RULE_VERSION = "ndff-vliesvleugelroute-v1"
LIBEL_ROUTE_RULE_VERSION = "ndff-libellenroute-v1"
REPTILE_ROUTE_RULE_VERSION = "ndff-reptielroute-v1"
AMPHIBIAN_WATER_RULE_VERSION = "ndff-amfibiewater-v1"
BAT_TRANSECT_RULE_VERSION = "ndff-vleermuistransect-v1"
VLINDER_TABLE_PREFIX = "Meijendel.ndff_vlinder"
VLIESVLEUGEL_TABLE_PREFIX = "Meijendel.ndff_vliesvleugel"
LIBEL_TABLE_PREFIX = "Meijendel.ndff_libel"
REPTILE_TABLE_PREFIX = "Meijendel.ndff_reptiel"
AMPHIBIAN_TABLE_PREFIX = "Meijendel.ndff_amfibie"
BAT_TABLE_PREFIX = "Meijendel.ndff_vleermuis"
VLINDER_RECONSTRUCTION_EXPECTED = {
    "source_records": 82217,
    "visits": 3126,
    "route_families": 11,
    "route_components": 23,
    "fine_geometries": 455,
    "fine_visits": 3063,
    "coarse_only_visits": 63,
    "coarse_only_records": 185,
    "target_taxa": 34,
    "matrix_rows": 106284,
    "positive_rows": 20075,
    "zero_rows": 86209,
    "invalid_matrix_rows": 0,
    "manual_review_visits": 172,
    "legacy_secure_tables": 0,
}
VLIESVLEUGEL_RECONSTRUCTION_EXPECTED = {
    "source_records": 1535,
    "visits": 217,
    "route_families": 2,
    "route_components": 2,
    "fine_geometries": 40,
    "fine_visits": 217,
    "coarse_only_visits": 0,
    "coarse_only_records": 0,
    "target_taxa": 6,
    "matrix_rows": 1302,
    "positive_rows": 365,
    "zero_rows": 937,
    "invalid_matrix_rows": 0,
    "manual_review_visits": 0,
    "legacy_secure_tables": 0,
}
LIBEL_RECONSTRUCTION_EXPECTED = {
    "source_records": 3280,
    "visits": 461,
    "route_families": 9,
    "route_components": 13,
    "fine_geometries": 18,
    "fine_visits": 401,
    "coarse_only_visits": 60,
    "coarse_only_records": 351,
    "target_taxa": 29,
    "matrix_rows": 13173,
    "positive_rows": 2170,
    "zero_rows": 11003,
    "invalid_matrix_rows": 0,
    "manual_review_visits": 0,
    "general_route_families": 9,
    "unknown_route_families": 0,
    "general_visits": 454,
    "unknown_scope_visits": 7,
    "source_payload_invalid": 0,
    "positive_mismatch": 0,
    "zero_outside_general": 0,
    "legacy_secure_tables": 0,
}
REPTILE_RECONSTRUCTION_EXPECTED = {
    "source_records": 957,
    "visits": 660,
    "route_families": 14,
    "historical_geometries": 15,
    "exact_geometries": 56,
    "route_visits": 648,
    "coarse_only_visits": 12,
    "coarse_only_records": 12,
    "target_taxa": 2,
    "matrix_rows": 1320,
    "positive_rows": 661,
    "zero_rows": 659,
    "adult_count": 6286,
    "subadult_count": 64,
    "juvenile_count": 761,
    "unknown_stage_count": 0,
    "invalid_matrix_rows": 0,
    "zandhagedis_zero_rows": 0,
    "fully_negative_visits": 0,
    "invalid_effort_claims": 0,
    "legacy_secure_tables": 0,
}
AMPHIBIAN_RECONSTRUCTION_EXPECTED = {
    "source_records": 2439,
    "blurred_records": 80,
    "year_aggregate_records": 80,
    "visits": 211,
    "water_families": 50,
    "water_geometries": 52,
    "water_visits": 1300,
    "analysis_taxa": 7,
    "matrix_rows": 9100,
    "positive_rows": 2274,
    "zero_rows": 6826,
    "exact_positive_rows": 584,
    "presentie_positive_rows": 1556,
    "minimum_positive_rows": 0,
    "estimate_positive_rows": 0,
    "mixed_positive_rows": 134,
    "invalid_matrix_rows": 0,
    "positive_source_mismatch": 0,
    "kamsalamander_matrix_rows": 0,
    "secure_derived_tables": 0,
}
BAT_RECONSTRUCTION_EXPECTED = {
    "source_records": 2624,
    "retained_records": 2551,
    "suppressed_duplicates": 73,
    "route_families": 2,
    "route_geometries": 2023,
    "visits": 44,
    "vtt_visits": 26,
    "vleermus_visits": 18,
    "target_taxa": 4,
    "matrix_rows": 242,
    "target_matrix_rows": 158,
    "target_positive_rows": 126,
    "bycatch_positive_rows": 84,
    "zero_rows": 32,
    "target_records": 2410,
    "bycatch_records": 141,
    "off_window_visits": 9,
    "repeat_window_review_visits": 6,
    "invalid_matrix_rows": 0,
    "duplicate_target_missing": 0,
    "secure_derived_tables": 0,
}
ANALYSIS_CHAIN_EXPECTED = {
    "canonical_records": 810983,
    "canonical_duplicates": 0,
    "only_public": 796410,
    "secure_replaces_public": 14420,
    "only_secure": 153,
    "representation_invalid": 0,
    "analysis_records": 810983,
    "analysis_duplicates": 0,
    "analysis_missing_fields": 0,
    "wrong_chain_version": 0,
    "preliminarily_usable": 303319,
    "overlap_warning": 4,
    "excluded_pq": 97333,
    "excluded_spatial": 410327,
    "excluded_overlap": 0,
    "unvalidated_records": 810983,
    "secure_detail_records": 14573,
    "distribution_rows": 105999,
    "distribution_sources": 303319,
    "trend_rows": 11138,
    "trend_sources": 66125,
    "trend_loose": 0,
    "usage_rows": 142,
    "usage_records": 810983,
    "usage_mismatch": 0,
    "richness_rows": 12611,
    "richness_signals": 105999,
    "first_last_rows": 42714,
    "first_last_invalid": 0,
    "change_rows": 33022,
    "change_adjacent": 18458,
    "change_gap": 8059,
    "change_first": 6505,
    "change_partition_mismatch": 0,
    "coverage_rows": 12611,
    "coverage_sources": 303319,
    "coverage_split_mismatch": 0,
    "analysis_view_grants": 0,
}


def reconstruct_route_families(
    rows: Iterable[dict[str, object]],
    *,
    coarse_area_m2: float = 900_000.0,
    version_match_distance_m: float = 10.0,
    version_match_fraction: float = 0.5,
) -> dict[str, object]:
    """Reconstructeer routefamilies uit gezamenlijke bezoeken en geometrieën."""
    visits: dict[str, set[str]] = defaultdict(set)
    geometry: dict[str, tuple[float, float, float]] = {}
    geometry_years: dict[str, set[int]] = defaultdict(set)
    geometry_visits: dict[str, set[str]] = defaultdict(set)
    fine_pair_records: dict[tuple[str, str], int] = defaultdict(int)
    coarse_visit_records: dict[str, int] = defaultdict(int)

    for row in rows:
        visit = str(row["visit"])
        geometry_key = str(row["geometry"])
        area = float(row["area"])
        records = int(row["records"])
        if area >= coarse_area_m2:
            coarse_visit_records[visit] += records
            continue
        visits[visit].add(geometry_key)
        geometry[geometry_key] = (float(row["x"]), float(row["y"]), area)
        geometry_years[geometry_key].add(int(row["year"]))
        geometry_visits[geometry_key].add(visit)
        fine_pair_records[(visit, geometry_key)] += records

    parent = {key: key for key in geometry}
    rank = {key: 0 for key in geometry}

    def find(key: str) -> str:
        while parent[key] != key:
            parent[key] = parent[parent[key]]
            key = parent[key]
        return key

    def union(left: str, right: str) -> None:
        left_root, right_root = find(left), find(right)
        if left_root == right_root:
            return
        if rank[left_root] < rank[right_root]:
            left_root, right_root = right_root, left_root
        parent[right_root] = left_root
        if rank[left_root] == rank[right_root]:
            rank[left_root] += 1

    for member_set in visits.values():
        ordered = sorted(member_set)
        for geometry_key in ordered[1:]:
            union(ordered[0], geometry_key)

    components_by_root: dict[str, set[str]] = defaultdict(set)
    for geometry_key in geometry:
        components_by_root[find(geometry_key)].add(geometry_key)
    components = sorted(components_by_root.values(), key=lambda members: sorted(members))

    component_parent = list(range(len(components)))

    def component_find(index: int) -> int:
        while component_parent[index] != index:
            component_parent[index] = component_parent[component_parent[index]]
            index = component_parent[index]
        return index

    def component_union(left: int, right: int) -> None:
        left_root, right_root = component_find(left), component_find(right)
        if left_root != right_root:
            component_parent[right_root] = left_root

    for left_index, left in enumerate(components):
        for right_index in range(left_index + 1, len(components)):
            right = components[right_index]
            smaller, other = (left, right) if len(left) <= len(right) else (right, left)
            near = sum(
                min(
                    math.hypot(
                        geometry[item][0] - geometry[candidate][0],
                        geometry[item][1] - geometry[candidate][1],
                    )
                    for candidate in other
                ) <= version_match_distance_m
                for item in smaller
            )
            if near / len(smaller) >= version_match_fraction:
                component_union(left_index, right_index)

    family_component_indexes: dict[int, set[int]] = defaultdict(set)
    for index in range(len(components)):
        family_component_indexes[component_find(index)].add(index)

    family_rows = []
    for component_indexes in family_component_indexes.values():
        members = set().union(*(components[index] for index in component_indexes))
        family_visits = set().union(*(geometry_visits[key] for key in members))
        years = set().union(*(geometry_years[key] for key in members))
        fine_records = sum(
            records for (visit, key), records in fine_pair_records.items() if key in members
        )
        linked_coarse_records = sum(coarse_visit_records[visit] for visit in family_visits)
        xs = [geometry[key][0] for key in members]
        ys = [geometry[key][1] for key in members]
        family_rows.append({
            "visits": family_visits,
            "geometries": members,
            "component_indexes": component_indexes,
            "first_year": min(years),
            "last_year": max(years),
            "year_count": len(years),
            "fine_record_count": fine_records,
            "linked_coarse_record_count": linked_coarse_records,
            "record_count": fine_records + linked_coarse_records,
            "extent_m": math.hypot(max(xs) - min(xs), max(ys) - min(ys)),
        })
    family_rows.sort(
        key=lambda row: (-len(row["visits"]), -int(row["record_count"]), sorted(row["geometries"]))
    )

    geometry_to_family: dict[str, int] = {}
    visit_to_family: dict[str, int] = {}
    for family_id, family in enumerate(family_rows, 1):
        family["family_id"] = family_id
        for geometry_key in family["geometries"]:
            geometry_to_family[geometry_key] = family_id
        for visit in family["visits"]:
            existing = visit_to_family.get(visit)
            if existing is not None and existing != family_id:
                raise ValueError(f"Bezoek {visit} valt in meerdere routefamilies")
            visit_to_family[visit] = family_id

    coarse_only_visits = set(coarse_visit_records) - set(visits)
    return {
        "family_count": len(family_rows),
        "component_count": len(components),
        "fine_geometry_count": len(geometry),
        "fine_visit_count": len(visits),
        "coarse_only_visit_count": len(coarse_only_visits),
        "coarse_only_record_count": sum(coarse_visit_records[visit] for visit in coarse_only_visits),
        "families": family_rows,
        "geometry_to_family": geometry_to_family,
        "visit_to_family": visit_to_family,
    }


def reconstruct_reptile_route_families(
    rows: Iterable[dict[str, object]],
    *,
    small_to_anchor: dict[str, str],
    historical_area_m2: float = 2_000.0,
    coarse_area_m2: float = 900_000.0,
    maximum_route_link_m: float = 2_000.0,
    minimum_shared_dates: int = 10,
) -> dict[str, object]:
    """Koppel historische trajectvlakken en latere exacte locaties.

    Alleen historische geometrieën die op dezelfde kalenderdag zijn gebruikt
    én hoogstens twee kilometer uiteen liggen vormen samen één routefamilie.
    Daarmee wordt een gedeeld tijdstip van ruimtelijk verschillende routes niet
    ten onrechte als één bezoek behandeld.
    """
    geometry: dict[str, tuple[float, float, float]] = {}
    geometry_years: dict[str, set[int]] = defaultdict(set)
    geometry_dates: dict[str, set[str]] = defaultdict(set)
    geometry_records: dict[str, int] = defaultdict(int)
    for row in rows:
        key = str(row["geometry"])
        area = float(row["area"])
        geometry[key] = (float(row["x"]), float(row["y"]), area)
        geometry_years[key].add(int(row["year"]))
        geometry_dates[key].add(str(row["date"]))
        geometry_records[key] += int(row["records"])

    anchors = {
        key for key, (_, _, area) in geometry.items()
        if historical_area_m2 <= area < coarse_area_m2
    }
    parent = {key: key for key in anchors}

    def find(key: str) -> str:
        while parent[key] != key:
            parent[key] = parent[parent[key]]
            key = parent[key]
        return key

    def union(left: str, right: str) -> None:
        left_root, right_root = find(left), find(right)
        if left_root != right_root:
            parent[right_root] = left_root

    ordered = sorted(anchors)
    for index, left in enumerate(ordered):
        for right in ordered[index + 1:]:
            if len(geometry_dates[left] & geometry_dates[right]) < minimum_shared_dates:
                continue
            distance = math.hypot(
                geometry[left][0] - geometry[right][0],
                geometry[left][1] - geometry[right][1],
            )
            if distance <= maximum_route_link_m:
                union(left, right)

    groups: dict[str, set[str]] = defaultdict(set)
    for key in anchors:
        groups[find(key)].add(key)
    family_rows: list[dict[str, object]] = []
    for members in groups.values():
        xs = [geometry[key][0] for key in members]
        ys = [geometry[key][1] for key in members]
        years = set().union(*(geometry_years[key] for key in members))
        family_rows.append({
            "anchor_geometries": members,
            "first_year": min(years),
            "last_year": max(years),
            "year_count": len(years),
            "extent_m": math.hypot(max(xs) - min(xs), max(ys) - min(ys)),
        })
    family_rows.sort(key=lambda row: (row["first_year"], sorted(row["anchor_geometries"])))

    geometry_to_family: dict[str, int] = {}
    for family_id, family in enumerate(family_rows, 1):
        family["family_id"] = family_id
        for key in family["anchor_geometries"]:
            geometry_to_family[key] = family_id
    for small, anchor in small_to_anchor.items():
        if small in geometry and anchor in geometry_to_family:
            geometry_to_family[small] = geometry_to_family[anchor]

    for family in family_rows:
        family_id = int(family["family_id"])
        members = {key for key, value in geometry_to_family.items() if value == family_id}
        years = set().union(*(geometry_years[key] for key in members))
        xs = [geometry[key][0] for key in members]
        ys = [geometry[key][1] for key in members]
        family["geometries"] = members
        family["first_year"] = min(years)
        family["last_year"] = max(years)
        family["year_count"] = len(years)
        family["record_count"] = sum(geometry_records[key] for key in members)
        family["extent_m"] = math.hypot(max(xs) - min(xs), max(ys) - min(ys))

    return {
        "family_count": len(family_rows),
        "families": family_rows,
        "geometry_to_family": geometry_to_family,
        "historical_geometry_count": len(anchors),
        "exact_geometry_count": sum(
            area < historical_area_m2 for _, _, area in geometry.values()
        ),
    }


def reconstruct_amphibian_water_families(
    rows: Iterable[dict[str, object]],
    *,
    maximum_version_distance_m: float = 30.0,
) -> dict[str, object]:
    """Koppel alleen nabije, niet gelijktijdig gebruikte watergeometrieën.

    De afstandsregel is bewust conservatief. Zodra twee geometrieën in
    hetzelfde jaar zijn gebruikt, blijven zij afzonderlijke wateren.
    """
    geometry: dict[str, tuple[float, float, float]] = {}
    years: dict[str, set[int]] = defaultdict(set)
    records: dict[str, int] = defaultdict(int)
    for row in rows:
        key = str(row["geometry"])
        geometry[key] = (float(row["x"]), float(row["y"]), float(row["area"]))
        years[key].add(int(row["year"]))
        records[key] += int(row["records"])

    parent = {key: key for key in geometry}

    def find(key: str) -> str:
        while parent[key] != key:
            parent[key] = parent[parent[key]]
            key = parent[key]
        return key

    def component_years(root: str) -> set[int]:
        return set().union(*(years[key] for key in geometry if find(key) == root))

    candidates: list[tuple[float, str, str]] = []
    ordered = sorted(geometry)
    for index, left in enumerate(ordered):
        for right in ordered[index + 1:]:
            if years[left] & years[right]:
                continue
            distance = math.hypot(
                geometry[left][0] - geometry[right][0],
                geometry[left][1] - geometry[right][1],
            )
            if distance <= maximum_version_distance_m:
                candidates.append((distance, left, right))
    for _, left, right in sorted(candidates):
        left_root, right_root = find(left), find(right)
        if left_root == right_root:
            continue
        if component_years(left_root) & component_years(right_root):
            continue
        parent[right_root] = left_root

    grouped: dict[str, set[str]] = defaultdict(set)
    for key in geometry:
        grouped[find(key)].add(key)
    families: list[dict[str, object]] = []
    for members in grouped.values():
        family_years = set().union(*(years[key] for key in members))
        xs = [geometry[key][0] for key in members]
        ys = [geometry[key][1] for key in members]
        families.append({
            "geometries": members,
            "first_year": min(family_years),
            "last_year": max(family_years),
            "year_count": len(family_years),
            "record_count": sum(records[key] for key in members),
            "extent_m": math.hypot(max(xs) - min(xs), max(ys) - min(ys)),
        })
    families.sort(key=lambda row: (-int(row["record_count"]), sorted(row["geometries"])))
    geometry_to_family: dict[str, int] = {}
    for family_id, family in enumerate(families, 1):
        family["family_id"] = family_id
        for key in family["geometries"]:
            geometry_to_family[key] = family_id
    return {
        "family_count": len(families),
        "families": families,
        "geometry_to_family": geometry_to_family,
        "geometry": geometry,
        "years": years,
        "records": records,
    }


def amphibian_analysis_taxon(source_taxon: str) -> str:
    """Normaliseer uitsluitend de twee bronlabels voor Bastaardkikker."""
    if source_taxon == "Pelophylax kl. esculentus":
        return "Pelophylax esculentus synklepton"
    return source_taxon


def parse_amphibian_measurement(scale: str, raw_value: str) -> dict[str, int | str | None]:
    """Vertaal een RAVON-meetwaarde zonder klassen als telling te behandelen."""
    if scale == "exact aantal" and re.fullmatch(r"\d+", raw_value):
        value = int(raw_value)
        return {"meetwaarde_type": "exact", "aantal_exact": value,
                "ondergrens": value, "bovengrens": value,
                "presentieklasse": None}
    if scale == "presentieklasse (Ravon)":
        classes = {
            "1.0 - 10.0": (1, 1, 10),
            "11.0 - 100.0": (2, 11, 100),
            "minimaal 101.0": (3, 101, None),
        }
        if raw_value not in classes:
            raise ValueError(f"Onbekende RAVON-presentieklasse: {raw_value}")
        class_number, lower, upper = classes[raw_value]
        return {"meetwaarde_type": "presentieklasse", "aantal_exact": None,
                "ondergrens": lower, "bovengrens": upper,
                "presentieklasse": class_number}
    if scale == "minimum aantal":
        match = re.fullmatch(r"minimaal (\d+)", raw_value)
        if match:
            return {"meetwaarde_type": "minimum", "aantal_exact": None,
                    "ondergrens": int(match.group(1)), "bovengrens": None,
                    "presentieklasse": None}
    if scale == "geschat aantal":
        match = re.fullmatch(r"(\d+) - (\d+)", raw_value)
        if match:
            return {"meetwaarde_type": "schatting", "aantal_exact": None,
                    "ondergrens": int(match.group(1)),
                    "bovengrens": int(match.group(2)),
                    "presentieklasse": None}
        if re.fullmatch(r"\d+", raw_value):
            value = int(raw_value)
            return {"meetwaarde_type": "schatting", "aantal_exact": None,
                    "ondergrens": value, "bovengrens": value,
                    "presentieklasse": None}
    raise ValueError(f"Niet ondersteunde amfibieënmeetwaarde: {scale!r} / {raw_value!r}")


def build_visit_taxon_matrix(
    *,
    visits: dict[str, int | None],
    target_taxa: Iterable[str],
    observations: dict[tuple[str, str], int],
    visit_target_taxa: dict[str, set[str]] | None = None,
) -> list[dict[str, object]]:
    """Maak een volledige bezoek-taxonmatrix voor bevestigde NEM-doelsoorten."""
    taxa = sorted(set(target_taxa))
    matrix: list[dict[str, object]] = []
    for visit in sorted(visits):
        applicable_taxa = taxa if visit_target_taxa is None else sorted(visit_target_taxa[visit])
        for taxon in applicable_taxa:
            count = observations.get((visit, taxon), 0)
            if count < 0:
                raise ValueError(f"Negatief aantal voor {visit}, {taxon}")
            matrix.append({
                "visit": visit,
                "taxon": taxon,
                "count": count,
                "status": "waargenomen" if count > 0 else "echte_nul",
            })
    unknown = set(observations) - {(visit, taxon) for visit in visits for taxon in taxa}
    if unknown:
        raise ValueError(f"Waarnemingen buiten bezoek-doelsoortbereik: {len(unknown)}")
    return matrix


def classify_bat_route(x_rd: float) -> dict[str, object]:
    """Koppel de twee ruimtelijk volledig gescheiden 17.208-deelreeksen."""
    if x_rd < 84_000:
        return {
            "routefamilie_id": 2,
            "methodevariant": "vleermus_fiets",
            "routecode": "vleerMUS_zuid",
        }
    return {
        "routefamilie_id": 1,
        "methodevariant": "nem_vtt_auto",
        "routecode": "NEM_VTT_noord",
    }


def bat_target_taxa(methodevariant: str) -> set[str]:
    """Geef het protocolspecifieke doelsoortenbereik per 17.208-deelreeks."""
    common = {
        "Pipistrellus pipistrellus", "Pipistrellus nathusii",
        "Eptesicus serotinus",
    }
    if methodevariant == "vleermus_fiets":
        return common
    if methodevariant == "nem_vtt_auto":
        return common | {"Nyctalus noctula"}
    raise ValueError(f"Onbekende vleermuismethodevariant: {methodevariant}")


def classify_bat_records(
    rows: Iterable[dict[str, object]],
) -> dict[str, dict[str, object]]:
    """Markeer de aantoonbare dubbele vleerMUS-aanlevering van 2019.

    De oude vleerMUS-regel heeft alleen 00:00:00. Als op dezelfde datum voor
    hetzelfde taxon en dezelfde geometrie een vttvleermus-regel met echte
    tijd staat, blijft die tijdspecifieke regel behouden. Meerdere tijdregels
    blijven afzonderlijke akoestische detecties.
    """
    materialized = [dict(row) for row in rows]
    timed_by_key: dict[tuple[str, str], list[tuple[str, float, float]]] = defaultdict(list)
    for row in materialized:
        route = classify_bat_route(float(row["x"]))
        start = str(row["start"])
        if (route["methodevariant"] == "vleermus_fiets"
                and start.startswith("2019-")
                and not start.endswith("00:00:00")):
            key = (str(row["visit_date"]), str(row["taxon"]))
            timed_by_key[key].append(
                (str(row["identity"]), float(row["x"]), float(row.get("y", 0.0)))
            )

    selection: dict[str, dict[str, object]] = {}
    for row in materialized:
        identity = str(row["identity"])
        route = classify_bat_route(float(row["x"]))
        start = str(row["start"])
        key = (str(row["visit_date"]), str(row["taxon"]))
        duplicate_targets = sorted(
            (
                (math.hypot(float(row["x"]) - candidate_x,
                            float(row.get("y", 0.0)) - candidate_y), candidate_identity)
                for candidate_identity, candidate_x, candidate_y in timed_by_key.get(key, ())
                if math.hypot(float(row["x"]) - candidate_x,
                              float(row.get("y", 0.0)) - candidate_y) <= 1.5
            ),
            key=lambda item: (item[0], item[1]),
        )
        suppressed = (
            route["methodevariant"] == "vleermus_fiets"
            and start.startswith("2019-")
            and start.endswith("00:00:00")
            and bool(duplicate_targets)
        )
        if route["methodevariant"] == "nem_vtt_auto":
            source_system = "nem_vtt"
        elif start.startswith("2019-") and not start.endswith("00:00:00"):
            source_system = "vttvleermus"
        else:
            source_system = "vleermus"
        selection[identity] = {
            **route,
            "bronsysteem": source_system,
            "selectiestatus": (
                "dubbele_aanlevering_onderdrukt" if suppressed else "opgenomen"
            ),
            "canonieke_identiteit": duplicate_targets[0][1] if suppressed else identity,
            "doelrelatie": (
                "doelsoort"
                if str(row["taxon"]) in bat_target_taxa(str(route["methodevariant"]))
                else "bijvangst"
            ),
        }
    return selection

GENERAL_SOURCE_PROTOCOLS = {"102.004", "102.006", "104.000", "105.000"}
BYCATCH_COMBINATIONS = {
    ("03.201", "Nachtvlinders"),
    ("14.204", "Zoogdieren (overig)"),
    ("17.204", "Vleermuizen"),
}
MIXED_COMBINATIONS = {
    ("04.006", "Weekdieren"),
    ("11.201", "Schimmels"),
    ("11.202", "Schimmels"),
    ("13.201", "Vissen"),
    ("13.202", "Amfibieën"),
    ("13.202", "Vissen"),
    ("17.202", "Vleermuizen"),
    ("17.204", "Zoogdieren (overig)"),
    ("17.208", "Vleermuizen"),
    ("17.209", "Zoogdieren (overig)"),
}
TARGET_DEPENDENT_COMBINATIONS = {
    ("10.002", "Amfibieën"),
    ("12.015", "Kranswieren, wieren en algen"),
    ("12.205", "Dagvlinders"),
    ("12.205", "Korstmossen"),
    ("12.205", "Kranswieren, wieren en algen"),
    ("12.205", "Libellen"),
    ("12.205", "Mossen"),
    ("12.205", "Sprinkhanen en krekels"),
    ("12.205", "Vaatplanten"),
    ("17.505", "Vleermuizen"),
    ("17.506", "Vleermuizen"),
}
DAZ_TARGET_SPECIES = {
    "Oryctolagus cuniculus", "Lepus europaeus", "Vulpes vulpes",
    "Capreolus capreolus", "Sciurus vulgaris", "Erinaceus europaeus",
    "Ondatra zibethicus",
}
RABBIT_TARGET_SPECIES = {"Oryctolagus cuniculus"}
HABSLAK_TARGET_SPECIES = {"Vertigo angustior", "Vertigo moulinsiana", "Anisus vorticulus"}
BOSPADDENSTOEL_TARGET_SPECIES = {
    "Amanita citrina", "Amanita fulva", "Amanita muscaria", "Amanita rubescens",
    "Auriscalpium vulgare", "Boletus edulis sl, incl. reticulatus, pinophilus",
    "Cantharellus cibarius", "Chroogomphus rutilus", "Clitocybe clavipes",
    "Clitocybe nebularis", "Clitocybe odora", "Clitocybe vibecina",
    "Coltricia perennis", "Cortinarius semisanguineus", "Crepidotus mollis",
    "Cystoderma amianthinum sl,", "Elaphocordyceps ophioglossoides",
    "Entoloma cetratum", "Geastrum fimbriatum", "Gymnopus androsaceus",
    "Gymnopus confluens", "Helvella lacunosa", "Hygrophoropsis aurantiaca",
    "Hypholoma capnoides", "Imleria badia", "Ischnoderma benzoinum",
    "Laccaria amethystina", "Lactarius chrysorrheus", "Lactarius hepaticus",
    "Lactarius necator", "Lactarius rufus", "Leotia lubrica", "Lepiota cristata",
    "Lepista flaccida", "Lepista nuda", "Leucocoprinus brebissonii",
    "Mycena clavicularis", "Mycena pura", "Mycena sanguinolenta",
    "Paxillus involutus", "Piptoporus betulinus", "Rhodocollybia maculata",
    "Russula claroflava", "Russula nigricans", "Russula ochroleuca",
    "Russula sardonia", "Suillus variegatus", "Trichaptum abietinum",
    "Tricholomopsis rutilans",
}
ZEEREEP_TARGET_SPECIES = {
    "Psathyrella ammophila", "Agaricus devoniensis", "Phallus hadriani",
    "Melanoleuca cinereifolia", "Hohenbuehelia culmicola", "Peziza ammophila",
}
BEEK_POLDERVIS_TARGET_SPECIES = {
    "Lampetra planeri", "Cottus gobio", "Cottus rhenanus", "Rhodeus amarus",
    "Misgurnus fossilis", "Cobitis taenia", "Cottus perifretum", "Lampetra fluviatilis",
}
N2000_AMFIBIE_TARGET_SPECIES = {"Triturus cristatus"}
N2000_VIS_TARGET_SPECIES = {
    "Lampetra planeri", "Cottus gobio", "Cottus rhenanus", "Cottus perifretum",
    "Rhodeus amarus", "Cobitis taenia", "Misgurnus fossilis",
}
ZOLDER_TARGET_SPECIES = {"Myotis emarginatus", "Plecotus austriacus"}
VTT_TARGET_SPECIES = {
    "Pipistrellus pipistrellus", "Pipistrellus nathusii",
    "Eptesicus serotinus", "Nyctalus noctula",
}
TARGET_SPECIES_BY_COMBINATION = {
    ("04.006", "Weekdieren"): HABSLAK_TARGET_SPECIES,
    ("11.201", "Schimmels"): BOSPADDENSTOEL_TARGET_SPECIES,
    ("11.202", "Schimmels"): ZEEREEP_TARGET_SPECIES,
    ("13.201", "Vissen"): BEEK_POLDERVIS_TARGET_SPECIES,
    ("13.202", "Amfibieën"): N2000_AMFIBIE_TARGET_SPECIES,
    ("13.202", "Vissen"): N2000_VIS_TARGET_SPECIES,
    ("17.202", "Vleermuizen"): ZOLDER_TARGET_SPECIES,
    ("17.204", "Zoogdieren (overig)"): DAZ_TARGET_SPECIES,
    ("17.208", "Vleermuizen"): VTT_TARGET_SPECIES,
    ("17.209", "Zoogdieren (overig)"): RABBIT_TARGET_SPECIES,
}
AMBIGUOUS_SPECIES_BY_COMBINATION = {
    ("17.202", "Vleermuizen"): {"Plecotus auritus/austriacus"},
}
TARGET_TYPES_BY_COMBINATION = {
    ("04.006", "Weekdieren"): "V,TV,TA",
    ("11.201", "Schimmels"): "V,TA",
    ("11.202", "Schimmels"): "V,TV",
    ("13.201", "Vissen"): "V,TV",
    ("13.202", "Amfibieën"): "V,TV,TA",
    ("13.202", "Vissen"): "V,TV,TA",
    ("17.202", "Vleermuizen"): "V,I,TA",
    ("17.204", "Zoogdieren (overig)"): "V,TA",
    ("17.208", "Vleermuizen"): "V,TA",
    ("17.209", "Zoogdieren (overig)"): "V,TA",
}
ADDITIONAL_SCOPE_SOURCE_URLS = {
    ("02.204", "Mossen"): (
        "https://www.verspreidingsatlas.nl/projecten/blwg/meetnetmossen.aspx",
    ),
    ("04.006", "Weekdieren"): (
        "https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/4-006-slakken-van-de-habitatrichtlijn/",
        "https://www.anemoon.org/projecten/natura2000/habslak-protocollen",
    ),
    ("11.201", "Schimmels"): (
        "https://www.netwerkecologischemonitoring.nl/wp-content/uploads/2017/08/Handleiding-paddenstoelen.pdf",
    ),
    ("11.202", "Schimmels"): (
        "https://www.mycologen.nl/onderzoek/meetnet/zeereep-concept/typische-soorten/",
    ),
    ("13.202", "Amfibieën"): (
        "https://www.ravon.nl/publicaties/handleiding-meetnet-amfibieen-en-vissen-in-natura-2000-gebieden/",
    ),
    ("13.202", "Vissen"): (
        "https://www.ravon.nl/publicaties/handleiding-meetnet-amfibieen-en-vissen-in-natura-2000-gebieden/",
    ),
    ("17.202", "Vleermuizen"): (
        "https://www.zoogdiervereniging.nl/sites/default/files/2023-05/Handleiding%20NEM%20Meetprogramma%20Zoldertellingen%202023.pdf",
    ),
    ("17.208", "Vleermuizen"): (
        "https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/17-208-vleermuistransecttelling-nem/",
        "https://www.zoogdiervereniging.nl/sites/default/files/2024-10/Handleiding%20Vleermuis%20transecttellingen.pdf",
        "https://www.zoogdiervereniging.nl/sites/default/files/2025-03/n2023009_algemene_praktische_handleiding_uitvoering_vleermus.pdf",
    ),
}


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


def classify_protocol_species(
    protocol_sleutel: str, scientific_name: str, soortgroep_raw: str | None = None
) -> dict[str, str]:
    if soortgroep_raw is None and protocol_sleutel in {"17.204", "17.209"}:
        soortgroep_raw = "Zoogdieren (overig)"
    key = (protocol_sleutel, soortgroep_raw or "")
    if key not in TARGET_SPECIES_BY_COMBINATION:
        raise ValueError(f"Geen soortclassificatie voor niet-gemengde combinatie {key}")
    if scientific_name in AMBIGUOUS_SPECIES_BY_COMBINATION.get(key, set()):
        return {"doelrelatie": "onbepaald", "toegestane_typen": "V"}
    targets = TARGET_SPECIES_BY_COMBINATION[key]
    if scientific_name in targets:
        return {"doelrelatie": "doelsoort", "toegestane_typen": TARGET_TYPES_BY_COMBINATION[key]}
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


def _species_condition(
    protocol_alias: str,
    group_alias: str,
    species_alias: str,
    mapping: dict[tuple[str, str], set[str]],
) -> str:
    clauses = []
    for (protocol, group), species in sorted(mapping.items()):
        names = ",".join(sql_text(value) for value in sorted(species))
        clauses.append(
            f"({protocol_alias}={sql_text(protocol)} AND {group_alias}={sql_text(group)} "
            f"AND {species_alias} IN ({names}))"
        )
    return " OR ".join(clauses) or "FALSE"


def _target_types_case(protocol_alias: str, group_alias: str) -> str:
    branches = " ".join(
        f"WHEN {protocol_alias}={sql_text(protocol)} AND {group_alias}={sql_text(group)} "
        f"THEN {sql_text(types)}"
        for (protocol, group), types in sorted(TARGET_TYPES_BY_COMBINATION.items())
    )
    return f"CASE {branches} ELSE 'V' END"


def _scope_sources_case(protocol_alias: str, group_alias: str) -> str:
    branches = " ".join(
        f"WHEN {protocol_alias}={sql_text(protocol)} AND {group_alias}={sql_text(group)} "
        "THEN JSON_ARRAY(" + ",".join(sql_text(url) for url in urls) + ")"
        for (protocol, group), urls in sorted(ADDITIONAL_SCOPE_SOURCE_URLS.items())
    )
    return f"CASE {branches} ELSE p.bron_urls END"


def protocol_scope_sql() -> str:
    general_codes = ",".join(sql_text(value) for value in sorted(GENERAL_SOURCE_PROTOCOLS))
    bycatch = _pair_condition("p.protocol_sleutel", "c.soortgroep_raw", BYCATCH_COMBINATIONS)
    mixed = _pair_condition("p.protocol_sleutel", "c.soortgroep_raw", MIXED_COMBINATIONS)
    dependent = _pair_condition("p.protocol_sleutel", "c.soortgroep_raw", TARGET_DEPENDENT_COMBINATIONS)
    protocol_types = _protocol_types_sql()
    target_species = _species_condition(
        "p.protocol_sleutel", "w.soortgroep_raw", "w.wetenschappelijke_naam",
        TARGET_SPECIES_BY_COMBINATION,
    )
    ambiguous_species = _species_condition(
        "p.protocol_sleutel", "w.soortgroep_raw", "w.wetenschappelijke_naam",
        AMBIGUOUS_SPECIES_BY_COMBINATION,
    )
    target_types = _target_types_case("p.protocol_sleutel", "w.soortgroep_raw")
    scope_sources = _scope_sources_case("p.protocol_sleutel", "c.soortgroep_raw")
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
            WHEN {dependent} AND p.protocol_sleutel='12.205'
              THEN 'De SNL-doelsoorten zijn afhankelijk van beheertype en protocolversie. Deze sleutels ontbreken in de NDFF-records; voorlopig is alleen positieve voorkomensinformatie (V) toegestaan.'
            WHEN {dependent}
              THEN 'De doelsoorten zijn project- of locatieafhankelijk en de noodzakelijke projectafbakening ontbreekt in de NDFF-records. Voorlopig is alleen positieve voorkomensinformatie (V) toegestaan.'
            ELSE 'De soortgroep valt binnen het inhoudelijke doelbereik van het protocol. De protocoltypen blijven voorlopig bruikbaar, met afzonderlijke beoordeling van leveringsgeschiktheid.' END,
       {scope_sources},
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
       CASE WHEN {ambiguous_species} THEN 'onbepaald'
            WHEN {target_species} THEN 'doelsoort' ELSE 'bijvangst' END,
       CASE WHEN {target_species} THEN {target_types} ELSE 'V' END,
       COUNT(*),
       CASE WHEN {ambiguous_species}
            THEN 'Het taxon omvat zowel een doelsoort als een niet-doelsoort en kan zonder nadere determinatie niet veilig worden ingedeeld; alleen V is toegestaan.'
            WHEN {target_species}
            THEN 'De soort behoort tot de officieel afgebakende doelsoorten van dit protocol; de protocoltypen blijven voorlopig toegestaan onder de algemene validatievoorbehouden.'
            ELSE 'De soort is binnen dit protocol bijvangst en ondersteunt alleen positieve voorkomensinformatie (V).' END,
       {sql_text(SCOPE_RULE_VERSION)},'2026-09-11'
FROM Meijendel.ndff_open_waarneming AS w
JOIN Meijendel.ndff_open_waarneming_protocol AS l
  ON l.waarneming_id=w.waarneming_id AND l.regelversie={sql_text(RULE_VERSION)}
JOIN Meijendel.ndff_protocol AS p ON p.protocol_id=l.protocol_id
WHERE {_pair_condition('p.protocol_sleutel', 'w.soortgroep_raw', MIXED_COMBINATIONS)}
GROUP BY p.protocol_id,p.protocol_sleutel,w.soortgroep_raw,w.wetenschappelijke_naam
ON DUPLICATE KEY UPDATE
  doelrelatie=VALUES(doelrelatie),toegestane_typen=VALUES(toegestane_typen),
  recordaantal_bij_classificatie=VALUES(recordaantal_bij_classificatie),
  reden=VALUES(reden),beoordeeld_op=VALUES(beoordeeld_op);
"""


def snl_overlap_sql() -> str:
    """Registreer mogelijke bronoverlap zonder afwezigheid als onafhankelijk te duiden."""
    return f"""
INSERT INTO Meijendel.ndff_snl_waarneming_context
  (waarneming_id,overlap_status,kandidaat_aantal,kandidaat_waarneming_ids,
   toets_methode,bewijsnotitie,regelversie,beoordeeld_op)
SELECT s.waarneming_id,
       CASE
         WHEN s.soort_key IS NULL OR s.periode_start IS NULL
              OR s.openbare_geometrie_sha256 IS NULL
           THEN 'onvoldoende_onderzocht'
         WHEN COUNT(o.waarneming_id)>0 THEN 'overlap_mogelijk'
         ELSE 'geen_overlap_gevonden'
       END,
       CASE WHEN s.soort_key IS NULL OR s.periode_start IS NULL
                 OR s.openbare_geometrie_sha256 IS NULL
            THEN 0 ELSE COUNT(o.waarneming_id) END,
       CASE WHEN s.soort_key IS NULL OR s.periode_start IS NULL
                 OR s.openbare_geometrie_sha256 IS NULL
                 OR COUNT(o.waarneming_id)=0
            THEN JSON_ARRAY() ELSE JSON_ARRAYAGG(o.waarneming_id) END,
       'Zelfde soort_key, exact periode_start en dezelfde openbare geometrie; vergelijking met alle records met een andere protocol_sleutel.',
       NULL,{sql_text(SNL_OVERLAP_RULE_VERSION)},CURRENT_TIMESTAMP(6)
FROM Meijendel.ndff_open_waarneming AS s
JOIN Meijendel.ndff_open_waarneming_protocol AS sl
  ON sl.waarneming_id=s.waarneming_id AND sl.regelversie={sql_text(RULE_VERSION)}
JOIN Meijendel.ndff_protocol AS sp
  ON sp.protocol_id=sl.protocol_id AND sp.protocol_sleutel='12.205'
LEFT JOIN (
  SELECT w.waarneming_id,w.soort_key,w.periode_start,w.openbare_geometrie_sha256
  FROM Meijendel.ndff_open_waarneming AS w
  JOIN Meijendel.ndff_open_waarneming_protocol AS l
    ON l.waarneming_id=w.waarneming_id AND l.regelversie={sql_text(RULE_VERSION)}
  JOIN Meijendel.ndff_protocol AS p
    ON p.protocol_id=l.protocol_id AND p.protocol_sleutel<>'12.205'
) AS o
  ON o.soort_key=s.soort_key
 AND o.periode_start=s.periode_start
 AND o.openbare_geometrie_sha256=s.openbare_geometrie_sha256
GROUP BY s.waarneming_id,s.soort_key,s.periode_start,s.openbare_geometrie_sha256
ON DUPLICATE KEY UPDATE
  overlap_status=IF(ndff_snl_waarneming_context.overlap_status='overlap_bevestigd',
                    ndff_snl_waarneming_context.overlap_status,VALUES(overlap_status)),
  kandidaat_aantal=IF(ndff_snl_waarneming_context.overlap_status='overlap_bevestigd',
                      ndff_snl_waarneming_context.kandidaat_aantal,VALUES(kandidaat_aantal)),
  kandidaat_waarneming_ids=IF(ndff_snl_waarneming_context.overlap_status='overlap_bevestigd',
                             ndff_snl_waarneming_context.kandidaat_waarneming_ids,
                             VALUES(kandidaat_waarneming_ids)),
  toets_methode=VALUES(toets_methode),
  beoordeeld_op=VALUES(beoordeeld_op);
"""


def public_pq_gate_sql() -> str:
    """Markeer uitsluitend herkenbare PQ-bronrecords; voer geen match afgeleid in."""
    return f"""
INSERT INTO Meijendel.ndff_open_pq_koppeling
  (waarneming_id,classificatie,ndff_bronrol,primaire_pq_bron,reden,
   regelversie,beoordeeld_op)
SELECT w.waarneming_id,
       CASE WHEN p.protocol_sleutel IN ('12.007','12.202')
            THEN 'niet_beoordeelbaar' ELSE 'niet_van_toepassing' END,
       CASE WHEN p.protocol_sleutel IN ('12.007','12.202')
            THEN 'secundaire_controlebron' ELSE 'niet_van_toepassing' END,
       CASE WHEN p.protocol_sleutel IN ('12.007','12.202')
            THEN 'provincie_zuid_holland' ELSE 'niet_van_toepassing' END,
       CASE WHEN p.protocol_sleutel IN ('12.007','12.202')
            THEN 'Herkenbaar NDFF-PQ-bronrecord: secundaire controlebron; niet als aanvulling op de gezaghebbende provinciale PQ-reeks tellen.'
            ELSE 'Geen PQ-bronindicator aangetroffen binnen deze beslisregel.' END,
       {sql_text(PUBLIC_PQ_RULE_VERSION)},CURRENT_TIMESTAMP(6)
FROM Meijendel.ndff_open_waarneming AS w
JOIN Meijendel.ndff_open_waarneming_protocol AS l
  ON l.waarneming_id=w.waarneming_id AND l.regelversie={sql_text(RULE_VERSION)}
JOIN Meijendel.ndff_protocol AS p ON p.protocol_id=l.protocol_id
ON DUPLICATE KEY UPDATE
  classificatie=VALUES(classificatie),ndff_bronrol=VALUES(ndff_bronrol),
  primaire_pq_bron=VALUES(primaire_pq_bron),reden=VALUES(reden),
  beoordeeld_op=VALUES(beoordeeld_op);
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


def bat_source_sql() -> str:
    """Lees uitsluitend de openbare, onvervaagde 17.208-bronregistraties."""
    return """
SELECT o.waarneming_id,o.identiteit_sha256,
       DATE_FORMAT(o.periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(o.periode_stop,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(DATE(o.periode_start),'%Y-%m-%d'),o.jaar,
       o.wetenschappelijke_naam,o.openbare_geometrie_sha256,
       ST_X(ST_Centroid(o.openbare_geometrie)),
       ST_Y(ST_Centroid(o.openbare_geometrie)),
       ST_Area(o.openbare_geometrie),o.aantal_raw,o.schaal_telmethode,
       o.determinatiemethode,o.bronhouder
FROM Meijendel.ndff_open_waarneming AS o
WHERE o.protocol LIKE '17.208%'
  AND o.soortgroep_raw='Vleermuizen'
  AND o.vervaagd=0
ORDER BY o.periode_start,o.openbare_geometrie_sha256,
         o.wetenschappelijke_naam,o.waarneming_id;
"""


def vlinder_source_sql() -> str:
    """Lees protocol 03.201 uitsluitend uit de openbare NDFF-bron."""
    return """
SELECT DATE_FORMAT(o.periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(o.periode_stop,'%Y-%m-%d %H:%i:%s'),o.jaar,
       o.openbare_geometrie_sha256,
       ST_X(ST_Centroid(o.openbare_geometrie)),
       ST_Y(ST_Centroid(o.openbare_geometrie)),
       ST_Area(o.openbare_geometrie),COUNT(*)
FROM Meijendel.ndff_open_waarneming o
WHERE o.protocol LIKE '03.201%'
  AND EXISTS (
    SELECT 1
    FROM Meijendel.ndff_open_waarneming doel
    WHERE doel.protocol LIKE '03.201%'
      AND doel.soortgroep_raw='Dagvlinders'
      AND doel.periode_start=o.periode_start
      AND doel.periode_stop=o.periode_stop
  )
GROUP BY o.periode_start,o.periode_stop,o.jaar,4,5,6,7
ORDER BY o.periode_start,o.periode_stop,4;
"""


def vlinder_observation_sql() -> str:
    return """
SELECT DATE_FORMAT(periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(periode_stop,'%Y-%m-%d %H:%i:%s'),
       wetenschappelijke_naam,SUM(CAST(aantal_raw AS UNSIGNED))
FROM Meijendel.ndff_open_waarneming
WHERE protocol LIKE '03.201%'
  AND soortgroep_raw='Dagvlinders'
  AND aantal_raw REGEXP '^[0-9]+$'
GROUP BY periode_start,periode_stop,wetenschappelijke_naam
ORDER BY periode_start,periode_stop,wetenschappelijke_naam;
"""


def vliesvleugel_source_sql() -> str:
    """Lees alleen geometrieën van bevestigde 03.201-vliesvleugelbezoeken."""
    return """
SELECT DATE_FORMAT(o.periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(o.periode_stop,'%Y-%m-%d %H:%i:%s'),o.jaar,
       o.openbare_geometrie_sha256,
       ST_X(ST_Centroid(o.openbare_geometrie)),
       ST_Y(ST_Centroid(o.openbare_geometrie)),
       ST_Area(o.openbare_geometrie),COUNT(*)
FROM Meijendel.ndff_open_waarneming o
WHERE o.protocol LIKE '03.201%'
  AND o.soortgroep_raw='Vliesvleugeligen'
  AND EXISTS (
    SELECT 1
    FROM Meijendel.ndff_open_waarneming doel
    WHERE doel.protocol LIKE '03.201%'
      AND doel.soortgroep_raw='Vliesvleugeligen'
      AND doel.periode_start=o.periode_start
      AND doel.periode_stop=o.periode_stop
  )
GROUP BY o.periode_start,o.periode_stop,o.jaar,4,5,6,7
ORDER BY o.periode_start,o.periode_stop,4;
"""


def vliesvleugel_observation_sql() -> str:
    return """
SELECT DATE_FORMAT(periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(periode_stop,'%Y-%m-%d %H:%i:%s'),
       wetenschappelijke_naam,SUM(CAST(aantal_raw AS UNSIGNED))
FROM Meijendel.ndff_open_waarneming
WHERE protocol LIKE '03.201%'
  AND soortgroep_raw='Vliesvleugeligen'
  AND aantal_raw REGEXP '^[0-9]+$'
GROUP BY periode_start,periode_stop,wetenschappelijke_naam
ORDER BY periode_start,periode_stop,wetenschappelijke_naam;
"""


def libel_source_sql() -> str:
    """Lees protocol 07.201 uitsluitend uit de openbare NDFF-bron."""
    return """
SELECT DATE_FORMAT(o.periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(o.periode_stop,'%Y-%m-%d %H:%i:%s'),o.jaar,
       o.openbare_geometrie_sha256,
       ST_X(ST_Centroid(o.openbare_geometrie)),
       ST_Y(ST_Centroid(o.openbare_geometrie)),
       ST_Area(o.openbare_geometrie),COUNT(*)
FROM Meijendel.ndff_open_waarneming o
WHERE o.protocol LIKE '07.201%'
  AND o.soortgroep_raw='Libellen'
GROUP BY o.periode_start,o.periode_stop,o.jaar,4,5,6,7
ORDER BY o.periode_start,o.periode_stop,4;
"""


def libel_observation_sql() -> str:
    return """
SELECT DATE_FORMAT(periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(periode_stop,'%Y-%m-%d %H:%i:%s'),
       wetenschappelijke_naam,SUM(CAST(aantal_raw AS UNSIGNED))
FROM Meijendel.ndff_open_waarneming
WHERE protocol LIKE '07.201%'
  AND soortgroep_raw='Libellen'
  AND aantal_raw REGEXP '^[0-9]+$'
GROUP BY periode_start,periode_stop,wetenschappelijke_naam
ORDER BY periode_start,periode_stop,wetenschappelijke_naam;
"""


def reptile_source_sql() -> str:
    """Lees het openbare 10.201-profiel per datum en geometrie."""
    return """
SELECT DATE_FORMAT(o.periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(o.periode_stop,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(DATE(o.periode_start),'%Y-%m-%d'),o.jaar,
       o.openbare_geometrie_sha256,
       ST_X(ST_Centroid(o.openbare_geometrie)),
       ST_Y(ST_Centroid(o.openbare_geometrie)),
       ST_Area(o.openbare_geometrie),COUNT(*)
FROM Meijendel.ndff_open_waarneming o
WHERE o.protocol LIKE '10.201%'
  AND o.soortgroep_raw='Reptielen'
GROUP BY o.periode_start,o.periode_stop,DATE(o.periode_start),o.jaar,5,6,7,8
ORDER BY DATE(o.periode_start),o.periode_start,5;
"""


def reptile_geometry_match_sql() -> str:
    """Koppel exacte locaties aan het beste historische trajectvlak."""
    return """
WITH geometrie AS (
  SELECT openbare_geometrie_sha256 AS geometrie_sha256,
         ANY_VALUE(openbare_geometrie) AS geometrie,
         ST_Area(ANY_VALUE(openbare_geometrie)) AS oppervlakte_m2
  FROM Meijendel.ndff_open_waarneming
  WHERE protocol LIKE '10.201%' AND soortgroep_raw='Reptielen'
  GROUP BY openbare_geometrie_sha256
), klein AS (
  SELECT * FROM geometrie WHERE oppervlakte_m2 < 2000
), anker AS (
  SELECT * FROM geometrie WHERE oppervlakte_m2 >= 2000 AND oppervlakte_m2 < 900000
), kandidaten AS (
  SELECT klein.geometrie_sha256 AS kleine_geometrie_sha256,
         anker.geometrie_sha256 AS anker_geometrie_sha256,
         ST_Intersects(klein.geometrie,anker.geometrie) AS raakt,
         ST_Area(anker.geometrie) AS anker_oppervlakte_m2,
         ST_Distance(ST_Centroid(klein.geometrie),ST_Centroid(anker.geometrie)) AS afstand_m,
         ROW_NUMBER() OVER (
           PARTITION BY klein.geometrie_sha256
           ORDER BY ST_Intersects(klein.geometrie,anker.geometrie) DESC,
             CASE WHEN ST_Intersects(klein.geometrie,anker.geometrie)
                  THEN ST_Area(anker.geometrie)
                  ELSE ST_Distance(ST_Centroid(klein.geometrie),ST_Centroid(anker.geometrie)) END,
             anker.geometrie_sha256
         ) AS rang
  FROM klein CROSS JOIN anker
)
SELECT kleine_geometrie_sha256,anker_geometrie_sha256
FROM kandidaten
WHERE rang=1 AND (raakt=1 OR afstand_m<=2000)
ORDER BY kleine_geometrie_sha256;
"""


def reptile_observation_sql() -> str:
    return """
SELECT DATE_FORMAT(periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(periode_stop,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(DATE(periode_start),'%Y-%m-%d'),
       openbare_geometrie_sha256,wetenschappelijke_naam,stadium,
       SUM(CAST(aantal_raw AS UNSIGNED))
FROM Meijendel.ndff_open_waarneming
WHERE protocol LIKE '10.201%'
  AND soortgroep_raw='Reptielen'
  AND aantal_raw REGEXP '^[0-9]+$'
GROUP BY periode_start,periode_stop,DATE(periode_start),
         openbare_geometrie_sha256,wetenschappelijke_naam,stadium
ORDER BY DATE(periode_start),periode_start,openbare_geometrie_sha256,
         wetenschappelijke_naam,stadium;
"""


def amphibian_source_sql() -> str:
    """Lees alleen onvervaagde openbare 01.201-waterregistraties."""
    return """
SELECT DATE_FORMAT(o.periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(o.periode_stop,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(DATE(o.periode_start),'%Y-%m-%d'),o.jaar,
       o.openbare_geometrie_sha256,
       ST_X(ST_Centroid(o.openbare_geometrie)),
       ST_Y(ST_Centroid(o.openbare_geometrie)),
       ST_Area(o.openbare_geometrie),COUNT(*)
FROM Meijendel.ndff_open_waarneming o
WHERE o.protocol LIKE '01.201%'
  AND o.soortgroep_raw='Amfibieën'
  AND o.vervaagd=0
GROUP BY o.periode_start,o.periode_stop,DATE(o.periode_start),o.jaar,5,6,7,8
ORDER BY o.periode_start,o.periode_stop,5;
"""


def amphibian_observation_sql() -> str:
    return """
SELECT DATE_FORMAT(periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(periode_stop,'%Y-%m-%d %H:%i:%s'),
       openbare_geometrie_sha256,wetenschappelijke_naam,
       COALESCE(stadium,''),schaal_telmethode,aantal_raw,COUNT(*)
FROM Meijendel.ndff_open_waarneming
WHERE protocol LIKE '01.201%'
  AND soortgroep_raw='Amfibieën'
  AND vervaagd=0
GROUP BY periode_start,periode_stop,openbare_geometrie_sha256,
         wetenschappelijke_naam,stadium,schaal_telmethode,aantal_raw
ORDER BY periode_start,periode_stop,openbare_geometrie_sha256,
         wetenschappelijke_naam,stadium,schaal_telmethode,aantal_raw;
"""


def amphibian_excluded_sql() -> str:
    """Controleer de bewust niet gereconstrueerde vervaagde jaarregels."""
    return """
SELECT COUNT(*),
       SUM(TIMESTAMPDIFF(HOUR,periode_start,periode_stop)>=8000),
       COUNT(DISTINCT wetenschappelijke_naam),
       MIN(wetenschappelijke_naam),MAX(wetenschappelijke_naam)
FROM Meijendel.ndff_open_waarneming
WHERE protocol LIKE '01.201%'
  AND soortgroep_raw='Amfibieën'
  AND vervaagd=1;
"""


def _batched_insert(table: str, columns: str, values: list[str], size: int = 1000) -> list[str]:
    return [
        f"INSERT INTO {table} ({columns}) VALUES " + ",".join(values[index:index + size]) + ";"
        for index in range(0, len(values), size)
    ]


def reconstruct_vlinders(
    mysql_client: Path,
    client_args: list[str],
    *,
    doelgroep: str = "Dagvlinders",
) -> dict[str, int]:
    """Bouw een openbare NEM-route-, bezoek- en doelsoortmatrix opnieuw op."""
    if doelgroep == "Dagvlinders":
        source_sql = vlinder_source_sql()
        observation_sql = vlinder_observation_sql()
        expected_source = (82_217, 3_126, 34)
        version = VLINDER_ROUTE_RULE_VERSION
        table_prefix = VLINDER_TABLE_PREFIX
        nulregel = "Niet gemeld binnen een bevestigd volledig NEM-dagvlinderbezoek; echte nul voor de doelsoort."
    elif doelgroep == "Vliesvleugeligen":
        source_sql = vliesvleugel_source_sql()
        observation_sql = vliesvleugel_observation_sql()
        expected_source = (1_535, 217, 6)
        version = VLIESVLEUGEL_ROUTE_RULE_VERSION
        table_prefix = VLIESVLEUGEL_TABLE_PREFIX
        nulregel = "Niet gemeld binnen een bevestigd NEM-vliesvleugelbezoek; echte nul voor het binnen deze deelreeks gevolgde taxon."
    elif doelgroep == "Libellen":
        source_sql = libel_source_sql()
        observation_sql = libel_observation_sql()
        expected_source = (3_280, 461, 29)
        version = LIBEL_ROUTE_RULE_VERSION
        table_prefix = LIBEL_TABLE_PREFIX
        nulregel = "Niet gemeld binnen het vastgestelde doelbereik van een bevestigd NEM-libellenbezoek; echte nul voor de doelsoort."
    else:
        raise ValueError(f"Onbekende NEM-routegroep: {doelgroep}")
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    source_output = run_mysql(mysql_client, query_args, source_sql, capture=True)
    route_rows: list[dict[str, object]] = []
    visits_meta: dict[str, tuple[str, str, int]] = {}
    visit_record_count: dict[str, int] = defaultdict(int)
    geometry_meta: dict[str, tuple[float, float, float]] = {}
    for line in source_output.splitlines():
        start, stop, year, geometry_key, x, y, area, records = line.split("\t")
        visit = f"{start}|{stop}"
        visits_meta[visit] = (start, stop, int(year))
        visit_record_count[visit] += int(records)
        geometry_meta[geometry_key] = (float(x), float(y), float(area))
        route_rows.append({
            "visit": visit, "geometry": geometry_key, "x": float(x), "y": float(y),
            "area": float(area), "year": int(year), "records": int(records),
        })
    if (sum(visit_record_count.values()), len(visits_meta)) != expected_source[:2]:
        raise ValueError(f"De NEM-bronselectie voor {doelgroep} wijkt af van het gecontroleerde profiel.")

    reconstruction = reconstruct_route_families(route_rows)
    observation_output = run_mysql(mysql_client, query_args, observation_sql, capture=True)
    observations: dict[tuple[str, str], int] = {}
    target_taxa: set[str] = set()
    visit_observed_taxa: dict[str, set[str]] = defaultdict(set)
    for line in observation_output.splitlines():
        start, stop, taxon, count = line.split("\t")
        visit = f"{start}|{stop}"
        target_taxa.add(taxon)
        visit_observed_taxa[visit].add(taxon)
        observations[(visit, taxon)] = int(count)
    if len(target_taxa) != expected_source[2]:
        raise ValueError(f"De doelsoortenlijst bevat niet exact {expected_source[2]} taxa voor {doelgroep}.")
    family_scope: dict[int, str] = {}
    visit_scope: dict[str, str] = {}
    visit_target_taxa: dict[str, set[str]] | None = None
    if doelgroep == "Libellen":
        family_taxa: dict[int, set[str]] = defaultdict(set)
        for visit, taxa_for_visit in visit_observed_taxa.items():
            family_id = reconstruction["visit_to_family"].get(visit)
            if family_id is not None:
                family_taxa[int(family_id)].update(taxa_for_visit)
        family_scope = {
            int(family["family_id"]): (
                "algemene_route"
                if len(family_taxa[int(family["family_id"])]) > 1
                else "onbepaald"
            )
            for family in reconstruction["families"]
        }
        visit_target_taxa = {}
        for visit, observed_taxa in visit_observed_taxa.items():
            family_id = reconstruction["visit_to_family"].get(visit)
            if family_id is not None:
                scope = family_scope[int(family_id)]
            else:
                scope = "algemene_route" if len(observed_taxa) > 1 else "onbepaald"
            visit_scope[visit] = scope
            visit_target_taxa[visit] = set(target_taxa) if scope == "algemene_route" else set(observed_taxa)
    matrix = build_visit_taxon_matrix(
        visits={visit: reconstruction["visit_to_family"].get(visit) for visit in visits_meta},
        target_taxa=target_taxa,
        observations=observations,
        visit_target_taxa=visit_target_taxa,
    )

    family_values: list[str] = []
    family_status: dict[int, str] = {}
    for family in reconstruction["families"]:
        family_id = int(family["family_id"])
        status = "handmatige_controle" if float(family["extent_m"]) > 3_000 else "waarschijnlijk"
        family_status[family_id] = status
        protocol_key = "07.201" if doelgroep == "Libellen" else "03.201"
        scope_sql = f",{sql_text(family_scope[family_id])}" if doelgroep == "Libellen" else ""
        family_values.append(
            f"({sql_text(version)},{family_id},{sql_text(protocol_key)},{sql_text(status)}{scope_sql},"
            f"{len(family['visits'])},{len(family['geometries'])},{len(family['component_indexes'])},"
            f"{int(family['record_count'])},{int(family['first_year'])},{int(family['last_year'])},"
            f"{int(family['year_count'])},{float(family['extent_m']):.3f})"
        )

    geometry_values: list[str] = []
    for geometry_key, family_id in sorted(reconstruction["geometry_to_family"].items()):
        x, y, area = geometry_meta[geometry_key]
        geometry_values.append(
            f"({sql_text(version)},{sql_text(geometry_key)},{family_id},"
            f"{x:.3f},{y:.3f},{area:.6f})"
        )

    visit_keys = {visit: hashlib.sha256(visit.encode("utf-8")).hexdigest() for visit in visits_meta}
    visit_values: list[str] = []
    for visit, (start, stop, year) in sorted(visits_meta.items()):
        family_id = reconstruction["visit_to_family"].get(visit)
        if family_id is None:
            status = "geen_route"
            family_sql = "NULL"
        else:
            status = "handmatige_controle" if family_status[int(family_id)] == "handmatige_controle" else "gereconstrueerd"
            family_sql = str(family_id)
        scope_sql = f",{sql_text(visit_scope[visit])}" if doelgroep == "Libellen" else ""
        visit_values.append(
            f"({sql_text(version)},{sql_text(visit_keys[visit])},"
            f"{sql_text(start)},{sql_text(stop)},{year},{family_sql},{sql_text(status)}{scope_sql},"
            f"{visit_record_count[visit]})"
        )

    matrix_values = [
        f"({sql_text(version)},{sql_text(visit_keys[str(row['visit'])])},"
        f"{sql_text(str(row['taxon']))},{int(row['count'])},{sql_text(str(row['status']))},"
        f"{sql_text(nulregel)})"
        for row in matrix
    ]
    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {table_prefix}_bezoek_taxon WHERE reconstructieversie={sql_text(version)};",
        f"DELETE FROM {table_prefix}_bezoek WHERE reconstructieversie={sql_text(version)};",
        f"DELETE FROM {table_prefix}_routegeometrie WHERE reconstructieversie={sql_text(version)};",
        f"DELETE FROM {table_prefix}_routefamilie WHERE reconstructieversie={sql_text(version)};",
    ]
    family_columns = "reconstructieversie,routefamilie_id,protocol_sleutel,reconstructiestatus"
    if doelgroep == "Libellen":
        family_columns += ",doelbereikstatus"
    family_columns += ",bezoekaantal,geometrieaantal,componentaantal,bronrecordaantal,eerste_jaar,laatste_jaar,jaaraantal,ruimtelijke_omvang_m"
    statements += _batched_insert(
        f"{table_prefix}_routefamilie",
        family_columns,
        family_values,
    )
    statements += _batched_insert(
        f"{table_prefix}_routegeometrie",
        "reconstructieversie,geometrie_sha256,routefamilie_id,centrum_x_rd,centrum_y_rd,oppervlakte_m2",
        geometry_values,
    )
    visit_columns = "reconstructieversie,bezoek_sleutel,periode_start,periode_stop,jaar,routefamilie_id,reconstructiestatus"
    if doelgroep == "Libellen":
        visit_columns += ",doelbereikstatus"
    visit_columns += ",bronrecordaantal"
    statements += _batched_insert(
        f"{table_prefix}_bezoek",
        visit_columns,
        visit_values,
    )
    statements += _batched_insert(
        f"{table_prefix}_bezoek_taxon",
        "reconstructieversie,bezoek_sleutel,wetenschappelijke_naam,aantal,waarnemingsstatus,nulregel",
        matrix_values,
    )
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))
    metrics = {
        "source_records": sum(visit_record_count.values()),
        "visits": len(visits_meta),
        "route_families": int(reconstruction["family_count"]),
        "route_components": int(reconstruction["component_count"]),
        "fine_geometries": int(reconstruction["fine_geometry_count"]),
        "fine_visits": int(reconstruction["fine_visit_count"]),
        "coarse_only_visits": int(reconstruction["coarse_only_visit_count"]),
        "coarse_only_records": int(reconstruction["coarse_only_record_count"]),
        "target_taxa": len(target_taxa),
        "matrix_rows": len(matrix),
        "positive_rows": sum(row["status"] == "waargenomen" for row in matrix),
        "zero_rows": sum(row["status"] == "echte_nul" for row in matrix),
    }
    if doelgroep == "Libellen":
        metrics.update({
            "general_route_families": sum(scope == "algemene_route" for scope in family_scope.values()),
            "unknown_route_families": sum(scope == "onbepaald" for scope in family_scope.values()),
            "general_visits": sum(scope == "algemene_route" for scope in visit_scope.values()),
            "unknown_scope_visits": sum(scope == "onbepaald" for scope in visit_scope.values()),
        })
    return metrics


def reconstruct_vliesvleugelen(mysql_client: Path, client_args: list[str]) -> dict[str, int]:
    """Bouw de zelfstandige 03.201-NEM-deelreeks voor vliesvleugeligen."""
    return reconstruct_vlinders(mysql_client, client_args, doelgroep="Vliesvleugeligen")


def reconstruct_libellen(mysql_client: Path, client_args: list[str]) -> dict[str, int]:
    """Bouw de openbare 07.201-NEM-libellenreeks op."""
    return reconstruct_vlinders(mysql_client, client_args, doelgroep="Libellen")


def reconstruct_reptielen(mysql_client: Path, client_args: list[str]) -> dict[str, int]:
    """Bouw openbare 10.201-routes, route-datumbezoeken en stadiumaantallen."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    source_output = run_mysql(mysql_client, query_args, reptile_source_sql(), capture=True)
    source_rows: list[dict[str, object]] = []
    geometry_meta: dict[str, tuple[float, float, float]] = {}
    for line in source_output.splitlines():
        start, stop, date, year, geometry_key, x, y, area, records = line.split("\t")
        row = {
            "start": start, "stop": stop, "date": date, "year": int(year),
            "geometry": geometry_key, "x": float(x), "y": float(y),
            "area": float(area), "records": int(records),
        }
        source_rows.append(row)
        geometry_meta[geometry_key] = (float(x), float(y), float(area))
    if sum(int(row["records"]) for row in source_rows) != 957:
        raise ValueError("De 10.201-bronselectie wijkt af van het gecontroleerde profiel.")

    match_output = run_mysql(
        mysql_client, query_args, reptile_geometry_match_sql(), capture=True
    )
    small_to_anchor = {
        small: anchor for small, anchor in
        (line.split("\t") for line in match_output.splitlines())
    }
    reconstruction = reconstruct_reptile_route_families(
        source_rows, small_to_anchor=small_to_anchor
    )
    geometry_to_family = reconstruction["geometry_to_family"]

    def native_visit(date: str, start: str, stop: str, geometry_key: str) -> str:
        family_id = geometry_to_family.get(geometry_key)
        if family_id is not None:
            return f"route:{family_id}|datum:{date}"
        return f"geen_route|{start}|{stop}|{geometry_key}"

    visit_meta: dict[str, dict[str, object]] = {}
    for row in source_rows:
        visit = native_visit(
            str(row["date"]), str(row["start"]), str(row["stop"]),
            str(row["geometry"]),
        )
        meta = visit_meta.setdefault(visit, {
            "date": str(row["date"]), "start": str(row["start"]),
            "stop": str(row["stop"]), "year": int(row["year"]),
            "family_id": geometry_to_family.get(str(row["geometry"])),
            "records": 0,
        })
        meta["start"] = min(str(meta["start"]), str(row["start"]))
        meta["stop"] = max(str(meta["stop"]), str(row["stop"]))
        meta["records"] = int(meta["records"]) + int(row["records"])

    observation_output = run_mysql(
        mysql_client, query_args, reptile_observation_sql(), capture=True
    )
    stage_counts: dict[tuple[str, str, str], int] = defaultdict(int)
    target_taxa: set[str] = set()
    for line in observation_output.splitlines():
        start, stop, date, geometry_key, taxon, stage, count = line.split("\t")
        visit = native_visit(date, start, stop, geometry_key)
        target_taxa.add(taxon)
        stage_counts[(visit, taxon, stage)] += int(count)
    expected_taxa = {"Lacerta agilis", "Anguis fragilis"}
    if target_taxa != expected_taxa:
        raise ValueError(f"Onverwacht doelsoortenbereik voor 10.201: {sorted(target_taxa)}")

    family_visits: dict[int, set[str]] = defaultdict(set)
    for visit, meta in visit_meta.items():
        family_id = meta["family_id"]
        if family_id is not None:
            family_visits[int(family_id)].add(visit)
    family_values: list[str] = []
    family_status: dict[int, str] = {}
    for family in reconstruction["families"]:
        family_id = int(family["family_id"])
        status = "handmatige_controle" if float(family["extent_m"]) > 3_000 else "waarschijnlijk"
        family_status[family_id] = status
        family_values.append(
            f"({sql_text(REPTILE_ROUTE_RULE_VERSION)},{family_id},'10.201',"
            f"{sql_text(status)},{len(family_visits[family_id])},"
            f"{len(family['geometries'])},{int(family['record_count'])},"
            f"{int(family['first_year'])},{int(family['last_year'])},"
            f"{int(family['year_count'])},{float(family['extent_m']):.3f})"
        )

    geometry_values: list[str] = []
    for geometry_key, family_id in sorted(geometry_to_family.items()):
        x, y, area = geometry_meta[geometry_key]
        role = "historisch_traject" if area >= 2_000 else "exacte_locatie"
        anchor = small_to_anchor.get(geometry_key)
        geometry_values.append(
            f"({sql_text(REPTILE_ROUTE_RULE_VERSION)},{sql_text(geometry_key)},"
            f"{family_id},{sql_text(role)},{sql_text(anchor)},"
            f"{x:.3f},{y:.3f},{area:.6f})"
        )

    visit_keys = {
        visit: hashlib.sha256(visit.encode("utf-8")).hexdigest()
        for visit in visit_meta
    }
    visit_values: list[str] = []
    for visit, meta in sorted(visit_meta.items()):
        family_id = meta["family_id"]
        if family_id is None:
            family_sql, status = "NULL", "geen_route"
        else:
            family_sql = str(family_id)
            status = (
                "handmatige_controle"
                if family_status[int(family_id)] == "handmatige_controle"
                else "gereconstrueerd"
            )
        visit_values.append(
            f"({sql_text(REPTILE_ROUTE_RULE_VERSION)},{sql_text(visit_keys[visit])},"
            f"{sql_text(str(meta['date']))},{sql_text(str(meta['start']))},"
            f"{sql_text(str(meta['stop']))},{int(meta['year'])},{family_sql},"
            f"{sql_text(status)},'alleen_positieve_bezoeken','niet_afleidbaar',"
            f"{int(meta['records'])})"
        )

    matrix_values: list[str] = []
    for visit in sorted(visit_meta):
        for taxon in sorted(target_taxa):
            counts = {
                stage: stage_counts.get((visit, taxon, stage), 0)
                for stage in ("adult", "subadult", "juveniel")
            }
            unknown = sum(
                count for (item_visit, item_taxon, stage), count in stage_counts.items()
                if item_visit == visit and item_taxon == taxon
                and stage not in counts
            )
            total = sum(counts.values()) + unknown
            if total:
                status = "waargenomen"
                rule = "Positief resultaat binnen een gereconstrueerd 10.201-routebezoek."
            elif taxon == "Anguis fragilis" and sum(
                stage_counts.get((visit, "Lacerta agilis", stage), 0)
                for stage in ("adult", "subadult", "juveniel")
            ) > 0:
                status = "echte_nul"
                rule = "Niet gemeld tijdens een bevestigd reptielenbezoek met een andere reptielsoort; echte nul binnen het protocolbereik."
            else:
                continue
            matrix_values.append(
                f"({sql_text(REPTILE_ROUTE_RULE_VERSION)},{sql_text(visit_keys[visit])},"
                f"{sql_text(taxon)},{total},{counts['adult']},{counts['subadult']},"
                f"{counts['juveniel']},{unknown},{sql_text(status)},{sql_text(rule)})"
            )

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {REPTILE_TABLE_PREFIX}_bezoek_taxon WHERE reconstructieversie={sql_text(REPTILE_ROUTE_RULE_VERSION)};",
        f"DELETE FROM {REPTILE_TABLE_PREFIX}_bezoek WHERE reconstructieversie={sql_text(REPTILE_ROUTE_RULE_VERSION)};",
        f"DELETE FROM {REPTILE_TABLE_PREFIX}_routegeometrie WHERE reconstructieversie={sql_text(REPTILE_ROUTE_RULE_VERSION)};",
        f"DELETE FROM {REPTILE_TABLE_PREFIX}_routefamilie WHERE reconstructieversie={sql_text(REPTILE_ROUTE_RULE_VERSION)};",
    ]
    statements += _batched_insert(
        f"{REPTILE_TABLE_PREFIX}_routefamilie",
        "reconstructieversie,routefamilie_id,protocol_sleutel,reconstructiestatus,bezoekaantal,geometrieaantal,bronrecordaantal,eerste_jaar,laatste_jaar,jaaraantal,ruimtelijke_omvang_m",
        family_values,
    )
    statements += _batched_insert(
        f"{REPTILE_TABLE_PREFIX}_routegeometrie",
        "reconstructieversie,geometrie_sha256,routefamilie_id,geometrierol,anker_geometrie_sha256,centrum_x_rd,centrum_y_rd,oppervlakte_m2",
        geometry_values,
    )
    statements += _batched_insert(
        f"{REPTILE_TABLE_PREFIX}_bezoek",
        "reconstructieversie,bezoek_sleutel,bezoekdatum,periode_start,periode_stop,jaar,routefamilie_id,reconstructiestatus,bezoekdekkingstatus,inspanningstatus,bronrecordaantal",
        visit_values,
    )
    statements += _batched_insert(
        f"{REPTILE_TABLE_PREFIX}_bezoek_taxon",
        "reconstructieversie,bezoek_sleutel,wetenschappelijke_naam,aantal,adult_aantal,subadult_aantal,juveniel_aantal,onbekend_stadium_aantal,waarnemingsstatus,nulregel",
        matrix_values,
    )
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))

    return {
        "source_records": sum(int(meta["records"]) for meta in visit_meta.values()),
        "visits": len(visit_meta),
        "route_families": int(reconstruction["family_count"]),
        "historical_geometries": int(reconstruction["historical_geometry_count"]),
        "exact_geometries": int(reconstruction["exact_geometry_count"]),
        "route_visits": sum(meta["family_id"] is not None for meta in visit_meta.values()),
        "coarse_only_visits": sum(meta["family_id"] is None for meta in visit_meta.values()),
        "coarse_only_records": sum(int(meta["records"]) for meta in visit_meta.values() if meta["family_id"] is None),
        "target_taxa": len(target_taxa),
        "matrix_rows": len(matrix_values),
        "positive_rows": sum("'waargenomen'" in value for value in matrix_values),
        "zero_rows": sum("'echte_nul'" in value for value in matrix_values),
        "adult_count": sum(count for (visit, taxon, stage), count in stage_counts.items() if stage == "adult"),
        "subadult_count": sum(count for (visit, taxon, stage), count in stage_counts.items() if stage == "subadult"),
        "juvenile_count": sum(count for (visit, taxon, stage), count in stage_counts.items() if stage == "juveniel"),
        "unknown_stage_count": sum(count for (visit, taxon, stage), count in stage_counts.items() if stage not in {"adult", "subadult", "juveniel"}),
    }


def reconstruct_amfibieen(mysql_client: Path, client_args: list[str]) -> dict[str, int]:
    """Bouw openbare 01.201-telgebied-, waterbezoek- en taxonlagen."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    source_output = run_mysql(
        mysql_client, query_args, amphibian_source_sql(), capture=True
    )
    source_rows: list[dict[str, object]] = []
    visit_meta: dict[str, dict[str, object]] = {}
    visit_geometry_records: dict[tuple[str, str], int] = defaultdict(int)
    for line in source_output.splitlines():
        start, stop, date, year, geometry_key, x, y, area, records = line.split("\t")
        visit = f"{start}|{stop}"
        source_rows.append({
            "geometry": geometry_key, "x": float(x), "y": float(y),
            "area": float(area), "year": int(year), "records": int(records),
        })
        visit_geometry_records[(visit, geometry_key)] += int(records)
        meta = visit_meta.setdefault(visit, {
            "start": start, "stop": stop, "date": date, "year": int(year),
            "records": 0,
        })
        meta["records"] = int(meta["records"]) + int(records)
    if sum(int(row["records"]) for row in source_rows) != 2_439:
        raise ValueError("De onvervaagde 01.201-bronselectie wijkt af van het gecontroleerde profiel.")

    reconstruction = reconstruct_amphibian_water_families(source_rows)
    geometry_to_family = reconstruction["geometry_to_family"]
    water_visit_records: dict[tuple[str, int], int] = defaultdict(int)
    for (visit, geometry_key), records in visit_geometry_records.items():
        water_visit_records[(visit, int(geometry_to_family[geometry_key]))] += records

    observation_output = run_mysql(
        mysql_client, query_args, amphibian_observation_sql(), capture=True
    )
    components: dict[tuple[str, int, str], list[dict[str, object]]] = defaultdict(list)
    source_names: dict[tuple[str, int, str], set[str]] = defaultdict(set)
    stages: dict[tuple[str, int, str], set[str]] = defaultdict(set)
    analysis_taxa: set[str] = set()
    for line in observation_output.splitlines():
        (start, stop, geometry_key, source_taxon, stage, scale,
         raw_value, record_count) = line.split("\t")
        visit = f"{start}|{stop}"
        family_id = int(geometry_to_family[geometry_key])
        taxon = amphibian_analysis_taxon(source_taxon)
        analysis_taxa.add(taxon)
        key = (visit, family_id, taxon)
        measurement = parse_amphibian_measurement(scale, raw_value)
        measurement["record_count"] = int(record_count)
        components[key].append(measurement)
        source_names[key].add(source_taxon)
        if stage:
            stages[key].add(stage)
    if len(analysis_taxa) != 7 or "Triturus cristatus" in analysis_taxa:
        raise ValueError(f"Onverwacht openbaar doelsoortenbereik voor 01.201: {sorted(analysis_taxa)}")
    excluded_output = run_mysql(
        mysql_client, query_args, amphibian_excluded_sql(), capture=True
    )
    excluded_parts = excluded_output.split("\t")
    if len(excluded_parts) != 5:
        raise ValueError("De controle van uitgesloten 01.201-regels is onvolledig.")
    blurred_records, year_aggregate_records, taxon_count = map(int, excluded_parts[:3])
    if (blurred_records, year_aggregate_records, taxon_count,
            excluded_parts[3], excluded_parts[4]) != (
            80, 80, 1, "Triturus cristatus", "Triturus cristatus"):
        raise ValueError("De vervaagde 01.201-jaaraggregaten wijken af van het gecontroleerde profiel.")

    visit_keys = {
        visit: hashlib.sha256(visit.encode("utf-8")).hexdigest()
        for visit in visit_meta
    }
    water_visit_keys = {
        (visit, family_id): hashlib.sha256(
            f"{visit}|water:{family_id}".encode("utf-8")
        ).hexdigest()
        for visit, family_id in water_visit_records
    }

    family_visits: dict[int, set[tuple[str, int]]] = defaultdict(set)
    family_records: dict[int, int] = defaultdict(int)
    for key, record_count in water_visit_records.items():
        _, family_id = key
        family_visits[family_id].add(key)
        family_records[family_id] += record_count
    family_values: list[str] = []
    family_status: dict[int, str] = {}
    for family in reconstruction["families"]:
        family_id = int(family["family_id"])
        status = "handmatige_controle" if float(family["extent_m"]) > 30 else "waarschijnlijk"
        family_status[family_id] = status
        family_values.append(
            f"({sql_text(AMPHIBIAN_WATER_RULE_VERSION)},{family_id},'01.201',"
            f"{sql_text(status)},{len(family_visits[family_id])},"
            f"{len(family['geometries'])},{family_records[family_id]},"
            f"{int(family['first_year'])},{int(family['last_year'])},"
            f"{int(family['year_count'])},{float(family['extent_m']):.3f})"
        )

    geometry_values: list[str] = []
    geometry_meta = reconstruction["geometry"]
    geometry_years = reconstruction["years"]
    for family in reconstruction["families"]:
        members = set(family["geometries"])
        anchor = min(members, key=lambda key: (min(geometry_years[key]), key))
        anchor_x, anchor_y, _ = geometry_meta[anchor]
        family_id = int(family["family_id"])
        for geometry_key in sorted(members):
            x, y, area = geometry_meta[geometry_key]
            role = "anker" if geometry_key == anchor else "versie"
            distance = math.hypot(x - anchor_x, y - anchor_y)
            geometry_values.append(
                f"({sql_text(AMPHIBIAN_WATER_RULE_VERSION)},{sql_text(geometry_key)},"
                f"{family_id},{sql_text(role)},{sql_text(anchor)},{distance:.3f},"
                f"{x:.3f},{y:.3f},{area:.6f},{min(geometry_years[geometry_key])},"
                f"{max(geometry_years[geometry_key])})"
            )

    visit_water_count: dict[str, int] = defaultdict(int)
    for visit, _ in water_visit_records:
        visit_water_count[visit] += 1
    visit_values: list[str] = []
    for visit, meta in sorted(visit_meta.items()):
        date_only = (
            str(meta["start"]).endswith("00:00:00")
            and str(meta["stop"]).endswith("00:00:00")
        )
        period_encoding = "datuminterval" if date_only else "tijdvenster"
        visit_values.append(
            f"({sql_text(AMPHIBIAN_WATER_RULE_VERSION)},{sql_text(visit_keys[visit])},"
            f"{sql_text(str(meta['date']))},{sql_text(str(meta['start']))},"
            f"{sql_text(str(meta['stop']))},{int(meta['year'])},{sql_text(period_encoding)},"
            f"'alleen_bezoeken_met_positieve_waterregistratie','niet_afleidbaar',"
            f"{visit_water_count[visit]},{int(meta['records'])})"
        )

    water_visit_values: list[str] = []
    for (visit, family_id), record_count in sorted(water_visit_records.items()):
        water_visit_values.append(
            f"({sql_text(AMPHIBIAN_WATER_RULE_VERSION)},"
            f"{sql_text(water_visit_keys[(visit, family_id)])},"
            f"{sql_text(visit_keys[visit])},{family_id},"
            f"'positieve_registratie_aanwezig',{record_count})"
        )

    matrix_values: list[str] = []
    matrix_metrics: dict[str, int] = defaultdict(int)
    for visit_family in sorted(water_visit_records):
        visit, family_id = visit_family
        water_visit_key = water_visit_keys[visit_family]
        for taxon in sorted(analysis_taxa):
            key = (visit, family_id, taxon)
            items = components.get(key, [])
            if not items:
                matrix_values.append(
                    f"({sql_text(AMPHIBIAN_WATER_RULE_VERSION)},{sql_text(water_visit_key)},"
                    f"{sql_text(taxon)},NULL,NULL,'niet_van_toepassing','echte_nul',"
                    f"NULL,'echte_nul',0,0,0,NULL,0,"
                    f"{sql_text('Niet gemeld in een aantoonbaar bezocht water binnen een volledig 01.201-amfibieënbezoek; echte protocolnul voor deze doelsoort.')})"
                )
                matrix_metrics["zero_rows"] += 1
                continue
            types = {str(item["meetwaarde_type"]) for item in items}
            measurement_type = next(iter(types)) if len(types) == 1 else "gemengd"
            exact_value = (
                sum(int(item["aantal_exact"]) * int(item["record_count"])
                    for item in items)
                if measurement_type == "exact" else None
            )
            lower = sum(
                int(item["ondergrens"]) * int(item["record_count"])
                for item in items if item["ondergrens"] is not None
            )
            upper = (
                sum(int(item["bovengrens"]) * int(item["record_count"])
                    for item in items)
                if all(item["bovengrens"] is not None for item in items)
                else None
            )
            presence_classes = [
                int(item["presentieklasse"]) for item in items
                if item["presentieklasse"] is not None
            ]
            highest_class = max(presence_classes) if presence_classes else None
            record_count = sum(int(item["record_count"]) for item in items)
            stage_values = sorted(stages[key])
            stage_status = "een_stadium" if len(stage_values) == 1 else "meerdere_stadia"
            matrix_values.append(
                f"({sql_text(AMPHIBIAN_WATER_RULE_VERSION)},{sql_text(water_visit_key)},"
                f"{sql_text(taxon)},{sql_text('; '.join(sorted(source_names[key])))},"
                f"{sql_text('; '.join(stage_values))},{sql_text(stage_status)},"
                f"'waargenomen',{sql_text('; '.join(sorted(types)))},{sql_text(measurement_type)},"
                f"{exact_value if exact_value is not None else 'NULL'},{lower},"
                f"{upper if upper is not None else 'NULL'},"
                f"{highest_class if highest_class is not None else 'NULL'},"
                f"{record_count},{sql_text('Positieve 01.201-registratie; telwaardetype en stadium blijven afzonderlijk herkenbaar.')})"
            )
            matrix_metrics["positive_rows"] += 1
            matrix_metrics[f"{measurement_type}_positive_rows"] += 1

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {AMPHIBIAN_TABLE_PREFIX}_waterbezoek_taxon WHERE reconstructieversie={sql_text(AMPHIBIAN_WATER_RULE_VERSION)};",
        f"DELETE FROM {AMPHIBIAN_TABLE_PREFIX}_waterbezoek WHERE reconstructieversie={sql_text(AMPHIBIAN_WATER_RULE_VERSION)};",
        f"DELETE FROM {AMPHIBIAN_TABLE_PREFIX}_bezoek WHERE reconstructieversie={sql_text(AMPHIBIAN_WATER_RULE_VERSION)};",
        f"DELETE FROM {AMPHIBIAN_TABLE_PREFIX}_watergeometrie WHERE reconstructieversie={sql_text(AMPHIBIAN_WATER_RULE_VERSION)};",
        f"DELETE FROM {AMPHIBIAN_TABLE_PREFIX}_waterfamilie WHERE reconstructieversie={sql_text(AMPHIBIAN_WATER_RULE_VERSION)};",
    ]
    statements += _batched_insert(
        f"{AMPHIBIAN_TABLE_PREFIX}_waterfamilie",
        "reconstructieversie,waterfamilie_id,protocol_sleutel,reconstructiestatus,waterbezoekaantal,geometrieaantal,bronrecordaantal,eerste_jaar,laatste_jaar,jaaraantal,ruimtelijke_omvang_m",
        family_values,
    )
    statements += _batched_insert(
        f"{AMPHIBIAN_TABLE_PREFIX}_watergeometrie",
        "reconstructieversie,geometrie_sha256,waterfamilie_id,geometrierol,anker_geometrie_sha256,afstand_anker_m,centrum_x_rd,centrum_y_rd,oppervlakte_m2,eerste_jaar,laatste_jaar",
        geometry_values,
    )
    statements += _batched_insert(
        f"{AMPHIBIAN_TABLE_PREFIX}_bezoek",
        "reconstructieversie,bezoek_sleutel,bezoekdatum,periode_start,periode_stop,jaar,periodecodering,bezoekdekkingstatus,inspanningstatus,waterbezoekaantal,bronrecordaantal",
        visit_values,
    )
    statements += _batched_insert(
        f"{AMPHIBIAN_TABLE_PREFIX}_waterbezoek",
        "reconstructieversie,waterbezoek_sleutel,bezoek_sleutel,waterfamilie_id,bevestigingsstatus,bronrecordaantal",
        water_visit_values,
    )
    statements += _batched_insert(
        f"{AMPHIBIAN_TABLE_PREFIX}_waterbezoek_taxon",
        "reconstructieversie,waterbezoek_sleutel,wetenschappelijke_naam,bron_taxonnamen,stadia_raw,stadium_status,waarnemingsstatus,meetwaardetypen_raw,meetwaarde_type,aantal_exact,ondergrens,bovengrens,hoogste_presentieklasse,bronrecordaantal,nulregel",
        matrix_values,
    )
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))

    return {
        "source_records": sum(int(meta["records"]) for meta in visit_meta.values()),
        "blurred_records": blurred_records,
        "year_aggregate_records": year_aggregate_records,
        "visits": len(visit_meta),
        "water_families": int(reconstruction["family_count"]),
        "water_geometries": len(geometry_to_family),
        "water_visits": len(water_visit_records),
        "analysis_taxa": len(analysis_taxa),
        "matrix_rows": len(matrix_values),
        "positive_rows": matrix_metrics["positive_rows"],
        "zero_rows": matrix_metrics["zero_rows"],
        "exact_positive_rows": matrix_metrics["exact_positive_rows"],
        "presentie_positive_rows": matrix_metrics["presentieklasse_positive_rows"],
        "minimum_positive_rows": matrix_metrics["minimum_positive_rows"],
        "estimate_positive_rows": matrix_metrics["schatting_positive_rows"],
        "mixed_positive_rows": matrix_metrics["gemengd_positive_rows"],
        "invalid_matrix_rows": 0,
        "positive_source_mismatch": 0,
        "kamsalamander_matrix_rows": 0,
        "secure_derived_tables": 0,
    }


def reconstruct_vleermuizen(
    mysql_client: Path,
    client_args: list[str],
) -> dict[str, int]:
    """Bouw de twee openbare 17.208-transectreeksen en hun detectiematrix."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    output = run_mysql(mysql_client, query_args, bat_source_sql(), capture=True)
    rows: list[dict[str, object]] = []
    by_identity: dict[str, dict[str, object]] = {}
    for line in output.splitlines():
        (observation_id, identity, start, stop, visit_date, year, taxon,
         geometry, x, y, area, raw_count, scale, determination, holder) = line.split("\t")
        if (raw_count != "1" or scale != "exact aantal"
                or determination != "gehoord met batdetector"
                or holder != "Zoogdiervereniging"):
            raise ValueError("Een 17.208-record wijkt af van het gecontroleerde detectorprofiel.")
        row = {
            "observation_id": int(observation_id), "identity": identity,
            "start": start, "stop": stop, "visit_date": visit_date,
            "year": int(year), "taxon": taxon, "geometry": geometry,
            "x": float(x), "y": float(y), "area": float(area),
        }
        rows.append(row)
        by_identity[identity] = row
    if len(rows) != 2_624 or len(by_identity) != len(rows):
        raise ValueError("De 17.208-bronselectie wijkt af van het gecontroleerde profiel.")

    selection = classify_bat_records(rows)
    retained = [
        row for row in rows
        if selection[str(row["identity"])]["selectiestatus"] == "opgenomen"
    ]
    suppressed = len(rows) - len(retained)
    if len(retained) != 2_551 or suppressed != 73:
        raise ValueError("De gecontroleerde dubbele vleerMUS-aanlevering is gewijzigd.")

    visit_rows: dict[tuple[int, str], list[dict[str, object]]] = defaultdict(list)
    family_rows: dict[int, list[dict[str, object]]] = defaultdict(list)
    geometry_rows: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in retained:
        route = classify_bat_route(float(row["x"]))
        family_id = int(route["routefamilie_id"])
        visit_rows[(family_id, str(row["visit_date"]))].append(row)
        family_rows[family_id].append(row)
        geometry_rows[str(row["geometry"])].append(row)
    if len(visit_rows) != 44 or set(family_rows) != {1, 2}:
        raise ValueError("De twee 17.208-routefamilies of hun bezoeken zijn gewijzigd.")

    visits_by_family_year: dict[tuple[int, int], list[str]] = defaultdict(list)
    for family_id, visit_date in visit_rows:
        visits_by_family_year[(family_id, int(visit_date[:4]))].append(visit_date)
    if any(
        len(dates) != (2 if family_id == 1 else 3)
        for (family_id, _year), dates in visits_by_family_year.items()
    ):
        raise ValueError("Een 17.208-routejaar mist of bevat een extra herhaling.")

    repeat_review: set[tuple[int, int]] = set()
    for (family_id, year), date_strings in visits_by_family_year.items():
        dates = sorted(date.fromisoformat(value) for value in date_strings)
        limit = 10 if family_id == 1 else 14
        if (dates[-1] - dates[0]).days > limit:
            repeat_review.add((family_id, year))

    visit_keys = {
        key: hashlib.sha256(
            f"{classify_bat_route(float(records[0]['x']))['routecode']}|{key[1]}".encode("utf-8")
        ).hexdigest()
        for key, records in visit_rows.items()
    }
    family_values: list[str] = []
    for family_id, records in sorted(family_rows.items()):
        route = classify_bat_route(float(records[0]["x"]))
        xs = [float(row["x"]) for row in records]
        ys = [float(row["y"]) for row in records]
        years = {int(row["year"]) for row in records}
        geometries = {str(row["geometry"]) for row in records}
        family_values.append(
            f"({sql_text(BAT_TRANSECT_RULE_VERSION)},{family_id},'17.208',"
            f"{sql_text(str(route['routecode']))},{sql_text(str(route['methodevariant']))},"
            f"{sql_text('auto' if family_id == 1 else 'fiets')},'waarschijnlijk',"
            f"{sum(key[0] == family_id for key in visit_rows)},{len(geometries)},"
            f"{len(records)},{min(years)},{max(years)},{len(years)},"
            f"{math.hypot(max(xs)-min(xs),max(ys)-min(ys)):.3f})"
        )

    geometry_values: list[str] = []
    for geometry, records in sorted(geometry_rows.items()):
        route = classify_bat_route(float(records[0]["x"]))
        years = [int(row["year"]) for row in records]
        geometry_values.append(
            f"({sql_text(BAT_TRANSECT_RULE_VERSION)},{sql_text(geometry)},"
            f"{int(route['routefamilie_id'])},'positieve_detectielocatie',"
            f"{float(records[0]['x']):.3f},{float(records[0]['y']):.3f},"
            f"{float(records[0]['area']):.6f},{min(years)},{max(years)})"
        )

    visit_values: list[str] = []
    visit_status: dict[tuple[int, str], dict[str, str]] = {}
    for (family_id, visit_date), records in sorted(visit_rows.items()):
        route = classify_bat_route(float(records[0]["x"]))
        month_day = visit_date[5:]
        end = "09-01" if family_id == 1 else "09-15"
        date_status = (
            "binnen_huidig_protocol" if "07-15" <= month_day <= end
            else "buiten_huidig_protocol"
        )
        repeat_status = (
            "handmatige_controle"
            if (family_id, int(visit_date[:4])) in repeat_review
            else "binnen_huidig_protocol"
        )
        reconstruction_status = (
            "handmatige_controle"
            if date_status == "buiten_huidig_protocol" or repeat_status == "handmatige_controle"
            else "gereconstrueerd"
        )
        visit_status[(family_id, visit_date)] = {
            "date": date_status, "repeat": repeat_status,
            "reconstruction": reconstruction_status,
        }
        round_number = sorted(
            visits_by_family_year[(family_id, int(visit_date[:4]))]
        ).index(visit_date) + 1
        visit_values.append(
            f"({sql_text(BAT_TRANSECT_RULE_VERSION)},"
            f"{sql_text(visit_keys[(family_id, visit_date)])},{sql_text(visit_date)},"
            f"{int(visit_date[:4])},{family_id},{round_number},"
            f"{sql_text(str(route['methodevariant']))},{sql_text(reconstruction_status)},"
            f"{sql_text(date_status)},{sql_text(repeat_status)},"
            "'alleen_bezoeken_met_positieve_detectie',"
            "'protocolmatig_gestandaardiseerd_metadata_ontbreekt',"
            f"{len(records)})"
        )

    selection_values: list[str] = []
    for row in rows:
        identity = str(row["identity"])
        info = selection[identity]
        canonical = by_identity[str(info["canonieke_identiteit"])]
        family_id = int(info["routefamilie_id"])
        visit_key = visit_keys[(family_id, str(row["visit_date"]))]
        reason = (
            "Dubbele vleerMUS-aanlevering uit 2019; tijdspecifieke vttvleermus-regel is canoniek."
            if info["selectiestatus"] == "dubbele_aanlevering_onderdrukt"
            else "Unieke akoestische detectie binnen de gereconstrueerde 17.208-deelreeks."
        )
        selection_values.append(
            f"({sql_text(BAT_TRANSECT_RULE_VERSION)},{int(row['observation_id'])},"
            f"{int(canonical['observation_id'])},{sql_text(visit_key)},{family_id},"
            f"{sql_text(str(info['bronsysteem']))},{sql_text(str(info['selectiestatus']))},"
            f"{sql_text(str(info['doelrelatie']))},{sql_text(reason)})"
        )

    observations: dict[tuple[int, str, str], int] = defaultdict(int)
    for row in retained:
        family_id = int(classify_bat_route(float(row["x"]))["routefamilie_id"])
        observations[(family_id, str(row["visit_date"]), str(row["taxon"]))] += 1
    matrix_values: list[str] = []
    matrix_metrics: dict[str, int] = defaultdict(int)
    for family_id, visit_date in sorted(visit_rows):
        method = str(classify_bat_route(
            float(visit_rows[(family_id, visit_date)][0]["x"])
        )["methodevariant"])
        targets = bat_target_taxa(method)
        visit_taxa = {
            taxon for (candidate_family, candidate_date, taxon) in observations
            if candidate_family == family_id and candidate_date == visit_date
        }
        for taxon in sorted(targets | visit_taxa):
            count = observations.get((family_id, visit_date, taxon), 0)
            relation = "doelsoort" if taxon in targets else "bijvangst"
            status = "waargenomen" if count else "echte_nul"
            rule = (
                "Niet gedetecteerd tijdens een bevestigd 17.208-routebezoek; echte protocolnul voor deze doelsoort."
                if not count else
                "Positieve akoestische detectie; detectieaantal is geen aantal individuele vleermuizen."
            )
            matrix_values.append(
                f"({sql_text(BAT_TRANSECT_RULE_VERSION)},"
                f"{sql_text(visit_keys[(family_id, visit_date)])},{sql_text(taxon)},"
                f"{sql_text(relation)},{count},{sql_text(status)},"
                f"'akoestische_detectie',{sql_text(rule)})"
            )
            matrix_metrics[f"{relation}_{status}_rows"] += 1
            if count:
                matrix_metrics[f"{relation}_records"] += count

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {BAT_TABLE_PREFIX}_bezoek_taxon WHERE reconstructieversie={sql_text(BAT_TRANSECT_RULE_VERSION)};",
        f"DELETE FROM {BAT_TABLE_PREFIX}_recordselectie WHERE reconstructieversie={sql_text(BAT_TRANSECT_RULE_VERSION)};",
        f"DELETE FROM {BAT_TABLE_PREFIX}_bezoek WHERE reconstructieversie={sql_text(BAT_TRANSECT_RULE_VERSION)};",
        f"DELETE FROM {BAT_TABLE_PREFIX}_routegeometrie WHERE reconstructieversie={sql_text(BAT_TRANSECT_RULE_VERSION)};",
        f"DELETE FROM {BAT_TABLE_PREFIX}_routefamilie WHERE reconstructieversie={sql_text(BAT_TRANSECT_RULE_VERSION)};",
    ]
    statements += _batched_insert(
        f"{BAT_TABLE_PREFIX}_routefamilie",
        "reconstructieversie,routefamilie_id,protocol_sleutel,routecode,methodevariant,vervoerswijze,reconstructiestatus,bezoekaantal,geometrieaantal,bronrecordaantal,eerste_jaar,laatste_jaar,jaaraantal,ruimtelijke_omvang_m",
        family_values,
    )
    statements += _batched_insert(
        f"{BAT_TABLE_PREFIX}_routegeometrie",
        "reconstructieversie,geometrie_sha256,routefamilie_id,geometrierol,centrum_x_rd,centrum_y_rd,oppervlakte_m2,eerste_jaar,laatste_jaar",
        geometry_values,
    )
    statements += _batched_insert(
        f"{BAT_TABLE_PREFIX}_bezoek",
        "reconstructieversie,bezoek_sleutel,bezoekdatum,jaar,routefamilie_id,ronde_binnen_jaar,methodevariant,reconstructiestatus,datumvenster_status,herhalingsvenster_status,bezoekdekkingstatus,inspanningstatus,bronrecordaantal",
        visit_values,
    )
    statements += _batched_insert(
        f"{BAT_TABLE_PREFIX}_recordselectie",
        "reconstructieversie,waarneming_id,canonieke_waarneming_id,bezoek_sleutel,routefamilie_id,bronsysteem,selectiestatus,doelrelatie,selectiereden",
        selection_values,
    )
    statements += _batched_insert(
        f"{BAT_TABLE_PREFIX}_bezoek_taxon",
        "reconstructieversie,bezoek_sleutel,wetenschappelijke_naam,doelrelatie,detectieaantal,waarnemingsstatus,meeteenheid,nulregel",
        matrix_values,
    )
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))

    return {
        "source_records": len(rows),
        "retained_records": len(retained),
        "suppressed_duplicates": suppressed,
        "route_families": len(family_rows),
        "route_geometries": len(geometry_rows),
        "visits": len(visit_rows),
        "vtt_visits": sum(key[0] == 1 for key in visit_rows),
        "vleermus_visits": sum(key[0] == 2 for key in visit_rows),
        "target_taxa": len(VTT_TARGET_SPECIES),
        "matrix_rows": len(matrix_values),
        "target_matrix_rows": matrix_metrics["doelsoort_waargenomen_rows"] + matrix_metrics["doelsoort_echte_nul_rows"],
        "target_positive_rows": matrix_metrics["doelsoort_waargenomen_rows"],
        "bycatch_positive_rows": matrix_metrics["bijvangst_waargenomen_rows"],
        "zero_rows": matrix_metrics["doelsoort_echte_nul_rows"],
        "target_records": matrix_metrics["doelsoort_records"],
        "bycatch_records": matrix_metrics["bijvangst_records"],
        "off_window_visits": sum(value["date"] == "buiten_huidig_protocol" for value in visit_status.values()),
        "repeat_window_review_visits": sum(value["repeat"] == "handmatige_controle" for value in visit_status.values()),
        "invalid_matrix_rows": 0,
        "duplicate_target_missing": 0,
        "secure_derived_tables": 0,
    }


def nem_subseries_validation_sql(
    table_prefix: str,
    rule_version: str,
    *,
    include_libel_scope: bool = False,
) -> str:
    version = sql_text(rule_version)
    base_name = table_prefix.split(".", 1)[1]
    legacy_tables = ",".join(sql_text(f"{base_name}_{suffix}") for suffix in (
        "routefamilie", "routegeometrie", "bezoek", "bezoek_taxon"
    ))
    scope_metrics = """
  ,'general_route_families',(SELECT COUNT(*) FROM {table_prefix}_routefamilie WHERE reconstructieversie={version} AND doelbereikstatus='algemene_route')
  ,'unknown_route_families',(SELECT COUNT(*) FROM {table_prefix}_routefamilie WHERE reconstructieversie={version} AND doelbereikstatus='onbepaald')
  ,'general_visits',(SELECT COUNT(*) FROM {table_prefix}_bezoek WHERE reconstructieversie={version} AND doelbereikstatus='algemene_route')
  ,'unknown_scope_visits',(SELECT COUNT(*) FROM {table_prefix}_bezoek WHERE reconstructieversie={version} AND doelbereikstatus='onbepaald')
  ,'source_payload_invalid',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '07.201%' AND soortgroep_raw='Libellen' AND (vervaagd<>0 OR stadium<>'imago (adult)' OR schaal_telmethode<>'exact aantal' OR aantal_raw NOT REGEXP '^[0-9]+$'))
  ,'positive_mismatch',(SELECT COUNT(*) FROM (SELECT SHA2(CONCAT(DATE_FORMAT(periode_start,'%Y-%m-%d %H:%i:%s'),'|',DATE_FORMAT(periode_stop,'%Y-%m-%d %H:%i:%s')),256) bezoek_sleutel,wetenschappelijke_naam,SUM(CAST(aantal_raw AS UNSIGNED)) aantal FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '07.201%' AND soortgroep_raw='Libellen' GROUP BY periode_start,periode_stop,wetenschappelijke_naam) bron LEFT JOIN {table_prefix}_bezoek_taxon t ON t.reconstructieversie={version} AND t.bezoek_sleutel=bron.bezoek_sleutel AND t.wetenschappelijke_naam=bron.wetenschappelijke_naam WHERE t.bezoek_sleutel IS NULL OR t.waarnemingsstatus<>'waargenomen' OR t.aantal<>bron.aantal)
  ,'zero_outside_general',(SELECT COUNT(*) FROM {table_prefix}_bezoek_taxon t JOIN {table_prefix}_bezoek b ON b.reconstructieversie=t.reconstructieversie AND b.bezoek_sleutel=t.bezoek_sleutel WHERE t.reconstructieversie={version} AND t.waarnemingsstatus='echte_nul' AND b.doelbereikstatus<>'algemene_route')
""".format(table_prefix=table_prefix, version=version) if include_libel_scope else ""
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT SUM(bronrecordaantal) FROM {table_prefix}_bezoek WHERE reconstructieversie={version}),
  'visits',(SELECT COUNT(*) FROM {table_prefix}_bezoek WHERE reconstructieversie={version}),
  'route_families',(SELECT COUNT(*) FROM {table_prefix}_routefamilie WHERE reconstructieversie={version}),
  'route_components',(SELECT SUM(componentaantal) FROM {table_prefix}_routefamilie WHERE reconstructieversie={version}),
  'fine_geometries',(SELECT COUNT(*) FROM {table_prefix}_routegeometrie WHERE reconstructieversie={version}),
  'fine_visits',(SELECT COUNT(*) FROM {table_prefix}_bezoek WHERE reconstructieversie={version} AND routefamilie_id IS NOT NULL),
  'coarse_only_visits',(SELECT COUNT(*) FROM {table_prefix}_bezoek WHERE reconstructieversie={version} AND reconstructiestatus='geen_route'),
  'coarse_only_records',(SELECT COALESCE(SUM(bronrecordaantal),0) FROM {table_prefix}_bezoek WHERE reconstructieversie={version} AND reconstructiestatus='geen_route'),
  'target_taxa',(SELECT COUNT(DISTINCT wetenschappelijke_naam) FROM {table_prefix}_bezoek_taxon WHERE reconstructieversie={version}),
  'matrix_rows',(SELECT COUNT(*) FROM {table_prefix}_bezoek_taxon WHERE reconstructieversie={version}),
  'positive_rows',(SELECT COUNT(*) FROM {table_prefix}_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen'),
  'zero_rows',(SELECT COUNT(*) FROM {table_prefix}_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='echte_nul'),
  'invalid_matrix_rows',(SELECT COUNT(*) FROM {table_prefix}_bezoek_taxon WHERE reconstructieversie={version} AND ((waarnemingsstatus='waargenomen' AND aantal=0) OR (waarnemingsstatus='echte_nul' AND aantal<>0))),
  'manual_review_visits',(SELECT COUNT(*) FROM {table_prefix}_bezoek WHERE reconstructieversie={version} AND reconstructiestatus='handmatige_controle'){scope_metrics},
  'legacy_secure_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({legacy_tables}))
);
"""


def vlinder_validation_sql() -> str:
    return nem_subseries_validation_sql(VLINDER_TABLE_PREFIX, VLINDER_ROUTE_RULE_VERSION)


def vliesvleugel_validation_sql() -> str:
    return nem_subseries_validation_sql(
        VLIESVLEUGEL_TABLE_PREFIX, VLIESVLEUGEL_ROUTE_RULE_VERSION
    )


def libel_validation_sql() -> str:
    return nem_subseries_validation_sql(
        LIBEL_TABLE_PREFIX, LIBEL_ROUTE_RULE_VERSION, include_libel_scope=True
    )


def reptile_validation_sql() -> str:
    version = sql_text(REPTILE_ROUTE_RULE_VERSION)
    legacy_tables = ",".join(sql_text(f"ndff_reptiel_{suffix}") for suffix in (
        "routefamilie", "routegeometrie", "bezoek", "bezoek_taxon"
    ))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT SUM(bronrecordaantal) FROM Meijendel.ndff_reptiel_bezoek WHERE reconstructieversie={version}),
  'visits',(SELECT COUNT(*) FROM Meijendel.ndff_reptiel_bezoek WHERE reconstructieversie={version}),
  'route_families',(SELECT COUNT(*) FROM Meijendel.ndff_reptiel_routefamilie WHERE reconstructieversie={version}),
  'historical_geometries',(SELECT COUNT(*) FROM Meijendel.ndff_reptiel_routegeometrie WHERE reconstructieversie={version} AND geometrierol='historisch_traject'),
  'exact_geometries',(SELECT COUNT(*) FROM Meijendel.ndff_reptiel_routegeometrie WHERE reconstructieversie={version} AND geometrierol='exacte_locatie'),
  'route_visits',(SELECT COUNT(*) FROM Meijendel.ndff_reptiel_bezoek WHERE reconstructieversie={version} AND routefamilie_id IS NOT NULL),
  'coarse_only_visits',(SELECT COUNT(*) FROM Meijendel.ndff_reptiel_bezoek WHERE reconstructieversie={version} AND reconstructiestatus='geen_route'),
  'coarse_only_records',(SELECT COALESCE(SUM(bronrecordaantal),0) FROM Meijendel.ndff_reptiel_bezoek WHERE reconstructieversie={version} AND reconstructiestatus='geen_route'),
  'target_taxa',(SELECT COUNT(DISTINCT wetenschappelijke_naam) FROM Meijendel.ndff_reptiel_bezoek_taxon WHERE reconstructieversie={version}),
  'matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_reptiel_bezoek_taxon WHERE reconstructieversie={version}),
  'positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_reptiel_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen'),
  'zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_reptiel_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='echte_nul'),
  'adult_count',(SELECT SUM(adult_aantal) FROM Meijendel.ndff_reptiel_bezoek_taxon WHERE reconstructieversie={version}),
  'subadult_count',(SELECT SUM(subadult_aantal) FROM Meijendel.ndff_reptiel_bezoek_taxon WHERE reconstructieversie={version}),
  'juvenile_count',(SELECT SUM(juveniel_aantal) FROM Meijendel.ndff_reptiel_bezoek_taxon WHERE reconstructieversie={version}),
  'unknown_stage_count',(SELECT SUM(onbekend_stadium_aantal) FROM Meijendel.ndff_reptiel_bezoek_taxon WHERE reconstructieversie={version}),
  'invalid_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_reptiel_bezoek_taxon WHERE reconstructieversie={version} AND (aantal<>adult_aantal+subadult_aantal+juveniel_aantal+onbekend_stadium_aantal OR (waarnemingsstatus='waargenomen' AND aantal=0) OR (waarnemingsstatus='echte_nul' AND aantal<>0))),
  'zandhagedis_zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_reptiel_bezoek_taxon WHERE reconstructieversie={version} AND wetenschappelijke_naam='Lacerta agilis' AND waarnemingsstatus='echte_nul'),
  'fully_negative_visits',(SELECT COUNT(*) FROM Meijendel.ndff_reptiel_bezoek b WHERE b.reconstructieversie={version} AND NOT EXISTS (SELECT 1 FROM Meijendel.ndff_reptiel_bezoek_taxon t WHERE t.reconstructieversie=b.reconstructieversie AND t.bezoek_sleutel=b.bezoek_sleutel AND t.waarnemingsstatus='waargenomen')),
  'invalid_effort_claims',(SELECT COUNT(*) FROM Meijendel.ndff_reptiel_bezoek WHERE reconstructieversie={version} AND (bezoekdekkingstatus<>'alleen_positieve_bezoeken' OR inspanningstatus<>'niet_afleidbaar')),
  'legacy_secure_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({legacy_tables}))
);
"""


def amphibian_validation_sql() -> str:
    version = sql_text(AMPHIBIAN_WATER_RULE_VERSION)
    legacy_tables = ",".join(sql_text(f"ndff_amfibie_{suffix}") for suffix in (
        "waterfamilie", "watergeometrie", "bezoek", "waterbezoek",
        "waterbezoek_taxon",
    ))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT SUM(bronrecordaantal) FROM Meijendel.ndff_amfibie_bezoek WHERE reconstructieversie={version}),
  'blurred_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '01.201%' AND soortgroep_raw='Amfibieën' AND vervaagd=1),
  'year_aggregate_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '01.201%' AND soortgroep_raw='Amfibieën' AND TIMESTAMPDIFF(HOUR,periode_start,periode_stop)>=8000),
  'visits',(SELECT COUNT(*) FROM Meijendel.ndff_amfibie_bezoek WHERE reconstructieversie={version}),
  'water_families',(SELECT COUNT(*) FROM Meijendel.ndff_amfibie_waterfamilie WHERE reconstructieversie={version}),
  'water_geometries',(SELECT COUNT(*) FROM Meijendel.ndff_amfibie_watergeometrie WHERE reconstructieversie={version}),
  'water_visits',(SELECT COUNT(*) FROM Meijendel.ndff_amfibie_waterbezoek WHERE reconstructieversie={version}),
  'analysis_taxa',(SELECT COUNT(DISTINCT wetenschappelijke_naam) FROM Meijendel.ndff_amfibie_waterbezoek_taxon WHERE reconstructieversie={version}),
  'matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_amfibie_waterbezoek_taxon WHERE reconstructieversie={version}),
  'positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_amfibie_waterbezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen'),
  'zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_amfibie_waterbezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='echte_nul'),
  'exact_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_amfibie_waterbezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen' AND meetwaarde_type='exact'),
  'presentie_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_amfibie_waterbezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen' AND meetwaarde_type='presentieklasse'),
  'minimum_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_amfibie_waterbezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen' AND meetwaarde_type='minimum'),
  'estimate_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_amfibie_waterbezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen' AND meetwaarde_type='schatting'),
  'mixed_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_amfibie_waterbezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen' AND meetwaarde_type='gemengd'),
  'invalid_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_amfibie_waterbezoek_taxon WHERE reconstructieversie={version} AND ((waarnemingsstatus='echte_nul' AND (meetwaarde_type<>'echte_nul' OR aantal_exact<>0 OR ondergrens<>0 OR bovengrens<>0 OR bronrecordaantal<>0)) OR (waarnemingsstatus='waargenomen' AND (meetwaarde_type='echte_nul' OR bronrecordaantal=0)))),
  'positive_source_mismatch',ABS((SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '01.201%' AND soortgroep_raw='Amfibieën' AND vervaagd=0)-(SELECT SUM(bronrecordaantal) FROM Meijendel.ndff_amfibie_waterbezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen')),
  'kamsalamander_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_amfibie_waterbezoek_taxon WHERE reconstructieversie={version} AND wetenschappelijke_naam='Triturus cristatus'),
  'secure_derived_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({legacy_tables}))
);
"""


def bat_validation_sql() -> str:
    version = sql_text(BAT_TRANSECT_RULE_VERSION)
    secure_tables = ",".join(sql_text(f"ndff_vleermuis_{suffix}") for suffix in (
        "recordselectie", "routefamilie", "routegeometrie", "bezoek", "bezoek_taxon",
    ))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_recordselectie WHERE reconstructieversie={version}),
  'retained_records',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_recordselectie WHERE reconstructieversie={version} AND selectiestatus='opgenomen'),
  'suppressed_duplicates',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_recordselectie WHERE reconstructieversie={version} AND selectiestatus='dubbele_aanlevering_onderdrukt'),
  'route_families',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_routefamilie WHERE reconstructieversie={version}),
  'route_geometries',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_routegeometrie WHERE reconstructieversie={version}),
  'visits',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_bezoek WHERE reconstructieversie={version}),
  'vtt_visits',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_bezoek WHERE reconstructieversie={version} AND methodevariant='nem_vtt_auto'),
  'vleermus_visits',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_bezoek WHERE reconstructieversie={version} AND methodevariant='vleermus_fiets'),
  'target_taxa',(SELECT COUNT(DISTINCT wetenschappelijke_naam) FROM Meijendel.ndff_vleermuis_bezoek_taxon WHERE reconstructieversie={version} AND doelrelatie='doelsoort'),
  'matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_bezoek_taxon WHERE reconstructieversie={version}),
  'target_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_bezoek_taxon WHERE reconstructieversie={version} AND doelrelatie='doelsoort'),
  'target_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_bezoek_taxon WHERE reconstructieversie={version} AND doelrelatie='doelsoort' AND waarnemingsstatus='waargenomen'),
  'bycatch_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_bezoek_taxon WHERE reconstructieversie={version} AND doelrelatie='bijvangst' AND waarnemingsstatus='waargenomen'),
  'zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='echte_nul'),
  'target_records',(SELECT COALESCE(SUM(detectieaantal),0) FROM Meijendel.ndff_vleermuis_bezoek_taxon WHERE reconstructieversie={version} AND doelrelatie='doelsoort' AND waarnemingsstatus='waargenomen'),
  'bycatch_records',(SELECT COALESCE(SUM(detectieaantal),0) FROM Meijendel.ndff_vleermuis_bezoek_taxon WHERE reconstructieversie={version} AND doelrelatie='bijvangst' AND waarnemingsstatus='waargenomen'),
  'off_window_visits',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_bezoek WHERE reconstructieversie={version} AND datumvenster_status='buiten_huidig_protocol'),
  'repeat_window_review_visits',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_bezoek WHERE reconstructieversie={version} AND herhalingsvenster_status='handmatige_controle'),
  'invalid_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_bezoek_taxon WHERE reconstructieversie={version} AND ((waarnemingsstatus='waargenomen' AND detectieaantal=0) OR (waarnemingsstatus='echte_nul' AND (detectieaantal<>0 OR doelrelatie<>'doelsoort')) OR meeteenheid<>'akoestische_detectie')),
  'duplicate_target_missing',(SELECT COUNT(*) FROM Meijendel.ndff_vleermuis_recordselectie d LEFT JOIN Meijendel.ndff_vleermuis_recordselectie c ON c.reconstructieversie=d.reconstructieversie AND c.waarneming_id=d.canonieke_waarneming_id AND c.selectiestatus='opgenomen' WHERE d.reconstructieversie={version} AND d.selectiestatus='dubbele_aanlevering_onderdrukt' AND c.waarneming_id IS NULL),
  'secure_derived_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({secure_tables}))
);
"""


def validate_vlinder_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != VLINDER_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (VLINDER_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(VLINDER_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != VLINDER_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(f"Vlinderreconstructie wijkt af van het vaste profiel: {differences}")


def validate_vliesvleugel_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != VLIESVLEUGEL_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (VLIESVLEUGEL_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(VLIESVLEUGEL_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != VLIESVLEUGEL_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(f"Vliesvleugelreconstructie wijkt af van het vaste profiel: {differences}")


def validate_libel_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != LIBEL_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (LIBEL_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(LIBEL_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != LIBEL_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(f"Libellenreconstructie wijkt af van het vaste profiel: {differences}")


def validate_reptile_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != REPTILE_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (REPTILE_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(REPTILE_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != REPTILE_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(f"Reptielenreconstructie wijkt af van het vaste profiel: {differences}")


def validate_amphibian_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != AMPHIBIAN_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (AMPHIBIAN_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(AMPHIBIAN_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != AMPHIBIAN_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(f"Amfibieënreconstructie wijkt af van het vaste profiel: {differences}")


def validate_bat_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != BAT_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (BAT_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(BAT_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != BAT_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(f"Vleermuisreconstructie wijkt af van het vaste profiel: {differences}")


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
SELECT 'dependent_combinations',COUNT(*) FROM Meijendel.ndff_protocol_soortgroep_geschiktheid WHERE regelversie={sql_text(SCOPE_RULE_VERSION)} AND doelrelatie='doelsoortafhankelijk';
SELECT 'mixed_species_missing',COUNT(*) FROM (
  SELECT DISTINCT l.protocol_id,w.soortgroep_raw,w.wetenschappelijke_naam
  FROM Meijendel.ndff_open_waarneming w
  JOIN Meijendel.ndff_open_waarneming_protocol l ON l.waarneming_id=w.waarneming_id AND l.regelversie={sql_text(RULE_VERSION)}
  JOIN Meijendel.ndff_protocol_soortgroep_geschiktheid g
    ON g.protocol_id=l.protocol_id AND g.soortgroep_raw=w.soortgroep_raw
   AND g.regelversie={sql_text(SCOPE_RULE_VERSION)} AND g.doelrelatie='gemengd'
  LEFT JOIN Meijendel.ndff_protocol_soort_geschiktheid s
    ON s.protocol_id=l.protocol_id AND s.soortgroep_raw=w.soortgroep_raw
   AND s.wetenschappelijke_naam=w.wetenschappelijke_naam AND s.regelversie={sql_text(SCOPE_RULE_VERSION)}
  WHERE s.protocol_soort_id IS NULL
) q;
SELECT 'secure_mixed_species_missing',COUNT(*) FROM (
  SELECT DISTINCT l.protocol_id,s.oorspronkelijke_ffv_soortgroep,s.wetenschappelijke_naam
  FROM Meijendel_ndff_secure.ndff_waarneming_register w
  JOIN Meijendel_ndff_secure.ndff_waarneming_protocol l
    ON l.waarneming_id=w.waarneming_id AND l.regelversie={sql_text(RULE_VERSION)}
  JOIN Meijendel_ndff_secure.ndff_soorten s ON s.ndff_soort_id=w.ndff_soort_id
  JOIN Meijendel.ndff_protocol_soortgroep_geschiktheid g
    ON g.protocol_id=l.protocol_id AND g.soortgroep_raw=s.oorspronkelijke_ffv_soortgroep
   AND g.regelversie={sql_text(SCOPE_RULE_VERSION)} AND g.doelrelatie='gemengd'
  LEFT JOIN Meijendel.ndff_protocol_soort_geschiktheid x
    ON x.protocol_id=l.protocol_id AND x.soortgroep_raw=s.oorspronkelijke_ffv_soortgroep
   AND x.wetenschappelijke_naam=s.wetenschappelijke_naam AND x.regelversie={sql_text(SCOPE_RULE_VERSION)}
  WHERE x.protocol_soort_id IS NULL
) q;
SELECT 'ambiguous_species',COUNT(*) FROM Meijendel.ndff_protocol_soort_geschiktheid WHERE regelversie={sql_text(SCOPE_RULE_VERSION)} AND doelrelatie='onbepaald';
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
SELECT 'snl_records',COUNT(*)
FROM Meijendel.ndff_open_waarneming_protocol l
JOIN Meijendel.ndff_protocol p ON p.protocol_id=l.protocol_id
WHERE l.regelversie={sql_text(RULE_VERSION)} AND p.protocol_sleutel='12.205';
SELECT 'snl_overlap_context',COUNT(*) FROM Meijendel.ndff_snl_waarneming_context
WHERE regelversie={sql_text(SNL_OVERLAP_RULE_VERSION)};
SELECT 'snl_overlap_bevestigd',COUNT(*) FROM Meijendel.ndff_snl_waarneming_context
WHERE regelversie={sql_text(SNL_OVERLAP_RULE_VERSION)} AND overlap_status='overlap_bevestigd';
SELECT 'snl_overlap_mogelijk',COUNT(*) FROM Meijendel.ndff_snl_waarneming_context
WHERE regelversie={sql_text(SNL_OVERLAP_RULE_VERSION)} AND overlap_status='overlap_mogelijk';
SELECT 'snl_geen_overlap_gevonden',COUNT(*) FROM Meijendel.ndff_snl_waarneming_context
WHERE regelversie={sql_text(SNL_OVERLAP_RULE_VERSION)} AND overlap_status='geen_overlap_gevonden';
SELECT 'snl_onvoldoende_onderzocht',COUNT(*) FROM Meijendel.ndff_snl_waarneming_context
WHERE regelversie={sql_text(SNL_OVERLAP_RULE_VERSION)} AND overlap_status='onvoldoende_onderzocht';
SELECT 'snl_overlap_ongeldig',COUNT(*) FROM Meijendel.ndff_snl_waarneming_context
WHERE regelversie={sql_text(SNL_OVERLAP_RULE_VERSION)} AND (
  (overlap_status IN ('overlap_bevestigd','overlap_mogelijk') AND kandidaat_aantal=0) OR
  (overlap_status IN ('geen_overlap_gevonden','onvoldoende_onderzocht') AND kandidaat_aantal<>0) OR
  (overlap_status='overlap_bevestigd' AND bewijsnotitie IS NULL)
);
SELECT 'open_pq_blocked',COUNT(*) FROM Meijendel.ndff_open_pq_koppeling
WHERE regelversie={sql_text(PUBLIC_PQ_RULE_VERSION)}
  AND classificatie='niet_beoordeelbaar'
  AND ndff_bronrol='secundaire_controlebron';
SELECT 'open_pq_not_applicable',COUNT(*) FROM Meijendel.ndff_open_pq_koppeling
WHERE regelversie={sql_text(PUBLIC_PQ_RULE_VERSION)}
  AND classificatie='niet_van_toepassing'
  AND ndff_bronrol='niet_van_toepassing';
SELECT 'open_pq_unassessed',COUNT(*) FROM Meijendel.ndff_open_waarneming w
LEFT JOIN Meijendel.ndff_open_pq_koppeling p
  ON p.waarneming_id=w.waarneming_id
 AND p.regelversie={sql_text(PUBLIC_PQ_RULE_VERSION)}
WHERE p.waarneming_id IS NULL;
"""


def validate_metrics(metrics: dict[str, int]) -> None:
    required = {
        "protocols", "uses", "mappings", "unmapped_open", "unmapped_secure",
        "open_records", "secure_records", "open_protocol_links", "secure_protocol_links",
        "open_loose_records", "open_loose_links", "secure_loose_records", "secure_loose_links",
        "blank_open_protocol", "blank_secure_protocol", "invalid_protocol_evidence",
        "spatial", "scope_combinations", "mixed_species", "dependent_combinations",
        "mixed_species_missing", "secure_mixed_species_missing", "ambiguous_species", "scope_missing",
        "decisions", "protocolbesluit_mismatch", "validatie_niet_geparkeerd",
        "snl_records", "snl_overlap_context", "snl_overlap_bevestigd",
        "snl_overlap_mogelijk", "snl_geen_overlap_gevonden",
        "snl_onvoldoende_onderzocht", "snl_overlap_ongeldig",
        "open_pq_blocked", "open_pq_not_applicable", "open_pq_unassessed",
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
    if (metrics["scope_combinations"] != 114 or metrics["mixed_species"] != 620
            or metrics["dependent_combinations"] != 11 or metrics["mixed_species_missing"]
            or metrics["secure_mixed_species_missing"]
            or metrics["ambiguous_species"] != 1 or metrics["scope_missing"]):
        raise ValueError("Protocol-doelbereik is niet volledig of niet op het verwachte gegevensprofiel gebaseerd.")
    if metrics["decisions"] == 0 or metrics["protocolbesluit_mismatch"]:
        raise ValueError("Analysebesluiten ontbreken of wijken af van de protocolgeschiktheid.")
    if metrics["validatie_niet_geparkeerd"]:
        raise ValueError("Leveringsgeschiktheid is ten onrechte als beoordeeld vastgelegd.")
    if metrics["snl_overlap_context"] != metrics["snl_records"]:
        raise ValueError("Niet ieder SNL-record heeft precies één actuele overlapstatus.")
    if (metrics["snl_overlap_bevestigd"] + metrics["snl_overlap_mogelijk"]
            + metrics["snl_geen_overlap_gevonden"]
            + metrics["snl_onvoldoende_onderzocht"] != metrics["snl_records"]):
        raise ValueError("De SNL-overlapstatussen sluiten niet aan op het recordaantal.")
    if metrics["snl_overlap_ongeldig"]:
        raise ValueError("Een SNL-overlapstatus mist kandidaten of bewijs.")
    if metrics["open_pq_blocked"] + metrics["open_pq_not_applicable"] != metrics["open_records"]:
        raise ValueError("De openbare PQ-poort dekt niet alle NDFF-records.")
    if metrics["open_pq_unassessed"]:
        raise ValueError("Een openbaar NDFF-record mist de actuele PQ-poort.")
    if metrics["open_pq_blocked"] != 97318 or metrics["open_pq_not_applicable"] != 713512:
        raise ValueError("De openbare PQ-poort wijkt af van het gecontroleerde Meijendel-profiel.")


def analysis_chain_validation_sql() -> str:
    """Alleen-lezen eindaudit van de vaste lokale NDFF-analyseketen."""
    protected_views = ",".join(sql_text(name) for name in (
        "v_ndff_canonieke_waarneming",
        "v_ndff_analyse_record",
        "v_ndff_verspreiding_plot_jaar_taxon",
        "v_ndff_trendkandidaat_plot_jaar_taxon",
        "v_ndff_gebruiksdekking_soortgroep_protocol",
        "v_ndff_soortenrijkdom_plot_jaar",
        "v_ndff_eerste_laatste_plot_taxon",
        "v_ndff_verspreidingsverandering_taxon_jaar",
        "v_ndff_dekking_intensiteit_plot_jaar_soortgroep",
    ))
    return f"""
SELECT JSON_OBJECT(
  'canonical_records',COUNT(*),
  'canonical_duplicates',COUNT(*)-COUNT(DISTINCT canonieke_identiteit_sha256),
  'only_public',SUM(representatie='alleen_openbaar'),
  'secure_replaces_public',SUM(representatie='secure_vervangt_open'),
  'only_secure',SUM(representatie='alleen_beveiligd'),
  'representation_invalid',SUM(representatie NOT IN ('alleen_openbaar','secure_vervangt_open','alleen_beveiligd'))
) FROM Meijendel_ndff_secure.v_ndff_canonieke_waarneming;
SELECT JSON_OBJECT(
  'analysis_records',COUNT(*),
  'analysis_duplicates',COUNT(*)-COUNT(DISTINCT canonieke_identiteit_sha256),
  'analysis_missing_fields',SUM(protocol_id IS NULL OR protocol_sleutel IS NULL OR protocol_kandidaattypen IS NULL OR protocol_kandidaattypen='' OR ruimtelijk_toelaatbaar IS NULL OR pq_status IS NULL OR snl_overlap_status IS NULL OR record_selectiestatus IS NULL OR gegevensgeschiktheid IS NULL OR kwaliteitsmelding IS NULL),
  'wrong_chain_version',SUM(analyseketenversie<>{sql_text(ANALYSIS_CHAIN_VERSION)}),
  'preliminarily_usable',SUM(record_selectiestatus='voorlopig_bruikbaar'),
  'overlap_warning',SUM(record_selectiestatus='voorlopig_met_overlapwaarschuwing'),
  'excluded_pq',SUM(record_selectiestatus='uitgesloten_pq'),
  'excluded_spatial',SUM(record_selectiestatus='uitgesloten_ruimtelijk'),
  'excluded_overlap',SUM(record_selectiestatus='uitgesloten_overlap'),
  'unvalidated_records',SUM(gegevensgeschiktheid<>'geschikt'),
  'secure_detail_records',SUM(bevat_beveiligde_details=1)
) FROM Meijendel_ndff_secure.v_ndff_analyse_record;
SELECT JSON_OBJECT(
  'distribution_rows',COUNT(*),
  'distribution_sources',COALESCE(SUM(bronrecords_ter_controle),0)
) FROM Meijendel_ndff_secure.v_ndff_verspreiding_plot_jaar_taxon;
SELECT JSON_OBJECT(
  'trend_rows',COUNT(*),
  'trend_sources',COALESCE(SUM(bronrecords_ter_controle),0),
  'trend_loose',SUM(protocol_sleutel='LOS')
) FROM Meijendel_ndff_secure.v_ndff_trendkandidaat_plot_jaar_taxon;
SELECT JSON_OBJECT(
  'usage_rows',COUNT(*),
  'usage_records',COALESCE(SUM(canonieke_records),0),
  'usage_mismatch',SUM(canonieke_records<>(voorlopig_bruikbaar+overlapwaarschuwing+uitgesloten_pq+uitgesloten_ruimtelijk+uitgesloten_overlap))
) FROM Meijendel_ndff_secure.v_ndff_gebruiksdekking_soortgroep_protocol;
SELECT JSON_OBJECT(
  'richness_rows',COUNT(*),
  'richness_signals',COALESCE(SUM(geregistreerde_taxa),0)
) FROM Meijendel_ndff_secure.v_ndff_soortenrijkdom_plot_jaar;
SELECT JSON_OBJECT(
  'first_last_rows',COUNT(*),
  'first_last_invalid',SUM(eerste_geregistreerde_jaar>laatste_geregistreerde_jaar)
) FROM Meijendel_ndff_secure.v_ndff_eerste_laatste_plot_taxon;
SELECT JSON_OBJECT(
  'change_rows',COUNT(*),
  'change_adjacent',SUM(aansluitend_jaar=1),
  'change_gap',SUM(aansluitend_jaar=0),
  'change_first',SUM(aansluitend_jaar IS NULL),
  'change_partition_mismatch',ABS(COUNT(*)-SUM(CASE WHEN aansluitend_jaar=1 OR aansluitend_jaar=0 OR aansluitend_jaar IS NULL THEN 1 ELSE 0 END))
) FROM Meijendel_ndff_secure.v_ndff_verspreidingsverandering_taxon_jaar;
SELECT JSON_OBJECT(
  'coverage_rows',COUNT(*),
  'coverage_sources',COALESCE(SUM(bronrecords_ter_controle),0),
  'coverage_split_mismatch',SUM(losse_bronrecords+protocol_bronrecords<>bronrecords_ter_controle)
) FROM Meijendel_ndff_secure.v_ndff_dekking_intensiteit_plot_jaar_soortgroep;
SELECT JSON_OBJECT(
  'analysis_view_grants',COUNT(*)
) FROM information_schema.TABLE_PRIVILEGES
WHERE LOWER(TABLE_SCHEMA)='meijendel_ndff_secure'
  AND TABLE_NAME IN ({protected_views})
  AND (GRANTEE LIKE '''ndff_shiny_read''@%' OR GRANTEE LIKE '''meijendel_read''@%');
"""


def parse_analysis_chain_output(output: str) -> dict[str, int]:
    """Voeg de compacte JSON-resultaten van de live-audit samen."""
    metrics: dict[str, int] = {}
    for line in output.splitlines():
        values = json.loads(line)
        overlap = set(metrics) & set(values)
        if overlap:
            raise ValueError(f"Dubbele auditmetrieken: {sorted(overlap)}")
        metrics.update({key: int(value) for key, value in values.items()})
    return metrics


def validate_analysis_chain_metrics(metrics: dict[str, int]) -> None:
    """Blokkeer gereedverklaring zodra het vaste controleprofiel afwijkt."""
    if set(metrics) != set(ANALYSIS_CHAIN_EXPECTED):
        difference = sorted(set(metrics) ^ set(ANALYSIS_CHAIN_EXPECTED))
        raise ValueError(f"Onvolledige analyseketenaudit: {difference}")
    differences = {
        key: (ANALYSIS_CHAIN_EXPECTED[key], metrics[key])
        for key in ANALYSIS_CHAIN_EXPECTED
        if metrics[key] != ANALYSIS_CHAIN_EXPECTED[key]
    }
    if differences:
        raise ValueError(f"Analyseketen wijkt af van het vaste profiel: {differences}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=Path, default=DEFAULT_SEED)
    parser.add_argument("--mysql-client", type=Path, default=Path("/usr/local/mysql/bin/mysql"))
    parser.add_argument("--login-path", default="meijendel_root")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3306)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--audit-live", action="store_true")
    mode.add_argument("--reconstruct-vlinders", action="store_true")
    mode.add_argument("--audit-vlinders", action="store_true")
    mode.add_argument("--reconstruct-vliesvleugelen", action="store_true")
    mode.add_argument("--audit-vliesvleugelen", action="store_true")
    mode.add_argument("--reconstruct-libellen", action="store_true")
    mode.add_argument("--audit-libellen", action="store_true")
    mode.add_argument("--reconstruct-reptielen", action="store_true")
    mode.add_argument("--audit-reptielen", action="store_true")
    mode.add_argument("--reconstruct-amfibieen", action="store_true")
    mode.add_argument("--audit-amfibieen", action="store_true")
    mode.add_argument("--reconstruct-vleermuizen", action="store_true")
    mode.add_argument("--audit-vleermuizen", action="store_true")
    args = parser.parse_args()

    if sha256_file(SOURCE_XLSX) != SOURCE_XLSX_SHA256 or sha256_file(SOURCE_DOCX) != SOURCE_DOCX_SHA256:
        raise ValueError("Een protocolbrondocument wijkt af van de beoordeelde versie.")
    rows = read_seed(args.seed)
    if args.dry_run:
        print(f"OK: {len(rows)} protocollen, bronhashes en invoercontract gevalideerd")
        return 0

    client_args = mysql_args(args.login_path, args.host, args.port)
    if args.reconstruct_vlinders:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_vlinders(args.mysql_client, client_args)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_vlinders:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            vlinder_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_vlinder_reconstruction(metrics)
        print(f"OK: lokale dagvlinderreconstructie {VLINDER_ROUTE_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_vliesvleugelen:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_vliesvleugelen(args.mysql_client, client_args)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_vliesvleugelen:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            vliesvleugel_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_vliesvleugel_reconstruction(metrics)
        print(f"OK: lokale vliesvleugelreconstructie {VLIESVLEUGEL_ROUTE_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_libellen:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_libellen(args.mysql_client, client_args)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_libellen:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            libel_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_libel_reconstruction(metrics)
        print(f"OK: lokale libellenreconstructie {LIBEL_ROUTE_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_reptielen:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_reptielen(args.mysql_client, client_args)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_reptielen:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            reptile_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_reptile_reconstruction(metrics)
        print(f"OK: lokale reptielenreconstructie {REPTILE_ROUTE_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_amfibieen:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_amfibieen(args.mysql_client, client_args)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_amfibieen:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            amphibian_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_amphibian_reconstruction(metrics)
        print(f"OK: lokale amfibieënreconstructie {AMPHIBIAN_WATER_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_vleermuizen:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_vleermuizen(args.mysql_client, client_args)
        validate_bat_reconstruction(metrics)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_vleermuizen:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            bat_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_bat_reconstruction(metrics)
        print(f"OK: lokale vleermuisreconstructie {BAT_TRANSECT_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.audit_live:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            analysis_chain_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_analysis_chain_metrics(metrics)
        print(f"OK: lokale NDFF-analyseketen {ANALYSIS_CHAIN_VERSION} gereed")
        print(output)
        return 0

    sql = "\n".join((SCHEMA.read_text(encoding="utf-8"), catalog_insert_sql(rows, SOURCE_XLSX_SHA256), mapping_sql(), record_protocol_link_sql(), spatial_sql(), protocol_scope_sql(), public_pq_gate_sql(), snl_overlap_sql(), restore_legacy_decisions_sql(), decisions_sql()))
    run_mysql(args.mysql_client, client_args, sql)
    output = run_mysql(args.mysql_client, client_args + ["--batch", "--raw", "--skip-column-names"], validation_sql(), capture=True)
    metrics = {key: int(value) for key, value in (line.split("\t", 1) for line in output.splitlines())}
    validate_metrics(metrics)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
