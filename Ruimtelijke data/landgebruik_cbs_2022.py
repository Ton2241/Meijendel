#!/usr/bin/env python3

import argparse
import re
import xml.etree.ElementTree as ET
from pathlib import Path

import geopandas as gpd
import pandas as pd


def parse_args():
    parser = argparse.ArgumentParser(
        description="Bereken landgebruik per plot uit CBS NBBG2022."
    )
    parser.add_argument("--plots", required=True, help="Pad naar plot shapefile")
    parser.add_argument("--gpkg", required=True, help="Pad naar CBS GeoPackage")
    parser.add_argument("--layer", required=True, help="Laagnaam in GeoPackage")
    parser.add_argument("--qml", required=True, help="Pad naar QML stijlbestand")
    parser.add_argument("--year", required=True, type=int, help="Jaar voor output")
    parser.add_argument("--source", required=True, help="Bronnaam voor output")
    parser.add_argument("--output", required=True, help="Pad naar output CSV")
    return parser.parse_args()


def parse_qml_categories(qml_path):
    tree = ET.parse(qml_path)
    root = tree.getroot()
    mapping = {}
    for category in root.findall(".//category"):
        value = category.attrib.get("value")
        label = category.attrib.get("label", "")
        if value is None:
            continue
        match = re.match(r"^\s*\d+\s*-\s*(.+?)\s*$", label)
        klasse = match.group(1) if match else label
        mapping[int(value)] = klasse
    return mapping


def main():
    args = parse_args()

    class_map = parse_qml_categories(args.qml)

    plots = gpd.read_file(args.plots)[["plotid", "geometry"]].copy()
    plots["plot_id"] = plots["plotid"].astype(int)
    plots = plots[["plot_id", "geometry"]]
    plot_bounds = tuple(plots.total_bounds)

    landgebruik = gpd.read_file(
        args.gpkg,
        layer=args.layer,
        bbox=plot_bounds,
    )[["NBBG22", "geometry"]].copy()
    landgebruik["klasse_code"] = landgebruik["NBBG22"].astype(int)
    landgebruik["klasse"] = landgebruik["klasse_code"].map(class_map).fillna(
        landgebruik["klasse_code"].astype(str)
    )
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
    grouped["jaar"] = args.year
    grouped["bron"] = args.source

    output = grouped[["plot_id", "jaar", "bron", "klasse", "area_m2", "pct"]].copy()
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output.to_csv(output_path, index=False)


if __name__ == "__main__":
    main()
