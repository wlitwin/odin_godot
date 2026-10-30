from pathlib import Path
import json,shutil,subprocess,sys,tempfile
source=Path(sys.argv[1]).resolve();report=Path(__file__).with_name('report.py');results=[]
for case in ['valid','conflict','missing_peer','no_ownership','world_mismatch','too_few_worlds']:
 with tempfile.TemporaryDirectory(prefix='render-report-') as folder:
  root=Path(folder)
  for p in source.iterdir():
   if p.name=='browser':shutil.copytree(p,root/p.name)
   elif p.name not in ('render-summary.json','report-validation.json'):(root/p.name).symlink_to(p,target_is_directory=p.is_dir())
  p=root/'browser/render-traces.json';d=json.loads(p.read_text())
  if case=='conflict':d[0]['conflicts']=1
  if case=='missing_peer':d.pop()
  p.write_text(json.dumps(d))
  p=root/'browser/hashes.json';d=json.loads(p.read_text())
  if case=='world_mismatch':d['hashes'][1][d['common'][0]]='0'
  if case=='too_few_worlds':d['common']=d['common'][:2]
  p.write_text(json.dumps(d))
  if case=='no_ownership':
   p=root/'browser/member-2.log';p.write_text(p.read_text().replace('REPLAY_MESH2_WEB_OWNERSHIP_OK','removed'))
  run=subprocess.run([sys.executable,str(report),str(root)],text=True,capture_output=True)
  assert (run.returncode==0)==(case=='valid'),(case,run.stdout,run.stderr)
  if case!='valid':assert 'AssertionError' in run.stderr,run.stderr
  results.append({'case':case,'accepted':run.returncode==0})
(source/'report-validation.json').write_text(json.dumps(results,indent=2)+'\n');print('RENDER_REPORT_CHECKS_OK cases='+str(len(results)))
