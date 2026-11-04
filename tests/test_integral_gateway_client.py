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
if __name__=='__main__':unittest.main()
