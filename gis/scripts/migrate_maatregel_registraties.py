#!/usr/bin/env python3
"""Gerichte lokale migratie; geen volledige dump, cachebouw of publicatie."""
from __future__ import annotations
import argparse
from contextlib import contextmanager
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OLD = ('plot_jaar_maatregel','plot_jaar_toegankelijkheid','plot_jaar_toegankelijkheid_deel')
NEW = ('maatregel_registratie_herkomst','maatregel_toegankelijkheid_registratie','maatregel_plot_jaar_registratie')
VERSION = 'beheer-toegang-v1-20261016'
BRON = 'legacy_beheer_toegang_20261016'
DUPLICATES = {('M15',1991):'begrazing_helmduinen_1991',('M16',1991):'begrazing_helmduinen_1991',('M13',1997):'kikkervalleien_begrazing_1997',('M13s',1997):'kikkervalleien_begrazing_1997',('M14',1997):'kikkervalleien_begrazing_1997'}

def literal(value):
    if value is None: return 'NULL'
    if isinstance(value,(int,float)): return str(value)
    return "CONVERT(X'"+str(value).encode().hex()+"' USING utf8mb4)"

def stable(value): return json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':'))
def digest(value): return hashlib.sha256(stable(value).encode()).hexdigest()

class Client:
    def __init__(self,database,login_path='meijendel_root'):
        if not re.fullmatch(r'[A-Za-z0-9_]+',database): raise ValueError('Ongeldige database')
        self.database=database;self.login_path=login_path
    def command(self,tool='mysql'):
        return ['/usr/local/mysql/bin/'+tool,'--login-path='+self.login_path,'--host=127.0.0.1','--protocol=TCP']
    def sql(self,sql,selected=True):
        cmd=self.command()+['--batch','--raw','--skip-column-names']+([self.database] if selected else [])
        p=subprocess.run(cmd,input=sql,text=True,capture_output=True)
        if p.returncode: raise RuntimeError(p.stderr.strip())
        return p.stdout.strip()
    def scalar(self,sql): return int(self.sql(sql))
    def columns(self,table):
        return self.sql(f"SELECT COLUMN_NAME FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name={literal(table)} ORDER BY ORDINAL_POSITION").splitlines()
    def rows(self,table):
        cols=self.columns(table)
        if not cols: raise RuntimeError('Tabel/schema ontbreekt: '+table)
        pairs=','.join(literal(x)+',`'+x+'`' for x in cols)
        result=self.sql(f'SELECT JSON_OBJECT({pairs}) FROM `{table}`')
        return sorted([json.loads(x) for x in result.splitlines()],key=stable)
    def kind(self,table):
        return self.sql(f'SELECT TABLE_TYPE FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name={literal(table)}')

@contextmanager
def migration_lock(c):
    name='maatregel_registraties:'+c.database
    cmd=c.command()+['--batch','--raw','--skip-column-names','--unbuffered']
    proc=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    try:
        proc.stdin.write(f"SELECT GET_LOCK({literal(name)},0);\nSELECT SLEEP(86400);\n");proc.stdin.flush()
        if proc.stdout.readline().strip()!='1': raise RuntimeError('Migratie wordt reeds uitgevoerd')
        yield
    finally:
        proc.terminate();proc.wait(timeout=10)

def snapshot(c): return {t:c.rows(t) for t in OLD}

def audit(c):
    rows=snapshot(c)
    if c.kind(OLD[0])=='VIEW': return rows
    counts=[len(rows[t]) for t in OLD]
    if counts!=[144,55,0]: raise RuntimeError(f'Bronomvang gewijzigd: {counts}; eerst beoordelen')
    if any(r['jaar'] not in range(1991,2000) or r['maatregel_id']!=3 or r['bron']!='HANDMATIG' or any(r[k]!='' for k in ('intensiteit_code','uitvoerder_of_diersoort','deel_label')) or any(r[k] is not None for k in ('dekking_pct','opmerking')) for r in rows[OLD[0]]): raise RuntimeError('Begrazingsinhoud wijkt af van goedgekeurde migratie')
    if any(r['jaar']!=2024 for r in rows[OLD[1]]): raise RuntimeError('Toegankelijkheidsperiode gewijzigd')
    plots={r['plot_id']:r['kavel_nummer'] for r in c.rows('plots')}
    for (name,year),code in DUPLICATES.items():
        targets=c.scalar(f"SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast v JOIN plots p USING(plot_id) WHERE p.kavel_nummer={literal(name)} AND jaar={year} AND uitvoering_code={literal(code)} AND maatregel_id=3")
        if targets!=1 or sum(plots.get(r['plot_id'])==name and r['jaar']==year for r in rows[OLD[0]])!=1: raise RuntimeError('Dubbelingsdoel ontbreekt of is meervoudig: '+name)
    incoming=c.scalar("SELECT COUNT(*) FROM information_schema.key_column_usage WHERE referenced_table_schema=DATABASE() AND referenced_table_name IN ("+','.join(map(literal,OLD))+")")
    if incoming: raise RuntimeError('Inkomende foreign keys blokkeren omschakeling')
    return rows

def backup(c,path,rows):
    path=Path(path)
    manifest=path/'manifest.json'
    if manifest.exists():
        info=json.loads(manifest.read_text())
        if info['database']!=c.database or info['snapshot']!=rows: raise RuntimeError('Back-up hoort bij andere database/broninhoud')
        if hashlib.sha256((path/'restore.sql').read_bytes()).hexdigest()!=info['dump_sha256']: raise RuntimeError('Back-uphash wijkt af')
        return info
    path.mkdir(parents=True,exist_ok=False)
    path.chmod(0o700)
    cmd=c.command('mysqldump')+['--no-tablespaces','--single-transaction','--complete-insert','--set-gtid-purged=OFF','--skip-dump-date',c.database,*OLD]
    dump=subprocess.run(cmd,capture_output=True,check=True).stdout
    (path/'restore.sql').write_bytes(dump)
    info={'database':c.database,'snapshot':rows,'dump_sha256':hashlib.sha256(dump).hexdigest(),'version':VERSION,'brontype_existed':c.scalar("SELECT COUNT(*) FROM maatregel_brontype WHERE brontype_code='handmatige_registratie'"),'source_existed':c.scalar(f'SELECT COUNT(*) FROM maatregel_bron WHERE bron_code={literal(BRON)}'),'bronvast_count':c.scalar('SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast'),'grants':c.sql("SELECT CONCAT(grantee,'|',table_name,'|',privilege_type) FROM information_schema.table_privileges WHERE table_schema=DATABASE() ORDER BY grantee,table_name,privilege_type")}
    manifest.write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n')
    if snapshot(c)!=rows: raise RuntimeError('Bron wijzigde tijdens back-up')
    return info

def json_value(col,typ): return f"JSON_VALUE(h.oorspronkelijke_rij,'$.{col}' RETURNING {typ} NULL ON EMPTY NULL ON ERROR)"

def view_sql():
    # Feiten komen uit de canonieke tabellen; JSON bevat alleen oorspronkelijke presentatie/ids.
    id_expr=json_value('id','SIGNED')
    bron_expr=json_value('bron','CHAR(50)')
    specs={
      OLD[0]: [('id',f'COALESCE({id_expr},-a.registratie_id)'),('plot_id','a.plot_id'),('jaar','a.jaar'),('bron',f'COALESCE({bron_expr},b.bron_code)'),('maatregel_id','a.maatregel_id'),('intensiteit_code','a.intensiteit_code'),('uitvoerder_of_diersoort','a.uitvoerder_of_diersoort'),('deel_label','a.deel_label'),('dekking_pct','a.dekking_pct'),('opmerking','a.opmerking')],
      OLD[1]: [('plot_id','a.plot_id'),('plot_naam',json_value('plot_naam','CHAR(255)')),('jaar','a.jaar'),('bron',f'COALESCE({bron_expr},b.bron_code)'),('status_code','a.status_code'),('opmerking','a.opmerking')],
      OLD[2]: [('id',f'COALESCE({id_expr},-a.registratie_id)'),('plot_id','a.plot_id'),('jaar','a.jaar'),('bron',f'COALESCE({bron_expr},b.bron_code)'),('deel_label','a.deel_label'),('status_code','a.status_code'),('aandeel_pct','a.aandeel_pct'),('barriere_type','a.barriere_type'),('geom_wkt','a.geom_wkt'),('opmerking','a.opmerking')]
    }
    sql=[]
    for t,cols in specs.items():
        beheer=t==OLD[0];fk='beheer_registratie_id' if beheer else 'toegang_registratie_id'
        target='maatregel_plot_jaar_registratie' if beheer else 'maatregel_toegankelijkheid_registratie'
        text=f'CREATE OR REPLACE ALGORITHM=TEMPTABLE SQL SECURITY DEFINER VIEW `{t}` AS SELECT '+','.join(expr+' AS `'+name+'`' for name,expr in cols)+f' FROM {target} a JOIN maatregel_bron b USING(bron_id) LEFT JOIN maatregel_registratie_herkomst h ON h.{fk}=a.registratie_id AND h.brontabel={literal(t)}'
        if not beheer: text+=" WHERE a.niveau="+literal('plot' if t==OLD[1] else 'deel')
        else:
            dup=[]
            for name,_ in cols:
                if name in ('plot_id','jaar','maatregel_id'): expr='v.'+name
                else: expr=json_value(name,{'id':'SIGNED','dekking_pct':'DECIMAL(5,2)'}.get(name,'CHAR(255)'))
                dup.append(expr+' AS `'+name+'`')
            text+=' UNION ALL SELECT '+','.join(dup)+" FROM maatregel_registratie_herkomst h JOIN v_plot_jaar_maatregel_bronvast v ON v.uitvoering_id=h.uitvoering_id AND v.plot_id=h.plot_id AND v.jaar=h.jaar WHERE h.brontabel="+literal(t)
        sql.append(text+';')
    # Aanvullende beschrijvende selectie: volledige bronvaste laag plus uitsluitend aanvullende feiten.
    sql.append("CREATE OR REPLACE ALGORITHM=TEMPTABLE SQL SECURITY DEFINER VIEW v_plot_jaar_maatregel_gecombineerd AS SELECT plot_id,jaar,maatregel_id,uitvoering_id,bron_id,'bronvast' AS registratiestatus FROM v_plot_jaar_maatregel_bronvast UNION ALL SELECT a.plot_id,a.jaar,a.maatregel_id,a.uitvoering_id,a.bron_id,a.beoordelingsstatus FROM maatregel_plot_jaar_registratie a;")
    return '\n'.join(sql)

def apply(c,path,interrupt_after_rename=False):
    if c.kind(OLD[0])=='VIEW': verify(c,path);return
    rows=audit(c);info=backup(c,path,rows)
    for t in NEW:
        if c.kind(t) and c.scalar('SELECT COUNT(*) FROM `'+t+'`'): raise RuntimeError('Nieuwe tabellen bevatten reeds registraties; eerst herstel/audit')
    suffix=(ROOT/'gis/database/maatregelen_schema.sql').read_text().split('-- Jaarfeiten en toestandsregistraties;',1)[1]
    c.sql('-- Jaarfeiten en toestandsregistraties;'+suffix)
    plots={r['plot_id']:r['kavel_nummer'] for r in c.rows('plots')}
    executions={r['uitvoering_code']:r['uitvoering_id'] for r in c.rows('maatregel_uitvoering')}
    statements=["START TRANSACTION;", "INSERT INTO maatregel_brontype VALUES ('handmatige_registratie',NULL,'Oorspronkelijke handmatige bronregistratie') ON DUPLICATE KEY UPDATE brontype_code=brontype_code;",f"INSERT INTO maatregel_bron(bron_code,brontype_code,titel,raadpleegdatum,bronstatus,opmerking) VALUES ({literal(BRON)},'handmatige_registratie','Historische handmatige beheer- en toegankelijkheidsregistraties',CURRENT_DATE,'overgenomen_bronregistratie','Administratieve migratie; geen nieuwe onafhankelijke bronbevestiging') ON DUPLICATE KEY UPDATE bron_code=bron_code;",f'SET @bron=(SELECT bron_id FROM maatregel_bron WHERE bron_code={literal(BRON)});']
    for t in OLD:
        for row in rows[t]:
            duplicate=DUPLICATES.get((plots[row['plot_id']],row['jaar'])) if t==OLD[0] else None
            key=str(row['id']) if 'id' in row else stable([row['plot_id'],row['jaar'],row['bron']])
            columns=['brontabel','bronsleutel','oorspronkelijke_rij','rij_sha256','migratieversie']
            values=[literal(t),literal(key),literal(stable(row)),literal(digest(row)),literal(VERSION)]
            if duplicate:
                columns+=['uitvoering_id','plot_id','jaar']; values+=map(literal,[executions[duplicate],row['plot_id'],row['jaar']])
            else:
                table='maatregel_plot_jaar_registratie' if t==OLD[0] else 'maatregel_toegankelijkheid_registratie'
                fields=['plot_id','jaar']+(['maatregel_id','intensiteit_code','uitvoerder_of_diersoort','deel_label','dekking_pct','opmerking'] if t==OLD[0] else ['status_code','opmerking']+(['deel_label','aandeel_pct','barriere_type','geom_wkt'] if t==OLD[2] else []))
                fvalues=[literal(row[k]) for k in fields]
                fields+=['bron_id'];fvalues+=['@bron']
                if t!=OLD[0]: fields+=['niveau'];fvalues+=[literal('plot' if t==OLD[1] else 'deel')]
                statements.append(f"INSERT INTO {table} ({','.join(fields)}) VALUES ({','.join(fvalues)});")
                columns+=['beheer_registratie_id' if t==OLD[0] else 'toegang_registratie_id'];values+=['LAST_INSERT_ID()']
            statements.append(f"INSERT INTO maatregel_registratie_herkomst ({','.join(columns)}) VALUES ({','.join(values)});")
    statements+=['COMMIT;'];c.sql('\n'.join(statements))
    if snapshot(c)!=rows: raise RuntimeError('Bron veranderde vóór omschakeling; herstel vereist')
    c.sql('RENAME TABLE '+','.join(f'`{t}` TO `{t}_migratie_oud`' for t in OLD))
    if interrupt_after_rename: return
    c.sql(view_sql())
    verify(c,path)
    c.sql('DROP TABLE '+','.join('`'+t+'_migratie_oud`' for t in OLD))

def verify(c,path):
    info=json.loads((Path(path)/'manifest.json').read_text())
    if info['database']!=c.database: raise RuntimeError('Verkeerde back-updatabase')
    if snapshot(c)!=info['snapshot']: raise RuntimeError('Canonieke reconstructie verschilt van bron')
    origins=c.rows('maatregel_registratie_herkomst')
    if len(origins)!=199: raise RuntimeError('Herkomstomvang wijkt af')
    if sum(x['uitvoering_id'] is not None for x in origins)!=5: raise RuntimeError('Ontdubbeling wijkt af')
    for x in origins:
        if digest(x['oorspronkelijke_rij'])!=x['rij_sha256']: raise RuntimeError('Herkomsthash wijkt af')
    if c.scalar('SELECT COUNT(*) FROM v_plot_jaar_maatregel_bronvast')!=info['bronvast_count']: raise RuntimeError('Bronvaste laag veranderde')
    grants=c.sql("SELECT CONCAT(grantee,'|',table_name,'|',privilege_type) FROM information_schema.table_privileges WHERE table_schema=DATABASE() ORDER BY grantee,table_name,privilege_type")
    if grants!=info['grants']: raise RuntimeError('Bestaande tabelrechten veranderden')

def restore(c,path):
    path=Path(path);info=json.loads((path/'manifest.json').read_text())
    if info['database']!=c.database or hashlib.sha256((path/'restore.sql').read_bytes()).hexdigest()!=info['dump_sha256']: raise RuntimeError('Herstelbron ongeldig')
    for t in OLD:
        if c.kind(t)=='VIEW': c.sql(f'DROP VIEW `{t}`')
        elif c.kind(t)=='BASE TABLE': c.sql(f'DROP TABLE `{t}`')
    # Gebruik de gevalideerde export ook bij onderbroken RENAME/VIEW-fasen.
    c.sql((path/'restore.sql').read_text())
    if snapshot(c)!=info['snapshot']: raise RuntimeError('Herstelcontrole mislukt')
    c.sql('DROP VIEW IF EXISTS v_plot_jaar_maatregel_gecombineerd')
    for t in NEW: c.sql(f'DROP TABLE IF EXISTS `{t}`')
    for t in OLD: c.sql(f'DROP TABLE IF EXISTS `{t}_migratie_oud`')
    if not info['source_existed']: c.sql(f'DELETE FROM maatregel_bron WHERE bron_code={literal(BRON)}')
    if not info['brontype_existed']: c.sql("DELETE FROM maatregel_brontype WHERE brontype_code='handmatige_registratie' AND NOT EXISTS (SELECT 1 FROM maatregel_bron WHERE brontype_code='handmatige_registratie')")

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--database',required=True);p.add_argument('--login-path',default='meijendel_root');p.add_argument('--backup-dir',type=Path,required=True)
    g=p.add_mutually_exclusive_group(required=True)
    for mode in ('audit','apply','verify','restore'): g.add_argument('--'+mode,action='store_true')
    args=p.parse_args();c=Client(args.database,args.login_path)
    try:
        if args.audit:
            data=audit(c);print(json.dumps({t:len(v) for t,v in data.items()}))
        elif args.apply:
            with migration_lock(c): apply(c,args.backup_dir)
            print('OK: migratie en reconstructie')
        elif args.verify: verify(c,args.backup_dir);print('OK: volledige reconstructie en ontdubbeling')
        else:
            with migration_lock(c): restore(c,args.backup_dir)
            print('OK: gecontroleerd herstel')
    except (RuntimeError,subprocess.CalledProcessError) as exc: p.exit(1,str(exc)+'\n')
