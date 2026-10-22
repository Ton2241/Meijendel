#!/usr/bin/env python3
"""Bounded 9.7.1 -> 9.7.4 runtime switch, with a separate data directory.

Run only from the local guarded wrapper's root-owned, hash-verified snapshot.
No application or ecological data release is published by this helper.
"""
from __future__ import annotations
import datetime as dt
import gzip
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

CANDIDATE_COMMIT = '47d133641833ae4cc420128350d6de63bcc6ecde'
DATA_COMMIT = '9da16f606a6fbc58763e83f708f03cd544b73b61'
OLD_IMAGE = 'sha256:787656985cc0d4ba01768aab80976b3ad7a2ce0b870fb5a64b37cc80b08c99b2'
NEW_IMAGE = 'sha256:c58c7a7ee44359d56c04b676abe26ec4f7d8b5f2b385a6f2f3c7f87a08752a91'
CANDIDATE_ROOT = Path('/srv/vwgm/mysql974-candidate-47d133641833')
CANDIDATE = 'meijendel-mysql-974-candidate-47d133641833'
ROLLBACK = 'meijendel-mysql-971-rollback-20261022'
ACTIVE = 'meijendel-mysql'
OLD_TAG = 'vwgm-mysql:9.7.1'
NEW_TAG = 'vwgm-mysql:9.7.4'
ROLLBACK_TAG = 'vwgm-mysql:rollback-971-20261022'
CANDIDATE_TAG = 'vwgm-mysql:candidate-974-47d133641833'
STATE = Path('/srv/vwgm/deploy-state')
APP = Path('/srv/vwgm/vwg-m-linux-app')
BACKUP = Path('/srv/vwgm/backups/vwg-m-baremetal')

def require(condition, message):
    if not condition: raise ValueError(message)

def validate_manifest(manifest, now):
    expected = dict(status='validated-candidate-only',version='9.7.4',source_version='9.7.1',
                    image=NEW_IMAGE,source_image=OLD_IMAGE,source_commit=CANDIDATE_COMMIT,
                    data_commit=DATA_COMMIT,data=str(CANDIDATE_ROOT/'data'),container=CANDIDATE,
                    review_before='2026-10-23')
    require(all(manifest.get(k)==v for k,v in expected.items()), 'kandidaatmanifest wijkt af van beoordeeld bewijs')
    tested=dt.datetime.fromisoformat(manifest['tested_at'])
    require(tested.tzinfo is not None and tested <= now and (now-tested).total_seconds()<86400,
            'testtijd is ongeldig, ligt in de toekomst of is meer dan24uur geleden')
    require(now < dt.datetime(2026,10,23,tzinfo=dt.timezone.utc),'beoordeling verlopen; opnieuw beoordelen')

def dump_hash(path):
    """Source uses the same mysqldump binary/flags before and after preparation."""
    digest=hashlib.sha256()
    with gzip.open(path,'rb') as stream:
        for line in stream:
            if not line.startswith(b'-- Dump completed on '): digest.update(line)
    return digest.hexdigest()

def perform_switch(runtime, create_args, source_was_read_only, verify=None, on_rollback=None):
    old_id=runtime.container_id(ACTIVE)
    require(bool(old_id),'broncontainer ontbreekt')
    try:
        runtime.docker('stop','--time','60',ACTIVE)
        runtime.docker('rename',ACTIVE,ROLLBACK)
        runtime.docker('update','--restart=no',ROLLBACK)
        runtime.docker(*create_args)
        runtime.docker('start',ACTIVE)
        runtime.wait(ACTIVE,'9.7.4')
        runtime.docker('tag',OLD_IMAGE,ROLLBACK_TAG)
        runtime.docker('tag',NEW_IMAGE,NEW_TAG)
        runtime.docker('image','rm',OLD_TAG)
        if verify: verify()
    except BaseException as original:
        # Ignore further termination requests while restoring service.
        for sig in (signal.SIGINT,signal.SIGTERM,signal.SIGHUP):
            signal.signal(sig, signal.SIG_IGN)
        failures=[]
        def restore(action):
            try: action()
            except BaseException as exc: failures.append(type(exc).__name__)
        # A daemon mutation may succeed even when its CLI reply times out.
        # Reconcile actual immutable container IDs, never a post-command flag.
        try:
            active_id=runtime.container_id(ACTIVE)
            rollback_id=runtime.container_id(ROLLBACK)
            if rollback_id==old_id:
                if active_id: restore(runtime.remove_new_active)
                restore(lambda: runtime.docker('rename',ROLLBACK,ACTIVE))
            if runtime.container_id(ACTIVE)==old_id:
                restore(lambda: runtime.docker('update','--restart=unless-stopped',ACTIVE))
                restore(lambda: runtime.docker('start',ACTIVE))
                restore(lambda: runtime.wait(ACTIVE,'9.7.1'))
                if not source_was_read_only:
                    restore(lambda: runtime.query(ACTIVE,'SET GLOBAL super_read_only=OFF; SET GLOBAL read_only=OFF'))
            else:
                failures.append('oorspronkelijke container niet onder actieve naam gevonden')
        except BaseException as exc:
            failures.append(type(exc).__name__)
        restore(lambda: runtime.docker('tag',OLD_IMAGE,OLD_TAG))
        restore(lambda: runtime.docker('image','rm',NEW_TAG,ROLLBACK_TAG,check=False))
        if not failures and on_rollback:
            restore(on_rollback)
        if failures:
            raise RuntimeError('OMSCHAKELING MISLUKT; terugval vereist controle: '+','.join(failures)) from original
        raise

class Runtime:
    def __init__(self,stage):
        self.stage=stage
        spec=importlib.util.spec_from_file_location('backup_support',stage/'backup_baremetal_vps.py')
        self.backup=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.backup)
        self.database=self.backup.parse_env_file(Path('/srv/vwgm/meijendel-mysql/mysql.env'))['MYSQL_DATABASE']
        require(self.database.replace('_','').isalnum(),'ongeldige databasenaam')

    def command(self,args,*,check=True,timeout=300,stdout=subprocess.PIPE):
        result=subprocess.run([str(a) for a in args],stdin=subprocess.DEVNULL,stdout=stdout,
                              stderr=subprocess.PIPE,timeout=timeout)
        if check and result.returncode:
            # Never expose command arguments, environment, auth rows or SQL results.
            raise RuntimeError(f'opdracht {Path(str(args[0])).name} faalde met status{result.returncode}')
        return result

    def docker(self,*args,check=True):
        result=self.command(['docker',*args],check=check)
        return result.stdout.decode() if result.stdout is not None else ''

    def inspect(self,container): return json.loads(self.docker('inspect',container))[0]

    def container_id(self,name):
        # Distinguish a missing container from daemon/permission failures.
        result=self.command(['docker','inspect','--format','{{.Id}}',name],check=False)
        if result.returncode==0: return result.stdout.decode().strip()
        if b'No such object' in result.stderr or b'No such container' in result.stderr: return None
        raise RuntimeError('containeridentiteit kon niet betrouwbaar worden vastgesteld')

    def remove_new_active(self):
        info=self.inspect(ACTIVE)
        require(info['Image']==NEW_IMAGE and
                [m['Source'] for m in info['Mounts'] if m['Destination']=='/var/lib/mysql']==[str(CANDIDATE_ROOT/'data')],
                'onbekende actieve container wordt niet verwijderd')
        self.docker('rm','-f',info['Id'])

    def client(self,container,client,args,*,stdout=subprocess.PIPE):
        self.backup.MYSQL_CONTAINER=container
        result=self.backup.run_mysql(client,args,stdout=stdout,timeout=1800 if client=='mysqldump' else 60)
        require(result.returncode==0,f'{client}-controle faalde in {container}')
        return result.stdout.decode() if result.stdout is not None else ''

    def query(self,container,sql):
        return self.client(container,'mysql',['--batch','--skip-column-names',self.database,'-e',sql]).strip()

    def wait(self,container,version):
        for attempt in range(120):
            try:
                if self.query(container,'SELECT VERSION()')==version: return
            except (ValueError,RuntimeError,subprocess.SubprocessError): pass
            time.sleep(2)
        raise RuntimeError(f'MySQL{version} niet gereed in {container}')

    def inventory(self,container):
        self.backup.MYSQL_CONTAINER=container
        return self.backup.mysql_inventory(self.database)

    def schema(self,container):
        return self.client(container,'mysqldump',['--no-data','--skip-comments','--skip-dump-date',
                           '--no-tablespaces','--set-gtid-purged=OFF',self.database])

    def validate_candidate(self):
        require(self.query(ACTIVE,'SELECT VERSION()')=='9.7.1','bronversie veranderd')
        require(self.query(CANDIDATE,'SELECT VERSION()')=='9.7.4','doelversie veranderd')
        source=self.inventory(ACTIVE)
        require(len(source)==305,'bron bevat niet de beoordeelde305objecten')
        require(source==self.inventory(CANDIDATE),'objecten of rijtellingen verschillen')
        require(self.schema(ACTIVE)==self.schema(CANDIDATE),'schemas verschillen')
        settings='SELECT @@time_zone, @@sql_mode, @@character_set_server, @@collation_server'
        require(self.query(ACTIVE,settings)==self.query(CANDIDATE,settings),'instellingen verschillen')
        checks=0
        for name,item in source.items():
            if item['type']!='BASE TABLE': continue
            result=self.query(CANDIDATE,f'CHECK TABLE `{name}` EXTENDED')
            require(result.splitlines()[-1].split('\t')[-2:]==['status','OK'],f'tabelcontrole faalde:{name}')
            checks+=1
        require(checks==282,'aantal tabelcontroles wijkt af')
        user=self.docker('exec',CANDIDATE,'printenv','MYSQL_USER').strip()
        require(user.replace('_','').isalnum(),'ongeldige leesaccountnaam')
        privileges=self.query(CANDIDATE,"SELECT COUNT(*),COALESCE(SUM(PRIVILEGE_TYPE<>'SELECT'),0) FROM information_schema.SCHEMA_PRIVILEGES WHERE GRANTEE=CONCAT(QUOTE('"+user+"'),'@',QUOTE('%')) AND TABLE_SCHEMA=DATABASE()")
        require(privileges=='1\t0','leesaccount heeft niet uitsluitend SELECT')
        # Full grants are kept private; compare only permitted privilege rows.
        require(self.query(CANDIDATE,"SELECT COUNT(*) FROM information_schema.USER_PRIVILEGES WHERE GRANTEE=CONCAT(QUOTE('"+user+"'),'@',QUOTE('%')) AND PRIVILEGE_TYPE<>'USAGE'")=='0','leesaccount heeft globale rechten')
        print('GROEN|mysql974-hercontrole|objects=305|checks=282|leesrechten=SELECT',flush=True)
        return source

    def dump_source(self,path):
        # run_mysql requires a real OS file descriptor, so compress after dumping.
        raw=path.with_suffix('.sql')
        try:
            with raw.open('wb') as output:
                self.client(ACTIVE,'mysqldump',['--single-transaction','--routines','--triggers','--events',
                            '--hex-blob','--set-gtid-purged=OFF','--no-tablespaces',self.database],stdout=output)
            with raw.open('rb') as source,gzip.open(path,'wb') as target: shutil.copyfileobj(source,target)
        finally: raw.unlink(missing_ok=True)

    def install_support(self):
        files=[('backup_baremetal_vps.py',Path('/usr/local/sbin/vwgm-baremetal-backup'),0o750),
               ('backup_baremetal_vps.py',APP/'scripts/backup_baremetal_vps.py',0o755),
               ('restore_new_vps.sh',APP/'scripts/restore_new_vps.sh',0o755),
               ('container-audit',Path('/usr/local/libexec/vwgm-admin/vulnerability-audit-root'),0o750),
               ('container-audit',Path('/opt/vwgm-security-monitor/container-audit'),0o750)]
        previous=self.stage/'previous-support'
        previous.mkdir(mode=0o700)
        for index,(name,target,mode) in enumerate(files):
            require(target.is_file() and not target.is_symlink(),f'onverwacht installatiepad:{target}')
            shutil.copy2(target,previous/str(index))
            temp=target.with_name(target.name+'.mysql974-new')
            require(not temp.exists() and not temp.is_symlink(),'tijdelijk installatiepad bestaat al')
            with temp.open('xb') as stream: stream.write((self.stage/name).read_bytes())
            os.chmod(temp,mode)
            os.replace(temp,target)
        # Record this bounded compatibility publication separately from app/data releases.
        (STATE/'mysql974-support.json').write_text((self.stage/'sources.json').read_text())
        os.chmod(STATE/'mysql974-support.json',0o644)
        root=Path('/opt/vwgm-security-monitor')
        sums=''.join(hashlib.sha256((root/name).read_bytes()).hexdigest()+'  '+str(root/name)+'\n'
                     for name in ['security_monitor.py','container-audit'])
        (root/'SHA256SUMS').write_text(sums)

    def verify_active(self,expected_inventory):
        require(self.inventory(ACTIVE)==expected_inventory,'actieve gegevenscontrole faalt')
        require(self.query(ACTIVE,'SELECT @@innodb_redo_log_capacity')=='536870912','redo is niet512MiB')
        info=self.inspect(ACTIVE)
        require(info['Image']==NEW_IMAGE,'actieve image wijkt af')
        for flag in ['-u','-g']:
            require(self.docker('exec',ACTIVE,'id',flag,'mysql').strip()=='1999','actieve UID/GID wijkt af')
        require(info['HostConfig']['PortBindings']=={'3306/tcp':[{'HostIp':'127.0.0.1','HostPort':'3307'}]},'poortbinding wijkt af')
        self.command(['/usr/local/libexec/vwgm-admin/check-caddy-mysql-isolation'])
        for host,path,code in [('www.vwg-m.nl','/welkom/index.asp','200'),
                               ('www.vwg-m.nl','/soorten/vogel.asp?id=90','200'),
                               ('www.vwg-m.nl','/leden/member-auth','401'),
                               ('app.vwg-m.nl','/shiny_meijendel/','401')]:
            result=self.command(['curl','--max-time','30','--silent','--show-error','--insecure','--output','/dev/null',
                                 '--write-out','%{http_code}','--resolve',host+':443:127.0.0.1','https://'+host+path])
            require(result.stdout.decode()==code,'rooktest faalde:'+host+path)
        self.docker('image','rm',CANDIDATE_TAG)
        with (self.stage/'active-scan.log').open('wb') as output:
            scan=self.command(['/bin/bash',self.stage/'container-audit'],check=False,timeout=1200,stdout=output)
        text=(self.stage/'active-scan.log').read_text()
        require(scan.returncode in (0,1) and not any(line.startswith(('URGENT|','BLOKKADE|')) for line in text.splitlines()),'actieve scan technisch onvolledig')
        for label in [ACTIVE,'shiny_meijendel']:
            require('SAMENVATTING|'+label+'|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0' in text,'actieve image niet0/0:'+label)
        for line in text.splitlines():
            if line.startswith('AANDACHT|'):
                require(line.startswith(('AANDACHT|container-image|'+ROLLBACK+'|',
                                         'AANDACHT|container-image|'+ROLLBACK_TAG.replace(':','-')+'|')),
                        'onverwachte aandachtregel in nacontrole')
        print('GROEN|mysql974-actief|versie=9.7.4|uid=1999|critical=0|high=0',flush=True)
        # Fresh full backup and temporary SQL restore must pass before success.
        with (self.stage/'backup-result.json').open('wb') as output:
            self.command(['/usr/local/sbin/vwgm-baremetal-backup'],stdout=output,timeout=3600)
        self.command([APP/'scripts/restore_check_backup.sh',BACKUP/'vwg-m-baremetal-latest.tar.gz'],timeout=1800)
        manifest=json.loads((BACKUP/'vwg-m-baremetal-latest-manifest.json').read_text())
        require(manifest['mysql_database']['validation']['status']=='ok','nieuw proefherstel niet groen')
        require(manifest['mysql_runtime']['version']=='9.7.4','nieuwe back-up bevat andere MySQL-versie')


def main(stage_path):
    os.umask(0o077)
    stage=Path(stage_path)
    require(os.geteuid()==0 and stage.parent==Path('/var/tmp') and stage.name.startswith('vwgm-mysql974-switch-root-'), 'alleen rootbootstrap toegestaan')
    require(stage.stat().st_uid==0 and stage.stat().st_mode&0o777==0o700,'rootbronmap niet beveiligd')
    require((STATE/'production.lock').is_dir(),'productieslot ontbreekt')
    require((STATE/'Meijendel.commit').read_text().strip()==DATA_COMMIT,'datarelease veranderd')
    sources=json.loads((stage/'sources.json').read_text())
    require((STATE/'VWG_M.commit').read_text().strip()==sources['production']['VWG_M'],'website-release veranderd')
    require((STATE/'security-monitor.commit').read_text().strip()==sources['production']['security-monitor'],'monitorrelease veranderd')
    for sig in (signal.SIGINT,signal.SIGTERM,signal.SIGHUP):
        signal.signal(sig,lambda number,frame: (_ for _ in ()).throw(InterruptedError('onderbroken')))
    manifest=CANDIDATE_ROOT/'manifest.json'
    require(not manifest.is_symlink() and manifest.stat().st_uid==0,'manifest niet rootbeheerd')
    validate_manifest(json.loads(manifest.read_text()),dt.datetime.now(dt.timezone.utc))
    runtime=Runtime(stage)
    old=runtime.inspect(ACTIVE)
    candidate=runtime.inspect(CANDIDATE)
    require(old['Image']==OLD_IMAGE and old['State']['Running'],'actieve uitgangsimage veranderd')
    require(candidate['Image']==NEW_IMAGE and candidate['State']['Status']=='exited' and candidate['State']['ExitCode']==0,'kandidaat niet schoon gestopt')
    for info,path in [(old,'/srv/vwgm/meijendel-mysql-971-uid1999/data'),(candidate,str(CANDIDATE_ROOT/'data'))]:
        require([m['Source'] for m in info['Mounts'] if m['Destination']=='/var/lib/mysql']==[path],'datamount wijkt af')
    require(set(runtime.docker('ps','-a','--format','{{.Names}}').splitlines())=={ACTIVE,'shiny_meijendel',CANDIDATE},'containerinventaris wijkt af')
    require(old['HostConfig']['RestartPolicy']['Name']=='unless-stopped','bronrestartbeleid wijkt af')
    require(old['HostConfig']['NetworkMode'] in ['default','bridge'],'bron heeft afwijkend netwerk')
    require(old['HostConfig']['Memory']==0 and old['HostConfig']['NanoCpus']==0,'bron heeft afwijkende resourcelimieten')
    require(len(old['Mounts'])==1 and len(candidate['Mounts'])==1,'extra bron- of kandidaatmounts aanwezig')
    require(runtime.query(ACTIVE,'SELECT @@global.read_only, @@global.super_read_only')=='0\t0','bron heeft afwijkende schrijfblokkade')
    backup_manifest=BACKUP/'vwg-m-baremetal-latest-manifest.json'
    previous=json.loads(backup_manifest.read_text())
    created=dt.datetime.fromisoformat(previous['created_at'])
    require(0 <= (dt.datetime.now(dt.timezone.utc)-created).total_seconds()<86400 and previous['mysql_database']['validation']['status']=='ok','verse gecontroleerde back-up ontbreekt')
    require(shutil.disk_usage('/srv').free>10*1024**3,'minder dan10GiBvrije schijfruimte')
    require(runtime.command(['systemctl','is-active','--quiet','vwg-m-baremetal-backup.service'],check=False).returncode!=0,'er loopt al een back-up')
    # Keep root-owned execution and all rollback evidence after Terminal disconnects.
    work=Path('/srv/vwgm/mysql974-switch-20261022')
    require(not work.exists(),'omschakeltaak bestaat al; eerst beoordelen')
    shutil.copytree(stage,work)
    os.chmod(work,0o700)
    runtime.stage=work
    runtime.install_support()
    readonly=runtime.query(ACTIVE,'SELECT @@global.super_read_only')=='1'
    frozen=False
    try:
        frozen=True # A disconnect can arrive just after SQL succeeds.
        runtime.query(ACTIVE,'SET GLOBAL super_read_only=ON')
        runtime.dump_source(work/'source-current.sql.gz')
        require(dump_hash(work/'source-current.sql.gz')==dump_hash(CANDIDATE_ROOT/'source.sql.gz'),'brongegevens veranderd sinds proef; opnieuw testen')
        runtime.docker('start',CANDIDATE)
        runtime.wait(CANDIDATE,'9.7.4')
        inventory=runtime.validate_candidate()
        runtime.docker('stop','--time','60',CANDIDATE)
        runtime.docker('rm',CANDIDATE)
        create=['create','--name',ACTIVE,'--restart','unless-stopped','--env-file','/srv/vwgm/meijendel-mysql/mysql.env',
                '-p','127.0.0.1:3307:3306','-v',str(CANDIDATE_ROOT/'data')+':/var/lib/mysql',NEW_IMAGE,
                '--local-infile=0','--mysqlx=0','--binlog-expire-logs-seconds=259200','--innodb-redo-log-capacity=536870912']
        state_record=STATE/'mysql-runtime.json'
        require(not state_record.is_symlink(),'runtimeverslag is een symlink')
        old_record=state_record.read_bytes() if state_record.exists() else None
        def atomic_record(path,content):
            temp=work/'runtime-record.tmp'
            with temp.open('wb') as stream:
                stream.write(content)
                stream.flush()
                os.fsync(stream.fileno())
            if path.parent==STATE: os.chmod(temp,0o644)
            os.replace(temp,path)
        def restore_record():
            rollback_report=dict(status='rolled-back',active_version='9.7.1',active_image=OLD_IMAGE,
                                 attempted_version='9.7.4',attempted_image=NEW_IMAGE,
                                 completed_at=dt.datetime.now(dt.timezone.utc).isoformat())
            atomic_record(work/'manifest.json',(json.dumps(rollback_report,indent=2)+'\n').encode())
            if old_record is None: state_record.unlink(missing_ok=True)
            else: atomic_record(state_record,old_record)
        def verify_and_record():
            runtime.verify_active(inventory)
            for name,commit in sources['production'].items():
                require((STATE/(name+'.commit')).read_text().strip()==commit,'geregistreerde release gewijzigd:'+name)
            record=dict(status='validated-active-runtime',version='9.7.4',image=NEW_IMAGE,data=str(CANDIDATE_ROOT/'data'),
                        rollback_container=ROLLBACK,rollback_image=OLD_IMAGE,rollback_data='/srv/vwgm/meijendel-mysql-971-uid1999/data',
                        sources=sources,completed_at=dt.datetime.now(dt.timezone.utc).isoformat())
            content=(json.dumps(record,indent=2)+'\n').encode()
            atomic_record(work/'manifest.json',content)
            atomic_record(state_record,content)
        perform_switch(runtime,create,readonly,verify_and_record,restore_record)
        frozen=False # original source remains stopped as the explicit rollback.
    finally:
        if frozen:
            for sig in (signal.SIGINT,signal.SIGTERM,signal.SIGHUP): signal.signal(sig,signal.SIG_IGN)
            runtime.docker('stop','--time','60',CANDIDATE,check=False)
            if not readonly:
                require(runtime.container_id(ACTIVE)==old['Id'],'bron niet actief; schrijfblokkadeherstel vereist handmatige beoordeling')
                runtime.query(ACTIVE,'SET GLOBAL super_read_only=OFF; SET GLOBAL read_only=OFF')
    print('GROEN|mysql974-omschakeling|productie=9.7.4|objects=305|checks=282|backup=groen|rollback=9.7.1|datarelease=ongewijzigd',flush=True)

if __name__=='__main__':
    try: main(sys.argv[1])
    except Exception as exc:
        print('BLOKKADE|mysql974-omschakeling|'+str(exc),file=sys.stderr)
        raise SystemExit(1)
