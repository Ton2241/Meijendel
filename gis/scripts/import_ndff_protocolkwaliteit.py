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
from collections import Counter, defaultdict
from datetime import date, datetime
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
MIXED_POSITIVE_PROTOCOLS = {"04.004", "07.001"}
POSITIVE_ONLY_SOURCE_PROTOCOLS = {
    "12.004", "12.006", "17.005", "17.006",
    "102.004", "102.006", "104.000", "105.000",
}
STRUCTURED_INCOMPLETE_PROTOCOLS = {
    "17.002": {"TV"},
    "102.002": {"I", "TV"},
    "102.005": {"I", "TV"},
    "102.007": {"I", "TV"},
}
VLINDER_ROUTE_RULE_VERSION = "ndff-vlinderroute-v1"
VLIESVLEUGEL_ROUTE_RULE_VERSION = "ndff-vliesvleugelroute-v1"
LIBEL_ROUTE_RULE_VERSION = "ndff-libellenroute-v1"
REPTILE_ROUTE_RULE_VERSION = "ndff-reptielroute-v1"
AMPHIBIAN_WATER_RULE_VERSION = "ndff-amfibiewater-v1"
BAT_TRANSECT_RULE_VERSION = "ndff-vleermuistransect-v1"
RABBIT_COUNT_RULE_VERSION = "ndff-konijnentelling-v1"
DAZ_BMP_RULE_VERSION = "ndff-daz-bmp-v1"
ZEEREEP_RULE_VERSION = "ndff-zeereep-v1"
BOSPADDENSTOEL_RULE_VERSION = "ndff-bospaddenstoel-v1"
HNS_RULE_VERSION = "ndff-hns-v1"
KORSTMOS_RULE_VERSION = "ndff-korstmos-v1"
MOS_RULE_VERSION = "ndff-mos-v1"
FLORBASE_RULE_VERSION = "ndff-florbase-v1"
FLORBASE_COMPLETENESS_THRESHOLD = 50
HABSLAK_RULE_VERSION = "ndff-habslak-v1"
HABSLAK_MINIMUM_SAMPLE_LOCATIONS = 15
BRAAKBAL_RULE_VERSION = "ndff-braakbal-v1"
BRAAKBAL_MINIMUM_PREY = 150
TUINTELLING_RULE_VERSION = "ndff-tuintelling-v1"
TUINTELLING_GEOMETRY_DISTANCE_M = 1.0
LIVEATLAS_RULE_VERSION = "ndff-liveatlas-v1"
KWARTIERTELLING_RULE_VERSION = "ndff-kwartiertelling-v1"
NACHTVLINDER_RULE_VERSION = "ndff-nachtvlinder-v1"
BOSPADDENSTOEL_VERSPREIDING_RULE_VERSION = "ndff-bospaddenstoel-verspreiding-v1"
POLDERVIS_RULE_VERSION = "ndff-poldervis-v1"
OTTER_BEVER_RULE_VERSION = "ndff-otter-bever-v1"
VLINDER_TABLE_PREFIX = "Meijendel.ndff_vlinder"
VLIESVLEUGEL_TABLE_PREFIX = "Meijendel.ndff_vliesvleugel"
LIBEL_TABLE_PREFIX = "Meijendel.ndff_libel"
REPTILE_TABLE_PREFIX = "Meijendel.ndff_reptiel"
AMPHIBIAN_TABLE_PREFIX = "Meijendel.ndff_amfibie"
BAT_TABLE_PREFIX = "Meijendel.ndff_vleermuis"
RABBIT_TABLE_PREFIX = "Meijendel.ndff_konijn"
DAZ_BMP_TABLE_PREFIX = "Meijendel.ndff_daz_bmp"
ZEEREEP_TABLE_PREFIX = "Meijendel.ndff_zeereep"
BOSPADDENSTOEL_TABLE_PREFIX = "Meijendel.ndff_bospaddenstoel"
HNS_TABLE_PREFIX = "Meijendel.ndff_hns"
KORSTMOS_TABLE_PREFIX = "Meijendel.ndff_korstmos"
MOS_TABLE_PREFIX = "Meijendel.ndff_mos"
FLORBASE_TABLE_PREFIX = "Meijendel.ndff_florbase"
HABSLAK_TABLE_PREFIX = "Meijendel.ndff_habslak"
BRAAKBAL_TABLE_PREFIX = "Meijendel.ndff_braakbal"
TUINTELLING_TABLE_PREFIX = "Meijendel.ndff_tuintelling"
LIVEATLAS_TABLE_PREFIX = "Meijendel.ndff_liveatlas"
KWARTIERTELLING_TABLE_PREFIX = "Meijendel.ndff_kwartiertelling"
NACHTVLINDER_TABLE_PREFIX = "Meijendel.ndff_nachtvlinder"
BOSPADDENSTOEL_VERSPREIDING_TABLE_PREFIX = (
    "Meijendel.ndff_bospaddenstoel_verspreiding"
)
POLDERVIS_TABLE_PREFIX = "Meijendel.ndff_poldervis"
OTTER_BEVER_TABLE_PREFIX = "Meijendel.ndff_otter_bever"
RESTERENDE_NEM_RECONSTRUCTION_EXPECTED = {
    "source_records": 633,
    "nachtvlinder_source_records": 596,
    "nachtvlinder_hokyears": 5,
    "nachtvlinder_taxon_rows": 84,
    "nachtvlinder_total_registered": 878,
    "bospaddenstoel_source_records": 14,
    "bospaddenstoel_visits": 2,
    "bospaddenstoel_taxon_rows": 14,
    "poldervis_source_records": 20,
    "poldervis_locations": 3,
    "poldervis_visits": 6,
    "poldervis_taxon_rows": 19,
    "poldervis_positive_rows": 17,
    "poldervis_missing_target_rows": 2,
    "poldervis_total_registered": 83,
    "otter_bever_source_records": 3,
    "otter_bever_hokyears": 1,
    "otter_bever_taxon_rows": 1,
    "otter_bever_total_registered": 3,
    "zero_rows": 0,
    "unlinked_source_records": 0,
    "secure_derived_tables": 0,
    "lmf_ndff_derived_tables": 0,
}
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
RABBIT_RECONSTRUCTION_EXPECTED = {
    "source_records": 5809,
    "target_records": 5095,
    "bycatch_records": 714,
    "target_count_sum": 43850,
    "bycatch_count_sum": 1049,
    "dates": 812,
    "grids": 11,
    "grid_date_taxon_rows": 5084,
    "spring_window_records": 2526,
    "autumn_window_records": 2789,
    "off_window_records": 494,
    "exact_duplicate_groups": 71,
    "exact_duplicate_members": 142,
    "multi_record_grid_date_taxon_groups": 725,
    "possible_daz_overlap_records": 11,
    "derived_zero_rows": 0,
    "multiple_plot_records": 5809,
    "secure_source_records": 0,
    "secure_derived_tables": 0,
}
DAZ_BMP_RECONSTRUCTION_EXPECTED = {
    "source_records": 10670,
    "unique_link_records": 3171,
    "multiple_link_records": 1026,
    "unlinked_records": 6473,
    "candidate_links": 5404,
    "confirmed_visits": 1475,
    "confirmed_plots": 49,
    "target_matrix_rows": 10325,
    "target_positive_rows": 2681,
    "true_zero_rows": 7552,
    "ambiguous_target_rows": 92,
    "target_count_sum": 12685,
    "bycatch_positive_rows": 49,
    "bycatch_positive_records": 50,
    "ambiguous_confirmed_visits": 159,
    "secure_source_records": 58,
    "secure_linked_to_public": 58,
    "secure_derived_tables": 0,
    "invalid_matrix_rows": 0,
}
ZEEREEP_RECONSTRUCTION_EXPECTED = {
    "source_records": 3738,
    "reconstructable_records": 3729,
    "excluded_blurred_records": 9,
    "kilometer_squares": 21,
    "visits": 161,
    "target_taxa": 6,
    "observed_target_rows": 224,
    "true_zero_rows": 742,
    "matrix_rows": 966,
    "target_source_records": 240,
    "off_season_visits": 61,
    "invalid_matrix_rows": 0,
    "legacy_secure_tables": 0,
}
BOSPADDENSTOEL_RECONSTRUCTION_EXPECTED = {
    "source_records": 982,
    "exact_source_records": 498,
    "presence_source_records": 484,
    "duplicate_presence_records": 473,
    "canonical_positive_records": 509,
    "meetpoints": 3,
    "source_geometries": 6,
    "visits": 110,
    "target_scope_rows": 76,
    "target_taxa": 49,
    "target_positive_rows": 506,
    "bycatch_positive_rows": 3,
    "visit_matrix_rows": 2934,
    "true_zero_rows": 2428,
    "annual_rows": 977,
    "annual_positive_rows": 316,
    "annual_zero_rows": 661,
    "off_season_visits": 7,
    "invalid_source_measurements": 0,
    "invalid_meetpoint_geometries": 0,
    "duplicate_target_missing": 0,
    "invalid_matrix_rows": 0,
    "invalid_annual_rows": 0,
    "legacy_secure_tables": 0,
}
HNS_RECONSTRUCTION_EXPECTED = {
    "source_records": 4569,
    "year_aggregate_records": 39,
    "linked_source_records": 4569,
    "inventories": 26,
    "complete_inventories": 23,
    "fragment_inventories": 3,
    "complete_source_records": 4524,
    "fragment_source_records": 6,
    "target_taxa": 703,
    "visit_matrix_rows": 16169,
    "positive_rows": 4439,
    "true_zero_rows": 11730,
    "hok_years": 12,
    "annual_rows": 8436,
    "annual_positive_rows": 3269,
    "annual_zero_rows": 5167,
    "repeated_hok_years": 10,
    "independence_unconfirmed_visits": 21,
    "invalid_matrix_rows": 0,
    "matrix_size_mismatch": 0,
    "positive_source_mismatch": 0,
    "selection_status_mismatch": 0,
    "invalid_annual_rows": 0,
    "unlinked_source_records": 0,
    "legacy_secure_tables": 0,
}
KORSTMOS_RECONSTRUCTION_EXPECTED = {
    "source_records": 364,
    "excluded_blurred_records": 20,
    "meetlocations": 12,
    "repeated_meetlocations": 4,
    "oneoff_meetlocations": 8,
    "visits": 32,
    "repeated_location_visits": 24,
    "oneoff_location_visits": 8,
    "target_taxa": 30,
    "recordselection_rows": 364,
    "selected_records": 277,
    "suppressed_duplicate_records": 67,
    "abundance_conflict_records": 20,
    "matrix_rows": 960,
    "positive_rows": 287,
    "normal_positive_rows": 277,
    "conflict_positive_rows": 10,
    "true_zero_rows": 673,
    "single_plot_records": 352,
    "multiple_plot_records": 12,
    "invalid_source_measurements": 0,
    "invalid_matrix_rows": 0,
    "matrix_size_mismatch": 0,
    "positive_source_mismatch": 0,
    "unlinked_source_records": 0,
    "secure_derived_tables": 0,
}
MOS_RECONSTRUCTION_EXPECTED = {
    "source_records": 376,
    "excluded_blurred_records": 1,
    "inventories": 7,
    "single_year_inventories": 6,
    "cross_year_inventories": 1,
    "date_clusters": 21,
    "day_clusters": 19,
    "year_clusters": 2,
    "single_date_inventories": 4,
    "multiple_date_inventories": 3,
    "target_taxa": 111,
    "recordselection_rows": 376,
    "selected_records": 353,
    "suppressed_duplicate_records": 21,
    "abundance_conflict_records": 2,
    "matrix_rows": 777,
    "positive_rows": 354,
    "abundance_positive_rows": 312,
    "presence_positive_rows": 41,
    "conflict_positive_rows": 1,
    "true_zero_rows": 423,
    "single_plot_source_records": 52,
    "multiple_plot_source_records": 324,
    "invalid_source_measurements": 0,
    "invalid_matrix_rows": 0,
    "matrix_size_mismatch": 0,
    "positive_source_mismatch": 0,
    "unlinked_source_records": 0,
    "secure_derived_tables": 0,
}
FLORBASE_RECONSTRUCTION_EXPECTED = {
    "source_records": 21161,
    "excluded_blurred_records": 213,
    "inventories": 183,
    "complete_inventories": 118,
    "fragment_inventories": 65,
    "complete_source_records": 20174,
    "fragment_source_records": 987,
    "complete_hoks": 33,
    "all_hoks": 36,
    "target_taxa": 857,
    "matrix_rows": 101126,
    "positive_rows": 19405,
    "presence_positive_rows": 18731,
    "amount_positive_rows": 674,
    "preliminary_zero_rows": 81721,
    "invalid_matrix_rows": 0,
    "matrix_size_mismatch": 0,
    "positive_source_mismatch": 0,
    "unlinked_source_records": 0,
    "pq_non_applicable_records": 21374,
    "pq_other_records": 0,
    "secure_derived_tables": 0,
}
HABSLAK_RECONSTRUCTION_EXPECTED = {
    "source_records": 2772,
    "unblurred_source_records": 2629,
    "blurred_source_records": 143,
    "sample_events": 251,
    "positive_event_taxa": 1730,
    "square_years": 66,
    "sufficient_square_years": 4,
    "insufficient_square_years": 62,
    "target_positive_square_years": 40,
    "preliminary_zero_square_years": 0,
    "invalid_sample_rows": 0,
    "unlinked_source_records": 0,
    "secure_derived_tables": 0,
}
BRAAKBAL_RECONSTRUCTION_EXPECTED = {
    "source_records": 389,
    "blurred_source_records": 387,
    "unblurred_source_records": 2,
    "hok_years": 37,
    "taxon_rows": 226,
    "distinct_taxa": 14,
    "total_prey_count": 9381,
    "field_mouse_count": 3424,
    "minimum_150_party_unknown": 18,
    "under_150": 19,
    "annual_aggregates": 34,
    "dated_registrations": 2,
    "mixed_period_aggregates": 1,
    "multi_year_aggregates": 0,
    "other_interval_aggregates": 0,
    "inferred_zero_rows": 0,
    "plot_linked_rows": 0,
    "invalid_hokyear_rows": 0,
    "unlinked_source_records": 0,
    "secure_derived_tables": 0,
}
TUINTELLING_RECONSTRUCTION_EXPECTED = {
    "source_records": 309,
    "geometry_versions": 6,
    "garden_area_families": 3,
    "periods": 125,
    "weekly_periods": 119,
    "day_periods": 5,
    "point_periods": 1,
    "other_periods": 0,
    "group_periods": 213,
    "local_target_taxa": 33,
    "matrix_rows": 1645,
    "positive_rows": 308,
    "preliminary_zero_rows": 1337,
    "exact_count_source_records": 288,
    "presence_source_records": 21,
    "outside_source_records": 308,
    "multiple_source_records": 1,
    "post_renewal_periods": 0,
    "plot_linked_rows": 0,
    "invalid_matrix_rows": 0,
    "matrix_size_mismatch": 0,
    "positive_source_mismatch": 0,
    "unlinked_source_records": 0,
    "secure_derived_tables": 0,
}
LIVEATLAS_RECONSTRUCTION_EXPECTED = {
    "source_records": 231,
    "visits": 64,
    "group_visits": 87,
    "taxon_rows": 169,
    "distinct_taxa": 33,
    "geometry_versions": 128,
    "exact_count_source_records": 231,
    "total_count": 455,
    "butterfly_visits": 53,
    "dragonfly_visits": 34,
    "short_visits": 1,
    "recommended_duration_visits": 23,
    "long_visits": 40,
    "single_plot_visits": 12,
    "multiple_visits": 35,
    "outside_visits": 5,
    "mixed_visits": 12,
    "completeness_unknown_group_visits": 87,
    "zero_rows": 0,
    "invalid_taxon_rows": 0,
    "positive_source_mismatch": 0,
    "unlinked_source_records": 0,
    "secure_derived_tables": 0,
}
KWARTIERTELLING_RECONSTRUCTION_EXPECTED = {
    "source_records": 102,
    "intervals": 17,
    "group_intervals": 18,
    "taxon_rows": 49,
    "distinct_taxa": 19,
    "geometry_versions": 87,
    "exact_count_source_records": 102,
    "total_count": 102,
    "butterfly_intervals": 17,
    "moth_intervals": 1,
    "short_intervals": 3,
    "protocol_duration_intervals": 7,
    "overlong_intervals": 7,
    "single_plot_intervals": 14,
    "multiple_intervals": 1,
    "outside_intervals": 0,
    "mixed_intervals": 2,
    "completeness_unknown_group_intervals": 18,
    "zero_rows": 0,
    "invalid_taxon_rows": 0,
    "positive_source_mismatch": 0,
    "unlinked_source_records": 0,
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
    "trend_rows": 10855,
    "trend_sources": 65464,
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


def classify_rabbit_season(visit_date: str) -> str:
    """Toets een teldatum aan de huidige landelijke telvensters.

    Historische afwijkingen blijven behouden: buiten het huidige venster is
    een controlesignaal en geen uitsluiting.
    """
    month_day = visit_date[5:10]
    if "03-15" <= month_day <= "04-07":
        return "voorjaar_huidig_venster"
    if "09-15" <= month_day <= "10-15":
        return "najaar_huidig_venster"
    return "buiten_huidig_venster"


def classify_rabbit_record_signal(
    grid_date_taxon_count: int, exact_value_count: int
) -> str:
    """Markeer samenlopende sectieregels zonder ze als dubbel te verwijderen."""
    if exact_value_count > 1:
        return "gelijke_telwaarde_binnen_hokdatum_taxon"
    if grid_date_taxon_count > 1:
        return "meerdere_sectieregels_binnen_hokdatum_taxon"
    return "uniek_binnen_hokdatum_taxon"


def build_daz_bmp_matrix(
    confirmed_visits: set[int],
    positive_counts: dict[tuple[int, str], tuple[int, int]],
    ambiguous_counts: dict[tuple[int, str], int],
) -> list[dict[str, object]]:
    """Bouw de DAZ-matrix voor aantoonbaar deelnemende BMP-bezoeken.

    Een eenduidig gekoppelde positieve 17.204-regel bewijst deelname. Voor de
    zeven DAZ-doelsoorten is ontbreken dan een echte nul, behalve als een
    meervoudig koppelbaar record van hetzelfde taxon die nul onzeker maakt.
    Bijvangsten krijgen uitsluitend positieve regels en nooit afgeleide nullen.
    """
    rows: list[dict[str, object]] = []
    for visit_id in sorted(confirmed_visits):
        for taxon in sorted(DAZ_TARGET_SPECIES):
            count, source_records = positive_counts.get((visit_id, taxon), (0, 0))
            ambiguous = ambiguous_counts.get((visit_id, taxon), 0)
            if count > 0:
                status = "waargenomen"
                value_status = "minimum_door_ambiguiteit" if ambiguous else "exact"
                value: int | None = count
                zero_rule = "bevestigde_daz_deelname"
            elif ambiguous:
                status = "onbepaald_ambigu"
                value_status = "niet_toewijsbaar"
                value = None
                zero_rule = "geblokkeerd_door_ambigu_record"
            else:
                status = "echte_nul"
                value_status = "echte_nul"
                value = 0
                zero_rule = "bevestigde_daz_deelname"
            rows.append({
                "visit_id": visit_id, "taxon": taxon, "relation": "doelsoort",
                "status": status, "count": value, "source_records": source_records,
                "ambiguous_records": ambiguous, "value_status": value_status,
                "zero_rule": zero_rule,
            })

        bycatch_taxa = sorted({
            taxon for candidate_visit, taxon in positive_counts
            if candidate_visit == visit_id and taxon not in DAZ_TARGET_SPECIES
        })
        for taxon in bycatch_taxa:
            count, source_records = positive_counts[(visit_id, taxon)]
            ambiguous = ambiguous_counts.get((visit_id, taxon), 0)
            rows.append({
                "visit_id": visit_id, "taxon": taxon, "relation": "bijvangst",
                "status": "waargenomen", "count": count,
                "source_records": source_records, "ambiguous_records": ambiguous,
                "value_status": "minimum_door_ambiguiteit" if ambiguous else "exact",
                "zero_rule": "niet_van_toepassing_bijvangst",
            })
    return rows


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
    ("17.204", "Zoogdieren (overig)"): (
        "https://www.netwerkecologischemonitoring.nl/meetprogrammas/zoogdieren",
        "https://www.netwerkecologischemonitoring.nl/wp-content/uploads/2025/05/meetprogrammasvoorfloraenfauna2024.pdf",
    ),
    ("17.209", "Zoogdieren (overig)"): (
        "https://www.netwerkecologischemonitoring.nl/meetprogrammas/zoogdieren",
        "https://www.zoogdiervereniging.nl/sites/default/files/2019-10/2016.36%20Zoogdieren%20in%20Zuid-Holland.pdf",
        "https://www.zoogdiervereniging.nl/sites/default/files/2026-04/telganger_2023-2_0-24-29_konijnentellingen.pdf",
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


def protocol_delivery_assessment(
    protocol_sleutel: str, analysetype: str
) -> tuple[str, str] | None:
    """Beoordeel gemengde en uitsluitend positieve bronleveringen.

    De ontvangen regels van 04.004 en 07.001 onderscheiden geen volledige
    gebiedsinventarisaties van losse, historische, collectie- of
    literatuurregistraties. V blijft daarom voorwaardelijk bruikbaar. I en TV
    mogen alleen als indicatieve verandering in registraties worden berekend;
    TA en TK worden door deze levering niet ondersteund.

    De expliciet positieve bronprotocollen bevatten geen complete bezoeken,
    inspanning of nullen. Daar blijft alleen V voorwaardelijk bruikbaar.
    """
    assessed_protocols = (
        MIXED_POSITIVE_PROTOCOLS
        | POSITIVE_ONLY_SOURCE_PROTOCOLS
        | set(STRUCTURED_INCOMPLETE_PROTOCOLS)
    )
    if protocol_sleutel not in assessed_protocols:
        return None
    if analysetype == "V":
        return "voorwaardelijk", "voorlopig_toegelaten"
    if protocol_sleutel in MIXED_POSITIVE_PROTOCOLS and analysetype in {"I", "TV"}:
        return "onvoldoende", "voorlopig_toegelaten"
    if analysetype in STRUCTURED_INCOMPLETE_PROTOCOLS.get(protocol_sleutel, set()):
        return "onvoldoende", "voorlopig_toegelaten"
    return "onvoldoende", "uitgesloten_huidige_levering"


def delivery_assessment_sql() -> str:
    """Leg beoordeelde gemengde en uitsluitend positieve leveringen vast."""
    positive_reason = (
        "De NDFF-levering combineert volledige gebiedsinventarisaties met "
        "losse, historische, collectie- of literatuurregistraties zonder "
        "onderscheidende lijst-, bezoek- of inspanningssleutel. Positieve "
        "verspreidingsinformatie is na ruimtelijke en PQ-toets bruikbaar."
    )
    indicative_reason = (
        "De protocolcode ondersteunt in beginsel vergelijking door de tijd, "
        "maar de ontvangen levering scheidt volledige inventarisaties niet "
        "van losse of secundaire registraties. Alleen indicatieve verandering "
        "in geregistreerde aanwezigheid is toegestaan; niet presenteren als "
        "populatietrend, abundantie, afwezigheid of causaal beheereffect."
    )
    excluded_reason = (
        "De ontvangen gemengde atlas-/verspreidingslevering bevat geen "
        "onderscheidende telobjecten, volledige bezoeken, inspanning of "
        "nulwaarnemingen en onderbouwt dit analysetype daarom niet."
    )
    source_positive_reason = (
        "Dit bronprotocol levert in de ontvangen NDFF-selectie uitsluitend "
        "positieve registraties en geen complete bezoeken, onderzoeksinspanning, "
        "volledige soortenlijst of afleidbare nullen. De registratie is na "
        "ruimtelijke en PQ-toets bruikbaar als voorkomensinformatie."
    )
    source_excluded_reason = (
        "Dit bronprotocol levert geen complete bezoeken, onderzoeksinspanning, "
        "volledige soortenlijst of afleidbare nullen. Alleen positieve "
        "voorkomensinformatie is verantwoord; dit analysetype is uitgesloten."
    )
    structured_positive_reason = (
        "De protocolcode en de ontvangen datum-, duur-, locatie- en telvelden "
        "tonen een gestructureerde bronregistratie. Positieve voorkomensinformatie "
        "is na ruimtelijke en PQ-toets bruikbaar."
    )
    structured_indicative_reason = (
        "Het protocol ondersteunt dit analysetype in beginsel en de ontvangen "
        "regels bevatten herhaalde of getimede registraties. De oorspronkelijke "
        "tuin-, route-, lijst- of monster-ID en volledigheidsmetadata ontbreken "
        "echter. Alleen indicatieve verandering in geregistreerde tellingen is "
        "toegestaan; niet presenteren als gevalideerde populatietrend."
    )
    structured_excluded_reason = (
        "De gestructureerde bron is herkenbaar, maar de huidige levering bevat "
        "niet de volledige meeteenheid-, bezoek-, lijst- of monsterstructuur die "
        "voor dit analysetype nodig is."
    )
    assessment_rows: list[str] = []
    assessed_protocols = sorted(
        MIXED_POSITIVE_PROTOCOLS
        | POSITIVE_ONLY_SOURCE_PROTOCOLS
        | set(STRUCTURED_INCOMPLETE_PROTOCOLS)
    )
    for protocol_sleutel in assessed_protocols:
        for analysetype in ANALYSIS_TYPES:
            assessment = protocol_delivery_assessment(protocol_sleutel, analysetype)
            if assessment is None:
                continue
            gegevensgeschiktheid, eindbesluit = assessment
            if protocol_sleutel in STRUCTURED_INCOMPLETE_PROTOCOLS and analysetype == "V":
                reason = structured_positive_reason
            elif (
                protocol_sleutel in STRUCTURED_INCOMPLETE_PROTOCOLS
                and analysetype in STRUCTURED_INCOMPLETE_PROTOCOLS[protocol_sleutel]
            ):
                reason = structured_indicative_reason
            elif protocol_sleutel in STRUCTURED_INCOMPLETE_PROTOCOLS:
                reason = structured_excluded_reason
            elif protocol_sleutel in POSITIVE_ONLY_SOURCE_PROTOCOLS and analysetype == "V":
                reason = source_positive_reason
            elif protocol_sleutel in POSITIVE_ONLY_SOURCE_PROTOCOLS:
                reason = source_excluded_reason
            elif analysetype == "V":
                reason = positive_reason
            elif analysetype in {"I", "TV"}:
                reason = indicative_reason
            else:
                reason = excluded_reason
            assessment_rows.append(
                "SELECT "
                f"{sql_text(protocol_sleutel)} AS protocol_sleutel,"
                f"{sql_text(analysetype)} AS analysetype,"
                f"{sql_text(gegevensgeschiktheid)} AS gegevensgeschiktheid,"
                f"{sql_text(eindbesluit)} AS eindbesluit,"
                f"{sql_text(reason)} AS reden"
            )
    assessment_sql = " UNION ALL ".join(assessment_rows)
    return f"""
UPDATE Meijendel.ndff_analysebesluit AS d
JOIN Meijendel.ndff_protocol AS p ON p.protocol_id=d.protocol_id
JOIN ({assessment_sql}) AS a
  ON a.protocol_sleutel=p.protocol_sleutel AND a.analysetype=d.analysetype
SET d.gegevensgeschiktheid=a.gegevensgeschiktheid,
    d.eindbesluit=a.eindbesluit,
    d.reden=a.reden,
    d.besloten_op='2026-09-12'
WHERE d.regelversie={sql_text(DECISION_RULE_VERSION)};
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


def rabbit_source_sql() -> str:
    """Lees de openbare positieve sectietellingen van protocol 17.209."""
    return """
SELECT o.waarneming_id,DATE_FORMAT(DATE(o.periode_start),'%Y-%m-%d'),o.jaar,
       o.openbare_geometrie_sha256,o.hoknummer,o.wetenschappelijke_naam,
       o.aantal_raw,o.schaal_telmethode,o.telonderwerp,
       o.determinatiemethode,o.bronhouder,o.vervaagd,
       r.ruimtelijke_klasse,r.toewijzingskwaliteit
FROM Meijendel.ndff_open_waarneming AS o
JOIN Meijendel.ndff_open_ruimtelijke_beoordeling AS r
  ON r.waarneming_id=o.waarneming_id
WHERE o.protocol LIKE '17.209%'
  AND o.soortgroep_raw='Zoogdieren (overig)'
ORDER BY o.periode_start,o.openbare_geometrie_sha256,
         o.wetenschappelijke_naam,o.waarneming_id;
"""


def daz_exact_keys_sql() -> str:
    """Lees alleen sleutels voor een voorzichtig 17.204-overlapsignaal."""
    return """
SELECT DISTINCT DATE_FORMAT(DATE(o.periode_start),'%Y-%m-%d'),
       o.openbare_geometrie_sha256,o.wetenschappelijke_naam,o.aantal_raw
FROM Meijendel.ndff_open_waarneming AS o
WHERE o.protocol LIKE '17.204%'
  AND o.soortgroep_raw='Zoogdieren (overig)';
"""


def daz_bmp_source_sql() -> str:
    """Lees alle openbare positieve zoogdierregistraties van NEM 17.204."""
    return """
SELECT o.waarneming_id,DATE_FORMAT(DATE(o.periode_start),'%Y-%m-%d'),o.jaar,
       o.wetenschappelijke_naam,o.aantal_raw,o.schaal_telmethode,
       o.telonderwerp,o.determinatiemethode,o.bronhouder,o.vervaagd
FROM Meijendel.ndff_open_waarneming AS o
WHERE o.protocol LIKE '17.204%'
ORDER BY o.waarneming_id;
"""


def daz_bmp_candidate_sql() -> str:
    """Koppel 17.204-records aan ruimtelijk mogelijke BMP-bezoeken op datum."""
    return """
SELECT o.waarneming_id,b.bezoek_id,b.plot_id,
       DATE_FORMAT(b.bezoek_datum,'%Y-%m-%d'),
       COUNT(*) OVER (PARTITION BY o.waarneming_id) AS kandidaat_bezoekaantal
FROM Meijendel.ndff_open_waarneming AS o
JOIN Meijendel.ndff_sovon_plot AS p
  ON p.plotversie_id=1
 AND ST_Intersects(o.openbare_geometrie,p.plot_geometrie)
JOIN Meijendel.dagbezoeken_bmp AS b
  ON b.plot_id=p.plot_id
 AND b.bezoek_datum=DATE(o.periode_start)
WHERE o.protocol LIKE '17.204%'
ORDER BY o.waarneming_id,b.bezoek_id;
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


def reconstruct_konijnen(
    mysql_client: Path,
    client_args: list[str],
) -> dict[str, int]:
    """Classificeer 17.209 zonder ontbrekende route- of sectie-ID's te raden."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    output = run_mysql(mysql_client, query_args, rabbit_source_sql(), capture=True)
    rows: list[dict[str, object]] = []
    for line in output.splitlines():
        (observation_id, visit_date, year, geometry, grid, taxon, raw_count,
         scale, subject, determination, holder, blurred, spatial_class,
         assignment_quality) = line.split("\t")
        if (not raw_count.isdigit() or int(raw_count) <= 0
                or scale != "exact aantal" or subject != "levend exemplaar"
                or determination != "gezien" or holder != "Zoogdiervereniging"
                or blurred != "0"):
            raise ValueError("Een 17.209-record wijkt af van het gecontroleerde telprofiel.")
        if spatial_class != "multiple" or assignment_quality != "multiple":
            raise ValueError("Een 17.209-kilometerhok heeft onverwacht geen multiple-plotstatus.")
        rows.append({
            "observation_id": int(observation_id), "visit_date": visit_date,
            "year": int(year), "geometry": geometry, "grid": grid,
            "taxon": taxon, "count": int(raw_count),
        })
    if len(rows) != 5_809 or len({int(row["observation_id"]) for row in rows}) != len(rows):
        raise ValueError("De 17.209-bronselectie wijkt af van het gecontroleerde profiel.")

    daz_output = run_mysql(mysql_client, query_args, daz_exact_keys_sql(), capture=True)
    daz_keys = {
        (visit_date, geometry, taxon, int(raw_count))
        for visit_date, geometry, taxon, raw_count in
        (line.split("\t") for line in daz_output.splitlines())
        if raw_count.isdigit()
    }
    grid_date_taxon_counts: Counter[tuple[str, str, str]] = Counter()
    exact_counts: Counter[tuple[str, str, str, int]] = Counter()
    aggregate: dict[tuple[str, str, str], dict[str, object]] = {}
    for row in rows:
        group_key = (str(row["visit_date"]), str(row["geometry"]), str(row["taxon"]))
        exact_key = (*group_key, int(row["count"]))
        grid_date_taxon_counts[group_key] += 1
        exact_counts[exact_key] += 1
        item = aggregate.setdefault(group_key, {
            "year": int(row["year"]), "grid": str(row["grid"]),
            "counts": [],
        })
        item["counts"].append(int(row["count"]))  # type: ignore[union-attr]

    selection_values: list[str] = []
    for row in rows:
        group_key = (str(row["visit_date"]), str(row["geometry"]), str(row["taxon"]))
        exact_key = (*group_key, int(row["count"]))
        target = str(row["taxon"]) == "Oryctolagus cuniculus"
        overlap = exact_key in daz_keys
        note = (
            "Exacte positieve sectietelling uit NEM 17.209. De FFV-export bevat geen route- of sectie-id; "
            "het kilometerhok kan meerdere secties en SOVON-plots omvatten. Gelijke waarden blijven "
            "afzonderlijke bronrecords en zijn niet automatisch dubbelen. Geen nul of routetrend afleiden."
        )
        selection_values.append(
            f"({sql_text(RABBIT_COUNT_RULE_VERSION)},{int(row['observation_id'])},'17.209',"
            f"{sql_text('doelsoort' if target else 'bijvangst')},{int(row['count'])},"
            f"{sql_text(classify_rabbit_season(str(row['visit_date'])))},"
            f"{sql_text(classify_rabbit_record_signal(grid_date_taxon_counts[group_key], exact_counts[exact_key]))},"
            f"{grid_date_taxon_counts[group_key]},{exact_counts[exact_key]},"
            f"{sql_text('mogelijke_overlap_17_204' if overlap else 'geen_exacte_match')},"
            "'kilometerhok_meerdere_sovonplots','sectie_zonder_route_of_sectie_id',"
            f"'wacht_op_route_sectie_koppeling',{sql_text(note)})"
        )

    aggregate_values: list[str] = []
    for (visit_date, geometry, taxon), item in sorted(aggregate.items()):
        counts = list(item["counts"])  # type: ignore[arg-type]
        key = hashlib.sha256(f"{visit_date}|{geometry}|{taxon}".encode("utf-8")).hexdigest()
        aggregate_values.append(
            f"({sql_text(RABBIT_COUNT_RULE_VERSION)},{sql_text(key)},"
            f"{sql_text(visit_date)},{int(item['year'])},{sql_text(geometry)},"
            f"{sql_text(str(item['grid']))},{sql_text(taxon)},"
            f"{sql_text('doelsoort' if taxon == 'Oryctolagus cuniculus' else 'bijvangst')},"
            f"{len(counts)},{sum(counts)},{min(counts)},{max(counts)},"
            "'diagnostische_proxy_geen_meeteenheid','niet_afleidbaar')"
        )

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {RABBIT_TABLE_PREFIX}_hokdatum_taxon WHERE reconstructieversie={sql_text(RABBIT_COUNT_RULE_VERSION)};",
        f"DELETE FROM {RABBIT_TABLE_PREFIX}_recordselectie WHERE reconstructieversie={sql_text(RABBIT_COUNT_RULE_VERSION)};",
    ]
    statements += _batched_insert(
        f"{RABBIT_TABLE_PREFIX}_recordselectie",
        "reconstructieversie,waarneming_id,protocol_sleutel,doelrelatie,aantal_exact,seizoenstatus,recordgroepstatus,hokdatum_taxon_groepsgrootte,exactgelijke_groepsgrootte,daz_overlapstatus,ruimtelijke_status,meeteenheidstatus,trendgebruik,kwaliteitsnotitie",
        selection_values,
    )
    statements += _batched_insert(
        f"{RABBIT_TABLE_PREFIX}_hokdatum_taxon",
        "reconstructieversie,hokdatum_taxon_sleutel,teldatum,jaar,openbare_geometrie_sha256,hoknummer,wetenschappelijke_naam,doelrelatie,bronrecordaantal,aantal_som,aantal_min,aantal_max,aggregatiestatus,nulstatus",
        aggregate_values,
    )
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))

    target_rows = [row for row in rows if row["taxon"] == "Oryctolagus cuniculus"]
    bycatch_rows = [row for row in rows if row["taxon"] != "Oryctolagus cuniculus"]
    season_counts = Counter(classify_rabbit_season(str(row["visit_date"])) for row in rows)
    return {
        "source_records": len(rows), "target_records": len(target_rows),
        "bycatch_records": len(bycatch_rows),
        "target_count_sum": sum(int(row["count"]) for row in target_rows),
        "bycatch_count_sum": sum(int(row["count"]) for row in bycatch_rows),
        "dates": len({row["visit_date"] for row in rows}),
        "grids": len({row["geometry"] for row in rows}),
        "grid_date_taxon_rows": len(aggregate),
        "spring_window_records": season_counts["voorjaar_huidig_venster"],
        "autumn_window_records": season_counts["najaar_huidig_venster"],
        "off_window_records": season_counts["buiten_huidig_venster"],
        "exact_duplicate_groups": sum(count > 1 for count in exact_counts.values()),
        "exact_duplicate_members": sum(count for count in exact_counts.values() if count > 1),
        "multi_record_grid_date_taxon_groups": sum(count > 1 for count in grid_date_taxon_counts.values()),
        "possible_daz_overlap_records": sum(
            (str(row["visit_date"]), str(row["geometry"]), str(row["taxon"]), int(row["count"])) in daz_keys
            for row in rows
        ),
        "derived_zero_rows": 0, "multiple_plot_records": len(rows),
        "secure_source_records": 0, "secure_derived_tables": 0,
    }


def reconstruct_daz_bmp(
    mysql_client: Path,
    client_args: list[str],
) -> dict[str, int]:
    """Reconstructeer DAZ-deelname en echte nullen binnen bekende BMP-bezoeken."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    source_output = run_mysql(mysql_client, query_args, daz_bmp_source_sql(), capture=True)
    source: dict[int, dict[str, object]] = {}
    for line in source_output.splitlines():
        (observation_id, visit_date, year, taxon, raw_count, scale, subject,
         determination, holder, blurred) = line.split("\t")
        if (not raw_count.isdigit() or int(raw_count) <= 0
                or scale != "exact aantal" or subject != "levend exemplaar"
                or determination != "gezien" or holder != "Zoogdiervereniging"
                or blurred != "0"):
            raise ValueError("Een 17.204-record wijkt af van het gecontroleerde DAZ-profiel.")
        observation = int(observation_id)
        source[observation] = {
            "date": visit_date, "year": int(year), "taxon": taxon,
            "count": int(raw_count),
        }
    if len(source) != 10_670:
        raise ValueError("De 17.204-bronselectie wijkt af van het gecontroleerde profiel.")

    candidate_output = run_mysql(mysql_client, query_args, daz_bmp_candidate_sql(), capture=True)
    candidates: dict[int, list[dict[str, object]]] = defaultdict(list)
    for line in candidate_output.splitlines():
        observation_id, visit_id, plot_id, visit_date, candidate_count = line.split("\t")
        observation = int(observation_id)
        if observation not in source:
            raise ValueError("DAZ-kandidaatkoppeling verwijst naar een record buiten 17.204.")
        candidates[observation].append({
            "visit_id": int(visit_id), "plot_id": int(plot_id),
            "date": visit_date, "candidate_count": int(candidate_count),
        })
    if any(len(items) != int(items[0]["candidate_count"]) for items in candidates.values()):
        raise ValueError("Inconsistente kandidaat-aantallen in DAZ-BMP-koppeling.")

    unique_links = {
        observation: items[0]
        for observation, items in candidates.items()
        if len(items) == 1
    }
    confirmed_visits = {int(item["visit_id"]) for item in unique_links.values()}
    visit_meta: dict[int, dict[str, object]] = {}
    positive_counts: dict[tuple[int, str], tuple[int, int]] = {}
    unique_records_by_visit: Counter[int] = Counter()
    for observation, item in unique_links.items():
        visit_id = int(item["visit_id"])
        visit_meta[visit_id] = item
        unique_records_by_visit[visit_id] += 1
        taxon = str(source[observation]["taxon"])
        count, records = positive_counts.get((visit_id, taxon), (0, 0))
        positive_counts[(visit_id, taxon)] = (
            count + int(source[observation]["count"]), records + 1,
        )

    ambiguous_counts: Counter[tuple[int, str]] = Counter()
    ambiguous_records_by_visit: Counter[int] = Counter()
    for observation, items in candidates.items():
        if len(items) <= 1:
            continue
        taxon = str(source[observation]["taxon"])
        for item in items:
            visit_id = int(item["visit_id"])
            if visit_id in confirmed_visits:
                ambiguous_counts[(visit_id, taxon)] += 1
                ambiguous_records_by_visit[visit_id] += 1

    matrix = build_daz_bmp_matrix(
        confirmed_visits,
        positive_counts,
        dict(ambiguous_counts),
    )

    visit_values: list[str] = []
    visit_note = (
        "DAZ-deelname is bevestigd door minimaal één eenduidig aan dit BMP-bezoek "
        "gekoppeld positief 17.204-record. Niet-bevestigde BMP-bezoeken worden niet "
        "als DAZ-bezoek gebruikt. BMP-bezoektijd is bekend; afzonderlijke DAZ-inspanning niet."
    )
    for visit_id in sorted(confirmed_visits):
        meta = visit_meta[visit_id]
        visit_values.append(
            f"({sql_text(DAZ_BMP_RULE_VERSION)},{visit_id},{int(meta['plot_id'])},"
            f"{sql_text(str(meta['date']))},{int(str(meta['date'])[:4])},"
            "'bevestigd_door_positieve_17_204',"
            f"{unique_records_by_visit[visit_id]},{ambiguous_records_by_visit[visit_id]},"
            "'zeven_daz_doelsoorten','bmp_bezoek_bekend_daz_inspanning_niet_afzonderlijk',"
            f"{sql_text(visit_note)})"
        )

    selection_values: list[str] = []
    for observation, row in sorted(source.items()):
        items = candidates.get(observation, [])
        if len(items) == 1:
            link_status = "eenduidig_bmp_bezoek"
            visit_sql = str(int(items[0]["visit_id"]))
            use_status = "opgenomen_in_bezoekmatrix"
        elif items:
            link_status = "meerdere_bmp_bezoeken"
            visit_sql = "NULL"
            use_status = "alleen_bronrecord"
        else:
            link_status = "geen_bmp_bezoek"
            visit_sql = "NULL"
            use_status = "alleen_bronrecord"
        relation = "doelsoort" if str(row["taxon"]) in DAZ_TARGET_SPECIES else "bijvangst"
        note = (
            "Openbare 17.204-registratie. Een eenduidige koppeling vereist dezelfde datum "
            "en precies één door het kilometerhok geraakt SOVON-plot met een BMP-bezoek."
        )
        selection_values.append(
            f"({sql_text(DAZ_BMP_RULE_VERSION)},{observation},'17.204',"
            f"{sql_text(str(row['taxon']))},{sql_text(relation)},{int(row['count'])},"
            f"{len(items)},{sql_text(link_status)},{visit_sql},{sql_text(use_status)},"
            f"{sql_text(note)})"
        )

    candidate_values: list[str] = []
    for observation, items in sorted(candidates.items()):
        for item in items:
            candidate_values.append(
                f"({sql_text(DAZ_BMP_RULE_VERSION)},{observation},{int(item['visit_id'])},"
                f"{int(item['plot_id'])},{sql_text(str(item['date']))})"
            )

    matrix_values: list[str] = []
    for row in matrix:
        count_sql = "NULL" if row["count"] is None else str(int(row["count"]))
        note = (
            "Echte nul uitsluitend voor een DAZ-doelsoort binnen een bevestigd deelnemend "
            "BMP-bezoek. Een meervoudig koppelbaar record van hetzelfde taxon blokkeert de nul."
        )
        matrix_values.append(
            f"({sql_text(DAZ_BMP_RULE_VERSION)},{int(row['visit_id'])},"
            f"{sql_text(str(row['taxon']))},{sql_text(str(row['relation']))},"
            f"{sql_text(str(row['status']))},{count_sql},{int(row['source_records'])},"
            f"{int(row['ambiguous_records'])},{sql_text(str(row['value_status']))},"
            f"{sql_text(str(row['zero_rule']))},{sql_text(note)})"
        )

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {DAZ_BMP_TABLE_PREFIX}_recordkandidaat WHERE reconstructieversie={sql_text(DAZ_BMP_RULE_VERSION)};",
        f"DELETE FROM {DAZ_BMP_TABLE_PREFIX}_bezoek_taxon WHERE reconstructieversie={sql_text(DAZ_BMP_RULE_VERSION)};",
        f"DELETE FROM {DAZ_BMP_TABLE_PREFIX}_recordselectie WHERE reconstructieversie={sql_text(DAZ_BMP_RULE_VERSION)};",
        f"DELETE FROM {DAZ_BMP_TABLE_PREFIX}_bezoek WHERE reconstructieversie={sql_text(DAZ_BMP_RULE_VERSION)};",
    ]
    statements += _batched_insert(
        f"{DAZ_BMP_TABLE_PREFIX}_bezoek",
        "reconstructieversie,bezoek_id,plot_id,bezoekdatum,jaar,deelnamestatus,eenduidig_bronrecordaantal,ambigu_kandidaatrecordaantal,nulbereikstatus,inspanningstatus,kwaliteitsnotitie",
        visit_values,
    )
    statements += _batched_insert(
        f"{DAZ_BMP_TABLE_PREFIX}_recordselectie",
        "reconstructieversie,waarneming_id,protocol_sleutel,wetenschappelijke_naam,doelrelatie,aantal_exact,kandidaat_bezoekaantal,koppelstatus,bezoek_id,gebruiksstatus,kwaliteitsnotitie",
        selection_values,
    )
    statements += _batched_insert(
        f"{DAZ_BMP_TABLE_PREFIX}_recordkandidaat",
        "reconstructieversie,waarneming_id,bezoek_id,plot_id,bezoekdatum",
        candidate_values,
    )
    statements += _batched_insert(
        f"{DAZ_BMP_TABLE_PREFIX}_bezoek_taxon",
        "reconstructieversie,bezoek_id,wetenschappelijke_naam,doelrelatie,waarnemingsstatus,aantal,bronrecordaantal,ambigu_recordaantal,telwaardestatus,nulregel,kwaliteitsnotitie",
        matrix_values,
    )
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))

    audit_output = run_mysql(
        mysql_client, query_args, daz_bmp_validation_sql(), capture=True,
    )
    return parse_analysis_chain_output(audit_output)


def classify_zeereep_abundance(scale: str, raw_value: str) -> str:
    """Behoud de NMV-siteklasse zonder die als vruchtlichaamaantal te lezen."""
    mapping = {
        ("NMV-aantalsklassen", "1.0 - 3.0"): "klasse_1_3",
        ("NMV-aantalsklassen", "4.0 - 20.0"): "klasse_4_20",
        ("NMV-aantalsklassen", "minimaal 21.0"): "klasse_21_plus",
        ("voorkomen", "minimaal 1.0"): "aanwezig",
        ("exact aantal", "1"): "exact_1",
    }
    try:
        return mapping[(scale, raw_value)]
    except KeyError as exc:
        raise ValueError(f"Niet ondersteunde 11.202-meetwaarde: {scale!r} / {raw_value!r}") from exc


def zeereep_source_sql() -> str:
    """Lees 11.202 uitsluitend uit de openbare, niet-vervaagde bronlaag."""
    return """
SELECT o.waarneming_id,DATE_FORMAT(DATE(o.periode_start),'%Y-%m-%d'),o.jaar,
       FLOOR(ST_X(ST_Centroid(o.openbare_geometrie))/1000),
       FLOOR(ST_Y(ST_Centroid(o.openbare_geometrie))/1000),
       o.wetenschappelijke_naam,o.schaal_telmethode,o.aantal_raw
FROM Meijendel.ndff_open_waarneming o
WHERE o.protocol LIKE '11.202%'
  AND o.soortgroep_raw='Schimmels'
  AND o.vervaagd=0
ORDER BY DATE(o.periode_start),4,5,o.wetenschappelijke_naam,o.waarneming_id;
"""


def reconstruct_zeereeppaddenstoelen(
    mysql_client: Path,
    client_args: list[str],
) -> dict[str, int]:
    """Bouw kilometerhokbezoeken en een matrix voor zes typische soorten."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    output = run_mysql(mysql_client, query_args, zeereep_source_sql(), capture=True)
    records: list[dict[str, object]] = []
    for line in output.splitlines():
        observation_id, visit_date, year, x_km, y_km, taxon, scale, raw = line.split("\t")
        records.append({
            "observation_id": int(observation_id), "date": visit_date,
            "year": int(year), "x_km": int(x_km), "y_km": int(y_km),
            "taxon": taxon, "abundance": classify_zeereep_abundance(scale, raw),
        })
    if len(records) != 3_729:
        raise ValueError("De onvervaagde 11.202-bronselectie wijkt af van het gecontroleerde profiel.")

    visits: dict[tuple[str, str], dict[str, object]] = {}
    hoks: dict[str, dict[str, object]] = {}
    abundance_rank = {
        "aanwezig": 1, "exact_1": 2, "klasse_1_3": 3,
        "klasse_4_20": 4, "klasse_21_plus": 5,
    }
    positives: dict[tuple[str, str], dict[str, object]] = {}
    for row in records:
        hok = f"{row['x_km']}-{row['y_km']}"
        visit_id = f"{hok}|{row['date']}"
        visit = visits.setdefault((hok, str(row["date"])), {
            "id": visit_id, "year": int(row["year"]), "records": 0, "taxa": set(),
        })
        visit["records"] = int(visit["records"]) + 1
        cast_taxa = visit["taxa"]
        assert isinstance(cast_taxa, set)
        cast_taxa.add(str(row["taxon"]))
        hok_row = hoks.setdefault(hok, {
            "x_km": int(row["x_km"]), "y_km": int(row["y_km"]),
            "records": 0, "visits": set(), "years": set(),
        })
        hok_row["records"] = int(hok_row["records"]) + 1
        cast_visits = hok_row["visits"]
        cast_years = hok_row["years"]
        assert isinstance(cast_visits, set) and isinstance(cast_years, set)
        cast_visits.add(visit_id)
        cast_years.add(int(row["year"]))
        taxon = str(row["taxon"])
        if taxon in ZEEREEP_TARGET_SPECIES:
            key = (visit_id, taxon)
            current = positives.get(key)
            if current is None:
                positives[key] = {"records": 1, "abundance": str(row["abundance"])}
            else:
                current["records"] = int(current["records"]) + 1
                if abundance_rank[str(row["abundance"])] > abundance_rank[str(current["abundance"])]:
                    current["abundance"] = str(row["abundance"])

    visit_keys = {
        str(meta["id"]): hashlib.sha256(str(meta["id"]).encode("utf-8")).hexdigest()
        for meta in visits.values()
    }
    hok_values: list[str] = []
    for hok, row in sorted(hoks.items()):
        years = row["years"]
        visit_set = row["visits"]
        assert isinstance(years, set) and isinstance(visit_set, set)
        hok_values.append(
            f"({sql_text(ZEEREEP_RULE_VERSION)},{sql_text(hok)},{int(row['x_km'])},"
            f"{int(row['y_km'])},'11.202',{len(visit_set)},{int(row['records'])},"
            f"{min(years)},{max(years)},{len(years)})"
        )

    visit_values: list[str] = []
    visit_note = (
        "Bezoek gereconstrueerd uit minimaal één onvervaagd 11.202-record in hetzelfde "
        "RD-kilometerhok op dezelfde datum. Bezoektijd en waarnemersbekwaamheid zijn niet meegeleverd."
    )
    for (hok, visit_date), row in sorted(visits.items()):
        taxa = row["taxa"]
        assert isinstance(taxa, set)
        season = "kernseizoen_okt_dec" if int(visit_date[5:7]) in (10, 11, 12) else "buiten_kernseizoen"
        visit_values.append(
            f"({sql_text(ZEEREEP_RULE_VERSION)},{sql_text(visit_keys[str(row['id'])])},"
            f"{sql_text(hok)},{sql_text(visit_date)},{int(row['year'])},{sql_text(season)},"
            f"{int(row['records'])},{len(taxa)},'bezoek_bevestigd_inspanning_niet_meegeleverd',"
            f"{sql_text(visit_note)})"
        )

    matrix_values: list[str] = []
    matrix_note = (
        "Protocolafgeleide nul binnen een bevestigd 11.202-hokbezoek en de zes typische "
        "doelsoorten. Gebruik als NEM-trendinvoer met de expliciete waarschuwing dat "
        "waarnemersbekwaamheid en volledige bezoektijd nog niet uit de NDFF-levering zijn gevalideerd."
    )
    for row in sorted(visits.values(), key=lambda item: str(item["id"])):
        visit_id = str(row["id"])
        for taxon in sorted(ZEEREEP_TARGET_SPECIES):
            positive = positives.get((visit_id, taxon))
            status = "waargenomen" if positive else "echte_nul"
            source_count = int(positive["records"]) if positive else 0
            abundance = str(positive["abundance"]) if positive else "geen"
            matrix_values.append(
                f"({sql_text(ZEEREEP_RULE_VERSION)},{sql_text(visit_keys[visit_id])},"
                f"{sql_text(taxon)},'typische_doelsoort',{sql_text(status)},{source_count},"
                f"{sql_text(abundance)},'bevestigd_11_202_hokbezoek',{sql_text(matrix_note)})"
            )

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {ZEEREEP_TABLE_PREFIX}_bezoek_taxon WHERE reconstructieversie={sql_text(ZEEREEP_RULE_VERSION)};",
        f"DELETE FROM {ZEEREEP_TABLE_PREFIX}_bezoek WHERE reconstructieversie={sql_text(ZEEREEP_RULE_VERSION)};",
        f"DELETE FROM {ZEEREEP_TABLE_PREFIX}_kilometerhok WHERE reconstructieversie={sql_text(ZEEREEP_RULE_VERSION)};",
    ]
    statements += _batched_insert(
        f"{ZEEREEP_TABLE_PREFIX}_kilometerhok",
        "reconstructieversie,hok_sleutel,x_km,y_km,protocol_sleutel,bezoekaantal,bronrecordaantal,eerste_jaar,laatste_jaar,jaaraantal",
        hok_values,
    )
    statements += _batched_insert(
        f"{ZEEREEP_TABLE_PREFIX}_bezoek",
        "reconstructieversie,bezoek_sleutel,hok_sleutel,bezoekdatum,jaar,seizoenstatus,bronrecordaantal,geregistreerde_taxa,inspanningstatus,kwaliteitsnotitie",
        visit_values,
    )
    statements += _batched_insert(
        f"{ZEEREEP_TABLE_PREFIX}_bezoek_taxon",
        "reconstructieversie,bezoek_sleutel,wetenschappelijke_naam,doelrelatie,waarnemingsstatus,bronrecordaantal,hoogste_nmv_klasse,nulregel,kwaliteitsnotitie",
        matrix_values,
    )
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))
    audit_output = run_mysql(
        mysql_client, query_args, zeereep_validation_sql(), capture=True,
    )
    return parse_analysis_chain_output(audit_output)


def normalize_bospaddenstoel_date(scale: str, start: str, stop: str) -> str:
    """Herstel de lokale teldatum uit de twee historische NDFF-representaties."""
    if scale == "exact aantal":
        return stop[:10]
    if scale == "voorkomen":
        return start[:10]
    raise ValueError(f"Niet ondersteunde 11.201-meetschaal: {scale!r}")


def parse_bospaddenstoel_count(scale: str, raw_value: str) -> int | None:
    """Lees alleen echte vruchtlichaamtellingen; presentie blijft ongemeten."""
    if scale == "voorkomen" and raw_value == "minimaal 1.0":
        return None
    if scale == "exact aantal" and re.fullmatch(r"[1-9][0-9]*", raw_value):
        return int(raw_value)
    raise ValueError(f"Niet ondersteunde 11.201-meetwaarde: {scale!r} / {raw_value!r}")


def select_bospaddenstoel_records(
    rows: Iterable[dict[str, object]],
) -> dict[str, dict[str, object]]:
    """Kies per meetpunt, datum en taxon de exacte regel boven presentie."""
    materialized = [dict(row) for row in rows]
    grouped: dict[tuple[int, str, str], list[dict[str, object]]] = defaultdict(list)
    for row in materialized:
        grouped[(int(row["plot"]), str(row["date"]), str(row["taxon"]))].append(row)
    selection: dict[str, dict[str, object]] = {}
    for candidates in grouped.values():
        exact = [row for row in candidates if row["scale"] == "exact aantal"]
        presence = [row for row in candidates if row["scale"] == "voorkomen"]
        if len(exact) > 1 or len(presence) > 1:
            raise ValueError("Meerdere 11.201-regels van hetzelfde representatietype binnen één resultaat.")
        canonical = exact[0] if exact else presence[0]
        canonical_identity = str(canonical["identity"])
        for row in candidates:
            identity = str(row["identity"])
            if row is canonical:
                status = "opgenomen_exact" if exact else "opgenomen_presentie"
            else:
                status = "dubbele_presentie_onderdrukt"
            selection[identity] = {
                "selectiestatus": status,
                "canonieke_identiteit": canonical_identity,
            }
    return selection


def reconstruct_bospaddenstoel_plot_families(
    rows: Iterable[dict[str, object]],
) -> dict[str, int]:
    """Koppel de exact-aantal- en presentiegeometrie van hetzelfde meetpunt."""
    geometries: dict[str, dict[str, object]] = {}
    for row in rows:
        geometry = str(row["geometry"])
        info = geometries.setdefault(geometry, {
            "x": float(row["x"]), "y": float(row["y"]),
            "scales": set(), "keys": set(),
        })
        scales = info["scales"]
        keys = info["keys"]
        assert isinstance(scales, set) and isinstance(keys, set)
        scales.add(str(row["scale"]))
        keys.add((str(row["date"]), str(row["taxon"])))

    adjacency = {geometry: set() for geometry in geometries}
    geometry_names = sorted(geometries)
    for index, left_name in enumerate(geometry_names):
        left = geometries[left_name]
        for right_name in geometry_names[index + 1:]:
            right = geometries[right_name]
            left_scales, right_scales = left["scales"], right["scales"]
            left_keys, right_keys = left["keys"], right["keys"]
            assert isinstance(left_scales, set) and isinstance(right_scales, set)
            assert isinstance(left_keys, set) and isinstance(right_keys, set)
            distance = math.hypot(
                float(left["x"]) - float(right["x"]),
                float(left["y"]) - float(right["y"]),
            )
            if distance <= 160 and left_scales != right_scales and left_keys & right_keys:
                adjacency[left_name].add(right_name)
                adjacency[right_name].add(left_name)

    components: list[set[str]] = []
    unseen = set(geometry_names)
    while unseen:
        root = min(unseen)
        stack = [root]
        component: set[str] = set()
        while stack:
            current = stack.pop()
            if current in component:
                continue
            component.add(current)
            unseen.discard(current)
            stack.extend(adjacency[current] - component)
        components.append(component)
    components.sort(key=lambda component: (
        sum(float(geometries[g]["x"]) for g in component) / len(component),
        sum(float(geometries[g]["y"]) for g in component) / len(component),
    ))
    return {
        geometry: family_id
        for family_id, component in enumerate(components, start=1)
        for geometry in component
    }


def bospaddenstoel_source_sql() -> str:
    """Lees de historische 11.201-reeks uit de niet-gevoelige bronlaag."""
    return """
SELECT o.waarneming_id,o.identiteit_sha256,o.openbare_geometrie_sha256,
       ST_X(ST_Centroid(o.openbare_geometrie)),ST_Y(ST_Centroid(o.openbare_geometrie)),
       ST_Area(o.openbare_geometrie),
       DATE_FORMAT(o.periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(o.periode_stop,'%Y-%m-%d %H:%i:%s'),
       o.wetenschappelijke_naam,o.schaal_telmethode,o.aantal_raw,o.jaar
FROM Meijendel.ndff_open_waarneming o
WHERE o.protocol LIKE '11.201%'
  AND o.soortgroep_raw='Schimmels'
  AND o.vervaagd=0
ORDER BY o.waarneming_id;
"""


def parse_hns_hoks(raw_hok: str) -> tuple[str, ...]:
    """Lees de door de openbare bronlaag geraakte RD-kilometerhokken."""
    hoks: list[str] = []
    for part in raw_hok.split("|"):
        match = re.fullmatch(r"\s*(\d+)\s*-\s*(\d+)\s*", part)
        if not match:
            raise ValueError(f"Niet ondersteund HNS-hoknummer: {raw_hok!r}")
        hoks.append(f"{int(match.group(1))} - {int(match.group(2))}")
    return tuple(sorted(set(hoks)))


def _hns_hok_xy(hok: str) -> tuple[int, int]:
    x, y = hok.split(" - ")
    return int(x), int(y)


def _hns_year_aggregate(row: dict[str, object]) -> bool:
    start = date.fromisoformat(str(row["date"]))
    stop = date.fromisoformat(str(row["stop_date"]))
    return bool(row["blurred"]) and start.month == start.day == 1 and (
        stop.year == start.year + 1 and stop.month == stop.day == 1
    )


def reconstruct_hns_candidates(
    rows: Iterable[dict[str, object]],
    *,
    minimum_taxa: int = 50,
    minimum_dominant_share: float = 0.8,
) -> dict[str, object]:
    """Vorm controleerbare HNS-dagclusters zonder lijst-ID's te verzinnen.

    Naburige hokken op dezelfde datum worden als één ruimtelijk cluster gezien;
    het hok met veruit de meeste bronregels wordt het waarschijnlijke doelhok.
    De drempels herkennen volledige lijsten, maar blijven expliciet een
    reconstructieregel en geen eigenschap van het landelijke HNS-protocol.
    """
    materialized = [dict(row) for row in rows]
    record_status: dict[int, str] = {}
    record_inventory: dict[int, str | None] = {}
    dated: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in materialized:
        observation_id = int(row["observation_id"])
        if _hns_year_aggregate(row):
            record_status[observation_id] = "vervaagd_jaarrecord_niet_toegewezen"
            record_inventory[observation_id] = None
            continue
        row["hoks"] = parse_hns_hoks(str(row["hok"]))
        dated[str(row["date"])].append(row)

    inventories: dict[str, dict[str, object]] = {}
    for visit_date, date_rows in sorted(dated.items()):
        unique_hoks = sorted({hok for row in date_rows for hok in row["hoks"]})
        adjacency = {hok: set() for hok in unique_hoks}
        for index, left in enumerate(unique_hoks):
            lx, ly = _hns_hok_xy(left)
            for right in unique_hoks[index + 1:]:
                rx, ry = _hns_hok_xy(right)
                if max(abs(lx - rx), abs(ly - ry)) <= 1:
                    adjacency[left].add(right)
                    adjacency[right].add(left)

        components: list[set[str]] = []
        unseen = set(unique_hoks)
        while unseen:
            root = min(unseen)
            stack = [root]
            component: set[str] = set()
            while stack:
                current = stack.pop()
                if current in component:
                    continue
                component.add(current)
                unseen.discard(current)
                stack.extend(adjacency[current] - component)
            components.append(component)

        for component in components:
            component_rows = [
                row for row in date_rows if set(row["hoks"]) & component
            ]
            score = Counter(
                hok for row in component_rows for hok in row["hoks"] if hok in component
            )
            target_hok, _ = sorted(score.items(), key=lambda item: (-item[1], item[0]))[0]
            target_rows = sum(target_hok in row["hoks"] for row in component_rows)
            share = target_rows / len(component_rows)
            taxa = {str(row["taxon"]) for row in component_rows}
            visit_day = date.fromisoformat(visit_date)
            in_season = date(visit_day.year, 4, 27) <= visit_day <= date(
                visit_day.year, 9, 30
            )
            complete = (
                len(taxa) >= minimum_taxa
                and share >= minimum_dominant_share
                and in_season
            )
            status = "volledige_lijst_aannemelijk" if complete else "fragment"
            key_material = f"{target_hok}|{visit_date}|{'/'.join(sorted(component))}"
            inventory_key = hashlib.sha256(key_material.encode("utf-8")).hexdigest()
            inventories[inventory_key] = {
                "target_hok": target_hok,
                "date": visit_date,
                "stop_date": max(str(row["stop_date"]) for row in component_rows),
                "status": status,
                "season_status": (
                    "binnen_veldseizoen" if in_season else "buiten_veldseizoen"
                ),
                "source_record_count": len(component_rows),
                "taxa_count": len(taxa),
                "dominant_share": share,
                "taxa": taxa,
                "rows": component_rows,
            }
            selection_status = (
                "opgenomen_volledige_lijst" if complete else "opgenomen_fragment"
            )
            for row in component_rows:
                observation_id = int(row["observation_id"])
                if observation_id in record_status:
                    raise ValueError("Een HNS-record is aan meerdere inventarisaties gekoppeld.")
                record_status[observation_id] = selection_status
                record_inventory[observation_id] = inventory_key

    if len(record_status) != len(materialized):
        raise ValueError("Niet alle HNS-bronrecords kregen een selectiestatus.")
    return {
        "inventories": inventories,
        "record_status": record_status,
        "record_inventory": record_inventory,
    }


def build_hns_visit_matrix(
    *,
    complete_inventories: dict[str, set[str]],
    target_taxa: set[str],
) -> list[dict[str, str]]:
    """Maak presentie/nullen uitsluitend voor aannemelijk volledige lijsten."""
    return [
        {
            "visit": visit,
            "taxon": taxon,
            "status": "waargenomen" if taxon in observed else "echte_nul",
        }
        for visit, observed in sorted(complete_inventories.items())
        for taxon in sorted(target_taxa)
    ]


def hns_source_sql() -> str:
    """Lees 12.204 uitsluitend uit de openbare bronlaag."""
    return """
SELECT o.waarneming_id,o.identiteit_sha256,
       DATE_FORMAT(o.periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(o.periode_stop,'%Y-%m-%d %H:%i:%s'),
       o.hoknummer,o.wetenschappelijke_naam,o.vervaagd,o.oorsprong
FROM Meijendel.ndff_open_waarneming o
WHERE o.protocol LIKE '12.204%'
  AND o.soortgroep_raw='Vaatplanten'
ORDER BY o.waarneming_id;
"""


def korstmos_abundance_rank(raw: str) -> int:
    """Vertaal uitsluitend de twee in de NDFF-export aanwezige BLWG-klassen."""
    mapping = {"0.01 - 0.1": 1, "minimaal 0.1": 2}
    try:
        return mapping[raw]
    except KeyError as error:
        raise ValueError(f"Onbekende BLWG-bedekkingsklasse: {raw!r}") from error


def classify_korstmos_records(
    rows: Iterable[dict[str, object]],
) -> dict[int, dict[str, object]]:
    """Kies canonieke regels en bewaar afwijkende abundantie als conflict."""
    grouped: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for source_row in rows:
        row = dict(source_row)
        grouped[(str(row["visit"]), str(row["taxon"]))].append(row)

    result: dict[int, dict[str, object]] = {}
    for group_rows in grouped.values():
        ordered = sorted(group_rows, key=lambda row: int(row["observation_id"]))
        abundances = {str(row["abundance"]) for row in ordered}
        if len(abundances) > 1:
            for row in ordered:
                result[int(row["observation_id"])] = {
                    "selectiestatus": "abundantieconflict_bewaard",
                    "canonieke_waarneming_id": None,
                }
            continue
        canonical_id = int(ordered[0]["observation_id"])
        for index, row in enumerate(ordered):
            result[int(row["observation_id"])] = {
                "selectiestatus": (
                    "opgenomen" if index == 0 else "dubbele_registratie_onderdrukt"
                ),
                "canonieke_waarneming_id": canonical_id,
            }
    return result


def build_korstmos_visit_matrix(
    *,
    visits: set[str],
    target_taxa: set[str],
    records: Iterable[dict[str, object]],
) -> list[dict[str, object]]:
    """Maak positieve resultaten en echte nullen voor complete 02.202-lijsten."""
    positives: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for source_row in records:
        row = dict(source_row)
        positives[(str(row["visit"]), str(row["taxon"]))].append(row)

    matrix: list[dict[str, object]] = []
    for visit in sorted(visits):
        for taxon in sorted(target_taxa):
            source_rows = positives.get((visit, taxon), [])
            abundances = {str(row["abundance"]) for row in source_rows}
            if not source_rows:
                status, raw, rank = "echte_nul", None, 0
            elif len(abundances) > 1:
                status, raw, rank = "waargenomen_abundantieconflict", None, None
            else:
                raw = next(iter(abundances))
                status, rank = "waargenomen", korstmos_abundance_rank(raw)
            matrix.append({
                "visit": visit,
                "taxon": taxon,
                "status": status,
                "bedekkingsklasse_raw": raw,
                "bedekkingsrang": rank,
                "source_count": len(source_rows),
            })
    return matrix


def korstmos_source_sql() -> str:
    """Lees 02.202 uitsluitend uit de openbare, onvervaagde bronlaag."""
    return f"""
SELECT o.waarneming_id,o.identiteit_sha256,o.openbare_geometrie_sha256,
       ST_X(ST_Centroid(o.openbare_geometrie)),
       ST_Y(ST_Centroid(o.openbare_geometrie)),ST_Area(o.openbare_geometrie),
       DATE_FORMAT(DATE(o.periode_start),'%Y-%m-%d'),o.jaar,
       o.wetenschappelijke_naam,o.schaal_telmethode,o.aantal_raw,
       r.ruimtelijke_klasse,r.toewijzingskwaliteit,
       COALESCE(CAST(r.eenduidig_plot_id AS CHAR),'NULL')
FROM Meijendel.ndff_open_waarneming o
JOIN Meijendel.ndff_open_ruimtelijke_beoordeling r
  ON r.waarneming_id=o.waarneming_id
 AND r.regelversie={sql_text(RULE_VERSION)}
WHERE o.protocol LIKE '02.202%'
  AND o.soortgroep_raw='Korstmossen'
  AND o.vervaagd=0
ORDER BY o.waarneming_id;
"""


def mos_abundance_rank(raw: str) -> int:
    """Vertaal de drie BLWG-talrijkheidsklassen zonder schijnprecisie."""
    mapping = {"1.0": 1, "2.0 - 5.0": 2, "minimaal 6.0": 3}
    try:
        return mapping[raw]
    except KeyError as error:
        raise ValueError(f"Onbekende BLWG-aantalsklasse: {raw!r}") from error


def classify_mos_records(
    rows: Iterable[dict[str, object]],
) -> dict[int, dict[str, object]]:
    """Ontdubbel per hokinventarisatie en taxon; bewaar meetconflicten."""
    grouped: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for source_row in rows:
        row = dict(source_row)
        grouped[(str(row["inventory"]), str(row["taxon"]))].append(row)

    result: dict[int, dict[str, object]] = {}
    for group_rows in grouped.values():
        ordered = sorted(group_rows, key=lambda row: int(row["observation_id"]))
        measurements = {
            (str(row["scale"]), str(row["abundance"])) for row in ordered
        }
        if len(measurements) > 1:
            for row in ordered:
                result[int(row["observation_id"])] = {
                    "selectiestatus": "abundantieconflict_bewaard",
                    "canonieke_waarneming_id": None,
                }
            continue
        canonical_id = int(ordered[0]["observation_id"])
        for index, row in enumerate(ordered):
            result[int(row["observation_id"])] = {
                "selectiestatus": (
                    "opgenomen" if index == 0 else "dubbele_registratie_onderdrukt"
                ),
                "canonieke_waarneming_id": canonical_id,
            }
    return result


def build_mos_inventory_matrix(
    *,
    inventories: set[str],
    target_taxa: set[str],
    records: Iterable[dict[str, object]],
) -> list[dict[str, object]]:
    """Maak per volledige hokinventarisatie positieve resultaten en echte nullen."""
    positives: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for source_row in records:
        row = dict(source_row)
        positives[(str(row["inventory"]), str(row["taxon"]))].append(row)

    matrix: list[dict[str, object]] = []
    for inventory in sorted(inventories):
        for taxon in sorted(target_taxa):
            source_rows = positives.get((inventory, taxon), [])
            measurements = {
                (str(row["scale"]), str(row["abundance"])) for row in source_rows
            }
            if not source_rows:
                status, scale, raw, rank = "echte_nul", None, None, 0
            elif len(measurements) > 1:
                status, scale, raw, rank = (
                    "waargenomen_abundantieconflict", None, None, None
                )
            else:
                scale, raw = next(iter(measurements))
                if scale == "BLWG-aantalsklassen":
                    status, rank = "waargenomen_aantalsklasse", mos_abundance_rank(raw)
                elif scale in {"aanwezig", "voorkomen"} and raw == "minimaal 1.0":
                    status, rank = "waargenomen_presentie", None
                else:
                    raise ValueError(f"Onbekende 02.204-meetwaarde: {scale!r}, {raw!r}")
            matrix.append({
                "inventory": inventory,
                "taxon": taxon,
                "status": status,
                "scale": scale,
                "aantalsklasse_raw": raw,
                "aantalsrang": rank,
                "source_count": len(source_rows),
            })
    return matrix


def mos_source_sql() -> str:
    """Lees 02.204 uitsluitend uit de openbare, onvervaagde bronlaag."""
    return f"""
SELECT o.waarneming_id,o.identiteit_sha256,o.hoknummer,
       DATE_FORMAT(DATE(o.periode_start),'%Y-%m-%d'),
       DATE_FORMAT(DATE(o.periode_stop),'%Y-%m-%d'),o.jaar,
       o.wetenschappelijke_naam,o.schaal_telmethode,o.aantal_raw,
       o.openbare_geometrie_sha256,r.ruimtelijke_klasse,
       r.toewijzingskwaliteit
FROM Meijendel.ndff_open_waarneming o
JOIN Meijendel.ndff_open_ruimtelijke_beoordeling r
  ON r.waarneming_id=o.waarneming_id
 AND r.regelversie={sql_text(RULE_VERSION)}
WHERE o.protocol LIKE '02.204%'
  AND o.soortgroep_raw='Mossen'
  AND o.vervaagd=0
ORDER BY o.hoknummer,o.periode_start,o.waarneming_id;
"""


def classify_florbase_inventory(taxon_count: int) -> str:
    """Classificeer een 12.001-hokjaar met een transparante voorlopige drempel."""
    if taxon_count < 0:
        raise ValueError("Een taxonaantal kan niet negatief zijn.")
    return (
        "volledige_lijst_aannemelijk"
        if taxon_count >= FLORBASE_COMPLETENESS_THRESHOLD
        else "fragment"
    )


def build_florbase_inventory_matrix(
    *,
    inventories: set[str],
    target_taxa: set[str],
    records: Iterable[dict[str, object]],
) -> list[dict[str, object]]:
    """Bouw positieve regels en voorlopige protocolnullen per volledig hokjaar."""
    positives: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for source_row in records:
        row = dict(source_row)
        positives[(str(row["inventory"]), str(row["taxon"]))].append(row)

    matrix: list[dict[str, object]] = []
    for inventory in sorted(inventories):
        for taxon in sorted(target_taxa):
            source_rows = positives.get((inventory, taxon), [])
            if source_rows:
                measurements = sorted({
                    (str(row["scale"]), str(row["abundance"]))
                    for row in source_rows
                })
                presence_only = all(
                    scale in {"aanwezig", "voorkomen"}
                    and abundance == "minimaal 1.0"
                    for scale, abundance in measurements
                )
                status = "waargenomen"
                measurement_status = (
                    "alleen_presentie"
                    if presence_only
                    else "aantalsinformatie_niet_aggregeerbaar"
                )
            else:
                measurements = []
                status = "protocolnul_onder_volledigheidsaanname"
                measurement_status = "niet_van_toepassing"
            matrix.append({
                "inventory": inventory,
                "taxon": taxon,
                "status": status,
                "measurement_status": measurement_status,
                "measurements": measurements,
                "source_count": len(source_rows),
            })
    return matrix


def florbase_source_sql() -> str:
    """Lees 12.001 uitsluitend uit de openbare, onvervaagde bronlaag."""
    return """
SELECT o.waarneming_id,o.identiteit_sha256,
       FLOOR(ST_X(ST_Centroid(o.openbare_geometrie))/1000),
       FLOOR(ST_Y(ST_Centroid(o.openbare_geometrie))/1000),
       o.jaar,DATE_FORMAT(DATE(o.periode_start),'%Y-%m-%d'),
       DATE_FORMAT(DATE(o.periode_stop),'%Y-%m-%d'),
       o.wetenschappelijke_naam,o.schaal_telmethode,o.aantal_raw
FROM Meijendel.ndff_open_waarneming o
WHERE o.protocol LIKE '12.001%'
  AND o.soortgroep_raw='Vaatplanten'
  AND o.vervaagd=0
ORDER BY o.jaar,o.waarneming_id;
"""


def classify_habslak_hokjaar(
    unique_sample_locations: int,
    target_source_count: int,
) -> str:
    """Classificeer Nauwe-korfslakstatus volgens de openbare HabSlak-handleiding."""
    if unique_sample_locations < 0 or target_source_count < 0:
        raise ValueError("HabSlak-aantallen kunnen niet negatief zijn.")
    if target_source_count > 0:
        return "waargenomen"
    if unique_sample_locations >= HABSLAK_MINIMUM_SAMPLE_LOCATIONS:
        return "protocolnul_onder_doelbereikaanname"
    return "niet_beoordeelbaar_onvoldoende_bemonsterd"


def build_habslak_positive_matrix(
    records: Iterable[dict[str, object]],
) -> list[dict[str, object]]:
    """Bundel positieve monster-taxonregels zonder aantallen op te tellen."""
    grouped: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for source_row in records:
        row = dict(source_row)
        grouped[(str(row["sample"]), str(row["taxon"]))].append(row)

    matrix: list[dict[str, object]] = []
    for (sample, taxon), source_rows in sorted(grouped.items()):
        measurements = [
            {
                "schaal": str(row.get("scale") or ""),
                "waarde": str(row.get("abundance") or ""),
                "telonderwerp": str(row.get("subject") or ""),
                "determinatiemethode": str(row.get("determination") or ""),
            }
            for row in sorted(
                source_rows,
                key=lambda item: (
                    str(item.get("subject") or ""),
                    str(item.get("abundance") or ""),
                    str(item.get("determination") or ""),
                ),
            )
        ]
        matrix.append({
            "sample": sample,
            "taxon": taxon,
            "status": "waargenomen",
            "source_count": len(source_rows),
            "measurements": measurements,
        })
    return matrix


def habslak_source_sql() -> str:
    """Lees 04.006 uitsluitend uit de openbare bron- en ruimtelijke laag."""
    return f"""
SELECT o.waarneming_id,o.identiteit_sha256,COALESCE(o.hoknummer,''),
       DATE_FORMAT(DATE(o.periode_start),'%Y-%m-%d'),o.jaar,
       o.wetenschappelijke_naam,o.openbare_geometrie_sha256,
       ST_X(ST_Centroid(o.openbare_geometrie)),
       ST_Y(ST_Centroid(o.openbare_geometrie)),ST_Area(o.openbare_geometrie),
       COALESCE(o.aantal_raw,''),COALESCE(o.schaal_telmethode,''),
       COALESCE(o.telonderwerp,''),COALESCE(o.determinatiemethode,''),
       COALESCE(o.bronhouder,''),o.vervaagd,r.ruimtelijke_klasse,
       r.toewijzingskwaliteit,COALESCE(r.eenduidig_plot_id,0)
FROM Meijendel.ndff_open_waarneming o
JOIN Meijendel.ndff_open_ruimtelijke_beoordeling r
  ON r.waarneming_id=o.waarneming_id
 AND r.regelversie={sql_text(RULE_VERSION)}
WHERE o.protocol LIKE '04.006%'
  AND o.soortgroep_raw='Weekdieren'
ORDER BY o.waarneming_id;
"""


def classify_braakbal_period(start: str, stop: str) -> str:
    """Classificeer het aangeleverde broninterval zonder een bezoek te veronderstellen."""
    start_date = date.fromisoformat(start)
    stop_date = date.fromisoformat(stop)
    days = (stop_date - start_date).days
    if days < 1:
        raise ValueError("Een braakbal-broninterval moet een positieve duur hebben.")
    if days == 1:
        return "gedateerde_registratie"
    if days in {365, 366}:
        return "jaaraggregaat"
    if 730 <= days <= 732:
        return "meerjaaraggregaat"
    return "overig_interval"


def classify_braakbal_inspanning(prey_sum: int) -> str:
    """Markeer alleen de somdrempel; de oorspronkelijke partij blijft onbekend."""
    if prey_sum < 1:
        raise ValueError("Een braakbalaggregaat moet minstens één prooidier bevatten.")
    if prey_sum >= BRAAKBAL_MINIMUM_PREY:
        return "som_minimaal_150_partij_onbekend"
    return "som_minder_dan_150"


def build_braakbal_positive_aggregates(
    records: Iterable[dict[str, object]],
) -> dict[str, list[dict[str, object]]]:
    """Bundel uitsluitend positieve bronregels per openbare geometrie en jaar."""
    groups: dict[tuple[int, str], list[dict[str, object]]] = defaultdict(list)
    for source_row in records:
        row = dict(source_row)
        count = int(row["count"])
        if count < 1:
            raise ValueError("Braakbalregels zonder positief aantal zijn niet geldig.")
        groups[(int(row["year"]), str(row["geometry"]))].append(row)

    hokyears: list[dict[str, object]] = []
    taxa: list[dict[str, object]] = []
    for (year, geometry), source_rows in sorted(groups.items()):
        first = source_rows[0]
        invariant = (
            bool(first["blurred"]), first.get("blur_level"), float(first["x"]),
            float(first["y"]), float(first["area"]),
        )
        if any(
            (
                bool(row["blurred"]), row.get("blur_level"), float(row["x"]),
                float(row["y"]), float(row["area"]),
            ) != invariant
            for row in source_rows
        ):
            raise ValueError(f"Inconsistente braakbal-geometriecontext: {year}|{geometry}")

        prey_sum = sum(int(row["count"]) for row in source_rows)
        field_mouse_count = sum(
            int(row["count"])
            for row in source_rows
            if str(row["taxon"]) == "Microtus arvalis"
        )
        period_types = {
            classify_braakbal_period(str(row["start"]), str(row["stop"]))
            for row in source_rows
        }
        period_status = next(iter(period_types)) if len(period_types) == 1 else "gemengd"
        key = hashlib.sha256(f"17.002|{year}|{geometry}".encode("utf-8")).hexdigest()
        hokyears.append({
            "key": key, "year": year, "geometry": geometry,
            "x": float(first["x"]), "y": float(first["y"]),
            "area": float(first["area"]), "blurred": bool(first["blurred"]),
            "blur_level": first.get("blur_level"), "period_status": period_status,
            "source_count": len(source_rows),
            "taxon_count": len({str(row["taxon"]) for row in source_rows}),
            "prey_sum": prey_sum, "field_mouse_count": field_mouse_count,
            "field_mouse_share": field_mouse_count / prey_sum,
            "effort_status": classify_braakbal_inspanning(prey_sum),
            "zero_status": "geen_nul_afleidbaar",
        })
        by_taxon: dict[str, list[dict[str, object]]] = defaultdict(list)
        for row in source_rows:
            by_taxon[str(row["taxon"])].append(row)
        for taxon, taxon_rows in sorted(by_taxon.items()):
            total = sum(int(row["count"]) for row in taxon_rows)
            taxa.append({
                "key": key, "taxon": taxon, "status": "waargenomen",
                "source_count": len(taxon_rows), "total_count": total,
                "share": total / prey_sum,
            })
    return {"hokyears": hokyears, "taxa": taxa}


def braakbal_source_sql() -> str:
    """Lees protocol 17.002 uitsluitend uit de openbare bronlaag."""
    return """
SELECT o.waarneming_id,o.jaar,o.openbare_geometrie_sha256,
       o.wetenschappelijke_naam,CAST(o.aantal_raw AS UNSIGNED),
       DATE_FORMAT(DATE(o.periode_start),'%Y-%m-%d'),
       DATE_FORMAT(DATE(o.periode_stop),'%Y-%m-%d'),
       o.vervaagd,COALESCE(o.vervagingsniveau_km,0),
       ST_X(ST_Centroid(o.openbare_geometrie)),
       ST_Y(ST_Centroid(o.openbare_geometrie)),ST_Area(o.openbare_geometrie)
FROM Meijendel.ndff_open_waarneming o
WHERE o.protocol LIKE '17.002%'
ORDER BY o.jaar,o.waarneming_id;
"""


def classify_tuintelling_period(start: str, stop: str) -> str:
    """Classificeer het aangeleverde telinterval van Jaarrond Tuintelling."""
    start_time = datetime.fromisoformat(start)
    stop_time = datetime.fromisoformat(stop)
    minutes = int((stop_time - start_time).total_seconds() // 60)
    if minutes < 1:
        raise ValueError("Een tuintellingperiode moet een positieve duur hebben.")
    if minutes <= 15:
        return "tijdstiptelling"
    if minutes == 24 * 60:
        return "dagperiode"
    if minutes == 7 * 24 * 60:
        return "weektelling"
    return "overige_periode"


def reconstruct_tuinvakfamilies(
    geometries: Iterable[dict[str, object]],
    *,
    distance_m: float = TUINTELLING_GEOMETRY_DISTANCE_M,
) -> dict[str, str]:
    """Bundel vrijwel gelijke openbare tuinvakken zonder een tuin-ID te claimen."""
    if distance_m <= 0:
        raise ValueError("De afstandsdrempel voor tuinvakken moet positief zijn.")
    by_geometry: dict[str, tuple[float, float]] = {}
    for source_row in geometries:
        row = dict(source_row)
        geometry = str(row["geometry"])
        point = (float(row["x"]), float(row["y"]))
        if geometry in by_geometry and by_geometry[geometry] != point:
            raise ValueError(f"Inconsistente centroide voor tuingeometrie {geometry}.")
        by_geometry[geometry] = point

    remaining = set(by_geometry)
    mapping: dict[str, str] = {}
    while remaining:
        seed = min(remaining)
        component = {seed}
        frontier = [seed]
        remaining.remove(seed)
        while frontier:
            current = frontier.pop()
            x1, y1 = by_geometry[current]
            neighbours = {
                candidate for candidate in remaining
                if math.hypot(x1 - by_geometry[candidate][0], y1 - by_geometry[candidate][1])
                <= distance_m
            }
            component.update(neighbours)
            frontier.extend(sorted(neighbours))
            remaining.difference_update(neighbours)
        family = hashlib.sha256(
            ("102.002|tuinvakfamilie|" + "|".join(sorted(component))).encode("utf-8")
        ).hexdigest()
        for geometry in component:
            mapping[geometry] = family
    return mapping


def build_tuintelling_structure(
    records: Iterable[dict[str, object]],
    geometry_to_family: dict[str, str],
) -> dict[str, list[dict[str, object]]]:
    """Bouw telperioden en een lokaal begrensde soortgroepmatrix."""
    source_rows = [dict(row) for row in records]
    local_targets: dict[str, set[str]] = defaultdict(set)
    periods: dict[tuple[str, str, str], list[dict[str, object]]] = defaultdict(list)
    for row in source_rows:
        geometry = str(row["geometry"])
        if geometry not in geometry_to_family:
            raise ValueError(f"Tuintellinggeometrie zonder tuinvakfamilie: {geometry}")
        group = str(row["group"])
        taxon = str(row["taxon"])
        local_targets[group].add(taxon)
        period_key = (
            geometry_to_family[geometry], str(row["start"]), str(row["stop"])
        )
        periods[period_key].append(row)

    period_rows: list[dict[str, object]] = []
    group_period_rows: list[dict[str, object]] = []
    matrix_rows: list[dict[str, object]] = []
    for (family, start, stop), rows in sorted(periods.items()):
        period = hashlib.sha256(
            f"102.002|{family}|{start}|{stop}".encode("utf-8")
        ).hexdigest()
        groups = sorted({str(row["group"]) for row in rows})
        period_rows.append({
            "key": period, "family": family, "start": start, "stop": stop,
            "period_type": classify_tuintelling_period(start, stop),
            "source_count": len(rows), "group_count": len(groups),
            "spatial_statuses": sorted({str(row.get("spatial_status") or "onbekend") for row in rows}),
        })
        for group in groups:
            group_rows = [row for row in rows if str(row["group"]) == group]
            by_taxon: dict[str, list[dict[str, object]]] = defaultdict(list)
            for row in group_rows:
                by_taxon[str(row["taxon"])].append(row)
            group_period_rows.append({
                "period": period, "group": group,
                "source_count": len(group_rows),
                "observed_taxa": len(by_taxon),
                "local_target_taxa": len(local_targets[group]),
            })
            for taxon in sorted(local_targets[group]):
                taxon_rows = by_taxon.get(taxon, [])
                measurements = [
                    {
                        "schaal": str(row.get("scale") or ""),
                        "waarde": str(row.get("amount") or ""),
                        "stadium": str(row.get("stage") or ""),
                        "sekse": str(row.get("sex") or ""),
                    }
                    for row in sorted(
                        taxon_rows,
                        key=lambda item: (
                            str(item.get("stage") or ""),
                            str(item.get("sex") or ""),
                            int(item["observation_id"]),
                        ),
                    )
                ]
                matrix_rows.append({
                    "period": period, "group": group, "taxon": taxon,
                    "status": (
                        "waargenomen" if taxon_rows
                        else "protocolnul_binnen_lokaal_doelbereik"
                    ),
                    "source_count": len(taxon_rows),
                    "measurements": measurements,
                })
    return {
        "periods": period_rows,
        "group_periods": group_period_rows,
        "matrix": matrix_rows,
    }


def tuintelling_source_sql() -> str:
    """Lees 102.002 uit de openbare bron- en ruimtelijke laag."""
    return f"""
SELECT o.waarneming_id,o.jaar,o.openbare_geometrie_sha256,
       ST_X(ST_Centroid(o.openbare_geometrie)),
       ST_Y(ST_Centroid(o.openbare_geometrie)),ST_Area(o.openbare_geometrie),
       DATE_FORMAT(o.periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(o.periode_stop,'%Y-%m-%d %H:%i:%s'),
       o.soortgroep_raw,o.wetenschappelijke_naam,
       COALESCE(o.aantal_raw,''),COALESCE(o.schaal_telmethode,''),
       COALESCE(o.stadium,''),COALESCE(o.sekse,''),
       r.ruimtelijke_klasse,r.toewijzingskwaliteit
FROM Meijendel.ndff_open_waarneming o
JOIN Meijendel.ndff_open_ruimtelijke_beoordeling r
  ON r.waarneming_id=o.waarneming_id
 AND r.regelversie={sql_text(RULE_VERSION)}
WHERE o.protocol LIKE '102.002%'
ORDER BY o.jaar,o.waarneming_id;
"""


def classify_liveatlas_visit_spatial(
    records: Iterable[dict[str, object]],
) -> tuple[str, int | None, int | None]:
    """Vat recordgeometrieën samen zonder ze als gelopen route te presenteren."""
    rows = [dict(row) for row in records]
    if not rows:
        raise ValueError("Een LiveAtlas-bezoek moet bronrecords bevatten.")
    qualities = [str(row["spatial_quality"]) for row in rows]
    plot_pairs = {
        (int(row["plot_version"]), int(row["plot_id"]))
        for row in rows
        if row.get("plot_version") is not None and row.get("plot_id") is not None
    }
    if all(value == "single_volledig_binnen" for value in qualities) and len(plot_pairs) == 1:
        plot_version, plot_id = next(iter(plot_pairs))
        return "single_volledig_binnen", plot_version, plot_id
    if all(value == "multiple" for value in qualities):
        return "multiple", None, None
    if all(value == "outside" for value in qualities):
        return "outside", None, None
    return "gemengd", None, None


def build_liveatlas_structure(
    records: Iterable[dict[str, object]],
) -> dict[str, list[dict[str, object]]]:
    """Reconstrueer LiveAtlas-bezoeken, uitsluitend met positieve uitkomsten."""
    source_rows = [dict(row) for row in records]
    visits_by_interval: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for row in source_rows:
        start = str(row["start"])
        stop = str(row["stop"])
        if datetime.fromisoformat(stop) <= datetime.fromisoformat(start):
            raise ValueError("Een LiveAtlas-bezoek moet een positieve duur hebben.")
        if not str(row.get("amount") or "").isdigit():
            raise ValueError(
                f"LiveAtlas-record {row['observation_id']} heeft geen geheel positief aantal."
            )
        if int(str(row["amount"])) <= 0:
            raise ValueError(
                f"LiveAtlas-record {row['observation_id']} heeft geen positief aantal."
            )
        visits_by_interval[(start, stop)].append(row)

    visits: list[dict[str, object]] = []
    group_visits: list[dict[str, object]] = []
    taxa: list[dict[str, object]] = []
    record_links: list[dict[str, object]] = []
    for (start, stop), rows in sorted(visits_by_interval.items()):
        visit_key = hashlib.sha256(
            f"102.005|bezoek|{start}|{stop}".encode("utf-8")
        ).hexdigest()
        duration = int(
            (datetime.fromisoformat(stop) - datetime.fromisoformat(start)).total_seconds()
            // 60
        )
        if duration < 15:
            duration_status = "korter_dan_15"
        elif duration <= 90:
            duration_status = "binnen_advies_15_90"
        else:
            duration_status = "langer_dan_90"
        spatial_status, plot_version, plot_id = classify_liveatlas_visit_spatial(rows)
        groups = sorted({str(row["group"]) for row in rows})
        visits.append({
            "key": visit_key,
            "start": start,
            "stop": stop,
            "duration_minutes": duration,
            "duration_status": duration_status,
            "source_count": len(rows),
            "geometry_count": len({str(row["geometry"]) for row in rows}),
            "group_count": len(groups),
            "spatial_status": spatial_status,
            "plot_version": plot_version,
            "plot_id": plot_id,
        })
        for row in rows:
            record_links.append({
                "observation_id": int(row["observation_id"]),
                "visit": visit_key,
                "spatial_quality": str(row["spatial_quality"]),
                "plot_id": (
                    int(row["plot_id"]) if row.get("plot_id") is not None else None
                ),
            })
        for group in groups:
            group_rows = [row for row in rows if str(row["group"]) == group]
            by_taxon: dict[str, list[dict[str, object]]] = defaultdict(list)
            for row in group_rows:
                by_taxon[str(row["taxon"])].append(row)
            group_visits.append({
                "visit": visit_key,
                "group": group,
                "source_count": len(group_rows),
                "observed_taxa": len(by_taxon),
                "completeness_status": "niet_meegeleverd",
                "zero_status": "geen_nul_afleidbaar",
            })
            for taxon, taxon_rows in sorted(by_taxon.items()):
                measurements = [
                    {
                        "waarneming_id": int(row["observation_id"]),
                        "aantal": int(str(row["amount"])),
                        "schaal": str(row.get("scale") or ""),
                        "geometrie": str(row["geometry"]),
                        "ruimtelijke_kwaliteit": str(row["spatial_quality"]),
                    }
                    for row in sorted(
                        taxon_rows, key=lambda item: int(item["observation_id"])
                    )
                ]
                taxa.append({
                    "visit": visit_key,
                    "group": group,
                    "taxon": taxon,
                    "observation_status": "waargenomen",
                    "source_count": len(taxon_rows),
                    "total_count": sum(item["aantal"] for item in measurements),
                    "measurements": measurements,
                    "zero_rule": "geen_nul_afleidbaar",
                })
    return {
        "visits": visits,
        "group_visits": group_visits,
        "taxa": taxa,
        "record_links": record_links,
    }


def liveatlas_source_sql() -> str:
    """Lees LiveAtlas uit de openbare bron- en ruimtelijke kwaliteitslaag."""
    return f"""
SELECT o.waarneming_id,
       DATE_FORMAT(o.periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(o.periode_stop,'%Y-%m-%d %H:%i:%s'),
       o.soortgroep_raw,o.wetenschappelijke_naam,
       COALESCE(o.aantal_raw,''),COALESCE(o.schaal_telmethode,''),
       o.openbare_geometrie_sha256,r.toewijzingskwaliteit,
       r.plotversie_id,r.eenduidig_plot_id
FROM Meijendel.ndff_open_waarneming o
JOIN Meijendel.ndff_open_ruimtelijke_beoordeling r
  ON r.waarneming_id=o.waarneming_id
 AND r.regelversie={sql_text(RULE_VERSION)}
WHERE o.protocol LIKE '102.005%'
ORDER BY o.periode_start,o.periode_stop,o.waarneming_id;
"""


def classify_kwartiertelling_duration(duration_minutes: int) -> str:
    """Classificeer de aangeleverde duur zonder geldige korte tellingen uit te sluiten."""
    if duration_minutes <= 0:
        raise ValueError("Een kwartiertelling moet een positieve duur hebben.")
    if duration_minutes < 15:
        return "korter_dan_15_toegestaan"
    if duration_minutes == 15:
        return "protocolconform_15_minuten"
    return "bronafwijking_boven_15_minuten"


def build_kwartiertelling_structure(
    records: Iterable[dict[str, object]],
) -> dict[str, list[dict[str, object]]]:
    """Reconstrueer kwartiertelintervallen zonder route-, lijst- of nulclaims."""
    source_rows = [dict(row) for row in records]
    rows_by_interval: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for row in source_rows:
        start = str(row["start"])
        stop = str(row["stop"])
        duration = int(
            (datetime.fromisoformat(stop) - datetime.fromisoformat(start)).total_seconds()
            // 60
        )
        classify_kwartiertelling_duration(duration)
        if not str(row.get("amount") or "").isdigit() or int(str(row["amount"])) <= 0:
            raise ValueError(
                f"Kwartiertellingrecord {row['observation_id']} heeft geen geheel positief aantal."
            )
        rows_by_interval[(start, stop)].append(row)

    intervals: list[dict[str, object]] = []
    group_intervals: list[dict[str, object]] = []
    taxa: list[dict[str, object]] = []
    record_links: list[dict[str, object]] = []
    for (start, stop), rows in sorted(rows_by_interval.items()):
        interval_key = hashlib.sha256(
            f"102.007|telinterval|{start}|{stop}".encode("utf-8")
        ).hexdigest()
        duration = int(
            (datetime.fromisoformat(stop) - datetime.fromisoformat(start)).total_seconds()
            // 60
        )
        spatial_status, plot_version, plot_id = classify_liveatlas_visit_spatial(rows)
        groups = sorted({str(row["group"]) for row in rows})
        intervals.append({
            "key": interval_key,
            "start": start,
            "stop": stop,
            "duration_minutes": duration,
            "duration_status": classify_kwartiertelling_duration(duration),
            "source_count": len(rows),
            "geometry_count": len({str(row["geometry"]) for row in rows}),
            "group_count": len(groups),
            "spatial_status": spatial_status,
            "plot_version": plot_version,
            "plot_id": plot_id,
        })
        for row in rows:
            record_links.append({
                "observation_id": int(row["observation_id"]),
                "interval": interval_key,
                "spatial_quality": str(row["spatial_quality"]),
                "plot_id": int(row["plot_id"]) if row.get("plot_id") is not None else None,
            })
        for group in groups:
            group_rows = [row for row in rows if str(row["group"]) == group]
            by_taxon: dict[str, list[dict[str, object]]] = defaultdict(list)
            for row in group_rows:
                by_taxon[str(row["taxon"])].append(row)
            group_intervals.append({
                "interval": interval_key,
                "group": group,
                "source_count": len(group_rows),
                "observed_taxa": len(by_taxon),
                "completeness_status": (
                    "niet_meegeleverd_ononderscheidbaar_soortgericht"
                ),
                "zero_status": "geen_nul_afleidbaar",
            })
            for taxon, taxon_rows in sorted(by_taxon.items()):
                measurements = [
                    {
                        "waarneming_id": int(row["observation_id"]),
                        "aantal": int(str(row["amount"])),
                        "schaal": str(row.get("scale") or ""),
                        "geometrie": str(row["geometry"]),
                        "ruimtelijke_kwaliteit": str(row["spatial_quality"]),
                    }
                    for row in sorted(
                        taxon_rows, key=lambda item: int(item["observation_id"])
                    )
                ]
                taxa.append({
                    "interval": interval_key,
                    "group": group,
                    "taxon": taxon,
                    "observation_status": "waargenomen",
                    "source_count": len(taxon_rows),
                    "total_count": sum(item["aantal"] for item in measurements),
                    "measurements": measurements,
                    "zero_rule": "geen_nul_afleidbaar",
                })
    return {
        "intervals": intervals,
        "group_intervals": group_intervals,
        "taxa": taxa,
        "record_links": record_links,
    }


def kwartiertelling_source_sql() -> str:
    """Lees kwartiertellingen uit de openbare bron- en ruimtelijke kwaliteitslaag."""
    return f"""
SELECT o.waarneming_id,
       DATE_FORMAT(o.periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(o.periode_stop,'%Y-%m-%d %H:%i:%s'),
       o.soortgroep_raw,o.wetenschappelijke_naam,
       COALESCE(o.aantal_raw,''),COALESCE(o.schaal_telmethode,''),
       o.openbare_geometrie_sha256,r.toewijzingskwaliteit,
       r.plotversie_id,r.eenduidig_plot_id
FROM Meijendel.ndff_open_waarneming o
JOIN Meijendel.ndff_open_ruimtelijke_beoordeling r
  ON r.waarneming_id=o.waarneming_id
 AND r.regelversie={sql_text(RULE_VERSION)}
WHERE o.protocol LIKE '102.007%'
ORDER BY o.periode_start,o.periode_stop,o.waarneming_id;
"""


def reconstruct_bospaddenstoelen(
    mysql_client: Path,
    client_args: list[str],
) -> dict[str, int]:
    """Bouw meetpunten, bezoeken, echte nullen en jaarlijkse maxima voor 11.201."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    output = run_mysql(mysql_client, query_args, bospaddenstoel_source_sql(), capture=True)
    records: list[dict[str, object]] = []
    for line in output.splitlines():
        (observation_id, identity, geometry, x, y, area, start, stop, taxon,
         scale, raw, year) = line.split("\t")
        visit_date = normalize_bospaddenstoel_date(scale, start, stop)
        records.append({
            "observation_id": int(observation_id), "identity": identity,
            "geometry": geometry, "x": float(x), "y": float(y), "area": float(area),
            "start": start, "stop": stop, "date": visit_date,
            "taxon": taxon, "scale": scale, "raw": raw, "year": int(visit_date[:4]),
            "count": parse_bospaddenstoel_count(scale, raw),
            "relation": "doelsoort" if taxon in BOSPADDENSTOEL_TARGET_SPECIES else "bijvangst",
        })
    if len(records) != 982:
        raise ValueError("De onvervaagde 11.201-bronselectie wijkt af van het gecontroleerde profiel.")

    geometry_to_plot = reconstruct_bospaddenstoel_plot_families(records)
    for row in records:
        row["plot"] = geometry_to_plot[str(row["geometry"])]
    selection = select_bospaddenstoel_records(records)
    by_identity = {str(row["identity"]): row for row in records}
    canonical = [
        row for row in records
        if selection[str(row["identity"])]["selectiestatus"] != "dubbele_presentie_onderdrukt"
    ]

    geometry_rows: dict[str, dict[str, object]] = {}
    for row in records:
        geometry = str(row["geometry"])
        info = geometry_rows.setdefault(geometry, {
            "plot": int(row["plot"]), "x": float(row["x"]), "y": float(row["y"]),
            "area": float(row["area"]), "scale": str(row["scale"]),
            "records": 0, "years": set(),
        })
        info["records"] = int(info["records"]) + 1
        years = info["years"]
        assert isinstance(years, set)
        years.add(int(row["year"]))

    visits: dict[tuple[int, str], dict[str, object]] = {}
    for row in records:
        visit = visits.setdefault((int(row["plot"]), str(row["date"])), {
            "records": 0, "canonical": 0, "taxa": set(),
        })
        visit["records"] = int(visit["records"]) + 1
    for row in canonical:
        visit = visits[(int(row["plot"]), str(row["date"]))]
        visit["canonical"] = int(visit["canonical"]) + 1
        taxa = visit["taxa"]
        assert isinstance(taxa, set)
        taxa.add(str(row["taxon"]))

    plot_scope: dict[int, set[str]] = defaultdict(set)
    positive_by_visit: dict[tuple[int, str, str], dict[str, object]] = {}
    bycatch_positive_rows = 0
    for row in canonical:
        if row["relation"] == "bijvangst":
            bycatch_positive_rows += 1
            continue
        plot = int(row["plot"])
        taxon = str(row["taxon"])
        plot_scope[plot].add(taxon)
        positive_by_visit[(plot, str(row["date"]), taxon)] = row

    plot_rows: dict[int, dict[str, object]] = {}
    for row in records:
        plot = int(row["plot"])
        info = plot_rows.setdefault(plot, {"records": 0, "years": set(), "geometries": set()})
        info["records"] = int(info["records"]) + 1
        years, geometries = info["years"], info["geometries"]
        assert isinstance(years, set) and isinstance(geometries, set)
        years.add(int(row["year"]))
        geometries.add(str(row["geometry"]))

    meetpoint_values: list[str] = []
    meetpoint_note = (
        "Meetpuntfamilie gereconstrueerd uit een exact-aantal- en presentiegeometrie met "
        "dezelfde datum-taxonresultaten. Het oorspronkelijke NMV-meetpuntnummer en de "
        "terreinschets ontbreken in de NDFF-levering."
    )
    for plot, info in sorted(plot_rows.items()):
        years, geometries = info["years"], info["geometries"]
        assert isinstance(years, set) and isinstance(geometries, set)
        x = sum(float(geometry_rows[g]["x"]) for g in geometries) / len(geometries)
        y = sum(float(geometry_rows[g]["y"]) for g in geometries) / len(geometries)
        plot_visits = {date_value for plot_id, date_value in visits if plot_id == plot}
        meetpoint_values.append(
            f"({sql_text(BOSPADDENSTOEL_RULE_VERSION)},{plot},{sql_text(f'MP-{plot:02d}')},"
            f"'11.201',{x:.2f},{y:.2f},{len(geometries)},{len(plot_visits)},"
            f"{int(info['records'])},{min(years)},{max(years)},{len(years)},"
            "'conservatief_afgeleid_uit_ooit_waargenomen_telsoorten',"
            f"{sql_text(meetpoint_note)})"
        )

    geometry_values: list[str] = []
    for geometry, info in sorted(geometry_rows.items()):
        years = info["years"]
        assert isinstance(years, set)
        representation = "exact_aantal_vlak" if info["scale"] == "exact aantal" else "presentie_vlak"
        geometry_values.append(
            f"({sql_text(BOSPADDENSTOEL_RULE_VERSION)},{sql_text(geometry)},"
            f"{int(info['plot'])},{sql_text(representation)},{float(info['x']):.2f},"
            f"{float(info['y']):.2f},{float(info['area']):.2f},{int(info['records'])},"
            f"{min(years)},{max(years)})"
        )

    selection_values: list[str] = []
    for row in records:
        selected = selection[str(row["identity"])]
        canonical_row = by_identity[str(selected["canonieke_identiteit"])]
        reason = (
            "Parallelle presentieregel onderdrukt ten gunste van de exacte vruchtlichaamtelling."
            if selected["selectiestatus"] == "dubbele_presentie_onderdrukt"
            else "Canoniek positief resultaat binnen het gereconstrueerde 11.201-bezoek."
        )
        selection_values.append(
            f"({sql_text(BOSPADDENSTOEL_RULE_VERSION)},{int(row['observation_id'])},"
            f"{int(canonical_row['observation_id'])},{int(row['plot'])},{sql_text(str(row['date']))},"
            f"{sql_text(str(row['relation']))},{sql_text(str(selected['selectiestatus']))},"
            f"{sql_text(reason)})"
        )

    scope_values: list[str] = []
    for plot, taxa in sorted(plot_scope.items()):
        for taxon in sorted(taxa):
            positive_dates = sorted(
                date.fromisoformat(visit_date) for candidate_plot, visit_date, candidate_taxon
                in positive_by_visit
                if candidate_plot == plot and candidate_taxon == taxon
            )
            scope_values.append(
                f"({sql_text(BOSPADDENSTOEL_RULE_VERSION)},{plot},{sql_text(taxon)},"
                f"'doelsoort_ooit_waargenomen_op_meetpunt',{positive_dates[0].year},"
                f"{positive_dates[-1].year},{len(positive_dates)})"
            )

    visit_keys = {
        (plot, visit_date): hashlib.sha256(f"{plot}|{visit_date}".encode("utf-8")).hexdigest()
        for plot, visit_date in visits
    }
    visit_values: list[str] = []
    visit_note = (
        "Bezoek bevestigd door minimaal één canoniek 11.201-resultaat. Volledig negatieve "
        "bezoeken en zoektijd zijn niet als afzonderlijke regels door NDFF meegeleverd."
    )
    for (plot, visit_date), info in sorted(visits.items()):
        taxa = info["taxa"]
        assert isinstance(taxa, set)
        month = int(visit_date[5:7])
        season = "kernseizoen_jul_nov" if 7 <= month <= 11 else "buiten_kernseizoen"
        visit_values.append(
            f"({sql_text(BOSPADDENSTOEL_RULE_VERSION)},{sql_text(visit_keys[(plot, visit_date)])},"
            f"{plot},{sql_text(visit_date)},{int(visit_date[:4])},{sql_text(season)},"
            f"{int(info['records'])},{int(info['canonical'])},{len(taxa)},"
            f"'bezoek_bevestigd_duur_niet_meegeleverd',{sql_text(visit_note)})"
        )

    matrix_values: list[str] = []
    matrix_note = (
        "Protocolafgeleide bezoeknul voor een telsoort die op dit vaste meetpunt aantoonbaar "
        "tot het gevolgde doelbereik hoorde. De nul geldt voor vruchtlichamen op dit bezoek, "
        "niet voor afwezigheid van het mycelium of habitatgeschiktheid."
    )
    for (plot, visit_date), _info in sorted(visits.items()):
        for taxon in sorted(plot_scope[plot]):
            positive = positive_by_visit.get((plot, visit_date, taxon))
            if positive is None:
                status, count_value, source_count = "echte_nul", "0", 0
            elif positive["scale"] == "exact aantal":
                status, count_value, source_count = (
                    "waargenomen_exact", str(int(positive["count"])), 1
                )
            else:
                status, count_value, source_count = "waargenomen_presentie", "NULL", 1
            matrix_values.append(
                f"({sql_text(BOSPADDENSTOEL_RULE_VERSION)},"
                f"{sql_text(visit_keys[(plot, visit_date)])},{sql_text(taxon)},"
                f"{sql_text(status)},{count_value},{source_count},"
                f"'aantoonbaar_gevolgde_telsoort_op_bevestigd_bezoek',{sql_text(matrix_note)})"
            )

    year_values: list[str] = []
    annual_note = (
        "Jaarwaarde volgens het historische 11.201-protocol: het hoogste getelde aantal "
        "vruchtlichamen op één bezoek, niet de som van bezoeken. Alleen jaren met ten minste "
        "één uit NDFF reconstrueerbaar bezoek zijn opgenomen."
    )
    plot_years = sorted({(plot, int(visit_date[:4])) for plot, visit_date in visits})
    for plot, year in plot_years:
        year_visits = sorted(
            visit_date for candidate_plot, visit_date in visits
            if candidate_plot == plot and int(visit_date[:4]) == year
        )
        for taxon in sorted(plot_scope[plot]):
            positives = [
                positive_by_visit[(plot, visit_date, taxon)]
                for visit_date in year_visits
                if (plot, visit_date, taxon) in positive_by_visit
            ]
            exact_counts = [int(row["count"]) for row in positives if row["count"] is not None]
            if exact_counts:
                status, maximum = "maximum_exact", str(max(exact_counts))
            elif positives:
                status, maximum = "alleen_presentie", "NULL"
            else:
                status, maximum = "echte_nul", "0"
            year_values.append(
                f"({sql_text(BOSPADDENSTOEL_RULE_VERSION)},{plot},{year},{sql_text(taxon)},"
                f"{sql_text(status)},{maximum},{len(year_visits)},{len(positives)},"
                f"{sql_text(annual_note)})"
            )

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {BOSPADDENSTOEL_TABLE_PREFIX}_jaar_taxon WHERE reconstructieversie={sql_text(BOSPADDENSTOEL_RULE_VERSION)};",
        f"DELETE FROM {BOSPADDENSTOEL_TABLE_PREFIX}_bezoek_taxon WHERE reconstructieversie={sql_text(BOSPADDENSTOEL_RULE_VERSION)};",
        f"DELETE FROM {BOSPADDENSTOEL_TABLE_PREFIX}_bezoek WHERE reconstructieversie={sql_text(BOSPADDENSTOEL_RULE_VERSION)};",
        f"DELETE FROM {BOSPADDENSTOEL_TABLE_PREFIX}_doelbereik WHERE reconstructieversie={sql_text(BOSPADDENSTOEL_RULE_VERSION)};",
        f"DELETE FROM {BOSPADDENSTOEL_TABLE_PREFIX}_recordselectie WHERE reconstructieversie={sql_text(BOSPADDENSTOEL_RULE_VERSION)};",
        f"DELETE FROM {BOSPADDENSTOEL_TABLE_PREFIX}_geometrie WHERE reconstructieversie={sql_text(BOSPADDENSTOEL_RULE_VERSION)};",
        f"DELETE FROM {BOSPADDENSTOEL_TABLE_PREFIX}_meetpunt WHERE reconstructieversie={sql_text(BOSPADDENSTOEL_RULE_VERSION)};",
    ]
    for table, columns, values in (
        (f"{BOSPADDENSTOEL_TABLE_PREFIX}_meetpunt", "reconstructieversie,meetpunt_id,meetpunt_sleutel,protocol_sleutel,centrum_x_rd,centrum_y_rd,geometrieaantal,bezoekaantal,bronrecordaantal,eerste_jaar,laatste_jaar,jaaraantal,doelbereikstatus,kwaliteitsnotitie", meetpoint_values),
        (f"{BOSPADDENSTOEL_TABLE_PREFIX}_geometrie", "reconstructieversie,geometrie_sha256,meetpunt_id,representatietype,centrum_x_rd,centrum_y_rd,oppervlakte_m2,bronrecordaantal,eerste_jaar,laatste_jaar", geometry_values),
        (f"{BOSPADDENSTOEL_TABLE_PREFIX}_recordselectie", "reconstructieversie,waarneming_id,canonieke_waarneming_id,meetpunt_id,bezoekdatum,doelrelatie,selectiestatus,selectiereden", selection_values),
        (f"{BOSPADDENSTOEL_TABLE_PREFIX}_doelbereik", "reconstructieversie,meetpunt_id,wetenschappelijke_naam,afleidingsregel,eerste_jaar,laatste_jaar,positieve_bezoekaantal", scope_values),
        (f"{BOSPADDENSTOEL_TABLE_PREFIX}_bezoek", "reconstructieversie,bezoek_sleutel,meetpunt_id,bezoekdatum,jaar,seizoenstatus,bronrecordaantal,canonieke_positieve_resultaten,geregistreerde_taxa,inspanningstatus,kwaliteitsnotitie", visit_values),
        (f"{BOSPADDENSTOEL_TABLE_PREFIX}_bezoek_taxon", "reconstructieversie,bezoek_sleutel,wetenschappelijke_naam,waarnemingsstatus,aantal_vruchtlichamen,bronrecordaantal,nulregel,kwaliteitsnotitie", matrix_values),
        (f"{BOSPADDENSTOEL_TABLE_PREFIX}_jaar_taxon", "reconstructieversie,meetpunt_id,jaar,wetenschappelijke_naam,jaarstatus,maximum_vruchtlichamen,bezoekaantal,positief_bezoekaantal,kwaliteitsnotitie", year_values),
    ):
        statements += _batched_insert(table, columns, values)
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))
    audit_output = run_mysql(
        mysql_client, query_args, bospaddenstoel_validation_sql(), capture=True,
    )
    return parse_analysis_chain_output(audit_output)


def _hns_effort_status(rows: list[dict[str, object]]) -> str:
    starts = [datetime.fromisoformat(str(row["start"])) for row in rows]
    stops = [datetime.fromisoformat(str(row["stop"])) for row in rows]
    first, last = min(starts), max(stops)
    all_midnight = all(value.time().isoformat() == "00:00:00" for value in starts + stops)
    elapsed_minutes = (last - first).total_seconds() / 60
    if all_midnight and elapsed_minutes <= 24 * 60:
        return "datum_bekend_duur_onbekend"
    if first.date() != last.date() and elapsed_minutes <= 14 * 24 * 60:
        return "mogelijke_meerdageninventarisatie_binnen_14_dagen"
    if first.date() == last.date() and 4 * 60 <= elapsed_minutes <= 12 * 60:
        return "duur_binnen_4_12_uur"
    return "duur_buiten_protocol_of_onvolledig"


def reconstruct_hns(
    mysql_client: Path,
    client_args: list[str],
) -> dict[str, int]:
    """Bouw voorlopige HNS-lijsten, echte nullen en hok-jaaruitkomsten."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    output = run_mysql(mysql_client, query_args, hns_source_sql(), capture=True)
    records: list[dict[str, object]] = []
    for line in output.splitlines():
        observation_id, identity, start, stop, hok, taxon, blurred, origin = line.split("\t")
        records.append({
            "observation_id": int(observation_id),
            "identity": identity,
            "start": start,
            "stop": stop,
            "date": start[:10],
            "stop_date": stop[:10],
            "hok": hok,
            "taxon": taxon,
            "blurred": blurred == "1",
            "origin": origin,
        })
    if len(records) != 4569:
        raise ValueError("De openbare 12.204-bronselectie wijkt af van het gecontroleerde profiel.")

    reconstruction = reconstruct_hns_candidates(records)
    inventories = reconstruction["inventories"]
    record_status = reconstruction["record_status"]
    record_inventory = reconstruction["record_inventory"]
    assert (
        isinstance(inventories, dict)
        and isinstance(record_status, dict)
        and isinstance(record_inventory, dict)
    )
    complete = {
        key: info for key, info in inventories.items()
        if info["status"] == "volledige_lijst_aannemelijk"
    }
    target_taxa = {
        str(taxon) for info in complete.values() for taxon in info["taxa"]
    }
    repetitions = Counter(
        (str(info["target_hok"]), int(str(info["date"])[:4]))
        for info in complete.values()
    )

    inventory_values: list[str] = []
    inventory_note = (
        "Inventarisatie uit openbare NDFF-regels gereconstrueerd. FLORON-lijst-ID, "
        "waarnemer en deelnemersaantal ontbreken; herhaalde datumclusters zijn daarom "
        "niet bewezen onafhankelijk. De lijststatus gebruikt regelversie ndff-hns-v1."
    )
    for key, info in sorted(inventories.items()):
        rows = info["rows"]
        assert isinstance(rows, list)
        target_year = int(str(info["date"])[:4])
        repeat_status = (
            "herhaling_aanwezig_onafhankelijkheid_niet_bevestigd"
            if info["status"] == "volledige_lijst_aannemelijk"
            and repetitions[(str(info["target_hok"]), target_year)] > 1
            else "enkele_inventarisatie"
        )
        info["repeat_status"] = repeat_status
        info["effort_status"] = _hns_effort_status(rows)
        inventory_values.append(
            f"({sql_text(HNS_RULE_VERSION)},{sql_text(key)},'12.204',"
            f"{sql_text(str(info['target_hok']))},{sql_text(str(info['date']))},"
            f"{sql_text(str(info['stop_date']))},{target_year},"
            f"{sql_text(str(info['status']))},{sql_text(str(info['season_status']))},"
            f"{sql_text(str(info['effort_status']))},{sql_text(repeat_status)},"
            f"{int(info['source_record_count'])},{int(info['taxa_count'])},"
            f"{float(info['dominant_share']):.5f},{sql_text(inventory_note)})"
        )

    selection_values: list[str] = []
    for row in records:
        observation_id = int(row["observation_id"])
        status = str(record_status[observation_id])
        inventory_key = record_inventory[observation_id]
        if status == "vervaagd_jaarrecord_niet_toegewezen":
            reason = (
                "Openbare vervaging heeft de bezoekdatum vervangen door een jaarinterval; "
                "de positieve waarneming blijft bruikbaar op hok-jaarniveau maar niet voor "
                "de bezoekmatrix."
            )
            inventory_sql = "NULL"
        elif status == "opgenomen_fragment":
            reason = (
                "Datumcluster bevat te weinig taxa, ligt buiten het veldseizoen of heeft "
                "onvoldoende concentratie in één doelhok; alleen positieve aanwezigheid."
            )
            inventory_sql = sql_text(str(inventory_key))
        else:
            reason = (
                "Onderdeel van een aannemelijk volledige HNS-lijst; aantallen en dubbele "
                "vindplaatsen worden voor HNS-aanwezigheid samengenomen."
            )
            inventory_sql = sql_text(str(inventory_key))
        selection_values.append(
            f"({sql_text(HNS_RULE_VERSION)},{observation_id},{inventory_sql},"
            f"{sql_text(status)},{sql_text(reason)})"
        )

    scope_info: dict[str, dict[str, object]] = {}
    positive_counts: Counter[tuple[str, str]] = Counter()
    for key, info in complete.items():
        seen: set[str] = set()
        for row in info["rows"]:
            taxon = str(row["taxon"])
            positive_counts[(key, taxon)] += 1
            seen.add(taxon)
        for taxon in seen:
            entry = scope_info.setdefault(taxon, {"years": set(), "visits": 0})
            years = entry["years"]
            assert isinstance(years, set)
            years.add(int(str(info["date"])[:4]))
            entry["visits"] = int(entry["visits"]) + 1
    scope_values = [
        f"({sql_text(HNS_RULE_VERSION)},{sql_text(taxon)},"
        f"'waargenomen_op_aannemelijk_volledige_hns_lijst',"
        f"{min(info['years'])},{max(info['years'])},{int(info['visits'])})"
        for taxon, info in sorted(scope_info.items())
    ]

    complete_taxa = {
        key: {str(taxon) for taxon in info["taxa"]}
        for key, info in complete.items()
    }
    matrix = build_hns_visit_matrix(
        complete_inventories=complete_taxa, target_taxa=target_taxa
    )
    matrix_note = (
        "Echte nul: taxon niet gemeld op een onder ndff-hns-v1 als aannemelijk "
        "volledig geclassificeerde HNS-lijst. De bezoekeenheid en onafhankelijkheid "
        "zijn uit NDFF-regels gereconstrueerd en nog niet door FLORON bevestigd."
    )
    matrix_values = [
        f"({sql_text(HNS_RULE_VERSION)},{sql_text(row['visit'])},"
        f"{sql_text(row['taxon'])},{sql_text(row['status'])},"
        f"{positive_counts[(row['visit'], row['taxon'])]},"
        f"'niet_gemeld_op_aannemelijk_volledige_hns_lijst',{sql_text(matrix_note)})"
        for row in matrix
    ]

    by_hok_year: dict[tuple[str, int], list[str]] = defaultdict(list)
    for key, info in complete.items():
        by_hok_year[(str(info["target_hok"]), int(str(info["date"])[:4]))].append(key)
    year_note = (
        "Hok-jaaruitkomst uit aannemelijk volledige HNS-lijsten. Herhaalbezoeken zijn "
        "niet automatisch onafhankelijke tellers; gebruik de onafhankelijkheidsstatus."
    )
    year_values: list[str] = []
    for (target_hok, year), visit_keys in sorted(by_hok_year.items()):
        independence = (
            "herhaling_aanwezig_onafhankelijkheid_niet_bevestigd"
            if len(visit_keys) > 1 else "niet_van_toepassing_een_inventarisatie"
        )
        for taxon in sorted(target_taxa):
            positive_visits = sum(taxon in complete_taxa[key] for key in visit_keys)
            status = "waargenomen" if positive_visits else "echte_nul"
            year_values.append(
                f"({sql_text(HNS_RULE_VERSION)},{sql_text(target_hok)},{year},"
                f"{sql_text(taxon)},{sql_text(status)},{len(visit_keys)},"
                f"{positive_visits},{sql_text(independence)},{sql_text(year_note)})"
            )

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {HNS_TABLE_PREFIX}_hok_jaar_taxon WHERE reconstructieversie={sql_text(HNS_RULE_VERSION)};",
        f"DELETE FROM {HNS_TABLE_PREFIX}_inventarisatie_taxon WHERE reconstructieversie={sql_text(HNS_RULE_VERSION)};",
        f"DELETE FROM {HNS_TABLE_PREFIX}_doelbereik WHERE reconstructieversie={sql_text(HNS_RULE_VERSION)};",
        f"DELETE FROM {HNS_TABLE_PREFIX}_recordselectie WHERE reconstructieversie={sql_text(HNS_RULE_VERSION)};",
        f"DELETE FROM {HNS_TABLE_PREFIX}_inventarisatie WHERE reconstructieversie={sql_text(HNS_RULE_VERSION)};",
    ]
    for table, columns, values in (
        (f"{HNS_TABLE_PREFIX}_inventarisatie", "reconstructieversie,inventarisatie_sleutel,protocol_sleutel,doelhok,begindatum,einddatum,jaar,lijststatus,seizoenstatus,inspanningstatus,herhaalstatus,bronrecordaantal,geregistreerde_taxa,doelhok_aandeel,kwaliteitsnotitie", inventory_values),
        (f"{HNS_TABLE_PREFIX}_recordselectie", "reconstructieversie,waarneming_id,inventarisatie_sleutel,selectiestatus,selectiereden", selection_values),
        (f"{HNS_TABLE_PREFIX}_doelbereik", "reconstructieversie,wetenschappelijke_naam,afleidingsregel,eerste_jaar,laatste_jaar,positieve_inventarisatieaantal", scope_values),
        (f"{HNS_TABLE_PREFIX}_inventarisatie_taxon", "reconstructieversie,inventarisatie_sleutel,wetenschappelijke_naam,waarnemingsstatus,bronrecordaantal,nulregel,kwaliteitsnotitie", matrix_values),
        (f"{HNS_TABLE_PREFIX}_hok_jaar_taxon", "reconstructieversie,doelhok,jaar,wetenschappelijke_naam,jaarstatus,inventarisatieaantal,positief_inventarisatieaantal,onafhankelijkheidsstatus,kwaliteitsnotitie", year_values),
    ):
        statements += _batched_insert(table, columns, values)
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))
    audit_output = run_mysql(mysql_client, query_args, hns_validation_sql(), capture=True)
    return parse_analysis_chain_output(audit_output)


def reconstruct_korstmossen(
    mysql_client: Path,
    client_args: list[str],
) -> dict[str, int]:
    """Bouw vaste proefvlakken, bezoeken en echte nullen voor protocol 02.202."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    output = run_mysql(mysql_client, query_args, korstmos_source_sql(), capture=True)
    records: list[dict[str, object]] = []
    for line in output.splitlines():
        (observation_id, identity, geometry, x, y, area, visit_date, year,
         taxon, scale, abundance, spatial_class, assignment_quality, plot_id) = (
            line.split("\t")
        )
        visit = hashlib.sha256(f"{geometry}|{visit_date}".encode("utf-8")).hexdigest()
        records.append({
            "observation_id": int(observation_id),
            "identity": identity,
            "geometry": geometry,
            "x": float(x),
            "y": float(y),
            "area": float(area),
            "date": visit_date,
            "year": int(year),
            "taxon": taxon,
            "scale": scale,
            "abundance": abundance,
            "spatial_class": spatial_class,
            "assignment_quality": assignment_quality,
            "plot_id": None if plot_id == "NULL" else int(plot_id),
            "visit": visit,
        })
    if len(records) != KORSTMOS_RECONSTRUCTION_EXPECTED["source_records"]:
        raise ValueError(
            "De onvervaagde 02.202-bronselectie wijkt af van het gecontroleerde profiel."
        )
    for row in records:
        if row["scale"] != "BLWG-bedekkingsklassen":
            raise ValueError("02.202 bevat een onverwachte schaal/telmethode.")
        korstmos_abundance_rank(str(row["abundance"]))

    geometry_info: dict[str, dict[str, object]] = {}
    for row in records:
        geometry = str(row["geometry"])
        info = geometry_info.setdefault(geometry, {
            "x": float(row["x"]), "y": float(row["y"]), "area": float(row["area"]),
            "records": 0, "years": set(), "visits": set(), "plots": set(),
            "spatial_classes": set(), "assignment_qualities": set(),
        })
        info["records"] = int(info["records"]) + 1
        for key, value in (
            ("years", int(row["year"])), ("visits", str(row["visit"])),
            ("spatial_classes", str(row["spatial_class"])),
            ("assignment_qualities", str(row["assignment_quality"])),
        ):
            values = info[key]
            assert isinstance(values, set)
            values.add(value)
        if row["plot_id"] is not None:
            plots = info["plots"]
            assert isinstance(plots, set)
            plots.add(int(row["plot_id"]))

    geometry_ids = {
        geometry: index
        for index, (geometry, _info) in enumerate(
            sorted(
                geometry_info.items(),
                key=lambda item: (float(item[1]["x"]), float(item[1]["y"]), item[0]),
            ),
            start=1,
        )
    }
    for row in records:
        row["meetlocation"] = geometry_ids[str(row["geometry"])]

    selection = classify_korstmos_records(records)
    visits: dict[str, dict[str, object]] = {}
    for row in records:
        visit = str(row["visit"])
        info = visits.setdefault(visit, {
            "meetlocation": int(row["meetlocation"]), "date": str(row["date"]),
            "year": int(row["year"]), "rows": [], "taxa": set(),
        })
        rows = info["rows"]
        taxa = info["taxa"]
        assert isinstance(rows, list) and isinstance(taxa, set)
        rows.append(row)
        taxa.add(str(row["taxon"]))

    target_taxa = {str(row["taxon"]) for row in records}
    matrix = build_korstmos_visit_matrix(
        visits=set(visits), target_taxa=target_taxa, records=records,
    )

    meetlocation_values: list[str] = []
    location_note = (
        "Meetlocatie is de onvervaagde openbare 02.202-geometrie. Herhaalde geometrieën "
        "worden als hetzelfde vaste proefvlak behandeld; oorspronkelijke BLWG-locatie-ID "
        "en eventuele grensversies zijn niet meegeleverd."
    )
    for geometry, info in sorted(geometry_info.items(), key=lambda item: geometry_ids[item[0]]):
        years, location_visits, plots = info["years"], info["visits"], info["plots"]
        spatial_classes = info["spatial_classes"]
        assignment_qualities = info["assignment_qualities"]
        assert all(isinstance(value, set) for value in (
            years, location_visits, plots, spatial_classes, assignment_qualities,
        ))
        single = (
            spatial_classes == {"single"}
            and assignment_qualities == {"single_volledig_binnen"}
            and len(plots) == 1
        )
        spatial_status = "eenduidig_plot" if single else "meerdere_plots"
        plot_sql = str(next(iter(plots))) if single else "NULL"
        repeat_status = (
            "herhaald_vast_proefvlak" if len(location_visits) > 1 else "eenmalig_proefvlak"
        )
        meetlocation_values.append(
            f"({sql_text(KORSTMOS_RULE_VERSION)},{geometry_ids[geometry]},"
            f"{sql_text(geometry)},'02.202',{float(info['x']):.2f},{float(info['y']):.2f},"
            f"{float(info['area']):.2f},{sql_text(spatial_status)},{plot_sql},"
            f"{sql_text(repeat_status)},{len(location_visits)},{int(info['records'])},"
            f"{min(years)},{max(years)},{sql_text(location_note)})"
        )

    visit_values: list[str] = []
    visit_note = (
        "Bezoek gereconstrueerd uit dezelfde onvervaagde proefvlakgeometrie en datum. "
        "Conform 02.202 geldt dit als complete soortenlijst; exacte bezoektijd en "
        "waarnemer-ID ontbreken in de NDFF-levering."
    )
    for visit, info in sorted(visits.items()):
        visit_rows, taxa = info["rows"], info["taxa"]
        assert isinstance(visit_rows, list) and isinstance(taxa, set)
        statuses = {
            str(selection[int(row["observation_id"])]["selectiestatus"])
            for row in visit_rows
        }
        if "abundantieconflict_bewaard" in statuses:
            registration = "abundantieconflict"
        elif "dubbele_registratie_onderdrukt" in statuses:
            registration = "parallelle_registraties"
        else:
            registration = "geen_dubbelen"
        visit_values.append(
            f"({sql_text(KORSTMOS_RULE_VERSION)},{sql_text(visit)},"
            f"{int(info['meetlocation'])},{sql_text(str(info['date']))},{int(info['year'])},"
            f"{len(visit_rows)},{len(taxa)},'volledige_soortenlijst_protocolconform',"
            f"{sql_text(registration)},{sql_text(visit_note)})"
        )

    selection_values: list[str] = []
    for row in records:
        selected = selection[int(row["observation_id"])]
        status = str(selected["selectiestatus"])
        canonical = selected["canonieke_waarneming_id"]
        if status == "opgenomen":
            reason = "Canonieke positieve registratie binnen bezoek en taxon."
        elif status == "dubbele_registratie_onderdrukt":
            reason = "Gelijke parallelle registratie onderdrukt; bronregel blijft traceerbaar."
        else:
            reason = (
                "Verschillende grove NDFF-bedekkingsklassen binnen hetzelfde bezoek en taxon; "
                "beide bronregels blijven bewaard en de afgeleide abundantie is onbekend."
            )
        canonical_sql = "NULL" if canonical is None else str(int(canonical))
        selection_values.append(
            f"({sql_text(KORSTMOS_RULE_VERSION)},{int(row['observation_id'])},"
            f"{canonical_sql},{int(row['meetlocation'])},{sql_text(str(row['visit']))},"
            f"{sql_text(status)},{sql_text(reason)})"
        )

    scope_values: list[str] = []
    for taxon in sorted(target_taxa):
        positive_visits = {
            str(row["visit"]) for row in records if str(row["taxon"]) == taxon
        }
        positive_years = {
            int(row["year"]) for row in records if str(row["taxon"]) == taxon
        }
        scope_values.append(
            f"({sql_text(KORSTMOS_RULE_VERSION)},{sql_text(taxon)},"
            "'openbaar_taxon_waargenomen_op_02_202_bezoek',"
            f"{min(positive_years)},{max(positive_years)},{len(positive_visits)})"
        )

    matrix_note = (
        "Echte nul wanneer dit openbare 02.202-doeltaxon niet is gemeld op een bevestigd "
        "bezoek met protocolconform complete soortenlijst. De twee NDFF-klassen zijn een "
        "grovere weergave dan de oorspronkelijke zesdelige BLWG-abundantieschaal."
    )
    matrix_values: list[str] = []
    for row in matrix:
        raw_sql = sql_text(row["bedekkingsklasse_raw"])
        rank_sql = "NULL" if row["bedekkingsrang"] is None else str(row["bedekkingsrang"])
        matrix_values.append(
            f"({sql_text(KORSTMOS_RULE_VERSION)},{sql_text(str(row['visit']))},"
            f"{sql_text(str(row['taxon']))},{sql_text(str(row['status']))},{raw_sql},"
            f"{rank_sql},{int(row['source_count'])},"
            f"'niet_gemeld_op_volledige_02_202_soortenlijst',{sql_text(matrix_note)})"
        )

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {KORSTMOS_TABLE_PREFIX}_bezoek_taxon WHERE reconstructieversie={sql_text(KORSTMOS_RULE_VERSION)};",
        f"DELETE FROM {KORSTMOS_TABLE_PREFIX}_doelbereik WHERE reconstructieversie={sql_text(KORSTMOS_RULE_VERSION)};",
        f"DELETE FROM {KORSTMOS_TABLE_PREFIX}_recordselectie WHERE reconstructieversie={sql_text(KORSTMOS_RULE_VERSION)};",
        f"DELETE FROM {KORSTMOS_TABLE_PREFIX}_bezoek WHERE reconstructieversie={sql_text(KORSTMOS_RULE_VERSION)};",
        f"DELETE FROM {KORSTMOS_TABLE_PREFIX}_meetlocatie WHERE reconstructieversie={sql_text(KORSTMOS_RULE_VERSION)};",
    ]
    for table, columns, values in (
        (f"{KORSTMOS_TABLE_PREFIX}_meetlocatie", "reconstructieversie,meetlocatie_id,geometrie_sha256,protocol_sleutel,centrum_x_rd,centrum_y_rd,oppervlakte_m2,ruimtelijke_klasse,sovon_plot_id,herhaalstatus,bezoekaantal,bronrecordaantal,eerste_jaar,laatste_jaar,kwaliteitsnotitie", meetlocation_values),
        (f"{KORSTMOS_TABLE_PREFIX}_bezoek", "reconstructieversie,bezoek_sleutel,meetlocatie_id,bezoekdatum,jaar,bronrecordaantal,geregistreerde_taxa,lijststatus,registratiestatus,kwaliteitsnotitie", visit_values),
        (f"{KORSTMOS_TABLE_PREFIX}_recordselectie", "reconstructieversie,waarneming_id,canonieke_waarneming_id,meetlocatie_id,bezoek_sleutel,selectiestatus,selectiereden", selection_values),
        (f"{KORSTMOS_TABLE_PREFIX}_doelbereik", "reconstructieversie,wetenschappelijke_naam,afleidingsregel,eerste_jaar,laatste_jaar,positieve_bezoekaantal", scope_values),
        (f"{KORSTMOS_TABLE_PREFIX}_bezoek_taxon", "reconstructieversie,bezoek_sleutel,wetenschappelijke_naam,waarnemingsstatus,bedekkingsklasse_raw,bedekkingsrang,bronrecordaantal,nulregel,kwaliteitsnotitie", matrix_values),
    ):
        statements += _batched_insert(table, columns, values)
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))
    audit_output = run_mysql(
        mysql_client, query_args, korstmos_validation_sql(), capture=True,
    )
    return parse_analysis_chain_output(audit_output)


def reconstruct_mossen(
    mysql_client: Path,
    client_args: list[str],
) -> dict[str, int]:
    """Bouw zeven volledige 02.204-hokinventarisaties met echte nullen."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    output = run_mysql(mysql_client, query_args, mos_source_sql(), capture=True)
    records: list[dict[str, object]] = []
    for line in output.splitlines():
        (observation_id, identity, hok, start, stop, year, taxon, scale,
         abundance, geometry, spatial_class, assignment_quality) = line.split("\t")
        start_date, stop_date = date.fromisoformat(start), date.fromisoformat(stop)
        duration_days = (stop_date - start_date).days
        if duration_days == 1:
            time_precision = "dag"
        elif (
            start_date.month == start_date.day == 1
            and stop_date == date(start_date.year + 1, 1, 1)
        ):
            time_precision = "jaar"
        else:
            raise ValueError(f"Onbekende 02.204-tijdprecisie: {start} tot {stop}")
        inventory = hashlib.sha256(f"02.204|{hok}".encode("utf-8")).hexdigest()
        date_cluster = hashlib.sha256(
            f"{inventory}|{start}|{stop}".encode("utf-8")
        ).hexdigest()
        records.append({
            "observation_id": int(observation_id), "identity": identity,
            "hok": hok, "start": start, "stop": stop, "year": int(year),
            "taxon": taxon, "scale": scale, "abundance": abundance,
            "geometry": geometry, "spatial_class": spatial_class,
            "assignment_quality": assignment_quality,
            "time_precision": time_precision, "inventory": inventory,
            "date_cluster": date_cluster,
        })
    if len(records) != MOS_RECONSTRUCTION_EXPECTED["source_records"]:
        raise ValueError(
            "De onvervaagde 02.204-bronselectie wijkt af van het gecontroleerde profiel."
        )
    for row in records:
        scale, raw = str(row["scale"]), str(row["abundance"])
        if scale == "BLWG-aantalsklassen":
            mos_abundance_rank(raw)
        elif scale not in {"aanwezig", "voorkomen"} or raw != "minimaal 1.0":
            raise ValueError(f"Onbekende 02.204-meetwaarde: {scale!r}, {raw!r}")

    inventories: dict[str, dict[str, object]] = {}
    date_clusters: dict[str, dict[str, object]] = {}
    for row in records:
        inventory = str(row["inventory"])
        info = inventories.setdefault(inventory, {
            "hok": str(row["hok"]), "starts": set(), "stops": set(),
            "years": set(), "date_clusters": set(), "rows": [], "taxa": set(),
        })
        for key, value in (
            ("starts", str(row["start"])), ("stops", str(row["stop"])),
            ("years", int(row["year"])), ("date_clusters", str(row["date_cluster"])),
            ("taxa", str(row["taxon"])),
        ):
            values = info[key]
            assert isinstance(values, set)
            values.add(value)
        info_rows = info["rows"]
        assert isinstance(info_rows, list)
        info_rows.append(row)

        cluster = date_clusters.setdefault(str(row["date_cluster"]), {
            "inventory": inventory, "start": str(row["start"]),
            "stop": str(row["stop"]), "time_precision": str(row["time_precision"]),
            "rows": [], "taxa": set(), "geometries": set(),
        })
        cluster_rows = cluster["rows"]
        cluster_taxa, cluster_geometries = cluster["taxa"], cluster["geometries"]
        assert isinstance(cluster_rows, list)
        assert isinstance(cluster_taxa, set) and isinstance(cluster_geometries, set)
        cluster_rows.append(row)
        cluster_taxa.add(str(row["taxon"]))
        cluster_geometries.add(str(row["geometry"]))

    selection = classify_mos_records(records)
    target_taxa = {str(row["taxon"]) for row in records}
    matrix = build_mos_inventory_matrix(
        inventories=set(inventories), target_taxa=target_taxa, records=records,
    )

    inventory_note = (
        "Native 02.204-meeteenheid: één zo volledig mogelijk geïnventariseerd RD-"
        "kilometerhok. De protocolcode onderbouwt de volledige lijst; BLWG-lijst-ID, "
        "waarnemer en verplichte bezoekduur zijn niet in de FFV-export opgenomen. Het "
        "kilometerhok wordt niet als waarneming in ieder geraakt SOVON-plot geïnterpreteerd."
    )
    inventory_values: list[str] = []
    for inventory, info in sorted(inventories.items(), key=lambda item: str(item[1]["hok"])):
        starts, stops, years = info["starts"], info["stops"], info["years"]
        clusters, rows, taxa = info["date_clusters"], info["rows"], info["taxa"]
        assert all(isinstance(value, set) for value in (starts, stops, years, clusters, taxa))
        assert isinstance(rows, list)
        first_year, last_year = min(years), max(years)
        year_status = "binnen_een_jaar" if first_year == last_year else "overspant_jaargrens"
        inventory_values.append(
            f"({sql_text(MOS_RULE_VERSION)},{sql_text(inventory)},'02.204',"
            f"{sql_text(str(info['hok']))},{sql_text(min(starts))},{sql_text(max(stops))},"
            f"{first_year},{last_year},{sql_text(year_status)},{len(clusters)},"
            f"{len(rows)},{len(taxa)},'volledige_soortenlijst_protocolconform',"
            "'protocolconform_bezoekduur_niet_meegeleverd',"
            f"'kilometerhok_niet_naar_sovonplot_toegewezen',{sql_text(inventory_note)})"
        )

    cluster_note = (
        "Bronperiode binnen één volledige kilometerhokinventarisatie. Dit is geen "
        "zelfstandig herhaalbezoek en levert daarom niet afzonderlijk echte nullen."
    )
    cluster_values: list[str] = []
    for cluster_key, info in sorted(
        date_clusters.items(), key=lambda item: (str(item[1]["inventory"]), str(item[1]["start"]))
    ):
        rows, taxa, geometries = info["rows"], info["taxa"], info["geometries"]
        assert isinstance(rows, list)
        assert isinstance(taxa, set) and isinstance(geometries, set)
        cluster_values.append(
            f"({sql_text(MOS_RULE_VERSION)},{sql_text(cluster_key)},"
            f"{sql_text(str(info['inventory']))},{sql_text(str(info['start']))},"
            f"{sql_text(str(info['stop']))},{sql_text(str(info['time_precision']))},"
            f"{len(rows)},{len(taxa)},{len(geometries)},"
            "'onderdeel_kilometerhokinventarisatie_geen_zelfstandig_bezoek',"
            f"{sql_text(cluster_note)})"
        )

    selection_values: list[str] = []
    for row in records:
        selected = selection[int(row["observation_id"])]
        status = str(selected["selectiestatus"])
        canonical = selected["canonieke_waarneming_id"]
        if status == "opgenomen":
            reason = "Canonieke positieve registratie binnen kilometerhok en taxon."
        elif status == "dubbele_registratie_onderdrukt":
            reason = (
                "Dezelfde meetklasse is binnen de hokinventarisatie meermaals geregistreerd; "
                "de bronregel blijft traceerbaar maar telt niet als extra resultaat."
            )
        else:
            reason = (
                "Verschillende aantalsklassen binnen dezelfde hokinventarisatie en hetzelfde "
                "taxon; bronregels blijven bewaard en de afgeleide abundantie is onbekend."
            )
        canonical_sql = "NULL" if canonical is None else str(int(canonical))
        selection_values.append(
            f"({sql_text(MOS_RULE_VERSION)},{int(row['observation_id'])},{canonical_sql},"
            f"{sql_text(str(row['inventory']))},{sql_text(str(row['date_cluster']))},"
            f"{sql_text(status)},{sql_text(reason)})"
        )

    scope_values: list[str] = []
    for taxon in sorted(target_taxa):
        taxon_rows = [row for row in records if str(row["taxon"]) == taxon]
        positive_inventories = {str(row["inventory"]) for row in taxon_rows}
        years = {int(row["year"]) for row in taxon_rows}
        scope_values.append(
            f"({sql_text(MOS_RULE_VERSION)},{sql_text(taxon)},"
            "'openbaar_taxon_waargenomen_in_02_204_inventarisatie',"
            f"{min(years)},{max(years)},{len(positive_inventories)})"
        )

    matrix_note = (
        "Echte nul wanneer dit openbare 02.204-doeltaxon niet is gemeld op de complete "
        "kilometerhoklijst. Talrijkheid is uitsluitend de ordinale BLWG-klasse 1-3. "
        "Presentieregels zonder aantalsklasse en conflicten blijven daarvan gescheiden."
    )
    matrix_values: list[str] = []
    for row in matrix:
        rank_sql = "NULL" if row["aantalsrang"] is None else str(row["aantalsrang"])
        matrix_values.append(
            f"({sql_text(MOS_RULE_VERSION)},{sql_text(str(row['inventory']))},"
            f"{sql_text(str(row['taxon']))},{sql_text(str(row['status']))},"
            f"{sql_text(row['scale'])},{sql_text(row['aantalsklasse_raw'])},{rank_sql},"
            f"{int(row['source_count'])},'niet_gemeld_op_volledige_02_204_soortenlijst',"
            f"{sql_text(matrix_note)})"
        )

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {MOS_TABLE_PREFIX}_inventarisatie_taxon WHERE reconstructieversie={sql_text(MOS_RULE_VERSION)};",
        f"DELETE FROM {MOS_TABLE_PREFIX}_doelbereik WHERE reconstructieversie={sql_text(MOS_RULE_VERSION)};",
        f"DELETE FROM {MOS_TABLE_PREFIX}_recordselectie WHERE reconstructieversie={sql_text(MOS_RULE_VERSION)};",
        f"DELETE FROM {MOS_TABLE_PREFIX}_datumcluster WHERE reconstructieversie={sql_text(MOS_RULE_VERSION)};",
        f"DELETE FROM {MOS_TABLE_PREFIX}_inventarisatie WHERE reconstructieversie={sql_text(MOS_RULE_VERSION)};",
    ]
    for table, columns, values in (
        (f"{MOS_TABLE_PREFIX}_inventarisatie", "reconstructieversie,inventarisatie_sleutel,protocol_sleutel,hoknummer,begindatum,einddatum,eerste_jaar,laatste_jaar,jaarstatus,datumclusteraantal,bronrecordaantal,geregistreerde_taxa,lijststatus,inspanningstatus,plotstatus,kwaliteitsnotitie", inventory_values),
        (f"{MOS_TABLE_PREFIX}_datumcluster", "reconstructieversie,datumcluster_sleutel,inventarisatie_sleutel,periode_start,periode_stop,tijdprecisie,bronrecordaantal,geregistreerde_taxa,brongeometrieaantal,clusterstatus,kwaliteitsnotitie", cluster_values),
        (f"{MOS_TABLE_PREFIX}_recordselectie", "reconstructieversie,waarneming_id,canonieke_waarneming_id,inventarisatie_sleutel,datumcluster_sleutel,selectiestatus,selectiereden", selection_values),
        (f"{MOS_TABLE_PREFIX}_doelbereik", "reconstructieversie,wetenschappelijke_naam,afleidingsregel,eerste_jaar,laatste_jaar,positieve_inventarisatieaantal", scope_values),
        (f"{MOS_TABLE_PREFIX}_inventarisatie_taxon", "reconstructieversie,inventarisatie_sleutel,wetenschappelijke_naam,waarnemingsstatus,bron_schaal,aantalsklasse_raw,aantalsrang,bronrecordaantal,nulregel,kwaliteitsnotitie", matrix_values),
    ):
        statements += _batched_insert(table, columns, values)
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))
    audit_output = run_mysql(mysql_client, query_args, mos_validation_sql(), capture=True)
    return parse_analysis_chain_output(audit_output)


def reconstruct_florbase(
    mysql_client: Path,
    client_args: list[str],
) -> dict[str, int]:
    """Bouw voorlopige 12.001-hokjaarlijsten en een presentiematrix."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    output = run_mysql(mysql_client, query_args, florbase_source_sql(), capture=True)
    records: list[dict[str, object]] = []
    for line in output.splitlines():
        (observation_id, identity, hok_x, hok_y, year, start, stop, taxon,
         scale, abundance) = line.split("\t")
        if not taxon or not scale or not abundance:
            raise ValueError(f"Onvolledige 12.001-bronregel: {observation_id}")
        x, y, inventory_year = int(hok_x), int(hok_y), int(year)
        inventory = hashlib.sha256(
            f"12.001|{x}|{y}|{inventory_year}".encode("utf-8")
        ).hexdigest()
        records.append({
            "observation_id": int(observation_id), "identity": identity,
            "hok_x": x, "hok_y": y, "hok": f"{x}-{y}",
            "year": inventory_year, "start": start, "stop": stop,
            "taxon": taxon, "scale": scale, "abundance": abundance,
            "inventory": inventory,
        })
    if len(records) != FLORBASE_RECONSTRUCTION_EXPECTED["source_records"]:
        raise ValueError(
            "De onvervaagde 12.001-bronselectie wijkt af van het gecontroleerde profiel."
        )

    inventories: dict[str, dict[str, object]] = {}
    for row in records:
        inventory = str(row["inventory"])
        info = inventories.setdefault(inventory, {
            "hok_x": int(row["hok_x"]), "hok_y": int(row["hok_y"]),
            "hok": str(row["hok"]), "year": int(row["year"]),
            "starts": set(), "stops": set(), "dates": set(),
            "rows": [], "taxa": set(),
        })
        starts, stops, dates, taxa = (
            info["starts"], info["stops"], info["dates"], info["taxa"]
        )
        assert all(isinstance(value, set) for value in (starts, stops, dates, taxa))
        starts.add(str(row["start"]))
        stops.add(str(row["stop"]))
        dates.add(str(row["start"]))
        taxa.add(str(row["taxon"]))
        info_rows = info["rows"]
        assert isinstance(info_rows, list)
        info_rows.append(row)

    complete_inventories: set[str] = set()
    complete_records: list[dict[str, object]] = []
    for inventory, info in inventories.items():
        taxa, info_rows = info["taxa"], info["rows"]
        assert isinstance(taxa, set) and isinstance(info_rows, list)
        info["list_status"] = classify_florbase_inventory(len(taxa))
        if info["list_status"] == "volledige_lijst_aannemelijk":
            complete_inventories.add(inventory)
            complete_records.extend(info_rows)

    target_taxa = {str(row["taxon"]) for row in complete_records}
    matrix = build_florbase_inventory_matrix(
        inventories=complete_inventories,
        target_taxa=target_taxa,
        records=complete_records,
    )

    inventory_note = (
        "Native 12.001-meeteenheid: één RD-kilometerhok per jaar. De FFV-export "
        "bevat geen FLORON-lijst-ID, bezoekduur of oorspronkelijke volledigheidsvlag. "
        "Minimaal 50 geregistreerde taxa geldt daarom uitsluitend als transparante, "
        "voorlopige aanwijzing voor een volledige lijst en niet als officiële FLORON-"
        "norm. Het hok wordt niet naar afzonderlijke SOVON-plots verdeeld."
    )
    inventory_values: list[str] = []
    for inventory, info in sorted(
        inventories.items(),
        key=lambda item: (int(item[1]["year"]), int(item[1]["hok_x"]), int(item[1]["hok_y"])),
    ):
        starts, stops, dates, rows, taxa = (
            info["starts"], info["stops"], info["dates"], info["rows"], info["taxa"]
        )
        assert all(isinstance(value, set) for value in (starts, stops, dates, taxa))
        assert isinstance(rows, list)
        list_status = str(info["list_status"])
        completeness = (
            "afgeleid_minimaal_50_taxa"
            if list_status == "volledige_lijst_aannemelijk"
            else "onvoldoende_voor_nulafleiding"
        )
        inventory_values.append(
            f"({sql_text(FLORBASE_RULE_VERSION)},{sql_text(inventory)},'12.001',"
            f"{int(info['hok_x'])},{int(info['hok_y'])},{sql_text(str(info['hok']))},"
            f"{int(info['year'])},{sql_text(min(starts))},{sql_text(max(stops))},"
            f"{len(dates)},{len(rows)},{len(taxa)},{sql_text(list_status)},"
            f"{FLORBASE_COMPLETENESS_THRESHOLD},{sql_text(completeness)},"
            "'bezoekduur_en_volledigheidsvlag_niet_meegeleverd',"
            f"'kilometerhok_niet_naar_sovonplot_toegewezen',{sql_text(inventory_note)})"
        )

    selection_values: list[str] = []
    for row in records:
        list_status = str(inventories[str(row["inventory"])]["list_status"])
        if list_status == "volledige_lijst_aannemelijk":
            status = "opgenomen_volledige_lijst"
            reason = (
                "Positieve bronregel in een hokjaar met minimaal 50 geregistreerde taxa; "
                "opgenomen in de voorlopige inventarisatiematrix."
            )
        else:
            status = "opgenomen_fragment"
            reason = (
                "Positieve bronregel in een hokjaar met minder dan 50 geregistreerde taxa; "
                "bewaard als fragment en niet gebruikt om nullen af te leiden."
            )
        selection_values.append(
            f"({sql_text(FLORBASE_RULE_VERSION)},{int(row['observation_id'])},"
            f"{sql_text(str(row['inventory']))},{sql_text(status)},{sql_text(reason)})"
        )

    scope_values: list[str] = []
    for taxon in sorted(target_taxa):
        taxon_rows = [row for row in complete_records if str(row["taxon"]) == taxon]
        years = {int(row["year"]) for row in taxon_rows}
        positive_inventories = {str(row["inventory"]) for row in taxon_rows}
        scope_values.append(
            f"({sql_text(FLORBASE_RULE_VERSION)},{sql_text(taxon)},"
            "'openbaar_taxon_waargenomen_op_aannemelijk_volledige_12_001_lijst',"
            f"{min(years)},{max(years)},{len(positive_inventories)},"
            "'historische_checklistversies_niet_meegeleverd')"
        )

    matrix_note = (
        "Een niet-gemeld taxon is alleen een voorlopige protocolnul onder de aanname "
        "dat een hokjaar met minimaal 50 taxa een volledige 12.001-streeplijst is. "
        "De oorspronkelijke volledigheidsvlag, inspanning en historische checklistversie "
        "ontbreken. Positieve aantalsinformatie wordt niet over vindplaatsen opgeteld."
    )
    matrix_values: list[str] = []
    for row in matrix:
        is_zero = row["status"] == "protocolnul_onder_volledigheidsaanname"
        null_rule = (
            "niet_gemeld_op_12_001_hokjaar_met_minimaal_50_taxa"
            if is_zero else "niet_van_toepassing"
        )
        measurements_json = json.dumps([
            {"schaal": scale, "waarde": abundance}
            for scale, abundance in row["measurements"]
        ], ensure_ascii=False, separators=(",", ":"))
        matrix_values.append(
            f"({sql_text(FLORBASE_RULE_VERSION)},{sql_text(str(row['inventory']))},"
            f"{sql_text(str(row['taxon']))},{sql_text(str(row['status']))},"
            f"{sql_text(str(row['measurement_status']))},{int(row['source_count'])},"
            f"{sql_text(measurements_json)},{sql_text(null_rule)},{sql_text(matrix_note)})"
        )

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {FLORBASE_TABLE_PREFIX}_inventarisatie_taxon WHERE reconstructieversie={sql_text(FLORBASE_RULE_VERSION)};",
        f"DELETE FROM {FLORBASE_TABLE_PREFIX}_doelbereik WHERE reconstructieversie={sql_text(FLORBASE_RULE_VERSION)};",
        f"DELETE FROM {FLORBASE_TABLE_PREFIX}_recordselectie WHERE reconstructieversie={sql_text(FLORBASE_RULE_VERSION)};",
        f"DELETE FROM {FLORBASE_TABLE_PREFIX}_inventarisatie WHERE reconstructieversie={sql_text(FLORBASE_RULE_VERSION)};",
    ]
    for table, columns, values in (
        (f"{FLORBASE_TABLE_PREFIX}_inventarisatie", "reconstructieversie,inventarisatie_sleutel,protocol_sleutel,hok_x,hok_y,hoknummer,jaar,begindatum,einddatum,datumclusteraantal,bronrecordaantal,geregistreerde_taxa,lijststatus,volledigheidsdrempel_taxa,volledigheidsstatus,inspanningstatus,plotstatus,kwaliteitsnotitie", inventory_values),
        (f"{FLORBASE_TABLE_PREFIX}_recordselectie", "reconstructieversie,waarneming_id,inventarisatie_sleutel,selectiestatus,selectiereden", selection_values),
        (f"{FLORBASE_TABLE_PREFIX}_doelbereik", "reconstructieversie,wetenschappelijke_naam,afleidingsregel,eerste_jaar,laatste_jaar,positieve_inventarisatieaantal,taxonomiestatus", scope_values),
        (f"{FLORBASE_TABLE_PREFIX}_inventarisatie_taxon", "reconstructieversie,inventarisatie_sleutel,wetenschappelijke_naam,waarnemingsstatus,meetwaardestatus,bronrecordaantal,meetwaarden_json,nulregel,kwaliteitsnotitie", matrix_values),
    ):
        statements += _batched_insert(table, columns, values)
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))
    audit_output = run_mysql(mysql_client, query_args, florbase_validation_sql(), capture=True)
    return parse_analysis_chain_output(audit_output)


def reconstruct_habslak(
    mysql_client: Path,
    client_args: list[str],
) -> dict[str, int]:
    """Bouw openbare HabSlak-monsters en een voorlopige Nauwe-korfslak-hokjaarlaag."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    output = run_mysql(mysql_client, query_args, habslak_source_sql(), capture=True)
    records: list[dict[str, object]] = []
    for line in output.splitlines():
        fields = line.split("\t")
        if len(fields) != 19:
            raise ValueError(f"Onverwachte 04.006-bronregel met {len(fields)} velden.")
        (observation_id, identity, hok, visit_date, year, taxon, geometry,
         x, y, area, abundance, scale, subject, determination, source, blurred,
         spatial_class, assignment_quality, plot_id) = fields
        is_blurred = blurred == "1"
        sample = None if is_blurred else hashlib.sha256(
            f"04.006|{visit_date}|{geometry}".encode("utf-8")
        ).hexdigest()
        records.append({
            "observation_id": int(observation_id), "identity": identity,
            "hok": hok, "date": visit_date, "year": int(year), "taxon": taxon,
            "geometry": geometry, "x": float(x), "y": float(y), "area": float(area),
            "abundance": abundance, "scale": scale, "subject": subject,
            "determination": determination, "source": source,
            "blurred": is_blurred, "spatial_class": spatial_class,
            "assignment_quality": assignment_quality, "plot_id": int(plot_id),
            "sample": sample,
        })
    if len(records) != HABSLAK_RECONSTRUCTION_EXPECTED["source_records"]:
        raise ValueError("De 04.006-bronselectie wijkt af van het gecontroleerde profiel.")

    unblurred = [row for row in records if not bool(row["blurred"])]
    samples: dict[str, dict[str, object]] = {}
    for row in unblurred:
        sample = str(row["sample"])
        info = samples.setdefault(sample, {
            "date": str(row["date"]), "year": int(row["year"]),
            "hok": str(row["hok"]), "geometry": str(row["geometry"]),
            "x": float(row["x"]), "y": float(row["y"]), "area": float(row["area"]),
            "assignment_quality": str(row["assignment_quality"]),
            "plot_id": int(row["plot_id"]), "rows": [], "taxa": set(),
        })
        invariant = (
            str(row["date"]), int(row["year"]), str(row["hok"]),
            str(row["geometry"]), str(row["assignment_quality"]), int(row["plot_id"]),
        )
        expected = (
            info["date"], info["year"], info["hok"], info["geometry"],
            info["assignment_quality"], info["plot_id"],
        )
        if invariant != expected:
            raise ValueError(f"Inconsistente 04.006-monstercontext: {sample}")
        sample_rows, taxa = info["rows"], info["taxa"]
        assert isinstance(sample_rows, list) and isinstance(taxa, set)
        sample_rows.append(row)
        taxa.add(str(row["taxon"]))

    matrix = build_habslak_positive_matrix(unblurred)
    target = "Vertigo angustior"
    target_counts: Counter[tuple[str, int]] = Counter(
        (str(row["hok"]), int(row["year"]))
        for row in records if str(row["taxon"]) == target
    )
    hokyears: dict[tuple[str, int], dict[str, object]] = {}
    for sample, info in samples.items():
        key = (str(info["hok"]), int(info["year"]))
        item = hokyears.setdefault(key, {"samples": set(), "geometries": set()})
        item_samples, item_geometries = item["samples"], item["geometries"]
        assert isinstance(item_samples, set) and isinstance(item_geometries, set)
        item_samples.add(sample)
        item_geometries.add(str(info["geometry"]))

    common_note = (
        "Openbare reconstructie van protocol 04.006. Een monster is afgeleid uit "
        "kalenderdatum en onvervaagde openbare geometrie. De export bevat geen "
        "oorspronkelijk monster-ID, monstertype of doelsoort per veldformulier. "
        "Meetwaarden met verschillende telonderwerpen blijven afzonderlijk in JSON "
        "en worden niet opgeteld. Exacte beschermde vindplaatsen zijn niet gekopieerd."
    )
    sample_values: list[str] = []
    for sample, info in sorted(samples.items(), key=lambda item: (item[1]["date"], item[0])):
        sample_rows, taxa = info["rows"], info["taxa"]
        assert isinstance(sample_rows, list) and isinstance(taxa, set)
        quality = str(info["assignment_quality"])
        plot_id = int(info["plot_id"]) if quality == "single_volledig_binnen" else 0
        sample_values.append(
            f"({sql_text(HABSLAK_RULE_VERSION)},{sql_text(sample)},'04.006',"
            f"{sql_text(str(info['date']))},{int(info['year'])},{sql_text(str(info['hok']))},"
            f"{sql_text(str(info['geometry']))},{float(info['x']):.3f},{float(info['y']):.3f},"
            f"{float(info['area']):.3f},{plot_id if plot_id else 'NULL'},"
            f"{sql_text(quality)},{len(sample_rows)},{len(taxa)},"
            f"'monstertype_niet_meegeleverd',{sql_text(common_note)})"
        )

    selection_values: list[str] = []
    for row in records:
        is_target = str(row["taxon"]) in HABSLAK_TARGET_SPECIES
        relation = "doelsoort" if is_target else "begeleidende_soort"
        if not bool(row["blurred"]):
            status = "opgenomen_monstercontext"
            reason = "Onvervaagde openbare positieve bronregel, gekoppeld aan datum-geometriemonster."
        elif is_target:
            status = "vervaagde_doelsoort_alleen_hokjaar"
            reason = "Vervaagde openbare doelsoortregel; uitsluitend gebruikt als positieve hokjaarstatus."
        else:
            status = "vervaagde_bijvangst_alleen_positief"
            reason = "Vervaagde begeleidende soort; alleen positieve verspreidingsinformatie, geen monster- of nulafleiding."
        selection_values.append(
            f"({sql_text(HABSLAK_RULE_VERSION)},{int(row['observation_id'])},"
            f"{sql_text(str(row['sample'])) if row['sample'] else 'NULL'},"
            f"{sql_text(status)},{sql_text(relation)},{sql_text(reason)})"
        )

    matrix_note = (
        "Positieve soortregistratie binnen een gereconstrueerd openbaar HabSlak-monster. "
        "Niet-gemelde begeleidende soorten zijn onbekend en worden nooit als nul ingevuld."
    )
    matrix_values: list[str] = []
    for row in matrix:
        relation = "doelsoort" if str(row["taxon"]) in HABSLAK_TARGET_SPECIES else "begeleidende_soort"
        measurements_json = json.dumps(
            row["measurements"], ensure_ascii=False, separators=(",", ":")
        )
        matrix_values.append(
            f"({sql_text(HABSLAK_RULE_VERSION)},{sql_text(str(row['sample']))},"
            f"{sql_text(str(row['taxon']))},{sql_text(relation)},'waargenomen',"
            f"{int(row['source_count'])},{sql_text(measurements_json)},"
            f"'niet_van_toepassing',{sql_text(matrix_note)})"
        )

    hokyear_note = (
        "Volgens de openbare HabSlak-handleiding geldt een kilometerhok voor Nauwe "
        "korfslak als voldoende onderzocht bij minimaal 15 kansrijke monsterlocaties. "
        "Omdat doelbereik en oorspronkelijke formulieren ontbreken, is een niet-detectie "
        "hoogstens een protocolnul onder doelbereikaanname. Begeleidende soorten krijgen "
        "geen nullen."
    )
    hokyear_values: list[str] = []
    for (hok, year), info in sorted(hokyears.items(), key=lambda item: (item[0][1], item[0][0])):
        sample_set, geometry_set = info["samples"], info["geometries"]
        assert isinstance(sample_set, set) and isinstance(geometry_set, set)
        count = target_counts[(hok, year)]
        status = classify_habslak_hokjaar(len(geometry_set), count)
        sampling = (
            "voldoende_minimaal_15"
            if len(geometry_set) >= HABSLAK_MINIMUM_SAMPLE_LOCATIONS
            else "onvoldoende_minder_dan_15"
        )
        key = hashlib.sha256(f"04.006|{hok}|{year}|{target}".encode("utf-8")).hexdigest()
        hokyear_values.append(
            f"({sql_text(HABSLAK_RULE_VERSION)},{sql_text(key)},'04.006',"
            f"{sql_text(hok)},{year},{sql_text(target)},{len(sample_set)},"
            f"{len(geometry_set)},{HABSLAK_MINIMUM_SAMPLE_LOCATIONS},"
            f"{sql_text(sampling)},{count},{sql_text(status)},{sql_text(hokyear_note)})"
        )

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {HABSLAK_TABLE_PREFIX}_monster_taxon WHERE reconstructieversie={sql_text(HABSLAK_RULE_VERSION)};",
        f"DELETE FROM {HABSLAK_TABLE_PREFIX}_recordselectie WHERE reconstructieversie={sql_text(HABSLAK_RULE_VERSION)};",
        f"DELETE FROM {HABSLAK_TABLE_PREFIX}_hokjaar WHERE reconstructieversie={sql_text(HABSLAK_RULE_VERSION)};",
        f"DELETE FROM {HABSLAK_TABLE_PREFIX}_monster WHERE reconstructieversie={sql_text(HABSLAK_RULE_VERSION)};",
    ]
    for table, columns, values in (
        (f"{HABSLAK_TABLE_PREFIX}_monster", "reconstructieversie,monster_sleutel,protocol_sleutel,bezoekdatum,jaar,hoknummer,openbare_geometrie_sha256,centroide_x_rd,centroide_y_rd,oppervlakte_m2,eenduidig_plot_id,plotstatus,bronrecordaantal,geregistreerde_taxa,doelbereikstatus,kwaliteitsnotitie", sample_values),
        (f"{HABSLAK_TABLE_PREFIX}_recordselectie", "reconstructieversie,waarneming_id,monster_sleutel,selectiestatus,doelrelatie,selectiereden", selection_values),
        (f"{HABSLAK_TABLE_PREFIX}_monster_taxon", "reconstructieversie,monster_sleutel,wetenschappelijke_naam,doelrelatie,waarnemingsstatus,bronrecordaantal,meetwaarden_json,nulstatus,kwaliteitsnotitie", matrix_values),
        (f"{HABSLAK_TABLE_PREFIX}_hokjaar", "reconstructieversie,hokjaar_sleutel,protocol_sleutel,hoknummer,jaar,doelsoort,monsteraantal,unieke_monsterlocaties,minimale_monsterlocaties,bemonsteringsstatus,doelsoort_bronrecordaantal,doelsoortstatus,kwaliteitsnotitie", hokyear_values),
    ):
        statements += _batched_insert(table, columns, values)
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))
    audit_output = run_mysql(mysql_client, query_args, habslak_validation_sql(), capture=True)
    return parse_analysis_chain_output(audit_output)


def reconstruct_braakballen(
    mysql_client: Path,
    client_args: list[str],
) -> dict[str, int]:
    """Bouw een conservatieve regionale positieve laag voor protocol 17.002."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    output = run_mysql(mysql_client, query_args, braakbal_source_sql(), capture=True)
    records: list[dict[str, object]] = []
    for line in output.splitlines():
        fields = line.split("\t")
        if len(fields) != 12:
            raise ValueError(f"Onverwachte 17.002-bronregel met {len(fields)} velden.")
        (observation_id, year, geometry, taxon, count, start, stop, blurred,
         blur_level, x, y, area) = fields
        records.append({
            "observation_id": int(observation_id), "year": int(year),
            "geometry": geometry, "taxon": taxon, "count": int(count),
            "start": start, "stop": stop, "blurred": blurred == "1",
            "blur_level": int(blur_level) or None,
            "x": float(x), "y": float(y), "area": float(area),
        })
    if len(records) != BRAAKBAL_RECONSTRUCTION_EXPECTED["source_records"]:
        raise ValueError("De 17.002-bronselectie wijkt af van het gecontroleerde profiel.")

    result = build_braakbal_positive_aggregates(records)
    hokyears = result["hokyears"]
    taxa = result["taxa"]
    key_by_group = {
        (int(row["year"]), str(row["geometry"])): str(row["key"])
        for row in hokyears
    }
    common_note = (
        "Openbare reconstructie van braakbalprotocol 17.002. De meeste regels zijn "
        "tot een 10 x 10 km-vlak vervaagd en oorspronkelijke partij- en nest-ID's "
        "ontbreken. De prooisom kan daarom meerdere partijen omvatten. Ook bij een "
        "som van minimaal 150 worden geen echte nullen, lokale bezoeken of "
        "SOVON-plotkoppelingen afgeleid. Alleen positieve regionale samenstelling "
        "en indicatieve verandering in registraties zijn toegestaan."
    )
    hokyear_values: list[str] = []
    for row in hokyears:
        blurred = bool(row["blurred"])
        spatial_status = "vervaagd_10km" if blurred else "onvervaagd_bronvlak"
        blur_level = row["blur_level"] if blurred else None
        hokyear_values.append(
            f"({sql_text(BRAAKBAL_RULE_VERSION)},{sql_text(str(row['key']))},'17.002',"
            f"{int(row['year'])},{sql_text(str(row['geometry']))},"
            f"{float(row['x']):.3f},{float(row['y']):.3f},{float(row['area']):.3f},"
            f"{1 if blurred else 0},{int(blur_level) if blur_level is not None else 'NULL'},"
            f"{sql_text(str(row['period_status']))},{int(row['source_count'])},"
            f"{int(row['taxon_count'])},{int(row['prey_sum'])},"
            f"{int(row['field_mouse_count'])},{float(row['field_mouse_share']):.8f},"
            f"{sql_text(str(row['effort_status']))},{sql_text(spatial_status)},"
            f"'geen_nul_afleidbaar','niet_gekoppeld_grove_brongeometrie',"
            f"{sql_text(common_note)})"
        )

    selection_values: list[str] = []
    for row in records:
        key = key_by_group[(int(row["year"]), str(row["geometry"]))]
        if bool(row["blurred"]):
            status = "vervaagd_regionale_positieve_context"
            reason = (
                "Positieve bronregel binnen een vervaagd 10 x 10 km-hok; alleen "
                "regionale samenstelling, geen lokale aanwezigheid of plottoewijzing."
            )
        else:
            status = "onvervaagd_losse_protocolregistratie"
            reason = (
                "Onvervaagde positieve protocolregel zonder volledige "
                "braakbalpartij; geen bezoek-, nul- of inspanningsafleiding."
            )
        selection_values.append(
            f"({sql_text(BRAAKBAL_RULE_VERSION)},{int(row['observation_id'])},"
            f"{sql_text(key)},{sql_text(status)},{sql_text(reason)})"
        )

    taxon_note = (
        "Positieve taxonsamenstelling per openbaar bronvlak en jaar. Herhaalde "
        "taxonregels zijn samengevoegd; aantallen gelden niet als lokale abundantie "
        "omdat oorspronkelijke braakbalpartijen niet kunnen worden onderscheiden."
    )
    taxon_values = [
        f"({sql_text(BRAAKBAL_RULE_VERSION)},{sql_text(str(row['key']))},"
        f"{sql_text(str(row['taxon']))},'waargenomen',{int(row['source_count'])},"
        f"{int(row['total_count'])},{float(row['share']):.8f},"
        f"'niet_van_toepassing_positief',{sql_text(taxon_note)})"
        for row in taxa
    ]

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {BRAAKBAL_TABLE_PREFIX}_hokjaar_taxon WHERE reconstructieversie={sql_text(BRAAKBAL_RULE_VERSION)};",
        f"DELETE FROM {BRAAKBAL_TABLE_PREFIX}_recordselectie WHERE reconstructieversie={sql_text(BRAAKBAL_RULE_VERSION)};",
        f"DELETE FROM {BRAAKBAL_TABLE_PREFIX}_hokjaar WHERE reconstructieversie={sql_text(BRAAKBAL_RULE_VERSION)};",
    ]
    for table, columns, values in (
        (f"{BRAAKBAL_TABLE_PREFIX}_hokjaar", "reconstructieversie,hokjaar_sleutel,protocol_sleutel,jaar,openbare_geometrie_sha256,centroide_x_rd,centroide_y_rd,oppervlakte_m2,vervaagd,vervagingsniveau_km,bronperiodestatus,bronrecordaantal,geregistreerde_taxa,som_prooidieren,veldmuis_aantal,veldmuis_aandeel,inspanningsstatus,ruimtelijke_status,nulstatus,plotstatus,kwaliteitsnotitie", hokyear_values),
        (f"{BRAAKBAL_TABLE_PREFIX}_recordselectie", "reconstructieversie,waarneming_id,hokjaar_sleutel,selectiestatus,selectiereden", selection_values),
        (f"{BRAAKBAL_TABLE_PREFIX}_hokjaar_taxon", "reconstructieversie,hokjaar_sleutel,wetenschappelijke_naam,waarnemingsstatus,bronrecordaantal,totaal_aantal,aandeel_prooidieren,nulstatus,kwaliteitsnotitie", taxon_values),
    ):
        statements += _batched_insert(table, columns, values)
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))
    audit_output = run_mysql(mysql_client, query_args, braakbal_validation_sql(), capture=True)
    return parse_analysis_chain_output(audit_output)


def reconstruct_tuintellingen(
    mysql_client: Path,
    client_args: list[str],
) -> dict[str, int]:
    """Bouw openbare tuinvlak-, telperiode- en lokaal begrensde nulstructuur."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    output = run_mysql(mysql_client, query_args, tuintelling_source_sql(), capture=True)
    records: list[dict[str, object]] = []
    for line in output.splitlines():
        fields = line.split("\t")
        if len(fields) != 16:
            raise ValueError(f"Onverwachte 102.002-bronregel met {len(fields)} velden.")
        (observation_id, year, geometry, x, y, area, start, stop, group, taxon,
         amount, scale, stage, sex, spatial_class, assignment_quality) = fields
        records.append({
            "observation_id": int(observation_id), "year": int(year),
            "geometry": geometry, "x": float(x), "y": float(y),
            "area": float(area), "start": start, "stop": stop,
            "group": group, "taxon": taxon, "amount": amount,
            "scale": scale, "stage": stage, "sex": sex,
            "spatial_class": spatial_class,
            "spatial_status": assignment_quality,
        })
    if len(records) != TUINTELLING_RECONSTRUCTION_EXPECTED["source_records"]:
        raise ValueError("De 102.002-bronselectie wijkt af van het gecontroleerde profiel.")

    geometry_to_family = reconstruct_tuinvakfamilies(records)
    structure = build_tuintelling_structure(records, geometry_to_family)
    periods = structure["periods"]
    group_periods = structure["group_periods"]
    matrix = structure["matrix"]
    period_key_by_source = {
        (str(row["family"]), str(row["start"]), str(row["stop"])): str(row["key"])
        for row in periods
    }

    common_note = (
        "Openbare reconstructie van protocol 102.002. Bij iedere telling kiest de "
        "teller soortgroepen en meldt daarbinnen alle waargenomen soorten. Een "
        "positieve regel bewijst daarom alleen dat die soortgroep in deze periode "
        "is geteld. Oorspronkelijke tuin- en telling-ID's ontbreken; openbare "
        "250 m-geometrieën zijn geen bewezen tuinen. Alle records liggen buiten "
        "een eenduidig Meijendel-SOVON-plot."
    )
    geometries: dict[str, dict[str, object]] = {}
    families: dict[str, dict[str, object]] = {}
    for row in records:
        geometry = str(row["geometry"])
        family = geometry_to_family[geometry]
        geom = geometries.setdefault(geometry, {
            "family": family, "x": float(row["x"]), "y": float(row["y"]),
            "area": float(row["area"]), "years": set(), "rows": [],
            "statuses": set(),
        })
        invariant = (geom["family"], geom["x"], geom["y"], geom["area"])
        if invariant != (family, float(row["x"]), float(row["y"]), float(row["area"])):
            raise ValueError(f"Inconsistente 102.002-geometriecontext: {geometry}")
        geom_years, geom_rows, geom_statuses = geom["years"], geom["rows"], geom["statuses"]
        assert isinstance(geom_years, set) and isinstance(geom_rows, list)
        assert isinstance(geom_statuses, set)
        geom_years.add(int(row["year"]))
        geom_rows.append(row)
        geom_statuses.add(str(row["spatial_status"]))

        family_info = families.setdefault(family, {
            "geometries": set(), "starts": [], "stops": [], "rows": [],
        })
        family_geometries = family_info["geometries"]
        family_starts, family_stops, family_rows = (
            family_info["starts"], family_info["stops"], family_info["rows"]
        )
        assert isinstance(family_geometries, set)
        assert isinstance(family_starts, list) and isinstance(family_stops, list)
        assert isinstance(family_rows, list)
        family_geometries.add(geometry)
        family_starts.append(str(row["start"]))
        family_stops.append(str(row["stop"]))
        family_rows.append(row)

    family_values: list[str] = []
    for family, info in sorted(families.items()):
        family_geometries, family_starts, family_stops, family_rows = (
            info["geometries"], info["starts"], info["stops"], info["rows"]
        )
        assert isinstance(family_geometries, set)
        assert isinstance(family_starts, list) and isinstance(family_stops, list)
        assert isinstance(family_rows, list)
        family_values.append(
            f"({sql_text(TUINTELLING_RULE_VERSION)},{sql_text(family)},'102.002',"
            f"{len(family_geometries)},{sql_text(min(family_starts))},"
            f"{sql_text(max(family_stops))},{len(family_rows)},"
            f"'afgeleid_binnen_1_meter_geen_tuin_id',{sql_text(common_note)})"
        )

    geometry_values: list[str] = []
    for geometry, info in sorted(geometries.items()):
        years, geom_rows, statuses = info["years"], info["rows"], info["statuses"]
        assert isinstance(years, set) and isinstance(geom_rows, list)
        assert isinstance(statuses, set)
        spatial_status = next(iter(statuses)) if len(statuses) == 1 else "gemengd"
        geometry_values.append(
            f"({sql_text(TUINTELLING_RULE_VERSION)},{sql_text(geometry)},"
            f"{sql_text(str(info['family']))},{float(info['x']):.3f},"
            f"{float(info['y']):.3f},{float(info['area']):.3f},"
            f"{min(years)},{max(years)},{len(geom_rows)},"
            f"{sql_text(spatial_status)},{sql_text(common_note)})"
        )

    period_note = (
        "Gereconstrueerde telperiode op basis van tuinvakfamilie plus exact "
        "broninterval. Dit is geen oorspronkelijk telling-ID. De levering eindigt "
        "voor de vernieuwing van Jaarrond Tuintelling in juli 2022."
    )
    period_values = [
        f"({sql_text(TUINTELLING_RULE_VERSION)},{sql_text(str(row['key']))},"
        f"{sql_text(str(row['family']))},{sql_text(str(row['start']))},"
        f"{sql_text(str(row['stop']))},{sql_text(str(row['period_type']))},"
        f"'voor_vernieuwing_2022',{int(row['source_count'])},"
        f"{int(row['group_count'])},'niet_gekoppeld_geen_meijendelplot',"
        f"{sql_text(period_note)})"
        for row in periods
    ]

    group_note = (
        "Minstens één positieve regel bevestigt dat deze soortgroep tijdens de "
        "telperiode is geteld. Het doelbereik omvat voorlopig alleen de taxa die "
        "ergens in deze lokale 102.002-levering zijn aangetroffen."
    )
    group_values = [
        f"({sql_text(TUINTELLING_RULE_VERSION)},{sql_text(str(row['period']))},"
        f"{sql_text(str(row['group']))},{int(row['source_count'])},"
        f"{int(row['observed_taxa'])},{int(row['local_target_taxa'])},"
        f"'positieve_regel_bevestigt_getelde_soortgroep',"
        f"'alleen_lokaal_aangetroffen_taxa',{sql_text(group_note)})"
        for row in group_periods
    ]

    matrix_note = (
        "Een nul betekent uitsluitend: niet gemeld binnen een door een positieve "
        "regel bevestigde soortgroeptelling en binnen het lokale doelbereik. De nul "
        "geldt niet voor alle landelijke tuinsoorten en niet voor een Meijendel-plot."
    )
    matrix_values: list[str] = []
    for row in matrix:
        is_positive = str(row["status"]) == "waargenomen"
        measurements_json = json.dumps(
            row["measurements"], ensure_ascii=False, separators=(",", ":")
        )
        null_rule = (
            "niet_van_toepassing" if is_positive
            else "niet_gemeld_binnen_positief_bevestigde_soortgroeptelling"
        )
        matrix_values.append(
            f"({sql_text(TUINTELLING_RULE_VERSION)},{sql_text(str(row['period']))},"
            f"{sql_text(str(row['group']))},{sql_text(str(row['taxon']))},"
            f"{sql_text(str(row['status']))},{int(row['source_count'])},"
            f"{sql_text(measurements_json)},{sql_text(null_rule)},"
            f"{sql_text(matrix_note)})"
        )

    selection_reason = (
        "Bronregel gekoppeld aan een gereconstrueerde regionale telperiode. De "
        "openbare locatie valt niet eenduidig binnen een Meijendel-SOVON-plot."
    )
    selection_values: list[str] = []
    for row in records:
        family = geometry_to_family[str(row["geometry"])]
        period = period_key_by_source[(family, str(row["start"]), str(row["stop"]))]
        selection_values.append(
            f"({sql_text(TUINTELLING_RULE_VERSION)},{int(row['observation_id'])},"
            f"{sql_text(period)},'regionale_protocolcontext_geen_meijendelplot',"
            f"{sql_text(selection_reason)})"
        )

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {TUINTELLING_TABLE_PREFIX}_periode_soortgroep_taxon WHERE reconstructieversie={sql_text(TUINTELLING_RULE_VERSION)};",
        f"DELETE FROM {TUINTELLING_TABLE_PREFIX}_recordselectie WHERE reconstructieversie={sql_text(TUINTELLING_RULE_VERSION)};",
        f"DELETE FROM {TUINTELLING_TABLE_PREFIX}_periode_soortgroep WHERE reconstructieversie={sql_text(TUINTELLING_RULE_VERSION)};",
        f"DELETE FROM {TUINTELLING_TABLE_PREFIX}_telperiode WHERE reconstructieversie={sql_text(TUINTELLING_RULE_VERSION)};",
        f"DELETE FROM {TUINTELLING_TABLE_PREFIX}_geometrie WHERE reconstructieversie={sql_text(TUINTELLING_RULE_VERSION)};",
        f"DELETE FROM {TUINTELLING_TABLE_PREFIX}_tuinvakfamilie WHERE reconstructieversie={sql_text(TUINTELLING_RULE_VERSION)};",
    ]
    for table, columns, values in (
        (f"{TUINTELLING_TABLE_PREFIX}_tuinvakfamilie", "reconstructieversie,tuinvakfamilie_sleutel,protocol_sleutel,geometrieversies,eerste_periode,laatste_periode,bronrecordaantal,identificatiestatus,kwaliteitsnotitie", family_values),
        (f"{TUINTELLING_TABLE_PREFIX}_geometrie", "reconstructieversie,openbare_geometrie_sha256,tuinvakfamilie_sleutel,centroide_x_rd,centroide_y_rd,oppervlakte_m2,eerste_jaar,laatste_jaar,bronrecordaantal,ruimtelijke_status,kwaliteitsnotitie", geometry_values),
        (f"{TUINTELLING_TABLE_PREFIX}_telperiode", "reconstructieversie,telperiode_sleutel,tuinvakfamilie_sleutel,periode_start,periode_stop,teltype,methodeversie,bronrecordaantal,getelde_soortgroepen,plotstatus,kwaliteitsnotitie", period_values),
        (f"{TUINTELLING_TABLE_PREFIX}_periode_soortgroep", "reconstructieversie,telperiode_sleutel,soortgroep_raw,bronrecordaantal,waargenomen_taxa,lokale_doelsoorten,selectiebewijs,doelbereikstatus,kwaliteitsnotitie", group_values),
        (f"{TUINTELLING_TABLE_PREFIX}_periode_soortgroep_taxon", "reconstructieversie,telperiode_sleutel,soortgroep_raw,wetenschappelijke_naam,waarnemingsstatus,bronrecordaantal,meetwaarden_json,nulregel,kwaliteitsnotitie", matrix_values),
        (f"{TUINTELLING_TABLE_PREFIX}_recordselectie", "reconstructieversie,waarneming_id,telperiode_sleutel,selectiestatus,selectiereden", selection_values),
    ):
        statements += _batched_insert(table, columns, values)
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))
    audit_output = run_mysql(mysql_client, query_args, tuintelling_validation_sql(), capture=True)
    return parse_analysis_chain_output(audit_output)


def reconstruct_liveatlas(
    mysql_client: Path,
    client_args: list[str],
) -> dict[str, int]:
    """Bouw openbare LiveAtlas-bezoeken zonder route- of nulclaims."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    output = run_mysql(mysql_client, query_args, liveatlas_source_sql(), capture=True)
    records: list[dict[str, object]] = []
    for line in output.splitlines():
        fields = line.split("\t")
        if len(fields) != 11:
            raise ValueError(f"Onverwachte 102.005-bronregel met {len(fields)} velden.")
        (observation_id, start, stop, group, taxon, amount, scale, geometry,
         spatial_quality, plot_version, plot_id) = fields
        records.append({
            "observation_id": int(observation_id),
            "start": start, "stop": stop, "group": group, "taxon": taxon,
            "amount": amount, "scale": scale, "geometry": geometry,
            "spatial_quality": spatial_quality,
            "plot_version": None if plot_version == "NULL" else int(plot_version),
            "plot_id": None if plot_id == "NULL" else int(plot_id),
        })
    if len(records) != LIVEATLAS_RECONSTRUCTION_EXPECTED["source_records"]:
        raise ValueError("De 102.005-bronselectie wijkt af van het gecontroleerde profiel.")

    structure = build_liveatlas_structure(records)
    visits = structure["visits"]
    group_visits = structure["group_visits"]
    taxa = structure["taxa"]
    record_links = structure["record_links"]

    visit_note = (
        "Afgeleid LiveAtlas-bezoek op basis van exact gelijke begin- en eindtijd. "
        "De gelopen route, het oorspronkelijke bezoek-ID, het aantal waarnemers "
        "en de complete-lijststatus per soortgroep zijn niet meegeleverd. De "
        "openbare recordgeometrieën mogen niet als volledige route worden gelezen."
    )
    visit_values = [
        f"({sql_text(LIVEATLAS_RULE_VERSION)},{sql_text(str(row['key']))},'102.005',"
        f"{sql_text(str(row['start']))},{sql_text(str(row['stop']))},"
        f"{int(row['duration_minutes'])},{sql_text(str(row['duration_status']))},"
        f"{int(row['source_count'])},{int(row['geometry_count'])},"
        f"{int(row['group_count'])},{sql_text(str(row['spatial_status']))},"
        f"{int(row['plot_version']) if row['plot_version'] is not None else 'NULL'},"
        f"{int(row['plot_id']) if row['plot_id'] is not None else 'NULL'},"
        f"'route_niet_meegeleverd',{sql_text(visit_note)})"
        for row in visits
    ]

    group_note = (
        "De positieve regels bewijzen dat deze soortgroep tijdens het afgeleide "
        "bezoek is geregistreerd. De FFV-levering vermeldt niet of de teller de "
        "soortgroep als complete lijst heeft afgesloten; ontbrekende soorten zijn "
        "daarom onbekend en niet nul."
    )
    group_values = [
        f"({sql_text(LIVEATLAS_RULE_VERSION)},{sql_text(str(row['visit']))},"
        f"{sql_text(str(row['group']))},{int(row['source_count'])},"
        f"{int(row['observed_taxa'])},'niet_meegeleverd','geen_nul_afleidbaar',"
        f"{sql_text(group_note)})"
        for row in group_visits
    ]

    taxon_note = (
        "Positieve LiveAtlas-uitkomst. Herhaalde bronregels voor hetzelfde taxon "
        "binnen het afgeleide bezoek zijn opgeteld en blijven afzonderlijk "
        "controleerbaar in meetwaarden_json. Er zijn geen nullen afgeleid."
    )
    taxon_values: list[str] = []
    for row in taxa:
        measurements_json = json.dumps(
            row["measurements"], ensure_ascii=False, separators=(",", ":")
        )
        taxon_values.append(
            f"({sql_text(LIVEATLAS_RULE_VERSION)},{sql_text(str(row['visit']))},"
            f"{sql_text(str(row['group']))},{sql_text(str(row['taxon']))},"
            f"'waargenomen',{int(row['source_count'])},{int(row['total_count'])},"
            f"{sql_text(measurements_json)},'geen_nul_afleidbaar',"
            f"{sql_text(taxon_note)})"
        )

    selection_note = (
        "Positieve 102.005-bronregel gekoppeld aan een afgeleid bezoek. "
        "Gebruik de bestaande recordgeometrie voor verspreidingscontext; route en "
        "complete-lijststatus ontbreken, zodat afwezigheid niet kan worden afgeleid."
    )
    selection_values = [
        f"({sql_text(LIVEATLAS_RULE_VERSION)},{int(row['observation_id'])},"
        f"{sql_text(str(row['visit']))},{sql_text(str(row['spatial_quality']))},"
        f"{int(row['plot_id']) if row['spatial_quality']=='single_volledig_binnen' and row['plot_id'] is not None else 'NULL'},"
        f"'positief_protocolrecord_geen_nulafleiding',{sql_text(selection_note)})"
        for row in record_links
    ]

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {LIVEATLAS_TABLE_PREFIX}_bezoek_taxon WHERE reconstructieversie={sql_text(LIVEATLAS_RULE_VERSION)};",
        f"DELETE FROM {LIVEATLAS_TABLE_PREFIX}_recordselectie WHERE reconstructieversie={sql_text(LIVEATLAS_RULE_VERSION)};",
        f"DELETE FROM {LIVEATLAS_TABLE_PREFIX}_bezoek_soortgroep WHERE reconstructieversie={sql_text(LIVEATLAS_RULE_VERSION)};",
        f"DELETE FROM {LIVEATLAS_TABLE_PREFIX}_bezoek WHERE reconstructieversie={sql_text(LIVEATLAS_RULE_VERSION)};",
    ]
    for table, columns, values in (
        (f"{LIVEATLAS_TABLE_PREFIX}_bezoek", "reconstructieversie,bezoek_sleutel,protocol_sleutel,periode_start,periode_stop,duur_minuten,duurstatus,bronrecordaantal,geometrieversies,soortgroepen_met_positieve_regels,ruimtelijke_status,plotversie_id,eenduidig_plot_id,routestatus,kwaliteitsnotitie", visit_values),
        (f"{LIVEATLAS_TABLE_PREFIX}_bezoek_soortgroep", "reconstructieversie,bezoek_sleutel,soortgroep_raw,bronrecordaantal,waargenomen_taxa,volledigheidsstatus,nulstatus,kwaliteitsnotitie", group_values),
        (f"{LIVEATLAS_TABLE_PREFIX}_bezoek_taxon", "reconstructieversie,bezoek_sleutel,soortgroep_raw,wetenschappelijke_naam,waarnemingsstatus,bronrecordaantal,totaal_aantal,meetwaarden_json,nulregel,kwaliteitsnotitie", taxon_values),
        (f"{LIVEATLAS_TABLE_PREFIX}_recordselectie", "reconstructieversie,waarneming_id,bezoek_sleutel,ruimtelijke_status,eenduidig_plot_id,selectiestatus,selectiereden", selection_values),
    ):
        statements += _batched_insert(table, columns, values)
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))
    audit_output = run_mysql(mysql_client, query_args, liveatlas_validation_sql(), capture=True)
    return parse_analysis_chain_output(audit_output)


def reconstruct_kwartiertellingen(
    mysql_client: Path,
    client_args: list[str],
) -> dict[str, int]:
    """Bouw openbare kwartiertelintervallen zonder route- of nulclaims."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    output = run_mysql(mysql_client, query_args, kwartiertelling_source_sql(), capture=True)
    records: list[dict[str, object]] = []
    for line in output.splitlines():
        fields = line.split("\t")
        if len(fields) != 11:
            raise ValueError(f"Onverwachte 102.007-bronregel met {len(fields)} velden.")
        (observation_id, start, stop, group, taxon, amount, scale, geometry,
         spatial_quality, plot_version, plot_id) = fields
        records.append({
            "observation_id": int(observation_id),
            "start": start, "stop": stop, "group": group, "taxon": taxon,
            "amount": amount, "scale": scale, "geometry": geometry,
            "spatial_quality": spatial_quality,
            "plot_version": None if plot_version == "NULL" else int(plot_version),
            "plot_id": None if plot_id == "NULL" else int(plot_id),
        })
    if len(records) != KWARTIERTELLING_RECONSTRUCTION_EXPECTED["source_records"]:
        raise ValueError("De 102.007-bronselectie wijkt af van het gecontroleerde profiel.")

    structure = build_kwartiertelling_structure(records)
    interval_note = (
        "Afgeleid kwartiertelinterval op basis van exact gelijke begin- en eindtijd. "
        "De oorspronkelijke route, het tel-ID en het lijsttype zijn niet meegeleverd. "
        "Een duur boven vijftien minuten blijft bewaard als te controleren bronafwijking."
    )
    interval_values = [
        f"({sql_text(KWARTIERTELLING_RULE_VERSION)},{sql_text(str(row['key']))},"
        f"'102.007',{sql_text(str(row['start']))},{sql_text(str(row['stop']))},"
        f"{int(row['duration_minutes'])},{sql_text(str(row['duration_status']))},"
        f"{int(row['source_count'])},{int(row['geometry_count'])},"
        f"{int(row['group_count'])},{sql_text(str(row['spatial_status']))},"
        f"{int(row['plot_version']) if row['plot_version'] is not None else 'NULL'},"
        f"{int(row['plot_id']) if row['plot_id'] is not None else 'NULL'},"
        f"'route_niet_meegeleverd',{sql_text(interval_note)})"
        for row in structure["intervals"]
    ]
    group_note = (
        "Positieve regels bewijzen registratie van deze soortgroep binnen het "
        "afgeleide interval. De levering onderscheidt een complete soortenlijst "
        "niet van een soortgerichte telling; niet-gemelde soorten zijn daarom onbekend."
    )
    group_values = [
        f"({sql_text(KWARTIERTELLING_RULE_VERSION)},"
        f"{sql_text(str(row['interval']))},{sql_text(str(row['group']))},"
        f"{int(row['source_count'])},{int(row['observed_taxa'])},"
        f"'niet_meegeleverd_ononderscheidbaar_soortgericht',"
        f"'geen_nul_afleidbaar',{sql_text(group_note)})"
        for row in structure["group_intervals"]
    ]
    taxon_note = (
        "Positieve uitkomst binnen een afgeleid kwartiertelinterval. Bronregels "
        "voor hetzelfde taxon zijn opgeteld en blijven afzonderlijk controleerbaar "
        "in meetwaarden_json; er zijn geen nullen afgeleid."
    )
    taxon_values = [
        f"({sql_text(KWARTIERTELLING_RULE_VERSION)},"
        f"{sql_text(str(row['interval']))},{sql_text(str(row['group']))},"
        f"{sql_text(str(row['taxon']))},'waargenomen',{int(row['source_count'])},"
        f"{int(row['total_count'])},"
        f"{sql_text(json.dumps(row['measurements'], ensure_ascii=False, separators=(',', ':')))},"
        f"'geen_nul_afleidbaar',{sql_text(taxon_note)})"
        for row in structure["taxa"]
    ]
    selection_note = (
        "Positieve 102.007-bronregel gekoppeld aan een afgeleid telinterval. "
        "Gebruik de recordgeometrie alleen voor verspreidingscontext; route, "
        "complete-lijststatus en soortgerichte status ontbreken."
    )
    selection_values = [
        f"({sql_text(KWARTIERTELLING_RULE_VERSION)},"
        f"{int(row['observation_id'])},{sql_text(str(row['interval']))},"
        f"{sql_text(str(row['spatial_quality']))},"
        f"{int(row['plot_id']) if row['spatial_quality']=='single_volledig_binnen' and row['plot_id'] is not None else 'NULL'},"
        f"'positief_protocolrecord_geen_nulafleiding',{sql_text(selection_note)})"
        for row in structure["record_links"]
    ]

    statements = [
        "START TRANSACTION;",
        f"DELETE FROM {KWARTIERTELLING_TABLE_PREFIX}_interval_taxon WHERE reconstructieversie={sql_text(KWARTIERTELLING_RULE_VERSION)};",
        f"DELETE FROM {KWARTIERTELLING_TABLE_PREFIX}_recordselectie WHERE reconstructieversie={sql_text(KWARTIERTELLING_RULE_VERSION)};",
        f"DELETE FROM {KWARTIERTELLING_TABLE_PREFIX}_interval_soortgroep WHERE reconstructieversie={sql_text(KWARTIERTELLING_RULE_VERSION)};",
        f"DELETE FROM {KWARTIERTELLING_TABLE_PREFIX}_telinterval WHERE reconstructieversie={sql_text(KWARTIERTELLING_RULE_VERSION)};",
    ]
    for table, columns, values in (
        (f"{KWARTIERTELLING_TABLE_PREFIX}_telinterval", "reconstructieversie,interval_sleutel,protocol_sleutel,periode_start,periode_stop,duur_minuten,duurstatus,bronrecordaantal,geometrieversies,soortgroepen_met_positieve_regels,ruimtelijke_status,plotversie_id,eenduidig_plot_id,routestatus,kwaliteitsnotitie", interval_values),
        (f"{KWARTIERTELLING_TABLE_PREFIX}_interval_soortgroep", "reconstructieversie,interval_sleutel,soortgroep_raw,bronrecordaantal,waargenomen_taxa,volledigheidsstatus,nulstatus,kwaliteitsnotitie", group_values),
        (f"{KWARTIERTELLING_TABLE_PREFIX}_interval_taxon", "reconstructieversie,interval_sleutel,soortgroep_raw,wetenschappelijke_naam,waarnemingsstatus,bronrecordaantal,totaal_aantal,meetwaarden_json,nulregel,kwaliteitsnotitie", taxon_values),
        (f"{KWARTIERTELLING_TABLE_PREFIX}_recordselectie", "reconstructieversie,waarneming_id,interval_sleutel,ruimtelijke_status,eenduidig_plot_id,selectiestatus,selectiereden", selection_values),
    ):
        statements += _batched_insert(table, columns, values)
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))
    audit_output = run_mysql(
        mysql_client, query_args, kwartiertelling_validation_sql(), capture=True
    )
    return parse_analysis_chain_output(audit_output)


def resterende_nem_source_sql() -> str:
    """Lees de vier resterende openbare NEM-reeksen; 12.202/PQ blijft erbuiten."""
    return f"""
SELECT SUBSTRING_INDEX(o.protocol,' ',1),o.waarneming_id,
       DATE_FORMAT(o.periode_start,'%Y-%m-%d %H:%i:%s'),
       DATE_FORMAT(o.periode_stop,'%Y-%m-%d %H:%i:%s'),o.jaar,
       o.soortgroep_raw,o.wetenschappelijke_naam,
       COALESCE(o.aantal_raw,''),COALESCE(o.schaal_telmethode,''),
       o.openbare_geometrie_sha256,COALESCE(o.hoknummer,''),o.vervaagd,
       COALESCE(o.vervagingsniveau_km,0),r.toewijzingskwaliteit,
       r.plotversie_id,COALESCE(r.eenduidig_plot_id,0)
FROM Meijendel.ndff_open_waarneming o
JOIN Meijendel.ndff_open_ruimtelijke_beoordeling r
  ON r.waarneming_id=o.waarneming_id
 AND r.regelversie={sql_text(RULE_VERSION)}
WHERE o.protocol LIKE '03.203%'
   OR o.protocol LIKE '11.204%'
   OR o.protocol LIKE '13.201%'
   OR o.protocol LIKE '17.207%'
ORDER BY SUBSTRING_INDEX(o.protocol,' ',1),o.periode_start,o.waarneming_id;
"""


def _parse_resterende_nem_rows(output: str) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for line in output.splitlines():
        fields = line.split("\t")
        if len(fields) != 16:
            raise ValueError(f"Onverwachte resterende-NEM-bronregel met {len(fields)} velden.")
        (protocol, observation_id, start, stop, year, group, taxon, amount,
         scale, geometry, grid, blurred, blur_level, spatial, plot_version,
         plot_id) = fields
        rows.append({
            "protocol": protocol, "observation_id": int(observation_id),
            "start": start, "stop": stop, "year": int(year), "group": group,
            "taxon": taxon, "amount": amount, "scale": scale,
            "geometry": geometry, "grid": grid, "blurred": int(blurred),
            "blur_level": int(blur_level), "spatial": spatial,
            "plot_version": int(plot_version),
            "plot_id": int(plot_id) or None,
        })
    return rows


def _positive_measurements(rows: list[dict[str, object]]) -> tuple[int, list[dict[str, object]]]:
    measurements: list[dict[str, object]] = []
    total = 0
    for row in sorted(rows, key=lambda item: int(item["observation_id"])):
        raw = str(row["amount"])
        if not raw.isdigit() or int(raw) <= 0:
            raise ValueError(
                f"Record {row['observation_id']} heeft geen geheel positief exact aantal."
            )
        value = int(raw)
        total += value
        measurements.append({
            "waarneming_id": int(row["observation_id"]),
            "aantal": value, "schaal": str(row["scale"]),
            "geometrie": str(row["geometry"]),
        })
    return total, measurements


def reconstruct_resterende_nem(
    mysql_client: Path,
    client_args: list[str],
) -> dict[str, int]:
    """Reconstrueer 03.203, 11.204, 13.201 en 17.207 in één transactie."""
    query_args = client_args + ["--batch", "--raw", "--skip-column-names"]
    output = run_mysql(mysql_client, query_args, resterende_nem_source_sql(), capture=True)
    records = _parse_resterende_nem_rows(output)
    if len(records) != RESTERENDE_NEM_RECONSTRUCTION_EXPECTED["source_records"]:
        raise ValueError("De resterende NEM-bronselectie wijkt af van het gecontroleerde profiel.")
    by_protocol: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in records:
        by_protocol[str(row["protocol"])].append(row)

    statements = ["START TRANSACTION;"]
    for table in (
        f"{NACHTVLINDER_TABLE_PREFIX}_hokjaar_taxon",
        f"{NACHTVLINDER_TABLE_PREFIX}_recordselectie",
        f"{NACHTVLINDER_TABLE_PREFIX}_hokjaar",
        f"{BOSPADDENSTOEL_VERSPREIDING_TABLE_PREFIX}_bezoek_taxon",
        f"{BOSPADDENSTOEL_VERSPREIDING_TABLE_PREFIX}_recordselectie",
        f"{BOSPADDENSTOEL_VERSPREIDING_TABLE_PREFIX}_bezoek",
        f"{POLDERVIS_TABLE_PREFIX}_bezoek_taxon",
        f"{POLDERVIS_TABLE_PREFIX}_recordselectie",
        f"{POLDERVIS_TABLE_PREFIX}_bezoek",
        f"{POLDERVIS_TABLE_PREFIX}_waterlocatie",
        f"{OTTER_BEVER_TABLE_PREFIX}_hokjaar_taxon",
        f"{OTTER_BEVER_TABLE_PREFIX}_recordselectie",
        f"{OTTER_BEVER_TABLE_PREFIX}_hokjaar",
    ):
        version = (
            NACHTVLINDER_RULE_VERSION if "nachtvlinder" in table
            else BOSPADDENSTOEL_VERSPREIDING_RULE_VERSION if "bospaddenstoel_verspreiding" in table
            else POLDERVIS_RULE_VERSION if "poldervis" in table
            else OTTER_BEVER_RULE_VERSION
        )
        statements.append(f"DELETE FROM {table} WHERE reconstructieversie={sql_text(version)};")

    # 03.203: de openbare levering bestaat uitsluitend uit vervaagde jaaraggregaten.
    night_rows = by_protocol["03.203"]
    night_units: dict[tuple[str, int], list[dict[str, object]]] = defaultdict(list)
    for row in night_rows:
        if not row["blurred"] or row["spatial"] != "multiple" or row["scale"] != "exact aantal":
            raise ValueError("03.203 bevat een onverwachte ruimtelijke of telwaardevariant.")
        night_units[(str(row["geometry"]), int(row["year"]))].append(row)
    night_unit_values, night_taxon_values, night_selection_values = [], [], []
    night_note = (
        "Openbaar vervaagd geometrie-jaar uit 03.203. De FFV-levering bevat geen "
        "val-, bezoek- of inspanningsstructuur; sommen zijn geregistreerde aantallen, "
        "geen abundantie en ontbrekende soorten zijn geen nullen."
    )
    for (geometry, year), unit_rows in sorted(night_units.items()):
        key = hashlib.sha256(f"03.203|{geometry}|{year}".encode()).hexdigest()
        grids = sorted({str(row["grid"]) for row in unit_rows if row["grid"]})
        night_unit_values.append(
            f"({sql_text(NACHTVLINDER_RULE_VERSION)},{sql_text(key)},'03.203',"
            f"{sql_text(geometry)},{sql_text(grids[0] if len(grids)==1 else '')},"
            f"{year},{len(unit_rows)},'multiple','positieve_jaargegevens_geen_bezoekstructuur',"
            f"{sql_text(night_note)})"
        )
        by_taxon: dict[str, list[dict[str, object]]] = defaultdict(list)
        for row in unit_rows:
            by_taxon[str(row["taxon"])].append(row)
            night_selection_values.append(
                f"({sql_text(NACHTVLINDER_RULE_VERSION)},{int(row['observation_id'])},"
                f"{sql_text(key)},'vervaagd_positief_hokjaar',{sql_text(night_note)})"
            )
        for taxon, taxon_rows in sorted(by_taxon.items()):
            total, measurements = _positive_measurements(taxon_rows)
            night_taxon_values.append(
                f"({sql_text(NACHTVLINDER_RULE_VERSION)},{sql_text(key)},"
                f"{sql_text(taxon)},'waargenomen',{len(taxon_rows)},{total},"
                f"{sql_text(json.dumps(measurements, ensure_ascii=False, separators=(',', ':')))},"
                f"'geen_nul_afleidbaar',{sql_text(night_note)})"
            )

    # 11.204: twee positieve inventarisaties; NMV-klassen blijven ongewijzigd.
    fungus_rows = by_protocol["11.204"]
    fungus_visits: dict[tuple[str, str, str], list[dict[str, object]]] = defaultdict(list)
    for row in fungus_rows:
        fungus_visits[(str(row["geometry"]), str(row["start"]), str(row["stop"]))].append(row)
    fungus_visit_values, fungus_taxon_values, fungus_selection_values = [], [], []
    fungus_note = (
        "Afgeleid bezoek uit 11.204. De NMV-aantalsklasse blijft bronwaarde. "
        "Omdat deelnemers alleen soorten mogen invoeren die zij herkennen, is dit "
        "geen bewezen complete lijst en worden geen nullen afgeleid."
    )
    for (geometry, start, stop), visit_rows in sorted(fungus_visits.items()):
        key = hashlib.sha256(f"11.204|{geometry}|{start}|{stop}".encode()).hexdigest()
        grids = sorted({str(row["grid"]) for row in visit_rows if row["grid"]})
        fungus_visit_values.append(
            f"({sql_text(BOSPADDENSTOEL_VERSPREIDING_RULE_VERSION)},{sql_text(key)},"
            f"'11.204',{sql_text(geometry)},{sql_text(grids[0] if len(grids)==1 else '')},"
            f"{sql_text(start)},{sql_text(stop)},{len(visit_rows)},'multiple',"
            f"'waarnemerskennis_onbekend_geen_complete_lijst',{sql_text(fungus_note)})"
        )
        by_taxon: dict[str, list[dict[str, object]]] = defaultdict(list)
        for row in visit_rows:
            by_taxon[str(row["taxon"])].append(row)
            fungus_selection_values.append(
                f"({sql_text(BOSPADDENSTOEL_VERSPREIDING_RULE_VERSION)},"
                f"{int(row['observation_id'])},{sql_text(key)},"
                f"'positief_bezoek_geen_nulafleiding',{sql_text(fungus_note)})"
            )
        for taxon, taxon_rows in sorted(by_taxon.items()):
            measurements = [{
                "waarneming_id": int(row["observation_id"]),
                "waarde": str(row["amount"]), "schaal": str(row["scale"]),
            } for row in sorted(taxon_rows, key=lambda item: int(item["observation_id"]))]
            fungus_taxon_values.append(
                f"({sql_text(BOSPADDENSTOEL_VERSPREIDING_RULE_VERSION)},"
                f"{sql_text(key)},{sql_text(taxon)},'waargenomen',{len(taxon_rows)},"
                f"{sql_text(json.dumps(measurements, ensure_ascii=False, separators=(',', ':')))},"
                f"'geen_nul_afleidbaar',{sql_text(fungus_note)})"
            )

    # 13.201: geometrie is waterproxy; alleen Kleine modderkruiper is lokaal doelsoort.
    fish_rows = by_protocol["13.201"]
    fish_locations: dict[str, list[dict[str, object]]] = defaultdict(list)
    fish_visits: dict[tuple[str, str, str], list[dict[str, object]]] = defaultdict(list)
    for row in fish_rows:
        fish_locations[str(row["geometry"])].append(row)
        fish_visits[(str(row["geometry"]), str(row["start"]), str(row["stop"]))].append(row)
    fish_location_values, fish_visit_values, fish_taxon_values, fish_selection_values = [], [], [], []
    fish_note = (
        "Afgeleid 13.201-bezoek. Exacte telwaarden blijven geregistreerde aantallen. "
        "Submethode, doelbereik en inspanning ontbreken; niet-gemelde Kleine "
        "modderkruiper is daarom onbekend en nadrukkelijk geen nul."
    )
    for geometry, location_rows in sorted(fish_locations.items()):
        location_key = hashlib.sha256(f"13.201|water|{geometry}".encode()).hexdigest()
        statuses = {str(row["spatial"]) for row in location_rows}
        if len(statuses) != 1 or next(iter(statuses)) not in {"single_volledig_binnen", "outside"}:
            raise ValueError("13.201-waterlocatie heeft een onverwachte ruimtelijke status.")
        status = next(iter(statuses))
        plots = {int(row["plot_id"]) for row in location_rows if row["plot_id"] is not None}
        versions = {int(row["plot_version"]) for row in location_rows}
        plot_id = next(iter(plots)) if status == "single_volledig_binnen" and len(plots)==1 else None
        plot_version = next(iter(versions)) if plot_id is not None and len(versions)==1 else None
        fish_location_values.append(
            f"({sql_text(POLDERVIS_RULE_VERSION)},{sql_text(location_key)},'13.201',"
            f"{sql_text(geometry)},{len(location_rows)},{sql_text(status)},"
            f"{plot_version if plot_version is not None else 'NULL'},"
            f"{plot_id if plot_id is not None else 'NULL'},"
            f"'openbare_geometrie_als_waterproxy',{sql_text(fish_note)})"
        )
    for (geometry, start, stop), visit_rows in sorted(fish_visits.items()):
        location_key = hashlib.sha256(f"13.201|water|{geometry}".encode()).hexdigest()
        visit_key = hashlib.sha256(f"13.201|visit|{geometry}|{start}|{stop}".encode()).hexdigest()
        fish_visit_values.append(
            f"({sql_text(POLDERVIS_RULE_VERSION)},{sql_text(visit_key)},"
            f"{sql_text(location_key)},{sql_text(start)},{sql_text(stop)},"
            f"{len(visit_rows)},'submethode_en_inspanning_niet_meegeleverd',"
            f"{sql_text(fish_note)})"
        )
        by_taxon: dict[str, list[dict[str, object]]] = defaultdict(list)
        for row in visit_rows:
            by_taxon[str(row["taxon"])].append(row)
            fish_selection_values.append(
                f"({sql_text(POLDERVIS_RULE_VERSION)},{int(row['observation_id'])},"
                f"{sql_text(visit_key)},'positief_protocolrecord',{sql_text(fish_note)})"
            )
        for taxon, taxon_rows in sorted(by_taxon.items()):
            total, measurements = _positive_measurements(taxon_rows)
            relation = "doelsoort" if taxon == "Cobitis taenia" else "bijvangst"
            fish_taxon_values.append(
                f"({sql_text(POLDERVIS_RULE_VERSION)},{sql_text(visit_key)},"
                f"{sql_text(taxon)},{sql_text(relation)},'waargenomen',"
                f"{len(taxon_rows)},{total},"
                f"{sql_text(json.dumps(measurements, ensure_ascii=False, separators=(',', ':')))},"
                f"'niet_van_toepassing',{sql_text(fish_note)})"
            )
        if "Cobitis taenia" not in by_taxon:
            fish_taxon_values.append(
                f"({sql_text(POLDERVIS_RULE_VERSION)},{sql_text(visit_key)},"
                f"'Cobitis taenia','doelsoort','doelsoort_niet_gemeld',0,NULL,"
                f"JSON_ARRAY(),'geen_nul_doelmethode_onbekend',{sql_text(fish_note)})"
            )

    # 17.207: positief Ottersignaal op recordniveau; hokjaar is geen enkel plot.
    mammal_rows = by_protocol["17.207"]
    mammal_units: dict[tuple[str, int], list[dict[str, object]]] = defaultdict(list)
    for row in mammal_rows:
        mammal_units[(str(row["grid"]), int(row["year"]))].append(row)
    mammal_unit_values, mammal_taxon_values, mammal_selection_values = [], [], []
    mammal_note = (
        "Openbaar 17.207-hokjaar met positieve Otterregistraties. De afzonderlijke "
        "punten behouden hun plotcontext, maar het kilometerhok omvat meerdere plots. "
        "Ontbrekende Bever is geen nul zonder waarnemersdekking."
    )
    for (grid, year), unit_rows in sorted(mammal_units.items()):
        key = hashlib.sha256(f"17.207|{grid}|{year}".encode()).hexdigest()
        mammal_unit_values.append(
            f"({sql_text(OTTER_BEVER_RULE_VERSION)},{sql_text(key)},'17.207',"
            f"{sql_text(grid)},{year},{len(unit_rows)},'meerdere_plots_binnen_hok',"
            f"'alleen_positieve_records_geen_waarnemersdekking',{sql_text(mammal_note)})"
        )
        by_taxon: dict[str, list[dict[str, object]]] = defaultdict(list)
        for row in unit_rows:
            if row["plot_id"] is None:
                raise ValueError("17.207-positief record mist de verwachte plotcontext.")
            by_taxon[str(row["taxon"])].append(row)
            mammal_selection_values.append(
                f"({sql_text(OTTER_BEVER_RULE_VERSION)},{int(row['observation_id'])},"
                f"{sql_text(key)},{int(row['plot_id'])},"
                f"'positieve_puntcontext_geen_hoknul',{sql_text(mammal_note)})"
            )
        for taxon, taxon_rows in sorted(by_taxon.items()):
            total, measurements = _positive_measurements(taxon_rows)
            mammal_taxon_values.append(
                f"({sql_text(OTTER_BEVER_RULE_VERSION)},{sql_text(key)},"
                f"{sql_text(taxon)},'doelsoort','waargenomen',{len(taxon_rows)},"
                f"{total},{sql_text(json.dumps(measurements, ensure_ascii=False, separators=(',', ':')))},"
                f"'geen_nul_afleidbaar',{sql_text(mammal_note)})"
            )

    inserts = (
        (f"{NACHTVLINDER_TABLE_PREFIX}_hokjaar", "reconstructieversie,hokjaar_sleutel,protocol_sleutel,openbare_geometrie_sha256,hoknummer,jaar,bronrecordaantal,ruimtelijke_status,telstatus,kwaliteitsnotitie", night_unit_values),
        (f"{NACHTVLINDER_TABLE_PREFIX}_hokjaar_taxon", "reconstructieversie,hokjaar_sleutel,wetenschappelijke_naam,waarnemingsstatus,bronrecordaantal,geregistreerd_aantal,meetwaarden_json,nulregel,kwaliteitsnotitie", night_taxon_values),
        (f"{NACHTVLINDER_TABLE_PREFIX}_recordselectie", "reconstructieversie,waarneming_id,hokjaar_sleutel,selectiestatus,selectiereden", night_selection_values),
        (f"{BOSPADDENSTOEL_VERSPREIDING_TABLE_PREFIX}_bezoek", "reconstructieversie,bezoek_sleutel,protocol_sleutel,openbare_geometrie_sha256,hoknummer,periode_start,periode_stop,bronrecordaantal,ruimtelijke_status,volledigheidsstatus,kwaliteitsnotitie", fungus_visit_values),
        (f"{BOSPADDENSTOEL_VERSPREIDING_TABLE_PREFIX}_bezoek_taxon", "reconstructieversie,bezoek_sleutel,wetenschappelijke_naam,waarnemingsstatus,bronrecordaantal,meetwaarden_json,nulregel,kwaliteitsnotitie", fungus_taxon_values),
        (f"{BOSPADDENSTOEL_VERSPREIDING_TABLE_PREFIX}_recordselectie", "reconstructieversie,waarneming_id,bezoek_sleutel,selectiestatus,selectiereden", fungus_selection_values),
        (f"{POLDERVIS_TABLE_PREFIX}_waterlocatie", "reconstructieversie,waterlocatie_sleutel,protocol_sleutel,openbare_geometrie_sha256,bronrecordaantal,ruimtelijke_status,plotversie_id,eenduidig_plot_id,identificatiestatus,kwaliteitsnotitie", fish_location_values),
        (f"{POLDERVIS_TABLE_PREFIX}_bezoek", "reconstructieversie,bezoek_sleutel,waterlocatie_sleutel,periode_start,periode_stop,bronrecordaantal,methodestatus,kwaliteitsnotitie", fish_visit_values),
        (f"{POLDERVIS_TABLE_PREFIX}_bezoek_taxon", "reconstructieversie,bezoek_sleutel,wetenschappelijke_naam,doelrelatie,waarnemingsstatus,bronrecordaantal,geregistreerd_aantal,meetwaarden_json,nulregel,kwaliteitsnotitie", fish_taxon_values),
        (f"{POLDERVIS_TABLE_PREFIX}_recordselectie", "reconstructieversie,waarneming_id,bezoek_sleutel,selectiestatus,selectiereden", fish_selection_values),
        (f"{OTTER_BEVER_TABLE_PREFIX}_hokjaar", "reconstructieversie,hokjaar_sleutel,protocol_sleutel,hoknummer,jaar,bronrecordaantal,ruimtelijke_status,volledigheidsstatus,kwaliteitsnotitie", mammal_unit_values),
        (f"{OTTER_BEVER_TABLE_PREFIX}_hokjaar_taxon", "reconstructieversie,hokjaar_sleutel,wetenschappelijke_naam,doelrelatie,waarnemingsstatus,bronrecordaantal,geregistreerd_aantal,meetwaarden_json,nulregel,kwaliteitsnotitie", mammal_taxon_values),
        (f"{OTTER_BEVER_TABLE_PREFIX}_recordselectie", "reconstructieversie,waarneming_id,hokjaar_sleutel,eenduidig_plot_id,selectiestatus,selectiereden", mammal_selection_values),
    )
    for table, columns, values in inserts:
        statements += _batched_insert(table, columns, values)
    statements.append("COMMIT;")
    run_mysql(mysql_client, client_args, "\n".join(statements))
    audit_output = run_mysql(
        mysql_client, query_args, resterende_nem_validation_sql(), capture=True
    )
    return parse_analysis_chain_output(audit_output)


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


def rabbit_validation_sql() -> str:
    version = sql_text(RABBIT_COUNT_RULE_VERSION)
    secure_tables = ",".join(sql_text(f"ndff_konijn_{suffix}") for suffix in (
        "recordselectie", "hokdatum_taxon",
    ))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT COUNT(*) FROM Meijendel.ndff_konijn_recordselectie WHERE reconstructieversie={version}),
  'target_records',(SELECT COUNT(*) FROM Meijendel.ndff_konijn_recordselectie WHERE reconstructieversie={version} AND doelrelatie='doelsoort'),
  'bycatch_records',(SELECT COUNT(*) FROM Meijendel.ndff_konijn_recordselectie WHERE reconstructieversie={version} AND doelrelatie='bijvangst'),
  'target_count_sum',(SELECT SUM(aantal_exact) FROM Meijendel.ndff_konijn_recordselectie WHERE reconstructieversie={version} AND doelrelatie='doelsoort'),
  'bycatch_count_sum',(SELECT SUM(aantal_exact) FROM Meijendel.ndff_konijn_recordselectie WHERE reconstructieversie={version} AND doelrelatie='bijvangst'),
  'dates',(SELECT COUNT(DISTINCT teldatum) FROM Meijendel.ndff_konijn_hokdatum_taxon WHERE reconstructieversie={version}),
  'grids',(SELECT COUNT(DISTINCT openbare_geometrie_sha256) FROM Meijendel.ndff_konijn_hokdatum_taxon WHERE reconstructieversie={version}),
  'grid_date_taxon_rows',(SELECT COUNT(*) FROM Meijendel.ndff_konijn_hokdatum_taxon WHERE reconstructieversie={version}),
  'spring_window_records',(SELECT COUNT(*) FROM Meijendel.ndff_konijn_recordselectie WHERE reconstructieversie={version} AND seizoenstatus='voorjaar_huidig_venster'),
  'autumn_window_records',(SELECT COUNT(*) FROM Meijendel.ndff_konijn_recordselectie WHERE reconstructieversie={version} AND seizoenstatus='najaar_huidig_venster'),
  'off_window_records',(SELECT COUNT(*) FROM Meijendel.ndff_konijn_recordselectie WHERE reconstructieversie={version} AND seizoenstatus='buiten_huidig_venster'),
  'exact_duplicate_groups',(SELECT ROUND(SUM(1.0/exactgelijke_groepsgrootte)) FROM Meijendel.ndff_konijn_recordselectie WHERE reconstructieversie={version} AND exactgelijke_groepsgrootte>1),
  'exact_duplicate_members',(SELECT COUNT(*) FROM Meijendel.ndff_konijn_recordselectie WHERE reconstructieversie={version} AND recordgroepstatus='gelijke_telwaarde_binnen_hokdatum_taxon'),
  'multi_record_grid_date_taxon_groups',(SELECT COUNT(*) FROM Meijendel.ndff_konijn_hokdatum_taxon WHERE reconstructieversie={version} AND bronrecordaantal>1),
  'possible_daz_overlap_records',(SELECT COUNT(*) FROM Meijendel.ndff_konijn_recordselectie WHERE reconstructieversie={version} AND daz_overlapstatus='mogelijke_overlap_17_204'),
  'derived_zero_rows',0,
  'multiple_plot_records',(SELECT COUNT(*) FROM Meijendel.ndff_konijn_recordselectie WHERE reconstructieversie={version} AND ruimtelijke_status='kilometerhok_meerdere_sovonplots'),
  'secure_source_records',(SELECT COUNT(*) FROM Meijendel_ndff_secure.ndff_zoogdieren_overig WHERE protocol='17.209'),
  'secure_derived_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({secure_tables}))
);
"""


def daz_bmp_validation_sql() -> str:
    version = sql_text(DAZ_BMP_RULE_VERSION)
    secure_tables = ",".join(sql_text(f"ndff_daz_bmp_{suffix}") for suffix in (
        "recordselectie", "recordkandidaat", "bezoek", "bezoek_taxon",
    ))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT COUNT(*) FROM Meijendel.ndff_daz_bmp_recordselectie WHERE reconstructieversie={version}),
  'unique_link_records',(SELECT COUNT(*) FROM Meijendel.ndff_daz_bmp_recordselectie WHERE reconstructieversie={version} AND koppelstatus='eenduidig_bmp_bezoek'),
  'multiple_link_records',(SELECT COUNT(*) FROM Meijendel.ndff_daz_bmp_recordselectie WHERE reconstructieversie={version} AND koppelstatus='meerdere_bmp_bezoeken'),
  'unlinked_records',(SELECT COUNT(*) FROM Meijendel.ndff_daz_bmp_recordselectie WHERE reconstructieversie={version} AND koppelstatus='geen_bmp_bezoek'),
  'candidate_links',(SELECT COUNT(*) FROM Meijendel.ndff_daz_bmp_recordkandidaat WHERE reconstructieversie={version}),
  'confirmed_visits',(SELECT COUNT(*) FROM Meijendel.ndff_daz_bmp_bezoek WHERE reconstructieversie={version}),
  'confirmed_plots',(SELECT COUNT(DISTINCT plot_id) FROM Meijendel.ndff_daz_bmp_bezoek WHERE reconstructieversie={version}),
  'target_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_daz_bmp_bezoek_taxon WHERE reconstructieversie={version} AND doelrelatie='doelsoort'),
  'target_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_daz_bmp_bezoek_taxon WHERE reconstructieversie={version} AND doelrelatie='doelsoort' AND waarnemingsstatus='waargenomen'),
  'true_zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_daz_bmp_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='echte_nul'),
  'ambiguous_target_rows',(SELECT COUNT(*) FROM Meijendel.ndff_daz_bmp_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='onbepaald_ambigu'),
  'target_count_sum',(SELECT SUM(aantal) FROM Meijendel.ndff_daz_bmp_bezoek_taxon WHERE reconstructieversie={version} AND doelrelatie='doelsoort' AND waarnemingsstatus='waargenomen'),
  'bycatch_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_daz_bmp_bezoek_taxon WHERE reconstructieversie={version} AND doelrelatie='bijvangst'),
  'bycatch_positive_records',(SELECT SUM(bronrecordaantal) FROM Meijendel.ndff_daz_bmp_bezoek_taxon WHERE reconstructieversie={version} AND doelrelatie='bijvangst'),
  'ambiguous_confirmed_visits',(SELECT COUNT(*) FROM Meijendel.ndff_daz_bmp_bezoek WHERE reconstructieversie={version} AND ambigu_kandidaatrecordaantal>0),
  'secure_source_records',(SELECT COUNT(*) FROM Meijendel_ndff_secure.ndff_waarneming_register WHERE protocol LIKE '17.204%'),
  'secure_linked_to_public',(SELECT COUNT(*) FROM Meijendel_ndff_secure.ndff_waarneming_register r JOIN Meijendel_ndff_secure.ndff_open_secure_koppeling k ON k.secure_waarneming_id=r.waarneming_id WHERE r.protocol LIKE '17.204%' AND k.open_waarneming_id IS NOT NULL),
  'secure_derived_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({secure_tables})),
  'invalid_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_daz_bmp_bezoek_taxon WHERE reconstructieversie={version} AND ((waarnemingsstatus='waargenomen' AND (aantal IS NULL OR aantal=0 OR bronrecordaantal=0)) OR (waarnemingsstatus='echte_nul' AND (aantal<>0 OR bronrecordaantal<>0 OR ambigu_recordaantal<>0 OR doelrelatie<>'doelsoort')) OR (waarnemingsstatus='onbepaald_ambigu' AND (aantal IS NOT NULL OR bronrecordaantal<>0 OR ambigu_recordaantal=0 OR doelrelatie<>'doelsoort'))))
);
"""


def zeereep_validation_sql() -> str:
    version = sql_text(ZEEREEP_RULE_VERSION)
    secure_tables = ",".join(sql_text(f"ndff_zeereep_{suffix}") for suffix in (
        "kilometerhok", "bezoek", "bezoek_taxon",
    ))
    target_list = ",".join(sql_text(name) for name in sorted(ZEEREEP_TARGET_SPECIES))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '11.202%' AND soortgroep_raw='Schimmels'),
  'reconstructable_records',(SELECT SUM(bronrecordaantal) FROM Meijendel.ndff_zeereep_bezoek WHERE reconstructieversie={version}),
  'excluded_blurred_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '11.202%' AND soortgroep_raw='Schimmels' AND vervaagd=1),
  'kilometer_squares',(SELECT COUNT(*) FROM Meijendel.ndff_zeereep_kilometerhok WHERE reconstructieversie={version}),
  'visits',(SELECT COUNT(*) FROM Meijendel.ndff_zeereep_bezoek WHERE reconstructieversie={version}),
  'target_taxa',(SELECT COUNT(DISTINCT wetenschappelijke_naam) FROM Meijendel.ndff_zeereep_bezoek_taxon WHERE reconstructieversie={version}),
  'observed_target_rows',(SELECT COUNT(*) FROM Meijendel.ndff_zeereep_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen'),
  'true_zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_zeereep_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='echte_nul'),
  'matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_zeereep_bezoek_taxon WHERE reconstructieversie={version}),
  'target_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '11.202%' AND soortgroep_raw='Schimmels' AND vervaagd=0 AND wetenschappelijke_naam IN ({target_list})),
  'off_season_visits',(SELECT COUNT(*) FROM Meijendel.ndff_zeereep_bezoek WHERE reconstructieversie={version} AND seizoenstatus='buiten_kernseizoen'),
  'invalid_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_zeereep_bezoek_taxon WHERE reconstructieversie={version} AND ((waarnemingsstatus='waargenomen' AND (bronrecordaantal=0 OR hoogste_nmv_klasse='geen')) OR (waarnemingsstatus='echte_nul' AND (bronrecordaantal<>0 OR hoogste_nmv_klasse<>'geen')))),
  'legacy_secure_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({secure_tables}))
);
"""


def bospaddenstoel_validation_sql() -> str:
    version = sql_text(BOSPADDENSTOEL_RULE_VERSION)
    secure_tables = ",".join(sql_text(f"ndff_bospaddenstoel_{suffix}") for suffix in (
        "meetpunt", "geometrie", "recordselectie", "doelbereik", "bezoek",
        "bezoek_taxon", "jaar_taxon",
    ))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '11.201%' AND soortgroep_raw='Schimmels' AND vervaagd=0),
  'exact_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '11.201%' AND soortgroep_raw='Schimmels' AND vervaagd=0 AND schaal_telmethode='exact aantal'),
  'presence_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '11.201%' AND soortgroep_raw='Schimmels' AND vervaagd=0 AND schaal_telmethode='voorkomen'),
  'duplicate_presence_records',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_recordselectie WHERE reconstructieversie={version} AND selectiestatus='dubbele_presentie_onderdrukt'),
  'canonical_positive_records',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_recordselectie WHERE reconstructieversie={version} AND selectiestatus<>'dubbele_presentie_onderdrukt'),
  'meetpoints',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_meetpunt WHERE reconstructieversie={version}),
  'source_geometries',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_geometrie WHERE reconstructieversie={version}),
  'visits',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_bezoek WHERE reconstructieversie={version}),
  'target_scope_rows',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_doelbereik WHERE reconstructieversie={version}),
  'target_taxa',(SELECT COUNT(DISTINCT wetenschappelijke_naam) FROM Meijendel.ndff_bospaddenstoel_doelbereik WHERE reconstructieversie={version}),
  'target_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus IN ('waargenomen_exact','waargenomen_presentie')),
  'bycatch_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_recordselectie WHERE reconstructieversie={version} AND doelrelatie='bijvangst' AND selectiestatus<>'dubbele_presentie_onderdrukt'),
  'visit_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_bezoek_taxon WHERE reconstructieversie={version}),
  'true_zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='echte_nul'),
  'annual_rows',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_jaar_taxon WHERE reconstructieversie={version}),
  'annual_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_jaar_taxon WHERE reconstructieversie={version} AND jaarstatus<>'echte_nul'),
  'annual_zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_jaar_taxon WHERE reconstructieversie={version} AND jaarstatus='echte_nul'),
  'off_season_visits',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_bezoek WHERE reconstructieversie={version} AND seizoenstatus='buiten_kernseizoen'),
  'invalid_source_measurements',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '11.201%' AND soortgroep_raw='Schimmels' AND vervaagd=0 AND NOT ((schaal_telmethode='exact aantal' AND aantal_raw REGEXP '^[1-9][0-9]*$') OR (schaal_telmethode='voorkomen' AND aantal_raw='minimaal 1.0'))),
  'invalid_meetpoint_geometries',(SELECT COUNT(*) FROM (SELECT meetpunt_id FROM Meijendel.ndff_bospaddenstoel_geometrie WHERE reconstructieversie={version} GROUP BY meetpunt_id HAVING COUNT(*)<>2 OR COUNT(DISTINCT representatietype)<>2) q),
  'duplicate_target_missing',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_recordselectie d LEFT JOIN Meijendel.ndff_bospaddenstoel_recordselectie c ON c.reconstructieversie=d.reconstructieversie AND c.waarneming_id=d.canonieke_waarneming_id AND c.selectiestatus='opgenomen_exact' WHERE d.reconstructieversie={version} AND d.selectiestatus='dubbele_presentie_onderdrukt' AND c.waarneming_id IS NULL),
  'invalid_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_bezoek_taxon WHERE reconstructieversie={version} AND ((waarnemingsstatus='waargenomen_exact' AND (aantal_vruchtlichamen IS NULL OR aantal_vruchtlichamen=0 OR bronrecordaantal=0)) OR (waarnemingsstatus='waargenomen_presentie' AND (aantal_vruchtlichamen IS NOT NULL OR bronrecordaantal=0)) OR (waarnemingsstatus='echte_nul' AND (aantal_vruchtlichamen<>0 OR bronrecordaantal<>0)))),
  'invalid_annual_rows',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_jaar_taxon WHERE reconstructieversie={version} AND ((jaarstatus='maximum_exact' AND (maximum_vruchtlichamen IS NULL OR maximum_vruchtlichamen=0 OR positief_bezoekaantal=0)) OR (jaarstatus='alleen_presentie' AND (maximum_vruchtlichamen IS NOT NULL OR positief_bezoekaantal=0)) OR (jaarstatus='echte_nul' AND (maximum_vruchtlichamen<>0 OR positief_bezoekaantal<>0)))),
  'legacy_secure_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({secure_tables}))
);
"""


def hns_validation_sql() -> str:
    version = sql_text(HNS_RULE_VERSION)
    secure_tables = ",".join(sql_text(f"ndff_hns_{suffix}") for suffix in (
        "inventarisatie", "recordselectie", "doelbereik",
        "inventarisatie_taxon", "hok_jaar_taxon",
    ))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '12.204%' AND soortgroep_raw='Vaatplanten'),
  'year_aggregate_records',(SELECT COUNT(*) FROM Meijendel.ndff_hns_recordselectie WHERE reconstructieversie={version} AND selectiestatus='vervaagd_jaarrecord_niet_toegewezen'),
  'linked_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_hns_recordselectie WHERE reconstructieversie={version}),
  'inventories',(SELECT COUNT(*) FROM Meijendel.ndff_hns_inventarisatie WHERE reconstructieversie={version}),
  'complete_inventories',(SELECT COUNT(*) FROM Meijendel.ndff_hns_inventarisatie WHERE reconstructieversie={version} AND lijststatus='volledige_lijst_aannemelijk'),
  'fragment_inventories',(SELECT COUNT(*) FROM Meijendel.ndff_hns_inventarisatie WHERE reconstructieversie={version} AND lijststatus='fragment'),
  'complete_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_hns_recordselectie WHERE reconstructieversie={version} AND selectiestatus='opgenomen_volledige_lijst'),
  'fragment_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_hns_recordselectie WHERE reconstructieversie={version} AND selectiestatus='opgenomen_fragment'),
  'target_taxa',(SELECT COUNT(*) FROM Meijendel.ndff_hns_doelbereik WHERE reconstructieversie={version}),
  'visit_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_hns_inventarisatie_taxon WHERE reconstructieversie={version}),
  'positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_hns_inventarisatie_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen'),
  'true_zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_hns_inventarisatie_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='echte_nul'),
  'hok_years',(SELECT COUNT(*) FROM (SELECT doelhok,jaar FROM Meijendel.ndff_hns_hok_jaar_taxon WHERE reconstructieversie={version} GROUP BY doelhok,jaar) q),
  'annual_rows',(SELECT COUNT(*) FROM Meijendel.ndff_hns_hok_jaar_taxon WHERE reconstructieversie={version}),
  'annual_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_hns_hok_jaar_taxon WHERE reconstructieversie={version} AND jaarstatus='waargenomen'),
  'annual_zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_hns_hok_jaar_taxon WHERE reconstructieversie={version} AND jaarstatus='echte_nul'),
  'repeated_hok_years',(SELECT COUNT(*) FROM (SELECT doelhok,jaar FROM Meijendel.ndff_hns_inventarisatie WHERE reconstructieversie={version} AND lijststatus='volledige_lijst_aannemelijk' GROUP BY doelhok,jaar HAVING COUNT(*)>1) q),
  'independence_unconfirmed_visits',(SELECT COUNT(*) FROM Meijendel.ndff_hns_inventarisatie WHERE reconstructieversie={version} AND herhaalstatus='herhaling_aanwezig_onafhankelijkheid_niet_bevestigd'),
  'invalid_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_hns_inventarisatie_taxon WHERE reconstructieversie={version} AND ((waarnemingsstatus='waargenomen' AND bronrecordaantal=0) OR (waarnemingsstatus='echte_nul' AND bronrecordaantal<>0))),
  'matrix_size_mismatch',(SELECT COUNT(*) FROM (SELECT i.inventarisatie_sleutel,COUNT(t.wetenschappelijke_naam) matrixregels,(SELECT COUNT(*) FROM Meijendel.ndff_hns_doelbereik d WHERE d.reconstructieversie={version}) doelomvang FROM Meijendel.ndff_hns_inventarisatie i LEFT JOIN Meijendel.ndff_hns_inventarisatie_taxon t ON t.reconstructieversie=i.reconstructieversie AND t.inventarisatie_sleutel=i.inventarisatie_sleutel WHERE i.reconstructieversie={version} AND i.lijststatus='volledige_lijst_aannemelijk' GROUP BY i.inventarisatie_sleutel HAVING matrixregels<>doelomvang) q),
  'positive_source_mismatch',ABS((SELECT COALESCE(SUM(bronrecordaantal),0) FROM Meijendel.ndff_hns_inventarisatie_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen')-(SELECT COUNT(*) FROM Meijendel.ndff_hns_recordselectie WHERE reconstructieversie={version} AND selectiestatus='opgenomen_volledige_lijst')),
  'selection_status_mismatch',(SELECT COUNT(*) FROM Meijendel.ndff_hns_recordselectie s JOIN Meijendel.ndff_hns_inventarisatie i ON i.reconstructieversie=s.reconstructieversie AND i.inventarisatie_sleutel=s.inventarisatie_sleutel WHERE s.reconstructieversie={version} AND ((s.selectiestatus='opgenomen_volledige_lijst' AND i.lijststatus<>'volledige_lijst_aannemelijk') OR (s.selectiestatus='opgenomen_fragment' AND i.lijststatus<>'fragment'))),
  'invalid_annual_rows',(SELECT COUNT(*) FROM Meijendel.ndff_hns_hok_jaar_taxon WHERE reconstructieversie={version} AND ((jaarstatus='waargenomen' AND (positief_inventarisatieaantal=0 OR positief_inventarisatieaantal>inventarisatieaantal)) OR (jaarstatus='echte_nul' AND positief_inventarisatieaantal<>0))),
  'unlinked_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o LEFT JOIN Meijendel.ndff_hns_recordselectie s ON s.reconstructieversie={version} AND s.waarneming_id=o.waarneming_id WHERE o.protocol LIKE '12.204%' AND o.soortgroep_raw='Vaatplanten' AND s.waarneming_id IS NULL),
  'legacy_secure_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({secure_tables}))
);
"""


def korstmos_validation_sql() -> str:
    version = sql_text(KORSTMOS_RULE_VERSION)
    secure_tables = ",".join(sql_text(f"ndff_korstmos_{suffix}") for suffix in (
        "meetlocatie", "bezoek", "recordselectie", "doelbereik", "bezoek_taxon",
    ))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '02.202%' AND soortgroep_raw='Korstmossen' AND vervaagd=0),
  'excluded_blurred_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '02.202%' AND soortgroep_raw='Korstmossen' AND vervaagd=1),
  'meetlocations',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_meetlocatie WHERE reconstructieversie={version}),
  'repeated_meetlocations',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_meetlocatie WHERE reconstructieversie={version} AND herhaalstatus='herhaald_vast_proefvlak'),
  'oneoff_meetlocations',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_meetlocatie WHERE reconstructieversie={version} AND herhaalstatus='eenmalig_proefvlak'),
  'visits',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_bezoek WHERE reconstructieversie={version}),
  'repeated_location_visits',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_bezoek b JOIN Meijendel.ndff_korstmos_meetlocatie m ON m.reconstructieversie=b.reconstructieversie AND m.meetlocatie_id=b.meetlocatie_id WHERE b.reconstructieversie={version} AND m.herhaalstatus='herhaald_vast_proefvlak'),
  'oneoff_location_visits',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_bezoek b JOIN Meijendel.ndff_korstmos_meetlocatie m ON m.reconstructieversie=b.reconstructieversie AND m.meetlocatie_id=b.meetlocatie_id WHERE b.reconstructieversie={version} AND m.herhaalstatus='eenmalig_proefvlak'),
  'target_taxa',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_doelbereik WHERE reconstructieversie={version}),
  'recordselection_rows',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_recordselectie WHERE reconstructieversie={version}),
  'selected_records',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_recordselectie WHERE reconstructieversie={version} AND selectiestatus='opgenomen'),
  'suppressed_duplicate_records',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_recordselectie WHERE reconstructieversie={version} AND selectiestatus='dubbele_registratie_onderdrukt'),
  'abundance_conflict_records',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_recordselectie WHERE reconstructieversie={version} AND selectiestatus='abundantieconflict_bewaard'),
  'matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_bezoek_taxon WHERE reconstructieversie={version}),
  'positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus<>'echte_nul'),
  'normal_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen'),
  'conflict_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen_abundantieconflict'),
  'true_zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='echte_nul'),
  'single_plot_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o JOIN Meijendel.ndff_open_ruimtelijke_beoordeling r ON r.waarneming_id=o.waarneming_id AND r.regelversie={sql_text(RULE_VERSION)} WHERE o.protocol LIKE '02.202%' AND o.soortgroep_raw='Korstmossen' AND o.vervaagd=0 AND r.toewijzingskwaliteit='single_volledig_binnen'),
  'multiple_plot_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o JOIN Meijendel.ndff_open_ruimtelijke_beoordeling r ON r.waarneming_id=o.waarneming_id AND r.regelversie={sql_text(RULE_VERSION)} WHERE o.protocol LIKE '02.202%' AND o.soortgroep_raw='Korstmossen' AND o.vervaagd=0 AND r.ruimtelijke_klasse='multiple'),
  'invalid_source_measurements',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '02.202%' AND soortgroep_raw='Korstmossen' AND vervaagd=0 AND (schaal_telmethode<>'BLWG-bedekkingsklassen' OR aantal_raw NOT IN ('0.01 - 0.1','minimaal 0.1'))),
  'invalid_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_bezoek_taxon WHERE reconstructieversie={version} AND ((waarnemingsstatus='waargenomen' AND (bedekkingsklasse_raw IS NULL OR bedekkingsrang NOT IN (1,2) OR bronrecordaantal=0)) OR (waarnemingsstatus='waargenomen_abundantieconflict' AND (bedekkingsklasse_raw IS NOT NULL OR bedekkingsrang IS NOT NULL OR bronrecordaantal<2)) OR (waarnemingsstatus='echte_nul' AND (bedekkingsklasse_raw IS NOT NULL OR bedekkingsrang<>0 OR bronrecordaantal<>0)))),
  'matrix_size_mismatch',(SELECT COUNT(*) FROM (SELECT b.bezoek_sleutel,COUNT(t.wetenschappelijke_naam) matrixregels,(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_doelbereik d WHERE d.reconstructieversie={version}) doelomvang FROM Meijendel.ndff_korstmos_bezoek b LEFT JOIN Meijendel.ndff_korstmos_bezoek_taxon t ON t.reconstructieversie=b.reconstructieversie AND t.bezoek_sleutel=b.bezoek_sleutel WHERE b.reconstructieversie={version} GROUP BY b.bezoek_sleutel HAVING matrixregels<>doelomvang) q),
  'positive_source_mismatch',ABS((SELECT COALESCE(SUM(bronrecordaantal),0) FROM Meijendel.ndff_korstmos_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus<>'echte_nul')-(SELECT COUNT(*) FROM Meijendel.ndff_korstmos_recordselectie WHERE reconstructieversie={version})),
  'unlinked_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o LEFT JOIN Meijendel.ndff_korstmos_recordselectie s ON s.reconstructieversie={version} AND s.waarneming_id=o.waarneming_id WHERE o.protocol LIKE '02.202%' AND o.soortgroep_raw='Korstmossen' AND o.vervaagd=0 AND s.waarneming_id IS NULL),
  'secure_derived_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({secure_tables}))
);
"""


def mos_validation_sql() -> str:
    version = sql_text(MOS_RULE_VERSION)
    secure_tables = ",".join(sql_text(f"ndff_mos_{suffix}") for suffix in (
        "inventarisatie", "datumcluster", "recordselectie", "doelbereik",
        "inventarisatie_taxon",
    ))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '02.204%' AND soortgroep_raw='Mossen' AND vervaagd=0),
  'excluded_blurred_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '02.204%' AND soortgroep_raw='Mossen' AND vervaagd=1),
  'inventories',(SELECT COUNT(*) FROM Meijendel.ndff_mos_inventarisatie WHERE reconstructieversie={version}),
  'single_year_inventories',(SELECT COUNT(*) FROM Meijendel.ndff_mos_inventarisatie WHERE reconstructieversie={version} AND jaarstatus='binnen_een_jaar'),
  'cross_year_inventories',(SELECT COUNT(*) FROM Meijendel.ndff_mos_inventarisatie WHERE reconstructieversie={version} AND jaarstatus='overspant_jaargrens'),
  'date_clusters',(SELECT COUNT(*) FROM Meijendel.ndff_mos_datumcluster WHERE reconstructieversie={version}),
  'day_clusters',(SELECT COUNT(*) FROM Meijendel.ndff_mos_datumcluster WHERE reconstructieversie={version} AND tijdprecisie='dag'),
  'year_clusters',(SELECT COUNT(*) FROM Meijendel.ndff_mos_datumcluster WHERE reconstructieversie={version} AND tijdprecisie='jaar'),
  'single_date_inventories',(SELECT COUNT(*) FROM Meijendel.ndff_mos_inventarisatie WHERE reconstructieversie={version} AND datumclusteraantal=1),
  'multiple_date_inventories',(SELECT COUNT(*) FROM Meijendel.ndff_mos_inventarisatie WHERE reconstructieversie={version} AND datumclusteraantal>1),
  'target_taxa',(SELECT COUNT(*) FROM Meijendel.ndff_mos_doelbereik WHERE reconstructieversie={version}),
  'recordselection_rows',(SELECT COUNT(*) FROM Meijendel.ndff_mos_recordselectie WHERE reconstructieversie={version}),
  'selected_records',(SELECT COUNT(*) FROM Meijendel.ndff_mos_recordselectie WHERE reconstructieversie={version} AND selectiestatus='opgenomen'),
  'suppressed_duplicate_records',(SELECT COUNT(*) FROM Meijendel.ndff_mos_recordselectie WHERE reconstructieversie={version} AND selectiestatus='dubbele_registratie_onderdrukt'),
  'abundance_conflict_records',(SELECT COUNT(*) FROM Meijendel.ndff_mos_recordselectie WHERE reconstructieversie={version} AND selectiestatus='abundantieconflict_bewaard'),
  'matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_mos_inventarisatie_taxon WHERE reconstructieversie={version}),
  'positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_mos_inventarisatie_taxon WHERE reconstructieversie={version} AND waarnemingsstatus<>'echte_nul'),
  'abundance_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_mos_inventarisatie_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen_aantalsklasse'),
  'presence_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_mos_inventarisatie_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen_presentie'),
  'conflict_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_mos_inventarisatie_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen_abundantieconflict'),
  'true_zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_mos_inventarisatie_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='echte_nul'),
  'single_plot_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o JOIN Meijendel.ndff_open_ruimtelijke_beoordeling r ON r.waarneming_id=o.waarneming_id AND r.regelversie={sql_text(RULE_VERSION)} WHERE o.protocol LIKE '02.204%' AND o.soortgroep_raw='Mossen' AND o.vervaagd=0 AND r.toewijzingskwaliteit='single_volledig_binnen'),
  'multiple_plot_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o JOIN Meijendel.ndff_open_ruimtelijke_beoordeling r ON r.waarneming_id=o.waarneming_id AND r.regelversie={sql_text(RULE_VERSION)} WHERE o.protocol LIKE '02.204%' AND o.soortgroep_raw='Mossen' AND o.vervaagd=0 AND r.ruimtelijke_klasse='multiple'),
  'invalid_source_measurements',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '02.204%' AND soortgroep_raw='Mossen' AND vervaagd=0 AND NOT ((schaal_telmethode='BLWG-aantalsklassen' AND aantal_raw IN ('1.0','2.0 - 5.0','minimaal 6.0')) OR (schaal_telmethode IN ('aanwezig','voorkomen') AND aantal_raw='minimaal 1.0'))),
  'invalid_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_mos_inventarisatie_taxon WHERE reconstructieversie={version} AND ((waarnemingsstatus='waargenomen_aantalsklasse' AND (bron_schaal<>'BLWG-aantalsklassen' OR aantalsklasse_raw IS NULL OR aantalsrang NOT IN (1,2,3) OR bronrecordaantal=0)) OR (waarnemingsstatus='waargenomen_presentie' AND (bron_schaal NOT IN ('aanwezig','voorkomen') OR aantalsklasse_raw<>'minimaal 1.0' OR aantalsrang IS NOT NULL OR bronrecordaantal=0)) OR (waarnemingsstatus='waargenomen_abundantieconflict' AND (bron_schaal IS NOT NULL OR aantalsklasse_raw IS NOT NULL OR aantalsrang IS NOT NULL OR bronrecordaantal<2)) OR (waarnemingsstatus='echte_nul' AND (bron_schaal IS NOT NULL OR aantalsklasse_raw IS NOT NULL OR aantalsrang<>0 OR bronrecordaantal<>0)))),
  'matrix_size_mismatch',(SELECT COUNT(*) FROM (SELECT i.inventarisatie_sleutel,COUNT(t.wetenschappelijke_naam) matrixregels,(SELECT COUNT(*) FROM Meijendel.ndff_mos_doelbereik d WHERE d.reconstructieversie={version}) doelomvang FROM Meijendel.ndff_mos_inventarisatie i LEFT JOIN Meijendel.ndff_mos_inventarisatie_taxon t ON t.reconstructieversie=i.reconstructieversie AND t.inventarisatie_sleutel=i.inventarisatie_sleutel WHERE i.reconstructieversie={version} GROUP BY i.inventarisatie_sleutel HAVING matrixregels<>doelomvang) q),
  'positive_source_mismatch',ABS((SELECT COALESCE(SUM(bronrecordaantal),0) FROM Meijendel.ndff_mos_inventarisatie_taxon WHERE reconstructieversie={version} AND waarnemingsstatus<>'echte_nul')-(SELECT COUNT(*) FROM Meijendel.ndff_mos_recordselectie WHERE reconstructieversie={version})),
  'unlinked_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o LEFT JOIN Meijendel.ndff_mos_recordselectie s ON s.reconstructieversie={version} AND s.waarneming_id=o.waarneming_id WHERE o.protocol LIKE '02.204%' AND o.soortgroep_raw='Mossen' AND o.vervaagd=0 AND s.waarneming_id IS NULL),
  'secure_derived_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({secure_tables}))
);
"""


def florbase_validation_sql() -> str:
    version = sql_text(FLORBASE_RULE_VERSION)
    secure_tables = ",".join(sql_text(f"ndff_florbase_{suffix}") for suffix in (
        "inventarisatie", "recordselectie", "doelbereik", "inventarisatie_taxon",
    ))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '12.001%' AND soortgroep_raw='Vaatplanten' AND vervaagd=0),
  'excluded_blurred_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '12.001%' AND soortgroep_raw='Vaatplanten' AND vervaagd=1),
  'inventories',(SELECT COUNT(*) FROM Meijendel.ndff_florbase_inventarisatie WHERE reconstructieversie={version}),
  'complete_inventories',(SELECT COUNT(*) FROM Meijendel.ndff_florbase_inventarisatie WHERE reconstructieversie={version} AND lijststatus='volledige_lijst_aannemelijk'),
  'fragment_inventories',(SELECT COUNT(*) FROM Meijendel.ndff_florbase_inventarisatie WHERE reconstructieversie={version} AND lijststatus='fragment'),
  'complete_source_records',(SELECT COALESCE(SUM(bronrecordaantal),0) FROM Meijendel.ndff_florbase_inventarisatie WHERE reconstructieversie={version} AND lijststatus='volledige_lijst_aannemelijk'),
  'fragment_source_records',(SELECT COALESCE(SUM(bronrecordaantal),0) FROM Meijendel.ndff_florbase_inventarisatie WHERE reconstructieversie={version} AND lijststatus='fragment'),
  'complete_hoks',(SELECT COUNT(DISTINCT CONCAT(hok_x,'-',hok_y)) FROM Meijendel.ndff_florbase_inventarisatie WHERE reconstructieversie={version} AND lijststatus='volledige_lijst_aannemelijk'),
  'all_hoks',(SELECT COUNT(DISTINCT CONCAT(hok_x,'-',hok_y)) FROM Meijendel.ndff_florbase_inventarisatie WHERE reconstructieversie={version}),
  'target_taxa',(SELECT COUNT(*) FROM Meijendel.ndff_florbase_doelbereik WHERE reconstructieversie={version}),
  'matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_florbase_inventarisatie_taxon WHERE reconstructieversie={version}),
  'positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_florbase_inventarisatie_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen'),
  'presence_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_florbase_inventarisatie_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen' AND meetwaardestatus='alleen_presentie'),
  'amount_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_florbase_inventarisatie_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen' AND meetwaardestatus='aantalsinformatie_niet_aggregeerbaar'),
  'preliminary_zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_florbase_inventarisatie_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='protocolnul_onder_volledigheidsaanname'),
  'invalid_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_florbase_inventarisatie_taxon WHERE reconstructieversie={version} AND ((waarnemingsstatus='waargenomen' AND (bronrecordaantal=0 OR meetwaardestatus='niet_van_toepassing' OR nulregel<>'niet_van_toepassing' OR JSON_LENGTH(meetwaarden_json)=0)) OR (waarnemingsstatus='protocolnul_onder_volledigheidsaanname' AND (bronrecordaantal<>0 OR meetwaardestatus<>'niet_van_toepassing' OR nulregel<>'niet_gemeld_op_12_001_hokjaar_met_minimaal_50_taxa' OR JSON_LENGTH(meetwaarden_json)<>0)))),
  'matrix_size_mismatch',(SELECT COUNT(*) FROM (SELECT i.inventarisatie_sleutel,COUNT(t.wetenschappelijke_naam) matrixregels,(SELECT COUNT(*) FROM Meijendel.ndff_florbase_doelbereik d WHERE d.reconstructieversie={version}) doelomvang FROM Meijendel.ndff_florbase_inventarisatie i LEFT JOIN Meijendel.ndff_florbase_inventarisatie_taxon t ON t.reconstructieversie=i.reconstructieversie AND t.inventarisatie_sleutel=i.inventarisatie_sleutel WHERE i.reconstructieversie={version} AND i.lijststatus='volledige_lijst_aannemelijk' GROUP BY i.inventarisatie_sleutel HAVING matrixregels<>doelomvang) q),
  'positive_source_mismatch',ABS((SELECT COALESCE(SUM(bronrecordaantal),0) FROM Meijendel.ndff_florbase_inventarisatie_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen')-(SELECT COUNT(*) FROM Meijendel.ndff_florbase_recordselectie WHERE reconstructieversie={version} AND selectiestatus='opgenomen_volledige_lijst')),
  'unlinked_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o LEFT JOIN Meijendel.ndff_florbase_recordselectie s ON s.reconstructieversie={version} AND s.waarneming_id=o.waarneming_id WHERE o.protocol LIKE '12.001%' AND o.soortgroep_raw='Vaatplanten' AND o.vervaagd=0 AND s.waarneming_id IS NULL),
  'pq_non_applicable_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o JOIN Meijendel.ndff_open_pq_koppeling p ON p.waarneming_id=o.waarneming_id AND p.regelversie={sql_text(PUBLIC_PQ_RULE_VERSION)} WHERE o.protocol LIKE '12.001%' AND o.soortgroep_raw='Vaatplanten' AND p.classificatie='niet_van_toepassing'),
  'pq_other_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o JOIN Meijendel.ndff_open_pq_koppeling p ON p.waarneming_id=o.waarneming_id AND p.regelversie={sql_text(PUBLIC_PQ_RULE_VERSION)} WHERE o.protocol LIKE '12.001%' AND o.soortgroep_raw='Vaatplanten' AND p.classificatie<>'niet_van_toepassing'),
  'secure_derived_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({secure_tables}))
);
"""


def habslak_validation_sql() -> str:
    version = sql_text(HABSLAK_RULE_VERSION)
    secure_tables = ",".join(sql_text(f"ndff_habslak_{suffix}") for suffix in (
        "monster", "recordselectie", "monster_taxon", "hokjaar",
    ))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '04.006%' AND soortgroep_raw='Weekdieren'),
  'unblurred_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '04.006%' AND soortgroep_raw='Weekdieren' AND vervaagd=0),
  'blurred_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '04.006%' AND soortgroep_raw='Weekdieren' AND vervaagd=1),
  'sample_events',(SELECT COUNT(*) FROM Meijendel.ndff_habslak_monster WHERE reconstructieversie={version}),
  'positive_event_taxa',(SELECT COUNT(*) FROM Meijendel.ndff_habslak_monster_taxon WHERE reconstructieversie={version}),
  'square_years',(SELECT COUNT(*) FROM Meijendel.ndff_habslak_hokjaar WHERE reconstructieversie={version}),
  'sufficient_square_years',(SELECT COUNT(*) FROM Meijendel.ndff_habslak_hokjaar WHERE reconstructieversie={version} AND bemonsteringsstatus='voldoende_minimaal_15'),
  'insufficient_square_years',(SELECT COUNT(*) FROM Meijendel.ndff_habslak_hokjaar WHERE reconstructieversie={version} AND bemonsteringsstatus='onvoldoende_minder_dan_15'),
  'target_positive_square_years',(SELECT COUNT(*) FROM Meijendel.ndff_habslak_hokjaar WHERE reconstructieversie={version} AND doelsoortstatus='waargenomen'),
  'preliminary_zero_square_years',(SELECT COUNT(*) FROM Meijendel.ndff_habslak_hokjaar WHERE reconstructieversie={version} AND doelsoortstatus='protocolnul_onder_doelbereikaanname'),
  'invalid_sample_rows',(SELECT COUNT(*) FROM Meijendel.ndff_habslak_monster m WHERE m.reconstructieversie={version} AND ((m.plotstatus='single_volledig_binnen' AND m.eenduidig_plot_id IS NULL) OR (m.plotstatus<>'single_volledig_binnen' AND m.eenduidig_plot_id IS NOT NULL) OR m.bronrecordaantal=0 OR m.geregistreerde_taxa=0)),
  'unlinked_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o LEFT JOIN Meijendel.ndff_habslak_recordselectie s ON s.reconstructieversie={version} AND s.waarneming_id=o.waarneming_id WHERE o.protocol LIKE '04.006%' AND o.soortgroep_raw='Weekdieren' AND s.waarneming_id IS NULL),
  'secure_derived_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({secure_tables}))
);
"""


def braakbal_validation_sql() -> str:
    version = sql_text(BRAAKBAL_RULE_VERSION)
    secure_tables = ",".join(sql_text(f"ndff_braakbal_{suffix}") for suffix in (
        "hokjaar", "recordselectie", "hokjaar_taxon",
    ))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '17.002%'),
  'blurred_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '17.002%' AND vervaagd=1),
  'unblurred_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '17.002%' AND vervaagd=0),
  'hok_years',(SELECT COUNT(*) FROM Meijendel.ndff_braakbal_hokjaar WHERE reconstructieversie={version}),
  'taxon_rows',(SELECT COUNT(*) FROM Meijendel.ndff_braakbal_hokjaar_taxon WHERE reconstructieversie={version}),
  'distinct_taxa',(SELECT COUNT(DISTINCT wetenschappelijke_naam) FROM Meijendel.ndff_braakbal_hokjaar_taxon WHERE reconstructieversie={version}),
  'total_prey_count',(SELECT COALESCE(SUM(som_prooidieren),0) FROM Meijendel.ndff_braakbal_hokjaar WHERE reconstructieversie={version}),
  'field_mouse_count',(SELECT COALESCE(SUM(veldmuis_aantal),0) FROM Meijendel.ndff_braakbal_hokjaar WHERE reconstructieversie={version}),
  'minimum_150_party_unknown',(SELECT COUNT(*) FROM Meijendel.ndff_braakbal_hokjaar WHERE reconstructieversie={version} AND inspanningsstatus='som_minimaal_150_partij_onbekend'),
  'under_150',(SELECT COUNT(*) FROM Meijendel.ndff_braakbal_hokjaar WHERE reconstructieversie={version} AND inspanningsstatus='som_minder_dan_150'),
  'annual_aggregates',(SELECT COUNT(*) FROM Meijendel.ndff_braakbal_hokjaar WHERE reconstructieversie={version} AND bronperiodestatus='jaaraggregaat'),
  'dated_registrations',(SELECT COUNT(*) FROM Meijendel.ndff_braakbal_hokjaar WHERE reconstructieversie={version} AND bronperiodestatus='gedateerde_registratie'),
  'mixed_period_aggregates',(SELECT COUNT(*) FROM Meijendel.ndff_braakbal_hokjaar WHERE reconstructieversie={version} AND bronperiodestatus='gemengd'),
  'multi_year_aggregates',(SELECT COUNT(*) FROM Meijendel.ndff_braakbal_hokjaar WHERE reconstructieversie={version} AND bronperiodestatus='meerjaaraggregaat'),
  'other_interval_aggregates',(SELECT COUNT(*) FROM Meijendel.ndff_braakbal_hokjaar WHERE reconstructieversie={version} AND bronperiodestatus='overig_interval'),
  'inferred_zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_braakbal_hokjaar WHERE reconstructieversie={version} AND nulstatus<>'geen_nul_afleidbaar'),
  'plot_linked_rows',(SELECT COUNT(*) FROM Meijendel.ndff_braakbal_hokjaar WHERE reconstructieversie={version} AND plotstatus<>'niet_gekoppeld_grove_brongeometrie'),
  'invalid_hokyear_rows',(SELECT COUNT(*) FROM Meijendel.ndff_braakbal_hokjaar h WHERE h.reconstructieversie={version} AND (h.bronrecordaantal=0 OR h.geregistreerde_taxa=0 OR h.som_prooidieren=0 OR ABS(h.veldmuis_aandeel*h.som_prooidieren-h.veldmuis_aantal)>0.00002)),
  'unlinked_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o LEFT JOIN Meijendel.ndff_braakbal_recordselectie s ON s.reconstructieversie={version} AND s.waarneming_id=o.waarneming_id WHERE o.protocol LIKE '17.002%' AND s.waarneming_id IS NULL),
  'secure_derived_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({secure_tables}))
);
"""


def tuintelling_validation_sql() -> str:
    version = sql_text(TUINTELLING_RULE_VERSION)
    secure_tables = ",".join(sql_text(f"ndff_tuintelling_{suffix}") for suffix in (
        "tuinvakfamilie", "geometrie", "telperiode", "periode_soortgroep",
        "periode_soortgroep_taxon", "recordselectie",
    ))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '102.002%'),
  'geometry_versions',(SELECT COUNT(*) FROM Meijendel.ndff_tuintelling_geometrie WHERE reconstructieversie={version}),
  'garden_area_families',(SELECT COUNT(*) FROM Meijendel.ndff_tuintelling_tuinvakfamilie WHERE reconstructieversie={version}),
  'periods',(SELECT COUNT(*) FROM Meijendel.ndff_tuintelling_telperiode WHERE reconstructieversie={version}),
  'weekly_periods',(SELECT COUNT(*) FROM Meijendel.ndff_tuintelling_telperiode WHERE reconstructieversie={version} AND teltype='weektelling'),
  'day_periods',(SELECT COUNT(*) FROM Meijendel.ndff_tuintelling_telperiode WHERE reconstructieversie={version} AND teltype='dagperiode'),
  'point_periods',(SELECT COUNT(*) FROM Meijendel.ndff_tuintelling_telperiode WHERE reconstructieversie={version} AND teltype='tijdstiptelling'),
  'other_periods',(SELECT COUNT(*) FROM Meijendel.ndff_tuintelling_telperiode WHERE reconstructieversie={version} AND teltype='overige_periode'),
  'group_periods',(SELECT COUNT(*) FROM Meijendel.ndff_tuintelling_periode_soortgroep WHERE reconstructieversie={version}),
  'local_target_taxa',(SELECT COUNT(DISTINCT wetenschappelijke_naam) FROM Meijendel.ndff_tuintelling_periode_soortgroep_taxon WHERE reconstructieversie={version}),
  'matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_tuintelling_periode_soortgroep_taxon WHERE reconstructieversie={version}),
  'positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_tuintelling_periode_soortgroep_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen'),
  'preliminary_zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_tuintelling_periode_soortgroep_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='protocolnul_binnen_lokaal_doelbereik'),
  'exact_count_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '102.002%' AND schaal_telmethode='exact aantal'),
  'presence_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '102.002%' AND schaal_telmethode='voorkomen'),
  'outside_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o JOIN Meijendel.ndff_open_ruimtelijke_beoordeling r ON r.waarneming_id=o.waarneming_id AND r.regelversie={sql_text(RULE_VERSION)} WHERE o.protocol LIKE '102.002%' AND r.toewijzingskwaliteit='outside'),
  'multiple_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o JOIN Meijendel.ndff_open_ruimtelijke_beoordeling r ON r.waarneming_id=o.waarneming_id AND r.regelversie={sql_text(RULE_VERSION)} WHERE o.protocol LIKE '102.002%' AND r.toewijzingskwaliteit='multiple'),
  'post_renewal_periods',(SELECT COUNT(*) FROM Meijendel.ndff_tuintelling_telperiode WHERE reconstructieversie={version} AND periode_start>='2022-07-07'),
  'plot_linked_rows',(SELECT COUNT(*) FROM Meijendel.ndff_tuintelling_telperiode WHERE reconstructieversie={version} AND plotstatus<>'niet_gekoppeld_geen_meijendelplot'),
  'invalid_matrix_rows',(SELECT COUNT(*) FROM Meijendel.ndff_tuintelling_periode_soortgroep_taxon WHERE reconstructieversie={version} AND ((waarnemingsstatus='waargenomen' AND (bronrecordaantal=0 OR JSON_LENGTH(meetwaarden_json)=0 OR nulregel<>'niet_van_toepassing')) OR (waarnemingsstatus='protocolnul_binnen_lokaal_doelbereik' AND (bronrecordaantal<>0 OR JSON_LENGTH(meetwaarden_json)<>0 OR nulregel<>'niet_gemeld_binnen_positief_bevestigde_soortgroeptelling')))),
  'matrix_size_mismatch',ABS((SELECT COUNT(*) FROM Meijendel.ndff_tuintelling_periode_soortgroep_taxon WHERE reconstructieversie={version})-(SELECT COALESCE(SUM(lokale_doelsoorten),0) FROM Meijendel.ndff_tuintelling_periode_soortgroep WHERE reconstructieversie={version})),
  'positive_source_mismatch',ABS((SELECT COALESCE(SUM(bronrecordaantal),0) FROM Meijendel.ndff_tuintelling_periode_soortgroep_taxon WHERE reconstructieversie={version} AND waarnemingsstatus='waargenomen')-(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '102.002%')),
  'unlinked_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o LEFT JOIN Meijendel.ndff_tuintelling_recordselectie s ON s.reconstructieversie={version} AND s.waarneming_id=o.waarneming_id WHERE o.protocol LIKE '102.002%' AND s.waarneming_id IS NULL),
  'secure_derived_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({secure_tables}))
);
"""


def liveatlas_validation_sql() -> str:
    version = sql_text(LIVEATLAS_RULE_VERSION)
    secure_tables = ",".join(sql_text(f"ndff_liveatlas_{suffix}") for suffix in (
        "bezoek", "bezoek_soortgroep", "bezoek_taxon", "recordselectie",
    ))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '102.005%'),
  'visits',(SELECT COUNT(*) FROM Meijendel.ndff_liveatlas_bezoek WHERE reconstructieversie={version}),
  'group_visits',(SELECT COUNT(*) FROM Meijendel.ndff_liveatlas_bezoek_soortgroep WHERE reconstructieversie={version}),
  'taxon_rows',(SELECT COUNT(*) FROM Meijendel.ndff_liveatlas_bezoek_taxon WHERE reconstructieversie={version}),
  'distinct_taxa',(SELECT COUNT(DISTINCT wetenschappelijke_naam) FROM Meijendel.ndff_liveatlas_bezoek_taxon WHERE reconstructieversie={version}),
  'geometry_versions',(SELECT COUNT(DISTINCT openbare_geometrie_sha256) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '102.005%'),
  'exact_count_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '102.005%' AND schaal_telmethode='exact aantal' AND aantal_raw REGEXP '^[0-9]+$'),
  'total_count',(SELECT COALESCE(SUM(totaal_aantal),0) FROM Meijendel.ndff_liveatlas_bezoek_taxon WHERE reconstructieversie={version}),
  'butterfly_visits',(SELECT COUNT(*) FROM Meijendel.ndff_liveatlas_bezoek_soortgroep WHERE reconstructieversie={version} AND soortgroep_raw='Dagvlinders'),
  'dragonfly_visits',(SELECT COUNT(*) FROM Meijendel.ndff_liveatlas_bezoek_soortgroep WHERE reconstructieversie={version} AND soortgroep_raw='Libellen'),
  'short_visits',(SELECT COUNT(*) FROM Meijendel.ndff_liveatlas_bezoek WHERE reconstructieversie={version} AND duurstatus='korter_dan_15'),
  'recommended_duration_visits',(SELECT COUNT(*) FROM Meijendel.ndff_liveatlas_bezoek WHERE reconstructieversie={version} AND duurstatus='binnen_advies_15_90'),
  'long_visits',(SELECT COUNT(*) FROM Meijendel.ndff_liveatlas_bezoek WHERE reconstructieversie={version} AND duurstatus='langer_dan_90'),
  'single_plot_visits',(SELECT COUNT(*) FROM Meijendel.ndff_liveatlas_bezoek WHERE reconstructieversie={version} AND ruimtelijke_status='single_volledig_binnen'),
  'multiple_visits',(SELECT COUNT(*) FROM Meijendel.ndff_liveatlas_bezoek WHERE reconstructieversie={version} AND ruimtelijke_status='multiple'),
  'outside_visits',(SELECT COUNT(*) FROM Meijendel.ndff_liveatlas_bezoek WHERE reconstructieversie={version} AND ruimtelijke_status='outside'),
  'mixed_visits',(SELECT COUNT(*) FROM Meijendel.ndff_liveatlas_bezoek WHERE reconstructieversie={version} AND ruimtelijke_status='gemengd'),
  'completeness_unknown_group_visits',(SELECT COUNT(*) FROM Meijendel.ndff_liveatlas_bezoek_soortgroep WHERE reconstructieversie={version} AND volledigheidsstatus='niet_meegeleverd'),
  'zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_liveatlas_bezoek_taxon WHERE reconstructieversie={version} AND waarnemingsstatus<>'waargenomen'),
  'invalid_taxon_rows',(SELECT COUNT(*) FROM Meijendel.ndff_liveatlas_bezoek_taxon WHERE reconstructieversie={version} AND (bronrecordaantal=0 OR totaal_aantal=0 OR JSON_LENGTH(meetwaarden_json)=0 OR nulregel<>'geen_nul_afleidbaar')),
  'positive_source_mismatch',ABS((SELECT COALESCE(SUM(bronrecordaantal),0) FROM Meijendel.ndff_liveatlas_bezoek_taxon WHERE reconstructieversie={version})-(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '102.005%')),
  'unlinked_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o LEFT JOIN Meijendel.ndff_liveatlas_recordselectie s ON s.reconstructieversie={version} AND s.waarneming_id=o.waarneming_id WHERE o.protocol LIKE '102.005%' AND s.waarneming_id IS NULL),
  'secure_derived_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({secure_tables}))
);
"""


def kwartiertelling_validation_sql() -> str:
    version = sql_text(KWARTIERTELLING_RULE_VERSION)
    secure_tables = ",".join(
        sql_text(f"ndff_kwartiertelling_{suffix}")
        for suffix in (
            "telinterval", "interval_soortgroep", "interval_taxon", "recordselectie",
        )
    )
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '102.007%'),
  'intervals',(SELECT COUNT(*) FROM Meijendel.ndff_kwartiertelling_telinterval WHERE reconstructieversie={version}),
  'group_intervals',(SELECT COUNT(*) FROM Meijendel.ndff_kwartiertelling_interval_soortgroep WHERE reconstructieversie={version}),
  'taxon_rows',(SELECT COUNT(*) FROM Meijendel.ndff_kwartiertelling_interval_taxon WHERE reconstructieversie={version}),
  'distinct_taxa',(SELECT COUNT(DISTINCT wetenschappelijke_naam) FROM Meijendel.ndff_kwartiertelling_interval_taxon WHERE reconstructieversie={version}),
  'geometry_versions',(SELECT COUNT(DISTINCT openbare_geometrie_sha256) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '102.007%'),
  'exact_count_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '102.007%' AND schaal_telmethode='exact aantal' AND aantal_raw REGEXP '^[0-9]+$'),
  'total_count',(SELECT COALESCE(SUM(totaal_aantal),0) FROM Meijendel.ndff_kwartiertelling_interval_taxon WHERE reconstructieversie={version}),
  'butterfly_intervals',(SELECT COUNT(*) FROM Meijendel.ndff_kwartiertelling_interval_soortgroep WHERE reconstructieversie={version} AND soortgroep_raw='Dagvlinders'),
  'moth_intervals',(SELECT COUNT(*) FROM Meijendel.ndff_kwartiertelling_interval_soortgroep WHERE reconstructieversie={version} AND soortgroep_raw='Nachtvlinders'),
  'short_intervals',(SELECT COUNT(*) FROM Meijendel.ndff_kwartiertelling_telinterval WHERE reconstructieversie={version} AND duurstatus='korter_dan_15_toegestaan'),
  'protocol_duration_intervals',(SELECT COUNT(*) FROM Meijendel.ndff_kwartiertelling_telinterval WHERE reconstructieversie={version} AND duurstatus='protocolconform_15_minuten'),
  'overlong_intervals',(SELECT COUNT(*) FROM Meijendel.ndff_kwartiertelling_telinterval WHERE reconstructieversie={version} AND duurstatus='bronafwijking_boven_15_minuten'),
  'single_plot_intervals',(SELECT COUNT(*) FROM Meijendel.ndff_kwartiertelling_telinterval WHERE reconstructieversie={version} AND ruimtelijke_status='single_volledig_binnen'),
  'multiple_intervals',(SELECT COUNT(*) FROM Meijendel.ndff_kwartiertelling_telinterval WHERE reconstructieversie={version} AND ruimtelijke_status='multiple'),
  'outside_intervals',(SELECT COUNT(*) FROM Meijendel.ndff_kwartiertelling_telinterval WHERE reconstructieversie={version} AND ruimtelijke_status='outside'),
  'mixed_intervals',(SELECT COUNT(*) FROM Meijendel.ndff_kwartiertelling_telinterval WHERE reconstructieversie={version} AND ruimtelijke_status='gemengd'),
  'completeness_unknown_group_intervals',(SELECT COUNT(*) FROM Meijendel.ndff_kwartiertelling_interval_soortgroep WHERE reconstructieversie={version} AND volledigheidsstatus='niet_meegeleverd_ononderscheidbaar_soortgericht'),
  'zero_rows',(SELECT COUNT(*) FROM Meijendel.ndff_kwartiertelling_interval_taxon WHERE reconstructieversie={version} AND waarnemingsstatus<>'waargenomen'),
  'invalid_taxon_rows',(SELECT COUNT(*) FROM Meijendel.ndff_kwartiertelling_interval_taxon WHERE reconstructieversie={version} AND (bronrecordaantal=0 OR totaal_aantal=0 OR JSON_LENGTH(meetwaarden_json)=0 OR nulregel<>'geen_nul_afleidbaar')),
  'positive_source_mismatch',ABS((SELECT COALESCE(SUM(bronrecordaantal),0) FROM Meijendel.ndff_kwartiertelling_interval_taxon WHERE reconstructieversie={version})-(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '102.007%')),
  'unlinked_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o LEFT JOIN Meijendel.ndff_kwartiertelling_recordselectie s ON s.reconstructieversie={version} AND s.waarneming_id=o.waarneming_id WHERE o.protocol LIKE '102.007%' AND s.waarneming_id IS NULL),
  'secure_derived_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({secure_tables}))
);
"""


def resterende_nem_validation_sql() -> str:
    night = sql_text(NACHTVLINDER_RULE_VERSION)
    fungus = sql_text(BOSPADDENSTOEL_VERSPREIDING_RULE_VERSION)
    fish = sql_text(POLDERVIS_RULE_VERSION)
    mammal = sql_text(OTTER_BEVER_RULE_VERSION)
    secure_tables = ",".join(sql_text(name) for name in (
        "ndff_nachtvlinder_hokjaar", "ndff_nachtvlinder_hokjaar_taxon",
        "ndff_nachtvlinder_recordselectie",
        "ndff_bospaddenstoel_verspreiding_bezoek",
        "ndff_bospaddenstoel_verspreiding_bezoek_taxon",
        "ndff_bospaddenstoel_verspreiding_recordselectie",
        "ndff_poldervis_waterlocatie", "ndff_poldervis_bezoek",
        "ndff_poldervis_bezoek_taxon", "ndff_poldervis_recordselectie",
        "ndff_otter_bever_hokjaar", "ndff_otter_bever_hokjaar_taxon",
        "ndff_otter_bever_recordselectie",
    ))
    return f"""
SELECT JSON_OBJECT(
  'source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '03.203%' OR protocol LIKE '11.204%' OR protocol LIKE '13.201%' OR protocol LIKE '17.207%'),
  'nachtvlinder_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '03.203%'),
  'nachtvlinder_hokyears',(SELECT COUNT(*) FROM Meijendel.ndff_nachtvlinder_hokjaar WHERE reconstructieversie={night}),
  'nachtvlinder_taxon_rows',(SELECT COUNT(*) FROM Meijendel.ndff_nachtvlinder_hokjaar_taxon WHERE reconstructieversie={night}),
  'nachtvlinder_total_registered',(SELECT SUM(geregistreerd_aantal) FROM Meijendel.ndff_nachtvlinder_hokjaar_taxon WHERE reconstructieversie={night}),
  'bospaddenstoel_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '11.204%'),
  'bospaddenstoel_visits',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_verspreiding_bezoek WHERE reconstructieversie={fungus}),
  'bospaddenstoel_taxon_rows',(SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_verspreiding_bezoek_taxon WHERE reconstructieversie={fungus}),
  'poldervis_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '13.201%'),
  'poldervis_locations',(SELECT COUNT(*) FROM Meijendel.ndff_poldervis_waterlocatie WHERE reconstructieversie={fish}),
  'poldervis_visits',(SELECT COUNT(*) FROM Meijendel.ndff_poldervis_bezoek WHERE reconstructieversie={fish}),
  'poldervis_taxon_rows',(SELECT COUNT(*) FROM Meijendel.ndff_poldervis_bezoek_taxon WHERE reconstructieversie={fish}),
  'poldervis_positive_rows',(SELECT COUNT(*) FROM Meijendel.ndff_poldervis_bezoek_taxon WHERE reconstructieversie={fish} AND waarnemingsstatus='waargenomen'),
  'poldervis_missing_target_rows',(SELECT COUNT(*) FROM Meijendel.ndff_poldervis_bezoek_taxon WHERE reconstructieversie={fish} AND waarnemingsstatus='doelsoort_niet_gemeld' AND nulregel='geen_nul_doelmethode_onbekend'),
  'poldervis_total_registered',(SELECT SUM(geregistreerd_aantal) FROM Meijendel.ndff_poldervis_bezoek_taxon WHERE reconstructieversie={fish} AND waarnemingsstatus='waargenomen'),
  'otter_bever_source_records',(SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE protocol LIKE '17.207%'),
  'otter_bever_hokyears',(SELECT COUNT(*) FROM Meijendel.ndff_otter_bever_hokjaar WHERE reconstructieversie={mammal}),
  'otter_bever_taxon_rows',(SELECT COUNT(*) FROM Meijendel.ndff_otter_bever_hokjaar_taxon WHERE reconstructieversie={mammal}),
  'otter_bever_total_registered',(SELECT SUM(geregistreerd_aantal) FROM Meijendel.ndff_otter_bever_hokjaar_taxon WHERE reconstructieversie={mammal}),
  'zero_rows',(
      (SELECT COUNT(*) FROM Meijendel.ndff_nachtvlinder_hokjaar_taxon WHERE reconstructieversie={night} AND waarnemingsstatus<>'waargenomen')+
      (SELECT COUNT(*) FROM Meijendel.ndff_bospaddenstoel_verspreiding_bezoek_taxon WHERE reconstructieversie={fungus} AND waarnemingsstatus<>'waargenomen')+
      (SELECT COUNT(*) FROM Meijendel.ndff_otter_bever_hokjaar_taxon WHERE reconstructieversie={mammal} AND waarnemingsstatus<>'waargenomen')+
      (SELECT COUNT(*) FROM Meijendel.ndff_poldervis_bezoek_taxon WHERE reconstructieversie={fish} AND waarnemingsstatus NOT IN ('waargenomen','doelsoort_niet_gemeld'))
  ),
  'unlinked_source_records',(
      (SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o LEFT JOIN Meijendel.ndff_nachtvlinder_recordselectie s ON s.reconstructieversie={night} AND s.waarneming_id=o.waarneming_id WHERE o.protocol LIKE '03.203%' AND s.waarneming_id IS NULL)+
      (SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o LEFT JOIN Meijendel.ndff_bospaddenstoel_verspreiding_recordselectie s ON s.reconstructieversie={fungus} AND s.waarneming_id=o.waarneming_id WHERE o.protocol LIKE '11.204%' AND s.waarneming_id IS NULL)+
      (SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o LEFT JOIN Meijendel.ndff_poldervis_recordselectie s ON s.reconstructieversie={fish} AND s.waarneming_id=o.waarneming_id WHERE o.protocol LIKE '13.201%' AND s.waarneming_id IS NULL)+
      (SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming o LEFT JOIN Meijendel.ndff_otter_bever_recordselectie s ON s.reconstructieversie={mammal} AND s.waarneming_id=o.waarneming_id WHERE o.protocol LIKE '17.207%' AND s.waarneming_id IS NULL)
  ),
  'secure_derived_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema)='meijendel_ndff_secure' AND table_name IN ({secure_tables})),
  'lmf_ndff_derived_tables',(SELECT COUNT(*) FROM information_schema.tables WHERE LOWER(table_schema) IN ('meijendel','meijendel_ndff_secure') AND LOWER(table_name) LIKE 'ndff_lmf%')
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


def validate_rabbit_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != RABBIT_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (RABBIT_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(RABBIT_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != RABBIT_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(f"Konijnentellingclassificatie wijkt af van het vaste profiel: {differences}")


def validate_daz_bmp_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != DAZ_BMP_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (DAZ_BMP_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(DAZ_BMP_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != DAZ_BMP_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(f"DAZ-BMP-reconstructie wijkt af van het vaste profiel: {differences}")


def validate_zeereep_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != ZEEREEP_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (ZEEREEP_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(ZEEREEP_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != ZEEREEP_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(
            f"Zeereeppaddenstoelenreconstructie wijkt af van het vaste profiel: {differences}"
        )


def validate_bospaddenstoel_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != BOSPADDENSTOEL_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (BOSPADDENSTOEL_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(BOSPADDENSTOEL_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != BOSPADDENSTOEL_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(
            f"Bospaddenstoelenreconstructie wijkt af van het vaste profiel: {differences}"
        )


def validate_hns_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != HNS_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (HNS_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(HNS_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != HNS_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(f"HNS-reconstructie wijkt af van het vaste profiel: {differences}")


def validate_korstmos_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != KORSTMOS_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (KORSTMOS_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(KORSTMOS_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != KORSTMOS_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(f"Korstmossenreconstructie wijkt af van het vaste profiel: {differences}")


def validate_mos_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != MOS_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (MOS_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(MOS_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != MOS_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(f"Mossenreconstructie wijkt af van het vaste profiel: {differences}")


def validate_florbase_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != FLORBASE_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (FLORBASE_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(FLORBASE_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != FLORBASE_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(
            f"FLORBASE-reconstructie wijkt af van het vaste profiel: {differences}"
        )


def validate_habslak_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != HABSLAK_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (HABSLAK_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(HABSLAK_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != HABSLAK_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(
            f"HabSlak-reconstructie wijkt af van het vaste profiel: {differences}"
        )


def validate_braakbal_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != BRAAKBAL_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (BRAAKBAL_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(BRAAKBAL_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != BRAAKBAL_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(
            f"Braakbalreconstructie wijkt af van het vaste profiel: {differences}"
        )


def validate_tuintelling_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != TUINTELLING_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (TUINTELLING_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(TUINTELLING_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != TUINTELLING_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(
            f"Tuintellingreconstructie wijkt af van het vaste profiel: {differences}"
        )


def validate_liveatlas_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != LIVEATLAS_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (LIVEATLAS_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(LIVEATLAS_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != LIVEATLAS_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(
            f"LiveAtlas-reconstructie wijkt af van het vaste profiel: {differences}"
        )


def validate_kwartiertelling_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != KWARTIERTELLING_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (KWARTIERTELLING_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(
                set(metrics) | set(KWARTIERTELLING_RECONSTRUCTION_EXPECTED)
            )
            if metrics.get(key) != KWARTIERTELLING_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(
            "Kwartiertellingreconstructie wijkt af van het vaste profiel: "
            f"{differences}"
        )


def validate_resterende_nem_reconstruction(metrics: dict[str, int]) -> None:
    if metrics != RESTERENDE_NEM_RECONSTRUCTION_EXPECTED:
        differences = {
            key: (RESTERENDE_NEM_RECONSTRUCTION_EXPECTED.get(key), metrics.get(key))
            for key in sorted(set(metrics) | set(RESTERENDE_NEM_RECONSTRUCTION_EXPECTED))
            if metrics.get(key) != RESTERENDE_NEM_RECONSTRUCTION_EXPECTED.get(key)
        }
        raise ValueError(
            f"Resterende NEM-reconstructie wijkt af van het vaste profiel: {differences}"
        )


def validation_sql() -> str:
    structured_protocols = set(STRUCTURED_INCOMPLETE_PROTOCOLS)
    assessed_protocols_sql = ",".join(
        sql_text(protocol)
        for protocol in sorted(
            MIXED_POSITIVE_PROTOCOLS
            | POSITIVE_ONLY_SOURCE_PROTOCOLS
            | structured_protocols
        )
    )
    positive_only_sql = ",".join(
        sql_text(protocol) for protocol in sorted(POSITIVE_ONLY_SOURCE_PROTOCOLS)
    )
    structured_protocols_sql = ",".join(
        sql_text(protocol) for protocol in sorted(structured_protocols)
    )
    structured_indicative_sql = " OR ".join(
        "(p.protocol_sleutel=" + sql_text(protocol)
        + " AND d.analysetype IN ("
        + ",".join(sql_text(kind) for kind in sorted(kinds)) + "))"
        for protocol, kinds in sorted(STRUCTURED_INCOMPLETE_PROTOCOLS.items())
    )
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
SELECT 'protocolbesluit_mismatch',COUNT(*) FROM Meijendel.ndff_analysebesluit AS d
WHERE regelversie={sql_text(DECISION_RULE_VERSION)}
  AND d.gegevensgeschiktheid='niet_beoordeeld' AND (
  (analysetype='V' AND eindbesluit<>'voorlopig_toegelaten') OR
  (protocolgeschiktheid='niet_onderbouwd' AND analysetype<>'V' AND eindbesluit<>'uitgesloten_huidige_levering') OR
  (protocolgeschiktheid IN ('primair','voorwaardelijk') AND analysetype<>'V'
    AND eindbesluit NOT IN ('voorlopig_toegelaten','alleen_na_doelsoortselectie','wacht_op_doelsoortafbakening'))
);
SELECT 'leveringsbeoordelingen',COUNT(*) FROM Meijendel.ndff_analysebesluit d
JOIN Meijendel.ndff_protocol p ON p.protocol_id=d.protocol_id
WHERE d.regelversie={sql_text(DECISION_RULE_VERSION)}
  AND d.gegevensgeschiktheid<>'niet_beoordeeld';
SELECT 'leveringsbeoordeling_onverwacht',COUNT(*) FROM Meijendel.ndff_analysebesluit d
JOIN Meijendel.ndff_protocol p ON p.protocol_id=d.protocol_id
WHERE d.regelversie={sql_text(DECISION_RULE_VERSION)}
  AND d.gegevensgeschiktheid<>'niet_beoordeeld'
  AND p.protocol_sleutel NOT IN ({assessed_protocols_sql});
SELECT 'leveringsbeoordeling_ongeldig',COUNT(*) FROM Meijendel.ndff_analysebesluit d
JOIN Meijendel.ndff_protocol p ON p.protocol_id=d.protocol_id
WHERE d.regelversie={sql_text(DECISION_RULE_VERSION)}
  AND p.protocol_sleutel IN ({assessed_protocols_sql})
  AND NOT (
    (d.analysetype='V' AND d.gegevensgeschiktheid='voorwaardelijk'
      AND d.eindbesluit='voorlopig_toegelaten')
    OR (p.protocol_sleutel IN ('04.004','07.001')
      AND d.analysetype IN ('I','TV') AND d.gegevensgeschiktheid='onvoldoende'
      AND d.eindbesluit='voorlopig_toegelaten')
    OR (p.protocol_sleutel IN ('04.004','07.001')
      AND d.analysetype IN ('TA','TK') AND d.gegevensgeschiktheid='onvoldoende'
      AND d.eindbesluit='uitgesloten_huidige_levering')
    OR (p.protocol_sleutel IN ({positive_only_sql})
      AND d.analysetype IN ('I','TV','TA','TK')
      AND d.gegevensgeschiktheid='onvoldoende'
      AND d.eindbesluit='uitgesloten_huidige_levering')
    OR (({structured_indicative_sql})
      AND d.gegevensgeschiktheid='onvoldoende'
      AND d.eindbesluit='voorlopig_toegelaten')
    OR (p.protocol_sleutel IN ({structured_protocols_sql})
      AND d.analysetype<>'V' AND NOT ({structured_indicative_sql})
      AND d.gegevensgeschiktheid='onvoldoende'
      AND d.eindbesluit='uitgesloten_huidige_levering')
  );
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
        "decisions", "protocolbesluit_mismatch", "leveringsbeoordelingen",
        "leveringsbeoordeling_onverwacht", "leveringsbeoordeling_ongeldig",
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
    if (metrics["leveringsbeoordelingen"] != 400
            or metrics["leveringsbeoordeling_onverwacht"]
            or metrics["leveringsbeoordeling_ongeldig"]):
        raise ValueError("De beoordeelde atlas-/verspreidingsleveringen wijken af.")
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
    mode.add_argument("--reconstruct-konijnen", action="store_true")
    mode.add_argument("--audit-konijnen", action="store_true")
    mode.add_argument("--reconstruct-daz-bmp", action="store_true")
    mode.add_argument("--audit-daz-bmp", action="store_true")
    mode.add_argument("--reconstruct-zeereeppaddenstoelen", action="store_true")
    mode.add_argument("--audit-zeereeppaddenstoelen", action="store_true")
    mode.add_argument("--reconstruct-bospaddenstoelen", action="store_true")
    mode.add_argument("--audit-bospaddenstoelen", action="store_true")
    mode.add_argument("--reconstruct-hns", action="store_true")
    mode.add_argument("--audit-hns", action="store_true")
    mode.add_argument("--reconstruct-korstmossen", action="store_true")
    mode.add_argument("--audit-korstmossen", action="store_true")
    mode.add_argument("--reconstruct-mossen", action="store_true")
    mode.add_argument("--audit-mossen", action="store_true")
    mode.add_argument("--reconstruct-florbase", action="store_true")
    mode.add_argument("--audit-florbase", action="store_true")
    mode.add_argument("--reconstruct-habslak", action="store_true")
    mode.add_argument("--audit-habslak", action="store_true")
    mode.add_argument("--reconstruct-braakballen", action="store_true")
    mode.add_argument("--audit-braakballen", action="store_true")
    mode.add_argument("--reconstruct-tuintellingen", action="store_true")
    mode.add_argument("--audit-tuintellingen", action="store_true")
    mode.add_argument("--reconstruct-liveatlas", action="store_true")
    mode.add_argument("--audit-liveatlas", action="store_true")
    mode.add_argument("--reconstruct-kwartiertellingen", action="store_true")
    mode.add_argument("--audit-kwartiertellingen", action="store_true")
    mode.add_argument("--reconstruct-resterende-nem", action="store_true")
    mode.add_argument("--audit-resterende-nem", action="store_true")
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
    if args.reconstruct_konijnen:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_konijnen(args.mysql_client, client_args)
        validate_rabbit_reconstruction(metrics)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_konijnen:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            rabbit_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_rabbit_reconstruction(metrics)
        print(f"OK: lokale konijnentellingclassificatie {RABBIT_COUNT_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_daz_bmp:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_daz_bmp(args.mysql_client, client_args)
        validate_daz_bmp_reconstruction(metrics)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_daz_bmp:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            daz_bmp_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_daz_bmp_reconstruction(metrics)
        print(f"OK: lokale DAZ-BMP-reconstructie {DAZ_BMP_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_zeereeppaddenstoelen:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_zeereeppaddenstoelen(args.mysql_client, client_args)
        validate_zeereep_reconstruction(metrics)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_zeereeppaddenstoelen:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            zeereep_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_zeereep_reconstruction(metrics)
        print(f"OK: lokale zeereeppaddenstoelenreconstructie {ZEEREEP_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_bospaddenstoelen:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_bospaddenstoelen(args.mysql_client, client_args)
        validate_bospaddenstoel_reconstruction(metrics)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_bospaddenstoelen:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            bospaddenstoel_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_bospaddenstoel_reconstruction(metrics)
        print(f"OK: lokale bospaddenstoelenreconstructie {BOSPADDENSTOEL_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_hns:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_hns(args.mysql_client, client_args)
        validate_hns_reconstruction(metrics)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_hns:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            hns_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_hns_reconstruction(metrics)
        print(f"OK: lokale HNS-reconstructie {HNS_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_korstmossen:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_korstmossen(args.mysql_client, client_args)
        validate_korstmos_reconstruction(metrics)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_korstmossen:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            korstmos_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_korstmos_reconstruction(metrics)
        print(f"OK: lokale korstmossenreconstructie {KORSTMOS_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_mossen:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_mossen(args.mysql_client, client_args)
        validate_mos_reconstruction(metrics)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_mossen:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            mos_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_mos_reconstruction(metrics)
        print(f"OK: lokale mossenreconstructie {MOS_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_florbase:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_florbase(args.mysql_client, client_args)
        validate_florbase_reconstruction(metrics)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_florbase:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            florbase_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_florbase_reconstruction(metrics)
        print(f"OK: lokale FLORBASE-reconstructie {FLORBASE_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_habslak:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_habslak(args.mysql_client, client_args)
        validate_habslak_reconstruction(metrics)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_habslak:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            habslak_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_habslak_reconstruction(metrics)
        print(f"OK: lokale HabSlak-reconstructie {HABSLAK_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_braakballen:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_braakballen(args.mysql_client, client_args)
        validate_braakbal_reconstruction(metrics)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_braakballen:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            braakbal_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_braakbal_reconstruction(metrics)
        print(f"OK: lokale braakbalreconstructie {BRAAKBAL_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_tuintellingen:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_tuintellingen(args.mysql_client, client_args)
        validate_tuintelling_reconstruction(metrics)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_tuintellingen:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            tuintelling_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_tuintelling_reconstruction(metrics)
        print(f"OK: lokale tuintellingreconstructie {TUINTELLING_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_liveatlas:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_liveatlas(args.mysql_client, client_args)
        validate_liveatlas_reconstruction(metrics)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_liveatlas:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            liveatlas_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_liveatlas_reconstruction(metrics)
        print(f"OK: lokale LiveAtlas-reconstructie {LIVEATLAS_RULE_VERSION} gereed")
        print(output)
        return 0
    if args.reconstruct_kwartiertellingen:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_kwartiertellingen(args.mysql_client, client_args)
        validate_kwartiertelling_reconstruction(metrics)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_kwartiertellingen:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            kwartiertelling_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_kwartiertelling_reconstruction(metrics)
        print(
            "OK: lokale kwartiertellingreconstructie "
            f"{KWARTIERTELLING_RULE_VERSION} gereed"
        )
        print(output)
        return 0
    if args.reconstruct_resterende_nem:
        run_mysql(args.mysql_client, client_args, SCHEMA.read_text(encoding="utf-8"))
        metrics = reconstruct_resterende_nem(args.mysql_client, client_args)
        validate_resterende_nem_reconstruction(metrics)
        print(json.dumps(metrics, ensure_ascii=False, sort_keys=True))
        return 0
    if args.audit_resterende_nem:
        output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            resterende_nem_validation_sql(),
            capture=True,
        )
        metrics = parse_analysis_chain_output(output)
        validate_resterende_nem_reconstruction(metrics)
        print("OK: vier resterende openbare NEM-reeksen gecontroleerd")
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
        remaining_output = run_mysql(
            args.mysql_client,
            client_args + ["--batch", "--raw", "--skip-column-names"],
            resterende_nem_validation_sql(),
            capture=True,
        )
        validate_resterende_nem_reconstruction(
            parse_analysis_chain_output(remaining_output)
        )
        print(f"OK: lokale NDFF-analyseketen {ANALYSIS_CHAIN_VERSION} gereed")
        print(output)
        print("OK: vier resterende openbare NEM-reeksen gecontroleerd")
        print(remaining_output)
        return 0

    sql = "\n".join((SCHEMA.read_text(encoding="utf-8"), catalog_insert_sql(rows, SOURCE_XLSX_SHA256), mapping_sql(), record_protocol_link_sql(), spatial_sql(), protocol_scope_sql(), public_pq_gate_sql(), snl_overlap_sql(), restore_legacy_decisions_sql(), decisions_sql(), delivery_assessment_sql()))
    run_mysql(args.mysql_client, client_args, sql)
    output = run_mysql(args.mysql_client, client_args + ["--batch", "--raw", "--skip-column-names"], validation_sql(), capture=True)
    metrics = {key: int(value) for key, value in (line.split("\t", 1) for line in output.splitlines())}
    validate_metrics(metrics)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
