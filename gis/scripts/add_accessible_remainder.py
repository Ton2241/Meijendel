#!/usr/bin/env python3
"""Voeg het bevestigde openbare complement van de actuele statusvlakken toe."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from osgeo import ogr

import migrate_toegankelijkheidsgebieden as migration


SOURCE_CODE = "handmatige_statusaanvulling_20261110"
AREA_CODE = "overig_meijendel_toegankelijk_1955"
EXPECTED_AREA_M2 = 3_040_272.952003


def read_live_plots(client: migration.Client) -> dict[str, ogr.Geometry]:
    plots: dict[str, ogr.Geometry] = {}
    for line in client.sql(
        "SELECT kavel_nummer,HEX(ST_AsBinary(geom)) FROM plots "
        "WHERE geom IS NOT NULL AND ST_IsValid(geom) ORDER BY plot_id"
    ).splitlines():
        kavel, geometry_hex = line.split("\t", 1)
        plots[kavel] = ogr.CreateGeometryFromWkb(bytes.fromhex(geometry_hex))
    if len(plots) != 55 or not all(geometry.IsValid() for geometry in plots.values()):
        raise ValueError(f"Verwacht 55 geldige actuele kavelgeometrieën, gevonden {len(plots)}")
    return plots


def read_live_areas(
    client: migration.Client,
    *,
    exclude_remainder: bool = False,
) -> list[dict[str, Any]]:
    condition = f"AND g.gebied_code<>{migration.sql_literal(AREA_CODE)}" if exclude_remainder else ""
    rows = client.sql(
        "SELECT g.gebied_code,v.status_code,v.bron_object_id,v.geometrie_sha256,"
        "HEX(ST_AsBinary(v.geometrie)),v.geldig_vanaf,IF(v.geldig_tot IS NULL,'NULL',v.geldig_tot) "
        "FROM toegankelijkheidsgebied_versie v JOIN toegankelijkheidsgebied g USING(gebied_id) "
        f"WHERE v.geldig_tot IS NULL {condition} ORDER BY g.gebied_code"
    )
    areas = []
    for line in rows.splitlines():
        code, status, feature_id, geometry_hash, geometry_hex, valid_from, valid_to = line.split("\t")
        geometry = ogr.CreateGeometryFromWkb(bytes.fromhex(geometry_hex))
        if geometry is None or not geometry.IsValid():
            raise ValueError(f"Ongeldige actuele statusgeometrie: {code}")
        areas.append({
            "gebied_code": code,
            "status_code": status,
            "feature_id": feature_id,
            "geometrie_sha256": geometry_hash,
            "geometry": geometry,
            "geldig_vanaf": valid_from,
            "geldig_tot": valid_to,
        })
    return areas


def build_remainder_record(
    plots: dict[str, ogr.Geometry],
    occupied: list[ogr.Geometry],
    *,
    expected_area_m2: float,
) -> dict[str, Any]:
    plot_union = migration._union_geometries(list(plots.values()))
    occupied_union = migration._union_geometries(occupied)
    remainder = migration._polygonal_multipolygon(plot_union.Difference(occupied_union))
    area_m2 = migration.polygonal_area(remainder)
    if abs(area_m2 - expected_area_m2) >= 0.01:
        raise ValueError(
            f"Openbaar complement is {area_m2:.6f} m2; verwacht {expected_area_m2:.6f} m2"
        )
    if migration.polygonal_area(remainder.Intersection(occupied_union)) >= 0.01:
        raise ValueError("Openbaar complement overlapt een bestaand statusvlak")
    if migration.polygonal_area(plot_union.Difference(remainder.Union(occupied_union))) >= 0.01:
        raise ValueError("Na aanvulling blijft kavelgebied zonder status")
    wkb = bytes(remainder.ExportToWkb(ogr.wkbNDR))
    return {
        "gebied_code": AREA_CODE,
        "naam": "Overige openbaar toegankelijke delen van Meijendel",
        "status_code": "toegankelijk",
        "bron_code": SOURCE_CODE,
        "feature_id": "onderzoekskavels:complement-actuele-statusvlakken-20261110",
        "wkt": remainder.ExportToIsoWkt(),
        "geometrie_sha256": hashlib.sha256(wkb).hexdigest(),
        "oppervlakte_m2": float(remainder.GetArea()),
        "interne_ringen": sum(
            max(0, part.GetGeometryCount() - 1)
            for part in migration._polygon_parts(remainder)
        ),
        "geometriedelen": len(list(migration._polygon_parts(remainder))),
    }


def apply_remainder(client: migration.Client, record: dict[str, Any]) -> None:
    statements = (
        "START TRANSACTION",
        "INSERT INTO maatregel_bron "
        "(bron_code,brontype_code,titel,bron_datum,raadpleegdatum,bronstatus,opmerking) VALUES ("
        f"{migration.sql_literal(SOURCE_CODE)},'handmatige_registratie',"
        "'Openbaar toegankelijke restgebieden binnen de onderzoekskavels',"
        "'2026-11-10','2026-11-10','door gebruiker bevestigd',"
        "'Alle eerder turkoois weergegeven restgebieden zijn door Ton als openbaar toegankelijk "
        "bevestigd; de geometrie is het complement van de overige actuele statusvlakken binnen "
        "de actuele geometrie van de 55 onderzoekskavels') "
        "ON DUPLICATE KEY UPDATE titel=VALUES(titel),bronstatus=VALUES(bronstatus),opmerking=VALUES(opmerking)",
        "INSERT INTO toegankelijkheidsgebied (gebied_code,naam,opmerking) VALUES ("
        f"{migration.sql_literal(AREA_CODE)},{migration.sql_literal(record['naam'])},"
        "'Door Ton bevestigde openbare restgebieden binnen de actuele onderzoekskavels') "
        "ON DUPLICATE KEY UPDATE naam=VALUES(naam),opmerking=VALUES(opmerking)",
        "INSERT INTO toegankelijkheidsgebied_versie "
        "(gebied_id,versienummer,status_code,geldig_vanaf,geldig_tot,vastgesteld_op,bron_id,"
        "bron_object_id,inwinningsmethode,nauwkeurigheid_m,geometrie,geometrie_wkt,"
        "geometrie_sha256,oppervlakte_m2,geometrie_opmerking) SELECT "
        f"g.gebied_id,1,'toegankelijk','1955-01-01',NULL,'2026-11-10',b.bron_id,"
        f"{migration.sql_literal(record['feature_id'])},"
        "'complement actuele statusvlakken binnen actuele kavelunie',NULL,"
        f"ST_GeomFromText({migration.sql_literal(record['wkt'])},28992),"
        f"{migration.sql_literal(record['wkt'])},{migration.sql_literal(record['geometrie_sha256'])},"
        f"{record['oppervlakte_m2']:.6f},"
        "'Alle op 10 november 2026 nog onbedekte kavelgedeelten; door Ton visueel bevestigd als openbaar toegankelijk' "
        "FROM toegankelijkheidsgebied g JOIN maatregel_bron b "
        f"ON b.bron_code={migration.sql_literal(SOURCE_CODE)} "
        f"WHERE g.gebied_code={migration.sql_literal(AREA_CODE)} "
        "ON DUPLICATE KEY UPDATE status_code=VALUES(status_code),geldig_vanaf=VALUES(geldig_vanaf),"
        "geldig_tot=VALUES(geldig_tot),vastgesteld_op=VALUES(vastgesteld_op),bron_id=VALUES(bron_id),"
        "bron_object_id=VALUES(bron_object_id),inwinningsmethode=VALUES(inwinningsmethode),"
        "geometrie=VALUES(geometrie),geometrie_wkt=VALUES(geometrie_wkt),"
        "geometrie_sha256=VALUES(geometrie_sha256),oppervlakte_m2=VALUES(oppervlakte_m2),"
        "geometrie_opmerking=VALUES(geometrie_opmerking)",
        "COMMIT",
    )
    client.sql(";\n".join(statements) + ";")
    migration.rebuild_plot_derivations(client)


def verify_live(client: migration.Client, expected: dict[str, Any]) -> dict[str, Any]:
    plots = read_live_plots(client)
    areas = read_live_areas(client)
    if len(areas) != 14:
        raise AssertionError(f"Verwacht 14 actuele statusgebieden, gevonden {len(areas)}")
    if any(area["geldig_vanaf"] != "1955-01-01" or area["geldig_tot"] != "NULL" for area in areas):
        raise AssertionError("Niet alle actuele statusgebieden lopen van 1955-01-01 tot NULL")
    by_code = {area["gebied_code"]: area for area in areas}
    remainder = by_code.get(AREA_CODE)
    if remainder is None or remainder["status_code"] != "toegankelijk":
        raise AssertionError("Het openbare restgebied ontbreekt of heeft een verkeerde status")
    if remainder["geometrie_sha256"] != expected["geometrie_sha256"]:
        raise AssertionError("Hash van het openbare restgebied wijkt af")
    plot_union = migration._union_geometries(list(plots.values()))
    status_union = migration._union_geometries([area["geometry"] for area in areas])
    uncovered_m2 = migration.polygonal_area(plot_union.Difference(status_union))
    if uncovered_m2 >= 0.01:
        raise AssertionError(f"Nog {uncovered_m2:.6f} m2 kavelgebied zonder status")
    overlap_pairs = 0
    for index, area_1 in enumerate(areas[:-1]):
        for area_2 in areas[index + 1:]:
            overlap = migration.polygonal_area(area_1["geometry"].Intersection(area_2["geometry"]))
            if overlap >= 0.01:
                overlap_pairs += 1
    if overlap_pairs:
        raise AssertionError(f"Nog {overlap_pairs} statusoverlapparen vanaf 0,01 m2")
    status_counts: dict[str, int] = {}
    for area in areas:
        status_counts[area["status_code"]] = status_counts.get(area["status_code"], 0) + 1
    expected_counts = {
        "afgesloten": 5,
        "toegankelijk": 7,
        "toegankelijk_buiten_broedseizoen": 1,
        "toegankelijk_met_toegangskaart": 1,
    }
    if status_counts != expected_counts:
        raise AssertionError(status_counts)
    return {
        "plots": len(plots),
        "gebieden": len(areas),
        "statussen": status_counts,
        "statusoverlapparen_ge_0_01_m2": overlap_pairs,
        "kavelgebied_zonder_status_m2": uncovered_m2,
        "plotdoorsnijdingen": int(client.scalar("SELECT COUNT(*) FROM toegankelijkheidsgebied_plot_afleiding")),
        "bronnen": int(client.scalar("SELECT COUNT(*) FROM maatregel_bron")),
        "restgebied_oppervlakte_m2": expected["oppervlakte_m2"],
        "restgebied_geometrie_sha256": expected["geometrie_sha256"],
        "restgebied_interne_ringen": expected["interne_ringen"],
        "restgebied_delen": expected["geometriedelen"],
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", default="Meijendel")
    parser.add_argument("--backup-dir", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--verify", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    client = migration.Client(args.database)
    current = read_live_areas(client, exclude_remainder=True)
    expected = build_remainder_record(
        read_live_plots(client),
        [area["geometry"] for area in current],
        expected_area_m2=EXPECTED_AREA_M2,
    )
    if args.apply:
        backup_feature = next(area for area in current if area["gebied_code"] == migration.AREA_CODE)
        backup_areas = [area for area in current if area["gebied_code"] != migration.AREA_CODE]
        metadata = migration.backup(client, args.backup_dir, backup_feature, backup_areas)
        apply_remainder(client, expected)
        print(json.dumps({"backup_metadata": str(metadata)}, ensure_ascii=False))
    if args.verify:
        print(json.dumps(verify_live(client, expected), ensure_ascii=False, sort_keys=True))
    elif not args.apply:
        print(json.dumps({key: value for key, value in expected.items() if key != "wkt"}, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
