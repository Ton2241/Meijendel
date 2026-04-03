#!/usr/bin/env python3

import argparse
import re
from pathlib import Path

import geopandas as gpd
import pandas as pd
from pyproj import Transformer


def parse_args():
    parser = argparse.ArgumentParser(
        description="Bereken Natura2000 T0 habitat per plot (2014) en vergelijk met Meijendel.sql."
    )
    parser.add_argument("--plots", required=True, help="Pad naar plot shapefile (RD)")
    parser.add_argument("--t0-shp", required=True, help="Pad naar Natura2000 shapefile")
    parser.add_argument("--sql", required=True, help="Pad naar Meijendel.sql")
    parser.add_argument("--year", type=int, default=2014, help="Jaar voor output")
    parser.add_argument("--output", required=True, help="Pad naar output CSV (plot_jaar_habitat)")
    parser.add_argument("--report", required=True, help="Pad naar vergelijking CSV")
    return parser.parse_args()


def extract_insert_block(sql_text, table_name):
    # Find the INSERT INTO block by simple string search to avoid regex pitfalls
    needle = f"INSERT INTO `{table_name}`"
    idx = sql_text.find(needle)
    if idx == -1:
        # fallback without backticks
        needle = f"INSERT INTO {table_name}"
        idx = sql_text.find(needle)
        if idx == -1:
            return None
    # find the first "VALUES" after the insert header
    values_idx = sql_text.find("VALUES", idx)
    if values_idx == -1:
        return None
    # end at the next semicolon not inside quotes
    inq = False
    end_idx = None
    for i in range(values_idx, len(sql_text)):
        ch = sql_text[i]
        if ch == "'":
            inq = not inq
        if ch == ";" and not inq:
            end_idx = i
            break
    if end_idx is None:
        return None
    return sql_text[values_idx + len("VALUES"):end_idx].strip()


def parse_habitattypen(sql_text):
    vals = extract_insert_block(sql_text, "habitattypen")
    if not vals:
        raise ValueError("Geen INSERT INTO `habitattypen` gevonden in SQL.")
    rows = []
    for tup in split_tuples(vals):
        parts = split_fields(tup)
        if len(parts) >= 3:
            hid = int(parts[0])
            code = parts[1].strip().strip("'")
            naam = parts[2].strip().strip("'")
            rows.append((hid, code, naam))
    return pd.DataFrame(rows, columns=["habitat_id", "habitat_code", "habitat_naam"])


def parse_plot_jaar_habitat(sql_text, year):
    vals = extract_insert_block(sql_text, "plot_jaar_habitat")
    if not vals:
        return pd.DataFrame(columns=["plot_id", "habitat_id", "aandeel_m2"])
    rows = []
    for tup in split_tuples(vals):
        parts = split_fields(tup)
        if len(parts) >= 5:
            plot_id = int(parts[1])
            jaar = int(parts[2])
            habitat_id = int(parts[3])
            aandeel = None if parts[4] == "NULL" else float(parts[4])
            if jaar == year:
                rows.append((plot_id, habitat_id, aandeel))
    return pd.DataFrame(rows, columns=["plot_id", "habitat_id", "aandeel_m2"])

def split_tuples(vals):
    tuples = []
    cur = ""
    depth = 0
    inq = False
    for ch in vals:
        if ch == "'" and not inq:
            inq = True
            cur += ch
            continue
        if ch == "'" and inq:
            inq = False
            cur += ch
            continue
        if not inq:
            if ch == "(":
                depth += 1
                if depth == 1:
                    cur = ""
                    continue
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    tuples.append(cur.strip())
                    cur = ""
                    continue
        if depth >= 1:
            cur += ch
    return tuples

def split_fields(tup):
    parts = []
    cur = ""
    inq = False
    for ch in tup:
        if ch == "'" and not inq:
            inq = True
            cur += ch
            continue
        if ch == "'" and inq:
            inq = False
            cur += ch
            continue
        if ch == "," and not inq:
            parts.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur:
        parts.append(cur.strip())
    return parts

def normalize_habitat_code(code):
    if code is None:
        return None
    s = str(code).strip().upper()
    # remove ZG prefix if present
    if s.startswith("ZG"):
        s = s[2:]
    # normalize letter O to zero
    s = s.replace("O", "0")
    # collapse known subtypes to base types
    if s.startswith("H2180A"):
        return "H2180A"
    if s.startswith("H2190A"):
        return "H2190A"
    # keep only first suffix letter after H#### if present
    m = re.match(r"^(H\\d{4}[A-Z])", s)
    if m:
        return m.group(1)
    m = re.match(r"^(H\\d{4})", s)
    if m:
        return m.group(1)
    return s


def main():
    args = parse_args()

    sql_text = Path(args.sql).read_text()
    hab_df = parse_habitattypen(sql_text)
    existing_df = parse_plot_jaar_habitat(sql_text, args.year)

    plots = gpd.read_file(args.plots)[["plotid", "geometry"]].copy()
    plots["plot_id"] = plots["plotid"].astype(int)
    plots = plots[["plot_id", "geometry"]]

    # Compute bbox of plots in WGS84 for fast read
    minx, miny, maxx, maxy = plots.total_bounds
    transformer = Transformer.from_crs(28992, 4326, always_xy=True)
    minx_w, miny_w = transformer.transform(minx, miny)
    maxx_w, maxy_w = transformer.transform(maxx, maxy)
    bbox_wgs84 = (minx_w, miny_w, maxx_w, maxy_w)

    t0 = gpd.read_file(
        args.t0_shp,
        bbox=bbox_wgs84,
    )

    # Filter to Meijendel & Berkheide
    if "gebied" in t0.columns:
        t0 = t0[t0["gebied"].str.contains("Meijendel|Berkheide", case=False, na=False)]

    # Build long table of habitat codes with perc1..perc6
    pairs = [
        ("habitatt_6", "perc1"),
        ("habitatt_7", "perc2"),
        ("habitatt_8", "perc3"),
        ("habitatt_9", "perc4"),
        ("habitat_10", "perc5"),
        ("habitat_11", "perc6"),
    ]

    records = []
    for _, row in t0.iterrows():
        geom = row.geometry
        for code_col, perc_col in pairs:
            code = row.get(code_col)
            perc = row.get(perc_col)
            if code is None:
                continue
            try:
                perc_val = float(perc)
            except Exception:
                continue
            if perc_val <= 0:
                continue
            raw_code = str(code).strip()
            norm_code = normalize_habitat_code(raw_code)
            records.append({
                "habitat_code_raw": raw_code,
                "habitat_code": norm_code,
                "perc": perc_val,
                "geometry": geom
            })

    if not records:
        raise ValueError("Geen habitatrecords gevonden in T0 dataset na filtering.")

    t0_long = gpd.GeoDataFrame(records, geometry="geometry", crs=t0.crs)
    t0_long = t0_long.to_crs(28992)

    inter = gpd.overlay(plots, t0_long, how="intersection", keep_geom_type=True)
    inter["area_m2"] = inter.geometry.area * (inter["perc"] / 100.0)
    inter = inter[inter["area_m2"] > 0].copy()

    grouped = (
        inter.groupby(["plot_id", "habitat_code", "habitat_code_raw"], as_index=False)["area_m2"]
        .sum()
        .sort_values(["plot_id", "habitat_code"])
    )

    # Map habitat_code to habitat_id
    merged = grouped.merge(hab_df, on="habitat_code", how="left")
    if merged["habitat_id"].isna().any():
        # Keep unknowns for report
        pass

    output = merged[["plot_id", "habitat_id", "area_m2", "habitat_code", "habitat_code_raw"]].copy()
    output["jaar"] = args.year
    output = output.rename(columns={"area_m2": "aandeel_m2"})
    output = output[["plot_id", "jaar", "habitat_id", "aandeel_m2", "habitat_code", "habitat_code_raw"]]

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    output.to_csv(out_path, index=False)

    # Comparison report with existing data
    if not existing_df.empty:
        comp = output.merge(
            existing_df,
            on=["plot_id", "habitat_id"],
            how="outer",
            suffixes=("_nieuw", "_bestaand"),
        )
        comp["verschil_m2"] = comp["aandeel_m2_nieuw"].fillna(0) - comp["aandeel_m2_bestaand"].fillna(0)
    else:
        comp = output.copy()
        comp["aandeel_m2_bestaand"] = None
        comp["verschil_m2"] = None

    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    comp.to_csv(report_path, index=False)


if __name__ == "__main__":
    main()
