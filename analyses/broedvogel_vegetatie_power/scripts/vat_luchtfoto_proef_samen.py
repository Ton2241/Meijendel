#!/usr/bin/env python3
"""Maak een compacte, herleidbare samenvatting van beide luchtfotoproeven."""

from __future__ import annotations

import argparse
import csv
import json
import statistics
from collections import defaultdict
from pathlib import Path


def read_csv(path):
    with Path(path).open(encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def pearson(pairs):
    x = [a for a, _ in pairs]
    y = [b for _, b in pairs]
    mean_x, mean_y = statistics.mean(x), statistics.mean(y)
    numerator = sum((a - mean_x) * (b - mean_y) for a, b in pairs)
    denominator = (
        sum((a - mean_x) ** 2 for a in x) * sum((b - mean_y) ** 2 for b in y)
    ) ** 0.5
    return numerator / denominator if denominator else float("nan")


def summarize_variant(name, directory, landcover):
    validation = read_csv(directory / "luchtfoto_validatie.csv")
    shares = read_csv(directory / "luchtfoto_plot_aandelen.csv")
    rows = []
    for item in validation:
        rows.append({
            "kenmerkenset": name, "uitkomst": "overdracht",
            "vergelijking": item["toets"], "n": item["n"],
            "maat": "macro_f1", "waarde": item["macro_f1"],
            "poort": item["poort_macro_f1_0_60"],
        })

    by_plot = defaultdict(dict)
    for item in shares:
        by_plot[(int(item["plot_id"]), item["klasse"])][int(item["jaar"])] = float(item["aandeel"])
    for first, second in ((2020, 2022), (2022, 2023), (2023, 2024)):
        for land_class in ("open", "laag", "struweel", "boom"):
            changes = [
                abs(values[second] - values[first])
                for (plot_id, current_class), values in by_plot.items()
                if current_class == land_class and first in values and second in values
            ]
            rows.append({
                "kenmerkenset": name, "uitkomst": "jaarstabiliteit",
                "vergelijking": f"{first}-{second}:{land_class}", "n": len(changes),
                "maat": "mediaan_absolute_verandering_aandeel",
                "waarde": statistics.median(changes), "poort": "niet_vastgesteld",
            })

    predicted_2022 = defaultdict(dict)
    for item in shares:
        if int(item["jaar"]) == 2022:
            predicted_2022[int(item["plot_id"])][item["klasse"]] = float(item["aandeel"])
    pairs = []
    for item in landcover:
        if int(item["jaar"]) != 2022:
            continue
        plot_id = int(item["plot_id"])
        if plot_id not in predicted_2022:
            continue
        predicted_woody = predicted_2022[plot_id]["struweel"] + predicted_2022[plot_id]["boom"]
        pairs.append((float(item["houtig_aandeel"]), predicted_woody))
    rows.extend((
        {
            "kenmerkenset": name, "uitkomst": "onafhankelijke_plotvergelijking",
            "vergelijking": "houtig_aandeel_2022", "n": len(pairs), "maat": "mae",
            "waarde": statistics.mean(abs(a - b) for a, b in pairs), "poort": "beschrijvend",
        },
        {
            "kenmerkenset": name, "uitkomst": "onafhankelijke_plotvergelijking",
            "vergelijking": "houtig_aandeel_2022", "n": len(pairs), "maat": "bias_voorspeld_min_bron",
            "waarde": statistics.mean(b - a for a, b in pairs), "poort": "beschrijvend",
        },
        {
            "kenmerkenset": name, "uitkomst": "onafhankelijke_plotvergelijking",
            "vergelijking": "houtig_aandeel_2022", "n": len(pairs), "maat": "pearson_r",
            "waarde": pearson(pairs), "poort": "beschrijvend",
        },
    ))
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", type=Path, required=True)
    parser.add_argument("--genormaliseerd", type=Path, required=True)
    parser.add_argument("--landbedekking", type=Path, required=True)
    parser.add_argument("--uitvoer", type=Path, required=True)
    args = parser.parse_args()
    landcover = read_csv(args.landbedekking)
    rows = summarize_variant("raw", args.raw, landcover)
    rows += summarize_variant("genormaliseerd", args.genormaliseerd, landcover)
    args.uitvoer.parent.mkdir(parents=True, exist_ok=True)
    with args.uitvoer.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    status = {
        "run_id": args.raw.parent.name,
        "status": "niet_bruikbaar_voor_jaarlijkse_uitbreiding",
        "reden": "Geen van beide kenmerkensets haalt macro-F1 0,60 in beide onafhankelijke overdrachtstoetsen 2020-2023.",
        "water_en_zand": "niet_afzonderlijk_gevalideerd; pixelreferenties ontbreken",
        "gegevens": {
            "bronplots": 55, "analyseplots": 53,
            "uitgesloten_plot_ids": [3503, 3514],
            "beeldjaren": [2016, 2020, 2022, 2023, 2024],
            "ahn_referentie": {"2016": "AHN3/2014", "2020": "AHN4/2020", "2023": "AHN5/2023"},
        },
        "validatiepoort": "macro-F1 >= 0,60 in beide overdrachtstoetsen 2020 naar 2023 en 2023 naar 2020",
        "model": {
            "algoritme": "RandomForestClassifier", "n_estimators": 160,
            "max_depth": 18, "min_samples_leaf": 4,
            "class_weight": "balanced_subsample", "n_jobs": 2,
            "steekproef_per_klasse_per_toets": 40000,
        },
        "software_uitgevoerde_run": {
            "python": "3.9.6", "numpy": "2.0.2", "rasterio": "1.4.3",
            "geopandas": "1.0.1", "scipy": "1.13.1", "scikit_learn": "1.6.1",
        },
    }
    args.uitvoer.with_suffix(".json").write_text(
        json.dumps(status, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
