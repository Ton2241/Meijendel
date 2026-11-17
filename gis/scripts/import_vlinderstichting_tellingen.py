#!/usr/bin/env python3
"""Importeer uitsluitend Toves jaargegevens voor reeds geolokaliseerde telobjecten.

De drie CSV's bevatten jaaruitkomsten, geen gedateerde bezoeken. De oorspronkelijke
bestanden blijven ongewijzigd op T7; de levende geometrie bepaalt de selectie.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
import sys
import uuid
from pathlib import Path
from types import SimpleNamespace

import import_external_ecology_sources as registry
import import_vlinder_libellen_locaties as locaties


ROOT = Path(__file__).resolve().parents[2]
SOURCE = locaties.DEFAULT_SOURCE
YEARS = tuple(range(1990, 2027))
JAARCIJFERS = "Jaarcijfers_dagvlinders_perroute_Meijendel & Berkheide.csv"
BEZOEKEN = "Meijendel & Berkheide_bezoeken_per_jaar_per_route.csv"
TOTALEN = "Meijendel & Berkheide_aantalvlinders_per_jaar_per_route.csv"
BRON_SYSTEEM = "De Vlinderstichting"
BRON_DATASET = "Meetnet Vlinders - Meijendel en Berkheide"
BRON_VERSIE = "2026-11-16"
LEVERING_ID = "tove-2026-11-16"
IMPORTVERSIE = "vlinderstichting-tellingen-v1"
PROEFOMGEVINGEN = locaties.PROEFOMGEVINGEN
T7_GATE = locaties.T7_GATE


def read_csv(source: Path, filename: str) -> list[dict[str, str]]:
    with (source / filename).open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle, delimiter=";"))


def nonnegative_int(value: str, context: str) -> int:
    if not re.fullmatch(r"\d+", value.strip()):
        raise ValueError(f"{context}: verwacht geheel, niet-negatief getal: {value!r}")
    return int(value)


def overview(source: Path, filename: str) -> dict[tuple[str, str], dict[str, str]]:
    result = {}
    for row in read_csv(source, filename):
        key = row["Soortgroep"], row["countobject_name"]
        if key in result:
            raise ValueError(f"{filename}: dubbele telobjectnaam: {key}")
        if not set(map(str, YEARS)) <= row.keys():
            raise ValueError(f"{filename}: jaarbereik 1990–2026 ontbreekt")
        result[key] = row
    return result


def build_rows(source: Path, day_objects: dict[int, str],
               libel_objects: dict[int, str]) -> SimpleNamespace:
    """Selecteer alleen objecten die de levende geometriecontrole doorgaf."""
    locaties.validate_sources(source)
    if not day_objects or not libel_objects:
        raise ValueError("Geen geolokaliseerde dagvlinder- of libellenobjecten")
    if len(set(day_objects.values())) != len(day_objects) or len(set(libel_objects.values())) != len(libel_objects):
        raise ValueError("Dubbele bronnaam in levende telobjectselectie")
    visits = overview(source, BEZOEKEN)
    totals = overview(source, TOTALEN)
    if visits.keys() != totals.keys():
        raise ValueError("De twee jaaroverzichten bevatten niet dezelfde telobjecten")
    if any(visits[k]["Projectnaam"] != totals[k]["Projectnaam"] for k in visits):
        raise ValueError("Projectnaam verschilt tussen de twee jaaroverzichten")

    day_years = []
    for code, name in sorted(day_objects.items()):
        key = "dagvlinders", name
        if key not in visits:
            raise ValueError(f"Dagvlindercode {code} ontbreekt in jaaroverzicht: {name}")
        for year in YEARS:
            v = visits[key][str(year)].strip()
            t = totals[key][str(year)].strip()
            if not v and not t:
                continue
            if not v or not t:
                raise ValueError(f"Onvolledig dagvlinderroutejaar {code}/{year}")
            day_years.append({"bron_code": code, "jaar": year,
                              "bezoekaantal": nonnegative_int(v, f"bezoeken {code}/{year}"),
                              "ruw_totaal": nonnegative_int(t, f"ruw totaal {code}/{year}"),
                              "jaarstatus": "voorlopig" if year == 2026 else "afgesloten"})

    libel_years = []
    for local_id, name in sorted(libel_objects.items()):
        key = "libellen", name
        if key not in visits:
            raise ValueError(f"Libellenlocatie {local_id} ontbreekt in jaaroverzicht: {name}")
        for year in YEARS:
            v = visits[key][str(year)].strip()
            t = totals[key][str(year)].strip()
            if not v and not t:
                continue
            if not v or not t:
                raise ValueError(f"Onvolledig libellenlocatiejaar {local_id}/{year}")
            if nonnegative_int(t, f"vlindertotaal bij libellen {local_id}/{year}") != 0:
                raise ValueError("Niet-nul vlindertotaal bij libellen vergt inhoudelijke beoordeling")
            libel_years.append({"telobject_id": local_id, "jaar": year,
                                "bezoekaantal": nonnegative_int(v, f"libellenbezoeken {local_id}/{year}"),
                                "jaarstatus": "voorlopig" if year == 2026 else "afgesloten"})

    year_keys = {(r["bron_code"], r["jaar"]) for r in day_years}
    day_species_years = []
    code_names: dict[str, str] = {}
    source_keys = set()
    for row in read_csv(source, JAARCIJFERS):
        code = nonnegative_int(row["countobject_id"], "countobject_id")
        if code not in day_objects:
            continue
        parsed = locaties.POPUP.search(row["meetpunt"])
        if not parsed or parsed.group(1) != "dagvlinders" or parsed.group(2) != day_objects[code]:
            raise ValueError(f"Bronnaam wijkt af bij dagvlindercode {code}")
        year = nonnegative_int(row["visit_year"], f"jaar bij {code}")
        species_code = row["Soortcode"].strip()
        if not re.fullmatch(r"\d+", species_code):
            raise ValueError(f"Ongeldige oorspronkelijke Soortcode: {species_code!r}")
        name = row["species_name_nl"].strip()
        if not name or (species_code in code_names and code_names[species_code] != name):
            raise ValueError(f"Bronsoortnaam conflicteert bij Soortcode {species_code}")
        code_names[species_code] = name
        key = code, year, species_code
        if key in source_keys or (code, year) not in year_keys:
            raise ValueError(f"Dubbele of verweesde soortjaarregel: {key}")
        source_keys.add(key)
        day_species_years.append({"bron_code": code, "jaar": year,
                                  "soortcode": species_code,
                                  "jaarcijfer": nonnegative_int(row["jaarcijfer"], f"jaarcijfer {key}"),
                                  "ntell": nonnegative_int(row["ntell"], f"ntell {key}")})
    if {(r["bron_code"], r["jaar"]) for r in day_species_years} != year_keys:
        raise ValueError("Een dagvlinderroutejaar heeft geen soortjaarregels")
    return SimpleNamespace(day_years=day_years,
                           day_species_years=day_species_years,
                           libel_years=libel_years, code_names=code_names)


def mysql_read(sql: str) -> list[str]:
    cmd = ["/usr/local/mysql/bin/mysql", "--login-path=meijendel_root", "--protocol=TCP",
           "-h", "127.0.0.1", "-P", "3306", "-D", "Meijendel",
           "--batch", "--raw", "--skip-column-names", "-e", sql]
    result = subprocess.run(cmd, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"MySQL-lezing mislukt ({result.returncode}): {result.stderr.strip()}")
    return result.stdout.splitlines()


def live_geo_objects() -> tuple[dict[int, str], dict[int, str]]:
    day_sql = ("SELECT o.bron_code,o.bronnaam FROM vlinders_dag_telobject o "
               "WHERE EXISTS(SELECT 1 FROM vlinders_dag_geometrie g "
               "WHERE g.bron_code=o.bron_code) ORDER BY o.bron_code")
    libel_sql = ("SELECT o.telobject_id,o.bronnaam FROM libellen_telobject o "
                 "WHERE EXISTS(SELECT 1 FROM libellen_geometrie g "
                 "WHERE g.telobject_id=o.telobject_id) ORDER BY o.telobject_id")
    def parse(lines: list[str]) -> dict[int, str]:
        return {int(code): name for code, name in (line.split("\t", 1) for line in lines)}
    day, libel = parse(mysql_read(day_sql)), parse(mysql_read(libel_sql))
    if day != locaties.SELECTED_DAG or set(libel.values()) != set(locaties.SELECTED_LIBELLEN):
        raise ValueError("De levende geometrieselectie wijkt af van Tons elf plus elf telobjecten")
    return day, libel


def sql_text(value: str) -> str:
    """Een UTF-8-hexliteral voorkomt SQL-escaping en codeverlies in bronnamen."""
    return "CONVERT(X'" + value.encode("utf-8").hex() + "' USING utf8mb4)"


def sql_rows(table: str, columns: tuple[str, ...], values: list[tuple[str, ...]],
             *, chunk_size: int = 400) -> list[str]:
    if not values:
        return []
    statement = f"INSERT INTO {table} ({','.join(columns)}) VALUES "
    return [statement + ',\n'.join('(' + ','.join(row) + ')' for row in values[i:i + chunk_size]) + ';'
            for i in range(0, len(values), chunk_size)]


def live_taxon_plan(code_names: dict[str, str]) -> SimpleNamespace:
    """Koppel broncodes nominaal; creëer alleen het aantoonbaar ontbrekende taxon."""
    taxon_sql = ("SELECT JSON_OBJECT('taxon_id',taxon_id,'groep_id',groep_id,"
                 "'wetenschappelijke_naam',wetenschappelijke_naam,"
                 "'naam_zonder_auteur',naam_zonder_auteur,'naam_auteur',naam_auteur,"
                 "'nederlandse_naam',nederlandse_naam,'weergavenaam',weergavenaam,"
                 "'taxonvorm',taxonvorm,'taxonrang',taxonrang) FROM taxa")
    taxa = [json.loads(line) for line in mysql_read(taxon_sql)]
    if mysql_read("SELECT groep_id FROM taxon_groepen WHERE groep_code='dagvlinders'") != ['3']:
        raise ValueError("De centrale dagvlindergroep is niet eenduidig groep 3")
    active = mysql_read("SELECT COUNT(*) FROM taxa_bronkoppeling WHERE "
                        "bron_systeem='De Vlinderstichting' AND "
                        "bron_dataset='Meetnet Vlinders - Meijendel en Berkheide' AND "
                        "bron_versie='2026-11-16' AND ingetrokken_op IS NULL")
    if active != ['0']:
        raise ValueError("Tove-brontaxoncodes bestaan al; niet opnieuw importeren")
    by_name: dict[str, list[dict]] = {}
    for taxon in taxa:
        if taxon['groep_id'] == 3 and taxon['nederlandse_naam']:
            by_name.setdefault(taxon['nederlandse_naam'].casefold(), []).append(taxon)
    targets = {}
    missing = set()
    for code, name in code_names.items():
        matches = by_name.get(name.casefold(), [])
        if len(matches) == 1:
            targets[code] = matches[0]
        elif not matches:
            missing.add(name)
        else:
            raise ValueError(f"Ambigue centrale dagvlindernaam: {name}")
    if missing != {'grote weerschijnvlinder'}:
        raise ValueError(f"Onverwachte ontbrekende dagvlindertaxa: {sorted(missing)}")
    missing_codes = [code for code, name in code_names.items() if name in missing]
    if missing_codes != ['66']:
        raise ValueError(f"Grote weerschijnvlinder heeft onverwachte broncodes: {missing_codes}")
    links_sql = ("SELECT JSON_OBJECT('bron_systeem',bron_systeem,'bron_dataset',bron_dataset,"
                 "'bron_versie',bron_versie,'bron_taxon_id',bron_taxon_id,"
                 "'taxon_id',taxon_id,'ingetrokken_op',ingetrokken_op,"
                 "'bronmetadata',bronmetadata) FROM taxa_bronkoppeling "
                 "WHERE bron_systeem='Meijendel' AND bron_dataset='taxa_naamgebruik_archief'")
    links = [json.loads(line) for line in mysql_read(links_sql)]
    source = {'bron_systeem': BRON_SYSTEEM, 'bron_dataset': BRON_DATASET,
              'bron_versie': BRON_VERSIE, 'bron_taxon_id': '66',
              'bron_nederlandse_naam': 'grote weerschijnvlinder'}
    new_taxon = {'groep_id': 3, 'wetenschappelijke_naam': 'Apatura iris',
                 'naam_zonder_auteur': 'Apatura iris',
                 'nederlandse_naam': 'Grote weerschijnvlinder',
                 'taxonvorm': 'taxon', 'taxonrang': 'species'}
    prepared = registry.prepare_registry_import(source, new_taxon, taxa, links)
    if prepared['nieuw_taxon'] is None or prepared['taxon_id'] is not None:
        raise ValueError("Een bestaand Apatura-taxon vereist een nieuwe inhoudelijke beoordeling")
    return SimpleNamespace(targets=targets, new_taxon=prepared['nieuw_taxon'])


def import_sql(rows: SimpleNamespace, day_objects: dict[int, str],
               libel_objects: dict[int, str], taxon_plan: SimpleNamespace) -> str:
    """Maak één gecontroleerde, transactionele import zonder NDFF-mutaties."""
    target = taxon_plan.targets
    if set(target) != set(rows.code_names) - {'66'}:
        raise ValueError("Niet alle bestaande broncodes hebben één centraal dagvlindertaxon")
    annual_hash = locaties.SOURCE_FILES[JAARCIJFERS]
    manifest = json.dumps(locaties.SOURCE_FILES, ensure_ascii=False, sort_keys=True)
    new = taxon_plan.new_taxon
    guard = "INSERT INTO tove_import_guard(ok) SELECT "
    sql = ["USE Meijendel;", "SET NAMES utf8mb4;", "SET SESSION innodb_lock_wait_timeout=10;",
           "CREATE TEMPORARY TABLE tove_import_guard(ok TINYINT NOT NULL CHECK(ok=1));",
           "CREATE TEMPORARY TABLE tove_code_plan("
           "soortcode VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY, "
           "bron_naam VARCHAR(1000) NOT NULL, taxon_id BIGINT UNSIGNED NULL, "
           "wetenschappelijke_naam VARCHAR(500) NULL);",
           "CREATE TEMPORARY TABLE tove_soortjaar_plan("
           "bron_code SMALLINT UNSIGNED NOT NULL, jaar SMALLINT UNSIGNED NOT NULL, "
           "soortcode VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, "
           "jaarcijfer INT UNSIGNED NOT NULL, ntell SMALLINT UNSIGNED NOT NULL, "
           "PRIMARY KEY(bron_code,jaar,soortcode));"]
    codes = []
    for code, name in sorted(rows.code_names.items(), key=lambda item: int(item[0])):
        taxon = target.get(code)
        codes.append((sql_text(code), sql_text(name),
                      str(taxon['taxon_id']) if taxon else 'NULL',
                      sql_text(taxon['wetenschappelijke_naam']) if taxon else 'NULL'))
    sql += sql_rows('tove_code_plan', ('soortcode','bron_naam','taxon_id','wetenschappelijke_naam'), codes)
    species = [(str(r['bron_code']),str(r['jaar']),sql_text(r['soortcode']),
                str(r['jaarcijfer']),str(r['ntell'])) for r in rows.day_species_years]
    sql += sql_rows('tove_soortjaar_plan',
                    ('bron_code','jaar','soortcode','jaarcijfer','ntell'),species)
    sql += ["START TRANSACTION;",
            guard + "COUNT(*)=0 FROM vlinderstichting_levering;",
            guard + "COUNT(*)=0 FROM vlinders_dag_routejaar;",
            guard + "COUNT(*)=0 FROM vlinders_dag_routejaar_soortcode;",
            guard + "COUNT(*)=0 FROM libellen_routejaar;",
            guard + f"COUNT(*)={len(rows.code_names)} FROM tove_code_plan;",
            guard + f"COUNT(*)={len(rows.day_species_years)} FROM tove_soortjaar_plan;",
            guard + "COUNT(*)=0 FROM taxa_bronkoppeling WHERE "
                    "bron_systeem=" + sql_text(BRON_SYSTEEM) + " AND bron_dataset=" +
                    sql_text(BRON_DATASET) + " AND bron_versie=" + sql_text(BRON_VERSIE) + ";",
            guard + "COUNT(*)=0 FROM taxa WHERE wetenschappelijke_naam='Apatura iris' "
                    "OR nederlandse_naam='Grote weerschijnvlinder' "
                    "OR weergavenaam='Grote weerschijnvlinder';",
            guard + "COUNT(*)=1 FROM taxon_groepen WHERE groep_id=3 AND groep_code='dagvlinders';",
            guard + f"COUNT(*)={len(target)} "
                    "FROM tove_code_plan p JOIN taxa t ON t.taxon_id=p.taxon_id "
                    "WHERE p.taxon_id IS NOT NULL AND LOWER(t.nederlandse_naam)=LOWER(p.bron_naam) "
                    "AND BINARY t.wetenschappelijke_naam=BINARY p.wetenschappelijke_naam "
                    "AND t.groep_id=3 AND t.beheerstatus='voorlopig';"]
    for code, name in day_objects.items():
        sql.append(guard + "EXISTS(SELECT 1 FROM vlinders_dag_telobject o "
                   "WHERE o.bron_code=" + str(code) + " AND BINARY o.bronnaam=BINARY " + sql_text(name) +
                   " AND EXISTS(SELECT 1 FROM vlinders_dag_geometrie g WHERE g.bron_code=o.bron_code));")
    for local_id, name in libel_objects.items():
        sql.append(guard + "EXISTS(SELECT 1 FROM libellen_telobject o "
                   "WHERE o.telobject_id=" + str(local_id) + " AND BINARY o.bronnaam=BINARY " + sql_text(name) +
                   " AND EXISTS(SELECT 1 FROM libellen_geometrie g WHERE g.telobject_id=o.telobject_id));")
    sql += ["INSERT INTO taxa(taxon_uuid,groep_id,wetenschappelijke_naam,"
            "naam_zonder_auteur,nederlandse_naam,weergavenaam,taxonrang,taxonvorm,"
            "taxonomische_status,beheerstatus,naam_volgens,opmerkingen) VALUES ("+
            ','.join((sql_text(str(uuid.uuid4())), '3',sql_text('Apatura iris'),
                      sql_text('Apatura iris'), sql_text('Grote weerschijnvlinder'),
                      sql_text(new['weergavenaam']),sql_text('species'),sql_text('taxon'),
                      sql_text('unresolved'),sql_text('voorlopig'),
                      sql_text('De Vlinderstichting, soortpagina Grote weerschijnvlinder, geraadpleegd 2026-11-17'),
                      sql_text('Nominaal broncode 66; 2026-waarde voorlopig. Taxonconcept niet afzonderlijk vastgesteld.'))) + ");",
            "SET @tove_apatura_id=LAST_INSERT_ID();",
            guard + "@tove_apatura_id>0;",
            "INSERT INTO taxa_bronkoppeling("
            "bron_systeem,bron_dataset,bron_versie,bron_taxon_id,bron_sleuteltype,"
            "bron_nederlandse_naam,bron_soortgroep,bronbestand_sha256,taxon_id,"
            "koppelstatus,taxonrelatie,koppelmethode,regelversie,onderbouwing) "
            "SELECT "+sql_text(BRON_SYSTEEM)+','+sql_text(BRON_DATASET)+','+sql_text(BRON_VERSIE)+
            ",p.soortcode,'oorspronkelijk',p.bron_naam,'dagvlinders',"+sql_text(annual_hash)+
            ",COALESCE(p.taxon_id,@tove_apatura_id),'kandidaat','onbekend',"
            "'broncode_en_gecontroleerde_naam',"+sql_text(IMPORTVERSIE)+
            ",'Nominale broncode-naamkoppeling; taxonconcept niet als gelijk bewezen' "
            "FROM tove_code_plan p ORDER BY CAST(p.soortcode AS UNSIGNED);",
            guard + f"COUNT(*)={len(rows.code_names)} FROM taxa_bronkoppeling WHERE "
                    "bron_systeem="+sql_text(BRON_SYSTEEM)+" AND bron_dataset="+
                    sql_text(BRON_DATASET)+" AND bron_versie="+sql_text(BRON_VERSIE)+
                    " AND bronbestand_sha256="+sql_text(annual_hash)+" AND koppelstatus='kandidaat';",
            "INSERT INTO vlinderstichting_levering(levering_id,bronhouder,ontvangen_op,"
            "bronbestanden_json,importversie,rechtenstatus) VALUES ("+
            ','.join((sql_text(LEVERING_ID),sql_text(BRON_SYSTEEM),sql_text('2026-11-16'),
                      sql_text(manifest),sql_text(IMPORTVERSIE),
                      sql_text('Gebruiksrechten voor externe publicatie niet afzonderlijk vastgesteld'))) + ");"]
    day_values = [(str(r['bron_code']),str(r['jaar']),str(r['bezoekaantal']),
                   str(r['ruw_totaal']),sql_text(r['jaarstatus']),sql_text(LEVERING_ID))
                  for r in rows.day_years]
    sql += sql_rows('vlinders_dag_routejaar',
                    ('bron_code','jaar','bezoekaantal','ruw_totaal','jaarstatus','levering_id'),day_values)
    libel_values = [(str(r['telobject_id']),str(r['jaar']),str(r['bezoekaantal']),
                     sql_text(r['jaarstatus']),sql_text(LEVERING_ID)) for r in rows.libel_years]
    sql += sql_rows('libellen_routejaar',
                    ('telobject_id','jaar','bezoekaantal','jaarstatus','levering_id'),libel_values)
    sql += ["INSERT INTO vlinders_dag_routejaar_soortcode("
            "bron_code,jaar,soortcode,jaarcijfer,ntell,taxon_bronkoppeling_id) "
            "SELECT s.bron_code,s.jaar,s.soortcode,s.jaarcijfer,s.ntell,b.koppeling_id "
            "FROM tove_soortjaar_plan s JOIN taxa_bronkoppeling b "
            "ON BINARY b.bron_taxon_id=BINARY s.soortcode AND b.bron_systeem="+
            sql_text(BRON_SYSTEEM)+" AND b.bron_dataset="+sql_text(BRON_DATASET)+
            " AND b.bron_versie="+sql_text(BRON_VERSIE)+
            " AND b.bronbestand_sha256="+sql_text(annual_hash)+
            " AND b.koppelstatus='kandidaat' AND b.ingetrokken_op IS NULL;",
            guard + f"COUNT(*)={len(rows.day_years)} FROM vlinders_dag_routejaar;",
            guard + f"COUNT(*)={len(rows.libel_years)} FROM libellen_routejaar;",
            guard + f"COUNT(*)={len(rows.day_species_years)} FROM vlinders_dag_routejaar_soortcode;",
            guard + "SUM(jaarcijfer=0)="+
                    str(sum(r['jaarcijfer']==0 for r in rows.day_species_years))+
                    " FROM vlinders_dag_routejaar_soortcode;",
            "COMMIT;",
            "SELECT 'tove-import',COUNT(*) FROM vlinders_dag_routejaar_soortcode;"]
    return '\n'.join(sql) + '\n'


def audit_live(rows: SimpleNamespace) -> None:
    queries = {
        'dagroutejaren': "SELECT COUNT(*) FROM vlinders_dag_routejaar",
        'dagbezoeken': "SELECT COALESCE(SUM(bezoekaantal),0) FROM vlinders_dag_routejaar",
        'soortcodejaren': "SELECT COUNT(*) FROM vlinders_dag_routejaar_soortcode",
        'jaarcijfer_nullen': "SELECT COUNT(*) FROM vlinders_dag_routejaar_soortcode WHERE jaarcijfer=0",
        'libellenlocatiejaren': "SELECT COUNT(*) FROM libellen_routejaar",
        'libellenbezoeken': "SELECT COALESCE(SUM(bezoekaantal),0) FROM libellen_routejaar",
        'voorlopig_2026': "SELECT COUNT(*) FROM vlinders_dag_routejaar_soortcode WHERE jaar=2026",
        'actieve_broncodes': "SELECT COUNT(*) FROM taxa_bronkoppeling WHERE "
                            "bron_systeem='De Vlinderstichting' AND "
                            "bron_dataset='Meetnet Vlinders - Meijendel en Berkheide' "
                            "AND bron_versie='2026-11-16' AND koppelstatus='kandidaat' "
                            "AND ingetrokken_op IS NULL",
        'ontbrekende_taxonroute': "SELECT COUNT(*) FROM vlinders_dag_routejaar_soortcode s "
                                 "LEFT JOIN taxa_bronkoppeling b ON b.koppeling_id=s.taxon_bronkoppeling_id "
                                 "LEFT JOIN taxa t ON t.taxon_id=b.taxon_id "
                                 "LEFT JOIN taxon_groepen g ON g.groep_id=t.groep_id "
                                 "WHERE b.koppeling_id IS NULL OR t.taxon_id IS NULL OR g.groep_code<>'dagvlinders'",
        'geen_daggeometrie': "SELECT COUNT(*) FROM vlinders_dag_routejaar r WHERE NOT EXISTS "
                             "(SELECT 1 FROM vlinders_dag_geometrie g WHERE g.bron_code=r.bron_code)",
        'geen_libelgeometrie': "SELECT COUNT(*) FROM libellen_routejaar r WHERE NOT EXISTS "
                               "(SELECT 1 FROM libellen_geometrie g WHERE g.telobject_id=r.telobject_id)",
        'broncode_conflict': "SELECT COUNT(*) FROM vlinders_dag_routejaar_soortcode s "
                             "JOIN taxa_bronkoppeling b ON b.koppeling_id=s.taxon_bronkoppeling_id "
                             "WHERE BINARY s.soortcode<>BINARY b.bron_taxon_id OR "
                             "b.bron_systeem<>'De Vlinderstichting' OR "
                             "b.bron_dataset<>'Meetnet Vlinders - Meijendel en Berkheide'",
    }
    expected = {
        'dagroutejaren': len(rows.day_years),
        'dagbezoeken': sum(r['bezoekaantal'] for r in rows.day_years),
        'soortcodejaren': len(rows.day_species_years),
        'jaarcijfer_nullen': sum(r['jaarcijfer']==0 for r in rows.day_species_years),
        'libellenlocatiejaren': len(rows.libel_years),
        'libellenbezoeken': sum(r['bezoekaantal'] for r in rows.libel_years),
        'voorlopig_2026': sum(r['jaar']==2026 for r in rows.day_species_years),
        'actieve_broncodes': len(rows.code_names),
        'ontbrekende_taxonroute': 0,
        'geen_daggeometrie': 0,
        'geen_libelgeometrie': 0,
        'broncode_conflict': 0,
    }
    for label, query in queries.items():
        result = mysql_read(query)
        if result != [str(expected[label])]:
            raise ValueError(f"Live audit {label}: verwacht {expected[label]}, gevonden {result}")
    fact_checks = [
        ("dagroutejaren", rows.day_years, ("bron_code","jaar","bezoekaantal","ruw_totaal","jaarstatus"),
         "SELECT JSON_OBJECT('bron_code',bron_code,'jaar',jaar,'bezoekaantal',bezoekaantal,"
         "'ruw_totaal',ruw_totaal,'jaarstatus',jaarstatus) FROM vlinders_dag_routejaar"),
        ("soortcodejaren", rows.day_species_years,
         ("bron_code","jaar","soortcode","jaarcijfer","ntell"),
         "SELECT JSON_OBJECT('bron_code',bron_code,'jaar',jaar,'soortcode',soortcode,"
         "'jaarcijfer',jaarcijfer,'ntell',ntell) FROM vlinders_dag_routejaar_soortcode"),
        ("libellenlocatiejaren", rows.libel_years,
         ("telobject_id","jaar","bezoekaantal","jaarstatus"),
         "SELECT JSON_OBJECT('telobject_id',telobject_id,'jaar',jaar,"
         "'bezoekaantal',bezoekaantal,'jaarstatus',jaarstatus) FROM libellen_routejaar"),
    ]
    for label, expected_rows, fields, query in fact_checks:
        make_key = lambda r: tuple(r[field] for field in fields)
        actual_rows = [json.loads(line) for line in mysql_read(query)]
        if sorted(map(make_key,actual_rows)) != sorted(map(make_key,expected_rows)):
            raise ValueError(f"Live audit {label}: inhoud verschilt regel voor regel van de bron")
    link_query = ("SELECT JSON_OBJECT('code',bron_taxon_id,'naam',bron_nederlandse_naam) "
                  "FROM taxa_bronkoppeling WHERE bron_systeem='De Vlinderstichting' AND "
                  "bron_dataset='Meetnet Vlinders - Meijendel en Berkheide' AND "
                  "bron_versie='2026-11-16' AND ingetrokken_op IS NULL")
    actual_names = {r['code']:r['naam'] for r in (json.loads(line) for line in mysql_read(link_query))}
    if actual_names != rows.code_names:
        raise ValueError("Live audit: broncode-namen wijken af van Toves CSV")
    print("Live audit geslaagd: 11 dagroutes, 11 libellenlocaties, "
          "alle jaarregels, broncodejaar-nullen en centrale taxonroutes kloppen")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--audit-live", action="store_true")
    mode.add_argument("--output-sql", type=Path)
    args = parser.parse_args()
    day, libel = live_geo_objects()
    rows = build_rows(args.source, day, libel)
    if args.audit_live:
        audit_live(rows)
        return
    output = args.output_sql.resolve()
    if not output.is_relative_to(PROEFOMGEVINGEN) or not output.parent.is_dir():
        raise ValueError("Import-SQL moet in een bestaande geregistreerde T7-proefmap staan")
    gate = subprocess.run([sys.executable,str(T7_GATE),'check',str(output)],
                          text=True,capture_output=True)
    if gate.returncode:
        raise ValueError(f"T7-uitvoer geweigerd: {gate.stderr.strip()}")
    plan = live_taxon_plan(rows.code_names)
    output.write_text(import_sql(rows, day, libel, plan),encoding='utf-8')
    print(f"Importbestand: {output}")
    print(f"SHA-256: {locaties.sha256_file(output)}")
    print(f"Selectie: {len(day)} dagroutes, {len(libel)} libellenlocaties; "
          f"{len(rows.day_years)} dagroutejaren, {len(rows.day_species_years)} soortcodejaren, "
          f"{len(rows.libel_years)} libellenlocatiejaren")


if __name__ == "__main__":
    main()
