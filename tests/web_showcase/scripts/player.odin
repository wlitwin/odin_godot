//gd:extends CharacterBody2D
//gd:class Player
package showcase_scripts

// ----------------------------------------------------------------------------
// Player — a CharacterBody2D driven entirely by compiled Odin. `_process` reads the
// real input axes (`input_get_axis`, now correct after the float-ptrcall fix) and moves
// the node, so holding the arrow keys walks the player around. `speed` is an @export, so
// it shows in the Inspector and can be tuned per-scene.
// ----------------------------------------------------------------------------

import gd "godot:godot"

Player :: struct {
	owner: gd.Node2d, // base is CharacterBody2D (a Node2d); owner handle typed as Node2d.
	speed: f32 `gd:"export"`,
}

player_ready :: proc(self: ^Player) {
	if self.speed == 0 {self.speed = 220}
	// A fresh game starts at score 0 (shared module reset).
	game_state_reset()
	gd.node2d_set_position(self.owner, gd.Vector2{40, 100})
}

player_process :: proc(self: ^Player, delta: f64) {
	input := gd.singleton_input()
	dx := f32(gd.input_get_axis(input, gd.sname("ui_left"), gd.sname("ui_right")))
	dy := f32(gd.input_get_axis(input, gd.sname("ui_up"), gd.sname("ui_down")))
	pos := gd.node2d_get_position(self.owner)
	pos.x += dx * self.speed * f32(delta)
	pos.y += dy * self.speed * f32(delta)
	gd.node2d_set_position(self.owner, pos)
}
