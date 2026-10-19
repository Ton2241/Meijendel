#!/usr/bin/env python3
"""Controle en ontsluiting van de aangeleverde Schmidt-Tauscher-rasters."""

from collections import Counter
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import geopandas as gpd
import pandas as pd
import rasterio
from rasterio.features import rasterize
from scipy import ndimage


CLASSES = ("struik", "bos", "boomgroep", "laag", "riet", "zand", "water")


def class_codes(year: int) -> dict[int, str]:
    base = {
        1: "laag",
        2: "struik",
        3: "bos",
        4: "water",
        5: "zand",
        13: "boomgroep",
        26: "riet",
    }
    aliases = {
        2001: {
            **{code: "laag" for code in (137, 138, 139, 140)},
            **{code: "water" for code in (2001, 2002, 2003, 2004, 2005)},
            **{code: "bos" for code in (8001, 8002, 8003, 8004)},
        },
        2022: {
            **{code: "laag" for code in (137, 138, 139, 141)},
            **{code: "bos" for code in (65, 66, 67, 69)},
            **{code: "boomgroep" for code in (75, 76, 77, 79)},
            **{code: "water" for code in (210, 211, 212)},
        },
    }
    if year not in aliases:
        raise ValueError("Landbedekkingsjaar moet 2001 of 2022 zijn.")
    return base | aliases[year]


def raster_class_totals(path: Path, year: int) -> tuple[dict[str, float], dict[int, int]]:
    mapping = class_codes(year)
    with rasterio.open(path) as dataset:
        values = dataset.read(1, masked=True).compressed()
        pixel_area_ha = abs(dataset.transform.a * dataset.transform.e) / 10_000
    counts = Counter(int(value) for value in values)
    unknown = {code: count for code, count in counts.items() if code not in mapping}
    totals = {class_name: 0.0 for class_name in CLASSES}
    for code, count in counts.items():
        if code in mapping:
            totals[mapping[code]] += count * pixel_area_ha
    return totals, unknown


def raster_plot_summary(
    raster_path: Path, plot_path: Path, year: int
) -> tuple[pd.DataFrame, dict[int, int], int]:
    mapping = class_codes(year)
    plots = gpd.read_file(plot_path)
    required = {"plotid", "plot", "opp_ha", "geometry"}
    missing = required - set(plots.columns)
    if missing:
        raise ValueError(f"Plotbestand mist velden: {', '.join(sorted(missing))}")
    if plots["plot"].duplicated().any():
        raise ValueError("Plotbestand bevat dubbele plotcodes.")

    with rasterio.open(raster_path) as dataset:
        if plots.crs != dataset.crs:
            plots = plots.to_crs(dataset.crs)
        values = dataset.read(1, masked=True)
        valid = ~np.ma.getmaskarray(values)
        pixel_area_ha = abs(dataset.transform.a * dataset.transform.e) / 10_000
        plot_grid = rasterize(
            ((geometry, index) for index, geometry in enumerate(plots.geometry, start=1)),
            out_shape=values.shape,
            transform=dataset.transform,
            fill=0,
            all_touched=False,
            dtype="int16",
        )

    integer_values = values.filled(0).astype(np.int64, copy=False)
    valid_codes, valid_counts = np.unique(integer_values[valid], return_counts=True)
    unknown = {
        int(code): int(count)
        for code, count in zip(valid_codes, valid_counts)
        if int(code) not in mapping
    }
    unassigned = int(np.count_nonzero(valid & (plot_grid == 0)))
    rows = []
    for index, plot in enumerate(plots.itertuples(index=False), start=1):
        in_plot = valid & (plot_grid == index)
        counts = Counter(int(value) for value in integer_values[in_plot])
        for class_name in CLASSES:
            count = sum(count for code, count in counts.items() if mapping.get(code) == class_name)
            rows.append(
                {
                    "plot_id_bron": int(plot.plotid),
                    "plot": str(plot.plot),
                    "plot_oppervlak_ha_bron": float(plot.opp_ha),
                    "jaar": year,
                    "klasse": class_name,
                    "pixels": count,
                    "raster_ha": count * pixel_area_ha,
                }
            )
    return pd.DataFrame(rows), unknown, unassigned


def calculate_spatial_metrics(
    classes: np.ndarray, valid: np.ndarray, pixel_size: float
) -> tuple[dict[str, float], list[dict[str, float]]]:
    if classes.shape != valid.shape:
        raise ValueError("Klassen en geldig-masker hebben niet dezelfde vorm.")
    valid_count = int(np.count_nonzero(valid))
    if valid_count == 0:
        raise ValueError("Plot bevat geen geldige rasterpixels.")
    pixel_area_ha = pixel_size * pixel_size / 10_000
    area_ha = valid_count * pixel_area_ha
    class_codes_present, counts = np.unique(classes[valid], return_counts=True)
    shares = counts / valid_count
    shannon = float(-np.sum(shares * np.log(shares)))

    horizontal = valid[:, :-1] & valid[:, 1:] & (classes[:, :-1] != classes[:, 1:])
    vertical = valid[:-1, :] & valid[1:, :] & (classes[:-1, :] != classes[1:, :])
    internal_edge_m = float((np.count_nonzero(horizontal) + np.count_nonzero(vertical)) * pixel_size)

    structure = ndimage.generate_binary_structure(2, 1)
    class_rows = []
    for code, count in zip(class_codes_present, counts):
        class_mask = valid & (classes == code)
        labels, patch_count = ndimage.label(class_mask, structure=structure)
        patch_sizes = np.bincount(labels[class_mask])
        largest = int(patch_sizes.max()) if patch_sizes.size else 0
        touches_horizontal = horizontal & (
            (classes[:, :-1] == code) | (classes[:, 1:] == code)
        )
        touches_vertical = vertical & (
            (classes[:-1, :] == code) | (classes[1:, :] == code)
        )
        class_edge_m = float(
            (np.count_nonzero(touches_horizontal) + np.count_nonzero(touches_vertical))
            * pixel_size
        )
        class_rows.append(
            {
                "klasse_code": int(code),
                "pixels": int(count),
                "aandeel": float(count / valid_count),
                "patches": int(patch_count),
                "patches_per_ha": float(patch_count / area_ha),
                "grootste_patch_aandeel": float(largest / count),
                "rand_m_per_ha": float(class_edge_m / area_ha),
            }
        )
    landscape = {
        "geldige_pixels": valid_count,
        "oppervlak_ha": float(area_ha),
        "klasse_rijkdom": int(len(class_codes_present)),
        "shannon": shannon,
        "interne_rand_m_per_ha": float(internal_edge_m / area_ha),
    }
    return landscape, class_rows


def raster_spatial_summary(
    raster_path: Path, plot_path: Path, year: int
) -> tuple[pd.DataFrame, pd.DataFrame, dict[int, int], int]:
    mapping = class_codes(year)
    plots = gpd.read_file(plot_path)
    required = {"plotid", "plot", "opp_ha", "geometry"}
    missing = required - set(plots.columns)
    if missing:
        raise ValueError(f"Plotbestand mist velden: {', '.join(sorted(missing))}")

    with rasterio.open(raster_path) as dataset:
        if plots.crs != dataset.crs:
            plots = plots.to_crs(dataset.crs)
        raw = dataset.read(1, masked=True)
        valid = ~np.ma.getmaskarray(raw)
        plot_grid = rasterize(
            ((geometry, index) for index, geometry in enumerate(plots.geometry, start=1)),
            out_shape=raw.shape,
            transform=dataset.transform,
            fill=0,
            all_touched=False,
            dtype="int16",
        )
        pixel_size = float(np.sqrt(abs(dataset.transform.a * dataset.transform.e)))

    raw_values = raw.filled(0).astype(np.int64, copy=False)
    codes, counts = np.unique(raw_values[valid], return_counts=True)
    unknown = {
        int(code): int(count)
        for code, count in zip(codes, counts)
        if int(code) not in mapping
    }
    unassigned = int(np.count_nonzero(valid & (plot_grid == 0)))
    ordinal = {class_name: index for index, class_name in enumerate(CLASSES, start=1)}
    collapsed = np.zeros(raw_values.shape, dtype=np.int8)
    for code, class_name in mapping.items():
        collapsed[raw_values == code] = ordinal[class_name]

    landscape_rows = []
    class_rows = []
    for index, plot in enumerate(plots.itertuples(index=False), start=1):
        in_plot = valid & (plot_grid == index)
        landscape, measured_classes = calculate_spatial_metrics(
            collapsed, in_plot, pixel_size
        )
        identity = {
            "plot_id_bron": int(plot.plotid),
            "plot": str(plot.plot),
            "jaar": year,
        }
        landscape_rows.append(identity | landscape)
        measured = {row["klasse_code"]: row for row in measured_classes}
        for class_name, class_code in ordinal.items():
            row = measured.get(
                class_code,
                {
                    "pixels": 0,
                    "aandeel": 0.0,
                    "patches": 0,
                    "patches_per_ha": 0.0,
                    "grootste_patch_aandeel": 0.0,
                    "rand_m_per_ha": 0.0,
                },
            )
            class_rows.append(identity | {"klasse": class_name} | {
                key: value for key, value in row.items() if key != "klasse_code"
            })
    return pd.DataFrame(landscape_rows), pd.DataFrame(class_rows), unknown, unassigned


def compare_with_published(raster_rows: pd.DataFrame, published_path: Path) -> pd.DataFrame:
    published = pd.read_csv(published_path)
    required = {"kavel_nummer", "jaar"} | {f"{class_name}_ha" for class_name in CLASSES}
    missing = required - set(published.columns)
    if missing:
        raise ValueError(f"Gepubliceerde tabel mist velden: {', '.join(sorted(missing))}")
    long = published.melt(
        id_vars=["kavel_nummer", "jaar"],
        value_vars=[f"{class_name}_ha" for class_name in CLASSES],
        var_name="klasse",
        value_name="gepubliceerd_ha",
    )
    long["klasse"] = long["klasse"].str.removesuffix("_ha")
    long["plot"] = long["kavel_nummer"].str.removeprefix("M")
    years = sorted(set(int(year) for year in raster_rows["jaar"]))
    long = long[long["jaar"].isin(years)]
    compared = raster_rows.merge(
        long[["plot", "jaar", "klasse", "gepubliceerd_ha"]],
        on=["plot", "jaar", "klasse"],
        how="outer",
        indicator=True,
    )
    compared["koppelstatus"] = compared["_merge"].map(
        {"both": "gekoppeld", "left_only": "alleen_raster", "right_only": "alleen_tabel"}
    )
    compared = compared.drop(columns="_merge")
    compared["verschil_ha"] = compared["raster_ha"] - compared["gepubliceerd_ha"]
    compared["absoluut_verschil_ha"] = compared["verschil_ha"].abs()
    return compared.sort_values(["jaar", "plot", "klasse"]).reset_index(drop=True)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run_delivery_analysis(
    source_dir: Path, published_path: Path, output_dir: Path
) -> dict:
    source_dir = Path(source_dir)
    published_path = Path(published_path)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    plot_path = source_dir / "kacheln25.shp"
    rasters = {
        2001: source_dir / "classification2001_25k_grove.tif",
        2022: source_dir / "classification2022_grove_25k.tif",
    }

    area_rows = []
    landscape_rows = []
    class_metric_rows = []
    unknown_by_year = {}
    unassigned_by_year = {}
    raster_metadata = {}
    for year, raster_path in rasters.items():
        areas, unknown_area, unassigned_area = raster_plot_summary(
            raster_path, plot_path, year
        )
        landscape, class_metrics, unknown_spatial, unassigned_spatial = (
            raster_spatial_summary(raster_path, plot_path, year)
        )
        if unknown_area != unknown_spatial or unassigned_area != unassigned_spatial:
            raise RuntimeError("Oppervlakte- en ruimtelijke controle spreken elkaar tegen.")
        area_rows.append(areas)
        landscape_rows.append(landscape)
        class_metric_rows.append(class_metrics)
        unknown_by_year[str(year)] = unknown_area
        unassigned_by_year[str(year)] = unassigned_area
        with rasterio.open(raster_path) as dataset:
            raster_metadata[str(year)] = {
                "bestand": raster_path.name,
                "breedte_pixels": dataset.width,
                "hoogte_pixels": dataset.height,
                "crs": dataset.crs.to_string(),
                "pixel_breedte_m": abs(dataset.transform.a),
                "pixel_hoogte_m": abs(dataset.transform.e),
                "geldige_pixels": int(dataset.read_masks(1).astype(bool).sum()),
            }

    areas = pd.concat(area_rows, ignore_index=True)
    comparison = compare_with_published(areas, published_path)
    landscapes = pd.concat(landscape_rows, ignore_index=True)
    class_metrics = pd.concat(class_metric_rows, ignore_index=True)

    change_fields = [
        "aandeel", "patches_per_ha", "grootste_patch_aandeel", "rand_m_per_ha"
    ]
    earlier = class_metrics[class_metrics["jaar"] == 2001][
        ["plot_id_bron", "plot", "klasse", *change_fields]
    ]
    later = class_metrics[class_metrics["jaar"] == 2022][
        ["plot_id_bron", "plot", "klasse", *change_fields]
    ]
    changes = earlier.merge(
        later,
        on=["plot_id_bron", "plot", "klasse"],
        suffixes=("_2001", "_2022"),
        validate="one_to_one",
    )
    for field in change_fields:
        changes[f"verandering_{field}"] = changes[f"{field}_2022"] - changes[f"{field}_2001"]

    comparison.to_csv(
        output_dir / "landbedekking_raster_laatste_oppervlaktecontrole.csv", index=False
    )
    landscapes.to_csv(
        output_dir / "landbedekking_raster_laatste_landscapemetrics.csv", index=False
    )
    class_metrics.to_csv(
        output_dir / "landbedekking_raster_laatste_klassemetrics.csv", index=False
    )
    changes.to_csv(
        output_dir / "landbedekking_raster_laatste_verandering.csv", index=False
    )

    source_files = []
    for path in sorted(source_dir.iterdir()):
        if path.is_file():
            source_files.append(
                {"bestand": path.name, "bytes": path.stat().st_size, "sha256": sha256(path)}
            )
    manifest = {
        "bron": "Schmidt-Tauscher, Häger en Van der Hagen 2025; levering Achim Häger",
        "ontvangstdatum": "2026-10-19",
        "jaren": [2001, 2022],
        "plots": int(landscapes["plot"].nunique()),
        "klassen": list(CLASSES),
        "onbekende_codes": unknown_by_year,
        "niet_toegewezen_pixels": unassigned_by_year,
        "oppervlaktecontrole": {
            str(year): {
                "regels": int((comparison["jaar"] == year).sum()),
                "gemiddeld_absoluut_verschil_ha": float(
                    comparison.loc[comparison["jaar"] == year, "absoluut_verschil_ha"].mean()
                ),
                "maximaal_absoluut_verschil_ha": float(
                    comparison.loc[comparison["jaar"] == year, "absoluut_verschil_ha"].max()
                ),
            }
            for year in rasters
        },
        "raster_metadata": raster_metadata,
        "klassecodes": {
            str(year): {str(code): class_name for code, class_name in class_codes(year).items()}
            for year in rasters
        },
        "bronbestanden": source_files,
    }
    with (output_dir / "landbedekking_raster_laatste_manifest.json").open(
        "w", encoding="utf-8"
    ) as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Valideer en ontsluit de geleverde landbedekkingsrasters."
    )
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--published", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    manifest = run_delivery_analysis(args.source_dir, args.published, args.output_dir)
    print(json.dumps(manifest["oppervlaktecontrole"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
