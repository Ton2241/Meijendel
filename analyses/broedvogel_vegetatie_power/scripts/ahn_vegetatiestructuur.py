#!/usr/bin/env python3

"""Leid reproduceerbare AHN-hoogteproxies per vogelplot af.

DSM minus DTM meet objecthoogte. Buiten Meijendel kan dat ook bebouwing zijn;
de uitkomst wordt daarom uitsluitend als vegetatiestructuurproxy gebruikt.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd
import rasterio
from rasterio.mask import mask


MIN_OBJECT_HEIGHT_M = 0.15
SHRUB_HEIGHT_M = 2.0
TREE_HEIGHT_M = 5.0
MAX_PLAUSIBLE_HEIGHT_M = 45.0


def _edge_length(classes: np.ndarray, valid: np.ndarray, pixel_size: float) -> float:
    horizontal = (
        valid[:, :-1]
        & valid[:, 1:]
        & (classes[:, :-1] != classes[:, 1:])
    )
    vertical = (
        valid[:-1, :]
        & valid[1:, :]
        & (classes[:-1, :] != classes[1:, :])
    )
    return float((horizontal.sum() + vertical.sum()) * pixel_size)


def calculate_height_metrics(
    dsm: np.ndarray, dtm: np.ndarray, pixel_size: float
) -> dict[str, float | int]:
    if dsm.shape != dtm.shape:
        raise ValueError("DSM en DTM moeten dezelfde rastervorm hebben.")
    raw = np.asarray(dsm, dtype=float) - np.asarray(dtm, dtype=float)
    finite = np.isfinite(raw)
    outlier = finite & (raw > MAX_PLAUSIBLE_HEIGHT_M)
    valid = finite & ~outlier
    height = np.where(valid, np.maximum(raw, 0.0), np.nan)
    values = height[valid]
    result: dict[str, float | int] = {
        "geldige_pixels": int(valid.sum()),
        "uitbijter_pixels": int(outlier.sum()),
    }
    metric_names = (
        "hoogte_mediaan_m",
        "hoogte_p95_m",
        "hoogte_max_m",
        "hoogte_sd_m",
        "aandeel_open",
        "aandeel_lage_vegetatie",
        "aandeel_struweel",
        "aandeel_bomen",
        "randlengte_m_per_ha",
    )
    if not values.size:
        result.update({name: float("nan") for name in metric_names})
        return result

    classes = np.full(height.shape, -1, dtype=np.int8)
    classes[valid & (height <= MIN_OBJECT_HEIGHT_M)] = 0
    classes[valid & (height > MIN_OBJECT_HEIGHT_M) & (height < SHRUB_HEIGHT_M)] = 1
    classes[valid & (height >= SHRUB_HEIGHT_M) & (height < TREE_HEIGHT_M)] = 2
    classes[valid & (height >= TREE_HEIGHT_M)] = 3
    area_ha = values.size * pixel_size * pixel_size / 10_000.0
    result.update(
        {
            "hoogte_mediaan_m": float(np.median(values)),
            "hoogte_p95_m": float(np.quantile(values, 0.95)),
            "hoogte_max_m": float(np.max(values)),
            "hoogte_sd_m": float(np.std(values, ddof=0)),
            "aandeel_open": float(np.mean(values <= MIN_OBJECT_HEIGHT_M)),
            "aandeel_lage_vegetatie": float(
                np.mean((values > MIN_OBJECT_HEIGHT_M) & (values < SHRUB_HEIGHT_M))
            ),
            "aandeel_struweel": float(
                np.mean((values >= SHRUB_HEIGHT_M) & (values < TREE_HEIGHT_M))
            ),
            "aandeel_bomen": float(np.mean(values >= TREE_HEIGHT_M)),
            "randlengte_m_per_ha": _edge_length(classes, valid, pixel_size) / area_ha,
        }
    )
    return result


def dominant_acquisition_dates(
    plots: gpd.GeoDataFrame,
    flightlines: gpd.GeoDataFrame,
    date_field: str,
    max_nearest_distance_m: float = 500.0,
) -> pd.DataFrame:
    if date_field not in flightlines.columns:
        raise ValueError(f"Datumveld ontbreekt in vlieglijnen: {date_field}")
    if plots.crs != flightlines.crs:
        flightlines = flightlines.to_crs(plots.crs)
    overlap = gpd.overlay(
        plots[["plotid", "geometry"]],
        flightlines[[date_field, "geometry"]],
        how="intersection",
        keep_geom_type=False,
    )
    rows = []
    if not overlap.empty:
        overlap["inwinningsdatum"] = pd.to_datetime(
            overlap[date_field], errors="raise"
        ).dt.strftime("%Y-%m-%d")
        overlap["gewicht"] = overlap.geometry.area
        zero_area = overlap["gewicht"] <= 0
        overlap.loc[zero_area, "gewicht"] = overlap.loc[zero_area].geometry.length
        weights = (
            overlap.groupby(["plotid", "inwinningsdatum"], as_index=False)["gewicht"]
            .sum()
            .sort_values(
                ["plotid", "gewicht", "inwinningsdatum"],
                ascending=[True, False, True],
            )
        )
        totals = weights.groupby("plotid")["gewicht"].sum()
        for row in weights.drop_duplicates("plotid").itertuples():
            rows.append(
                {
                    "plotid": int(row.plotid),
                    "inwinningsdatum": row.inwinningsdatum,
                    "datum_dekkingsaandeel": float(row.gewicht / totals.loc[row.plotid]),
                    "datum_methode": "vlakoverlap",
                    "afstand_vlieglijn_m": 0.0,
                }
            )
    covered = {row["plotid"] for row in rows}
    normalized_dates = pd.to_datetime(flightlines[date_field], errors="raise").dt.strftime(
        "%Y-%m-%d"
    )
    for plot in plots[~plots["plotid"].isin(covered)].itertuples():
        distances = flightlines.geometry.distance(plot.geometry)
        nearest = int(distances.idxmin())
        distance = float(distances.loc[nearest])
        if distance <= max_nearest_distance_m:
            rows.append(
                {
                    "plotid": int(plot.plotid),
                    "inwinningsdatum": normalized_dates.loc[nearest],
                    "datum_dekkingsaandeel": float("nan"),
                    "datum_methode": "dichtstbijzijnde_vlieglijn",
                    "afstand_vlieglijn_m": distance,
                }
            )
    return pd.DataFrame(rows).set_index("plotid").sort_index()


def _read_masked_band(src: rasterio.io.DatasetReader, geometry) -> np.ndarray:
    data, _ = mask(src, [geometry.__geo_interface__], crop=True, filled=True)
    values = data[0].astype(float)
    if src.nodata is not None:
        values[values == src.nodata] = np.nan
    return values


def derive_plot_metrics(
    plots_path: str,
    dsm_path: str,
    dtm_path: str,
    cycle: str,
    flightlines_path: str,
    date_field: str,
) -> pd.DataFrame:
    plots = gpd.read_file(plots_path)
    if "plotid" not in plots.columns:
        raise ValueError("Veld 'plotid' ontbreekt in het plotbestand.")
    flightlines = gpd.read_file(flightlines_path)
    dates = dominant_acquisition_dates(plots, flightlines, date_field)
    with rasterio.open(dsm_path) as dsm_src, rasterio.open(dtm_path) as dtm_src:
        if dsm_src.crs != dtm_src.crs or dsm_src.transform != dtm_src.transform:
            raise ValueError("DSM en DTM hebben niet hetzelfde rastergrid.")
        if plots.crs != dsm_src.crs:
            plots = plots.to_crs(dsm_src.crs)
        pixel_size = float(abs(dsm_src.transform.a))
        rows = []
        for feature in plots.itertuples():
            if feature.plotid not in dates.index:
                continue
            acquisition_date = dates.loc[feature.plotid, "inwinningsdatum"]
            dsm = _read_masked_band(dsm_src, feature.geometry)
            dtm = _read_masked_band(dtm_src, feature.geometry)
            metrics = calculate_height_metrics(dsm, dtm, pixel_size)
            rows.append(
                {
                    "plot_id": int(feature.plotid),
                    "ahn_cyclus": cycle,
                    "inwinningsdatum": acquisition_date,
                    "inwinningsjaar": int(acquisition_date[:4]),
                    "datum_dekkingsaandeel": float(
                        dates.loc[feature.plotid, "datum_dekkingsaandeel"]
                    ),
                    "datum_methode": dates.loc[feature.plotid, "datum_methode"],
                    "afstand_vlieglijn_m": float(
                        dates.loc[feature.plotid, "afstand_vlieglijn_m"]
                    ),
                    "resolutie_m": pixel_size,
                    **metrics,
                }
            )
    return pd.DataFrame(rows).sort_values(["inwinningsjaar", "plot_id"])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plots", required=True)
    parser.add_argument("--dsm", required=True)
    parser.add_argument("--dtm", required=True)
    parser.add_argument("--cycle", required=True)
    parser.add_argument("--flightlines", required=True)
    parser.add_argument("--date-field", default="datum")
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    result = derive_plot_metrics(
        args.plots,
        args.dsm,
        args.dtm,
        args.cycle,
        args.flightlines,
        args.date_field,
    )
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    result.to_csv(output, index=False)


if __name__ == "__main__":
    main()
