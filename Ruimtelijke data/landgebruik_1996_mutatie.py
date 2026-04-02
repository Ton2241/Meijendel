#!/usr/bin/env python3

import argparse
from pathlib import Path

import geopandas as gpd


def parse_args():
    parser = argparse.ArgumentParser(
        description="Bereken landgebruik per plot voor 1996 uit het CBS mutatiebestand."
    )
    parser.add_argument("--plots", required=True, help="Pad naar plot shapefile")
    parser.add_argument("--mutatie-shp", required=True, help="Pad naar mutatie shapefile")
    parser.add_argument("--output", required=True, help="Pad naar output CSV")
    parser.add_argument("--source", default="CBS_BBG1996", help="Bronnaam voor output")
    return parser.parse_args()


def main():
    args = parse_args()

    plots = gpd.read_file(args.plots)[["plotid", "geometry"]].copy()
    plots["plot_id"] = plots["plotid"].astype(int)
    plots = plots[["plot_id", "geometry"]]
    plot_bounds = tuple(plots.total_bounds)

    landgebruik = gpd.read_file(
        args.mutatie_shp,
        bbox=plot_bounds,
    )[["BG96", "geometry"]].copy()
    landgebruik["klasse_code"] = landgebruik["BG96"].astype(int)
    landgebruik["klasse"] = "BG96_" + landgebruik["klasse_code"].astype(str)
    landgebruik = landgebruik[["klasse", "geometry"]]

    intersections = gpd.overlay(
        plots,
        landgebruik,
        how="intersection",
        keep_geom_type=True,
    )
    intersections["area_m2"] = intersections.geometry.area
    intersections = intersections[intersections["area_m2"] > 0].copy()

    grouped = (
        intersections.groupby(["plot_id", "klasse"], as_index=False)["area_m2"]
        .sum()
        .sort_values(["plot_id", "klasse"])
    )

    totals = grouped.groupby("plot_id", as_index=False)["area_m2"].sum()
    totals = totals.rename(columns={"area_m2": "plot_total_m2"})
    grouped = grouped.merge(totals, on="plot_id", how="left")
    grouped["pct"] = grouped["area_m2"] / grouped["plot_total_m2"] * 100.0
    grouped["jaar"] = 1996
    grouped["bron"] = args.source

    output = grouped[["plot_id", "jaar", "bron", "klasse", "area_m2", "pct"]].copy()
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output.to_csv(output_path, index=False)


if __name__ == "__main__":
    main()
