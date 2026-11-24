import importlib.util,unittest,tempfile,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('client',ROOT/'deploy/integral_gateway_client.py');client=importlib.util.module_from_spec(spec);spec.loader.exec_module(client)
class CheckoutGuard(unittest.TestCase):
 def test_only_clean_main_equal_to_origin_main_can_supply_gateway_payload(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)
   def git(*args):return subprocess.check_output(['git','-C',str(p),*args],text=True,stderr=subprocess.DEVNULL).strip()
   git('init','-b','main');git('config','user.name','Test');git('config','user.email','test@example.invalid');(p/'file').write_text('x');git('add','file');git('commit','-m','fixture');commit=git('rev-parse','HEAD');git('update-ref','refs/remotes/origin/main',commit)
   self.assertEqual(client.check_checkout(p),commit)
   (p/'file').write_text('modified')
   with self.assertRaises(ValueError):client.check_checkout(p)
   (p/'file').write_text('x');git('checkout','-b','task')
   with self.assertRaises(ValueError):client.check_checkout(p)
class ManagedClientContract(unittest.TestCase):
 def test_receive_checks_ancestry_and_apply_requires_saved_evidence(self):
  import json
  from types import SimpleNamespace
  from unittest.mock import patch
  with tempfile.TemporaryDirectory() as d:
   out=Path(d);archive=out/'payload.tar.gz';archive.write_bytes(b'T7')
   commits={'Meijendel':'a'*40,'VWG_M':'b'*40,'VWG_Project':'c'*40}
   previous={'Meijendel':'d'*40,'VWG_M':'e'*40}
   prepared=dict(commits=commits,archive=str(archive),sha256='f'*64)
   repos={name:out/name for name in commits}
   response=dict(stage='preflight',commits=commits,production_commits=previous,
                 archive_sha256=prepared['sha256'],archive_bytes=2)
   seen=[]
   def run(args,**kwargs):
    command=args[-1];seen.append(command)
    if command.startswith('meijendel-receive'):
     self.assertEqual(kwargs['stdin'].read(),b'T7')
     return SimpleNamespace(stdout=json.dumps(response))
    if command.startswith('meijendel-apply'):
     self.assertEqual(kwargs['stdin'],subprocess.DEVNULL)
   with patch.object(client,'run',side_effect=run) as execute:
    with self.assertRaisesRegex(ValueError,'Ontvang eerst'):
     client.managed_execute(prepared,'apply','loopback','key',out,repos)
    execute.assert_not_called()
    client.managed_execute(prepared,'receive','loopback','key',out,repos)
    self.assertEqual(seen,[f"meijendel-receive {commits['Meijendel']} {'f'*64} 2",commits['Meijendel'],commits['VWG_M']])
    self.assertEqual(json.loads((out/'managed-preflight.json').read_text()),response)
    for name in previous:
     execute.assert_any_call(['git','-C',repos[name],'merge-base','--is-ancestor',previous[name],commits[name]])
    client.managed_execute(prepared,'apply','loopback','key',out,repos)
    self.assertTrue(seen[-1].startswith('meijendel-apply'))
    archive.write_bytes(b'changed')
    with self.assertRaisesRegex(ValueError,'dit archief'):
     client.managed_execute(prepared,'apply','loopback','key',out,repos)

 def test_finalize_and_adopt_use_only_fixed_managed_commands(self):
  from types import SimpleNamespace
  from unittest.mock import patch
  prepared={'commits':{'Meijendel':'a'*40},'sha256':'b'*64}
  commands=[]
  def run(args,**kwargs):
   commands.append(args[-1]);self.assertEqual(kwargs['stdin'],subprocess.DEVNULL)
   return SimpleNamespace(stdout='OK')
  with patch.object(client,'run',side_effect=run):
   client.managed_finalization(prepared,'finalize','host','key')
   client.managed_finalization(prepared,'adopt-finalization','host','key')
  self.assertEqual(commands,[f"meijendel-finalize {'a'*40} {'b'*64}",
                             f"meijendel-adopt-finalization {'a'*40} {'b'*64}"])

class LegacyStorageContract(unittest.TestCase):
 def test_release_budget_checks_both_compressed_copies_and_preserves_reserve(self):
  import io,tarfile
  from unittest.mock import patch
  gib=1024**3
  with tempfile.TemporaryDirectory() as d:
   archive=Path(d)/'payload.tar.gz'
   with tarfile.open(archive,'w:gz') as bundle:
    for name,value in [('payload/data/meijendel.sql',b'SQL'),('receipt.json',b'receipt')]:
     item=tarfile.TarInfo(name);item.size=len(value);bundle.addfile(item,io.BytesIO(value))
   size=archive.stat().st_size
   expected=28*gib+2*size
   room={'inbox':{'device':1,'free':expected-1},'packages':{'device':1,'free':expected-1}}
   with patch.object(client,'read_legacy_capacity',return_value=room):
    with self.assertRaisesRegex(ValueError,'voor overdracht'):
     client.check_legacy_capacity(archive,'host','key')
    room['inbox']['free']=room['packages']['free']=expected
    client.check_legacy_capacity(archive,'host','key')
    room['inbox']={'device':2,'free':size}
    room['packages']['free']=28*gib+size
    client.check_legacy_capacity(archive,'host','key')
 def test_full_archive_budget_uses_existing_five_copy_and_eight_gib_check(self):
  gib=1024**3
  self.assertEqual(client.package_workspace(5*gib,4*gib),33*gib)
  self.assertEqual(client.package_workspace(20,0,presentation=True),gib+20)

 def test_capacity_gate_precedes_upload_and_resume_never_uploads_again(self):
  import json,os
  from types import SimpleNamespace
  from unittest.mock import patch
  with tempfile.TemporaryDirectory() as d:
   out=Path(d)
   archive=out/'payload.tar.gz';archive.write_bytes(b'T7')
   commits={name:'a'*40 for name in ('Meijendel','VWG_M','VWG_Project')}
   prepared=out/'prepared.json'
   prepared.write_text(json.dumps(dict(archive=str(archive),sha256=client.core.sha(archive),commits=commits,
      intent='production',recipe={'analysis_root':d,'website_root':d},project_root=d)))
   steps=[]
   def capacity(*args):
    steps.append('capacity')
   def upload(*args,**kwargs):
    steps.append('upload')
    self.assertEqual(args[0][0],'/usr/bin/rsync')
    self.assertIn('StrictHostKeyChecking=yes',args[0][4])
   def gateway(args,**kwargs):
    stage=args[2];steps.append(stage)
    if stage=='preflight':
     kwargs['stdout'].write(json.dumps({'stage':'preflight','production_commits':{}})+'\n')
    return SimpleNamespace(returncode=0)
   def cleanup(*args):
    steps.append('cleanup')
   with patch.dict(os.environ,{'VWG_MANAGED_DEPLOY_TARGET':'','VWG_MANAGED_DEPLOY_SSH_KEY':''}), \
       patch.object(client,'check_checkout',return_value='a'*40), \
       patch.object(client,'check_preflight_commits'), \
       patch.object(client,'check_legacy_capacity',side_effect=ValueError('geen ruimte')) as gate, \
       patch.object(client,'run',side_effect=upload) as transfer, \
       patch.object(client.subprocess,'run',side_effect=gateway), \
       patch.object(client,'cleanup_legacy_inbox',side_effect=cleanup):
    with self.assertRaisesRegex(ValueError,'geen ruimte'):
     client.execute(prepared,'apply',yes=True)
    transfer.assert_not_called()
    gate.side_effect=capacity
    client.execute(prepared,'apply',yes=True)
    self.assertEqual(steps,['capacity','upload','preflight','apply','cleanup'])
    client.execute(prepared,'apply',yes=True)
    self.assertEqual(steps,['capacity','upload','preflight','apply','cleanup','cleanup'])
 def test_cleanup_requires_verified_t7_archive_before_remote_call(self):
  from unittest.mock import patch
  p={'archive':'not-on-t7','sha256':'a'*64,'commits':{}}
  with patch.object(client,'checked_tree',side_effect=ValueError('T7 is niet gemount')), patch.object(client,'run') as run:
   with self.assertRaisesRegex(ValueError,'T7'):
    client.cleanup_legacy_inbox(p,'host','key')
   run.assert_not_called()
 def test_cleanup_verifies_active_receipt_and_excludes_pending_or_changed_files(self):
  import hashlib,json
  body=b'T7'
  digest=hashlib.sha256(body).hexdigest()
  commits={'Meijendel':'a'*40,'VWG_M':'b'*40,'VWG_Project':'c'*40}
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);state=root/'state';inbox=state/'integral-inbox';inbox.mkdir(parents=True)
   production=root/'production';active=production/'releases'/'active';active.mkdir(parents=True)
   (production/'current').symlink_to(active)
   (active/'release.json').write_text(json.dumps({'release_id':'active','source_commits':commits,'gateway_package_sha256':digest}))
   for name in ('Meijendel','VWG_M'):(state/(name+'.commit')).write_text(commits[name])
   archive=inbox/(commits['Meijendel']+'.tar.gz')
   archive.write_bytes(body)
   namespace={'__name__':'test_fixture'}
   exec(client.LEGACY_CLEANUP_PROGRAM,namespace)
   cleanup=namespace['remove_completed']
   lock=state/'production.lock';lock.mkdir()
   with self.assertRaises(FileExistsError):cleanup(state,production,commits,digest,len(body))
   self.assertTrue(archive.exists());lock.rmdir()
   with self.assertRaisesRegex(ValueError,'Actieve release'):cleanup(state,production,commits,'d'*64,len(body))
   self.assertEqual(archive.read_bytes(),body)
   archive.write_bytes(b'X7')
   with self.assertRaisesRegex(ValueError,'SHA-256'):cleanup(state,production,commits,digest,len(body))
   self.assertFalse(lock.exists());self.assertTrue(archive.exists())
   archive.write_bytes(body)
   self.assertTrue(cleanup(state,production,commits,digest,len(body)))
   self.assertFalse(archive.exists());self.assertFalse(lock.exists())
   self.assertFalse(cleanup(state,production,commits,digest,len(body)))

if __name__=='__main__':unittest.main()
