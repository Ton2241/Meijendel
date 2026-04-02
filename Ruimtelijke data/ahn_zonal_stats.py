#!/usr/bin/env python3

import argparse
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd
import rasterio
from rasterio.mask import mask


def parse_args():
    parser = argparse.ArgumentParser(
        description="Bereken AHN gemiddelde en standaardafwijking per plot."
    )
    parser.add_argument("--plots", required=True, help="Pad naar plot shapefile")
    parser.add_argument("--raster", required=True, help="Pad naar merged AHN raster")
    parser.add_argument("--year", required=True, type=int, help="Jaar voor output")
    parser.add_argument("--source", required=True, help="Bronnaam voor output")
    parser.add_argument("--output", required=True, help="Pad naar output CSV")
    return parser.parse_args()


def main():
    args = parse_args()

    plots = gpd.read_file(args.plots)

    if "plotid" not in plots.columns:
        raise ValueError("Veld 'plotid' ontbreekt in shapefile.")

    with rasterio.open(args.raster) as src:
        if plots.crs != src.crs:
            plots = plots.to_crs(src.crs)

        nodata = src.nodata
        rows = []

        for _, feature in plots.iterrows():
            geom = [feature.geometry.__geo_interface__]
            data, _ = mask(src, geom, crop=True, filled=True)
            values = data[0]

            valid = np.isfinite(values)
            if nodata is not None:
                valid &= values != nodata

            values = values[valid]

            if values.size == 0:
                mean_val = np.nan
                sd_val = np.nan
            else:
                mean_val = float(values.mean())
                sd_val = float(values.std(ddof=0))

            rows.append(
                {
                    "plot_id": int(feature["plotid"]),
                    "jaar": args.year,
                    "bron": args.source,
                    "ahn_mean": mean_val,
                    "ahn_sd": sd_val,
                    "stikstof_mean": np.nan,
                    "stikstof_median": np.nan,
                }
            )

    df = pd.DataFrame(rows).sort_values("plot_id")
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_path, index=False)


if __name__ == "__main__":
    main()
