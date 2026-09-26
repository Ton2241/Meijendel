#!/usr/bin/env python3
"""Semantische controles op de bronoverstijgende analysecatalogus."""

from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SERIES = ROOT / "gis" / "database" / "analyse_datareeks_seed.csv"
DECISIONS = ROOT / "gis" / "database" / "analyse_geschiktheid_seed.csv"
ANALYSIS_TYPES = {"V", "I", "TV", "TA", "TK"}


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def main() -> int:
    series = read_rows(SERIES)
    decisions = read_rows(DECISIONS)
    by_key = {row["datareeks_sleutel"]: row for row in series}
    assert len(by_key) == len(series), "datareeks_sleutel moet uniek zijn"

    required = {
        "vogels-territoria",
        "vogels-bmp-bezoeken",
        "vogels-winterbezoeken",
        "provinciale-pq",
        "sovon-vwg-zoogdieren",
        "vangblik-1953-1960",
        "ndff-canoniek",
        "stowa-limnodata-meijendel",
        "endure-helmduinfauna-meijendel-2018",
        "lvd-meijendel-v1-6",
        "nmr-vlinders-meijendel",
        "naturalis-botany-meijendel",
        "naturalis-coleoptera-meijendel",
        "eis-bijenmonitoring-meijendel",
        "aquatische-macrofauna-meijendel-1974-1975",
        "duinvallei-vegetatie-context",
        "jachtspinnen-1969-1970",
        "vogelstand-meijendel-1924",
    }
    assert required <= set(by_key), required - set(by_key)

    counts = Counter(row["datareeks_sleutel"] for row in decisions)
    for key, row in by_key.items():
        if row["classificatiebron"] == "generiek":
            assert counts[key] == 5, (key, counts[key])
            codes = {
                decision["analyse_type_code"]
                for decision in decisions
                if decision["datareeks_sleutel"] == key
            }
            assert codes == ANALYSIS_TYPES, (key, codes)
        else:
            assert key == "ndff-canoniek", key
            assert counts[key] == 0, "NDFF-besluiten mogen niet worden gekopieerd"

    for decision in decisions:
        source = by_key[decision["datareeks_sleutel"]]
        if source["bronstatus"] == "contextbron":
            assert decision["eindbesluit"] in {"alleen_context", "niet_toegelaten"}

    print(
        "OK: analysegeschiktheid-seed "
        f"({len(series)} gegevensreeksen, {len(decisions)} generieke besluiten)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
