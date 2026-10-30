"""Record condition-specific acceptance and failure without relabeling the matrix."""
from pathlib import Path
import hashlib,json,subprocess,sys,tempfile
root=Path(sys.argv[1]).resolve();report=Path(__file__).with_name('report.py');plan=json.loads((root/'run-plan.json').read_text())
results={};implementation_results={}
for condition in plan['conditions']:
 for implementation in (None,'kit','replay'):
  with tempfile.TemporaryDirectory(prefix='replay-endurance-audit-') as tmp:
   view=Path(tmp)
   for p in root.iterdir():
    if p.name not in ('run-plan.json','summary.json','summary.json.pending'):(view/p.name).symlink_to(p,target_is_directory=p.is_dir())
   scoped={**plan,'conditions':[condition]};(view/'run-plan.json').write_text(json.dumps(scoped))
   command=[sys.executable,str(report),str(view),'--allow-partial']
   if implementation:command+=['--implementation',implementation]
   run=subprocess.run(command,text=True,capture_output=True)
   suffix=condition+('-'+implementation if implementation else '')
   if run.returncode==0:
    summary=json.loads((view/'summary.json').read_text());summary['acceptance_scope']=suffix
    (root/f'summary-{suffix}.json').write_text(json.dumps(summary,indent=2)+'\n')
   value={'accepted':run.returncode==0,'exit_code':run.returncode,'stdout':run.stdout,'stderr':run.stderr}
   if implementation:implementation_results[suffix]=value
   else:results[condition]=value
observations=[]
for p in sorted(root.glob('*/pair-*/*/success-*.json')):
 d=json.loads(p.read_text());all_trace=d['trace'];trace=[s for s in all_trace if s.get('ready',True)];last_tick=trace[0]['tick'];last_at=trace[0]['us'];gaps=[]
 for sample in trace[1:]:
  if sample['tick']>last_tick:gaps.append(sample['us']-last_at);last_tick,last_at=sample['tick'],sample['us']
 gaps.append(all_trace[-1]['us']-last_at)
 edges=[[sum(b['people'][i]['cd'][j]>a['people'][i]['cd'][j]+120 for a,b in zip(trace,trace[1:])) for j in (0,1)] for i in (0,1)]
 observations.append({'source':str(p.relative_to(root)),'condition':d['condition'],'implementation':d['implementation'],'role':d['role'],'casts_observed':edges,'final_dashes':d['final']['dashes'],'final_hp':d['final']['hp'],'resyncs':all_trace[-1]['resyncs']-all_trace[0]['resyncs'],'unavailable_us':sum(b['us']-a['us'] for a,b in zip(all_trace,all_trace[1:]) if not a.get('ready',True)),'prediction_stalls':trace[-1].get('stalls',0)-trace[0].get('stalls',0),'max_observed_tick_gap_us':max(gaps)})
value={'full_matrix_accepted':all(r['accepted'] for r in results.values()) and plan['repetitions']==3 and plan['conditions']==['delay','lossy'],'conditions':results,'by_implementation':implementation_results,'observations':observations,'report_sha256':hashlib.sha256(report.read_bytes()).hexdigest(),'scope':'Condition acceptance is separate from full-matrix acceptance. Failed-condition observations are diagnostic, not a paired performance result.'}
(root/'assessment.json').write_text(json.dumps(value,indent=2)+'\n')
print('ENDURANCE_ASSESSMENT full_matrix_accepted='+str(value['full_matrix_accepted']).lower()+' conditions='+str({k:v['accepted'] for k,v in results.items()}))
