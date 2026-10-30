"""Reject broken workload/provenance evidence without mutating the real run."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys,tempfile
source=Path(sys.argv[1]).resolve();report=Path(__file__).with_name('report.py');checks=[]
condition=sys.argv[2] if len(sys.argv)>2 else None
assert condition in (None,'delay','lossy')
controlled=json.loads((source/'run-plan.json').read_text()).get('owner_control',False)
cases=['bad_dash_outcome','valid','sent_but_prediction_rejected','partial_plan','short_window','unsettled_warmup','stale_authority','falling_population','no_shots','no_kills','no_motion','missing_body','bad_health','bad_loot','bad_final','wrong_input','reordered_trace','negative_sample','missing_frame_times','changed_binary','changed_source','runtime_error','no_player_motion','wrong_movement','bad_move_time','no_casts','bad_cast_time','no_rally','no_chill','bad_cooldowns','bad_player_hp','wrong_abilities','no_burn','no_salve','no_surge','no_hp_loss','no_hp_recovery','no_reloads','no_dash_work','no_dash_intent','no_hazard_intent','bad_hazard_time','missing_proxy','bad_proxy_config','unreadable_final','unavailable_too_long','dead_final_player','wrong_action_policy','missing_cast_receipt','unsent_cast_receipt','wrong_receipt_model','reused_cast_sequence','changed_jam_salt','bad_fired_count','missing_jam_exposure','bad_jam_pulls','bad_clear_pulls','bad_final_taps']
reuse_enabled=json.loads((source/'run-plan.json').read_text()).get('correction_reuse',False)
if reuse_enabled:cases+=['undeclared_reuse','negative_reuse_count']
if 'snapshot_every' in json.loads((source/'run-plan.json').read_text()):cases+=['wrong_snapshot_interval']
if controlled:cases+=['missing_control_provenance','undeclared_control','wrong_control_root','bad_repair_hash','owner_rewind']
if condition=='delay':cases=[c for c in cases if c not in ('missing_proxy','bad_proxy_config')]
for case in cases:
 with tempfile.TemporaryDirectory(prefix='replay-jam-report-') as temporary:
  root=Path(temporary)
  for name in ['contract.json','build-manifest.json','framework-source.json','source-sha256.txt','run-plan.json']:shutil.copy2(source/name,root/name)
  if condition:
   p=root/'run-plan.json';plan=json.loads(p.read_text());plan['conditions']=[condition];p.write_text(json.dumps(plan))
  if controlled:
   for name in ['owner-control.json','kit-framework-source.json']:shutil.copy2(source/name,root/name)
  for line in (source/'source-sha256.txt').read_text().splitlines():
   _,name=line.split('  ',1);target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.symlink_to(source/name)
  for captured_condition in ('delay','lossy'):
   if (source/captured_condition).exists():shutil.copytree(source/captured_condition,root/captured_condition)
  for impl in ('kit','replay'):shutil.copy2(source/impl/'endurance-fixture.json',root/impl/'endurance-fixture.json')
  shutil.copy2(source/'replay/action-policy.json',root/'replay/action-policy.json')
  build=json.loads((root/'build-manifest.json').read_text())
  for name in build['binaries']:
   target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.symlink_to(source/name)
  path=root/'delay/pair-1/kit/success-host.json';data=json.loads(path.read_text());trace=data['trace']
  if case=='wrong_snapshot_interval':
   p=root/'delay/pair-1/replay/success-host.json';m=json.loads(p.read_text());m['snapshot_every']+=1;p.write_text(json.dumps(m))
  if case=='undeclared_reuse':
   p=root/'run-plan.json';m=json.loads(p.read_text());m['correction_reuse']=False;p.write_text(json.dumps(m))
  if case=='negative_reuse_count':
   p=root/'delay/pair-1/replay/success-client.json';m=json.loads(p.read_text());m['trace'][10]['reused']=-1;p.write_text(json.dumps(m))
  if case=='missing_control_provenance':(root/'owner-control.json').unlink()
  if case=='undeclared_control':
   p=root/'run-plan.json';m=json.loads(p.read_text());m['owner_control']=False;p.write_text(json.dumps(m))
  if case=='wrong_control_root':
   p=root/'build-manifest.json';m=json.loads(p.read_text());m['collections']['kit']=m['collections']['replay'];p.write_text(json.dumps(m))
  if case=='bad_repair_hash':
   p=root/'owner-control.json';m=json.loads(p.read_text());m['after_sha256']='0'*64;p.write_text(json.dumps(m))
  if case=='owner_rewind':
   p=root/'delay/pair-1/kit/success-client.json';m=json.loads(p.read_text());s=next(s for s in m['trace'] if 400000<s['us']<700000);s['people'][1]['y']-=20;p.write_text(json.dumps(m))
  if case=='partial_plan':
   p=root/'run-plan.json';plan=json.loads(p.read_text());plan['repetitions']=2;p.write_text(json.dumps(plan))
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
   other=root/'delay/pair-1/kit/success-client.json';client=json.loads(other.read_text());client['final']['spent'][0]+=1;other.write_text(json.dumps(client))
  if case=='no_player_motion':
   for sample in trace:
    for person in sample['people']:person['x']=840;person['y']=544
  if case=='wrong_movement':data['movement'][0]['direction']=[0,0]
  if case=='bad_move_time':data['movement'][0]['us']=900000
  if case=='sent_but_prediction_rejected':
   p=root/'delay/pair-1/kit/success-client.json';m=json.loads(p.read_text());m['cast_receipts'][0].update(state=0,reason=5);p.write_text(json.dumps(m))
  if case=='missing_cast_receipt':data['cast_receipts']=[]
  if case=='unsent_cast_receipt':data['cast_receipts'][0].update(sequence=0,state=0,reason=5,submitted=0)
  if case=='wrong_receipt_model':data['cast_receipts'][0]['model']=1
  if case=='reused_cast_sequence':
   p=root/'delay/pair-1/kit/success-client.json';m=json.loads(p.read_text());m['cast_receipts'][1]['sequence']=m['cast_receipts'][0]['sequence'];p.write_text(json.dumps(m))
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
  if case in ('no_burn','no_salve','no_surge'):
   for sample in trace:
    for person in sample['people']:person[case[3:]]=0
  if case in ('no_hp_loss','no_hp_recovery'):
   for sample in trace:
    for person in sample['people']:person['hp']=10 if case=='no_hp_loss' else 4
  if case=='no_reloads':
   for sample in trace:
    for person in sample['people']:person['mode']=0
  if case=='no_dash_work':
   for sample in trace:
    for person in sample['people']:person['dashes']=0
  if case=='changed_jam_salt':trace[10]['people'][0]['salt']^=1
  if case=='bad_fired_count':trace[10]['people'][0]['shots']+=1
  if case=='missing_jam_exposure':
   for sample in trace:
    for person in sample['people']:person['mode']=0;person['taps']=0
  if case=='bad_jam_pulls':data['final_guns'][0]['pulls'][2]+=1
  if case=='bad_clear_pulls':data['final_guns'][0]['pulls'][4]+=1
  if case=='bad_final_taps':data['final_guns'][0]['mode']=2;data['final_guns'][0]['taps']=0
  if case=='wrong_action_policy':
   p=root/'replay/action-policy.json';value=json.loads(p.read_text());value['policy']='Scheduled';p.write_text(json.dumps(value))
  if case=='dead_final_player':data['final']['hp']=[0,0]
  if case=='unreadable_final':data['final_ready']=False
  if case=='unavailable_too_long':trace[3]={'ready':False,'us':trace[3]['us'],'resyncs':1,'reason':1}
  if case=='bad_dash_outcome':
   p=root/'delay/pair-1/replay/success-client.json';m=json.loads(p.read_text());m['dash_receipts']['confirmed']=9;p.write_text(json.dumps(m))
  if case=='no_dash_intent':data['dashes']=[]
  if case=='no_hazard_intent':data['hazards']=[]
  if case=='bad_hazard_time':data['hazards'][0]['us']=0
  if case=='missing_proxy':(root/'lossy/pair-1/kit/proxy/receipt.json').unlink()
  if case=='bad_proxy_config':
   p=root/'lossy/pair-1/kit/proxy/receipt.json';value=json.loads(p.read_text());value['config']['loss']=0;p.write_text(json.dumps(value))
  if case=='runtime_error':
   p=root/'delay/pair-1/kit/host.log';p.write_text(p.read_text()+'\nERROR: injected\n')
  path.write_text(json.dumps(data))
  run=subprocess.run([sys.executable,str(report),str(root)]+(['--allow-partial'] if condition else []),text=True,capture_output=True,timeout=30)
  valid=case in ('valid','sent_but_prediction_rejected');assert (run.returncode==0)==valid,(case,run.stderr)
  assert (root/'summary.json').exists()==valid,case
  if not valid:assert ('AssertionError' in run.stderr or case in ('missing_control_provenance','missing_proxy') and 'FileNotFoundError' in run.stderr),(case,run.stderr)
  checks.append({'case':case,'accepted':valid})
(source/('report-validation-'+condition+'.json' if condition else 'report-validation.json')).write_text(json.dumps({'report_sha256':hashlib.sha256(report.read_bytes()).hexdigest(),'cases':checks},indent=2)+'\n')
print('REPLAY_JAM_REPORT_VALIDATION_OK cases='+str(len(checks)))
