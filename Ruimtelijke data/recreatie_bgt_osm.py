#!/usr/bin/env python3

import argparse
from pathlib import Path

import geopandas as gpd
import pandas as pd


def parse_args():
    parser = argparse.ArgumentParser(
        description="Bereken recreatievariabelen per plot uit BGT/OSM-lagen."
    )
    parser.add_argument("--plots", required=True, help="Pad naar plot shapefile of geopackage")
    parser.add_argument("--plot-id-field", default="plotid", help="Veldnaam met plot-id")
    parser.add_argument("--jaar", required=True, type=int, help="Jaar voor output")
    parser.add_argument("--output", required=True, help="Pad naar output CSV voor plot_jaar_infra")

    parser.add_argument("--paden", help="Pad naar lijnenlaag met paden/wegen")
    parser.add_argument("--paden-layer", help="Optionele laagnaam voor padenbestand")
    parser.add_argument("--paden-bron", default="BGT", help="Broncode voor padvariabelen")

    parser.add_argument("--parkeerplaatsen", help="Pad naar punten- of polygonenlaag met parkeerplaatsen")
    parser.add_argument("--parkeer-layer", help="Optionele laagnaam voor parkeerbestand")
    parser.add_argument("--parkeer-bron", default="OSM", help="Broncode voor parkeerafstand")

    parser.add_argument("--hoofdtoegangen", help="Pad naar puntenlaag of csv/gpkg met hoofdtoegangen")
    parser.add_argument("--hoofdtoegang-layer", help="Optionele laagnaam voor hoofdtoegangen")
    parser.add_argument("--hoofdtoegang-bron", default="HANDMATIG", help="Broncode voor hoofdtoegangafstand")
    return parser.parse_args()


def read_vector(path, layer=None):
    path_obj = Path(path)
    if path_obj.suffix.lower() == ".csv":
        df = pd.read_csv(path_obj)
        required = {"x_rd", "y_rd"}
        if not required.issubset(df.columns):
            raise ValueError("CSV met punten moet kolommen x_rd en y_rd bevatten.")
        return gpd.GeoDataFrame(
            df.copy(),
            geometry=gpd.points_from_xy(df["x_rd"], df["y_rd"]),
            crs="EPSG:28992",
        )
    if layer:
        return gpd.read_file(path, layer=layer)
    return gpd.read_file(path)


def load_plots(path, plot_id_field):
    plots = read_vector(path)
    plots = plots[[plot_id_field, "geometry"]].copy()
    plots["plot_id"] = plots[plot_id_field].astype(int)
    plots = plots[["plot_id", "geometry"]]
    if plots.crs is None:
        raise ValueError("Plotlaag heeft geen CRS.")
    return plots


def to_rd(crs_frame, target="EPSG:28992"):
    if crs_frame.crs is None:
        raise ValueError("Laag heeft geen CRS.")
    if str(crs_frame.crs) != target:
        return crs_frame.to_crs(target)
    return crs_frame


def geometry_union(geoseries):
    if hasattr(geoseries, "union_all"):
        return geoseries.union_all()
    return geoseries.unary_union


def line_metrics(plots, lines, jaar, bron):
    rows = []
    if lines is None or lines.empty:
        return rows

    line_union = geometry_union(lines.geometry)
    clipped = gpd.overlay(plots, lines[["geometry"]], how="intersection", keep_geom_type=True)

    if clipped.empty:
        lengths = pd.DataFrame(columns=["plot_id", "lengte_m"])
    else:
        clipped["lengte_m"] = clipped.geometry.length
        lengths = clipped.groupby("plot_id", as_index=False)["lengte_m"].sum()

    length_map = dict(zip(lengths["plot_id"], lengths["lengte_m"]))

    for plot in plots.itertuples():
        opp_ha = plot.geometry.area / 10000.0
        afstand = plot.geometry.distance(line_union)
        lengte_m = float(length_map.get(plot.plot_id, 0.0))
        padlengte_per_ha = lengte_m / opp_ha if opp_ha > 0 else None
        rows.append(
            {
                "plot_id": plot.plot_id,
                "jaar": jaar,
                "bron": bron,
                "variabele": "afstand_pad_m",
                "waarde": round(float(afstand), 3),
            }
        )
        rows.append(
            {
                "plot_id": plot.plot_id,
                "jaar": jaar,
                "bron": bron,
                "variabele": "padlengte_m_per_ha",
                "waarde": round(float(padlengte_per_ha), 3) if padlengte_per_ha is not None else None,
            }
        )
    return rows


def distance_metric(plots, features, jaar, bron, variabele):
    rows = []
    if features is None or features.empty:
        return rows

    feature_union = geometry_union(features.geometry)
    for plot in plots.itertuples():
        afstand = plot.geometry.distance(feature_union)
        rows.append(
            {
                "plot_id": plot.plot_id,
                "jaar": jaar,
                "bron": bron,
                "variabele": variabele,
                "waarde": round(float(afstand), 3),
            }
        )
    return rows


def main():
    args = parse_args()

    plots = to_rd(load_plots(args.plots, args.plot_id_field))
    plot_bounds = tuple(plots.total_bounds)

    rows = []

    if args.paden:
        paden = read_vector(args.paden, args.paden_layer)
        paden = to_rd(paden[["geometry"]].copy())
        paden = paden.cx[plot_bounds[0]:plot_bounds[2], plot_bounds[1]:plot_bounds[3]].copy()
        paden = paden[paden.geometry.notna() & ~paden.geometry.is_empty].copy()
        rows.extend(line_metrics(plots, paden, args.jaar, args.paden_bron))

    if args.parkeerplaatsen:
        parkeer = read_vector(args.parkeerplaatsen, args.parkeer_layer)
        parkeer = to_rd(parkeer[["geometry"]].copy())
        parkeer = parkeer.cx[plot_bounds[0]:plot_bounds[2], plot_bounds[1]:plot_bounds[3]].copy()
        parkeer = parkeer[parkeer.geometry.notna() & ~parkeer.geometry.is_empty].copy()
        rows.extend(distance_metric(plots, parkeer, args.jaar, args.parkeer_bron, "afstand_parkeerplaats_m"))

    if args.hoofdtoegangen:
        hoofd = read_vector(args.hoofdtoegangen, args.hoofdtoegang_layer)
        hoofd = to_rd(hoofd[["geometry"]].copy())
        hoofd = hoofd[hoofd.geometry.notna() & ~hoofd.geometry.is_empty].copy()
        rows.extend(distance_metric(plots, hoofd, args.jaar, args.hoofdtoegang_bron, "afstand_hoofdtoegang_m"))

    output = pd.DataFrame(rows, columns=["plot_id", "jaar", "bron", "variabele", "waarde"])
    output = output.sort_values(["jaar", "plot_id", "variabele", "bron"]).reset_index(drop=True)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output.to_csv(output_path, index=False)


if __name__ == "__main__":
    main()
