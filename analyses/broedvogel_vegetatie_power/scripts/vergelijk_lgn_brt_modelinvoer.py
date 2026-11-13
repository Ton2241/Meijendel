#!/usr/bin/env python3
"""Vergelijk de definitieve LGN-afleiding met de voorlopige BRT-afstandslaag."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import geopandas as gpd
import numpy as np
import rasterio
from rasterio.features import geometry_mask
from rasterio.mask import mask


def statistics(values: np.ndarray) -> dict:
    return {
        "minimum": float(np.min(values)),
        "p05": float(np.quantile(values, 0.05)),
        "mediaan": float(np.median(values)),
        "gemiddelde": float(np.mean(values)),
        "p95": float(np.quantile(values, 0.95)),
        "maximum": float(np.max(values)),
    }


def compare(old_path: Path, new_path: Path, mask_path: Path, plots_path: Path, lgn_path: Path) -> dict:
    plots = gpd.read_file(plots_path).to_crs("EPSG:28992")
    geometries = list(plots.geometry)
    with rasterio.open(old_path) as old, rasterio.open(new_path) as new, rasterio.open(mask_path) as study:
        if (old.transform, old.shape, old.crs) != (new.transform, new.shape, new.crs):
            raise ValueError("De BRT- en LGN-stacks liggen niet op hetzelfde rooster.")
        pilot = ~geometry_mask(geometries, out_shape=old.shape, transform=old.transform)
        old_distance = old.read(7)[pilot].astype(np.float64)
        new_distance = new.read(7)[pilot].astype(np.float64)
        included = study.read(1)[pilot].astype(bool)
    difference = new_distance - old_distance
    absolute = np.abs(difference)
    with rasterio.open(lgn_path) as lgn:
        values, _ = mask(lgn, geometries, crop=True, filled=False)
        selected = values[0].compressed()
    classes, counts = np.unique(selected, return_counts=True)
    return {
        "pilotplot_ids": sorted(int(value) for value in plots["plotid"]),
        "aantal_25cm_pixels": int(old_distance.size),
        "afstand_brt_m": statistics(old_distance),
        "afstand_lgn_m": statistics(new_distance),
        "verschil_lgn_min_brt_m": statistics(difference),
        "absoluut_verschil_m": statistics(absolute),
        "correlatie": float(np.corrcoef(old_distance, new_distance)[0, 1]),
        "aandeel_table_s3_studiegebied": float(included.mean()),
        "lgn_klasseverdeling_5m": {
            str(int(code)): int(count) for code, count in zip(classes, counts)
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--brt-stack", type=Path, required=True)
    parser.add_argument("--lgn-stack", type=Path, required=True)
    parser.add_argument("--lgn-mask", type=Path, required=True)
    parser.add_argument("--plots", type=Path, required=True)
    parser.add_argument("--lgn", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = compare(args.brt_stack, args.lgn_stack, args.lgn_mask, args.plots, args.lgn)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
