//gd:extends Node
package callback_game

import gd "godot:godot"
import kboot "godot:kit/boot"
import actors "actors"

GameA :: struct {
    owner: gd.Node,
    boot: kboot.Boot,
    actor_scene: gd.Packed_Scene `gd:"entity=actors.Actor:1"`,
    walker_scene: gd.Packed_Scene `gd:"entity=actors.Walker:2"`,
    points, tick_points, edges, effects: i32,
    last_mine: bool,
}

// A lane owner with no sampler still registers the private input type through
// the generated leaf alias; the field rules remain active on received inputs.
@(gd_step)
game_a_step_world :: proc(self: ^GameA) {}
