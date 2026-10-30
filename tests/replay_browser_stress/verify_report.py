"""Reject altered browser receipts without changing the captured run."""
from pathlib import Path
import json,shutil,subprocess,sys,tempfile
source=Path(sys.argv[1]).resolve();report=Path(__file__).with_name('report.py');checks=[]
for case in ['valid','missing_shuffle','credit_overflow','memory_overflow','no_blackout','no_checkpoint_progress','world_mismatch','stale_world']:
 with tempfile.TemporaryDirectory(prefix='browser-stress-verify-') as tmp:
  root=Path(tmp)
  for p in source.iterdir():
   if p.name=='browser':shutil.copytree(p,root/p.name)
   elif p.name not in ('summary.json','report-validation.json'):(root/p.name).symlink_to(p,target_is_directory=p.is_dir())
  p=root/'browser/recovery.json';d=json.loads(p.read_text())
  if case=='missing_shuffle':d['final'][1]['shuffled_snapshots']=0
  if case=='no_blackout':d['faults'][0]['blackout']=0
  if case=='no_checkpoint_progress':d['final'][0]['backup_tick']=d['initial'][0]['backup_tick']
  if case=='world_mismatch':d['hashes'][1][d['common'][0]]='0'
  p.write_text(json.dumps(d))
  p=root/'browser/telemetry.json';d=json.loads(p.read_text())
  if case=='credit_overflow':d[0]['credit_u']=17
  if case=='memory_overflow':d[0]['assembly_bytes']=d[0]['assembly_limit']+1
  p.write_text(json.dumps(d))
  if case=='stale_world':
   p=root/'browser/success-client.json';d=json.loads(p.read_text());d['trace'][10]['facts_ahead']=31;p.write_text(json.dumps(d))
  run=subprocess.run([sys.executable,str(report),str(root)],text=True,capture_output=True)
  assert (run.returncode==0)==(case=='valid'),(case,run.stdout,run.stderr)
  if case!='valid':assert 'AssertionError' in run.stderr,(case,run.stderr)
  checks.append({'case':case,'accepted':run.returncode==0})
(source/'report-validation.json').write_text(json.dumps(checks,indent=2)+'\n');print('BROWSER_STRESS_REPORT_CHECKS_OK cases='+str(len(checks)))
