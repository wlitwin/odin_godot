from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];here=Path(__file__).resolve().parent;out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_swarm_comparison/prepare.py'),str(out)],check=True)
shutil.copy2(out/'contract.json',out/'swarm-preparation-contract.json')
for impl in ('kit','replay'):
 project=out/impl/'project';baseline=impl=='kit'
 package,typ,prefix=('scrapyard_scripts','Scrapyard','scrapyard') if baseline else ('replay_scrapyard','ReplayScrapyard','replay_scrapyard')
 imports='import kn "godot:kit/net"' if baseline else 'import rgd "godot:replay/godot"'
 choose='self.settings.ab_l,self.settings.ab_r=3,4;vault_declare(self)' if baseline else 'replay_scrapyard_dev_abilities(self,3,4)'
 move='scrapyard_dev_walk(self,gd.Int(compare_move[0]),gd.Int(compare_move[1]),1)' if baseline else 'aim:=self.manual_aim;replay_scrapyard_dev_drive(self,gd.Int(compare_move[0]),gd.Int(compare_move[1]),false);self.manual_aim=aim'
 cast='accepted:=slot==0 ? bool(scrapyard_dev_cast_l(self,1,0)) : bool(scrapyard_dev_cast_r(self,1,0))' if baseline else 'accepted:=replay_scrapyard_dev_cast(self,gd.Int(slot),1,0,false)'
 capture='''
 for _,mob in self.mobs {if mob.health.hp>0 {for fx in mob.fx {if fx.kind==3 && fx.left>0 {compare_chilled+=1;break}}}}
 for i in 0..<2 {if player,ok:=runner_of(self,kn.Player_Id(i+1));ok {
  compare_people[i]={position={player.x,player.y},cooldowns={player.slime.cd,player.ignite.cd},abilities={player.ab_l,player.ab_r}}
  for fx in player.fx {if fx.kind==4 && fx.left>0 {compare_people[i].rally=true}}
 }}
''' if baseline else '''
 frame,ok:=rgd.session_authority_state(self.session);if !ok {return}
 for alive,i in frame.state.mobs.alive {if alive && frame.state.mobs.values[i].hp>0 {for fx in frame.state.mobs.values[i].fx {if fx.kind==3 && fx.left>0 {compare_chilled+=1;break}}}}
 for player,i in frame.state.players[:2] {
  compare_people[i]={position=player.position,cooldowns={u16(player.ability_cd[0].remaining),u16(player.ability_cd[1].remaining)},abilities=player.profile.abilities}
  for fx in player.fx {if fx.kind==4 && fx.left>0 {compare_people[i].rally=true}}
 }
'''
 text=f'''package {package}
import gd "godot:godot"
{imports}
Mixed_Player :: struct {{position:[2]f32,cooldowns:[2]u16,abilities:[2]u8,rally:bool}}
compare_people:[2]Mixed_Player
compare_move:[2]i32
compare_cast_pending:u8
compare_cast_sent,compare_cast_refused:[2]u32
compare_chilled:u32
// Intents are dispatched inside the already timed game callback. No world writes.
compare_mixed_tick :: proc(self:^{typ}) {{
 {move}
 for slot in 0..<2 {{if compare_cast_pending&(u8(1)<<uint(slot))!=0 {{
  {cast}
  if accepted {{compare_cast_sent[slot]+=1}} else {{compare_cast_refused[slot]+=1}}
 }}}}
 compare_cast_pending=0
}}
@(gd_method)
{prefix}_compare_choose :: proc(self:^{typ}) {{{choose}}}
@(gd_method)
{prefix}_compare_move :: proc(self:^{typ},x,y:gd.Int) {{compare_move={{i32(clamp(x,-1,1)),i32(clamp(y,-1,1))}}}}
@(gd_method)
{prefix}_compare_cast :: proc(self:^{typ},slot:gd.Int) {{if slot>=0 && slot<2 {{compare_cast_pending|=u8(1)<<uint(slot)}}}}
@(gd_method)
{prefix}_compare_mixed_census :: proc(self:^{typ}) {{compare_people={{}};compare_chilled=0;{capture}}}
@(gd_method)
{prefix}_compare_position :: proc(self:^{typ},seat:gd.Int)->gd.Vector2 {{return seat>=1 && seat<=2 ? compare_people[seat-1].position : gd.Vector2{{}}}}
@(gd_method)
{prefix}_compare_mixed_probe :: proc(self:^{typ},key:string,seat:gd.Int=1)->gd.Int {{
 if key=="chilled" {{return gd.Int(compare_chilled)}}
 if seat<1 || seat>2 {{return -1}}
 player:=compare_people[seat-1]
 switch key {{case "rally":return gd.Int(player.rally);case "cd0":return gd.Int(player.cooldowns[0]);case "cd1":return gd.Int(player.cooldowns[1]);case "loadout":return gd.Int(player.abilities==([2]u8{{3,4}}));case "sent":return gd.Int(compare_cast_sent[seat-1]);case "refused":return gd.Int(compare_cast_refused[seat-1])}}
 return -1
}}
'''
 (project/'scripts/comparison_mixed.odin').write_text(text)
 p=project/'scripts/comparison_combat.odin';s=p.read_text();start=s.index('compare_combat_tick ::');end=s.index('\n@(gd_method)',start)
 block=s[start:end];last=block.rfind('}');block=block[:last]+' compare_mixed_tick(self)\n'+block[last:];s=s[:start]+block+s[end:];p.write_text(s)
 if not baseline:
  p=project/'scripts/comparison.odin';s=p.read_text()
  s=s.replace('compare_active=true;', 'compare_active=true;if !self.session.authority {self.session.client.reuse_equal_corrections=gd.env_int("COMPARE_REUSE_EQUAL",0)==1};',1)
  s+='\n@(gd_method)\nreplay_scrapyard_compare_reused :: proc(self:^ReplayScrapyard)->gd.Int {return self.session.authority ? 0 : gd.Int(self.session.client.stats.reused_correction_ticks)}\n@(gd_method)\nreplay_scrapyard_compare_reuse_enabled :: proc(self:^ReplayScrapyard)->bool {return !self.session.authority && self.session.client.reuse_equal_corrections}\n'
  p.write_text(s)
 shutil.copy2(here/'driver.gd',project/'comparison.gd')
files=[p for p in out.rglob('*') if p.is_file() and p.suffix in ('.odin','.gd','.tscn','.tres','.png','.wav','.mp3') and not p.name.endswith('.gen.odin')]
(out/'source-sha256.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(out))+'\n' for p in sorted(files)))
shutil.copy2(here/'contract.json',out/'contract.json');print('REPLAY_MIXED_PREPARED')
