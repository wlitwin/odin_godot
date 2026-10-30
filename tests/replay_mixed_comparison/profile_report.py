from pathlib import Path
import csv,json,math,sys
root=Path(sys.argv[1]);result={}
for role in ('host','client'):
 groups={}
 for row in csv.DictReader((root/f'timing-{role}.csv').open()):groups.setdefault(row['metric'],[]).append(int(row['us']))
 assert all(v>=0 for values in groups.values() for v in values)
 q=lambda values,f:sorted(values)[max(0,math.ceil(len(values)*f)-1)]
 result[role]={name:{'samples':len(values),'total_us':sum(values),'p50_us':q(values,.5),'p95_us':q(values,.95),'mean_us':sum(values)/len(values)} for name,values in groups.items()}
 assert 'frame' in result[role] and 'pump' in result[role]
(root/'phases.json').write_text(json.dumps({'roles':result,'note':'Nested inclusive phases overlap; do not sum pump/snapshot/replay into frame. Instrumentation is enabled only in this diagnostic run.'},indent=2)+'\n')
print('REPLAY_MIXED_PHASE_REPORT_OK')
