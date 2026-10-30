package replay_scrapyard
import gd "godot:godot"
import rgd "godot:replay/godot"
import game "../shared/game"

@(gd_method)
replay_scrapyard_dedicated_boot :: proc(self:^ReplayScrapyard,server:bool) {} // Explicit launch role already opens Session.
@(gd_method)
replay_scrapyard_dedicated_profile :: proc(self:^ReplayScrapyard,look:gd.Int) {replay_scrapyard_dev_loadout(self,look,0)}
@(gd_method)
replay_scrapyard_dedicated_drive :: proc(self:^ReplayScrapyard,x,y:gd.Int,fire:bool) {
 replay_scrapyard_dev_stress_fire(self);self.manual_move={f32(x),f32(y)};self.manual_fire=fire
}
@(gd_method)
replay_scrapyard_dedicated_position :: proc(self:^ReplayScrapyard)->gd.Vector2 {
 frame,ok:=rgd.session_state(self.session);seat:=rgd.session_seat(self.session)
 return ok && seat>0 ? gd.Vector2{frame.state.players[seat-1].position[0],frame.state.players[seat-1].position[1]} : gd.Vector2{}
}
@(gd_method)
replay_scrapyard_dedicated_probe :: proc(self:^ReplayScrapyard,key:string)->gd.Int {
 frame,ok:=rgd.session_authority_state(self.session)
 if key=="ready" {return gd.Int(self.session.ready && ok)}
 if !ok {return -1};w:=&frame.state;seat:=rgd.session_seat(self.session)
 switch key {
 case "authority":return gd.Int(self.session.authority)
 case "seat":return gd.Int(seat)
 case "avatars":n:=0;for p in w.players {if p.in_yard {n+=1}};return gd.Int(n)
 case "hp":return seat>0 ? gd.Int(w.players[seat-1].hp) : -1
 case "iron":return seat>0 ? gd.Int(w.players[seat-1].gun_id) : -1
 case "cores":return seat>0 ? gd.Int(w.players[seat-1].cores) : -1
 case "kills":return seat>0 ? gd.Int(w.players[seat-1].kills) : 0
 case "stage":return gd.Int(w.stage)
 case "floor":return gd.Int(w.floor)
 case "run":return gd.Int(w.run)
 case "clock":return gd.Int(frame.tick)
 case "wave":return gd.Int(w.director.wave)
 case "spawned":return gd.Int(w.spawn_index)
 case "rest_until":return gd.Int(w.director.rest_until)
 case "living":return gd.Int(game.living_enemies(w))
 }
 return -1
}
