import importlib.util,unittest,tempfile,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('linux',ROOT/'deploy/integral_release_linux.py');linux=importlib.util.module_from_spec(spec);spec.loader.exec_module(linux)
class LinuxContract(unittest.TestCase):
 def test_trial_layout_has_only_private_names_and_loopback_ports(self):
  layout=linux.layout('a'*40,trial=True)
  self.assertTrue(layout['database'].startswith('vwg_integral_'))
  self.assertNotIn(layout['mysql'],('meijendel-mysql','shiny_meijendel'))
  self.assertEqual(layout['ports'],{'mysql':33317,'website':18197,'dashboard':18196,'shiny':18198,'caddy':18199})
 def test_invalid_commit_and_hash_rejected(self):
  for value in ['../etc','a'*39,'main','a'*40+';id']:
   with self.assertRaises(ValueError):linux.layout(value,trial=True)
 def test_caddy_binding_preserves_auth_and_replaces_only_asset_roots(self):
  source=(Path('/Users/ton/Documents/GitHub/_worktrees/VWG_M/bootstrap-presentatie-2026')/'website/vwg-m-linux-app/deploy/caddy/Caddyfile.production').read_text()
  config=linux.caddy_config(source,trial=True)
  self.assertIn('forward_auth 127.0.0.1:18197',config)
  self.assertIn('/auth/analysis-dashboard',config)
  self.assertIn('/auth/analysis-shiny',config)
  self.assertIn('reverse_proxy 127.0.0.1:18196',config)
  self.assertIn('http://127.0.0.1:18199',config)
  self.assertNotIn('/var/log/caddy',config)
 def test_trial_cannot_take_production_layout(self):
  values=linux.layout('b'*40,trial=True);values['mysql']='meijendel-mysql'
  with self.assertRaises(ValueError):linux.guard_trial_layout(values)
 def test_missing_production_owned_objects_never_means_dump_entire_database(self):
  with self.assertRaises(ValueError):linux.owned_objects([])
  self.assertEqual(set(linux.owned_objects(linux.OBJECTS)),set(linux.OBJECTS))
 def test_archive_cannot_install_symlinks_or_parent_paths(self):
  import tarfile,io
  for name,kind in [('../outside','file'),('payload/link','link')]:
   with tempfile.TemporaryDirectory() as d:
    root=Path(d);archive=root/'bad.tar.gz'
    with tarfile.open(archive,'w:gz') as out:
     item=tarfile.TarInfo(name)
     if kind=='link':item.type=tarfile.SYMTYPE;item.linkname='/etc/passwd';out.addfile(item)
     else:item.size=1;out.addfile(item,io.BytesIO(b'x'))
    with self.assertRaises(ValueError):linux.safe_extract(archive,root/'target')
    self.assertFalse((root/'outside').exists())
 def test_docker_env_preserves_literal_password(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'docker.env';linux.write_env(p,{'PASSWORD':'a $b " c'},systemd=False)
   self.assertEqual(p.read_text(),'PASSWORD=a $b " c\n')
 def test_user_payload_never_selects_legacy_or_host_paths(self):
  for m in [{'legacy':True},{'mysql':{'source':'/etc/shadow'}}]:
   with self.assertRaises(ValueError):linux.guard_payload(m)
 def test_managed_runtime_is_outside_user_owned_srv_tree(self):
  self.assertTrue(linux.layout('c'*40,True)['root'].startswith('/var/lib/vwgm-integral/'))
 def test_migration_must_match_root_installed_catalogue(self):
  catalogue={'sql/123_example.sql':'a'*64}
  linux.approved_migration('sql/123_example.sql','a'*64,catalogue)
  for name,digest in [('sql/123_example.sql','b'*64),('sql/999_arbitrary.sql','a'*64),('/etc/passwd','a'*64)]:
   with self.assertRaises(ValueError):linux.approved_migration(name,digest,catalogue)
class RecoveryContract(unittest.TestCase):
 def test_second_stop_preserves_initial_timer_set(self):
  from unittest.mock import patch
  from types import SimpleNamespace
  h=linux.LinuxHooks(linux.layout('a'*40,False));h.logged=lambda *a,**k:None
  replies=iter(['','vwg-m-backup.timer loaded active waiting','', ''])
  with patch.object(linux,'run',side_effect=lambda *a,**k:SimpleNamespace(stdout=next(replies))):
   h.stop_production_writers();h.stop_production_writers()
  self.assertEqual(h.timers,['vwg-m-backup.timer'])
 def test_rollback_expects_just_applied_commits(self):
  old={'Meijendel':'a'*40,'VWG_M':'b'*40};new={'Meijendel':'c'*40,'VWG_M':'d'*40,'VWG_Project':'e'*40}
  self.assertEqual(linux.phase_commits('apply',{'production_commits':old},{'commits':new}),old)
  self.assertEqual(linux.phase_commits('rollback',{'production_commits':old},{'commits':new}),{k:new[k] for k in old})
if __name__=='__main__':unittest.main()
