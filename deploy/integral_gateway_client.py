#!/usr/bin/env python3
"""Prepare and run one integral release through the existing bounded gateway.

No model fits. Preparation is local; the isolated Linux rehearsal is explicit.
Installing gateway code requires the visible standard macOS Terminal window.
"""
import argparse,importlib.util,json,os,secrets,shlex,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('core',ROOT/'deploy/integral_release.py');core=importlib.util.module_from_spec(spec);spec.loader.exec_module(core)

def run(args,**kw):return subprocess.run([str(x) for x in args],check=True,**kw)
def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args],text=True).strip()
def check_checkout(root):
 if git(root,'branch','--show-current')!='main' or git(root,'status','--porcelain') or git(root,'rev-parse','HEAD')!=git(root,'rev-parse','origin/main'):raise ValueError('Alleen schone actuele main: '+str(root))
 return git(root,'rev-parse','HEAD')

def prepare(recipe_file,baseline,output,project):
 recipe=json.loads(recipe_file.read_text());analysis=Path(recipe['analysis_root']);website=Path(recipe['website_root'])
 commits={name:check_checkout(path) for name,path in [('Meijendel',analysis),('VWG_M',website),('VWG_Project',project)]}
 if output.exists():raise ValueError('Nieuw uitvoerpad vereist')
 output.mkdir(parents=True,mode=0o700)
 trial=recipe['mode']=='local_rehearsal'
 if trial and (baseline is None or recipe['year_to']>2025):raise ValueError('Historische Linux-proef vraagt de bewaarde basisbeoordeling tot2025')
 recipe=recipe|dict(local_probe=False,cms_migrations=[],release_id='candidate-'+commits['Meijendel'][:12]) if trial else recipe
 if not trial:
  run(['bash',analysis/'scripts/validate_meijendel_export.sh',recipe['sql'],recipe['sql_manifest']])
 manifest=core.build_package(recipe,output/'payload')
 receipt=dict(schema='meijendel-integral-gateway-v1',intent='isolated_trial' if trial else 'production',commits=commits,source_hash=manifest['source_hash'],year_to=manifest['year_to'],canonical_export_validated=not trial)
 core.atomic_json(output/'receipt.json',receipt)
 archive=output/'payload.tar.gz'
 with tarfile.open(archive,'w:gz',compresslevel=1) as tar:
  tar.add(output/'payload',arcname='payload');tar.add(output/'receipt.json',arcname='receipt.json')
  if trial:tar.add(baseline,arcname='baseline-bootstrap')
 prepared=dict(schema='meijendel-integral-prepared-v1',commits=commits,recipe=recipe,project_root=str(project),archive=str(archive),sha256=core.sha(archive),intent=receipt['intent'])
 core.atomic_json(output/'prepared.json',prepared)
 print('PREPARED='+str(output/'prepared.json'),flush=True)
 return output/'prepared.json'

def execute(prepared_file,stage,install=False,yes=False):
 p=json.loads(prepared_file.read_text());analysis=Path(p['recipe']['analysis_root']);website=Path(p['recipe']['website_root']);project=Path(p['project_root']);out=prepared_file.parent
 for name,path in [('Meijendel',analysis),('VWG_M',website),('VWG_Project',project)]:
  if check_checkout(path)!=p['commits'][name]:raise ValueError('Broncommit veranderd sinds pakketbouw: '+name)
 if core.sha(p['archive'])!=p['sha256']:raise ValueError('Lokaal pakket gewijzigd')
 if stage in ('apply','rollback') and (p['intent']!='production' or not yes):raise ValueError('Productieactie vraagt een productiepak en --yes')
 if install:
  if not os.isatty(0) or os.getenv('TERM_PROGRAM')!='Apple_Terminal':raise ValueError('Start installatie zelf in het standaard macOS Terminal-venster')
  env=os.environ|dict(VWG_M_DIR=str(website),MEIJENDEL_DIR=str(analysis))
  run(['bash',project/'scripts/install_vwgm_admin_gateway_vps.sh','--apply','--yes'],env=env)
 key=Path.home()/'.ssh/vwgm_spectraip_ed25519';target='ton@45.87.43.90';commit=p['commits']['Meijendel'];digest=p['sha256']
 run(['/opt/homebrew/bin/rsync','-a','--partial','--append-verify','-e',shlex.join(['ssh','-i',str(key)]),p['archive'],target+':/srv/vwgm/deploy-state/integral-inbox/'+commit+'.tar.gz'])
 def gateway(operation):
  # A reconnect reuses its saved operation ID, never starts another import.
  operations=out/'operations.json';saved=json.loads(operations.read_text()) if operations.exists() else {}
  item=saved.get(operation);env=os.environ|dict(GATEWAY_ACTION='meijendel-integral')
  env.pop('GATEWAY_OPERATION_ID',None);env.pop('GATEWAY_NEW_OPERATION_ID',None)
  if item and item['state']=='complete':return (out/(operation+'.log')).read_text()
  if item and item['state']=='failed':raise RuntimeError('Vorige fase is definitief mislukt; beoordeel '+str(out/(operation+'.log'))+' voordat een nieuwe operatie wordt gemaakt')
  if item:env['GATEWAY_OPERATION_ID']=item['id']
  else:
   item=dict(id=secrets.token_hex(16),state='pending');saved[operation]=item;core.atomic_json(operations,saved);env['GATEWAY_NEW_OPERATION_ID']=item['id']
  print('GATEWAY_STAGE='+operation+' operation='+item['id'],flush=True)
  with (out/(operation+'.log')).open('w') as log:
   result=subprocess.run(['bash',str(analysis/'deploy/run_gateway_job_vps.sh'),operation,commit,digest],env=env,stdout=log,stderr=log)
  if result.returncode and 'GATEWAY_JOB_STATUS=' in (out/(operation+'.log')).read_text():
   item['state']='failed';core.atomic_json(operations,saved)
  if result.returncode:raise RuntimeError('Gatewayfase '+operation+' niet voltooid; log='+str(out/(operation+'.log'))+'; hervat dezelfde operatie '+item['id'])
  item['state']='complete';core.atomic_json(operations,saved);return (out/(operation+'.log')).read_text()
 if stage in ('rehearse','apply'):
  text=gateway('preflight');response=next(json.loads(line) for line in text.splitlines() if line.startswith('{') and 'production_commits' in line)
  for name,old in response['production_commits'].items():
   path=analysis if name=='Meijendel' else website
   run(['git','-C',path,'merge-base','--is-ancestor',old,p['commits'][name]])
 text=gateway(stage)
 if stage=='rehearse':
  evidence=next(json.loads(line) for line in text.splitlines() if line.startswith('{') and 'meijendel-integral-linux-proof-v1' in line)
  if not evidence.get('success') or evidence['production_before']!=evidence['production_after']:raise ValueError('Geen groene onveranderde productie-identiteit')
  core.atomic_json(out/'linux-proof.json',evidence);gateway('cleanup')
 print('KLAAR — '+stage+' via gesloten gateway; '+('productie-inhoud niet gepubliceerd' if p['intent']=='isolated_trial' else 'controleer geregistreerde release'),flush=True)


def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--recipe',type=Path);a.add_argument('--baseline-bootstrap',type=Path);a.add_argument('--output',type=Path);a.add_argument('--project-root',type=Path);a.add_argument('--prepared',type=Path);a.add_argument('--stage',choices=['prepare','preflight','rehearse','apply','rollback','cleanup'],default='prepare');a.add_argument('--install-gateway',action='store_true');a.add_argument('--yes',action='store_true');args=a.parse_args()
 if args.stage=='prepare':
  if not all([args.recipe,args.output,args.project_root]):a.error('prepare vraagt recipe, output en project-root')
  prepare(args.recipe,args.baseline_bootstrap,args.output,args.project_root)
 else:
  if not args.prepared:a.error('prepared ontbreekt')
  execute(args.prepared,args.stage,args.install_gateway,args.yes)
if __name__=='__main__':main()
