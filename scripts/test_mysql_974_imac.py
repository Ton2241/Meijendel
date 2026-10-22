#!/usr/bin/env python3
"""Safety regression tests for local Oracle cutover; no system changes."""
import gzip,importlib.util,tempfile,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('imac',Path(__file__).resolve().parents[1]/'deploy/switch_mysql_974_imac.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class Safety(unittest.TestCase):
 def test_dump_comparison_keeps_every_data_change(self):
  with tempfile.TemporaryDirectory() as d:
   def save(n,data):
    p=Path(d)/n
    with gzip.open(p,'wb') as f:f.write(data)
    return p
   a=save('a',b'-- Server version\t9.7.1\nINSERT 1;\n-- Dump completed on yesterday\n')
   b=save('b',b'-- Server version\t9.7.4\nINSERT 1;\n-- Dump completed on today\n')
   c=save('c',b'-- Server version\t9.7.4\nINSERT 2;\n-- Dump completed on today\n')
   self.assertEqual(m.dump_hash(a),m.dump_hash(b))
   self.assertNotEqual(m.dump_hash(a),m.dump_hash(c))
 def test_dump_hash_does_not_ignore_unknown_server_or_sql_comments(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'a'
   with gzip.open(p,'wb') as f:f.write(b'-- Server version\t9.7.5\n')
   with self.assertRaises(ValueError):m.dump_hash(p)
 def test_exact_candidate_manifest_required(self):
  good=dict(status='validated-local-candidate-only',source_version='9.7.1',target_version='9.7.4',objects=724,checks=668,accounts=2,schemas=m.SCHEMAS,archive_sha256=m.ARCHIVE_SHA,source_objects_schema_accounts_and_counts_equal=True)
  m.validate_manifest(good)
  for key,val in [('objects',725),('status','partial'),('source_version','9.5.0'),('checks',0),('archive_sha256','a'*64),('schemas',m.SCHEMAS[:-1])]:
   with self.subTest(key=key),self.assertRaises(ValueError):m.validate_manifest({**good,key:val})
 def test_every_failure_restores_source_write_state_and_after_stop_rolls_back(self):
  for fail in ['fresh','stop','install','activate','verify','writable']:
   events=[]
   class Fake:
    def freeze(self):events.append('freeze')
    def fresh(self):events.append('fresh');self.check('fresh')
    def stop_old(self):events.append('stop');self.check('stop')
    def install(self):events.append('install');self.check('install')
    def activate(self):events.append('activate');self.check('activate')
    def verify(self):events.append('verify');self.check('verify')
    def writable(self):events.append('writable');self.check('writable')
    def check(self,k):
     if k==fail:raise RuntimeError(k)
    def rollback(self):events.append('rollback')
    def unfreeze_old(self):events.append('unfreeze')
   with self.subTest(fail=fail),self.assertRaises(RuntimeError):m.transaction(Fake())
   if fail=='fresh':self.assertNotIn('rollback',events);self.assertIn('unfreeze',events)
   else:self.assertIn('rollback',events)
 def test_partial_freeze_failure_also_attempts_unfreeze(self):
  events=[]
  class Fake:
   def freeze(self):raise RuntimeError('partial freeze')
   def unfreeze_old(self):events.append('unfreeze')
  with self.assertRaises(RuntimeError):m.transaction(Fake())
  self.assertEqual(events,['unfreeze'])
 def test_failure_before_service_stop_never_stops_live_source(self):
  events=[]
  op=m.Operation.__new__(m.Operation);op.service_stopped=False
  op.unfreeze_old=lambda:events.append('unfreeze')
  old=m.admin;old_stopped=m.stopped;old_wait=m.wait_version
  m.stopped=lambda:None;m.wait_version=lambda v:None
  m.admin=lambda *a,**kw:events.append(a)
  try:op.rollback()
  finally:m.admin=old;m.stopped=old_stopped;m.wait_version=old_wait
  self.assertEqual(events,['unfreeze'])
 def test_no_old_data_rollback_after_writes_may_have_started(self):
  events=[]
  class Fake:
   write_exposed=False
   def freeze(self):pass
   def fresh(self):pass
   def stop_old(self):pass
   def install(self):pass
   def activate(self):pass
   def verify(self):pass
   def writable(self):self.write_exposed=True;raise RuntimeError('post-start failure')
   def rollback(self):events.append('BAD-old-data-rollback')
   def preserve_new(self):events.append('preserve-new-data')
  with self.assertRaises(RuntimeError):m.transaction(Fake())
  self.assertEqual(events,['preserve-new-data'])
 def test_failed_bootout_with_live_old_server_only_unfreezes(self):
  events=[];op=m.Operation.__new__(m.Operation)
  op.service_stopped=True;op.old_stopped=False
  op.old_is_live=lambda:True;op.unfreeze_old=lambda:events.append('unfreeze')
  old=m.admin;old_stopped=m.stopped;old_wait=m.wait_version;old_query=m.query
  m.admin=lambda *a,**kw:events.append(a);m.stopped=lambda:None;m.wait_version=lambda v:None;m.query=lambda sql:'9.7.1\t0\t0'
  try:op.rollback()
  finally:m.admin=old;m.stopped=old_stopped;m.wait_version=old_wait;m.query=old_query
  self.assertEqual(events,['unfreeze'])
 def test_service_identity_requires_actual_old_data_and_bounded_new_args(self):
  service={'Program':'/usr/local/mysql/bin/mysqld','ProgramArguments':m.BASE_ARGS,'UserName':'_mysql','GroupName':'_mysql'}
  m.validate_service(service,str(m.OLD/'data'))
  for value in [str(m.NEW/'data'),'/some/other/data']:
   with self.assertRaises(ValueError):m.validate_service(service,value)
  with self.assertRaises(ValueError):m.validate_service({**service,'ProgramArguments':[*m.BASE_ARGS,'--defaults-file=/tmp/untrusted']},str(m.OLD/'data'))
  args=m.new_args(True)
  self.assertEqual(args[1],'--no-defaults')
  self.assertIn('--datadir='+str(m.NEW/'data'),args)
  self.assertFalse(any(str(m.OLD) in a for a in args))
 def test_success_verifies_readonly_before_enabling_writes(self):
  events=[]
  class Fake:
   def __getattr__(self,k):return lambda:events.append(k)
  m.transaction(Fake())
  self.assertEqual(events,['freeze','fresh','stop_old','install','activate','verify','writable'])
if __name__=='__main__':unittest.main()
