"""Apply the existing workload gates to one measured Replay rate diagnostic."""
from pathlib import Path
import argparse,json,subprocess,sys,tempfile
p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('measurement',type=Path);a=p.parse_args()
source,measurement=a.source.resolve(),a.measurement.resolve()
proof=json.loads((measurement/'provenance.json').read_text());interval=proof['snapshot_every']
assert 1<=interval<=30
with tempfile.TemporaryDirectory(prefix='replay-rate-report-') as directory:
 root=Path(directory)
 for path in source.iterdir():
  if path.name not in ('delay','lossy','run-plan.json','summary.json','summary.json.pending'):
   (root/path.name).symlink_to(path,target_is_directory=path.is_dir())
 (root/'delay/pair-1').mkdir(parents=True)
 (root/'delay/pair-1/replay').symlink_to(measurement,target_is_directory=True)
 plan=json.loads((source/'run-plan.json').read_text());plan.update(repetitions=1,conditions=['delay'],snapshot_every=interval)
 (root/'run-plan.json').write_text(json.dumps(plan,indent=2)+'\n')
 command=[sys.executable,str(Path(__file__).with_name('report.py')),str(root),'--allow-partial','--implementation','replay']
 result=subprocess.run(command,text=True,capture_output=True)
 (measurement/'workload-validation.json').write_text(json.dumps({'scope':'One Replay-only delay diagnostic; no full-matrix acceptance claim.','snapshot_every':interval,'accepted':result.returncode==0,'stdout':result.stdout,'stderr':result.stderr},indent=2)+'\n')
 if result.returncode:print(result.stderr,file=sys.stderr);raise SystemExit(result.returncode)
 summary=json.loads((root/'summary.json').read_text());summary['acceptance_scope']='Replay-only delay rate diagnostic'
 (measurement/'workload-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print('REPLAY_RATE_WORKLOAD_OK interval='+str(interval))
