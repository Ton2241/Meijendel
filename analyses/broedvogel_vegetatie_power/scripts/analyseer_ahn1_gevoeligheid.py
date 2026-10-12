#!/usr/bin/env python3

"""Kwantificeer hoe sterk AHN1-structuurmaten afhangen van rasterafleiding."""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd


METRICS = (
    "hoogte_mediaan_m",
    "hoogte_p95_m",
    "aandeel_open",
    "aandeel_lage_vegetatie",
    "aandeel_struweel",
    "aandeel_bomen",
    "randlengte_m_per_ha",
)


def compare(mean: pd.DataFrame, maximum: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    merged = mean[["plot_id", *METRICS]].merge(
        maximum[["plot_id", *METRICS]], on="plot_id", suffixes=("_mean", "_max"),
        validate="one_to_one"
    )
    detail = merged[["plot_id"]].copy()
    rows = []
    for metric in METRICS:
        difference = merged[f"{metric}_max"] - merged[f"{metric}_mean"]
        detail[f"{metric}_verschil_max_min_mean"] = difference
        rows.append(
            {
                "maat": metric,
                "gemiddelde_mean_methode": merged[f"{metric}_mean"].mean(),
                "gemiddelde_max_methode": merged[f"{metric}_max"].mean(),
                "gemiddeld_verschil": difference.mean(),
                "mediaan_absoluut_verschil": difference.abs().median(),
                "maximum_absoluut_verschil": difference.abs().max(),
            }
        )
    return detail, pd.DataFrame(rows)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mean", required=True)
    parser.add_argument("--max", required=True)
    parser.add_argument("--output-detail", required=True)
    parser.add_argument("--output-summary", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    detail, summary = compare(pd.read_csv(args.mean), pd.read_csv(args.max))
    Path(args.output_detail).parent.mkdir(parents=True, exist_ok=True)
    detail.to_csv(args.output_detail, index=False)
    summary.to_csv(args.output_summary, index=False)


if __name__ == "__main__":
    main()
