//gd:extends Node
package callback_game

import gd "godot:godot"
import kboot "godot:kit/boot"
import bodies "actors"

GameB :: struct {
    owner: gd.Node,
    boot: kboot.Boot,
    actor_scene: gd.Packed_Scene `gd:"entity=bodies.Actor:1"`,
    walker_scene: gd.Packed_Scene `gd:"entity=bodies.Walker:2"`,
    points, tick_points, edges, effects: i32,
    last_mine: bool,
}
