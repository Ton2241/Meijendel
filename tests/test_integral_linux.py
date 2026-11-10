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
class ShinyMountRegression(unittest.TestCase):
 def test_nested_cache_target_exists_before_docker_mounts_readonly_parent(self):
  from unittest.mock import patch
  from types import SimpleNamespace
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);package=root/'package';(package/'shiny/shiny_meijendel').mkdir(parents=True)
   (package/'cache.rds').write_text('cache');(root/'runtime').mkdir()
   s=linux.layout('a'*40,True);s.update(root=str(root),shiny_uid=1,shiny_gid=1,shiny_image='sha256:'+'b'*64)
   h=object.__new__(linux.LinuxHooks);h.s=s;h.runtime=root/'runtime';h.p=s['ports'];h.private=root;h.trial_address=lambda name:'172.29.0.3'
   def logged(args,**kw):
    if args[:2]==['docker','run']:
     self.assertTrue((package/'shiny/shiny_meijendel/app_cache').is_dir(),'Docker needs the nested mountpoint before the parent bind becomes read-only')
   h.logged=logged
   with patch.object(linux.subprocess,'run',return_value=SimpleNamespace(returncode=1)),patch.object(linux.os,'chown'),patch.object(linux,'secret_json'):
    h.start_shiny(package,{'cache':{'root':'cache.rds'},'mysql':{'source':'data/meijendel.sql'}})
 def test_trial_website_uses_host_reachable_internal_mysql_address(self):
  from unittest.mock import patch
  from types import SimpleNamespace
  s=linux.layout('a'*40,True);s['website_env']={'DATABASE_URL':'postgresql:///vwg_integral_'+('a'*12)}
  h=linux.LinuxHooks(s)
  item={'Config':{'Labels':{'vwgm.integral.commit':'a'*40}},'NetworkSettings':{'Networks':{s['network']:{'IPAddress':'172.29.0.2'}}}}
  with patch.object(linux,'inspect_container',return_value=item),patch.object(linux,'secret_json'),patch('socket.create_connection',return_value=SimpleNamespace(close=lambda:None)):
   h.bind_trial_mysql()
  self.assertEqual(s['website_env']['MEIJENDEL_MYSQL_HOST'],'172.29.0.2')
  self.assertEqual(s['website_env']['MEIJENDEL_MYSQL_PORT'],'3306')
class InternalShinyBinding(unittest.TestCase):
 def test_shiny_health_uses_internal_container_endpoint(self):
  s=linux.layout('a'*40,True);s['shiny_upstream']='172.29.0.3:3838';h=linux.LinuxHooks(s)
  self.assertEqual(h.shiny_url(),'http://172.29.0.3:3838/')
 def test_trial_caddy_uses_same_internal_endpoint_and_keeps_auth(self):
  source=Path('/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app/deploy/caddy/Caddyfile.production').read_text()
  config=linux.caddy_config(source,trial=True,shiny_upstream='172.29.0.3:3838')
  self.assertIn('reverse_proxy 172.29.0.3:3838',config)
  self.assertIn('/auth/analysis-shiny',config)
  self.assertNotIn('127.0.0.1:18198',config)
class InitialTrialResumeGuard(unittest.TestCase):
 def test_resume_rejects_trial_that_already_started_activation(self):
  from unittest.mock import Mock
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);(root/'journal.json').write_text('{}');h=Mock();h.root=root
   with self.assertRaisesRegex(ValueError,'activering'):
    linux.check_initial_baseline(h,root/'A',root/'B',{'source_hash':'x','year_to':2025})
   h.import_mysql.assert_not_called()
 def test_complete_initial_baseline_can_be_reused_without_import(self):
  from unittest.mock import Mock,patch
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);a=root/'A';b=root/'B';private=root/'private';private.mkdir();data=root/'data';data.mkdir()
   (root/'trial.marker').write_text('a'*40);(private/'ownership.json').write_text('{"database":true}');(data/'_integral_release_probe').write_text('A')
   h=Mock();h.root=root;h.private=private;h.s={'commit':'a'*40,'website_data':str(data)};h.sql.side_effect=['A','2025'];h.pgsql.return_value='A'
   m={'source_hash':'x','year_from':1958,'year_to':2025}
   stored=lambda path:m|{'release_id':path.name,'mode':'local_rehearsal'}
   with patch.object(linux.core,'current',return_value=a),patch.object(linux.core,'verify',side_effect=stored):linux.check_initial_baseline(h,a,b,m)
   h.import_mysql.assert_not_called();h.restore_pg.assert_not_called()
 def test_database_change_blocks_initial_baseline_reuse(self):
  from unittest.mock import Mock,patch
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);a=root/'A';b=root/'B';private=root/'private';private.mkdir()
   (root/'trial.marker').write_text('a'*40);(private/'ownership.json').write_text('{"database":true}')
   h=Mock();h.root=root;h.private=private;h.s={'commit':'a'*40};h.sql.return_value='B'
   m={'source_hash':'x','year_from':1958,'year_to':2025}
   with patch.object(linux.core,'current',return_value=a),patch.object(linux.core,'verify',side_effect=lambda path:m|{'release_id':path.name,'mode':'local_rehearsal'}):
    with self.assertRaisesRegex(ValueError,'beginversie A'):linux.check_initial_baseline(h,a,b,m)
   h.import_mysql.assert_not_called()
if __name__=='__main__':unittest.main()
