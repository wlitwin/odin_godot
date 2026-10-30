package replay_scrapyard
import gd "godot:godot"
import rgd "godot:replay/godot"
import game "../shared/game"
@(gd_method)
replay_scrapyard_solo_input :: proc(self:^ReplayScrapyard,x,y:gd.Int,fire:bool) {
 replay_scrapyard_dev_stress_fire(self)
 self.manual_move={f32(x),f32(y)};self.manual_fire=fire
}
@(gd_method)
replay_scrapyard_solo_probe :: proc(self:^ReplayScrapyard,key:string)->gd.Int {
 frame,ready:=rgd.session_authority_state(self.session)
 if key=="ready" {return gd.Int(ready && frame.state.players[0].in_yard)}
 if !ready {return -1};w:=&frame.state;p:=w.players[0]
 switch key {
 case "tick":return gd.Int(frame.tick)
 case "stage":return gd.Int(w.stage)
 case "run":return gd.Int(w.run)
 case "floor":return gd.Int(w.floor)
 case "wave":return gd.Int(w.director.wave)
 case "pending":return gd.Int(w.director.pending)
 case "alive":return gd.Int(w.director.alive)
 case "done":return gd.Int(w.director.done)
 case "rest_until":return gd.Int(w.director.rest_until)
 case "spawned":return gd.Int(w.spawn_index)
 case "living":return gd.Int(game.living_enemies(w))
 case "props":n:=0;for alive,i in w.mobs.alive {if alive && w.mobs.values[i].hp>0 && w.catalog.mobs[w.mobs.values[i].kind].prop {n+=1}};return gd.Int(n)
 case "projectiles":return gd.Int(w.shots.count)
 case "shots":return gd.Int(p.shots)
 case "booms":return gd.Int(w.barrel_blasts)
 case "kills":return gd.Int(p.kills)
 case "hp":return gd.Int(p.hp)
 case "x":return gd.Int(p.position[0])
 case "y":return gd.Int(p.position[1])
 case "cores":return gd.Int(p.cores)
 case "scrap":return gd.Int(p.scrap)
 case "mag":return gd.Int(w.catalog.guns[p.gun_id].mechanism.mag)
 case "jam":return gd.Int(w.catalog.guns[p.gun_id].mechanism.jam_per_mille)
 case "iron":return gd.Int(p.gun_id)
 }
 return -1
}
@(gd_method)
replay_scrapyard_solo_position :: proc(self:^ReplayScrapyard)->gd.Vector2 {
 frame,ok:=rgd.session_authority_state(self.session);return ok ? gd.Vector2{frame.state.players[0].position[0],frame.state.players[0].position[1]} : gd.Vector2{}
}
@(gd_method)
replay_scrapyard_solo_cover_count :: proc(self:^ReplayScrapyard)->gd.Int {
 frame,ok:=rgd.session_authority_state(self.session);return ok ? gd.Int(len(frame.state.layout.covers)) : 0
}
@(gd_method)
replay_scrapyard_solo_cover :: proc(self:^ReplayScrapyard,index:gd.Int)->gd.Rect2 {
 frame,ok:=rgd.session_authority_state(self.session)
 if !ok || index<0 || int(index)>=len(frame.state.layout.covers) {return {}}
 c:=frame.state.layout.covers[index];return {{f32(c.x),f32(c.y)},{f32(c.w),f32(c.h)}}
}
@(gd_method)
replay_scrapyard_solo_prop :: proc(self:^ReplayScrapyard,index:gd.Int)->gd.Vector3 {
 frame,ok:=rgd.session_authority_state(self.session);if !ok {return {}}
 props:[2]gd.Vector3;count:=0
 for alive,i in frame.state.mobs.alive {if alive {m:=frame.state.mobs.values[i];if m.hp>0 && frame.state.catalog.mobs[m.kind].prop && count<2 {props[count]={m.position[0],m.position[1],f32(m.hp)};count+=1}}}
 if count==2 && (props[0].x>props[1].x || props[0].x==props[1].x && props[0].y>props[1].y) {props[0],props[1]=props[1],props[0]}
 return index>=0 && int(index)<count ? props[index] : gd.Vector3{}
}
