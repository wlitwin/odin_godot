"""Join a dash request to its queue sequence and committed authority outcome."""
from pathlib import Path
import json,re,sys
root=Path(sys.argv[1]);runs=[]
def events(path):
 rows=[]
 for line in path.read_text().splitlines():
  if not line.startswith('INPUT_'):continue
  row={'kind':line.split()[0]};row.update({k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',line)});rows.append(row)
 return rows
for folder in sorted(root.glob('pair-*/lossy')):
 if not all((folder/f'success-{role}.json').exists() for role in ('host','client')):continue
 client=events(folder/'client.log');host=events(folder/'host.log')
 for log in (client,host):
  counts=[e for e in log if e['kind']=='INPUT_AUDIT_COUNT'];assert len(counts)==1 and counts[0]['dropped']==0
 requests=[e for e in client if e['kind']=='INPUT_REQUEST'];rows=[]
 for i,request in enumerate(requests):
  end=requests[i+1]['now'] if i+1<len(requests) else 2**64
  queued=[e for e in client if e['kind']=='INPUT_QUEUED' and request['now']<=e['now']<end]
  sequences={e['sequence'] for e in queued}
  selected=lambda log,kind:[e for e in log if e['kind']==kind and e.get('sequence') in sequences and e.get('seat',2)==2]
  sent=selected(client,'INPUT_ACTION_SENT');arrived=selected(host,'INPUT_ARRIVAL');admitted=selected(host,'INPUT_ADMITTED');settled=selected(host,'INPUT_SETTLED');results=selected(client,'INPUT_RESULT')
  diagnosis='applied' if len(settled)==len(results)==len(queued)==1 and settled[0]['applied']==results[0]['applied']==1 else 'not_queued' if not queued else 'not_sent' if not sent else 'not_received' if not arrived else 'not_admitted' if not admitted else 'unsettled' if not settled else 'refused_or_unobserved'
  rows.append({'press':i+1,'request':request,'queued':queued,'sent':sent,'arrived':arrived,'admitted':admitted,'settled':settled,'results':results,'diagnosis':diagnosis})
 data=json.loads((folder/'success-client.json').read_text())
 runs.append({'pair':folder.parent.name,'final_dashes':data['final']['dashes'],'dash_receipts':data['dash_receipts'],'presses':rows})
 print(folder.parent.name,'final',data['final']['dashes'],'diagnoses',[r['diagnosis'] for r in rows])
(root/'input-audit.json').write_text(json.dumps({'kind':'actions','runs':runs,'scope':'Buffered instrumented copies. Sequence joins cross processes; process-local clocks are never compared. Not a performance measurement.'},indent=2)+'\n')
