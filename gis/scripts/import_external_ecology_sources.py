#!/usr/bin/env python3
"""Selecteer en importeer geografisch toegelaten openbare ecologiebronnen.

De ruwe Darwin Core-archieven blijven buiten Git. Dit script leest de eerder
met ``profile_external_dwca.py`` gemaakte Meijendelselecties en schrijft een
herhaalbare, transactionele import voor de analytische database ``Meijendel``.
"""

from __future__ import annotations

import argparse
import calendar
import copy
import csv
import hashlib
import gzip
import json
import re
import subprocess
import tempfile
import unicodedata
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis" / "database" / "external_ecology_schema.sql"
DATABASE = "Meijendel"
IMPORT_VERSION = "externe-ecologie-v1"

FUSION_RULE = 'taxa-gerichte-fusie-v1'
CENTRAL_RULE = 'taxa-centrale-lijst-v1'

QUERY_RULE = 'taxa-centrale-querypoort-v1'
SOURCE_TAXON_FIELDS = (
    'taxonID', 'taxonKey', 'scientificNameID', 'acceptedNameUsageID',
    'nameAccordingTo', 'nameAccordingToID', 'scientificName', 'scientificNameAuthorship',
    'kingdom', 'phylum', 'class', 'order', 'family', 'genus', 'taxonRank',
    'verbatimTaxonRank', 'taxonomicStatus', 'nomenclaturalCode', 'taxonRemarks',
    'higherClassification',
)
SOURCE_USAGE_FIELDS = (*SOURCE_TAXON_FIELDS, 'dataset', 'name', 'raw_name', 'nl', 'rank')
STAGING_TABLES = {'import_dagwaarnemingen_raw', 'import_resultaten_raw',
                  'import_waarnemingen_breed', 'import_waarnemingen_lang'}
SOURCE_FAMILIES = {
    'endure-helmduinfauna-meijendel-2018': 'endure',
    'stowa-limnodata-meijendel': 'stowa_limnodata',
    'naturalis-botany-meijendel': 'naturalis_botany',
    'naturalis-coleoptera-meijendel': 'naturalis_coleoptera',
    'nmr-vlinders-meijendel': 'nmr_vlinders',
}
SOURCE_SUFFIXES = ('dataset', 'event', 'resultaat', 'overlap')


def source_family_tables() -> dict[str, str]:
    return {prefix+'_'+suffix: 'externe_ecologie_'+suffix
            for prefix in SOURCE_FAMILIES.values() for suffix in SOURCE_SUFFIXES}


def source_family_for_dataset(key: str) -> str:
    if key == 'lvd-meijendel-v1-6':
        return 'externe_ecologie'
    if key not in SOURCE_FAMILIES:
        raise ValueError('Onbeoordeelde bron: geen stilzwijgende generieke import')
    return SOURCE_FAMILIES[key]


def source_usage_projection(metadata: dict) -> dict:
    """Historic taxon context, excluding subsequent merge/review annotations."""
    return {field: metadata.get(field) for field in SOURCE_USAGE_FIELDS}


def derived_source_key(route: dict, row: dict) -> str:
    return json.dumps([row[route['name_field']], *[row.get(c) for c in route['context_fields']]],
                      ensure_ascii=False, separators=(',', ':'))


def central_query_routes(schema: dict[str, set[str]]) -> dict[str, dict]:
    """Discover every taxon-bearing layer; unknown semantics fail closed.

    Discovery is not acceptance: the live gate additionally requires the actual
    FK, row-level coverage and write guards for every discovered direct route.
    Temporary imports are never accepted as committed observational data.
    """
    catalogues = {
        'soorten': {'id': 'id', 'name_field': 'latijnse_naam', 'nullable': True},
        'ndff_soorten': {'id': 'soort_key', 'name_field': 'wetenschappelijke_naam'},
        'sovon_avimap_taxon': {'id': 'batch_id,soortgroep_code,soortnr',
                             'name_field': 'wetenschappelijke_naam'},
    }
    routes = {}
    for table, columns in schema.items():
        if not re.fullmatch('[a-zA-Z][a-zA-Z0-9_]*', table):
            raise ValueError('Ongeldige tabelidentifier')
        if table in {'taxa', 'taxa_bronkoppeling', 'taxon_groepen'}:
            continue
        if table in STAGING_TABLES:
            routes[table] = {'kind': 'staging'}
        elif table in catalogues:
            routes[table] = {'kind': 'catalogue', **catalogues[table]}
        elif table == 'ndff_open_waarneming':
            routes[table] = {'kind': 'catalogue_child', 'catalogue': 'ndff_soorten',
                             'join': 'w.soort_key=c.soort_key', 'role': 'bronwaarneming'}
        elif table == 'sovon_avimap_waarneming':
            routes[table] = {'kind': 'catalogue_child', 'catalogue': 'sovon_avimap_taxon',
                'join': 'w.batch_id=c.batch_id AND w.soortgroep_code=c.soortgroep_code AND w.soortnr=c.soortnr',
                'role': 'bronwaarneming'}
        elif 'soort_id' in columns:
            routes[table] = {'kind': 'catalogue_child', 'catalogue': 'soorten',
                             'join': 'w.soort_id=c.id',
                             'role': 'bronwaarneming' if 'jaar' in columns else 'soortreferentie'}
        elif table == 'externe_ecologie_resultaat' or table in {
                prefix+'_resultaat' for prefix in SOURCE_FAMILIES.values()}:
            routes[table] = {'kind': 'external', 'role': 'bronwaarneming'}
            if table != 'externe_ecologie_resultaat':
                prefix = table.removesuffix('_resultaat')
                routes[table].update(event_table=prefix+'_event', dataset_table=prefix+'_dataset')
        elif table.startswith(('ndff_', 'sovon_avimap_')) and ('waarneming_id' in columns or 'ndff_waarneming_id' in columns):
            field = 'waarneming_id' if 'waarneming_id' in columns else 'ndff_waarneming_id'
            routes[table] = {'kind': 'ndff_child', 'join': f'w.{field}=o.waarneming_id',
                             'role': 'bronverwijzing'}
        elif table.startswith(('ndff_', 'sovon_avimap_')) and columns & {'wetenschappelijke_naam', 'doelsoort'}:
            name = 'wetenschappelijke_naam' if 'wetenschappelijke_naam' in columns else 'doelsoort'
            version = 'reconstructieversie' if 'reconstructieversie' in columns else 'regelversie'
            if version not in columns:
                raise ValueError(f'{table}: bronversie ontbreekt')
            routes[table] = {'kind': 'derived', 'name_field': name, 'version_field': version,
                'context_fields': sorted(columns & {'soortgroep_raw', 'batch_id', 'protocol_id'}),
                'nullable': name == 'doelsoort',
                'role': 'afgeleide_meting' if columns & {'waarnemingsstatus','jaarstatus','doelsoortstatus'}
                        else 'soortreferentie'}
        elif 'taxon_bronkoppeling_id' in columns:
            routes[table] = {'kind': 'direct', 'role': 'bronwaarneming'}
        elif 'ndff_soort_id' in columns:
            routes[table] = {'kind': 'catalogue_child', 'catalogue': 'ndff_soorten',
                             'join': 'w.ndff_soort_id=c.ndff_soort_id', 'role': 'soortreferentie'}
        elif columns & {'wetenschappelijke_naam','scientificName','scientific_name','scientificname',
                        'doelsoort','taxon_id','taxon_uuid','species_id','soort_key'}:
            raise ValueError(f'{table}: nieuwe ongecontroleerde soortgegevenslaag')
    return routes


def central_taxon_query(table: str, route: dict, taxon_id: int | None = None) -> str:
    """Read the stored, version-bound route, never infer identity from names.

    One query per source keeps original values and analysis roles separate;
    this is not a UNION that silently sums sources or reconstructed zeroes.
    Historical decisions remain queryable through the measurement's pinned ID.
    """
    if not re.fullmatch('[a-zA-Z][a-zA-Z0-9_]*', table):
        raise ValueError('Ongeldige tabelidentifier')
    if taxon_id is not None and (type(taxon_id) is not int or taxon_id <= 0):
        raise ValueError('Ongeldige taxonidentifier')
    kind = route['kind']
    if kind == 'staging':
        raise ValueError('Tijdelijke invoer is geen toegelaten waarnemingslaag')
    joins = ''
    if kind == 'catalogue_child':
        joins = (f"JOIN `{route['catalogue']}` c ON c.taxon_bronkoppeling_id=b.koppeling_id\n"
                 f"JOIN `{table}` w ON {route['join']}")
    elif kind == 'ndff_child':
        joins = ("JOIN ndff_soorten c ON c.taxon_bronkoppeling_id=b.koppeling_id\n"
                 "JOIN ndff_open_waarneming o ON o.soort_key=c.soort_key\n"
                 f"JOIN `{table}` w ON {route['join']}")
    else:
        joins = f'JOIN `{table}` w ON w.taxon_bronkoppeling_id=b.koppeling_id'
    return ("SELECT t.taxon_id,t.weergavenaam,g.groep_id,g.groep_code,g.groep_naam,"
            "b.koppeling_id,b.koppelstatus,b.taxonrelatie,b.bron_dataset,b.bron_versie,w.*\n"
            "FROM taxa t\nLEFT JOIN taxon_groepen g ON g.groep_id=t.groep_id\n"
            "JOIN taxa_bronkoppeling b ON b.taxon_id=t.taxon_id\n" + joins +
            (f'\nWHERE t.taxon_id={taxon_id}' if taxon_id is not None else '') + ';')


def query_identifier(value: str) -> str:
    if not re.fullmatch('[A-Za-z][A-Za-z0-9_]*', value):
        raise ValueError('Ongeldige SQL-identifier')
    return '`' + value + '`'


def query_literal(value) -> str:
    if value is None:
        return 'NULL'
    return "CONVERT(X'" + str(value).encode().hex() + "' USING utf8mb4)"


def query_context_sql(metadata: str) -> str:
    return 'JSON_OBJECT(' + ','.join(
        query_literal(f) + ',' + f"JSON_EXTRACT({metadata},'$.{f}')"
        for f in SOURCE_USAGE_FIELDS) + ')'


def derived_key_sql(route: dict, alias: str = 'w') -> str:
    fields = [route['name_field'], *route['context_fields']]
    return "CONCAT('context-sha256:',SHA2(CAST(JSON_ARRAY(" + ','.join(
        alias + '.' + query_identifier(f) for f in fields) + ') AS CHAR CHARACTER SET utf8mb4),256))'


def central_source_condition(table: str, route: dict, alias='w') -> str:
    """Same semantic check in the acceptance gate and in BEFORE row triggers."""
    kind = route['kind']
    if kind=='catalogue':
        if table=='soorten': source_id=f'CAST({alias}.id AS CHAR)'; name=f'{alias}.latijnse_naam'
        elif table=='ndff_soorten': source_id=f'{alias}.soort_key'; name=f'{alias}.wetenschappelijke_naam'
        else:
            source_id=f"REPLACE(CAST(JSON_ARRAY({alias}.batch_id,{alias}.soortgroep_code,{alias}.soortnr) AS CHAR),' ','')"
            name=f'{alias}.wetenschappelijke_naam'
        condition = "b.bron_systeem='Meijendel' AND BINARY b.bron_dataset=BINARY "+query_literal(table)+\
                    ' AND BINARY b.bron_taxon_id=BINARY '+source_id+' AND BINARY b.bron_wetenschappelijke_naam <=> BINARY '+name
        if table=='ndff_soorten':
            condition += f" AND BINARY JSON_UNQUOTE(JSON_EXTRACT(b.bronmetadata,'$.soortgroep_raw')) <=> BINARY {alias}.soortgroep_raw"
        return condition
    if table=='pq_vegetatie_waarneming':
        return ("b.bron_systeem='Meijendel' AND b.bron_dataset='pq_vegetatie_taxon' AND "
                f"CAST(JSON_UNQUOTE(JSON_EXTRACT(b.bronmetadata,'$.taxon_id')) AS UNSIGNED)={alias}.bron_taxon_lokaal_id")
    if table=='vangblik_vangst':
        fields = {'scientific_name':'scientificName','kingdom':'kingdom','phylum':'phylum',
                  'class_name':'class','order_name':'order','family':'family','taxon_rank':'taxonRank'}
        return ("b.bron_systeem='Meijendel' AND b.bron_dataset='vangblik_soorten' AND "+' AND '.join(
            f"BINARY JSON_EXTRACT(b.bronmetadata,'$.{c}') <=> BINARY JSON_EXTRACT({alias}.raw_payload,'$.{f}')"
            for c,f in fields.items()))
    if kind=='external' or table=='pq_vegetatie_bronresultaat':
        event = 'pq_vegetatie_bronopname' if table=='pq_vegetatie_bronresultaat' else route.get('event_table','externe_ecologie_event')
        dataset = route.get('dataset_table','externe_ecologie_dataset')
        query_identifier(event); query_identifier(dataset)
        source = f'(SELECT d.dataset_sleutel FROM {event} e JOIN {dataset} d ON d.dataset_id=e.dataset_id WHERE e.event_id={alias}.event_id)'
        version = f"(SELECT CONCAT(d.bronversie,'; sha256:',d.bronbestand_sha256) FROM {event} e JOIN {dataset} d ON d.dataset_id=e.dataset_id WHERE e.event_id={alias}.event_id)"
        fields = {f:f"JSON_EXTRACT({alias}.bronmetadata,'$.{f}')" for f in SOURCE_TAXON_FIELDS}
        fields.update(dataset=source,name=f'{alias}.wetenschappelijke_naam',raw_name=f'{alias}.wetenschappelijke_naam_bron',
                      nl=f'{alias}.nederlandse_naam',rank=f'{alias}.'+('taxonomische_status_aangeleverd' if table=='pq_vegetatie_bronresultaat' else 'taxonrang'))
        context='JSON_OBJECT('+','.join(query_literal(f)+','+fields[f] for f in SOURCE_USAGE_FIELDS)+')'
        return ("b.bron_systeem='Meijendel' AND BINARY b.bron_dataset=BINARY "+source+
                ' AND BINARY b.bron_versie=BINARY '+version+
                ' AND b.bron_context_sha256=UNHEX(SHA2(CAST('+context+' AS CHAR CHARACTER SET utf8mb4),256))')
    return 'TRUE'


# Accepted physical schema. Every new/changed column requires an explicit route review.
# Updated from the canonical local database and checked against the restored candidate.
CENTRAL_QUERY_SCHEMA = {
    'BGgroup': frozenset(['euring_code', 'group_code', 'id', 'soort_naam']),
    'analyse_datareeks': frozenset(['aangemaakt_op', 'beoordeeld_op', 'beveiligingsniveau', 'bezoekstructuur_status', 'bijgewerkt_op', 'bron_object', 'bron_schema', 'bronorganisatie', 'bronselectie_omschrijving', 'bronstatus', 'classificatiebron', 'datareeks_id', 'datareeks_sleutel', 'jaar_tot', 'jaar_van', 'korrel', 'kwaliteitsmelding', 'methode_status', 'naam', 'nulwaarneming_status', 'recordaantal_bij_beoordeling', 'regelversie', 'ruimtelijke_status', 'soortgroep', 'validatie_status']),
    'analyse_datareeks_geschiktheid': frozenset(['analyse_type_code', 'beoordeeld_op', 'datareeks_geschiktheid_id', 'datareeks_id', 'eindbesluit', 'gegevensgeschiktheid', 'kwaliteitsmelding', 'protocolgeschiktheid', 'regelversie', 'voorwaarden']),
    'analyse_recorduitzondering': frozenset(['analyse_type_code', 'beoordeeld_op', 'bronrecord_sleutel', 'datareeks_id', 'eindbesluit', 'gegevensgeschiktheid', 'recorduitzondering_id', 'reden', 'regelversie']),
    'analyse_type': frozenset(['analyse_type_code', 'naam', 'omschrijving']),
    'bezoekersdruk_locatie': frozenset(['bron', 'geom', 'id', 'locatie_type', 'naam', 'omschrijving']),
    'bezoekersdruk_meting': frozenset(['bron', 'dagtype', 'eenheid', 'herkomst', 'id', 'indicator', 'jaar', 'locatie_id', 'opmerking', 'seizoen', 'waarde']),
    'bronnen': frozenset(['code', 'id', 'omschrijving']),
    'dagbezoeken_bmp': frozenset(['aantal_records', 'aantal_soorten', 'begintijd', 'bezoek_datum', 'bezoek_id', 'bezoekduur_min', 'bron_id', 'dagvanjaar', 'deelbezoek', 'deelbezoek_deel', 'eindtijd', 'gunstig', 'invoerdatum', 'jaar', 'omstandigheden_opm', 'opmerking', 'plot_id']),
    'dagbezoeken_wv': frozenset(['aantal_records', 'aantal_soorten', 'begintijd', 'bezoek_datum', 'bezoek_id', 'bezoekduur_min', 'bron_id', 'dagvanjaar', 'deelbezoek', 'deelbezoek_deel', 'eindtijd', 'gunstig', 'ijs', 'invoerdatum', 'jaar', 'omstandigheden_opm', 'opmerking', 'plot_id', 'sneeuw', 'telling_id', 'tellingtype', 'telomschrijving', 'waterstand']),
    'dagwaarnemingen_bmp': frozenset(['aantal', 'bezoek_id', 'broedcode', 'bron_id', 'bron_waarneming_id', 'cluster_territorium', 'cluster_territorium_id', 'dag', 'dagvanjaar', 'geom', 'geslacht', 'id', 'in_plot', 'invoerdatum', 'ioc_sort', 'jaar', 'kopid', 'maand', 'opmerking', 'plot_id', 'soort_id', 'soortgroep_code', 'sovon_soortnr', 'wrntype', 'x_coord', 'y_coord']),
    'dagwaarnemingen_wv': frozenset(['aantal', 'bezoek_id', 'broedcode', 'bron_id', 'bron_waarneming_id', 'cluster_territorium', 'cluster_territorium_id', 'dag', 'dagvanjaar', 'geom', 'geslacht', 'id', 'in_plot', 'invoerdatum', 'ioc_sort', 'jaar', 'kopid', 'maand', 'opmerking', 'plot_id', 'soort_id', 'soortgroep_code', 'sovon_soortnr', 'wrntype', 'x_coord', 'y_coord']),
    'evg_landschapstypen': frozenset(['beschrijving', 'id']),
    'evg_vogel_landschapgroep': frozenset(['beschrijving_landschap_vogel', 'groepsnummer', 'veeleisendheid_score', 'vogel_id']),
    'evg_vogel_landschapstype': frozenset(['landschap_id', 'soort_id', 'veeleisendheid']),
    'evg_vogelgroepen': frozenset(['beschrijving_landschap_groep', 'groepsnummer', 'landschap_groep']),
    'externe_ecologie_dataset': frozenset(['bronbestand_naam', 'bronbestand_sha256', 'bronorganisatie', 'bronversie', 'dataset_id', 'dataset_sleutel', 'doi', 'geimporteerd_op', 'importversie', 'licentie', 'selectie_omschrijving', 'titel']),
    'externe_ecologie_event': frozenset(['analyse_status', 'bron_event_id', 'bron_locatie', 'bronmetadata', 'coordinate_uncertainty_m', 'dataset_id', 'datum_precisie', 'event_datum', 'event_datum_tot', 'event_id', 'inspanning_eenheid', 'inspanning_waarde', 'jaar', 'latitude', 'longitude', 'ruimtelijke_klasse', 'sampling_protocol']),
    'externe_ecologie_overlap': frozenset(['doelrecord_sleutel', 'doelsysteem', 'koppelmethode', 'overlap_id', 'resultaat_id', 'toelichting', 'zekerheid']),
    'externe_ecologie_resultaat': frozenset(['basis_of_record', 'bron_occurrence_id', 'bronmetadata', 'catalogusnummer', 'event_id', 'hoeveelheid', 'hoeveelheid_eenheid', 'hoeveelheid_oorspronkelijk', 'nederlandse_naam', 'occurrence_status', 'resultaat_id', 'taxon_bronkoppeling_id', 'taxonrang', 'wetenschappelijke_naam', 'wetenschappelijke_naam_bron']),
    'familie': frozenset(['familie_latijn', 'familienaam_nl', 'id', 'orde_latijn', 'orde_nl']),
    'functional_group_definition': frozenset(['created_at', 'group_code', 'group_version', 'id', 'minimum_exploratief', 'minimum_hoofdindicator', 'minimum_robuust', 'naam_nl', 'onderzoeksvraag', 'rule_json', 'status']),
    'functional_group_membership': frozenset(['binary_membership', 'classification', 'functional_group_definition_id', 'generated_at', 'generation_commit', 'id', 'membership_weight', 'rationale_json', 'soort_id']),
    'habitattypen': frozenset(['beschrijving', 'habitat_code', 'habitat_doelstelling', 'habitat_naam', 'id']),
    'habitattypen_doelstelling': frozenset(['doelstelling_csv', 'habitat_code_csv', 'habitat_naam_csv']),
    'habitattypen_kenmerken': frozenset(['aangemaakt_op', 'bron', 'habitattype_id', 'id', 'soorten_kenmerken_datadictionary_id']),
    'import_dagwaarnemingen_raw': frozenset(['aantal', 'broedcode', 'bron_waarneming_id', 'bzdid', 'clterr', 'clterrid', 'dag', 'doy', 'geslacht', 'inplot', 'ioc_sort', 'jaar', 'kopid', 'maand', 'naam', 'opmerk', 'plotid', 'projectid', 'soortgrp', 'soortnr', 'telgeb', 'wrntype', 'x_coord', 'y_coord']),
    'import_resultaten_raw': frozenset(['aantal', 'dh100ha', 'euring', 'gebied', 'ioc_sort', 'jaar', 'kopid', 'naam', 'oid', 'opp_ha', 'plotid', 'projectid', 'rl_status', 'snl', 'waarnemer', 'wetenschap']),
    'import_waarnemingen_breed': frozenset(['bron_id', 'euring_code', 'jaar', 'p_105', 'p_10_12_76', 'p_12A', 'p_13', 'p_13S', 'p_14', 'p_15', 'p_16S', 'p_16plus', 'p_17A', 'p_17B', 'p_1A', 'p_1B', 'p_2', 'p_3', 'p_31', 'p_32', 'p_33', 'p_34', 'p_35', 'p_36', 'p_41', 'p_42', 'p_43', 'p_45', 'p_46', 'p_4_5', 'p_51', 'p_52', 'p_53', 'p_54A', 'p_54B', 'p_55', 'p_6', 'p_61', 'p_62', 'p_63', 'p_64', 'p_65', 'p_66', 'p_7', 'p_71', 'p_72', 'p_73', 'p_74', 'p_75', 'p_75A', 'p_77', 'p_78_79', 'p_8', 'p_83', 'p_84', 'p_85', 'p_91']),
    'import_waarnemingen_lang': frozenset(['bron_id', 'euring_code', 'jaar', 'plot_id', 'soort_id', 'territoria']),
    'ioc_euring_mapping': frozenset(['aantal_records', 'bron_naam', 'euring_code', 'ioc_sort', 'wetenschap']),
    'kernopgave_habitat': frozenset(['habitat_id', 'kernopgave_id']),
    'kernopgave_soort': frozenset(['kernopgave_id', 'soort_id']),
    'kernopgaven': frozenset(['code', 'id', 'omschrijving']),
    'legacy_trait_mapping': frozenset(['category_id', 'id', 'legacy_code', 'mapping_rule', 'mapping_status', 'mapping_strength', 'reviewed_on', 'trait_id']),
    'maatregel_habitat': frozenset(['habitat_id', 'maatregel_id']),
    'maatregelen': frozenset(['code', 'druk_aandachtspunt', 'id', 'maatregelgroep_code', 'omschrijving']),
    'maatregelen_kernwoorden': frozenset(['actief', 'code', 'id', 'kernwoord', 'parent_maatregel_id']),
    'meijendel_basisgebied': frozenset(['basisgebiedversie_id', 'gebied_geometrie', 'gebied_id', 'naam']),
    'meijendel_basisgebied_versie': frozenset(['aangemaakt_op', 'basisgebiedversie_id', 'bronbestand', 'bronbestand_sha256', 'crs_epsg', 'oppervlakte_ha', 'projectgeometrie_sha256', 'status', 'versie']),
    'meijendel_natura2000': frozenset(['gebied_geometrie', 'gebiedsnummer', 'naam', 'natura2000versie_id']),
    'meijendel_natura2000_versie': frozenset(['aangemaakt_op', 'bronbestand', 'bronbestand_sha256', 'crs_epsg', 'gebiedsnummer', 'natura2000versie_id', 'oppervlakte_ha', 'versie']),
    'meijendel_waarneming_ruimtelijke_status': frozenset(['basisgebiedversie_id', 'basisstatus', 'beoordeeld_op', 'bron_record_id', 'bron_tabel', 'eenduidig_plot_id', 'locatiemethode', 'natura2000status', 'natura2000versie_id', 'plotversie_id', 'reden', 'regelversie', 'ruimtelijke_status_id', 'sovon_plot_count', 'toelatingsstatus']),
    'natura2000_vogelrichtlijn_soort': frozenset(['bron_gelezen_op', 'bron_url', 'eu_code', 'id', 'pdf_url', 'profiel_url', 'profieltype', 'richtlijn_bijlage', 'richtlijn_id', 'soort_id']),
    'ndff_amfibie_bezoek': frozenset(['bezoek_sleutel', 'bezoekdatum', 'bezoekdekkingstatus', 'bronrecordaantal', 'inspanningstatus', 'jaar', 'periode_start', 'periode_stop', 'periodecodering', 'reconstructieversie', 'waterbezoekaantal']),
    'ndff_amfibie_waterbezoek': frozenset(['bevestigingsstatus', 'bezoek_sleutel', 'bronrecordaantal', 'reconstructieversie', 'waterbezoek_sleutel', 'waterfamilie_id']),
    'ndff_amfibie_waterbezoek_taxon': frozenset(['aantal_exact', 'bovengrens', 'bron_taxonnamen', 'bronrecordaantal', 'hoogste_presentieklasse', 'meetwaarde_type', 'meetwaardetypen_raw', 'nulregel', 'ondergrens', 'reconstructieversie', 'stadia_raw', 'stadium_status', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'waterbezoek_sleutel', 'wetenschappelijke_naam']),
    'ndff_amfibie_waterfamilie': frozenset(['aangemaakt_op', 'bronrecordaantal', 'eerste_jaar', 'geometrieaantal', 'jaaraantal', 'laatste_jaar', 'protocol_sleutel', 'reconstructiestatus', 'reconstructieversie', 'ruimtelijke_omvang_m', 'waterbezoekaantal', 'waterfamilie_id']),
    'ndff_amfibie_watergeometrie': frozenset(['afstand_anker_m', 'anker_geometrie_sha256', 'centrum_x_rd', 'centrum_y_rd', 'eerste_jaar', 'geometrie_sha256', 'geometrierol', 'laatste_jaar', 'oppervlakte_m2', 'reconstructieversie', 'waterfamilie_id']),
    'ndff_amfibieen': frozenset(['waarneming_id']),
    'ndff_analysebesluit': frozenset(['analysebesluit_id', 'analysetype', 'besloten_op', 'bron_scope', 'eindbesluit', 'gegevensgeschiktheid', 'protocol_id', 'protocolgeschiktheid', 'recordaantal_bij_besluit', 'reden', 'regelversie', 'soortgroep_raw', 'vereist_pq_toets', 'vereist_ruimtelijke_toets']),
    'ndff_bospaddenstoel_bezoek': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'bezoekdatum', 'bronrecordaantal', 'canonieke_positieve_resultaten', 'geregistreerde_taxa', 'inspanningstatus', 'jaar', 'kwaliteitsnotitie', 'meetpunt_id', 'reconstructieversie', 'seizoenstatus']),
    'ndff_bospaddenstoel_bezoek_taxon': frozenset(['aangemaakt_op', 'aantal_vruchtlichamen', 'bezoek_sleutel', 'bronrecordaantal', 'kwaliteitsnotitie', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_bospaddenstoel_doelbereik': frozenset(['aangemaakt_op', 'afleidingsregel', 'eerste_jaar', 'laatste_jaar', 'meetpunt_id', 'positieve_bezoekaantal', 'reconstructieversie', 'taxon_bronkoppeling_id', 'wetenschappelijke_naam']),
    'ndff_bospaddenstoel_geometrie': frozenset(['aangemaakt_op', 'bronrecordaantal', 'centrum_x_rd', 'centrum_y_rd', 'eerste_jaar', 'geometrie_sha256', 'laatste_jaar', 'meetpunt_id', 'oppervlakte_m2', 'reconstructieversie', 'representatietype']),
    'ndff_bospaddenstoel_jaar_taxon': frozenset(['aangemaakt_op', 'bezoekaantal', 'jaar', 'jaarstatus', 'kwaliteitsnotitie', 'maximum_vruchtlichamen', 'meetpunt_id', 'positief_bezoekaantal', 'reconstructieversie', 'taxon_bronkoppeling_id', 'wetenschappelijke_naam']),
    'ndff_bospaddenstoel_meetpunt': frozenset(['aangemaakt_op', 'bezoekaantal', 'bronrecordaantal', 'centrum_x_rd', 'centrum_y_rd', 'doelbereikstatus', 'eerste_jaar', 'geometrieaantal', 'jaaraantal', 'kwaliteitsnotitie', 'laatste_jaar', 'meetpunt_id', 'meetpunt_sleutel', 'protocol_sleutel', 'reconstructieversie']),
    'ndff_bospaddenstoel_recordselectie': frozenset(['aangemaakt_op', 'bezoekdatum', 'canonieke_waarneming_id', 'doelrelatie', 'meetpunt_id', 'reconstructieversie', 'selectiereden', 'selectiestatus', 'waarneming_id']),
    'ndff_bospaddenstoel_verspreiding_bezoek': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'bronrecordaantal', 'hoknummer', 'kwaliteitsnotitie', 'openbare_geometrie_sha256', 'periode_start', 'periode_stop', 'protocol_sleutel', 'reconstructieversie', 'ruimtelijke_status', 'volledigheidsstatus']),
    'ndff_bospaddenstoel_verspreiding_bezoek_taxon': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'bronrecordaantal', 'kwaliteitsnotitie', 'meetwaarden_json', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_bospaddenstoel_verspreiding_recordselectie': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'reconstructieversie', 'selectiereden', 'selectiestatus', 'waarneming_id']),
    'ndff_braakbal_hokjaar': frozenset(['aangemaakt_op', 'bronperiodestatus', 'bronrecordaantal', 'centroide_x_rd', 'centroide_y_rd', 'geregistreerde_taxa', 'hokjaar_sleutel', 'inspanningsstatus', 'jaar', 'kwaliteitsnotitie', 'nulstatus', 'openbare_geometrie_sha256', 'oppervlakte_m2', 'plotstatus', 'protocol_sleutel', 'reconstructieversie', 'ruimtelijke_status', 'som_prooidieren', 'veldmuis_aandeel', 'veldmuis_aantal', 'vervaagd', 'vervagingsniveau_km']),
    'ndff_braakbal_hokjaar_taxon': frozenset(['aandeel_prooidieren', 'aangemaakt_op', 'bronrecordaantal', 'hokjaar_sleutel', 'kwaliteitsnotitie', 'nulstatus', 'reconstructieversie', 'taxon_bronkoppeling_id', 'totaal_aantal', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_braakbal_recordselectie': frozenset(['aangemaakt_op', 'hokjaar_sleutel', 'reconstructieversie', 'selectiereden', 'selectiestatus', 'waarneming_id']),
    'ndff_dagvlinders': frozenset(['waarneming_id']),
    'ndff_daz_bmp_bezoek': frozenset(['aangemaakt_op', 'ambigu_kandidaatrecordaantal', 'bezoek_id', 'bezoekdatum', 'deelnamestatus', 'eenduidig_bronrecordaantal', 'inspanningstatus', 'jaar', 'kwaliteitsnotitie', 'nulbereikstatus', 'plot_id', 'reconstructieversie']),
    'ndff_daz_bmp_bezoek_taxon': frozenset(['aangemaakt_op', 'aantal', 'ambigu_recordaantal', 'bezoek_id', 'bronrecordaantal', 'doelrelatie', 'kwaliteitsnotitie', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'telwaardestatus', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_daz_bmp_recordkandidaat': frozenset(['aangemaakt_op', 'bezoek_id', 'bezoekdatum', 'plot_id', 'reconstructieversie', 'waarneming_id']),
    'ndff_daz_bmp_recordselectie': frozenset(['aangemaakt_op', 'aantal_exact', 'bezoek_id', 'doelrelatie', 'gebruiksstatus', 'kandidaat_bezoekaantal', 'koppelstatus', 'kwaliteitsnotitie', 'protocol_sleutel', 'reconstructieversie', 'waarneming_id', 'wetenschappelijke_naam']),
    'ndff_eencelligen': frozenset(['waarneming_id']),
    'ndff_florbase_doelbereik': frozenset(['aangemaakt_op', 'afleidingsregel', 'eerste_jaar', 'laatste_jaar', 'positieve_inventarisatieaantal', 'reconstructieversie', 'taxon_bronkoppeling_id', 'taxonomiestatus', 'wetenschappelijke_naam']),
    'ndff_florbase_inventarisatie': frozenset(['aangemaakt_op', 'begindatum', 'bronrecordaantal', 'datumclusteraantal', 'einddatum', 'geregistreerde_taxa', 'hok_x', 'hok_y', 'hoknummer', 'inspanningstatus', 'inventarisatie_sleutel', 'jaar', 'kwaliteitsnotitie', 'lijststatus', 'plotstatus', 'protocol_sleutel', 'reconstructieversie', 'volledigheidsdrempel_taxa', 'volledigheidsstatus']),
    'ndff_florbase_inventarisatie_taxon': frozenset(['aangemaakt_op', 'bronrecordaantal', 'inventarisatie_sleutel', 'kwaliteitsnotitie', 'meetwaarden_json', 'meetwaardestatus', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_florbase_recordselectie': frozenset(['aangemaakt_op', 'inventarisatie_sleutel', 'reconstructieversie', 'selectiereden', 'selectiestatus', 'waarneming_id']),
    'ndff_geleedpotigen_overig': frozenset(['waarneming_id']),
    'ndff_habslak_hokjaar': frozenset(['aangemaakt_op', 'bemonsteringsstatus', 'doelsoort', 'doelsoort_bronrecordaantal', 'doelsoortstatus', 'hokjaar_sleutel', 'hoknummer', 'jaar', 'kwaliteitsnotitie', 'minimale_monsterlocaties', 'monsteraantal', 'protocol_sleutel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'unieke_monsterlocaties']),
    'ndff_habslak_monster': frozenset(['aangemaakt_op', 'bezoekdatum', 'bronrecordaantal', 'centroide_x_rd', 'centroide_y_rd', 'doelbereikstatus', 'eenduidig_plot_id', 'geregistreerde_taxa', 'hoknummer', 'jaar', 'kwaliteitsnotitie', 'monster_sleutel', 'openbare_geometrie_sha256', 'oppervlakte_m2', 'plotstatus', 'protocol_sleutel', 'reconstructieversie']),
    'ndff_habslak_monster_taxon': frozenset(['aangemaakt_op', 'bronrecordaantal', 'doelrelatie', 'kwaliteitsnotitie', 'meetwaarden_json', 'monster_sleutel', 'nulstatus', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_habslak_recordselectie': frozenset(['aangemaakt_op', 'doelrelatie', 'monster_sleutel', 'reconstructieversie', 'selectiereden', 'selectiestatus', 'waarneming_id']),
    'ndff_hns_doelbereik': frozenset(['aangemaakt_op', 'afleidingsregel', 'eerste_jaar', 'laatste_jaar', 'positieve_inventarisatieaantal', 'reconstructieversie', 'taxon_bronkoppeling_id', 'wetenschappelijke_naam']),
    'ndff_hns_hok_jaar_taxon': frozenset(['aangemaakt_op', 'doelhok', 'inventarisatieaantal', 'jaar', 'jaarstatus', 'kwaliteitsnotitie', 'onafhankelijkheidsstatus', 'positief_inventarisatieaantal', 'reconstructieversie', 'taxon_bronkoppeling_id', 'wetenschappelijke_naam']),
    'ndff_hns_inventarisatie': frozenset(['aangemaakt_op', 'begindatum', 'bronrecordaantal', 'doelhok', 'doelhok_aandeel', 'einddatum', 'geregistreerde_taxa', 'herhaalstatus', 'inspanningstatus', 'inventarisatie_sleutel', 'jaar', 'kwaliteitsnotitie', 'lijststatus', 'protocol_sleutel', 'reconstructieversie', 'seizoenstatus']),
    'ndff_hns_inventarisatie_taxon': frozenset(['aangemaakt_op', 'bronrecordaantal', 'inventarisatie_sleutel', 'kwaliteitsnotitie', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_hns_recordselectie': frozenset(['aangemaakt_op', 'inventarisatie_sleutel', 'reconstructieversie', 'selectiereden', 'selectiestatus', 'waarneming_id']),
    'ndff_insecten_overig': frozenset(['waarneming_id']),
    'ndff_kevers': frozenset(['waarneming_id']),
    'ndff_konijn_hokdatum_taxon': frozenset(['aangemaakt_op', 'aantal_max', 'aantal_min', 'aantal_som', 'aggregatiestatus', 'bronrecordaantal', 'doelrelatie', 'hokdatum_taxon_sleutel', 'hoknummer', 'jaar', 'nulstatus', 'openbare_geometrie_sha256', 'reconstructieversie', 'taxon_bronkoppeling_id', 'teldatum', 'wetenschappelijke_naam']),
    'ndff_konijn_recordselectie': frozenset(['aangemaakt_op', 'aantal_exact', 'daz_overlapstatus', 'doelrelatie', 'exactgelijke_groepsgrootte', 'hokdatum_taxon_groepsgrootte', 'kwaliteitsnotitie', 'meeteenheidstatus', 'protocol_sleutel', 'reconstructieversie', 'recordgroepstatus', 'ruimtelijke_status', 'seizoenstatus', 'trendgebruik', 'waarneming_id']),
    'ndff_korstmos_bezoek': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'bezoekdatum', 'bronrecordaantal', 'geregistreerde_taxa', 'jaar', 'kwaliteitsnotitie', 'lijststatus', 'meetlocatie_id', 'reconstructieversie', 'registratiestatus']),
    'ndff_korstmos_bezoek_taxon': frozenset(['aangemaakt_op', 'bedekkingsklasse_raw', 'bedekkingsrang', 'bezoek_sleutel', 'bronrecordaantal', 'kwaliteitsnotitie', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_korstmos_doelbereik': frozenset(['aangemaakt_op', 'afleidingsregel', 'eerste_jaar', 'laatste_jaar', 'positieve_bezoekaantal', 'reconstructieversie', 'taxon_bronkoppeling_id', 'wetenschappelijke_naam']),
    'ndff_korstmos_meetlocatie': frozenset(['aangemaakt_op', 'bezoekaantal', 'bronrecordaantal', 'centrum_x_rd', 'centrum_y_rd', 'eerste_jaar', 'geometrie_sha256', 'herhaalstatus', 'kwaliteitsnotitie', 'laatste_jaar', 'meetlocatie_id', 'oppervlakte_m2', 'protocol_sleutel', 'reconstructieversie', 'ruimtelijke_klasse', 'sovon_plot_id']),
    'ndff_korstmos_recordselectie': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'canonieke_waarneming_id', 'meetlocatie_id', 'reconstructieversie', 'selectiereden', 'selectiestatus', 'waarneming_id']),
    'ndff_korstmossen': frozenset(['waarneming_id']),
    'ndff_kranswieren_wieren_algen': frozenset(['waarneming_id']),
    'ndff_kreeftachtigen': frozenset(['waarneming_id']),
    'ndff_kwartiertelling_interval_soortgroep': frozenset(['aangemaakt_op', 'bronrecordaantal', 'interval_sleutel', 'kwaliteitsnotitie', 'nulstatus', 'reconstructieversie', 'soortgroep_raw', 'volledigheidsstatus', 'waargenomen_taxa']),
    'ndff_kwartiertelling_interval_taxon': frozenset(['aangemaakt_op', 'bronrecordaantal', 'interval_sleutel', 'kwaliteitsnotitie', 'meetwaarden_json', 'nulregel', 'reconstructieversie', 'soortgroep_raw', 'taxon_bronkoppeling_id', 'totaal_aantal', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_kwartiertelling_recordselectie': frozenset(['aangemaakt_op', 'eenduidig_plot_id', 'interval_sleutel', 'reconstructieversie', 'ruimtelijke_status', 'selectiereden', 'selectiestatus', 'waarneming_id']),
    'ndff_kwartiertelling_telinterval': frozenset(['aangemaakt_op', 'bronrecordaantal', 'duur_minuten', 'duurstatus', 'eenduidig_plot_id', 'geometrieversies', 'interval_sleutel', 'kwaliteitsnotitie', 'periode_start', 'periode_stop', 'plotversie_id', 'protocol_sleutel', 'reconstructieversie', 'routestatus', 'ruimtelijke_status', 'soortgroepen_met_positieve_regels']),
    'ndff_libel_bezoek': frozenset(['bezoek_sleutel', 'bronrecordaantal', 'doelbereikstatus', 'jaar', 'periode_start', 'periode_stop', 'reconstructiestatus', 'reconstructieversie', 'routefamilie_id']),
    'ndff_libel_bezoek_taxon': frozenset(['aantal', 'bezoek_sleutel', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_libel_routefamilie': frozenset(['aangemaakt_op', 'bezoekaantal', 'bronrecordaantal', 'componentaantal', 'doelbereikstatus', 'eerste_jaar', 'geometrieaantal', 'jaaraantal', 'laatste_jaar', 'protocol_sleutel', 'reconstructiestatus', 'reconstructieversie', 'routefamilie_id', 'ruimtelijke_omvang_m']),
    'ndff_libel_routegeometrie': frozenset(['centrum_x_rd', 'centrum_y_rd', 'geometrie_sha256', 'oppervlakte_m2', 'reconstructieversie', 'routefamilie_id']),
    'ndff_libellen': frozenset(['waarneming_id']),
    'ndff_liveatlas_bezoek': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'bronrecordaantal', 'duur_minuten', 'duurstatus', 'eenduidig_plot_id', 'geometrieversies', 'kwaliteitsnotitie', 'periode_start', 'periode_stop', 'plotversie_id', 'protocol_sleutel', 'reconstructieversie', 'routestatus', 'ruimtelijke_status', 'soortgroepen_met_positieve_regels']),
    'ndff_liveatlas_bezoek_soortgroep': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'bronrecordaantal', 'kwaliteitsnotitie', 'nulstatus', 'reconstructieversie', 'soortgroep_raw', 'volledigheidsstatus', 'waargenomen_taxa']),
    'ndff_liveatlas_bezoek_taxon': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'bronrecordaantal', 'kwaliteitsnotitie', 'meetwaarden_json', 'nulregel', 'reconstructieversie', 'soortgroep_raw', 'taxon_bronkoppeling_id', 'totaal_aantal', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_liveatlas_recordselectie': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'eenduidig_plot_id', 'reconstructieversie', 'ruimtelijke_status', 'selectiereden', 'selectiestatus', 'waarneming_id']),
    'ndff_lmfa_bezoek': frozenset(['aangemaakt_op', 'begindatum', 'bezoek_sleutel', 'bezoekstatus', 'bronrecordaantal', 'einddatum', 'geregistreerde_doelsoorten', 'jaar', 'kwaliteitsnotitie', 'reconstructieversie', 'route_sleutel', 'vervaagd_bronrecordaantal']),
    'ndff_lmfa_bezoek_taxon': frozenset(['aangemaakt_op', 'abundantieklasse', 'bezoek_sleutel', 'bronklasse_raw', 'bronrecordaantal', 'exact_totaal', 'kwaliteitsnotitie', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_lmfa_doelsoort': frozenset(['aangemaakt_op', 'bron_url', 'doelstatus', 'reconstructieversie', 'taxon_bronkoppeling_id', 'wetenschappelijke_naam']),
    'ndff_lmfa_recordselectie': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'reconstructieversie', 'selectiereden', 'selectiestatus', 'waarneming_id']),
    'ndff_lmfa_route': frozenset(['aangemaakt_op', 'bron_url', 'hok_x', 'hok_y', 'hoknummer', 'kwaliteitsnotitie', 'protocol_sleutel', 'reconstructieversie', 'route_sleutel', 'route_status']),
    'ndff_microvlinders': frozenset(['waarneming_id']),
    'ndff_mos_datumcluster': frozenset(['aangemaakt_op', 'brongeometrieaantal', 'bronrecordaantal', 'clusterstatus', 'datumcluster_sleutel', 'geregistreerde_taxa', 'inventarisatie_sleutel', 'kwaliteitsnotitie', 'periode_start', 'periode_stop', 'reconstructieversie', 'tijdprecisie']),
    'ndff_mos_doelbereik': frozenset(['aangemaakt_op', 'afleidingsregel', 'eerste_jaar', 'laatste_jaar', 'positieve_inventarisatieaantal', 'reconstructieversie', 'taxon_bronkoppeling_id', 'wetenschappelijke_naam']),
    'ndff_mos_inventarisatie': frozenset(['aangemaakt_op', 'begindatum', 'bronrecordaantal', 'datumclusteraantal', 'eerste_jaar', 'einddatum', 'geregistreerde_taxa', 'hoknummer', 'inspanningstatus', 'inventarisatie_sleutel', 'jaarstatus', 'kwaliteitsnotitie', 'laatste_jaar', 'lijststatus', 'plotstatus', 'protocol_sleutel', 'reconstructieversie']),
    'ndff_mos_inventarisatie_taxon': frozenset(['aangemaakt_op', 'aantalsklasse_raw', 'aantalsrang', 'bron_schaal', 'bronrecordaantal', 'inventarisatie_sleutel', 'kwaliteitsnotitie', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_mos_recordselectie': frozenset(['aangemaakt_op', 'canonieke_waarneming_id', 'datumcluster_sleutel', 'inventarisatie_sleutel', 'reconstructieversie', 'selectiereden', 'selectiestatus', 'waarneming_id']),
    'ndff_mossen': frozenset(['waarneming_id']),
    'ndff_nachtvlinder_hokjaar': frozenset(['aangemaakt_op', 'bronrecordaantal', 'hokjaar_sleutel', 'hoknummer', 'jaar', 'kwaliteitsnotitie', 'openbare_geometrie_sha256', 'protocol_sleutel', 'reconstructieversie', 'ruimtelijke_status', 'telstatus']),
    'ndff_nachtvlinder_hokjaar_taxon': frozenset(['aangemaakt_op', 'bronrecordaantal', 'geregistreerd_aantal', 'hokjaar_sleutel', 'kwaliteitsnotitie', 'meetwaarden_json', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_nachtvlinder_recordselectie': frozenset(['aangemaakt_op', 'hokjaar_sleutel', 'reconstructieversie', 'selectiereden', 'selectiestatus', 'waarneming_id']),
    'ndff_nachtvlinders': frozenset(['waarneming_id']),
    'ndff_ongewervelden_overig': frozenset(['waarneming_id']),
    'ndff_open_import_batch': frozenset(['batch_id', 'bouwversie', 'bronbestand', 'bronbestand_sha256', 'bronstatus', 'geimporteerd_op', 'opmerkingen', 'periode_einde', 'periode_start', 'recordaantal', 'taxonaantal']),
    'ndff_open_leveringsverrijking': frozenset(['aantal_max', 'aantal_min', 'bronrecord_sha256', 'dataeigenaar_uri', 'datumdekking_raw', 'eenheid_raw', 'koppelmethode', 'kwaliteitsstatus_raw', 'leveringsgeometrie_gelijk_aan_openbaar', 'leveringsperiode_gelijk_aan_openbaar', 'leveringsregel_id', 'locatie_type_raw', 'obs_uri', 'obs_uri_sha256', 'oorspronkelijke_aantal_raw', 'oppervlaktedekking_raw', 'sessionid_raw', 'ticketnummer', 'verrijkt_op', 'waarneming_id', 'zoid_raw']),
    'ndff_open_pq_koppeling': frozenset(['beoordeeld_op', 'classificatie', 'ndff_bronrol', 'primaire_pq_bron', 'reden', 'regelversie', 'waarneming_id']),
    'ndff_open_ruimtelijke_beoordeling': frozenset(['beoordeeld_op', 'eenduidig_plot_id', 'geometrie_oppervlakte_m2', 'geometrie_type', 'is_plotcontext_ruimtelijk_toelaatbaar', 'plot_match_count', 'plotversie_id', 'regelversie', 'ruimtelijke_klasse', 'toewijzingskwaliteit', 'vervaagd', 'vervagingsniveau_km', 'waarneming_id']),
    'ndff_open_soortgroep_koppeling': frozenset(['soortgroep_code', 'soortgroep_raw', 'waarneming_id']),
    'ndff_open_waarneming': frozenset(['aantal_raw', 'analyse_status', 'apparatuur', 'batch_id', 'beleidsstatus', 'biotoop', 'bouwversie', 'bronbestand_aantal', 'bronbestand_eerste', 'bronhouder', 'bronrecord_aantal', 'determinatiemethode', 'doodsoorzaak', 'gedrag', 'hok_grootte', 'hoknummer', 'identiteit', 'identiteit_sha256', 'jaar', 'nederlandse_naam', 'ontdubbel_sleutel', 'oorsprong', 'openbare_geometrie', 'openbare_geometrie_sha256', 'payload_conflict', 'periode_start', 'periode_stop', 'pq_status', 'protocol', 'raw_payload', 'schaal_telmethode', 'sekse', 'soort_key', 'soortgroep_raw', 'stadium', 'staging_fid', 'substraat', 'telonderwerp', 'verblijfplaats', 'vervaagd', 'vervaging_raw', 'vervagingsniveau_km', 'waarneming_id', 'wetenschappelijke_naam', 'zoek_of_vangmethode']),
    'ndff_open_waarneming_protocol': frozenset(['bewijsmethode', 'gekoppeld_op', 'protocol_id', 'regelversie', 'waarneming_id']),
    'ndff_otter_bever_hokjaar': frozenset(['aangemaakt_op', 'bronrecordaantal', 'hokjaar_sleutel', 'hoknummer', 'jaar', 'kwaliteitsnotitie', 'protocol_sleutel', 'reconstructieversie', 'ruimtelijke_status', 'volledigheidsstatus']),
    'ndff_otter_bever_hokjaar_taxon': frozenset(['aangemaakt_op', 'bronrecordaantal', 'doelrelatie', 'geregistreerd_aantal', 'hokjaar_sleutel', 'kwaliteitsnotitie', 'meetwaarden_json', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_otter_bever_recordselectie': frozenset(['aangemaakt_op', 'eenduidig_plot_id', 'hokjaar_sleutel', 'reconstructieversie', 'selectiereden', 'selectiestatus', 'waarneming_id']),
    'ndff_poldervis_bezoek': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'bronrecordaantal', 'kwaliteitsnotitie', 'methodestatus', 'periode_start', 'periode_stop', 'reconstructieversie', 'waterlocatie_sleutel']),
    'ndff_poldervis_bezoek_taxon': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'bronrecordaantal', 'doelrelatie', 'geregistreerd_aantal', 'kwaliteitsnotitie', 'meetwaarden_json', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_poldervis_recordselectie': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'reconstructieversie', 'selectiereden', 'selectiestatus', 'waarneming_id']),
    'ndff_poldervis_waterlocatie': frozenset(['aangemaakt_op', 'bronrecordaantal', 'eenduidig_plot_id', 'identificatiestatus', 'kwaliteitsnotitie', 'meeteenheidstype', 'openbare_geometrie_sha256', 'plotversie_id', 'protocol_sleutel', 'reconstructieversie', 'ruimtelijke_status', 'waterlocatie_sleutel']),
    'ndff_protocol': frozenset(['bron_nummers', 'bron_urls', 'bronbestand', 'bronbestand_sha256', 'broncontrole_datum', 'levering_scope', 'protocol_code', 'protocol_id', 'protocol_naam', 'protocol_sleutel']),
    'ndff_protocol_gebruik': frozenset(['aanvullend_gebruik', 'aanvullende_typen', 'begrenzing', 'benodigde_onderzoekscontext', 'bronbestand_sha256', 'broncontrole_datum', 'hoofdtype', 'passende_analyse', 'protocol_gebruik_id', 'protocol_id', 'regelversie', 'toelichting_sha256', 'wetenschappelijk_gebruik']),
    'ndff_protocol_mapping': frozenset(['aangemaakt_op', 'bron_scope', 'mapping_id', 'mapping_methode', 'protocol_id', 'protocol_raw', 'regelversie']),
    'ndff_protocol_soort_geschiktheid': frozenset(['beoordeeld_op', 'doelrelatie', 'protocol_id', 'protocol_soort_id', 'recordaantal_bij_classificatie', 'reden', 'regelversie', 'soortgroep_raw', 'taxon_bronkoppeling_id', 'toegestane_typen', 'wetenschappelijke_naam']),
    'ndff_protocol_soortgroep_geschiktheid': frozenset(['beoordeeld_op', 'bron_urls', 'doelrelatie', 'protocol_id', 'protocol_soortgroep_id', 'recordaantal_bij_classificatie', 'reden', 'regelversie', 'soortgroep_raw', 'toegestane_typen']),
    'ndff_ravon_n2000_monsterlocatieproxy': frozenset(['bronrecordaantal', 'identificatiestatus', 'kwaliteitsnotitie', 'locatie_sleutel', 'openbare_geometrie_sha256', 'protocol_sleutel', 'reconstructieversie', 'vervaagde_recordaantal']),
    'ndff_ravon_n2000_recordselectie': frozenset(['bezoekstatus', 'doelrelatie', 'kwaliteitsnotitie', 'locatie_sleutel', 'methodestatus', 'nulstatus', 'reconstructieversie', 'waarneming_id', 'waarnemingsstatus']),
    'ndff_reptiel_bezoek': frozenset(['bezoek_sleutel', 'bezoekdatum', 'bezoekdekkingstatus', 'bronrecordaantal', 'inspanningstatus', 'jaar', 'periode_start', 'periode_stop', 'periodebetekenis', 'reconstructiestatus', 'reconstructieversie', 'routefamilie_id']),
    'ndff_reptiel_bezoek_taxon': frozenset(['aantal', 'adult_aantal', 'bezoek_sleutel', 'juveniel_aantal', 'nulbereik', 'nulregel', 'onbekend_stadium_aantal', 'reconstructieversie', 'subadult_aantal', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_reptiel_routefamilie': frozenset(['aangemaakt_op', 'bezoekaantal', 'bronrecordaantal', 'eerste_jaar', 'geometrieaantal', 'jaaraantal', 'laatste_jaar', 'protocol_sleutel', 'reconstructiestatus', 'reconstructieversie', 'routefamilie_id', 'ruimtelijke_omvang_m']),
    'ndff_reptiel_routegeometrie': frozenset(['anker_geometrie_sha256', 'centrum_x_rd', 'centrum_y_rd', 'geometrie_sha256', 'geometrierol', 'oppervlakte_m2', 'reconstructieversie', 'routefamilie_id']),
    'ndff_reptielen': frozenset(['waarneming_id']),
    'ndff_schimmels': frozenset(['waarneming_id']),
    'ndff_snavelinsecten': frozenset(['waarneming_id']),
    'ndff_snl_waarneming_context': frozenset(['beoordeeld_op', 'bewijsnotitie', 'kandidaat_aantal', 'kandidaat_waarneming_ids', 'overlap_status', 'regelversie', 'toets_methode', 'waarneming_id']),
    'ndff_soorten': frozenset(['ndff_soort_id', 'nederlandse_naam', 'soort_key', 'soortgroep_raw', 'taxon_bronkoppeling_id', 'waarneming_aantal_bron', 'wetenschappelijke_naam']),
    'ndff_sovon_plot': frozenset(['bron_oppervlakte_ha', 'plot_geometrie', 'plot_geometrie_sha256', 'plot_id', 'plotnaam', 'plotnummer', 'plotversie_id', 'sovon_projectid']),
    'ndff_sovon_plotversie': frozenset(['bronbestand', 'bronbestand_sha256', 'crs_epsg', 'objectaantal', 'plotversie_id', 'versie']),
    'ndff_spinachtigen': frozenset(['waarneming_id']),
    'ndff_sprinkhanen_en_krekels': frozenset(['waarneming_id']),
    'ndff_tuintelling_geometrie': frozenset(['aangemaakt_op', 'bronrecordaantal', 'centroide_x_rd', 'centroide_y_rd', 'eerste_jaar', 'kwaliteitsnotitie', 'laatste_jaar', 'openbare_geometrie_sha256', 'oppervlakte_m2', 'reconstructieversie', 'ruimtelijke_status', 'tuinvakfamilie_sleutel']),
    'ndff_tuintelling_periode_soortgroep': frozenset(['aangemaakt_op', 'bronrecordaantal', 'doelbereikstatus', 'kwaliteitsnotitie', 'lokale_doelsoorten', 'reconstructieversie', 'selectiebewijs', 'soortgroep_raw', 'telperiode_sleutel', 'waargenomen_taxa']),
    'ndff_tuintelling_periode_soortgroep_taxon': frozenset(['aangemaakt_op', 'bronrecordaantal', 'kwaliteitsnotitie', 'meetwaarden_json', 'nulregel', 'reconstructieversie', 'soortgroep_raw', 'taxon_bronkoppeling_id', 'telperiode_sleutel', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_tuintelling_recordselectie': frozenset(['aangemaakt_op', 'reconstructieversie', 'selectiereden', 'selectiestatus', 'telperiode_sleutel', 'waarneming_id']),
    'ndff_tuintelling_telperiode': frozenset(['aangemaakt_op', 'bronrecordaantal', 'getelde_soortgroepen', 'kwaliteitsnotitie', 'methodeversie', 'periode_start', 'periode_stop', 'plotstatus', 'reconstructieversie', 'telperiode_sleutel', 'teltype', 'tuinvakfamilie_sleutel']),
    'ndff_tuintelling_tuinvakfamilie': frozenset(['aangemaakt_op', 'bronrecordaantal', 'eerste_periode', 'geometrieversies', 'identificatiestatus', 'kwaliteitsnotitie', 'laatste_periode', 'protocol_sleutel', 'reconstructieversie', 'tuinvakfamilie_sleutel']),
    'ndff_vaatplanten': frozenset(['waarneming_id']),
    'ndff_vissen': frozenset(['waarneming_id']),
    'ndff_vleermuis_bezoek': frozenset(['bezoek_sleutel', 'bezoekdatum', 'bezoekdekkingstatus', 'bronrecordaantal', 'datumvenster_status', 'herhalingsvenster_status', 'inspanningstatus', 'jaar', 'methodevariant', 'reconstructiestatus', 'reconstructieversie', 'ronde_binnen_jaar', 'routefamilie_id']),
    'ndff_vleermuis_bezoek_taxon': frozenset(['bezoek_sleutel', 'detectieaantal', 'doelrelatie', 'meeteenheid', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_vleermuis_recordselectie': frozenset(['bezoek_sleutel', 'bronsysteem', 'canonieke_waarneming_id', 'doelrelatie', 'reconstructieversie', 'routefamilie_id', 'selectiereden', 'selectiestatus', 'waarneming_id']),
    'ndff_vleermuis_routefamilie': frozenset(['aangemaakt_op', 'bezoekaantal', 'bronrecordaantal', 'eerste_jaar', 'geometrieaantal', 'jaaraantal', 'laatste_jaar', 'methodevariant', 'protocol_sleutel', 'reconstructiestatus', 'reconstructieversie', 'routecode', 'routefamilie_id', 'ruimtelijke_omvang_m', 'vervoerswijze']),
    'ndff_vleermuis_routegeometrie': frozenset(['centrum_x_rd', 'centrum_y_rd', 'eerste_jaar', 'geometrie_sha256', 'geometrierol', 'laatste_jaar', 'oppervlakte_m2', 'reconstructieversie', 'routefamilie_id']),
    'ndff_vleermuizen': frozenset(['waarneming_id']),
    'ndff_vliegen_en_muggen': frozenset(['waarneming_id']),
    'ndff_vliesvleugel_bezoek': frozenset(['bezoek_sleutel', 'bronrecordaantal', 'jaar', 'periode_start', 'periode_stop', 'reconstructiestatus', 'reconstructieversie', 'routefamilie_id']),
    'ndff_vliesvleugel_bezoek_taxon': frozenset(['aantal', 'bezoek_sleutel', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_vliesvleugel_routefamilie': frozenset(['aangemaakt_op', 'bezoekaantal', 'bronrecordaantal', 'componentaantal', 'eerste_jaar', 'geometrieaantal', 'jaaraantal', 'laatste_jaar', 'protocol_sleutel', 'reconstructiestatus', 'reconstructieversie', 'routefamilie_id', 'ruimtelijke_omvang_m']),
    'ndff_vliesvleugel_routegeometrie': frozenset(['centrum_x_rd', 'centrum_y_rd', 'geometrie_sha256', 'oppervlakte_m2', 'reconstructieversie', 'routefamilie_id']),
    'ndff_vliesvleugeligen': frozenset(['waarneming_id']),
    'ndff_vlinder_bezoek': frozenset(['bezoek_sleutel', 'bronrecordaantal', 'doelbereik_bewijs', 'doelbereikstatus', 'doelsoort', 'jaar', 'periode_start', 'periode_stop', 'reconstructiestatus', 'reconstructieversie', 'routefamilie_id', 'taxon_bronkoppeling_id']),
    'ndff_vlinder_bezoek_taxon': frozenset(['aantal', 'bewijsgrond', 'bezoek_sleutel', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_vlinder_route_identificatie': frozenset(['aangemaakt_op', 'bewijsbron_uri', 'bewijsgrond', 'bron_eerste_jaar', 'bron_laatste_jaar', 'doelsoort', 'officieel_routenummer', 'officiele_routenaam', 'reconstructieversie', 'routefamilie_id', 'taxon_bronkoppeling_id', 'zekerheidsniveau']),
    'ndff_vlinder_routefamilie': frozenset(['aangemaakt_op', 'bezoekaantal', 'bronrecordaantal', 'componentaantal', 'doelsoort', 'eerste_jaar', 'geometrieaantal', 'jaaraantal', 'laatste_jaar', 'protocol_sleutel', 'reconstructiestatus', 'reconstructieversie', 'routefamilie_id', 'routetype', 'routetype_bewijs', 'ruimtelijke_omvang_m', 'taxon_bronkoppeling_id']),
    'ndff_vlinder_routegeometrie': frozenset(['centrum_x_rd', 'centrum_y_rd', 'geometrie_sha256', 'geometrierol', 'geometrierol_bewijs', 'oppervlakte_m2', 'reconstructieversie', 'routefamilie_id']),
    'ndff_weekdieren': frozenset(['waarneming_id']),
    'ndff_zeereep_bezoek': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'bezoekdatum', 'bronrecordaantal', 'geregistreerde_taxa', 'hok_sleutel', 'inspanningstatus', 'jaar', 'kwaliteitsnotitie', 'reconstructieversie', 'seizoenstatus']),
    'ndff_zeereep_bezoek_taxon': frozenset(['aangemaakt_op', 'bezoek_sleutel', 'bronrecordaantal', 'doelrelatie', 'hoogste_nmv_klasse', 'kwaliteitsnotitie', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'ndff_zeereep_kilometerhok': frozenset(['aangemaakt_op', 'bezoekaantal', 'bronrecordaantal', 'eerste_jaar', 'hok_sleutel', 'jaaraantal', 'laatste_jaar', 'protocol_sleutel', 'reconstructieversie', 'x_km', 'y_km']),
    'ndff_zoogdieren_overig': frozenset(['waarneming_id']),
    'plot_jaar_ahn_dtm': frozenset(['ahn_mean', 'ahn_sd', 'bron', 'jaar', 'plot_id']),
    'plot_jaar_habitat': frozenset(['aandeel_m2', 'habitat_id', 'id', 'jaar', 'plot_id']),
    'plot_jaar_infra': frozenset(['bron', 'jaar', 'plot_id', 'variabele', 'waarde']),
    'plot_jaar_landgebruik': frozenset(['area_m2', 'bron', 'jaar', 'klasse', 'pct', 'plot_id']),
    'plot_jaar_maatregel': frozenset(['bron', 'deel_label', 'dekking_pct', 'id', 'intensiteit_code', 'jaar', 'maatregel_id', 'opmerking', 'plot_id', 'uitvoerder_of_diersoort']),
    'plot_jaar_oppervlak': frozenset(['id', 'jaar', 'oppervlakte_km2', 'plot_id']),
    'plot_jaar_stikstof': frozenset(['bron', 'jaar', 'plot_id', 'stikstof_mean', 'stikstof_median']),
    'plot_jaar_teller': frozenset(['id', 'jaar', 'plot_id', 'teller_id']),
    'plot_jaar_toegankelijkheid': frozenset(['bron', 'jaar', 'opmerking', 'plot_id', 'plot_naam', 'status_code']),
    'plot_jaar_toegankelijkheid_deel': frozenset(['aandeel_pct', 'barriere_type', 'bron', 'deel_label', 'geom_wkt', 'id', 'jaar', 'opmerking', 'plot_id', 'status_code']),
    'plot_link': frozenset(['bron', 'id', 'label', 'link_type', 'opmerking', 'plot_id', 'url']),
    'plotkolom_mapping': frozenset(['kolomnaam', 'plot_id']),
    'plots': frozenset(['geom', 'in_gebruik', 'kavel_nummer', 'plot_id', 'plot_naam', 'plot_nr', 'plot_wv']),
    'pq_plot_jaar_vegetatie': frozenset(['bedekking_som_gem', 'bronbestand', 'bronstatus', 'dekking_kwaliteit', 'importversie', 'jaar', 'methode', 'n_opnamen', 'n_pq', 'plot_id', 'shannon_gem', 'soortenrijkdom_gem', 'taxa_aantal', 'taxonlijst_versie']),
    'pq_vegetatie_bronopname': frozenset(['analyse_status', 'bron_event_id', 'bron_locatie', 'bronmetadata', 'coordinate_uncertainty_m', 'dataset_id', 'datum_precisie', 'event_datum', 'event_datum_tot', 'event_id', 'inspanning_eenheid', 'inspanning_waarde', 'jaar', 'latitude', 'longitude', 'ruimtelijke_klasse', 'sampling_protocol', 'zelfstandig_meetellen']),
    'pq_vegetatie_bronoverlap': frozenset(['doelrecord_sleutel', 'doelsysteem', 'koppelmethode', 'overlap_id', 'resultaat_id', 'toelichting', 'zekerheid']),
    'pq_vegetatie_bronresultaat': frozenset(['basis_of_record', 'bron_occurrence_id', 'bronmetadata', 'catalogusnummer', 'event_id', 'hoeveelheid', 'hoeveelheid_eenheid', 'hoeveelheid_oorspronkelijk', 'nederlandse_naam', 'occurrence_status', 'resultaat_id', 'taxon_bronkoppeling_id', 'taxonomische_status_aangeleverd', 'wetenschappelijke_naam', 'wetenschappelijke_naam_bron']),
    'pq_vegetatie_import': frozenset(['aangemaakt_op', 'aantal_opnamen', 'aantal_pq', 'aantal_taxa', 'aantal_waarnemingen', 'bronbestand', 'import_id', 'importstatus', 'ontvangen_op', 'sha256', 'taxonlijst_versie', 'toelichting']),
    'pq_vegetatie_opname': frozenset(['bodemtype_code', 'bodemtype_code_aangeleverd', 'bodemtype_naam', 'bodemtype_status', 'geom', 'ipi_code', 'ipi_naam', 'jaar', 'opname_datum', 'opname_id', 'pq_nummer', 'x_rd', 'y_rd']),
    'pq_vegetatie_opname_bronkoppeling': frozenset(['beoordeeld_op', 'bewijs', 'event_id', 'koppelstatus', 'opname_id', 'regelversie']),
    'pq_vegetatie_opname_plot': frozenset(['afstand_grens_m', 'match_method', 'opname_id', 'plot_id', 'polygon_bron']),
    'pq_vegetatie_pq': frozenset(['bronbestand', 'eerste_jaar', 'import_id', 'importversie', 'laatste_jaar', 'lmf', 'n2000_gebied', 'pq_nummer']),
    'pq_vegetatie_waarneming': frozenset(['abundantie_code', 'abundantie_percentage', 'bron_taxon_lokaal_id', 'gra_gebr', 'natuurwaarde_n', 'oever_cultuur', 'opname_id', 'plabed_code', 'taxon_bronkoppeling_id', 'trofgra', 'trofind', 'trofwat', 'vochtind', 'waarneming_id', 'zuur_vn', 'zuur_za']),
    'richtlijnen': frozenset(['id', 'naam']),
    'soort_familie': frozenset(['familie_id', 'id', 'soort_id']),
    'soort_habitat': frozenset(['habitat_id', 'id', 'soort_id']),
    'soort_richtlijn': frozenset(['id', 'richtlijn_id', 'soort_id']),
    'soorten': frozenset(['duitse_naam', 'engelse_naam', 'euring_code', 'franse_naam', 'id', 'latijnse_naam', 'soort_naam', 'spaanse_naam', 'taxon_bronkoppeling_id']),
    'soorten_habitattypen': frozenset(['habitattype_id', 'id', 'koppelingsterkte', 'soort_id']),
    'soorten_kenmerken': frozenset(['code', 'hoofdcategorie_id', 'id', 'soort_id', 'soortnaam', 'waarde']),
    'soorten_kenmerken_datadictionary': frozenset(['betekenis', 'betekenis_nederlands', 'code_type', 'id', 'parent_code', 'status', 'veld']),
    'soorten_kenmerken_hoofdcategorien': frozenset(['beschrijving', 'beschrijving_engels', 'code', 'id']),
    'soorten_kenmerken_voedsel': frozenset(['id', 'soort_id', 'soortnaam', 'voedselcode', 'waarde']),
    'soorten_kenmerken_vogeltypering': frozenset(['aangemaakt_op', 'bijgewerkt_op', 'soort_id', 'soortnaam', 'vogeltypering']),
    'sovon_avimap_bezoek': frozenset(['aangemaakt_op', 'batch_id', 'begintijd', 'bezoekdatum', 'bezoekduur_min', 'bron_aantal_records', 'bron_aantal_soorten', 'bron_bezoek_id', 'bronproject_id', 'dagvanjaar', 'deelbezoek', 'deelbezoek_deel', 'eindtijd', 'gunstig', 'jaar', 'lopend_jaar', 'niet_vogel_recordaantal', 'omstandigheden_opm', 'opmerking', 'plot_id', 'plotnaam']),
    'sovon_avimap_daz_bezoek_taxon': frozenset(['aangemaakt_op', 'aantal', 'batch_id', 'bron_bezoek_id', 'bronrecordaantal', 'doelrelatie', 'kwaliteitsnotitie', 'lopend_jaar', 'nederlandse_naam', 'nulregel', 'reconstructieversie', 'taxon_bronkoppeling_id', 'waarnemingsstatus', 'wetenschappelijke_naam']),
    'sovon_avimap_import_batch': frozenset(['aangemaakt_op', 'actueel', 'batch_id', 'bronbestanden_json', 'bronmanifest_sha256', 'bronmap', 'bronproject_id', 'kwaliteitsnotitie', 'niet_vogel_bezoeken', 'niet_vogel_records', 'niet_vogel_taxa', 'ontvangen_op', 'regelversie']),
    'sovon_avimap_ndff_daz_koppeling': frozenset(['aangemaakt_op', 'batch_id', 'koppel_sleutel', 'koppelstatus', 'kwaliteitsnotitie', 'ndff_aantal_som', 'ndff_recordaantal', 'ndff_waarneming_id', 'sovon_aantal_som', 'sovon_bron_waarneming_ids', 'sovon_bronrecordaantal']),
    'sovon_avimap_taxon': frozenset(['aangemaakt_op', 'batch_id', 'ndff_soort_id', 'nederlandse_naam', 'soortgroep_code', 'soortgroep_naam', 'soortnr', 'taxon_bronkoppeling_id', 'taxon_mapping_status', 'wetenschappelijke_naam']),
    'sovon_avimap_vogel_sync_batch': frozenset(['afsluitjaar', 'batch_id', 'behouden_database_territoria_zonder_bronregel', 'bijgewerkte_bezoekduur', 'bijgewerkte_bezoekteksten', 'bijgewerkte_in_plot_records', 'bijgewerkte_territoriumaantallen', 'bron_bezoeken', 'bron_territoriumresultaten', 'bron_vogelrecords', 'kwaliteitsnotitie', 'regelversie', 'sync_id', 'toegevoegde_bezoeken', 'toegevoegde_territoriumresultaten', 'toegevoegde_vogelrecords', 'uitgevoerd_op']),
    'sovon_avimap_waarneming': frozenset(['aangemaakt_op', 'aantal', 'batch_id', 'broedcode', 'bron_bezoek_id', 'bron_waarneming_id', 'bronproject_id', 'bronstatus', 'cluster_territorium', 'cluster_territorium_id', 'dag', 'dagvanjaar', 'gegevensrol', 'geom', 'geslacht', 'in_plot', 'ioc_sort', 'jaar', 'kopid', 'lopend_jaar', 'maand', 'opmerking', 'plot_id', 'soortgroep_code', 'soortnr', 'telgebied', 'waarnemingsdatum', 'wrntype', 'x_coord', 'y_coord']),
    'species_trait_value': frozenset(['boolean_value', 'category_id', 'confidence_score', 'created_at', 'evidence_note', 'geographic_context', 'id', 'import_batch_id', 'is_preferred', 'levensfase', 'numeric_value', 'ordinal_value', 'population_context', 'preferred_context_hash', 'quality_status', 'raw_value', 'seizoen', 'soort_id', 'trait_id', 'updated_at', 'value_type']),
    'species_trait_value_source': frozenset(['evidence_note', 'source_id', 'source_locator', 'species_trait_value_id']),
    'taxa': frozenset(['aangemaakt_op', 'aanvullende_namen', 'beheerstatus', 'bovenliggend_taxon_id', 'concept_identificatie', 'familie', 'geaccepteerd_taxon_id', 'geslacht', 'gewijzigd_op', 'groep_id', 'klasse', 'naam_auteur', 'naam_gepubliceerd_in', 'naam_gepubliceerd_in_id', 'naam_gepubliceerd_jaar', 'naam_identificatie', 'naam_volgens', 'naam_volgens_id', 'naam_volgens_versie', 'naam_zonder_auteur', 'nederlandse_naam', 'nomenclatuurcode', 'nomenclatuurstatus', 'oorspronkelijk_taxon_id', 'opmerkingen', 'orde', 'rijk', 'stam', 'taxon_id', 'taxon_uuid', 'taxonmetadata', 'taxonomische_status', 'taxonrang', 'taxonrang_bron', 'taxonvorm', 'vastgesteld_door', 'vastgesteld_op', 'weergavenaam', 'wetenschappelijke_naam']),
    'taxa_bronkoppeling': frozenset(['aangemaakt_op', 'actieve_exacte_bron', 'beoordeeld_door', 'beoordeeld_op', 'besluitversie', 'bron_citatie', 'bron_concept_identificatie', 'bron_context_sha256', 'bron_dataset', 'bron_identiteit_sha256', 'bron_licentie', 'bron_naam_identificatie', 'bron_naam_volgens', 'bron_nederlandse_naam', 'bron_sleuteltype', 'bron_soortgroep', 'bron_systeem', 'bron_taxon_id', 'bron_taxonomische_status', 'bron_taxonrang', 'bron_uri', 'bron_versie', 'bron_wetenschappelijke_naam', 'bronbestand_sha256', 'bronmetadata', 'doeltaxon_sleutel', 'gewijzigd_op', 'ingetrokken_op', 'koppeling_id', 'koppelmethode', 'koppelstatus', 'onderbouwing', 'regelversie', 'taxon_id', 'taxonrelatie']),
    'taxon_groepen': frozenset(['aangemaakt_op', 'actief', 'bovenliggende_groep_id', 'gewijzigd_op', 'groep_code', 'groep_id', 'groep_naam', 'groepmetadata', 'indeling_bron', 'indeling_versie', 'omschrijving', 'sorteervolgorde']),
    'tellers': frozenset(['id', 'tellercode']),
    'territoria': frozenset(['bron_id', 'id', 'invoerdatum', 'jaar', 'plot_id', 'soort_id', 'territoria']),
    'trait_analysis_scope': frozenset(['created_at', 'generation_commit', 'id', 'naam_nl', 'omschrijving_nl', 'scope_code', 'source_file', 'source_sha256']),
    'trait_analysis_scope_species': frozenset(['scope_id', 'soort_id']),
    'trait_category': frozenset(['category_code', 'id', 'naam_nl', 'omschrijving_nl', 'sort_order', 'status', 'trait_id']),
    'trait_definition': frozenset(['context_standaard', 'created_at', 'datatype', 'domein', 'eenheid', 'id', 'levensfase_standaard', 'naam_nl', 'omschrijving_nl', 'seizoen_standaard', 'status', 'trait_code', 'trait_rol', 'trait_version', 'updated_at', 'verplicht_v1']),
    'trait_import_batch': frozenset(['batch_code', 'bron_rijen', 'file_sha256', 'geimporteerde_waarden', 'gekoppelde_soorten', 'id', 'imported_at', 'omzettingsregels', 'source_id', 'source_url', 'source_version', 'status', 'taxonomie_naam', 'taxonomie_versie']),
    'trait_source': frozenset(['bron_scope', 'bronrang', 'doi', 'geraadpleegd_op', 'id', 'licentie', 'notities', 'source_code', 'titel', 'url', 'volledige_citatie']),
    'trait_taxon_mapping': frozenset(['evidence_note', 'id', 'mapping_method', 'soort_id', 'source_id', 'source_scientific_name', 'status']),
    'trends': frozenset(['id', 'jaar', 'regio', 'soort_id', 'waarde']),
    'vangblik_event': frozenset(['batch_id', 'country', 'country_code', 'event_id', 'event_remarks', 'eventdatum', 'geen_harde_nul', 'geodetic_datum', 'heeft_predatie_of_zoogdierrisico', 'is_vergelijkingsblik_1959', 'locality', 'locatieversie_id', 'occurrenceaantal', 'owner_institution_code', 'raw_payload', 'sample_size_unit', 'sample_size_value', 'sampling_effort', 'sampling_protocol', 'start_day_of_year']),
    'vangblik_event_plot': frozenset(['event_id', 'is_eenduidig', 'koppelregel_versie', 'plot_id']),
    'vangblik_import_batch': frozenset(['batch_id', 'dataset_doi', 'dataset_titel', 'dataset_versie', 'eventaantal', 'eventbestand_sha256', 'geimporteerd_op', 'licentie', 'occurrenceaantal', 'occurrencebestand_sha256']),
    'vangblik_locatieversie': frozenset(['batch_id', 'decimal_latitude', 'decimal_longitude', 'geldig_tot_en_met', 'geldig_vanaf', 'is_verplaatst_blok_7_18', 'locatiepunt', 'locatieversie_id', 'location_id', 'onzekerheid_meter', 'verbatim_x_rd', 'verbatim_y_rd']),
    'vangblik_vangst': frozenset(['analyse_status', 'basis_of_record', 'batch_id', 'bron_event_id', 'event_id', 'individual_count', 'is_verweesd', 'life_stage', 'minimumvangst_mogelijk', 'occurrence_id', 'occurrence_remarks', 'occurrence_status', 'owner_institution_code', 'raw_payload', 'recorded_by', 'referentieel_geldig', 'taxon_bronkoppeling_id']),
    'weer': frozenset(['FG', 'Naam', 'PG', 'RH', 'SQ', 'STN', 'TG', 'TN', 'TX', 'UG', 'datum']),
    'weer_legenda': frozenset(['toelichting', 'variabele']),
}

def central_query_schema_contract(schema: dict[str, set[str]]) -> None:
    expected = dict(CENTRAL_QUERY_SCHEMA)
    additions = source_family_tables()
    if set(schema) & set(additions):
        expected.update({table: CENTRAL_QUERY_SCHEMA[original] for table,original in additions.items()})
    for table in sorted(set(schema) | set(expected)):
        if table not in schema or table not in expected:
            raise ValueError(table + ": niet beoordeelde schemawijziging")
        if set(schema[table]) != expected[table]:
            raise ValueError(table + ": gewijzigde kolommen vereisen centrale routecontrole")


class CentralQueryDatabase:
    """One local MySQL connection contract; never logs credentials or source rows."""
    def __init__(self, database='Meijendel', login_path='meijendel_root',
                 client='/usr/local/mysql/bin/mysql', *, writable=False, host='127.0.0.1',port=3306):
        query_identifier(database)
        self.database = database
        self.args = [str(client), '--login-path='+login_path, '--protocol=TCP',
                     '--host='+str(host), '--port='+str(port), '--batch', '--raw',
                     '--skip-column-names', database]
        self.writable = writable

    def sql(self, sql: str, *, write=False) -> str:
        if write and not self.writable:
            raise ValueError('Alleen-lezen controle kan geen database wijzigen')
        command = sql if write else 'START TRANSACTION READ ONLY;\n'+sql+'\nCOMMIT;'
        result = subprocess.run(self.args, input=command, text=True, capture_output=True)
        if result.returncode:
            raise RuntimeError(result.stderr.strip())
        return result.stdout.strip()

    def objects(self, sql: str) -> list[dict]:
        return [json.loads(line) for line in self.sql(sql).splitlines()]

    def schema(self) -> dict[str, set[str]]:
        output = self.sql("SELECT c.TABLE_NAME,c.COLUMN_NAME FROM information_schema.COLUMNS c "
            "JOIN information_schema.TABLES t ON t.TABLE_SCHEMA=c.TABLE_SCHEMA AND t.TABLE_NAME=c.TABLE_NAME "
            "WHERE c.TABLE_SCHEMA=DATABASE() AND t.TABLE_TYPE='BASE TABLE' ORDER BY c.TABLE_NAME,c.ORDINAL_POSITION;")
        schema = defaultdict(set)
        for line in output.splitlines():
            table, column = line.split('\t'); schema[table].add(column)
        return dict(schema)


def central_query_audit(db: CentralQueryDatabase, *, require_guards=True) -> dict:
    """Whole database acceptance, including unknown layers, pinned IDs and fan-out.

    A taxon without a known group is retained by LEFT JOIN. No observation is
    accepted on a free text name match. DDL by root cannot be intercepted by a
    MySQL trigger: this complete scan is required before AND after controlled DDL.
    """
    schema = db.schema()
    central_query_schema_contract(schema)
    routes = central_query_routes(schema)
    result = {'rule':QUERY_RULE, 'database':db.database, 'tables':len(schema), 'routes':{}, 'errors':[]}
    errors = result['errors']
    invalid = db.sql("SELECT COUNT(*) FROM taxa_bronkoppeling b LEFT JOIN taxa t ON t.taxon_id=b.taxon_id "
        "WHERE b.taxon_id IS NOT NULL AND t.taxon_id IS NULL;")
    if invalid != '0': errors.append('Verweesde centrale taxonkoppelingen: '+invalid)
    if db.sql('SELECT COUNT(*) FROM taxa t LEFT JOIN taxon_groepen g ON g.groep_id=t.groep_id '
              'WHERE t.groep_id IS NOT NULL AND g.groep_id IS NULL;') != '0':
        errors.append('Verweesde groepsindeling')
    fks = set(tuple(line.split('\t')) for line in db.sql(
        "SELECT TABLE_NAME,COLUMN_NAME,REFERENCED_TABLE_NAME,REFERENCED_COLUMN_NAME "
        "FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=DATABASE() "
        "AND REFERENCED_TABLE_NAME IS NOT NULL;").splitlines())
    if db.sql("SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=DATABASE() "
              "AND REFERENCED_TABLE_SCHEMA IS NOT NULL AND REFERENCED_TABLE_SCHEMA<>DATABASE();")!='0':
        errors.append('Foreign key verwijst buiten de gecontroleerde database')
    for key,prefix in [('lvd-meijendel-v1-6','externe_ecologie'),*SOURCE_FAMILIES.items()]:
        if prefix+'_dataset' not in schema: continue
        if prefix!='externe_ecologie' and db.sql(f'SELECT COUNT(*) FROM {prefix}_dataset WHERE BINARY dataset_sleutel<>BINARY '+query_literal(key)+';')!='0':
            errors.append(prefix+': dataset hoort niet bij deze bronfamilie')
        if prefix!='externe_ecologie' and db.sql("SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS "
                "WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME IN ("+
                ','.join(query_literal(prefix+'_'+s) for s in ('event','resultaat','overlap'))+
                ") AND (DELETE_RULE NOT IN ('RESTRICT','NO ACTION') OR UPDATE_RULE NOT IN ('RESTRICT','NO ACTION'));")!='0':
            errors.append(prefix+': automatische cascade niet toegestaan')
        for table,field,parent,parent_field in [
            (prefix+'_event','dataset_id',prefix+'_dataset','dataset_id'),
            (prefix+'_resultaat','event_id',prefix+'_event','event_id'),
            (prefix+'_overlap','resultaat_id',prefix+'_resultaat','resultaat_id')]:
            if (table,field,parent,parent_field) not in fks:
                errors.append(table+': bronouder ontbreekt')
            orphans = db.sql(f'SELECT COUNT(*) FROM {table} c LEFT JOIN {parent} p '
                f'ON c.{field}=p.{parent_field} WHERE p.{parent_field} IS NULL;')
            if orphans!='0': errors.append(table+': verweesde bronregels: '+orphans)
    triggers = set(line.split('\t')[0] for line in db.sql(
        "SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE();").splitlines())
    if require_guards and 'cq_registry_bu' not in triggers:
        errors.append('Centrale bronbesluiten missen schrijfbewaking')
    if require_guards:
        definitions = db.objects("SELECT JSON_OBJECT('name',TRIGGER_NAME,'table',EVENT_OBJECT_TABLE,"
            "'event',EVENT_MANIPULATION,'timing',ACTION_TIMING,'body',ACTION_STATEMENT) FROM information_schema.TRIGGERS "
            "WHERE TRIGGER_SCHEMA=DATABASE();")
        actual={row['name']:row for row in definitions}
        for match in re.finditer(r'CREATE TRIGGER (\w+) BEFORE (INSERT|UPDATE|DELETE) ON `?(\w+)`? FOR EACH ROW (BEGIN.*?END)\$\$',
                                central_query_triggers_sql({'routes':routes}),re.S):
            name,event,table,body=match.groups()
            found=actual.get(name)
            if (found is None or found['table']!=table or found['event']!=event or found['timing']!='BEFORE'
                    or ' '.join(found['body'].split())!=' '.join(body.split())):
                errors.append(name+': schrijfbewaking ontbreekt of is gewijzigd')
    for table, route in routes.items():
        kind = route['kind']; qtable = query_identifier(table)
        count = int(db.sql(f'SELECT COUNT(*) FROM {qtable};'))
        entry = {'rows':count, **route}; result['routes'][table] = entry
        if kind == 'staging':
            if count: errors.append(f'{table}: {count} niet toegelaten tijdelijke invoerregels')
            continue
        if kind in {'catalogue','direct','external','derived'}:
            if 'taxon_bronkoppeling_id' not in schema[table]:
                errors.append(table+': vaste centrale bronkoppeling ontbreekt'); continue
            if (table,'taxon_bronkoppeling_id','taxa_bronkoppeling','koppeling_id') not in fks:
                errors.append(table+': centrale FK ontbreekt')
            allowed = ('w.taxon_bronkoppeling_id IS NOT NULL' if kind == 'catalogue' and route.get('nullable')
                       else 'w.'+query_identifier(route['name_field'])+' IS NOT NULL'
                       if kind == 'derived' and route.get('nullable') else 'TRUE')
            missing = int(db.sql(f'SELECT COUNT(*) FROM {qtable} w LEFT JOIN taxa_bronkoppeling b '
                'ON b.koppeling_id=w.taxon_bronkoppeling_id LEFT JOIN taxa t ON t.taxon_id=b.taxon_id '
                f'WHERE ({allowed}) AND (t.taxon_id IS NULL OR b.koppelstatus NOT IN (\'kandidaat\',\'bevestigd\'));'))
            if missing: errors.append(f'{table}: {missing} regels niet centraal bereikbaar')
            entry['unreachable'] = missing
            if kind in {'catalogue','direct','external'}:
                mismatch = db.sql(f'SELECT COUNT(*) FROM {qtable} w JOIN taxa_bronkoppeling b '
                    'ON b.koppeling_id=w.taxon_bronkoppeling_id WHERE ('+central_source_condition(table,route)+') IS NOT TRUE;')
                if mismatch!='0': errors.append(table+': verkeerde bronidentiteit: '+mismatch)
            if kind == 'derived':
                mismatch = db.sql(f'SELECT COUNT(*) FROM {qtable} w JOIN taxa_bronkoppeling b '
                    'ON b.koppeling_id=w.taxon_bronkoppeling_id WHERE '
                    f'BINARY b.bron_dataset<>BINARY {query_literal(table)} OR '
                    f'BINARY b.bron_versie<>BINARY w.{query_identifier(route["version_field"])} OR '
                    f'BINARY b.bron_taxon_id<>BINARY {derived_key_sql(route)};')
                if mismatch != '0': errors.append(table+': broncontext wijkt af: '+mismatch)
        else:
            catalogue = route.get('catalogue', 'ndff_soorten')
            if 'taxon_bronkoppeling_id' not in schema[catalogue]:
                errors.append(table+': centrale catalogusroute ontbreekt'); continue
            if kind == 'ndff_child':
                joined = f'{qtable} w LEFT JOIN ndff_open_waarneming o ON {route["join"]} '
                joined += 'LEFT JOIN ndff_soorten c ON c.soort_key=o.soort_key '
            else:
                joined = f'{qtable} w LEFT JOIN {query_identifier(catalogue)} c ON {route["join"]} '
            reference_scope = 'c.taxon_bronkoppeling_id IS NOT NULL AND ' if route.get('role')=='soortreferentie' else ''
            missing = int(db.sql('SELECT COUNT(*) FROM '+joined+
                'LEFT JOIN taxa_bronkoppeling b ON b.koppeling_id=c.taxon_bronkoppeling_id '
                'LEFT JOIN taxa t ON t.taxon_id=b.taxon_id WHERE '+reference_scope+"(t.taxon_id IS NULL "
                "OR b.koppelstatus NOT IN ('kandidaat','bevestigd'));"))
            entry['unreachable'] = missing
            if missing: errors.append(f'{table}: {missing} niet centraal bereikbare regels')
        if require_guards:
            for suffix in ('bi','bu'):
                if central_trigger_name(table,suffix) not in triggers:
                    errors.append(table+': schrijfbewaking ontbreekt: '+suffix)
    result['status'] = 'verified' if not errors else 'blocked'
    return result


def central_trigger_name(table: str, suffix: str) -> str:
    return 'cq_' + hashlib.sha256(table.encode()).hexdigest()[:20] + '_' + suffix


def central_query_plan(db: CentralQueryDatabase) -> dict:
    """Source identities, not display names, bind every current observation layer."""
    schema = db.schema(); routes = central_query_routes(schema)
    links = db.objects("SELECT JSON_OBJECT('id',koppeling_id,'taxon_id',taxon_id,'dataset',bron_dataset,"
        "'version',bron_versie,'source_id',bron_taxon_id,'name',bron_wetenschappelijke_naam,"
        "'metadata',bronmetadata,'status',koppelstatus) FROM taxa_bronkoppeling "
        "WHERE bron_systeem='Meijendel' AND ingetrokken_op IS NULL;")
    plan = {'rule':QUERY_RULE,'catalogues':{},'derived':{},'external':{},'operational':None,
            'routes':routes, 'schema':{k:sorted(v) for k,v in schema.items()}}
    by_catalogue = defaultdict(dict)
    for link in links:
        if link['dataset'] in {'soorten','ndff_soorten','sovon_avimap_taxon'}:
            key = link['source_id']
            if key in by_catalogue[link['dataset']]: raise ValueError('Ambigue broncatalogusidentiteit')
            by_catalogue[link['dataset']][key] = link
    for table, route in routes.items():
        if route['kind'] != 'catalogue': continue
        fields = ['id'] if table == 'soorten' else ['soort_key'] if table == 'ndff_soorten' else ['batch_id','soortgroep_code','soortnr']
        rows = db.objects('SELECT JSON_OBJECT('+','.join(query_literal(c)+','+query_identifier(c) for c in fields)+
                          ') FROM '+query_identifier(table)+';')
        mapping = []
        for row in rows:
            key = str(row[fields[0]]) if len(fields)==1 else json.dumps([row[c] for c in fields],separators=(',', ':'))
            link = by_catalogue[table].get(key)
            if not link: raise ValueError(f'{table}: niet geregistreerde bronidentiteit {key}')
            if link['taxon_id'] is None:
                if table != 'soorten': raise ValueError('Ontbrekend centraal taxon')
                continue  # Unused, unresolved catalogue entry; observations still fail closed.
            mapping.append({'key':row,'link':link['id']})
        plan['catalogues'][table] = mapping
    # Source catalogue names remain the literal evidence after central taxon merges.
    candidates = defaultdict(list)
    for link in links:
        if link['dataset'] in {'ndff_soorten','sovon_avimap_taxon','ndff_lmfa_doelsoort',
                              'ndff_zeereep_doelbereik'} and link['taxon_id'] is not None:
            candidates[link['name']].append(link)
    for table, route in routes.items():
        if route['kind'] != 'derived': continue
        fields = [route['version_field'],route['name_field'],*route['context_fields']]
        rows = db.objects('SELECT DISTINCT JSON_OBJECT('+','.join(query_literal(c)+',w.'+query_identifier(c) for c in fields)+
                          ",'source_key',"+derived_key_sql(route)+') FROM '+query_identifier(table)+
                          ' w WHERE w.'+query_identifier(route['name_field'])+' IS NOT NULL;')
        registrations = []
        for row in rows:
            found = candidates[row[route['name_field']]]
            if 'soortgroep_raw' in row:
                found = [b for b in found if b['dataset']=='ndff_soorten' and
                         b['metadata'].get('soortgroep_raw') == row['soortgroep_raw']]
            elif table.startswith('sovon_avimap_'):
                avimap = [b for b in found if b['dataset']=='sovon_avimap_taxon' and
                          b['metadata'].get('batch_id') == row.get('batch_id')]
                # Ondatra has a documented target range but no positive Avimap record.
                found = avimap or ([b for b in found if b['dataset']=='ndff_soorten']
                                  if row[route['name_field']]=='Ondatra zibethicus' else [])
            else:
                found = [b for b in found if b['dataset']=='ndff_soorten' or
                         (table.startswith('ndff_lmfa_') and b['dataset']=='ndff_lmfa_doelsoort') or
                         (table.startswith('ndff_zeereep_') and b['dataset']=='ndff_zeereep_doelbereik')]
            targets = {b['taxon_id'] for b in found}
            if len(targets) != 1:
                raise ValueError(f'{table}: bronnaam {row[route["name_field"]]!r} niet eenduidig ({len(targets)} taxa)')
            registrations.append({'version':row[route['version_field']], 'source_key':row['source_key'],
                'name':row[route['name_field']], 'taxon_id':next(iter(targets)),
                'metadata':{'bronvelden':{c:row[c] for c in fields},
                            'onderliggende_bronkoppeling_ids':sorted(b['id'] for b in found),
                            'interpretatie':'nominale taxonroute; geen bevestigde conceptgelijkheid'}})
        plan['derived'][table] = registrations
    datasets = db.objects("SELECT JSON_OBJECT('id',dataset_id,'key',dataset_sleutel,'version',"
        "CONCAT(bronversie,'; sha256:',bronbestand_sha256)) FROM externe_ecologie_dataset;")
    for dataset in datasets:
        rows = db.objects("SELECT JSON_OBJECT('resultaat_id',r.resultaat_id,'wetenschappelijke_naam',r.wetenschappelijke_naam,"
            "'wetenschappelijke_naam_bron',r.wetenschappelijke_naam_bron,'nederlandse_naam',r.nederlandse_naam,"
            "'taxonrang',r.taxonrang,'bronmetadata',r.bronmetadata) FROM externe_ecologie_resultaat r "
            f"JOIN externe_ecologie_event e ON e.event_id=r.event_id WHERE e.dataset_id={int(dataset['id'])};")
        existing = [{**b,'bron_systeem':'Meijendel','bron_dataset':b['dataset'],'bron_versie':b['version'],
                     'ingetrokken_op':None,'bronmetadata':b['metadata'],'koppeling_id':b['id'],
                     'koppelstatus':b['status']} for b in links if b['dataset']==dataset['key'] and b['version']==dataset['version']]
        resolved_rows = []
        unresolved = []
        unresolved_rows = [r for r in rows if r['wetenschappelijke_naam']=='Indet.'
                           and dataset['key']=='naturalis-botany-meijendel']
        resolved_map = resolve_external_taxon_links([r for r in rows if r not in unresolved_rows],existing,
                                                    dataset['key'],dataset['version'])
        for row in rows:
            if row in unresolved_rows:
                unresolved.append(row); continue
            resolved_rows.append({'result_id':row['resultaat_id'],'link':resolved_map[row['resultaat_id']]})
        if unresolved:
            if (dataset['key']!='naturalis-botany-meijendel' or len(unresolved)!=1 or
                    unresolved[0]['wetenschappelijke_naam']!='Indet.'):
                raise ValueError(f'{dataset["key"]}: {len(unresolved)} niet opgeloste bronvermeldingen')
            row = unresolved[0]
            usage = {f:row['bronmetadata'].get(f) for f in SOURCE_TAXON_FIELDS}
            usage.update(dataset=dataset['key'],name=row['wetenschappelijke_naam'],raw_name=row['wetenschappelijke_naam_bron'],
                         nl=row['nederlandse_naam'],rank=row['taxonrang'])
            original = [b for b in existing if source_usage_projection(b['metadata'])==usage]
            if len(original)!=1 or original[0]['taxon_id'] is not None:
                raise ValueError('Oorspronkelijk onbeoordeeld Indet.-besluit niet eenduidig')
            plan['operational'] = {'source_link':original[0]['id'],'result_id':row['resultaat_id'],
                'dataset':dataset['key'],'version':dataset['version'],'metadata':usage,
                'label':'Onbepaald collectieobject — Naturalis Botany'}
        plan['external'][dataset['key']] = resolved_rows
    plan['original_constraint_names'] = db.sql("SELECT CONSTRAINT_NAME FROM information_schema.TABLE_CONSTRAINTS "
        "WHERE CONSTRAINT_SCHEMA=DATABASE() ORDER BY CONSTRAINT_NAME;").splitlines()
    plan['original_max_ids'] = {table:int(db.sql(f'SELECT MAX({field}) FROM {table};'))
                               for table,field in [('taxa','taxon_id'),('taxa_bronkoppeling','koppeling_id')]}
    return plan


def central_query_migration_sql(plan: dict, *, commit=False) -> str:
    """Only DML; run twice (rollback then commit) after separately tested DDL."""
    statements = ['START TRANSACTION;']
    operational = plan['operational']
    if operational:
        meta = {'registratieregel':QUERY_RULE,'interpretatie':'geen bepaald biologisch taxon of rang',
                'oorspronkelijk_onbeoordeeld_bronbesluit':operational['source_link']}
        statements += ["INSERT INTO taxa(taxon_uuid,wetenschappelijke_naam,weergavenaam,taxonvorm,"
            "taxonomische_status,beheerstatus,naam_volgens,taxonmetadata) VALUES(UUID(),'Indet.',"+
            query_literal(operational['label'])+",'operationele_eenheid','unresolved','voorlopig',"
            "'Ongedetermineerd Naturalis-collectieobject; geen soortbepaling',"+query_literal(json.dumps(meta,ensure_ascii=False))+');',
            'SET @cq_operational=LAST_INSERT_ID();',
            "INSERT INTO taxa_bronkoppeling(bron_systeem,bron_dataset,bron_versie,bron_taxon_id,bron_sleuteltype,"
            "bron_wetenschappelijke_naam,bronmetadata,taxon_id,koppelstatus,taxonrelatie,koppelmethode,regelversie,onderbouwing) "
            "SELECT bron_systeem,bron_dataset,bron_versie,CONCAT('operationeel:',koppeling_id),'afgeleid',"
            "bron_wetenschappelijke_naam,bronmetadata,@cq_operational,'kandidaat','onbekend','onbepaald_collection_object',"+
            query_literal(QUERY_RULE)+",'Alleen operationele vindbaarheid; oorspronkelijk onbeoordeeld besluit blijft ongewijzigd' "
            f"FROM taxa_bronkoppeling WHERE koppeling_id={operational['source_link']};",
            'SET @cq_operational_link=LAST_INSERT_ID();']
    for table, mapping in plan['catalogues'].items():
        for row in mapping:
            condition = ' AND '.join(query_identifier(c)+' <=> '+query_literal(v) for c,v in row['key'].items())
            statements.append(f'UPDATE {query_identifier(table)} SET taxon_bronkoppeling_id={row["link"]} WHERE {condition};')
    for table, registrations in plan['derived'].items():
        for row in registrations:
            fields = ['bron_systeem','bron_dataset','bron_versie','bron_taxon_id','bron_sleuteltype',
                      'bron_wetenschappelijke_naam','bronmetadata','taxon_id','koppelstatus','taxonrelatie',
                      'koppelmethode','regelversie','onderbouwing']
            vals = ['Meijendel',table,row['version'],row['source_key'],'afgeleid',row['name'],
                    json.dumps(row['metadata'],ensure_ascii=False),row['taxon_id'],'kandidaat','onbekend',
                    'brongetrouwe_afgeleide_meettaxonroute',QUERY_RULE,
                    'Versiegebonden bronvelden en onderliggende centrale bronkoppelingen; geen conceptgelijkheid']
            statements.append('INSERT INTO taxa_bronkoppeling('+','.join(fields)+') VALUES('+','.join(map(query_literal,vals))+');')
        route = plan['routes'][table]
        identity = ("UNHEX(SHA2(CAST(JSON_ARRAY('Meijendel',"+query_literal(table)+',w.'+query_identifier(route['version_field'])+
                    ','+derived_key_sql(route)+') AS CHAR CHARACTER SET utf8mb4),256))')
        statements.append(f'UPDATE {query_identifier(table)} w JOIN taxa_bronkoppeling b ON b.bron_identiteit_sha256={identity} '
                          "AND b.ingetrokken_op IS NULL SET w.taxon_bronkoppeling_id=b.koppeling_id;")
    # A temporary mapping is exact per source result ID and leaves every old cell intact.
    statements.append('CREATE TEMPORARY TABLE cq_result_map(result_id BIGINT PRIMARY KEY,link_id BIGINT NOT NULL);')
    rows = [f'({r["result_id"]},{r["link"]})' for group in plan['external'].values() for r in group]
    for index in range(0,len(rows),1000):
        statements.append('INSERT INTO cq_result_map VALUES '+','.join(rows[index:index+1000])+';')
    if operational:
        statements.append(f'INSERT INTO cq_result_map VALUES({operational["result_id"]},@cq_operational_link);')
    statements += ['UPDATE externe_ecologie_resultaat r JOIN cq_result_map m ON m.result_id=r.resultaat_id '
                   'SET r.taxon_bronkoppeling_id=m.link_id;',
                   'DROP TEMPORARY TABLE cq_result_map;', 'COMMIT;' if commit else 'ROLLBACK;']
    return '\n'.join(statements)


def central_query_schema_sql(plan: dict, *, finalize=False) -> str:
    statements = []
    schema = plan['schema']
    if not finalize:
        if 'bron_context_sha256' not in schema['taxa_bronkoppeling']:
            statements.append('ALTER TABLE taxa_bronkoppeling ADD COLUMN bron_context_sha256 BINARY(32) '
                'GENERATED ALWAYS AS (UNHEX(SHA2(CAST('+query_context_sql('bronmetadata')+
                ' AS CHAR CHARACTER SET utf8mb4),256))) STORED, ADD INDEX ix_cq_broncontext(bron_context_sha256);')
        for table, route in plan['routes'].items():
            if route['kind'] not in {'catalogue','derived','external'}: continue
            if 'taxon_bronkoppeling_id' not in schema[table]:
                name = hashlib.sha256(table.encode()).hexdigest()[:20]
                statements.append(f'ALTER TABLE {query_identifier(table)} ADD COLUMN taxon_bronkoppeling_id BIGINT UNSIGNED NULL,'
                    f' ADD INDEX ix_cq_{name}(taxon_bronkoppeling_id), ADD CONSTRAINT fk_cq_{name} '
                    'FOREIGN KEY(taxon_bronkoppeling_id) REFERENCES taxa_bronkoppeling(koppeling_id);')
    else:
        for table, route in plan['routes'].items():
            if route['kind'] in {'catalogue','derived','external'} and not route.get('nullable'):
                name = hashlib.sha256(table.encode()).hexdigest()[:20]
                statements.append(f'ALTER TABLE {query_identifier(table)} DROP FOREIGN KEY fk_cq_{name}, '
                    'MODIFY taxon_bronkoppeling_id BIGINT UNSIGNED NOT NULL, '
                    f'ADD CONSTRAINT fk_cq_final_{name} FOREIGN KEY(taxon_bronkoppeling_id) REFERENCES taxa_bronkoppeling(koppeling_id);')
    return '\n'.join(statements)


def central_query_triggers_sql(plan: dict) -> str:
    """Guards are local-schema bound and survive a complete dump/restore.

    Source usages for new reconstruction versions are admitted only when the
    already registered source catalogue gives one nominal target. New biological
    taxa still require the normal central register import/review first.
    """
    statements = ['DELIMITER $$']
    routes = plan['routes']
    validity = ("SELECT COUNT(*) INTO cq_n FROM taxa_bronkoppeling b JOIN taxa t ON t.taxon_id=b.taxon_id "
        "WHERE b.koppeling_id=NEW.taxon_bronkoppeling_id AND b.koppelstatus IN ('kandidaat','bevestigd');\n"
        "IF cq_n<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Geen geldige centrale taxonroute'; END IF;\n")
    for table, route in routes.items():
        kind = route['kind']
        if kind=='staging': continue
        body = ''
        declarations = 'DECLARE cq_n BIGINT DEFAULT 0; DECLARE cq_id BIGINT UNSIGNED; DECLARE cq_taxon BIGINT UNSIGNED;'
        if kind=='ndff_child':
            body = ('IF NOT EXISTS(SELECT 1 FROM ndff_open_waarneming o WHERE '+route['join'].replace('w.','NEW.')+
                    ") THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='NDFF-bronwaarneming bestaat niet'; END IF;")
        elif kind == 'catalogue_child':
            # Catalogue target protection + existing FK protects the factual source key.
            join = route['join'].replace('w.', 'NEW.')
            body = ('SELECT COUNT(*) INTO cq_n FROM '+query_identifier(route['catalogue'])+' c '
                'JOIN taxa_bronkoppeling b ON b.koppeling_id=c.taxon_bronkoppeling_id '
                "JOIN taxa t ON t.taxon_id=b.taxon_id WHERE "+join+
                " AND b.koppelstatus IN ('kandidaat','bevestigd'); "
                "IF cq_n<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Bronsoort niet centraal bereikbaar'; END IF;")
            if route.get('role')=='soortreferentie':
                body='IF NOT EXISTS(SELECT 1 FROM '+query_identifier(route['catalogue'])+' c WHERE '+join+\
                     ' AND c.taxon_bronkoppeling_id IS NULL) THEN '+body+' END IF;'
        elif kind == 'catalogue':
            if table=='soorten':
                source_id='CAST(NEW.id AS CHAR)'; name='NEW.latijnse_naam'
            elif table=='ndff_soorten': source_id='NEW.soort_key'; name='NEW.wetenschappelijke_naam'
            else:
                # Initial registry uses compact JSON tuple. This expression removes
                # only structural spaces, never source values (these are integers).
                source_id="REPLACE(CAST(JSON_ARRAY(NEW.batch_id,NEW.soortgroep_code,NEW.soortnr) AS CHAR),' ','')"
                name='NEW.wetenschappelijke_naam'
            conditions = ("b.bron_systeem='Meijendel' AND BINARY b.bron_dataset=BINARY "+query_literal(table)+
                ' AND BINARY b.bron_taxon_id=BINARY '+source_id+' AND b.taxon_id IS NOT NULL '
                "AND b.ingetrokken_op IS NULL AND b.koppelstatus IN ('kandidaat','bevestigd') "
                'AND BINARY b.bron_wetenschappelijke_naam <=> BINARY '+name)
            if table=='ndff_soorten':
                conditions += " AND BINARY JSON_UNQUOTE(JSON_EXTRACT(b.bronmetadata,'$.soortgroep_raw')) <=> BINARY NEW.soortgroep_raw"
            body = (f'SELECT COUNT(*),MIN(b.koppeling_id) INTO cq_n,cq_id FROM taxa_bronkoppeling b WHERE {conditions}; '
                'IF NEW.taxon_bronkoppeling_id IS NULL AND cq_n=1 THEN SET NEW.taxon_bronkoppeling_id=cq_id; END IF; ')
            if table=='soorten':
                body += 'IF NEW.taxon_bronkoppeling_id IS NOT NULL THEN '
            body += ('IF NEW.taxon_bronkoppeling_id IS NULL OR NOT EXISTS(SELECT 1 FROM taxa_bronkoppeling b WHERE '+conditions+
                     ' AND b.koppeling_id=NEW.taxon_bronkoppeling_id) THEN '
                     "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Registreer bronsoort eerst centraal'; END IF; "+validity)
            if table=='soorten': body += 'END IF;'
        elif kind == 'derived':
            key = derived_key_sql(route,'NEW'); version='NEW.'+query_identifier(route['version_field'])
            name='NEW.'+query_identifier(route['name_field'])
            source_hash=("UNHEX(SHA2(CAST(JSON_ARRAY('Meijendel',"+query_literal(table)+','+version+','+key+
                         ') AS CHAR CHARACTER SET utf8mb4),256))')
            conditions = "b.bron_identiteit_sha256="+source_hash+" AND b.ingetrokken_op IS NULL AND b.taxon_id IS NOT NULL AND b.koppelstatus IN ('kandidaat','bevestigd')"
            catalogue='sovon_avimap_taxon' if table.startswith('sovon_avimap_') else 'ndff_soorten'
            context = 'BINARY c.wetenschappelijke_naam=BINARY '+name
            if 'soortgroep_raw' in route['context_fields']: context+=' AND BINARY c.soortgroep_raw=BINARY NEW.soortgroep_raw'
            if 'batch_id' in route['context_fields'] and catalogue=='sovon_avimap_taxon': context+=' AND c.batch_id=NEW.batch_id'
            source_lookup = (f'SELECT COUNT(DISTINCT b.taxon_id),MIN(b.taxon_id) INTO cq_n,cq_taxon FROM {catalogue} c '
                            'JOIN taxa_bronkoppeling b ON b.koppeling_id=c.taxon_bronkoppeling_id WHERE '+context+'; ')
            for prefix,source in [('ndff_lmfa_','ndff_lmfa_doelsoort'),('ndff_zeereep_','ndff_zeereep_doelbereik')]:
                if table.startswith(prefix):
                    source_lookup += ('IF cq_n=0 THEN SELECT COUNT(DISTINCT b.taxon_id),MIN(b.taxon_id) INTO cq_n,cq_taxon '
                        "FROM taxa_bronkoppeling b WHERE b.bron_systeem='Meijendel' AND b.ingetrokken_op IS NULL "
                        'AND b.bron_dataset='+query_literal(source)+' AND BINARY b.bron_wetenschappelijke_naam=BINARY '+name+
                        " AND b.regelversie<>"+query_literal(QUERY_RULE)+" AND b.koppelstatus IN ('kandidaat','bevestigd'); END IF; ")
            if catalogue=='sovon_avimap_taxon':
                source_lookup += ("IF cq_n=0 AND BINARY "+name+"=BINARY 'Ondatra zibethicus' THEN "
                    'SELECT COUNT(DISTINCT b.taxon_id),MIN(b.taxon_id) INTO cq_n,cq_taxon FROM ndff_soorten c '
                    'JOIN taxa_bronkoppeling b ON b.koppeling_id=c.taxon_bronkoppeling_id '
                    "WHERE BINARY c.wetenschappelijke_naam=BINARY 'Ondatra zibethicus'; END IF; ")
            metadata=('JSON_OBJECT(\'bronvelden\',JSON_OBJECT('+','.join(query_literal(f)+',NEW.'+query_identifier(f)
                for f in [route['version_field'],route['name_field'],*route['context_fields']])+
                "),'interpretatie','nominale route uit centraal gekoppelde broncatalogus; geen conceptgelijkheid')")
            body = (f'IF {name} IS NOT NULL THEN '
                f'SELECT COUNT(*),MIN(b.koppeling_id) INTO cq_n,cq_id FROM taxa_bronkoppeling b WHERE {conditions}; '
                'IF cq_n=0 THEN '+source_lookup+
                "IF cq_n<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Afgeleide soort eerst centraal beoordelen'; END IF; "
                'INSERT INTO taxa_bronkoppeling(bron_systeem,bron_dataset,bron_versie,bron_taxon_id,bron_sleuteltype,'
                'bron_wetenschappelijke_naam,bronmetadata,taxon_id,koppelstatus,taxonrelatie,koppelmethode,regelversie,onderbouwing) '
                "VALUES('Meijendel',"+query_literal(table)+','+version+','+key+",'afgeleid',"+name+','+metadata+
                ",cq_taxon,'kandidaat','onbekend','brongetrouwe_afgeleide_meettaxonroute',"+query_literal(QUERY_RULE)+
                ",'Versiegebonden nominale broncatalogusroute; geen bevestigde conceptgelijkheid'); "
                'SET cq_id=LAST_INSERT_ID(); SET cq_n=1; END IF; '
                "IF cq_n<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Ambigue afgeleide bronidentiteit'; END IF; "
                'IF NEW.taxon_bronkoppeling_id IS NULL THEN SET NEW.taxon_bronkoppeling_id=cq_id; END IF; '
                "IF NEW.taxon_bronkoppeling_id<>cq_id THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Afgeleide broncontext past niet'; END IF; "+
                validity+' ELSE IF NEW.taxon_bronkoppeling_id IS NOT NULL THEN '
                "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Geen doelsoort maar wel taxonkoppeling'; END IF; END IF;")
        elif kind == 'external':
            event_table = route.get('event_table','externe_ecologie_event')
            dataset_table = route.get('dataset_table','externe_ecologie_dataset')
            query_identifier(event_table); query_identifier(dataset_table)
            declarations += ' DECLARE cq_dataset VARCHAR(255); DECLARE cq_version VARCHAR(255); DECLARE cq_context BINARY(32);'
            fields = {f:f"JSON_EXTRACT(NEW.bronmetadata,'$.{f}')" for f in SOURCE_TAXON_FIELDS}
            fields.update(dataset='cq_dataset',name='NEW.wetenschappelijke_naam',raw_name='NEW.wetenschappelijke_naam_bron',
                          nl='NEW.nederlandse_naam',rank='NEW.taxonrang')
            context='JSON_OBJECT('+','.join(query_literal(f)+','+fields[f] for f in SOURCE_USAGE_FIELDS)+')'
            conditions = ("b.bron_context_sha256=cq_context AND b.bron_systeem='Meijendel' "
                'AND BINARY b.bron_dataset=BINARY cq_dataset AND BINARY b.bron_versie=BINARY cq_version '
                "AND b.ingetrokken_op IS NULL AND b.taxon_id IS NOT NULL AND b.koppelstatus IN ('kandidaat','bevestigd')")
            body = ('SELECT d.dataset_sleutel,CONCAT(d.bronversie,\'; sha256:\',d.bronbestand_sha256) INTO cq_dataset,cq_version '
                f'FROM {event_table} e JOIN {dataset_table} d ON d.dataset_id=e.dataset_id WHERE e.event_id=NEW.event_id; '
                'SET cq_context=UNHEX(SHA2(CAST('+context+' AS CHAR CHARACTER SET utf8mb4),256)); '
                f'SELECT COUNT(*),MIN(b.koppeling_id) INTO cq_n,cq_id FROM taxa_bronkoppeling b WHERE {conditions}; '
                "IF cq_n<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Externe bron eerst centraal registreren'; END IF; "
                'IF NEW.taxon_bronkoppeling_id IS NULL THEN SET NEW.taxon_bronkoppeling_id=cq_id; END IF; '
                "IF NEW.taxon_bronkoppeling_id<>cq_id THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Externe taxonbroncontext past niet'; END IF; "+validity)
        else:
            condition=central_source_condition(table,route,'NEW')
            body=("IF NOT EXISTS(SELECT 1 FROM taxa_bronkoppeling b WHERE b.koppeling_id=NEW.taxon_bronkoppeling_id AND "+
                  condition+") THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Taxonkoppeling past niet bij bronwaarneming'; END IF; "+validity)
        for suffix,event in [('bi','INSERT'),('bu','UPDATE')]:
            trigger=central_trigger_name(table,suffix)
            statements += [f'DROP TRIGGER IF EXISTS {trigger}$$',
                f'CREATE TRIGGER {trigger} BEFORE {event} ON {query_identifier(table)} FOR EACH ROW BEGIN\n'
                +declarations+'\n'+body+'\nEND$$']
    # Registry edits must not make any pinned measurement lose its target or origin.
    references = ' OR '.join(f'EXISTS(SELECT 1 FROM {query_identifier(table)} WHERE taxon_bronkoppeling_id=OLD.koppeling_id)'
        for table,r in routes.items() if r['kind'] in {'catalogue','derived','direct','external'})
    source_fields = ('soort_key','ndff_soort_id','soortgroep_raw','wetenschappelijke_naam','nederlandse_naam',
                     'id','latijnse_naam','soort_naam','euring_code','engelse_naam','duitse_naam','franse_naam','spaanse_naam',
                     'batch_id','soortgroep_code','soortnr','soortgroep_naam','bronvelden','taxon_id','srtnum',
                     'scientific_name','kingdom','phylum','class_name','order_name','family','taxon_rank')
    preserved = ' OR '.join("NOT (JSON_EXTRACT(NEW.bronmetadata,'$."+f+"') <=> JSON_EXTRACT(OLD.bronmetadata,'$."+f+"'))"
                            for f in source_fields)
    guard = ("IF ("+references+") AND (NEW.taxon_id IS NULL OR NEW.koppelstatus NOT IN ('kandidaat','bevestigd') OR "
        'NOT (NEW.bron_systeem<=>OLD.bron_systeem) OR NOT (NEW.bron_dataset<=>OLD.bron_dataset) OR '
        'NOT (NEW.bron_versie<=>OLD.bron_versie) OR NOT (NEW.bron_taxon_id<=>OLD.bron_taxon_id) OR '
        'NOT (NEW.bron_wetenschappelijke_naam<=>OLD.bron_wetenschappelijke_naam) OR '
        'NOT ('+query_context_sql('NEW.bronmetadata')+' <=> '+query_context_sql('OLD.bronmetadata')+') OR '+preserved+') THEN '
        "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Gebruikte taxonbroncontext moet behouden blijven'; END IF;")
    statements += ['DROP TRIGGER IF EXISTS cq_registry_bu$$',
        'CREATE TRIGGER cq_registry_bu BEFORE UPDATE ON taxa_bronkoppeling FOR EACH ROW BEGIN '+guard+' END$$',
        ]
    children = ' OR '.join('EXISTS(SELECT 1 FROM '+query_identifier(table)+' w WHERE '+
        route['join'].replace('o.waarneming_id','OLD.waarneming_id')+')'
        for table,route in routes.items() if route['kind']=='ndff_child')
    for suffix,event in [('bd','DELETE'),('bu','UPDATE')]:
        condition = '('+children+')'
        if event=='UPDATE': condition = 'NOT (NEW.waarneming_id<=>OLD.waarneming_id) AND '+condition
        statements += [f'DROP TRIGGER IF EXISTS cq_ndff_parent_{suffix}$$',
            f'CREATE TRIGGER cq_ndff_parent_{suffix} BEFORE {event} ON ndff_open_waarneming FOR EACH ROW BEGIN '
            'IF '+condition+" THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Verwijder eerst afgeleide NDFF-verwijzingen'; END IF; END$$"]
    for table,field,child in [('externe_ecologie_event','dataset_id','externe_ecologie_resultaat'),
                              ('pq_vegetatie_bronopname','dataset_id','pq_vegetatie_bronresultaat')]:
        name=central_trigger_name(table,'bu')
        statements += [f'DROP TRIGGER IF EXISTS {name}$$',f'CREATE TRIGGER {name} BEFORE UPDATE ON {table} FOR EACH ROW BEGIN '
            f'IF NOT (NEW.{field}<=>OLD.{field}) AND EXISTS(SELECT 1 FROM {child} WHERE event_id=OLD.event_id) THEN '
            "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Waargenomen bronopname kan niet van dataset wisselen'; END IF; END$$"]
    name=central_trigger_name('externe_ecologie_dataset','bu')
    statements += [f'DROP TRIGGER IF EXISTS {name}$$',f'CREATE TRIGGER {name} BEFORE UPDATE ON externe_ecologie_dataset FOR EACH ROW BEGIN '
        'IF (NOT (NEW.dataset_sleutel<=>OLD.dataset_sleutel) OR NOT (NEW.bronversie<=>OLD.bronversie) OR '
        'NOT (NEW.bronbestand_sha256<=>OLD.bronbestand_sha256)) AND ('
        'EXISTS(SELECT 1 FROM externe_ecologie_event e JOIN externe_ecologie_resultaat r ON r.event_id=e.event_id WHERE e.dataset_id=OLD.dataset_id) OR '
        'EXISTS(SELECT 1 FROM pq_vegetatie_bronopname e JOIN pq_vegetatie_bronresultaat r ON r.event_id=e.event_id WHERE e.dataset_id=OLD.dataset_id)) THEN '
        "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Gebruikte bronversie mag niet worden overschreven'; END IF; END$$"]
    for source_key,prefix in SOURCE_FAMILIES.items():
        if prefix+'_resultaat' not in routes: continue
        event_table, dataset_table, result_table = (prefix+'_'+s for s in ('event','dataset','resultaat'))
        source_guard = 'IF NOT (BINARY NEW.dataset_sleutel<=>BINARY '+query_literal(source_key)+') THEN '+\
            "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Dataset past niet bij deze bronfamilie'; END IF; "
        name = central_trigger_name(dataset_table,'bi')
        statements += [f'DROP TRIGGER IF EXISTS {name}$$',
            f'CREATE TRIGGER {name} BEFORE INSERT ON {dataset_table} FOR EACH ROW BEGIN {source_guard} END$$']
        for table, body in [
            (event_table, f'IF NOT (NEW.dataset_id<=>OLD.dataset_id) AND EXISTS(SELECT 1 FROM {result_table} WHERE event_id=OLD.event_id) THEN '
             "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Waargenomen bronopname kan niet van dataset wisselen'; END IF;"),
            (dataset_table, source_guard+'IF (NOT (NEW.dataset_sleutel<=>OLD.dataset_sleutel) OR NOT (NEW.bronversie<=>OLD.bronversie) OR '
             f'NOT (NEW.bronbestand_sha256<=>OLD.bronbestand_sha256)) AND EXISTS(SELECT 1 FROM {event_table} e '
             'WHERE e.dataset_id=OLD.dataset_id) THEN '
             "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Gebruikte bronversie mag niet worden overschreven'; END IF;")]:
            name = central_trigger_name(table,'bu')
            statements += [f'DROP TRIGGER IF EXISTS {name}$$', f'CREATE TRIGGER {name} BEFORE UPDATE ON {table} FOR EACH ROW BEGIN {body} END$$']
    statements.append('DELIMITER ;')
    return '\n'.join(statements)


def central_constraint_projection(row: dict) -> dict:
    """MySQL ALTER retypes this ASCII-only regex literal, not its meaning.

    Limit equivalence to the existing hash CHECK and its two exact literals;
    do not normalize arbitrary taxonomy checks, collations or expressions.
    """
    row = dict(row)
    if row['name']=='ck_taxa_bron_hash' and row['table']=='taxa_bronkoppeling':
        row['clause'] = row['clause'].replace("_ascii\\'^[0-9a-f]{64}$\\'", "_utf8mb4\\'^[0-9a-f]{64}$\\'")
    return row


def central_query_original_snapshot(db: CentralQueryDatabase, plan: dict) -> dict:
    """Every old cell, including metadata, zeros, provenance and analysis flags.

    A 256-bit per-row digest is reduced as four independent 64-bit XORs plus
    row count. Unchanged tables use MySQL's native full-table checksum. New
    register rows are excluded by the original maximum IDs, never by names.
    """
    affected = {'taxa','taxa_bronkoppeling','externe_ecologie_resultaat',*plan['catalogues'],*plan['derived']}
    types = {(t,c):kind for t,c,kind in (line.split('\t') for line in db.sql(
        'SELECT TABLE_NAME,COLUMN_NAME,DATA_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE();').splitlines())}
    result = {}
    for table, columns in plan['schema'].items():
        qtable = query_identifier(table)
        if table not in affected:
            result[table] = db.sql('CHECKSUM TABLE '+qtable+';').split('\t')[-1]
            continue
        fields = []
        for column in columns:
            value = query_identifier(column)
            if types[table,column] in {'binary','varbinary','blob','tinyblob','mediumblob','longblob','bit'}:
                value = 'HEX('+value+')'
            elif types[table,column] in {'geometry','point','polygon','multipolygon','linestring','multilinestring','multipoint','geometrycollection'}:
                value = 'HEX(ST_AsWKB('+value+'))'
            fields += [query_literal(column),value]
        scope = ''
        if table in plan['original_max_ids']:
            field = 'taxon_id' if table=='taxa' else 'koppeling_id'
            scope = f' WHERE {field}<={plan["original_max_ids"][table]}'
        aggregations = ','.join(f'BIT_XOR(CAST(CONV(SUBSTRING(h,{i},16),16,10) AS UNSIGNED))' for i in (1,17,33,49))
        result[table] = db.sql('SELECT COUNT(*),'+aggregations+' FROM (SELECT SHA2(CAST(JSON_OBJECT('+','.join(fields)+
            ') AS CHAR CHARACTER SET utf8mb4),256) h FROM '+qtable+scope+') original_cells;')
    def normalize(value):
        return value.replace('`'+db.database.lower()+'`','`meijendel`').replace('`'+db.database+'`','`meijendel`')
    views = db.sql("SELECT TABLE_NAME,VIEW_DEFINITION FROM information_schema.VIEWS WHERE TABLE_SCHEMA=DATABASE() ORDER BY TABLE_NAME;")
    result['__views'] = hashlib.sha256(normalize(views).encode()).hexdigest()
    # Original types, nullability, defaults, generated expressions, indexes and
    # constraints are independent of row equality and must survive too.
    definitions = db.objects("SELECT JSON_OBJECT('table',TABLE_NAME,'column',COLUMN_NAME,'type',COLUMN_TYPE,"
        "'nullable',IS_NULLABLE,'default',COLUMN_DEFAULT,'extra',EXTRA,'generated',GENERATION_EXPRESSION,"
        "'collation',COLLATION_NAME,'comment',COLUMN_COMMENT) FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=DATABASE() ORDER BY TABLE_NAME,ORDINAL_POSITION;")
    originals = []
    for row in definitions:
        if row['table'] not in plan['schema']:
            # Derived view nullability is re-inferred by MySQL on restore; it
            # differs even when the view SQL, output and all base columns match.
            row={**row,'nullable':'derived-view'}
        elif row['column'] not in plan['schema'][row['table']]: continue
        originals.append(row)
    result['__columns'] = hashlib.sha256(normalize(json.dumps(originals,ensure_ascii=False,sort_keys=True)).encode()).hexdigest()
    indexes = db.objects("SELECT JSON_OBJECT('table',TABLE_NAME,'name',INDEX_NAME,'nonunique',NON_UNIQUE,"
        "'sequence',SEQ_IN_INDEX,'column',COLUMN_NAME,'subpart',SUB_PART,'type',INDEX_TYPE) FROM information_schema.STATISTICS "
        "WHERE TABLE_SCHEMA=DATABASE() ORDER BY TABLE_NAME,INDEX_NAME,SEQ_IN_INDEX;")
    result['__indexes'] = hashlib.sha256(json.dumps([r for r in indexes if r['column'] in plan['schema'][r['table']]],
                                        ensure_ascii=False,sort_keys=True).encode()).hexdigest()
    constraints = db.objects("SELECT JSON_OBJECT('name',t.CONSTRAINT_NAME,'type',t.CONSTRAINT_TYPE,"
        "'table',t.TABLE_NAME,'clause',c.CHECK_CLAUSE,'update',f.UPDATE_RULE,'delete',f.DELETE_RULE,"
        "'keys',(SELECT GROUP_CONCAT(CONCAT(k.COLUMN_NAME,':',COALESCE(k.REFERENCED_TABLE_NAME,''),':',"
        "COALESCE(k.REFERENCED_COLUMN_NAME,'')) ORDER BY k.ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE k "
        "WHERE k.CONSTRAINT_SCHEMA=t.CONSTRAINT_SCHEMA AND k.TABLE_NAME=t.TABLE_NAME AND k.CONSTRAINT_NAME=t.CONSTRAINT_NAME)) "
        "FROM information_schema.TABLE_CONSTRAINTS t "
        "LEFT JOIN information_schema.CHECK_CONSTRAINTS c ON c.CONSTRAINT_SCHEMA=t.CONSTRAINT_SCHEMA AND c.CONSTRAINT_NAME=t.CONSTRAINT_NAME "
        "LEFT JOIN information_schema.REFERENTIAL_CONSTRAINTS f ON f.CONSTRAINT_SCHEMA=t.CONSTRAINT_SCHEMA AND f.TABLE_NAME=t.TABLE_NAME AND f.CONSTRAINT_NAME=t.CONSTRAINT_NAME "
        "WHERE t.CONSTRAINT_SCHEMA=DATABASE() ORDER BY t.TABLE_NAME,t.CONSTRAINT_NAME;")
    result['__constraints'] = hashlib.sha256(json.dumps([central_constraint_projection(r) for r in constraints if r['name'] in plan['original_constraint_names']],
                                             ensure_ascii=False,sort_keys=True).encode()).hexdigest()
    # View results are checked, not merely their text. These are existing views,
    # not new query entry points; central queries remain plain SELECT statements.
    view_columns = defaultdict(list)
    for row in definitions:
        if row['table'] not in plan['schema']: view_columns[row['table']].append(row['column'])
    for table,columns in view_columns.items():
        fields=[]
        for c in columns:
            value=query_identifier(c)
            if types[table,c] in {'binary','varbinary','blob','tinyblob','mediumblob','longblob','bit'}: value='HEX('+value+')'
            elif types[table,c] in {'geometry','point','polygon','multipolygon','linestring','multilinestring','multipoint','geometrycollection'}: value='HEX(ST_AsWKB('+value+'))'
            fields += [query_literal(c),value]
        result['__view_'+table] = db.sql('SELECT COUNT(*),'+','.join(
            f'BIT_XOR(CAST(CONV(SUBSTRING(h,{i},16),16,10) AS UNSIGNED))' for i in (1,17,33,49))+
            ' FROM (SELECT SHA2(CAST(JSON_OBJECT('+','.join(fields)+') AS CHAR CHARACTER SET utf8mb4),256) h FROM '+
            query_identifier(table)+') view_rows;')
    return result


def central_query_gate(database='Meijendel', login_path='meijendel_root', client='/usr/local/mysql/bin/mysql',
                       host='127.0.0.1',port=3306) -> dict:
    result = central_query_audit(CentralQueryDatabase(database,login_path,client,host=host,port=port))
    if result['errors']:
        raise RuntimeError('Centrale taxonpoort blokkeert: '+'; '.join(result['errors']))
    return result


def central_query_guarded_operation(operation, *, enabled=True, database='Meijendel',
                                    login_path='meijendel_root',client='/usr/local/mysql/bin/mysql',
                                    host='127.0.0.1',port=3306):
    """Call after argument parsing, around the actual writer, also from Python."""
    if not enabled: return operation()
    central_query_gate(database,login_path,client,host,port)
    result = operation()
    central_query_gate(database,login_path,client,host,port)
    return result


def central_query_negative_tests(db: CentralQueryDatabase) -> None:
    """Only inside the restored proof schema; all probes roll back."""
    if not re.fullmatch('Meijendel_taxa_query_(?:proef|herstel)_[0-9]+',db.database):
        raise ValueError('Schrijfproeven uitsluitend in de geïsoleerde herstelproef')
    probes = [
        'UPDATE externe_ecologie_resultaat SET taxon_bronkoppeling_id=0 LIMIT 1',
        'UPDATE pq_vegetatie_waarneming SET taxon_bronkoppeling_id=0 LIMIT 1',
        'UPDATE vangblik_vangst SET taxon_bronkoppeling_id=0 LIMIT 1',
        'UPDATE ndff_lmfa_bezoek_taxon SET wetenschappelijke_naam=\'Niet geregistreerd taxon\' LIMIT 1',
        "UPDATE taxa_bronkoppeling SET bron_versie='onjuiste versie' WHERE koppeling_id="
        '(SELECT taxon_bronkoppeling_id FROM ndff_soorten LIMIT 1)',
        'UPDATE taxa_bronkoppeling SET taxon_id=NULL WHERE koppeling_id='
        '(SELECT taxon_bronkoppeling_id FROM ndff_soorten LIMIT 1)',
        "UPDATE taxa_bronkoppeling SET bronmetadata=JSON_SET(bronmetadata,'$.scientific_name','Onjuist taxon') WHERE koppeling_id="
        '(SELECT taxon_bronkoppeling_id FROM vangblik_vangst LIMIT 1)',
        "UPDATE ndff_vaatplanten SET waarneming_id=(SELECT MAX(waarneming_id)+1 FROM ndff_open_waarneming) LIMIT 1",
        'DELETE FROM ndff_open_waarneming WHERE waarneming_id=(SELECT waarneming_id FROM ndff_vaatplanten LIMIT 1)',
        'UPDATE ndff_open_waarneming SET waarneming_id=(SELECT id FROM (SELECT MAX(waarneming_id)+1 id FROM ndff_open_waarneming) x) '
        'WHERE waarneming_id=(SELECT waarneming_id FROM ndff_vaatplanten LIMIT 1)',
        "UPDATE externe_ecologie_dataset SET bronversie='ongeldige versie' WHERE dataset_id=2",
        'UPDATE externe_ecologie_event SET dataset_id=3 WHERE event_id='
        '(SELECT event_id FROM externe_ecologie_resultaat LIMIT 1)',
    ]
    for table in ('externe_ecologie_resultaat','pq_vegetatie_waarneming','pq_vegetatie_bronresultaat','vangblik_vangst'):
        probes.append('UPDATE '+table+' SET taxon_bronkoppeling_id=(SELECT MIN(koppeling_id) FROM taxa_bronkoppeling '
                      "WHERE bron_dataset='soorten' AND taxon_id IS NOT NULL AND ingetrokken_op IS NULL) LIMIT 1")
    for probe in probes:
        try: db.sql('START TRANSACTION; '+probe+'; ROLLBACK;',write=True)
        except RuntimeError as exc:
            if "45000" not in str(exc): raise
        else: raise RuntimeError('Ongeldige invoer werd niet geblokkeerd: '+probe.split(' SET ')[0])
    for table in ('externe_ecologie_resultaat','ndff_lmfa_bezoek_taxon','ndff_soorten','soorten',
                  'sovon_avimap_taxon','pq_vegetatie_waarneming','vangblik_vangst'):
        db.sql('START TRANSACTION; UPDATE '+query_identifier(table)+
               ' SET taxon_bronkoppeling_id=taxon_bronkoppeling_id LIMIT 1; ROLLBACK;',write=True)
    # Missing group never makes the original observation disappear.
    original = db.sql('SELECT COUNT(*) FROM externe_ecologie_resultaat r JOIN taxa_bronkoppeling b '
                     'ON b.koppeling_id=r.taxon_bronkoppeling_id JOIN taxa t ON t.taxon_id=b.taxon_id WHERE t.groep_id IS NULL;')
    joined = db.sql('SELECT COUNT(*) FROM taxa t LEFT JOIN taxon_groepen g ON g.groep_id=t.groep_id '
                   'JOIN taxa_bronkoppeling b ON b.taxon_id=t.taxon_id JOIN externe_ecologie_resultaat r '
                   'ON r.taxon_bronkoppeling_id=b.koppeling_id WHERE t.groep_id IS NULL;')
    if original!=joined: raise RuntimeError('Niet ingedeelde taxa verdwijnen uit query')


def execute_central_query_migration(args) -> int:
    """Proof schema only first; live requires exact unchanged backup/plan/code proof."""
    root = args.centrale_bewijs_dir
    if root is None: raise ValueError('--centrale-bewijs-dir is vereist')
    if args.database != 'Meijendel' and not re.fullmatch('Meijendel_taxa_query_(?:proef|herstel)_[0-9]+',args.database):
        raise ValueError('Alleen de canonieke database of een gerichte herstelproef')
    db = CentralQueryDatabase(args.database,args.login_path,args.mysql_client,host=args.host,port=args.port,writable=args.apply)
    if args.apply and args.centrale_backup is None: raise ValueError('Volledige back-up is vereist')
    backup_hash=None
    if args.centrale_backup:
        digest=hashlib.sha256()
        with args.centrale_backup.open('rb') as f:
            while chunk:=f.read(1024*1024): digest.update(chunk)
        backup_hash=digest.hexdigest()
    resume = args.centrale_hervat_proef
    if resume and (args.database=='Meijendel' or not args.apply or not root.is_dir()):
        raise ValueError('Hervatten uitsluitend van de bestaande geïsoleerde, nog niet vastgelegde proef')
    original = CentralQueryDatabase('Meijendel',args.login_path,args.mysql_client,host=args.host,port=args.port) if resume else db
    plan = central_query_plan(original)
    snapshot = central_query_original_snapshot(original,plan)
    if resume:
        if json.loads((root/'plan.json').read_text())!=plan or (root/'result.json').exists() or (root/'rollback.json').exists():
            raise ValueError('Hervatting heeft geen identiek oorspronkelijk plan of is al vastgelegd')
        previous=json.loads((root/'before.json').read_text())
        # The sole first-proof discrepancy was MySQL's ASCII regex introducer.
        # Retain that original evidence; the stricter new constraint projection
        # is computed afresh against the untouched canonical database.
        if any(previous[k]!=snapshot[k] for k in previous if k not in {'__constraints','__columns'}):
            raise ValueError('Oorspronkelijke gegevens of schema veranderd sinds de onderbroken proef')
        if central_query_original_snapshot(db,plan)!=snapshot:
            raise ValueError('De onderbroken proef wijkt af van de volledige oorspronkelijke database')
        if db.sql('SELECT COUNT(*) FROM taxa_bronkoppeling WHERE regelversie='+query_literal(QUERY_RULE)+';')!='0':
            raise ValueError('De onderbroken proef heeft al centrale gegevens vastgelegd')
    code_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    plan_hash = hashlib.sha256(json.dumps(plan,sort_keys=True,ensure_ascii=False).encode()).hexdigest()
    def save(name,value):
        with (root/name).open('x',encoding='utf-8') as f: json.dump(value,f,ensure_ascii=False,indent=2)
    if args.apply and args.database=='Meijendel':
        if args.centrale_proefbewijs is None: raise ValueError('Live wijziging vereist een passende herstel- en terugdraaiproef')
        proof = json.loads(args.centrale_proefbewijs.read_text())
        if (proof.get('status')!='verified' or proof.get('snapshot')!=snapshot or proof.get('code_sha256')!=code_hash
                or proof.get('plan_sha256')!=plan_hash or not proof.get('rollback_verified') or not proof.get('negative_tests_verified')
                or proof.get('backup_sha256')!=backup_hash or not proof.get('backup_restore_verified') or not proof.get('schema_restore_verified')):
            raise ValueError('Proefbewijs past niet bij de volledige actuele database, code of bronkoppelingen')
    if resume:
        save('resumed-before.json',snapshot)
    else:
        root.mkdir(parents=True,exist_ok=False)
        save('plan.json',plan); save('before.json',snapshot)
    if not args.apply:
        print('READ-ONLY: volledige bronkoppelingen en schema geïnventariseerd'); return 0
    if not resume: db.sql(central_query_schema_sql(plan),write=True)
    db.sql(central_query_migration_sql(plan),write=True)
    if central_query_original_snapshot(db,plan)!=snapshot:
        raise RuntimeError('Terugdraaiproef heeft oorspronkelijke cellen gewijzigd')
    if db.sql('SELECT COUNT(*) FROM taxa_bronkoppeling WHERE regelversie='+query_literal(QUERY_RULE)+';')!='0':
        raise RuntimeError('Terugdraaiproef liet centrale bronkoppelingen achter')
    save('rollback.json',{'status':'verified'})
    db.sql(central_query_migration_sql(plan,commit=True),write=True)
    db.sql(central_query_schema_sql(plan,finalize=True),write=True)
    db.sql(central_query_triggers_sql(plan),write=True)
    result = central_query_audit(db)
    if result['errors']: raise RuntimeError('; '.join(result['errors']))
    if central_query_original_snapshot(db,plan)!=snapshot:
        raise RuntimeError('Oorspronkelijke waarnemingen, bronwaarden of analyses gewijzigd')
    if args.database!='Meijendel':
        central_query_negative_tests(db)
        if central_query_original_snapshot(db,plan)!=snapshot:
            raise RuntimeError('Negatieve schrijfproeven hebben oorspronkelijke gegevens veranderd')
        recovery=args.centrale_herstel_database
        if not recovery or not re.fullmatch('Meijendel_taxa_query_herstel_[0-9]+',recovery):
            raise ValueError('Afzonderlijke volledige schemaherstelproef is vereist')
        restored=CentralQueryDatabase(recovery,args.login_path,args.mysql_client,host=args.host,port=args.port,writable=True)
        # Never replace an existing schema. This exact recovery target must be absent.
        db.sql('CREATE DATABASE '+query_identifier(recovery)+' CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;',write=True)
        process=subprocess.Popen(restored.args,stdin=subprocess.PIPE,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        try:
            with gzip.open(args.centrale_backup,'rb') as source:
                for line in source:
                    if line.startswith(b'/*!50001 VIEW'):
                        line=line.replace(b'`meijendel`.',('`'+recovery.lower()+'`.').encode()).replace(b'`Meijendel`.',('`'+recovery+'`.').encode())
                    process.stdin.write(line)
            process.stdin.close(); error=process.stderr.read(); status=process.wait()
        except BaseException:
            process.kill(); process.wait(); raise
        if status: raise RuntimeError(error.decode())
        if central_query_original_snapshot(restored,plan)!=snapshot:
            raise RuntimeError('Volledig herstel wijkt af op gegevens, schema of bestaande viewuitkomsten')
    result.update(snapshot=snapshot,rollback_verified=True,code_sha256=code_hash,plan_sha256=plan_hash,
                  negative_tests_verified=True,backup_sha256=backup_hash,backup_restore_verified=True,schema_restore_verified=True)
    save('result.json',result)
    print('OK: alle geïnventariseerde soortwaarnemingen centraal bereikbaar; bewijs:',root)
    return 0

# Approved on 29 September 2026; presentation only, never taxon identity.
DISPLAY_NAMES = {
    471: ('Acanthis flammea', 'Barmsijs', 1, 'Barmsijs — Grote of Kleine niet onderscheiden'),
    472: ('Acanthis flammea', 'Grote Barmsijs', 1, 'Grote barmsijs'),
    284: ('Branta canadensis', 'Kleine Canadese Gans', 1, 'Kleine Canadese gans'),
    285: ('Branta canadensis', 'Grote Canadese Gans', 1, 'Grote Canadese gans'),
    30322: ('Elachista', 'Elachista', 9, 'Elachista — algengeslacht'),
    30633: ('Elachista', 'Elachista', 12, 'Elachista — microvlindergeslacht'),
    33906: ('Psathyrella corrugis', 'Sierlijke franjehoed', 17, 'Sierlijke franjehoed'),
    33907: ('Psathyrella corrugis', 'Sierlijke franjehoed sl, incl. Kortwortelfranjehoed', 17,
            'Sierlijke franjehoed — inclusief Kortwortelfranjehoed'),
    34312: ('Psathyrella piluliformis', 'Witsteelfranjehoed', 17, 'Witsteelfranjehoed'),
    34313: ('Psathyrella piluliformis', 'Witsteelfranjehoed sl, incl. Zoetgeurende witsteelfranjehoed', 17,
            'Witsteelfranjehoed — inclusief Zoetgeurende witsteelfranjehoed'),
    35436: ('Dactylorhiza majalis', 'Brede orchis', 21, 'Brede orchis'),
    42297: ('Dactylorhiza majalis', 'Brede orchis en Rietorchis', 21,
            'Brede orchis / Rietorchis — niet onderscheiden'),
    39058: ('Lepidoptera', 'Dagvlinder', None, 'Dagvlinder — niet nader bepaald'),
    41317: ('Lepidoptera', None, None, 'Vlinder — dag- of nachtvlinder niet onderscheiden'),
}


def display_name_key(value: str) -> str:
    """Conservative precheck; MySQL's unique index remains authoritative."""
    return ''.join(c for c in unicodedata.normalize('NFKD', value.casefold())
                   if not unicodedata.combining(c))


def display_name_base(taxon: dict) -> str:
    dutch = ' '.join((taxon.get('nederlandse_naam') or '').split())
    label = dutch or ' '.join((taxon.get('wetenschappelijke_naam') or '').split())
    # Two source names contain Windows-1252 quotes decoded as C1 controls.
    # Repair only their presentation; the original source field stays intact.
    return label.replace('\x93', '“').replace('\x94', '”')


def checked_display_name(value: str) -> str:
    if (not isinstance(value, str) or not value.strip() or value != ' '.join(value.split())
            or len(value) > 700 or any(unicodedata.category(c).startswith('C') for c in value)):
        raise ValueError('Weergavenaam moet gevuld, opgeschoond en maximaal 700 tekens zijn')
    return value


def taxon_display_names(taxa: list[dict]) -> dict[int, str]:
    """Fill all labels without changing source fields or merging any rows."""
    labels = {}
    for row in taxa:
        key = row['taxon_id']
        if key in labels:
            raise ValueError('Dubbele taxon-ID in weergavenaamplan')
        label = row.get('weergavenaam')
        if not label and key in DISPLAY_NAMES:
            latin, dutch, group, label = DISPLAY_NAMES[key]
            if (row.get('wetenschappelijke_naam'), row.get('nederlandse_naam'), row.get('groep_id')) != (latin, dutch, group):
                raise ValueError('Beoordeelde naamcontext gewijzigd; eerst opnieuw beoordelen')
        labels[key] = checked_display_name(label or display_name_base(row))
    buckets = defaultdict(list)
    for key, label in labels.items():
        buckets[display_name_key(label)].append(key)
    collisions = {i for ids in buckets.values() if len(ids) > 1 for i in ids}
    for row in taxa:
        key = row['taxon_id']
        if key in collisions:
            if row.get('weergavenaam') or key in DISPLAY_NAMES:
                raise ValueError('Bestaande of beoordeelde weergavenaam botst; niet automatisch hernoemen')
            latin = display_name_base({'wetenschappelijke_naam': row['wetenschappelijke_naam']})
            labels[key] = checked_display_name(labels[key] + ' — ' + latin)
    if len({display_name_key(v) for v in labels.values()}) != len(labels):
        raise ValueError('Naamconflict vereist inhoudelijke verduidelijking; geen nummers toevoegen')
    return labels


def prepare_taxon_display_name(taxon: dict, taxa: list[dict]) -> str:
    """New import label; existing labels are never silently renamed."""
    labels = [checked_display_name(t['weergavenaam']) for t in taxa]
    label = taxon.get('weergavenaam')
    if label is None:
        label = display_name_base(taxon)
        same_base = any(display_name_key(display_name_base(t)) == display_name_key(label) for t in taxa)
        if same_base or display_name_key(label) in {display_name_key(v) for v in labels}:
            label += ' — ' + display_name_base({'wetenschappelijke_naam': taxon.get('wetenschappelijke_naam')})
    label = checked_display_name(label)
    if display_name_key(label) in {display_name_key(v) for v in labels}:
        raise ValueError('Weergavenaam bestaat al; inhoudelijk beoordelen vóór import')
    return label


def prepare_registry_import(source: dict, taxon: dict, taxa: list[dict], links: list[dict],
                            *, name_evidence: dict | None = None) -> dict:
    """Prepare identity AND label. A new row still requires a source review.

    Use in the same locked transaction as the eventual insert; NOT NULL,
    CHECK and UNIQUE in MySQL guard missing labels and concurrent collisions.
    A display label is never evidence of taxonomic identity.
    """
    resolved = resolve_registry_import(source, taxon, taxa, links, name_evidence=name_evidence)
    if resolved is not None:
        row = next(t for t in taxa if t['taxon_id'] == resolved['taxon_id'])
        return {**resolved, 'weergavenaam': checked_display_name(row['weergavenaam']), 'nieuw_taxon': None}
    new = copy.deepcopy(taxon)
    new['weergavenaam'] = prepare_taxon_display_name(taxon, taxa)
    return {'taxon_id': None, 'koppeling_id': None, 'nieuw_taxon': new}


def display_name_migration_sql(snapshot: dict, labels: dict[int, str], *, commit: bool = False) -> str:
    """DML only; nullable column is added beforehand, constraints afterwards.

    Snapshot expressions deliberately include every OLD cell, not the new
    column. This proves no name, identity, timestamp or source link changed.
    """
    if set(labels) != {t['taxon_id'] for t in snapshot['taxa']['rows']}:
        raise ValueError('Weergavenaamplan dekt niet exact alle taxa')
    if len({display_name_key(checked_display_name(v)) for v in labels.values()}) != len(labels):
        raise ValueError('Dubbele weergavenamen in migratieplan')
    literal = lambda value: "CONVERT(X'" + value.encode().hex() + "' USING utf8mb4)"
    sql = ['SET NAMES utf8mb4;', 'SET SESSION group_concat_max_len=16777216;',
           'SET SESSION innodb_lock_wait_timeout=10;',
           'CREATE TEMPORARY TABLE display_guard(ok INT NOT NULL CHECK(ok=1));',
           'CREATE TEMPORARY TABLE display_plan(id BIGINT UNSIGNED PRIMARY KEY,naam VARCHAR(700) NOT NULL UNIQUE) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;',
           'INSERT INTO display_plan VALUES ' + ','.join(f'({int(i)},{literal(v)})' for i,v in sorted(labels.items())) + ';',
           'START TRANSACTION;', 'SELECT taxon_id FROM taxa ORDER BY taxon_id FOR UPDATE;',
           'SELECT koppeling_id FROM taxa_bronkoppeling ORDER BY koppeling_id FOR UPDATE;']
    guards = [f"INSERT INTO display_guard SELECT SHA2(GROUP_CONCAT(SHA2(CAST({s['expression']} AS CHAR),256) ORDER BY `{s['pk']}` SEPARATOR ''),256)='{s['sha256']}' FROM `{table}`;"
              for table,s in snapshot.items()]
    sql += guards
    sql += ['INSERT INTO display_guard SELECT COUNT(*)=0 FROM taxa WHERE weergavenaam IS NOT NULL;',
            'UPDATE taxa t JOIN display_plan p ON p.id=t.taxon_id SET t.weergavenaam=p.naam,t.gewijzigd_op=t.gewijzigd_op;',
            'INSERT INTO display_guard SELECT COUNT(*)=0 FROM taxa t LEFT JOIN display_plan p ON p.id=t.taxon_id WHERE p.id IS NULL OR NOT(BINARY t.weergavenaam<=>BINARY p.naam);']
    sql += guards
    sql += ['COMMIT;' if commit else 'ROLLBACK;']
    return '\n'.join(sql)


def display_name_schema_sql(*, finalize: bool = False) -> str:
    if not finalize:
        return "SET SESSION lock_wait_timeout=10; ALTER TABLE taxa ADD COLUMN weergavenaam VARCHAR(700) NULL COMMENT 'Unieke lokale presentatienaam; geen taxonidentiteit of wetenschappelijke naam' AFTER nederlandse_naam;"
    return """SET SESSION lock_wait_timeout=10;
ALTER TABLE taxa MODIFY COLUMN weergavenaam VARCHAR(700) NOT NULL
  COMMENT 'Unieke lokale presentatienaam; geen taxonidentiteit of wetenschappelijke naam',
  ADD UNIQUE KEY uq_taxa_weergavenaam (weergavenaam),
  ADD CONSTRAINT ck_taxa_weergavenaam CHECK (
    REGEXP_LIKE(weergavenaam,'[^[:space:]]') AND NOT REGEXP_LIKE(weergavenaam,'[[:cntrl:]]')
    AND BINARY weergavenaam=BINARY TRIM(weergavenaam));"""


def central_name(row: dict) -> str:
    """Conservatieve naamnormalisatie; geen fuzzy match of synoniemenresolver."""
    name = row.get('naam_zonder_auteur') or row['wetenschappelijke_naam']
    name = re.sub(r'\s+', ' ', name.replace('ssp.', 'subsp.')).strip()
    author = re.sub(r'\s+', ' ', row.get('naam_auteur') or '').strip()
    if not row.get('naam_zonder_auteur') and author and name.endswith(' ' + author):
        name = name[:-len(author)].strip()
    return name


def central_conflicts(rows: list[dict], links: list[dict]) -> list[str]:
    """Nominaal taxon is niet hetzelfde als congruent historisch bronconcept."""
    conflicts = []
    for field in ('groep_id', 'taxonvorm', 'taxonrang', 'rijk', 'stam', 'klasse',
                  'orde', 'familie', 'nomenclatuurcode'):
        values = {r.get(field) for r in rows if r.get(field) not in (None, '')}
        if field == 'familie':
            values = {re.sub(r'^(?:Musci_|Hepat\._)', '', v) for v in values}
        if field in {'stam','klasse','orde','familie'}:
            values = {re.sub(r'^(?:Fungi_|Lichenes_)', '', v) for v in values}
        if len(values) > 1:
            conflicts.append(field)
    if any(r.get('groep_id') is None for r in rows):
        conflicts.append('groepscontext_ontbreekt')
    if any(r.get('taxonvorm') != 'taxon' for r in rows):
        conflicts.append('geen_enkelvoudig_taxon')
    authors = set()
    for row in rows:
        author = re.sub(r'\s+', ' ', (row.get('naam_auteur') or '').replace('ssp.', 'subsp.')).strip()
        name = central_name(row)
        if author.startswith(name + ' '):
            author = author[len(name):].strip()
        if author.startswith('species '):
            author = author[8:]
        if author:
            authors.add(re.sub(r'[\s.,]+', '', author).casefold())
    if len(authors) > 1:
        conflicts.append('auteurschap')
    scope = re.compile(r'\b(?:sensu|auct|non|incl|complex|indet)\b|\b(?:cf|aff|agg|spec)\.|\bs\.?\s*[ls]\b|[/+]', re.I)
    ids = {r['taxon_id'] for r in rows if r.get('taxon_id') is not None}
    for row in rows:
        text = ' '.join(str(row.get(f) or '') for f in
                        ('wetenschappelijke_naam','nederlandse_naam','opmerkingen'))
        if scope.search(text) or (row.get('taxonmetadata') or {}).get('vormsignalen'):
            conflicts.append('bronafbakening')
    for link in links:
        if link.get('taxon_id') not in ids:
            continue
        meta = link.get('bronmetadata') or {}
        text = ' '.join(str(meta.get(f) or '') for f in
                        ('raw_name','taxonRemarks','scientificName','nameAccordingTo'))
        text += ' ' + ' '.join(str(link.get(f) or '') for f in
                              ('bron_wetenschappelijke_naam','bron_naam_volgens'))
        if scope.search(text):
            conflicts.append('bronafbakening')
    return sorted(set(conflicts))


def plan_central_taxa(taxa: list[dict], links: list[dict]) -> dict:
    """Gelijke nominale taxa; afwijkende context blijft expliciet uitgesloten.

    Geen keuze uit een deelgroep wanneer een lege auteur een homoniem zou
    kunnen overbruggen. Alle broncontexten blijven bij uitvoering bewaard.
    """
    names = defaultdict(list)
    by_taxon = defaultdict(list)
    for row in taxa:
        names[central_name(row)].append(row)
    for link in links:
        by_taxon[link.get('taxon_id')].append(link)
    result = {'groups': [], 'excluded': []}
    for name, rows in sorted(names.items()):
        if len(rows) < 2:
            continue
        rows = sorted(rows, key=lambda r: r['taxon_id'])
        group_links = [b for r in rows for b in by_taxon[r['taxon_id']]]
        conflicts = central_conflicts(rows, group_links)
        item = {'name': name, 'ids': [r['taxon_id'] for r in rows]}
        if conflicts:
            result['excluded'].append({**item, 'reasons': conflicts})
        else:
            result['groups'].append({**item, 'keep': rows[0]['taxon_id'], 'rule': CENTRAL_RULE})
    return result


def resolve_taxon_usage(identity, taxa: list[dict], links: list[dict]) -> dict | None:
    """Vind centrale bestemming én oorspronkelijke context, zonder conceptfusie."""
    current = {r['taxon_id']: r for r in taxa}
    archived = []
    for link in links:
        if (link.get('bron_systeem') != 'Meijendel'
                or link.get('bron_dataset') != 'taxa_naamgebruik_archief'
                or link.get('ingetrokken_op') is not None):
            continue
        meta = link.get('bronmetadata') or {}
        original = meta.get('taxon_voor') or {}
        if identity not in (original.get('taxon_id'), original.get('taxon_uuid')):
            continue
        if (meta.get('regelversie') != CENTRAL_RULE or link['taxon_id'] not in current
                or link.get('bron_taxon_id') != original.get('taxon_uuid')):
            raise ValueError('Ongeldig broncontextarchief')
        archived.append({'taxon_id': link['taxon_id'], 'bron_taxon': original,
                         'conceptrelatie': 'onbekend'})
    if len(archived) > 1:
        raise ValueError('Meerdere oorspronkelijke broncontexten voor dezelfde identiteit')
    if archived:
        return archived[0]
    target = resolve_taxon_identity(identity, taxa, links)
    if target is not None:
        contexts = list(taxa) + [(b.get('bronmetadata') or {}).get('taxon_voor',{})
                                for b in links if b.get('bron_dataset')=='taxa_naamgebruik_archief']
        originals = []
        for context in contexts:
            for fusion in (context.get('taxonmetadata') or {}).get('fusie_historie',[]):
                for old in fusion.get('before_taxa',[]):
                    if identity in (old.get('taxon_id'),old.get('taxon_uuid')):
                        if old not in originals:
                            originals.append(old)
        if len(originals)>1:
            raise ValueError('Tegenstrijdige oudere fusiecontext')
        if originals:
            return {'taxon_id':target,'bron_taxon':originals[0],'conceptrelatie':'onbekend'}
    return None if target is None else {'taxon_id': target, 'bron_taxon': current[target],
                                       'conceptrelatie': 'onbekend'}


def resolve_registry_import(source: dict, taxon: dict, taxa: list[dict], links: list[dict],
                            *, name_evidence: dict | None = None) -> dict | None:
    """Voor iedere import: bronidentiteit, dan eenduidig taxon; twijfel blokkeert.

    None betekent alleen geen bestaande kandidaat, geen toestemming tot invoer.
    Aanroeper gebruikt een vergrendelde actuele snapshot in dezelfde transactie.
    """
    fields = ('bron_systeem','bron_dataset','bron_versie','bron_taxon_id')
    if any(not source.get(f) for f in fields):
        raise ValueError('Volledige bronidentiteit vereist')
    existing = [b for b in links if b.get('ingetrokken_op') is None
                and all(b.get(f) == source[f] for f in fields)]
    if existing:
        if (len(existing) != 1 or existing[0]['taxon_id'] not in {t['taxon_id'] for t in taxa}
                or existing[0].get('koppelstatus') not in {'kandidaat','bevestigd'}):
            raise ValueError('Bestaande bronidentiteit niet eenduidig gekoppeld')
        original = existing[0]
        for field in ('bron_wetenschappelijke_naam','bron_nederlandse_naam','bron_taxonrang',
                      'bron_naam_volgens','bron_naam_identificatie','bron_concept_identificatie',
                      'bron_taxonomische_status','bronbestand_sha256','bron_soortgroep'):
            if original.get(field) != source.get(field):
                raise ValueError('Bestaande bronidentiteit met andere of onvolledige bronvelden: '+field)
        stored = {k:v for k,v in (original.get('bronmetadata') or {}).items()
                  if k!='register_broncontext'}
        if stored != (source.get('bronmetadata') or {}):
            raise ValueError('Oorspronkelijke bronmetadata verschilt of ontbreekt')
        return {'taxon_id': existing[0]['taxon_id'], 'koppeling_id': existing[0]['koppeling_id']}
    candidates = [t for t in taxa if central_name(t) == central_name(taxon)]
    archived_targets={b['taxon_id'] for b in links
                      if b.get('bron_systeem')=='Meijendel'
                      and b.get('bron_dataset')=='taxa_naamgebruik_archief'
                      and b.get('ingetrokken_op') is None
                      and (b.get('bronmetadata') or {}).get('taxon_voor')
                      and central_name(b['bronmetadata']['taxon_voor'])==central_name(taxon)}
    if archived_targets-{t['taxon_id'] for t in candidates}:
        raise ValueError('Naam is eerder gecorrigeerd of gefuseerd; bronafbakening beoordelen, geen nieuw taxon')
    if not candidates:
        # A shared binomial is only a REVIEW signal, never identity evidence.
        # This catches new author/rank/separator variants while preventing a
        # species from being silently equated with its subspecies or aggregate.
        def name_stem(row):
            match=re.match(r'^([A-Z][a-z]+)\s+(?:[x×]\s+)?([a-z][a-z-]+)\b',central_name(row))
            return match.groups() if match else None
        stem=name_stem(taxon)
        if stem and any(name_stem(t)==stem for t in taxa):
            raise ValueError('Verwante naamvariant bestaat; rang, auteur en afbakening beoordelen vóór nieuwe invoer')
        authored=re.fullmatch(r'([A-Z][a-z]+) (?:[A-Z(]|von |de ).*',central_name(taxon))
        if authored and any(central_name(t)==authored[1] for t in taxa):
            raise ValueError('Bestaande hogere taxonnaam met auteursuffix; eerst inhoudelijk beoordelen')
        return None
    incoming = {**taxon,'taxon_id':-1}
    incoming_link = {**source,'taxon_id':-1}
    if len(candidates) != 1 or central_conflicts([incoming, *candidates], [*links,incoming_link]):
        raise ValueError('Gelijknamige invoer vereist inhoudelijke beoordeling; geen nieuw duplicaat')
    name=central_name(taxon)
    if not central_name_evidence_ok(name,name_evidence or {}):
        raise ValueError('Nieuwe bronidentiteit vereist een eenduidig gecontroleerd naamanker')
    reference=central_name_reference(name,taxon['groep_id'],name_evidence)
    if central_conflicts([incoming,*candidates,reference],[]):
        raise ValueError('Naamanker wijkt inhoudelijk af van de invoer of het bestaande taxon')
    return {'taxon_id': candidates[0]['taxon_id'], 'koppeling_id': None}


def central_name_evidence_ok(name: str, evidence: dict) -> bool:
    """Eenduidig extern naamanker, nooit bewijs van historische congruentie."""
    answer=evidence.get('response') or {}
    usage=answer.get('usage') or {}
    diagnostics=answer.get('diagnostics') or {}
    if (evidence.get('name')!=name or not re.fullmatch(r'[a-f0-9]{64}', evidence.get('response_sha256',''))
            or diagnostics.get('matchType')!='EXACT' or diagnostics.get('confidence',0)<95
            or usage.get('canonicalName')!=name or not usage.get('key')):
        return False
    for alt in diagnostics.get('alternatives',[]):
        u=alt.get('usage') or {}
        if not u:
            return False
        if u.get('canonicalName')!=name:
            continue
        if (u.get('rank') in {'SPECIES_AGGREGATE','UNRANKED'}
                or usage.get('rank') in {'SPECIES_AGGREGATE','UNRANKED'}
                or (usage.get('rank') and u.get('rank') and u['rank']!=usage['rank'])):
            return False
        if u.get('key')==usage['key']:
            continue
        if (alt.get('acceptedUsage') or u).get('key')==(answer.get('acceptedUsage') or usage).get('key'):
            continue
        # COL may supply accepted and provisional entries for the same nominal
        # name. Different IDs alone are not homonyms. Require author, rank and
        # every shared higher classification to agree, with a known kingdom.
        main_class={x['rank']:x['name'] for x in answer.get('classification',[]) if x['rank']!='SPECIES'}
        alt_class={x['rank']:x['name'] for x in alt.get('classification',[]) if x['rank']!='SPECIES'}
        if (not usage.get('authorship') or u.get('authorship')!=usage['authorship']
                or not usage.get('rank') or u.get('rank')!=usage['rank']
                or not main_class.get('KINGDOM') or alt_class.get('KINGDOM')!=main_class['KINGDOM']
                or any(main_class[k]!=alt_class[k] for k in main_class.keys() & alt_class.keys())):
            return False
    return True


def central_name_reference(name: str, group_id: int, evidence: dict) -> dict:
    answer=evidence['response']; usage=answer['usage']
    reference={'taxon_id':-2,'wetenschappelijke_naam':name,
               'groep_id':group_id,'taxonvorm':'taxon',
               'naam_auteur':usage.get('authorship'),
               'taxonrang':usage.get('rank','').lower() or None}
    fields={'KINGDOM':'rijk','PHYLUM':'stam','CLASS':'klasse','ORDER':'orde','FAMILY':'familie'}
    for rank in answer.get('classification',[]):
        if rank['rank'] in fields:
            reference[fields[rank['rank']]]=rank['name']
    return reference


def central_taxa_projection(taxa: list[dict], links: list[dict], *, name_evidence: dict | None = None) -> dict:
    """Exact te verwachten cellen en herstelarchief, zonder databasewijziging."""
    plan = plan_central_taxa(taxa, links)
    if name_evidence is not None:
        selected=[]
        rows_by_id={t['taxon_id']:t for t in taxa}
        for group in plan['groups']:
            evidence=name_evidence.get(group['name'],{})
            if not central_name_evidence_ok(group['name'],evidence):
                plan['excluded'].append({**group,'reasons':['geen_eenduidig_extern_naamanker']})
                continue
            answer=evidence['response']; usage=answer['usage']
            rows=[rows_by_id[i] for i in group['ids']]
            reference=central_name_reference(group['name'],rows[0]['groep_id'],evidence)
            conflicts=central_conflicts([*rows,reference],[])
            if conflicts:
                plan['excluded'].append({**group,'reasons':['referentie_'+c for c in conflicts]})
            else:
                selected.append({**group,'naamanker_sha256':evidence['response_sha256'],
                                 'naamanker_usage':usage['key']})
        plan['groups']=selected
    by_id = {t['taxon_id']: t for t in taxa}
    mapping = {i:g['keep'] for g in plan['groups'] for i in g['ids']}
    if any((t.get(f) in mapping) for t in taxa for f in
           ('bovenliggend_taxon_id','geaccepteerd_taxon_id','oorspronkelijk_taxon_id')):
        raise ValueError('Taxonomische zelfverwijzing vereist aparte beoordeling')
    keys = [(b['bron_identiteit_sha256'], b['besluitversie'], mapping.get(b['taxon_id'],b['taxon_id'])) for b in links]
    if len(keys) != len(set(keys)):
        raise ValueError('Samenvoeging veroorzaakt bronbesluitbotsing')
    if any((t.get('taxonmetadata') or {}).get('centrale_lijst') for t in taxa if t['taxon_id'] in mapping):
        raise ValueError('Herhaalde centralisatie vereist een nieuw beoordeeld plan')
    by_source = defaultdict(list)
    for b in links:
        by_source[b['taxon_id']].append(b)
    archives = []
    for i, target in sorted(mapping.items()):
        original = by_id[i]
        archives.append({'bron_systeem':'Meijendel','bron_dataset':'taxa_naamgebruik_archief',
            'bron_versie':CENTRAL_RULE,'bron_taxon_id':original['taxon_uuid'],
            'bron_wetenschappelijke_naam':original['wetenschappelijke_naam'],
            'bron_taxonrang':original.get('taxonrang'),
            'bron_naam_volgens':original.get('naam_volgens'),
            'bronmetadata':{'regelversie':CENTRAL_RULE,'taxon_voor':original,
                            'bronkoppelingen_voor':by_source[i]},
            'taxon_id':target,'koppelstatus':'kandidaat','taxonrelatie':'onbekend',
            'koppelmethode':'centralisatie-met-behoud-broncontext','regelversie':CENTRAL_RULE,
            'onderbouwing':'Centrale nominale vermelding; oorspronkelijk bronconcept volledig behouden. Geen congruentie vastgesteld.'})
    after_links = copy.deepcopy(links)
    for b in after_links:
        if b['taxon_id'] not in mapping:
            continue
        if b['koppelstatus'] != 'kandidaat' or b['taxonrelatie'] != 'onbekend':
            raise ValueError('Bevestigd bronbesluit mag niet stilzwijgend worden omgezet')
        meta = b['bronmetadata'] or {}
        if 'register_broncontext' in meta:
            raise ValueError('Broncontext is al gemigreerd')
        meta['register_broncontext'] = copy.deepcopy(by_id[b['taxon_id']])
        b['bronmetadata'] = meta
        b['taxon_id'] = b['doeltaxon_sleutel'] = mapping[b['taxon_id']]
    new_taxa = copy.deepcopy([t for t in taxa if mapping.get(t['taxon_id'],t['taxon_id'])==t['taxon_id']])
    groups = {g['keep']:g for g in plan['groups']}
    for t in new_taxa:
        if t['taxon_id'] not in groups:
            continue
        g = groups[t['taxon_id']]
        originals = [by_id[i] for i in g['ids']]
        # Enrich only unambiguous empty cells. Historical source treatment is
        # preserved in archive rows, not reinterpreted as a shared concept.
        for f in ('naam_auteur','nederlandse_naam','taxonrang','nomenclatuurcode',
                  'rijk','stam','klasse','orde','familie','geslacht'):
            values = {r.get(f) for r in originals if r.get(f) not in (None,'')}
            if t.get(f) is None and len(values)==1:
                t[f] = next(iter(values))
        t['naam_zonder_auteur'] = g['name']
        t['naam_volgens'] = 'Meijendel centrale nominale taxonregistratie; bronconcepten afzonderlijk bewaard'
        t['naam_volgens_id'] = None
        t['naam_volgens_versie'] = CENTRAL_RULE
        t['concept_identificatie'] = None
        t['taxonomische_status'] = 'unresolved'
        t['taxonmetadata'] = {**(t.get('taxonmetadata') or {}),
            'centrale_lijst':{'regelversie':CENTRAL_RULE,'oorspronkelijke_ids':g['ids'],
                              'historische_conceptgelijkheid':False}}
    return {'taxa':new_taxa,'links':after_links,'archives':archives,'plan':plan,'mapping':mapping}


def reviewed_group_hash(ids: list[int], taxa: list[dict], links: list[dict]) -> str:
    """Bind a reviewed decision to every source cell, not just name and ID."""
    payload={'taxa':sorted((t for t in taxa if t['taxon_id'] in ids),key=lambda t:t['taxon_id']),
             'links':sorted((b for b in links if b['taxon_id'] in ids),key=lambda b:b['koppeling_id'])}
    return hashlib.sha256(json.dumps(payload,sort_keys=True,ensure_ascii=False,
                                    separators=(',',':')).encode()).hexdigest()


def reviewed_taxa_projection(taxa: list[dict], links: list[dict], plan: dict) -> dict:
    """Execute a bounded, source-hashed review; never infer concept congruence.

    Unlike the conservative discovery planner this accepts individually reviewed
    author/classification differences and name corrections. Review evidence is
    mandatory. Previously archived UUIDs are redirected, not archived twice.
    """
    rule='taxa-beoordeelde-fusie-v2'
    if plan.get('rule')!=rule or not plan.get('groups'):
        raise ValueError('Een expliciet beoordeeld fusieplan is vereist')
    allowed={'naam_auteur','nederlandse_naam','taxonrang','taxonvorm','groep_id',
             'rijk','stam','klasse','orde','familie','geslacht','nomenclatuurcode','opmerkingen'}
    by_id={t['taxon_id']:t for t in taxa}
    mapping={}
    for g in plan['groups']:
        ids=g.get('ids',[])
        if (not ids or len(ids)!=len(set(ids)) or set(ids)-by_id.keys()
                or g.get('keep') not in ids or set(ids)&mapping.keys()
                or not g.get('name') or not g.get('reason') or not g.get('evidence')
                or set(g.get('updates',{}))-allowed):
            raise ValueError('Onvolledig, overlappend of onbevoegd fusiebesluit')
        for e in g['evidence']:
            if not e.get('url') or not re.fullmatch('[a-f0-9]{64}',e.get('sha256','')):
                raise ValueError('Controleerbare bewijsverwijzing ontbreekt')
        if reviewed_group_hash(ids,taxa,links)!=g.get('source_sha256'):
            raise ValueError('Broncellen gewijzigd sinds inhoudelijke beoordeling')
        mapping.update({i:g['keep'] for i in ids})
    if any(t.get(f) in mapping for t in taxa for f in
           ('bovenliggend_taxon_id','geaccepteerd_taxon_id','oorspronkelijk_taxon_id')):
        raise ValueError('Taxonomische zelfverwijzing vereist aparte beoordeling')
    keys=[(b['bron_identiteit_sha256'],b['besluitversie'],mapping.get(b['taxon_id'],b['taxon_id'])) for b in links]
    if len(keys)!=len(set(keys)):
        raise ValueError('Samenvoeging veroorzaakt bronbesluitbotsing')
    by_source=defaultdict(list)
    archived=set()
    for b in links:
        by_source[b['taxon_id']].append(b)
        if b.get('bron_systeem')=='Meijendel' and b.get('bron_dataset')=='taxa_naamgebruik_archief':
            original=(b.get('bronmetadata') or {}).get('taxon_voor') or {}
            if (b.get('ingetrokken_op') is not None or b.get('bron_versie')!=CENTRAL_RULE
                    or b.get('bron_taxon_id')!=original.get('taxon_uuid')
                    or original.get('taxon_uuid') in archived):
                raise ValueError('Ongeldig of dubbel bestaand broncontextarchief')
            archived.add(original['taxon_uuid'])
    archives=[]
    for i,target in sorted(mapping.items()):
        original=by_id[i]
        if original['taxon_uuid'] in archived:
            continue
        archives.append({'bron_systeem':'Meijendel','bron_dataset':'taxa_naamgebruik_archief',
            'bron_versie':CENTRAL_RULE,'bron_taxon_id':original['taxon_uuid'],
            'bron_wetenschappelijke_naam':original['wetenschappelijke_naam'],
            'bron_taxonrang':original.get('taxonrang'),'bron_naam_volgens':original.get('naam_volgens'),
            'bronmetadata':{'regelversie':CENTRAL_RULE,'taxon_voor':copy.deepcopy(original),
                            'bronkoppelingen_voor':copy.deepcopy(by_source[i])},
            'taxon_id':target,'koppelstatus':'kandidaat','taxonrelatie':'onbekend',
            'koppelmethode':'centralisatie-met-behoud-broncontext','regelversie':CENTRAL_RULE,
            'onderbouwing':'Beoordeelde nominale fusie; oorspronkelijke broncontext behouden. Geen historische congruentie vastgesteld.'})
    after_links=copy.deepcopy(links)
    for b in after_links:
        i=b['taxon_id']
        if i not in mapping:
            continue
        if b['koppelstatus']!='kandidaat' or b['taxonrelatie']!='onbekend':
            raise ValueError('Bevestigd bronbesluit mag niet stilzwijgend worden omgezet')
        if not (b['bron_systeem']=='Meijendel' and b['bron_dataset'] in
                {'taxa_naamgebruik_archief','taxa_fusie_alias'}):
            meta=b.get('bronmetadata') or {}
            meta.setdefault('register_broncontext',copy.deepcopy(by_id[i]))
            b['bronmetadata']=meta
        b['taxon_id']=b['doeltaxon_sleutel']=mapping[i]
    new_taxa=copy.deepcopy([t for t in taxa if mapping.get(t['taxon_id'],t['taxon_id'])==t['taxon_id']])
    groups={g['keep']:g for g in plan['groups']}
    for t in new_taxa:
        g=groups.get(t['taxon_id'])
        if not g:
            continue
        originals=[by_id[i] for i in g['ids']]
        for field in allowed-{'opmerkingen'}:
            values={r.get(field) for r in originals if r.get(field) not in (None,'')}
            if t.get(field) is None and len(values)==1:
                t[field]=next(iter(values))
        t.update(copy.deepcopy(g.get('updates',{})))
        t['wetenschappelijke_naam']=t['naam_zonder_auteur']=g['name']
        t['naam_volgens']='Meijendel centrale nominale taxonregistratie; bronconcepten afzonderlijk bewaard'
        t['naam_volgens_id']=None
        t['naam_volgens_versie']=rule
        t['concept_identificatie']=None
        t['taxonomische_status']='unresolved'
        meta=t.get('taxonmetadata') or {}
        meta.setdefault('beoordeelde_fusies',[]).append({'besluit':copy.deepcopy(g),
            'taxa_voor':copy.deepcopy(originals),'historische_conceptgelijkheid':False})
        meta['centrale_lijst']={'regelversie':rule,'oorspronkelijke_ids':g['ids'],
                               'historische_conceptgelijkheid':False}
        t['taxonmetadata']=meta
    return {'taxa':new_taxa,'links':after_links,'archives':archives,'plan':copy.deepcopy(plan),'mapping':mapping}


def central_taxa_sql(snapshot: dict, *, name_evidence: dict | None = None,
                     reviewed_plan: dict | None = None, commit: bool = False) -> str:
    """Alleen DML, fail-closed snapshotpoort en celcontrole binnen één transactie."""
    if (not name_evidence and not reviewed_plan) or (name_evidence is not None and reviewed_plan is not None):
        raise ValueError('Precies één volledige naambeoordeling of beoordeeld fusieplan vereist')
    old_taxa, old_links = snapshot['taxa']['rows'], snapshot['taxa_bronkoppeling']['rows']
    if reviewed_plan is not None:
        projected=reviewed_taxa_projection(old_taxa,old_links,reviewed_plan)
    else:
        projected = central_taxa_projection(old_taxa, old_links, name_evidence=name_evidence)
    if not projected['mapping']:
        raise ValueError('Geen beoordeelde fusies')
    def literal(value):
        if value is None:
            return 'NULL'
        if isinstance(value,(dict,list)):
            value=json.dumps(value,ensure_ascii=False)
        return "CONVERT(X'"+str(value).encode().hex()+"' USING utf8mb4)"
    def json_literal(value):
        return literal(json.dumps(value,ensure_ascii=False))
    sql = ["SET SESSION group_concat_max_len=16777216;",
           "SET SESSION innodb_lock_wait_timeout=15;",
           "CREATE TEMPORARY TABLE central_guard(ok INT NOT NULL CHECK(ok=1));",
           "START TRANSACTION;",
           "SELECT taxon_id FROM taxa ORDER BY taxon_id FOR UPDATE;",
           "SELECT koppeling_id FROM taxa_bronkoppeling ORDER BY koppeling_id FOR UPDATE;"]
    for table, spec in snapshot.items():
        sql.append(f"INSERT INTO central_guard SELECT SHA2(GROUP_CONCAT(SHA2(CAST({spec['expression']} AS CHAR),256) ORDER BY `{spec['pk']}` SEPARATOR ''),256)='{spec['sha256']}' FROM `{table}`;")
    for record in projected['archives']:
        sql.append('INSERT INTO taxa_bronkoppeling ('+','.join(record)+') VALUES ('+','.join(literal(v) for v in record.values())+');')
    for before, after in zip(old_links,projected['links']):
        if before == after:
            continue
        sql.append(f"UPDATE taxa_bronkoppeling SET taxon_id={after['taxon_id']},bronmetadata={literal(after['bronmetadata'])} WHERE koppeling_id={after['koppeling_id']};")
    before_taxa = {t['taxon_id']:t for t in old_taxa}
    for after in projected['taxa']:
        before = before_taxa[after['taxon_id']]
        changed = {f:v for f,v in after.items() if before.get(f)!=v}
        if changed:
            sql.append('UPDATE taxa SET '+','.join(f'`{f}`={literal(v)}' for f,v in changed.items())+f" WHERE taxon_id={after['taxon_id']};")
    removed = [i for i,target in projected['mapping'].items() if i != target]
    if removed:
        sql.append('DELETE FROM taxa WHERE taxon_id IN ('+','.join(map(str,removed))+');')
    # Every original surviving cell and every archived cell is checked before
    # commit, not merely counts. Generated target keys are included.
    for table, rows in [('taxa',projected['taxa']),('taxa_bronkoppeling',projected['links'])]:
        spec=snapshot[table]
        for row in rows:
            expected={k:v for k,v in row.items() if k!='gewijzigd_op'}
            sql.append(f"INSERT INTO central_guard SELECT COUNT(*)=1 FROM `{table}` WHERE `{spec['pk']}`={row[spec['pk']]} AND BINARY CAST(JSON_REMOVE({spec['expression']},'$.gewijzigd_op') AS CHAR)=BINARY CAST(CAST({json_literal(expected)} AS JSON) AS CHAR);")
    for archive in projected['archives']:
        sql.append("INSERT INTO central_guard SELECT COUNT(*)=1 FROM taxa_bronkoppeling WHERE bron_systeem='Meijendel' AND bron_dataset='taxa_naamgebruik_archief' "
                   f"AND bron_versie='{CENTRAL_RULE}' AND bron_taxon_id={literal(archive['bron_taxon_id'])} AND taxon_id={archive['taxon_id']} "
                   f"AND BINARY CAST(bronmetadata AS CHAR)=BINARY CAST(CAST({literal(archive['bronmetadata'])} AS JSON) AS CHAR);")
    sql.extend([f"INSERT INTO central_guard SELECT COUNT(*)={len(projected['taxa'])} FROM taxa;",
                f"INSERT INTO central_guard SELECT COUNT(*)={len(old_links)+len(projected['archives'])} FROM taxa_bronkoppeling;",
                "INSERT INTO central_guard SELECT COUNT(*)=0 FROM taxa_bronkoppeling b LEFT JOIN taxa t ON t.taxon_id=b.taxon_id WHERE b.taxon_id IS NOT NULL AND t.taxon_id IS NULL;",
                'COMMIT;' if commit else 'ROLLBACK;'])
    return '\n'.join(sql)


FUSION_GROUPS = ((40389, 40390), (40402, 40403, 40404))
FUSION_UUIDS = {
    40389: 'ea88e014-fe9d-4fcc-91b9-36b8bea5f358',
    40390: 'bac4ac07-e0b3-49b8-9840-d00ca5cce76c',
    40402: '288053b1-aee4-4fce-8b8a-58d1bb6167d0',
    40403: '05dbcb96-be93-459a-9e2b-76eec4cdb568',
    40404: '865f6504-b92c-45bd-bf52-164da0e057bd',
}
FUSION_VERSION = ('2026-09-24; sha256:'
                  '19611eead96004ff51e12f8415159e23a6e75e23a30cfb190fcb89262f282ebc')
FUSION_SOURCE = {
    40389: ('Rhantus (Rhantus) frontalis (Marsham, 1802)', '8139140b07115e012ec4e37dac410b3466178bf50cdf8e3f835f64107bac0a18'),
    40390: ('Rhantus frontalis (Marsham, 1802)', '254ac84de0f84d021280e91f3023a82d11e7ee3211d1cb664c908cc58154d21d'),
    40402: ('Haliplus (Haliplinus) ruficollis (De Geer, 1774)', 'fe1f08ee4f1157c2a99acd126f52fc9bf76c340ae0b4265f28a1d21f51aa2b2a'),
    40403: ('Haliplus (Haliplus) ruficollis (De Geer, 1774)', 'ec473c85e57480011795301140094c7e5c609765ffe25d9dd877c2a3bff24e81'),
    40404: ('Haliplus ruficollis (De Geer, 1774)', 'd3b56cbe38f78f344aa503e81e71380bc7b74437f039876d7b503e3bdbe5f44c'),
}


def resolve_taxon_identity(identity, taxa: list[dict], links: list[dict]):
    """Resolveer een centraal ID/UUID, inclusief expliciete technische fusie-aliassen.

    Gewone naamreferenties (dataset taxa) zijn nooit identiteitsaliassen.
    Een alias moet direct op een bestaande rij eindigen: geen ketens of cycli.
    """
    identities = {}
    live_ids = {row['taxon_id'] for row in taxa}
    for row in taxa:
        for key in (row['taxon_id'], row['taxon_uuid']):
            if key in identities:
                raise ValueError('Dubbele centrale identiteit')
            identities[key] = row['taxon_id']
    for link in links:
        if (link.get('bron_systeem') != 'Meijendel'
                or link.get('bron_dataset') != 'taxa_naamgebruik_archief'
                or link.get('ingetrokken_op') is not None):
            continue
        meta = link.get('bronmetadata') or {}
        original = meta.get('taxon_voor') or {}
        if (meta.get('regelversie') != CENTRAL_RULE or link['taxon_id'] not in live_ids
                or link.get('bron_taxon_id') != original.get('taxon_uuid')
                or type(original.get('taxon_id')) is not int):
            raise ValueError('Ongeldige centrale broncontextverwijzing')
        for key in (original['taxon_id'],original['taxon_uuid']):
            if key in identities and identities[key] != link['taxon_id']:
                raise ValueError('Botsende centrale broncontextverwijzing')
            identities[key] = link['taxon_id']
    for link in links:
        if (link['bron_systeem'] != 'Meijendel' or link['bron_dataset'] != 'taxa_fusie_alias'
                or link['ingetrokken_op'] is not None):
            continue
        meta = link['bronmetadata'] or {}
        old_id, old_uuid = meta.get('voormalig_taxon_id'), meta.get('voormalig_taxon_uuid')
        if (meta.get('rol') != 'technische_fusie_alias' or type(old_id) is not int
                or not old_uuid or old_uuid != link['bron_taxon_id']
                or link['taxon_id'] not in live_ids or link['regelversie'] != FUSION_RULE
                or link['bron_versie'] != FUSION_RULE or link['koppelstatus'] != 'kandidaat'
                or link['taxonrelatie'] != 'onbekend'):
            raise ValueError('Ongeldige technische fusie-alias')
        for key in (old_id, old_uuid):
            if key in identities:
                raise ValueError('Dubbele of cyclische fusie-alias')
            identities[key] = link['taxon_id']
    return identities.get(identity)


def plan_taxon_fusion(taxa: list[dict], links: list[dict]) -> list[dict]:
    """Uitsluitend de vijf beoordeelde Naturalis-naamregistraties; geen naamheuristiek."""
    by_id = {row['taxon_id']: row for row in taxa}
    if len(by_id) != len(taxa) or not FUSION_UUIDS.keys() <= by_id.keys():
        raise ValueError('Fusie al uitgevoerd of oorspronkelijke taxa ontbreken')
    plan = []
    for group in FUSION_GROUPS:
        rows = [by_id[taxon_id] for taxon_id in group]
        keeper = rows[0]
        expected_name = 'Rhantus frontalis' if group[0] == 40389 else 'Haliplus ruficollis'
        ignored = {'taxon_id', 'taxon_uuid', 'aangemaakt_op', 'gewijzigd_op'}
        if (len(keeper) < 38 or keeper.get('wetenschappelijke_naam') != expected_name
                or keeper.get('naam_volgens_versie') != FUSION_VERSION
                or keeper.get('naam_volgens') != 'Lokale bronweergave Meijendel.naturalis-coleoptera-meijendel'
                or keeper.get('groep_id') != 7):
            raise ValueError('Taxonstructuur of beoordeelde broncontext wijkt af')
        for row in rows:
            if (row['taxon_uuid'] != FUSION_UUIDS[row['taxon_id']]
                    or {k: v for k, v in row.items() if k not in ignored}
                    != {k: v for k, v in keeper.items() if k not in ignored}):
                raise ValueError('Verschillende taxonvelden: geen bewezen dubbele registratie')
        removed = set(group[1:])
        for row in taxa:
            if any(row[field] in removed for field in
                   ('bovenliggend_taxon_id', 'geaccepteerd_taxon_id', 'oorspronkelijk_taxon_id')):
                raise ValueError('Taxonomische verwijzing vereist afzonderlijke beoordeling')
        source_links = [link for link in links if link['taxon_id'] in group]
        for row in rows:
            direct = [link for link in source_links if link['taxon_id'] == row['taxon_id']]
            if (len(direct) != 1 or direct[0]['bron_dataset'] != 'naturalis-coleoptera-meijendel'
                    or direct[0]['bron_systeem'] != 'Meijendel'
                    or direct[0]['bronbestand_sha256'] != FUSION_VERSION.split('sha256:')[1]
                    or direct[0]['bron_taxon_id'] != 'taxonvelden-sha256:' + FUSION_SOURCE[row['taxon_id']][1]
                    or direct[0]['bron_versie'] != FUSION_VERSION
                    or direct[0]['koppelstatus'] != 'kandidaat'
                    or direct[0]['taxonrelatie'] != 'onbekend'
                    or direct[0]['ingetrokken_op'] is not None):
                raise ValueError('Onverwachte bronkoppelingen: eerst opnieuw beoordelen')
            meta = direct[0]['bronmetadata'] or {}
            raw_name = FUSION_SOURCE[row['taxon_id']][0]
            if (meta.get('raw_name') != raw_name or meta.get('scientificName') != raw_name
                    or any(meta.get(k) is not None for k in ('taxonRemarks', 'nameAccordingTo',
                        'nameAccordingToID', 'taxonID', 'taxonKey', 'scientificNameID', 'acceptedNameUsageID'))
                    or {k:v for k,v in meta.items() if k not in {'raw_name','scientificName'}}
                    != {k:v for k,v in source_links[0]['bronmetadata'].items() if k not in {'raw_name','scientificName'}}):
                raise ValueError('Bronvelden verschillen meer dan de beoordeelde subgenusnotatie')
        if (keeper.get('taxonmetadata') or {}).get('fusie_historie'):
            raise ValueError('Eerdere fusie aanwezig; geen blinde herhaling')
        plan.append({'keep': group[0], 'remove': list(group[1:]), 'before_taxa': rows,
                     'before_links': source_links,
                     'rule': FUSION_RULE,
                     'reason': 'Zelfde Naturalis-snapshot en alle taxonvelden; alleen subgenusnotatie in ruwe bronnaam verschilt.',
                     'evidence': ['https://code.iczn.org/chapter-2-the-number-of-words-in-the-scientific-names-of-animals/article-6-interpolated-names/',
                                  'https://repository.naturalis.nl/document/148523',
                                  'https://www.lanuv.nrw.de/fileadmin/lanuvpubl/4_arbeitsblaetter/40020.pdf']})
    target_map = {old: item['keep'] for item in plan for old in item['remove']}
    keys = [(b['bron_identiteit_sha256'], b['besluitversie'], target_map.get(b['taxon_id'], b['taxon_id']))
            for b in links]
    if len(keys) != len(set(keys)):
        raise ValueError('Fusie veroorzaakt een botsing tussen bronkoppelingen')
    # Two reviewed Rhantus name-reference links retain their immutable source UUID.
    # They must be resolved through resolve_taxon_identity, not mistaken for aliases.
    logical = [(b['koppeling_id'], b['bron_taxon_id'], b['taxon_id'], b['koppelstatus'], b['taxonrelatie'])
               for b in links if b['bron_dataset'] == 'taxa' and b['bron_taxon_id'] in FUSION_UUIDS.values()]
    if sorted(logical) != [(50230, FUSION_UUIDS[40389], 44804, 'kandidaat', 'onbekend'),
                           (50231, FUSION_UUIDS[40390], 44804, 'kandidaat', 'onbekend')]:
        raise ValueError('Logische UUID-verwijzingen wijken af van beoordeelde inventarisatie')
    return plan


def taxon_registry_snapshot(client: Path, args: list[str]) -> dict:
    """Alle cellen, inclusief microseconden, JSON en gegenereerde binaire sleutels."""
    result = {}
    for table, pk in [('taxa', 'taxon_id'), ('taxa_bronkoppeling', 'koppeling_id')]:
        columns = run_mysql(client, args,
            "SELECT COLUMN_NAME,DATA_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() "
            f"AND TABLE_NAME='{table}' ORDER BY ORDINAL_POSITION").splitlines()
        parts = []
        for column in columns:
            name, kind = column.split('\t')
            expr = f'HEX(`{name}`)' if kind in {'binary', 'varbinary'} else f'`{name}`'
            parts.extend([f"'{name}'", expr])
        expression = 'JSON_OBJECT(' + ','.join(parts) + ')'
        raw = run_mysql(client, args, f'SELECT SHA2(CAST({expression} AS CHAR),256),{expression} FROM `{table}` ORDER BY `{pk}`')
        pairs = [line.split('\t', 1) for line in raw.splitlines()]
        result[table] = {'rows': [json.loads(pair[1]) for pair in pairs],
                         'sha256': hashlib.sha256(''.join(pair[0] for pair in pairs).encode()).hexdigest(),
                         'expression': expression, 'pk': pk}
    return result


def taxon_fusion_sql(snapshot: dict, *, commit: bool = False) -> str:
    """Eén verbinding en transactie; iedere afwijking stopt vóór COMMIT.

    Het mysql-programma moet zonder --force worden gestart. Bij een SQL-fout
    sluit het de verbinding, waardoor InnoDB de gehele transactie terugdraait.
    """
    plan = plan_taxon_fusion(snapshot['taxa']['rows'], snapshot['taxa_bronkoppeling']['rows'])
    literal = lambda value: "CONVERT(X'" + json.dumps(value, ensure_ascii=False).encode().hex() + "' USING utf8mb4)"
    sql = ["SET SESSION group_concat_max_len=16777216;",
           "CREATE TEMPORARY TABLE fusie_guard (ok INT NOT NULL CHECK(ok=1));",
           "START TRANSACTION;",
           "SELECT taxon_id FROM taxa ORDER BY taxon_id FOR UPDATE;",
           "SELECT koppeling_id FROM taxa_bronkoppeling ORDER BY koppeling_id FOR UPDATE;",
           "CREATE TEMPORARY TABLE fusie_before_taxa AS SELECT * FROM taxa;",
           "CREATE TEMPORARY TABLE fusie_before_links AS SELECT * FROM taxa_bronkoppeling;"]
    for table, spec in snapshot.items():
        sql.append(f"INSERT INTO fusie_guard SELECT SHA2(GROUP_CONCAT(SHA2(CAST({spec['expression']} AS CHAR),256) ORDER BY `{spec['pk']}` SEPARATOR ''),256)='{spec['sha256']}' FROM `{table}`;")
    for item in plan:
        keeper = item['before_taxa'][0]
        metadata = dict(keeper['taxonmetadata'] or {})
        metadata['fusie_historie'] = [item]
        sql.append(f"UPDATE taxa SET taxonmetadata={literal(metadata)} WHERE taxon_id={item['keep']};")
        for row in item['before_taxa'][1:]:
            old = row['taxon_id']
            meta = {'rol': 'technische_fusie_alias', 'voormalig_taxon_id': old,
                    'voormalig_taxon_uuid': row['taxon_uuid']}
            sql.append(f"UPDATE taxa_bronkoppeling SET taxon_id={item['keep']} WHERE taxon_id={old};")
            sql.append("INSERT INTO taxa_bronkoppeling (bron_systeem,bron_dataset,bron_versie,bron_taxon_id,bronmetadata,taxon_id,koppelstatus,taxonrelatie,koppelmethode,regelversie,onderbouwing) VALUES ("
                       f"'Meijendel','taxa_fusie_alias','{FUSION_RULE}','{row['taxon_uuid']}',{literal(meta)},{item['keep']},'kandidaat','onbekend','technische-identiteitsalias','{FUSION_RULE}','Technische alias van dubbele registratie binnen dezelfde broncontext; geen nieuwe conceptbeoordeling.');")
            sql.append(f"DELETE FROM taxa WHERE taxon_id={old};")
    sql.extend([
        f"INSERT INTO fusie_guard SELECT COUNT(*)={len(snapshot['taxa']['rows']) - 3} FROM taxa;",
        f"INSERT INTO fusie_guard SELECT COUNT(*)={len(snapshot['taxa_bronkoppeling']['rows']) + 3} FROM taxa_bronkoppeling;",
        "INSERT INTO fusie_guard SELECT COUNT(*)=0 FROM taxa_bronkoppeling b LEFT JOIN taxa t ON t.taxon_id=b.taxon_id WHERE b.taxon_id IS NOT NULL AND t.taxon_id IS NULL;",
    ])
    # Guard every original cell before committing, not only counts/FKs.
    for table, spec in snapshot.items():
        old_table = 'fusie_before_taxa' if table == 'taxa' else 'fusie_before_links'
        excluded = " WHERE taxon_id NOT IN (40389,40390,40402,40403,40404)" if table == 'taxa' else " WHERE taxon_id NOT IN (40390,40403,40404) OR taxon_id IS NULL"
        sha = f"SHA2(CAST({spec['expression']} AS CHAR),256)"
        sql.append(f"INSERT INTO fusie_guard SELECT COUNT(*)=0 FROM (SELECT `{spec['pk']}` id,{sha} h FROM {old_table}{excluded}) old LEFT JOIN (SELECT `{spec['pk']}` id,{sha} h FROM {table}) new USING(id) WHERE new.id IS NULL OR BINARY old.h<>BINARY new.h;")
    for item in plan:
        for row in item['before_links']:
            if row['taxon_id'] not in item['remove']:
                continue
            expected = {**row, 'taxon_id': item['keep'], 'doeltaxon_sleutel': item['keep']}
            expected.pop('gewijzigd_op')
            expr = snapshot['taxa_bronkoppeling']['expression']
            # JSON_OBJECT carries MySQL's internal DATETIME type; the archived
            # JSON roundtrip carries its identical six-digit text. Compare the
            # canonical serialized cells bytewise, not these internal types.
            sql.append(f"INSERT INTO fusie_guard SELECT BINARY CAST(JSON_REMOVE({expr},'$.gewijzigd_op') AS CHAR)=BINARY CAST(CAST({literal(expected)} AS JSON) AS CHAR) FROM taxa_bronkoppeling WHERE koppeling_id={row['koppeling_id']};")
        metadata = {**(item['before_taxa'][0]['taxonmetadata'] or {}), 'fusie_historie': [item]}
        expected = {**item['before_taxa'][0], 'taxonmetadata': metadata}
        expected.pop('gewijzigd_op')
        expr = snapshot['taxa']['expression']
        sql.append(f"INSERT INTO fusie_guard SELECT BINARY CAST(JSON_REMOVE({expr},'$.gewijzigd_op') AS CHAR)=BINARY CAST(CAST({literal(expected)} AS JSON) AS CHAR) FROM taxa WHERE taxon_id={item['keep']};")
    sql.append('COMMIT;' if commit else 'ROLLBACK;')
    return '\n'.join(sql)

def resolve_pq_taxon_links(catalogue: list[dict], links: list[dict]) -> dict[int, int]:
    """Koppel oorspronkelijke PQ-naamgebruiken, zonder concepten gelijk te stellen."""
    by_code = defaultdict(list)
    for link in links:
        if (link['bron_systeem'] == 'Meijendel' and link['bron_dataset'] == 'pq_vegetatie_taxon'
                and link['ingetrokken_op'] is None):
            by_code[link['bron_taxon_id']].append(link)
    resolved = {}
    for taxon in catalogue:
        matches = by_code[str(taxon['srtnum'])]
        if len(matches) != 1:
            raise ValueError(f"PQ-code {taxon['srtnum']}: geen unieke actieve bronkoppeling")
        link = matches[0]
        if (link['taxon_id'] is None or link['koppelstatus'] not in {'kandidaat', 'bevestigd'}
                or any(key not in link['bronmetadata'] or link['bronmetadata'][key] != value
                       for key, value in taxon.items())):
            raise ValueError(f"PQ-code {taxon['srtnum']}: doel of bronvelden wijken af")
        if taxon['taxon_id'] in resolved:
            raise ValueError('Dubbele lokale taxonidentificatie')
        resolved[taxon['taxon_id']] = link['koppeling_id']
    return resolved


def resolve_external_taxon_links(results: list[dict], links: list[dict],
                                 dataset: str, source_version: str) -> dict[int, int]:
    """Exact de versiegebonden taxonvelden van het centrale invoermanifest hergebruiken."""
    fields = ('taxonID', 'taxonKey', 'scientificNameID', 'acceptedNameUsageID',
              'nameAccordingTo', 'nameAccordingToID', 'scientificName', 'scientificNameAuthorship',
              'kingdom', 'phylum', 'class', 'order', 'family', 'genus', 'taxonRank',
              'verbatimTaxonRank', 'taxonomicStatus', 'nomenclaturalCode', 'taxonRemarks',
              'higherClassification')

    def canonical(value):
        return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(',', ':'))

    by_usage = defaultdict(list)
    for link in links:
        if (link['bron_systeem'] == 'Meijendel' and link['bron_dataset'] == dataset
                and link['bron_versie'] == source_version and link['ingetrokken_op'] is None):
            by_usage[canonical(source_usage_projection(link['bronmetadata']))].append(link)
    resolved = {}
    for row in results:
        usage = {key: row['bronmetadata'].get(key) for key in fields}
        usage.update(dataset=dataset, name=row['wetenschappelijke_naam'],
                     raw_name=row['wetenschappelijke_naam_bron'], nl=row['nederlandse_naam'],
                     rank=row['taxonrang'])
        matches = by_usage[canonical(usage)]
        if (len(matches) != 1 or matches[0]['taxon_id'] is None
                or matches[0]['koppelstatus'] not in {'kandidaat', 'bevestigd'}):
            raise ValueError(f"Resultaat {row['resultaat_id']}: geen unieke brongetrouwe taxonkoppeling")
        if row['resultaat_id'] in resolved:
            raise ValueError('Dubbele resultaatidentificatie')
        resolved[row['resultaat_id']] = matches[0]['koppeling_id']
    return resolved


SOURCE_CONFIG = {
    "stowa": {
        "dataset_sleutel": "stowa-limnodata-meijendel",
        "titel": "STOWA Limnodata binnen Meijendel",
        "organisatie": "STOWA; Hoogheemraadschap van Delfland en Rijnland",
        "doi": "10.15468/ennulm",
        "licentie": "CC BY 4.0",
        "bestand": "stowa_limnodata.zip",
        "sha256": "a77a07107ed7c196777b7290d50f83d8114e41ff131c12879755d95c3efd1717",
        "versie": "2020-04-14",
        "selectie": "Exacte puntselectie binnen het Meijendel-basisgebied; positieve resultaten per bemonstering en meeteenheid.",
    },
    "endure": {
        "dataset_sleutel": "endure-helmduinfauna-meijendel-2018",
        "titel": "ENDURE helmduinfauna Meijendel 2018",
        "organisatie": "Universiteit Gent en ENDURE",
        "doi": "10.15468/xx2gcp",
        "licentie": "CC BY 4.0",
        "bestand": "endure.zip",
        "sha256": "9f7a4d95da6f04e9aa4f5eeae61a17dd9d5a0d5b4ff099248a9861075826a1fc",
        "versie": "1.8 / 2026-08-10",
        "selectie": "Vijftien exacte meetpunten binnen het basisgebied; veertien complete aanwezigheids-afwezigheidsmatrices.",
    },
    "nmr": {
        "dataset_sleutel": "nmr-vlinders-meijendel",
        "titel": "NMR vlinder- en motcollectie Meijendel",
        "organisatie": "Natuurhistorisch Museum Rotterdam",
        "doi": "10.15468/czfn9y",
        "licentie": "CC BY 4.0",
        "bestand": "nmr_observations.zip",
        "sha256": "4791aafa76259643b7045d927f1d39f995532e24cc4dcdeccf30e173446b0673",
        "versie": "download 2026-09-26",
        "selectie": "Alleen gedateerde, unieke records met een expliciete Meijendel- of Bierlap-etiketplaats binnen het basisgebied.",
    },
    "botany": {
        "dataset_sleutel": "naturalis-botany-meijendel",
        "titel": "Naturalis Botany specimens Meijendel",
        "organisatie": "Naturalis Biodiversity Center",
        "doi": "10.15468/ib5ypt",
        "licentie": "CC0 1.0",
        "bestand": "naturalis_botany.zip",
        "sha256": "2d40dde338bac879499dbe5ff68da7ef56aca04401541b87d813bbd4af3175b5",
        "versie": "2026-09-24",
        "selectie": "Alleen gedateerde, unieke specimens met een expliciete Meijendel-deelgebied-etiketplaats binnen het basisgebied.",
    },
    "coleoptera": {
        "dataset_sleutel": "naturalis-coleoptera-meijendel",
        "titel": "Naturalis Coleoptera specimens Meijendel",
        "organisatie": "Naturalis Biodiversity Center",
        "doi": "10.15468/jrjojf",
        "licentie": "CC0 1.0",
        "bestand": "naturalis_coleoptera.zip",
        "sha256": "19611eead96004ff51e12f8415159e23a6e75e23a30cfb190fcb89262f282ebc",
        "versie": "2026-09-24",
        "selectie": "Alleen gedateerde, unieke specimens met een expliciete Meijendel-deelgebied-etiketplaats binnen het basisgebied.",
    },
    "lvd": {
        "dataset_sleutel": "lvd-meijendel-v1-6",
        "titel": "Landelijke Vegetatie Databank Meijendelselectie",
        "organisatie": "Wageningen Environmental Research",
        "doi": "10.15468/ksqxep",
        "licentie": "CC BY 4.0",
        "bestand": "lvd.zip",
        "sha256": "84095fedcf3e13e1b7fc8888a5e7fea136360bbb4db7836d560faffb7f869886",
        "versie": "1.6 / 2016-07-14",
        "selectie": "Alleen opnamen waarvan de gepubliceerde coördinaatonzekerheid maximaal 50 meter is en het punt binnen het basisgebied ligt.",
    },
}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def stowa_event_key(row: dict[str, str]) -> str:
    return "|".join(
        (row.get("fieldNumber", ""), row.get("eventDate", ""), row.get("decimalLatitude", ""), row.get("decimalLongitude", ""))
    )


def admit_museum_row(row: dict[str, str]) -> bool:
    return bool(
        row.get("_binnen_basisgebied") == "1"
        and row.get("_expliciet_meijendel") == "1"
        and (row.get("eventDate") or row.get("_jaar"))
        and (row.get("occurrenceID") or row.get("_core_id"))
    )


def admit_lvd_event(row: dict[str, str]) -> bool:
    try:
        return float(row.get("coordinateUncertaintyInMeters", "")) <= 50
    except (TypeError, ValueError):
        return False


def as_float(value: str | None):
    if value in (None, ""):
        return None
    try:
        return float(value)
    except ValueError:
        return None


def as_int(value: str | None):
    number = as_float(value)
    return int(number) if number is not None else None


def event_period(value: str | None, year: str | None):
    value = (value or "").strip()
    exact = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})", value)
    if exact:
        return value, value, "exact"
    interval = re.fullmatch(r"(\d{4}-\d{2}-\d{2})/(\d{4}-\d{2}-\d{2})", value)
    if interval:
        return interval.group(1), interval.group(2), "interval"
    month = re.fullmatch(r"(\d{4})-(\d{2})-?", value)
    if month:
        last = calendar.monthrange(int(month.group(1)), int(month.group(2)))[1]
        prefix = f"{month.group(1)}-{month.group(2)}"
        return f"{prefix}-01", f"{prefix}-{last:02d}", "maand"
    if year and str(year).isdigit():
        return f"{year}-01-01", f"{year}-12-31", "jaar"
    return None, None, "onbekend"


def compact_json(row: dict[str, str]) -> str:
    return json.dumps(row, ensure_ascii=False, separators=(",", ":"))


def museum_canonical_name(row: dict[str, str]) -> str:
    source = (row.get("scientificName") or row.get("verbatimIdentification") or "onbekend").strip()
    authorship = (row.get("scientificNameAuthorship") or "").strip()
    if authorship and source.endswith(authorship):
        source = source[: -len(authorship)].strip()
    source = re.sub(r"^([A-ZÀ-ÖØ-Þ][^\s]+)\s+\([A-ZÀ-ÖØ-Þ][^)]+\)\s+", r"\1 ", source)
    rank = (row.get("taxonRank") or "").lower()
    if rank in {"species", "sp."}:
        words = source.split()
        if len(words) >= 2:
            return " ".join(words[:2])
    source = re.sub(r"\s+\([^)]*,?\s*\d{4}\)\s*$", "", source)
    source = re.sub(r"\s+[A-ZÀ-ÖØ-Þ][^,]*,?\s*\d{4}\s*$", "", source)
    return source.strip()


def mysql_field(value) -> str:
    if value is None:
        return r"\N"
    return str(value).replace("\\", "\\\\").replace("\t", r"\t").replace("\n", r"\n").replace("\r", r"\r")


def write_tsv(path: Path, header: tuple[str, ...], rows) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write("\t".join(header) + "\n")
        for row in rows:
            handle.write("\t".join(mysql_field(value) for value in row) + "\n")


def museum_event_row(source_key: str, row: dict[str, str]):
    config = SOURCE_CONFIG[source_key]
    occurrence_id = row.get("occurrenceID") or row.get("_core_id")
    return (
        config["dataset_sleutel"], occurrence_id, *event_period(row.get("eventDate"), row.get("_jaar")),
        as_int(row.get("_jaar")), as_float(row.get("decimalLatitude")),
        as_float(row.get("decimalLongitude")), as_float(row.get("coordinateUncertaintyInMeters")),
        row.get("locality") or row.get("verbatimLocality") or None,
        "meijendel_gebiedslabel", row.get("samplingProtocol") or None, None, None,
        "collectiecontext", compact_json(row),
    )


def museum_result_row(source_key: str, row: dict[str, str]):
    config = SOURCE_CONFIG[source_key]
    occurrence_id = row.get("occurrenceID") or row.get("_core_id")
    source_name = row.get("scientificName") or row.get("verbatimIdentification") or "onbekend"
    return (
        config["dataset_sleutel"], occurrence_id, occurrence_id,
        museum_canonical_name(row), source_name,
        row.get("vernacularName") or None, row.get("taxonRank") or None, "present",
        as_float(row.get("individualCount") or row.get("organismQuantity")),
        row.get("individualCount") or row.get("organismQuantity") or None,
        row.get("organismQuantityType") or "individuals",
        row.get("basisOfRecord") or None, row.get("catalogNumber") or None, compact_json(row),
    )


def dataset_row(config: dict[str, str]):
    return (
        config["dataset_sleutel"], config["titel"], config["organisatie"], config["doi"],
        config["licentie"], config["bestand"], config["sha256"], config["versie"],
        config["selectie"], IMPORT_VERSION,
    )


def write_import_files(
    target: Path,
    *,
    stowa_rows: list[dict[str, str]],
    stowa_measurements: dict[str, tuple[str, str, str]],
    endure_events: list[dict[str, str]],
    endure_results: list[dict[str, str]],
    museum_sources: dict[str, tuple[list[dict[str, str]], dict[str, str]]],
    lvd_events: list[dict[str, str]],
    lvd_releves: dict[str, dict[str, str]],
    lvd_occurrences: list[dict[str, str]],
) -> dict[str, Path]:
    target.mkdir(parents=True, exist_ok=True)
    used_configs = []
    events = []
    results = []

    if stowa_rows:
        used_configs.append(SOURCE_CONFIG["stowa"])
        seen_events = set()
        for row in stowa_rows:
            key = stowa_event_key(row)
            if key not in seen_events:
                seen_events.add(key)
                events.append((
                    SOURCE_CONFIG["stowa"]["dataset_sleutel"], key,
                    *event_period(row.get("eventDate"), row.get("_jaar")),
                    as_int(row.get("_jaar")), as_float(row.get("decimalLatitude")),
                    as_float(row.get("decimalLongitude")), as_float(row.get("coordinateUncertaintyInMeters")),
                    row.get("locality") or None, "punt_binnen_50m", row.get("samplingProtocol") or None,
                    None, None, "positieve_resultaten_alleen", compact_json(row),
                ))
            occurrence_id = row.get("occurrenceID") or row.get("_core_id")
            measurement = stowa_measurements.get(row.get("_core_id", ""), ("", "", ""))
            results.append((
                SOURCE_CONFIG["stowa"]["dataset_sleutel"], key, occurrence_id,
                row.get("scientificName") or "onbekend", row.get("scientificName") or "onbekend",
                None, row.get("taxonRank") or None,
                "present", as_float(measurement[0] or row.get("individualCount")),
                measurement[0] or row.get("individualCount") or None,
                measurement[1] or measurement[2] or None, row.get("basisOfRecord") or None,
                row.get("catalogNumber") or None, compact_json(row),
            ))

    if endure_events:
        used_configs.append(SOURCE_CONFIG["endure"])
        result_events = {row.get("_core_id") for row in endure_results}
        for row in endure_events:
            source_id = row.get("eventID") or row.get("_core_id")
            events.append((
                SOURCE_CONFIG["endure"]["dataset_sleutel"], source_id,
                *event_period(row.get("eventDate"), row.get("_jaar")), as_int(row.get("_jaar")),
                as_float(row.get("decimalLatitude")), as_float(row.get("decimalLongitude")),
                as_float(row.get("coordinateUncertaintyInMeters")), None, "punt_binnen_50m",
                row.get("samplingProtocol") or None, as_float(row.get("sampleSizeValue")),
                row.get("sampleSizeUnit") or None,
                "volledig_bezoek" if source_id in result_events else "geen_resultaatmatrix",
                compact_json(row),
            ))
        for row in endure_results:
            source_id = row.get("eventID") or row.get("_core_id")
            results.append((
                SOURCE_CONFIG["endure"]["dataset_sleutel"], source_id,
                row.get("occurrenceID") or f"{source_id}|{row.get('scientificName','')}",
                row.get("scientificName") or row.get("verbatimIdentification") or "onbekend",
                row.get("scientificName") or row.get("verbatimIdentification") or "onbekend",
                None, row.get("taxonRank") or None,
                "absent" if row.get("occurrenceStatus") == "absent" else "present",
                as_float(row.get("individualCount")), row.get("individualCount") or None,
                "individuals", row.get("basisOfRecord") or None, None, compact_json(row),
            ))

    for source_key, (source_rows, config) in museum_sources.items():
        admitted = [row for row in source_rows if admit_museum_row(row)]
        if not admitted:
            continue
        used_configs.append(config)
        seen = set()
        for row in admitted:
            occurrence_id = row.get("occurrenceID") or row.get("_core_id")
            if occurrence_id in seen:
                continue
            seen.add(occurrence_id)
            events.append(museum_event_row(source_key, row))
            results.append(museum_result_row(source_key, row))

    admitted_lvd = [row for row in lvd_events if admit_lvd_event(row)]
    if admitted_lvd:
        used_configs.append(SOURCE_CONFIG["lvd"])
        admitted_ids = {row.get("eventID") or row.get("_core_id") for row in admitted_lvd}
        for row in admitted_lvd:
            event_id = row.get("eventID") or row.get("_core_id")
            metadata = dict(row)
            metadata["releve"] = lvd_releves.get(event_id, {})
            events.append((
                SOURCE_CONFIG["lvd"]["dataset_sleutel"], event_id,
                *event_period(row.get("eventDate"), row.get("_jaar")),
                as_int(row.get("_jaar")), as_float(row.get("decimalLatitude")),
                as_float(row.get("decimalLongitude")), as_float(row.get("coordinateUncertaintyInMeters")),
                None, "punt_binnen_50m", row.get("samplingProtocol") or None,
                as_float(row.get("sampleSizeValue")), row.get("sampleSizeUnit") or None,
                "volledig_bezoek", compact_json(metadata),
            ))
        for row in lvd_occurrences:
            event_id = row.get("eventID") or row.get("_core_id")
            if event_id not in admitted_ids:
                continue
            results.append((
                SOURCE_CONFIG["lvd"]["dataset_sleutel"], event_id,
                row.get("occurrenceID") or f"{event_id}|{row.get('scientificName','')}",
                row.get("scientificName") or "onbekend", row.get("scientificName") or "onbekend",
                row.get("vernacularName") or None,
                row.get("taxonomicStatus") or None, "present",
                as_float(row.get("organismQuantity") or row.get("individualCount")),
                row.get("organismQuantity") or row.get("individualCount") or None,
                row.get("organismQuantityType") or None, row.get("basisOfRecord") or None,
                None, compact_json(row),
            ))

    unique_configs = {config["dataset_sleutel"]: config for config in used_configs}
    paths = {name: target / f"{name}.tsv" for name in ("datasets", "events", "results")}
    write_tsv(paths["datasets"], (
        "dataset_sleutel", "titel", "bronorganisatie", "doi", "licentie",
        "bronbestand_naam", "bronbestand_sha256", "bronversie", "selectie_omschrijving", "importversie",
    ), (dataset_row(config) for config in unique_configs.values()))
    write_tsv(paths["events"], (
        "dataset_sleutel", "bron_event_id", "event_datum", "event_datum_tot", "datum_precisie",
        "jaar", "latitude", "longitude",
        "coordinate_uncertainty_m", "bron_locatie", "ruimtelijke_klasse", "sampling_protocol",
        "inspanning_waarde", "inspanning_eenheid", "analyse_status", "bronmetadata",
    ), events)
    write_tsv(paths["results"], (
        "dataset_sleutel", "bron_event_id", "bron_occurrence_id", "wetenschappelijke_naam",
        "wetenschappelijke_naam_bron",
        "nederlandse_naam", "taxonrang", "occurrence_status", "hoeveelheid",
        "hoeveelheid_oorspronkelijk", "hoeveelheid_eenheid", "basis_of_record",
        "catalogusnummer", "bronmetadata",
    ), results)
    return paths


def sql_path(path: Path) -> str:
    return str(path.resolve()).replace("\\", "\\\\").replace("'", "''")


def load_sql(paths: dict[str, Path], database: str = DATABASE) -> str:
    datasets, events, results = (sql_path(paths[key]) for key in ("datasets", "events", "results"))
    return f"""
USE {database};
START TRANSACTION;
CREATE TEMPORARY TABLE tmp_external_dataset LIKE externe_ecologie_dataset;
ALTER TABLE tmp_external_dataset DROP COLUMN dataset_id, DROP COLUMN geimporteerd_op;
LOAD DATA LOCAL INFILE '{datasets}' INTO TABLE tmp_external_dataset
CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\'
LINES TERMINATED BY '\\n' IGNORE 1 LINES;
INSERT INTO externe_ecologie_dataset (
  dataset_sleutel,titel,bronorganisatie,doi,licentie,bronbestand_naam,
  bronbestand_sha256,bronversie,selectie_omschrijving,importversie
) SELECT dataset_sleutel,titel,bronorganisatie,doi,licentie,bronbestand_naam,
  bronbestand_sha256,bronversie,selectie_omschrijving,importversie
FROM tmp_external_dataset
ON DUPLICATE KEY UPDATE titel=VALUES(titel),bronorganisatie=VALUES(bronorganisatie),
  doi=VALUES(doi),licentie=VALUES(licentie),bronbestand_naam=VALUES(bronbestand_naam),
  bronbestand_sha256=VALUES(bronbestand_sha256),bronversie=VALUES(bronversie),
  selectie_omschrijving=VALUES(selectie_omschrijving),importversie=VALUES(importversie);

DELETE e FROM externe_ecologie_event e
JOIN externe_ecologie_dataset d ON d.dataset_id=e.dataset_id
JOIN tmp_external_dataset t ON t.dataset_sleutel=d.dataset_sleutel;

CREATE TEMPORARY TABLE tmp_external_event (
  dataset_sleutel VARCHAR(128), bron_event_id VARCHAR(512), event_datum DATE,
  event_datum_tot DATE, datum_precisie VARCHAR(16),
  jaar SMALLINT UNSIGNED, latitude DECIMAL(10,7), longitude DECIMAL(10,7),
  coordinate_uncertainty_m DECIMAL(12,2), bron_locatie VARCHAR(1000),
  ruimtelijke_klasse VARCHAR(64), sampling_protocol VARCHAR(1000),
  inspanning_waarde DECIMAL(18,6), inspanning_eenheid VARCHAR(128),
  analyse_status VARCHAR(64), bronmetadata JSON
);
LOAD DATA LOCAL INFILE '{events}' INTO TABLE tmp_external_event
CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\'
LINES TERMINATED BY '\\n' IGNORE 1 LINES;
INSERT INTO externe_ecologie_event (
  dataset_id,bron_event_id,event_datum,event_datum_tot,datum_precisie,jaar,latitude,longitude,
  coordinate_uncertainty_m,bron_locatie,ruimtelijke_klasse,sampling_protocol,
  inspanning_waarde,inspanning_eenheid,analyse_status,bronmetadata
) SELECT d.dataset_id,t.bron_event_id,t.event_datum,t.event_datum_tot,t.datum_precisie,t.jaar,t.latitude,t.longitude,
  t.coordinate_uncertainty_m,t.bron_locatie,t.ruimtelijke_klasse,t.sampling_protocol,
  t.inspanning_waarde,t.inspanning_eenheid,t.analyse_status,t.bronmetadata
FROM tmp_external_event t
JOIN externe_ecologie_dataset d ON d.dataset_sleutel=t.dataset_sleutel;

CREATE TEMPORARY TABLE tmp_external_result (
  dataset_sleutel VARCHAR(128), bron_event_id VARCHAR(512), bron_occurrence_id VARCHAR(512),
  wetenschappelijke_naam VARCHAR(500), wetenschappelijke_naam_bron VARCHAR(500),
  nederlandse_naam VARCHAR(500), taxonrang VARCHAR(128),
  occurrence_status VARCHAR(16), hoeveelheid DECIMAL(24,8), hoeveelheid_oorspronkelijk VARCHAR(255),
  hoeveelheid_eenheid VARCHAR(128), basis_of_record VARCHAR(128), catalogusnummer VARCHAR(255),
  bronmetadata JSON
);
LOAD DATA LOCAL INFILE '{results}' INTO TABLE tmp_external_result
CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\'
LINES TERMINATED BY '\\n' IGNORE 1 LINES;
INSERT INTO externe_ecologie_resultaat (
  event_id,bron_occurrence_id,wetenschappelijke_naam,wetenschappelijke_naam_bron,nederlandse_naam,taxonrang,
  occurrence_status,hoeveelheid,hoeveelheid_oorspronkelijk,hoeveelheid_eenheid,
  basis_of_record,catalogusnummer,bronmetadata
) SELECT e.event_id,t.bron_occurrence_id,t.wetenschappelijke_naam,t.wetenschappelijke_naam_bron,t.nederlandse_naam,t.taxonrang,
  t.occurrence_status,t.hoeveelheid,t.hoeveelheid_oorspronkelijk,t.hoeveelheid_eenheid,
  t.basis_of_record,t.catalogusnummer,t.bronmetadata
FROM tmp_external_result t
JOIN externe_ecologie_dataset d ON d.dataset_sleutel=t.dataset_sleutel
JOIN externe_ecologie_event e ON e.dataset_id=d.dataset_id AND e.bron_event_id=t.bron_event_id;
COMMIT;
"""


PQ_MOVES = {
    'externe_ecologie_event': 'pq_vegetatie_bronopname',
    'externe_ecologie_resultaat': 'pq_vegetatie_bronresultaat',
    'externe_ecologie_overlap': 'pq_vegetatie_bronoverlap',
}


def pq_row_expression(columns: list[dict], alias: str) -> str:
    """Dezelfde typevaste, bytegevoelige rijrepresentatie vóór en na verplaatsing."""
    parts = []
    for column in columns:
        name, datatype = column['name'], column['type']
        if not re.fullmatch(r'[a-zA-Z0-9_]+', name):
            raise ValueError('Onverwachte kolomidentificatie')
        value = f'{alias}.`{name}`'
        if datatype in {'decimal', 'date', 'datetime', 'timestamp', 'time'}:
            value = f'CAST({value} AS CHAR)'
        elif datatype in {'binary', 'varbinary', 'blob', 'longblob'}:
            value = f'HEX({value})'
        parts.extend((f"'{name}'", value))
    return 'JSON_OBJECT(' + ','.join(parts) + ')'


def prepare_pq_migration(client: Path, args: list[str]) -> dict:
    """Lees één bronsnapshot; kies alleen reeds vastgelegde LVD/PQ-kandidaten."""
    from run_external_ecology_overlap_audit import compare_pq_recordings
    read_args = [*args, '--batch', '--raw', '--skip-column-names', '--default-character-set=utf8mb4']
    tables = [*PQ_MOVES, 'pq_vegetatie_taxon', 'externe_ecologie_dataset']
    quoted = ','.join(f"'{table}'" for table in tables)
    metadata = run_mysql(client, read_args,
        "SELECT JSON_OBJECT('table',TABLE_NAME,'name',COLUMN_NAME,'type',DATA_TYPE,'key',COLUMN_KEY) "
        f"FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ({quoted}) "
        "ORDER BY TABLE_NAME,ORDINAL_POSITION")
    columns = {table: [] for table in tables}
    for line in metadata.splitlines():
        column = json.loads(line)
        columns[column.pop('table')].append(column)
    if any(not cols for cols in columns.values()):
        raise ValueError('De oorspronkelijke PQ-/LVD-brontabellen ontbreken')
    scope = """SELECT DISTINCT r.event_id FROM externe_ecologie_overlap x
      JOIN externe_ecologie_resultaat r USING(resultaat_id)
      JOIN externe_ecologie_event e USING(event_id)
      JOIN externe_ecologie_dataset d USING(dataset_id)
      WHERE x.doelsysteem='provinciale_pq' AND d.dataset_sleutel='lvd-meijendel-v1-6'"""
    where = {
        'externe_ecologie_event': f's.event_id IN ({scope})',
        'externe_ecologie_resultaat': f's.event_id IN ({scope})',
        'externe_ecologie_overlap': f's.resultaat_id IN (SELECT resultaat_id FROM externe_ecologie_resultaat WHERE event_id IN ({scope}))',
        'externe_ecologie_dataset': "s.dataset_sleutel='lvd-meijendel-v1-6'",
        'pq_vegetatie_taxon': 'TRUE',
    }
    statements = ['SET NAMES utf8mb4;', 'SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;',
                  'START TRANSACTION READ ONLY, WITH CONSISTENT SNAPSHOT;']
    for table in tables:
        expression = pq_row_expression(columns[table], 's')
        primary = next(c['name'] for c in columns[table] if c['key'] == 'PRI')
        statements.append(f"SELECT JSON_OBJECT('table','{table}','row',{expression},"
                          f"'hash',SHA2(CAST({expression} AS CHAR),256)) FROM `{table}` s "
                          f"WHERE {where[table]} ORDER BY s.`{primary}`;")
    statements.append("""SELECT JSON_OBJECT('table','registry','row',JSON_OBJECT(
      'koppeling_id',koppeling_id,'taxon_id',taxon_id,'bron_systeem',bron_systeem,
      'bron_dataset',bron_dataset,'bron_versie',bron_versie,'bron_taxon_id',bron_taxon_id,
      'bronmetadata',bronmetadata,'koppelstatus',koppelstatus,'ingetrokken_op',ingetrokken_op))
      FROM taxa_bronkoppeling WHERE bron_systeem='Meijendel'
        AND bron_dataset IN ('pq_vegetatie_taxon','lvd-meijendel-v1-6')
        AND ingetrokken_op IS NULL ORDER BY koppeling_id;""")
    statements.append("""SELECT JSON_OBJECT('table','province','row',JSON_OBJECT(
      'opname_id',w.opname_id,'name',t.latijnse_naam_bron,'code',w.abundantie_code,
      'quantity',CAST(w.abundantie_percentage AS CHAR)))
      FROM pq_vegetatie_waarneming w JOIN pq_vegetatie_taxon t USING(taxon_id)
      ORDER BY w.waarneming_id;""")
    statements.append("""SELECT DISTINCT JSON_OBJECT('table','pairs','row',JSON_OBJECT(
      'event_id',r.event_id,'opname_id',p.opname_id,'date',CAST(p.opname_datum AS CHAR),
      'distance_m',ROUND(ST_Distance(p.geom,ST_Transform(ST_SRID(Point(e.longitude,e.latitude),4326),28992)),3),
      'date_precision',e.datum_precisie,'source_uncertainty_m',e.coordinate_uncertainty_m))
      FROM externe_ecologie_overlap x JOIN externe_ecologie_resultaat r USING(resultaat_id)
      JOIN externe_ecologie_event e USING(event_id) JOIN externe_ecologie_dataset d USING(dataset_id)
      JOIN pq_vegetatie_opname p ON p.opname_id=CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(x.doelrecord_sleutel,':',2),':',-1) AS UNSIGNED)
      WHERE x.doelsysteem='provinciale_pq' AND d.dataset_sleutel='lvd-meijendel-v1-6';""")
    statements.append('ROLLBACK;')
    raw = run_mysql(client, read_args, '\n'.join(statements))
    collected, hashes = defaultdict(list), defaultdict(dict)
    for line in raw.splitlines():
        item = json.loads(line)
        table, row = item['table'], item['row']
        collected[table].append(row)
        if 'hash' in item:
            primary = next(c['name'] for c in columns[table] if c['key'] == 'PRI')
            hashes[table][row[primary]] = item['hash']
    dataset, = collected['externe_ecologie_dataset']
    if dataset['bronbestand_sha256'] != SOURCE_CONFIG['lvd']['sha256']:
        raise ValueError('LVD-bronversie gewijzigd; eerst opnieuw beoordelen')
    pq_links = resolve_pq_taxon_links(collected['pq_vegetatie_taxon'], collected['registry'])
    lvd_links = resolve_external_taxon_links(collected['externe_ecologie_resultaat'], collected['registry'],
        dataset['dataset_sleutel'], dataset['bronversie'] + '; sha256:' + dataset['bronbestand_sha256'])
    province, lvd = defaultdict(list), defaultdict(list)
    for row in collected['province']:
        province[row['opname_id']].append(row)
    import ast
    for row in collected['externe_ecologie_resultaat']:
        raw_properties = row['bronmetadata'].get('dynamicProperties') or '{}'
        properties = ast.literal_eval(raw_properties)
        if not isinstance(properties, dict):
            raise ValueError('LVD-bedekkingsmetadata hebben geen objectvorm')
        lvd[row['event_id']].append({'name': row['wetenschappelijke_naam'],
            'code': properties.get('coverScaleCode'), 'quantity': row['hoeveelheid'],
            'layer': row['bronmetadata'].get('layer')})
    pairs = [dict(pair, **compare_pq_recordings(province[pair['opname_id']], lvd[pair['event_id']]))
             for pair in collected['pairs']]
    if not pairs or set(lvd) != {pair['event_id'] for pair in pairs}:
        raise ValueError('Niet iedere bronopname heeft een provinciale kandidaat')
    return {'version': 'pq-integratie-v1', 'columns': columns,
            'tables': {table: collected[table] for table in tables}, 'hashes': dict(hashes),
            'pq_links': pq_links, 'lvd_links': lvd_links, 'pairs': pairs,
            'registry': collected['registry'],
            'input_sha256': hashlib.sha256(raw.encode()).hexdigest()}


def pq_migration_sql(plan: dict, *, commit: bool = False) -> str:
    """Kopiëren, iedere oorspronkelijke cel bewijzen, dan pas bronregels verwijderen.

    Een MySQL CHECK-fout breekt de client af; disconnect rolt de open transactie
    terug. DDL voor blijvende tabellen en catalogusverwijdering horen hier niet in.
    """
    if plan['version'] != 'pq-integratie-v1' or not plan['pairs']:
        raise ValueError('Onbekend of leeg PQ-migratieplan')

    def integer(value):
        if isinstance(value, bool) or not str(value).isdigit():
            raise ValueError('Ongeldige numerieke bronidentificatie')
        return str(value)

    def json_value(value):
        payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode().hex()
        return f'CAST(CONVERT(0x{payload} USING utf8mb4) AS JSON)'

    sql = ['SET NAMES utf8mb4;', 'SET SESSION innodb_lock_wait_timeout=10;',
           'SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;',
           "SET @pq_lock=GET_LOCK(CONCAT(DATABASE(),':pq-integratie-v1'),0);",
           'START TRANSACTION;',
           'CREATE TEMPORARY TABLE tmp_pq_guard(ok TINYINT NOT NULL CHECK(ok=1)) ENGINE=InnoDB;']

    def guard(condition):
        sql.append(f'INSERT INTO tmp_pq_guard VALUES(IF(({condition}),1,0));')

    def insert(table, rows):
        for offset in range(0, len(rows), 500):
            sql.append(f'INSERT INTO {table} VALUES ' + ','.join(rows[offset:offset + 500]) + ';')

    guard('@pq_lock=1')
    for target in [*PQ_MOVES.values(), 'pq_vegetatie_opname_bronkoppeling']:
        guard(f'(SELECT COUNT(*) FROM {target})=0')
    guard('(SELECT COUNT(*) FROM pq_vegetatie_waarneming WHERE taxon_bronkoppeling_id IS NOT NULL)=0')
    sql.extend([
        'CREATE TEMPORARY TABLE tmp_pq_events(id BIGINT UNSIGNED PRIMARY KEY) ENGINE=InnoDB;',
        'CREATE TEMPORARY TABLE tmp_pq_results(id BIGINT UNSIGNED PRIMARY KEY,koppeling_id BIGINT UNSIGNED NOT NULL) ENGINE=InnoDB;',
        'CREATE TEMPORARY TABLE tmp_pq_taxa(id INT PRIMARY KEY,koppeling_id BIGINT UNSIGNED NOT NULL) ENGINE=InnoDB;',
        'CREATE TEMPORARY TABLE tmp_pq_hashes(bron VARCHAR(64),id BIGINT UNSIGNED,h CHAR(64),PRIMARY KEY(bron,id)) ENGINE=InnoDB;',
        'CREATE TEMPORARY TABLE tmp_pq_registry(id BIGINT UNSIGNED PRIMARY KEY,inhoud JSON NOT NULL) ENGINE=InnoDB;',
    ])
    insert('tmp_pq_events', [f"({integer(r['event_id'])})" for r in plan['tables']['externe_ecologie_event']])
    insert('tmp_pq_results', [f'({integer(k)},{integer(v)})' for k, v in plan['lvd_links'].items()])
    insert('tmp_pq_taxa', [f'({integer(k)},{integer(v)})' for k, v in plan['pq_links'].items()])
    registry_keys = tuple(plan['registry'][0])
    insert('tmp_pq_registry', [f"({integer(r['koppeling_id'])},{json_value(r)})" for r in plan['registry']])
    registry_expression = 'JSON_OBJECT(' + ','.join(f"'{key}',b.`{key}`" for key in registry_keys) + ')'
    guard('(SELECT COUNT(*) FROM tmp_pq_registry x LEFT JOIN taxa_bronkoppeling b ON b.koppeling_id=x.id '
          f'WHERE b.koppeling_id IS NULL OR NOT(CAST({registry_expression} AS BINARY)<=>CAST(x.inhoud AS BINARY)))=0')
    for table, hashes in plan['hashes'].items():
        if table not in {*PQ_MOVES, 'pq_vegetatie_taxon', 'externe_ecologie_dataset'}:
            raise ValueError('Onverwachte brontabel in migratieplan')
        for digest in hashes.values():
            if not re.fullmatch('[0-9a-f]{64}', digest):
                raise ValueError('Ongeldige bronhash')
        insert('tmp_pq_hashes', [f"('{table}',{integer(key)},'{digest}')" for key, digest in hashes.items()])
        primary = next(c['name'] for c in plan['columns'][table] if c['key'] == 'PRI')
        expression = pq_row_expression(plan['columns'][table], 's')
        guard(f"(SELECT COUNT(*) FROM tmp_pq_hashes x LEFT JOIN `{table}` s ON s.`{primary}`=x.id "
              f"WHERE x.bron='{table}' AND (s.`{primary}` IS NULL OR SHA2(CAST({expression} AS CHAR),256)<>x.h))=0")
    n_events = len(plan['tables']['externe_ecologie_event'])
    n_results = len(plan['tables']['externe_ecologie_resultaat'])
    n_overlap = len(plan['tables']['externe_ecologie_overlap'])
    guard(f'(SELECT COUNT(*) FROM externe_ecologie_resultaat r JOIN tmp_pq_events x ON x.id=r.event_id)={n_results}')
    guard(f'(SELECT COUNT(*) FROM externe_ecologie_overlap o JOIN tmp_pq_results x ON x.id=o.resultaat_id)={n_overlap}')
    sql.append('UPDATE pq_vegetatie_waarneming w JOIN tmp_pq_taxa x ON x.id=w.taxon_id '
               'SET w.taxon_bronkoppeling_id=x.koppeling_id;')
    guard('(SELECT COUNT(*) FROM pq_vegetatie_waarneming WHERE taxon_bronkoppeling_id IS NULL)=0')
    for table, target in PQ_MOVES.items():
        column_names = ','.join('`' + c['name'] + '`' for c in plan['columns'][table])
        select_names = ','.join('s.`' + c['name'] + '`' for c in plan['columns'][table])
        if table == 'externe_ecologie_event':
            extra_columns, extra_values, join = ',zelfstandig_meetellen', ',0', 'tmp_pq_events x ON x.id=s.event_id'
        elif table == 'externe_ecologie_resultaat':
            extra_columns, extra_values, join = ',taxon_bronkoppeling_id', ',x.koppeling_id', 'tmp_pq_results x ON x.id=s.resultaat_id'
        else:
            extra_columns, extra_values, join = '', '', 'tmp_pq_results x ON x.id=s.resultaat_id'
        sql.append(f'INSERT INTO {target}({column_names}{extra_columns}) '
                   f'SELECT {select_names}{extra_values} FROM {table} s JOIN {join};')
        primary = next(c['name'] for c in plan['columns'][table] if c['key'] == 'PRI')
        expression = pq_row_expression(plan['columns'][table], 's')
        guard(f"(SELECT COUNT(*) FROM tmp_pq_hashes x LEFT JOIN {target} s ON s.`{primary}`=x.id "
              f"WHERE x.bron='{table}' AND (s.`{primary}` IS NULL OR SHA2(CAST({expression} AS CHAR),256)<>x.h))=0")
    insert('pq_vegetatie_opname_bronkoppeling(event_id,opname_id,koppelstatus,regelversie,bewijs)',
        [f"({integer(p['event_id'])},{integer(p['opname_id'])},'vermoedelijk','pq-integratie-v1',{json_value(p)})"
         for p in plan['pairs']])
    for table, expected in [('pq_vegetatie_bronopname', n_events), ('pq_vegetatie_bronresultaat', n_results),
                            ('pq_vegetatie_bronoverlap', n_overlap), ('pq_vegetatie_opname_bronkoppeling', len(plan['pairs']))]:
        guard(f'(SELECT COUNT(*) FROM {table})={expected}')
    # Alleen volledig bewaarde opnamen; de twee bekende CASCADE-relaties verwijderen
    # hun resultaten en overlapregels. Onbekende verwijzende tabellen blokkeren vooraf.
    guard("(SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() "
          "AND REFERENCED_TABLE_NAME IN ('externe_ecologie_event','externe_ecologie_resultaat') "
          "AND TABLE_NAME NOT IN ('externe_ecologie_resultaat','externe_ecologie_overlap'))=0")
    sql.append('DELETE e FROM externe_ecologie_event e JOIN tmp_pq_events x ON x.id=e.event_id;')
    guard('(SELECT COUNT(*) FROM externe_ecologie_event e JOIN tmp_pq_events x ON x.id=e.event_id)=0')
    guard('(SELECT COUNT(*) FROM externe_ecologie_resultaat r JOIN tmp_pq_events x ON x.id=r.event_id)=0')
    guard('(SELECT COUNT(*) FROM externe_ecologie_overlap o JOIN tmp_pq_results x ON x.id=o.resultaat_id)=0')
    sql.append('COMMIT;' if commit else 'ROLLBACK;')
    sql.append("DO RELEASE_LOCK(CONCAT(DATABASE(),':pq-integratie-v1'));")
    return '\n'.join(sql)


def pq_schema_sql() -> str:
    """Bronvarianten van Event/Occurrence en expliciete ResourceRelationship.

    CREATE LIKE behoudt alle bestaande bronkolommen en hun precisie. MySQL
    kopieert hierbij geen foreign keys; onderstaande sleutels zijn daarom
    expliciet. Geen nieuwe taxoncatalogus en geen nieuw taxonconceptbesluit.
    Een bestaande doelnaam blokkeert bewust een tweede schema-uitvoering.
    """
    return """
SET SESSION lock_wait_timeout=10;
CREATE TABLE pq_vegetatie_bronopname LIKE externe_ecologie_event;
ALTER TABLE pq_vegetatie_bronopname
  ADD COLUMN zelfstandig_meetellen BOOLEAN NOT NULL DEFAULT FALSE,
  ADD CONSTRAINT ck_pq_bronopname_geen_tweede_telling CHECK(zelfstandig_meetellen=0),
  ADD CONSTRAINT fk_pq_bronopname_dataset FOREIGN KEY(dataset_id)
    REFERENCES externe_ecologie_dataset(dataset_id);
CREATE TABLE pq_vegetatie_bronresultaat LIKE externe_ecologie_resultaat;
ALTER TABLE pq_vegetatie_bronresultaat
  ADD COLUMN taxon_bronkoppeling_id BIGINT UNSIGNED NOT NULL,
  ADD CONSTRAINT fk_pq_bronresultaat_opname FOREIGN KEY(event_id)
    REFERENCES pq_vegetatie_bronopname(event_id),
  ADD CONSTRAINT fk_pq_bronresultaat_taxon FOREIGN KEY(taxon_bronkoppeling_id)
    REFERENCES taxa_bronkoppeling(koppeling_id);
CREATE TABLE pq_vegetatie_bronoverlap LIKE externe_ecologie_overlap;
ALTER TABLE pq_vegetatie_bronoverlap
  ADD CONSTRAINT fk_pq_bronoverlap_resultaat FOREIGN KEY(resultaat_id)
    REFERENCES pq_vegetatie_bronresultaat(resultaat_id);
CREATE TABLE pq_vegetatie_opname_bronkoppeling (
  event_id BIGINT UNSIGNED NOT NULL,
  opname_id INT NOT NULL,
  koppelstatus ENUM('vermoedelijk','bevestigd','afgewezen') NOT NULL,
  regelversie VARCHAR(128) CHARACTER SET ascii NOT NULL,
  bewijs JSON NOT NULL,
  beoordeeld_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY(event_id,opname_id,regelversie),
  CONSTRAINT fk_pq_bronkoppeling_bron FOREIGN KEY(event_id)
    REFERENCES pq_vegetatie_bronopname(event_id),
  CONSTRAINT fk_pq_bronkoppeling_opname FOREIGN KEY(opname_id)
    REFERENCES pq_vegetatie_opname(opname_id),
  CONSTRAINT ck_pq_bronkoppeling_bewijs CHECK(JSON_TYPE(bewijs)='OBJECT')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
ALTER TABLE pq_vegetatie_waarneming
  ADD COLUMN taxon_bronkoppeling_id BIGINT UNSIGNED NULL,
  ADD CONSTRAINT fk_pq_waarneming_centrale_taxon FOREIGN KEY(taxon_bronkoppeling_id)
    REFERENCES taxa_bronkoppeling(koppeling_id);
"""


def pq_analysis_view_sql(*, original_rank: bool = False) -> str:
    """Behoud de bestaande catalogusafnemer, met uitsluitend één fysieke bronkopie."""
    marker = 'CREATE OR REPLACE VIEW v_externe_ecologie_analyse AS'
    base = SCHEMA.read_text(encoding='utf-8').split(marker, 1)[1].strip().removesuffix(';')
    moved, replacements = re.subn(
        r"EXISTS \(\s*SELECT 1\s*FROM externe_ecologie_overlap o.*?\) AS heeft_bekende_overlap",
        '1 AS heeft_bekende_overlap', base, count=1, flags=re.S)
    if replacements != 1:
        raise ValueError('De bestaande analyseview is gewijzigd; opnieuw beoordelen')
    moved = moved.replace('externe_ecologie_event', 'pq_vegetatie_bronopname')
    moved = moved.replace('externe_ecologie_resultaat', 'pq_vegetatie_bronresultaat')
    rank = 't.taxonrang' if original_rank else (
        "CASE WHEN JSON_CONTAINS_PATH(b.bronmetadata,'one','$.register_broncontext') "
        "THEN JSON_VALUE(b.bronmetadata,'$.register_broncontext.taxonrang' "
        "RETURNING CHAR(64) NULL ON EMPTY NULL ON ERROR) ELSE t.taxonrang END")
    moved = moved.replace('r.taxonrang,', rank + ' AS taxonrang,')
    moved += ('\nJOIN taxa_bronkoppeling b ON b.koppeling_id=r.taxon_bronkoppeling_id'
              '\nJOIN taxa t ON t.taxon_id=b.taxon_id')
    return marker + '\n' + base + '\nUNION ALL\n' + moved + ';\n'


def pq_finalize_sql() -> str:
    """Eenmalige DDL-afronding, pas na geteste bronverplaatsing en herstelbewijs."""
    fields = ('taxon_id', 'nederlandse_naam', 'latijnse_naam_bron', 'srtnum',
              'taxonlijst_versie', 'taxoncode_officieel', 'wetenschappelijke_naam_officieel',
              'taxon_koppeling_status')
    original = 'JSON_OBJECT(' + ','.join(f"'{k}',q.`{k}`" for k in fields) + ')'
    retained = 'JSON_OBJECT(' + ','.join(f"'{k}',JSON_EXTRACT(b.bronmetadata,'$.{k}')" for k in fields) + ')'
    sql = f"""
SET NAMES utf8mb4;
SET SESSION lock_wait_timeout=10;
CREATE TEMPORARY TABLE tmp_pq_finalize_guard(ok TINYINT NOT NULL CHECK(ok=1));
CREATE TEMPORARY TABLE tmp_pq_calculated_before AS SELECT * FROM pq_plot_jaar_vegetatie_berekend;
INSERT INTO tmp_pq_finalize_guard VALUES(IF((SELECT COUNT(*) FROM pq_vegetatie_taxon)=714,1,0));
INSERT INTO tmp_pq_finalize_guard VALUES(IF((SELECT COUNT(*) FROM pq_vegetatie_waarneming)=53122,1,0));
INSERT INTO tmp_pq_finalize_guard VALUES(IF((SELECT COUNT(*) FROM pq_vegetatie_waarneming
  WHERE taxon_bronkoppeling_id IS NULL)=0,1,0));
INSERT INTO tmp_pq_finalize_guard VALUES(IF((SELECT COUNT(*) FROM pq_vegetatie_taxon q
  JOIN taxa_bronkoppeling b ON b.bron_systeem='Meijendel' AND b.bron_dataset='pq_vegetatie_taxon'
    AND b.bron_taxon_id=CAST(q.srtnum AS CHAR) AND b.ingetrokken_op IS NULL
  WHERE CAST({original} AS BINARY)=CAST({retained} AS BINARY))=714,1,0));
INSERT INTO tmp_pq_finalize_guard VALUES(IF((SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE
  WHERE TABLE_SCHEMA=DATABASE() AND REFERENCED_TABLE_NAME='pq_vegetatie_taxon'
    AND TABLE_NAME<>'pq_vegetatie_waarneming')=0,1,0));
CREATE OR REPLACE VIEW pq_vegetatie_opname_metrics AS
SELECT o.opname_id,o.pq_nummer,o.jaar,op.plot_id,
  COUNT(DISTINCT q.taxon_id) AS soortenrijkdom,
  SUM(q.abundantie_percentage) AS bedekking_som,
  -SUM(CASE WHEN q.totaal_bedekking>0 AND q.abundantie_percentage>0
    THEN (q.abundantie_percentage/q.totaal_bedekking)*LN(q.abundantie_percentage/q.totaal_bedekking)
    ELSE 0 END) AS shannon
FROM (SELECT w.opname_id,b.taxon_id,w.abundantie_percentage,
    SUM(w.abundantie_percentage) OVER(PARTITION BY w.opname_id) AS totaal_bedekking
  FROM pq_vegetatie_waarneming w JOIN taxa_bronkoppeling b ON b.koppeling_id=w.taxon_bronkoppeling_id) q
JOIN pq_vegetatie_opname o ON o.opname_id=q.opname_id
JOIN pq_vegetatie_opname_plot op ON op.opname_id=o.opname_id
GROUP BY o.opname_id,o.pq_nummer,o.jaar,op.plot_id;
CREATE OR REPLACE VIEW pq_plot_jaar_vegetatie_berekend AS
SELECT m.plot_id,m.jaar,COUNT(DISTINCT m.pq_nummer) AS n_pq,COUNT(*) AS n_opnamen,
  tx.taxa_aantal,ROUND(AVG(m.soortenrijkdom),3) AS soortenrijkdom_gem,
  ROUND(AVG(m.bedekking_som),3) AS bedekking_som_gem,ROUND(AVG(m.shannon),4) AS shannon_gem
FROM pq_vegetatie_opname_metrics m
JOIN (SELECT op.plot_id,o.jaar,COUNT(DISTINCT b.taxon_id) AS taxa_aantal
  FROM pq_vegetatie_opname_plot op JOIN pq_vegetatie_opname o ON o.opname_id=op.opname_id
  JOIN pq_vegetatie_waarneming w ON w.opname_id=o.opname_id
  JOIN taxa_bronkoppeling b ON b.koppeling_id=w.taxon_bronkoppeling_id
  GROUP BY op.plot_id,o.jaar) tx ON tx.plot_id=m.plot_id AND tx.jaar=m.jaar
GROUP BY m.plot_id,m.jaar,tx.taxa_aantal;
INSERT INTO tmp_pq_finalize_guard VALUES(IF((SELECT COUNT(*) FROM pq_plot_jaar_vegetatie_berekend)=513,1,0));
INSERT INTO tmp_pq_finalize_guard VALUES(IF((SELECT COUNT(*) FROM pq_plot_jaar_vegetatie_berekend b
  LEFT JOIN tmp_pq_calculated_before p USING(plot_id,jaar)
  WHERE NOT(b.n_pq<=>p.n_pq AND b.n_opnamen<=>p.n_opnamen AND b.taxa_aantal<=>p.taxa_aantal
    AND b.soortenrijkdom_gem<=>p.soortenrijkdom_gem AND b.bedekking_som_gem<=>p.bedekking_som_gem
    AND b.shannon_gem<=>p.shannon_gem))=0,1,0));
ALTER TABLE pq_vegetatie_waarneming
  DROP FOREIGN KEY fk_pq_vegetatie_waarneming_taxon,
  RENAME COLUMN taxon_id TO bron_taxon_lokaal_id,
  MODIFY COLUMN taxon_bronkoppeling_id BIGINT UNSIGNED NOT NULL,
  DROP INDEX uq_pq_vegetatie_waarneming,
  ADD UNIQUE KEY uq_pq_vegetatie_waarneming(opname_id,taxon_bronkoppeling_id);
DROP TABLE pq_vegetatie_taxon;
ALTER TABLE pq_vegetatie_bronresultaat
  CHANGE COLUMN taxonrang taxonomische_status_aangeleverd VARCHAR(128) NULL
    COMMENT 'Letterlijke waarde uit de voormalige foutief benoemde taxonrang; geen taxonRank';
UPDATE analyse_datareeks SET bronselectie_omschrijving=CONCAT(bronselectie_omschrijving,
  '. PQ-integratie 27 september 2026: volledige vermoedelijke bronopnamen staan onder pq_*; '
  'alle bijbehorende resultaten blijven uitgesloten van zelfstandig meetellen')
WHERE datareeks_sleutel='lvd-meijendel-v1-6';
"""
    return sql + '\n' + pq_analysis_view_sql()


def mysql_args(login_path: str) -> list[str]:
    return [f"--login-path={login_path}", "--protocol=tcp", "--host=127.0.0.1", "--port=3306", "--local-infile=1", "--binary-mode"]


def run_mysql(client: Path, args: list[str], sql: str) -> str:
    result = subprocess.run([str(client), *args], input=sql, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f"mysql stopte met code {result.returncode}")
    return result.stdout.strip()


def apply_sql_with_local_infile(client: Path, args: list[str], sql: str) -> None:
    original = run_mysql(client, args, "SELECT @@GLOBAL.local_infile;")
    changed = original.strip() != "1"
    if changed:
        run_mysql(client, args, "SET GLOBAL local_infile=1;")
    try:
        run_mysql(client, args, sql)
    finally:
        if changed:
            run_mysql(client, args, "SET GLOBAL local_infile=0;")


def guard_legacy_import(client: Path, args: list[str]) -> None:
    """Voorkom herinvoer/verlies van bronvarianten door de historische bulkimport."""
    if run_mysql(client, args,
        "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() "
        "AND TABLE_NAME='pq_vegetatie_bronopname'").strip() != '0':
        raise RuntimeError('PQ-integratie aanwezig: historische bulkimport geblokkeerd. '
                           'Gebruik een bronbewuste aanvulling met centrale taxonkoppeling.')


def pq_snapshot(client: Path, args: list[str], *, migrated: bool = False) -> dict:
    """Controleer alle onaangeraakte tabellen en alle oorspronkelijke provinciale velden."""
    query = lambda sql: run_mysql(client, args, sql)
    tables = query("SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() "
                   "AND TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME").splitlines()
    mutable = {*PQ_MOVES, *PQ_MOVES.values(), 'pq_vegetatie_opname_bronkoppeling',
               'pq_vegetatie_taxon', 'pq_vegetatie_waarneming', 'analyse_datareeks'}
    unchanged = [t for t in tables if t not in mutable]
    if any(not re.fullmatch(r'[A-Za-z0-9_]+', t) for t in unchanged):
        raise ValueError('Onverwachte tabelnaam')
    checksums = query('CHECKSUM TABLE ' + ','.join(f'`{t}`' for t in unchanged) + ' EXTENDED')
    digest = lambda text: hashlib.sha256(text.encode()).hexdigest()
    cols = [json.loads(line) for line in query(
        "SELECT JSON_OBJECT('name',COLUMN_NAME,'type',DATA_TYPE) FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='pq_vegetatie_waarneming' "
        "AND COLUMN_NAME<>'taxon_bronkoppeling_id' ORDER BY ORDINAL_POSITION").splitlines()]
    expression = pq_row_expression(cols, 'w')
    if migrated:
        expression = expression.replace("'bron_taxon_lokaal_id'", "'taxon_id'")
    rows = query(f'SELECT SHA2(CAST({expression} AS CHAR),256) FROM pq_vegetatie_waarneming w ORDER BY waarneming_id')
    sources = query("SELECT * FROM analyse_datareeks WHERE datareeks_sleutel<>'lvd-meijendel-v1-6' ORDER BY datareeks_id")
    return {
        'unchanged_tables': {line.split('\t')[0].split('.',1)[1]: line.split('\t')[1]
                             for line in checksums.splitlines()},
        'province_rows_sha256': digest(rows),
        'other_source_metadata_sha256': digest(sources),
        'public_sha256': digest(query('SELECT * FROM website_plot_vegetatie_jaar ORDER BY plot_id,jaar')),
        'stored_pq_sha256': digest(query('SELECT * FROM pq_plot_jaar_vegetatie ORDER BY plot_id,jaar')),
        'calculated_sha256': digest(query('SELECT * FROM pq_plot_jaar_vegetatie_berekend ORDER BY plot_id,jaar')),
    }


def verify_pq_integration(client: Path, args: list[str], plan: dict, before: dict) -> dict:
    """Onafhankelijke nacontrole, inclusief iedere verplaatste bronrij na de DDL."""
    after = pq_snapshot(client, args, migrated=True)
    if after != before:
        raise RuntimeError('PQ-behoudcontrole mislukt: ' + ', '.join(k for k in before if before[k] != after[k]))
    query = lambda sql: run_mysql(client, args, sql)
    for source, target in PQ_MOVES.items():
        cols = plan['columns'][source]
        key = next(c['name'] for c in cols if c['key'] == 'PRI')
        expression = pq_row_expression(cols, 'r')
        if target == 'pq_vegetatie_bronresultaat':
            expression = expression.replace('r.`taxonrang`', 'r.`taxonomische_status_aangeleverd`')
        actual = {int(line.split('\t')[0]): line.split('\t')[1] for line in query(
            f'SELECT `{key}`,SHA2(CAST({expression} AS CHAR),256) FROM {target} r ORDER BY `{key}`').splitlines()}
        if actual != {int(k): v for k, v in plan['hashes'][source].items()}:
            raise RuntimeError('Niet alle oorspronkelijke bronvelden behouden: ' + source)
    expected = {'pq_vegetatie_bronopname':644, 'pq_vegetatie_bronresultaat':16627,
                'pq_vegetatie_bronoverlap':32657, 'pq_vegetatie_opname_bronkoppeling':652}
    for table, count in expected.items():
        if query(f'SELECT COUNT(*) FROM {table}') != str(count):
            raise RuntimeError('Onverwacht aantal in ' + table)
    zero_queries = [
        "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='pq_vegetatie_taxon'",
        'SELECT COUNT(*) FROM pq_vegetatie_bronopname WHERE zelfstandig_meetellen<>0',
        "SELECT COUNT(*) FROM pq_vegetatie_opname_bronkoppeling WHERE koppelstatus<>'vermoedelijk'",
        'SELECT COUNT(*) FROM externe_ecologie_event e JOIN pq_vegetatie_bronopname p USING(event_id)',
        'SELECT COUNT(*) FROM externe_ecologie_resultaat e JOIN pq_vegetatie_bronresultaat p USING(resultaat_id)',
    ]
    for table in ['pq_vegetatie_waarneming','pq_vegetatie_bronresultaat']:
        zero_queries.append(f'SELECT COUNT(*) FROM {table} w LEFT JOIN taxa_bronkoppeling b '
            'ON b.koppeling_id=w.taxon_bronkoppeling_id LEFT JOIN taxa t ON t.taxon_id=b.taxon_id '
            'WHERE b.koppeling_id IS NULL OR t.taxon_id IS NULL')
    if any(query(sql) != '0' for sql in zero_queries):
        raise RuntimeError('PQ-referentie, dubbele opslag of meetellingsbeveiliging mislukt')
    if query("SELECT COUNT(*) FROM v_externe_ecologie_analyse WHERE dataset_sleutel='lvd-meijendel-v1-6'") != '81310':
        raise RuntimeError('Bestaande LVD-catalogusdekking gewijzigd')
    return {'status':'verified','counts':expected,'snapshot':after}


def execute_pq_integration(args) -> int:
    """Eenmalige beheerhandeling; live alleen met identieke geslaagde proef en back-up."""
    if not __debug__:
        raise RuntimeError('Optimalisatie is niet toegestaan bij databaseacceptatie')
    if not (args.database == 'Meijendel' or re.fullmatch(r'Meijendel_pq_proef_[0-9]+', args.database)):
        raise ValueError('Alleen de canonieke database of een expliciete PQ-proefdatabase is toegestaan')
    if args.pq_bewijs_dir is None or args.pq_backup_manifest is None:
        raise ValueError('PQ-integratie vereist een nieuw bewijsdirectory en back-upmanifest')
    root = args.pq_bewijs_dir
    if root.exists():
        raise ValueError('Bewijsdirectory bestaat al; eerdere uitvoering niet overschrijven')
    backup = json.loads(args.pq_backup_manifest.read_text())
    with Path(backup['file']).open('rb') as handle:
        if hashlib.file_digest(handle, 'sha256').hexdigest() != backup['sha256']:
            raise ValueError('Back-uphash wijkt af')
    db_args = mysql_args(args.login_path) + ['--batch','--raw','--skip-column-names',args.database]
    client = args.mysql_client
    before = pq_snapshot(client, db_args)
    if any(v == 'NULL' for v in before['unchanged_tables'].values()):
        raise RuntimeError('Ten minste één tabelchecksum is niet beschikbaar')
    plan = prepare_pq_migration(client, db_args)
    # Canonieke planhash is onafhankelijk van MySQL-volgorde van DISTINCT kandidaatparen.
    plan['pairs'].sort(key=lambda p: (p['event_id'],p['opname_id']))
    plan_hash = hashlib.sha256(json.dumps({k:v for k,v in plan.items() if k!='input_sha256'},
        sort_keys=True,ensure_ascii=False,separators=(',',':')).encode()).hexdigest()
    code_hash = hashlib.sha256(Path(__file__).read_bytes() + SCHEMA.read_bytes()).hexdigest()
    if args.apply and args.database == 'Meijendel':
        if args.pq_proefbewijs is None:
            raise ValueError('Live invoer vereist geslaagde identieke proef')
        proof = json.loads(args.pq_proefbewijs.read_text())
        if (proof.get('status') != 'verified' or not proof.get('rollback_verified')
                or not re.fullmatch(r'Meijendel_pq_proef_[0-9]+', proof.get('database',''))
                or proof.get('snapshot') != before or proof.get('plan_sha256') != plan_hash
                or proof.get('code_sha256') != code_hash or proof.get('backup_sha256') != backup['sha256']):
            raise ValueError('Proefbewijs past niet bij de actuele database, code of back-up')
    root.mkdir(parents=True)
    def save(name, value):
        with (root/name).open('x',encoding='utf-8') as handle:
            json.dump(value,handle,ensure_ascii=False,indent=2)
    save('plan.json',plan)
    save('before.json',before)
    if not args.apply:
        print('READ-ONLY: migratieplan en uitgangscontrole opgeslagen in',root)
        return 0
    run_mysql(client, db_args, pq_schema_sql())
    # Catalogus blijft volledig tijdens de atomische verplaatsing van bronregels.
    run_mysql(client, db_args, pq_analysis_view_sql())
    original = run_mysql(client, db_args, 'CHECKSUM TABLE externe_ecologie_event,externe_ecologie_resultaat,externe_ecologie_overlap,pq_vegetatie_waarneming')
    run_mysql(client, db_args, pq_migration_sql(plan))
    if original != run_mysql(client, db_args, 'CHECKSUM TABLE externe_ecologie_event,externe_ecologie_resultaat,externe_ecologie_overlap,pq_vegetatie_waarneming'):
        raise RuntimeError('Transactionele terugdraaiproef wijkt af')
    for table in [*PQ_MOVES.values(),'pq_vegetatie_opname_bronkoppeling']:
        if run_mysql(client, db_args, f'SELECT COUNT(*) FROM {table}') != '0':
            raise RuntimeError('Rollback liet bronvarianten achter')
    save('rollback.json',{'status':'verified'})
    run_mysql(client, db_args, pq_migration_sql(plan,commit=True))
    run_mysql(client, db_args, pq_finalize_sql())
    result = verify_pq_integration(client, db_args, plan, before)
    result.update(database=args.database,backup_sha256=backup['sha256'],plan_sha256=plan_hash,
                  code_sha256=code_hash,rollback_verified=True)
    save('result.json',result)
    print('PQ-integratie gecontroleerd:',json.dumps(result['counts']),'; bewijs:',root)
    return 0


def source_separation_schema_sql() -> str:
    """LIKE preserves column/index/CHECK semantics; foreign keys need explicit copies."""
    sql = ['SET SESSION lock_wait_timeout=10;']
    for key,prefix in SOURCE_FAMILIES.items():
        for suffix in SOURCE_SUFFIXES:
            sql.append(f'CREATE TABLE {prefix}_{suffix} LIKE externe_ecologie_{suffix};')
        sql += [
            f'ALTER TABLE {prefix}_dataset ADD CONSTRAINT ck_{prefix}_source '
            'CHECK(BINARY dataset_sleutel=BINARY '+query_literal(key)+');',
            f'ALTER TABLE {prefix}_event ADD CONSTRAINT fk_{prefix}_event_dataset '
            f'FOREIGN KEY(dataset_id) REFERENCES {prefix}_dataset(dataset_id) ON DELETE RESTRICT;',
            f'ALTER TABLE {prefix}_resultaat ADD CONSTRAINT fk_{prefix}_resultaat_event '
            f'FOREIGN KEY(event_id) REFERENCES {prefix}_event(event_id) ON DELETE RESTRICT, '
            f'ADD CONSTRAINT fk_{prefix}_resultaat_taxon FOREIGN KEY(taxon_bronkoppeling_id) '
            'REFERENCES taxa_bronkoppeling(koppeling_id);',
            f'ALTER TABLE {prefix}_overlap ADD CONSTRAINT fk_{prefix}_overlap_resultaat '
            f'FOREIGN KEY(resultaat_id) REFERENCES {prefix}_resultaat(resultaat_id) ON DELETE RESTRICT;',
        ]
    return '\n'.join(sql)


def source_separation_counts(db: CentralQueryDatabase) -> dict:
    counts = {}
    for key,prefix in SOURCE_FAMILIES.items():
        counts[prefix] = {}
        hashes = {}
        scopes = source_separation_scopes(key)
        for suffix,where in scopes.items():
            counts[prefix][suffix] = int(db.sql(f'SELECT COUNT(*) FROM externe_ecologie_{suffix} s WHERE {where};'))
            hashes[suffix] = db.sql('SET SESSION group_concat_max_len=1073741824; SELECT '+
                source_cell_digest_sql('externe_ecologie_'+suffix,'externe_ecologie_'+suffix,where)+';')
        counts[prefix]['_hashes'] = hashes
        if counts[prefix]['dataset'] != 1:
            raise ValueError('Verwachte oorspronkelijke bronregistratie ontbreekt: '+prefix)
    return counts


def source_separation_scopes(key: str) -> dict[str,str]:
    source_family_for_dataset(key)
    dataset = 'SELECT dataset_id FROM externe_ecologie_dataset WHERE BINARY dataset_sleutel=BINARY '+query_literal(key)
    events = f'SELECT event_id FROM externe_ecologie_event WHERE dataset_id IN ({dataset})'
    results = f'SELECT resultaat_id FROM externe_ecologie_resultaat WHERE event_id IN ({events})'
    return dict(dataset=f's.dataset_id IN ({dataset})',event=f's.dataset_id IN ({dataset})',
                resultaat=f's.event_id IN ({events})',overlap=f's.resultaat_id IN ({results})')


def source_cell_digest_sql(table: str, original: str, where='TRUE') -> str:
    columns = sorted(CENTRAL_QUERY_SCHEMA[original])
    fields = ','.join(query_literal(c)+',s.'+query_identifier(c) for c in columns)
    rows = f'SELECT SHA2(CAST(JSON_OBJECT({fields}) AS CHAR CHARACTER SET utf8mb4),256) h FROM {query_identifier(table)} s WHERE {where}'
    return "(SELECT COALESCE(SHA2(GROUP_CONCAT(h ORDER BY h SEPARATOR ''),256),SHA2('',256)) FROM ("+rows+') cells)'


def source_separation_sql(counts: dict, *, commit=False) -> str:
    """One atomic copy-and-delete; checks fail before source deletion, no ignored errors."""
    if set(counts) != set(SOURCE_FAMILIES.values()):
        raise ValueError('Onvolledige bronselectie')
    sql = ['SET NAMES utf8mb4;', 'SET SESSION innodb_lock_wait_timeout=10;',
           'SET SESSION group_concat_max_len=1073741824;',
           'START TRANSACTION;', 'CREATE TEMPORARY TABLE tmp_source_guard(ok TINYINT NOT NULL CHECK(ok=1));']
    def guard(condition):
        sql.append('INSERT INTO tmp_source_guard VALUES(IF('+condition+',1,0));')
    guard('@@SESSION.foreign_key_checks=1')
    guard("(SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=DATABASE() "
          "AND REFERENCED_TABLE_NAME IN ('externe_ecologie_dataset','externe_ecologie_event','externe_ecologie_resultaat') "
          "AND TABLE_NAME NOT IN ('externe_ecologie_event','externe_ecologie_resultaat','externe_ecologie_overlap','pq_vegetatie_bronopname'))=0")
    for key,prefix in SOURCE_FAMILIES.items():
        scopes = source_separation_scopes(key)
        hashes = counts[prefix].get('_hashes',{})
        if set(hashes)!=set(SOURCE_SUFFIXES) or any(not re.fullmatch('[0-9a-f]{64}',h) for h in hashes.values()):
            raise ValueError('Bewezen volledige broncelhashes ontbreken')
        # Parent locks also block concurrent child INSERTs through their FK.
        for suffix,primary in zip(SOURCE_SUFFIXES,('dataset_id','event_id','resultaat_id','overlap_id')):
            sql.append(f'SELECT {primary} FROM externe_ecologie_{suffix} s WHERE {scopes[suffix]} FOR UPDATE;')
        for suffix in SOURCE_SUFFIXES:
            original, target = 'externe_ecologie_'+suffix, prefix+'_'+suffix
            n = counts[prefix][suffix]
            if type(n) is not int or n < 0: raise ValueError('Ongeldige brontelling')
            if n*64>16*1024*1024: raise ValueError('Bronhashstream vereist apart beoordeelde grotere limiet')
            guard(f'(SELECT COUNT(*) FROM {target})=0')
            guard(f'(SELECT COUNT(*) FROM {original} s WHERE {scopes[suffix]})={n}')
            guard(source_cell_digest_sql(original,original,scopes[suffix])+'='+query_literal(hashes[suffix]))
            columns = ','.join(query_identifier(c) for c in sorted(CENTRAL_QUERY_SCHEMA[original]))
            sql.append(f'INSERT INTO {target} ({columns}) SELECT {columns} FROM {original} s WHERE {scopes[suffix]};')
            guard(f'(SELECT COUNT(*) FROM {target})={n}')
            guard(source_cell_digest_sql(target,original)+'='+query_literal(hashes[suffix]))
        # Explicit child-first deletion, by the fully verified target IDs:
        # the real multi-level cascade trial left old children behind.
        for suffix,primary in reversed(list(zip(SOURCE_SUFFIXES,
                ('dataset_id','event_id','resultaat_id','overlap_id')))):
            original = 'externe_ecologie_'+suffix
            target = prefix+'_'+suffix
            sql.append(f'DELETE s FROM {original} s WHERE s.{primary} IN (SELECT {primary} FROM {target});')
            guard(f'(SELECT COUNT(*) FROM {original} s JOIN {target} n USING({primary}))=0')
    for prefix in ('externe_ecologie',*SOURCE_FAMILIES.values()):
        for child,parent,field in [('event','dataset','dataset_id'),
                ('resultaat','event','event_id'),('overlap','resultaat','resultaat_id')]:
            guard(f'(SELECT COUNT(*) FROM {prefix}_{child} c LEFT JOIN {prefix}_{parent} p '
                f'ON c.{field}=p.{field} WHERE p.{field} IS NULL)=0')
    sql.append('COMMIT;' if commit else 'ROLLBACK;')
    return '\n'.join(sql)


def source_separation_view_sql() -> str:
    """Adapt the EXISTING consumer only; central querying remains ordinary SELECT."""
    marker = 'CREATE OR REPLACE VIEW v_externe_ecologie_analyse AS'
    original = pq_analysis_view_sql()
    base = SCHEMA.read_text(encoding='utf-8').split(marker,1)[1].strip().removesuffix(';')
    branches = []
    for prefix in SOURCE_FAMILIES.values():
        branch = base
        for suffix in SOURCE_SUFFIXES:
            branch = branch.replace('externe_ecologie_'+suffix,prefix+'_'+suffix)
        branches.append(branch)
    return original.rstrip().removesuffix(';')+'\nUNION ALL\n'+'\nUNION ALL\n'.join(branches)+';\n'


def source_separation_snapshot(db: CentralQueryDatabase) -> dict:
    """All unchanged tables, all old source cells logically reunited, all existing view rows.

    Exact ordered SHA256 streams retain multiplicity; source primary keys and
    version fields are included, never just species names or summary counts.
    """
    schema = db.schema()
    central_query_schema_contract(schema)
    additions = source_family_tables()
    columns = db.objects("SELECT JSON_OBJECT('table',TABLE_NAME,'name',COLUMN_NAME,'type',DATA_TYPE,"
        "'definition',COLUMN_TYPE,'nullable',IS_NULLABLE,'default',COLUMN_DEFAULT,'extra',EXTRA,"
        "'generated',GENERATION_EXPRESSION,'collation',COLLATION_NAME,'comment',COLUMN_COMMENT) "
        "FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() ORDER BY TABLE_NAME,ORDINAL_POSITION;")
    tables = defaultdict(list)
    for column in columns: tables[column['table']].append(column)
    digest = lambda raw: hashlib.sha256(raw.encode()).hexdigest()
    def row_digest(table, source=None):
        items = []
        for column in tables[table]:
            value = 's.'+query_identifier(column['name'])
            if column['type'] in {'binary','varbinary','blob','tinyblob','mediumblob','longblob','bit'}:
                value = 'HEX('+value+')'
            elif column['type'] in {'geometry','point','polygon','multipolygon','linestring','multilinestring','multipoint','geometrycollection'}:
                value = 'HEX(ST_AsWKB('+value+'))'
            items += [query_literal(column['name']),value]
        raw = db.sql('SELECT SHA2(CAST(JSON_OBJECT('+','.join(items)+') AS CHAR CHARACTER SET utf8mb4),256) h '
                     'FROM '+(source or query_identifier(table))+' s ORDER BY h;')
        return {'rows':len(raw.splitlines()),'sha256':digest(raw)}
    result = {}
    for table in sorted(CENTRAL_QUERY_SCHEMA):
        if table.startswith('externe_ecologie_'):
            suffix = table.removeprefix('externe_ecologie_')
            cols = ','.join(query_identifier(c['name']) for c in tables[table])
            sources = [table]+[p+'_'+suffix for p in SOURCE_FAMILIES.values() if p+'_'+suffix in schema]
            union = '('+' UNION ALL '.join(f'SELECT {cols} FROM {query_identifier(s)}' for s in sources)+')'
            result[table] = row_digest(table,union)
        else:
            checksum = db.sql('CHECKSUM TABLE '+query_identifier(table)+' EXTENDED;').split('\t')[-1]
            if checksum == 'NULL': raise ValueError('Geen volledige checksum: '+table)
            result[table] = checksum
    for table in sorted(set(tables)-set(schema)):
        result['view:'+table] = row_digest(table)
    # Existing physical metadata and all unaffected view definitions must remain identical.
    originals = [{**c,'nullable':'derived-view'} if c['table'] not in schema else c
                 for c in columns if c['table'] not in additions]
    result['columns'] = digest(json.dumps(originals,ensure_ascii=False,sort_keys=True))
    normalize = lambda raw: raw.replace('`'+db.database.lower()+'`','`meijendel`').replace('`'+db.database+'`','`meijendel`')
    for name,query in {
        'indexes': "SELECT TABLE_NAME,INDEX_NAME,NON_UNIQUE,SEQ_IN_INDEX,COLUMN_NAME,SUB_PART,INDEX_TYPE "
            "FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() ORDER BY TABLE_NAME,INDEX_NAME,SEQ_IN_INDEX;",
        'constraints': "SELECT t.TABLE_NAME,t.CONSTRAINT_NAME,t.CONSTRAINT_TYPE,c.CHECK_CLAUSE,f.UPDATE_RULE,f.DELETE_RULE,"
            "(SELECT GROUP_CONCAT(CONCAT(k.COLUMN_NAME,':',COALESCE(k.REFERENCED_TABLE_NAME,''),':',COALESCE(k.REFERENCED_COLUMN_NAME,'')) "
            "ORDER BY k.ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE k WHERE k.CONSTRAINT_SCHEMA=t.CONSTRAINT_SCHEMA "
            "AND k.TABLE_NAME=t.TABLE_NAME AND k.CONSTRAINT_NAME=t.CONSTRAINT_NAME) "
            "FROM information_schema.TABLE_CONSTRAINTS t LEFT JOIN information_schema.CHECK_CONSTRAINTS c "
            "ON c.CONSTRAINT_SCHEMA=t.CONSTRAINT_SCHEMA AND c.CONSTRAINT_NAME=t.CONSTRAINT_NAME "
            "LEFT JOIN information_schema.REFERENTIAL_CONSTRAINTS f ON f.CONSTRAINT_SCHEMA=t.CONSTRAINT_SCHEMA "
            "AND f.TABLE_NAME=t.TABLE_NAME AND f.CONSTRAINT_NAME=t.CONSTRAINT_NAME "
            "WHERE t.CONSTRAINT_SCHEMA=DATABASE() ORDER BY t.TABLE_NAME,t.CONSTRAINT_NAME;",
        'views': "SELECT TABLE_NAME,VIEW_DEFINITION FROM information_schema.VIEWS WHERE TABLE_SCHEMA=DATABASE() "
            "AND TABLE_NAME<>'v_externe_ecologie_analyse' ORDER BY TABLE_NAME;",
        # Filter complete trigger records in SQL. ACTION_STATEMENT contains
        # newlines: a line-wise filter would retain a new trigger's body.
        'triggers': "SELECT EVENT_OBJECT_TABLE,TRIGGER_NAME,ACTION_STATEMENT FROM information_schema.TRIGGERS "
            "WHERE TRIGGER_SCHEMA=DATABASE() AND TRIGGER_NAME<>'cq_registry_bu' "
            "AND EVENT_OBJECT_TABLE NOT IN ("+','.join(map(query_literal,additions))+') ORDER BY TRIGGER_NAME;',
        'routines': "SELECT ROUTINE_NAME,ROUTINE_TYPE,ROUTINE_DEFINITION FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() ORDER BY ROUTINE_NAME;",
        'events': "SELECT EVENT_NAME,EVENT_DEFINITION,INTERVAL_VALUE,INTERVAL_FIELD,STATUS FROM information_schema.EVENTS WHERE EVENT_SCHEMA=DATABASE() ORDER BY EVENT_NAME;",
    }.items():
        raw = '\n'.join(line for line in db.sql(query).splitlines() if line.split('\t',1)[0] not in additions)
        result[name] = digest(normalize(raw))
    return result


def validate_source_backup(backup: Path) -> None:
    """Only an unqualified single-database dump, never a database-switching script."""
    quoted = re.compile(r"'(?:[^'\\]|\\.|'')*'")
    commands = re.compile(r'\b(?:USE\b|(?:CREATE|DROP|ALTER)\s+(?:DATABASE|SCHEMA)\b)',re.I)
    qualified = re.compile(r'\b(?:TABLE|INTO|UPDATE|REFERENCES|FROM|JOIN)\s+`?\w+`?\s*\.|'
        r'\b(?:BEFORE|AFTER)\s+(?:INSERT|UPDATE|DELETE)\s+ON\s+`?\w+`?\s*\.',re.I)
    with gzip.open(backup,'rt',encoding='utf-8') as handle:
        for line in handle:
            if line.lstrip().startswith('--'): continue
            sql = quoted.sub("''",line)
            if commands.search(sql) or re.match(r'\s*(?:\\|SOURCE\b|CONNECT\b|SYSTEM\b)',sql,re.I):
                raise ValueError('Back-up bevat een databasewisseling of clientcommando; herstel geweigerd')
            if qualified.search(sql) and not line.startswith('/*!50001 VIEW'):
                raise ValueError('Back-up bevat database-gekwalificeerde instructies buiten bestaande views')


def restore_source_copy(db: CentralQueryDatabase, backup: Path) -> None:
    if not re.fullmatch(r'Meijendel_bronnen_(?:proef|herstel)_[0-9]+',db.database):
        raise ValueError('Herstel uitsluitend naar een eigen, nog niet bestaande proefdatabase')
    if '--host=127.0.0.1' not in db.args or '--port=3306' not in db.args:
        raise ValueError('Herstelproef uitsluitend lokaal')
    validate_source_backup(backup)
    db_args = db.args[:-1]
    subprocess.run(db_args, input='CREATE DATABASE '+query_identifier(db.database)+
        ' CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;',text=True,check=True,capture_output=True)
    process = subprocess.Popen(db.args,stdin=subprocess.PIPE,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    try:
        # These are disposable local proof schemas, not canonical writes.
        # Avoid duplicating an entire restore in the canonical binary log;
        # this affects ONLY this already-validated restore connection.
        process.stdin.write(b'SET SESSION sql_log_bin=0;\n')
        with gzip.open(backup,'rb') as source:
            for line in source:
                if line.startswith(b'/*!50001 VIEW'):
                    line = line.replace(b'`meijendel`.',('`'+db.database.lower()+'`.').encode()).replace(b'`Meijendel`.',('`'+db.database+'`.').encode())
                process.stdin.write(line)
        process.stdin.close(); error=process.stderr.read(); status=process.wait()
    except BaseException:
        process.kill(); process.wait(); raise
    if status: raise RuntimeError(error.decode())


def source_append_sql(payload: dict) -> str:
    """Append one approved source version, with trigger-resolved central identification.

    No replacement, no source-local taxa, no fallback to a joint import table.
    A changed delivery/version must first be reviewed and registered separately.
    """
    key = payload.get('dataset_sleutel')
    prefix = source_family_for_dataset(key)
    if prefix == 'externe_ecologie': raise ValueError('LVD/PQ valt buiten deze bronaanvulling')
    if set(payload)-{'dataset_sleutel','bronversie','bronbestand_sha256','events','resultaten'}:
        raise ValueError('Onbekende bronaanvullingsvelden')
    version, sha = payload.get('bronversie'),payload.get('bronbestand_sha256')
    if not isinstance(version,str) or not isinstance(sha,str) or not re.fullmatch('[0-9a-f]{64}',sha):
        raise ValueError('Exacte beoordeelde bronversie en bestandshash zijn verplicht')
    if not isinstance(payload.get('events',[]),list) or not isinstance(payload.get('resultaten'),list) or not payload['resultaten']:
        raise ValueError('Bronaanvulling vereist resultaatregels en een eventlijst')
    if payload.get('events'):
        raise ValueError('Nieuwe events vereisen eerst geografische toelating; deze route gebruikt uitsluitend bestaande toegelaten events')
    dataset = f'SELECT dataset_id FROM {prefix}_dataset WHERE BINARY dataset_sleutel=BINARY '+query_literal(key)+\
        ' AND BINARY bronversie=BINARY '+query_literal(version)+' AND BINARY bronbestand_sha256=BINARY '+query_literal(sha)
    sql = ['SET NAMES utf8mb4;', 'START TRANSACTION;',
           'CREATE TEMPORARY TABLE tmp_source_append_guard(ok TINYINT NOT NULL CHECK(ok=1));',
           f'INSERT INTO tmp_source_append_guard VALUES(IF((SELECT COUNT(*) FROM ({dataset}) d)=1,1,0));']
    for suffix,rows in [('event',payload.get('events',[])),('resultaat',payload['resultaten'])]:
        table = prefix+'_'+suffix
        excluded = {'event_id','dataset_id'} if suffix=='event' else {'resultaat_id','event_id','taxon_bronkoppeling_id'}
        columns = sorted(CENTRAL_QUERY_SCHEMA['externe_ecologie_'+suffix]-excluded)
        for row in rows:
            allowed = set(columns) | ({'bron_event_id'} if suffix=='resultaat' else set())
            if not isinstance(row,dict) or set(row)-allowed or not isinstance(row.get('bronmetadata'),dict):
                raise ValueError('Onbekende bronvelden of ontbrekende oorspronkelijke bronmetadata')
            values = [query_literal(json.dumps(row[c],ensure_ascii=False)) if c=='bronmetadata'
                      else query_literal(row.get(c)) for c in columns]
            target_columns = list(columns)
            if suffix=='event':
                target_columns.append('dataset_id'); values.append('('+dataset+')')
            else:
                if not isinstance(row.get('bron_event_id'),str): raise ValueError('Resultaat mist oorspronkelijke event-ID')
                event = f'SELECT event_id FROM {prefix}_event WHERE dataset_id=({dataset}) AND BINARY bron_event_id=BINARY '+query_literal(row['bron_event_id'])
                sql.append(f'INSERT INTO tmp_source_append_guard VALUES(IF((SELECT COUNT(*) FROM ({event}) e)=1,1,0));')
                target_columns += ['event_id','taxon_bronkoppeling_id']; values += ['('+event+')','NULL']
            sql.append('INSERT INTO '+table+' ('+','.join(map(query_identifier,target_columns))+') VALUES ('+','.join(values)+');')
    sql.append('COMMIT;')
    return '\n'.join(sql)


def execute_source_separation(args) -> int:
    if args.host!='127.0.0.1' or args.port!=3306:
        raise ValueError('Bronverplaatsing uitsluitend op de lokale iMac')
    if args.database!='Meijendel' and not re.fullmatch(r'Meijendel_bronnen_proef_[0-9]+',args.database):
        raise ValueError('Onbeoordeeld migratiedoel')
    root, backup = args.bron_bewijs_dir, args.bron_backup
    if not root or root.exists() or not backup or not backup.is_file():
        raise ValueError('Nieuwe bewijsmap en bestaande volledige back-up zijn verplicht')
    # Fail before the lengthy database audit if the backup is unavailable.
    # Stream the full archive rather than allocating it on the 8-GB iMac.
    digest = hashlib.sha256()
    with backup.open('rb') as handle:
        while chunk := handle.read(1024*1024): digest.update(chunk)
    backup_hash = digest.hexdigest()
    db = CentralQueryDatabase(args.database,args.login_path,args.mysql_client,writable=args.apply)
    before_audit = central_query_audit(db)
    if before_audit['errors']: raise ValueError('; '.join(before_audit['errors']))
    if set(db.schema()) & set(source_family_tables()):
        raise ValueError('Bronfamilies bestaan al: geen blinde herhaling of overschrijving')
    snapshot = source_separation_snapshot(db)
    counts = source_separation_counts(db)
    code_hash = hashlib.sha256(Path(__file__).read_bytes()+SCHEMA.read_bytes()+
        Path(__file__).with_name('test_import_external_ecology_sources.py').read_bytes()).hexdigest()
    if args.apply and args.database=='Meijendel':
        if not args.bron_proefbewijs: raise ValueError('Volledig geïsoleerd proefbewijs ontbreekt')
        proof = json.loads(args.bron_proefbewijs.read_text())
        if (proof.get('status')!='verified' or proof.get('snapshot')!=snapshot or proof.get('counts')!=counts
            or proof.get('code_sha256')!=code_hash or proof.get('backup_sha256')!=backup_hash
            or not proof.get('rollback_verified') or not proof.get('backup_restore_verified')
            or not proof.get('source_inputs_verified')
            or not re.fullmatch(r'Meijendel_bronnen_proef_[0-9]+',proof.get('database',''))):
            raise ValueError('Proefbewijs past niet bij dezelfde code, volledige bronstand en back-up')
    root.mkdir(parents=True,exist_ok=False)
    def save(name,value):
        with (root/name).open('x',encoding='utf-8') as handle:
            json.dump(value,handle,ensure_ascii=False,indent=2)
    save('before.json',snapshot); save('counts.json',counts)
    if not args.apply:
        print('READ-ONLY: bronverplaatsing geïnventariseerd; bewijs:',root); return 0
    db.sql(source_separation_schema_sql(),write=True)
    routes = central_query_routes(db.schema())
    db.sql(central_query_triggers_sql({'routes':routes}),write=True)
    db.sql(source_separation_view_sql(),write=True)
    db.sql(source_separation_sql(counts),write=True)
    if source_separation_snapshot(db)!=snapshot:
        raise RuntimeError('Terugdraaiproef veranderde oorspronkelijke informatie')
    if any(db.sql('SELECT COUNT(*) FROM '+query_identifier(t)+';')!='0' for t in source_family_tables()):
        raise RuntimeError('Terugdraaiproef liet bronregels achter')
    save('rollback.json',{'status':'verified'})
    if args.database!='Meijendel':
        subprocess.run(['python3','-B',str(Path(__file__).with_name('test_import_external_ecology_sources.py')),
            '--bron-driftproef',args.database,str(root/'counts.json'),str(args.mysql_client),args.login_path],check=True)
    db.sql(source_separation_sql(counts,commit=True),write=True)
    result = central_query_audit(db)
    if result['errors']: raise RuntimeError('; '.join(result['errors']))
    if source_separation_snapshot(db)!=snapshot:
        raise RuntimeError('Bronwaarden, overige tabellen, structuur of bestaande analyseuitkomsten gewijzigd')
    if args.database!='Meijendel':
        # Existing test module owns test-only writers; it never writes to the live database.
        subprocess.run(['python3','-B',str(Path(__file__).with_name('test_import_external_ecology_sources.py')),
                        '--bron-invoerproef',args.database,str(args.mysql_client),args.login_path],check=True)
        if source_separation_snapshot(db)!=snapshot:
            raise RuntimeError('Invoerproeven hebben oorspronkelijke informatie gewijzigd')
        if not args.bron_herstel_database: raise ValueError('Tweede onafhankelijke herstelkopie vereist')
        restored = CentralQueryDatabase(args.bron_herstel_database,args.login_path,args.mysql_client,writable=True)
        restore_source_copy(restored,backup)
        if source_separation_snapshot(restored)!=snapshot or central_query_audit(restored)['errors']:
            raise RuntimeError('Volledig herstel van originele schema en gegevens wijkt af')
    result.update(database=args.database,snapshot=snapshot,counts=counts,rollback_verified=True,
        source_inputs_verified=True,backup_restore_verified=True,code_sha256=code_hash,backup_sha256=backup_hash)
    save('result.json',result)
    print('OK: vijf bronnen fysiek gescheiden; alle bronwaarden en centrale routes behouden; bewijs:',root)
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profiles-dir", type=Path)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--mysql-client", type=Path, default=Path("/usr/local/mysql/bin/mysql"))
    parser.add_argument("--login-path", default="meijendel_root")
    parser.add_argument("--database", default=DATABASE)
    parser.add_argument('--host',default='127.0.0.1')
    parser.add_argument('--port',type=int,default=3306)
    parser.add_argument('--pq-integratie', action='store_true')
    parser.add_argument('--pq-bewijs-dir', type=Path)
    parser.add_argument('--pq-backup-manifest', type=Path)
    parser.add_argument('--pq-proefbewijs', type=Path)
    parser.add_argument('--centrale-querypoort', action='store_true')
    parser.add_argument('--centrale-query-sql',action='store_true')
    parser.add_argument('--taxon-id',type=int)
    parser.add_argument('--tabel')
    parser.add_argument('--centrale-integratie', action='store_true')
    parser.add_argument('--centrale-bewijs-dir', type=Path)
    parser.add_argument('--centrale-proefbewijs', type=Path)
    parser.add_argument('--centrale-backup',type=Path)
    parser.add_argument('--centrale-herstel-database')
    parser.add_argument('--centrale-hervat-proef',action='store_true')
    parser.add_argument('--bron-ontvlechting',action='store_true')
    parser.add_argument('--bron-bewijs-dir',type=Path)
    parser.add_argument('--bron-backup',type=Path)
    parser.add_argument('--bron-proefbewijs',type=Path)
    parser.add_argument('--bron-herstel-database')
    parser.add_argument('--bron-aanvulling',type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.bron_ontvlechting:
        return execute_source_separation(args)
    if args.centrale_query_sql:
        result=central_query_gate(args.database,args.login_path,args.mysql_client,args.host,args.port)
        selected={table:route for table,route in result['routes'].items()
                  if route['kind']!='staging' and (args.tabel is None or table==args.tabel)}
        if args.tabel and not selected: raise ValueError('Geen beoordeelde centrale route voor deze tabel')
        for table,route in selected.items():
            print('-- '+table+'; '+route.get('role','soortreferentie'))
            print(central_taxon_query(table,route,args.taxon_id))
        return 0
    if args.centrale_querypoort:
        result = central_query_gate(args.database,args.login_path,args.mysql_client,args.host,args.port)
        print(json.dumps(result,ensure_ascii=False,indent=2)); return 0
    if args.centrale_integratie:
        return execute_central_query_migration(args)
    if args.host!='127.0.0.1' or args.port!=3306:
        raise ValueError('Host/port zijn alleen voor de centrale controle; historische import gebruikt lokaal 127.0.0.1:3306')
    return central_query_guarded_operation(lambda:execute_external_main(args),enabled=args.apply,
        database=args.database,login_path=args.login_path,client=args.mysql_client,host=args.host,port=args.port)


def execute_external_main(args) -> int:
    if args.bron_aanvulling:
        payload = json.loads(args.bron_aanvulling.read_text(encoding='utf-8'))
        sql = source_append_sql(payload)
        if not args.apply:
            print('READ-ONLY: bronaanvulling gevalideerd; niets ingevoerd'); return 0
        db = CentralQueryDatabase(args.database,args.login_path,args.mysql_client,writable=True)
        db.sql(sql,write=True)
        print('OK: bronaanvulling in eigen bronfamilie en centraal taxonomisch verbonden')
        return 0
    if args.pq_integratie:
        return execute_pq_integration(args)
    if args.profiles_dir is None:
        raise ValueError('--profiles-dir is verplicht voor de historische externe import')
    if args.apply:
        guard_legacy_import(args.mysql_client, mysql_args(args.login_path) +
                           ['--batch', '--skip-column-names', args.database])
    source = args.profiles_dir
    stowa_measurements = {
        row["_core_id"]: (row.get("measurementValue", ""), row.get("measurementUnit", ""), row.get("measurementType", ""))
        for row in read_csv(source / "stowa_limnodata_extension_basisgebied.csv")
    }
    lvd_releves = {row["_core_id"]: row for row in read_csv(source / "lvd_releve_basisgebied.csv")}
    museum_sources = {
        "nmr": (read_csv(source / "nmr_observations_basisgebied.csv"), SOURCE_CONFIG["nmr"]),
        "botany": (read_csv(source / "naturalis_botany_basisgebied.csv"), SOURCE_CONFIG["botany"]),
        "coleoptera": (read_csv(source / "naturalis_coleoptera_basisgebied.csv"), SOURCE_CONFIG["coleoptera"]),
    }
    with tempfile.TemporaryDirectory(prefix="external-ecology-import-") as tmp:
        paths = write_import_files(
            Path(tmp),
            stowa_rows=read_csv(source / "stowa_limnodata_basisgebied.csv"),
            stowa_measurements=stowa_measurements,
            endure_events=read_csv(source / "endure_basisgebied.csv"),
            endure_results=read_csv(source / "endure_extension_basisgebied.csv"),
            museum_sources=museum_sources,
            lvd_events=read_csv(source / "lvd_events_basisgebied.csv"),
            lvd_releves=lvd_releves,
            lvd_occurrences=read_csv(source / "lvd_occurrence_basisgebied.csv"),
        )
        counts = {key: sum(1 for _ in path.open(encoding="utf-8")) - 1 for key, path in paths.items()}
        print(json.dumps(counts, ensure_ascii=False))
        if not args.apply:
            return 0
        schema = SCHEMA.read_text(encoding="utf-8").replace("USE Meijendel;", f"USE {args.database};", 1)
        sql = schema + "\n" + load_sql(paths, database=args.database)
        apply_sql_with_local_infile(args.mysql_client, mysql_args(args.login_path), sql)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
