"""Mutate captured evidence to exercise the loaded migration report gates."""
from pathlib import Path
import json,shutil,subprocess,sys,tempfile
source=Path(sys.argv[1]).resolve();raw_turn=json.loads((source/'browser/fault-plan.json').read_text()).get('transport_faults')=='turn_udp' if (source/'browser/fault-plan.json').exists() else False;report=Path(__file__).with_name('report.py');checks=[]
cases=['valid','inexact_restore','widened_rollback','excessive_loss','wrong_recovery_kind','two_authorities','no_new_action','world_mismatch','no_compression','credit_overflow','memory_overflow','stale_workload','no_faults','no_population','no_fire','no_layout','wrong_channel','hold_not_exercised','hold_wrong_duration','hold_early_release','hold_missing','hold_count_overflow','hold_queue_overflow','held_stale','held_credits','held_not_sampled']
projection=source/'browser/snapshot-contract.json'
private_history=projection.exists() and json.loads(projection.read_text())['private_history']
if private_history:cases+=['no_private_projection','large_public_snapshot','missing_codec_support','no_snapshot_delivery']
if not (source/'browser/hold-frontiers.json').exists():
 for case in ['held_stale','held_credits','held_not_sampled']:cases.remove(case)
if not (source/'browser/reliable-hold.json').exists():
 for case in ['hold_not_exercised','hold_wrong_duration','hold_early_release','hold_missing','hold_count_overflow','hold_queue_overflow']:cases.remove(case)
elif not (source/'browser/fault-plan.json').exists():
 for case in ['hold_early_release','hold_missing']:cases.remove(case)
for case in cases:
 with tempfile.TemporaryDirectory(prefix='loaded-migration-verify-') as tmp:
  root=Path(tmp)
  for p in source.iterdir():
   if p.name=='browser':shutil.copytree(p,root/p.name)
   elif p.name not in ('summary.json','report-validation.json'):(root/p.name).symlink_to(p,target_is_directory=p.is_dir())
  p=root/'browser/migration.json';d=json.loads(p.read_text())
  if case=='inexact_restore':d['winner']['restored_exact']=0
  if case=='widened_rollback':d['winner']['rollback_limit']=240
  if case=='excessive_loss':d['winner']['lost_ticks']=121
  if case=='wrong_recovery_kind':d['winner']['recovery_kind']=0
  if case=='two_authorities':d['final'][0]['authority']=d['final'][1]['authority']=1
  if case=='no_new_action':d['final'][0]['dashes']=d['before'][1]['dashes']
  if case=='world_mismatch':d['hashes'][1][d['common'][0]]='0'
  if case=='wrong_channel':d['before'][0]['capture_channel']=1
  if case=='no_layout':d['before'][1]['layout_archives']=0
  if case=='no_population':d['before'][0]['living']=0
  if case=='no_fire':d['before'][0]['spent1']=d['resumed'][0]['spent1']
  if case=='no_compression':d['before'][0]['wire_bytes']=0
  p.write_text(json.dumps(d))
  if case in ['no_private_projection','large_public_snapshot','missing_codec_support','no_snapshot_delivery']:
   q=root/'browser/snapshot-contract.json';v=json.loads(q.read_text())
   if case=='no_private_projection':v['initial'][0]['public_excluded_fields']=0
   if case=='large_public_snapshot':v['initial'][0]['public_snapshot_bytes']=v['initial'][0]['raw_bytes']
   if case=='missing_codec_support':v['initial'][0]['snapshot_shuffle_available']=0
   if case=='no_snapshot_delivery':v['initial'][0]['deltasnaps']=0
   q.write_text(json.dumps(v))
  p=root/'browser/telemetry.json';d=json.loads(p.read_text())
  if case=='credit_overflow':d[0]['credit_u']=17
  if case=='memory_overflow':d[0]['assembly_bytes']=d[0]['assembly_limit']+1
  p.write_text(json.dumps(d))
  if case=='stale_workload':
   p=root/'browser/success-client.json';d=json.loads(p.read_text());d['trace'][10]['facts_ahead']=31;p.write_text(json.dumps(d))
  if case=='no_faults':
   p=root/('browser/turn-network.json' if raw_turn else 'browser/terminal-client.json');d=json.loads(p.read_text())
   if raw_turn:d['pass']=False
   else:d['fault']['loss']=0
   p.write_text(json.dumps(d))
  if case in ['held_stale','held_credits','held_not_sampled']:
   p=root/'browser/hold-frontiers.json';d=json.loads(p.read_text())
   if case=='held_stale':d[-1]['states'][1]['facts']=d[-1]['states'][1]['head']+31
   if case=='held_credits':d[-1]['states'][1]['credit_r']=17
   if case=='held_not_sampled':d=d[:1]
   p.write_text(json.dumps(d))
  if case=='hold_count_overflow':
   p=root/'browser/reliable-hold.json';d=json.loads(p.read_text());d['held']=129;p.write_text(json.dumps(d))
  if case=='hold_queue_overflow':
   p=root/'browser/reliable-hold.json';d=json.loads(p.read_text());d['queuedBytes']=65537;p.write_text(json.dumps(d))
  if case=='hold_wrong_duration':
   p=root/'browser/reliable-hold.json';d=json.loads(p.read_text());d['milliseconds']+=1;p.write_text(json.dumps(d))
  if case=='hold_early_release':
   p=root/'browser/reliable-hold.json';d=json.loads(p.read_text());d['elapsedMs']=0;d['heldForMs']=0;p.write_text(json.dumps(d))
  if case=='hold_missing':(root/'browser/reliable-hold.json').unlink()
  if case=='hold_not_exercised':
   p=root/'browser/reliable-hold.json';d=json.loads(p.read_text());d['held']=0;p.write_text(json.dumps(d))
  run=subprocess.run([sys.executable,str(report),str(root)],text=True,capture_output=True)
  assert (run.returncode==0)==(case=='valid'),(case,run.stdout,run.stderr)
  if case!='valid':assert 'AssertionError' in run.stderr,(case,run.stderr)
  checks.append({'case':case,'accepted':run.returncode==0})
(source/'report-validation.json').write_text(json.dumps(checks,indent=2)+'\n');print('LOADED_MIGRATION_REPORT_CHECKS_OK cases='+str(len(checks)))
