from pathlib import Path
import hashlib,json,sys,tempfile
root=Path(sys.argv[1]).resolve();repo=Path(__file__).resolve().parents[2];sys.path.insert(0,str(repo/'tests/replay_jam_comparison'))
from workload import validate_condition
contract=json.loads((root/'contract.json').read_text());assert contract==json.loads((repo/'tests/replay_jam_comparison/contract.json').read_text())
for line in (root/'source-sha256.txt').read_text().splitlines():
 h,name=line.split('  ',1);assert hashlib.sha256((root/name).read_bytes()).hexdigest()==h,('source',name)
framework=json.loads((root/'framework-source.json').read_text())
for name,h in framework['sha256'].items():assert hashlib.sha256((Path(framework['root'])/name).read_bytes()).hexdigest()==h,('framework',name)
build=json.loads((root/'browser-build.json').read_text())
for name,h in build['binaries'].items():assert hashlib.sha256((root/name).read_bytes()).hexdigest()==h,('binary',name)
with tempfile.TemporaryDirectory(prefix='browser-jam-workload-') as tmp:
 view=Path(tmp);(view/'delay/pair-1').mkdir(parents=True);(view/'delay/pair-1/replay').symlink_to(root/'browser',target_is_directory=True)
 # Reuse the strict delay gameplay/observation policy. This is not an ENet delay
 # comparison: actual RTC message faults are checked separately below.
 rows=validate_condition(view,contract,{'repetitions':1,'snapshot_every':3},['replay'],{'enabled':False},'delay',None)
recovery=json.loads((root/'browser/recovery.json').read_text());telemetry=json.loads((root/'browser/telemetry.json').read_text())
assert len(recovery['common'])>=10 and all(all(h[k]==recovery['hashes'][0][k] for h in recovery['hashes']) for k in recovery['common'])
assert all(row['credit_r']<=16 and row['credit_u']<=16 and row['assembly_bytes']<=row['assembly_limit'] and row['rtc_failed']==0 for row in telemetry)
assert all(row['shuffled_snapshots']>0 and row['resyncs']==0 for row in recovery['final'])
assert recovery['final'][1]['action_copy_batches']>0
for fault in recovery['faults']:
 assert fault['loss']>0 and fault['duplicate']>0 and fault['capacity']==0 and not fault['errors']
 assert fault['maxQueuedBytes']<=65536 and fault['maxQueuedPackets']<=128
assert recovery['faults'][0]['blackout']>0 and recovery['faults'][0]['fences']>recovery['fenceBefore']
assert all(r['queue_limit']==8 for r in recovery['final'])
assert recovery['final'][0]['backup_tick']>recovery['initial'][0]['backup_tick']>0
assert recovery['final'][1]['backup_tick']>=recovery['final'][0]['backup_tick']
assert 'WEB_AUTHORITY_SERVER_OK epoch=1' in (root/'server.log').read_text()
value={'scope':'Two browser RTC processes; shared native gameplay gates with separately recorded message-level faults. RSS is summed process-tree RSS, not native single-process RSS. No paired Kit or raw SCTP-loss claim.','runs':rows,'recovery':recovery,'peak_assembly_bytes':max(row['assembly_bytes'] for row in telemetry),'max_credit':max(max(row['credit_r'],row['credit_u']) for row in telemetry)}
(root/'summary.json').write_text(json.dumps(value,indent=2)+'\n');print('REPLAY_BROWSER_STRESS_OK')
