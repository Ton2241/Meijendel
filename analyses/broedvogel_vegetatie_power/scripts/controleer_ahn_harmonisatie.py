#!/usr/bin/env python3

"""Controleer het contract van de geharmoniseerde AHN-structuurlaag."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd


CYCLES = ("AHN2", "AHN3", "AHN4", "AHN5")
SHARES = (
    "aandeel_open",
    "aandeel_lage_vegetatie",
    "aandeel_struweel",
    "aandeel_bomen",
)


def validate(data: pd.DataFrame) -> pd.DataFrame:
    checks: list[dict[str, object]] = []

    def add(name: str, passed: bool, detail: str) -> None:
        checks.append(
            {"controle": name, "geslaagd": bool(passed), "toelichting": detail}
        )

    add(
        "unieke_plot_cyclus",
        not data.duplicated(["plot_id", "ahn_cyclus"]).any(),
        f"{len(data)} regels",
    )
    cycle_counts = data.groupby("ahn_cyclus")["plot_id"].nunique().to_dict()
    add(
        "55_plots_per_cyclus",
        cycle_counts == {cycle: 55 for cycle in CYCLES},
        str(cycle_counts),
    )
    add(
        "vier_cycli",
        set(data["ahn_cyclus"]) == set(CYCLES),
        ", ".join(sorted(data["ahn_cyclus"].unique())),
    )
    moments = (
        data.groupby("ahn_cyclus")["structuurmoment"].unique().map(list).to_dict()
    )
    add(
        "een_structuurmoment_per_cyclus",
        moments
        == {"AHN2": [2008], "AHN3": [2014], "AHN4": [2020], "AHN5": [2023]},
        str(moments),
    )
    add(
        "zelfde_resolutie",
        set(data["resolutie_m"].dropna()) == {2.0},
        str(sorted(data["resolutie_m"].dropna().unique())),
    )
    add(
        "zelfde_harmonisatie",
        data["harmonisatie"].nunique(dropna=False) == 1
        and data["harmonisatie"].notna().all(),
        str(data["harmonisatie"].drop_duplicates().tolist()),
    )
    share_sum = data[list(SHARES)].sum(axis=1)
    add(
        "hoogteklassen_sommeren_tot_een",
        bool(np.allclose(share_sum, 1.0, rtol=0, atol=1e-8)),
        f"minimum={share_sum.min():.12f}; maximum={share_sum.max():.12f}",
    )
    add(
        "inwinningsgrond_compleet",
        data["inwinningsperiode"].notna().all()
        and data["respons_startjaar"].notna().all()
        and data.loc[data["ahn_cyclus"] != "AHN2", "inwinningsdatum"].notna().all(),
        (
            f"datum_ontbrekend={int(data['inwinningsdatum'].isna().sum())}; "
            f"periode_ontbrekend={int(data['inwinningsperiode'].isna().sum())}"
        ),
    )
    result = pd.DataFrame(checks)
    if not result["geslaagd"].all():
        failures = result.loc[~result["geslaagd"], "controle"].tolist()
        raise ValueError(f"AHN-harmonisatie faalt: {', '.join(failures)}")
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    result = validate(pd.read_csv(args.input))
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    result.to_csv(output, index=False)


if __name__ == "__main__":
    main()
