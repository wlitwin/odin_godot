"""Compare native snapshot send, fragment delivery and decode acknowledgment."""
import collections,json,sys
from pathlib import Path
root=Path(sys.argv[1]);captures={role:json.loads((root/f'snapshots-{role}-before.json').read_text()) for role in ['host','client']}
for role,r in captures.items():assert r['overflow']==r['unreadable']==0 and len(r['rows'])<=r['limit'],role
sends=[r for r in captures['host']['rows'] if r['event']=='send' and r['epoch']==1 and r['kind'] in [7,10,17,18,23,24]];receives=[r for r in captures['client']['rows'] if r['event']=='receive' and r['epoch']==1 and r['kind'] in [7,10,17,18,23,24]];acks=[r for r in captures['client']['rows'] if r['event']=='send' and r['kind']==11 and r['epoch']==1]
def scope(r):return ':'.join([str(r['epoch']),r.get('generation','unrecorded'),r.get('serial','unrecorded'),r['id']])
by_send=collections.defaultdict(list);by_receive=collections.defaultdict(list)
for r in sends:by_send[scope(r)].append(r)
for r in receives:by_receive[scope(r)].append(r)
ack={}
for r in acks:ack.setdefault(scope(r),r)
rows=[];delays=[]
for identity,s in by_send.items():
 r=by_receive[identity];lookup={}
 for x in r:lookup.setdefault((x['kind'],x['index']),x)
 matched=[lookup[(x['kind'],x['index'])]['at_ms']-x['at_ms'] for x in s if (x['kind'],x['index']) in lookup];delays+=matched
 first=min(x['at_ms'] for x in s);last=max(x['at_ms'] for x in s)
 rows.append({'scope':identity,'id':s[0]['id'],'tick':s[0]['tick'],'total':s[0]['total'],'sent':len(s),'received':len(r),'first_send_ms':first,'send_span_ms':last-first,'max_buffered_bytes':max(x['buffered_bytes'] for x in s),'wire_max_ms':max(matched) if matched else None,'ack_from_first_ms':ack[identity]['at_ms']-first if identity in ack else None,'ack_from_last_ms':ack[identity]['at_ms']-last if identity in ack else None})
def distribution(values):
 values=sorted(values);assert values
 return {'count':len(values),'median':values[len(values)//2],'p95':values[int(len(values)*.95)],'max':values[-1]}
result={'scoped_headers':all(r.get('version')==2 for r in captures.values()),'scope':'Observed native sends/deliveries; acknowledgment follows snapshot decode, not necessarily application. Same-machine clocks.','snapshots':len(rows),'missing_ack':sum(r['ack_from_first_ms'] is None for r in rows),'send_span_ms':distribution([r['send_span_ms'] for r in rows]),'native_delivery_ms':distribution(delays),'ack_from_first_ms':distribution([r['ack_from_first_ms'] for r in rows if r['ack_from_first_ms'] is not None]),'rows':rows}
if (root/'timing.json').exists() and (root/'telemetry.json').exists():
 origin=json.loads((root/'timing.json').read_text())['node_time_origin']
 observed=[r for r in json.loads((root/'telemetry.json').read_text()) if r['role']=='client' and r['epoch']==1]
 for row in rows:
  if row['scope'] not in ack:continue
  at=ack[row['scope']]['at_ms']
  future=next((r for r in observed if origin+r['sampled_ms']>=at and r['head']>=row['tick']),None)
  if future:row['ack_to_confirmed_observation_upper_ms']=origin+future['sampled_ms']-at
 values=[r['ack_to_confirmed_observation_upper_ms'] for r in rows if 'ack_to_confirmed_observation_upper_ms' in r]
 if values:result['ack_to_confirmed_observation_upper_ms']=distribution(values)
(root/'snapshot-path.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='rows'}))
print('longest sends',json.dumps(sorted(rows,key=lambda r:r['send_span_ms'],reverse=True)[:6]))
