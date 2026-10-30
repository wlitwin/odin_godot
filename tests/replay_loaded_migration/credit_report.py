"""Pair observed browser send/delivery timestamps for credit/fence metadata."""
import json,sys
from pathlib import Path
root=Path(sys.argv[1]);captures={name:json.loads((root/f'credits-{name}-before.json').read_text()) for name in ['host','client']};result={}
for name,c in captures.items():assert c['overflow']==c['unreadable']==0 and c['limit']==32768 and len(c['rows'])<=c['limit'],name
for sender,receiver in [('host','client'),('client','host')]:
 for channel in [0,1]:
  def relevant(e):return e['connection']==0 and e['kind']==1 and e['channel']==channel
  sent={e['sequence']:e for e in captures[sender]['rows'] if e['event']=='send' and relevant(e)}
  received={e['sequence']:e for e in captures[receiver]['rows'] if e['event']=='receive' and relevant(e)}
  rows=[{'sequence':k,'delay_ms':received[k]['at_ms']-v['at_ms'],'sent_at_ms':v['at_ms'],'sender_buffered_bytes':v['buffered_bytes']} for k,v in sent.items() if k in received]
  assert len(rows)>20 and all(r['delay_ms']>=-5 for r in rows)
  delays=sorted(r['delay_ms'] for r in rows);result[f'{sender}-to-{receiver}-channel-{channel}']={'matched':len(rows),'sent':len(sent),'received':len(received),'median_ms':delays[len(delays)//2],'p95_ms':delays[int(len(delays)*.95)],'max_ms':delays[-1],'over_150_ms':sum(t>150 for t in delays),'largest_delays':sorted(rows,key=lambda r:r['delay_ms'],reverse=True)[:12]}
(root/'credit-delivery.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:{x:y for x,y in v.items() if x!='largest_delays'} for k,v in result.items()}))
