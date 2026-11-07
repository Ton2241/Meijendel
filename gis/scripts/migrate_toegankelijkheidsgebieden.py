#!/usr/bin/env python3
"""Vervang voorlopige kaveltoegang door bronvaste gebiedspolygonen."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from typing import Any

from osgeo import ogr

ogr.UseExceptions()


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis/database/maatregelen_schema.sql"
_WORKTREE_GPKG = ROOT / "outputs/qfield_afscheidingen/meijendel_afscheidingen/veldwerk.gpkg"
_CANONICAL_GPKG = Path("/Users/ton/Documents/GitHub/Meijendel/outputs/qfield_afscheidingen/meijendel_afscheidingen/veldwerk.gpkg")
DEFAULT_GPKG = _WORKTREE_GPKG if _WORKTREE_GPKG.is_file() else _CANONICAL_GPKG
DEFAULT_FEATURE_ID = "2b3ae5c9-1ef6-4d82-9247-470fcc8054f6"
BACKUP_ROOT = Path("/Volumes/T7 Data/Home_Ton/Meijendel data/Backups-archief/Meijendel")
STATUS_CODES = ("afgesloten", "toegankelijk", "toegankelijk_met_toegangskaart")
MIGRATION_VERSION = "toegankelijkheidsgebieden-v1"
SOURCE_CODE = "garmin_veldregistratie_20261107"
AREA_CODE = "garmin_24999201739_omsloten_gebied"


def sql_literal(value: Any) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("\\", "\\\\").replace("'", "''") + "'"


def read_area_feature(path: Path, feature_id: str) -> dict[str, Any]:
    dataset = ogr.Open(str(path), 0)
    if dataset is None:
        raise ValueError(f"GeoPackage niet leesbaar: {path}")
    layer = dataset.GetLayerByName("gebieden")
    if layer is None:
        raise ValueError("Laag gebieden ontbreekt")
    layer.SetAttributeFilter(f"id = '{feature_id.replace(chr(39), chr(39) * 2)}'")
    features = list(layer)
    if len(features) != 1:
        raise ValueError(f"Verwacht één gebied {feature_id}, gevonden {len(features)}")
    feature = features[0]
    geometry = feature.GetGeometryRef().Clone()
    srs = layer.GetSpatialRef()
    epsg = int(srs.GetAuthorityCode(None)) if srs and srs.GetAuthorityCode(None) else None
    if epsg != 28992:
        raise ValueError(f"Gebied heeft EPSG:{epsg}, verwacht EPSG:28992")
    if not geometry.IsValid():
        raise ValueError("Gebiedsgeometrie is ongeldig")
    geometry = ogr.ForceToMultiPolygon(geometry)
    if geometry is None or geometry.GetGeometryName().upper() != "MULTIPOLYGON":
        raise ValueError("Gebiedsgeometrie is geen vlak")
    status = feature.GetField("categorie")
    if status not in STATUS_CODES:
        raise ValueError(f"Ongeldige gebiedsstatus: {status}")
    wkb = bytes(geometry.ExportToWkb(ogr.wkbNDR))
    return {
        "feature_id": feature_id,
        "status_code": status,
        "epsg": epsg,
        "geometry_type": geometry.GetGeometryName().upper(),
        "is_valid": bool(geometry.IsValid()),
        "wkt": geometry.ExportToIsoWkt(),
        "geometrie_sha256": hashlib.sha256(wkb).hexdigest(),
        "oppervlakte_m2": float(geometry.GetArea()),
        "datum_tijd": feature.GetFieldAsString("datum_tijd"),
        "bron": feature.GetFieldAsString("bron"),
        "ontvanger": feature.GetFieldAsString("ontvanger"),
        "nauwkeurigheid_m": feature.GetField("nauwkeurigheid_m"),
        "opmerking": feature.GetFieldAsString("opmerking"),
    }


def area_schema_sql() -> str:
    sql = SCHEMA.read_text(encoding="utf-8")
    start = sql.index("CREATE TABLE IF NOT EXISTS toegankelijkheidsstatus")
    end = sql.index("-- Uitsluitend herkomstmetadata", start)
    return sql[start:end].strip()


def build_migration_statements(feature: dict[str, Any]) -> list[str]:
    accuracy = feature["nauwkeurigheid_m"]
    return [
        "INSERT INTO maatregel_brontype (brontype_code,landelijke_broncategorie,omschrijving) "
        "VALUES ('veldregistratie','IBC99','Veldregistratie of daarvan afgeleide geometrie') "
        "ON DUPLICATE KEY UPDATE omschrijving=VALUES(omschrijving)",
        area_schema_sql(),
        "INSERT INTO maatregel_bron "
        "(bron_code,brontype_code,titel,bron_datum,raadpleegdatum,bronstatus,opmerking) VALUES ("
        f"'{SOURCE_CODE}','veldregistratie','Garmin-veldregistratie omsloten gebied',"
        "'2026-11-07','2026-11-07','door gebruiker bevestigd',"
        "'Garmin Connect-activiteit 24999201739; afgeleide QField-geometrie') "
        "ON DUPLICATE KEY UPDATE titel=VALUES(titel),bronstatus=VALUES(bronstatus),opmerking=VALUES(opmerking)",
        "INSERT INTO toegankelijkheidsgebied (gebied_code,naam,opmerking) VALUES ("
        f"'{AREA_CODE}','Omsloten gebied Garmin-route 7 november 2026',"
        "'Door Ton bevestigd als daadwerkelijk omsloten gebied') "
        "ON DUPLICATE KEY UPDATE naam=VALUES(naam),opmerking=VALUES(opmerking)",
        "INSERT INTO toegankelijkheidsgebied_versie "
        "(gebied_id,versienummer,status_code,geldig_vanaf,geldig_tot,vastgesteld_op,bron_id,"
        "bron_object_id,inwinningsmethode,nauwkeurigheid_m,geometrie,geometrie_wkt,"
        "geometrie_sha256,oppervlakte_m2,geometrie_opmerking) SELECT "
        f"g.gebied_id,1,{sql_literal(feature['status_code'])},'1955-01-01',NULL,'2026-11-07',"
        f"b.bron_id,{sql_literal(feature['feature_id'])},'Garmin-route; vlak afgeleid in QField',"
        f"{sql_literal(accuracy)},ST_GeomFromText({sql_literal(feature['wkt'])},28992),"
        f"{sql_literal(feature['wkt'])},{sql_literal(feature['geometrie_sha256'])},"
        f"{feature['oppervlakte_m2']:.3f},{sql_literal(feature['opmerking'])} "
        "FROM toegankelijkheidsgebied g JOIN maatregel_bron b "
        f"ON b.bron_code='{SOURCE_CODE}' WHERE g.gebied_code='{AREA_CODE}' "
        "ON DUPLICATE KEY UPDATE status_code=VALUES(status_code),geldig_vanaf=VALUES(geldig_vanaf),"
        "geldig_tot=VALUES(geldig_tot),vastgesteld_op=VALUES(vastgesteld_op),"
        "geometrie=VALUES(geometrie),geometrie_wkt=VALUES(geometrie_wkt),"
        "geometrie_sha256=VALUES(geometrie_sha256),oppervlakte_m2=VALUES(oppervlakte_m2),"
        "geometrie_opmerking=VALUES(geometrie_opmerking)",
        "DELETE FROM toegankelijkheidsgebied_plot_afleiding",
        "INSERT INTO toegankelijkheidsgebied_plot_afleiding "
        "(gebied_versie_id,plot_id,status_code,doorsnijding_m2,plot_oppervlakte_m2,aandeel_pct,"
        "gebied_geometrie_sha256,plot_geometrie_sha256) "
        "SELECT v.gebied_versie_id,p.plot_id,v.status_code,"
        "ST_Area(ST_Intersection(v.geometrie,p.geom)),ST_Area(p.geom),"
        "LEAST(100,100*ST_Area(ST_Intersection(v.geometrie,p.geom))/ST_Area(p.geom)),"
        "v.geometrie_sha256,p.geom_sha256 FROM toegankelijkheidsgebied_versie v JOIN plots p "
        "ON p.geom IS NOT NULL AND ST_Intersects(v.geometrie,p.geom) "
        "AND ST_Dimension(ST_Intersection(v.geometrie,p.geom))=2 "
        "WHERE v.geldig_tot IS NULL AND ST_IsValid(p.geom) AND ST_Area(p.geom)>0 "
        "",
        "DELETE FROM maatregel_registratie_herkomst WHERE toegang_registratie_id IS NOT NULL",
        "DROP TABLE maatregel_toegankelijkheid_registratie",
    ]


class Client:
    def __init__(self, database: str) -> None:
        self.database = database
        self.mysql = shutil.which("mysql") or "/usr/local/mysql-9.7.4-macos15-arm64/bin/mysql"
        self.mysqldump = shutil.which("mysqldump") or "/usr/local/mysql-9.7.4-macos15-arm64/bin/mysqldump"

    def command(self, executable: str | None = None) -> list[str]:
        return [executable or self.mysql, "--login-path=meijendel_root", "--batch", "--raw", "--skip-column-names", self.database]

    def dump_command(self) -> list[str]:
        return [self.mysqldump, "--login-path=meijendel_root"]

    def sql(self, statement: str) -> str:
        result = subprocess.run(self.command(), input=statement, text=True, capture_output=True, check=False)
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip())
        return result.stdout.strip()

    def scalar(self, statement: str) -> str:
        result = subprocess.run(
            self.command() + ["-e", statement],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip())
        return result.stdout.strip()


def ensure_backup_dir(path: Path) -> Path:
    resolved = path.expanduser().resolve()
    if not os.path.ismount("/Volumes/T7 Data"):
        raise RuntimeError("T7 is niet gemount")
    if resolved != BACKUP_ROOT.resolve() and BACKUP_ROOT.resolve() not in resolved.parents:
        raise RuntimeError(f"Back-up moet onder {BACKUP_ROOT} staan")
    resolved.mkdir(parents=True, exist_ok=True)
    return resolved


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def backup(client: Client, backup_dir: Path, feature: dict[str, Any]) -> Path:
    backup_dir = ensure_backup_dir(backup_dir)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    sql_path = backup_dir / f"meijendel-toegankelijkheid-voor-migratie-{stamp}.sql"
    command = client.dump_command() + [
        "--no-tablespaces",
        "--single-transaction",
        "--quick",
        "--complete-insert",
        "--set-gtid-purged=OFF",
        client.database,
        "maatregel_toegankelijkheid_registratie",
        "maatregel_registratie_herkomst",
    ]
    with sql_path.open("wb") as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.PIPE, check=False)
    if result.returncode or sql_path.stat().st_size == 0:
        sql_path.unlink(missing_ok=True)
        raise RuntimeError(result.stderr.decode("utf-8", "replace").strip() or "Back-up is leeg")
    digest = sha256(sql_path)
    metadata = {
        "database": client.database,
        "gemaakt_op": dt.datetime.now().astimezone().isoformat(),
        "sql_bestand": sql_path.name,
        "sql_sha256": digest,
        "sql_bytes": sql_path.stat().st_size,
        "oude_toegankelijkheidsregels": int(client.scalar("SELECT COUNT(*) FROM maatregel_toegankelijkheid_registratie")),
        "oude_toegankelijkheidsherkomsten": int(client.scalar("SELECT COUNT(*) FROM maatregel_registratie_herkomst WHERE toegang_registratie_id IS NOT NULL")),
        "beheerregistraties": int(client.scalar("SELECT COUNT(*) FROM maatregel_plot_jaar_registratie")),
        "qfield_feature_id": feature["feature_id"],
        "qfield_geometrie_sha256": feature["geometrie_sha256"],
    }
    metadata_path = sql_path.with_suffix(".json")
    metadata_path.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    sql_path.with_suffix(".sha256").write_text(f"{digest}  {sql_path.name}\n", encoding="ascii")
    if sha256(sql_path) != digest:
        raise RuntimeError("Back-uphash is niet reproduceerbaar")
    return metadata_path


def validate_retirement_counts(old_rows: int, origins: int) -> None:
    if old_rows != 55 or origins not in (0, 55):
        raise RuntimeError(f"Verwacht 55 voorlopige regels en 55 of reeds verwijderde herkomsten, gevonden {old_rows}/{origins}")


def retire_old_model(client: Client) -> None:
    if int(client.scalar("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='maatregel_toegankelijkheid_registratie' AND table_type='BASE TABLE'")) == 0:
        return
    old_rows = int(client.scalar("SELECT COUNT(*) FROM maatregel_toegankelijkheid_registratie"))
    origins = int(client.scalar("SELECT COUNT(*) FROM maatregel_registratie_herkomst WHERE toegang_registratie_id IS NOT NULL"))
    validate_retirement_counts(old_rows, origins)
    if origins:
        client.sql("DELETE FROM maatregel_registratie_herkomst WHERE toegang_registratie_id IS NOT NULL")
    fk_rows = client.sql(
        "SELECT CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='maatregel_registratie_herkomst' "
        "AND COLUMN_NAME='toegang_registratie_id' AND REFERENCED_TABLE_NAME IS NOT NULL"
    ).splitlines()
    for name in fk_rows:
        client.sql(f"ALTER TABLE maatregel_registratie_herkomst DROP FOREIGN KEY `{name}`")
    checks = client.sql(
        "SELECT tc.CONSTRAINT_NAME FROM information_schema.TABLE_CONSTRAINTS tc "
        "JOIN information_schema.CHECK_CONSTRAINTS cc USING(CONSTRAINT_SCHEMA,CONSTRAINT_NAME) "
        "WHERE tc.CONSTRAINT_SCHEMA=DATABASE() AND tc.TABLE_NAME='maatregel_registratie_herkomst' "
        "AND cc.CHECK_CLAUSE LIKE '%toegang_registratie_id%'"
    ).splitlines()
    for name in checks:
        client.sql(f"ALTER TABLE maatregel_registratie_herkomst DROP CHECK `{name}`")
    client.sql("ALTER TABLE maatregel_registratie_herkomst DROP COLUMN toegang_registratie_id")
    client.sql(
        "ALTER TABLE maatregel_registratie_herkomst ADD CONSTRAINT chk_mrh_precies_een_doel "
        "CHECK ((beheer_registratie_id IS NOT NULL)+(uitvoering_id IS NOT NULL)=1)"
    )
    client.sql("DROP TABLE maatregel_toegankelijkheid_registratie")


def apply(client: Client, feature: dict[str, Any]) -> None:
    statements = build_migration_statements(feature)
    for statement in statements[:7]:
        client.sql(statement)
    retire_old_model(client)


def verify(client: Client, feature: dict[str, Any]) -> dict[str, Any]:
    result = {
        "oude_tabel": int(client.scalar("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='maatregel_toegankelijkheid_registratie' AND table_type='BASE TABLE'")),
        "oude_herkomstkolom": int(client.scalar("SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name='maatregel_registratie_herkomst' AND column_name='toegang_registratie_id'")),
        "beheerregistraties": int(client.scalar("SELECT COUNT(*) FROM maatregel_plot_jaar_registratie")),
        "herkomsten": int(client.scalar("SELECT COUNT(*) FROM maatregel_registratie_herkomst")),
        "gebieden": int(client.scalar("SELECT COUNT(*) FROM toegankelijkheidsgebied")),
        "gebiedsversies": int(client.scalar("SELECT COUNT(*) FROM toegankelijkheidsgebied_versie")),
        "plotdoorsnijdingen": int(client.scalar("SELECT COUNT(*) FROM toegankelijkheidsgebied_plot_afleiding")),
        "bron101_beheer": int(client.scalar("SELECT COUNT(*) FROM maatregel_plot_jaar_registratie WHERE bron_id=101")),
    }
    if result["oude_tabel"] or result["oude_herkomstkolom"]:
        raise AssertionError(result)
    if result["beheerregistraties"] != 139 or result["herkomsten"] != 144 or result["bron101_beheer"] != 139:
        raise AssertionError(result)
    row = client.sql(
        "SELECT status_code,geldig_vanaf,IF(geldig_tot IS NULL,'NULL',geldig_tot),"
        "ST_SRID(geometrie),ST_IsValid(geometrie),ROUND(ST_Area(geometrie),3),geometrie_sha256 "
        "FROM toegankelijkheidsgebied_versie WHERE bron_object_id=" + sql_literal(feature["feature_id"])
    ).split("\t")
    if row[:5] != ["afgesloten", "1955-01-01", "NULL", "28992", "1"]:
        raise AssertionError(row)
    if row[6] != feature["geometrie_sha256"] or abs(float(row[5]) - feature["oppervlakte_m2"]) > 0.01:
        raise AssertionError(row)
    if result["plotdoorsnijdingen"] < 1:
        raise AssertionError("Geen kavels door gebied doorsneden")
    bad = int(client.scalar("SELECT COUNT(*) FROM toegankelijkheidsgebied_plot_afleiding WHERE aandeel_pct<=0 OR aandeel_pct>100"))
    if bad:
        raise AssertionError(f"Ongeldige afgeleide percentages: {bad}")
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", default="Meijendel")
    parser.add_argument("--gpkg", type=Path, default=DEFAULT_GPKG)
    parser.add_argument("--feature-id", default=DEFAULT_FEATURE_ID)
    parser.add_argument("--backup-dir", type=Path, default=BACKUP_ROOT)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--verify", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    feature = read_area_feature(args.gpkg, args.feature_id)
    client = Client(args.database)
    if args.apply:
        metadata = backup(client, args.backup_dir, feature)
        apply(client, feature)
        print(f"BACKUP_METADATA={metadata}")
    if args.apply or args.verify:
        print(json.dumps(verify(client, feature), sort_keys=True))
    if not args.apply and not args.verify:
        print(json.dumps({k: v for k, v in feature.items() if k != "wkt"}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
