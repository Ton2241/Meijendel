#!/usr/bin/env python3
"""Exercise upgrade safety gates and rollback without touching Docker or a VPS."""
import datetime as dt
import contextlib
import io
import gzip
import importlib.util
import json
from pathlib import Path
import tempfile
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('cutover', ROOT/'deploy/switch_mysql_974_vps_remote.py')

class SafetyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m = importlib.util.module_from_spec(SPEC)
        SPEC.loader.exec_module(cls.m)

    def manifest(self):
        return dict(status='validated-candidate-only', tested_at='2026-10-22T08:01:19+00:00',
                    version='9.7.4', source_version='9.7.1', image=self.m.NEW_IMAGE,
                    source_image=self.m.OLD_IMAGE, source_commit=self.m.CANDIDATE_COMMIT,
                    data_commit=self.m.DATA_COMMIT, data=str(self.m.CANDIDATE_ROOT/'data'),
                    container=self.m.CANDIDATE, review_before='2026-10-23')

    def test_manifest_accepts_exact_reviewed_candidate(self):
        self.m.validate_manifest(self.manifest(), dt.datetime(2026,10,22,10,tzinfo=dt.timezone.utc))

    def test_wrong_image_data_commit_path_and_expired_proof_block(self):
        for key, value in [('image', self.m.OLD_IMAGE), ('data_commit','f'*40),
                           ('data','/srv/other/data'), ('source_commit','a'*40),
                           ('container','meijendel-mysql'), ('status','failed')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.m.validate_manifest({**self.manifest(),key:value}, dt.datetime(2026,10,22,10,tzinfo=dt.timezone.utc))
        for date in [dt.datetime(2026,10,23,tzinfo=dt.timezone.utc), dt.datetime(2026,10,22,7,tzinfo=dt.timezone.utc)]:
            with self.assertRaises(ValueError): self.m.validate_manifest(self.manifest(), date)

    def test_dump_comparison_ignores_only_completion_timestamp(self):
        with tempfile.TemporaryDirectory() as tmp:
            paths = [Path(tmp)/f'{i}.gz' for i in range(3)]
            for path, value in zip(paths, [b'INSERT 1;\n-- Dump completed on yesterday\n',
                                         b'INSERT 1;\n-- Dump completed on today\n',
                                         b'INSERT 2;\n-- Dump completed on today\n']):
                with gzip.open(path,'wb') as stream: stream.write(value)
            self.assertEqual(self.m.dump_hash(paths[0]),self.m.dump_hash(paths[1]))
            self.assertNotEqual(self.m.dump_hash(paths[0]),self.m.dump_hash(paths[2]))

    def test_failed_new_start_restores_old_name_policy_and_source_write_state(self):
        events=[]
        class Fake:
            def __init__(self): self.names={'meijendel-mysql':'old-id'}
            def container_id(self,name): return self.names.get(name)
            def remove_new_active(self):
                events.append(('rm','-f','meijendel-mysql'))
                self.names.pop('meijendel-mysql',None)
            def docker(self,*args,**kwargs):
                events.append(args)
                if args[0]=='rename': self.names[args[2]]=self.names.pop(args[1])
                if args[0]=='create': self.names['meijendel-mysql']='new-id'
                if args==('start','meijendel-mysql') and self.names.get('meijendel-mysql')=='new-id': raise RuntimeError('start failed')
                return ''
            def query(self, container, sql): events.append((container,sql));return ''
            def wait(self,*args): events.append(('wait',*args))
        with self.assertRaises(RuntimeError):
            self.m.perform_switch(Fake(), ['create','--name','meijendel-mysql'], False)
        self.assertIn(('rename',self.m.ROLLBACK,'meijendel-mysql'),events)
        self.assertIn(('update','--restart=unless-stopped','meijendel-mysql'),events)
        self.assertIn(('meijendel-mysql','SET GLOBAL super_read_only=OFF; SET GLOBAL read_only=OFF'),events)
        self.assertLess(events.index(('stop','--time','60','meijendel-mysql')),events.index(('rename','meijendel-mysql',self.m.ROLLBACK)))

    def test_failure_before_rename_never_removes_source_container(self):
        events=[]
        class Fake:
            def __init__(self): self.names={'meijendel-mysql':'old-id'}
            def container_id(self,name): return self.names.get(name)
            def remove_new_active(self):
                events.append(('rm','-f','meijendel-mysql'))
                self.names.pop('meijendel-mysql',None)
            def docker(self,*args,**kwargs):
                events.append(args)
                if args[0]=='stop': raise RuntimeError('stop timeout')
                return ''
            def query(self,*args): events.append(args);return ''
            def wait(self,*args): return None
        with self.assertRaises(RuntimeError): self.m.perform_switch(Fake(),['create'],False)
        self.assertNotIn(('rm','-f','meijendel-mysql'), events)
        self.assertIn(('start','meijendel-mysql'),events)

    def test_rename_applied_then_timeout_recovers_actual_original_container(self):
        events=[]
        class Fake:
            def __init__(self): self.names={'meijendel-mysql':'old-id'}
            def container_id(self,name): return self.names.get(name)
            def remove_new_active(self): raise AssertionError('source must never be removed')
            def docker(self,*args,**kwargs):
                events.append(args)
                if args[0]=='rename':
                    self.names[args[2]]=self.names.pop(args[1])
                    if args[1]=='meijendel-mysql': raise TimeoutError('reply lost after rename')
                return ''
            def query(self,*args): events.append(args);return ''
            def wait(self,*args): return None
        runtime=Fake()
        with self.assertRaises(TimeoutError): self.m.perform_switch(runtime,['create'],False)
        self.assertEqual(runtime.container_id('meijendel-mysql'),'old-id')
        self.assertIn(('rename',self.m.ROLLBACK,'meijendel-mysql'),events)
        self.assertIn(('start','meijendel-mysql'),events)

    def test_failed_result_record_rolls_back_and_restores_previous_record(self):
        events=[]
        class Fake:
            def __init__(self): self.names={'meijendel-mysql':'old-id'}
            def container_id(self,name): return self.names.get(name)
            def remove_new_active(self): self.names.pop('meijendel-mysql')
            def docker(self,*args,**kwargs):
                events.append(args)
                if args[0]=='rename': self.names[args[2]]=self.names.pop(args[1])
                if args[0]=='create': self.names['meijendel-mysql']='new-id'
                return ''
            def query(self,*args): return ''
            def wait(self,*args): return None
        def record_failure(): raise OSError('filesystem full')
        runtime=Fake()
        with self.assertRaises(OSError):
            self.m.perform_switch(runtime,['create'],False,record_failure,lambda:events.append(('RESTORE_RECORD',)))
        self.assertEqual(runtime.container_id('meijendel-mysql'),'old-id')
        self.assertIn(('RESTORE_RECORD',),events)

class LockCompletionTests(unittest.TestCase):
    def test_unknown_remote_state_preserves_lock_and_stage(self):
        self.check_completion('',False)

    def test_only_finished_root_child_allows_lock_release(self):
        self.check_completion('helper-finished',True)

    def check_completion(self,marker,expected):
        script=(ROOT/'deploy/switch_mysql_974_vps.sh').read_text()
        finish=script[script.index('finish() {'):script.index('trap finish EXIT')]
        shell="""set -eu
REMOTE_STARTED=1
REMOTE_STAGE=/tmp/safe
LOCAL_STAGE=''
SSH_KEY=/tmp/key
VPS=host
DEPLOY_GLOBAL_LOCK=/srv/vwgm/deploy-state/production.lock
ssh() { case "$*" in *cat*) printf '%s' MARKER ;; *) echo REMOTE_CLEAN ;; esac; }
guard_release_lock() { echo RELEASE_LOCK; }
""".replace('MARKER',"'"+marker+"'")+finish+'\nfinish\n'
        result=subprocess.run(['bash','-c',shell],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual('RELEASE_LOCK' in result.stdout,expected)
        self.assertEqual('REMOTE_CLEAN' in result.stdout,expected)

class TableBudgetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m=importlib.util.module_from_spec(SPEC)
        SPEC.loader.exec_module(cls.m)

    def test_extended_checks_get_long_budget_without_extending_normal_queries(self):
        module=self.m
        calls=[]
        class Backup:
            MYSQL_CONTAINER=''
            def run_mysql(self,client,args,stdout=None,timeout=None):
                sql=args[-1]
                calls.append((client,sql,timeout))
                if client=='mysqldump': value='same schema'
                elif sql=='SELECT VERSION()': value='9.7.1' if self.MYSQL_CONTAINER==module.ACTIVE else '9.7.4'
                elif sql.startswith('CHECK TABLE'):
                    if timeout<=60: raise subprocess.TimeoutExpired(['docker','exec'],timeout)
                    value='table\tcheck\tstatus\tOK'
                elif 'SCHEMA_PRIVILEGES' in sql: value='1\t0'
                elif 'USER_PRIVILEGES' in sql: value='0'
                else: value='same settings'
                return subprocess.CompletedProcess([],0,value.encode(),b'')
        class Fake(module.Runtime):
            def __init__(self): self.backup=Backup();self.database='meijendel'
            def inventory(self,c):
                return {f't_{i}':{'type':'BASE TABLE' if i<282 else 'VIEW','rows':10} for i in range(305)}
            def docker(self,*args,**kwargs): return 'reader'
        with contextlib.redirect_stdout(io.StringIO()): Fake().validate_candidate()
        checks=[timeout for client,sql,timeout in calls if sql.startswith('CHECK TABLE')]
        self.assertEqual(len(checks),282)
        self.assertEqual(set(checks),{1800})
        ordinary=[timeout for client,sql,timeout in calls if client=='mysql' and not sql.startswith('CHECK TABLE')]
        self.assertEqual(set(ordinary),{60})

    def test_timeout_is_reported_without_dumping_entire_client_command(self):
        module=self.m
        class Backup:
            def run_mysql(self,*args,**kwargs):
                raise subprocess.TimeoutExpired(['docker','exec','PRIVATE_CLIENT_CODE'],kwargs['timeout'])
        runtime=module.Runtime.__new__(module.Runtime)
        runtime.backup=Backup();runtime.database='meijendel'
        with self.assertRaises(TimeoutError) as error:
            runtime.query(module.CANDIDATE,'CHECK TABLE `large_table` EXTENDED',timeout=1800)
        self.assertNotIn('PRIVATE_CLIENT_CODE',str(error.exception))
        self.assertIn('1800',str(error.exception))

    def test_new_attempt_path_preserves_previous_failed_work(self):
        commit='b'*40
        path=self.m.attempt_directory(commit)
        self.assertEqual(path,Path('/srv/vwgm/mysql974-switch-'+commit[:12]))
        self.assertNotEqual(path,Path('/srv/vwgm/mysql974-switch-20261022'))
        with self.assertRaises(ValueError): self.m.attempt_directory('../unsafe')

class ActiveVerificationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m=importlib.util.module_from_spec(SPEC)
        SPEC.loader.exec_module(cls.m)

    def verify(self,scan_lines,backup_ok=True,www_shiny_status=401,app_shiny_redirect="308|https://www.vwg-m.nl/shiny_meijendel/"):
        module=self.m
        with tempfile.TemporaryDirectory() as tmp:
            work=Path(tmp)
            # Exact bootstrap behavior: plain write_bytes produces non-executable code.
            audit=work/'container-audit'
            audit.write_text("printf '%s\\n' '"+"' '".join(scan_lines)+"'\nexit 1\n")
            audit.chmod(0o600)
            backup=work/'backup'
            backup.mkdir()
            (backup/'vwg-m-baremetal-latest-manifest.json').write_text(json.dumps({
                'mysql_database':{'validation':{'status':'ok' if backup_ok else 'failed'}},
                'mysql_runtime':{'version':'9.7.4'}}))
            class Fake(module.Runtime):
                def __init__(self): self.stage=work
                def inventory(self,c): return {'test':{'type':'BASE TABLE','rows':1}}
                def query(self,c,q): return '536870912'
                def inspect(self,c): return {'Image':module.NEW_IMAGE,'HostConfig':{'PortBindings':{'3306/tcp':[{'HostIp':'127.0.0.1','HostPort':'3307'}]}}}
                def docker(self,*args,**kwargs): return '1999' if args[0]=='exec' else ''
                def command(self,args,**kwargs):
                    if 'container-audit' in str(args):
                        return subprocess.run([str(a) for a in args],stdout=kwargs['stdout'],check=False)
                    if args[0]=='curl':
                        if args[-1]=='https://app.vwg-m.nl/shiny_meijendel/': code=app_shiny_redirect.encode()
                        elif args[-1]=='https://www.vwg-m.nl/shiny_meijendel/': code=str(www_shiny_status).encode()
                        else: code=b'401' if 'member-auth' in args[-1] else b'200'
                        return subprocess.CompletedProcess(args,0,code,b'')
                    return subprocess.CompletedProcess(args,0,b'',b'')
            old=module.BACKUP
            module.BACKUP=backup
            try:
                with contextlib.redirect_stdout(io.StringIO()):
                    Fake().verify_active({'test':{'type':'BASE TABLE','rows':1}})
            finally: module.BACKUP=old

    def green_scan(self):
        return ['SAMENVATTING|'+label+'|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0'
                for label in ['meijendel-mysql','shiny_meijendel']]

    def test_non_executable_snapshot_runs_and_accepts_only_expected_rollback(self):
        self.verify(self.green_scan()+['AANDACHT|container-image|'+self.m.ROLLBACK+'|old-image'])

    def test_incomplete_scan_and_other_attention_block(self):
        for lines in [self.green_scan()[:1],self.green_scan()+['URGENT|scanner|network-failure'],
                      self.green_scan()+['AANDACHT|container-hygiene|unknown-tag']]:
            with self.assertRaises(ValueError): self.verify(lines)

    def test_failed_backup_proof_blocks_completion(self):
        with self.assertRaises(ValueError): self.verify(self.green_scan(),backup_ok=False)

    def test_actual_shiny_host_requires_auth_and_redirect_must_be_exact(self):
        with self.assertRaises(ValueError): self.verify(self.green_scan(),www_shiny_status=200)
        with self.assertRaises(ValueError):
            self.verify(self.green_scan(),app_shiny_redirect='308|https://wrong.example/shiny_meijendel/')

class CandidateRecoveryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m=importlib.util.module_from_spec(SPEC)
        SPEC.loader.exec_module(cls.m)

    def proof(self):
        return dict(status='rolled-back',active_version='9.7.1',active_image=self.m.OLD_IMAGE,
                    attempted_version='9.7.4',attempted_image=self.m.NEW_IMAGE)

    def test_recovery_requires_explicit_retry_and_exact_rollback_proof(self):
        events=[]
        class Fake:
            def docker(self,*args): events.append(args)
        with self.assertRaises(ValueError): self.m.recreate_candidate(Fake(),self.proof(),False)
        with self.assertRaises(ValueError):
            self.m.recreate_candidate(Fake(),{**self.proof(),'status':'validated-active-runtime'},True)
        self.assertEqual(events,[])

    def test_recovery_creates_only_isolated_stopped_candidate_on_existing_data(self):
        events=[]
        class Fake:
            def docker(self,*args): events.append(args)
        self.m.recreate_candidate(Fake(),self.proof(),True)
        self.assertEqual(len(events),1)
        args=events[0]
        self.assertEqual(args[0],'create')
        self.assertIn(self.m.CANDIDATE,args)
        self.assertIn(self.m.NEW_IMAGE,args)
        self.assertNotIn('-p',args)
        self.assertEqual(args[args.index('--network')+1],'none')
        self.assertIn(str(self.m.CANDIDATE_ROOT/'data')+':/var/lib/mysql',args)
        self.assertNotIn(self.m.ACTIVE,args)

if __name__=='__main__': unittest.main()
