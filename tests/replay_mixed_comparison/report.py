from pathlib import Path
import csv,hashlib,json,math,statistics,sys
from provenance import validate
root=Path(sys.argv[1]);contract=json.loads((root/'contract.json').read_text());expected=json.loads(Path(__file__).with_name('contract.json').read_text());assert contract==expected
build=json.loads((root/'build-manifest.json').read_text())
assert build['flags']==['-debug','-o:speed'] and build['odin']
assert {name.split('/')[0] for name in build['binaries']}=={'kit','replay'}
assert (root/'source-sha256.txt').stat().st_size>0
for name,digest in build['binaries'].items():assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest,('binary',name)
for line in (root/'source-sha256.txt').read_text().splitlines():
 digest,name=line.split('  ',1);assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest,('source',name)
framework=json.loads((root/'framework-source.json').read_text())
assert framework['sha256']
for name,digest in framework['sha256'].items():assert hashlib.sha256((Path(framework['root'])/name).read_bytes()).hexdigest()==digest,('framework',name)
plan=json.loads((root/'run-plan.json').read_text());control=validate(root,framework,build,plan);full=plan['repetitions']==3;assert full or sys.argv[2:]==['--allow-partial']
assert type(plan['repetitions'])==int and 1<=plan['repetitions']<=3
assert {p.name for p in root.glob('pair-*')}=={'pair-'+str(i) for i in range(1,plan['repetitions']+1)}
def q(values,p):return sorted(values)[max(0,math.ceil(len(values)*p)-1)]
runs=[]
for pair in range(1,plan['repetitions']+1):
 for impl in ('kit','replay'):
  for role in ('host','client'):
   folder=root/f'pair-{pair}'/impl;data=json.loads((folder/f'success-{role}.json').read_text())
   assert data['implementation']==impl and data['role']==role
   assert data.get('reuse_enabled',False)==(plan.get('correction_reuse',False) and impl=='replay' and role=='client')
   assert 19900000<=data['elapsed_us']<=20300000
   low,high=contract['freshness']['authority_tick_advance' if role=='host' or impl=='kit' else 'client_received_tick_advance']
   assert low<=data['ticks']<=high
   warmup=data['warmup'];assert warmup['steady_ms']>=2000
   assert warmup['prediction_depth']<=warmup['lead']+30 and warmup['facts_ahead']<=30
   frames=data['frame_us'];times=data['frame_at_us'];trace=data['trace'];costs=data['census_us']
   assert len(frames)==len(times)>=1000 and all(type(v)==int and v>=0 for v in frames)
   assert times==sorted(times) and min(times)>=0 and max(times)<=data['elapsed_us']+100000
   assert len(trace)==len(costs)>=1000 and all(type(v)==int and v>=0 for v in costs)
   assert all(trace[i]['us']<trace[i+1]['us'] and trace[i]['tick']<=trace[i+1]['tick'] for i in range(len(trace)-1))
   assert trace[-1]['us']-trace[0]['us']>=19500000
   assert all(0<=s['facts_ahead']<=30 and 0<=s['prediction_depth']<=s['lead']+30 for s in trace)
   assert trace[-1]['resyncs']==trace[0]['resyncs']
   assert all(type(s.get('reused',0))==int and s.get('reused',0)>=0 for s in trace)
   assert all(a.get('reused',0)<=b.get('reused',0) for a,b in zip(trace,trace[1:]))
   if not data.get('reuse_enabled',False):assert trace[-1].get('reused',0)==0
   living=[s['living'] for s in trace];assert min(living)>=32 and max(living)<=44,('population envelope',impl,role,min(living),max(living))
   assert [i['fire'] for i in data['inputs']]==[True,False] and data['inputs'][0]['us']<=10000 and 19900000<=data['inputs'][1]['us']<=20400000
   assert data['known_before']==40 and data['kills_before']==0 and data['shots_before']==[0,0]
   assert len(set(data['initial_ids']))==40
   seen=set(data['initial_ids']);previous={};travel={}
   for sample in trace:
    enemies=sample['enemies'];assert len(enemies)<=64 and len({e['id'] for e in enemies})==len(enemies)
    assert sample['living']==sum(e['hp']>0 for e in enemies)
    for e in enemies:
     assert e['id']!='0' and e['kind']==0 and 0<=e['hp']<=3 and math.isfinite(e['x']) and math.isfinite(e['y'])
     seen.add(e['id'])
     if e['id'] in previous:
      old=previous[e['id']];assert e['hp']<=old['hp'];travel[e['id']]=travel.get(e['id'],0)+math.hypot(e['x']-old['x'],e['y']-old['y'])
     previous[e['id']]=e
    for field in ('damage','kills','scrap','spent','ammo'):
     assert len(sample[field])==2 and all(type(v)==int and v>=0 for v in sample[field])
    assert sample['loot']>=0
    if role=='host':
     assert sum(sample['scrap'])+sample['loot']==3*sum(sample['kills'])
     assert sum(sample['damage'])+sum(e['hp'] for e in enemies)==3*len(seen),('health conservation',impl,sample['us'])
     assert sample['living']+sum(sample['kills'])==len(seen),('kill conservation',impl,sample['us'])
   spent=[trace[-1]['spent'][i]-data['shots_before'][i] for i in (0,1)]
   assert all(45<=v<=75 for v in spent),('shots',impl,role,spent)
   kills=sum(trace[-1]['kills'])-data['kills_before'];assert kills>=20,('churn',impl,role,kills)
   assert len(seen)>=60 and sum(v>=10 for v in travel.values())>=20,('actor churn/motion',impl,role,len(seen))
   duration=trace[-1]['us']-trace[0]['us'];mean=sum(trace[i]['living']*(trace[i+1]['us']-trace[i]['us']) for i in range(len(trace)-1))/duration
   assert mean>=36,('mean occupancy',impl,role,mean)
   # Validate authored input timing and reconstruct movement/status exposure
   # from observations; submitted intents alone do not establish gameplay work.
   movement=data['movement'];assert len(movement)==20
   for i,event in enumerate(movement):
    assert event['direction']==contract['movement']['directions'][i%4]
    assert i*1000000<=event['us']<=i*1000000+150000,('movement timing',i,event)
   assert len(data['casts'])==len(contract['casts'])
   for event,wanted in zip(data['casts'],contract['casts']):
    assert event['slot']==wanted['slot'] and wanted['at_ms']*1000<=event['us']<=wanted['at_ms']*1000+150000
   assert data['cast_sent']==[2,2] and data['cast_refused']==[0,0]
   player_travel=[];rally_samples=[];rises=[]
   owner_reversals=0
   for seat in (0,1):
    people=[sample['people'][seat] for sample in trace]
    assert all(len(sample['people'])==2 for sample in trace)
    assert all(p['hp']==10 and p['loadout']==1 and math.isfinite(p['x']) and math.isfinite(p['y']) and p['rally'] in (0,1) and len(p['cd'])==2 and 0<=p['cd'][0]<=480 and 0<=p['cd'][1]<=900 for p in people)
    distance=sum(math.hypot(b['x']-a['x'],b['y']-a['y']) for a,b in zip(people,people[1:]));player_travel.append(distance)
    assert distance>=contract['movement']['minimum_travel_px_per_player'],('player movement',impl,role,seat,distance)
    for axis in ('x','y'):assert max(p[axis] for p in people)-min(p[axis] for p in people)>=contract['movement']['minimum_axis_span_px']
    active=sum(p['rally'] for p in people);rally_samples.append(active)
    assert active>=contract['status_requirements']['rally_samples_min_per_player'],('rally exposure',impl,role,seat,active)
    edges=[sum(b['cd'][slot]>a['cd'][slot]+120 for a,b in zip(people,people[1:])) for slot in (0,1)];rises.append(edges)
    assert edges==[2,2],('cast authority/observation edges',impl,role,seat,edges)
   if impl=='kit' and role=='client':
    for a,b in zip(trace,trace[1:]):
     segment=int(a['us']//1000000);within=a['us']%1000000
     if segment>=20 or not 150000<within<850000:continue
     direction=contract['movement']['directions'][segment%4]
     delta=[b['people'][1][axis]-a['people'][1][axis] for axis in ('x','y')]
     if sum(delta[j]*direction[j] for j in (0,1)) < -1:owner_reversals+=1
    if control['enabled']:assert owner_reversals==0,('owner rewind returned',pair,owner_reversals)
   chilled=sum(sample['chilled']>0 for sample in trace)
   assert all(type(sample['chilled'])==int and 0<=sample['chilled']<=sample['living'] for sample in trace)
   assert chilled>=contract['status_requirements']['mob_chill_samples_min'],('chill exposure',impl,role,chilled)
   final=data['final'];assert 0<final['living']<=44 and all(v>=45 for v in final['spent'])
   assert sum(final['damage'])+final['health_sum']==3*final['known']
   assert final['living']+sum(final['kills'])==final['known']
   assert sum(final['scrap'])+final['loot']==3*sum(final['kills'])
   assert all(final['spent'][i]>=trace[-1]['spent'][i] for i in (0,1))
   assert data['tx_bytes']>0
   if role=='host':
    assert final['known']==data['issued'],('all accepted spawns observed',final['known'],data['issued'])
    assert sum(final['scrap'])+final['loot']==3*sum(final['kills'])
   assert json.loads((folder/f'quiesced-{role}.json').read_text())=={'ready':True}
   text=(folder/f'{role}.log').read_text();assert 'REPLAY_MIXED_PEER_OK' in text and not any(x in text for x in ['MIXED_FAIL','REPLAY_SCRAPYARD_FAIL','SCRIPT ERROR','ERROR:','instances were leaked','resources still in use'])
   rss=[int(row['rss_kib']) for row in csv.DictReader((folder/'rss.csv').open()) if row['role']==role and row['measuring']=='1'];assert rss
   runs.append({'owner_reversals':owner_reversals,'player_travel_px':player_travel,'rally_samples':rally_samples,'cooldown_rises':rises,'chilled_samples':chilled,'pair':pair,'implementation':impl,'role':role,'samples':len(frames),'ticks_advanced':data['ticks'],'facts_ahead_p50':q([s['facts_ahead'] for s in trace],.5),'facts_ahead_p95':q([s['facts_ahead'] for s in trace],.95),'facts_ahead_max':max(s['facts_ahead'] for s in trace),'lead_min':min(s['lead'] for s in trace),'lead_max':max(s['lead'] for s in trace),'replayed_ticks':trace[-1]['replayed']-trace[0]['replayed'],'reused_ticks':trace[-1].get('reused',0)-trace[0].get('reused',0),'p50_us':q(frames,.5),'p95_us':q(frames,.95),'p99_us':q(frames,.99),'application_bytes_per_second':data['tx_bytes']*1000000/data['elapsed_us'],'rss_peak_kib':max(rss),'living_min':min(living),'living_max':max(living),'living_time_mean':mean,'observed_ids':len(seen),'kills':kills,'shots':spent,'census_p50_us':q(costs,.5),'census_p95_us':q(costs,.95)})
for pair in range(1,plan['repetitions']+1):
 for impl in ('kit','replay'):
  folder=root/f'pair-{pair}'/impl
  host=json.loads((folder/'success-host.json').read_text())['final']
  client=json.loads((folder/'success-client.json').read_text())['final']
  assert host==client,('settled convergence',pair,impl,host,client)
aggregates={}
for impl in ('kit','replay'):
 for role in ('host','client'):
  rows=[r for r in runs if r['implementation']==impl and r['role']==role]
  aggregates[impl+'/'+role]={key:{'median':statistics.median(r[key] for r in rows),'min':min(r[key] for r in rows),'max':max(r[key] for r in rows)} for key in ['p50_us','p95_us','p99_us','application_bytes_per_second','rss_peak_kib','living_time_mean','kills','census_p50_us']}
value={'correction_reuse':plan.get('correction_reuse',False),'owner_control':control,'contract':contract,'full_plan':full,'runs':runs,'aggregates':aggregates,'interpretation':'Matched moving offensive population envelope with observed status/cast work and churn. Different authority/presentation, actual shot and spawn timing remain visible. Callback elapsed time and application bytes are not CPU-only or transport overhead.'}
temporary=root/'summary.json.pending';temporary.write_text(json.dumps(value,indent=2)+'\n');temporary.replace(root/'summary.json');print('REPLAY_MIXED_REPORT_OK full_plan='+str(full).lower()+' processes='+str(len(runs)))
