from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];here=Path(__file__).resolve().parent;out=Path(sys.argv[1]).resolve()
env=os.environ.copy();env['REPLAY_COMPARISON_SCENARIO']='combat';env['REPLAY_COMPARISON_REPETITIONS']='3'
subprocess.run([sys.executable,str(root/'tests/replay_comparison/prepare.py'),str(out)],env=env,check=True)
shutil.copy2(out/'contract.json',out/'preparation-contract.json')
for impl in ('kit','replay'):
 project=out/impl/'project';fixture={}
 for name,key,value in [('data/guns/bolter.tres','mag','255'),('data/mobs/scrapbot.tres','bite','0')]:
  p=project/name;before=p.read_text();after,n=re.subn(r'^'+key+r' = \d+$',key+' = '+value,before,flags=re.M);assert n==1;p.write_text(after);fixture[name]={'before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(after.encode()).hexdigest(),'setting':{key:int(value)}}
 (out/impl/'swarm-fixture.json').write_text(json.dumps(fixture,indent=2)+'\n')
 p=project/'scripts/comparison_combat.odin';s=p.read_text();prefix='scrapyard' if impl=='kit' else 'replay_scrapyard';typ='Scrapyard' if impl=='kit' else 'ReplayScrapyard'
 s=s.replace('compare_totals:[2][3]gd.Int','compare_totals:[2][3]gd.Int\ncompare_swarm_enabled:bool\ncompare_swarm_next,compare_swarm_issued:u64')
 start=s.index(' if compare_spawn_pending {');end=s.index('\n }',start)+3
 if impl=='kit':
  source=''' if compare_swarm_enabled && self.ses.is_host && self.started {
  tick:=ks.session_tick_no(&self.ses)
  if tick>=compare_swarm_next {
   compare_swarm_next=tick+6;living:=0
   for _,mob in self.mobs {if mob.health.hp>0 {living+=1}}
   if len(self.mobs)<60 {
    for _ in 0..<min(max(40-living,0),4) {
     index:=compare_swarm_issued%40
     scrapyard_dev_spawn(self,0,2,gd.Int(100+index%5*24),gd.Int(i64(index/5)*28-98))
     compare_swarm_issued+=1
    }
   }
  }
 }'''
 else:
  source=''' if compare_swarm_enabled && self.session.authority {
  frame,ok:=rgd.session_authority_state(self.session)
  if ok && frame.tick>=compare_swarm_next {
   compare_swarm_next=frame.tick+6;living:=0
   for alive,i in frame.state.mobs.alive {if alive && frame.state.mobs.values[i].hp>0 {living+=1}}
   if frame.state.mobs.count<60 {
    for _ in 0..<min(max(40-living,0),4) {
     index:=compare_swarm_issued%40
     if replay_scrapyard_dev_spawn(self,0,2,gd.Float(100+index%5*24),gd.Float(i64(index/5)*28-98))<=0 {compare_spawn_failed=true;break}
     compare_swarm_issued+=1
    }
   }
  }
 }'''
 s=s[:start]+source+s[end:]
 s+=f'''\n@(gd_method)
{prefix}_compare_swarm :: proc(self:^{typ},enabled:bool) {{compare_swarm_enabled=enabled}}
@(gd_method)
{prefix}_compare_spawned :: proc(self:^{typ})->gd.Int {{return gd.Int(compare_swarm_issued)}}
''';p.write_text(s)
 # Runtime receipts use a shared workload driver; spawn and target-selection
 # work remain inside the timed game callback already installed by preparation.
 shutil.copy2(here/'driver.gd',project/'comparison.gd')
files=[p for p in out.rglob('*') if p.is_file() and p.suffix in ('.odin','.gd','.tscn','.tres','.png','.wav','.mp3') and not p.name.endswith('.gen.odin')]
(out/'source-sha256.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(out))+'\n' for p in sorted(files)))
shutil.copy2(here/'contract.json',out/'contract.json')
print('REPLAY_SWARM_PREPARED')
