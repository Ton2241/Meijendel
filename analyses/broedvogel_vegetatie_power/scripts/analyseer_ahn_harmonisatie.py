#!/usr/bin/env python3

"""Vat niveaus, overgangen en methodebreuk van de AHN-structuurlaag samen."""

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


def cycle_summary(data: pd.DataFrame) -> pd.DataFrame:
    grouped = data.groupby("ahn_cyclus", sort=False)
    rows = []
    for cycle, current in grouped:
        row = {
            "ahn_cyclus": cycle,
            "plots": current["plot_id"].nunique(),
            "structuurmoment": int(current["structuurmoment"].iloc[0]),
            "inwinningsperiode": " | ".join(
                sorted(current["inwinningsperiode"].dropna().astype(str).unique())
            ),
        }
        row.update({f"gemiddelde_{metric}": current[metric].mean() for metric in METRICS})
        rows.append(row)
    return pd.DataFrame(rows).sort_values("structuurmoment")


def transition_summary(data: pd.DataFrame) -> pd.DataFrame:
    cycles = cycle_summary(data)["ahn_cyclus"].tolist()
    rows = []
    for before, after in zip(cycles, cycles[1:]):
        left = data[data["ahn_cyclus"] == before][["plot_id", *METRICS]]
        right = data[data["ahn_cyclus"] == after][["plot_id", *METRICS]]
        paired = left.merge(right, on="plot_id", suffixes=("_voor", "_na"), validate="one_to_one")
        for metric in METRICS:
            difference = paired[f"{metric}_na"] - paired[f"{metric}_voor"]
            rows.append(
                {
                    "van": before,
                    "naar": after,
                    "maat": metric,
                    "plots": len(paired),
                    "gemiddelde_verandering": difference.mean(),
                    "mediaan_verandering": difference.median(),
                    "plots_toename": int((difference > 0).sum()),
                    "plots_afname": int((difference < 0).sum()),
                }
            )
    return pd.DataFrame(rows)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-cycles", required=True)
    parser.add_argument("--output-transitions", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    data = pd.read_csv(args.input)
    cycles = cycle_summary(data)
    transitions = transition_summary(data)
    Path(args.output_cycles).parent.mkdir(parents=True, exist_ok=True)
    cycles.to_csv(args.output_cycles, index=False)
    transitions.to_csv(args.output_transitions, index=False)


if __name__ == "__main__":
    main()
