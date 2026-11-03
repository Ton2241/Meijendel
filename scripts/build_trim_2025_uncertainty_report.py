#!/usr/bin/env python3
"""Persist the authorized 2025 uncertainty results; all calculations stay in R."""
from pathlib import Path
import csv, json, math, shutil, sys, hashlib, re

def read(path):
    with path.open() as f:return list(csv.DictReader(f))
def write(path,rows):
    with path.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def yes(x):return x=='TRUE'
def finite(x):
    try:return math.isfinite(float(x))
    except (ValueError,TypeError):return False
def fmt(x,unit='%'):
    if not finite(x):return '—'
    v=float(x);n=2
    if unit=='%' and v> -100 and round(v,2)==-100:
        n=6
        if round(v,6)==-100:n=12
        if round(v,12)==-100:return '> −100%'
    return f'{v:+.{n}f}{unit}'.replace('-', '−')
def band(r):
    if not finite(r['diagnostic_low']):return 'geen band'
    return f"{fmt(r['diagnostic_low'])} tot {fmt(r['diagnostic_high'])}"

def readable(text):
    # Space numbers in prose; preserve literal statuses and commit identifiers.
    tokens=[]
    def keep(m):
        tokens.append(m.group(0));return chr(0xE000+len(tokens)-1)
    text=re.sub(r'`[^`]+`|\b[0-9a-f]{8,64}\b',keep,text)
    text=re.sub(r'(?<=[A-Za-zÀ-ÿ])(?=\d)|(?<=\d)(?=[A-Za-zÀ-ÿ])',' ',text)
    for i,value in enumerate(tokens):text=text.replace(chr(0xE000+i),value)
    return text

def main():
    repo,parent,root=map(Path,sys.argv[1:4]);out=root/'assessment';dest=repo/'trim/bootstrap/species_2025_2000_20261103'
    long=read(out/'long_per_species.csv');periods=read(out/'periods.csv');annual=read(out/'annual_indices.csv')
    old=read(repo/'trim/bootstrap/endpoint_2025_500_window_check_20261103/per_species.csv')
    lm=json.loads((out/'long_manifest.json').read_text());pm=json.loads((out/'period_manifest.json').read_text())
    assert len(long)==156 and len(periods)==312 and len(annual)==10608
    missing={r['soort_id'] for r in old if r['gate']=='geen_2000_langemaat'};assert len(missing)==119
    selected=[r for r in long if int(r['n_planned'])==2000];assert len(selected)==32
    stable=[r for r in selected if r['gate']=='numeriek_stabiele_kandidaat']
    complete=[r for r in selected if yes(r['complete_non_degenerate'])]
    outfall=[r for r in selected if int(r['n_valid'])<2000]
    unsettled=[r for r in selected if r['gate']=='numeriek_nog_onrustig']
    for name in ['long_per_species.csv','long_primary_estimates.csv','long_window_sensitivity.csv','long_checkpoints.csv','long_manifest.json','periods.csv','annual_indices.csv','period_manifest.json']:
        shutil.copy2(out/name,dest/name)
    subsets=[r for r in periods if r['soort_id'] in missing];subseta=[r for r in annual if r['soort_id'] in missing]
    write(dest/'periods_without_long_baseline.csv',subsets);write(dest/'annual_without_long_baseline.csv',subseta)
    pp={(r['soort_id'],r['period']):r for r in periods};aa={r['soort_id']:[] for r in long}
    for r in annual:aa[r['soort_id']].append(r)
    overview=[];md=['# Resultaten per soort: alle 156 soorten, 1958–2025','',
        'Lange maat: vast gemiddeld1958–1962 tegenover2021–2025, experimentele vijfjaarsbrug. Voor32 zijn500 bestaande trekkingen aangevuld tot2000; voor de overige124 blijft de lange beoordeling op500 staan. Eigen perioden en jaarindices hebben voor alle156 een zelfstandige beoordeling met500 bestaande trekkingen. Alle getoonde banden zijn diagnostisch; geen vrijgegeven95%-intervallen.','',
        'Periodeverandering vergelijkt de eerste en laatste vijf jaar van de eigen bevroren modelperiode. Dit zijn per soort verschillende jaren; het percentage is netto over die periode, geen percentage per jaar. Jaarindices zijn per periode genormaliseerd aan hetzelfde positieve baseline-referentiejaar=100. De jaarbanden zijn puntgewijs. Ontbrekend blijft onbekend; nul blijft nul.','']
    for r in long:
        id=r['soort_id'];ps=[pp[(id,p)] for p in ['pre','post']];ys=aa[id]
        available=[a for a in ys if finite(a['baseline_index'])]
        bands=[a for a in ys if finite(a['diagnostic_low'])]
        refs=[a for a in ys if yes(a['is_reference'])]
        flags=[]
        if yes(r['scarce_endpoint_support']):flags.append('hoogstens één positieve bronkavel in een lang begin/eindvenster; modelaanvulling kan bepalend zijn')
        if yes(r['window_direction_sensitive']):flags.append('uitgangsrichting van de lange maat wisselt bij drie/vijf/zevenjaarsvensters')
        if int(r['n_draws_with_outside_index_problems']):flags.append(f"{r['n_draws_with_outside_index_problems']} lange trekkingen met apart gemelde indexjaarproblemen buiten gebruikte vensters")
        if r['gate']=='numeriek_nog_onrustig':flags.append('lange bandgrenzen voldoen na2000 niet aan beide stabiliteitsovergangen')
        if int(r['n_valid'])<int(r['n_planned']):flags.append('lange maat zonder volledige trekkingverdeling; band geweigerd')
        thin=[a for a in available if int(a['n_positive_source_plots'])<=1]
        if thin:flags.append(f"{len(thin)} beschikbare indexjaren met hoogstens één positieve bronkavel")
        short=[p for p in ps if p['baseline_status']=='te_korte_of_onderbroken_modelperiode']
        if short:flags.append('minstens één periode te kort/onderbroken voor twee vijfjaarsvensters')
        if len(bands)<len(available)-len(refs):flags.append('niet alle beschikbare jaarindices hebben500 geldige niet-constante uitkomsten; ontbrekende banden blijven leeg')
        item=dict(r);item['long_group']='uitbreiding32' if int(r['n_planned'])==2000 else ('geen_lange_baseline119' if id in missing else 'lange_uitval5')
        for per,p in zip(['pre','post'],ps):
            for key in ['model_start','model_end','baseline_model_ok','baseline_net_pct','baseline_status','n_valid','diagnostic_low','diagnostic_high','status','both_stable']:
                item[per+'_'+key]=p[key]
        item.update(available_baseline_index_years=len(available),annual_diagnostic_bands=len(bands),annual_stable_both=sum(yes(a['both_stable']) for a in bands),reference_year_positions=len(refs),limitations='; '.join(flags))
        overview.append(item)
        md+=['### '+r['soort_naam']+' ('+id+')','',f"Lange maat: {fmt(r['baseline_net_pct'])}; {r['n_valid']}/{r['n_planned']} geldig; {band(r)}. Status: `{r['gate']}`.",'']
        for per,p in zip(['1958–1983','1984–2025'],ps):
            own=f"{p['model_start']}–{p['model_end']}" if p['model_start'] else 'geen modeljaren'
            md+=[f"- Periode {per}, eigen modeljaren {own}: netto {fmt(p['baseline_net_pct'])}; {p['n_valid']}/500 geldig; {band(p)}. `{p['baseline_status']}` / `{p['status']}`. Positieve bronkavels in eigen begin/eindvenster: {p['source_positive_begin_plots']}/{p['source_positive_end_plots']}."]
        md+=['',f"Jaarindices: {len(available)}/68 kalenderposities met een baseline-index; {len(bands)} diagnostische jaarbanden, waarvan {sum(yes(a['both_stable']) for a in bands)} bij beide opeenvolgende controles stabiel. Referentiejaar vóór1984: {ps[0]['reference_year'] or 'geen'}; vanaf1984: {ps[1]['reference_year'] or 'geen'}; de {len(refs)} vaste referentieposities krijgen geen schijnband. Alle68 jaren met hun eigen aantallen, bronsteun en status staan in annual_indices.csv.",'', 'Beperkingen: '+('; '.join(flags) if flags else 'de vaste modeljaren, bronaanvulling en model-/brugaannamen blijven gelden; dekking is niet bewezen')+'.','']
    write(dest/'species_overview.csv',overview);write(dest/'species_without_long_baseline.csv',[r for r in overview if r['soort_id'] in missing]);(dest/'PER_SOORT.md').write_text(readable('\n'.join(md)+'\n'))
    available119=sum(yes(r['baseline_model_ok']) for r in subsets);net119=sum(finite(r['baseline_net_pct']) for r in subsets)
    bands119=sum(finite(r['diagnostic_low']) for r in subsets);yb119=sum(finite(r['diagnostic_low']) for r in subseta)
    baseyb119=sum(finite(r['baseline_index']) for r in subseta)
    models119={n:sum(sum(yes(pp[(id,p)]['baseline_model_ok']) for p in ['pre','post'])==n for id in missing) for n in [0,1,2]}
    description=f'''# Onzekerheidsbeoordeling tot en met2025: alle156 soorten

Voorafcriteria: e7f68940. De bestaande500 trekkingen zijn voor32 soorten aangevuld met1500 nieuwe, IDs501–2000, met dezelfde bron1958–2025, dezelfde seed en52 gestratificeerde kavelclusters. Eerste500 zijn onaangetast; nieuwe resultaten hebben een eigen identiteit met expliciete ouderhashes. Twee oude trekkingen reproduceerden vóór de uitbreiding de32 soort- en indexuitkomsten. Er is één fitworker gebruikt. Geen2026, nieuwe database-export/cache, groepsbootstrap of publicatie.

## Lange begin/eindmaat:32 uitgebreid

Van de32 hebben **{len(complete)} soorten2000/2000 geldige niet-constante uitkomsten**. Daarvan zijn **{len(stable)} numeriek stabiele kandidaten** volgens beide vooraf gekozen grensvergelijkingen; {len(unsettled)} houden bewegende grenzen. Bij {len(outfall)} soorten is sprake van uitval; hun band wordt geweigerd. Geen formele95%-marges vrijgegeven. De overige124 behouden de500beoordeling: vijf met lange uitval en119 zonder schatbare baseline voor deze vaste lange maat. Alle156 blijven zichtbaar.

De maat blijft100×(gemiddelde index2021–2025/gemiddelde index1958–1962−1), met brug1979–1983/1986–1990. Beide modellen en een positieve brug zijn vereist. Alleen eindige niet-negatieve indices in gebruikte vensters verplicht; overige jaarproblemen apart. Nuleinde blijft−100%; nulbegin ongedefinieerd; geen nul→één of aanvulling. Dezelfde controle geldt voor alle soorten. Drie- en zevenjaarsvensters blijven afzonderlijke gevoeligheidsuitkomsten.

Bij500,1000,1500 en2000 zijn beide diagnostische percentielgrenzen opgeslagen. Voor het etiket stabiel moeten1000→1500 én1500→2000 ieder aan beide eisen voldoen: verschuiving minder dan0,1 procentpunt én minder dan5% van de actuele bandbreedte. Meer trekkingen geven geen garantie dat de percentielband de werkelijke95%-dekking heeft. Een nieuwe uitval bij2000 blijft zichtbaar; geen band uit alleen succesvolle trekkingen.

## De119 zonder lange baseline: eigen perioden en jaarindices

Deze119 soorten zijn geen uitgesloten soortgroep. {models119[2]} hebben twee bruikbare baselinemodellen, {models119[1]} één en {models119[0]} geen. Hun238 perioderegels bevatten {available119} beschikbare baselinemodellen en {net119} schatbare eigen begin/eindveranderingen. {bands119} hebben een volledige niet-constante500verdeling met diagnostische periodeband. Hun8092 kalenderposities bevatten {baseyb119} beschikbare baseline-indexjaren en {yb119} diagnostische jaarbanden. Ieder ontbrekend model, onvoldoende lang venster, uitgevallen referentiejaar en ontbrekende index blijft met eigen status zichtbaar.

Dezelfde onafhankelijke500beoordeling staat ook voor de32 uitgebreide soorten en de vijf met lange uitval, zodat alle156 vergelijkbaar zijn vastgelegd:312 perioden en10608 soort-jaarposities. Dit zijn eigen onzekerheidsbeoordelingen; de periode- en jaarbanden hebben500 trekkingen, de lange maat van32 heeft2000.

Periodeverandering: gemiddelde eerste vijf tegenover laatste vijf jaren van de eigen bevroren baseline-modelperiode. Minimaal tien opeenvolgende jaren, geen overlap of schuivende vensters. Deze jaren staan per soort vermeld en verschillen tussen soorten. De maat is netto over die periode; zij vervangt niet de bestaande formele jaarlijkse overall-trend. Nulvriendelijk betekent dat een nuleinde−100% kan zijn, niet dat een ongedefinieerd nulbegin toch een getal krijgt. Modelperioden met eerder geblokkeerde overall-uitkomsten blijven geblokkeerd voor die jaarlijkse overall-inferentie.

Jaarindex: per periode hetzelfde eerste positieve baseline-referentiejaar=100 voor alle500 trekkingen. Een nul of ontbrekende index in dat referentiejaar maakt de relatieve reeks in die trekking ongedefinieerd; er wordt niet naar een ander jaar verschoven. Nul in andere jaren blijft nul. Het referentiejaar is per definitie100 en krijgt geen schijnmarge. Ook constante nulverdelingen krijgen geen inferentiële band. De brongetelde en positief getelde kavels staan per jaar naast de index.

Voor periode- en jaarbanden gelden dezelfde volledige-verdelingseis en percentielmethode type7. Stabiliteit wordt apart bij250→375 en375→500 getoetst, in procentpunten voor periodeverandering en indexpunten voor jaarindex, telkens met relatieve5%-eis. Jaarbanden zijn puntgewijs; er is geen gelijktijdige95%-band voor de hele reeks. Alle nieuwe formeleCI-kolommen blijven leeg.

## Herstel van zelfstandige periode-uitvoer

De500 oorspronkelijke batches bewaarden postindices na brugvermenigvuldiging. Een ontbrekende brug vernietigde daarmee de zelfstandig beschikbare postindex in de uitvoer, terwijl het postmodel wel kon slagen. Waar een brugvariant positief is, zijn de indices teruggeschaald. Alleen waar beide bruggen ontbreken, zijn dezelfde succesvolle postperiodemodellen met dezelfde trekkingen, modeljaren en engine hersteld: **{pm['recovery_model_fits']} periodeherstellingen**, met **{pm['recovery_model_attempts']} afzonderlijke modelpogingen**. Modelconfiguratie en bestaande periodehelling reproduceerden; bij een afwijking zou de uitvoering stoppen. Dit zijn geen nieuwe onafhankelijke trekkingen en geen nieuwe modelregel. Voorschatbare preperioden en terug te schalen postperioden zijn hergebruikt. Het originele500archief blijft intact.

## Grenzen van gebruik

De uitkomst beschrijft de bestaande modelgecorrigeerde telnetwerkroute. Zij bewijst geen gelijk bemonsterde geografische populatie. Schaarse positieve kavels, modelaanvulling, modelkeuze en de niet volledig te scheiden methode-/tijdverschillen in de brug blijven van belang. Venstergevoeligheid zit niet automatisch in één bootstrapband. Volledig berekenbaar of numeriek stabiel betekent daarom geen bewezen95%-dekking of ecologische zekerheid. Een ontbrekend jaar wordt nooit een nul en een constante bootstrapverdeling bewijst geen afwezigheid in heel Meijendel.

## Bestanden en herkomst

- PER_SOORT.md en species_overview.csv: alle156 soorten, lange maat plus eigen perioden/jaarindices en beperkingen.
- long_per_species.csv:156 lange statussen; long_primary_estimates.csv:bron en alle relevante trekkingen; long_window_sensitivity.csv:468 vensterregels; long_checkpoints.csv:128 primaire grenscontroles.
- periods.csv:312 perioden; annual_indices.csv:10608 kalenderposities met eigen onzekerheidsbeoordeling, referentiejaar en bronsteun.
- species_without_long_baseline.csv, periods_without_long_baseline.csv en annual_without_long_baseline.csv: expliciet119 soorten,238 perioden en8092 jaarposities.
- long_manifest.json en period_manifest.json: hashes, aantallen, hergebruik, nieuwe trekkingen, herstel en batchfouten. Criteria blijven in CRITERIA.md.

Nieuwe batchtijd voor1500 trekkingen: {lm['new_batch_runtime_seconds']:.2f}seconden; herstel500periode-uitvoer: {pm['runtime_seconds']:.2f}seconden. De twee verificatietrekkingen en rapportage vallen buiten die batchtijden. Geheugengetal is R-gc, geen volledigeRSS; systeemswap is niet alleen aanR toe te schrijven. Nieuwe batchfouten:{lm['batch_errors']}; herstelfouten:{pm['batch_errors']}.

Ruwe batches, alle378468 lange vensterregels en de volledige periode-/jaarindexdrawmatrix blijven buitenGit in de canonieke map outputs/trim-2025-species-2000-20261103. Reproductie met R/run_trim_2025_2000.R, R/run_trim_period_recovery.R, R/assess_trim_2025_2000.R en R/assess_trim_period_uncertainty.R; rapport met scripts/build_trim_2025_uncertainty_report.py. Alle scripts krijgen REPO,PARENT,ROOT en waar van toepassing OUT; voorbeelden staan in het uitvoeringsplan. Geen automatisme om meer trekkingen of publicatie te starten.
'''
    (dest/'README.md').write_text(readable(description))
    summary=f'''Voor alle156 soorten uit de bewaarde Meijendel-ontwikkelbron1958–2025 is de onzekerheidsbeoordeling vastgelegd. Criteria vooraf:e7f68940. Voor32 soorten zijn de bestaande500 trekkingen met1500 uitgebreid tot2000, met dezelfde52 kavelclusters; {len(complete)} hebben2000/2000 geldige niet-constante uitkomsten, {len(stable)} halen beide grensstabiliteitscontroles en {len(outfall)} hebben uitval zonder band. Voor de overige124 blijft de lange beoordeling op500 staan: vijf met uitval en119 zonder lange baseline. Alle156 hebben daarnaast een zelfstandige beoordeling met500 trekkingen voor312 afzonderlijke perioden en10608 kalenderposities. Binnen de119 hebben{models119[2]} soorten twee,{models119[1]} één en{models119[0]} geen bruikbaar baselinemodel; {net119} eigen periodeveranderingen en {yb119} jaarindices krijgen een volledige diagnostische band. Jaarindices gebruiken een vast referentiejaar per eigen modelperiode; ontbrekend of nul referentiejaar blijft ongedefinieerd, vaste100 en constante verdelingen krijgen geen schijnmarge. {pm['recovery_model_fits']} succesvolle postperiodemodellen zijn alleen hersteld omdat bruguitval hun zelfstandige index in de opgeslagen uitvoer had gewist; dezelfde trekkingen/modeljaren/configuraties en periodehellingen zijn gecontroleerd. Eerste500 en beschermde bronuitvoer blijven behouden. Eigen periodeveranderingen zijn netto tussen eerste/laatste vijf bevroren modeljaren, geen jaarlijkse overall-trend. Jaarbanden zijn puntgewijs. Alle banden blijven diagnostisch; geen formele95%-vrijgave. Beperkte bronsteun, vensterkeuze, model-/brugaannamen en onbekende dekking blijven per soort vermeld. Geen2026-invoer, database-, dump/cache- of productiewijziging; overige bronnen in Meijendel,Meijendel_bronnen en kandidaatbronnen behouden hun status. Bewijs:trim/bootstrap/species_2025_2000_20261103/README.md,PER_SOORT.md en soort-/periode-/jaarCSV’s.'''
    summary=readable(summary)
    (out/'project_summary.txt').write_text(summary)
    (out/'register_paragraph.txt').write_text('2.000-validatie en zelfstandige perioden/jaarindices, 3 november 2026. '+summary)
    result=dict(species=156,extended=32,complete=len(complete),stable=len(stable),unsettled=len(unsettled),outfall=len(outfall),period_models_119=available119,period_baselines_119=net119,period_bands_119=bands119,annual_baselines_119=baseyb119,annual_bands_119=yb119,models119=models119)
    (dest/'report_counts.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':main()
