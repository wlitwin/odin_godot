from pathlib import Path
import json,shutil,subprocess,sys,tempfile
source=Path(sys.argv[1]).resolve();report=Path(__file__).with_name('report.py');checks=[]
cases=['valid','lost_label','duplicate_label','observer_seat','extra_player','inexact_restore','no_renegotiation']
if json.loads((source/'browser/result.json').read_text()).get('mode')=='crash':cases+=['host_not_returned','observer_not_returned','new_label_missing']
if 'status' in json.loads((source/'browser/result.json').read_text())['final'][2]:cases+=['player_controls_hint']
for case in cases:
 with tempfile.TemporaryDirectory(prefix='observer-name-report-') as folder:
  root=Path(folder)
  for p in source.iterdir():
   if p.name=='browser':shutil.copytree(p,root/p.name)
   elif p.name not in ('summary.json','report-validation.json'):(root/p.name).symlink_to(p,target_is_directory=p.is_dir())
  p=root/'browser/result.json';d=json.loads(p.read_text())
  if case=='lost_label':d['final'][0]['history']=d['final'][0]['history'].replace('Watcher Ω (observer): watching safely','Observer: watching safely')
  if case=='duplicate_label':d['final'][0]['history']+='\nWatcher Ω (observer): watching safely'
  if case=='observer_seat':d['final'][2]['seat']=3
  if case=='extra_player':d['final'][2]['players']=3
  if case=='inexact_restore':d['promoted']['restored_exact']=0
  if case=='host_not_returned':d['returned_host']=False
  if case=='observer_not_returned':d['returned_observer']=False
  if case=='player_controls_hint':d['final'][2]['status']='WASD move · Shift dash · mouse fire'
  if case=='new_label_missing':d['final'][2]['history']=d['final'][2]['history'].replace('Rhea (observer): fresh observer','Observer: fresh observer')
  if case=='no_renegotiation':d['final'][2]['named_observer']=0
  p.write_text(json.dumps(d))
  run=subprocess.run([sys.executable,str(report),str(root)],text=True,capture_output=True);assert (run.returncode==0)==(case=='valid'),(case,run.stdout,run.stderr)
  if case!='valid':assert 'AssertionError' in run.stderr,run.stderr
  checks.append({'case':case,'accepted':run.returncode==0})
(source/'report-validation.json').write_text(json.dumps(checks,indent=2)+'\n');print('OBSERVER_NAME_REPORT_CHECKS_OK cases='+str(len(checks)))
