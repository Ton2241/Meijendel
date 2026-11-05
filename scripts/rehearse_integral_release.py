#!/usr/bin/env python3
"""Run actual native services and database recovery in one isolated local root.

No SSH, no production endpoints, no writes to the canonical databases. Production
uses the same coordinator/manifest; this adapter intentionally binds loopback and
only accepts a private MySQL socket plus a vwg_release_ PostgreSQL database.
"""
import argparse,functools,hashlib,http.server,importlib.util,json,os,re,secrets,signal,subprocess,sys,time,urllib.request,urllib.parse
from pathlib import Path
REPO=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('integral',REPO/'deploy/integral_release.py');release=importlib.util.module_from_spec(spec);spec.loader.exec_module(release)
MYSQL='/usr/local/mysql/bin/mysql';DUMP='/usr/local/mysql/bin/mysqldump'

def run(args,**kw):return subprocess.run([str(x) for x in args],check=True,**kw)
def read_json(path):return json.loads(Path(path).read_text())

class NativeHooks:
 def __init__(self,root,website,fail=False):
  self.root=Path(root).resolve();self.website=Path(website).resolve();self.private=self.root/'private';self.config=read_json(self.private/'native.json');self.pg=Path(self.config['pg_bin']);self.fail=fail
  self.socket=self.private/'mysql/mysql.sock';self.db=self.config['postgres_database']
  if not re.fullmatch('vwg_release_[a-z0-9_]+',self.db):raise ValueError('Alleen een lokale proefdatabase')
  self.env=os.environ|{'PGHOST':'127.0.0.1','PATH':str(self.pg)+':'+os.environ['PATH']}
 def sql(self,text):
  return run([MYSQL,'--no-defaults','--protocol=SOCKET','--socket='+str(self.socket),'-uroot','--batch','--skip-column-names'],input=text,text=True,capture_output=True).stdout
 def pgsql(self,text,database=None):
  return run([self.pg/'psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',database or self.db,'-c',text],env=self.env,text=True,capture_output=True).stdout.strip()
 def guard_mysql(self):
  actual=Path(self.sql('SELECT @@datadir;').strip()).resolve()
  if actual!=self.private/'mysql/data':raise ValueError('MySQL is niet de geïsoleerde proefinstance')
 def mysql_fingerprint(self):
  names=self.sql("SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema='Meijendel' ORDER BY TABLE_NAME;").splitlines()
  if not all(re.fullmatch('[A-Za-z0-9_]+',n) for n in names):raise ValueError('Onverwachte tabelnaam')
  return self.sql('CHECKSUM TABLE '+','.join('`Meijendel`.`'+n+'`' for n in names)+' EXTENDED;').splitlines()
 def pg_fingerprint(self):
  tables=self.pgsql("SELECT schemaname||'.'||tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema') ORDER BY 1;").splitlines();out={}
  for t in tables:
   if not re.fullmatch('[A-Za-z0-9_]+\\.[A-Za-z0-9_]+',t):raise ValueError('Onverwachte PG-tabel')
   out[t]=self.pgsql("SELECT count(*)||':'||md5(coalesce(string_agg(row_to_json(t)::text,E'\\n' ORDER BY row_to_json(t)::text),'')) FROM "+'.'.join(chr(34)+part+chr(34) for part in t.split('.'))+' t;')
  return out
 def snapshot(self,path):
  self.guard_mysql();path.mkdir(parents=True)
  with (path/'mysql.sql').open('wb') as out,(path/'snapshot.log').open('wb') as err:
   run([DUMP,'--no-defaults','--protocol=SOCKET','--socket='+str(self.socket),'-uroot','--single-transaction','--quick','--routines','--events','--triggers','--hex-blob','--set-gtid-purged=OFF','--no-tablespaces','Meijendel'],stdout=out,stderr=err)
  run([self.pg/'pg_dump','--format=custom','--no-owner','--file='+str(path/'cms.dump'),self.db],env=self.env,stdout=subprocess.DEVNULL)
  release.atomic_json(path/'backup.json',dict(mysql_sha256=release.sha(path/'mysql.sql'),cms_sha256=release.sha(path/'cms.dump'),mysql_fingerprint=self.mysql_fingerprint(),cms_fingerprint=self.pg_fingerprint()))
 def restore_mysql(self,path):
  self.guard_mysql();self.sql('DROP DATABASE IF EXISTS `Meijendel`; CREATE DATABASE `Meijendel` CHARACTER SET utf8mb4;')
  # Disposable native instance only: bulk-load profile, never production policy.
  self.sql('ALTER INSTANCE DISABLE INNODB REDO_LOG;')
  try:
   with Path(path).open('rb') as source,(self.private/'mysql/restore.log').open('wb') as log:
    run([MYSQL,'--no-defaults','--protocol=SOCKET','--socket='+str(self.socket),'-uroot','--binary-mode=1','Meijendel'],stdin=source,stdout=log,stderr=log)
  finally:self.sql('ALTER INSTANCE ENABLE INNODB REDO_LOG; SET GLOBAL innodb_flush_log_at_trx_commit=1;')
 def restore(self,path):
  m=read_json(path/'backup.json')
  if release.sha(path/'mysql.sql')!=m['mysql_sha256'] or release.sha(path/'cms.dump')!=m['cms_sha256']:raise ValueError('Herstelbronchecksum wijkt af')
  self.restore_mysql(path/'mysql.sql')
  self.pgsql("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='"+self.db+"' AND pid<>pg_backend_pid();",'postgres')
  run([self.pg/'dropdb',self.db],env=self.env,stdout=subprocess.DEVNULL);run([self.pg/'createdb','--template=template0',self.db],env=self.env,stdout=subprocess.DEVNULL)
  run([self.pg/'pg_restore','--no-owner','--exit-on-error','--dbname='+self.db,path/'cms.dump'],env=self.env,stdout=subprocess.DEVNULL)
  if self.mysql_fingerprint()!=m['mysql_fingerprint'] or self.pg_fingerprint()!=m['cms_fingerprint']:raise ValueError('Databases na herstel niet gelijk aan backup')
 def install_website_objects(self,path):
  module_path=self.website/'scripts/prepare_bootstrap_website_candidate.py'
  spec=importlib.util.spec_from_file_location('fixture',module_path);helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
  blocks={k:v.encode('latin1').decode('utf-8') for k,v in helper.snapshot_blocks(Path(path).read_bytes().decode('latin1')).items()}
  if set(blocks)!=helper.OBJECTS:raise ValueError('Websiteobjecten onvolledig')
  # Apply the existing controlled eight-object snapshot only inside the private instance.
  for name in ('website_species_mapping','website_plot_mapping'):
   b=blocks[name];ddl=re.search(r'CREATE TABLE[\s\S]*?;\s*\n',b).group(0);inserts=re.findall(r'^INSERT INTO [^\n]+',b,re.M)
   self.sql('USE Meijendel; DROP TABLE IF EXISTS `'+name+'`;'+ddl+'\n'+'\n'.join(inserts))
  for name in ('website_species_mapping_public','website_plot_mapping_public','website_species_territoria','website_species_trends','website_plot_year_totals','website_plot_species_totals'):
   b=blocks[name];start=b.index('/*!50001 CREATE');stmt=b[start:b.index(';',start)+1];stmt=re.sub(r'DEFINER=`[^`]+`@`[^`]+`','',stmt).replace('`meijendel`.','`Meijendel`.')
   self.sql('USE Meijendel; DROP VIEW IF EXISTS `'+name+'`;'+stmt)
 def apply(self,package):
  m=read_json(package/'release.json');self.restore_mysql(package/m['mysql']['source']);self.install_website_objects(package/m['mysql']['website_objects'])
  self.sql("CREATE TABLE Meijendel._release_probe(id int primary key,value varchar(100));INSERT INTO Meijendel._release_probe VALUES(1,'"+m['release_id']+"');")
  migrations=m['cms']['migrations']
  if migrations:
   env=self.env|dict(VWG_POSTGRES_DB=self.db,VWG_POSTGRES_MIGRATION_MODE='direct-local')
   with (self.private/'cms-migration.log').open('wb') as log:run(['bash',package/'website/scripts/apply_production_migrations.sh',*migrations],env=env,stdout=log,stderr=log)
 def stop(self):
  path=self.private/'processes.json'
  if not path.exists():return
  for pid in read_json(path).values():
   try:
    command=run(['ps','-p',str(pid),'-o','command='],text=True,capture_output=True).stdout
    if str(self.root) not in command:raise ValueError('Proces hoort niet bij deze proef')
    os.killpg(pid,signal.SIGTERM)
   except (ProcessLookupError,subprocess.CalledProcessError):pass
  for _ in range(30):
   if not any(self._alive(pid) for pid in read_json(path).values()):break
   time.sleep(.1)
  alive=[pid for pid in read_json(path).values() if self._alive(pid)]
  for pid in alive:
   command=run(['ps','-p',str(pid),'-o','command='],text=True,capture_output=True).stdout
   if str(self.root) not in command:raise ValueError('Procesidentiteit gewijzigd tijdens stoppen')
   os.killpg(pid,signal.SIGKILL)
  for _ in range(30):
   if not any(self._alive(pid) for pid in read_json(path).values()):break
   time.sleep(.1)
  if any(self._alive(pid) for pid in read_json(path).values()):raise RuntimeError('Dienst nog actief; database blijft ongemoeid, PIDs bewaard')
  path.unlink()
 def _alive(self,pid):
  result=subprocess.run(['ps','-p',str(pid),'-o','stat='],text=True,capture_output=True)
  return result.returncode==0 and bool(result.stdout.strip()) and not result.stdout.strip().startswith('Z')
 def start(self,package):
  m=read_json(package/'release.json');runtime=self.root/'runtime';runtime.mkdir(exist_ok=True)
  env=self.env|dict(MEIJENDEL_BOOTSTRAP_RELEASE='1',MEIJENDEL_RELEASE_MANIFEST=str(package/'release.json'),MEIJENDEL_BIND_HOST='127.0.0.1',MEIJENDEL_SQL_PATH=str(package/m['mysql']['source']),MEIJENDEL_SQL_MANIFEST_PATH=str(package/(m['mysql']['source']+'.manifest')),MEIJENDEL_CACHE_MANIFEST_PATH=str(package/Path(m['cache']['root']).with_suffix('.manifest')),MEIJENDEL_REQUIRE_PREBUILT_CACHE='1',MEIJENDEL_ALLOW_HISTORICAL_REHEARSAL='1' if m['historical_cache_rehearsal'] else '0',MEIJENDEL_CACHE_DIR=str(runtime/'shiny-cache'),VWG_EMAIL_DELIVERY_DISABLED='1',PYTHONDONTWRITEBYTECODE='1',DATABASE_URL='postgresql://127.0.0.1/'+self.db,MEIJENDEL_MYSQL_HOST='127.0.0.1',MEIJENDEL_MYSQL_PORT='3306',MEIJENDEL_MYSQL_DATABASE='Meijendel',MEIJENDEL_MYSQL_SOCKET=str(self.socket),MEIJENDEL_MYSQL_USER='release_reader',MEIJENDEL_MYSQL_PASSWORD=self.config['mysql_password'])
  website_code=runtime/'start_website.py';website_code.write_text("import sys,os\nfrom pathlib import Path\np=Path(os.environ['MEIJENDEL_RELEASE_MANIFEST']).parent\nsys.path.insert(0,str(p/'website'))\nos.chdir(p/'website')\nfrom app import main\nmain.GROUP_DENSITY_CSV=p/'www/groepen_grafieken/groep_dichtheid.csv'\nmain.GROUP_SPECIES_CSV=p/'www/groepen_grafieken/groep_soorten.csv'\nimport uvicorn\nuvicorn.run(main.app,host='127.0.0.1',port=18197)\n")
  python=Path('/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app/.venv/bin/python')
  cmds={'website':[str(python),str(website_code)],'dashboard':[sys.executable,str(Path(__file__).resolve()),'serve-dashboard','--root',str(self.root)],'shiny':['Rscript','-e',".libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()));shiny::runApp('"+str(package/'shiny/shiny_meijendel')+"',host='127.0.0.1',port=18198,launch.browser=FALSE)"]}
  pids={}
  for role,args in cmds.items():
   with (runtime/(role+'.log')).open('ab') as log:p=subprocess.Popen(args,env=env,stdout=log,stderr=log,start_new_session=True)
   pids[role]=p.pid
   release.atomic_json(self.private/'processes.json',pids)
  for role,port in [('dashboard',18196),('website',18197),('shiny',18198)]:
   for _ in range(120):
    try:
     with urllib.request.urlopen(f'http://127.0.0.1:{port}/',timeout=2):break
    except Exception:time.sleep(.5)
   else:raise RuntimeError(role+' startte niet; zie lokale runtime-log')
 def health(self,package):
  m=read_json(package/'release.json');rid=m['release_id']
  def get(url):
   with urllib.request.urlopen(url,timeout=30) as r:return r.read(),r.url
  config,url=get('http://127.0.0.1:18196/release-config.json');assert '/releases/'+rid+'/www/' in url;assert json.loads(config)['release_id']==rid
  body,_=get('http://127.0.0.1:18196/outputs/bootstrap-presentatie-2026/bootstrap.html');assert hashlib.sha256(body).hexdigest()==m['bootstrap']['html_sha256']
  body,_=get('http://127.0.0.1:18197/soorten/bootstrap.asp');assert hashlib.sha256(body).hexdigest()==m['bootstrap']['html_sha256']
  for path in ('/soorten/vogel.asp?id=3','/soorten/vogel.asp?id=23','/soorten/vogel.asp?id=117','/soorten/vogel.asp?id=199','/meijendel/verhalen/paradox-open-duin.asp'):
   body,_=get('http://127.0.0.1:18197'+path)
   if '/soorten/' in path:assert b'/soorten/bootstrap.asp?view=simple' in body
  body,_=get('http://127.0.0.1:18198/');assert b'shiny' in body.lower() and rid.encode() in body
  assert self.sql('SELECT value FROM Meijendel._release_probe;').strip()==rid
  assert self.pgsql('SELECT value FROM app._release_probe;')==rid
  # Exercise the packaged Shiny data loader, not just its HTTP shell.
  env=self.env|dict(MEIJENDEL_BOOTSTRAP_RELEASE='1',MEIJENDEL_RELEASE_MANIFEST=str(package/'release.json'),MEIJENDEL_BIND_HOST='127.0.0.1',MEIJENDEL_ALLOW_HISTORICAL_REHEARSAL='1' if m['historical_cache_rehearsal'] else '0')
  code=".libPaths(c(path.expand('~/Library/R/arm64/4.5/library'),.libPaths()));source('"+str(package/'shiny/shiny_meijendel/helpers.R')+"');source('"+str(package/'shiny/R/trim_bootstrap_preview.R')+"');x<-load_meijendel_tables_cached('"+str(package/m['mysql']['source'])+"');stopifnot(max(x$data$territoria$jaar)=="+str(m['year_to'])+",!is.null(load_trim_bootstrap_preview()));cat('PACKAGED_SHINY_DATA_OK\\n')"
  with (self.root/'runtime/shiny-data-check.log').open('wb') as log:run(['Rscript','-e',code],env=env,stdout=log,stderr=log)
  if self.fail:
   self.fail=False
   raise RuntimeError('opzettelijke fout na controle van alle drie diensten')
  release.atomic_json(self.root/'health.json',dict(release_id=rid,three_http_services=True,shared_bootstrap_sha256=m['bootstrap']['html_sha256'],mysql_probe=rid,cms_probe=rid,year_to=m['year_to']))

def serve_dashboard(root):
 root=Path(root).resolve()
 class Handler(http.server.SimpleHTTPRequestHandler):
  def do_GET(self):
   path=urllib.parse.urlsplit(self.path).path
   match=re.fullmatch(r'/releases/([A-Za-z0-9._-]+)/www/(.*)',path)
   if not match:
    active=release.current(root)
    if not active:self.send_error(503);return
    self.send_response(307);self.send_header('Location','/releases/'+active.name+'/www/'+self.path.lstrip('/'));self.end_headers();return
   self.directory=str(root/'releases'/match[1]/'www');self.path='/'+match[2]
   super().do_GET()
  def log_message(self,*a):pass
 http.server.ThreadingHTTPServer(('127.0.0.1',18196),Handler).serve_forever()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['serve-dashboard','activate','rollback','check','stop','exercise','exercise-recovery']);p.add_argument('--root',type=Path,required=True);p.add_argument('--website-root',type=Path);p.add_argument('--candidate',type=Path);p.add_argument('--fail-health',action='store_true');a=p.parse_args()
 if a.action=='serve-dashboard':return serve_dashboard(a.root)
 hooks=NativeHooks(a.root,a.website_root,a.fail_health)
 if a.action=='activate':release.activate(a.root,a.candidate,hooks)
 elif a.action in ('exercise','exercise-recovery'):
  if a.action=='exercise':
   old=release.current(a.root)
   if old is None or old==a.candidate.resolve():raise ValueError('Start met een andere bestaande basisrelease')
   release.activate(a.root,a.candidate,hooks);activation=read_json(a.root/'journal.json')
   release.atomic_json(a.root/'activation-proof.json',activation)
  else:
   activation=read_json(a.root/'activation-proof.json');old=Path(read_json(a.root/'last_backup.json')['package'])
   if release.current(a.root)!=a.candidate.resolve() or activation['attempted']!=a.candidate.name or activation['phase']!='active':raise ValueError('Geen geslaagde activering om te vervolgen')
  proof=dict(baseline=old.name,candidate=a.candidate.name,scope='native macOS, loopback, isolated databases',year_to=read_json(a.candidate/'release.json')['year_to'],activation=activation)
  # Both presentation versions deliberately share the same frozen SQL source.
  # Full import was already tested by activation. Inject actual partial writes,
  # then fail after the three service checks, without changing migration hashes.
  if read_json(old/'release.json')['source_hash']!=read_json(a.candidate/'release.json')['source_hash']:raise ValueError('Foutproef vraagt dezelfde bevroren wetenschappelijke bron')
  def partial_write(package):
   rid=read_json(package/'release.json')['release_id']
   hooks.sql("UPDATE Meijendel._release_probe SET value='"+rid+"';")
   hooks.pgsql("UPDATE app._release_probe SET value='"+rid+"';")
  hooks.apply=partial_write;hooks.fail=True
  proof['fault_injection']='actual partial writes in both databases, identical frozen source; fail after all three services pass'
  try:release.activate(a.root,old,hooks)
  except RuntimeError as e:
   if 'opzettelijke fout' not in str(e):raise
  else:raise AssertionError('Geplande fout niet opgetreden')
  proof['automatic_recovery']=read_json(a.root/'journal.json')
  assert release.current(a.root)==a.candidate.resolve()
  proof['recovered_candidate_health']=read_json(a.root/'health.json')
  release.rollback(a.root,hooks);assert release.current(a.root)==old
  proof['explicit_rollback']=read_json(a.root/'journal.json');proof['final_health']=read_json(a.root/'health.json')
  proof['database_fingerprints_verified_on_each_restore']=True
  release.atomic_json(a.root/'rehearsal-proof.json',proof)
 elif a.action=='rollback':release.rollback(a.root,hooks)
 elif a.action=='stop':hooks.stop()
 else:hooks.health(release.current(a.root))
 print('LOCAL_INTEGRAL_'+a.action.upper()+'_OK')
if __name__=='__main__':main()
