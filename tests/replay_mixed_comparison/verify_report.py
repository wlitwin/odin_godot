"""Reject broken workload/provenance evidence without mutating the real run."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys,tempfile
source=Path(sys.argv[1]).resolve();report=Path(__file__).with_name('report.py');checks=[]
controlled=json.loads((source/'run-plan.json').read_text()).get('owner_control',False)
cases=['valid','partial_plan','short_window','unsettled_warmup','stale_authority','falling_population','no_shots','no_kills','no_motion','missing_body','bad_health','bad_loot','bad_final','wrong_input','reordered_trace','negative_sample','missing_frame_times','changed_binary','changed_source','runtime_error','no_player_motion','wrong_movement','bad_move_time','no_casts','bad_cast_time','no_rally','no_chill','bad_cooldowns','bad_player_hp','wrong_abilities']
reuse_enabled=json.loads((source/'run-plan.json').read_text()).get('correction_reuse',False)
if reuse_enabled:cases+=['undeclared_reuse','negative_reuse_count']
if controlled:cases+=['missing_control_provenance','undeclared_control','wrong_control_root','bad_repair_hash','owner_rewind']
for case in cases:
 with tempfile.TemporaryDirectory(prefix='replay-mixed-report-') as temporary:
  root=Path(temporary)
  for name in ['contract.json','build-manifest.json','framework-source.json','source-sha256.txt','run-plan.json']:shutil.copy2(source/name,root/name)
  if controlled:
   for name in ['owner-control.json','kit-framework-source.json']:shutil.copy2(source/name,root/name)
  for line in (source/'source-sha256.txt').read_text().splitlines():
   _,name=line.split('  ',1);target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.symlink_to(source/name)
  for pair in source.glob('pair-*'):shutil.copytree(pair,root/pair.name)
  build=json.loads((root/'build-manifest.json').read_text())
  for name in build['binaries']:
   target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.symlink_to(source/name)
  path=root/'pair-1/kit/success-host.json';data=json.loads(path.read_text());trace=data['trace']
  if case=='undeclared_reuse':
   p=root/'run-plan.json';m=json.loads(p.read_text());m['correction_reuse']=False;p.write_text(json.dumps(m))
  if case=='negative_reuse_count':
   p=root/'pair-1/replay/success-client.json';m=json.loads(p.read_text());m['trace'][10]['reused']=-1;p.write_text(json.dumps(m))
  if case=='missing_control_provenance':(root/'owner-control.json').unlink()
  if case=='undeclared_control':
   p=root/'run-plan.json';m=json.loads(p.read_text());m['owner_control']=False;p.write_text(json.dumps(m))
  if case=='wrong_control_root':
   p=root/'build-manifest.json';m=json.loads(p.read_text());m['collections']['kit']=m['collections']['replay'];p.write_text(json.dumps(m))
  if case=='bad_repair_hash':
   p=root/'owner-control.json';m=json.loads(p.read_text());m['after_sha256']='0'*64;p.write_text(json.dumps(m))
  if case=='owner_rewind':
   p=root/'pair-1/kit/success-client.json';m=json.loads(p.read_text());s=next(s for s in m['trace'] if 400000<s['us']<700000);s['people'][1]['y']-=20;p.write_text(json.dumps(m))
  if case=='partial_plan':(root/'run-plan.json').write_text('{"repetitions":1}')
  if case=='unsettled_warmup':data['warmup']['facts_ahead']=40
  if case=='short_window':data['elapsed_us']=3000000
  if case=='stale_authority':trace[10]['facts_ahead']=40
  if case=='falling_population':trace[-1]['living']=20
  if case=='no_shots':trace[-1]['spent']=[0,0]
  if case=='no_kills':trace[-1]['kills']=[0,0]
  if case=='no_motion':
   for sample in trace:
    for enemy in sample['enemies']:enemy['x']=960;enemy['y']=544
  if case=='missing_body':
   trace[10]['enemies'].pop();trace[10]['living']=sum(e['hp']>0 for e in trace[10]['enemies'])
  if case=='bad_health':trace[10]['damage'][0]+=1
  if case=='bad_loot':trace[10]['loot']+=1
  if case=='bad_final':
   other=root/'pair-1/kit/success-client.json';client=json.loads(other.read_text());client['final']['spent'][0]+=1;other.write_text(json.dumps(client))
  if case=='no_player_motion':
   for sample in trace:
    for person in sample['people']:person['x']=840;person['y']=544
  if case=='wrong_movement':data['movement'][0]['direction']=[0,0]
  if case=='bad_move_time':data['movement'][0]['us']=900000
  if case=='no_casts':data['cast_sent']=[0,0]
  if case=='bad_cast_time':data['casts'][0]['us']=0
  if case=='no_rally':
   for sample in trace:
    for person in sample['people']:person['rally']=0
  if case=='no_chill':
   for sample in trace:sample['chilled']=0
  if case=='bad_cooldowns':
   for sample in trace:
    for person in sample['people']:person['cd']=[0,0]
  if case=='bad_player_hp':trace[10]['people'][0]['hp']=0
  if case=='wrong_abilities':trace[10]['people'][0]['loadout']=0
  if case=='wrong_input':data['inputs'][0]['fire']=False
  if case=='reordered_trace':trace[2]['us']=trace[0]['us']
  if case=='negative_sample':data['frame_us'][0]=-1
  if case=='missing_frame_times':data['frame_at_us']=[]
  if case=='changed_binary':
   build['binaries'][next(iter(build['binaries']))]='0'*64;(root/'build-manifest.json').write_text(json.dumps(build))
  if case=='changed_source':
   p=root/'source-sha256.txt';rows=p.read_text().splitlines();rows[0]='0'*64+rows[0][64:];p.write_text('\n'.join(rows)+'\n')
  if case=='runtime_error':
   p=root/'pair-1/kit/host.log';p.write_text(p.read_text()+'\nERROR: injected\n')
  path.write_text(json.dumps(data))
  run=subprocess.run([sys.executable,str(report),str(root)],text=True,capture_output=True,timeout=30)
  valid=case=='valid';assert (run.returncode==0)==valid,(case,run.stderr)
  assert (root/'summary.json').exists()==valid,case
  if not valid:assert ('AssertionError' in run.stderr or case=='missing_control_provenance' and 'FileNotFoundError' in run.stderr),(case,run.stderr)
  checks.append({'case':case,'accepted':valid})
(source/'report-validation.json').write_text(json.dumps({'report_sha256':hashlib.sha256(report.read_bytes()).hexdigest(),'cases':checks},indent=2)+'\n')
print('REPLAY_MIXED_REPORT_VALIDATION_OK cases='+str(len(checks)))
