"""Coarse checkpoint stage observations; sampled ticks are not latency guarantees."""
from pathlib import Path
import json,sys,statistics
root=Path(sys.argv[1]);rows=json.loads((root/'browser/telemetry.json').read_text())
host=[r for r in rows if r['role']=='host'];clients=[r for r in rows if r['role']=='client'];validated={};approved={}
for row in clients:
 if 'sampled_ms' not in row:continue
 for field,table in [('incoming_latest',validated),('prepared_tick',approved)]:
  tick=row.get(field,0)
  if tick>0 and tick not in table:table[tick]=row
stages=[]
for tick,row in validated.items():
 if tick not in approved:continue
 preceding=[h for h in host if h.get('sampled_ms',float('inf'))<=row['sampled_ms']]
 stages.append({'tick':tick,'first_seen_validated_ms':row['sampled_ms'],'first_seen_approved_ms':approved[tick]['sampled_ms'],'approval_observation_delay_ms':max(0,approved[tick]['sampled_ms']-row['sampled_ms']),'host_tick_age_at_validation':preceding[-1]['head']-tick if preceding else None})
value={'scope':'First sampled observations; approximately one sample per 0.1–0.2 seconds, not exact stage timestamps.','stages':stages}
if stages:
 value['median_approval_observation_ms']=statistics.median(x['approval_observation_delay_ms'] for x in stages)
 ages=[x['host_tick_age_at_validation'] for x in stages if x['host_tick_age_at_validation'] is not None]
 value['median_host_tick_age_at_validation']=statistics.median(ages) if ages else None
(root/'checkpoint-stages.json').write_text(json.dumps(value,indent=2)+'\n');print('CHECKPOINT_STAGE_REPORT',len(stages),value.get('median_approval_observation_ms'),value.get('median_host_tick_age_at_validation'))
