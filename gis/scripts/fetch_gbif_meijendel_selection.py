#!/usr/bin/env python3
"""Download een GBIF-dataset per jaar en selecteer exact op Meijendel."""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from profile_external_dwca import event_year, geometry_bounds, load_geometry, point_in_geometry


API = "https://api.gbif.org/v1/occurrence/search"


def request_json(parameters: dict[str, str | int], attempts: int = 5) -> dict:
    url = API + "?" + urllib.parse.urlencode(parameters)
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(url, timeout=60) as response:
                return json.load(response)
        except Exception:
            if attempt + 1 == attempts:
                raise
            time.sleep(2**attempt)
    raise AssertionError("onbereikbaar")


def available_years(dataset_key: str, bbox_wkt: str) -> tuple[int, list[int]]:
    payload = request_json(
        {
            "dataset_key": dataset_key,
            "geometry": bbox_wkt,
            "limit": 0,
            "facet": "year",
            "facetLimit": 500,
        }
    )
    years = sorted(int(item["name"]) for item in payload["facets"][0]["counts"])
    return int(payload["count"]), years


def iter_year(dataset_key: str, bbox_wkt: str, year: int):
    offset = 0
    while True:
        payload = request_json(
            {
                "dataset_key": dataset_key,
                "geometry": bbox_wkt,
                "year": year,
                "limit": 300,
                "offset": offset,
            }
        )
        yield from payload["results"]
        offset += len(payload["results"])
        if payload.get("endOfRecords") or not payload["results"]:
            break


def bbox_wkt(bounds: tuple[float, float, float, float]) -> str:
    minimum_x, minimum_y, maximum_x, maximum_y = bounds
    return (
        f"POLYGON(({minimum_x} {minimum_y},{maximum_x} {minimum_y},"
        f"{maximum_x} {maximum_y},{minimum_x} {maximum_y},{minimum_x} {minimum_y}))"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset-key", required=True)
    parser.add_argument("--boundary", type=Path, required=True)
    parser.add_argument("--output-jsonl", type=Path, required=True)
    parser.add_argument("--output-profile", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    geometry = load_geometry(args.boundary)
    rectangle = bbox_wkt(geometry_bounds(geometry))
    rectangle_count, years = available_years(args.dataset_key, rectangle)
    args.output_jsonl.parent.mkdir(parents=True, exist_ok=True)
    seen: set[str] = set()
    selected = dated_rectangle = 0
    minimum_year = maximum_year = None
    with args.output_jsonl.open("w", encoding="utf-8") as handle:
        for year in years:
            for record in iter_year(args.dataset_key, rectangle, year):
                dated_rectangle += 1
                key = str(record.get("key") or record.get("occurrenceID"))
                if key in seen:
                    continue
                seen.add(key)
                try:
                    longitude = float(record["decimalLongitude"])
                    latitude = float(record["decimalLatitude"])
                except (KeyError, TypeError, ValueError):
                    continue
                if not point_in_geometry(longitude, latitude, geometry):
                    continue
                selected += 1
                observed_year = int(event_year({key: str(value) for key, value in record.items()}))
                minimum_year = observed_year if minimum_year is None else min(minimum_year, observed_year)
                maximum_year = observed_year if maximum_year is None else max(maximum_year, observed_year)
                handle.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")
    result = {
        "dataset_key": args.dataset_key,
        "rechthoek_totaal": rectangle_count,
        "rechthoek_met_jaar": dated_rectangle,
        "rechthoek_zonder_jaar": rectangle_count - dated_rectangle,
        "binnen_basisgebied_met_jaar": selected,
        "jaar_van": minimum_year,
        "jaar_tot": maximum_year,
        "opmerking": "Records zonder jaar zijn niet via de jaarpartities opgehaald en zijn niet geschikt voor tijdanalyse.",
    }
    args.output_profile.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
