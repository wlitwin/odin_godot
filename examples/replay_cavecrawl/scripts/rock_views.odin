package replay_cavecrawl

import game "../shared/cave"
import presentation "godot:examples/replay_cavecrawl/shared/presentation"

cave_rock_position :: proc(w:^game.World,index:int,fraction:f32)->[2]f32 {
 return presentation.rock_position(w,index,fraction,game.BODY_RADIUS)
}
