from pathlib import Path
import json,re,sys
run=Path(sys.argv[1]).resolve();browser=len(sys.argv)>2 and sys.argv[2]=='browser';logs=run/'browser' if browser else run
records=[]
for path in sorted(logs.glob('*.log')):
 text=path.read_text();restored=re.findall(r'DEDICATED_COMBAT_RESTORED epoch=(\d+) tick=(\d+) shots=(\d+) casts=(\d+) kills=(\d+) living=(\d+) projectiles=(\d+) lobs=(\d+) zones=(\d+)',text)
 continued=re.findall(r'DEDICATED_COMBAT_CONTINUED epoch=(\d+) shots=(\d+) casts=(\d+) kills=(\d+)',text)
 for values in restored:
  epoch,tick,shots,casts,kills,living,projectiles,lobs,zones=map(int,values)
  assert living>0 and projectiles+lobs+zones>0 and shots>=8 and casts>=2
  matches=[tuple(map(int,c)) for c in continued if int(c[0])==epoch];assert matches,(path,'missing continuation')
  after=matches[0];assert after[1]>=shots+10 and after[2]>=casts+2 and after[3]>kills,(path,values,after)
  assert text.index('DEDICATED_COMBAT_CONTINUED')>text.index('DEDICATED_COMBAT_RESTORED'),'continuation checked before restore baseline'
  records.append({'process':path.name,'epoch':epoch,'checkpoint_tick':tick,'before':{'shots':shots,'casts':casts,'kills':kills,'living':living,'projectiles':projectiles,'lobs':lobs,'zones':zones},'after':{'shots':after[1],'casts':after[2],'kills':after[3]}})
assert records,'no combat recovery receipts'
assert any(re.search(r'peak=(?:[3-9]\d|[1-9]\d{2,})',p.read_text()) for p in logs.glob('*.log'))
(run/'combat-result.json').write_text(json.dumps({'pass':True,'records':records},indent=2)+'\n');print('REPLAY_DEDICATED_COMBAT_VERIFIED')
