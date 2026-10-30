package cave_upgrade

import net "godot:replay/net"
import game "../cave"
import r "godot:replay"

CONTENT_3 :: u64(0x4341564552504c33)
// C4 changes director behavior, not its wire layout. Keep C3's validation rule:
// wave zero was not a legal checkpoint in that content version.
world3_valid :: proc(world:World_7)->bool {return world.director.wave>0 && world7_valid(world)}
model3 :: proc()->net.Model(World_7,game.Control,game.Action,game.Event,game.SEATS) {
 return {control_valid=game.control_valid,action_valid=game.action_valid,state_valid=world3_valid,
  action=proc(_: ^World_7,_:u16,_:game.Action,_:^r.Step(game.Event))->bool {panic("archive-only C3 model cannot execute")}}
}
convert_world3 :: proc(world:World_7)->(game.World,bool) {
 if !world3_valid(world) {return {},false};return convert_world7(world)
}

convert_action3 :: proc(action:game.Action)->(game.Action,bool) {return action,true}
