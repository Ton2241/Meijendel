#!/usr/bin/env python3
"""Durable per-species report; does not run fits or publish anything."""
import argparse,csv,hashlib,json,shutil
from pathlib import Path

def load(p):
    with p.open(newline='',encoding='utf-8') as f:return list(csv.DictReader(f))
def finite(v):
    try:return __import__('math').isfinite(float(v))
    except (ValueError,TypeError):return False
def num(v):return f'{float(v):.2f}'.replace('.',',') if finite(v) else '—'
def band(r):return f"{num(r['diagnostic_low'])} tot {num(r['diagnostic_high'])}" if finite(r['diagnostic_low']) else 'geen band'
def yes(v):return v=='TRUE'
def dump(p,rows):
    with p.open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--run',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);a=parser.parse_args()
    repo=Path(__file__).resolve().parents[1];old=repo/'trim/bootstrap/species_2025_2000_20261103';source=a.run/'assessment';out=a.output
    out.mkdir(parents=True,exist_ok=True)
    p,y,l=load(source/'periods.csv'),load(source/'annual_indices.csv'),load(old/'long_per_species.csv');op,oy=load(old/'periods.csv'),load(old/'annual_indices.csv');m=json.loads((source/'period_manifest.json').read_text());v=json.loads((source/'result_verification.json').read_text())
    assert len(p)==312 and len(y)==10608 and len(l)==156 and v['all_bounds_independently_recomputed']
    for name in ('periods.csv','annual_indices.csv','period_manifest.json','result_verification.json'):shutil.copyfile(source/name,out/name)
    change=[]
    for typ,new,prev,keys in [('period',p,op,('soort_id','period')),('annual',y,oy,('soort_id','period','jaar'))]:
        before={tuple(r[k] for k in keys):r for r in prev}
        for r in new:
            b=before[tuple(r[k] for k in keys)]
            if int(r['n_planned'])==500:continue
            change.append(dict(type=typ,soort_id=r['soort_id'],soort_naam=r['soort_naam'],period=r['period'],jaar=r.get('jaar',''),before_n_valid=b['n_valid'],before_n_planned=b['n_planned'],after_n_valid=r['n_valid'],after_n_planned=r['n_planned'],before_status=b['status'],after_status=r['status'],before_low=b['diagnostic_low'],before_high=b['diagnostic_high'],after_low=r['diagnostic_low'],after_high=r['diagnostic_high'],before_stable=b['both_stable'],after_stable=r['both_stable'],lost_band=finite(b['diagnostic_low']) and not finite(r['diagnostic_low']),gained_band=not finite(b['diagnostic_low']) and finite(r['diagnostic_low'])))
    dump(out/'changes_from_500.csv',change)
    overview=[];parts=['# Resultaten per soort: zelfstandige perioden en jaarindices tot en met 2025\n','Alle 156 soorten blijven opgenomen. Per geselecteerde periode zijn 2.000 trekkingen beoordeeld; overige perioden behouden hun 500-beoordeling. Banden zijn diagnostisch en puntgewijs, geen vrijgegeven 95%-intervallen. De lange maat is niet opnieuw berekend.\n']
    for r in sorted(l,key=lambda r:r['soort_naam'].casefold()):
        sid=r['soort_id'];ps=[x for x in p if x['soort_id']==sid];ys=[x for x in y if x['soort_id']==sid];extended=[x for x in ps if x['n_planned']=='2000'];bands=[x for x in ys if finite(x['diagnostic_low'])]
        limits=[]
        if not extended:limits.append('Geen uitbreidbare periode bij 500; bestaande blokkades hieronder behouden.')
        if any(x['status']=='uitval_geen_band' for x in ps+ys):limits.append('Uitval: geen band voor de betreffende uitkomsten; geldige en beoordeelde aantallen staan apart.')
        if any(finite(x['diagnostic_low']) and not yes(x['both_stable']) for x in ps+ys):limits.append('Een of meer margegrenzen voldoen niet aan beide stabiliteitscontroles.')
        if any(int(x[k])<2 for x in ps for k in ('source_positive_begin_plots','source_positive_end_plots')):limits.append('Minstens één eigen begin/eindvenster heeft hoogstens één positieve bronkavel; modelaanvulling kan de uitkomst bepalen.')
        if any(finite(x['baseline_index']) and int(x['n_positive_source_plots'])<2 for x in ys):limits.append('Minstens één beschikbare jaarindex berust op hoogstens één positieve bronkavel.')
        if any(x['status'] in ('baseline_model_niet_schatbaar','buiten_bevroren_modeljaren') for x in ys):limits.append('Niet voor alle kalenderposities is een modelindex beschikbaar; ontbrekende jaren blijven zichtbaar.')
        limits.append('De periodebanden omvatten geen onzekerheid van een brug of groepsindex en zijn niet de marge van de jaarlijkse percentages sinds 1958/1990. Intervaldekking en geografische representativiteit zijn niet bewezen.')
        item=dict(soort_id=sid,soort_naam=r['soort_naam'],extended_periods=len(extended),retained_500_periods=2-len(extended),period_bands=sum(finite(x['diagnostic_low']) for x in ps),stable_period_bands=sum(yes(x['both_stable']) for x in ps),annual_positions=len(ys),available_annual_indices=sum(finite(x['baseline_index']) for x in ys),annual_bands=len(bands),stable_annual_bands=sum(yes(x['both_stable']) for x in ys),long_n_planned_unchanged=r['n_planned'],long_n_valid_unchanged=r['n_valid'],limitations=' '.join(limits));overview.append(item)
        parts.append(f"\n## {r['soort_naam']} — soort-ID {sid}\n")
        parts.append('| Eigen periode | Modeljaren | Referentie | Geldig / beoordeeld | Nettoverandering (%) | Diagnostische band (%) | Beide controles stabiel |\n|---|---|---:|---:|---:|---|---|')
        for q in ps:
            parts.append(f"| {q['period_calendar_start']}–{q['period_calendar_end']} | {q['model_start'] or '—'}–{q['model_end'] or '—'} | {q['reference_year'] or '—'} | {q['n_valid']} / {q['n_planned']} | {num(q['baseline_net_pct'])} | {band(q)} | {'ja' if yes(q['both_stable']) else 'nee'} |")
        for q in ps:
            parts.append(f"\nPeriode {q['period']}: status `{q['status']}`; modelreden `{q['baseline_model_reason'] or 'geen'}`; uitval/verdeling `{q['reasons']}`. Eigen beginvenster {q['first_window'] or '—'}, eindvenster {q['last_window'] or '—'}. Positieve bronkavels in deze vensters: {q['source_positive_begin_plots']} / {q['source_positive_end_plots']}.\n")
        parts.append(f"Jaarindices: {item['available_annual_indices']} beschikbaar op 68 kalenderposities; {len(bands)} met een diagnostische band, waarvan {item['stable_annual_bands']} beide stabiliteitscontroles halen. Alle jaarwaarden, aantallen, referenties, nullen, uitvalredenen en bandgrenzen staan in annual_indices.csv.\n")
        parts.append(f"Lange begin/eindmaat ongewijzigd: {r['n_valid']} / {r['n_planned']} geldig, status `{r['status']}`.\n")
        parts.extend('- '+t for t in limits)
    dump(out/'species_overview.csv',overview);(out/'PER_SOORT.md').write_text('\n'.join(parts)+'\n')
    lost=sum(x['lost_band'] for x in change);gained=sum(x['gained_band'] for x in change);selectedp=[x for x in p if x['n_planned']=='2000'];selectedy=[x for x in y if x['n_planned']=='2000'];pb=sum(finite(x['diagnostic_low']) for x in selectedp);yb=sum(finite(x['diagnostic_low']) for x in selectedy)
    summary=f"Alle 156 soorten uit de bewaarde ontwikkelbron 1958–2025 blijven zichtbaar: 312 perioden en 10.608 kalenderposities. Van 89 soorten zijn 141 zelfstandige perioden van 500 tot 2.000 trekkingen uitgebreid; de overige 171 perioden van alle soorten behouden de oorspronkelijke 500-beoordeling. Na uitbreiding hebben {pb} van de 141 perioden een volledige niet-constante diagnostische band, waarvan {sum(yes(x['both_stable']) for x in selectedp)} beide stabiliteitscontroles halen. Bij de jaarindices zijn {yb} diagnostische banden beschikbaar, waarvan {sum(yes(x['both_stable']) for x in selectedy)} beide controles halen. Er gingen {lost} eerdere periode-/jaarbanden verloren door uitval of een niet bruikbare verdeling; deze worden niet met succesvolle subsets gerepareerd. Er kwamen {gained} diagnostische jaar-/periodebanden bij."
    (out/'README.md').write_text('# Zelfstandige periode- en jaarindexbeoordeling: 2.000 trekkingen\n\n'+summary+f"\n\nVoorafcriteria: commit 32123615, CRITERIA.md. Dezelfde 52 gestratificeerde kavelclusters, seed en bevroren modeljaren als eerder. Eerste 500 matrices exact behouden, inclusief nul- en NA-patronen. De extra trekkingsnummers 501–2000 zijn gelijk aan die van de eerdere 32-soortenuitbreiding. Hergebruik: {m['reused_period_results']} bestaande periode-uitkomsten; daarbinnen {m['recovery_fits']} herstelberekeningen van eerder geslaagde modellen waarvan eigen indices ontbraken. Nieuwe zelfstandige periodeberekeningen: {m['new_period_calculations']}, met {m['new_fit_attempts']} modelpogingen. Bij hergebruik/herstel waren {m['recovery_fit_attempts']} modelpogingen nodig. Geen nieuwe brugberekening. Batchfouten: {m['batch_errors']}; batchtijd {m['runtime_seconds']:.1f} seconden, één fitworker.\n\nDe uitbreiding herstelt geen ontbrekende baseline, nul referentiejaar of oorspronkelijke uitval. De 67 soorten zonder uitbreidbare periode blijven met hun 500-status en beschikbare waarnemingsinformatie in PER_SOORT.md staan. De lange begin/eindmaat is ongewijzigd. Jaarmarges zijn puntgewijs binnen de eigen periode en referentieschaal, geen band rond de hele gebrugde lijn en geen interval voor de jaarlijkse samenvattingen sinds 1958/1990. Meer trekken bewijst geen 95%-dekking; alle formele CI-kolommen blijven leeg. Schaarse positieve kavels, modelaanvulling, modelkeuze en geografische representativiteit blijven beperkingen. De strikte bestaande grensstabiliteitsregel is niet versoepeld. Niet automatisch door naar 5.000.\n\nBestanden: PER_SOORT.md en species_overview.csv (156 soorten), periods.csv (312 regels), annual_indices.csv (10.608 regels), changes_from_500.csv (vergelijking voor alle uitgebreide uitkomsten), period_manifest.json (herkomst/hergebruik), result_verification.json (onafhankelijke berekening van alle bandgrenzen en stabiliteitsvlaggen). Ruwe nieuwe batches, controlepunten en de volledige drawmatrix blijven buiten Git in `outputs/trim-2025-periods-2000-20261104`. De historische 500- en lange 2.000-archieven zijn behouden.\n\nReproductie: R/run_trim_period_2000.R, R/assess_trim_period_2000.R, R/check_trim_period_2000_results.R en scripts/build_trim_period_2000_report.py. Geen nieuwe brongegevens, 2026-invoer, databasewijziging, export/cachebouw, groepsbootstrap of VPS-publicatie. De lokale webpreview wordt door deze beoordeling niet stilzwijgend van gegevensversie veranderd.\n")
    (source/'summary.txt').write_text(summary+'\n')
    (source/'register_paragraph.txt').write_text('**Zelfstandige periode- en jaarindexbeoordeling uitgebreid, 4 november 2026.** '+summary+' Eerste 500 waarden en oorspronkelijke archieven zijn behouden. Alle banden blijven diagnostisch en puntgewijs; formele CI-kolommen blijven leeg. Uitval, constante verdelingen, referentiejaarproblemen en beperkte bronsteun blijven per soort zichtbaar. De lange maat en jaarlijkse percentages sinds 1958/1990 zijn ongewijzigd. Geen 2026-invoer, bron-/database-/cachewijziging, groepsbootstrap of VPS-publicatie. Bewijs: trim/bootstrap/periods_2025_2000_20261104/README.md en PER_SOORT.md.\n')
    print(summary)
if __name__=='__main__':main()
