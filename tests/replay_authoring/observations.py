"""Describe sampled remote health/wallet visibility, without inferring latency percentiles."""
from pathlib import Path
import json,sys
root=Path(sys.argv[1]);groups={}
for path in sorted((root/'runs').glob('*/*/*/*/success-*.json')):
    receipt=json.loads(path.read_text())
    if receipt['role']=='host':continue
    pair,condition,case,impl=path.relative_to(root/'runs').parts[:4]
    key=impl+'/'+condition
    result=groups.setdefault(key,{'remote_runs':0,'runs_with_revived_health_before_credit':0,'sampled_observations':0,'partial_observations':0,'receipts':[]})
    rows=receipt['trace'];partial=[r for r in rows if r['hp'][1]==4 and r['cash'][1]==0]
    result['remote_runs']+=1;result['sampled_observations']+=len(rows);result['partial_observations']+=len(partial)
    result['runs_with_revived_health_before_credit']+=bool(partial)
    result['receipts'].append({'path':str(path.relative_to(root)),'partial_observations':len(partial)})
value={'groups':groups,'scope':'100 ms driver observations. Health and wallet are read sequentially in one callback. Counts show observed cross-subsystem settling, not measured packet latency or a proof that unobserved intervals were coherent.'}
(root/'observations.json').write_text(json.dumps(value,indent=2)+'\n')
print('REPLAY_AUTHORING_OBSERVATIONS_OK')
