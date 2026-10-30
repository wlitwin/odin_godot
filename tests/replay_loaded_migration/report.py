from pathlib import Path
import hashlib,json,os,sys,tempfile
root=Path(sys.argv[1]).resolve();repo=Path(__file__).resolve().parents[2];sys.path.insert(0,str(repo/'tests/replay_jam_comparison'))
from workload import validate_condition
contract=json.loads((root/'contract.json').read_text());assert contract==json.loads((repo/'tests/replay_jam_comparison/contract.json').read_text())
for line in (root/'source-sha256.txt').read_text().splitlines():
 h,name=line.split('  ',1);assert hashlib.sha256((root/name).read_bytes()).hexdigest()==h,('source',name)
framework=json.loads((root/'framework-source.json').read_text())
framework_root=Path(os.environ.get('REPLAY_SOURCE_ROOT',framework['root']))
for name,h in framework['sha256'].items():assert hashlib.sha256((framework_root/name).read_bytes()).hexdigest()==h,('framework',name)
build=json.loads((root/'browser-build.json').read_text())
for name,h in build['binaries'].items():assert hashlib.sha256((root/name).read_bytes()).hexdigest()==h,('binary',name)
with tempfile.TemporaryDirectory(prefix='loaded-migration-workload-') as tmp:
 view=Path(tmp);(view/'delay/pair-1').mkdir(parents=True);(view/'delay/pair-1/replay').symlink_to(root/'browser',target_is_directory=True)
 rows=validate_condition(view,contract,{'repetitions':1,'snapshot_every':3},['replay'],{'enabled':False},'delay',None)
d=json.loads((root/'browser/migration.json').read_text());winner=d['winner'];before=d['before'];final=d['final']
assert d['mode'] in ('planned','crash') and len(before)==len(final)==2
assert all(x['epoch']==1 and x['ready']==1 and x['rollback_limit']==120 for x in before)
assert before[0]['authority']==1 and before[1]['authority']==0
assert before[0]['capture_channel']==0 and before[1]['reply_reliable']==1
assert all(x['layout_archives']>0 for x in before) and before[0]['layout_saved']>0
assert len(d['resumed'])==2
assert all(32<=x['living']<=44 and x['spent1']>d['resumed'][i]['spent1'] and x['spent2']>d['resumed'][i]['spent2'] for i,x in enumerate(before))
assert 0<before[0]['wire_bytes']<before[0]['raw_bytes'] and before[1]['prepared_bytes']>0
assert winner['restored_exact']==winner['authority']==winner['recovery_ready']==1 and winner['epoch']==2 and winner['rollback_limit']==120 and winner['seat']==2
assert winner['recovery_kind']==(1 if d['mode']=='planned' else 2) and 0<=winner['lost_ticks']<=120
if d['mode']=='planned':assert winner['lost_ticks']==0 and winner['recovery_tick']>=before[0]['head']
else:assert winner['recovery_tick']>=before[1]['prepared_tick']
assert 0<d['elapsed_ms']<60000
assert len(d['common'])>=10 and len(set(d['common']))==len(d['common']) and len(d['hashes'])==2
assert all(all(h[k]==d['hashes'][0][k] for h in d['hashes']) for k in d['common'])
assert sum(x['authority'] for x in final)==1 and sorted(x['seat'] for x in final)==[1,2]
assert all(x['epoch']==2 and x['ready']==1 and x['dashes']>before[1]['dashes'] and x['dash_pending']==0 for x in final)
telemetry=json.loads((root/'browser/telemetry.json').read_text())
assert len(telemetry)>=20 and all(row['credit_r']<=16 and row['credit_u']<=16 and row['assembly_bytes']<=row['assembly_limit'] and row['rtc_failed']==0 and row['queue_limit']==8 for row in telemetry)
plan_path=root/'browser/fault-plan.json'
plan=json.loads(plan_path.read_text()) if plan_path.exists() else None
raw_turn=plan is not None and plan.get('transport_faults')=='turn_udp'
for role in ('client','returned' if d['mode']=='crash' else 'host'):
 terminal=json.loads((root/f'browser/terminal-{role}.json').read_text());fault=terminal['fault']
 assert fault['capacity']==0 and not fault['errors'] and fault['maxQueuedBytes']<=65536 and fault['maxQueuedPackets']<=128
 if raw_turn:
  assert not fault['enabled'] and fault['loss']==fault['duplicate']==0 and all(fault['config'][k]==0 for k in ['delay','jitter','loss','duplicate'])
 elif role!='returned':assert fault['loss']>0 and fault['duplicate']>0
snapshot_contract_path=root/'browser/snapshot-contract.json'
snapshot_contract=json.loads(snapshot_contract_path.read_text()) if snapshot_contract_path.exists() else None
if snapshot_contract is not None and snapshot_contract['private_history']:
 initial=snapshot_contract['initial'];assert len(initial)==2
 assert all(x['public_excluded_fields']>0 and x['snapshot_shuffle_available']==1 and x['deltasnaps']>0 and x['public_snapshot_bytes']>0 for x in initial)
 assert initial[0]['public_snapshot_bytes']==initial[1]['public_snapshot_bytes'] and initial[0]['public_snapshot_bytes']*2<initial[0]['raw_bytes']
 assert all(x['public_excluded_fields']>0 and x['snapshot_shuffle_available']==1 and x['deltasnaps']>0 for x in before)
else:assert all(x['shuffled_snapshots']>0 for x in before)
assert all(x['resyncs']==0 for x in before) and before[1]['action_copy_batches']>0
if plan is not None:
 requested=plan['reliable_hold_ms'];assert type(requested) is int and 0<=requested<=2000
 assert type(plan.get('hold_at_kill',False)) is bool
 if plan.get('hold_at_kill',False):assert requested>=1000 and plan['hold_before_kill_ms']==300
 else:assert plan.get('hold_before_kill_ms',0)==0
 assert (root/'browser/reliable-hold.json').exists()==(requested>0)
if (root/'browser/reliable-hold.json').exists():
 hold=json.loads((root/'browser/reliable-hold.json').read_text());requested=plan['reliable_hold_ms'] if plan is not None else 200
 assert hold['milliseconds']==requested and hold['triggered'] and 0<hold['held']<=128 and hold['peakBytes']<=65536 and not hold['errors']
 if plan is not None and plan.get('hold_at_kill',False):
  assert d['mode']=='crash' and plan['hold_before_kill_ms']==300 and hold['active'] and 0<hold['queuedBytes']<=hold['peakBytes'] and hold['heldForMs']>=300
  frontiers=json.loads((root/'browser/hold-frontiers.json').read_text());assert len(frontiers)>=2 and frontiers[-1]['hold']['active'] and frontiers[-1]['hold']['heldForMs']>=300
  assert sum(bool(row['hold']['active']) for row in frontiers)>=2
  for row in frontiers:
   states=row['states'];assert len(states)==2
   assert all(x['ready']==1 and x['epoch']==1 and x['resyncs']==0 and x['credit_r']<=16 and x['credit_u']<=16 and x['assembly_bytes']<=x['assembly_limit'] and x['queue_limit']==8 for x in states)
   assert 0<=states[1]['facts']-states[1]['head']<=30
 else:
  assert not hold['active'] and hold['queuedBytes']==0
  if plan is not None:assert hold['elapsedMs']>=requested-1 and hold['releasedAt']>=hold['startedAt']
if (root/'browser/render-before.json').exists():
 traces=json.loads((root/'browser/render-before.json').read_text());assert len(traces)==2 and all(t['binds']>0 and t['conflicts']==0 for t in traces)
 for role in ('client','returned' if d['mode']=='crash' else 'host'):
  trace=json.loads((root/f'browser/terminal-{role}.json').read_text())['render'];assert trace['binds']>0 and trace['conflicts']==0
assert 'WEB_AUTHORITY_SERVER_OK epoch=2'  in (root/'server.log').read_text()
if raw_turn:
 network=json.loads((root/'browser/turn-network.json').read_text());assert network['pass'] and network['fault_receives']>0 and network['relay_observations']>=6
 if network['config']['loss']>0:assert network['totals']['dtls_loss']>0
(root/'summary.json').write_text(json.dumps({'scope':('Two Chrome peers through real UDP TURN datagram faults; application message faults disabled.' if raw_turn else 'Two Chrome RTC peers under 40±10 ms message delay and 5% unreliable loss/duplication.')+' Existing 40-mob jam workload, hardware WebGL, speed WASM and local signaling/coordinator.','runs':rows,'migration':d},indent=2)+'\n')
print('REPLAY_LOADED_MIGRATION_OK mode='+d['mode'])
