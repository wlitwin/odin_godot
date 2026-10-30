"""Read-only combat census and intent adapters for isolated comparison projects."""
from pathlib import Path

def install(project, baseline):
    package, typ, prefix = ('scrapyard_scripts','Scrapyard','scrapyard') if baseline else ('replay_scrapyard','ReplayScrapyard','replay_scrapyard')
    imports = 'import ks "godot:kit/session"\nimport kn "godot:kit/net"' if baseline else 'import rgd "godot:replay/godot"'
    capture = '''
 compare_enemy_count=0;compare_alive=0;compare_drop_count=gd.Int(len(self.scraps));compare_loot=0;compare_stats_ready=true
 for _,drop in self.scraps {compare_loot+=gd.Int(drop.amount)}
 for id,mob in self.mobs {
  if compare_enemy_count==len(compare_enemies) {compare_census_overflow=true;break}
  compare_enemies[compare_enemy_count]={u64(id),{mob.x,mob.y},u16(mob.health.hp),mob.kind};compare_enemy_count+=1
  if mob.health.hp>0 {compare_alive+=1}
 }
 for i in 0..<2 {
  for name,column in ([3]string{"damage","kills","scrap"}) {
   col,found:=ks.session_stat_find(&self.ses,name)
   if !found {compare_stats_ready=false;compare_totals[i][column]=0;continue}
   compare_totals[i][column]=gd.Int(ks.session_stat(&self.ses,kn.Player_Id(i+1),col))
  }
 }
''' if baseline else '''
 frame,ok:=rgd.session_authority_state(self.session);compare_enemy_count=0;compare_alive=0;compare_drop_count=0;compare_loot=0;compare_stats_ready=ok
 if !ok {return}
 compare_drop_count=gd.Int(frame.state.drops.count)
 for alive,i in frame.state.drops.alive {if alive {compare_loot+=gd.Int(frame.state.drops.values[i].amount)}}
 for alive,i in frame.state.mobs.alive {if alive {
  if compare_enemy_count==len(compare_enemies) {compare_census_overflow=true;break}
  mob:=frame.state.mobs.values[i]
  compare_enemies[compare_enemy_count]={u64(frame.state.mobs.generations[i])<<32|u64(i+1),mob.position,mob.hp,mob.kind};compare_enemy_count+=1
  if mob.hp>0 {compare_alive+=1}
 }}
 for player,i in frame.state.players[:2] {compare_totals[i]={gd.Int(player.damage),gd.Int(player.kills),gd.Int(player.scrap)}}
'''
    spawn = 'scrapyard_dev_spawn(self,0,2,gd.Int(offset[0]),gd.Int(offset[1]))' if baseline else 'if replay_scrapyard_dev_spawn(self,0,2,gd.Float(offset[0]),gd.Float(offset[1]))<=0 {compare_spawn_failed=true}'
    target = '' if baseline else 'if compare_combat_held {replay_scrapyard_dev_stress_fire(self)}'
    text = f'''package {package}
import gd "godot:godot"
{imports}
Compare_Enemy :: struct {{id:u64,position:[2]f32,hp:u16,kind:u8}}
compare_enemies:[64]Compare_Enemy
compare_enemy_count:int
compare_alive,compare_drop_count,compare_loot:gd.Int
compare_totals:[2][3]gd.Int
compare_stats_ready,compare_census_overflow,compare_spawn_failed,compare_spawn_pending,compare_combat_held:bool
// Both spawn and targeting work execute within the timed real game callback.
compare_combat_tick :: proc(self:^{typ}) {{
 if compare_spawn_pending {{
  compare_spawn_pending=false
  for offset in ([4][2]i32{{{{80,-20}},{{80,0}},{{80,20}},{{100,0}}}}) {{{spawn}}}
 }}
 {target}
}}
@(gd_method)
{prefix}_compare_spawn :: proc(self:^{typ}) {{compare_spawn_pending=true}}
@(gd_method)
{prefix}_compare_census :: proc(self:^{typ}) {{ {capture} }}
@(gd_method)
{prefix}_compare_combat_probe :: proc(self:^{typ},key:string,seat:gd.Int)->gd.Int {{
 switch key {{case "living":return compare_alive;case "bodies":return gd.Int(compare_enemy_count);case "drops":return compare_drop_count;case "loot":return compare_loot;
 case "stats_ready":return gd.Int(compare_stats_ready);case "census_overflow":return gd.Int(compare_census_overflow);case "spawn_failed":return gd.Int(compare_spawn_failed)}}
 if seat<1 || seat>2 {{return -1}}
 switch key {{case "damage":return compare_totals[seat-1][0];case "kills":return compare_totals[seat-1][1];case "scrap":return compare_totals[seat-1][2]}}
 return -1
}}
@(gd_method)
{prefix}_compare_enemy :: proc(self:^{typ},index:gd.Int)->gd.Vector3 {{
 if index<0 || index>=gd.Int(compare_enemy_count) {{return {{}}}}
 e:=compare_enemies[index];return {{e.position[0],e.position[1],f32(e.hp)}}
}}
@(gd_method)
{prefix}_compare_enemy_id :: proc(self:^{typ},index:gd.Int)->gd.Int {{return index>=0 && index<gd.Int(compare_enemy_count) ? gd.Int(compare_enemies[index].id) : -1}}
@(gd_method)
{prefix}_compare_enemy_kind :: proc(self:^{typ},index:gd.Int)->gd.Int {{return index>=0 && index<gd.Int(compare_enemy_count) ? gd.Int(compare_enemies[index].kind) : -1}}
'''
    (project/'scripts/comparison_combat.odin').write_text(text)
    p=project/'scripts/comparison.odin';s=p.read_text().replace('compare_samples:[4096]u64','compare_samples:[4096]u64\ncompare_sample_times:[4096]u64')
    s=s.replace('compare_samples[compare_count]=gd.time_get_ticks_usec', 'compare_sample_times[compare_count]=gd.time_get_ticks_usec(gd.singleton_time())\n compare_samples[compare_count]=gd.time_get_ticks_usec')
    s=s.replace(f'{prefix}_compare_trigger :: proc(self:^{typ},enabled:bool) {{',f'{prefix}_compare_trigger :: proc(self:^{typ},enabled:bool) {{compare_combat_held=enabled;')
    s+=f'''\n@(gd_method)
{prefix}_compare_sample_time :: proc(self:^{typ},index:gd.Int)->gd.Int {{return index>=0 && index<gd.Int(compare_count) ? gd.Int(compare_sample_times[index]) : -1}}
'''
    p.write_text(s)
    p=project/'scripts/scrapyard.odin';s=p.read_text();needle='defer if compare_started!=0 {compare_note(compare_started)}';assert s.count(needle)==1
    p.write_text(s.replace(needle,needle+'\n compare_combat_tick(self)'))
