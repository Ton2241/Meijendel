#!/usr/bin/env python3
"""Registreer de gereconstrueerde fase-2-bronnen in Meijendel_bronnen.

De bijenbezoeken en aquatische methodebeschrijving zijn context zolang de
proefvlak- en monsterpuntgrenzen niet digitaal zijn gegeorefereerd. De ring- en
droge-duinvegetatiebronnen worden uitsluitend als kandidaat vastgelegd.
"""

from __future__ import annotations

import argparse
import csv
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis" / "database" / "phase2_context_schema.sql"

BEE_PLOTS = {
    **{f"M{i:02d}": "Vallei Meijendel" for i in range(1, 5)},
    **{f"M{i:02d}": "De Loopert" for i in range(5, 9)},
    **{f"M{i:02d}": "Buitenduinen" for i in range(9, 14)},
    **{f"M{i:02d}": "Binnenduinen" for i in range(14, 19)},
}

AQUATIC_POINTS = (
    ("MP1", "Pan 17.1", "Rietrand van infiltratieplas Pan 17.1"),
    ("MP2", "Pan 17.1", "Kale zandoever van infiltratieplas Pan 17.1"),
    ("MP3", "Pan 26.1.1", "Aan wind blootgestelde oever van Pan 26.1.1"),
    ("MP4", "Pan 26.1.1", "Minder aan wind blootgestelde oever van Pan 26.1.1"),
    ("MP5", "K10", "Kwelplas K10"),
    ("MP6", "G15", "Water G15"),
    ("MP7", "G21", "Water G21"),
)

AQUATIC_PROTOCOLS = (
    *( (f"MP{i}", "1974-06-01", "1974-06-30", 5.0, None,
        "Pilotbemonstering over vijf meter oever", "afwijkende_inspanning") for i in range(1, 8) ),
    *( (f"MP{i}", "1974-08-01", "1975-06-30", 2.5, 0.75,
        "Standaardbemonstering; vanaf augustus 1974", "standaard") for i in range(1, 7) ),
    ("MP7", "1974-08-01", "1975-06-30", 2.0, 0.60,
     "Standaardbemonstering aangepast aan monsterpunt 7", "standaard"),
    ("MP2", "1974-11-01", "1974-11-30", 1.25, None,
     "In november 1974 is bij monsterpunt 2 slechts 1,25 meter bemonsterd", "afwijkende_inspanning"),
    *( (code, "1975-07-01", "1975-07-31", None, None,
        "In juli 1975 is alleen een gedeeltelijke bemonstering uitgevoerd", "gedeeltelijke_bemonstering")
       for code in ("MP1", "MP2", "MP4", "MP5") ),
)


def sql_quote(value) -> str:
    if value is None:
        return "NULL"
    return "'" + str(value).replace("\\", "\\\\").replace("'", "''") + "'"


def read_visits(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 162 or {row["proefvlak_code"] for row in rows} != set(BEE_PLOTS):
        raise ValueError("Bijenbezoekbestand moet 162 bezoeken op proefvlakken M01-M18 bevatten")
    return rows


def values_sql(rows) -> str:
    return ",\n".join("(" + ",".join(sql_quote(value) for value in row) + ")" for row in rows)


def build_sql(visits: list[dict[str, str]], database: str = "Meijendel_bronnen") -> str:
    plot_values = values_sql(
        (code, area, 1.0, "kaart_in_rapport_geen_digitale_grens",
         "De rapporten tonen de begrenzing als figuur; een digitale, controleerbare proefvlakgrens ontbreekt.")
        for code, area in BEE_PLOTS.items()
    )
    visit_values = values_sql(
        (row["proefvlak_code"], row["bezoekdatum"], int(row["ronde"]), int(row["duur_minuten"]),
         "volledig_volgens_rapport", "rapporttabellen_nog_niet_geimporteerd")
        for row in visits
    )
    aquatic_points = values_sql(
        (*row, "watercode_bekend_grens_niet_gedigitaliseerd") for row in AQUATIC_POINTS
    )
    aquatic_protocols = values_sql(AQUATIC_PROTOCOLS)
    return f"""
USE {database};
START TRANSACTION;

INSERT INTO bron (
  bron_sleutel,bron_type,titel,omschrijving,bronorganisatie,jaar_van,jaar_tot,
  soortgroep,geografische_status,geografische_toelichting,analyse_status,rechten_status,regelversie
) VALUES
('eis-bijenmonitoring-meijendel','dataset','Bijenmonitoring Meijendel 2019, 2021 en 2023',
 'Achttien vaste hectareproefvlakken, drie bezoeken per onderzoeksjaar en 162 gestandaardiseerde bezoeken. De resultaatstabellen en digitale proefvlakgrenzen zijn nog niet geïmporteerd.',
 'EIS Kenniscentrum Insecten',2019,2023,'bijen','gedeeltelijk_geolokaliseerd',
 'De vier deelgebieden en proefvlakcodes M01-M18 zijn bekend. De rapportfiguren zijn nog niet omgezet in controleerbare digitale grenzen.',
 'context_alleen','geregistreerde_onderzoekers','fase2-2026-09-26'),
('aquatische-macrofauna-meijendel-1974-1975','dataset','Aquatische macrofauna Meijendel 1974-1975',
 'Zeven vaste monsterpunten met een gedocumenteerde, maar deels wisselende bemonsteringsmethode van juni 1974 tot juli 1975.',
 'Rijksuniversiteit Leiden; ontsloten via Naturalis',1974,1975,'aquatische macrofauna','gedeeltelijk_geolokaliseerd',
 'De watercodes Pan 17.1, Pan 26.1.1, K10, G15 en G21 zijn bekend; digitale punt- of watergrenzen ontbreken nog.',
 'context_alleen','geregistreerde_onderzoekers','fase2-2026-09-26'),
('vrs-ringgegevens-meijendel-kandidaat','kandidaatbron','Vogeltrekstation-biometrie: nog niet aan VRS Meijendel gekoppeld',
 'De 100.417 GBIF-treffers binnen de projectgrens dragen locatiecode NL19. Volgens de EURING-codebeschrijving betekent NL19 provincie Zuid-Holland, niet ringstation Meijendel. Trektellen-site 403 is wel VRS Meijendel, maar een recordsleutel tussen beide bronnen ontbreekt.',
 'Vogeltrekstation/NIOO-KNAW',1963,2023,'vogels','gedeeltelijk_geolokaliseerd',
 'Coordinaten vallen binnen het basisgebied, maar de gepubliceerde locatiecode bewijst niet dat het records van VRS Meijendel zijn.',
 'kandidaat','geregistreerde_onderzoekers','fase2-2026-09-26'),
('droge-duinvegetatieplots-1952-2012','kandidaatbron','Langjarige droge-duinvegetatieplots 1952-2012',
 'Eenenveertig vaste plots, aangelegd in 1952-1953, aanvankelijk jaarlijks en later gemiddeld eens per vier jaar opgenomen; laatste beschreven opname in 2012.',
 'Historische Meijendel-onderzoekers; WUR',1952,2012,'vegetatie','gedeeltelijk_geolokaliseerd',
 'De publicatiekaart toont 41 punten in Helmduinen, Kijfhoek en Bierlap zonder koppelbare plotcodes. De LVD-selectie bevat geen betrouwbare vertaling naar deze 41 plots.',
 'kandidaat','geregistreerde_onderzoekers','fase2-2026-09-26')
ON DUPLICATE KEY UPDATE
  titel=VALUES(titel),omschrijving=VALUES(omschrijving),bronorganisatie=VALUES(bronorganisatie),
  jaar_van=VALUES(jaar_van),jaar_tot=VALUES(jaar_tot),soortgroep=VALUES(soortgroep),
  geografische_status=VALUES(geografische_status),geografische_toelichting=VALUES(geografische_toelichting),
  analyse_status=VALUES(analyse_status),rechten_status=VALUES(rechten_status),regelversie=VALUES(regelversie);

SET @bee_id=(SELECT bron_id FROM bron WHERE bron_sleutel='eis-bijenmonitoring-meijendel');
SET @aquatic_id=(SELECT bron_id FROM bron WHERE bron_sleutel='aquatische-macrofauna-meijendel-1974-1975');
SET @ring_id=(SELECT bron_id FROM bron WHERE bron_sleutel='vrs-ringgegevens-meijendel-kandidaat');
SET @dry_id=(SELECT bron_id FROM bron WHERE bron_sleutel='droge-duinvegetatieplots-1952-2012');

DELETE FROM bron_bestand WHERE bron_id IN (@bee_id,@aquatic_id,@ring_id,@dry_id);
INSERT INTO bron_bestand (bron_id,bestand_naam,bestandstype,opslagklasse,recordaantal,sha256,toelichting) VALUES
(@bee_id,'Rapportage_Bijen_Meijendel_2019.pdf','PDF','publieke_url',54,'16a0bdfeab41f9b91c4cbb62980d95af3641f46127cc4461c1191f4574ffc79d','Rapport met drie bezoeken aan 18 proefvlakken in 2019.'),
(@bee_id,'Rapportage_Bijen_Meijendel_2021.pdf','PDF','publieke_url',54,'5db85fb90ef3d56953b43aad90a9ab36bf6dd3e569bd76b6bf202c40bbd916e5','Rapport met drie bezoeken aan 18 proefvlakken in 2021.'),
(@bee_id,'Rapportage_Bijen_Meijendel_2023.pdf','PDF','publieke_url',54,'6cf4b098e00cb16a3e143e6311c2321a2c5e82117cbcca59e8f5697895ccaf54','Rapport met drie bezoeken aan 18 proefvlakken in 2023.'),
(@aquatic_id,'Nieukerken_Doctoraalverslag_Meijendel_1978.pdf','PDF','publieke_url',7,'575fb7e07a08e418cfa8ea843ea7802527cb09c6958f72e53e5b17949c4228eb','Bron voor monsterpunten, periode en methode.'),
(@ring_id,'vt_biometrics.zip','Darwin Core Archive','publieke_url',100417,'d8ae4f07afab61e06fdb020c66ba0152c113204b40accb05bc22f1f0346b7e93','Ruimtelijke treffers; niet toelaatbaar als VRS Meijendel zonder stationsleutel.'),
(@dry_id,'proefschrift_van_der_hagen.pdf','PDF','publieke_url',41,'2d3c659e9cd0e234ac9d4605bd5fdc905a70d6abd418a74c801e24f5ee2c9a1b','Beschrijving en kaart van 41 plots; kaart bevat geen koppelbare plotcodes.');

DELETE FROM bijen_bezoek WHERE bron_id=@bee_id;
DELETE FROM bijen_proefvlak WHERE bron_id=@bee_id;
INSERT INTO bijen_proefvlak (bron_id,proefvlak_code,deelgebied,oppervlakte_ha,locatie_status,toelichting)
SELECT @bee_id,v.* FROM (VALUES ROW {plot_values.replace('),\n(', '), ROW (')}) AS v(proefvlak_code,deelgebied,oppervlakte_ha,locatie_status,toelichting);
INSERT INTO bijen_bezoek (bron_id,proefvlak_code,bezoekdatum,ronde,duur_minuten,bezoek_status,resultaten_status)
SELECT @bee_id,v.* FROM (VALUES ROW {visit_values.replace('),\n(', '), ROW (')}) AS v(proefvlak_code,bezoekdatum,ronde,duur_minuten,bezoek_status,resultaten_status);

DELETE FROM aquatisch_monsterprotocol WHERE bron_id=@aquatic_id;
DELETE FROM aquatisch_monsterpunt WHERE bron_id=@aquatic_id;
INSERT INTO aquatisch_monsterpunt (bron_id,monsterpunt_code,watercode,omschrijving,locatie_status)
SELECT @aquatic_id,v.* FROM (VALUES ROW {aquatic_points.replace('),\n(', '), ROW (')}) AS v(monsterpunt_code,watercode,omschrijving,locatie_status);
INSERT INTO aquatisch_monsterprotocol (bron_id,monsterpunt_code,datum_van,datum_tot,traject_meter,bemonsterd_oppervlak_m2,methode,vergelijkbaarheid)
SELECT @aquatic_id,v.* FROM (VALUES ROW {aquatic_protocols.replace('),\n(', '), ROW (')}) AS v(monsterpunt_code,datum_van,datum_tot,traject_meter,bemonsterd_oppervlak_m2,methode,vergelijkbaarheid);

COMMIT;
-- 162 gestandaardiseerde bezoeken zijn hiermee als context geregistreerd.
"""


def run_mysql(client: Path, login_path: str, sql: str) -> None:
    subprocess.run(
        [str(client), f"--login-path={login_path}", "--protocol=tcp", "--host=127.0.0.1", "--port=3306"],
        input=sql, text=True, check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--visits", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--mysql-client", type=Path, default=Path("/usr/local/mysql/bin/mysql"))
    parser.add_argument("--login-path", default="meijendel_root")
    parser.add_argument("--database", default="Meijendel_bronnen")
    args = parser.parse_args()
    visits = read_visits(args.visits)
    modus = "IMPORT" if args.apply else "DRY-RUN"
    print(f"{modus}: {len(BEE_PLOTS)} bijenproefvlakken; {len(visits)} bezoeken; {len(AQUATIC_POINTS)} waterpunten")
    if args.apply:
        schema = SCHEMA.read_text(encoding="utf-8").replace(
            "USE Meijendel_bronnen;", f"USE {args.database};", 1
        )
        run_mysql(args.mysql_client, args.login_path, schema + "\n" + build_sql(visits, database=args.database))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
