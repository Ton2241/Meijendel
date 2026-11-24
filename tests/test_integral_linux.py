import importlib.util,unittest,tempfile,json,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('linux',ROOT/'deploy/integral_release_linux.py');linux=importlib.util.module_from_spec(spec);spec.loader.exec_module(linux)
class LinuxContract(unittest.TestCase):
 def test_queued_apply_checks_preflight_before_claiming_approval(self):
  launcher=(ROOT/'deploy/integral_release_linux.py').read_text()
  freeze=launcher.index("base,receipt,m=freeze(a.commit")
  authorization=launcher.index("queue_check('authorize',a.sha256)",freeze)
  self.assertLess(freeze,authorization)
  self.assertLess(launcher.index("check_production_release(a.stage,base,receipt,m)",freeze),authorization)
 def test_finalization_routes_require_queue_authorization_before_returning(self):
  launcher=(ROOT/'deploy/integral_release_linux.py').read_text()
  authorization=launcher.index("queue_check('authorize',a.sha256)",launcher.index("with global_lock()"))
  finalization=launcher.index("if a.stage in ('finalize-plan','finalize','adopt-finalization')")
  self.assertLess(authorization,finalization)
  self.assertLess(launcher.index("queue_check('require-active',a.sha256)",authorization),finalization)
 def test_trial_layout_has_only_private_names_and_loopback_ports(self):
  layout=linux.layout('a'*40,trial=True)
  self.assertTrue(layout['database'].startswith('vwg_integral_'))
  self.assertNotIn(layout['mysql'],('meijendel-mysql','shiny_meijendel'))
  self.assertEqual(layout['ports'],{'mysql':33317,'website':18197,'dashboard':18196,'shiny':18198,'caddy':18199})
 def test_invalid_commit_and_hash_rejected(self):
  for value in ['../etc','a'*39,'main','a'*40+';id']:
   with self.assertRaises(ValueError):linux.layout(value,trial=True)
 def test_caddy_binding_preserves_auth_and_replaces_only_asset_roots(self):
  website=Path(os.environ.get('VWG_M_ROOT',ROOT.parent/'VWG_M'))
  source=(website/'website/vwg-m-linux-app/deploy/caddy/Caddyfile.production').read_text()
  config=linux.caddy_config(source,trial=True)
  self.assertIn('forward_auth 127.0.0.1:18197',config)
  self.assertIn('/auth/analysis-dashboard',config)
  self.assertIn('/auth/analysis-shiny',config)
  self.assertIn('/outputs/aantalsindex-preview/*',config)
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
class ManagedReceiveContract(unittest.TestCase):
 def test_receive_checks_signed_approval_before_reading(self):
  from unittest.mock import Mock,patch
  source=Mock()
  with patch.object(linux,'queue_check',side_effect=ValueError('Geen akkoord')):
   with self.assertRaisesRegex(ValueError,'Geen akkoord'):
    linux.receive_release('a'*40,'b'*64,10,source)
  source.read.assert_not_called()
 def test_stream_requires_exact_size_and_hash(self):
  import hashlib,io
  data=b'Meijendel T7'
  digest=hashlib.sha256(data).hexdigest()
  with tempfile.TemporaryDirectory() as d:
   path=Path(d)/'package'
   linux.receive_archive(path,len(data),digest,io.BytesIO(data))
   self.assertEqual(path.read_bytes(),data)
   for received,size,expected in [(data[:-1],len(data),digest),(data+b'x',len(data),digest),(data,len(data),'0'*64)]:
    path.unlink()
    with self.assertRaises(ValueError):
     linux.receive_archive(path,size,expected,io.BytesIO(received))
 def test_active_policy_only_accepts_private_receive_stage(self):
  from unittest.mock import patch
  with tempfile.TemporaryDirectory() as d, patch.object(linux,'QUEUE_POLICY',Path(d)/'active'):
   with self.assertRaises(FileNotFoundError):
    linux.queue_stage('receive-queued')
   linux.QUEUE_POLICY.touch()
   with patch.object(linux,'secure_file'):
    self.assertEqual(linux.queue_stage('receive-queued'),('receive',True))
    with self.assertRaises(ValueError):
     linux.queue_stage('receive')

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

class CompressedRollback(unittest.TestCase):
 def test_existing_backup_can_be_compressed_without_changing_its_sql_identity(self):
  import gzip,hashlib
  with tempfile.TemporaryDirectory() as d:
   path=Path(d)
   contents=b'INSERT INTO voorbeeld VALUES (1);\n'*100
   raw=path/'mysql.sql';raw.write_bytes(contents)
   digest=hashlib.sha256(contents).hexdigest()
   manifest={'files':{'mysql.sql':digest},'other':'preserved'}
   (path/'backup.json').write_text(json.dumps(manifest))
   self.assertEqual(linux.mysql_backup_source(path,manifest),raw)
   final=linux.compress_mysql_backup(path)
   saved=json.loads((path/'backup.json').read_text())
   self.assertFalse(raw.exists())
   self.assertEqual(saved['other'],'preserved')
   self.assertEqual(saved['mysql_sql_sha256'],digest)
   self.assertEqual(final,path/'mysql.sql.gz')
   self.assertEqual(gzip.decompress(final.read_bytes()),contents)
   self.assertEqual(linux.mysql_backup_source(path,saved),final)
   self.assertEqual(linux.compress_mysql_backup(path),final)
 def test_wrong_compressed_payload_is_rejected_before_destructive_import(self):
  import gzip
  from unittest.mock import Mock
  with tempfile.TemporaryDirectory() as d:
   path=Path(d)
   source=path/'mysql.sql.gz';source.write_bytes(gzip.compress(b'wrong'))
   m={'files':{'mysql.sql.gz':linux.core.sha(source)},'mysql_sql_sha256':'a'*64}
   (path/'backup.json').write_text(json.dumps(m))
   hook=object.__new__(linux.LinuxHooks); hook.import_mysql=Mock()
   with self.assertRaisesRegex(ValueError,'SQL'):
    hook.restore(path)
   hook.import_mysql.assert_not_called()
 def test_conversion_keeps_raw_on_failed_manifest_write(self):
  from unittest.mock import patch
  with tempfile.TemporaryDirectory() as d:
   path=Path(d); raw=path/'mysql.sql'; raw.write_bytes(b'keep me')
   m={'files':{'mysql.sql':linux.core.sha(raw)}}
   (path/'backup.json').write_text(json.dumps(m))
   with patch.object(linux,'secret_json',side_effect=OSError('write failed')):
    with self.assertRaises(OSError):linux.compress_mysql_backup(path)
   self.assertEqual(raw.read_bytes(),b'keep me')
   self.assertEqual(json.loads((path/'backup.json').read_text()),m)
   self.assertEqual(linux.compress_mysql_backup(path),path/'mysql.sql.gz')

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
class CaddyReadiness(unittest.TestCase):
 def test_generated_auth_block_uses_parser_supported_newlines(self):
  source=Path('/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app/deploy/caddy/Caddyfile.production').read_text()
  config=linux.caddy_config(source,True,shiny_upstream='172.29.0.3:3838')
  self.assertNotIn('{ uri ',config)
 def test_readiness_wait_includes_caddy_and_retries_connection_refusal(self):
  from unittest.mock import patch
  h=linux.LinuxHooks(linux.layout('a'*40,True));h.s['shiny_upstream']='172.29.0.3:3838';calls=[]
  def get(url):
   calls.append(url)
   if ':18199/' in url and calls.count(url)==1:raise ConnectionRefusedError('starting')
   return b'ok',200,url
  h.get=get
  with patch.object(linux.time,'sleep'):h.wait_services()
  self.assertEqual(calls.count('http://127.0.0.1:18199/'),2)
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


class QueueLockContract(unittest.TestCase):
 def test_unconfirmed_mutation_retains_shared_host_lock(self):
  from unittest.mock import patch
  with tempfile.TemporaryDirectory() as d:
   state=Path(d);lock=state/'production.lock'
   with patch.object(linux,'STATE',state):
    with self.assertRaises(RuntimeError):
     with linux.global_lock() as start_mutation:
      start_mutation()
      raise RuntimeError('onbevestigde activering')
    self.assertTrue(lock.is_dir())
    with self.assertRaises(FileExistsError):
     with linux.global_lock():
      self.fail('Een tweede eigenaar kreeg de lock')

 def test_lock_releases_after_preflight_rejection_or_green_mutation(self):
  from unittest.mock import patch
  with tempfile.TemporaryDirectory() as d:
   state=Path(d);lock=state/'production.lock'
   with patch.object(linux,'STATE',state):
    with self.assertRaises(ValueError):
     with linux.global_lock():
      raise ValueError('kandidaat geweigerd vóór mutatie')
    self.assertFalse(lock.exists())
    with linux.global_lock() as start_mutation:
     start_mutation()
     self.assertTrue(lock.is_dir())
    self.assertFalse(lock.exists())

 def test_queued_operation_never_falls_back_to_legacy(self):
  from unittest.mock import patch
  with tempfile.TemporaryDirectory() as d:
   marker=Path(d)/'vps-queue-required'
   with patch.object(linux,'QUEUE_POLICY',marker), patch.object(linux,'secure_file') as secure:
    self.assertEqual(linux.queue_stage('apply'),('apply',False))
    marker.touch()
    with self.assertRaisesRegex(ValueError,'begrensde'):
     linux.queue_stage('apply')
    self.assertEqual(linux.queue_stage('apply-queued'),('apply',True))
    secure.assert_called_once_with(marker)


class ReleaseFinalizationContract(unittest.TestCase):
 def identity(self,name,digest):
  return {'release_id':name,'package_digest':digest,
          'commits':{'Meijendel':'a'*40,'VWG_M':'b'*40}}

 def context(self):
  active=self.identity('release-B','b'*64)|{'path':'/control/production/releases/release-B'}
  previous=self.identity('release-A','a'*64)|{'path':'/control/production/releases/release-A'}
  old=self.identity('release-old','c'*64)|{'path':'/control/production/releases/release-old'}
  return {
   'active':active,'previous':previous,
   'journal':{'phase':'active','previous':'release-A','attempted':'release-B','activated_at':'2026-11-22T20:00:00Z'},
   'health':{'release_id':'release-B','three_services':True,'shiny_cache_and_bootstrap':True},
   'sealed_packages':[
    active|{'path':'/control/packages/'+'b'*64,'bytes':100,'fingerprint':[1,2]},
    previous|{'path':'/control/packages/'+'a'*64,'bytes':200,'fingerprint':[1,3]},
    old|{'path':'/control/packages/'+'c'*64,'bytes':300,'fingerprint':[1,4]},
   ],
   'releases':[active|{'bytes':400,'fingerprint':[1,5]},previous|{'bytes':500,'fingerprint':[1,6]},old|{'bytes':600,'fingerprint':[1,7]}],
   'staging':[{'path':'/control/packages/.receive-old','bytes':50,'fingerprint':[1,8]}],
   'inbox':[{'path':'/state/integral-inbox/old.tar.gz','digest':'c'*64,'bytes':25,'fingerprint':[1,9]}],
   'free_bytes':40*linux.GIB,
  }

 def proof(self):
  release={'release_id':'release-B','package_digest':'b'*64,
           'meijendel_commit':'a'*40,'vwg_m_commit':'b'*40}
  return {'chain_date':'2026-11-23','proof_created_at':'2026-11-23T04:15:00Z',
          'pull_proof':{'release':release,
                        'backup':{'created_at':'2026-11-23T00:15:00Z'}}}

 def inventory(self):
  return {'containers':[{'name':'meijendel-mysql','image':'sha256:'+'d'*64,
                         'mount_sources':['/control/production/runtime']}],
          'queue_identity':None,'host_mount_sources':[],
          'build_cache':[{'ID':'cacheold123','Reclaimable':True,'Mutable':False,
                          'Shared':False,'Size':'700','UsageCount':0,'Parents':[],
                          'CreatedAt':'2026-11-20T00:00:00Z','LastUsedAt':'2026-11-20T00:00:00Z',
                          'Description':'old release build','Type':'regular'}]}

 def test_plan_matches_proof_health_and_keeps_current_plus_one_previous(self):
  plan=linux.build_finalization_plan(self.context(),self.proof(),self.inventory())
  removed={(item['kind'],item.get('path',item.get('id'))) for item in plan['objects']}
  self.assertEqual(removed,{('sealed_package','/control/packages/'+'c'*64),
                            ('release','/control/production/releases/release-old'),
                            ('staging','/control/packages/.receive-old'),
                            ('inbox_archive','/state/integral-inbox/old.tar.gz'),
                            ('buildkit_cache','cacheold123')})
  self.assertEqual(plan['projected_free_bytes'],40*linux.GIB+1675)

 def test_mismatch_stale_proof_failed_health_or_nonactive_journal_blocks_all(self):
  for mutate in (
   lambda c,p,i:p['pull_proof']['release'].update(package_digest='0'*64),
   lambda c,p,i:p['pull_proof']['backup'].update(created_at='2026-11-22T19:00:00Z'),
   lambda c,p,i:c['health'].update(three_services=False),
   lambda c,p,i:c['journal'].update(phase='restored'),
  ):
   context=self.context();proof=self.proof();inventory=self.inventory();mutate(context,proof,inventory)
   with self.subTest(mutate=mutate),self.assertRaises(ValueError):
    linux.build_finalization_plan(context,proof,inventory)

 def test_active_mount_queue_reference_or_unknown_cache_schema_blocks_everything(self):
  context=self.context();inventory=self.inventory()
  inventory['containers'][0]['mount_sources'].append('/control/packages/'+'c'*64+'/payload')
  with self.assertRaisesRegex(ValueError,'actieve verwijzing'):
   linux.build_finalization_plan(context,self.proof(),inventory)
  inventory=self.inventory();inventory['queue_identity']='c'*64
  with self.assertRaisesRegex(ValueError,'wachtrij'):
   linux.build_finalization_plan(context,self.proof(),inventory)
  inventory=self.inventory();inventory['build_cache'][0]['Unexpected']=True
  with self.assertRaisesRegex(ValueError,'cache'):
   linux.build_finalization_plan(context,self.proof(),inventory)

 def test_candidate_nested_inside_active_mount_or_host_mount_is_blocked(self):
  context=self.context();inventory=self.inventory()
  inventory['containers'][0]['mount_sources']=['/control/packages']
  with self.assertRaisesRegex(ValueError,'actieve verwijzing'):
   linux.build_finalization_plan(context,self.proof(),inventory)
  inventory=self.inventory();inventory['host_mount_sources']=['/control/production/releases/release-old/data']
  with self.assertRaisesRegex(ValueError,'actieve verwijzing'):
   linux.build_finalization_plan(context,self.proof(),inventory)

 def test_direct_predecessor_from_journal_is_the_only_rollback_release(self):
  context=self.context()
  context['previous']=self.identity('release-direct','d'*64)|{'path':'/control/production/releases/release-direct'}
  context['releases'].append(context['previous']|{'bytes':10,'fingerprint':[1,10]})
  context['journal']['previous']='release-direct'
  plan=linux.build_finalization_plan(context,self.proof(),self.inventory())
  removed={item.get('path') for item in plan['objects']}
  self.assertNotIn('/control/production/releases/release-direct',removed)
  self.assertIn('/control/production/releases/release-A',removed)

 def test_apply_uses_exact_plan_and_targeted_buildkit_id_only(self):
  plan=linux.build_finalization_plan(self.context(),self.proof(),self.inventory())
  removed=[];commands=[]
  result=linux.apply_finalization_plan(
   plan,
   remove_path=lambda item:removed.append((item['kind'],item['path'])),
   command=lambda args:commands.append(args),
   free_bytes=lambda:41*linux.GIB,
  )
  self.assertEqual(len(removed),4)
  self.assertEqual(commands,[['docker','buildx','prune','--force','--filter','id=cacheold123','--filter','inuse=false']])
  self.assertEqual(result['free_bytes_after'],41*linux.GIB)

 def test_apply_records_each_completed_object_before_a_later_failure(self):
  plan=linux.build_finalization_plan(self.context(),self.proof(),self.inventory())
  progress=[]
  def remove(item):
   if progress:raise RuntimeError('second failed')
   progress.append(item['path'])
  with self.assertRaisesRegex(RuntimeError,'second failed'):
   linux.apply_finalization_plan(plan,remove_path=remove,command=lambda args:None,
                                 free_bytes=lambda:41*linux.GIB,record_progress=progress.append)
  self.assertEqual(progress[1]['path'],progress[0])

 def test_upload_gate_requires_completed_previous_release_and_36_gib_after_upload(self):
  active=self.identity('release-B','b'*64)
  complete={'schema':'vwgm-release-finalization-state-v1','status':'complete','release':active}
  linux.check_upload_admission(active,complete,'c'*64,40*linux.GIB,2*linux.GIB)
  with self.assertRaisesRegex(ValueError,'finalisatie'):
   linux.check_upload_admission(active,None,'c'*64,40*linux.GIB,2*linux.GIB)
  with self.assertRaisesRegex(RuntimeError,'36 GiB'):
   linux.check_upload_admission(active,complete,'c'*64,37*linux.GIB,2*linux.GIB)
  # An exact retry of the active package is not a new release.
  linux.check_upload_admission(active,None,'b'*64,36*linux.GIB,1)

 def test_adoption_is_explicit_and_idempotent_only_for_same_active_release(self):
  import json
  from datetime import datetime,timezone
  with tempfile.TemporaryDirectory() as d:
   path=Path(d)/'finalization.json';active=self.identity('release-B','b'*64)
   linux.adopt_finalization_state(path,active,'2026-11-22T20:00:00Z',now=datetime(2026,11,23,tzinfo=timezone.utc))
   saved=json.loads(path.read_text())
   self.assertEqual(saved['status'],'pending');self.assertTrue(saved['adopted'])
   linux.adopt_finalization_state(path,active,'2026-11-22T20:00:00Z',now=datetime(2026,11,23,tzinfo=timezone.utc))
   with self.assertRaisesRegex(ValueError,'andere release'):
    linux.adopt_finalization_state(path,self.identity('release-C','c'*64),'2026-11-23T20:00:00Z',now=datetime(2026,11,24,tzinfo=timezone.utc))

 def test_finalization_requires_matching_pending_state(self):
  active=self.identity('release-B','b'*64)
  pending={'schema':'vwgm-release-finalization-state-v1','status':'pending','release':active,
           'activated_at':'2026-11-22T20:00:00Z','adopted':True}
  self.assertTrue(linux.require_pending_finalization(pending,active,'2026-11-22T20:00:00Z'))
  for changed in (
   pending|{'status':'complete'},
   pending|{'release':self.identity('release-C','c'*64)},
   pending|{'activated_at':'2026-11-22T20:00:01Z'},
  ):
   with self.assertRaises(ValueError):
    linux.require_pending_finalization(changed,active,'2026-11-22T20:00:00Z')

 def test_applied_plan_requires_every_exact_object_to_be_absent(self):
  plan={'objects':[{'kind':'release','path':'/releases/old'},
                   {'kind':'buildkit_cache','id':'cache123'}]}
  linux.verify_finalization_result(plan,remaining_paths=set(),remaining_cache_ids=set())
  with self.assertRaises(RuntimeError):
   linux.verify_finalization_result(plan,remaining_paths={'/releases/old'},remaining_cache_ids=set())
  with self.assertRaises(RuntimeError):
   linux.verify_finalization_result(plan,remaining_paths=set(),remaining_cache_ids={'cache123'})

 def test_newest_current_proof_is_selected_and_expired_proof_is_rejected(self):
  from datetime import datetime,timezone
  now=datetime(2026,11,24,6,tzinfo=timezone.utc)
  def proof(created,protected):return {'proof_created_at':created,'snapshot_status':{'protected_until':protected}}
  older=proof('2026-11-24T04:00:00Z','2026-11-30T05:00:00Z')
  newest=proof('2026-11-24T05:00:00Z','2026-11-30T05:00:00Z')
  self.assertEqual(linux.select_current_chain_proof([(older,'a'),(newest,'b')],now=now)[1],'b')
  expired=proof('2026-11-22T00:00:00Z','2026-11-24T05:59:59Z')
  with self.assertRaisesRegex(ValueError,'actueel'):
   linux.select_current_chain_proof([(expired,'c')],now=now)



class PresentationReleaseContract(unittest.TestCase):
 def test_only_presentation_changes_are_admitted(self):
  old=dict(release_id='A',source_hash='a'*64,group_index={'html_sha256':'old'},
           files={'data/meijendel.sql':'a'*64,'www/pagina.html':'b'*64})
  new=old|dict(release_id='B',group_index={'html_sha256':'new'},
               files=old['files']|{'www/pagina.html':'c'*64})
  self.assertEqual(linux.presentation_changes(old,new),{'www/pagina.html':'c'*64})
  for patch in ({'source_hash':'b'*64},
                {'files':new['files']|{'data/meijendel.sql':'d'*64}},
                {'files':new['files']|{'website/sql/099_patch.sql':'e'*64}},
                {'files':new['files']|{'website/app/../secrets.py':'e'*64}}):
   with self.subTest(patch=patch), self.assertRaises(ValueError):
    linux.presentation_changes(old,new|patch)

 def test_dashboard_trim_delta_permits_only_known_analytics_csv_paths(self):
  permitted=('www/trim/soorten/soortindices_per_jaar.csv',
             'www/trim_msi_evg/functionele_msi_per_groep_per_jaar.csv')
  old=dict(release_id='A',source_hash='a'*64,files=dict.fromkeys(permitted,'b'*64))
  changed=dict.fromkeys(permitted,'c'*64)
  new=old|dict(release_id='B',files=changed)
  self.assertEqual(linux.presentation_changes(old,new),changed)
  for name in ('www/trim/bootstrap/run_manifest.json','www/trim/soorten/ander.csv',
               'www/trim_msi_evg/gam_voorspellingen_landelijk_msi_groepen.csv',
               'www/trim_msi_evg/../release-config.json'):
   with self.subTest(name=name), self.assertRaises(ValueError):
    linux.presentation_changes(old,new|{'files':changed|{name:'d'*64}})
  with self.assertRaises(ValueError):
   linux.presentation_changes(old,new|{'files':{permitted[0]:'c'*64}})

 def test_switch_failure_restores_previous_release_and_releases_lock(self):
  from unittest.mock import Mock, patch
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory); (root/'releases').mkdir()
   old=root/'releases/A';new=root/'releases/B';old.mkdir();new.mkdir()
   linux.core.set_current(root,old)
   switch=Mock(side_effect=[RuntimeError('kandidaat onbereikbaar'),None])
   latch=Mock()
   with patch.object(linux,'switch_presentation_consumers',switch):
    with self.assertRaisesRegex(RuntimeError,'kandidaat onbereikbaar'):
     linux.activate_presentation(root,old,new,Mock(),latch)
   self.assertEqual(linux.core.current(root),old.resolve())
   self.assertEqual([call.args[1:3] for call in switch.call_args_list],[(old,new),(new,old)])
   self.assertEqual([call.args for call in latch.call_args_list],[(),(False,)])

 def test_systemd_binding_updates_release_argument_and_working_directory(self):
  from unittest.mock import patch
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory);old=root/'old';new=root/'new';path=root/'unit.conf'
   path.write_text(f'WorkingDirectory={old}/website\nExecStart=python helper _website {old}\n')
   with patch.object(linux,'secure_file'):
    linux.rebind_presentation_file(path,old,new)
    self.assertEqual(path.read_text(),f'WorkingDirectory={new}/website\nExecStart=python helper _website {new}\n')
    linux.rebind_presentation_file(path,old,new)
    linux.rebind_presentation_file(path,new,old)
   self.assertEqual(path.read_text(),f'WorkingDirectory={old}/website\nExecStart=python helper _website {old}\n')


if __name__ == '__main__':
 unittest.main()
