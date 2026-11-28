#!/usr/bin/env python3
"""Bronvaste telpuntentabel en afgeleide scenario's; wijzigt geen database."""
import csv
import hashlib
import json
import subprocess
import sys
from pathlib import Path
csv.field_size_limit(16 * 1024 * 1024)


def write_csv(path, rows):
    with path.open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def main():
    root = Path(sys.argv[1]).resolve()
    subprocess.run(['python3', '/Users/ton/.codex/bin/t7_work.py', 'check', str(root)], check=True)
    out = root / 'outputs'
    source22 = 'https://www.dunea.nl/over-dunea/-/media/bestanden/duinen/rapport-trendanalyse-meijendel-29-11-22.pdf'
    source24 = 'https://www.dunea.nl/algemeen/-/media/bestanden/nieuws/update-trendanalyse-meijendel_def_sept-2024_publieksversie.pdf'
    names = {
        1: 'Meijendelseweg tussen Slingerweg en rotonde',
        2: 'Prinsenweg fietspad', 3: 'Golfzangweg fietspad',
        4: 'Fietspad uitzichtpunt Pannenduin / Ganzenhoekweg',
        5: 'Meijendelseweg fietspad', 6: 'Waalsdorpervlakte fietspad',
        7: 'Meijendelseweg tussen rotonde en Vallei',
    }
    metadata = []
    exact_descriptions = {
        1: 'Meijendelseweg thv huisnummer 30 tussen Slingerweg en rotonde parkeerterrein',
        2: 'Prinsenweg nabij Onder de Watertoren tussen Harstenhoekweg en strandopgang Noorderstrand',
        3: 'Golfzangweg tussen Uitzichtpunt Pannenduin en Vogeltbos',
        4: 'Fietspad tussen Uitzichtpunt Pannenduin en Observation deck Abeientop',
        5: 'Meijendelseweg thv lichtmasten tussen Meijendelseweg en parkeerterrein',
        6: 'Fietspad Waalsdorpervlakte tussen De Waal Malefijtpad en Monument Waalsdorpervlakte',
        7: 'Meijendelseweg tussen rotonde en Vallei Meijendel',
    }
    for point, name in names.items():
        metadata.append(dict(
            telpunt_id=f'dunea_{point}', naam=name,
            vervoerswijze='fiets_en_motorvoertuigen' if point in (1, 7) else 'fiets',
            methode='telslang_Dinaf', meetbegin='2021-11-24' if point == 7 else '2021-07-21',
            meeteind='2022-06-14' if point == 2 else '2022-07-13',
            nieuw_vergelijkbaar_begin='2022-01-01', nieuw_vergelijkbaar_eind='2023-12-31',
            exacte_x_rd='', exacte_y_rd='', locatiebron='schematische kaart figuur 3; geen getalcoordinaten',
            nadere_ligging=exact_descriptions[point], aanvullende_locatiebron=source24+' figuur 2 pagina 3',
            teldekking_2022_2023='364 dagen per jaar in tabel 6' if point in (2, 4, 5, 6) else 'niet per telpunt vastgesteld',
            datum_ontbrekende_dag='niet vermeld',
            broedseizoen='maart-juni als vooraf gekozen venster; geen dagelijkse passages beschikbaar',
            route_kavelkoppeling='niet vrijgegeven: exacte tellerlocatie en bediende route nog vaststellen',
            bron=source22, pagina='5-6',
            beperking=('2004-2006 geen telling volgens rapport' if point in (2, 4) else
                        'in 2022-rapport slechts een teljaar 2021' if point == 6 else
                        '2016 meting 6 september-1 december; geen broedseizoen' if point == 1 else ''),
        ))
    write_csv(out/'telpunten.csv', metadata)
    # Letterlijke gehele waarden uit tabellen 9 en 10, gedrukte pagina's 19-20.
    peak = {
        (2022,2): [16,24,77,100,120,58,133,260,132,49,13,0],
        (2022,4): [13,14,39,58,74,92,89,132,60,31,9,0],
        (2022,5): [0,1,0,7,5,0,8,4,1,3,1,0],
        (2022,6): [19,18,36,42,80,45,42,68,34,33,8,0],
        (2023,2): [8,7,18,65,99,232,136,170,189,31,4,1],
        (2023,4): [1,4,10,44,73,88,59,107,95,14,1,0],
        (2023,5): [0,0,0,4,5,5,0,8,9,0,0,0],
        (2023,6): [3,4,6,34,76,56,20,50,51,12,3,3],
    }
    annual = {(2022,2):982,(2022,4):611,(2022,5):30,(2022,6):425,
              (2023,2):960,(2023,4):496,(2023,5):31,(2023,6):318}
    rows=[]; contrasts=[]
    for (year, point), values in peak.items():
        for month, value in enumerate(values,1):
            rows.append(dict(telpunt_id=f'dunea_{point}',jaar=year,maand=month,
                drukke_uren=value,drempel_fietsers_per_uur=100 if point==6 else 250,
                richting='beide',eenheid='uren_boven_drempel',bron=source24,pagina='19-20',
                teldekking='364 dagen per jaar; ontbrekende datum onbekend'))
        contrasts.append(dict(telpunt_id=f'dunea_{point}',jaar=year,
            drukke_uren_maart_juni=sum(values[2:6]),jaartotaal_maandtabel=sum(values),
            jaartotaal_tabel6=annual[(year,point)],
            verschil_maandtabel_tabel6=sum(values)-annual[(year,point)],
            interpretatie='drukke uren; geen passages of bezoekersaantallen'))
    write_csv(out/'recreatie_drukke_uren_maand.csv',rows)
    write_csv(out/'recreatie_vergelijkbare_perioden.csv',contrasts)
    write_csv(out/'verkeersmodel_status.csv',[dict(
        analyse='passages_100_met_kavel_en_jaareffect',status='niet_schatbaar_met_gecontroleerde_bronnen',
        telpunten_met_maandtabellen=4,vergelijkbare_jaren='2022;2023',
        routes_met_broedseizoenpassages_en_gevalideerde_kavelkoppeling=0,
        reden='geen ruwe passagewaarden per meetdag en geen exacte telpunt-route-kavelkoppeling; drukke uren zijn andere meeteenheid',
        gevonden='Dunea 2022 en 2024; WUR-catalogus deel XXIV en deel XXIII; lokale Zotero en T7-bestandszoekactie',
        bronhouder='Dunea bezit ruwe Dinaf-tellingen; geen externe aanvraag verzonden')])

    with (out/'bron_gebieden.tsv').open() as stream:
        areas=list(csv.DictReader(stream,delimiter='\t'))
    scenarios=[]
    def scenario(sid,area,before,after,earliest,latest,geometry,source,quality,status):
        scenarios.append(dict(scenario_id=sid,gebied_of_routesegment=area,status_voor=before,
            status_na=after,wijziging_vroegst=earliest,wijziging_laatst=latest,
            geometrieversie=geometry,bronverwijzing=source,bewijskwaliteit=quality,analyse_status=status))
    for area in areas:
        scenario('brongebonden',area['gebied_code'],'onbekend',area['status_code'],'','',
            area['geometrie_sha256'],f"maatregel_bron:{area['bron_id']}; vastgesteld {area['vastgesteld_op']}",
            'actuele kaart; historische periode niet onafhankelijk onderbouwd','alleen_kaartstand_2026')
        scenario('maximale_terugprojectie',area['gebied_code'],'onbekend',area['status_code'],
            '1955-01-01','1955-01-01',area['geometrie_sha256'],'inschatting eigenaar; stresstest',
            'veronderstelling; geen historisch bewijs','alleen_stresstest_geen_gebeurteniseffect')
    for event,source in [('gedeeltelijke_openstelling_1959','Het Vrije Volk 1959-05-23 ddd:010953402:mpeg21:a0281'),
                         ('toegangsbeperking_1969','Rotterdamsch Parool 1969-09-24 MMSARO03:259066021:mpeg21:a00103')]:
        for timing in ['vroeg','midden','laat']:
            scenario(f'{event}_{timing}','nog_niet_gekoppeld','onbekend','onbekend','','','',source,
                'zoekanker; ingangsdatum en grens onbewezen','niet_schatbaar')
    for variant in ['historische_routetakken','strook_onbekend_voor_eerste_bewijs','strook_volgt_omringend_gebied']:
        scenario(f'corridor_{variant}','fietspadcorridor','onbekend','toegankelijk','','',
            '0b59cc88a80de095f9d2473e688c4f823704b8d3454605cecef5bb12d700a79b',
            'goedgekeurd GeoPackage 2026-11-10; WUR-XXIII volledige tekst niet verkregen',
            'historische routetakgrenzen en datums ontbreken','niet_schatbaar')
    write_csv(out/'scenariomatrix.csv',scenarios)
    with (out/'kavelcontrasten.csv').open() as stream:
        shares=list(csv.DictReader(stream))
    annual_scenarios=[]
    for plot in shares:
        for year in range(1950,2027):
            for sid in ['brongebonden','maximale_terugprojectie']:
                # Een momentopname uit november bewijst ook voor het kaartjaar
                # zelf geen regime tijdens het eerdere broedseizoen.
                known = sid=='maximale_terugprojectie' and year>=1955
                annual_scenarios.append(dict(scenario_id=sid,plot_id=plot['plot_id'],kavel=plot['kavel'],jaar=year,
                    toegankelijk=float(plot['toegankelijk_aandeel']) if known else 0,
                    afgesloten=float(plot['afgesloten_aandeel']) if known else 0,
                    seizoensgebonden=float(plot['toegankelijk_buiten_broedseizoen_aandeel']) if known else 0,
                    dagkaart=float(plot['toegankelijk_met_toegangskaart_aandeel']) if known else 0,
                    aandeel_onbekend=0 if known else 1,
                    ruimtelijke_basis='huidige_kavelgeometrie_geen_bewijs_historisch_kavelbestaan'))
    write_csv(out/'scenario_kaveljaar.csv',annual_scenarios)
    hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file() and p.suffix in ('.csv','.tsv','.json') and p.name!='bron_en_uitvoer_hashes.json'}
    (out/'bron_en_uitvoer_hashes.json').write_text(json.dumps(hashes,indent=2)+'\n')
    print(json.dumps(dict(telpunten=len(metadata),maandregels=len(rows),scenario_regels=len(scenarios),
        kaveljaar_scenario_regels=len(annual_scenarios),maandtabel_verschillen=[r for r in contrasts if r['verschil_maandtabel_tabel6']]),indent=2))


if __name__=='__main__':
    main()
