package cave_upgrade

import r "godot:replay"
import net "godot:replay/net"
import game "../cave"

CONTENT_8 :: u64(0x4341564552504c38)
convert_world8 :: proc(world:game.World)->(game.World,bool) {return world,game.state_valid(world)}

// Executable C8 descriptor for explicit historical recording verification. State,
// controls, actions and the existing Event layout are unchanged; C8 never emitted
// a Hit for a dweller. Do not use this descriptor to run current-content sessions.
model8 :: proc()->net.Model(game.World,game.Control,game.Action,game.Event,game.SEATS) {
 m:=game.model()
 m.step=proc(w:^game.World,c:[game.SEATS]game.Control,j,l:u64,ctx:^r.Step(game.Event)) {
  game.step_motion(w,c,j,l,ctx,true,false)
 }
 return m
}
