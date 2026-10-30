package cave_upgrade

import net "godot:replay/net"
import r "godot:replay"
import game "../cave"

CONTENT_5 :: u64(0x4341564552504c35)
// C6 changes relic transition policy without changing the archived value layout.
// Preserve the recorded position/ownership exactly; C6 rules apply on advancement.
model5 :: proc()->net.Model(World_7,game.Control,game.Action,game.Event,game.SEATS) {
 return {control_valid=game.control_valid,action_valid=game.action_valid,state_valid=world7_valid,
  action=proc(_: ^World_7,_:u16,_:game.Action,_:^r.Step(game.Event))->bool {panic("archive-only C5 model cannot execute")}}
}
convert_world5 :: proc(world:World_7)->(game.World,bool) {return convert_world7(world)}
