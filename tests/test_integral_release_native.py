import importlib.util,json,os,signal,subprocess,sys,tempfile,time,unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('native',ROOT/'scripts/rehearse_integral_release.py');n=importlib.util.module_from_spec(spec);spec.loader.exec_module(n)
class NativeServiceTests(unittest.TestCase):
 def hook(self,root):
  h=n.NativeHooks.__new__(n.NativeHooks);h.root=root.resolve();h.private=h.root/'private';h.private.mkdir();h.env=dict(os.environ);h.db='vwg_release_test';h.socket=h.private/'mysql.sock';h.config={'mysql_password':'test-only'};return h
 def test_stop_waits_for_stubborn_process_and_preserves_no_live_service(self):
  with tempfile.TemporaryDirectory() as d:
   h=self.hook(Path(d));p=subprocess.Popen([sys.executable,'-c','import signal,time,sys;signal.signal(signal.SIGTERM,signal.SIG_IGN);print("READY",flush=True);time.sleep(60)',str(h.root)],stdout=subprocess.PIPE,text=True,start_new_session=True)
   try:
    self.assertEqual(p.stdout.readline().strip(),'READY');n.release.atomic_json(h.private/'processes.json',{'test':p.pid});h.stop();self.assertIsNotNone(p.poll());self.assertFalse((h.private/'processes.json').exists())
   finally:
    if p.poll() is None:os.killpg(p.pid,signal.SIGKILL)
    p.wait();p.stdout.close()
 def test_partial_start_records_first_process_before_second_failure(self):
  with tempfile.TemporaryDirectory() as d:
   h=self.hook(Path(d));package=h.root/'package';package.mkdir();(package/'release.json').write_text(json.dumps({'cache':{'root':'data/cache/test.rds'},'historical_cache_rehearsal':True,'mysql':{'source':'data/meijendel.sql'}}))
   class Process:pid=12345
   with patch.object(h,'guard_postgres'),patch.object(n.subprocess,'Popen',side_effect=[Process(),OSError('second start failed')]):
    with self.assertRaises(OSError):h.start(package)
   self.assertEqual(n.read_json(h.private/'processes.json'),{'website':12345})
if __name__=='__main__':unittest.main()
