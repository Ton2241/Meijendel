#!/opt/homebrew/bin/python3.14
"""Vul plots.geom uit de nieuwste SOVON-shapefile en koppel naamgeometrieën."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from datetime import date
from pathlib import Path
from typing import NamedTuple

from osgeo import ogr


ogr.UseExceptions()

ROOT = Path(__file__).parents[2]
SCHEMA = ROOT / "gis" / "database" / "nameninventaris_plotkoppeling_schema.sql"
DEFAULT_SHP = Path(
    "/Volumes/T7 Data/Home_Ton/Meijendel data/SOVON/Per jaar/2025/"
    "avimap_252_diversen__gebieden.shp"
)
DEFAULT_MYSQL = Path("/usr/local/mysql-9.7.1-macos15-arm64/bin/mysql")
VERSIESLEUTEL = "sovon-avimap-2025-download-2026-10-02"
REKENREGELVERSIE = "nameninventaris-plot-overlap-v1"
UITGESLOTEN_PLOT_ID = 29945
UITGESLOTEN_NAAM = "De Horsten"


class PlotGeometry(NamedTuple):
    plot_id: int
    project_id: int
    plotnummer: int
    naam: str
    oppervlakte_ha: float
    wkb_hex: str
    wkb_sha256: str
    srid: int
    is_valid: bool


class PlotDelivery(NamedTuple):
    source: Path
    bron_datum: date
    bron_objecten: int
    plots: tuple[PlotGeometry, ...]
    uitgesloten_plot_id: int
    uitgesloten_naam: str
    component_hashes: dict[str, str]
    bundel_sha256: str


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sql_text(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"


def read_plot_delivery(shp: Path) -> PlotDelivery:
    shp = shp.resolve()
    component_paths = {suffix: shp.with_suffix(suffix) for suffix in (".shp", ".shx", ".dbf", ".prj")}
    missing = [str(path) for path in component_paths.values() if not path.is_file()]
    if missing:
        raise ValueError("Ontbrekende shapefilecomponenten: " + ", ".join(missing))

    dataset = ogr.Open(str(shp), 0)
    if dataset is None:
        raise ValueError(f"SOVON-shapefile niet leesbaar: {shp}")
    layer = dataset.GetLayer(0)
    if layer is None:
        raise ValueError("SOVON-shapefile bevat geen laag")
    fields = {layer.GetLayerDefn().GetFieldDefn(i).GetName().lower()
              for i in range(layer.GetLayerDefn().GetFieldCount())}
    required = {"plotid", "projectid", "plotnummer", "naam", "opp_ha"}
    if not required <= fields:
        raise ValueError(f"SOVON-shapefile mist kolommen: {sorted(required - fields)}")

    srs = layer.GetSpatialRef()
    if srs is None:
        raise ValueError("SOVON-shapefile heeft geen CRS")
    srs.AutoIdentifyEPSG()
    srid_text = srs.GetAuthorityCode(None) or srs.GetAuthorityCode("PROJCS")
    srid = int(srid_text or 0)
    if srid != 28992:
        raise ValueError(f"SOVON-shapefile heeft EPSG:{srid}, verwacht EPSG:28992")

    bron_datum_text = layer.GetMetadataItem("DBF_DATE_LAST_UPDATE")
    if not bron_datum_text:
        raise ValueError("DBF_DATE_LAST_UPDATE ontbreekt")
    bron_datum = date.fromisoformat(bron_datum_text)

    plots: list[PlotGeometry] = []
    excluded: list[tuple[int, str]] = []
    seen: set[int] = set()
    for feature in layer:
        plot_id = int(feature["plotid"])
        naam = str(feature["naam"]).strip()
        if plot_id in seen:
            raise ValueError(f"Dubbel SOVON-plot-ID: {plot_id}")
        seen.add(plot_id)
        geometry = feature.GetGeometryRef()
        if geometry is None or geometry.IsEmpty():
            raise ValueError(f"SOVON-plot {plot_id} heeft geen geometrie")
        geometry = geometry.Clone()
        geometry.FlattenTo2D()
        if plot_id == UITGESLOTEN_PLOT_ID or naam.casefold() == UITGESLOTEN_NAAM.casefold():
            excluded.append((plot_id, naam))
            continue
        wkb = bytes(geometry.ExportToWkb(ogr.wkbNDR))
        plots.append(PlotGeometry(
            plot_id=plot_id,
            project_id=int(feature["projectid"]),
            plotnummer=int(feature["plotnummer"]),
            naam=naam,
            oppervlakte_ha=float(feature["opp_ha"]),
            wkb_hex=wkb.hex(),
            wkb_sha256=hashlib.sha256(wkb).hexdigest(),
            srid=srid,
            is_valid=bool(geometry.IsValid()),
        ))
    bron_objecten = layer.GetFeatureCount()
    dataset = None

    if bron_datum != date(2026, 10, 2):
        raise ValueError(f"Onverwachte bronbestanddatum: {bron_datum}")
    if bron_objecten != 56:
        raise ValueError(f"Onverwacht aantal SOVON-bronobjecten: {bron_objecten}")
    if excluded != [(UITGESLOTEN_PLOT_ID, UITGESLOTEN_NAAM)]:
        raise ValueError(f"Uitsluiting wijkt af: {excluded!r}")
    if len(plots) != 55:
        raise ValueError(f"Na uitsluiting van De Horsten blijven {len(plots)} in plaats van 55 plots over")
    if any(plot.project_id != 252 for plot in plots):
        raise ValueError("SOVON-shapefile bevat een onverwacht project-ID")
    if any(not plot.is_valid for plot in plots):
        raise ValueError("SOVON-shapefile bevat ongeldige geometrie")

    component_hashes = {suffix[1:]: sha256_file(path) for suffix, path in component_paths.items()}
    bundle = "\n".join(f"{key}:{component_hashes[key]}" for key in sorted(component_hashes))
    return PlotDelivery(
        source=shp,
        bron_datum=bron_datum,
        bron_objecten=bron_objecten,
        plots=tuple(sorted(plots, key=lambda item: item.plot_id)),
        uitgesloten_plot_id=UITGESLOTEN_PLOT_ID,
        uitgesloten_naam=UITGESLOTEN_NAAM,
        component_hashes=component_hashes,
        bundel_sha256=hashlib.sha256(bundle.encode("ascii")).hexdigest(),
    )


def build_import_sql(delivery: PlotDelivery, database: str) -> str:
    values = ",\n".join(
        f"({plot.plot_id},UNHEX('{plot.wkb_hex}'),'{plot.wkb_sha256}')"
        for plot in delivery.plots
    )
    hashes = delivery.component_hashes
    return f"""USE `{database}`;
START TRANSACTION;
CREATE TEMPORARY TABLE tmp_plot_geometrie (
  plot_id INT NOT NULL PRIMARY KEY,
  geom_wkb LONGBLOB NOT NULL,
  geom_sha256 CHAR(64) CHARACTER SET ascii NOT NULL
);
INSERT INTO tmp_plot_geometrie (plot_id,geom_wkb,geom_sha256) VALUES
{values};

-- De Horsten (plot_id=29945) is bronobject, maar hoort niet in Meijendel.
INSERT INTO plot_geometrie_import (
  versiesleutel,bronbestand,bron_datum,shp_sha256,shx_sha256,dbf_sha256,prj_sha256,
  bundel_sha256,bron_objecten,geimporteerde_plots,uitgesloten_plot_id,
  uitgesloten_naam,selectieregel,actueel
) VALUES (
  '{VERSIESLEUTEL}',{sql_text(str(delivery.source))},'{delivery.bron_datum.isoformat()}',
  '{hashes['shp']}','{hashes['shx']}','{hashes['dbf']}','{hashes['prj']}',
  '{delivery.bundel_sha256}',56,55,29945,'De Horsten',
  'Neem alle project 252-polygonen over behalve plotid 29945 De Horsten; de resterende 55 IDs moeten exact overeenkomen met plots.in_gebruik=1.',1
) ON DUPLICATE KEY UPDATE plot_geometrie_import_id=LAST_INSERT_ID(plot_geometrie_import_id);
SET @plot_geom_import_id=LAST_INSERT_ID();
UPDATE plot_geometrie_import
SET actueel=(plot_geometrie_import_id=@plot_geom_import_id);

UPDATE plots p
JOIN tmp_plot_geometrie t ON t.plot_id=p.plot_id
SET p.geom=ST_GeomFromWKB(t.geom_wkb,28992),
    p.geom_sha256=t.geom_sha256,
    p.geom_bron_import_id=@plot_geom_import_id;

DELETE FROM nameninventaris_plot_koppeling
WHERE plot_geometrie_import_id=@plot_geom_import_id;
INSERT INTO nameninventaris_plot_koppeling (
  geometrie_id,plot_id,plot_geometrie_import_id,relatietype,intersectiedimensie,
  naamgeometrie_sha256,plotgeometrie_sha256,rekenregelversie
)
SELECT
  g.geometrie_id,p.plot_id,@plot_geom_import_id,
  CASE WHEN o.objectklasse='pad_of_weg' THEN 'lijn_overlap' ELSE 'oppervlakte_overlap' END,
  ST_Dimension(ST_Intersection(g.geometry,p.geom)),
  g.wkt_sha256,p.geom_sha256,'{REKENREGELVERSIE}'
FROM nameninventaris_geometrie g
JOIN nameninventaris_object o ON o.object_id=g.object_id
JOIN plots p ON p.geom_bron_import_id=@plot_geom_import_id
WHERE ST_Intersects(g.geometry,p.geom)
  AND ((o.objectklasse IN ('gebied','functioneel_gebied')
        AND ST_Dimension(ST_Intersection(g.geometry,p.geom))=2)
       OR (o.objectklasse='pad_of_weg'
        AND ST_Dimension(ST_Intersection(g.geometry,p.geom))=1));
COMMIT;
"""


def mysql_run(mysql_client: Path, login_path: str, database: str | None, sql: str) -> str:
    command = [str(mysql_client), f"--login-path={login_path}", "--protocol=tcp",
               "--host=127.0.0.1", "--port=3306", "--batch", "--raw",
               "--skip-column-names"]
    if database:
        command.append(database)
    result = subprocess.run(command, input=sql, text=True, capture_output=True, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr or result.stdout)
    return result.stdout.strip()


def database_plot_ids(mysql_client: Path, login_path: str, database: str) -> set[int]:
    output = mysql_run(
        mysql_client, login_path, database,
        "SELECT plot_id FROM plots WHERE in_gebruik=1 ORDER BY plot_id;",
    )
    return {int(value) for value in output.splitlines() if value}


def validate_existing_import(delivery: PlotDelivery, *, database: str,
                             mysql_client: Path, login_path: str) -> None:
    output = mysql_run(
        mysql_client, login_path, database,
        "SELECT bundel_sha256 FROM plot_geometrie_import "
        f"WHERE versiesleutel={sql_text(VERSIESLEUTEL)};",
    )
    if output and output != delivery.bundel_sha256:
        raise ValueError(
            f"Bronversie {VERSIESLEUTEL} bestaat al met een andere bundelhash: "
            f"database={output}, levering={delivery.bundel_sha256}"
        )


def apply_delivery(delivery: PlotDelivery, *, database: str, mysql_client: Path,
                   login_path: str) -> dict[str, int]:
    source_ids = {plot.plot_id for plot in delivery.plots}
    target_ids = database_plot_ids(mysql_client, login_path, database)
    if source_ids != target_ids:
        raise ValueError(
            "De 55 SOVON-plot-ID's na uitsluiting van De Horsten komen niet exact overeen "
            f"met plots.in_gebruik=1; alleen_bron={sorted(source_ids-target_ids)}, "
            f"alleen_database={sorted(target_ids-source_ids)}"
        )
    de_horsten = mysql_run(
        mysql_client, login_path, database,
        "SELECT COUNT(*) FROM plots WHERE plot_id=29945 OR LOWER(plot_naam)='de horsten';",
    )
    if de_horsten != "0":
        raise ValueError("De Horsten staat al in plots en wordt niet automatisch verwijderd")

    schema = SCHEMA.read_text(encoding="utf-8").replace("USE Meijendel;", f"USE `{database}`;", 1)
    mysql_run(mysql_client, login_path, None, schema)
    validate_existing_import(
        delivery,
        database=database,
        mysql_client=mysql_client,
        login_path=login_path,
    )
    mysql_run(mysql_client, login_path, None, build_import_sql(delivery, database))
    result = mysql_run(
        mysql_client, login_path, database,
        "SELECT "
        "(SELECT COUNT(*) FROM plots WHERE geom IS NOT NULL),"
        "(SELECT COUNT(*) FROM nameninventaris_plot_koppeling k "
        " JOIN plot_geometrie_import i USING (plot_geometrie_import_id) WHERE i.actueel=1),"
        "(SELECT COUNT(*) FROM v_nameninventaris_plot_actueel),"
        "(SELECT COUNT(*) FROM plots WHERE plot_id=29945 OR LOWER(plot_naam)='de horsten');",
    )
    met_geom, koppelingen, scope_koppelingen, de_horsten_count = map(int, result.split("\t"))
    if met_geom != 55 or de_horsten_count != 0:
        raise RuntimeError(f"Nacontrole mislukt: met_geom={met_geom}, De Horsten={de_horsten_count}")
    return {
        "plots_met_geometrie": met_geom,
        "koppelingen_alle_55": koppelingen,
        "koppelingen_scope_53": scope_koppelingen,
        "de_horsten": de_horsten_count,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--shp", type=Path, default=DEFAULT_SHP)
    parser.add_argument("--database", default="Meijendel")
    parser.add_argument("--mysql-client", type=Path, default=DEFAULT_MYSQL)
    parser.add_argument("--login-path", default="meijendel_root")
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()

    delivery = read_plot_delivery(args.shp)
    summary: dict[str, object] = {
        "modus": "execute" if args.execute else "dry-run",
        "bron": str(delivery.source),
        "bron_datum": delivery.bron_datum.isoformat(),
        "bron_objecten": delivery.bron_objecten,
        "geimporteerde_plots": len(delivery.plots),
        "uitgesloten": {"plot_id": delivery.uitgesloten_plot_id,
                         "naam": delivery.uitgesloten_naam},
        "bundel_sha256": delivery.bundel_sha256,
    }
    if args.execute:
        summary.update(apply_delivery(
            delivery,
            database=args.database,
            mysql_client=args.mysql_client,
            login_path=args.login_path,
        ))
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
