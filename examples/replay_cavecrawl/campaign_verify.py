from pathlib import Path
import json,sys
root=Path(sys.argv[1])
def read(name):return json.loads((root/(name+'.json')).read_text())
roles=('host','client','observer')
phases=('join','loot','drop','grab','carry','setdown','positions','death','revive','stale','reclaim','heal','respawn_positions','bleedout','regather','fight1','exit1','loot2','fight2','exit2')
for role in roles:
 for phase in phases:assert (root/(phase+'-'+role+'.json')).is_file(),(role,phase)
 assert read('complete-'+role)['done']
 assert read('complete-'+role)['deaths']==2
finish=read('finish')
for role in roles:
 witness=read('hash-'+role)
 assert witness==finish,(role,witness,finish)
 assert finish['tick']>=read('exit2-'+role)['head'],('victory comparison preceded completion',role)
for role in ('host','client'):
 assert read('grab-'+role)['gems']==3
 assert read('death-'+role)['gems']==3
 assert read('reclaim-'+role)['gems']==3
 assert read('regather-'+role)['gems']==3
 assert read('fight1-'+role)['slain']==5
 assert read('fight2-'+role)['slain']==12
 assert read('exit2-'+role)['gems']==8 and read('exit2-'+role)['depth']==2
 assert read('bleedout-'+role)['head']>=read('respawn-deadline')['tick']
environment=read('environment')
if environment['loss_permyriad']>0:assert sum(read('complete-'+role)['drops'] for role in roles)>0
if environment['duplicate_permyriad']>0:assert sum(read('complete-'+role)['duplicates'] for role in roles)>0
summary={'environment':environment,'roles':list(roles),'phases':len(phases),'victory_tick':finish['tick'],'world_hash':finish['hash'],'depth':2,'slain':12,'gems':8,'death_paths':['revive before deadline','automatic respawn at deadline'],'source':'ordinary actions and movement; no world edits'}
(root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print('REPLAY_CAVE_CAMPAIGN_RECEIPTS_OK')
