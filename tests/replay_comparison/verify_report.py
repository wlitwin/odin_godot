"""Check that real comparison receipts cannot pass after workload evidence is broken."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys,tempfile

source=Path(sys.argv[1]).resolve()
report=Path(__file__).with_name('report.py')
combat=json.loads((source/'contract.json').read_text())['scenario']=='combat_encounter'
checks=[]
cases= ['valid','extra_round','reload_not_exercised','empty_projectile_trace','wrong_input','reordered_trace','changed_binary']
if combat:cases+=['no_damage','wrong_loot','no_enemy_motion','missing_enemies','bad_frame_times','wrong_spawn','wrong_body_hp','changed_source','negative_sample']
for case in cases:
 with tempfile.TemporaryDirectory(prefix='replay-report-') as temporary:
  root=Path(temporary)
  for name in ['contract.json','build-manifest.json','framework-source.json','source-sha256.txt']:
   if (source/name).exists():shutil.copy2(source/name,root/name)
  if (source/'source-sha256.txt').exists():
   for line in (source/'source-sha256.txt').read_text().splitlines():
    _,name=line.split('  ',1);target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.symlink_to(source/name)
  for pair in source.glob('pair-*'):shutil.copytree(pair,root/pair.name)
  build=json.loads((root/'build-manifest.json').read_text())
  # The report only reads binaries. These links avoid duplicating large DLLs;
  # malformed-evidence cases modify copied receipts, never the linked binaries.
  for name in build['binaries']:
   path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.symlink_to(source/name)
  path=root/'pair-1/kit/host.json';data=json.loads(path.read_text());work=data['workload']
  if case=='extra_round':work['shots'][0]+=1
  if case=='reload_not_exercised':work['reload_entries'][0]=0
  if case=='empty_projectile_trace':
   for sample in work['observations']:sample['projectiles']=0
  if case=='wrong_input':work['inputs'][0]['fire']=False
  if case=='reordered_trace':work['observations'][2]['us']=work['observations'][0]['us']
  if case=='no_damage':work['combat']['damage']=[0,0]
  if case=='wrong_loot':work['combat']['scrap']=[0,0]
  if case=='no_enemy_motion':
   for sample in work['observations']:
    for enemy in sample['combat']['enemies']:enemy['x']=960;enemy['y']=544
  if case=='missing_enemies':work['combat']['unique_enemies']=0
  if case=='negative_sample':data['frame_us'][0]=-1
  if case=='bad_frame_times':data['frame_at_us']=[]
  if case=='wrong_spawn':
   for sample in work['observations']:
    for enemy in sample['combat']['enemies']:enemy['x']+=1000
  if case=='wrong_body_hp':
   for sample in work['observations']:
    for enemy in sample['combat']['enemies']:enemy['hp']=9
  if case=='changed_source':
   path_hash=root/'source-sha256.txt';rows=path_hash.read_text().splitlines();rows[0]='0'*64+rows[0][64:];path_hash.write_text('\n'.join(rows)+'\n')
  if case=='changed_binary':
   build['binaries'][next(iter(build['binaries']))]='0'*64
   (root/'build-manifest.json').write_text(json.dumps(build))
  path.write_text(json.dumps(data))
  result=subprocess.run([sys.executable,str(report),str(root)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,timeout=30)
  valid=case=='valid'
  assert (result.returncode==0)==valid,(case,result.stderr)
  assert (root/'summary.json').exists()==valid,case
  if not valid:assert 'AssertionError' in result.stderr,(case,result.stderr)
  checks.append({'case':case,'accepted':valid})
(source/'report-validation.json').write_text(json.dumps({'report_sha256':hashlib.sha256(report.read_bytes()).hexdigest(),'cases':checks},indent=2)+'\n')
print('REPLAY_COMPARISON_REPORT_VALIDATION_OK')
