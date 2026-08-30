//gd:extends Node2D
//gd:class Player
package showcase

// ----------------------------------------------------------------------------
// Player — the Phase 2 showcase script. Demonstrates the full compiled-dispatch
// path: an `.odin` file attached to a Node2D whose `_ready` sets initial state and
// whose `_process(delta)` drives the node every frame through the typed godot API.
//
// HAND-WRITTEN registration (codegen is later polish). The `@(init)` proc below
// runs on dlopen and publishes the class to the runtime registry — pure data, no
// engine calls, so it is safe before the core boots this dll's gdext/godot globals.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

// First field MUST be the owner node pointer — the core writes the owner Object*
// at offset 0 when it allocates the instance.
Player :: struct {
	owner: gd.Node2d,
	speed: f32,
}

// Cached action names (constructing a String_Name every frame would leak).
@(private = "file")
ui_left_name: gd.String_Name
@(private = "file")
ui_right_name: gd.String_Name
@(private = "file")
names_ready: bool

@(private = "file")
ensure_names :: proc "contextless" () {
	if !names_ready {
		ui_left_name = gd.new_string_name_cstring("ui_left", true)
		ui_right_name = gd.new_string_name_cstring("ui_right", true)
		names_ready = true
	}
}

// _ready arrives as NOTIFICATION_READY in the core, dispatched here.
player_ready :: proc "c" (self_raw: rawptr) {
	self := cast(^Player)self_raw
	self.speed = 200
	// Initial state: park the node at a known origin.
	gd.node2d_set_position(self.owner, gd.Vector2{100, 50})
}

// _process(delta) arrives through call_func after the core enabled processing.
// Base behavior: drift right at `speed` px/sec. Input behavior: holding ui_right /
// ui_left adds/subtracts INPUT_SPEED worth of velocity, so input makes the node move
// several times faster than the idle drift.
INPUT_SPEED :: 1000

player_process :: proc "c" (self_raw: rawptr, delta: f64) {
	self := cast(^Player)self_raw
	ensure_names()

	input := gd.singleton_input()
	dir := f32(gd.input_get_axis(input, ui_left_name, ui_right_name))

	pos := gd.node2d_get_position(self.owner)
	pos.x += (self.speed + dir * INPUT_SPEED) * f32(delta)
	gd.node2d_set_position(self.owner, pos)
}

@(init)
_register_player :: proc "contextless" () {
	rt.register(
		rt.Class_Desc {
			name = "Player",
			path = "res://scripts/player.odin",
			global_name = "Player",
			base = "Node2D",
			size = size_of(Player),
			align = align_of(Player),
			lifecycle = rt.Lifecycle{ready = player_ready, process = player_process},
		},
	)
}
