"""Join diagnostic stages by simulation tick; process clocks stay separate."""
from pathlib import Path
import json,re,runpy,sys
root=Path(sys.argv[1]);runs=[]
if json.loads((root/'audit-manifest.json').read_text()).get('kind')=='actions':
 runpy.run_path(str(Path(__file__).with_name('action_analyze.py')),run_name='__main__');sys.exit(0)
def events(path):
 out=[]
 for line in path.read_text().splitlines():
  if not line.startswith('INPUT_'):continue
  row={'kind':line.split()[0]}
  for key,value in re.findall(r'(\w+)=([^ ]+)',line):
   row[key]=int(value) if value.isdigit() else value
  out.append(row)
 return out
for folder in sorted(root.glob('pair-*/lossy')):
 if not (folder/'success-client.json').exists() or not (folder/'success-host.json').exists():continue
 c=events(folder/'client.log');h=events(folder/'host.log');
 if (root/'framework/replay/net/input_audit.odin').exists() and not all(any(e['kind']=='INPUT_AUDIT_COUNT' for e in log) for log in (c,h)):continue
 for events_in_log in (c,h):
  for e in events_in_log:
   if e['kind']=='INPUT_AUDIT_COUNT':assert e['dropped']==0
 requests=[e for e in c if e['kind']=='INPUT_REQUEST'];rows=[]
 for i,request in enumerate(requests):
  end=requests[i+1]['now'] if i+1<len(requests) else 2**64
  captures=[e for e in c if e['kind']=='INPUT_CAPTURE' and request['now']<=e['now']<end]
  ticks={e['tick'] for e in captures}
  sends=[e for e in c if e['kind']=='INPUT_SENT' and e['tick'] in ticks]
  received=[e for e in h if e['kind']=='INPUT_RECEIVED' and e['seat']==2 and e['tick'] in ticks]
  accepted=[e for e in h if e['kind']=='INPUT_ACCEPTED' and e['seat']==2 and e['tick'] in ticks]
  executed=[e for e in h if e['kind']=='INPUT_EXECUTED' and e['seat']==2 and e['tick'] in ticks]
  model=[e for e in h if e['kind']=='INPUT_MODEL' and e['seat']==2 and e['tick'] in ticks]
  frames=[e for e in c if e['kind']=='INPUT_FRAME' and request['now']<=e['now']<end]
  diagnosis='executed' if executed else 'not_captured' if not captures else 'not_submitted' if not sends else 'not_received' if not received else 'late' if all(e['tick']<=e['head'] for e in received) else 'not_accepted' if not accepted else 'game_predicate'
  rows.append({'press':i+1,'request':request,'captures':captures,'send_count':len(sends),'received':received,'accepted':accepted,'model':model,'executed':executed,'frames':frames,'diagnosis':diagnosis})
 data=json.loads((folder/'success-client.json').read_text())
 runs.append({'pair':folder.parent.name,'requests':len(requests),'final_dashes':data['final']['dashes'],'presses':rows})
 print(folder.parent.name,'final',data['final']['dashes'],'diagnoses',[r['diagnosis'] for r in rows])
 for row in rows:
  if row['diagnosis']!='executed':print('UNEXECUTED',row['press'],row['diagnosis'],'capture_ticks',[e['tick'] for e in row['captures']],'arrivals',[(e['tick'],e['head']) for e in row['received']])
(root/'input-audit.json').write_text(json.dumps({'runs':runs,'scope':'Instrumented diagnostic copies; not performance measurements. Arrival head and sample tick share simulation time; process-local clocks are not compared.'},indent=2)+'\n')
