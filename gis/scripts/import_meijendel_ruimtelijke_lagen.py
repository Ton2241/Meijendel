#!/usr/bin/env python3
"""Importeer de ruimtelijke lagen en classificeer gelokaliseerde bronrecords."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from collections import defaultdict
from pathlib import Path

from osgeo import ogr


ogr.UseExceptions()

ROOT = Path(__file__).parents[2]
DEFAULT_GPKG = ROOT / "gis" / "vectors" / "meijendel_bereik" / "meijendel_ruimtelijke_lagen.gpkg"
DEFAULT_MANIFEST = ROOT / "gis" / "vectors" / "meijendel_bereik" / "meijendel_ruimtelijke_lagen_manifest.json"
SCHEMA = ROOT / "gis" / "database" / "meijendel_ruimtelijke_lagen_schema.sql"
RULE_VERSION = "meijendel-ruimtelijke-poort-v3"
PLOT_GEBIED_INDELING = "vogelplot-gebiedsindeling-v1"
EXPECTED_PLOT_GEBIED_COUNTS = {
    "buitenduin_noord": 9,
    "buitenduin_zuid": 7,
    "kijfhoek_en_bierlap": 16,
    "vallei_meijendel": 9,
    "zuid_oosthoek": 11,
    "haagsche_golfclub": 1,
    "voorlinden": 1,
    "hertenkamp": 1,
}
PLOT_GEBIED_PRECISION_M = 0.0001


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sql_text(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"


def force_multi(geometry: ogr.Geometry) -> ogr.Geometry:
    if geometry.GetGeometryName().upper() == "MULTIPOLYGON":
        return geometry.Clone()
    multi = ogr.Geometry(ogr.wkbMultiPolygon)
    multi.AddGeometry(geometry)
    return multi


def validate_plot_gebied_counts(counts: dict[str, int]) -> None:
    if counts != EXPECTED_PLOT_GEBIED_COUNTS:
        raise ValueError(
            "Actuele plotdekking per gebied wijkt af: "
            f"verwacht {EXPECTED_PLOT_GEBIED_COUNTS}, ontvangen {counts}"
        )
    if sum(counts.values()) != 55:
        raise ValueError(f"Actuele plotdekking moet 55 zijn, ontvangen {sum(counts.values())}")


def union_plot_geometries(plot_rows: list[tuple[int, str]]) -> ogr.Geometry:
    if not plot_rows:
        raise ValueError("Gebied zonder bronplotgeometrieën")
    union: ogr.Geometry | None = None
    seen: set[int] = set()
    for plot_id, wkb_hex in sorted(plot_rows, key=lambda row: row[0]):
        if plot_id in seen:
            raise ValueError(f"Dubbele brongeometrie voor plot {plot_id}")
        seen.add(plot_id)
        try:
            geometry = ogr.CreateGeometryFromWkb(bytes.fromhex(wkb_hex))
        except (RuntimeError, ValueError) as exc:
            raise ValueError(f"Onleesbare brongeometrie voor plot {plot_id}") from exc
        if (
            geometry is None
            or geometry.IsEmpty()
            or not geometry.IsValid()
            or geometry.GetGeometryName().upper() not in {"POLYGON", "MULTIPOLYGON"}
        ):
            raise ValueError(f"Ongeldige brongeometrie voor plot {plot_id}")
        geometry.FlattenTo2D()
        union = geometry.Clone() if union is None else union.Union(geometry)
    if union is None or union.IsEmpty() or not union.IsValid():
        raise ValueError("Topologische samenvoeging leverde geen geldige geometrie")
    union = union.SetPrecision(PLOT_GEBIED_PRECISION_M)
    union = force_multi(union)
    union.FlattenTo2D()
    if not union.IsValid():
        raise ValueError("Afgeleide multipolygon is ongeldig")
    return union


def derive_plot_gebied_geometries(
    rows: list[tuple[str, int, str]],
) -> list[tuple[str, int, float, str, str]]:
    grouped: dict[str, list[tuple[int, str]]] = defaultdict(list)
    all_plot_ids: set[int] = set()
    for gebied_code, plot_id, wkb_hex in rows:
        if plot_id in all_plot_ids:
            raise ValueError(f"Actueel plot {plot_id} komt in meer dan één gebied voor")
        all_plot_ids.add(plot_id)
        grouped[gebied_code].append((plot_id, wkb_hex))
    validate_plot_gebied_counts({code: len(values) for code, values in grouped.items()})
    derived = []
    for gebied_code in sorted(grouped):
        geometry = union_plot_geometries(grouped[gebied_code])
        wkb = bytes(geometry.ExportToWkb())
        derived.append(
            (
                gebied_code,
                len(grouped[gebied_code]),
                geometry.GetArea() / 10000.0,
                hashlib.sha256(wkb).hexdigest(),
                wkb.hex(),
            )
        )
    return derived


def read_single_geometry(path: Path, layer_name: str) -> tuple[ogr.Geometry, dict]:
    dataset = ogr.Open(str(path), 0)
    if dataset is None:
        raise ValueError(f"GeoPackage niet leesbaar: {path}")
    layer = dataset.GetLayerByName(layer_name)
    if layer is None or layer.GetFeatureCount() != 1:
        raise ValueError(f"Laag {layer_name} moet precies één object bevatten")
    feature = next(iter(layer))
    geometry = force_multi(feature.GetGeometryRef().Clone())
    values = {
        layer.GetLayerDefn().GetFieldDefn(i).GetName(): feature.GetField(i)
        for i in range(layer.GetLayerDefn().GetFieldCount())
    }
    return geometry, values


def run_mysql(mysql: str, mysql_args: list[str], sql: str) -> None:
    result = subprocess.run(
        [mysql, *mysql_args], input=sql, text=True, capture_output=True, check=False
    )
    if result.returncode:
        raise RuntimeError(result.stderr or result.stdout)


def query_mysql(mysql: str, mysql_args: list[str], sql: str) -> str:
    result = subprocess.run(
        [mysql, *mysql_args, "--batch", "--raw", "--skip-column-names"],
        input=sql,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode:
        raise RuntimeError(result.stderr or result.stdout)
    return result.stdout.strip()


def load_plot_gebied_source(
    mysql: str, mysql_args: list[str]
) -> tuple[str, int, list[tuple[str, int, str]]]:
    output = query_mysql(
        mysql,
        mysql_args,
        f"""
SELECT i.indeling_code,i.plotversie_id,v.versie,l.gebied_code,l.plot_id,
       HEX(ST_AsWKB(p.plot_geometrie))
FROM Meijendel.plot_gebiedsindeling i
JOIN Meijendel.ndff_sovon_plotversie v USING (plotversie_id)
JOIN Meijendel.plot_gebied_lidmaatschap l USING (indeling_code)
JOIN Meijendel.ndff_sovon_plot p
  ON p.plotversie_id=i.plotversie_id AND p.plot_id=l.plot_id
WHERE i.indeling_code={sql_text(PLOT_GEBIED_INDELING)}
  AND i.status='vastgesteld'
  AND l.lidmaatschap_status='actueel_met_geometrie'
ORDER BY l.gebied_code,l.plot_id;
""",
    )
    parsed = [line.split("\t") for line in output.splitlines() if line]
    if len(parsed) != 55:
        raise ValueError(f"Verwacht 55 actuele plotgeometrieën, ontvangen {len(parsed)}")
    identities = {(row[0], int(row[1]), row[2]) for row in parsed}
    if identities != {(PLOT_GEBIED_INDELING, int(parsed[0][1]), "2025")}:
        raise ValueError(f"Onverwachte indeling of plotversie: {sorted(identities)}")
    plotversie_id = int(parsed[0][1])
    rows = [(row[3], int(row[4]), row[5]) for row in parsed]
    return PLOT_GEBIED_INDELING, plotversie_id, rows


def plot_gebied_geometrie_sql(
    indeling_code: str,
    plotversie_id: int,
    derived: list[tuple[str, int, float, str, str]],
) -> str:
    if len(derived) != 8:
        raise ValueError(f"Verwacht acht gebiedsgeometrieën, ontvangen {len(derived)}")
    values = ",\n".join(
        "(" + ",".join(
            (
                sql_text(indeling_code),
                sql_text(gebied_code),
                str(plotversie_id),
                f"ST_GeomFromWKB(UNHEX({sql_text(wkb_hex)}),28992)",
                str(bronplot_aantal),
                f"{oppervlakte_ha:.6f}",
                sql_text(geometrie_sha256),
            )
        ) + ")"
        for gebied_code, bronplot_aantal, oppervlakte_ha, geometrie_sha256, wkb_hex in derived
    )
    return f"""
USE Meijendel;
START TRANSACTION;
DELETE FROM plot_gebied_geometrie
WHERE indeling_code={sql_text(indeling_code)} AND plotversie_id={plotversie_id};
INSERT INTO plot_gebied_geometrie
  (indeling_code,gebied_code,plotversie_id,gebied_geometrie,bronplot_aantal,
   oppervlakte_ha,geometrie_sha256)
VALUES
{values};
COMMIT;
"""


def apply_plot_gebieden_only(
    mysql: str,
    mysql_args: list[str],
    *,
    source_loader=load_plot_gebied_source,
    writer=run_mysql,
) -> str:
    indeling_code, plotversie_id, rows = source_loader(mysql, mysql_args)
    derived = derive_plot_gebied_geometries(rows)
    writer(
        mysql,
        [*mysql_args, "--show-warnings"],
        plot_gebied_geometrie_sql(indeling_code, plotversie_id, derived),
    )
    return (
        f"OK: {indeling_code}, plotversie {plotversie_id}, "
        f"55 geldige bronplots en {len(derived)} gebiedsgeometrieën geschreven"
    )


def boundary_sql(gpkg: Path, manifest: dict) -> str:
    basis, basis_fields = read_single_geometry(gpkg, "meijendel_basisgebied")
    natura, natura_fields = read_single_geometry(gpkg, "meijendel_natura2000")
    gpkg_hash = sha256_file(gpkg)
    version = manifest["versie"]
    return f"""
USE Meijendel;
START TRANSACTION;
INSERT INTO meijendel_basisgebied_versie
  (versie,bronbestand,bronbestand_sha256,projectgeometrie_sha256,crs_epsg,oppervlakte_ha,status)
VALUES
  ({sql_text(version)},{sql_text(str(gpkg.resolve()))},{sql_text(gpkg_hash)},
   {sql_text(manifest['projectgebied_sha256_wkb'])},28992,{float(basis_fields['oppervlakte_ha'])},'vastgesteld')
ON DUPLICATE KEY UPDATE
  bronbestand=VALUES(bronbestand), bronbestand_sha256=VALUES(bronbestand_sha256),
  projectgeometrie_sha256=VALUES(projectgeometrie_sha256),
  oppervlakte_ha=VALUES(oppervlakte_ha), status='vastgesteld';
SET @basisversie := (SELECT basisgebiedversie_id FROM meijendel_basisgebied_versie WHERE versie={sql_text(version)});
INSERT INTO meijendel_basisgebied
  (basisgebiedversie_id,gebied_id,naam,gebied_geometrie)
VALUES
  (@basisversie,1,'Meijendel projectgebied',ST_GeomFromText({sql_text(basis.ExportToWkt())},28992))
ON DUPLICATE KEY UPDATE naam=VALUES(naam), gebied_geometrie=VALUES(gebied_geometrie);

INSERT INTO meijendel_natura2000_versie
  (versie,bronbestand,bronbestand_sha256,gebiedsnummer,crs_epsg,oppervlakte_ha)
VALUES
  ({sql_text(version)},{sql_text(str(gpkg.resolve()))},{sql_text(gpkg_hash)},
   {int(natura_fields['n2000_nr'])},28992,{float(natura_fields['oppervlakte_ha'])})
ON DUPLICATE KEY UPDATE bronbestand=VALUES(bronbestand),
  bronbestand_sha256=VALUES(bronbestand_sha256), oppervlakte_ha=VALUES(oppervlakte_ha);
SET @naturaversie := (SELECT natura2000versie_id FROM meijendel_natura2000_versie WHERE versie={sql_text(version)});
INSERT INTO meijendel_natura2000
  (natura2000versie_id,gebiedsnummer,naam,gebied_geometrie)
VALUES
  (@naturaversie,{int(natura_fields['n2000_nr'])},{sql_text(str(natura_fields['naam']))},
   ST_GeomFromText({sql_text(natura.ExportToWkt())},28992))
ON DUPLICATE KEY UPDATE naam=VALUES(naam), gebied_geometrie=VALUES(gebied_geometrie);
COMMIT;
"""


def relation_case(alias: str, area_alias: str) -> str:
    return f"""CASE
      WHEN NOT ST_IsValid({alias}.geom) THEN 'ongeldig'
      WHEN ST_Within({alias}.geom,{area_alias}.gebied_geometrie) THEN 'volledig_binnen'
      WHEN ST_Intersects({alias}.geom,{area_alias}.gebied_geometrie) THEN 'raakt_grens'
      ELSE 'buiten' END"""


def admission_case(alias: str, area_alias: str) -> str:
    return f"""CASE
      WHEN NOT ST_IsValid({alias}.geom) THEN 'geen_lokalisatie'
      WHEN ST_Within({alias}.geom,{area_alias}.gebied_geometrie) THEN 'toegelaten'
      WHEN ST_Intersects({alias}.geom,{area_alias}.gebied_geometrie) THEN 'ruimtelijk_dubbelzinnig'
      ELSE 'buiten_projectgebied' END"""


def reason_case(alias: str, area_alias: str, location_method: str) -> str:
    readable = location_method.replace("_", " ")
    return f"""CASE
      WHEN NOT ST_IsValid({alias}.geom) THEN 'Brongeometrie is ongeldig.'
      WHEN ST_Within({alias}.geom,{area_alias}.gebied_geometrie)
        THEN 'De {readable} ligt volledig binnen het geversioneerde projectgebied.'
      WHEN ST_Intersects({alias}.geom,{area_alias}.gebied_geometrie)
        THEN 'De {readable} raakt alleen de projectgrens; dit bewijst geen aanwezigheid binnen Meijendel.'
      ELSE 'De {readable} ligt buiten het geversioneerde projectgebied.' END"""


def classify_temp_sql(source_table: str, location_method: str, *, reuse_ndff_plot: bool = False) -> str:
    if reuse_ndff_plot:
        plot_join = """
LEFT JOIN ndff_open_ruimtelijke_beoordeling r
  ON r.waarneming_id=CAST(s.bron_record_id AS UNSIGNED)
 AND r.regelversie='ndff-protocolkwaliteit-v1'"""
        plot_count = "COALESCE(r.plot_match_count,0)"
        plot_id = "r.eenduidig_plot_id"
    else:
        plot_join = "LEFT JOIN tmp_meijendel_plotmatch pm ON pm.bron_record_id=s.bron_record_id"
        plot_count = "pm.plot_count"
        plot_id = "pm.plot_id"
    plot_update = "" if reuse_ndff_plot else """
TRUNCATE TABLE tmp_meijendel_plotmatch;
INSERT INTO tmp_meijendel_plotmatch (bron_record_id,plot_count,plot_id)
SELECT s.bron_record_id,COUNT(p.plot_id),
       CASE WHEN COUNT(p.plot_id)=1 THEN MAX(p.plot_id) ELSE NULL END
FROM tmp_meijendel_ruimtelijke_bron s
LEFT JOIN v_meijendel_sovon_plot_actueel p
  ON MBRIntersects(s.geom,p.plot_geometrie)
 AND ST_Intersects(s.geom,p.plot_geometrie)
GROUP BY s.bron_record_id;
"""
    return f"""
{plot_update}
DELETE FROM meijendel_waarneming_ruimtelijke_status
WHERE bron_tabel={sql_text(source_table)} AND regelversie={sql_text(RULE_VERSION)};
INSERT INTO meijendel_waarneming_ruimtelijke_status
  (bron_tabel,bron_record_id,regelversie,basisgebiedversie_id,natura2000versie_id,
   plotversie_id,locatiemethode,basisstatus,natura2000status,sovon_plot_count,
   eenduidig_plot_id,toelatingsstatus,reden)
SELECT {sql_text(source_table)},s.bron_record_id,{sql_text(RULE_VERSION)},
       b.basisgebiedversie_id,n.natura2000versie_id,
       (SELECT MAX(plotversie_id) FROM ndff_sovon_plotversie),
       {sql_text(location_method)},
       {relation_case('s','b')},{relation_case('s','n')},
       {plot_count},{plot_id},{admission_case('s','b')},
       {reason_case('s','b',location_method)}
FROM tmp_meijendel_ruimtelijke_bron s
CROSS JOIN v_meijendel_basisgebied_actueel b
CROSS JOIN v_meijendel_natura2000_actueel n
{plot_join};
"""


def status_sql() -> str:
    parts = ["""
USE Meijendel;
DROP TEMPORARY TABLE IF EXISTS tmp_meijendel_ruimtelijke_bron;
CREATE TEMPORARY TABLE tmp_meijendel_ruimtelijke_bron (
  bron_record_id VARCHAR(128) CHARACTER SET ascii NOT NULL,
  geom GEOMETRY NOT NULL SRID 28992,
  PRIMARY KEY (bron_record_id),
  SPATIAL KEY sx_tmp_meijendel_geom (geom)
) ENGINE=InnoDB;
DROP TEMPORARY TABLE IF EXISTS tmp_meijendel_plotmatch;
CREATE TEMPORARY TABLE tmp_meijendel_plotmatch (
  bron_record_id VARCHAR(128) CHARACTER SET ascii NOT NULL,
  plot_count SMALLINT UNSIGNED NOT NULL,
  plot_id INT NULL,
  PRIMARY KEY (bron_record_id)
) ENGINE=InnoDB;
"""]
    sources = [
        ("ndff_open_waarneming", "bronpolygoon", "SELECT CAST(waarneming_id AS CHAR),openbare_geometrie FROM ndff_open_waarneming", True),
        ("dagwaarnemingen_bmp", "exact_punt", "SELECT CAST(id AS CHAR),ST_SRID(geom,28992) FROM dagwaarnemingen_bmp", False),
        ("dagwaarnemingen_wv", "exact_punt", "SELECT CAST(id AS CHAR),geom FROM dagwaarnemingen_wv", False),
        ("pq_vegetatie_opname", "exact_punt", "SELECT CAST(opname_id AS CHAR),geom FROM pq_vegetatie_opname", False),
        ("sovon_avimap_waarneming", "exact_punt", "SELECT CONCAT(batch_id,':',bron_waarneming_id),geom FROM sovon_avimap_waarneming", False),
        ("vangblik_event", "exact_punt", "SELECT e.event_id,l.locatiepunt FROM vangblik_event e JOIN vangblik_locatieversie l USING (locatieversie_id)", False),
    ]
    for source_table, method, selection, reuse in sources:
        parts.extend((
            "TRUNCATE TABLE tmp_meijendel_ruimtelijke_bron;",
            f"INSERT INTO tmp_meijendel_ruimtelijke_bron (bron_record_id,geom) {selection};",
            classify_temp_sql(source_table, method, reuse_ndff_plot=reuse),
        ))

    parts.append(f"""
DELETE FROM meijendel_waarneming_ruimtelijke_status
WHERE bron_tabel='territoria' AND regelversie={sql_text(RULE_VERSION)};
INSERT INTO meijendel_waarneming_ruimtelijke_status
  (bron_tabel,bron_record_id,regelversie,basisgebiedversie_id,natura2000versie_id,
   plotversie_id,locatiemethode,basisstatus,natura2000status,sovon_plot_count,
   eenduidig_plot_id,toelatingsstatus,reden)
SELECT 'territoria',CAST(t.id AS CHAR),{sql_text(RULE_VERSION)},
       b.basisgebiedversie_id,n.natura2000versie_id,p.plotversie_id,'plotvlak',
       CASE WHEN ST_Within(p.plot_geometrie,b.gebied_geometrie) THEN 'volledig_binnen'
            WHEN ST_Intersects(p.plot_geometrie,b.gebied_geometrie) THEN 'raakt_grens' ELSE 'buiten' END,
       CASE WHEN ST_Within(p.plot_geometrie,n.gebied_geometrie) THEN 'volledig_binnen'
            WHEN ST_Intersects(p.plot_geometrie,n.gebied_geometrie) THEN 'raakt_grens' ELSE 'buiten' END,
       1,t.plot_id,
       CASE WHEN ST_Within(p.plot_geometrie,b.gebied_geometrie) THEN 'toegelaten'
            WHEN ST_Intersects(p.plot_geometrie,b.gebied_geometrie) THEN 'ruimtelijk_dubbelzinnig'
            ELSE 'buiten_projectgebied' END,
       CASE WHEN ST_Within(p.plot_geometrie,b.gebied_geometrie)
              THEN 'Het volledige SOVON-plot ligt binnen het geversioneerde projectgebied.'
            WHEN ST_Intersects(p.plot_geometrie,b.gebied_geometrie)
              THEN 'Het SOVON-plot ligt slechts gedeeltelijk binnen het projectgebied; de territoriumregel heeft geen exact punt.'
            ELSE 'Het SOVON-plot ligt buiten het geversioneerde projectgebied.' END
FROM territoria t
JOIN v_meijendel_sovon_plot_actueel p ON p.plot_id=t.plot_id
CROSS JOIN v_meijendel_basisgebied_actueel b
CROSS JOIN v_meijendel_natura2000_actueel n;
""")
    parts.append(f"""
DELETE FROM meijendel_waarneming_ruimtelijke_status
WHERE bron_tabel IN ('duinvallei_opname','vogelstand_1924')
  AND regelversie={sql_text(RULE_VERSION)};
INSERT INTO meijendel_waarneming_ruimtelijke_status
  (bron_tabel,bron_record_id,regelversie,basisgebiedversie_id,natura2000versie_id,
   plotversie_id,locatiemethode,basisstatus,natura2000status,sovon_plot_count,
   eenduidig_plot_id,toelatingsstatus,reden)
SELECT 'duinvallei_opname',CAST(o.opname_id AS CHAR),{sql_text(RULE_VERSION)},
       b.basisgebiedversie_id,n.natura2000versie_id,p.plotversie_id,'benoemde_locatie',
       'geen_geometrie','geen_geometrie',0,NULL,'geen_lokalisatie',
       'De opname heeft een stabiele locatiecode, maar nog geen per opname gekoppelde geometrie.'
FROM duinvallei_opname o
CROSS JOIN v_meijendel_basisgebied_actueel b
CROSS JOIN v_meijendel_natura2000_actueel n
CROSS JOIN (SELECT MAX(plotversie_id) plotversie_id FROM ndff_sovon_plotversie) p;
INSERT INTO meijendel_waarneming_ruimtelijke_status
  (bron_tabel,bron_record_id,regelversie,basisgebiedversie_id,natura2000versie_id,
   plotversie_id,locatiemethode,basisstatus,natura2000status,sovon_plot_count,
   eenduidig_plot_id,toelatingsstatus,reden)
SELECT 'vogelstand_1924',CAST(v.id AS CHAR),{sql_text(RULE_VERSION)},
       b.basisgebiedversie_id,n.natura2000versie_id,p.plotversie_id,'geen',
       'geen_geometrie','geen_geometrie',0,NULL,'context_alleen',
       'Historische contextregel zonder afzonderlijke waarnemingsgeometrie.'
FROM vogelstand_1924 v
CROSS JOIN v_meijendel_basisgebied_actueel b
CROSS JOIN v_meijendel_natura2000_actueel n
CROSS JOIN (SELECT MAX(plotversie_id) plotversie_id FROM ndff_sovon_plotversie) p;
DROP TEMPORARY TABLE IF EXISTS tmp_meijendel_plotmatch;
DROP TEMPORARY TABLE IF EXISTS tmp_meijendel_ruimtelijke_bron;
""")
    return "\n".join(parts)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gpkg", type=Path, default=DEFAULT_GPKG)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--mysql", default="/usr/local/mysql/bin/mysql")
    parser.add_argument("--login-path", default="meijendel_root")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--apply-plot-gebieden", action="store_true")
    parser.add_argument("--audit-plot-gebieden", action="store_true")
    parser.add_argument("--sql-output", type=Path)
    args = parser.parse_args()
    from import_external_ecology_sources import central_query_guarded_operation
    return central_query_guarded_operation(
        lambda: execute_main(args),
        enabled=args.apply or args.apply_plot_gebieden,
        login_path=args.login_path,
        client=args.mysql,
    )


def execute_main(args) -> int:
    if args.apply and args.apply_plot_gebieden:
        raise ValueError("Gebruik --apply of --apply-plot-gebieden, niet beide")
    mysql_args = [f"--login-path={args.login_path}", '--protocol=TCP',
                  '--host=127.0.0.1','--port=3306']
    if args.apply_plot_gebieden:
        print(apply_plot_gebieden_only(args.mysql, mysql_args))
        return 0
    if args.audit_plot_gebieden and not args.apply:
        indeling_code, plotversie_id, rows = load_plot_gebied_source(args.mysql, mysql_args)
        derived = derive_plot_gebied_geometries(rows)
        print(
            f"OK: {indeling_code}, plotversie {plotversie_id}, "
            f"55 geldige bronplots en {len(derived)} afleidbare gebiedsgeometrieën"
        )
        return 0
    for path in (args.gpkg, args.manifest, SCHEMA):
        if not path.exists():
            raise FileNotFoundError(path)
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    sql = "\n".join((SCHEMA.read_text(encoding="utf-8"), boundary_sql(args.gpkg, manifest), status_sql()))
    if args.sql_output:
        args.sql_output.write_text(sql, encoding="utf-8")
    if not args.apply:
        print("DRY RUN: SQL opgebouwd; gebruik --apply om de lokale Meijendel-database te wijzigen.")
        return 0
    run_mysql(args.mysql, [*mysql_args,"--show-warnings"], sql)
    indeling_code, plotversie_id, rows = load_plot_gebied_source(args.mysql, mysql_args)
    derived = derive_plot_gebied_geometries(rows)
    run_mysql(
        args.mysql,
        [*mysql_args,"--show-warnings"],
        plot_gebied_geometrie_sql(indeling_code, plotversie_id, derived),
    )
    print(
        f"OK: ruimtelijke lagen en statusregels geïmporteerd ({RULE_VERSION}); "
        f"{len(derived)} plotgebiedsgeometrieën afgeleid"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
