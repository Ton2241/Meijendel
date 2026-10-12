#!/usr/bin/env python3
"""Kleine, reproduceerbare RGB/CIR-classificatieproef voor Meijendel."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
from typing import Iterable

import geopandas as gpd
import numpy as np
import rasterio
import sklearn
from rasterio.features import rasterize
from scipy.ndimage import uniform_filter
from sklearn.ensemble import RandomForestClassifier


CLASS_NAMES = ("open", "laag", "struweel", "boom")
NORMALIZED_FEATURE_NAMES = (
    "rgb_r_fractie", "rgb_g_fractie", "rgb_b_fractie",
    "cir_nir_fractie", "cir_r_fractie", "cir_g_fractie",
    "ndvi", "helderheid_norm", "rgb_textuur", "nir_textuur",
)
RAW_FEATURE_NAMES = ("rgb_r", "rgb_g", "rgb_b", "cir_nir", "cir_r", "cir_g", "ndvi", "brightness")
EXCLUDED_PLOT_IDS = {3503, 3514}  # M66 en M91: buiten Natura 2000-analysescope.


def height_classes(height: np.ndarray) -> np.ndarray:
    result = np.full(height.shape, -1, dtype=np.int8)
    finite = np.isfinite(height)
    result[finite & (height < 0.5)] = 0
    result[finite & (height >= 0.5) & (height < 2.0)] = 1
    result[finite & (height >= 2.0) & (height < 5.0)] = 2
    result[finite & (height >= 5.0)] = 3
    return result


def spectral_features(rgb: np.ndarray, cir: np.ndarray, mode="genormaliseerd"):
    if rgb.shape[0] != 3 or cir.shape[0] != 3 or rgb.shape[1:] != cir.shape[1:]:
        raise ValueError("RGB en CIR moeten dezelfde driedelige rastervorm hebben.")
    rgb = rgb.astype(np.float32, copy=False)
    cir = cir.astype(np.float32, copy=False)
    nir = cir[0]
    red = cir[1]
    ndvi = (nir - red) / np.maximum(nir + red, 1.0)
    brightness = np.mean(rgb, axis=0)
    if mode == "raw":
        stacked = np.moveaxis(
            np.concatenate((rgb, cir, ndvi[None], brightness[None]), axis=0), 0, -1
        )
        return stacked, list(RAW_FEATURE_NAMES)
    if mode != "genormaliseerd":
        raise ValueError(f"Onbekende kenmerkenset: {mode}")
    rgb_fraction = rgb / np.maximum(np.sum(rgb, axis=0, keepdims=True), 1.0)
    cir_fraction = cir / np.maximum(np.sum(cir, axis=0, keepdims=True), 1.0)
    lower, upper = np.nanpercentile(brightness, (2, 98))
    brightness_norm = np.clip((brightness - lower) / max(upper - lower, 1.0), 0.0, 1.0)

    def local_std(values):
        mean = uniform_filter(values, size=5, mode="nearest")
        mean_square = uniform_filter(values * values, size=5, mode="nearest")
        return np.sqrt(np.maximum(mean_square - mean * mean, 0.0)) / 255.0

    stacked = np.moveaxis(np.concatenate((
        rgb_fraction, cir_fraction, ndvi[None], brightness_norm[None],
        local_std(brightness)[None], local_std(nir)[None],
    ), axis=0), 0, -1)
    return stacked, list(NORMALIZED_FEATURE_NAMES)


def classification_metrics(truth: np.ndarray, predicted: np.ndarray):
    truth = np.asarray(truth)
    predicted = np.asarray(predicted)
    if truth.shape != predicted.shape:
        raise ValueError("Werkelijkheid en voorspelling hebben niet dezelfde vorm.")
    rows = []
    f1_values = []
    for code, name in enumerate(CLASS_NAMES):
        tp = int(np.sum((truth == code) & (predicted == code)))
        fp = int(np.sum((truth != code) & (predicted == code)))
        fn = int(np.sum((truth == code) & (predicted != code)))
        precision = tp / (tp + fp) if tp + fp else 0.0
        recall = tp / (tp + fn) if tp + fn else 0.0
        f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
        f1_values.append(f1)
        rows.append({
            "klasse": name, "n_werkelijk": int(np.sum(truth == code)),
            "n_voorspeld": int(np.sum(predicted == code)), "precision": precision,
            "recall": recall, "f1": f1,
        })
    return {
        "n": int(truth.size),
        "accuracy": float(np.mean(truth == predicted)) if truth.size else float("nan"),
        "macro_f1": float(np.mean(f1_values)),
    }, rows


def aggregate_plot_shares(classes: np.ndarray, plot_ids: np.ndarray, selected_plot_ids: Iterable[int]):
    rows = []
    for plot_id in selected_plot_ids:
        values = classes[plot_ids == plot_id]
        values = values[values >= 0]
        n = int(values.size)
        for code, name in enumerate(CLASS_NAMES):
            rows.append({
                "plot_id": int(plot_id), "klasse": name, "n_pixels": n,
                "aandeel": float(np.mean(values == code)) if n else float("nan"),
            })
    return rows


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_three_band(path: Path):
    with rasterio.open(path) as src:
        if src.count != 3:
            raise ValueError(f"{path.name} heeft {src.count} in plaats van drie banden.")
        return src.read(), src.profile, src.transform, src.crs


def read_height(dsm_path: Path, dtm_path: Path, expected_profile: dict):
    with rasterio.open(dsm_path) as dsm, rasterio.open(dtm_path) as dtm:
        for src in (dsm, dtm):
            if (
                src.width != expected_profile["width"]
                or src.height != expected_profile["height"]
                or src.transform != expected_profile["transform"]
                or src.crs != expected_profile["crs"]
            ):
                raise ValueError(f"Rasterrooster wijkt af: {src.name}")
        dsm_values = dsm.read(1).astype(np.float32)
        dtm_values = dtm.read(1).astype(np.float32)
        valid = np.isfinite(dsm_values) & np.isfinite(dtm_values)
        height = np.full(dsm_values.shape, np.nan, dtype=np.float32)
        height[valid] = np.maximum(dsm_values[valid] - dtm_values[valid], 0.0)
        return height


def plot_id_raster(shapefile: Path, profile: dict):
    plots = gpd.read_file(shapefile)
    plots = plots[~plots["plotid"].astype(int).isin(EXCLUDED_PLOT_IDS)].copy()
    if len(plots) != 53:
        raise ValueError(f"Na uitsluiting van M66 en M91 werden 53 plots verwacht, gevonden: {len(plots)}")
    shapes = ((geom, int(plot_id)) for geom, plot_id in zip(plots.geometry, plots["plotid"]))
    result = rasterize(
        shapes, out_shape=(profile["height"], profile["width"]),
        transform=profile["transform"], fill=0, dtype="int32",
    )
    return result, sorted(plots["plotid"].astype(int).tolist())


def balanced_sample(features, labels, plot_ids, per_class: int, seed: int):
    rng = np.random.default_rng(seed)
    valid = (labels >= 0) & (plot_ids > 0) & np.all(np.isfinite(features), axis=-1)
    flat_features = features.reshape(-1, features.shape[-1])
    flat_labels = labels.ravel()
    flat_valid = valid.ravel()
    selected = []
    for code in range(len(CLASS_NAMES)):
        indices = np.flatnonzero(flat_valid & (flat_labels == code))
        if not len(indices):
            raise ValueError(f"Geen pixels voor klasse {CLASS_NAMES[code]}.")
        selected.append(rng.choice(indices, min(per_class, len(indices)), replace=False))
    indices = np.concatenate(selected)
    rng.shuffle(indices)
    return flat_features[indices], flat_labels[indices]


def build_forest(seed: int):
    return RandomForestClassifier(
        n_estimators=160, max_depth=18, min_samples_leaf=4,
        class_weight="balanced_subsample", n_jobs=2, random_state=seed,
    )


def predict_in_chunks(model, features, valid, chunk_size=250_000):
    result = np.full(valid.shape, -1, dtype=np.int8)
    flat_valid = np.flatnonzero(valid.ravel())
    flat_features = features.reshape(-1, features.shape[-1])
    flat_result = result.ravel()
    for start in range(0, len(flat_valid), chunk_size):
        indices = flat_valid[start:start + chunk_size]
        flat_result[indices] = model.predict(flat_features[indices]).astype(np.int8)
    return result


def write_csv(path: Path, rows: list[dict]):
    if not rows:
        raise ValueError(f"Geen regels voor {path.name}.")
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--beeldmap", type=Path, required=True)
    parser.add_argument("--ahn-map", type=Path, required=True)
    parser.add_argument("--plots", type=Path, required=True)
    parser.add_argument("--uitvoer", type=Path, required=True)
    parser.add_argument("--per-klasse", type=int, default=40_000)
    parser.add_argument("--kenmerken", choices=("raw", "genormaliseerd"), default="genormaliseerd")
    args = parser.parse_args()

    reference = {2016: 3, 2020: 4, 2023: 5}
    all_years = (2016, 2020, 2022, 2023, 2024)
    data = {}
    profile = None
    for year in all_years:
        rgb, rgb_profile, transform, crs = read_three_band(args.beeldmap / f"rgb_{year}_2m.tif")
        cir, cir_profile, cir_transform, cir_crs = read_three_band(args.beeldmap / f"cir_{year}_2m.tif")
        if (rgb_profile["width"], rgb_profile["height"], transform, crs) != (
            cir_profile["width"], cir_profile["height"], cir_transform, cir_crs
        ):
            raise ValueError(f"RGB en CIR liggen niet op hetzelfde rooster in {year}.")
        if profile is None:
            profile = dict(rgb_profile)
            profile["transform"] = transform
        elif (profile["width"], profile["height"], profile["transform"], profile["crs"]) != (
            rgb_profile["width"], rgb_profile["height"], transform, crs
        ):
            raise ValueError(f"Beeldjaar {year} wijkt af van het gedeelde rooster.")
        features, feature_names = spectral_features(rgb, cir, args.kenmerken)
        data[year] = {"features": features}

    plot_ids, selected_plot_ids = plot_id_raster(args.plots, profile)
    for year, ahn_cycle in reference.items():
        height = read_height(
            args.ahn_map / f"ahn{ahn_cycle}_dsm_2m.tif",
            args.ahn_map / f"ahn{ahn_cycle}_dtm_2m.tif", profile,
        )
        data[year]["labels"] = height_classes(height)

    args.uitvoer.mkdir(parents=True, exist_ok=False)
    validation_rows = []
    class_rows = []
    folds = [
        ("2020_naar_2023", (2020,), 2023),
        ("2023_naar_2020", (2023,), 2020),
        ("2016_en_2020_naar_2023", (2016, 2020), 2023),
        ("2020_en_2023_naar_2016", (2020, 2023), 2016),
    ]
    for fold_index, (name, train_years, test_year) in enumerate(folds):
        train_parts = [balanced_sample(
            data[year]["features"], data[year]["labels"], plot_ids,
            args.per_klasse, 20261012 + year,
        ) for year in train_years]
        x_train = np.concatenate([part[0] for part in train_parts])
        y_train = np.concatenate([part[1] for part in train_parts])
        x_test, y_test = balanced_sample(
            data[test_year]["features"], data[test_year]["labels"], plot_ids,
            args.per_klasse, 20261100 + test_year,
        )
        model = build_forest(20261012 + fold_index)
        model.fit(x_train, y_train)
        predicted = model.predict(x_test)
        metrics, details = classification_metrics(y_test, predicted)
        validation_rows.append({
            "toets": name, "train_jaren": "+".join(map(str, train_years)),
            "test_jaar": test_year, **metrics,
            "poort_macro_f1_0_60": metrics["macro_f1"] >= 0.60,
        })
        for row in details:
            class_rows.append({"toets": name, **row})

    train_parts = [balanced_sample(
        data[year]["features"], data[year]["labels"], plot_ids,
        args.per_klasse, 20261200 + year,
    ) for year in reference]
    model = build_forest(20261231)
    model.fit(
        np.concatenate([part[0] for part in train_parts]),
        np.concatenate([part[1] for part in train_parts]),
    )
    plot_share_rows = []
    for year in all_years:
        valid = (plot_ids > 0) & np.all(np.isfinite(data[year]["features"]), axis=-1)
        predicted = predict_in_chunks(model, data[year]["features"], valid)
        rows = aggregate_plot_shares(predicted, plot_ids, selected_plot_ids)
        for row in rows:
            plot_share_rows.append({"jaar": year, **row})

    exact = [row for row in validation_rows if row["toets"] in {"2020_naar_2023", "2023_naar_2020"}]
    usable = all(row["macro_f1"] >= 0.60 for row in exact)
    manifest = {
        "status": "bruikbaar_voor_jaarlijkse_uitbreiding" if usable else "niet_bruikbaar_voor_jaarlijkse_uitbreiding",
        "poort": "macro-F1 >= 0,60 in beide onafhankelijke 2020/2023-overdrachtstoetsen",
        "n_bronplots": 55, "n_analyseplots": 53,
        "uitgesloten_plot_ids": sorted(EXCLUDED_PLOT_IDS),
        "beeldjaren": list(all_years), "ahn_referenties": reference,
        "klassen": list(CLASS_NAMES), "kenmerkenset": args.kenmerken,
        "features": feature_names,
        "steekproef_per_klasse_per_jaar": args.per_klasse,
        "random_forest": {
            "n_estimators": 160, "max_depth": 18, "min_samples_leaf": 4,
            "class_weight": "balanced_subsample", "n_jobs": 2,
        },
        "software": {
            "numpy": np.__version__, "rasterio": rasterio.__version__,
            "scikit_learn": sklearn.__version__,
        },
        "opmerking": "Open is de AHN-hoogteklasse onder 0,5 meter; water en kaal zand zijn hierin nog niet gevalideerd onderscheiden.",
        "bronbestanden": {
            path.name: sha256(path)
            for path in sorted(args.beeldmap.glob("*_2m.tif"))
        },
    }
    write_csv(args.uitvoer / "luchtfoto_validatie.csv", validation_rows)
    write_csv(args.uitvoer / "luchtfoto_validatie_per_klasse.csv", class_rows)
    write_csv(args.uitvoer / "luchtfoto_plot_aandelen.csv", plot_share_rows)
    (args.uitvoer / "luchtfoto_manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    main()
