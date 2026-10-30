package replay_scrapyard
import gd "godot:godot"
import rgd "godot:replay/godot"
import game "../shared/game"

@(gd_method)
replay_scrapyard_storm_probe :: proc(self:^ReplayScrapyard,key:string)->gd.Int {
 frame,ok:=rgd.session_authority_state(self.session);if !ok {return -1}
 for mob,i in frame.state.mobs.values {if frame.state.mobs.alive[i] && mob.kind==game.STORMCALLER {
  switch key {
  case "left":return gd.Int(mob.tele.left)
  case "wind":return gd.Int(mob.tele.wind)
  case "hp":return gd.Int(mob.hp)
  case "radius":return gd.Int(frame.state.catalog.mobs[mob.kind].pulse.radius)
  case "damage":return gd.Int(frame.state.catalog.mobs[mob.kind].pulse.damage)
  }
 }}
 return 0
}
