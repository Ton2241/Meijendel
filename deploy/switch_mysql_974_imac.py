#!/usr/bin/env python3
"""Controlled local Oracle patch upgrade; SQL stays in Ton's login-path context."""
import argparse,datetime as dt,gzip,hashlib,json,os,plistlib,pwd,re,shutil,signal,stat,subprocess,sys,time,threading
from pathlib import Path

SCHEMAS=['Meijendel','Meijendel_bronnen','meijendel_db','Meijendel_ndff_secure','Meijendel_pq_proef_20260927']
ARCHIVE_SHA='39e8e45a986773858f56f931829770f78463e6f5442260746b8d1a3e49763452'
DMG_SHA='899a34de0de332dadcf8201721d145d7894ecaf644c2716cd7b1995c870a9488'
WORK=Path('/Users/ton/VWG-maintenance/2026-10-22/mysql-upgrade-work')
OLD=Path('/usr/local/mysql-9.7.1-macos15-arm64')
NEW=Path('/usr/local/mysql-9.7.4-macos15-arm64')
LINK=Path('/usr/local/mysql')
PLIST=Path('/Library/LaunchDaemons/com.oracle.oss.mysql.mysqld.plist')
LABEL='system/com.oracle.oss.mysql.mysqld'
STATE=Path('/var/db/vwgm-mysql974-20261022')
OPTS=['--no-defaults','--login-path=meijendel_root','--protocol=tcp','--host=127.0.0.1','--port=3306']
BASE_ARGS=['/usr/local/mysql/bin/mysqld','--user=_mysql','--basedir=/usr/local/mysql','--datadir=/usr/local/mysql/data','--plugin-dir=/usr/local/mysql/lib/plugin','--log-error=/usr/local/mysql/data/mysqld.local.err','--pid-file=/usr/local/mysql/data/mysqld.local.pid']
DUMP_FLAGS=['--single-transaction','--routines','--triggers','--events','--hex-blob','--set-gtid-purged=OFF','--no-tablespaces','--databases',*SCHEMAS]

def sha(path):
 h=hashlib.sha256()
 with Path(path).open('rb') as f:
  while chunk:=f.read(8*1024*1024):h.update(chunk)
 return h.hexdigest()

def dump_hash(path):
 h=hashlib.sha256()
 with gzip.open(path,'rb') as f:
  for line in f:
   if line.startswith(b'-- Dump completed on '):continue
   if line.startswith(b'-- Server version\t'):
    if line.rstrip(b'\r\n') not in (b'-- Server version\t9.7.1',b'-- Server version\t9.7.4'):raise ValueError('onverwachte dumpserverversie')
    line=b'-- Server version\tVERSION\n'
   h.update(line)
 return h.hexdigest()

def validate_manifest(value):
 required=dict(status='validated-local-candidate-only',source_version='9.7.1',target_version='9.7.4',schemas=SCHEMAS,objects=724,checks=668,accounts=2,archive_sha256=ARCHIVE_SHA,source_objects_schema_accounts_and_counts_equal=True)
 if any(value.get(k)!=v for k,v in required.items()):raise ValueError('proefmanifest wijkt af van beoordeeld bewijs')

def validate_service(service,actual_data):
 if service.get('Program')!='/usr/local/mysql/bin/mysqld' or service.get('ProgramArguments')!=BASE_ARGS or service.get('UserName')!='_mysql' or service.get('GroupName')!='_mysql':raise ValueError('launchd-configuratie wijkt af van beoordeelde bron')
 if Path(actual_data).resolve()!=(OLD/'data').resolve():raise ValueError('werkelijke bron-datamap wijkt af')

def new_args(readonly):
 args=['/usr/local/mysql/bin/mysqld','--no-defaults','--user=_mysql','--basedir='+str(NEW),'--datadir='+str(NEW/'data'),'--plugin-dir='+str(NEW/'lib/plugin'),'--log-error='+str(NEW/'data/mysqld.local.err'),'--pid-file='+str(NEW/'data/mysqld.local.pid'),'--lower-case-table-names=2','--event-scheduler=ON','--innodb-redo-log-capacity=536870912']
 if readonly:args.append('--super-read-only=ON')
 return args

def transaction(op):
 frozen=False;stopping=False
 try:
  frozen=True;op.freeze();op.fresh()
  stopping=True;op.stop_old();op.install();op.activate();op.verify();op.writable()
 except BaseException:
  if getattr(op,'write_exposed',False) is True:op.preserve_new()
  elif stopping:op.rollback()
  elif frozen:op.unfreeze_old()
  raise

def recover(op):
 # The vendor has already removed OLD executables. Never rerun its installer
 # or activate the old datadir as an implicit recovery action.
 op.recovery_prepare()
 try:op.activate();op.verify();op.writable()
 except BaseException:op.preserve_new();raise


def replace_link(target):
 if not LINK.is_symlink():raise ValueError('centrale mysql-koppeling is geen symlink; niets verwijderen')
 if target not in (OLD,NEW):raise ValueError('onbekend koppelingsdoel')
 admin('/bin/rm',LINK)
 admin('/bin/ln','-s',target.name,LINK)
 # Darwin honours symlink access modes; sudo can inherit umask 077.
 admin('/bin/chmod','-h','777',LINK)
 if LINK.resolve()!=target.resolve():raise ValueError('koppeling wijkt af na herstel')


def validate_frozen_source(path):
 path=Path(path)
 if path.parent!=WORK.parent or not re.fullmatch(r'source-frozen-[0-9]{6}\.sql\.gz',path.name):raise ValueError('onbekende bevroren bronkopie')
 if path.is_symlink() or not path.is_file() or path.stat().st_uid!=os.getuid() or path.stat().st_mode&0o077:raise ValueError('bronkopie niet besloten/eigen')
 if dump_hash(path)!=dump_hash(WORK/'imac-974-proof/user-schemas.sql.gz'):raise ValueError('bevroren bron wijkt af van de gevalideerde proef')


def other_maintenance_pids():
 result=[]
 for line in run(['/bin/ps','-axo','pid=,comm=,args=']).stdout.decode().splitlines():
  row=line.split(None,2)
  if len(row)<3:continue
  pid=int(row[0]);program=Path(row[1]).name
  if pid==os.getpid():continue
  if program=='installer' or (program.lower().startswith('python') and 'switch_mysql_974_imac.py' in row[2]):result.append(pid)
 return result


def run(args,*,check=True,input=None,timeout=120):
 result=subprocess.run([str(a) for a in args],input=input,capture_output=True,timeout=timeout)
 if check and result.returncode:raise RuntimeError('opdracht mislukt: '+str(args[0])+'; stop en beoordeel het besloten onderhoudslog')
 return result

def admin(*args,**kw):return run(['/usr/bin/sudo','-n',*args],**kw)

def query(sql):
 client=NEW/'bin/mysql' if (NEW/'bin/mysql').is_file() else OLD/'bin/mysql'
 result=run([client,*OPTS,'--batch','--raw','--skip-column-names','-e',sql],timeout=1800)
 return result.stdout.decode().rstrip('\n')

def accounts():
 result={}
 for line in query("SELECT User,Host FROM mysql.user WHERE User NOT IN ('mysql.infoschema','mysql.session','mysql.sys') ORDER BY User,Host").splitlines():
  user,host=line.split('\t')
  if not re.fullmatch(r'[a-zA-Z0-9_]+',user) or not re.fullmatch(r'[a-zA-Z0-9_.]+',host):raise ValueError('onverwachte accountnaam')
  account="'"+user+"'@'"+host+"'"
  result[account]=dict(create=query('SHOW CREATE USER '+account).split('\t')[-1],grants=sorted(query('SHOW GRANTS FOR '+account).splitlines()))
 return result

def dump(path):
 binary=WORK/'downloads/mysql-9.7.4-macos15-arm64/bin/mysqldump'
 with path.open('xb') as out,(path.parent/(path.name+'.errors')).open('wb') as err:
  p=subprocess.Popen([str(binary),*OPTS,*DUMP_FLAGS],stdout=subprocess.PIPE,stderr=err)
  try:
   with gzip.GzipFile(fileobj=out,mode='wb') as zipped:
    while chunk:=p.stdout.read(1024*1024):zipped.write(chunk)
   if p.wait(timeout=30)!=0:raise RuntimeError('volledige SQL-dump mislukt')
  finally:
   if p.poll() is None:p.terminate();p.wait(timeout=30)

def mysql_pids():
 output=run(['/bin/ps','-axo','pid=,comm=']).stdout.decode()
 return [int(line.split(None,1)[0]) for line in output.splitlines() if line.split(None,1)[-1].endswith('/mysqld')]

def stopped():
 for _ in range(120):
  if not mysql_pids():return
  time.sleep(1)
 raise RuntimeError('MySQL-proces is niet aantoonbaar gestopt; geen datamap/symlink wijzigen')

def wait_version(version):
 for _ in range(120):
  try:
   if query('SELECT VERSION()')==version:return
  except (RuntimeError,subprocess.TimeoutExpired):pass
  time.sleep(1)
 raise RuntimeError('MySQL werd niet gereed met versie '+version)

class Operation:
 def __init__(self):
  self.saved_accounts=json.loads((WORK/'imac-974-proof/accounts-before.json').read_text())
  self.before=json.loads((WORK/'imac-974-proof/source-final-inventory.json').read_text())
  self.mount=WORK.parent/'oracle-installer-readonly';self.owns_mount=False
  self.original_plist=PLIST.read_bytes();self.installed=False
  self.data_moved=False;self.service_stopped=False;self.old_stopped=False;self.write_exposed=False;self.current_dump=None
  self.args=plistlib.loads(self.original_plist)['ProgramArguments']
  if not isinstance(self.args,list) or self.args[0]!='/usr/local/mysql/bin/mysqld':raise ValueError('onbekende launchd-opdracht')
 def preflight(self):
  if sys.platform!='darwin' or os.getuid()==0 or Path.home()!=Path('/Users/ton'):raise ValueError('alleen Ton op de iMac, zonder root-Python')
  if WORK.is_symlink() or WORK.stat().st_mode&0o077 or WORK.stat().st_uid!=os.getuid():raise ValueError('werkmap niet besloten/eigen')
  relocation=json.loads((WORK.parent/'mysql-work-relocation-proof.json').read_text())
  if relocation.get('status')!='verified-identical-before-source-removal' or relocation.get('destination')!=str(WORK) or Path(relocation['source']).exists():raise ValueError('volledige verplaatsing buiten iCloud nog niet bevestigd')
  if not LINK.is_symlink() or LINK.resolve()!=OLD or NEW.exists():raise ValueError('andere installatie of doel bestaat al')
  if not (OLD/'data').is_dir() or STATE.exists():raise ValueError('brondata of onderhoudsstatus niet zoals verwacht')
  if PLIST.is_symlink() or PLIST.stat().st_uid!=0 or PLIST.stat().st_mode&0o022:raise ValueError('onveilige launchd-plist')
  validate_service(plistlib.loads(self.original_plist),query('SELECT @@datadir'))
  if query('SELECT VERSION(),@@read_only,@@super_read_only')!='9.7.1\t0\t0':raise ValueError('bronversie/schrijfstatus wijkt af')
  if len(mysql_pids())!=1:raise ValueError('niet precies één MySQL-server')
  if query("SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE ID<>CONNECTION_ID() AND COMMAND NOT IN ('Sleep','Daemon')")!='0':raise ValueError('ander databasewerk actief')
  if query('SELECT COUNT(*) FROM information_schema.EVENTS')!='0':raise ValueError('actieve events eerst beoordelen')
  validate_manifest(json.loads((WORK/'imac-974-proof/manifest.json').read_text()))
  if sha(WORK/'imac-974-proof/user-schemas.sql.gz')!=ARCHIVE_SHA:raise ValueError('proefdump gewijzigd')
  if accounts()!=self.saved_accounts:raise ValueError('accounts gewijzigd sinds proef')
  for p,dirs,files in os.walk(WORK/'imac-974-proof/data'):
   for n in dirs+files:
    q=Path(p)/n
    if q.is_symlink() or q.stat().st_uid!=os.getuid():raise ValueError('onverwacht bestand in eigen proefdata')
  dmg=WORK/'downloads/mysql-9.7.4-macos15-arm64.dmg'
  if sha(dmg)!=DMG_SHA:raise ValueError('installerchecksum wijkt af')
  run(['/usr/bin/hdiutil','verify',dmg],timeout=180)
  if self.mount.exists():raise ValueError('installer-mount bestaat al')
  self.mount.mkdir(mode=0o700);self.owns_mount=True
  run(['/usr/bin/hdiutil','attach','-readonly','-nobrowse','-mountpoint',self.mount,dmg],timeout=180)
  packages=list(self.mount.glob('*.pkg'))
  if len(packages)!=1:raise ValueError('installer niet eenduidig')
  self.package=packages[0]
  signature=run(['/usr/sbin/pkgutil','--check-signature',self.package]).stdout.decode()
  if 'VB5E2TV963' not in signature or 'trusted' not in signature.lower():raise ValueError('Oracle-/Apple-signatuur niet bevestigd')
  if shutil.disk_usage('/System/Volumes/Data').free<12*1024**3:raise ValueError('minder dan12GiBvrij')
  print('GROEN|imac974-voorcontrole|bron=9.7.1|proef=724/668|accounts=2|installer=geverifieerd',flush=True)
 def recovery_preflight(self,source):
  if sys.platform!='darwin' or os.getuid()==0 or Path.home()!=Path('/Users/ton'):raise ValueError('alleen Ton op de iMac, zonder root-Python')
  if WORK.is_symlink() or WORK.stat().st_uid!=os.getuid() or WORK.stat().st_mode&0o077:raise ValueError('werkmap niet besloten/eigen')
  if mysql_pids() or other_maintenance_pids():raise ValueError('MySQL, installer of andere omschakelhelper is nog actief')
  if (WORK.parent/'imac-mysql-runtime.json').exists():raise ValueError('schrijfbare omschakeling al geregistreerd; geen herstelmodus')
  if not LINK.is_symlink() or PLIST.is_symlink() or PLIST.stat().st_uid!=0 or PLIST.stat().st_mode&0o022:raise ValueError('onveilige centrale koppeling of launchd-configuratie')
  validate_service(plistlib.loads(self.original_plist),str(OLD/'data'))
  validate_manifest(json.loads((WORK/'imac-974-proof/manifest.json').read_text()))
  if sha(WORK/'imac-974-proof/user-schemas.sql.gz')!=ARCHIVE_SHA:raise ValueError('proefdump gewijzigd')
  if len(self.saved_accounts)!=2 or len(self.before['objects'])!=724:raise ValueError('onvolledig vergelijkingsbewijs')
  uid=pwd.getpwnam('_mysql').pw_uid
  identities=[]
  for base in (OLD,NEW):
   if base.is_symlink() or base.stat().st_uid!=0:raise ValueError('onveilige versiegebonden installatiemap')
   data=base/'data'
   if data.is_symlink() or not data.is_dir() or data.stat().st_uid!=uid or data.stat().st_mode&0o022:raise ValueError('onveilige gegevensmap')
   identities.append((data.stat().st_dev,data.stat().st_ino))
  if identities[0]==identities[1]:raise ValueError('bron en doel delen dezelfde gegevensmap')
  if (WORK/'imac-974-proof/data').exists():raise ValueError('proefdata niet naar het verwachte doel verplaatst')
  for name in ('mysql','mysqld','mysqldump'):
   binary=NEW/'bin'/name
   if not re.search(r'\b9\.7\.4\b',run([binary,'--no-defaults','--version']).stdout.decode()):raise ValueError('geïnstalleerde doelversie wijkt af')
   run(['/usr/bin/codesign','--verify','--strict',binary])
   signature=run(['/usr/bin/codesign','-dv','--verbose=2',binary]).stderr.decode()
   if 'TeamIdentifier=VB5E2TV963' not in signature:raise ValueError('Oracle-signatuur van doelbinary niet bevestigd')
  self.current_dump=Path(source);validate_frozen_source(self.current_dump)
  print('GROEN|imac974-herstelvoorcontrole|geïnstalleerd=9.7.4|geen-server-actief|bronkopie=identiek|rootstatus=nog-controleren',flush=True)
 def recovery_prepare(self):
  # This metadata is deliberately checked after visible sudo authentication.
  for path,kind in ((STATE,'Directory'),(STATE/'original.plist','Regular File')):
   value=admin('/usr/bin/stat','-f','%HT:%u:%Lp',path).stdout.decode().strip().rsplit(':',2)
   if len(value)!=3 or value[0]!=kind or value[1]!='0' or int(value[2],8)&0o022:raise ValueError('onveilige root-herstelstatus')
  original=admin('/bin/cat',STATE/'original.plist').stdout
  validate_service(plistlib.loads(original),str(OLD/'data'))
  if original!=self.original_plist:raise ValueError('actuele configuratie wijkt af van root-bronkopie')
  if mysql_pids() or other_maintenance_pids():raise ValueError('ander onderhoud of een database werd gestart')
  admin('/bin/launchctl','bootout',LABEL,check=False);stopped()
  if admin('/bin/launchctl','print',LABEL,check=False).returncode==0:raise ValueError('launchd-job is nog geladen')
  replace_link(NEW)
  self.old_stopped=True;self.service_stopped=True;self.data_moved=True;self.installed=True
 def freeze(self):
  query('SET GLOBAL super_read_only=ON')
  if query('SELECT @@read_only,@@super_read_only')!='1\t1':raise ValueError('bron niet bevroren')
 def fresh(self):
  self.current_dump=WORK.parent/('source-frozen-'+dt.datetime.now().strftime('%H%M%S')+'.sql.gz')
  print('CONTROLE|imac974|verse-volledige-bronvergelijking',flush=True)
  dump(self.current_dump)
  if dump_hash(self.current_dump)!=dump_hash(WORK/'imac-974-proof/user-schemas.sql.gz'):raise ValueError('brondata sinds proef gewijzigd; nieuwe proef nodig')
  if accounts()!=self.saved_accounts:raise ValueError('bronaccounts gewijzigd')
 def stop_old(self):
  admin('/bin/mkdir','-m','700',STATE)
  admin('/bin/cp','-p',PLIST,STATE/'original.plist')
  self.service_stopped=True
  admin('/bin/launchctl','bootout',LABEL)
  stopped();self.old_stopped=True
 def install(self):
  print('INSTALLATIE|officieel-Oracle-pakket|oude-datamap-blijft-behouden',flush=True)
  admin('/usr/sbin/installer','-pkg',self.package,'-target','/',timeout=600)
  self.installed=True
  if not LINK.is_symlink():raise ValueError('installer heeft geen symlink geplaatst')
  admin('/bin/chmod','-h','777',LINK)
  if LINK.resolve()!=NEW:raise ValueError('installer heeft niet de verwachte symlink geplaatst')
  version=run([NEW/'bin/mysqld','--no-defaults','--version']).stdout.decode()
  if not re.search(r'\b9\.7\.4\b',version):raise ValueError('geïnstalleerde binaryversie onjuist')
  if mysql_pids():raise ValueError('installer heeft onverwacht MySQL gestart')
  # rmdir can only remove an empty installer-created directory.
  admin('/bin/rmdir',NEW/'data',check=False)
  if (NEW/'data').exists():raise ValueError('doeldata niet leeg; niet overschrijven')
  admin('/bin/mv',WORK/'imac-974-proof/data',NEW/'data')
  self.data_moved=True
  admin('/usr/sbin/chown','-R','_mysql:_mysql',NEW/'data',timeout=180)
 def plist_args(self,readonly):
  admin('/usr/bin/plutil','-replace','ProgramArguments','-json',json.dumps(new_args(readonly)),PLIST)
 def activate(self):
  admin('/bin/cp','-p',STATE/'original.plist',PLIST)
  self.plist_args(True)
  admin('/bin/launchctl','bootstrap','system',PLIST)
  wait_version('9.7.4')
 def verify(self):
  if Path(query('SELECT @@datadir')).resolve()!=(NEW/'data').resolve():raise ValueError('doelserver gebruikt niet uitsluitend de nieuwe datamap')
  if query('SELECT @@read_only,@@super_read_only,@@innodb_redo_log_capacity,@@lower_case_table_names')!='1\t1\t536870912\t2':raise ValueError('doelinstellingen wijken af')
  if accounts()!=self.saved_accounts:raise ValueError('doelaccounts of rechten wijken af')
  target=WORK.parent/('target-readonly-'+dt.datetime.now().strftime('%H%M%S')+'.sql.gz')
  dump(target)
  if dump_hash(target)!=dump_hash(self.current_dump):raise ValueError('volledige doelinhoud wijkt af van bevroren bron')
  objects=[r.split('\t') for r in query("SELECT TABLE_SCHEMA,TABLE_NAME,TABLE_TYPE FROM information_schema.TABLES WHERE TABLE_SCHEMA IN ("+','.join("'"+s+"'" for s in SCHEMAS)+") ORDER BY TABLE_SCHEMA,TABLE_NAME").splitlines()]
  if objects!=self.before['objects']:raise ValueError('doelobjecten wijken af')
  checks=0
  for schema,table,kind in objects:
   if kind!='BASE TABLE':continue
   name='`'+schema.replace('`','``')+'`.`'+table.replace('`','``')+'`'
   if query('CHECK TABLE '+name+' EXTENDED').splitlines()[-1].split('\t')[-2:]!=['status','OK']:raise ValueError('doeltabelcontrole faalde')
   checks+=1
   if checks%50==0:print('CONTROLE|imac974-tabellen|gereed='+str(checks)+'/668',flush=True)
  if checks!=668:raise ValueError('onjuist aantal tabelcontroles')
  query('SET PERSIST innodb_redo_log_capacity=536870912')
  if query('SELECT @@read_only,@@super_read_only,@@innodb_redo_log_capacity')!='1\t1\t536870912':raise ValueError('readonly-status/redo vóór vrijgave onjuist')
  for name in ['mysql','mysqldump']:
   text=run([NEW/'bin'/name,'--no-defaults','--version']).stdout.decode()
   if not re.search(r'\b9\.7\.4\b',text):raise ValueError('clientversie wijkt af')
 def writable(self):
  # Reload launchd without the temporary readonly startup flag only after the
  # complete readonly target verification. Original source data remain intact.
  admin('/bin/launchctl','bootout',LABEL);stopped();self.plist_args(False)
  self.write_exposed=True
  admin('/bin/launchctl','bootstrap','system',PLIST);wait_version('9.7.4')
  if query('SELECT VERSION(),@@read_only,@@super_read_only')!='9.7.4\t0\t0':raise ValueError('definitieve schrijfbare start niet bevestigd; nieuwe data behouden')
  record=dict(status='validated-active-runtime',version='9.7.4',data=str(NEW/'data'),rollback_data=str(OLD/'data'),schemas=SCHEMAS,objects=724,checks=668,accounts=2,full_logical_equivalence=True,rollback_programs_available=(OLD/'bin/mysqld').is_file(),completed_at=dt.datetime.now(dt.timezone.utc).isoformat())
  (WORK.parent/'imac-mysql-runtime.json').write_text(json.dumps(record,indent=2)+'\n')
  print('GROEN|imac974-omschakeling|versie=9.7.4|objects=724|checks=668|accounts=2|terugvaldata=9.7.1-behouden|oude-programmas=afzonderlijk-beoordelen',flush=True)
 def unfreeze_old(self):
  if query('SELECT VERSION()')!='9.7.1':raise RuntimeError('bronidentiteit onduidelijk; geen blinde schrijfwijziging')
  query('SET GLOBAL super_read_only=OFF; SET GLOBAL read_only=OFF')
 def old_is_live(self):
  try:
   return LINK.resolve()==OLD and query('SELECT VERSION()')=='9.7.1' and run(['/bin/launchctl','print',LABEL],check=False).returncode==0
  except (RuntimeError,subprocess.TimeoutExpired):return False
 def preserve_new(self):
  # Once a writable start is attempted, the new data may contain new writes.
  # Preserve that source and never silently reactivate the stale old copy.
  phase='schrijfbare-9.7.4-mogelijk-gestart' if self.write_exposed else 'readonly-9.7.4-herstel-afgebroken'
  print('BLOKKADE|'+phase+'|nieuwe-data-behouden|geen-terugval-op-oude-data',flush=True)
  admin('/bin/launchctl','bootout',LABEL,check=False);stopped()
 def rollback(self):
  if not self.service_stopped or (not self.old_stopped and self.old_is_live()):
   self.unfreeze_old();return
  if not self.old_stopped:
   try:self.unfreeze_old()
   except (RuntimeError,subprocess.TimeoutExpired):pass
  if not (OLD/'bin/mysqld').is_file():
   admin('/bin/launchctl','bootout',LABEL,check=False);stopped()
   raise RuntimeError('oude programma’s ontbreken; beide datamappen behouden, herstelmodus nodig')
  print('HERSTEL|oorspronkelijke-installatie-en-data',flush=True)
  admin('/bin/launchctl','bootout',LABEL,check=False);stopped()
  # The old version is only ever started with its own original data directory.
  replace_link(OLD)
  admin('/bin/cp','-p',STATE/'original.plist',PLIST)
  admin('/bin/launchctl','bootstrap','system',PLIST);wait_version('9.7.1');self.unfreeze_old()
  if query('SELECT VERSION(),@@read_only,@@super_read_only')!='9.7.1\t0\t0':raise RuntimeError('terugvalcontrole mislukt')
  print('GROEN|imac974-terugval|9.7.1|oude-data|schrijfstatus=aan',flush=True)
 def cleanup(self):
  if self.owns_mount and self.mount.exists():
   run(['/usr/bin/hdiutil','detach',self.mount],check=False)
   try:self.mount.rmdir()
   except OSError:pass

def main():
 p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');p.add_argument('--yes',action='store_true')
 p.add_argument('--recover-installed',action='store_true');p.add_argument('--source-frozen',type=Path);a=p.parse_args()
 if a.recover_installed!=bool(a.source_frozen):p.error('--recover-installed en --source-frozen samen gebruiken')
 if a.apply!=a.yes:p.error('gebruik --apply --yes samen')
 os.umask(0o077)
 op=Operation()
 try:
  if a.recover_installed:op.recovery_preflight(a.source_frozen)
  else:op.preflight()
  if not a.apply:print('ALLEEN VOORCONTROLE|geen installatie of schrijfstoppauze');return
  if not sys.stdin.isatty() or not sys.stdout.isatty():raise ValueError('alleen zichtbaar standaard macOS Terminal-venster')
  subprocess.run(['/usr/bin/sudo','-v'],check=True)
  # Full SQL comparisons and table checks can outlast sudo's normal cache.
  # Keep the already visibly authenticated session valid; never prompt hidden.
  done=threading.Event()
  def renew():
   while not done.wait(30):
    try:
     result=subprocess.run(['/usr/bin/sudo','-n','-v'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=15)
     if result.returncode:print('AANDACHT|sudo-sessie-kon-niet-worden-verlengd',flush=True);return
    except (OSError,subprocess.TimeoutExpired):return
  keeper=threading.Thread(target=renew,daemon=True);keeper.start()
  try:
   if a.recover_installed:recover(op)
   else:transaction(op)
  finally:done.set();keeper.join(timeout=20)
 finally:op.cleanup()
if __name__=='__main__':
 for signum in [signal.SIGINT,signal.SIGTERM,signal.SIGHUP]:signal.signal(signum,lambda n,f:(_ for _ in ()).throw(SystemExit(128+n)))
 try:main()
 except Exception as exc:print('BLOKKADE|imac974|'+str(exc),file=sys.stderr);sys.exit(1)
