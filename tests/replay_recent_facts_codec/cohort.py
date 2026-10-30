from pathlib import Path
import json,os,statistics,subprocess,sys
root=Path(__file__).resolve().parents[2];prepared=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=False)
orders=[['raw','compact'],['compact','raw'],['raw','compact']];results=[]
(out/'order.json').write_text(json.dumps(orders)+'\n')
for repetition,order in enumerate(orders,1):
 for mode in order:
  case=out/f'run-{repetition}-{mode}'
  with (out/f'run-{repetition}-{mode}.log').open('w') as log:
   subprocess.run([sys.executable,str(root/'tests/replay_cave_comparison/execute.py'),str(prepared),'owner',str(case)],env=os.environ|{'CAVE_COMPARE_RAW_RECENT_FACTS':'1' if mode=='raw' else '0','CAVE_COMPARE_PACKETS':'0','CAVE_COMPARE_RAW_OBSERVATIONS':'0'},stdout=log,stderr=subprocess.STDOUT,check=True)
  inputs=json.loads((case/'inputs.json').read_text())
  row={'repetition':repetition,'mode':mode,'binaries':inputs['binaries'],'processes':{}}
  if results:assert row['binaries']==results[0]['binaries']
  for role in ['host','client']:
   d=json.loads((case/f'{role}.json').read_text())
   assert d['pass'] and d['callback_dropped']==0 and len(d['callback_us'])>=800 and d['backup']>0
   assert d['final_state']['gems']==3 and d['final_state']['door']==1
   if role=='client':assert d['final_state']['confirmed']==2 and d['final_state']['visible_bag']==3
   for s in d['samples']:assert s['gems']==3 and s['visible_gems']==3 and s['mobs']==0 and s['hp']==100 and s['depth']==1
   row['processes'][role]={'bytes':d['final_state']['tx'],'kib_s':d['final_state']['tx']/(d['duration_ms']/1000)/1024,'mean_callback_us':statistics.mean(d['callback_us']),'p95_callback_us':sorted(d['callback_us'])[int(len(d['callback_us'])*.95)]}
  results.append(row);print('RECENT_FACTS_COHORT_CASE_OK',repetition,mode,flush=True)
summary={}
for mode in ['raw','compact']:
 summary[mode]={role:{key:statistics.median(row['processes'][role][key] for row in results if row['mode']==mode) for key in ['kib_s','mean_callback_us','p95_callback_us']} for role in ['host','client']}
(out/'report.json').write_text(json.dumps({'pass':True,'results':results,'summary':summary,'scope':'same binary and game contract; only negotiated recent-fact encoding differs'},indent=2)+'\n')
print('REPLAY_RECENT_FACTS_COHORT_OK',json.dumps(summary))
