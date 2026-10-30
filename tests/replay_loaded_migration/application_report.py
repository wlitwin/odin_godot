"""Classify measured freshness violations using one atomic client frontier probe."""
import json,sys
from pathlib import Path
root=Path(sys.argv[1]);capture=json.loads((root/'applied-client-before.json').read_text());assert capture['limit']==8192 and capture['overflow']==0 and len(capture['rows'])<=8192
rows=[r for r in capture['rows'] if r['phase']=='measure' and r.get('epoch')==1 and r['authority']==0];assert len(rows)>=1000
counts={k:0 for k in ['snapshot_not_decoded','decoded_waiting_facts','usable_not_applied','other']};bad=[]
for r in rows:
 assert r['observed']==r['confirmed']==r['journal'] and r['observed']<=r['facts']
 if r['facts']-r['observed']<=30:continue
 if r['eligible']>r['observed']:kind='usable_not_applied'
 elif r['latest_tick']<=r['observed']:kind='snapshot_not_decoded'
 elif r['latest_tick']>r['facts']:kind='decoded_waiting_facts'
 else:kind='other'
 counts[kind]+=1;bad.append({**r,'cause':kind})
result={'rows':len(rows),'maximum_facts_ahead':max(r['facts']-r['observed'] for r in rows),'violations':len(bad),'causes':counts,'native_probe_max_us':max(r['probe_us'] for r in rows),'note':'Native probe timing excludes the following JavaScript recording call. Measurement phase only; frame samples are not a network delivery trace.'}
(root/'application-path.json').write_text(json.dumps(result,indent=2)+'\n');(root/'application-violations.json').write_text(json.dumps(bad,indent=2)+'\n');print(json.dumps(result))
