#!/usr/bin/env python3

"""Selecteer officiële AHN-kaartbladen die de vogelplots raken."""

from __future__ import annotations

import argparse
from pathlib import Path

import geopandas as gpd
import pandas as pd


REQUIRED_PROPERTIES = ("file", "size", "sha256")


def select_tiles(index_path: str, plots_path: str) -> pd.DataFrame:
    tiles = gpd.read_file(index_path)
    plots = gpd.read_file(plots_path)
    missing = [name for name in REQUIRED_PROPERTIES if name not in tiles.columns]
    if missing:
        raise ValueError(f"Bladwijzer mist verplichte velden: {', '.join(missing)}")
    if tiles.crs is None or plots.crs is None:
        raise ValueError("Bladwijzer en plots moeten een CRS hebben.")
    if plots.crs != tiles.crs:
        plots = plots.to_crs(tiles.crs)

    plot_area = plots.geometry.union_all()
    selected = tiles.loc[tiles.geometry.intersects(plot_area)].copy()
    if selected.empty:
        raise ValueError("Geen AHN-kaartblad raakt de opgegeven plots.")
    selected["bestand"] = selected["file"].map(lambda value: Path(value).name)
    selected["omvang_bytes"] = pd.to_numeric(selected["size"], errors="raise").astype(
        "int64"
    )
    selected = selected.rename(columns={"file": "url"})
    return selected[["bestand", "url", "omvang_bytes", "sha256"]].sort_values(
        "bestand"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--index", required=True)
    parser.add_argument("--plots", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    result = select_tiles(args.index, args.plots)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    result.to_csv(output, index=False)


if __name__ == "__main__":
    main()
