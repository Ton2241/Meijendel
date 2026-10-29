#!/usr/bin/env python3
"""Vergelijk de ruimtelijke PQ-steekproef met landbedekking per vogelplot."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
from datetime import datetime, timezone

import numpy as np
import pandas as pd
import rasterio


OUTPUT_FILES = (
    "pq_representativiteit_laatste_klassen.csv",
    "pq_representativiteit_laatste_punten.csv",
    "pq_representativiteit_laatste_plots.csv",
    "pq_representativiteit_laatste_deelgebieden.csv",
    "pq_representativiteit_laatste_samenvatting.csv",
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def select_snapshot_opnamen(
    opnamen: pd.DataFrame, kaartjaar: int, max_afstand: int = 5
) -> pd.DataFrame:
    """Kies per PQ de dichtstbijzijnde opname; bij gelijkstand de recentste."""
    required = {"opname_id", "pq_nummer", "jaar", "plot_id", "x_rd", "y_rd"}
    missing = required.difference(opnamen.columns)
    if missing:
        raise ValueError(f"PQ-opnamen missen velden: {', '.join(sorted(missing))}")
    selected = opnamen.copy()
    selected["afstand_kaartjaar"] = (selected["jaar"] - kaartjaar).abs()
    selected = selected[selected["afstand_kaartjaar"] <= max_afstand].copy()
    selected = selected.sort_values(
        ["pq_nummer", "afstand_kaartjaar", "jaar", "opname_id"],
        ascending=[True, True, False, False],
    )
    selected = selected.drop_duplicates("pq_nummer", keep="first")
    selected["kaartjaar"] = int(kaartjaar)
    return selected.sort_values(["plot_id", "pq_nummer"]).reset_index(drop=True)


def _load_landcover_module(script_dir: Path):
    path = script_dir / "schmidt_tauscher_landbedekking.py"
    spec = importlib.util.spec_from_file_location("schmidt_tauscher_landbedekking", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sample_landcover(
    selected: pd.DataFrame, raster_path: Path, kaartjaar: int
) -> pd.DataFrame:
    """Lees op iedere PQ-coordinaat de geclassificeerde rasterwaarde."""
    result = selected.copy()
    codes = _load_landcover_module(Path(__file__).parent).class_codes(kaartjaar)
    with rasterio.open(raster_path) as dataset:
        if dataset.crs is None or dataset.crs.to_epsg() != 28992:
            raise ValueError(f"Raster {raster_path.name} heeft niet EPSG:28992.")
        samples = dataset.sample(zip(result.x_rd, result.y_rd), masked=True)
        values = []
        for sample in samples:
            value = sample[0]
            if np.ma.is_masked(value) or not np.isfinite(value) or not np.isclose(value, round(float(value))):
                values.append(pd.NA)
            else:
                values.append(int(round(float(value))))
    result["rastercode"] = pd.array(values, dtype="Int64")
    result["klasse"] = result["rastercode"].map(codes)
    result["raster_status"] = np.where(
        result["klasse"].notna(), "gekoppeld", "geen_bruikbare_rasterklasse"
    )
    return result


def build_representation_weights(
    oppervlak: pd.DataFrame, punten: pd.DataFrame
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Bereken representatieverhouding en oppervlaktegewicht per PQ."""
    area_required = {"plot_id", "jaar", "klasse", "aandeel"}
    point_required = {"plot_id", "kaartjaar", "pq_nummer", "klasse"}
    if missing := area_required.difference(oppervlak.columns):
        raise ValueError(f"Oppervlaktetabel mist velden: {', '.join(sorted(missing))}")
    if missing := point_required.difference(punten.columns):
        raise ValueError(f"PQ-puntentabel mist velden: {', '.join(sorted(missing))}")
    area = oppervlak.rename(columns={"jaar": "kaartjaar"}).copy()
    if area.duplicated(["plot_id", "kaartjaar", "klasse"]).any():
        raise ValueError("Oppervlaktetabel bevat dubbele plot-jaar-klasseregels.")
    if not np.allclose(
        area.groupby(["plot_id", "kaartjaar"])["aandeel"].sum().to_numpy(),
        1.0,
        atol=1e-6,
    ):
        raise ValueError("Landbedekkingsaandelen tellen niet per plot en jaar op tot een.")

    usable = punten[punten["klasse"].notna()].copy()
    counts = (
        usable.groupby(["plot_id", "kaartjaar", "klasse"], as_index=False)
        .agg(n_pq=("pq_nummer", "nunique"))
    )
    totals = (
        usable.groupby(["plot_id", "kaartjaar"], as_index=False)
        .agg(n_pq_totaal=("pq_nummer", "nunique"))
    )
    classes = area.merge(counts, how="left", on=["plot_id", "kaartjaar", "klasse"])
    classes = classes.merge(totals, how="left", on=["plot_id", "kaartjaar"])
    classes[["n_pq", "n_pq_totaal"]] = classes[["n_pq", "n_pq_totaal"]].fillna(0).astype(int)
    classes["pq_aandeel"] = np.where(
        classes["n_pq_totaal"] > 0,
        classes["n_pq"] / classes["n_pq_totaal"],
        np.nan,
    )
    classes["representatie_ratio"] = np.where(
        (classes["n_pq"] > 0) & (classes["aandeel"] > 0),
        classes["pq_aandeel"] / classes["aandeel"],
        np.nan,
    )
    classes["bemonsterd"] = classes["n_pq"] > 0

    plots = (
        classes.groupby(["plot_id", "kaartjaar"], as_index=False)
        .agg(
            n_pq=("n_pq_totaal", "max"),
            oppervlakteaandeel_bemonsterde_klassen=(
                "aandeel",
                lambda values: float(
                    values[classes.loc[values.index, "bemonsterd"]].sum()
                ),
            ),
            n_klassen=("klasse", "size"),
            n_bemonsterde_klassen=("bemonsterd", "sum"),
        )
    )

    covered = classes[classes["bemonsterd"]].copy()
    covered["klassegewicht_per_pq"] = covered["aandeel"] / covered["n_pq"]
    point_weights = usable.merge(
        covered[
            ["plot_id", "kaartjaar", "klasse", "klassegewicht_per_pq"]
        ],
        on=["plot_id", "kaartjaar", "klasse"],
        how="left",
        validate="many_to_one",
    )
    normalizer = point_weights.groupby(["plot_id", "kaartjaar"])[
        "klassegewicht_per_pq"
    ].transform("sum")
    point_weights["gewicht"] = point_weights["klassegewicht_per_pq"] / normalizer
    effective = (
        point_weights.assign(gewicht_kwadraat=point_weights["gewicht"] ** 2)
        .groupby(["plot_id", "kaartjaar"], as_index=False)
        .agg(gewicht_kwadraat=("gewicht_kwadraat", "sum"))
    )
    effective["effectieve_steekproefomvang"] = 1 / effective["gewicht_kwadraat"]
    plots = plots.merge(
        effective.drop(columns="gewicht_kwadraat"),
        on=["plot_id", "kaartjaar"],
        how="left",
    )
    point_output = punten.merge(
        point_weights[
            [
                "plot_id",
                "kaartjaar",
                "pq_nummer",
                "klassegewicht_per_pq",
                "gewicht",
            ]
        ],
        on=["plot_id", "kaartjaar", "pq_nummer"],
        how="left",
        validate="one_to_one",
    )
    return (
        classes.sort_values(["kaartjaar", "plot_id", "klasse"]).reset_index(drop=True),
        point_output.sort_values(["kaartjaar", "plot_id", "pq_nummer"]).reset_index(drop=True),
        plots.sort_values(["kaartjaar", "plot_id"]).reset_index(drop=True),
    )


def summarize_representation(
    classes: pd.DataFrame, zones: pd.DataFrame
) -> pd.DataFrame:
    """Vat oppervlakte- en PQ-aandelen samen voor alle plots en per deelgebied."""
    required = {
        "plot_id", "kaartjaar", "klasse", "klasse_ha", "plot_oppervlakte_ha", "n_pq"
    }
    if missing := required.difference(classes.columns):
        raise ValueError(f"Klassetabel mist samenvattingsvelden: {', '.join(sorted(missing))}")
    zone_required = {"plot_id", "gebied_code", "gebied_naam"}
    if missing := zone_required.difference(zones.columns):
        raise ValueError(f"Deelgebiedtabel mist velden: {', '.join(sorted(missing))}")
    if zones.duplicated("plot_id").any():
        raise ValueError("Een plot is aan meer dan een Meijendel-deelgebied gekoppeld.")
    joined = classes.merge(zones, on="plot_id", how="left", validate="many_to_one")
    joined["gebied_code"] = joined["gebied_code"].fillna("niet_ingedeeld")
    joined["gebied_naam"] = joined["gebied_naam"].fillna("Niet ingedeeld")

    def aggregate(data: pd.DataFrame, level: str, code: str, name: str) -> pd.DataFrame:
        plot_counts = (
            data.groupby(["kaartjaar", "plot_id"], as_index=False)
            .agg(n_pq_plot=("n_pq", "sum"))
            .groupby("kaartjaar", as_index=False)
            .agg(
                plots=("plot_id", "size"),
                plots_met_pq=("n_pq_plot", lambda values: int((values > 0).sum())),
            )
        )
        totals = (
            data.groupby("kaartjaar", as_index=False)
            .agg(oppervlakte_ha=("klasse_ha", "sum"), n_pq=("n_pq", "sum"))
            .rename(columns={"oppervlakte_ha": "oppervlakte_totaal_ha", "n_pq": "n_pq_totaal"})
        )
        out = data.groupby(["kaartjaar", "klasse"], as_index=False).agg(
            oppervlakte_ha=("klasse_ha", "sum"), n_pq=("n_pq", "sum")
        )
        out = out.merge(totals, on="kaartjaar", how="left", validate="many_to_one")
        out = out.merge(plot_counts, on="kaartjaar", how="left", validate="many_to_one")
        out["oppervlakte_aandeel"] = out["oppervlakte_ha"] / out["oppervlakte_totaal_ha"]
        out["pq_aandeel"] = np.where(
            out["n_pq_totaal"] > 0, out["n_pq"] / out["n_pq_totaal"], np.nan
        )
        out["representatie_ratio"] = np.where(
            (out["n_pq"] > 0) & (out["oppervlakte_aandeel"] > 0),
            out["pq_aandeel"] / out["oppervlakte_aandeel"],
            np.nan,
        )
        out.insert(0, "gebied_naam", name)
        out.insert(0, "gebied_code", code)
        out.insert(0, "niveau", level)
        return out

    rows = [aggregate(joined, "geheel", "meijendel_25_plots", "Alle 25 kaartplots")]
    for (code, name), subset in joined.groupby(["gebied_code", "gebied_naam"], sort=True):
        rows.append(aggregate(subset, "deelgebied", str(code), str(name)))
    return pd.concat(rows, ignore_index=True).sort_values(
        ["niveau", "gebied_code", "kaartjaar", "klasse"]
    ).reset_index(drop=True)


def read_area_metrics(path: Path) -> pd.DataFrame:
    raw = pd.read_csv(path)
    if {"plot_id", "kavel_nummer"}.issubset(raw.columns):
        expected = {"M17": 999995, "M17a": 3513}
        relevant = raw[raw["kavel_nummer"].isin(expected)].copy()
        wrong = relevant[
            relevant.apply(
                lambda row: int(row["plot_id"]) != expected[row["kavel_nummer"]],
                axis=1,
            )
        ]
        if not wrong.empty:
            pairs = ", ".join(
                f"{row.kavel_nummer}={int(row.plot_id)}"
                for row in wrong[["kavel_nummer", "plot_id"]]
                .drop_duplicates()
                .itertuples(index=False)
            )
            raise ValueError(f"M17/M17a-normalisatie is ongeldig: {pairs}.")
    classes = ("struik", "bos", "boomgroep", "laag", "riet", "zand", "water")
    wide_fields = {"plot_id", "jaar", *(f"{name}_aandeel" for name in classes)}
    if wide_fields.issubset(raw.columns):
        shares = raw.melt(
            id_vars=["plot_id", "jaar"],
            value_vars=[f"{name}_aandeel" for name in classes],
            var_name="klasse",
            value_name="aandeel",
        ).assign(klasse=lambda data: data["klasse"].str.removesuffix("_aandeel"))
        if "geclassificeerd_ha" in raw.columns and all(
            f"{name}_ha" in raw.columns for name in classes
        ):
            hectares = raw.melt(
                id_vars=["plot_id", "jaar", "geclassificeerd_ha"],
                value_vars=[f"{name}_ha" for name in classes],
                var_name="klasse",
                value_name="klasse_ha",
            ).assign(klasse=lambda data: data["klasse"].str.removesuffix("_ha"))
            hectares = hectares.rename(columns={"geclassificeerd_ha": "plot_oppervlakte_ha"})
            return shares.merge(
                hectares, on=["plot_id", "jaar", "klasse"], validate="one_to_one"
            )
        shares["plot_oppervlakte_ha"] = 1.0
        shares["klasse_ha"] = shares["aandeel"]
        return shares
    required = {"plot_id_bron", "jaar", "klasse", "aandeel"}
    if missing := required.difference(raw.columns):
        raise ValueError(f"Landbedekking mist velden: {', '.join(sorted(missing))}")
    return raw.rename(columns={"plot_id_bron": "plot_id"})[
        ["plot_id", "jaar", "klasse", "aandeel"]
    ]


def write_outputs(
    output_dir: Path,
    classes: pd.DataFrame,
    points: pd.DataFrame,
    plots: pd.DataFrame,
    strata: pd.DataFrame,
    metadata: dict,
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    run_id = metadata["run_id"]
    run_dir = output_dir / "runs" / run_id
    run_dir.mkdir(parents=True, exist_ok=False)
    classes.to_csv(run_dir / OUTPUT_FILES[0], index=False)
    points.to_csv(run_dir / OUTPUT_FILES[1], index=False)
    plots.to_csv(run_dir / OUTPUT_FILES[2], index=False)
    strata.to_csv(run_dir / OUTPUT_FILES[3], index=False)
    summary = (
        plots.groupby("kaartjaar", as_index=False)
        .agg(
            plots=("plot_id", "size"),
            plots_met_pq=("n_pq", lambda values: int((values > 0).sum())),
            pq=("n_pq", "sum"),
            mediaan_oppervlakteaandeel_bemonsterde_klassen=(
                "oppervlakteaandeel_bemonsterde_klassen",
                "median",
            ),
            gemiddelde_oppervlakteaandeel_bemonsterde_klassen=(
                "oppervlakteaandeel_bemonsterde_klassen",
                "mean",
            ),
        )
    )
    summary.to_csv(run_dir / OUTPUT_FILES[4], index=False)
    metadata["uitvoerbestanden_sha256"] = {
        name: sha256_file(run_dir / name) for name in OUTPUT_FILES
    }
    run_manifest = run_dir / "pq_representativiteit_laatste_manifest.json"
    run_manifest.write_text(
        json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    for name in OUTPUT_FILES:
        temporary = output_dir / f".{name}.{run_id}.tmp"
        shutil.copyfile(run_dir / name, temporary)
        os.replace(temporary, output_dir / name)
    manifest_name = "pq_representativiteit_laatste_manifest.json"
    temporary_manifest = output_dir / f".{manifest_name}.{run_id}.tmp"
    shutil.copyfile(run_manifest, temporary_manifest)
    os.replace(temporary_manifest, output_dir / manifest_name)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--opnamen", type=Path, required=True)
    parser.add_argument("--klassemetrics", type=Path, required=True)
    parser.add_argument("--raster-2001", type=Path, required=True)
    parser.add_argument("--raster-2022", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--deelgebieden", type=Path, required=True)
    parser.add_argument("--max-afstand", type=int, default=5)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--git-commit", required=True)
    parser.add_argument("--git-werkboomstatus", required=True)
    parser.add_argument("--mysql-versie", required=True)
    args = parser.parse_args()

    opnamen = pd.read_csv(args.opnamen, sep="\t")
    area = read_area_metrics(args.klassemetrics)
    zones = pd.read_csv(args.deelgebieden, sep="\t")
    map_plots = set(area["plot_id"].unique())
    opnamen = opnamen[opnamen["plot_id"].isin(map_plots)].copy()
    snapshots = []
    for year, raster in ((2001, args.raster_2001), (2022, args.raster_2022)):
        selected = select_snapshot_opnamen(opnamen, year, args.max_afstand)
        snapshots.append(sample_landcover(selected, raster, year))
    sampled = pd.concat(snapshots, ignore_index=True)
    classes, points, plots = build_representation_weights(area, sampled)
    strata = summarize_representation(classes, zones)
    metadata = {
        "run_id": args.run_id,
        "uitgevoerd_utc": datetime.now(timezone.utc).isoformat(),
        "git_commit_bij_start": args.git_commit,
        "git_werkboomstatus_bij_start": args.git_werkboomstatus,
        "mysql_clientversie": args.mysql_versie,
        "doel": "PQ-representativiteit binnen 25 kaartplots met landbedekking",
        "kaartjaren": [2001, 2022],
        "maximale_afstand_pq_opname_tot_kaartjaar": args.max_afstand,
        "plots": int(area["plot_id"].nunique()),
        "pq_punten_geselecteerd": {
            str(year): int((sampled["kaartjaar"] == year).sum()) for year in (2001, 2022)
        },
        "pq_punten_zonder_bruikbare_rasterklasse": {
            str(year): int(
                ((sampled["kaartjaar"] == year) & sampled["klasse"].isna()).sum()
            )
            for year in (2001, 2022)
        },
        "weging": "klasseoppervlakte gedeeld door aantal PQs in de klasse; genormaliseerd binnen bemonsterde klassen per plot en kaartjaar",
        "beperking": "Een klasse zonder PQ blijft onbedekt; de weging vult geen vegetatiewaarde in.",
        "bronbestanden_sha256": {
            "pq_opnamen_extract": sha256_file(args.opnamen),
            "deelgebieden_extract": sha256_file(args.deelgebieden),
            "landbedekking_klassemetrics": sha256_file(args.klassemetrics),
            "raster_2001": sha256_file(args.raster_2001),
            "raster_2022": sha256_file(args.raster_2022),
            "analysescript": sha256_file(Path(__file__)),
        },
    }
    write_outputs(args.output_dir, classes, points, plots, strata, metadata)


if __name__ == "__main__":
    main()
