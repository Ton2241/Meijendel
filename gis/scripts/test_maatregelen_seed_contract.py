#!/usr/bin/env python3
"""Integratiecontract voor de eerste bronvaste maatregeleninvoer."""

from __future__ import annotations

import subprocess
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis" / "database" / "maatregelen_schema.sql"
SEED = ROOT / "gis" / "database" / "maatregelen_seed.sql"
TEST_DB = f"meijendel_maatregelen_seed_{uuid.uuid4().hex[:12]}"
MYSQL = "/usr/local/mysql/bin/mysql"


def mysql(sql: str, database: str | None = None) -> str:
    command = [MYSQL, "--login-path=meijendel_root", "--host=127.0.0.1", "--protocol=TCP", "--batch", "--skip-column-names"]
    if database:
        command.append(database)
    result = subprocess.run(command, input=sql, text=True, capture_output=True, check=False)
    if result.returncode:
        raise AssertionError(result.stderr.strip() or result.stdout.strip())
    return result.stdout.strip()


def apply(path: Path) -> None:
    sql = path.read_text(encoding="utf-8").replace("USE Meijendel;", f"USE {TEST_DB};", 1)
    mysql(sql)


def scalar(sql: str) -> int:
    return int(mysql(sql, TEST_DB))


def main() -> int:
    assert SEED.is_file(), f"seed ontbreekt: {SEED}"
    assert int(mysql(f"SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='{TEST_DB}';")) == 0
    mysql(f"CREATE DATABASE {TEST_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;")
    try:
        mysql(
            """
            CREATE TABLE maatregelen (
              id INT NOT NULL,
              code VARCHAR(50) NOT NULL,
              omschrijving TEXT NOT NULL,
              PRIMARY KEY (id),
              UNIQUE KEY uq_maatregelen_code (code)
            ) ENGINE=InnoDB;
            INSERT INTO maatregelen (id, code, omschrijving) VALUES
              (1,'zeereepbeheer','Zeereepbeheer'),
              (2,'maaibeheer_aanvullend','Aanvullend maaibeheer'),
              (3,'begrazing','Begrazing'),
              (4,'exotenbestrijding','Exotenbestrijding'),
              (5,'plaggen_chopperen_afgraven','Plaggen/chopperen/afgraven'),
              (6,'hydrologie_optimaliseren','Optimaliseren hydrologie'),
              (7,'bosreductie_struweelbeheer','Bos- en struweelbeheer'),
              (8,'geomorfologie_herstel_stortplaatsen','Herstel geomorfologie'),
              (9,'strandreservaten','Strandreservaten'),
              (10,'predatorenbeheer','Predatorenbeheer'),
              (11,'rust_en_recreatiebeheer','Rust- en recreatiebeheer');
            CREATE TABLE plots (
              plot_id INT NOT NULL,
              kavel_nummer VARCHAR(255) NULL,
              in_gebruik TINYINT(1) NOT NULL DEFAULT 1,
              PRIMARY KEY (plot_id)
            ) ENGINE=InnoDB;
            INSERT INTO plots (plot_id,kavel_nummer,in_gebruik) VALUES
              (3490,'M33',1),(3496,'M34',1),(3497,'M83',1),(3498,'M7',1),
              (3499,'M105',1),(3500,'M46',1),(3501,'M71',1),(3502,'M10-12-76',1),
              (3503,'M66',1),(3504,'M3',1),(3505,'M1b',1),(3506,'M13s',1),
              (3507,'M45',1),(3508,'M32',1),(3509,'M63',1),(3510,'M85',1),
              (3511,'M13',1),(3512,'M14',1),(3513,'M17a',1),(3514,'M91',1),
              (3515,'M35',1),(3516,'M64',1),(3517,'M84',1),(3518,'M65',1),
              (3519,'M12a',1),(3520,'M62',1),(3521,'M6',1),(3522,'M61',1),
              (3523,'M2',1),(3524,'M15',1),(3525,'M16',1),(3526,'M72',1),
              (3527,'M73',1),(3528,'M74',1),(3529,'M17b',1),(3530,'M8',1),
              (3531,'M75',1),(3532,'M77',1),(3533,'M36',1),(3534,'M1a',1),
              (3581,'M4-5',1),(3583,'M75a',1),(9917,'M51',1),(10626,'M43',1),
              (12381,'M54a',1),(12382,'M54b',1),(20247,'M52',1),(20758,'M78/79',1),
              (27371,'M53',1),(29455,'M55',1),(29456,'M16s',1),(29457,'M42',1),
              (29459,'M31',1),(100425,'M41',1),(112100,'M84s',1),
              (999986,'M9',0),(999987,'M12',0),(999988,'M5',0),(999989,'M4',0),
              (999990,'M11',0),(999991,'M1',0),(999992,'M54',0),(999993,'M79',0),
              (999994,'M78',0),(999995,'M17',0),(999996,'M76',0),(999997,'M8/11',0),
              (999998,'M10',0),(999999,'M8/9',0);
            CREATE TABLE ndff_sovon_plotversie (
              plotversie_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
              versie VARCHAR(32) NOT NULL,
              bronbestand VARCHAR(500) NOT NULL,
              bronbestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
              crs_epsg INT UNSIGNED NOT NULL DEFAULT 28992,
              objectaantal SMALLINT UNSIGNED NOT NULL,
              PRIMARY KEY (plotversie_id),
              UNIQUE KEY uq_test_plotversie_hash (bronbestand_sha256)
            ) ENGINE=InnoDB;
            INSERT INTO ndff_sovon_plotversie
              (plotversie_id,versie,bronbestand,bronbestand_sha256,crs_epsg,objectaantal)
            VALUES (1,'2025','test.gpkg',REPEAT('a',64),28992,55);
            CREATE TABLE ndff_sovon_plot (
              plotversie_id BIGINT UNSIGNED NOT NULL,
              plot_id INT NOT NULL,
              plot_geometrie GEOMETRY NOT NULL SRID 28992,
              plot_geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
              PRIMARY KEY (plotversie_id,plot_id),
              CONSTRAINT fk_test_plotversie FOREIGN KEY (plotversie_id)
                REFERENCES ndff_sovon_plotversie (plotversie_id),
              CONSTRAINT fk_test_plot FOREIGN KEY (plot_id) REFERENCES plots (plot_id)
            ) ENGINE=InnoDB;
            """,
            TEST_DB,
        )
        apply(SCHEMA)
        apply(SEED)
        expected = {
            "maatregel_bron": 30,
            "maatregel_project": 18,
            "maatregel_uitvoering": 61,
            "maatregel_uitvoering_jaar": 100,
            "maatregel_uitvoering_bron": 83,
            "plot_gebied": 8,
            "plot_gebiedsindeling": 1,
            "plot_gebied_lidmaatschap": 69,
            "maatregel_plot_koppeling": 98,
            "maatregel_uitvoering_gebied": 2,
        }
        before = {table: scalar(f"SELECT COUNT(*) FROM {table};") for table in expected}
        assert before == expected, before
        assert scalar("SELECT COUNT(*) FROM maatregel_uitvoering u LEFT JOIN maatregel_uitvoering_bron b USING (uitvoering_id) WHERE b.uitvoering_id IS NULL;") == 0
        assert scalar("SELECT COUNT(*) FROM maatregel_geometrie;") == 0
        assert scalar("SELECT COUNT(*) FROM plot_gebied_geometrie;") == 0
        assert scalar("SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast;") == 148
        assert scalar("SELECT COUNT(*) FROM v_plot_gebied_actueel;") == 69
        assert scalar("SELECT COUNT(DISTINCT plot_id) FROM plot_gebied_lidmaatschap;") == 69
        assert mysql("SELECT GROUP_CONCAT(CONCAT(gebied_code,':',n) ORDER BY gebied_code SEPARATOR ',') FROM (SELECT gebied_code,COUNT(*) n FROM plot_gebied_lidmaatschap GROUP BY gebied_code) x;", TEST_DB) == (
            "buitenduin_noord:12,buitenduin_zuid:7,haagsche_golfclub:1,hertenkamp:1,"
            "kijfhoek_en_bierlap:23,vallei_meijendel:12,voorlinden:1,zuid_oosthoek:12"
        )
        assert scalar("SELECT COUNT(*) FROM plot_gebied_lidmaatschap WHERE lidmaatschap_status='actueel_met_geometrie';") == 55
        assert scalar("SELECT COUNT(*) FROM plot_gebied_lidmaatschap WHERE lidmaatschap_status='historisch_zonder_geometrie';") == 14
        assert scalar("SELECT COUNT(*) FROM v_plot_gebied_actueel WHERE plot_id=999995 AND gebied_code='buitenduin_noord';") == 1
        assert scalar("SELECT COUNT(*) FROM v_plot_gebied_actueel WHERE plot_id=3509 AND gebied_code='kijfhoek_en_bierlap';") == 1
        assert scalar("SELECT COUNT(*) FROM v_plot_gebied_actueel WHERE plot_id IN (3510,12381) AND gebied_code='vallei_meijendel';") == 2
        assert scalar("SELECT COUNT(*) FROM plots WHERE kavel_nummer='M54q';") == 0
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN plots p USING (plot_id)
          WHERE u.uitvoering_code='pas_24c_voorlinden'
            AND p.kavel_nummer='M91'
            AND pk.koppelmethode='benoemd_gebied_gevalideerd'
            AND pk.verificatiestatus='geverifieerd'
            AND pk.doorsnijding_pct IS NULL;
        """) == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_uitvoering_gebied ug
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          WHERE u.uitvoering_code='pas_24c_voorlinden'
            AND ug.indeling_code='vogelplot-gebiedsindeling-v1'
            AND ug.gebied_code='voorlinden'
            AND ug.relatietype='locatie_binnen_gebied'
            AND ug.verificatiestatus='geverifieerd';
        """) == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_uitvoering_jaar uj
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          WHERE u.uitvoering_code='pas_24c_voorlinden'
            AND uj.jaar=2025 AND uj.jaarstatus='onbekend';
        """) == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM v_plot_jaar_maatregel_bronvast
          WHERE uitvoering_code='pas_24c_voorlinden';
        """) == 0
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN plots p USING (plot_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='pan13_slib_1988_1989'
            AND pk.koppelmethode='expliciet_in_bron'
            AND pk.verificatiestatus='geverifieerd'
            AND pk.doorsnijding_pct IS NULL
            AND ((p.kavel_nummer='M2' AND b.bron_code='zotero_pan13_1991')
              OR (p.kavel_nummer='M3' AND b.bron_code='zotero_broedvogelmonitoring_2006'));
        """) == 2
        assert scalar("""
          SELECT COUNT(*)
          FROM v_plot_jaar_maatregel_bronvast
          WHERE uitvoering_code='pan13_slib_1988_1989'
            AND plot_id IN (3504,3523)
            AND jaar IN (1988,1989);
        """) == 4
        assert scalar("SELECT COUNT(*) FROM maatregel_uitvoering_jaar uj JOIN maatregel_uitvoering u USING (uitvoering_id) WHERE u.uitvoering_code='pas_23_maaibeheer' AND uj.jaar BETWEEN 2016 AND 2019 AND uj.jaarstatus='niet_uitgevoerd';") == 4
        assert scalar("SELECT COUNT(*) FROM maatregel_uitvoering_jaar uj JOIN maatregel_uitvoering u USING (uitvoering_id) WHERE u.uitvoering_code='pas_23_vogelkers_2020' AND uj.jaar=2020 AND uj.jaarstatus='uitgevoerd';") == 1
        assert scalar("SELECT COUNT(*) FROM maatregel_uitvoering u WHERE u.uitvoering_code='bendel_nabeheer_2026' AND u.uitvoering_status_code='gepland';") == 1
        assert scalar("SELECT COUNT(*) FROM maatregel_uitvoering_jaar uj JOIN maatregel_uitvoering u USING (uitvoering_id) WHERE u.uitvoering_code='bendel_nabeheer_2026';") == 0
        assert scalar("SELECT COUNT(*) FROM maatregel_bron WHERE zotero_item_key IN ('JVDIWBDE','3B2FN68M','F87WJAIG','EP58F3ZI','HDRX28C3','HTUFWIAS','8CFXEBIQ','NZWRNSSI','4BFHKS7Q','JQZFPPEK','9Z4K34B6','G3K24ZDB','MUAD7GB2','4KR5RBAH','ZS99KGRA');") == 15
        assert scalar("SELECT COUNT(*)-COUNT(DISTINCT zotero_item_key) FROM maatregel_bron WHERE zotero_item_key IS NOT NULL;") == 0
        assert scalar("SELECT COUNT(*) FROM maatregel_bron WHERE bron_code='zotero_valleien_2003' AND zotero_item_key='9Z4K34B6' AND titel='Vegetatieontwikkeling in duinvalleien van Meijendel na opheffen van infiltratieplassen';") == 1
        assert scalar("SELECT COUNT(*) FROM maatregel_bron WHERE bron_code='zotero_plas20_2006' AND bron_datum='2006-03-01' AND titel='Schone start voor infiltratieplas 20 in Meijendel';") == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN plots p USING (plot_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='plas20_reparatie_1969'
            AND p.kavel_nummer IN ('M16','M17a','M17b')
            AND pk.koppelmethode='benoemd_gebied_gevalideerd'
            AND pk.verificatiestatus='geverifieerd'
            AND pk.doorsnijding_pct IS NULL
            AND b.bron_code='zotero_plas20_2006';
        """) == 3
        assert scalar("""
          SELECT COUNT(*)
          FROM v_plot_jaar_maatregel_bronvast
          WHERE uitvoering_code='plas20_reparatie_1969'
            AND plot_id IN (3513,3525,3529)
            AND jaar=1969;
        """) == 3
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN plots p USING (plot_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='maaibeheer_libellenvallei_1975_2003'
            AND p.plot_id=3529
            AND p.kavel_nummer='M17b'
            AND pk.koppelmethode='benoemd_gebied_gevalideerd'
            AND pk.verificatiestatus='geverifieerd'
            AND pk.doorsnijding_pct IS NULL
            AND b.bron_code='zotero_valleien_2003';
        """) == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM v_plot_jaar_maatregel_bronvast
          WHERE uitvoering_code='maaibeheer_libellenvallei_1975_2003'
            AND plot_id=3529
            AND jaar=1975;
        """) == 1
        expected_name_inventory_plots = {
            "begrazing_kijfhoek_bierlap_1990": "M12a,M62,M63,M64,M65,M72,M73",
            "begrazing_meeuwenhoek_voor_2008": "M10-12-76,M12a,M73,M74,M75",
            "pas_22a_tafelberg_scheepje": "M13,M6,M7,M77",
            "pas_22c_uilenbosch": "M42,M43,M84s",
            "pas_23_vogelkers_2020": "M10-12-76,M12a,M62,M63,M64,M65,M72,M73,M74,M75",
            "pas_24b_ouderijs": "M53,M84,M85",
        }
        for execution_code, plots_csv in expected_name_inventory_plots.items():
            actual = mysql(f"""
              SELECT GROUP_CONCAT(p.kavel_nummer ORDER BY p.kavel_nummer SEPARATOR ',')
              FROM maatregel_plot_koppeling pk
              JOIN maatregel_uitvoering u USING (uitvoering_id)
              JOIN plots p USING (plot_id)
              WHERE u.uitvoering_code='{execution_code}'
                AND pk.koppelmethode='geometrische_doorsnijding'
                AND pk.verificatiestatus='geverifieerd'
                AND pk.doorsnijding_pct IS NULL
                AND pk.opmerking LIKE '%meijendel_nameninventaris_2026-10-14%';
            """, TEST_DB)
            assert actual == plots_csv, (execution_code, actual)
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_uitvoering u
          LEFT JOIN maatregel_plot_koppeling pk USING (uitvoering_id)
          WHERE pk.uitvoering_id IS NULL;
        """) == 23
        assert scalar("SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast WHERE uitvoering_code='begrazing_kijfhoek_bierlap_1990' AND jaar=1990;") == 7
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_uitvoering
          WHERE uitvoering_code IN ('begrazing_helmduinen_1991','kikkervalleien_begrazing_1997')
            AND uitvoering_status_code='in_uitvoering'
            AND datum_tot IS NULL
            AND cycliciteit='doorlopend tot heden'
            AND opmerking LIKE '%Ton bevestigde op 14 oktober 2026%';
        """) == 2
        assert mysql("""
          SELECT GROUP_CONCAT(p.kavel_nummer ORDER BY p.kavel_nummer SEPARATOR ',')
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN plots p USING (plot_id)
          WHERE u.uitvoering_code='begrazing_helmduinen_1991'
            AND pk.koppelmethode='benoemd_gebied_gevalideerd'
            AND pk.verificatiestatus='geverifieerd'
            AND pk.doorsnijding_pct IS NULL;
        """, TEST_DB) == "M15,M16,M17a"
        assert scalar("SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast WHERE uitvoering_code='begrazing_helmduinen_1991' AND jaar=1991;") == 3
        assert mysql("""
          SELECT GROUP_CONCAT(p.kavel_nummer ORDER BY p.kavel_nummer SEPARATOR ',')
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN plots p USING (plot_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='kikkervalleien_begrazing_1997'
            AND pk.koppelmethode='expliciet_in_bron'
            AND pk.verificatiestatus='geverifieerd'
            AND pk.doorsnijding_pct IS NULL
            AND b.bron_code='zotero_kikkervalleien_2010';
        """, TEST_DB) == "M13,M13s,M14"
        assert scalar("SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast WHERE uitvoering_code='kikkervalleien_begrazing_1997' AND jaar=1997;") == 3
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_uitvoering_bron ub
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='kikkervalleien_begrazing_1997'
            AND b.bron_code='zotero_kikkervalleien_2010'
            AND ub.bronrol='primaire_uitvoeringsbron'
            AND ub.pagina_of_paragraaf='p. 5 en 22';
        """) == 1
        assert mysql("""
          SELECT GROUP_CONCAT(p.kavel_nummer ORDER BY p.kavel_nummer SEPARATOR ',')
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN plots p USING (plot_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='kikkervalleien_bodem_1997'
            AND pk.koppelmethode='expliciet_in_bron'
            AND pk.verificatiestatus='geverifieerd'
            AND pk.doorsnijding_pct IS NULL
            AND b.bron_code='zotero_kikkervalleien_2010';
        """, TEST_DB) == "M13,M13s,M14"
        assert scalar("SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast WHERE uitvoering_code='kikkervalleien_bodem_1997' AND jaar=1997;") == 3
        assert mysql("""
          SELECT GROUP_CONCAT(CONCAT(p.kavel_nummer,':',pk.koppelmethode,':',b.bron_code) ORDER BY p.kavel_nummer SEPARATOR ',')
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN plots p USING (plot_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='kikkervalleien_infra_1997'
            AND pk.verificatiestatus='geverifieerd'
            AND pk.doorsnijding_pct IS NULL;
        """, TEST_DB) == "M13:benoemd_gebied_gevalideerd:zotero_kikkervalleien_2010,M13s:expliciet_in_bron:zotero_meijendel_mededelingen_30_1996,M14:expliciet_in_bron:zotero_meijendel_mededelingen_30_1996"
        assert scalar("SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast WHERE uitvoering_code='kikkervalleien_infra_1997' AND jaar=1997;") == 3
        assert mysql("""
          SELECT GROUP_CONCAT(CONCAT(p.kavel_nummer,':',pk.koppelmethode,':',b.bron_code) ORDER BY p.kavel_nummer SEPARATOR ',')
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN plots p USING (plot_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='kikkervallei_watercrassula'
            AND pk.verificatiestatus='geverifieerd'
            AND pk.doorsnijding_pct IS NULL;
        """, TEST_DB) == "M13:benoemd_gebied_gevalideerd:zotero_kikkervalleien_2010,M13s:benoemd_gebied_gevalideerd:zotero_kikkervalleien_2010,M14:benoemd_gebied_gevalideerd:zotero_kikkervalleien_2010"
        assert mysql("""
          SELECT GROUP_CONCAT(jaar ORDER BY jaar SEPARATOR ',')
          FROM maatregel_uitvoering_jaar j
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          WHERE u.uitvoering_code='kikkervallei_watercrassula'
            AND j.jaarstatus='uitgevoerd';
        """, TEST_DB) == "2015,2017,2018,2019,2020,2021,2022,2023,2024,2025"
        assert scalar("SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast WHERE uitvoering_code='kikkervallei_watercrassula' AND jaar IN (2015,2017,2018,2019,2020,2021,2022,2023,2024,2025);") == 30
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_uitvoering_bron ub
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='kikkervallei_watercrassula'
            AND b.bron_code='zotero_kikkervalleien_2010'
            AND ub.bronrol='plancontext'
            AND ub.pagina_of_paragraaf='p. 22';
        """) == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_uitvoering_bron ub
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='kikkervalleien_infra_1997'
            AND b.bron_code='zotero_meijendel_mededelingen_30_1996'
            AND b.zotero_item_key='2TXQMXTB'
            AND ub.bronrol='plancontext'
            AND ub.pagina_of_paragraaf='p. 99';
        """) == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_uitvoering_bron ub
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='kikkervalleien_bodem_1997'
            AND b.bron_code='zotero_kikkervalleien_2010'
            AND ub.bronrol='primaire_uitvoeringsbron'
            AND ub.pagina_of_paragraaf='p. 5 en 22'
            AND ub.bewijsnotitie LIKE '%vegetatie en voedselrijke bovengrond%';
        """) == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN plots p USING (plot_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='plaggen_parnassiapad2_1993'
            AND p.kavel_nummer='M15'
            AND pk.koppelmethode='benoemd_gebied_gevalideerd'
            AND pk.verificatiestatus='geverifieerd'
            AND pk.doorsnijding_pct IS NULL
            AND b.bron_code='zotero_hollands_duinen_86_2025'
            AND pk.opmerking LIKE '%Ton op 14 oktober 2026%';
        """) == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_uitvoering_bron ub
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='plaggen_parnassiapad2_1993'
            AND b.bron_code='zotero_hollands_duinen_86_2025'
            AND ub.bronrol='bevestiging'
            AND ub.pagina_of_paragraaf='p. 49, figuur 1';
        """) == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM v_plot_jaar_maatregel_bronvast
          WHERE uitvoering_code='plaggen_parnassiapad2_1993'
            AND plot_id=3524
            AND jaar=1993;
        """) == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN plots p USING (plot_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='plaggen_parnassiapad1_1997'
            AND p.kavel_nummer='M15'
            AND pk.koppelmethode='benoemd_gebied_gevalideerd'
            AND pk.verificatiestatus='geverifieerd'
            AND pk.doorsnijding_pct IS NULL
            AND b.bron_code='zotero_valleien_2003'
            AND pk.opmerking LIKE '%Ton op 14 oktober 2026%';
        """) == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM v_plot_jaar_maatregel_bronvast
          WHERE uitvoering_code='plaggen_parnassiapad1_1997'
            AND plot_id=3524
            AND jaar=1997;
        """) == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_bron
          WHERE bron_code='odh_konijnenontheffing_2023'
            AND brontype_code='inrichtingsplan'
            AND bron_datum='2023-08-28'
            AND bronstatus='definitieve_beschikking'
            AND url LIKE '%ODH701135.pdf';
        """) == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_uitvoering_bron ub
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='konijnen_bijplaatsing_2024_2026'
            AND b.bron_code='odh_konijnenontheffing_2023'
            AND ub.bronrol='bevestiging'
            AND ub.pagina_of_paragraaf='p. 5 en bijlagen p. 4-5';
        """) == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_uitvoering u
          JOIN maatregel_project p USING (project_id)
          WHERE u.uitvoering_code='konijnen_bijplaatsing_2024_2026'
            AND u.uitvoering_status_code='uitgevoerd'
            AND u.locatie_naam='Kleine Pan en Waterschapsvallei'
            AND u.locatie_precisie='benoemd_deelgebied'
            AND u.datum_vanaf='2024-01-01'
            AND u.datum_tot='2024-12-31'
            AND u.datum_precisie='jaar'
            AND p.bestuurlijke_status='uitvoering_2024_bevestigd_vervolg_onbekend'
            AND p.deelgebied='Kleine Pan en Waterschapsvallei'
            AND p.plan_einddatum='2026-03-31';
        """) == 1
        assert mysql("""
          SELECT GROUP_CONCAT(CONCAT(p.kavel_nummer,':',pk.koppelmethode,':',b.bron_code) ORDER BY p.kavel_nummer SEPARATOR ',')
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          JOIN plots p USING (plot_id)
          JOIN maatregel_bron b USING (bron_id)
          WHERE u.uitvoering_code='konijnen_bijplaatsing_2024_2026'
            AND pk.verificatiestatus='geverifieerd'
            AND pk.doorsnijding_pct IS NULL;
        """, TEST_DB) == "M41:expliciet_in_bron:odh_konijnenontheffing_2023,M8:expliciet_in_bron:odh_konijnenontheffing_2023"
        assert scalar("""
          SELECT COUNT(*)
          FROM v_plot_jaar_maatregel_bronvast
          WHERE uitvoering_code='konijnen_bijplaatsing_2024_2026'
            AND plot_id IN (3530,100425)
            AND jaar=2024;
        """) == 2
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_uitvoering_jaar j
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          WHERE u.uitvoering_code='konijnen_bijplaatsing_2024_2026'
            AND j.jaar<>2024;
        """) == 0
        assert scalar("SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast WHERE uitvoering_code='pas_22a_tafelberg_scheepje' AND jaar=2025;") == 4
        assert scalar("SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast WHERE uitvoering_code='pas_22c_uilenbosch' AND jaar BETWEEN 2017 AND 2021;") == 15
        assert scalar("SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast WHERE uitvoering_code='pas_23_vogelkers_2020' AND jaar=2020;") == 10
        assert scalar("SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast WHERE uitvoering_code IN ('begrazing_meeuwenhoek_voor_2008','pas_24b_ouderijs');") == 0
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          WHERE u.uitvoering_code='pan13_oeveraanpassing_1988_1989'
            AND pk.plot_id IN (3504,3523)
            AND pk.koppelmethode='expliciet_in_bron'
            AND pk.verificatiestatus='geverifieerd';
        """) == 2
        assert scalar("SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast WHERE uitvoering_code='pan13_oeveraanpassing_1988_1989' AND jaar IN (1988,1989);") == 4
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          WHERE u.uitvoering_code IN ('plas20_hydrologie_2005_2006','plas20_infrastructuur_2005_2006','slib_plas20_2005_2006')
            AND pk.plot_id IN (3513,3525,3529)
            AND pk.koppelmethode='benoemd_gebied_gevalideerd'
            AND pk.verificatiestatus='geverifieerd';
        """) == 9
        assert scalar("""
          SELECT COUNT(*)
          FROM v_plot_jaar_maatregel_bronvast
          WHERE uitvoering_code IN ('plas20_hydrologie_2005_2006','plas20_infrastructuur_2005_2006','slib_plas20_2005_2006')
            AND jaar IN (2005,2006);
        """) == 18
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          WHERE u.uitvoering_code='rietpoten_noord_1987';
        """) == 0
        assert scalar("SELECT COUNT(*) FROM maatregel_uitvoering WHERE uitvoering_code IN ('pan2_peilverlaging_1967','pan3_schoonmaak_1967','rietpoten_noord_1987','begrazing_kijfhoek_bierlap_1990','slib_plas20_2005_2006');") == 5
        assert scalar("SELECT COUNT(*) FROM maatregel_uitvoering WHERE uitvoering_code LIKE 'kwelplassen_2006_2007%';") == 0
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_plot_koppeling pk
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          WHERE u.uitvoering_code='pannen_16_17_peilverlaging_1967'
            AND pk.plot_id IN (3525,999995)
            AND pk.koppelmethode='expliciet_in_bron'
            AND pk.verificatiestatus='geverifieerd';
        """) == 2
        assert scalar("""
          SELECT COUNT(*)
          FROM maatregel_uitvoering_gebied ug
          JOIN maatregel_uitvoering u USING (uitvoering_id)
          WHERE u.uitvoering_code='begrazing_kijfhoek_bierlap_1990'
            AND ug.gebied_code='kijfhoek_en_bierlap'
            AND ug.relatietype='volledig_gebied'
            AND ug.verificatiestatus='geverifieerd';
        """) == 1
        assert scalar("""
          SELECT COUNT(*)
          FROM v_plot_jaar_maatregel_bronvast
          WHERE uitvoering_code='ganzenhoek_wandelpad_1974_1975'
            AND jaar IN (1974,1975);
        """) == 8
        apply(SEED)
        after = {table: scalar(f"SELECT COUNT(*) FROM {table};") for table in expected}
        assert after == before, (before, after)
    finally:
        mysql(f"DROP DATABASE {TEST_DB};")
    print("OK: maatregelen-seed, brondekking en idempotentie")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
