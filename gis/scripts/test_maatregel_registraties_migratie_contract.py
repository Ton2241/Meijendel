#!/usr/bin/env python3
"""Echte MySQL-proef: behoud, vijf duplicaten, idempotentie en herstel."""
import importlib.util
import json
import subprocess
import tempfile
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'gis/scripts/migrate_maatregel_registraties.py'

def main():
    assert SCRIPT.exists(), 'migratie ontbreekt'
    spec = importlib.util.spec_from_file_location('migration', SCRIPT)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    db = 'meijendel_registratie_test_' + uuid.uuid4().hex[:10]
    c = m.Client(db)
    c.sql(f'CREATE DATABASE `{db}` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci', selected=False)
    try:
        c.sql('CREATE TABLE plots(plot_id INT PRIMARY KEY,kavel_nummer VARCHAR(255),in_gebruik TINYINT DEFAULT 1); CREATE TABLE maatregelen(id INT PRIMARY KEY,code VARCHAR(50),omschrijving TEXT); CREATE TABLE ndff_sovon_plotversie(plotversie_id BIGINT UNSIGNED PRIMARY KEY,versie VARCHAR(32),bronbestand VARCHAR(500),bronbestand_sha256 CHAR(64),crs_epsg INT,objectaantal INT);')
        c.sql((ROOT/'gis/database/maatregelen_schema.sql').read_text().replace('USE Meijendel;', ''))
        c.sql("INSERT INTO maatregelen VALUES (3,'begrazing','Begrazing');")
        names=['M15','M16','M13','M13s','M14']+[f'T{i}' for i in range(6,56)]
        for i,name in enumerate(names,1): c.sql(f'INSERT INTO plots(plot_id,kavel_nummer) VALUES ({i},{m.literal(name)})')
        c.sql("INSERT INTO maatregel_project(project_code,naam,werkcategorie_code) VALUES ('test','Test','natuurbeheer'); INSERT INTO maatregel_bron(bron_code,brontype_code,titel,raadpleegdatum) VALUES ('test','beheerpublicatie','Test',CURRENT_DATE);")
        for code in set(m.DUPLICATES.values()):
            c.sql(f"INSERT INTO maatregel_uitvoering(uitvoering_code,project_id,maatregel_id,maatregeltype_code,activiteit_code,uitvoering_status_code,naam,locatie_naam,locatie_precisie,datum_precisie) VALUES ({m.literal(code)},1,3,'MT01','A01','uitgevoerd','Test','Test','benoemd_deelgebied','jaar')")
        for (plot,year),code in m.DUPLICATES.items():
            pid=names.index(plot)+1
            c.sql(f"INSERT IGNORE INTO maatregel_uitvoering_jaar SELECT uitvoering_id,{year},'uitgevoerd',1,NULL FROM maatregel_uitvoering WHERE uitvoering_code={m.literal(code)}; INSERT INTO maatregel_plot_koppeling SELECT uitvoering_id,{pid},'expliciet_in_bron',NULL,'geverifieerd',1,NULL FROM maatregel_uitvoering WHERE uitvoering_code={m.literal(code)};")
        c.sql("CREATE TABLE plot_jaar_maatregel(id INT PRIMARY KEY,plot_id INT,jaar SMALLINT UNSIGNED,bron VARCHAR(50),maatregel_id INT,intensiteit_code VARCHAR(30),uitvoerder_of_diersoort VARCHAR(50),deel_label VARCHAR(100),dekking_pct DECIMAL(5,2),opmerking VARCHAR(255)); CREATE TABLE plot_jaar_toegankelijkheid(plot_id INT,plot_naam VARCHAR(255),jaar INT,bron VARCHAR(50),status_code VARCHAR(30),opmerking VARCHAR(255),PRIMARY KEY(plot_id,jaar,bron)); CREATE TABLE plot_jaar_toegankelijkheid_deel(id INT PRIMARY KEY,plot_id INT,jaar INT,bron VARCHAR(50),deel_label VARCHAR(100),status_code VARCHAR(30),aandeel_pct DECIMAL(5,2),barriere_type VARCHAR(50),geom_wkt LONGTEXT,opmerking VARCHAR(255));")
        rid=0
        for pid in range(1,17):
            for year in range(1991,2000):
                rid+=1;c.sql(f"INSERT INTO plot_jaar_maatregel VALUES ({rid},{pid},{year},'HANDMATIG',3,'','','',NULL,NULL)")
        for pid in range(1,56): c.sql(f"INSERT INTO plot_jaar_toegankelijkheid VALUES ({pid},'Plot {pid}',2024,'HANDMATIG','vrij',NULL)")
        with tempfile.TemporaryDirectory() as tmp:
            backup=Path(tmp)/'backup'
            before=m.snapshot(c)
            m.apply(c,backup)
            assert c.scalar("SELECT COUNT(*) FROM information_schema.views WHERE table_schema=DATABASE() AND table_name IN ('plot_jaar_maatregel','plot_jaar_toegankelijkheid','plot_jaar_toegankelijkheid_deel') AND is_updatable='NO' AND security_type='DEFINER'")==3
            assert len(c.rows('maatregel_plot_jaar_registratie'))==139
            assert len(c.rows('maatregel_toegankelijkheid_registratie'))==55
            assert len(c.rows('maatregel_registratie_herkomst'))==199
            # Echte tabelgerichte dump: SQL-views bevatten geen oude INSERT-blokken.
            dump=Path(tmp)/'new.sql';out=Path(tmp)/'r.json'
            tables=list(m.NEW)+['maatregel_bron','maatregel_uitvoering','maatregel_uitvoering_jaar','maatregel_plot_koppeling']
            dump.write_bytes(subprocess.run(c.command('mysqldump')+['--no-tablespaces','--complete-insert','--set-gtid-purged=OFF',db,*tables],capture_output=True,check=True).stdout)
            rscript=Path(tmp)/'compare.R'
            rscript.write_text('source("'+str(ROOT/'shiny_meijendel/helpers.R')+'"); x<-reconstruct_legacy_maatregel_rows(read_maatregel_registration_tables("'+str(dump)+'",audit=TRUE)); jsonlite::write_json(x,"'+str(out)+'",dataframe="rows",auto_unbox=TRUE,na="null",null="null");')
            subprocess.run(['Rscript',str(rscript)],cwd=ROOT,check=True)
            actual=json.loads(out.read_text())
            assert {t:sorted(actual[t],key=m.stable) for t in m.OLD}==before, 'R/SQL-verschil'
            c.sql("INSERT INTO maatregel_plot_jaar_registratie(plot_id,jaar,maatregel_id,bron_id,deel_label,intensiteit_code) VALUES (1,1991,3,1,'deel noord','extensief')")
            assert c.scalar('SELECT COUNT(*) FROM v_plot_jaar_maatregel_gecombineerd')==c.scalar('SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast')+140,'onbewezen dubbeling onderdrukt'
            dump.write_bytes(subprocess.run(c.command('mysqldump')+['--no-tablespaces','--complete-insert','--set-gtid-purged=OFF',db,*tables],capture_output=True,check=True).stdout)
            subprocess.run(['Rscript',str(rscript)],cwd=ROOT,check=True)
            actual=json.loads(out.read_text())
            assert {t:sorted(actual[t],key=m.stable) for t in m.OLD}==m.snapshot(c),'SQL/R-pariteit nieuwe feiten'
            c.sql("DELETE FROM maatregel_plot_jaar_registratie WHERE deel_label='deel noord'")
            for invalid in ["INSERT INTO maatregel_plot_jaar_registratie(plot_id,jaar,maatregel_id,bron_id,dekking_pct) VALUES (1,2026,3,1,101)","INSERT INTO maatregel_registratie_herkomst(brontabel,bronsleutel,oorspronkelijke_rij,rij_sha256,migratieversie) VALUES ('test','1','{}',REPEAT('0',64),'test')"]:
                try:c.sql(invalid)
                except RuntimeError:pass
                else:raise AssertionError('ongeldige registratie toegelaten')

            # Beide schrijfroutes zijn idempotent, ook voor de vijf oude dubbelingen.
            for filename,source in [('16_import_maatregelen.sql','beheer.csv'),('11_import_toegankelijkheid.sql','toegang.csv')]:
                import csv,re
                table=m.OLD[0] if source=='beheer.csv' else m.OLD[1]
                cols=[x for x in before[table][0] if x not in ('id','plot_naam')]
                # Volg de vaste CSV-kolomvolgorde van de bestaande import.
                cols=['plot_id','jaar','bron','maatregel_id','intensiteit_code','uitvoerder_of_diersoort','deel_label','dekking_pct','opmerking'] if table==m.OLD[0] else ['plot_id','jaar','bron','status_code','opmerking']
                csvpath=Path(tmp)/source
                with csvpath.open('w',newline='') as stream:
                    writer=csv.DictWriter(stream,fieldnames=cols,extrasaction='ignore');writer.writeheader();writer.writerows(before[table])
                sql=(ROOT/'Ruimtelijke data'/filename).read_text()
                sql=re.sub(r"LOCAL INFILE '[^']+'", "LOCAL INFILE '"+str(csvpath)+"'",sql).replace('USE Meijendel;', '')
                # local_infile staat bewust uit op de iMac. Test dezelfde SQL na
                # staging van CSV-waarden; verander geen globale serverinstelling.
                staged='INSERT INTO tmp_maatregel_import ('+','.join(cols)+') VALUES '+','.join('('+','.join(m.literal(row.get(col)) for col in cols)+')' for row in before[table])+';'
                sql=re.sub(r'LOAD DATA LOCAL INFILE .*?;\n',staged+'\n',sql,flags=re.S)
                for _ in range(2):
                    cmd=c.command()+['--local-infile=1',db]
                    result=subprocess.run(cmd,input=sql,text=True,capture_output=True)
                    assert result.returncode==0,result.stderr
                assert m.snapshot(c)==before,'herimport verandert of verdubbelt oude feiten'
                if table==m.OLD[1]:
                    changed=sql.replace(m.literal('vrij'),m.literal('beperkt'),1)
                    result=subprocess.run(c.command()+[db],input=changed,text=True,capture_output=True)
                    assert result.returncode==0,result.stderr
                    assert len(c.rows('maatregel_toegankelijkheid_registratie'))==55,'correctie verdubbelt feiten'
                    result=subprocess.run(c.command()+[db],input=sql,text=True,capture_output=True)
                    assert result.returncode==0,result.stderr
                    assert m.snapshot(c)==before,'herstel van gecorrigeerde bron faalt'

            m.verify(c,backup)
            m.verify(c,backup); m.apply(c,backup);m.verify(c,backup)
            assert m.snapshot(c)==before
            assert c.scalar("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name IN ('plot_jaar_maatregel','plot_jaar_toegankelijkheid','plot_jaar_toegankelijkheid_deel') AND table_type='BASE TABLE'")==0
            # Een gewijzigde canonieke waarde moet door behoudscontrole worden ontdekt.
            c.sql("UPDATE maatregel_plot_jaar_registratie SET intensiteit_code='test' LIMIT 1")
            try: m.verify(c,backup)
            except (AssertionError,RuntimeError): pass
            else: raise AssertionError('inhoudsverlies niet ontdekt')
            c.sql("UPDATE maatregel_plot_jaar_registratie SET intensiteit_code='' WHERE intensiteit_code='test'")
            m.restore(c,backup)
            assert m.snapshot(c)==before
            # Onderbreking na atomair hernoemen: herstel moet alle drie tabellen terugzetten.
            m.apply(c,backup,interrupt_after_rename=True)
            try: m.apply(c,backup)
            except RuntimeError: pass
            else: raise AssertionError('onderbroken migratie ten onrechte als voltooid gemeld')
            m.restore(c,backup)
            assert m.snapshot(c)==before
            m.apply(c,backup);m.verify(c,backup)
            # De uiteindelijke afnemers moeten zonder enige oude view blijven werken.
            m.retire_views(c,Path(tmp)/'views-backup',backup)
            assert all(c.kind(t)=='' for t in m.OLD)
            m.verify(c,backup)
            m.retire_views(c,Path(tmp)/'views-backup',backup)
            m.apply(c,backup)
            assert all(c.kind(t)=='' for t in m.OLD)
            rscript.write_text('source("'+str(ROOT/'shiny_meijendel/helpers.R')+'"); x<-build_maatregel_registration_data(read_maatregel_registration_tables("'+str(dump)+'")); stopifnot(nrow(x$maatregel_beheer_jaar)==145L,nrow(x$maatregel_toegankelijkheid_registratie)==55L,!any(c("plot_jaar_maatregel","plot_jaar_toegankelijkheid") %in% names(x)));')
            # De eerdere dump bevat 140 aanvullende feiten + vijf bestaande doelen.
            subprocess.run(['Rscript',str(rscript)],cwd=ROOT,check=True)
        print('OK: 139/55 feiten, 199 herkomsten, vijf duplicaten, inhoudscontrole, herhaling en herstel')
    finally:
        c.sql(f'DROP DATABASE `{db}`',selected=False)
if __name__=='__main__': main()
