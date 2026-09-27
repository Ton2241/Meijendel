#!/usr/bin/env python3
"""Alleen-lezen structuurpoort voor het taxonregister; geen taxonimporttest.

Dit controleert het werkelijk aangemaakte MySQL-schema, niet SQL-brontekst.
Opzettelijk geen inserts: gegevensproeven volgen na afzonderlijke opdracht.
"""
from __future__ import annotations

import argparse
import subprocess

TABLES = {"taxon_groepen", "taxa", "taxa_bronkoppeling"}
GROUP_CODES = {
    'vogels', 'amfibieen', 'dagvlinders', 'eencelligen', 'geleedpotigen_overig',
    'insecten_overig', 'kevers', 'korstmossen', 'kranswieren_wieren_algen',
    'kreeftachtigen', 'libellen', 'microvlinders', 'mossen', 'nachtvlinders',
    'ongewervelden_overig', 'reptielen', 'schimmels', 'snavelinsecten',
    'spinachtigen', 'sprinkhanen_en_krekels', 'vaatplanten', 'vissen',
    'vleermuizen', 'vliegen_en_muggen', 'vliesvleugeligen', 'weekdieren',
    'zoogdieren_overig',
}
MYSQL = ["/usr/local/mysql/bin/mysql", "--login-path=meijendel_root",
         "--protocol=TCP", "--host=127.0.0.1", "--port=3306",
         "--batch", "--raw", "--skip-column-names", "Meijendel"]


def rows(sql: str) -> list[list[str]]:
    result = subprocess.run(MYSQL + ["-e", "START TRANSACTION READ ONLY; " + sql + "; COMMIT;"],
                            check=True, text=True, capture_output=True)
    return [line.split("\t") for line in result.stdout.splitlines()]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fase', choices=['leeg', 'groepen'], default='groepen',
                        help='leeg: historische installatiepoort; groepen: catalogus v1')
    args = parser.parse_args()
    scope = "table_schema=DATABASE() AND table_name IN ('taxon_groepen','taxa','taxa_bronkoppeling')"
    found = rows("SELECT table_name,engine,table_collation FROM information_schema.tables WHERE " + scope)
    assert {r[0] for r in found} == TABLES, f"Taxonregister ontbreekt of is onvolledig: {found}"
    assert all(r[1:] == ["InnoDB", "utf8mb4_0900_ai_ci"] for r in found), found
    print("OK: drie fysieke InnoDB-tabellen met Unicode")

    cols = {(r[0], r[1]): r[2:] for r in rows(
        "SELECT table_name,column_name,is_nullable,data_type FROM information_schema.columns WHERE " + scope)}
    for table, field in [("taxa", "groep_id"), ("taxa", "nederlandse_naam"),
                         ("taxa", "taxonrang"), ("taxa_bronkoppeling", "taxon_id")]:
        assert cols[table, field][0] == "YES", (table, field)
    for field in ["taxon_uuid", "wetenschappelijke_naam", "naam_auteur", "naam_volgens",
                  "naam_volgens_id", "naam_volgens_versie", "taxonomische_status",
                  "bovenliggend_taxon_id", "geaccepteerd_taxon_id", "oorspronkelijk_taxon_id",
                  "nomenclatuurcode", "naam_identificatie", "concept_identificatie",
                  "aanvullende_namen", "taxonmetadata"]:
        assert ("taxa", field) in cols, field
    for field in ["bron_systeem", "bron_dataset", "bron_versie", "bron_taxon_id",
                  "bron_wetenschappelijke_naam", "bron_taxonrang", "bron_taxonomische_status",
                  "bronmetadata", "koppelstatus", "taxonrelatie", "koppelmethode",
                  "regelversie", "onderbouwing", "beoordeeld_door", "beoordeeld_op",
                  "besluitversie", "ingetrokken_op", "bron_identiteit_sha256"]:
        assert ("taxa_bronkoppeling", field) in cols, field
    print("OK: identiteit, taxonrang, naamgebruik, bronversie en beoordeling afzonderlijk")

    fks = rows("SELECT table_name,column_name,referenced_table_name,referenced_column_name "
               "FROM information_schema.key_column_usage WHERE " + scope + " AND referenced_table_name IS NOT NULL")
    assert {tuple(r) for r in fks} == {
        ('taxon_groepen', 'bovenliggende_groep_id', 'taxon_groepen', 'groep_id'),
        ('taxa', 'groep_id', 'taxon_groepen', 'groep_id'),
        ('taxa', 'bovenliggend_taxon_id', 'taxa', 'taxon_id'),
        ('taxa', 'geaccepteerd_taxon_id', 'taxa', 'taxon_id'),
        ('taxa', 'oorspronkelijk_taxon_id', 'taxa', 'taxon_id'),
        ('taxa_bronkoppeling', 'taxon_id', 'taxa', 'taxon_id'),
    }, fks
    incoming = rows("SELECT table_name FROM information_schema.key_column_usage "
                    "WHERE referenced_table_schema=DATABASE() AND referenced_table_name "
                    "IN ('taxon_groepen','taxa','taxa_bronkoppeling') "
                    "AND table_name NOT IN ('taxon_groepen','taxa','taxa_bronkoppeling')")
    assert not incoming, incoming
    rules = rows("SELECT delete_rule,update_rule FROM information_schema.referential_constraints "
                 "WHERE constraint_schema=DATABASE() AND table_name IN ('taxon_groepen','taxa','taxa_bronkoppeling')")
    assert all(rule in {"RESTRICT", "NO ACTION"} for row in rules for rule in row), rules
    print("OK: zes interne relaties, geen wijziging aan bestaande relaties en geen cascades")

    unique = rows("SELECT table_name,index_name,GROUP_CONCAT(column_name ORDER BY seq_in_index) "
                  "FROM information_schema.statistics WHERE " + scope + " AND non_unique=0 "
                  "GROUP BY table_name,index_name")
    keys = {r[1]: r[2] for r in unique}
    assert keys["uq_taxon_groep_code"] == "groep_code"
    assert keys["uq_taxa_uuid"] == "taxon_uuid"
    assert keys["uq_taxa_bron_besluit"] == "bron_identiteit_sha256,besluitversie,doeltaxon_sleutel"
    assert keys["uq_taxa_bron_actief_exact"] == "actieve_exacte_bron"
    assert not any(r[0] == "taxa" and r[2] == "wetenschappelijke_naam" for r in unique)
    checks = rows("SELECT constraint_name,enforced FROM information_schema.table_constraints WHERE "
                  + scope + " AND constraint_type='CHECK'")
    assert len(checks) == 24 and all(r[1] == "YES" for r in checks), checks
    print("OK: unieke bronidentiteit/besluiten, geen unieke naam, actieve CHECK-regels")

    empty_tables = TABLES if args.fase == 'leeg' else TABLES - {'taxon_groepen'}
    for table in sorted(empty_tables):
        assert rows(f"SELECT COUNT(*) FROM {table}") == [["0"]], f"Niet leeg: {table}"
    if args.fase == 'groepen':
        groups = rows("SELECT groep_code,groep_naam,bovenliggende_groep_id,actief,"
                      "indeling_versie,JSON_UNQUOTE(JSON_EXTRACT(groepmetadata,'$.indelingstype')) "
                      "FROM taxon_groepen")
        assert {r[0] for r in groups} == GROUP_CODES, f'Groepscatalogus ontbreekt of wijkt af: {groups}'
        assert len(groups) == 27, groups
        assert all(r[1] and r[2:] == ['NULL', '1', 'meijendel-soortgroepen-v1',
                                     'praktische_soortgroep'] for r in groups), groups
        incomplete = rows("SELECT groep_code FROM taxon_groepen WHERE omschrijving IS NULL "
                          "OR CHAR_LENGTH(TRIM(omschrijving))=0 OR indeling_bron IS NULL "
                          "OR CHAR_LENGTH(TRIM(indeling_bron))=0")
        assert not incomplete, incomplete
        uncovered = rows("SELECT DISTINCT k.soortgroep_code FROM ndff_open_soortgroep_koppeling k "
                         "LEFT JOIN taxon_groepen g ON g.groep_code=k.soortgroep_code "
                         "WHERE g.groep_id IS NULL")
        assert not uncovered, f'Bestaande groepscodes ontbreken: {uncovered}'
        assert rows("SELECT groep_naam FROM taxon_groepen WHERE groep_code='vogels'") == [['Vogels']]
        print('OK: 27 brononafhankelijke gebruiksgroepen; bestaande groepscodes volledig gedekt')
    triggers = rows("SELECT trigger_name FROM information_schema.triggers WHERE trigger_schema=DATABASE() "
                    "AND event_object_table IN ('taxon_groepen','taxa','taxa_bronkoppeling')")
    assert not triggers, triggers
    print(f"OK: fase {args.fase}; taxa en bronkoppelingen leeg, geen triggers")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
