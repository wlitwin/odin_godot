"""Shared gameplay/observation gates; transport/build provenance is checked by callers."""
import csv,json,math

def q(values,p):return sorted(values)[max(0,math.ceil(len(values)*p)-1)]
def jam_roll(salt,spent):
 h=(salt*2654435761+spent*40503+668265263)&0xffffffff;h^=h>>15;h=h*2246822519&0xffffffff;h^=h>>13;return h%1000

def jam_count(salt,spent,contract):return sum(jam_roll(salt,n)<contract['weapon']['jam_per_mille'] for n in range(spent))

def gun_valid(g):
 assert type(g['salt'])==int and 0<=g['salt']<=0xffffffff and type(g['taps'])==int and 0<=g['taps']<=3
 assert g['mode'] in (0,1,2) and (g['mode']==2)==(g['taps']>0)
 assert 0<=g['ammo']<=8 and 0<=g['spent']<=100
 remainder=g['spent']%8
 assert g['ammo']==8-remainder if remainder else g['ammo'] in ((0,8) if g['mode']==0 else (0,))
 if g['mode']==1:assert g['ammo']==0

def validate_condition(root,contract,plan,implementations,control,condition,verify_proxy):
 policy=contract['conditions'][condition];runs=[]
 assert {p.name for p in (root/condition).glob('pair-*')}=={'pair-'+str(i) for i in range(1,plan['repetitions']+1)}
 for pair in range(1,plan['repetitions']+1):
  for impl in implementations:
   for role in ('host','client'):
    folder=root/condition/f'pair-{pair}'/impl
    if role=='host' and policy['raw_udp'] is not None:
     proxy=verify_proxy(folder/'proxy',policy['raw_udp'])
     for direction in proxy['directions'].values():assert direction['loss_dropped_packets']>0 and direction['duplicated_packets']>0
    data=json.loads((folder/f'success-{role}.json').read_text())
    assert data['implementation']==impl and data['role']==role and data['condition']==condition
    assert data.get('reuse_enabled',False)==(plan.get('correction_reuse',False) and impl=='replay' and role=='client')
    assert 19900000<=data['elapsed_us']<=20300000
    low,high=contract['freshness']['authority_tick_advance' if role=='host' or impl=='kit' else 'client_received_tick_advance']
    if impl=='replay' and role=='client':low=policy['minimum_client_ticks']
    assert low<=data['ticks']<=high
    warmup=data['warmup'];assert warmup['steady_ms']>=2000
    assert warmup['prediction_depth']<=warmup['lead']+30 and warmup['facts_ahead']<=30
    frames=data['frame_us'];times=data['frame_at_us'];all_trace=data['trace'];trace=[s for s in all_trace if s.get('ready',True)];costs=data['census_us']
    assert len(frames)==len(times)>=1000 and all(type(v)==int and v>=0 for v in frames)
    assert times==sorted(times) and min(times)>=0 and max(times)<=data['elapsed_us']+100000
    assert len(all_trace)==len(costs)>=1000 and len(trace)>=1000 and all(type(v)==int and v>=0 for v in costs)
    assert all(all_trace[i]['us']<all_trace[i+1]['us'] for i in range(len(all_trace)-1))
    unavailable_us=sum(b['us']-a['us'] for a,b in zip(all_trace,all_trace[1:]) if not a.get('ready',True))
    assert unavailable_us<=policy['maximum_unavailable_ms']*1000
    assert all(s['resyncs']>0 and 0<=s['reason']<=4 for s in all_trace if not s.get('ready',True))
    assert all(a['tick']<=b['tick'] or b['resyncs']>a['resyncs'] for a,b in zip(trace,trace[1:]))
    assert trace[-1]['us']-trace[0]['us']>=19500000
    assert all(0<=s['facts_ahead']<=policy['max_facts_ahead'] and 0<=s['prediction_depth']<=s['lead']+policy['max_facts_ahead'] for s in trace)
    assert 0<=all_trace[-1]['resyncs']-all_trace[0]['resyncs']<=policy['max_resyncs']
    assert all(type(s.get('reused',0))==int and s.get('reused',0)>=0 for s in trace)
    assert all(a.get('reused',0)<=b.get('reused',0) for a,b in zip(trace,trace[1:]))
    if not data.get('reuse_enabled',False):assert trace[-1].get('reused',0)==0
    if 'snapshot_every' in plan:assert data.get('snapshot_every')==(plan['snapshot_every'] if impl=='replay' else 0),('snapshot interval',impl,role)
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
    assert all(20<=v<=45 for v in spent),('shots',impl,role,spent)
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
    prediction_refused=0
    if impl=='kit':
     receipts=data['cast_receipts'];assert len(receipts)==4
     assert [r['slot'] for r in receipts]==[e['slot'] for e in contract['casts']]
     for receipt in receipts:
      assert receipt['seen']==1 and receipt['model']==0 and receipt['state'] in (0,1,2) and 0<=receipt['reason']<=6
      assert receipt['submitted']==int(receipt['sequence']>0 or receipt['state']==2)==1
      if role=='host':assert receipt['sequence']==0 and receipt['state']==2 and receipt['reason']==0
      else:
       assert receipt['sequence']>0 and receipt['state'] in (0,1)
       assert receipt['reason']==(5 if receipt['state']==0 else 0)
       prediction_refused+=receipt['state']==0
     if role=='client':assert all(a['sequence']<b['sequence'] for a,b in zip(receipts,receipts[1:]))
    else:assert data['cast_receipts']==[]

    if impl=='replay':assert data['dash_receipts']=={'submitted':10,'confirmed':10,'refused':0,'pending':0,'captured':0},('dash outcomes',condition,pair,role,data['dash_receipts'])
    else:assert data['dash_receipts']=={}
    assert len(data['dashes'])==10
    for event,ms in zip(data['dashes'],contract['dash_ms']):assert ms*1000<=event['us']<=ms*1000+150000
    expected_hazards=contract['hazards'] if role=='host' else []
    assert len(data['hazards'])==len(expected_hazards) and data['hazards_sent']==(12 if role=='host' else 0) and data['hazards_refused']==0
    for event,wanted in zip(data['hazards'],expected_hazards):assert event['status']==wanted['status'] and wanted['at_ms']*1000<=event['us']<=wanted['at_ms']*1000+150000
    player_travel=[];rally_samples=[];rises=[];health_work=[];jam_work=[]
    owner_reversals=0
    for seat in (0,1):
     people=[sample['people'][seat] for sample in trace]
     assert all(len(sample['people'])==2 for sample in trace)
     assert all(1<=p['hp']<=10 and p['loadout']==1 and math.isfinite(p['x']) and math.isfinite(p['y']) and p['rally'] in (0,1) and len(p['cd'])==2 and 0<=p['cd'][0]<=480 and 0<=p['cd'][1]<=900 for p in people)
     distance=sum(math.hypot(b['x']-a['x'],b['y']-a['y']) for a,b in zip(people,people[1:]));player_travel.append(distance)
     assert distance>=contract['movement']['minimum_travel_px_per_player'],('player movement',impl,role,seat,distance)
     for axis in ('x','y'):assert max(p[axis] for p in people)-min(p[axis] for p in people)>=contract['movement']['minimum_axis_span_px']
     active=sum(p['rally'] for p in people);rally_samples.append(active)
     assert active>=contract['status_requirements']['rally_samples_min_per_player'],('rally exposure',impl,role,seat,active)
     edges=[sum(b['cd'][slot]>a['cd'][slot]+120 for a,b in zip(people,people[1:])) for slot in (0,1)];rises.append(edges)
     assert edges==[2,2],('cast authority/observation edges',impl,role,seat,edges)
     health=contract['health_requirements']
     drops=sum(b['hp']<a['hp'] for a,b in zip(people,people[1:]));heals=sum(b['hp']>a['hp'] for a,b in zip(people,people[1:]))
     burn=sum(p['burn'] for p in people);salve=sum(p['salve'] for p in people);surge=sum(p['surge'] for p in people)
     reloads=sum(a['mode']!=1 and b['mode']==1 for a,b in zip(people,people[1:]))
     assert all(p['burn'] in (0,1) and p['salve'] in (0,1) and p['surge'] in (0,1) and p['mode'] in (0,1,2) and 0<=p['dashes']<=10 for p in people)
     assert drops>=health['minimum_hp_drops'] and heals>=health['minimum_hp_rises'],('damage/healing',condition,impl,role,seat,drops,heals)
     assert burn>=health['minimum_burn_samples'] and salve>=health['minimum_salve_samples'] and surge>=health['minimum_surge_samples'],('status work',condition,impl,role,seat,burn,salve,surge)
     assert reloads>=health['minimum_reload_entries'],('reload work',condition,impl,role,seat,reloads)
     assert people[-1]['dashes']-people[0]['dashes']==10,('dash work',condition,impl,role,seat)
     health_work.append({'hp_min':min(p['hp'] for p in people),'drops':drops,'heals':heals,'burn_samples':burn,'salve_samples':salve,'surge_samples':surge,'reloads':reloads,'dashes':people[-1]['dashes']})
     salts={p['salt'] for p in people};assert len(salts)==1;salt=next(iter(salts))
     for sample,person in zip(trace,people):
      gun={**person,'ammo':sample['ammo'][seat],'spent':sample['spent'][seat]};gun_valid(gun)
      if role=='host' or impl=='replay':assert gun['shots']+jam_count(salt,gun['spent'],contract)==gun['spent'],('dud/shot conservation',condition,impl,role,seat)
      else:assert gun['shots']==-1
     entries=sum(a['mode']!=2 and b['mode']==2 for a,b in zip(people,people[1:]));cleared=sum(a['mode']==2 and b['mode']==0 for a,b in zip(people,people[1:]))
     exposure=sum(p['mode']==2 for p in people);assert exposure>=30,('jam exposure',impl,role,seat)
     expected_jams=jam_count(salt,trace[-1]['spent'][seat],contract)
     assert expected_jams>=contract['jam_requirements']['minimum_jams_per_player']
     assert expected_jams-(people[-1]['mode']==2)>=contract['jam_requirements']['minimum_cleared_per_player']
     if role=='host' and impl=='replay':assert entries==expected_jams and cleared==expected_jams-(people[-1]['mode']==2)
     jam_work.append({'salt':salt,'expected_jams':expected_jams,'observed_entries':entries,'observed_cleared':cleared,'jam_samples':exposure,'spent':trace[-1]['spent'][seat],'shots':people[-1]['shots']})

 
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
    final=data['final'];assert data['final_ready'];assert len(final['hp'])==2 and all(1<=hp<=10 for hp in final['hp']) and final['dashes']==[10,10];assert 0<final['living']<=44 and all(v>=20 for v in final['spent'])
    if role=='host' or condition=='delay':assert sum(final['damage'])+final['health_sum']==3*final['known']
    if role=='host' or condition=='delay':assert final['living']+sum(final['kills'])==final['known']
    assert sum(final['scrap'])+final['loot']==3*sum(final['kills'])
    assert all(final['spent'][i]>=trace[-1]['spent'][i] for i in (0,1))
    assert len(data['final_guns'])==2
    for seat,gun in enumerate(data['final_guns']):
     gun_valid(gun);assert gun['mode'] in (0,2)
     expected_jams=jam_count(gun['salt'],gun['spent'],contract)
     if role=='host' or impl=='replay':assert gun['shots']+expected_jams==gun['spent']
     else:assert gun['shots']==-1
     if impl=='kit' and role=='host':
      pulls=gun['pulls'];assert len(pulls)==6 and all(type(x)==int and x>=0 for x in pulls)
      assert pulls[1]==gun['shots'] and pulls[2]==expected_jams
      assert pulls[5]==expected_jams-(gun['mode']==2)
      assert pulls[4]==2*pulls[5]+(3-gun['taps'] if gun['mode']==2 else 0)
    assert data['tx_bytes']>0
    if role=='host':
     assert final['known']==data['issued'],('all accepted spawns observed',final['known'],data['issued'])
     assert sum(final['scrap'])+final['loot']==3*sum(final['kills'])
    assert json.loads((folder/f'quiesced-{role}.json').read_text())=={'ready':True}
    text=(folder/f'{role}.log').read_text();assert 'REPLAY_JAM_PEER_OK' in text and not any(x in text for x in ['JAM_WORKLOAD_FAIL','REPLAY_SCRAPYARD_FAIL','SCRIPT ERROR','ERROR:','instances were leaked','resources still in use'])
    rss=[int(row['rss_kib']) for row in csv.DictReader((folder/'rss.csv').open()) if row['role']==role and row['measuring']=='1'];assert rss
    progress_gaps=[];last_tick=trace[0]['tick'];last_at=trace[0]['us']
    for sample in trace[1:]:
     if sample['tick']>last_tick:progress_gaps.append(sample['us']-last_at);last_tick,last_at=sample['tick'],sample['us']
    progress_gaps.append(all_trace[-1]['us']-last_at)
    stalls=trace[-1].get('stalls',0)-trace[0].get('stalls',0);catchups=trace[-1].get('catchups',0)-trace[0].get('catchups',0)
    assert stalls>=0 and catchups>=0
    runs.append({'jam_work':jam_work,'local_prediction_refusals':prediction_refused,'prediction_stalls':stalls,'snapshot_catchups':catchups,'max_observed_tick_gap_us':max(progress_gaps),'condition':condition,'settle_resyncs':data['final_resyncs']-all_trace[-1]['resyncs'],'unavailable_us':unavailable_us,'warmup_resyncs':all_trace[0]['resyncs'],'health_work':health_work,'resyncs':all_trace[-1]['resyncs']-all_trace[0]['resyncs'],'owner_reversals':owner_reversals,'player_travel_px':player_travel,'rally_samples':rally_samples,'cooldown_rises':rises,'chilled_samples':chilled,'pair':pair,'implementation':impl,'role':role,'samples':len(frames),'ticks_advanced':data['ticks'],'facts_ahead_p50':q([s['facts_ahead'] for s in trace],.5),'facts_ahead_p95':q([s['facts_ahead'] for s in trace],.95),'facts_ahead_max':max(s['facts_ahead'] for s in trace),'lead_min':min(s['lead'] for s in trace),'lead_max':max(s['lead'] for s in trace),'replayed_ticks':trace[-1]['replayed']-trace[0]['replayed'],'reused_ticks':trace[-1].get('reused',0)-trace[0].get('reused',0),'p50_us':q(frames,.5),'p95_us':q(frames,.95),'p99_us':q(frames,.99),'application_bytes_per_second':data['tx_bytes']*1000000/data['elapsed_us'],'rss_peak_kib':max(rss),'living_min':min(living),'living_max':max(living),'living_time_mean':mean,'observed_ids':len(seen),'kills':kills,'shots':spent,'census_p50_us':q(costs,.5),'census_p95_us':q(costs,.95)})
 for pair in range(1,plan['repetitions']+1):
  for impl in implementations:
   folder=root/condition/f'pair-{pair}'/impl
   host=json.loads((folder/'success-host.json').read_text())['final']
   client=json.loads((folder/'success-client.json').read_text())['final']
   assert {k:v for k,v in host.items() if k!='known'}=={k:v for k,v in client.items() if k!='known'},('settled convergence',condition,pair,impl,host,client)
   host_guns=json.loads((folder/'success-host.json').read_text())['final_guns'];client_guns=json.loads((folder/'success-client.json').read_text())['final_guns']
   for h,c in zip(host_guns,client_guns):assert {k:v for k,v in h.items() if k not in ('shots','pulls')}=={k:v for k,v in c.items() if k not in ('shots','pulls')}

 return runs
