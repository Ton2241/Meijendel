#!/usr/bin/env python3

"""Rasteriseer historische AHN1-grond- en niet-grondpunten op een gedeeld grid."""

from __future__ import annotations

import argparse
from pathlib import Path

import laspy
import numpy as np
import pandas as pd
import rasterio
from rasterio.transform import from_origin


NODATA = -9999.0


class RasterAccumulator:
    def __init__(self, bounds: tuple[float, float, float, float], resolution: float):
        self.min_x, self.min_y, self.max_x, self.max_y = bounds
        self.resolution = float(resolution)
        self.width = int(round((self.max_x - self.min_x) / self.resolution))
        self.height = int(round((self.max_y - self.min_y) / self.resolution))
        shape = (self.height, self.width)
        self.ground_sum = np.zeros(shape, dtype=np.float64)
        self.ground_count = np.zeros(shape, dtype=np.uint32)
        self.all_sum = np.zeros(shape, dtype=np.float64)
        self.all_count = np.zeros(shape, dtype=np.uint32)
        self.all_max = np.full(shape, -np.inf, dtype=np.float64)
        self.ground_points = 0
        self.nonground_points = 0

    def add(self, x: np.ndarray, y: np.ndarray, z: np.ndarray, ground: bool) -> int:
        col = np.floor((x - self.min_x) / self.resolution).astype(np.int64)
        row = np.floor((self.max_y - y) / self.resolution).astype(np.int64)
        valid = (
            np.isfinite(x)
            & np.isfinite(y)
            & np.isfinite(z)
            & (col >= 0)
            & (col < self.width)
            & (row >= 0)
            & (row < self.height)
        )
        row, col, z = row[valid], col[valid], z[valid]
        np.add.at(self.all_sum, (row, col), z)
        np.add.at(self.all_count, (row, col), 1)
        np.maximum.at(self.all_max, (row, col), z)
        if ground:
            np.add.at(self.ground_sum, (row, col), z)
            np.add.at(self.ground_count, (row, col), 1)
            self.ground_points += int(valid.sum())
        else:
            self.nonground_points += int(valid.sum())
        return int(valid.sum())

    def arrays(self) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
        dtm = np.full(self.ground_sum.shape, np.nan, dtype=np.float32)
        dsm_mean = np.full(self.ground_sum.shape, np.nan, dtype=np.float32)
        dsm_max = np.full(self.ground_sum.shape, np.nan, dtype=np.float32)
        ground = self.ground_count > 0
        occupied = self.all_count > 0
        dtm[ground] = (self.ground_sum[ground] / self.ground_count[ground]).astype(
            np.float32
        )
        dsm_mean[occupied] = (self.all_sum[occupied] / self.all_count[occupied]).astype(
            np.float32
        )
        dsm_max[occupied] = self.all_max[occupied].astype(np.float32)
        return dtm, dsm_mean, dsm_max

    def summary(self) -> pd.DataFrame:
        cells = self.width * self.height
        return pd.DataFrame(
            [
                {
                    "resolutie_m": self.resolution,
                    "cellen": cells,
                    "cellen_met_grond": int((self.ground_count > 0).sum()),
                    "aandeel_cellen_met_grond": float((self.ground_count > 0).sum() / cells),
                    "cellen_met_enig_punt": int((self.all_count > 0).sum()),
                    "aandeel_cellen_met_enig_punt": float((self.all_count > 0).sum() / cells),
                    "grondpunten": self.ground_points,
                    "niet_grondpunten": self.nonground_points,
                    "punten_per_m2": float(
                        (self.ground_points + self.nonground_points)
                        / ((self.max_x - self.min_x) * (self.max_y - self.min_y))
                    ),
                }
            ]
        )


def add_laz_files(
    accumulator: RasterAccumulator, files: list[str], ground: bool, chunk_size: int
) -> None:
    for path in files:
        with laspy.open(path) as source:
            for points in source.chunk_iterator(chunk_size):
                accumulator.add(
                    np.asarray(points.x), np.asarray(points.y), np.asarray(points.z), ground
                )


def write_raster(path: str, values: np.ndarray, accumulator: RasterAccumulator) -> None:
    output = np.where(np.isfinite(values), values, NODATA).astype(np.float32)
    with rasterio.open(
        path,
        "w",
        driver="GTiff",
        height=accumulator.height,
        width=accumulator.width,
        count=1,
        dtype="float32",
        crs="EPSG:28992",
        transform=from_origin(
            accumulator.min_x, accumulator.max_y,
            accumulator.resolution, accumulator.resolution
        ),
        nodata=NODATA,
        compress="deflate",
        tiled=True,
    ) as target:
        target.write(output, 1)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ground", nargs="+", required=True)
    parser.add_argument("--nonground", nargs="+", required=True)
    parser.add_argument("--bounds", nargs=4, type=float, required=True)
    parser.add_argument("--resolution", type=float, default=5.0)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--chunk-size", type=int, default=1_000_000)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output = Path(args.output_dir)
    output.mkdir(parents=True, exist_ok=True)
    accumulator = RasterAccumulator(tuple(args.bounds), args.resolution)
    add_laz_files(accumulator, args.ground, True, args.chunk_size)
    add_laz_files(accumulator, args.nonground, False, args.chunk_size)
    dtm, dsm_mean, dsm_max = accumulator.arrays()
    write_raster(str(output / "ahn1_dtm_mean_ground_5m.tif"), dtm, accumulator)
    write_raster(str(output / "ahn1_dsm_mean_all_5m.tif"), dsm_mean, accumulator)
    write_raster(str(output / "ahn1_dsm_max_all_5m.tif"), dsm_max, accumulator)
    accumulator.summary().to_csv(output / "ahn1_raster_haalbaarheid.csv", index=False)


if __name__ == "__main__":
    main()
