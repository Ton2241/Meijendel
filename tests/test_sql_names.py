"""SQL name contract; all fixtures local, never call MySQL/SSH."""
import importlib.util,json,os,subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def load(name,path):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
core=load('sql_core',ROOT/'deploy/integral_release.py')
linux=load('sql_linux',ROOT/'deploy/integral_release_linux.py')
class SqlNames(unittest.TestCase):
 def recipe(self,p):
  repo=p/'repo';site=p/'site/website/vwg-m-linux-app';boot=p/'boot';frozen=p/'frozen'
  for d in [repo/'shiny_meijendel',repo/'R',site/'app',site/'sql',site/'scripts',boot,frozen]:
   d.mkdir(parents=True,exist_ok=True)
  for n in ['trim','trim_msi_evg','groepen_grafieken','wintertellingen','output_ecologische_groepen']:(repo/n).mkdir()
  for n in ['bmp_meijendel_index.html','bmp_meijendel_data_loader.js']:(repo/n).write_text('fixture')
  (repo/'shiny_meijendel/app.R').write_text('fixture');(site/'app/main.py').write_text('fixture')
  for n in ['requirements.txt','requirements.lock','requirements-bootstrap.lock']:(site/n).write_text('')
  for n in ['bmp_meijendel_data.json','bmp_meijendel_data.json.manifest']:(frozen/n).write_text('{}')
  sql=p/'meijendel.sql';sql.write_text('CREATE TABLE voorbeeld(id int);\n')
  for n in ['meijendel.sql.manifest','cache.rds','cache.manifest','objects.sql']:(p/n).write_text('fixture')
  (boot/'bootstrap.html').write_text('fixture')
  (boot/'manifest.json').write_text(json.dumps(dict(year_from=1958,year_to=2025,source_hash=core.sha(sql),html_sha256=core.sha(boot/'bootstrap.html'))))
  return dict(analysis_root=str(repo),website_root=str(site.parents[1]),browser_root=str(frozen),bootstrap_root=str(boot),sql=str(sql),sql_manifest=str(p/'meijendel.sql.manifest'),cache=str(p/'cache.rds'),cache_manifest=str(p/'cache.manifest'),website_objects=str(p/'objects.sql'),year_from=1958,year_to=2025,mode='local_rehearsal',release_id='case-test')
 def test_new_package_has_only_lowercase_sql_and_linux_accepts_it(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d);r=self.recipe(p);target=p/'package';m=core.build_package(r,target)
   self.assertEqual(m['mysql']['source'],'data/meijendel.sql')
   self.assertEqual({x.name for x in (target/'data').glob('*.sql*')},{'meijendel.sql','meijendel.sql.manifest','website_objects.sql'})
   linux.guard_payload(m);self.assertEqual(core.verify(target)['source_hash'],core.sha(p/'meijendel.sql'))
 def test_linux_accepts_lowercase_and_preserved_legacy_packages(self):
  for name in ['meijendel.sql','Meijendel.sql']:
   source='data/'+name
   m=dict(components=['website','dashboard','shiny','mysql','cms'],mysql=dict(source=source,website_objects='data/website_objects.sql',database='Meijendel'),cache=dict(root='data/cache/a.rds'),bootstrap=dict(root='www/outputs/bootstrap-presentatie-2026'),files={x:'a'*64 for x in [source,source+'.manifest','data/cache/a.rds','data/cache/a.manifest','website/app/main.py','shiny/shiny_meijendel/app.R','www/bmp_meijendel_index.html']})
   with self.subTest(name=name):linux.guard_payload(m)
   other='data/Meijendel.sql' if name=='meijendel.sql' else 'data/meijendel.sql'
   m['files'][other]='b'*64
   with self.assertRaises(ValueError):linux.guard_payload(m)
 def shell(self,root,code):
  command='source "$1"; REMOTE_BASE="$2"; REMOTE_DATA="$2/data"; REMOTE_SHINY="$2/shiny"; REMOTE_WWW="$2/www"; REMOTE_APP="$2/app"; APP_CACHE="$2/cache"; SQL_FILE="$REMOTE_DATA/meijendel.sql"; SQL_MANIFEST_FILE="$SQL_FILE.manifest"; rollback_sql="$2/old.sql"; rollback_sql_manifest="$2/old.manifest"; '+code
  # Fail closed if sourcing unexpectedly tries any real database operation.
  env=os.environ|{'PATH':str(root/'bin')+':/usr/bin:/bin'}
  return subprocess.run(['bash','-c',command,'test',str(ROOT/'deploy/deploy_meijendel_release_vps_remote.sh'),str(root)],env=env,capture_output=True,text=True)
 def test_vps_path_transition_and_file_rollback_for_both_existing_names(self):
  for name in ['meijendel.sql','Meijendel.sql']:
   with self.subTest(name=name),tempfile.TemporaryDirectory() as d:
    p=Path(d)
    for n in ['bin','data','shiny','www','app/data','cache']:(p/n).mkdir(parents=True,exist_ok=True)
    for n in ['docker','ssh','sudo']:
     f=p/'bin'/n;f.write_text('#!/bin/sh\necho UNEXPECTED_EXTERNAL_OPERATION >&2\nexit 97\n');f.chmod(0o755)
    original=p/'data'/name;original.write_text('old');Path(str(original)+'.manifest').write_text('old-manifest')
    result=self.shell(p,'select_active_sql_paths; preserve_previous_sql; printf new > "$SQL_FILE"; printf new-manifest > "$SQL_MANIFEST_FILE"; publish_sql_links "$SQL_FILE" "$SQL_MANIFEST_FILE"; activation_started=1; first_cache_migration=0; had_cache_manifest=0; rollback_uses_candidate_cache=0; cache_file=""; restore_files')
    self.assertEqual(result.returncode,0,result.stderr)
    self.assertEqual(original.read_text(),'old');self.assertEqual(Path(str(original)+'.manifest').read_text(),'old-manifest')
    self.assertEqual((p/'www/meijendel.sql').read_text(),'old')
    self.assertEqual((p/'shiny/Meijendel.sql').read_text(),'old')
 def test_vps_version_guard_agrees_with_current_export_contract(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)
   result=self.shell(p,'validate_mysql_release_version 9.7.4')
   self.assertEqual(result.returncode,0,result.stderr)
   result=self.shell(p,'validate_mysql_release_version 9.7.1')
   self.assertNotEqual(result.returncode,0)
   self.assertIn('9.7.4',result.stderr)
 def test_dashboard_reads_manifest_for_both_sql_spellings(self):
  import socket,time,urllib.request,sys
  for name in ['meijendel.sql','Meijendel.sql']:
   with self.subTest(name=name),tempfile.TemporaryDirectory() as d:
    p=Path(d);r=self.recipe(p);package=p/'releases/case-test'
    m=core.build_package(r,package)
    if name!='meijendel.sql':
     for suffix in ['', '.manifest']:
      old='data/meijendel.sql'+suffix;new='data/'+name+suffix
      (package/old).rename(package/new);m['files'][new]=m['files'].pop(old)
     m['mysql']['source']='data/'+name;core.atomic_json(package/'release.json',m)
    core.verify(package);core.set_current(p,package)
    with socket.socket() as sock:
     sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
    command='import runpy,sys; from pathlib import Path; n=runpy.run_path(sys.argv[1]); n["dashboard"](Path(sys.argv[2]),int(sys.argv[3]))'
    child=subprocess.Popen([sys.executable,'-c',command,str(ROOT/'deploy/integral_release_linux.py'),str(p),str(port)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    try:
     for _ in range(60):
      try:
       with urllib.request.urlopen('http://127.0.0.1:'+str(port)+'/meijendel.sql',timeout=.2) as response:body=response.read()
       break
      except OSError:time.sleep(.05)
     else:self.fail('Lokale fixture-dashboard start niet')
     self.assertEqual(body,(p/'meijendel.sql').read_bytes())
     with urllib.request.urlopen('http://127.0.0.1:'+str(port)+'/Meijendel.sql',timeout=1) as response:self.assertEqual(response.read(),body)
    finally:
     child.terminate()
     try:child.wait(timeout=5)
     except subprocess.TimeoutExpired:child.kill();child.wait()

 def test_r_hash_accepts_sql_path_with_spaces(self):
  import shutil
  binary=shutil.which('Rscript')
  if not binary:self.skipTest('Rscript ontbreekt')
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'with space';p.mkdir();sql=p/'meijendel.sql';sql.write_text('SQL fixture')
   result=subprocess.run([binary,'--vanilla','-e','a<-commandArgs(TRUE);source(a[[1]]);cat(sha256_file(a[[2]]))',str(ROOT/'shiny_meijendel/helpers.R'),str(sql)],capture_output=True,text=True)
   self.assertEqual(result.returncode,0,result.stderr);self.assertEqual(result.stdout.strip(),core.sha(sql))

if __name__=='__main__':unittest.main()
