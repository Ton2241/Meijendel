#!/usr/bin/env python3
"""Render an inspectable diagnostic candidate from assessed, frozen CSV results.

No fits, no inference, no promotion to formal uncertainty. Outputs stay in outputs/.
"""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path

FILES = {'long': 'long_per_species.csv', 'periods': 'periods.csv', 'annual': 'annual_indices.csv'}
TEXT = {'soort_naam','period','baseline_status','baseline_model_reason','reasons','status',
        'diagnostic_method','gate','first_window','last_window'}

def number(value):
    try:
        x = float(value)
        return x if math.isfinite(x) else None
    except (ValueError, TypeError):
        return None

def convert(key, value):
    if key in TEXT: return value or None
    if value in ('TRUE','FALSE'): return value == 'TRUE'
    result = number(value)
    if value and result is None and value not in ('NA','NaN'):
        raise ValueError(f'Onbekend veldtype in {key}')
    return result

def diagnostic_band(row):
    value = row.get('baseline_index', row.get('baseline_net_pct'))
    low, high = row.get('diagnostic_low'), row.get('diagnostic_high')
    if (value is None or not row.get('complete_non_degenerate') or row.get('is_reference') or
        row.get('n_valid') != row.get('n_planned') or low is None or high is None or low >= high):
        return None
    if 'baseline_index' in row and low < 0: return None
    return low, high

def validate_bundle(bundle):
    years = range(bundle['year_from'], bundle['year_to']+1)
    ids = {r['soort_id'] for r in bundle['long']}
    if not ids or len(ids) != len(bundle['long']): raise ValueError('Dubbele of ontbrekende soort-ID')
    expected_periods = {(i,p) for i in ids for p in ('pre','post')}
    expected_annual = {(i, 'pre' if y<1984 else 'post', y) for i in ids for y in years}
    if len(bundle['periods']) != len(expected_periods) or {(r['soort_id'],r['period']) for r in bundle['periods']} != expected_periods:
        raise ValueError('Periode-inventaris onvolledig of dubbel')
    if len(bundle['annual']) != len(expected_annual) or {(r['soort_id'],r['period'],r['jaar']) for r in bundle['annual']} != expected_annual:
        raise ValueError('Jaarinventaris onvolledig of dubbel')
    for key in FILES:
        for row in bundle[key]:
            if not 0 <= row['n_valid'] <= row['n_planned']: raise ValueError('Ongeldig aantal trekkingen')
            if row.get('ci95_low') is not None or row.get('ci95_high') is not None:
                raise ValueError('Diagnostische kandidaat bevat formele intervallen')
            if row.get('diagnostic_low') is not None or row.get('diagnostic_high') is not None:
                if diagnostic_band(row) is None: raise ValueError('Band zonder volledige niet-constante verdeling')
    return bundle

def build_bundle(source):
    result = dict(schema='trim-bootstrap-presentation-v1', publication_status='diagnostisch', year_from=1958, year_to=2025, files={})
    for key, name in FILES.items():
        path = source/name
        result['files'][name] = hashlib.sha256(path.read_bytes()).hexdigest()
        with path.open(newline='', encoding='utf-8') as f:
            result[key] = [{k: convert(k,v) for k,v in row.items()} for row in csv.DictReader(f)]
    return validate_bundle(result)

def render(bundle, template):
    # Escape raw-text closing tags as well as Unicode line separators.
    payload = json.dumps(bundle, ensure_ascii=False, allow_nan=False, separators=(',',':')).replace('<','\\u003c').replace('\u2028','\\u2028').replace('\u2029','\\u2029')
    return template.replace('/*BOOTSTRAP_DATA*/null', payload)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--parent-manifest',type=Path,required=True)
    parser.add_argument('--selection',type=Path,required=True)
    args = parser.parse_args()
    bundle = build_bundle(args.source)
    parent = json.loads(args.parent_manifest.read_text())
    pm = json.loads((args.source/'period_manifest.json').read_text())
    lm = json.loads((args.source/'long_manifest.json').read_text())
    if hashlib.sha256(args.parent_manifest.read_bytes()).hexdigest() != lm['parent_manifest_sha256']:
        raise ValueError('Oudermanifest past niet bij lange beoordeling')
    if parent['context_sha256'] != pm['parent_context_sha256'] or parent['analysis_end_year'] != bundle['year_to']:
        raise ValueError('Broncontext wijkt af')
    selection = json.loads(args.selection.read_text())
    if selection.get('context_sha256') != parent['context_sha256']:
        raise ValueError('Selectie mist de gecontroleerde modelcontext')
    if (set(selection['species_ids']) != {r['soort_id'] for r in bundle['long']} or
        len(selection['plot_ids']) != parent['cluster_count'] or selection['year_from'] != bundle['year_from'] or selection['year_to'] != bundle['year_to']):
        raise ValueError('Selectie past niet bij beoordeling')
    bundle.update(run_id='species-2025-2000-assessment-20261103', source_hash=parent['source_hash'],
                  cache_sha256=parent['cache_sha256'], selection=selection,
                  long_windows=dict(first='1958–1962',last='2021–2025',bridge='1979–1983 / 1986–1990'))
    template = (Path(__file__).resolve().parents[1]/'presentation/trim_bootstrap.html').read_text()
    html = render(bundle, template)
    args.output.mkdir(parents=True,exist_ok=True)
    # The HTML is the single self-contained payload. Publish its manifest last.
    target = args.output/'bootstrap.html'
    tmp = target.with_suffix('.tmp'); tmp.write_text(html); tmp.replace(target)
    manifest = {k: bundle[k] for k in ('schema','publication_status','year_from','year_to','run_id','source_hash','cache_sha256','selection','files')}
    manifest['html_sha256'] = hashlib.sha256(target.read_bytes()).hexdigest()
    tmp = args.output/'manifest.tmp'; tmp.write_text(json.dumps(manifest,indent=2)+'\n'); tmp.replace(args.output/'manifest.json')
    print(f'OK: {len(bundle["long"])} soorten, {len(bundle["periods"])} perioden, {len(bundle["annual"])} jaarposities. {target}')

if __name__ == '__main__': main()
