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
import json
import re
import subprocess
import tempfile
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "gis" / "database" / "external_ecology_schema.sql"
DATABASE = "Meijendel"
IMPORT_VERSION = "externe-ecologie-v1"

FUSION_RULE = 'taxa-gerichte-fusie-v1'
CENTRAL_RULE = 'taxa-centrale-lijst-v1'


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
    if not candidates:
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


def central_taxa_sql(snapshot: dict, *, name_evidence: dict, commit: bool = False) -> str:
    """Alleen DML, fail-closed snapshotpoort en celcontrole binnen één transactie."""
    old_taxa, old_links = snapshot['taxa']['rows'], snapshot['taxa_bronkoppeling']['rows']
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
            by_usage[canonical(link['bronmetadata'])].append(link)
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profiles-dir", type=Path)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--mysql-client", type=Path, default=Path("/usr/local/mysql/bin/mysql"))
    parser.add_argument("--login-path", default="meijendel_root")
    parser.add_argument("--database", default=DATABASE)
    parser.add_argument('--pq-integratie', action='store_true')
    parser.add_argument('--pq-bewijs-dir', type=Path)
    parser.add_argument('--pq-backup-manifest', type=Path)
    parser.add_argument('--pq-proefbewijs', type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
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
