from pathlib import Path
import csv,json,math,statistics,sys,os,hashlib
root=Path(sys.argv[1]);runs=[]
contract=json.loads((root/'contract.json').read_text())
combat=contract['scenario']=='combat_encounter'
firing=contract['scenario'] in ('firing_range','combat_encounter')
build=json.loads((root/'build-manifest.json').read_text())
if (root/'framework-source.json').exists():
 framework=json.loads((root/'framework-source.json').read_text())
 for name,digest in framework['sha256'].items():assert hashlib.sha256((Path(framework['root'])/name).read_bytes()).hexdigest()==digest,('framework source changed',name)
if (root/'source-sha256.txt').exists():
 for line in (root/'source-sha256.txt').read_text().splitlines():
  digest,name=line.split('  ',1);assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest,('isolated source changed',name)
pairs=sorted(root.glob('pair-*'));assert pairs
if 'repetitions' in contract:assert {p.name for p in pairs}=={'pair-'+str(i) for i in range(1,contract['repetitions']+1)}
for name,digest in build['binaries'].items():assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest,('binary changed during measurement',name)
def quantile(values,p):return sorted(values)[max(0,math.ceil(len(values)*p)-1)]
for pair in sorted(root.glob('pair-*')):
 for impl in ['kit','replay']:
  for role in ['host','client']:
   folder=pair/impl;data=json.loads((folder/(role+'.json')).read_text());assert data['invariants'] and data['role']==role and data['implementation']==impl
   target=contract['sample_ms']*1000
   assert target-100000<=data['elapsed_us']<=target+300000 and target*60//1000000-15<=data['ticks']<=target*60//1000000+15,{'implementation':impl,'role':role,'pair':pair.name,'elapsed_us':data['elapsed_us'],'ticks':data['ticks']}
   samples=data.pop('frame_us');assert len(samples)>=100 and all(type(v) is int and v>=0 for v in samples)
   rss=[int(r['rss_kib']) for r in csv.DictReader((folder/'rss.csv').open()) if r['role']==role]
   data.update(pair=pair.name,frame_samples=len(samples),frame_p50_us=quantile(samples,.5),frame_p95_us=quantile(samples,.95),frame_p99_us=quantile(samples,.99),application_tx_bps=data['tx_bytes']*1e6/data['elapsed_us'],rss_peak_kib=max(rss))
   if firing:
    workload=data.pop('workload');assert workload['drained'] and workload['shots']==[9,9] and workload['ammo']==[3,3],workload
    assert all(count>=2 for count in workload['reload_entries']),workload
    trace=workload['observations'];assert len(trace)>=250
    inputs=workload['inputs'];assert len(inputs)==2 and inputs[0]['fire'] and not inputs[1]['fire']
    assert inputs[0]['aim']==inputs[1]['aim']==('nearest-living-enemy' if combat else [1,0]),inputs
    assert 0<=inputs[0]['us']<=(3000000 if combat else 5000) and 1000000<=inputs[1]['us']<=target+300000,inputs
    assert all(trace[i]['us']<trace[i+1]['us'] and trace[i]['tick']<=trace[i+1]['tick'] for i in range(len(trace)-1))
    assert all(all(0<=v<=9 for v in sample['spent']) and all(0<=v<=3 for v in sample['ammo']) and all(v in (0,1) for v in sample['mode']) for sample in trace)
    data['workload']={k:v for k,v in workload.items() if k!='observations'}
    if combat:
     from combat_report import summarize
     data['workload']['observed_combat']=summarize(data,workload,trace,samples,role,contract)
    if contract.get('client_timing_observations') and impl=='replay':
     assert all(all(isinstance(sample[key],int) and sample[key]>=0 for key in ['lead_ticks','prediction_depth','replayed_ticks']) for sample in trace)
     assert all(trace[i]['replayed_ticks']<=trace[i+1]['replayed_ticks'] for i in range(len(trace)-1))
     data['workload']['network_timing']={'lead_ticks_min':min(s['lead_ticks'] for s in trace),'lead_ticks_max':max(s['lead_ticks'] for s in trace),'prediction_depth_median':statistics.median(s['prediction_depth'] for s in trace),'prediction_depth_max':max(s['prediction_depth'] for s in trace),'replayed_ticks':trace[-1]['replayed_ticks']-trace[0]['replayed_ticks']}
    if contract.get('input_timing_feedback') and impl=='replay' and role=='client':
     assert all(s['input_turnaround_ms']>=0 and 900<=s['clock_scale_milli']<=1100 and s['timing_samples']>=0 for s in trace)
     assert trace[-1]['timing_samples']>trace[0]['timing_samples']
     data['workload']['network_timing'].update(input_turnaround_median_ms=statistics.median(s['input_turnaround_ms'] for s in trace),input_turnaround_max_ms=max(s['input_turnaround_ms'] for s in trace),arrival_lead_median=statistics.median(s['arrival_lead_milli']/1000 for s in trace),clock_scale_min=min(s['clock_scale_milli']/1000 for s in trace),clock_scale_max=max(s['clock_scale_milli']/1000 for s in trace),lead_updates=trace[-1]['lead_updates']-trace[0]['lead_updates'])
    if role=='host':
     counts=[s['projectiles'] for s in trace];assert min(counts)>=0 and 0<max(counts)<=4,counts
     # Integrate sampled occupancy; this is an observed workload, not an exact
     # per-tick count of objects created/destroyed between process callbacks.
     occupied_us=sum(trace[i]['projectiles']*(trace[i+1]['us']-trace[i]['us']) for i in range(len(trace)-1))
     data['workload'].update(projectiles_peak=max(counts),projectiles_time_mean=occupied_us/(trace[-1]['us']-trace[0]['us']),
       first_observed_shot_us=[next(s['us'] for s in trace if s['spent'][seat]>0) for seat in range(2)],
       ninth_observed_shot_us=[next(s['us'] for s in trace if s['spent'][seat]==9) for seat in range(2)])
   runs.append(data)
aggregates={}
for implementation in ['kit','replay']:
 for role in ['host','client']:
  rows=[r for r in runs if r['implementation']==implementation and r['role']==role]
  aggregates[implementation+'/'+role]={key:{'median':statistics.median(r[key] for r in rows),'min':min(r[key] for r in rows),'max':max(r[key] for r in rows)} for key in ['frame_p50_us','frame_p95_us','frame_p99_us','application_tx_bps','rss_peak_kib']}
if combat:
 for implementation in ['kit','replay']:
  for role in ['host','client']:
   rows=[r['workload']['observed_combat'] for r in runs if r['implementation']==implementation and r['role']==role]
   aggregates[implementation+'/'+role]['combat']={key:{'median':statistics.median(r[key] for r in rows),'min':min(r[key] for r in rows),'max':max(r[key] for r in rows)} for key in ['active_observed_frame_p50_us','active_observed_frame_p95_us','active_observed_frame_p99_us','living_time_mean','minimum_team_hp','last_living_observation_us','census_p50_us','observation_p50_us']}
summary={'contract':contract,'build':build,'runs':runs,'aggregates':aggregates,'phase_instrumentation':os.environ.get('REPLAY_COMPARISON_PHASES','0')=='1','build_flags':'-debug -o:speed (scripts); shared core build unchanged','interpretation':('Matched four-mob spawn intent and final damage/kill/pickup/shot totals; transient combat occupancy and timing are measured. No sustained-swarm conclusion.' if combat else 'Matched held-trigger intent, weapon settings and accepted shot totals; time-resolved projectile populations are measured, not presumed equal. No AI/damage/movement conclusion.' if firing else 'Idle networking workload only.')+' Inclusive game callback and RSS include different UI/audio implementations; do not interpret those as framework-only ratios.'}
payload=json.dumps(summary,indent=2)+'\n'
stage=root/'summary.json.pending'
try:
 stage.write_text(payload);os.replace(stage,root/'summary.json')
finally:
 stage.unlink(missing_ok=True)
print(payload)
