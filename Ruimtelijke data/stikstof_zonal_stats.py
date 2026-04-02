#!/usr/bin/env python3

import argparse
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd


def parse_args():
    parser = argparse.ArgumentParser(
        description="Bereken gebiedsgewogen stikstofstatistiek per plot en per jaar."
    )
    parser.add_argument("--plots", required=True, help="Pad naar plot shapefile")
    parser.add_argument("--gpkg", required=True, help="Pad naar stikstof GeoPackage")
    parser.add_argument("--output", required=True, help="Pad naar output CSV")
    parser.add_argument(
        "--source",
        default="RIVM_HIST_STIKSTOF",
        help="Bronnaam voor output",
    )
    return parser.parse_args()


def weighted_median(values, weights):
    if len(values) == 0:
        return np.nan

    order = np.argsort(values)
    values = np.asarray(values)[order]
    weights = np.asarray(weights)[order]
    cumulative = weights.cumsum()
    cutoff = weights.sum() / 2
    return float(values[cumulative >= cutoff][0])


def main():
    args = parse_args()

    plots = gpd.read_file(args.plots)[["plotid", "geometry"]].copy()
    plots["plot_id"] = plots["plotid"].astype(int)
    plots = plots[["plot_id", "geometry"]]
    plot_bounds = tuple(plots.total_bounds)

    layers = gpd.list_layers(args.gpkg)
    year_layers = [
        row["name"]
        for _, row in layers.iterrows()
        if row["name"].startswith("ndep_historisch_")
    ]
    year_layers = sorted(year_layers)

    all_rows = []

    for layer_name in year_layers:
        jaar = int(layer_name.rsplit("_", 1)[1])

        stikstof = gpd.read_file(args.gpkg, layer=layer_name, bbox=plot_bounds)[
            ["deposition", "geometry"]
        ].copy()
        stikstof["deposition"] = stikstof["deposition"].astype(float)

        intersections = gpd.overlay(
            plots,
            stikstof,
            how="intersection",
            keep_geom_type=True,
        )

        intersections["area_m2"] = intersections.geometry.area
        intersections = intersections[intersections["area_m2"] > 0].copy()

        for plot_id, group in intersections.groupby("plot_id"):
            values = group["deposition"].to_numpy()
            weights = group["area_m2"].to_numpy()

            mean_val = float(np.average(values, weights=weights))
            median_val = weighted_median(values, weights)

            all_rows.append(
                {
                    "plot_id": int(plot_id),
                    "jaar": jaar,
                    "bron": args.source,
                    "ahn_mean": np.nan,
                    "ahn_sd": np.nan,
                    "stikstof_mean": mean_val,
                    "stikstof_median": median_val,
                }
            )

    df = pd.DataFrame(all_rows).sort_values(["jaar", "plot_id"])
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_path, index=False)


if __name__ == "__main__":
    main()
