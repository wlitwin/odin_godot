package replay_cavecrawl
import gd "godot:godot"
import r "godot:replay"
import rgd "godot:replay/godot"

// Test-only reads of retained frames; no state edits or alternate simulation.
@(gd_method)
replay_cave_floor_value :: proc(self:^ReplayCave,tick:gd.Int,key:string,seat:gd.Int)->gd.Int {
 if !self.session.ready || !self.session.authority || tick<0 || seat<1 || seat>4 {return -1}
 frame,ok:=r.read(&self.session.server.timeline,u64(tick));if !ok {return -1}
 w:=&frame.state;p:=&w.players[seat-1]
 switch key {
 case "carrier":return gd.Int(w.relic.carrier)
 case "version":return gd.Int(w.relic.version)
 case "x":return gd.Int(w.relic.position[0])
 case "y":return gd.Int(w.relic.position[1])
 case "player_x":return gd.Int(p.position[0])
 case "player_y":return gd.Int(p.position[1])
 case "depth":return gd.Int(w.depth)
 case "run":return gd.Int(w.lobby.run)
 case "hp":return gd.Int(p.hp)
 case "stamina":return gd.Int(p.stamina)
 case "rock":return gd.Int(p.rock_cd)
 case "heal":return gd.Int(p.heal_cd)
 case "chill":return gd.Int(p.chill)
 case "kills":return gd.Int(p.kills)
 case "damage":return gd.Int(p.damage)
 case "bag":return gd.Int(p.bag[0].count)
 }
 return -1
}

@(gd_method)
replay_cave_carrier_value :: proc(self:^ReplayCave,key:string,seat:gd.Int)->gd.Int {
 frame,ok:=rgd.session_authority_state(self.session);if !ok || seat<1 || seat>4 {return -1}
 w:=&frame.state;p:=&w.players[seat-1]
 switch key {
 case "carrier":return gd.Int(w.relic.carrier)
 case "version":return gd.Int(w.relic.version)
 case "x":return gd.Int(w.relic.position[0])
 case "y":return gd.Int(w.relic.position[1])
 case "player_x":return gd.Int(p.position[0])
 case "player_y":return gd.Int(p.position[1])
 case "hp":return gd.Int(p.hp)
 case "connected":return gd.Int(p.connected)
 }
 return -1
}
