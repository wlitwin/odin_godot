//gd:extends Node
package callback_game

import gd "godot:godot"
import kboot "godot:kit/boot"
import actors "actors"

GameC :: struct {
    owner: gd.Node,
    boot: kboot.Boot,
    actor_scene: gd.Packed_Scene `gd:"entity=actors.Actor:1"`,
    walker_scene: gd.Packed_Scene `gd:"entity=actors.Walker:2"`,
    effects: i32,
}
