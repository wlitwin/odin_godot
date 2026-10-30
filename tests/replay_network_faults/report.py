from pathlib import Path
import hashlib,json,math,sys
from proxy_report import verify as verify_proxy
root=Path(sys.argv[1]);contract=json.loads((root/'contract.json').read_text());assert contract==json.loads(Path(__file__).with_name('contract.json').read_text())
plan=json.loads((root/'run-plan.json').read_text());pilot=sys.argv[2:]==['--pilot']
assert plan==({'repetitions':1,'conditions':['lossy']} if pilot else {'repetitions':2,'conditions':['lossy','rate_limited']})
for name,digest in json.loads((root/'build-manifest.json').read_text())['binaries'].items():assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest
for line in (root/'source-sha256.txt').read_text().splitlines():
 digest,name=line.split('  ',1);assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest
framework=json.loads((root/'framework-source.json').read_text())
for name,digest in framework['sha256'].items():assert hashlib.sha256((Path(framework['root'])/name).read_bytes()).hexdigest()==digest
assert {p.name for p in root.glob('pair-*')}=={f'pair-{i}' for i in range(1,plan['repetitions']+1)}
runs=[]
proxies=[]
def q(values,p):return sorted(values)[max(0,math.ceil(len(values)*p)-1)]
for pair in range(1,plan['repetitions']+1):
 for condition in plan['conditions']:
  folder=root/f'pair-{pair}'/condition;host=json.loads((folder/'success-host.json').read_text());client=json.loads((folder/'success-client.json').read_text())
  proxy=verify_proxy(folder/'proxy',contract['conditions'][condition]);proxies.append({'pair':pair,'condition':condition,**proxy})
  for direction in proxy['directions'].values():
   assert direction['received_packets']>100 and direction['loss_dropped_packets']>0 and direction['duplicated_packets']>0
   assert direction['max_queued_packets']<=128 and direction['max_queued_bytes']<=65536
   assert direction['scheduled_packets']==direction['forwarded_packets']+direction['shutdown_dropped_packets']
  for role,data in [('host',host),('client',client)]:
   assert data['role']==role and data['implementation']=='replay'
   assert 19900000<=data['elapsed_us']<=20300000 and len(data['frame_us'])>=1000
   assert all(type(v)==int and v>=0 for v in data['frame_us'])
   assert len(data['frame_at_us'])==len(data['frame_us']) and data['frame_at_us']==sorted(data['frame_at_us'])
   assert [v['fire'] for v in data['inputs']]==[True,False]
   assert 0<=data['inputs'][0]['us']<=10000 and 19900000<=data['inputs'][1]['us']<=20400000
   assert 1180<=data['ticks']<=1220 if role=='host' else data['ticks']>=1000
   all_trace=data['trace'];trace=[s for s in all_trace if s['ready']];assert len(trace)>=1000 and trace[-1]['us']-trace[0]['us']>=19500000
   assert all(trace[i]['us']<trace[i+1]['us'] for i in range(len(trace)-1))
   assert all_trace[-1]['resyncs']-all_trace[0]['resyncs']<=3
   assert data['final']['ready'] and data['final']['tick']>=trace[-1]['tick']
   if role=='host':
    assert all(45<=trace[-1]['spent'][i]-data['shots_before'][i]<=75 for i in (0,1))
    assert all(32<=s['living']<=44 for s in trace)
    assert sum(trace[-1]['kills'])-data['kills_before']>=20
    seen=set(data['initial_ids'])
    for s in trace:
     seen.update(e['id'] for e in s['enemies'])
     assert sum(s['damage'])+sum(e['hp'] for e in s['enemies'])==3*len(seen)
     assert sum(s['kills'])+s['living']==len(seen)
     assert sum(s['scrap'])+s['loot']==3*sum(s['kills'])
    assert data['final']['known']==data['issued']
   text=(folder/f'{role}.log').read_text();assert 'REPLAY_NETWORK_FAULT_PEER_OK' in text and not any(s in text for s in ['SWARM_FAIL','REPLAY_SCRAPYARD_FAIL','ERROR:','SCRIPT ERROR','instances were leaked','resources still in use'])
   assert json.loads((folder/f'quiesced-{role}.json').read_text())=={'ready':True}
   runs.append({'pair':pair,'condition':condition,'role':role,'ticks':data['ticks'],'samples':len(trace),'unavailable_samples':len(all_trace)-len(trace),'resyncs':all_trace[-1]['resyncs']-all_trace[0]['resyncs'],'facts_lag_p50':q([s['facts_ahead'] for s in trace],.5),'facts_lag_p95':q([s['facts_ahead'] for s in trace],.95),'callback_p50_us':q(data['frame_us'],.5),'callback_p95_us':q(data['frame_us'],.95),'application_bytes_per_second':data['tx_bytes']*1e6/data['elapsed_us'],'final':data['final']})
  assert {k:v for k,v in host['final'].items() if k not in ('known','tick','resyncs')}=={k:v for k,v in client['final'].items() if k not in ('known','tick','resyncs')},('final convergence',condition)
value={'contract':contract,'pilot':pilot,'runs':runs,'proxies':proxies};pending=root/'summary.json.pending';pending.write_text(json.dumps(value,indent=2)+'\n');pending.replace(root/'summary.json');print('REPLAY_NETWORK_FAULT_REPORT_OK processes='+str(len(runs)))
