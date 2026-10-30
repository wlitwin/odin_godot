from pathlib import Path
import hashlib,json,math,statistics,sys
root=Path(sys.argv[1]);contract=json.loads((root/'contract.json').read_text());base=contract['base'];build=json.loads((root/'build.json').read_text())
assert contract['scenario']=='owner_unwind_movement_control' and contract['repetitions']==3
assert {p.name for p in root.glob('pair-*')}=={'pair-1','pair-2','pair-3'}
assert build['flags']==['-debug','-o:speed']
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for name,h in build['binaries'].items():assert digest(root/name)==h,name
frameworks={}
for variant in ('original','owner_preserved'):
 manifest=json.loads((root/variant/'source-sha256.json').read_text())
 for name,h in manifest.items():assert digest(root/variant/'project'/name)==h,name
 framework=json.loads((root/variant/'framework-source.json').read_text());frameworks[variant]=framework
 for name,h in framework['sha256'].items():assert digest(Path(framework['root'])/name)==h,name
assert json.loads((root/'original/source-sha256.json').read_text())==json.loads((root/'owner_preserved/source-sha256.json').read_text())
a,b=frameworks['original']['sha256'],frameworks['owner_preserved']['sha256'];assert a.keys()==b.keys()
assert [n for n in a if a[n]!=b[n]]==['kit/net/registry.odin']
assert contract['repair']['before_sha256']==a['kit/net/registry.odin'] and contract['repair']['after_sha256']==b['kit/net/registry.odin']
rows=[]
for pair in (1,2,3):
 for variant in ('original','owner_preserved'):
  for role in ('host','client'):
   folder=root/f'pair-{pair}'/variant;d=json.loads((folder/f'success-{role}.json').read_text());trace=d['trace']
   assert d['implementation']=='kit' and d['role']==role
   assert 19900000<=d['elapsed_us']<=20300000 and len(trace)>=1000 and len(d['frame_us'])>=1000
   assert 1180<=d['ticks']<=1220 and d['cast_sent']==[2,2] and d['cast_refused']==[0,0]
   assert len(d['movement'])==20 and len(d['casts'])==4
   for i,m in enumerate(d['movement']):assert m['direction']==base['movement']['directions'][i%4] and i*1000000<=m['us']<=i*1000000+150000
   for m,w in zip(d['casts'],base['casts']):assert m['slot']==w['slot'] and w['at_ms']*1000<=m['us']<=w['at_ms']*1000+150000
   assert all(32<=s['living']<=44 and len(s['people'])==2 for s in trace)
   for seat in (0,1):
    people=[s['people'][seat] for s in trace]
    assert all(p['hp']==10 and p['loadout']==1 for p in people)
    assert sum(p['rally'] for p in people)>=240
    assert [sum(b['cd'][j]>a['cd'][j]+120 for a,b in zip(people,people[1:])) for j in (0,1)]==[2,2]
   assert sum(s['chilled']>0 for s in trace)>=20
   final=d['final'];assert final['living']+sum(final['kills'])==final['known']
   assert sum(final['damage'])+final['health_sum']==3*final['known'] and sum(final['scrap'])+final['loot']==3*sum(final['kills'])
   packet_rewinds=0;packet_distance=0.;pending_rewinds=0;movement_reversals=0
   for sample in trace:
    audit=sample['owner_audit'];p=audit['positions'];pending=audit['pending']
    assert len(p)==len(pending)==4 and all(len(v)==2 and all(math.isfinite(x) for x in v) for v in p)
    us=sample['us'];segment=int(us//1000000);within=us%1000000
    # Skip turn boundaries: cached callback observations may be one frame old.
    if segment>=20 or not 150000<within<850000:continue
    direction=base['movement']['directions'][segment%4]
    packet=sum((p[1][j]-p[0][j])*direction[j] for j in (0,1))
    move=sum((p[3][j]-p[2][j])*direction[j] for j in (0,1))
    if packet < -1:
     packet_rewinds+=1;packet_distance-=packet;pending_rewinds+=int(pending[0]>0)
    if move < -1:movement_reversals+=1
   expected=contract['expectations']
   if role=='host':assert packet_rewinds<=expected['host_packet_rewinds_max']
   elif variant=='owner_preserved':assert packet_rewinds<=expected['control_client_packet_rewinds_max']
   else:assert packet_rewinds>=expected['original_client_packet_rewinds_min'] and pending_rewinds==packet_rewinds
   assert movement_reversals==0,('movement step reversed input',pair,variant,role)
   travel=[]
   for seat in (0,1):
    people=[s['people'][seat] for s in trace]
    travel.append(sum(math.hypot(b['x']-a['x'],b['y']-a['y']) for a,b in zip(people,people[1:])))
   log=(folder/f'{role}.log').read_text();assert 'REPLAY_MIXED_PEER_OK' in log and not any(x in log for x in ('MIXED_FAIL','SCRIPT ERROR','ERROR:','instances were leaked','resources still in use'))
   rows.append({'pair':pair,'variant':variant,'role':role,'packet_rewinds':packet_rewinds,'pending_rewinds':pending_rewinds,'backward_packet_distance':packet_distance,'movement_reversals':movement_reversals,'observed_travel':travel,'kills':sum(trace[-1]['kills']),'final':final})
  assert json.loads((folder/'success-host.json').read_text())['final']==json.loads((folder/'success-client.json').read_text())['final']
result={'contract':contract,'runs':rows,'conclusion':'The original local-owner stream rewinds during packet processing with pending predictions. The isolated owner-preserving unwind removes those rewinds in this workload. No production Kit source is changed; residual trajectory/outcome differences remain separately measurable.'}
(root/'summary.json').write_text(json.dumps(result,indent=2)+'\n');print('REPLAY_MOVEMENT_AUDIT_REPORT_OK processes='+str(len(rows)))
