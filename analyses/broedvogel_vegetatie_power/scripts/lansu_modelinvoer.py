#!/usr/bin/env python3
"""Bouw de zeven invoerlagen voor een lokale toets van het Lansu-U-net.

De bandvolgorde en schaal volgen de gepubliceerde configuratie. De bronrasters
blijven buiten Git; alleen code, contract en compacte manifesten horen in de
repository.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import geopandas as gpd
import numpy as np
import rasterio
from rasterio.enums import Resampling
from rasterio.features import rasterize
from rasterio.merge import merge
from rasterio.transform import from_origin
from rasterio.vrt import WarpedVRT
from rasterio.warp import reproject
from rasterio.windows import Window, bounds as window_bounds
from scipy.ndimage import distance_transform_edt


RESOLUTION_M = 0.25
MODEL_TILE_PIXELS = 2048
MODEL_TILE_M = RESOLUTION_M * MODEL_TILE_PIXELS
NODATA_UINT16 = np.iinfo(np.uint16).max
MAX_ELEVATION_CM = NODATA_UINT16 - 1

CHANNELS = (
    "red",
    "green",
    "blue",
    "near_infrared",
    "dsm_cm",
    "canopy_height_cm",
    "distance_to_sea_m",
)
CLASS_ORDER = (
    "Bare_sand",
    "Shrubs",
    "Fresh_water",
    "Grass",
    "Broadl_trees",
    "Needl_trees",
    "Other",
)
NORMALIZATION_MEAN = (68.8427, 68.4807, 61.6793, 90.5604, 480.2229, 65.1453, 660.0991)
NORMALIZATION_STD = (67.6801, 65.3562, 59.7872, 78.8081, 659.9129, 213.4854, 924.3354)


class ModelGrid:
    def __init__(self, bounds, width, height, transform, crs="EPSG:28992"):
        self.bounds = bounds
        self.width = width
        self.height = height
        self.transform = transform
        self.crs = crs


def model_grid(bounds: tuple[float, float, float, float]) -> ModelGrid:
    """Leg een selectie vast op hele U-net-invoertegels van 512 meter."""
    left, bottom, right, top = bounds
    aligned_left = math.floor(left / MODEL_TILE_M) * MODEL_TILE_M
    aligned_bottom = math.floor(bottom / MODEL_TILE_M) * MODEL_TILE_M
    aligned_right = math.ceil(right / MODEL_TILE_M) * MODEL_TILE_M
    aligned_top = math.ceil(top / MODEL_TILE_M) * MODEL_TILE_M
    width = int(round((aligned_right - aligned_left) / RESOLUTION_M))
    height = int(round((aligned_top - aligned_bottom) / RESOLUTION_M))
    return ModelGrid(
        bounds=(aligned_left, aligned_bottom, aligned_right, aligned_top),
        width=width,
        height=height,
        transform=from_origin(aligned_left, aligned_top, RESOLUTION_M, RESOLUTION_M),
    )


def near_infrared(cir: np.ndarray) -> np.ndarray:
    if cir.ndim != 3 or cir.shape[0] != 3:
        raise ValueError("CIR moet drie banden bevatten in de volgorde NIR-rood-groen.")
    return cir[0]


def elevation_channels(dsm_m: np.ndarray, dtm_m: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    if dsm_m.shape != dtm_m.shape:
        raise ValueError("DSM en DTM moeten dezelfde rastervorm hebben.")
    dsm = np.asarray(dsm_m, dtype=np.float64)
    dtm = np.asarray(dtm_m, dtype=np.float64)
    valid_dsm = np.isfinite(dsm) & (dsm >= 0) & (dsm * 100 <= MAX_ELEVATION_CM)
    valid_canopy = valid_dsm & np.isfinite(dtm)
    dsm_cm = np.full(dsm.shape, NODATA_UINT16, dtype=np.uint16)
    canopy_cm = np.full(dsm.shape, NODATA_UINT16, dtype=np.uint16)
    dsm_cm[valid_dsm] = np.rint(dsm[valid_dsm] * 100).astype(np.uint16)
    canopy_m = np.maximum(dsm - dtm, 0.0)
    valid_canopy &= canopy_m * 100 <= MAX_ELEVATION_CM
    canopy_cm[valid_canopy] = np.rint(canopy_m[valid_canopy] * 100).astype(np.uint16)
    return dsm_cm, canopy_cm


def checkpoint_contract(input_channels: int, output_classes: int) -> list[str]:
    problems = []
    if input_channels != len(CHANNELS):
        problems.append(f"Checkpoint verwacht niet de vereiste 7 invoerkanalen: {input_channels}.")
    if output_classes != len(CLASS_ORDER):
        problems.append(f"Checkpoint bevat niet de vereiste 7 uitvoerklassen: {output_classes}.")
    return problems


def infer_checkpoint_contract(state_dict) -> dict:
    convolution_weights = []
    for name, value in state_dict.items():
        shape = tuple(int(item) for item in value.shape)
        if name.endswith("weight") and len(shape) == 4:
            convolution_weights.append((name, shape))
    if len(convolution_weights) < 2:
        raise ValueError("Checkpoint bevat onvoldoende convolutionele gewichten.")
    first_name, first_shape = convolution_weights[0]
    last_name, last_shape = convolution_weights[-1]
    input_channels = first_shape[1]
    output_classes = last_shape[0]
    return {
        "eerste_convolutie": first_name,
        "eerste_vorm": list(first_shape),
        "laatste_convolutie": last_name,
        "laatste_vorm": list(last_shape),
        "invoerkanalen": input_channels,
        "uitvoerklassen": output_classes,
        "problemen": checkpoint_contract(input_channels, output_classes),
    }


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _read_mosaic(sources, bounds, indexes) -> np.ndarray:
    values, transform = merge(
        sources,
        bounds=bounds,
        res=(RESOLUTION_M, RESOLUTION_M),
        indexes=indexes,
        nodata=0,
        method="first",
    )
    expected_transform = from_origin(bounds[0], bounds[3], RESOLUTION_M, RESOLUTION_M)
    if not transform.almost_equals(expected_transform):
        raise ValueError("Luchtfotomozaiek ligt niet exact op het doelrooster.")
    return values


def _distance_to_coast(coast_path: Path, coast_layer: str, grid: ModelGrid) -> np.ndarray:
    coast = gpd.read_file(coast_path, layer=coast_layer)
    if "segmenttype" in coast.columns:
        coast = coast[coast["segmenttype"] == "officiele_kustlijn"]
    if coast.empty:
        raise ValueError("Geen officiële kustlijn gevonden.")
    coast = coast.to_crs(grid.crs)
    coast_geometry = coast.geometry.union_all()
    source_res = 5.0
    left = min(grid.bounds[0], math.floor(coast_geometry.bounds[0] / source_res) * source_res)
    bottom = min(grid.bounds[1], math.floor(coast_geometry.bounds[1] / source_res) * source_res)
    right = max(grid.bounds[2], math.ceil(coast_geometry.bounds[2] / source_res) * source_res)
    top = max(grid.bounds[3], math.ceil(coast_geometry.bounds[3] / source_res) * source_res)
    width = int(round((right - left) / source_res))
    height = int(round((top - bottom) / source_res))
    transform = from_origin(left, top, source_res, source_res)
    coast_pixels = rasterize(
        [(coast_geometry, 1)],
        out_shape=(height, width),
        transform=transform,
        fill=0,
        all_touched=True,
        dtype=np.uint8,
    )
    coarse_distance = distance_transform_edt(coast_pixels == 0) * source_res
    destination = np.empty((grid.height, grid.width), dtype=np.float32)
    reproject(
        coarse_distance.astype(np.float32),
        destination,
        src_transform=transform,
        src_crs=grid.crs,
        dst_transform=grid.transform,
        dst_crs=grid.crs,
        resampling=Resampling.nearest,
    )
    return destination


def _profile(grid: ModelGrid) -> dict:
    return {
        "driver": "GTiff",
        "width": grid.width,
        "height": grid.height,
        "count": len(CHANNELS),
        "dtype": "uint16",
        "crs": grid.crs,
        "transform": grid.transform,
        "nodata": NODATA_UINT16,
        "compress": "DEFLATE",
        "predictor": 2,
        "tiled": True,
        "blockxsize": 512,
        "blockysize": 512,
        "bigtiff": "YES",
    }


def build_stack(
    plots_path: Path,
    rgb_paths: list[Path],
    cir_paths: list[Path],
    dsm_path: Path,
    dtm_path: Path,
    coast_path: Path,
    coast_layer: str,
    output_path: Path,
) -> dict:
    plots = gpd.read_file(plots_path).to_crs("EPSG:28992")
    grid = model_grid(tuple(float(value) for value in plots.total_bounds))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    distance = _distance_to_coast(coast_path, coast_layer, grid)
    pilot_mask = rasterize(
        [(plots.geometry.union_all(), 1)],
        out_shape=(grid.height, grid.width),
        transform=grid.transform,
        fill=0,
        all_touched=False,
        dtype=np.uint8,
    ).astype(bool)
    pilot_pixels = int(pilot_mask.sum())
    dsm_valid_pilot = 0
    canopy_valid_pilot = 0
    rgb_sources = [rasterio.open(path) for path in rgb_paths]
    cir_sources = [rasterio.open(path) for path in cir_paths]
    try:
        with rasterio.open(dsm_path) as dsm_source, rasterio.open(dtm_path) as dtm_source:
            vrt_options = {
                "crs": grid.crs,
                "transform": grid.transform,
                "width": grid.width,
                "height": grid.height,
                "resampling": Resampling.nearest,
                "nodata": np.nan,
                "dtype": "float32",
            }
            with WarpedVRT(dsm_source, **vrt_options) as dsm, WarpedVRT(dtm_source, **vrt_options) as dtm:
                with rasterio.open(output_path, "w", **_profile(grid)) as target:
                    for index, name in enumerate(CHANNELS, start=1):
                        target.set_band_description(index, name)
                    for row in range(0, grid.height, MODEL_TILE_PIXELS):
                        for col in range(0, grid.width, MODEL_TILE_PIXELS):
                            window = Window(col, row, MODEL_TILE_PIXELS, MODEL_TILE_PIXELS)
                            bounds = window_bounds(window, grid.transform)
                            rgb = _read_mosaic(rgb_sources, bounds, [1, 2, 3]).astype(np.uint16)
                            cir = _read_mosaic(cir_sources, bounds, [1, 2, 3])
                            dsm_values = dsm.read(1, window=window, masked=True).filled(np.nan)
                            dtm_values = dtm.read(1, window=window, masked=True).filled(np.nan)
                            dsm_cm, canopy_cm = elevation_channels(dsm_values, dtm_values)
                            pilot_tile = pilot_mask[
                                row : row + MODEL_TILE_PIXELS,
                                col : col + MODEL_TILE_PIXELS,
                            ]
                            dsm_valid_pilot += int((pilot_tile & (dsm_cm != NODATA_UINT16)).sum())
                            canopy_valid_pilot += int((pilot_tile & (canopy_cm != NODATA_UINT16)).sum())
                            # De datalader van Lansu normaliseert iedere pixel zonder apart
                            # nodatamasker. Water en AHN-gaten moeten daarom numeriek nul zijn.
                            dsm_cm[dsm_cm == NODATA_UINT16] = 0
                            canopy_cm[canopy_cm == NODATA_UINT16] = 0
                            bands = (
                                rgb[0],
                                rgb[1],
                                rgb[2],
                                near_infrared(cir).astype(np.uint16),
                                dsm_cm,
                                canopy_cm,
                                np.rint(distance[row : row + MODEL_TILE_PIXELS, col : col + MODEL_TILE_PIXELS]).astype(np.uint16),
                            )
                            for band_index, values in enumerate(bands, start=1):
                                target.write(values, band_index, window=window)
    finally:
        for source in rgb_sources + cir_sources:
            source.close()
    return {
        "bandvolgorde": list(CHANNELS),
        "klassevolgorde": list(CLASS_ORDER),
        "normalisatie_gemiddelde": list(NORMALIZATION_MEAN),
        "normalisatie_sd": list(NORMALIZATION_STD),
        "resolutie_m": RESOLUTION_M,
        "modeltegel_pixels": MODEL_TILE_PIXELS,
        "modeltegel_m": MODEL_TILE_M,
        "grid_bounds_rd": list(grid.bounds),
        "breedte_pixels": grid.width,
        "hoogte_pixels": grid.height,
        "plot_ids": sorted(int(value) for value in plots["plotid"]),
        "plot_namen": sorted(str(value) for value in plots["naam"]),
        "afstand_tot_zee": "BRT gemiddelde hoogwaterlijn, 5 m bronrooster, nearest-neighbour naar 25 cm",
        "hoogteschaal": "AHN4 DSM en DSM-DTM in meters, afgerond naar centimeters",
        "ahn4_brondekking_binnen_pilotplots": {
            "dsm": dsm_valid_pilot / pilot_pixels,
            "dsm_en_dtm_voor_kroonhoogte": canopy_valid_pilot / pilot_pixels,
            "ontbrekende_bronpixels_in_modelinvoer": "0, overeenkomstig een datalader zonder nodatamasker",
        },
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plots", type=Path, required=True)
    parser.add_argument("--rgb", type=Path, action="append", required=True)
    parser.add_argument("--cir", type=Path, action="append", required=True)
    parser.add_argument("--dsm", type=Path, required=True)
    parser.add_argument("--dtm", type=Path, required=True)
    parser.add_argument("--coast", type=Path, required=True)
    parser.add_argument("--coast-layer", default="meijendel_grenssegmenten")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    manifest = build_stack(
        args.plots,
        args.rgb,
        args.cir,
        args.dsm,
        args.dtm,
        args.coast,
        args.coast_layer,
        args.output,
    )
    sources = [args.plots, *args.rgb, *args.cir, args.dsm, args.dtm, args.coast]
    manifest["bronnen"] = [
        {"pad": str(path), "sha256": sha256(path)} for path in sources if path.is_file()
    ]
    manifest["uitvoer"] = {"pad": str(args.output), "sha256": sha256(args.output)}
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
