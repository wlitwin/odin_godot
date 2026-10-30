"""Mutate real native control-channel observations and reject incorrect claims."""
from pathlib import Path
import json,shutil,subprocess,sys,tempfile
source=Path(sys.argv[1]);script=Path(__file__).with_name('control_report.py');checks=[]
for case in ['valid','missing','ordered','unreliable','no_sent','no_received','wrong_label','wrong_data_order','false_legacy']:
 with tempfile.TemporaryDirectory() as tmp:
  root=Path(tmp)
  for p in [*source.glob('control-*-before.json'),*source.glob('control-*-recovered.json')]:shutil.copyfile(p,root/p.name)
  p=next(root.glob('control-*-before.json'));rows=json.loads(p.read_text());channels=rows[0]['channels'];c=next(c for c in channels if c['id']==2)
  if case=='missing':rows[0]['channels']=[x for x in channels if x['id']!=2]
  if case=='ordered':c['ordered']=True
  if case=='unreliable':c['maxRetransmits']=0
  if case=='no_sent':c['sent']=0
  if case=='no_received':c['received']=0
  if case=='wrong_label':c['label']='other'
  if case=='wrong_data_order':channels[0]['ordered']=False
  p.write_text(json.dumps(rows));result=subprocess.run([sys.executable,str(script),str(root),'legacy' if case=='false_legacy' else 'separate'],capture_output=True,text=True)
  assert (result.returncode==0)==(case=='valid'),(case,result.stdout,result.stderr)
  checks.append({'case':case,'accepted':result.returncode==0})
(source/'control-report-tests.json').write_text(json.dumps(checks,indent=2)+'\n');print('REPLAY_CONTROL_REPORT_CHECKS_OK',len(checks))
