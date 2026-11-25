#!/usr/bin/env python3
"""Importeer de vastgelegde Avimap-territoriumpuntlagen van project 252."""

import argparse
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

from osgeo import ogr

from import_external_ecology_sources import (
    CentralQueryDatabase,
    central_query_audit,
    central_query_routes,
    central_query_schema_contract,
    central_query_triggers_sql,
    central_trigger_name,
)
from import_ndff_protocolkwaliteit import sovon_bmp_bundle_manifest

YEARS = (2007, *range(2009, 2027))
POINT = 'sovon_bmp_territoriumstip'
BUNDLE = f'{POINT}_bron'
SOURCE_TOTAL = 134775
RECENT_VERSIONS = {2024: 4, 2025: 5, 2026: 6}

SCHEMA_SQL = f"""
CREATE TABLE IF NOT EXISTS {BUNDLE} (
  bundel_sha256 BINARY(32) PRIMARY KEY,
  project_id INT UNSIGNED NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  bronpad VARCHAR(1000) NOT NULL,
  bronbestanden JSON NOT NULL,
  bronregels INT UNSIGNED NOT NULL,
  basisgebiedversie_id BIGINT UNSIGNED NOT NULL,
  UNIQUE KEY uq_sovon_stip_bron_jaar (bundel_sha256,jaar),
  KEY ix_sovon_stip_project_jaar (project_id,jaar),
  CHECK (bronregels>0)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS {POINT} (
  bundel_sha256 BINARY(32) NOT NULL,
  bron_rijnummer INT UNSIGNED NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  plot_id INT NOT NULL,
  euring_code INT NOT NULL,
  taxon_bronkoppeling_id BIGINT UNSIGNED NOT NULL,
  aantal INT UNSIGNED NOT NULL,
  broedcode INT NULL,
  in_plot TINYINT UNSIGNED NOT NULL,
  bronvelden JSON NOT NULL,
  geom POINT NOT NULL SRID 28992,
  bron_record_sha256 BINARY(32) NOT NULL,
  PRIMARY KEY (bundel_sha256,bron_rijnummer),
  KEY ix_sovon_stip_kavel_jaar_soort (plot_id,jaar,euring_code),
  KEY ix_sovon_stip_taxon (taxon_bronkoppeling_id),
  SPATIAL KEY sx_sovon_stip_geom (geom),
  FOREIGN KEY (bundel_sha256,jaar) REFERENCES {BUNDLE}(bundel_sha256,jaar),
  FOREIGN KEY (plot_id) REFERENCES plots(plot_id),
  FOREIGN KEY (euring_code) REFERENCES soorten(euring_code),
  FOREIGN KEY (taxon_bronkoppeling_id) REFERENCES taxa_bronkoppeling(koppeling_id),
  CHECK (bron_rijnummer>0 AND aantal>0 AND in_plot IN (0,1))
) ENGINE=InnoDB;
"""


def digest(payload):
    return hashlib.sha256(payload).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(',', ':'))


def sql_text(value):
    return "CONVERT(X'" + value.encode('utf-8').hex() + "' USING utf8mb4)"


def read_source(db, root):
    taxon_map = {int(code): int(link) for code, link in (
        line.split('\t') for line in db.sql("""
SELECT s.euring_code,s.taxon_bronkoppeling_id
FROM soorten s JOIN taxa_bronkoppeling b ON b.koppeling_id=s.taxon_bronkoppeling_id
JOIN taxa t ON t.taxon_id=b.taxon_id JOIN taxon_groepen g ON g.groep_id=t.groep_id
WHERE g.groep_code='vogels' AND b.koppelstatus IN ('kandidaat','bevestigd');
""").splitlines()
    )}
    plots = set(map(int, db.sql('SELECT plot_id FROM plots;').splitlines()))
    version, wkb = db.sql(
        'SELECT basisgebiedversie_id,HEX(ST_AsWKB(gebied_geometrie)) FROM v_meijendel_basisgebied_actueel;'
    ).split('\t')
    boundary = ogr.CreateGeometryFromWkb(bytes.fromhex(wkb))
    prepared = boundary.CreatePreparedGeometry()
    bundles = {}
    points = {}
    for year in YEARS:
        folder = root / str(year)
        if year in RECENT_VERSIONS:
            folder /= f'Sovon_avimap_252_diversen__resultaten-{RECENT_VERSIONS[year]}'
        path = folder / 'avimap_252_diversen__territoria.shp'
        manifest, bundle = sovon_bmp_bundle_manifest(path)
        source = ogr.Open(str(path), 0)
        layer = source.GetLayer()
        if layer.GetSpatialRef().GetAuthorityCode(None) != '28992':
            raise ValueError(f'Geen RD New in {year}')
        count = layer.GetFeatureCount()
        bundles[bundle] = (252, year, str(path), manifest, count, int(version))
        read_count = 0
        for feature in layer:
            fields = feature.items()
            geo = feature.GetGeometryRef()
            plot, code = fields['plotid'], fields['euring']
            if (
                not geo or geo.IsEmpty() or geo.GetGeometryName() != 'POINT' or not prepared.Intersects(geo)
                or fields['projectid'] != 252 or fields['jaar'] != year
                or plot not in plots or code not in taxon_map
                or fields['aantal'] <= 0 or fields['inplot'] not in (0, 1)
            ):
                raise ValueError(f'Afwijkende of niet-toegelaten bronregel {year}/{feature.GetFID()}')
            geometry = bytes(geo.ExportToWkb(ogr.wkbNDR))
            record_hash = digest(canonical(fields).encode('utf-8') + geometry)
            key = (bundle, feature.GetFID() + 1)
            if key in points:
                raise ValueError(f'Dubbel bronrijnummer in {year}')
            points[key] = (
                year, plot, code, taxon_map[code], fields['aantal'], fields['broedcode'],
                fields['inplot'], fields, geometry.hex(), record_hash,
            )
            read_count += 1
        if read_count != count or sovon_bmp_bundle_manifest(path) != (manifest, bundle):
            raise ValueError(f'Bestandsbundel gewijzigd tijdens lezen: {year}')
    if len(bundles) != len(YEARS) or len(points) != SOURCE_TOTAL:
        raise ValueError('Omvang wijkt af van de beoordeelde 19 jaarlagen')
    return bundles, points


def ensure_guards(db, schema):
    names = {central_trigger_name(POINT, suffix) for suffix in ('bi', 'bu')}
    expected = {
        name: statement for name, statement in trigger_definitions(
            central_query_triggers_sql({'routes': central_query_routes(schema)})
        ) if name in names
    }
    if expected.keys() != names:
        raise RuntimeError('De centrale schrijfbeveiliging kan niet worden gegenereerd')
    installed = {row['name']: row for row in db.objects(f'''
SELECT JSON_OBJECT('name',TRIGGER_NAME,'timing',ACTION_TIMING,
                   'event',EVENT_MANIPULATION,'body',ACTION_STATEMENT)
FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE() AND EVENT_OBJECT_TABLE='{POINT}';
''')}
    for name, statement in expected.items():
        if name not in installed:
            db.sql(f'DELIMITER $$\n{statement}$$\nDELIMITER ;\n', write=True)
            continue
        row = installed[name]
        actual = f"CREATE TRIGGER {name} {row['timing']} {row['event']} ON `{POINT}` FOR EACH ROW {row['body']}"
        if actual.split() != statement.split():
            raise RuntimeError(f'Bestaande schrijfbewaking wijkt af: {name}')


def trigger_definitions(sql):
    for statement in sql.split('$$'):
        statement = statement.strip()
        if match := re.match(r'CREATE TRIGGER (\w+) ', statement):
            yield match[1], statement


def insert_sql(bundles, points, commit):
    lines = ['START TRANSACTION;']
    for key, (project, year, path, manifest, count, version) in bundles.items():
        lines.append(
            f"INSERT INTO {BUNDLE} VALUES (UNHEX('{key}'),{project},{year},"
            f"{sql_text(path)},{sql_text(canonical(manifest))},{count},{version});"
        )
    batch = []
    for (bundle, row_id), row in points.items():
        year, plot, code, taxon, count, brood, inside, raw, geom, source_hash = row
        brood_sql = 'NULL' if brood is None else str(brood)
        batch.append(
            f"(UNHEX('{bundle}'),{row_id},{year},{plot},{code},{taxon},{count},{brood_sql},{inside},"
            f"{sql_text(canonical(raw))},ST_GeomFromWKB(UNHEX('{geom}'),28992),UNHEX('{source_hash}'))"
        )
        if len(batch) == 750:
            lines.append(f"INSERT INTO {POINT} VALUES\n" + ',\n'.join(batch) + ';')
            batch.clear()
    if batch:
        lines.append(f"INSERT INTO {POINT} VALUES\n" + ',\n'.join(batch) + ';')
    lines.append('COMMIT;' if commit else 'ROLLBACK;')
    return '\n'.join(lines)


def verify(db, bundles, points):
    database_bundles = {}
    for line in db.sql(f"""SELECT LOWER(HEX(bundel_sha256)),project_id,jaar,bronpad,bronbestanden,
bronregels,basisgebiedversie_id FROM {BUNDLE};""").splitlines():
        key, project, year, path, manifest, count, version = line.split('\t')
        database_bundles[key] = (int(project), int(year), path, json.loads(manifest), int(count), int(version))
    if database_bundles != bundles:
        raise RuntimeError('Bronmanifesten komen niet overeen')
    count_rows = 0
    for line in db.sql(f"""SELECT LOWER(HEX(bundel_sha256)),bron_rijnummer,jaar,plot_id,euring_code,
taxon_bronkoppeling_id,aantal,COALESCE(broedcode,'NULL'),in_plot,bronvelden,
LOWER(HEX(ST_AsWKB(geom))),LOWER(HEX(bron_record_sha256)) FROM {POINT};""").splitlines():
        bundle, source_id, year, plot, code, taxon, count, brood, inside, raw, geom, row_hash = line.split('\t')
        row = (int(year), int(plot), int(code), int(taxon), int(count),
               None if brood == 'NULL' else int(brood), int(inside), json.loads(raw), geom, row_hash)
        if row != points.get((bundle, int(source_id))):
            raise RuntimeError(f'Bronpariteit ontbreekt voor {year}, bronrij {source_id}')
        count_rows += 1
    if count_rows != len(points):
        raise RuntimeError('Aantal bronstippen komt niet overeen')
    if db.sql(f'SELECT COUNT(*) FROM {POINT} WHERE ST_SRID(geom)<>28992;') != '0':
        raise RuntimeError('MySQL-stip heeft een afwijkend referentiestelsel')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bronmap', type=Path)
    parser.add_argument('--socket', type=Path, help='Alleen voor de geïsoleerde T7-proefserver')
    parser.add_argument('--proefbewijs', type=Path)
    parser.add_argument('--herstelkopie', type=Path)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--proef-rollback', action='store_true')
    mode.add_argument('--apply', action='store_true')
    mode.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    if args.proef_rollback and args.socket is None:
        parser.error('--proef-rollback vereist de geïsoleerde proefsocket')
    ogr.UseExceptions()
    db = CentralQueryDatabase(writable=not args.verify)
    if args.socket is not None:
        if not args.socket.is_socket():
            parser.error('Proefsocket ontbreekt')
        db.args = [
            db.args[0], '--no-defaults', '--no-login-paths', '--protocol=socket',
            f'--socket={args.socket}', '-u', 'root', '--batch', '--raw', '--skip-column-names', 'Meijendel',
        ]
        if db.sql('SELECT @@skip_networking;') != '1':
            parser.error('Proefserver heeft netwerktoegang')
    before = db.schema()
    # MySQL commits DDL per statement. After a failed setup the source table can already exist.
    core = {table: columns for table, columns in before.items() if table not in (POINT, BUNDLE)}
    central_query_schema_contract(core)
    bundles, points = read_source(db, args.bronmap)
    source_hashes = {str(row[1]): key for key, row in bundles.items()}
    code_hash = digest(Path(__file__).read_bytes())
    if args.apply and args.socket is None:
        if args.proefbewijs is None or args.herstelkopie is None:
            parser.error('Voor de levende database zijn proefbewijs en herstelkopie verplicht')
        proof = json.loads(args.proefbewijs.read_text())
        with args.herstelkopie.open('rb') as backup:
            backup_hash = hashlib.file_digest(backup, 'sha256').hexdigest()
        if (
            proof.get('bronbundels') != source_hashes
            or proof.get('importcode_sha256') != code_hash
            or proof.get('herstelkopie_sha256') != backup_hash
            or not proof.get('rollback_en_herstel_gecontroleerd')
            or proof.get('stippen') != SOURCE_TOTAL
        ):
            raise RuntimeError('Het proefbewijs past niet bij dezelfde invoer, code en herstelkopie')
    if args.verify:
        verify(db, bundles, points)
    else:
        db.sql(SCHEMA_SQL, write=True)
        current_schema = db.schema()
        central_query_schema_contract(current_schema)
        ensure_guards(db, current_schema)
        existing = int(db.sql(f'SELECT COUNT(*) FROM {POINT};'))
        if existing:
            verify(db, bundles, points)
            print('Herhaling: 0 bronregels toegevoegd.')
        else:
            db.sql(insert_sql(bundles, points, not args.proef_rollback), write=True)
            if args.proef_rollback:
                for table in (POINT, BUNDLE):
                    if db.sql(f'SELECT COUNT(*) FROM {table};') != '0':
                        raise RuntimeError(f'Proefrollback liet regels achter in {table}')
                print('Proefrollback: beide tabellen bevatten nul regels.')
                return
            verify(db, bundles, points)
    audit = central_query_audit(db)
    if audit['errors']:
        raise RuntimeError('; '.join(audit['errors']))
    print(json.dumps({
        'jaarregels': len(bundles), 'stippen': len(points), 'centrale_routes': len(audit['routes']),
        'jaar_aantallen': dict(sorted(Counter(row[0] for row in points.values()).items())),
        'buiten_kavel': sum(row[6] == 0 for row in points.values()),
        'herhaalde_bronrijen': len(points) - len({(key[0], row[-1]) for key, row in points.items()}),
        'bronbundels': source_hashes,
        'importcode_sha256': code_hash,
    }, ensure_ascii=False))


if __name__ == '__main__':
    main()
