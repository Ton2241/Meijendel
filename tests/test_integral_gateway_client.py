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
if __name__=='__main__':unittest.main()
