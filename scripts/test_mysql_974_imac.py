#!/usr/bin/env python3
"""Safety regression tests for local Oracle cutover; no system changes."""
import gzip,importlib.util,tempfile,unittest,os,subprocess
from unittest.mock import patch
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
class RecoverySafety(unittest.TestCase):
 def test_query_works_when_vendor_removed_old_client(self):
  with tempfile.TemporaryDirectory() as d:
   old=Path(d)/'old';new=Path(d)/'new';(new/'bin').mkdir(parents=True)
   client=new/'bin/mysql';client.write_text('#!/bin/sh\nprintf \'9.7.4\\t1\\t1\\n\'\n');client.chmod(0o755)
   with patch.object(m,'OLD',old),patch.object(m,'NEW',new):
    self.assertEqual(m.query('SELECT VERSION(),@@read_only,@@super_read_only'),'9.7.4\t1\t1')
 def test_recovery_never_calls_installer_or_old_data_rollback(self):
  for fail in [None,'verify','writable']:
   events=[]
   class Op:
    def recovery_prepare(self):events.append('prepare')
    def activate(self):events.append('readonly-start')
    def verify(self):events.append('full-verify');self.check('verify')
    def writable(self):events.append('writable');self.check('writable')
    def check(self,name):
     if name==fail:raise RuntimeError(name)
    def preserve_new(self):events.append('preserve-new')
   with self.subTest(fail=fail):
    if fail:
     with self.assertRaises(RuntimeError):m.recover(Op())
     self.assertEqual(events[-1],'preserve-new')
     if fail=='verify':self.assertNotIn('writable',events)
    else:
     m.recover(Op());self.assertEqual(events,['prepare','readonly-start','full-verify','writable'])
 def test_recovery_link_is_publicly_traversable_but_data_stay_private(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);old=root/'old';new=root/'new';old.mkdir();new.mkdir();data=new/'data';data.mkdir(mode=0o700)
   link=root/'mysql';link.symlink_to(old.name);os.chmod(link,0o700,follow_symlinks=False)
   def unprivileged_admin(*args,**kwargs):
    return m.run(args,**kwargs)
   with patch.object(m,'LINK',link),patch.object(m,'OLD',old),patch.object(m,'NEW',new),patch.object(m,'admin',unprivileged_admin):
    mask=os.umask(0o077)
    try:m.replace_link(new)
    finally:os.umask(mask)
   self.assertEqual(link.resolve(),new.resolve())
   self.assertEqual(link.lstat().st_mode&0o777,0o777)
   self.assertEqual(data.stat().st_mode&0o777,0o700)
 def test_recovery_never_removes_a_real_directory_at_mysql_link(self):
  with tempfile.TemporaryDirectory() as d:
   link=Path(d)/'mysql';link.mkdir();keep=link/'keep';keep.write_text('preserve')
   with patch.object(m,'LINK',link),self.assertRaises(ValueError):m.replace_link(Path(d)/'new')
   self.assertEqual(keep.read_text(),'preserve')
 def test_frozen_source_recovery_checks_content_owner_mode_and_location(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);work=root/'work';proof=work/'imac-974-proof';proof.mkdir(parents=True)
   original=proof/'user-schemas.sql.gz';frozen=root/'source-frozen-123456.sql.gz'
   def write(path,data):
    with gzip.open(path,'wb') as f:f.write(data)
    path.chmod(0o600)
   write(original,b'-- Server version\t9.7.1\nINSERT 1;\n-- Dump completed on before\n')
   write(frozen,b'-- Server version\t9.7.1\nINSERT 1;\n-- Dump completed on after\n')
   with patch.object(m,'WORK',work):
    m.validate_frozen_source(frozen)
    frozen.chmod(0o644)
    with self.assertRaises(ValueError):m.validate_frozen_source(frozen)
    write(frozen,b'-- Server version\t9.7.1\nINSERT 2;\n')
    with self.assertRaises(ValueError):m.validate_frozen_source(frozen)
    frozen.unlink();frozen.symlink_to(original)
    with self.assertRaises(ValueError):m.validate_frozen_source(frozen)
 def test_rollback_does_not_activate_missing_old_programs(self):
  events=[];op=m.Operation.__new__(m.Operation)
  op.service_stopped=True;op.old_stopped=True
  with tempfile.TemporaryDirectory() as d,patch.object(m,'OLD',Path(d)/'missing'),patch.object(m,'admin',lambda *a,**kw:events.append(a)),patch.object(m,'stopped',lambda:None):
   with self.assertRaisesRegex(RuntimeError,'programma'):op.rollback()
  self.assertFalse(any('bootstrap' in event for event in events))

class RecoveryGuards(unittest.TestCase):
 def test_diagnostic_cli_never_authenticates_or_starts_recovery(self):
  events=[]
  class Op:
   def recovery_preflight(self,p):events.append('preflight')
   def cleanup(self):events.append('cleanup')
  with patch.object(m,'Operation',Op),patch.object(m.sys,'argv',['helper','--recover-installed','--source-frozen','/fixture']),patch.object(m.subprocess,'run',side_effect=AssertionError('unexpected subprocess')):
   m.main()
  self.assertEqual(events,['preflight','cleanup'])
 def test_recovery_does_not_unmount_an_existing_mount_it_did_not_create(self):
  with tempfile.TemporaryDirectory() as d:
   mount=Path(d)/'existing';mount.mkdir();op=m.Operation.__new__(m.Operation);op.mount=mount;op.owns_mount=False
   with patch.object(m,'run',side_effect=AssertionError('unrelated mount touched')):op.cleanup()
   self.assertTrue(mount.exists())
 def test_root_metadata_or_loaded_job_blocks_link_mutation(self):
  import plistlib
  from types import SimpleNamespace
  original=plistlib.dumps(dict(Program='/usr/local/mysql/bin/mysqld',ProgramArguments=m.BASE_ARGS,UserName='_mysql',GroupName='_mysql'))
  for case in ['state-owner','state-link','plist-write','plist-content','loaded-job']:
   calls=[];op=m.Operation.__new__(m.Operation);op.original_plist=original
   def admin(*args,**kw):
    calls.append(args)
    if args[0]=='/usr/bin/stat':
     value='Directory:0:700' if args[-1]==m.STATE else 'Regular File:0:644'
     if case=='state-owner' and args[-1]==m.STATE:value='Directory:501:700'
     if case=='state-link' and args[-1]==m.STATE:value='Symbolic Link:0:777'
     if case=='plist-write' and args[-1]!=m.STATE:value='Regular File:0:666'
     return SimpleNamespace(stdout=value.encode(),returncode=0)
    if args[0]=='/bin/cat':
     content=original if case!='plist-content' else plistlib.dumps(dict(Program='/bad',ProgramArguments=m.BASE_ARGS,UserName='_mysql',GroupName='_mysql'))
     return SimpleNamespace(stdout=content,returncode=0)
    return SimpleNamespace(stdout=b'',returncode=0)
   with self.subTest(case=case),patch.object(m,'admin',admin),patch.object(m,'mysql_pids',lambda:[]),patch.object(m,'other_maintenance_pids',lambda:[]),patch.object(m,'stopped',lambda:None),patch.object(m,'replace_link',side_effect=AssertionError('unsafe link mutation')):
    with self.assertRaises(ValueError):op.recovery_prepare()
   self.assertFalse(any(a[:2]==('/bin/launchctl','bootstrap') for a in calls))

if __name__=='__main__':unittest.main()
