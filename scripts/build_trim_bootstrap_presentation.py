#!/usr/bin/env python3
"""Render an inspectable diagnostic candidate from assessed, frozen CSV results.

No TRIM refits or new bootstrap; descriptive summaries only.
No promotion to formal uncertainty. Trial outputs stay on the mounted T7.
"""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import sys
sys.path.insert(0,str(Path.home()/'Documents/GitHub/VWG_Project/scripts'))
from trial_storage import checked_tree

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

def annual_rate(rows, start_year, end_year):
    """Descriptive log-linear slope; never shift the start or discard zeros/gaps."""
    selected = [r for r in rows if start_year <= r['jaar'] <= end_year]
    result = dict(start_year=start_year, end_year=end_year,
                  estimate_pct_per_year=None, reason='ontbrekende_jaarindex',
                  method='loglineaire_samenvatting_jaarindices')
    if (len(selected) != end_year-start_year+1 or len(selected) < 3 or
        {r['jaar'] for r in selected} != set(range(start_year, end_year+1)) or
        any(r['value'] is None for r in selected)):
        return result
    if any(r['value'] == 0 for r in selected):
        return result | dict(reason='nulindex')
    if any(r['value'] < 0 for r in selected):
        return result | dict(reason='ongeldige_jaarindex')
    mean_year = sum(r['jaar'] for r in selected)/len(selected)
    slope = sum((r['jaar']-mean_year)*math.log(r['value']) for r in selected)/sum((r['jaar']-mean_year)**2 for r in selected)
    return result | dict(estimate_pct_per_year=math.expm1(slope)*100, reason='berekenbaar')

def add_annual_rates(bundle):
    # Match the dashboard's primary-series plus post-only merge, not the
    # independently normalised pre/post series from the bootstrap archive.
    root = Path(__file__).resolve().parents[1]
    merged = {}
    bundle['annual_rate_files'] = {}
    for filename, post_only in [('soortindices_bruikbare_tijdreeks.csv', False),
                                ('soortindices_per_jaar.csv', True)]:
        path = root/'trim/soorten'/filename
        bundle['annual_rate_files'][filename] = hashlib.sha256(path.read_bytes()).hexdigest()
        with path.open(newline='', encoding='utf-8') as f:
            for r in csv.DictReader(f):
                if post_only and r['brugmethode'] != 'alleen_post': continue
                key = (int(r['soort_id']), int(r['jaar']))
                # Same null-coalescing preference as getTrimIndexValue().
                value = next((number(r[k]) for k in ('index_gebrugged','index_100','trim_index')
                              if number(r.get(k)) is not None), None)
                merged[key] = dict(jaar=key[1], value=value)
    bundle['annual_rates'] = [dict(soort_id=r['soort_id'], soort_naam=r['soort_naam'],
        **annual_rate([v for (sid,y),v in merged.items() if sid == r['soort_id']], start, bundle['year_to']))
        for r in bundle['long'] for start in (1958,1990)]
    return bundle

def presentation_windows(year_from,year_to,width=5):
    if year_to-year_from+1 < 2*width:raise ValueError('Te korte begin/eindperiode')
    return dict(first=f'{year_from}–{year_from+width-1}',last=f'{year_to-width+1}–{year_to}',
                bridge='1979–1983 / 1986–1990')

def build_bundle(source, period_source=None, year_from=1958, year_to=2025):
    result = dict(schema='trim-bootstrap-presentation-v1', publication_status='diagnostisch', year_from=year_from, year_to=year_to, files={})
    for key, name in FILES.items():
        path = (period_source if period_source is not None and key != 'long' else source)/name
        result['files'][name] = hashlib.sha256(path.read_bytes()).hexdigest()
        with path.open(newline='', encoding='utf-8') as f:
            result[key] = [{k: convert(k,v) for k,v in row.items()} for row in csv.DictReader(f)]
    if period_source is not None:
        path=period_source/'period_manifest.json'
        meta=json.loads(path.read_text())
        if (meta.get('species') != len(result['long']) or meta.get('period') != f'{year_from}-{year_to}' or
            meta.get('formal_intervals') is not False or meta.get('first500_preserved_exact') is not True):
            raise ValueError('Periodebeoordeling heeft geen passende diagnostische herkomst')
        result['period_assessment']=dict(run_id=meta['run_id'],source_hash=meta['identity']['source_hash'],
            parent_context_sha256=meta['parent_context_sha256'],manifest_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    return add_annual_rates(validate_bundle(result))

def render(bundle, template):
    # Escape raw-text closing tags as well as Unicode line separators.
    payload = json.dumps(bundle, ensure_ascii=False, allow_nan=False, separators=(',',':')).replace('<','\\u003c').replace('\u2028','\\u2028').replace('\u2029','\\u2029')
    return template.replace('/*BOOTSTRAP_DATA*/null', payload)

def release_consumers(repo, website_root):
    """Bind the three existing consumers to the same generated payload."""
    paths={
        'dashboard':[repo/'bmp_meijendel_index.html'],
        'shiny':[repo/'shiny_meijendel/app.R',repo/'R/trim_bootstrap_preview.R'],
        'website':[website_root/'website/vwg-m-linux-app/app/bootstrap_presentation.py',
                   website_root/'website/vwg-m-linux-app/app/templates/species_detail.html']}
    checks={'dashboard':'outputs/bootstrap-presentatie-2026/bootstrap.html?view=dashboard',
            'shiny':'load_trim_bootstrap_preview()',
            'website':'bootstrap-preview.asp?view=simple'}
    for role,files in paths.items():
        if not any(checks[role] in p.read_text() for p in files):
            raise ValueError(f'Gedeelde bootstrapkoppeling ontbreekt: {role}')
    return {role:{str(p.relative_to(repo if role!='website' else website_root)):hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in files} for role,files in paths.items()}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--period-source',type=Path,help='Afzonderlijke latere periode-/jaarindexbeoordeling')
    parser.add_argument('--website-root',type=Path,help='Bind website, dashboard en Shiny in één lokaal kandidaatmanifest')
    parser.add_argument('--parent-manifest',type=Path,required=True)
    parser.add_argument('--selection',type=Path,required=True)
    args = parser.parse_args()
    args.output = checked_tree(args.output)
    parent = json.loads(args.parent_manifest.read_text())
    selection = json.loads(args.selection.read_text())
    bundle = build_bundle(args.source,args.period_source,int(selection['year_from']),int(parent['analysis_end_year']))
    pm = json.loads((args.source/'period_manifest.json').read_text())
    lm = json.loads((args.source/'long_manifest.json').read_text())
    if hashlib.sha256(args.parent_manifest.read_bytes()).hexdigest() != lm['parent_manifest_sha256']:
        raise ValueError('Oudermanifest past niet bij lange beoordeling')
    if parent['context_sha256'] != pm['parent_context_sha256'] or parent['analysis_end_year'] != bundle['year_to']:
        raise ValueError('Broncontext wijkt af')
    if 'period_assessment' in bundle:
        assessment=bundle['period_assessment']
        if assessment['source_hash'] != parent['source_hash'] or assessment['parent_context_sha256'] != parent['context_sha256']:
            raise ValueError('Periodebeoordeling hoort bij een andere broncontext')
    selection = json.loads(args.selection.read_text())
    if selection.get('context_sha256') != parent['context_sha256']:
        raise ValueError('Selectie mist de gecontroleerde modelcontext')
    if (set(selection['species_ids']) != {r['soort_id'] for r in bundle['long']} or
        len(selection['plot_ids']) != parent['cluster_count'] or selection['year_from'] != bundle['year_from'] or selection['year_to'] != bundle['year_to']):
        raise ValueError('Selectie past niet bij beoordeling')
    bundle.update(run_id=f"presentation-{bundle['year_from']}-{bundle['year_to']}-{args.source.name}", source_hash=parent['source_hash'],
                  cache_sha256=parent['cache_sha256'], selection=selection,
                  long_windows=presentation_windows(bundle['year_from'],bundle['year_to']))
    if 'period_assessment' in bundle:
        bundle['component_runs']={'long':bundle['run_id'],'periods':bundle['period_assessment']['run_id']}
        bundle['run_id']=f"presentation-{bundle['year_from']}-{bundle['year_to']}-{bundle['period_assessment']['run_id']}"
    template = (Path(__file__).resolve().parents[1]/'presentation/trim_bootstrap.html').read_text()
    html = render(bundle, template)
    consumers=release_consumers(Path(__file__).resolve().parents[1],args.website_root) if args.website_root else None
    args.output.mkdir(parents=True,exist_ok=True)
    # The HTML is the single self-contained payload. Publish its manifest last.
    target = args.output/'bootstrap.html'
    tmp = target.with_suffix('.tmp'); tmp.write_text(html); tmp.replace(target)
    manifest = {k: bundle[k] for k in ('schema','publication_status','year_from','year_to','run_id','source_hash','cache_sha256','selection','files','annual_rate_files')}
    for key in ('period_assessment','component_runs'):
        if key in bundle:manifest[key]=bundle[key]
    if consumers is not None:
        manifest['consumers']=consumers
        manifest['release_preparation']={'target_end_year':2026,'data_end_year':bundle['year_to'],
            'single_shared_payload':True,'production_authorized':False,
            'pending':['official_2026_validation','fresh_2026_source_products','estimator_specific_interval_decision','integral_release_checks','explicit_publication_approval']}
    manifest['html_sha256'] = hashlib.sha256(target.read_bytes()).hexdigest()
    tmp = args.output/'manifest.tmp'; tmp.write_text(json.dumps(manifest,indent=2)+'\n'); tmp.replace(args.output/'manifest.json')
    print(f'OK: {len(bundle["long"])} soorten, {len(bundle["periods"])} perioden, {len(bundle["annual"])} jaarposities. {target}')

if __name__ == '__main__': main()
