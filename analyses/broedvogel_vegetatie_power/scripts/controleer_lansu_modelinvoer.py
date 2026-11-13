#!/usr/bin/env python3
"""Controleer rastercontract en dekking binnen de gekozen vogelplots."""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path

import geopandas as gpd
import numpy as np
import rasterio
from rasterio.mask import mask


MODULE_PATH = Path(__file__).with_name("lansu_modelinvoer.py")


def load_contract_module():
    spec = importlib.util.spec_from_file_location("lansu_modelinvoer", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stack", type=Path, required=True)
    parser.add_argument("--plots", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    module = load_contract_module()
    plots = gpd.read_file(args.plots)
    problems = []
    bands = []
    with rasterio.open(args.stack) as source:
        if source.count != len(module.CHANNELS):
            problems.append(f"Raster bevat {source.count} in plaats van 7 banden.")
        if tuple(source.descriptions) != module.CHANNELS:
            problems.append("Bandvolgorde wijkt af van het gepubliceerde contract.")
        if source.crs != rasterio.crs.CRS.from_epsg(28992):
            problems.append(f"Onverwacht coordinatenstelsel: {source.crs}.")
        if abs(source.transform.a - module.RESOLUTION_M) > 1e-9:
            problems.append(f"Onverwachte resolutie: {source.transform.a} meter.")
        if plots.crs != source.crs:
            plots = plots.to_crs(source.crs)
        values, _ = mask(
            source,
            [plots.geometry.union_all().__geo_interface__],
            crop=True,
            filled=False,
            all_touched=False,
        )
        pilot_pixels = int((~np.ma.getmaskarray(values[0])).sum())
        if pilot_pixels == 0:
            problems.append("De pilotplots raken het invoerraster niet.")
        for band_index, name in enumerate(module.CHANNELS):
            band = values[band_index]
            valid = band.compressed()
            valid_fraction = float(valid.size / pilot_pixels) if pilot_pixels else 0.0
            bands.append(
                {
                    "band": band_index + 1,
                    "naam": name,
                    "geldige_fractie_binnen_pilotplots": valid_fraction,
                    "minimum": int(valid.min()) if valid.size else None,
                    "maximum": int(valid.max()) if valid.size else None,
                    "gemiddelde": float(valid.mean()) if valid.size else None,
                }
            )
            if valid_fraction < 0.99:
                problems.append(
                    f"{name} is slechts voor {valid_fraction:.1%} van de pilotplotpixels gevuld."
                )
    result = {
        "stack": str(args.stack),
        "stack_sha256": module.sha256(args.stack),
        "plots": str(args.plots),
        "plot_ids": sorted(int(value) for value in plots["plotid"]),
        "banden": bands,
        "problemen": problems,
        "status": "geldig" if not problems else "niet_geldig",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    if problems:
        raise SystemExit("Modelinvoer voldoet niet aan alle controles; zie controlerapport.")


if __name__ == "__main__":
    main()
