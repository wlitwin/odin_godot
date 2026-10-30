from pathlib import Path
import json,math,statistics,sys
root=Path(sys.argv[1]).resolve();cases=[]
def percentile(values,fraction):return sorted(values)[min(len(values)-1,math.ceil(len(values)*fraction)-1)]
for folder in sorted(p for p in root.glob('run-*') if p.is_dir()):
 pair={role:json.loads((folder/f'{role}.json').read_text()) for role in ['host','client']}
 host,client=pair['host'],pair['client'];assert host['variant']==client['variant']
 assert abs(host['start_unix_ms']-client['start_unix_ms'])<100,'start skew'
 for role,d in pair.items():
  assert d['pass'] and d['callback_dropped']==0 and len(d['callback_us'])>=800
  assert 16000<=d['duration_ms']<17000
  for s in d['samples']:assert (role!='host' or s['gems']==3) and 0<=s['gems']<=6 and s['mobs']==0 and s['hp']==100 and s['depth']==1
  assert d['final_state']['door']==1 and d['final_state']['gems']==3 and d['backup']>0 and d['final_state']['tx']>0
 assert client['final_state']['bag']==3 and host['final_state']['other_bag']==3
 assert client['final_state']['confirmed']==2 and client['final_state']['visible_bag']==3 and client['final_state']['visible_gems']==3 and client['final_state']['visible_door']==1
 actions={a['name']:a for a in client['actions']}
 required=['east issued','east arrived','chest issued','chest arrived','loot issued','loot visible','loot confirmed','door issued','door visible','door confirmed','west issued','west arrived','return issued','return arrived']
 assert all(k in actions for k in required)
 origin=actions['east issued'];baseline=origin['state']
 visible=next(s for s in client['samples'] if s['ms']>=origin['ms'] and abs(s['render_x']-baseline['render_x'])>.25)
 observed=next(s for s in host['samples'] if s['unix_ms']>=origin['unix_ms'] and abs(s['other_x']-host['warm_state']['other_x'])>.25)
 phases={}
 for name in ['east','chest','west','return']:phases[name]=actions[name+' arrived']['ms']-actions[name+' issued']['ms']
 result={'case':folder.name,'variant':host['variant'],'start_skew_ms':abs(host['start_unix_ms']-client['start_unix_ms']),'client_render_response_ms':visible['ms']-origin['ms'],'host_pose_observation_ms':observed['unix_ms']-origin['unix_ms'],'phase_ms':phases,'processes':{}}
 for name in ['loot','door']:
  for phase in ['visible','confirmed']:result[name+'_'+phase+'_ms']=actions[name+' '+phase]['ms']-actions[name+' issued']['ms']
 for role,d in pair.items():
  times=d['callback_us'];seconds=d['duration_ms']/1000
  result['processes'][role]={'callback_mean_us':statistics.mean(times),'callback_p95_us':percentile(times,.95),'callback_p99_us':percentile(times,.99),'callback_wall_percent':sum(times)/(d['duration_ms']*1000)*100,'tx_bytes':d['final_state']['tx'],'tx_kib_s':d['final_state']['tx']/seconds/1024,'frames':len(times),'backup_receipt':d['backup'],'visible_gem_min':min(s['visible_gems'] for s in d['samples']),'visible_gem_max':max(s['visible_gems'] for s in d['samples']),'visible_gem_unsettled_ms':sum(b['ms']-a['ms'] for a,b in zip(d['samples'],d['samples'][1:]) if a['visible_gems']!=3)}
 cases.append(result)
assert len(cases)==9 and all(sum(c['variant']==v for c in cases)==3 for v in ['kit','server','owner'])
summary={}
for variant in ['kit','server','owner']:
 rows=[c for c in cases if c['variant']==variant];summary[variant]={'processes':{},'timing':{}}
 for role in ['host','client']:
  summary[variant]['processes'][role]={}
  for key in ['callback_mean_us','callback_p95_us','callback_p99_us','callback_wall_percent','tx_kib_s']:
   values=[c['processes'][role][key] for c in rows];summary[variant]['processes'][role][key]={'median':statistics.median(values),'min':min(values),'max':max(values)}
 for key in ['client_render_response_ms','host_pose_observation_ms','loot_visible_ms','loot_confirmed_ms','door_visible_ms','door_confirmed_ms']:
  values=[c[key] for c in rows];summary[variant]['timing'][key]={'median':statistics.median(values),'min':min(values),'max':max(values)}
(root/'report.json').write_text(json.dumps({'pass':True,'cases':cases,'summary':summary,'scope':'quiet two-player interaction profile; callback wall time and application bytes, not total CPU/network cost'},indent=2)+'\n')
print('REPLAY_CAVE_COMPARISON_REPORT_OK',len(cases),'pairs')
print(json.dumps(summary,indent=2))
