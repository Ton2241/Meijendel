#!/usr/bin/env python3
"""Bereid de lokale import van Tove's geselecteerde vlinder- en libellenkaart voor.

Alleen de 11 door Ton gekozen dagvlinder- en 11 libellenlocaties worden
opgenomen. Jaarcijfers, bezoeken en NDFF-waarnemingen blijven buiten deze stap.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

from osgeo import ogr, osr


ogr.UseExceptions()

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis/database/vlinder_libellen_locaties_schema.sql"
DEFAULT_SOURCE = Path("/Volumes/T7 Data/Home_Ton/Meijendel data/Vlinderstichting")
DEFAULT_BASIS = ROOT / "gis/vectors/meijendel_bereik/meijendel_ruimtelijke_lagen.gpkg"
PROEFOMGEVINGEN = Path("/Volumes/T7 Data/Home_Ton/Proefomgevingen")
T7_GATE = Path("/Users/ton/.codex/bin/t7_work.py")
BASISVERSIE = "2026-09-24.3"

SOURCE_FILES = {
    "kaart_routes_Meijendel & Berkheide.html":
        "e6520f8cccd09271dd2a5309cd83546d407b18c19a4458be7cec9894ecf3bec9",
    "Jaarcijfers_dagvlinders_perroute_Meijendel & Berkheide.csv":
        "04d9ea76b546c3d7a7b4136f500a159d45cc296a26c1721d6aa94ed85cb5beb2",
    "Meijendel & Berkheide_bezoeken_per_jaar_per_route.csv":
        "4f7c69e1e3299f7c7c039944125e86ee1edfa646141932fd60f3fbcf37b8fbf7",
    "Meijendel & Berkheide_aantalvlinders_per_jaar_per_route.csv":
        "70f028c78fc71be79226c2ec120274995678b4b754bbf33846297d49fc375a6b",
}

SELECTED_DAG = {
    393: "Parnassiapad Meijendel",
    635: "Kijfhoekhoogte (Meijendel)",
    638: "Hertenkamp (Meijendel)",
    640: "Helmduinen (Meijendel)",
    929: "Scheepje - Meijendel",
    1149: "Violenwater Meijendel",
    4439: "Bierlap, groot dikkopje",
    4410: "De Klip",
    4588: "Vallei Meijendel",
    4615: "Sprang A. Meijendel",
    5169: "Vallei Meijendel Eikenpage",
}

# De oorspronkelijke naam blijft onaangeroerd; dit is uitsluitend de lokale kaartnaam.
DAG_WEERGAVENAAM_OVERRIDES = {638: "Bierlap – dagvlinderroute 638"}

SELECTED_LIBELLEN = (
    "De Hertenkamp, bospoel",
    "De Hertenkamp, poel",
    "De Hertenkamp, plas",
    "De Klip, poel",
    "De Klip, kranswierpoel",
    "De Klip, plas",
    "Meijendel - Helmduinen",
    "Meijendel - Kikkerberg",
    "Meijendel - Parnassiapad",
    "De Klip, Poel nieuw",
    "Meijendel Kikkervallei",
)

POPUP = re.compile(r"(dagvlinders|libellen):\s*(.*?);\s*geteld\s+(\d{4})-(\d{4})")
SCRIPT_JSON = re.compile(
    r'<script type="application/json" data-for="[^"]+">(.*?)</script>', re.S
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_sources(source: Path) -> None:
    for filename, expected in SOURCE_FILES.items():
        path = source / filename
        if not path.is_file() or sha256_file(path) != expected:
            raise ValueError(f"Bronbestand ontbreekt of SHA-256 is gewijzigd: {path}")


def read_csv(source: Path, filename: str) -> list[dict[str, str]]:
    with (source / filename).open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle, delimiter=";"))


def read_overview(source: Path, filename: str) -> dict[tuple[str, str], str]:
    rows = read_csv(source, filename)
    result = {}
    for row in rows:
        key = row["Soortgroep"], row["countobject_name"]
        if key in result:
            raise ValueError(f"Dubbel telobject in {filename}: {key}")
        result[key] = row["Projectnaam"]
    return result


def read_dag_codes(source: Path) -> dict[int, str]:
    filename = "Jaarcijfers_dagvlinders_perroute_Meijendel & Berkheide.csv"
    result = {}
    for row in read_csv(source, filename):
        code = int(row["countobject_id"])
        if code not in SELECTED_DAG:
            continue
        match = POPUP.search(row["meetpunt"])
        if match is None or match.group(1) != "dagvlinders":
            raise ValueError(f"Ongeldige dagvlindernaam voor broncode {code}")
        name = match.group(2)
        if code in result and result[code] != name:
            raise ValueError(f"Meer dan één bronnaam bij dagvlindercode {code}")
        result[code] = name
    if result != SELECTED_DAG:
        raise ValueError(f"Dagvlindercodes wijken af van de selectie: {result}")
    return result


def source_geometry(value):
    """Vind de coördinaten in één Leaflet-lijnfeature, zonder kaart-ID te gebruiken."""
    if isinstance(value, dict) and {"lng", "lat"} <= value.keys():
        return value
    if isinstance(value, list):
        found = [item for child in value if (item := source_geometry(child)) is not None]
        if len(found) == 1:
            return found[0]
    return None


def rd_transform() -> osr.CoordinateTransformation:
    wgs = osr.SpatialReference()
    wgs.ImportFromEPSG(4326)
    wgs.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    rd = osr.SpatialReference()
    rd.ImportFromEPSG(28992)
    rd.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    return osr.CoordinateTransformation(wgs, rd)


def read_map(source: Path) -> dict[tuple[str, str], dict]:
    text = (source / "kaart_routes_Meijendel & Berkheide.html").read_text(encoding="utf-8")
    match = SCRIPT_JSON.search(text)
    if match is None:
        raise ValueError("Leaflet-JSON in routekaart ontbreekt")
    calls = json.loads(match.group(1))["x"]["calls"]
    transform = rd_transform()
    result = defaultdict(lambda: {"period": None, "geometry": []})
    for call in calls:
        method = call["method"]
        if method not in {"addPolylines", "addCircleMarkers"}:
            continue
        args = call["args"]
        is_line = method == "addPolylines"
        popups = args[4] if is_line else args[8]
        for index, popup in enumerate(popups):
            plain = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html.unescape(popup)))
            parsed = POPUP.search(plain)
            if parsed is None:
                continue
            group, name = parsed.group(1), parsed.group(2)
            if not (
                (group == "dagvlinders" and name in SELECTED_DAG.values())
                or (group == "libellen" and name in SELECTED_LIBELLEN)
            ):
                continue
            period = int(parsed.group(3)), int(parsed.group(4))
            record = result[group, name]
            if record["period"] not in (None, period):
                raise ValueError(f"Tegenstrijdige kaartjaren bij {group}: {name}")
            record["period"] = period
            if is_line:
                coords = source_geometry(args[0][index])
                if coords is None or len(coords["lng"]) != len(coords["lat"]) or len(coords["lng"]) < 2:
                    raise ValueError(f"Ongeldige kaartlijn bij {group}: {name}")
                geometry = ogr.Geometry(ogr.wkbLineString)
                for lon, lat in zip(coords["lng"], coords["lat"]):
                    x, y, _ = transform.TransformPoint(lon, lat)
                    geometry.AddPoint_2D(x, y)
            else:
                x, y, _ = transform.TransformPoint(args[1][index], args[0][index])
                geometry = ogr.Geometry(ogr.wkbPoint)
                geometry.AddPoint_2D(x, y)
            if geometry.IsEmpty() or not geometry.IsValid() or (is_line and geometry.Length() <= 0):
                raise ValueError(f"Ongeldige RD-geometrie bij {group}: {name}")
            record["geometry"].append(geometry)
    return dict(result)


def read_basis(path: Path) -> ogr.Geometry:
    dataset = ogr.Open(str(path), 0)
    if dataset is None:
        raise ValueError(f"Meijendel-basisgebied ontbreekt: {path}")
    layer = dataset.GetLayerByName("meijendel_basisgebied")
    if layer is None or layer.GetFeatureCount() != 1:
        raise ValueError("Actuele basislaag moet precies één gebied bevatten")
    feature = next(iter(layer))
    if feature.GetField("versie") != BASISVERSIE:
        raise ValueError(f"Basisgebiedversie is niet {BASISVERSIE}")
    geometry = feature.GetGeometryRef().Clone()
    if geometry.IsEmpty() or not geometry.IsValid():
        raise ValueError("Meijendel-basisgebied is ongeldig")
    return geometry


def build_location_rows(source: Path, basis_gpkg: Path) -> dict[str, list[dict]]:
    validate_sources(source)
    read_dag_codes(source)
    visits = read_overview(source, "Meijendel & Berkheide_bezoeken_per_jaar_per_route.csv")
    totals = read_overview(source, "Meijendel & Berkheide_aantalvlinders_per_jaar_per_route.csv")
    if visits != totals:
        raise ValueError("Objectnamen en projecten verschillen tussen de jaaroverzichten")
    mapped = read_map(source)
    basis = read_basis(basis_gpkg)
    expected_keys = ({("dagvlinders", name) for name in SELECTED_DAG.values()}
                     | {("libellen", name) for name in SELECTED_LIBELLEN})
    if set(mapped) != expected_keys or not expected_keys <= set(visits):
        raise ValueError("Een geselecteerd telobject ontbreekt in kaart of jaaroverzicht")
    kaart_hash = SOURCE_FILES["kaart_routes_Meijendel & Berkheide.html"]
    rows = {name: [] for name in (
        "vlinders_dag_telobject", "vlinders_dag_geometrie",
        "libellen_telobject", "libellen_geometrie"
    )}
    for code, name in SELECTED_DAG.items():
        key = "dagvlinders", name
        period = mapped[key]["period"]
        rows["vlinders_dag_telobject"].append({
            "bron_code": code, "bronnaam": name, "projectnaam": visits[key],
            "weergavenaam_override": DAG_WEERGAVENAAM_OVERRIDES.get(code),
            "bron_eerste_jaar": period[0], "bron_laatste_jaar": period[1],
            "bronkaart_sha256": kaart_hash, "basisgebiedversie": BASISVERSIE,
        })
        for number, geometry in enumerate(mapped[key]["geometry"], 1):
            rows["vlinders_dag_geometrie"].append(
                geometry_row("bron_code", code, number, geometry, basis)
            )
    for internal_id, name in enumerate(SELECTED_LIBELLEN, 1):
        key = "libellen", name
        period = mapped[key]["period"]
        rows["libellen_telobject"].append({
            "telobject_id": internal_id, "bronnaam": name, "projectnaam": visits[key],
            "bron_eerste_jaar": period[0], "bron_laatste_jaar": period[1],
            "bronkaart_sha256": kaart_hash, "basisgebiedversie": BASISVERSIE,
        })
        for number, geometry in enumerate(mapped[key]["geometry"], 1):
            rows["libellen_geometrie"].append(
                geometry_row("telobject_id", internal_id, number, geometry, basis)
            )
    if [len(rows[key]) for key in rows] != [11, 194, 11, 24]:
        raise ValueError("De selectie heeft niet 11+11 locaties en 194+24 kaartcomponenten")
    return rows


def geometry_row(key: str, object_id: int, number: int, geometry: ogr.Geometry,
                 basis: ogr.Geometry) -> dict:
    if geometry.GetGeometryName() == "POINT":
        inside = bool(basis.Intersects(geometry))
    else:
        inside = geometry.Difference(basis).Length() <= 0.2
    if not inside:
        raise ValueError(f"Kaartcomponent van telobject {object_id} valt buiten Meijendel")
    wkb = bytes(geometry.ExportToWkb())
    return {
        key: object_id, "kaartcomponent_nr": number,
        "geometrie_type": geometry.GetGeometryName(),
        "wkb_hex": wkb.hex(), "geometrie_sha256": hashlib.sha256(wkb).hexdigest(),
        "binnen_basisgebied": inside,
    }


def sql_quote(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"


def sql_values(rows: list[dict], columns: tuple[str, ...]) -> str:
    return ",\n".join(
        "(" + ",".join("NULL" if row[col] is None else
                       str(row[col]) if isinstance(row[col], int) else sql_quote(row[col])
                       for col in columns) + ")"
        for row in rows
    )


def geometry_values(rows: list[dict], key: str) -> str:
    return ",\n".join(
        f"({row[key]},{row['kaartcomponent_nr']},"
        f"ST_GeomFromWKB(UNHEX('{row['wkb_hex']}'),28992),"
        f"'{row['geometrie_sha256']}')"
        for row in rows
    )


def build_insert_sql(rows: dict[str, list[dict]]) -> str:
    parent_columns = ("bronnaam", "projectnaam", "bron_eerste_jaar",
                      "bron_laatste_jaar", "bronkaart_sha256", "basisgebiedversie")
    day_columns = ("bron_code", *parent_columns, "weergavenaam_override")
    libel_columns = ("telobject_id", *parent_columns)
    day_parents = sql_values(rows["vlinders_dag_telobject"], day_columns)
    libel_parents = sql_values(rows["libellen_telobject"], libel_columns)
    day_geo = geometry_values(rows["vlinders_dag_geometrie"], "bron_code")
    libel_geo = geometry_values(rows["libellen_geometrie"], "telobject_id")
    return f"""
USE Meijendel;
START TRANSACTION;
INSERT INTO vlinders_dag_telobject ({','.join(day_columns)}) VALUES
{day_parents};
INSERT INTO vlinders_dag_geometrie
  (bron_code,kaartcomponent_nr,geometrie,geometrie_sha256) VALUES
{day_geo};
INSERT INTO libellen_telobject ({','.join(libel_columns)}) VALUES
{libel_parents};
INSERT INTO libellen_geometrie
  (telobject_id,kaartcomponent_nr,geometrie,geometrie_sha256) VALUES
{libel_geo};
COMMIT;
SELECT 'vlinders_dag_telobject' AS tabel, COUNT(*) AS regels FROM vlinders_dag_telobject
UNION ALL SELECT 'vlinders_dag_geometrie', COUNT(*) FROM vlinders_dag_geometrie
UNION ALL SELECT 'libellen_telobject', COUNT(*) FROM libellen_telobject
UNION ALL SELECT 'libellen_geometrie', COUNT(*) FROM libellen_geometrie;
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--basis", type=Path, default=DEFAULT_BASIS)
    parser.add_argument("--output-sql", type=Path, required=True)
    args = parser.parse_args()
    output = args.output_sql.resolve()
    if not output.is_relative_to(PROEFOMGEVINGEN) or not output.parent.is_dir():
        raise ValueError("Import-SQL moet in een bestaande geregistreerde T7-proefmap staan")
    gate = subprocess.run(
        [sys.executable, str(T7_GATE), "check", str(output)],
        text=True, capture_output=True, check=False,
    )
    if gate.returncode:
        raise ValueError(f"T7-uitvoer geweigerd: {gate.stderr.strip()}")
    rows = build_location_rows(args.source, args.basis)
    sql = SCHEMA.read_text(encoding="utf-8") + "\n" + build_insert_sql(rows)
    output.write_text(sql, encoding="utf-8")
    print(f"Importbestand: {output}")
    print(f"SHA-256: {sha256_file(output)}")
    print("Selectie: 11 dagvlinders, 194 kaartcomponenten; 11 libellen, 24 kaartcomponenten")


if __name__ == "__main__":
    main()
