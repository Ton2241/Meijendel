#!/usr/bin/python3
"""Fixed Linux hooks for the hash-bound VWG gateway; no arbitrary commands/paths."""
from __future__ import annotations
import argparse,contextlib,hashlib,http.server,importlib.util,json,os,re,shutil,stat,subprocess,sys,time,urllib.parse,urllib.request
from pathlib import Path
BASE=Path('/srv/vwgm');STATE=BASE/'deploy-state';CONTROL=Path('/var/lib/vwgm-integral');INSTALL=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('integral_release',INSTALL/'integral_release.py');core=importlib.util.module_from_spec(spec);spec.loader.exec_module(core)
OBJECTS=('vogelstand_1924','website_species_mapping','website_plot_mapping','website_species_mapping_public','website_plot_mapping_public','website_species_territoria','website_species_trends','website_plot_year_totals','website_plot_species_totals')

def root_directory(path,mode=0o751):
 path=Path(path)
 if path==CONTROL:path.mkdir(mode=mode,exist_ok=True)
 else:
  if not path.is_relative_to(CONTROL):raise ValueError('Geen beheerd rootpad')
  root_directory(path.parent);path.mkdir(mode=mode,exist_ok=True)
 value=path.lstat()
 if not stat.S_ISDIR(value.st_mode) or value.st_uid!=0 or value.st_gid!=0 or value.st_mode&0o022:raise ValueError('Onveilig beheerd pad: '+str(path))
 return path

def guard_payload(m):
 if m.get('legacy') or set(m.get('components',[]))!={'website','dashboard','shiny','mysql','cms'}:raise ValueError('Geen volledig gebruikerspakket')
 if m.get('mysql')!={'source':'data/Meijendel.sql','website_objects':'data/website_objects.sql','database':'Meijendel'}:raise ValueError('Onbekende SQL-binding')
 if not re.fullmatch(r'data/cache/[A-Za-z0-9_.-]+\.rds',m.get('cache',{}).get('root','')):raise ValueError('Onbekende cachebinding')
 if m.get('bootstrap',{}).get('root')!='www/outputs/bootstrap-presentatie-2026':raise ValueError('Onbekende bootstrapbinding')
 required=['data/Meijendel.sql','data/Meijendel.sql.manifest',m['cache']['root'],str(Path(m['cache']['root']).with_suffix('.manifest')),'website/app/main.py','shiny/shiny_meijendel/app.R','www/bmp_meijendel_index.html']
 if any(p not in m['files'] for p in required):raise ValueError('Niet gecontroleerde component')
 for relative in m.get('cms',{}).get('migrations',[]):
  if not re.fullmatch(r'sql/[0-9]{3}_[a-z0-9_]+\.sql',relative) or 'website/'+relative not in m['files']:raise ValueError('Niet gecontroleerde migratie')

def approved_migration(relative,digest,catalogue):
 if not re.fullmatch(r'sql/[0-9]{3}_[a-z0-9_]+\.sql',relative) or catalogue.get(relative)!=digest:raise ValueError('CMS-migratie niet door root goedgekeurd')

def owned_objects(names):
 if not set(OBJECTS[1:]).issubset(set(names)):raise ValueError('Productie-eigen websiteobjecten ontbreken')
 return [n for n in OBJECTS if n in names]

def sql_objects(path):
 result=set()
 with Path(path).open('rb') as source:
  for line in source:
   if line.startswith(b'INSERT '):continue
   result.update(n.decode('ascii') for n in re.findall(rb'(?:CREATE TABLE(?: IF NOT EXISTS)?|VIEW)\s+`([A-Za-z0-9_]+)`',line))
 if not result:raise ValueError('SQL-objectinventaris ontbreekt')
 return result

def layout(commit,trial=True):
 if not re.fullmatch('[0-9a-f]{40}',commit):raise ValueError('Exacte commit vereist')
 short=commit[:12]
 return dict(commit=commit,trial=trial,root=str(CONTROL/('trial/'+commit if trial else 'production')),
  database='vwg_integral_'+short if trial else 'vwg',mysql='vwgm_integral_mysql_'+short if trial else 'meijendel-mysql',
  shiny='vwgm_integral_shiny_'+short if trial else 'shiny_meijendel',network='vwgm_integral_'+short,
  units={role:'vwgm-integral-'+role+('-trial-'+short if trial else '') for role in ('website','dashboard','caddy')},
  ports=dict(mysql=33317 if trial else 3307,website=18197 if trial else 8091,dashboard=18196,shiny=18198 if trial else 3838,caddy=18199 if trial else 443))

def guard_trial_layout(m):
 expected=layout(m['commit'],True)
 if not m.get('trial') or any(m[k]!=expected[k] for k in ('root','database','mysql','shiny','network','units','ports')):raise ValueError('Proef moet volledig geïsoleerd blijven')

def caddy_config(source,trial=True):
 # Use the existing auth routes, never replace them with an unauthenticated file server.
 start=source.index('(vwg_app_routes) {');depth=0;end=None
 for i in range(source.index('{',start),len(source)):
  if source[i]=='{':depth+=1
  elif source[i]=='}':
   depth-=1
   if depth==0:end=i+1;break
 if end is None:raise ValueError('Onvolledige Caddy-routeconfiguratie')
 snippet=source[start:end]
 original='root * /srv/vwgm/www\n\t\tfile_server'
 if original not in snippet and '@integral_assets' not in snippet:raise ValueError('Onbekende dashboardbinding; geen automatische configuratiewijziging')
 snippet=snippet.replace(original,'reverse_proxy 127.0.0.1:18196')
 extra='''\n\t@integral_assets path /releases/* /release-config.json /bmp_meijendel_data_loader.js /groepen_grafieken/*
\thandle @integral_assets {
\t\tforward_auth 127.0.0.1:8091 { uri /auth/analysis-output }
\t\treverse_proxy 127.0.0.1:18196
\t}
'''
 if '@integral_assets' not in snippet:snippet=snippet.replace('(vwg_app_routes) {','(vwg_app_routes) {'+extra,1)
 # SQL remains behind its original member-auth handler; the selected payload changes.
 snippet=snippet.replace('root * /srv/vwgm/data\n\t\theader Content-Type "text/plain; charset=utf-8"\n\t\tfile_server','reverse_proxy 127.0.0.1:18196')
 if trial:
  snippet=snippet.replace('127.0.0.1:8091','127.0.0.1:18197').replace('127.0.0.1:3838','127.0.0.1:18198')
  return '{\n admin off\n persist_config off\n}\n'+snippet+'\nhttp://127.0.0.1:18199 {\n import vwg_app_routes\n}\n'
 return source[:start]+snippet+source[end:]

def run(args,**kw):return subprocess.run([str(x) for x in args],check=True,**kw)
def jsonfile(path):return json.loads(Path(path).read_text())
def secret_json(path,value):
 core.atomic_json(path,value);os.chmod(path,0o600)
def secure_file(path):
 s=Path(path).lstat()
 if not stat.S_ISREG(s.st_mode) or s.st_uid!=0 or s.st_gid!=0 or s.st_mode&0o022:raise ValueError('Geen veilig root-bestand: '+str(path))

def env_file(path):
 # The production env uses plain KEY=value records; do not execute it as shell code.
 result={}
 for line in Path(path).read_text().splitlines():
  if not line.strip() or line.lstrip().startswith('#'):continue
  key,sep,value=line.partition('=')
  if not sep or not re.fullmatch('[A-Z][A-Z0-9_]*',key):raise ValueError('Onbekende env-regel')
  result[key]=value.strip().strip('"').strip("'")
 return result

def write_env(path,values,systemd=True):
 if any('\n' in str(v) or '\r' in str(v) for v in values.values()):raise ValueError('Meerregelige env-waarde')
 Path(path).write_text(''.join(k+'='+(json.dumps(str(v),ensure_ascii=False) if systemd else str(v))+'\n' for k,v in sorted(values.items())));os.chmod(path,0o600)

MYSQL_CLIENT=r'''
set -euo pipefail
client="$1"; shift
password="${MYSQL_ROOT_PASSWORD:?}"
password="${password//\\/\\\\}"; password="${password//\"/\\\"}"
exec 3< <(printf '[client]\nuser=root\npassword="%s"\n' "$password")
child=$!; status=0
"$client" --defaults-extra-file=/dev/fd/3 "$@" || status=$?
exec 3<&-; wait "$child" 2>/dev/null || true
exit "$status"
'''

def docker_mysql(container,client='mysql',args=()):
 if client not in ('mysql','mysqldump'):raise ValueError('Onbekende MySQL-client')
 return ['docker','exec','-i',container,'bash','-lc',MYSQL_CLIENT,'bash',client,*args]

def inspect_container(name):return json.loads(run(['docker','inspect',name],capture_output=True,text=True).stdout)[0]
def production_identity():
 result={}
 for name in ('meijendel-mysql','shiny_meijendel'):
  m=inspect_container(name);result[name]=dict(id=m['Id'],image=m['Image'],restarts=m['RestartCount'],started=m['State']['StartedAt'])
 for path in (Path('/etc/caddy/Caddyfile'),STATE/'Meijendel.commit',STATE/'VWG_M.commit'):
  result[str(path)]={'sha256':core.sha(path),'commit':path.read_text().strip()} if path.suffix=='.commit' else core.sha(path)
 return result

class LinuxHooks:
 def __init__(self,settings):
  self.s=settings;self.root=Path(settings['root']);self.private=self.root/'private';self.runtime=self.root/'runtime'
  if settings['trial']:guard_trial_layout(settings)
  self.db=settings['database'];self.mysql=settings['mysql'];self.p=settings['ports'];self.mysql_db=settings.get('mysql_database','Meijendel')
  if self.mysql_db not in ('Meijendel','meijendel'):raise ValueError('Onbekend ecologisch schema')
  if settings['trial'] and 'website_env' in settings:
   u=urllib.parse.urlsplit(settings['website_env']['DATABASE_URL'])
   if u.path!='/'+self.db or any(k in dict(urllib.parse.parse_qsl(u.query)) for k in ('dbname','database','service','host')):raise ValueError('Website moet de proefdatabase gebruiken')
  if not re.fullmatch('vwg_integral_[0-9a-f]{12}|vwg',self.db):raise ValueError('Ongeldige vaste database')
  self.log=self.private/'operations.log'
 def logged(self,args,**kw):
  with self.log.open('ab') as log:return run(args,stdout=log,stderr=log,**kw)
 def pg(self,args,**kw):return run(['sudo','-n','-u','postgres',*args],**kw)
 def pgsql(self,text,db=None):return self.pg(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',db or self.db,'-c',text],capture_output=True,text=True).stdout.strip()
 def sql(self,text,container=None):
  if self.s['trial'] and container=='meijendel-mysql' and not text.lstrip().upper().startswith('SELECT '):raise ValueError('Productie is tijdens de proef uitsluitend leesbaar')
  text=text.replace('Meijendel',self.mysql_db)
  return run(docker_mysql(container or self.mysql,args=('--batch','--skip-column-names','--default-character-set=utf8mb4')),input=text,capture_output=True,text=True).stdout.strip()
 def mysql_fingerprint(self):
  names=self.sql("SELECT table_name FROM information_schema.tables WHERE table_schema='Meijendel' ORDER BY table_name;").splitlines()
  if not names or any(not re.fullmatch('[A-Za-z0-9_]+',n) for n in names):raise ValueError('Onverwachte tabelinventaris')
  return self.sql('CHECKSUM TABLE '+','.join('`Meijendel`.`'+n+'`' for n in names)+' EXTENDED;').splitlines()
 def pg_fingerprint(self):
  result={};names=self.pgsql("SELECT schemaname||'.'||tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema') ORDER BY 1;").splitlines()
  for name in names:
   if not re.fullmatch(r'[A-Za-z0-9_]+\.[A-Za-z0-9_]+',name):raise ValueError('Onbekende CMS-tabelnaam')
   quoted='.'.join('"'+part+'"' for part in name.split('.'))
   result[name]=self.pgsql("SELECT count(*)||':'||md5(coalesce(string_agg(row_to_json(t)::text,E'\\n' ORDER BY row_to_json(t)::text),'')) FROM "+quoted+' t;')
  return result
 def capture_files(self,source,archive):
  with Path(archive).open('wb') as out,self.log.open('ab') as log:
   run(['sudo','-n','-u','www-data','tar','--hard-dereference','-C',source,'-cf','-','.'],stdout=out,stderr=log)
  import tarfile
  with tarfile.open(archive) as tar:
   for member in tar.getmembers():
    if not (member.isfile() or member.isdir()) or Path(member.name).is_absolute() or '..' in Path(member.name).parts:raise ValueError('Bijzondere link/pad in gedeelde appbestanden')
 def unpack_files(self,archive,target):
  target=Path(target);target.mkdir(mode=0o750);os.chown(target,33,33)
  with Path(archive).open('rb') as data,self.log.open('ab') as log:run(['sudo','-n','-u','www-data','tar','--no-same-owner','--no-same-permissions','-C',target,'-xf','-'],stdin=data,stdout=log,stderr=log)
 def files_fingerprint(self):
  code="import hashlib,os,pathlib,sys;root=pathlib.Path(sys.argv[1]);h=hashlib.sha256();files=sorted(p for p in root.rglob('*') if p.is_file());[(h.update(str(p.relative_to(root)).encode()+b'\\0'),h.update(hashlib.sha256(p.read_bytes()).digest())) for p in files];print(h.hexdigest())"
  return run(['sudo','-n','-u','www-data','python3','-c',code,self.s['website_data']],capture_output=True,text=True).stdout.strip()
 def restore_files(self,archive):
  import uuid
  target=self.runtime/('data-restore-'+uuid.uuid4().hex);self.unpack_files(archive,target)
  # Unprivileged writes through a pinned destination directory; no root copy/chown
  # through user-controlled document paths.
  fd=os.open(self.s['website_data'],os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
  try:
   def drop():os.setgroups([]);os.setgid(33);os.setuid(33)
   with self.log.open('ab') as log:run(['rsync','-a','--delete','--no-owner','--no-group',str(target)+'/',f'/proc/self/fd/{fd}/'],pass_fds=(fd,),preexec_fn=drop,stdout=log,stderr=log)
  finally:os.close(fd);shutil.rmtree(target)
 def snapshot(self,path):
  print('INTEGRAL_STEP='+'snapshot',flush=True)
  path.mkdir(parents=True,mode=0o700)
  with (path/'mysql.sql').open('wb') as out,(path/'dump.log').open('wb') as err:
   run(docker_mysql(self.mysql,'mysqldump',('--single-transaction','--quick','--routines','--events','--triggers','--hex-blob','--set-gtid-purged=OFF','--no-tablespaces',self.mysql_db)),stdout=out,stderr=err)
  with (path/'cms.dump').open('wb') as out:self.pg(['pg_dump','--format=custom',self.db],stdout=out)
  # Live website/historical objects are preserved from this database, not a stale local fixture.
  names=self.sql("SELECT table_name FROM information_schema.tables WHERE table_schema='Meijendel';").splitlines();owned=owned_objects(names)
  with (path/'website_objects.sql').open('wb') as out,(path/'dump.log').open('ab') as err:
   run(docker_mysql(self.mysql,'mysqldump',('--single-transaction','--no-tablespaces','--set-gtid-purged=OFF',self.mysql_db,*owned)),stdout=out,stderr=err)
  self.capture_files(self.s['website_data'],path/'app-data.tar')
  m=dict(files={name:core.sha(path/name) for name in ('mysql.sql','cms.dump','website_objects.sql','app-data.tar')},filesystem=self.files_fingerprint(),mysql=self.mysql_fingerprint(),cms=self.pg_fingerprint(),owned=self.owned_fingerprint(),database=self.database_metadata())
  if not self.s['trial']:self.snapshot_production_files(path,m)
  secret_json(path/'backup.json',m)
 def import_mysql(self,path,reset=False):
  if reset:self.sql('SET SESSION sql_log_bin=0; DROP DATABASE IF EXISTS Meijendel; CREATE DATABASE Meijendel CHARACTER SET utf8mb4;')
  with Path(path).open('rb') as src,self.log.open('ab') as log:
   proc=subprocess.Popen(docker_mysql(self.mysql,args=('--binary-mode=1',self.mysql_db)),stdin=subprocess.PIPE,stdout=log,stderr=log)
   try:
    proc.stdin.write(b'SET SESSION sql_log_bin=0;\n');shutil.copyfileobj(src,proc.stdin,1024*1024);proc.stdin.close()
   except Exception:
    proc.stdin.close();proc.wait();raise
   if proc.wait()!=0:raise RuntimeError('MySQL-import mislukt; zie besloten operations.log')
 def owned_fingerprint(self):
  names=owned_objects(self.sql("SELECT table_name FROM information_schema.tables WHERE table_schema='Meijendel';").splitlines())
  result=run(docker_mysql(self.mysql,'mysqldump',('--single-transaction','--no-tablespaces','--set-gtid-purged=OFF','--skip-comments','--skip-dump-date','--order-by-primary',self.mysql_db,*names)),capture_output=True)
  return hashlib.sha256(result.stdout).hexdigest()
 def database_metadata(self):
  value=self.pgsql("SELECT json_build_object('owner',pg_get_userbyid(datdba),'acl',(SELECT json_agg(json_build_object('role',CASE WHEN grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(grantee) END,'privilege',privilege_type,'grantable',is_grantable)) FROM aclexplode(coalesce(datacl,acldefault('d',datdba))))) FROM pg_database WHERE datname='"+self.db+"';",'postgres')
  return json.loads(value)
 def restore_pg(self,path,metadata):
  self.pgsql("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='"+self.db+"' AND pid<>pg_backend_pid();",'postgres')
  self.pg(['dropdb',self.db],stdout=subprocess.DEVNULL);self.pg(['createdb','--template=template0','--owner='+metadata['owner'],self.db],stdout=subprocess.DEVNULL)
  with Path(path).open('rb') as source,self.log.open('ab') as log:self.pg(['pg_restore','--exit-on-error','--dbname='+self.db],stdin=source,stdout=log,stderr=log)
  self.pgsql('REVOKE ALL ON DATABASE "'+self.db+'" FROM PUBLIC;','postgres')
  for grant in metadata['acl']:
   role=grant['role'];privilege=grant['privilege']
   if not re.fullmatch('[A-Za-z_][A-Za-z0-9_]*',role) or privilege not in ('CONNECT','CREATE','TEMPORARY'):raise ValueError('Onverwacht databaserecht')
   target='PUBLIC' if role=='PUBLIC' else '"'+role+'"'
   self.pgsql('GRANT '+privilege+' ON DATABASE "'+self.db+'" TO '+target+(' WITH GRANT OPTION' if grant['grantable'] else '')+';','postgres')
 def restore(self,path):
  print('INTEGRAL_STEP='+'restore',flush=True)
  m=jsonfile(path/'backup.json')
  if any(core.sha(path/name)!=digest for name,digest in m['files'].items()):raise ValueError('Beschadigde herstelbron')
  self.import_mysql(path/'mysql.sql',reset=True);self.restore_pg(path/'cms.dump',m['database'])
  self.restore_files(path/'app-data.tar')
  if self.files_fingerprint()!=m['filesystem']:raise RuntimeError('Gedeelde appbestanden na herstel afwijkend')
  if self.mysql_fingerprint()!=m['mysql'] or self.pg_fingerprint()!=m['cms']:raise RuntimeError('Database-inhoud na herstel wijkt af')
  if not self.s['trial']:self.restore_production_files(path,m)
 def apply(self,package):
  print('INTEGRAL_STEP='+'apply',flush=True)
  m=jsonfile(package/'release.json')
  # Snapshot is the authoritative source for production-owned objects.
  before=jsonfile(self.root/'journal.json');backup=Path(before['backup'])
  self.import_mysql(package/m['mysql']['source'],reset=True);self.import_mysql(backup/'website_objects.sql')
  if self.owned_fingerprint()!=jsonfile(backup/'backup.json')['owned']:raise RuntimeError('Productie-eigen tabellen/views veranderd')
  if self.s['trial']:
   self.sql("CREATE TABLE IF NOT EXISTS Meijendel._release_probe(id int primary key,value varchar(100)); REPLACE INTO Meijendel._release_probe VALUES(1,'"+m['release_id']+"');")
   (Path(self.s['website_data'])/'_integral_release_probe').write_text(m['release_id']+'\n')
   self.pgsql("CREATE TABLE IF NOT EXISTS app._release_probe(id integer primary key,value text); INSERT INTO app._release_probe VALUES(1,'"+m['release_id']+"') ON CONFLICT(id) DO UPDATE SET value=excluded.value;")
  self.apply_migrations(package,m)
 def apply_migrations(self,package,m):
  if not m['cms']['migrations']:return
  catalogue=INSTALL/'integral_migrations.json';secure_file(catalogue);allowed=jsonfile(catalogue)['files']
  for relative in m['cms']['migrations']:
   source=core.safe_path(package,'website/'+relative);digest=core.sha(source);name=source.name
   approved_migration(relative,digest,allowed)
   recorded=self.pgsql("SELECT sha256 FROM app.schema_migrations WHERE filename='"+name+"';")
   if recorded:
    if recorded!=digest:raise ValueError('Bestaande CMS-migratie gewijzigd')
    continue
   # Only SQL bytes approved during the separate hash-bound root installation.
   # No runtime role/eigendom changes and no package scripts executed as root.
   args=['psql','-X','--single-transaction','-v','ON_ERROR_STOP=1','-d',self.db,'-f','-','-c',"INSERT INTO app.schema_migrations(filename,sha256) VALUES('"+name+"','"+digest+"')"]
   with self.log.open('ab') as log:self.pg(args,input=source.read_bytes(),stdout=log,stderr=log)
 def unit_exists(self,unit):
  return run(['systemctl','show','-p','LoadState','--value',unit+'.service'],capture_output=True,text=True).stdout.strip()!='not-found'
 def stop(self):
  if not self.s['trial']:self.stop_production_writers()
  units=list(self.s['units'].values())
  if not self.s['trial']:units=['caddy','vwg-m-linux-app',self.s['units']['dashboard']]
  for unit in units:
   if self.unit_exists(unit):self.logged(['systemctl','stop',unit])
   if subprocess.run(['systemctl','is-active','--quiet',unit],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0:raise RuntimeError('Dienst nog actief: '+unit)
  q=subprocess.run(['docker','inspect',self.s['shiny']],capture_output=True,text=True)
  if q.returncode==0 and json.loads(q.stdout)[0]['State']['Running']:self.logged(['docker','stop',self.s['shiny']])
 def start_unit(self,role,command,env_path=None):
  unit=self.s['units'][role]
  self.logged(['systemctl','reset-failed',unit]) if self.unit_exists(unit) else None
  args=['systemd-run','--quiet','--collect','--unit='+unit,'--uid=www-data','--gid=www-data','--property=MemoryMax=512M']
  if env_path:args+=['--property=EnvironmentFile='+str(env_path)]
  args+=['--',*command];self.logged(args)
 def start(self,package):
  print('INTEGRAL_STEP='+'start',flush=True)
  if jsonfile(package/'release.json').get('legacy'):return self.start_legacy(package)
  m=jsonfile(package/'release.json');s=self.s
  link=package/'website/app/data';target=Path(s['website_data'])
  if link.is_symlink():
   if link.resolve()!=target.resolve():raise ValueError('Onjuiste gedeelde app/data-binding')
  elif link.exists():raise ValueError('Runtime app/data mag niet in het codepakket staan')
  else:link.symlink_to(target,target_is_directory=True)
  if not s['trial']:self.configure_production(package)
  values=dict(self.s['website_env']);values.update(MEIJENDEL_BOOTSTRAP_RELEASE='1',MEIJENDEL_RELEASE_MANIFEST=str(package/'release.json'),MEIJENDEL_BIND_HOST='127.0.0.1',VWG_INTEGRAL_WEBSITE_PORT=str(self.p['website']),VWG_EMAIL_DELIVERY_DISABLED='1' if s['trial'] else values.get('VWG_EMAIL_DELIVERY_DISABLED','0'),PYTHONDONTWRITEBYTECODE='1',VWG_MEDIA_ROOT=str(self.s['media_root']))
  file=self.private/'website.env';write_env(file,values)
  if s['trial']:self.start_unit('website',[str(BASE/'vwg-m-linux-app/.venv/bin/python'),str(Path(__file__).resolve()),'_website',str(package)],file)
  else:self.logged(['systemctl','daemon-reload']);self.logged(['systemctl','start','vwg-m-linux-app'])
  if s['trial']:self.start_unit('dashboard',['/usr/bin/python3',str(Path(__file__).resolve()),'_dashboard',str(self.root),str(self.p['dashboard'])])
  else:self.logged(['systemctl','start',s['units']['dashboard']])
  self.start_shiny(package,m)
  config=self.runtime/'Caddyfile';config.write_text(caddy_config(self.s['caddy_source'],trial=s['trial']));os.chmod(config,0o644)
  if s['trial']:self.start_unit('caddy',['/usr/bin/caddy','run','--adapter','caddyfile','--config',str(config)])
  else:self.logged(['systemctl','start','caddy'])
 def start_shiny(self,package,m):
  name=self.s['shiny'];old=subprocess.run(['docker','inspect',name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  if old.returncode==0:self.logged(['docker','rm',name])
  cache=self.runtime/'shiny-cache';cache.mkdir(exist_ok=True);os.chown(cache,self.s['shiny_uid'],self.s['shiny_gid'])
  args=['docker','run','-d','--name',name,'--label','vwgm.integral.commit='+self.s['commit'],'--restart='+('no' if self.s['trial'] else 'unless-stopped'),'-p','127.0.0.1:'+str(self.p['shiny'])+':3838']
  if self.s['trial']:args+=['--memory=1g','--cpus=0.75']
  else:
   old=self.s['original_shiny'];host=old['HostConfig']
   if host.get('Privileged'):raise ValueError('Geen geprivilegieerd Shiny-profiel')
   if host.get('Memory'):args+=['--memory='+str(host['Memory'])]
   if host.get('NanoCpus'):args+=['--cpus='+str(host['NanoCpus']/1e9)]
   for cap in host.get('CapDrop') or []:args+=['--cap-drop='+cap]
   for opt in host.get('SecurityOpt') or []:args+=['--security-opt='+opt]
   if host.get('ReadonlyRootfs'):args+=['--read-only']
   for dest,options in (host.get('Tmpfs') or {}).items():args+=['--tmpfs',dest+':'+options]
   if old['Config'].get('User'):args+=['--user',old['Config']['User']]
  if self.s['trial']:args+=['--network',self.s['network']]
  elif self.s['original_shiny']['HostConfig'].get('NetworkMode'):args+=['--network',self.s['original_shiny']['HostConfig']['NetworkMode']]
  for source,target in [(package,'/release'),(package/'shiny/shiny_meijendel','/srv/shiny-server/shiny_meijendel'),(package/'shiny/R','/srv/shiny-server/R')]:args+=['--mount',f'type=bind,src={source},dst={target},readonly']
  args+=['--mount',f'type=bind,src={cache},dst=/srv/shiny-server/shiny_meijendel/app_cache']
  for folder in ('trim','trim_msi_evg','groepen_grafieken','wintertellingen','output_ecologische_groepen'):
   args+=['--mount',f'type=bind,src={package / "www" / folder},dst=/srv/shiny-server/{folder},readonly']
  for key,value in dict(MEIJENDEL_BOOTSTRAP_RELEASE='1',MEIJENDEL_RELEASE_MANIFEST='/release/release.json',MEIJENDEL_BIND_HOST='127.0.0.1',MEIJENDEL_SQL_PATH='/release/data/Meijendel.sql',MEIJENDEL_SQL_MANIFEST_PATH='/release/data/Meijendel.sql.manifest',MEIJENDEL_CACHE_MANIFEST_PATH='/release/'+str(Path(m['cache']['root']).with_suffix('.manifest')),MEIJENDEL_REQUIRE_PREBUILT_CACHE='1',MEIJENDEL_ALLOW_HISTORICAL_REHEARSAL='1' if m.get('historical_cache_rehearsal') and self.s['trial'] else '0').items():args+=['-e',key+'='+value]
  # Normal cache resolver expects the prebuilt RDS in app_cache.
  shutil.copy2(package/m['cache']['root'],cache/Path(m['cache']['root']).name);os.chmod(cache/Path(m['cache']['root']).name,0o644)
  self.logged(args+[self.s['shiny_image']])
 def get(self,url):
  with urllib.request.urlopen(url,timeout=10) as r:return r.read(),r.status,r.url
 def health(self,package):
  print('INTEGRAL_STEP='+'health',flush=True)
  m=jsonfile(package/'release.json')
  if m.get('legacy'):return self.health_legacy()
  urls=[f'http://127.0.0.1:{self.p[role]}/' for role in ('website','dashboard','shiny')]
  for url in urls:
   for _ in range(120):
    try:self.get(url);break
    except Exception:time.sleep(.5)
   else:raise RuntimeError('Dienst niet gereed: '+url)
  body,_,url=self.get(f'http://127.0.0.1:{self.p["dashboard"]}/release-config.json')
  if json.loads(body)['release_id']!=m['release_id'] or '/releases/'+m['release_id']+'/www/' not in url:raise RuntimeError('Verkeerde dashboardversie')
  for port,path in [(self.p['dashboard'],'/outputs/bootstrap-presentatie-2026/bootstrap.html'),(self.p['website'],'/soorten/bootstrap.asp')]:
   body,_,_=self.get('http://127.0.0.1:'+str(port)+path)
   if hashlib.sha256(body).hexdigest()!=m['bootstrap']['html_sha256']:raise RuntimeError('Bootstrapbytes wijken af')
  for sid in (3,23,117,199):
   body,_,_=self.get(f'http://127.0.0.1:{self.p["website"]}/soorten/vogel.asp?id={sid}')
   if b'/soorten/bootstrap.asp?view=simple' not in body:raise RuntimeError('Geen actieve bootstrap op soortpagina')
  self.logged(['docker','exec','--user','shiny',self.s['shiny'],'Rscript','-e',"setwd('/srv/shiny-server/shiny_meijendel');source('helpers.R');source('../R/trim_bootstrap_preview.R');x<-load_meijendel_tables_cached(resolve_meijendel_sql_path());stopifnot(isTRUE(x$from_cache),max(x$data$territoria$jaar)=="+str(m['year_to'])+",!is.null(load_trim_bootstrap_preview()));cat('LINUX_SHINY_DATA_BOOTSTRAP_OK\\n')"])
  if self.s['trial']:
   if (Path(self.s['website_data'])/'_integral_release_probe').read_text().strip()!=m['release_id']:raise RuntimeError('Verkeerde bestandversie')
   if self.sql('SELECT value FROM Meijendel._release_probe;')!=m['release_id'] or self.pgsql('SELECT value FROM app._release_probe;')!=m['release_id']:raise RuntimeError('Verkeerde databaseversie')
   for path in ('/bmp_meijendel_index.html','/shiny_meijendel/','/Meijendel.sql','/releases/'+m['release_id']+'/www/release-config.json'):
    try:self.get(f'http://127.0.0.1:{self.p["caddy"]}'+path)
    except urllib.error.HTTPError as e:
     if e.code not in (401,403):raise
    else:raise RuntimeError('Caddy beschermt de proefroute niet: '+path)
  if getattr(self,'fail_health',False):self.fail_health=False;raise RuntimeError('Opzettelijke Linux-healthfout')
  core.atomic_json(self.root/'health.json',dict(release_id=m['release_id'],year_to=m['year_to'],three_services=True,shared_bootstrap_sha256=m['bootstrap']['html_sha256'],shiny_cache_and_bootstrap=True,caddy_auth=self.s['trial']))
 def snapshot_production_files(self,path,m):
  m['host_files']={};m['active_timers']=getattr(self,'timers',[])
  m['dashboard_enabled']=subprocess.run(['systemctl','is-enabled','--quiet',self.s['units']['dashboard']],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0
  paths=[Path('/etc/caddy/Caddyfile'),Path('/etc/systemd/system')/(self.s['units']['dashboard']+'.service'),Path('/etc/systemd/system/vwg-m-baremetal-backup.service.d/50-integral.conf'),Path('/etc/systemd/system/vwg-m-linux-app.service.d/50-integral.conf'),STATE/'Meijendel.commit',STATE/'VWG_M.commit']
  for i,source in enumerate(paths):
   target='host-'+str(i)
   if source.is_symlink():raise ValueError('Onverwachte symlink in productieconfiguratie')
   m['host_files'][str(source)]={'backup':target if source.exists() else None,'mode':stat.S_IMODE(source.stat().st_mode) if source.exists() else None}
   if source.exists():shutil.copy2(source,path/target);m['files'][target]=core.sha(path/target)
 def restore_production_files(self,path,m):
  if not m.get('dashboard_enabled') and self.unit_exists(self.s['units']['dashboard']):self.logged(['systemctl','disable',self.s['units']['dashboard']])
  for name,item in m['host_files'].items():
   target=Path(name)
   if item['backup']:
    temp=target.with_name(target.name+'.integral-next');shutil.copy2(path/item['backup'],temp);os.chmod(temp,item['mode']);temp.replace(target)
   elif target.exists():target.unlink()
  self.timers=m.get('active_timers',[]);self.logged(['systemctl','daemon-reload'])
  if m.get('dashboard_enabled'):self.logged(['systemctl','enable',self.s['units']['dashboard']])
 def stop_production_writers(self):
  # Never interrupt an already-running backup/OCR/reminder worker.
  states=run(['systemctl','list-units','--type=service','--state=running','--no-legend','--plain','vwg-m-*'],capture_output=True,text=True).stdout
  active=[line.split()[0] for line in states.splitlines() if line.strip() and line.split()[0]!='vwg-m-linux-app.service']
  if active:raise RuntimeError('Wacht op actieve VWG-schrijver/back-up: '+','.join(active))
  timers=run(['systemctl','list-units','--type=timer','--state=active','--no-legend','--plain','vwg-m-*'],capture_output=True,text=True).stdout
  observed=[line.split()[0] for line in timers.splitlines() if line.strip()]
  self.timers=sorted(set(getattr(self,'timers',[]))|set(observed))
  if any(not re.fullmatch('vwg-m-[a-z0-9-]+.timer',n) for n in self.timers):raise ValueError('Onverwachte timer')
  if self.timers:self.logged(['systemctl','stop',*self.timers])
 def configure_production(self,package):
  unit=Path('/etc/systemd/system')/(self.s['units']['dashboard']+'.service')
  unit.write_text('[Unit]\nDescription=Meijendel integral dashboard\nAfter=network.target\n[Service]\nUser=www-data\nGroup=www-data\nExecStart=/usr/bin/python3 '+str(Path(__file__).resolve())+' _dashboard '+str(self.root)+' 18196\nRestart=always\n[Install]\nWantedBy=multi-user.target\n');os.chmod(unit,0o644)
  backup=Path('/etc/systemd/system/vwg-m-baremetal-backup.service.d/50-integral.conf');backup.parent.mkdir(parents=True,exist_ok=True)
  backup.write_text('[Service]\nExecStart=\nExecStart=/usr/bin/python3 '+str(INSTALL/'integral_backup.py')+'\n');os.chmod(backup,0o644)
  self.logged(['systemctl','daemon-reload']);self.logged(['systemctl','enable',self.s['units']['dashboard']])
  env=self.private/'website.env';drop=Path('/etc/systemd/system/vwg-m-linux-app.service.d/50-integral.conf');drop.parent.mkdir(parents=True,exist_ok=True)
  text='[Service]\nWorkingDirectory='+str(package/'website')+'\nEnvironmentFile='+str(env)+'\nExecStart=\nExecStart=/srv/vwgm/vwg-m-linux-app/.venv/bin/python '+str(Path(__file__).resolve())+' _website '+str(package)+'\n'
  temp=drop.with_name(drop.name+'.next');temp.write_text(text);os.chmod(temp,0o644);temp.replace(drop)
  config=Path('/etc/caddy/Caddyfile');text=caddy_config(self.s['caddy_source'],False);temp=config.with_name('Caddyfile.integral-next');temp.write_text(text);os.chmod(temp,0o644)
  self.logged(['caddy','validate','--adapter','caddyfile','--config',temp]);temp.replace(config)
 def start_legacy(self,package):
  spec=jsonfile(package/'legacy.json')['shiny'];name='shiny_meijendel'
  if subprocess.run(['docker','inspect',name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0:self.logged(['docker','rm',name])
  env=self.private/'legacy-shiny.env';write_env(env,dict(item.split('=',1) for item in spec['Config']['Env']),systemd=False)
  args=['docker','run','-d','--name',name,'--env-file',str(env)]
  user=spec['Config'].get('User')
  if user:args+=['--user',user]
  policy=spec['HostConfig']['RestartPolicy']['Name'];args+=['--restart='+policy]
  for mount in spec['Mounts']:
   if mount['Type']!='bind':raise ValueError('Oorspronkelijke Shiny heeft onbekend mounttype')
   args+=['--mount','type=bind,src='+mount['Source']+',dst='+mount['Destination']+('' if mount['RW'] else ',readonly')]
  for target,bindings in (spec['HostConfig'].get('PortBindings') or {}).items():
   for b in bindings or []:args+=['-p',b['HostIp']+':'+b['HostPort']+':'+target]
  if spec['HostConfig'].get('Memory'):args+=['--memory='+str(spec['HostConfig']['Memory'])]
  args+=[spec['Image'],*(spec['Config'].get('Cmd') or [])];self.logged(args)
  self.logged(['systemctl','daemon-reload']);self.logged(['systemctl','start','vwg-m-linux-app','caddy'])
 def health_legacy(self):
  for port in (8091,3838):
   for _ in range(120):
    try:self.get('http://127.0.0.1:'+str(port)+'/');break
    except Exception:time.sleep(.5)
   else:raise RuntimeError('Oorspronkelijke dienst start niet')
  if inspect_container('shiny_meijendel')['Image']!=self.s['original_shiny']['Image']:raise RuntimeError('Oorspronkelijke Shiny-image wijkt af')


def safe_extract(archive,destination):
 import tarfile
 if destination.exists():raise ValueError('Nieuw uitpakpad vereist')
 destination.mkdir(mode=0o700,parents=True)
 with tarfile.open(archive,'r:gz') as tar:
  members=tar.getmembers()
  expanded=sum(m.size for m in members);sql_size=sum(m.size for m in members if m.name=='payload/data/Meijendel.sql')
  if len(members)>100000 or expanded>16*1024**3:raise ValueError('Archief groter dan releasegrens')
  if sys.platform=='linux' and shutil.disk_usage(destination).free<expanded+5*sql_size+8*1024**3:raise ValueError('Onvoldoende ruimte voor pakket, proefdata, drie backups en 8GiB reserve')
  for item in members:
   if not (item.isfile() or item.isdir()) or '\\' in item.name:raise ValueError('Geen links of bijzondere archiefbestanden')
   path=core.safe_path(destination,item.name)
   if item.isdir():path.mkdir(parents=True,exist_ok=True,mode=0o755)
   else:
    path.parent.mkdir(parents=True,exist_ok=True,mode=0o755)
    with tar.extractfile(item) as source,path.open('xb') as target:shutil.copyfileobj(source,target)
    os.chmod(path,0o644);os.utime(path,(item.mtime,item.mtime))

def freeze(commit,digest):
 if not re.fullmatch('[0-9a-f]{64}',digest):raise ValueError('Exacte pakkethash vereist')
 source=STATE/'integral-inbox'/(commit+'.tar.gz');base=CONTROL/'packages'/digest
 if base.exists():
  secure_file(base/'sealed.json')
  if jsonfile(base/'sealed.json')!={'commit':commit,'sha256':digest}:raise ValueError('Verkeerde verzegeling')
 else:
  source_stat=source.lstat()
  if not stat.S_ISREG(source_stat.st_mode) or source.is_symlink():raise ValueError('Geen regulier pakket')
  if shutil.disk_usage(BASE).free<28*1024**3:raise RuntimeError('Minder dan 28GiB vrij; proef niet gestart')
  archive=CONTROL/'packages'/(digest+'.tar.gz');root_directory(archive.parent,0o700)
  fd=os.open(source,os.O_RDONLY|os.O_NOFOLLOW)
  with os.fdopen(fd,'rb') as src,archive.open('xb') as out:shutil.copyfileobj(src,out,1024*1024)
  os.chmod(archive,0o600)
  if core.sha(archive)!=digest:raise ValueError('Pakkethash wijkt af')
  safe_extract(archive,base);secret_json(base/'sealed.json',dict(commit=commit,sha256=digest));archive.unlink()
 receipt=jsonfile(base/'receipt.json')
 if set(receipt.get('commits',{}))!={'Meijendel','VWG_M','VWG_Project'} or any(not re.fullmatch('[0-9a-f]{40}',v) for v in receipt['commits'].values()):raise ValueError('Onbekende commitvelden')
 if receipt.get('schema')!='meijendel-integral-gateway-v1' or receipt['commits']['Meijendel']!=commit or not re.fullmatch('[0-9a-f]{40}',receipt['commits'].get('VWG_M','')):raise ValueError('Releasecommits ontbreken')
 package=base/'payload';m=core.verify(package);guard_payload(m)
 if m.get('source_hash')!=receipt.get('source_hash') or m['year_to']!=receipt['year_to']:raise ValueError('Ontvangstbewijs en payload verschillen')
 return base,receipt,m

@contextlib.contextmanager
def global_lock():
 path=STATE/'production.lock'
 path.mkdir(mode=0o700)
 try:yield
 finally:path.rmdir()

def make_readable(package):
 # This payload has ecological source/code only; private CMS/env/backups live elsewhere.
 for p in [package,*package.rglob('*')]:
  if p.is_symlink():raise ValueError('Symlink in pakket')
  os.chmod(p,0o755 if p.is_dir() else 0o644)

def copy_payload(source,target):
 shutil.copytree(source,target,copy_function=os.link)
 # The mutable control file must never be overwritten through its hard link.
 for name in ('release.json','www/release-config.json'):
  data=(target/name).read_bytes();(target/name).unlink();(target/name).write_bytes(data)

def set_package_id(package,rid,bootstrap=None):
 m=jsonfile(package/'release.json')
 if bootstrap:
  target=package/m['bootstrap']['root']
  shutil.rmtree(target);shutil.copytree(bootstrap,target)
  b=jsonfile(target/'manifest.json');m['bootstrap'].update(html_sha256=b['html_sha256'],manifest_sha256=core.sha(target/'manifest.json'))
 m['release_id']=rid
 public={k:m[k] for k in ('schema','release_id','mode','year_from','year_to','source_hash','presentation_approved','official_data_validated')};public['bootstrap']=m['bootstrap']|dict(root='outputs/bootstrap-presentatie-2026')
 core.atomic_json(package/'www/release-config.json',public)
 m['files']={str(p.relative_to(package)):core.sha(p) for p in sorted(package.rglob('*')) if p.is_file() and p!=package/'release.json'}
 core.atomic_json(package/'release.json',m);make_readable(package);core.verify(package)

def initialize_settings(commit,trial):
 s=layout(commit,trial);root=root_directory(s['root']);private=root_directory(root/'private',0o700);runtime=root_directory(root/'runtime',0o755)
 values=env_file('/etc/vwgm/vwg-m-linux-app.env');url=urllib.parse.urlsplit(values['DATABASE_URL'].replace('postgresql+psycopg://','postgresql://'))
 if url.path!='/vwg':raise ValueError('Onbekende productie-CMS-database')
 s.update(website_env=values,media_root=str(BASE/'vwg-m-linux-app/app/static/uploads'),caddy_source=Path('/etc/caddy/Caddyfile').read_text(),original_shiny=inspect_container('shiny_meijendel'))
 mysql_spec=inspect_container('meijendel-mysql')
 mysql_env=dict(item.split('=',1) for item in mysql_spec['Config']['Env'])
 if mysql_env.get('MYSQL_DATABASE') not in ('Meijendel','meijendel'):raise ValueError('Onbekend productieschema')
 s['mysql_database']=mysql_env['MYSQL_DATABASE']
 s['mysql_image']=mysql_spec['Image'];s['shiny_image']=s['original_shiny']['Image']
 for image in (s['mysql_image'],s['shiny_image']):
  if not re.fullmatch('sha256:[0-9a-f]{64}',image):raise ValueError('Exacte actieve image-ID vereist')
 if trial:
  import secrets
  password=secrets.token_urlsafe(32);s['mysql_password']=password
  values=values|dict(DATABASE_URL=urllib.parse.urlunsplit((url.scheme,url.netloc,'/'+s['database'],url.query,'')),MEIJENDEL_MYSQL_HOST='127.0.0.1',MEIJENDEL_MYSQL_PORT=str(s['ports']['mysql']),MEIJENDEL_MYSQL_DATABASE=s['mysql_database'],MEIJENDEL_MYSQL_USER='integral_reader',MEIJENDEL_MYSQL_PASSWORD=password,MEIJENDEL_MYSQL_SOCKET='',VWG_EMAIL_DELIVERY_DISABLED='1')
  s['website_env']=values
 h=LinuxHooks(s);s['pg_owner']=h.pgsql("SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname='vwg';",'postgres')
 for field in ('uid','gid'):s['shiny_'+field]=int(run(['docker','run','--rm','--network=none','--entrypoint','id',s['shiny_image'],'-'+field[0],'shiny'],capture_output=True,text=True).stdout.strip())
 if trial:
  media=root/'runtime/media';h.capture_files(s['media_root'],private/'initial-media.tar');h.unpack_files(private/'initial-media.tar',media)
  s['media_root']=str(media)
  s['website_env']['VWG_UPLOAD_QUARANTINE_DIR']=str(runtime/'quarantine')
  quarantine=runtime/'quarantine';quarantine.mkdir(mode=0o750);os.chown(quarantine,33,33)
 s['website_data']=str(runtime/'website-data') if trial else str(BASE/'vwg-m-linux-app/app/data')
 if trial:
  h.capture_files(BASE/'vwg-m-linux-app/app/data',private/'initial-data.tar');h.unpack_files(private/'initial-data.tar',s['website_data'])
 secret_json(private/'settings.json',s);return s

def prepare_trial(commit,base,m):
 root=root_directory(layout(commit,True)['root']);marker=root/'trial.marker'
 if marker.exists():raise RuntimeError('Bestaande proef eerst beoordelen/cleanup; niet overschrijven')
 marker.write_text(commit+'\n');os.chmod(marker,0o600);root_directory(root/'private',0o700)
 secret_json(root/'private/ownership.json',dict(database=False))
 s=initialize_settings(commit,True);h=LinuxHooks(s)
 self_env=h.private/'mysql.env';write_env(self_env,dict(MYSQL_ROOT_PASSWORD=s['mysql_password'],MYSQL_DATABASE='Meijendel'),systemd=False)
 h.logged(['docker','network','create','--internal',s['network']])
 data=h.private/'mysql';data.mkdir();os.chown(data,1999,1999)
 h.logged(['docker','run','-d','--name',s['mysql'],'--label','vwgm.integral.commit='+commit,'--network',s['network'],'--restart=no','--memory=768m','--cpus=0.75','--env-file',self_env,'-p','127.0.0.1:33317:3306','--mount',f'type=bind,src={data},dst=/var/lib/mysql',s['mysql_image'],'--local-infile=0','--mysqlx=0','--skip-log-bin','--innodb-buffer-pool-size=134217728','--innodb-redo-log-capacity=536870912'])
 for _ in range(180):
  try:h.sql('SELECT 1;');break
  except Exception:time.sleep(1)
 else:raise RuntimeError('Proef-MySQL start niet')
 releases=root/'releases';releases.mkdir(exist_ok=True);a=releases/('trial-A-'+commit[:12]);b=releases/('trial-B-'+commit[:12])
 copy_payload(base/'payload',b);set_package_id(b,b.name)
 copy_payload(b,a);set_package_id(a,a.name,base/'baseline-bootstrap')
 h.import_mysql(a/m['mysql']['source'],reset=True)
 # Read only the existing production-owned objects, including the historical table.
 names=h.sql("SELECT table_name FROM information_schema.tables WHERE table_schema='Meijendel';",container='meijendel-mysql').splitlines();owned=owned_objects(names)
 with (h.private/'initial_objects.sql').open('wb') as out,h.log.open('ab') as err:run(docker_mysql('meijendel-mysql','mysqldump',('--single-transaction','--no-tablespaces','--set-gtid-purged=OFF',s['mysql_database'],*owned)),stdout=out,stderr=err)
 h.import_mysql(h.private/'initial_objects.sql')
 h.sql("CREATE USER 'integral_reader'@'%' IDENTIFIED BY '"+s['mysql_password']+"';GRANT SELECT ON Meijendel.* TO 'integral_reader'@'%';CREATE TABLE Meijendel._release_probe(id int primary key,value varchar(100));INSERT INTO Meijendel._release_probe VALUES(1,'"+a.name+"');")
 with (h.private/'initial_cms.dump').open('wb') as out:h.pg(['pg_dump','--format=custom','vwg'],stdout=out)
 h.pg(['createdb','--template=template0','--owner='+s['pg_owner'],s['database']],stdout=subprocess.DEVNULL)
 secret_json(h.private/'ownership.json',dict(database=True))
 with (h.private/'initial_cms.dump').open('rb') as src,h.log.open('ab') as log:h.pg(['pg_restore','--exit-on-error','--dbname='+s['database']],stdin=src,stdout=log,stderr=log)
 (Path(s['website_data'])/'_integral_release_probe').write_text(a.name+'\n')
 h.pgsql("CREATE TABLE app._release_probe(id int primary key,value text);INSERT INTO app._release_probe VALUES(1,'"+a.name+"');")
 core.set_current(root,a);h.start(a);h.health(a)
 return h,a,b


def exercise_trial(commit,base,m,digest):
 before=production_identity();h,a,b=prepare_trial(commit,base,m)
 evidence=dict(schema='meijendel-integral-linux-proof-v1',commit=commit,package_sha256=digest,source_hash=m['source_hash'],year_from=m['year_from'],year_to=m['year_to'],production_before=before,platform=sys.platform,images={'mysql':h.s['mysql_image'],'shiny':h.s['shiny_image']})
 core.activate(h.root,b,h);evidence['activation']=jsonfile(h.root/'journal.json');evidence['candidate_health']=jsonfile(h.root/'health.json')
 def partial(package):
  rid=jsonfile(package/'release.json')['release_id'];(Path(h.s['website_data'])/'_integral_release_probe').write_text(rid+'\n');h.sql("UPDATE Meijendel._release_probe SET value='"+rid+"';");h.pgsql("UPDATE app._release_probe SET value='"+rid+"';")
 h.apply=partial;h.fail_health=True
 try:core.activate(h.root,a,h)
 except RuntimeError as e:
  if 'Opzettelijke Linux-healthfout' not in str(e):raise
 else:raise RuntimeError('Bewuste fout niet opgetreden')
 evidence['automatic_recovery']=jsonfile(h.root/'journal.json');evidence['recovered_health']=jsonfile(h.root/'health.json')
 core.rollback(h.root,h);evidence['explicit_rollback']=jsonfile(h.root/'journal.json');evidence['final_health']=jsonfile(h.root/'health.json');evidence['databases_equal_to_backups']=True;evidence['mutable_files_equal_to_backups']=True
 h.stop();evidence['production_after']=production_identity()
 if before!=evidence['production_after']:raise RuntimeError('Productie-identiteit is tijdens de proef veranderd')
 evidence['success']=True
 target=root_directory(CONTROL/'evidence',0o700);secret_json(target/(commit+'.json'),evidence)
 return evidence


def cleanup_trial(commit):
 s=layout(commit,True);root=Path(s['root']);marker=root/'trial.marker'
 if not marker.exists() or marker.is_symlink() or marker.read_text().strip()!=commit:raise ValueError('Geen eigen proefmarker; niets verwijderd')
 settings=jsonfile(root/'private/settings.json') if (root/'private/settings.json').exists() else s
 h=LinuxHooks(settings);h.stop()
 for name in (s['mysql'],s['shiny']):
  q=subprocess.run(['docker','inspect',name],capture_output=True,text=True)
  if q.returncode:
   continue
  value=json.loads(q.stdout)[0]
  if value['Config']['Labels'].get('vwgm.integral.commit')!=commit:raise ValueError('Container hoort niet bij deze proef')
  h.logged(['docker','rm','-f',name])
 if jsonfile(root/'private/ownership.json').get('database'):
  h.pgsql("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='"+s['database']+"';",'postgres');h.pg(['dropdb','--if-exists',s['database']],stdout=subprocess.DEVNULL)
 q=subprocess.run(['docker','network','inspect',s['network']],capture_output=True)
 if q.returncode==0:h.logged(['docker','network','rm',s['network']])
 # Exact task root, no source/production data. Evidence was saved independently.
 shutil.rmtree(root)


def legacy_baseline(h):
 root=h.root;current=core.current(root)
 if current:return current
 rid='legacy-'+(STATE/'Meijendel.commit').read_text().strip()[:12];path=root/'releases'/rid;path.mkdir(parents=True,mode=0o700)
 secret_json(path/'legacy.json',{'shiny':h.s['original_shiny']})
 m=dict(schema='meijendel-integral-release-v1',release_id=rid,mode='production',year_from=1958,year_to=int(h.sql('SELECT MAX(jaar) FROM Meijendel.territoria;')),source_hash=core.sha(BASE/'data/Meijendel.sql'),official_data_validated=True,presentation_approved=False,components=['website','dashboard','shiny','mysql','cms'],legacy=True,files={'legacy.json':core.sha(path/'legacy.json')})
 core.atomic_json(path/'release.json',m);core.set_current(root,path);return path


def phase_commits(stage,marker,receipt):
 return marker['production_commits'] if stage=='apply' else {n:receipt['commits'][n] for n in ('Meijendel','VWG_M')}


def production_action(stage,commit,base,receipt,m):
 if receipt.get('intent')!='production' or receipt.get('canonical_export_validated') is not True or m['mode']!='production' or not m['official_data_validated']:raise ValueError('Geen expliciete gevalideerde productierelease')
 marker=jsonfile(base/'preflight.json')
 if marker.get('commits')!=receipt['commits']:raise ValueError('Geen passende gecontroleerde preflight')
 expected_commits=phase_commits(stage,marker,receipt)
 for name,expected in expected_commits.items():
  if (STATE/(name+'.commit')).read_text().strip()!=expected:raise ValueError('Productiecommit past niet bij deze fase')
 root=CONTROL/'production';config=root/'private/settings.json'
 s=jsonfile(config) if config.exists() else initialize_settings(commit,False);h=LinuxHooks(s)
 legacy_baseline(h)
 if stage=='apply':
  live=set(h.sql("SELECT table_name FROM information_schema.tables WHERE table_schema='Meijendel';").splitlines())
  unknown=live-sql_objects(base/'payload/data/Meijendel.sql')-set(OBJECTS)
  if unknown:raise ValueError('Niet-gedekte productieobjecten: '+','.join(sorted(unknown)))
  package=root/'releases'/m['release_id']
  if not package.exists():
   copy_payload(base/'payload',package);meta=jsonfile(package/'release.json');meta['source_commits']=receipt['commits'];meta['gateway_package_sha256']=jsonfile(base/'sealed.json')['sha256'];core.atomic_json(package/'release.json',meta);make_readable(package)
  try:core.activate(root,package,h)
  finally:
   if (root/'journal.json').exists() and jsonfile(root/'journal.json').get('phase') in ('active','restored','rolled_back') and getattr(h,'timers',[]):h.logged(['systemctl','start',*h.timers])
  for name in ('Meijendel','VWG_M'):
   value=receipt['commits'][name]
   path=STATE/(name+'.commit');temp=path.with_name(path.name+'.next');temp.write_text(value+'\n');temp.replace(path)
  if getattr(h,'timers',[]):h.logged(['systemctl','start',*h.timers])
 elif stage=='rollback':
  try:core.rollback(root,h)
  finally:
   if (root/'journal.json').exists() and jsonfile(root/'journal.json').get('phase') in ('active','restored','rolled_back') and getattr(h,'timers',[]):h.logged(['systemctl','start',*h.timers])


def dashboard(root,port):
 root=Path(root).resolve()
 class Handler(http.server.SimpleHTTPRequestHandler):
  def do_GET(self):
   path=urllib.parse.urlsplit(self.path).path
   if path in ('/Meijendel.sql','/meijendel.sql'):
    source=core.current(root)/'data/Meijendel.sql';self.send_response(200);self.send_header('Content-Type','text/plain');self.send_header('Content-Length',str(source.stat().st_size));self.end_headers()
    with source.open('rb') as data:shutil.copyfileobj(data,self.wfile)
    return
   match=re.fullmatch(r'/releases/([A-Za-z0-9][A-Za-z0-9._-]{0,99})/www/(.*)',path)
   if not match:
    active=core.current(root);self.send_response(307);self.send_header('Location','/releases/'+active.name+'/www/'+self.path.lstrip('/'));self.end_headers();return
   self.directory=str(root/'releases'/match[1]/'www');self.path='/'+match[2];super().do_GET()
  def log_message(self,*args):pass
 http.server.ThreadingHTTPServer(('127.0.0.1',int(port)),Handler).serve_forever()


def website(package):
 package=Path(package).resolve();os.chdir(package/'website');sys.path.insert(0,str(package/'website'))
 manifest=jsonfile(package/'release.json')
 url=urllib.parse.urlsplit(os.environ['DATABASE_URL'])
 if manifest['mode']=='local_rehearsal' and not re.fullmatch('/vwg_integral_[0-9a-f]{12}',url.path):raise RuntimeError('Geen geïsoleerde CMS-verbinding')
 from app import main
 main.GROUP_DENSITY_CSV=package/'www/groepen_grafieken/groep_dichtheid.csv';main.GROUP_SPECIES_CSV=package/'www/groepen_grafieken/groep_soorten.csv'
 import uvicorn
 uvicorn.run(main.app,host='127.0.0.1',port=int(os.environ['VWG_INTEGRAL_WEBSITE_PORT']))


def main():
 if len(sys.argv)>1 and sys.argv[1] in ('_website','_dashboard'):
  if os.geteuid()==0:raise SystemExit('Diensten draaien nooit als root')
  if sys.argv[1]=='_website':return website(sys.argv[2])
  return dashboard(sys.argv[2],sys.argv[3])
 import signal
 def interrupted(signum,frame):raise RuntimeError('Onderbroken Linux-release: '+str(signum))
 signal.signal(signal.SIGTERM,interrupted);signal.signal(signal.SIGINT,interrupted)
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('stage',choices=['preflight','rehearse','apply','rollback','cleanup','recover']);parser.add_argument('commit');parser.add_argument('sha256');a=parser.parse_args()
 layout(a.commit,True)
 if os.geteuid()!=0:raise SystemExit('Alleen via de gesloten root-gateway')
 secure_file(Path(__file__));secure_file(INSTALL/'integral_release.py')
 with global_lock():
  if a.stage=='recover':
   root=CONTROL/'production';package=core.current(root);m=core.verify(package)
   if m.get('legacy') or m.get('source_commits',{}).get('Meijendel')!=a.commit or m.get('gateway_package_sha256')!=a.sha256:raise ValueError('Herstel past niet bij de opgeslagen actieve release')
   s=jsonfile(root/'private/settings.json');s['caddy_source']=Path('/etc/caddy/Caddyfile').read_text();s['website_env']=env_file('/etc/vwgm/vwg-m-linux-app.env')
   recovery=jsonfile(root/'recovery-runtime.json');s['shiny_image']=recovery['shiny_image']
   if not re.fullmatch('sha256:[0-9a-f]{64}',s['shiny_image']):raise ValueError('Geen exact herstelde Shiny-image')
   h=LinuxHooks(s)
   try:h.stop();h.start(package);h.health(package)
   except Exception:
    h.stop();raise
   if getattr(h,'timers',[]):h.logged(['systemctl','start',*h.timers])
   print('INTEGRAL_HOST_RECOVERY_OK');return
  base,receipt,m=freeze(a.commit,a.sha256)
  if a.stage=='preflight':
   response=dict(stage='preflight',source_hash=m['source_hash'],year_to=m['year_to'],commits=receipt['commits'],production_commits={n:(STATE/(n+'.commit')).read_text().strip() for n in ('Meijendel','VWG_M')})
   secret_json(base/'preflight.json',response);print(json.dumps(response));return
  if a.stage=='rehearse':
   if receipt.get('intent')!='isolated_trial' or m['mode']!='local_rehearsal' or m['year_to']>2025:raise ValueError('Alleen de uitdrukkelijke historische proef')
   evidence=CONTROL/'evidence'/(a.commit+'.json')
   if evidence.exists():
    result=jsonfile(evidence)
    if result.get('package_sha256')!=a.sha256 or not result.get('success') or production_identity()!=result.get('production_after'):raise ValueError('Ander of onvoltooid bewijs')
   else:result=exercise_trial(a.commit,base,m,a.sha256)
   print(json.dumps(result,sort_keys=True));return
  if a.stage=='cleanup':
   if receipt['intent']!='isolated_trial':raise ValueError('Cleanup is uitsluitend voor de proef')
   cleanup_trial(a.commit)
   shutil.rmtree(base)
   inbox=STATE/'integral-inbox'/(a.commit+'.tar.gz')
   if inbox.is_file() and not inbox.is_symlink() and core.sha(inbox)==a.sha256:inbox.unlink()
   print('INTEGRAL_TRIAL_CLEANUP_OK');return
  pending=CONTROL/'production/journal.json'
  if pending.exists() and jsonfile(pending).get('phase')=='recovery_failed':raise ValueError('Eerst het vastgelegde herstelincident oplossen')
  production_action(a.stage,a.commit,base,receipt,m);print('INTEGRAL_'+a.stage.upper()+'_OK')
if __name__=='__main__':main()
