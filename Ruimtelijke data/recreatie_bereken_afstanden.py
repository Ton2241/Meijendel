#!/usr/bin/env python3

import argparse
import csv
import json
import subprocess
import tempfile
from pathlib import Path

import pandas as pd
from shapely.geometry import shape
from shapely.ops import unary_union


def parse_args():
    parser = argparse.ArgumentParser(
        description="Bereken recreatie-afstanden per plot zonder geopandas."
    )
    parser.add_argument("--plots", required=True, help="Pad naar plotlaag")
    parser.add_argument("--plots-layer", help="Optionele laagnaam van plotlaag")
    parser.add_argument("--plot-id-field", default="plotid", help="Veldnaam voor plot_id")
    parser.add_argument("--jaar", required=True, type=int, help="Jaar voor output")
    parser.add_argument("--paden", required=True, help="Pad naar BGT-padlaag")
    parser.add_argument("--paden-layer", help="Optionele laagnaam van padlaag")
    parser.add_argument("--paden-lijnen", help="Pad naar lijnlaag voor padlengte per hectare")
    parser.add_argument("--paden-lijnen-layer", help="Optionele laagnaam van padlijnlaag")
    parser.add_argument("--parkeerplaatsen", required=True, help="Pad naar OSM-parkeerlaag")
    parser.add_argument("--parkeer-layer", help="Optionele laagnaam van parkeerlaag")
    parser.add_argument("--hoofdtoegangen", required=True, help="CSV met hoofdtoegangen in RD")
    parser.add_argument("--output", required=True, help="Pad naar output CSV")
    return parser.parse_args()


def export_geojson(src_path, dst_path, layer=None):
    cmd = ["ogr2ogr", "-f", "GeoJSON", dst_path, src_path]
    if layer:
        cmd.append(layer)
    cmd.extend(["-t_srs", "EPSG:28992"])
    subprocess.run(cmd, check=True)


def load_geojson_features(path):
    data = json.loads(Path(path).read_text())
    return data.get("features", [])


def load_plots(path, layer, plot_id_field):
    with tempfile.TemporaryDirectory() as tmpdir:
        geojson_path = str(Path(tmpdir) / "plots.geojson")
        export_geojson(path, geojson_path, layer=layer)
        features = load_geojson_features(geojson_path)

    plots = []
    for feat in features:
        props = feat.get("properties", {})
        geom = feat.get("geometry")
        if not geom:
            continue
        plot_id = props.get(plot_id_field)
        if plot_id is None:
            continue
        plots.append({"plot_id": int(plot_id), "geometry": shape(geom)})
    return plots


def load_vector_geometries(path, layer=None):
    with tempfile.TemporaryDirectory() as tmpdir:
        geojson_path = str(Path(tmpdir) / "layer.geojson")
        export_geojson(path, geojson_path, layer=layer)
        features = load_geojson_features(geojson_path)

    geoms = []
    for feat in features:
        geom = feat.get("geometry")
        if geom:
            geoms.append(shape(geom))
    return geoms


def load_hoofdtoegangen(path):
    df = pd.read_csv(path)
    required = {"x_rd", "y_rd"}
    if not required.issubset(df.columns):
        raise ValueError("Bestand met hoofdtoegangen moet x_rd en y_rd bevatten.")
    points = []
    for row in df.itertuples():
        if pd.isna(row.x_rd) or pd.isna(row.y_rd):
            continue
        points.append(shape({"type": "Point", "coordinates": [float(row.x_rd), float(row.y_rd)]}))
    return points


def distance_rows(plots, union_geom, jaar, bron, variabele):
    rows = []
    for plot in plots:
        afstand = plot["geometry"].distance(union_geom)
        rows.append(
            {
                "plot_id": plot["plot_id"],
                "jaar": jaar,
                "bron": bron,
                "variabele": variabele,
                "waarde": round(float(afstand), 3),
            }
        )
    return rows


def line_length_rows(plots, line_geoms, jaar, bron):
    rows = []
    for plot in plots:
        plot_geom = plot["geometry"]
        total_length = 0.0
        for geom in line_geoms:
            inter = plot_geom.intersection(geom)
            if not inter.is_empty:
                total_length += inter.length
        opp_ha = plot_geom.area / 10000.0
        waarde = total_length / opp_ha if opp_ha > 0 else 0.0
        rows.append(
            {
                "plot_id": plot["plot_id"],
                "jaar": jaar,
                "bron": bron,
                "variabele": "padlengte_m_per_ha",
                "waarde": round(float(waarde), 3),
            }
        )
    return rows


def main():
    args = parse_args()

    plots = load_plots(args.plots, args.plots_layer, args.plot_id_field)
    if not plots:
        raise ValueError("Geen plotgeometrie gevonden.")

    pad_geoms = load_vector_geometries(args.paden, layer=args.paden_layer)
    pad_line_geoms = load_vector_geometries(args.paden_lijnen, layer=args.paden_lijnen_layer) if args.paden_lijnen else []
    parkeer_geoms = load_vector_geometries(args.parkeerplaatsen, layer=args.parkeer_layer)
    hoofd_geoms = load_hoofdtoegangen(args.hoofdtoegangen)

    if not pad_geoms:
        raise ValueError("Geen padgeometrie gevonden.")
    if not parkeer_geoms:
        raise ValueError("Geen parkeergeometrie gevonden.")
    if not hoofd_geoms:
        raise ValueError("Geen hoofdtoegangspunten met coordinaten gevonden.")

    pad_union = unary_union(pad_geoms)
    parkeer_union = unary_union(parkeer_geoms)
    hoofd_union = unary_union(hoofd_geoms)

    rows = []
    rows.extend(distance_rows(plots, pad_union, args.jaar, "BGT", "afstand_pad_m"))
    if pad_line_geoms:
        rows.extend(line_length_rows(plots, pad_line_geoms, args.jaar, "OSM"))
    rows.extend(distance_rows(plots, parkeer_union, args.jaar, "OSM", "afstand_parkeerplaats_m"))
    rows.extend(distance_rows(plots, hoofd_union, args.jaar, "HANDMATIG", "afstand_hoofdtoegang_m"))

    rows.sort(key=lambda r: (r["jaar"], r["plot_id"], r["variabele"], r["bron"]))

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["plot_id", "jaar", "bron", "variabele", "waarde"])
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
