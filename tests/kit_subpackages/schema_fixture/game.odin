//gd:extends Node
package schema_game

import gd "godot:godot"
import ksess "godot:kit/session"
import rows "profiles"
import data "shadow"
import blocks "blocks"
import values "shadow"

Game :: struct {
    owner: gd.Node,
    ses: ksess.Session `gd:"profile=rows.Row"`,
    shadow: data.Payload,
    received: i64,
    block: blocks.Block(i32),
}

game_ready :: proc(self: ^Game) {}

// Same name as the block's blend, but deliberately wrong for that field.
blend_local :: proc(dst, a, b: rawptr, alpha: f32) { (cast(^i32)dst)^ = 999 }
