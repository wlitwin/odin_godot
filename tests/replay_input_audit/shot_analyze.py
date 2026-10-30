"""Reconcile every recorded ballistic shot with terminal cause and world totals."""
from pathlib import Path
import json,re,sys

def analyze(root):
 manifest=json.loads((root/'audit-manifest.json').read_text());assert manifest.get('shots') is True
 runs=[]
 for folder in sorted(root.glob('pair-*/lossy')):
  if not (folder/'success-host.json').exists():continue
  records=[];counts=[]
  for line in (folder/'host.log').read_text().splitlines():
   fields={k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',line)}
   if line.startswith('INPUT_AUDIT_COUNT '):counts.append(fields)
   if line.startswith(('INPUT_SHOT_BORN ','INPUT_SHOT_END ')):records.append({'kind':line.split()[0],**fields})
  assert len(counts)==1 and counts[0]['dropped']==0,('missing/overflowed buffer',folder)
  data=json.loads((folder/'success-host.json').read_text());assert data['implementation']=='replay' and data['role']=='host'
  assert data['shots_before']==[0,0] and data['kills_before']==0 and data['final_ready']
  born={};ended={}
  for e in records:
   key=(e['seat'],e['shot']);assert e['seat'] in (1,2)
   target=born if e['kind']=='INPUT_SHOT_BORN' else ended
   assert key not in target,('duplicate shot record',key);target[key]=e
  assert born.keys()==ended.keys(),('unterminated or unrecorded shots',born.keys()-ended.keys(),ended.keys()-born.keys())
  seats=[]
  for seat in (1,2):
   keys=[key for key in born if key[0]==seat];causes={'miss':0,'cover':0,'mob':0};damage=0;kills=0
   for key in keys:
    b,e=born[key],ended[key]
    assert b['family']==0 and b['damage']>0 and e['tick']>=b['tick'] and e['reason'] in (0,1,2)
    causes[('miss','cover','mob')[e['reason']]]+=1
    if e['reason']==2:
     assert 0<=e['hp_after']<e['hp_before']<=3
     damage+=e['hp_before']-e['hp_after'];kills+=e['hp_after']==0
    else:assert e['hp_before']==e['hp_after']==0
   assert len(keys)==data['final_guns'][seat-1]['shots'],('fired accounting',folder,seat)
   assert damage==data['final']['damage'][seat-1],('damage accounting',folder,seat,damage)
   assert kills==data['final']['kills'][seat-1],('kill accounting',folder,seat,kills)
   seats.append({'seat':seat,'fired':len(keys),'terminal':causes,'actual_damage':damage,'kills':kills,'shot_damage_values':sorted({born[key]['damage'] for key in keys})})
  end_tick=data['trace'][-1]['tick']
  window_kills=sum(e['reason']==2 and e['hp_after']==0 and e['tick']<=end_tick for e in ended.values())
  assert window_kills==sum(data['trace'][-1]['kills'])
  runs.append({'pair':folder.parent.name,'kills_in_window':window_kills,'seats':seats,'born':list(born.values()),'ended':list(ended.values())})
 assert runs,'no complete authority ledger'
 return {'scope':'Instrumented Replay authority ballistic ledger; exact shot/damage/kill accounting for completed runs, not paired workload acceptance or a performance measurement.','runs':runs}

if __name__=='__main__':
 root=Path(sys.argv[1]);value=analyze(root)
 (root/'shot-audit.json').write_text(json.dumps(value,indent=2)+'\n')
 for run in value['runs']:print(run['pair'],'window_kills='+str(run['kills_in_window']),run['seats'])
 print('REPLAY_SHOT_AUDIT_OK runs='+str(len(value['runs'])))
