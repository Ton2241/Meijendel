#!/usr/bin/env python3
"""One immutable package and transaction boundary for all three consumers.

No SSH/network deployment. Database/service operations are supplied by an explicit
local adapter; the same activation, backup and recovery order is used everywhere.
"""
import contextlib,fcntl,hashlib,json,os,re,time
from pathlib import Path

SQL_SOURCE='data/meijendel.sql'
LEGACY_SQL_SOURCE='data/Meijendel.sql'
def sql_source(manifest):
    source=manifest.get('mysql',{}).get('source')
    if source not in (SQL_SOURCE,LEGACY_SQL_SOURCE):raise ValueError('Onbekende SQL-binding')
    return source
def existing_sql(directory):
    for name in ('meijendel.sql','Meijendel.sql'):
        path=Path(directory)/name
        if path.is_file():return path
    raise FileNotFoundError('meijendel.sql ontbreekt: '+str(directory))

def sha(path):
    with Path(path).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def safe_path(root,relative):
    root=Path(root).resolve();p=Path(relative)
    if p.is_absolute() or '..' in p.parts:raise ValueError('Onveilig relatief releasepad')
    cursor=root
    for part in p.parts:
        cursor=cursor/part
        if cursor.is_symlink():raise ValueError('Symlink in releasepad')
    path=(root/p).resolve()
    if not path.is_relative_to(root):raise ValueError('Releasepad verlaat pakket')
    return path

def atomic_json(path,value):
    path=Path(path);tmp=path.with_name(path.name+'.next');tmp.write_text(json.dumps(value,indent=2)+'\n');tmp.replace(path)

def verify(package):
    package=Path(package).resolve();m=json.loads((package/'release.json').read_text())
    if m.get('schema')!='meijendel-integral-release-v1' or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,99}',m.get('release_id','')):raise ValueError('Ongeldig releasecontract')
    if not m.get('files') or m.get('year_to',0)<m.get('year_from',9999):raise ValueError('Onvolledig releasecontract')
    if m.get('mode')=='production':
        if m.get('historical_cache_rehearsal') or any('999_local_' in x for x in m.get('cms',{}).get('migrations',[])):raise ValueError('Proefonderdeel in productierelease')
        if m.get('official_data_validated') is not True or set(m.get('components',[]))!={'website','dashboard','shiny','mysql','cms'}:raise ValueError('Productierelease mist validatie of component')
    elif m.get('mode')!='local_rehearsal':raise ValueError('Onbekende releasemodus')
    for relative,expected in m['files'].items():
        p=safe_path(package,relative)
        if p.is_symlink() or not p.is_file() or sha(p)!=expected:raise ValueError('Releasebestand ontbreekt of wijkt af: '+relative)
    for section,keys in (('mysql',('source','website_objects')),('cache',('root',))):
        if section not in m:continue
        for key in keys:
            relative=m[section].get(key)
            if not isinstance(relative,str) or relative not in m['files']:raise ValueError('Niet gecontroleerd runtimebestand')
            safe_path(package,relative)
        if section=='mysql' and m['files'][m[section]['source']]!=m['source_hash']:raise ValueError('SQL-bronhash wijkt af')
        if section=='cache' and m['files'][m[section]['root']]!=m[section]['sha256']:raise ValueError('Cachehash wijkt af')
    if 'bootstrap' in m:
        root=safe_path(package,m['bootstrap']['root']);b=json.loads((root/'manifest.json').read_text())
        if any(b.get(k)!=m[k] for k in ('year_from','year_to','source_hash')):raise ValueError('Bootstrapbron/jaargrens wijkt af')
        if sha(root/'manifest.json')!=m['bootstrap']['manifest_sha256']:raise ValueError('Bootstrapmanifest wijkt af')
        if b['html_sha256']!=m['bootstrap']['html_sha256'] or sha(root/'bootstrap.html')!=b['html_sha256']:raise ValueError('Bootstrapinhoud wijkt af')
    return m

@contextlib.contextmanager
def lock(root):
    root=Path(root);root.mkdir(parents=True,exist_ok=True)
    with (root/'activation.lock').open('a') as f:
        fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)
        try:yield
        finally:fcntl.flock(f,fcntl.LOCK_UN)

def set_current(root,package):
    root=Path(root).resolve();package=Path(package).resolve()
    if not package.is_relative_to(root/'releases'):raise ValueError('Kandidaat staat niet in deze releaseomgeving')
    tmp=root/'current.next'
    if tmp.is_symlink():tmp.unlink()
    tmp.symlink_to(package,target_is_directory=True);tmp.replace(root/'current')

def current(root):
    p=Path(root)/'current'
    return p.resolve(strict=True) if p.is_symlink() else None

def activate(root,package,hooks):
    root=Path(root).resolve();package=Path(package).resolve();m=verify(package)
    with lock(root):
        old=current(root)
        if old==package:
            hooks.health(package);return m
        backup=root/'backups'/f"{time.time_ns()}-{old.name if old else 'initial'}"
        backup.parent.mkdir(parents=True,exist_ok=True)
        journal=dict(attempted=m['release_id'],previous=old.name if old else None,phase='backup',backup=str(backup))
        atomic_json(root/'journal.json',journal)
        # Quiesce all consumers BEFORE the coordinated database snapshot/change.
        snapshot_complete=False
        try:
            hooks.stop()
            hooks.snapshot(backup)
            snapshot_complete=True
            journal['phase']='apply';atomic_json(root/'journal.json',journal)
            hooks.apply(package)
            set_current(root,package);hooks.start(package);hooks.health(package)
        except Exception as error:
            try:
                hooks.stop()
                if snapshot_complete:hooks.restore(backup)
                if old is not None:
                    set_current(root,old);hooks.start(old);hooks.health(old)
                elif (root/'current').is_symlink():
                    (root/'current').unlink()
            except Exception as recovery_error:
                try:hooks.stop()
                finally:
                    journal.update(phase='recovery_failed',error=str(error),recovery_error=str(recovery_error))
                    atomic_json(root/'journal.json',journal)
                raise RuntimeError('Activering en herstel mislukt; diensten gestopt; zie journal.json') from recovery_error
            journal.update(phase='restored',error=str(error));atomic_json(root/'journal.json',journal)
            raise
        journal['phase']='active';atomic_json(root/'journal.json',journal)
        atomic_json(root/'last_backup.json',{'package':str(old) if old else None,'backup':str(backup)})
        return m

def rollback(root,hooks):
    root=Path(root).resolve()
    with lock(root):
        saved=json.loads((root/'last_backup.json').read_text())
        if not saved.get('package'):raise ValueError('Geen vorige release beschikbaar')
        previous=Path(saved['package']).resolve();verify(previous)
        backup=Path(saved['backup']).resolve()
        if not backup.is_relative_to(root/'backups'):raise ValueError('Onveilig herstelpad')
        now=current(root);rescue=root/'backups'/f'{time.time_ns()}-before-rollback'
        try:
            hooks.stop()
            hooks.snapshot(rescue)
        except Exception as error:
            try:
                if now:hooks.start(now);hooks.health(now)
            except Exception as recovery_error:
                try:hooks.stop()
                finally:atomic_json(root/'journal.json',dict(phase='recovery_failed',error=str(error),recovery_error=str(recovery_error),backup=str(rescue)))
                raise RuntimeError('Herstart na backupfout mislukt; diensten gestopt; zie journal.json') from recovery_error
            atomic_json(root/'journal.json',dict(phase='rollback_snapshot_failed_restored',error=str(error),active=now.name if now else None))
            raise
        try:
            hooks.restore(backup);set_current(root,previous);hooks.start(previous);hooks.health(previous)
        except Exception as error:
            try:
                hooks.stop();hooks.restore(rescue)
                if now:set_current(root,now);hooks.start(now);hooks.health(now)
            except Exception as recovery_error:
                try:hooks.stop()
                finally:atomic_json(root/'journal.json',dict(phase='recovery_failed',error=str(error),recovery_error=str(recovery_error),backup=str(rescue)))
                raise RuntimeError('Terugzetten en herstel mislukt; diensten gestopt; zie journal.json') from recovery_error
            atomic_json(root/'journal.json',dict(phase='rollback_failed_restored',error=str(error),active=now.name if now else None))
            raise
        atomic_json(root/'journal.json',dict(phase='rolled_back',active=previous.name,restored_from=str(backup)))
        return previous

def build_package(recipe,target):
    """Assemble existing validated products, never recalculate or relabel data."""
    import shutil
    target=Path(target)
    if recipe['mode']=='local_rehearsal':
        # Imported lazily: the shared coordinator also runs on the production VPS.
        import sys
        sys.path.insert(0,str(Path.home()/'Documents/GitHub/VWG_Project/scripts'))
        from trial_storage import checked_tree
        target=checked_tree(target)
    repo=Path(recipe['analysis_root']);website=Path(recipe['website_root'])/'website/vwg-m-linux-app'
    initial=json.loads((Path(recipe['bootstrap_root'])/'manifest.json').read_text())
    if (initial['year_from'],initial['year_to'])!=(recipe['year_from'],recipe['year_to']):raise ValueError('Bootstrapjaargrenzen wijken af')
    if recipe['mode']=='production' and recipe.get('historical_cache_rehearsal'):raise ValueError('Historische proefcache is geen productiecache')
    if target.exists():raise ValueError('Gebruik een nieuw releasepad')
    target.mkdir(parents=True,mode=0o700)
    def copy(source,relative):
        source=Path(source);dest=safe_path(target,relative);dest.parent.mkdir(parents=True,exist_ok=True)
        if source.is_dir():
            if any(p.is_symlink() for p in source.rglob('*')):raise ValueError('Bronmap bevat een symlink: '+str(source))
            def ignored(path,names):
                result=set(shutil.ignore_patterns('__pycache__','*.pyc','.DS_Store','app_cache')(path,names))
                if relative=='website/app' and Path(path)==source:result.add('data')
                if relative=='website/app' and Path(path)==source/'static':result.add('uploads')
                return result
            shutil.copytree(source,dest,ignore=ignored)
        else:shutil.copy2(source,dest)
    for name in ('bmp_meijendel_index.html','bmp_meijendel_data_loader.js'):
        copy(repo/name,'www/'+name)
    (target/'www/index.html').write_text('<!doctype html><html lang="nl"><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=bmp_meijendel_index.html"><title>Vogeldata Meijendel</title><a href="bmp_meijendel_index.html">Open het dashboard</a></html>')
    for name in ('trim','trim_msi_evg','groepen_grafieken','wintertellingen','output_ecologische_groepen'):
        copy(repo/name,'www/'+name)
    frozen=Path(recipe['browser_root'])
    for name in ('bmp_meijendel_data.json','bmp_meijendel_data.json.manifest'):copy(frozen/name,'www/'+name)
    copy(recipe['bootstrap_root'],'www/outputs/bootstrap-presentatie-2026')
    copy(repo/'shiny_meijendel','shiny/shiny_meijendel');copy(repo/'R','shiny/R')
    copy(website/'app','website/app');copy(website/'sql','website/sql');copy(website/'scripts','website/scripts')
    for name in ('requirements.txt','requirements.lock','requirements-bootstrap.lock'):copy(website/name,'website/'+name)
    copy(recipe['sql'],SQL_SOURCE);copy(recipe['sql_manifest'],SQL_SOURCE+'.manifest')
    cache=Path(recipe['cache']);copy(cache,'data/cache/'+cache.name);copy(recipe['cache_manifest'],'data/cache/'+Path(recipe['cache_manifest']).name)
    copy(recipe['website_objects'],'data/website_objects.sql')
    if recipe.get('local_probe'):
        if recipe['mode']!='local_rehearsal':raise ValueError('Proefmigratie uitsluitend lokaal')
        probe=target/'website/sql/999_local_release_probe.sql'
        probe.write_text("CREATE TABLE IF NOT EXISTS app._release_probe(id integer primary key,value text); INSERT INTO app._release_probe VALUES(1,'"+recipe['release_id']+"') ON CONFLICT(id) DO UPDATE SET value=excluded.value;\n")
    boot=target/'www/outputs/bootstrap-presentatie-2026';b=json.loads((boot/'manifest.json').read_text())
    if sha(target/SQL_SOURCE)!=b['source_hash']:raise ValueError('SQL en bootstrap hebben een andere bron')
    if (b['year_from'],b['year_to'])!=(recipe['year_from'],recipe['year_to']):raise ValueError('Bootstrapjaargrenzen wijken af')
    public=dict(schema='meijendel-integral-release-v1',release_id=recipe['release_id'],mode=recipe['mode'],
        year_from=b['year_from'],year_to=b['year_to'],source_hash=b['source_hash'],presentation_approved=True,
        official_data_validated=recipe.get('official_data_validated',False),
        bootstrap=dict(root='outputs/bootstrap-presentatie-2026',html_sha256=b['html_sha256'],manifest_sha256=sha(boot/'manifest.json')))
    atomic_json(target/'www/release-config.json',public)
    m=public|dict(components=['website','dashboard','shiny','mysql','cms'],
        bootstrap=public['bootstrap']|dict(root='www/outputs/bootstrap-presentatie-2026'),
        cache=dict(root='data/cache/'+cache.name,sha256=sha(target/'data/cache'/cache.name)),
        mysql=dict(source=SQL_SOURCE,website_objects='data/website_objects.sql',database='Meijendel'),
        cms=dict(strategy='versioned_migrations',migrations=recipe.get('cms_migrations',[])),
        historical_cache_rehearsal=recipe.get('historical_cache_rehearsal',False),
        formal_intervals_released=False)
    m['files']={str(p.relative_to(target)):sha(p) for p in sorted(target.rglob('*')) if p.is_file()}
    atomic_json(target/'release.json',m);verify(target);return m


def main():
    import argparse
    p=argparse.ArgumentParser(description=__doc__)
    sub=p.add_subparsers(dest='action',required=True)
    b=sub.add_parser('build');b.add_argument('--recipe',type=Path,required=True);b.add_argument('--target',type=Path,required=True)
    v=sub.add_parser('verify');v.add_argument('package',type=Path)
    a=p.parse_args()
    if a.action=='build':m=build_package(json.loads(a.recipe.read_text()),a.target)
    else:m=verify(a.package)
    print(json.dumps({k:m[k] for k in ('release_id','mode','year_from','year_to','source_hash')},indent=2))
if __name__=='__main__':main()
