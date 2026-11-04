import importlib.util,unittest,tempfile,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('release',ROOT/'deploy/integral_release.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class IntegralReleaseTests(unittest.TestCase):
 def candidate(self,root,name):
  p=root/'releases'/name;(p/'www').mkdir(parents=True)
  (p/'www/index.html').write_text(name)
  meta=dict(schema='meijendel-integral-release-v1',release_id=name,mode='local_rehearsal',year_from=1958,year_to=2025,source_hash='a'*64,presentation_approved=True,files={'www/index.html':hashlib.sha256(name.encode()).hexdigest()})
  (p/'release.json').write_text(json.dumps(meta));return p
 def test_activation_and_failed_health_restore_same_database_and_version(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);a=self.candidate(root,'A');b=self.candidate(root,'B');calls=[]
   class Hooks:
    value='A'
    def snapshot(s,path):path.mkdir();(path/'db.txt').write_text(s.value)
    def stop(s):calls.append('stop')
    def apply(s,p):s.value=p.name;calls.append('apply:'+p.name)
    def restore(s,p):s.value=(p/'db.txt').read_text();calls.append('restore:'+s.value)
    def start(s,p):calls.append('start:'+p.name)
    def health(s,p):
     if p.name=='B':raise RuntimeError('opzettelijke dienstfout')
   hooks=Hooks();m.set_current(root,a)
   with self.assertRaises(RuntimeError):m.activate(root,b,hooks)
   self.assertEqual((root/'current').resolve(),a.resolve())
   self.assertEqual(hooks.value,'A');self.assertIn('restore:A',calls)
 def test_successful_activation_and_explicit_rollback(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);a=self.candidate(root,'A');b=self.candidate(root,'B')
   class Hooks:
    value='A'
    def snapshot(s,path):path.mkdir();(path/'db.txt').write_text(s.value)
    def stop(s):pass
    def apply(s,p):s.value=p.name
    def restore(s,p):s.value=(p/'db.txt').read_text()
    def start(s,p):pass
    def health(s,p):assert s.value==p.name
   h=Hooks();m.set_current(root,a);m.activate(root,b,h)
   self.assertEqual(h.value,'B');m.rollback(root,h)
   self.assertEqual(h.value,'A');self.assertEqual(m.current(root),a.resolve())
 def test_failed_snapshot_restarts_original_without_partial_restore(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);a=self.candidate(root,'A');b=self.candidate(root,'B');calls=[]
   class Hooks:
    def stop(s):calls.append('stop')
    def snapshot(s,p):raise RuntimeError('backup failed')
    def restore(s,p):self.fail('partial backup must not be restored')
    def start(s,p):calls.append('start:'+p.name)
    def health(s,p):calls.append('health:'+p.name)
   m.set_current(root,a)
   with self.assertRaises(RuntimeError):m.activate(root,b,Hooks())
   self.assertEqual(calls,['stop','stop','start:A','health:A'])
 def test_symlink_inside_package_is_rejected(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);a=self.candidate(root,'A');(a/'www/alias').symlink_to('index.html')
   with self.assertRaises(ValueError):m.safe_path(a,'www/alias')
 def test_production_rejects_historical_cache(self):
  with tempfile.TemporaryDirectory() as d:
   p=self.candidate(Path(d),'A');v=json.loads((p/'release.json').read_text());v.update(mode='production',official_data_validated=True,components=['website','dashboard','shiny','mysql','cms'],historical_cache_rehearsal=True);(p/'release.json').write_text(json.dumps(v))
   with self.assertRaisesRegex(ValueError,'Proefonderdeel'):m.verify(p)
 def test_first_failed_activation_removes_current(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);a=self.candidate(root,'A');calls=[]
   class Hooks:
    def stop(s):pass
    def snapshot(s,p):p.mkdir()
    def apply(s,p):pass
    def start(s,p):pass
    def health(s,p):raise RuntimeError('first failed')
    def restore(s,p):calls.append('restored')
   with self.assertRaises(RuntimeError):m.activate(root,a,Hooks())
   self.assertIsNone(m.current(root));self.assertEqual(calls,['restored'])
 def test_recovery_failure_is_recorded_and_services_stopped(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);a=self.candidate(root,'A');b=self.candidate(root,'B');calls=[]
   class Hooks:
    def stop(s):calls.append('stop')
    def snapshot(s,p):p.mkdir()
    def apply(s,p):raise RuntimeError('apply failure')
    def restore(s,p):raise RuntimeError('restore failure')
   m.set_current(root,a)
   with self.assertRaisesRegex(RuntimeError,'Activering en herstel mislukt'):m.activate(root,b,Hooks())
   journal=json.loads((root/'journal.json').read_text())
   self.assertEqual(journal['phase'],'recovery_failed');self.assertEqual(journal['error'],'apply failure');self.assertEqual(journal['recovery_error'],'restore failure');self.assertEqual(calls[-1],'stop')
 def test_rollback_snapshot_and_restart_failure_stops_services(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);a=self.candidate(root,'A');b=self.candidate(root,'B');backup=root/'backups/original';backup.mkdir(parents=True);calls=[]
   m.set_current(root,b);m.atomic_json(root/'last_backup.json',{'package':str(a),'backup':str(backup)})
   class Hooks:
    def stop(s):calls.append('stop')
    def snapshot(s,p):raise RuntimeError('snapshot failed')
    def start(s,p):calls.append('partial start')
    def health(s,p):raise RuntimeError('restart failed')
   with self.assertRaisesRegex(RuntimeError,'Herstart na backupfout mislukt'):m.rollback(root,Hooks())
   journal=json.loads((root/'journal.json').read_text());self.assertEqual(journal['phase'],'recovery_failed');self.assertEqual(journal['error'],'snapshot failed');self.assertEqual(journal['recovery_error'],'restart failed');self.assertEqual(calls[-1],'stop')
 def test_checksum_rejection_does_not_stop_services(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);p=self.candidate(root,'A');(p/'www/index.html').write_text('wrong')
   with self.assertRaises(ValueError):m.verify(p)
 def test_path_escape_rejected(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)
   with self.assertRaises(ValueError):m.safe_path(p,'../outside')
if __name__=='__main__':unittest.main()
