"""Check output equivalence and summarize paired byte-scan timings."""
from pathlib import Path
import json,re,statistics,sys
root=Path(sys.argv[1]);groups={};proof={}
lines=(root/'native.log').read_text().splitlines()
assert len([line for line in lines if re.fullmatch(r'SCAN_CORPUS_OK hash=\d+',line)])==1
expected={(kind,case) for kind in ('SCAN_HASH','SCAN_DELTA') for case in
          ('zero','canonical_world','equal_random','dense_random','alternating_changes','periodic_changes')}
for line in lines:
 if not line.startswith(('SCAN_HASH ','SCAN_DELTA ')):continue
 kind=line.split()[0];f=dict(re.findall(r'(\w+)=([^ ]+)',line));key=(kind,f['case'],f['reference'])
 assert (kind,f['case']) in expected and f['reference'] in ('true','false'),key
 trial=int(f['trial']);values=groups.setdefault(key,{})
 assert trial not in values,('duplicate trial',key,trial)
 values[trial]=int(f['ns'])
 proof.setdefault((kind,f['case']),set()).add((f.get('result'),f.get('total'),f.get('hash')))
assert set(proof)==expected and all(len(p)==1 for p in proof.values()),proof
summary={}
for kind,case in proof:
 row={}
 for version in ['true','false']:
  values=groups[(kind,case,version)];assert set(values)==set(range(7)) and min(values.values())>0
  v=list(values.values());row['reference' if version=='true' else 'current']={'median_ns':statistics.median(v),'min_ns':min(v),'max_ns':max(v),'trials':v}
 row['ratio_reference_over_current']=row['reference']['median_ns']/row['current']['median_ns']
 summary[kind+'/'+case]=row
(root/'summary.json').write_text(json.dumps({'iterations_per_trial':1000,'trials_per_version':7,'cases':summary,'interpretation':'Algorithm-level elapsed time. Dense/fragmented tradeoffs are retained; results are not a full-game speedup claim.'},indent=2)+'\n')
print('REPLAY_SCANS_REPORT_OK')
