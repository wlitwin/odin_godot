//gd:extends Node
//gd:class GameManager
package autoload_scripts

// ----------------------------------------------------------------------------
// GameManager — a REAL Godot autoload singleton written in Odin.
//
// Configured in project.godot as:
//
//     [autoload]
//     GameManager="*res://scripts/game_manager.odin"
//
// The leading `*` makes Godot instantiate this script's base node (`//gd:extends Node`),
// attach the script, and add it under /root at startup with the name `GameManager` — so
// it is reachable everywhere as `/root/GameManager` (GDScript: `GameManager` directly),
// persists across scene changes, and runs `_ready` once at boot.
//
// On `_ready` it ALSO exercises the new ProjectSettings + InputMap ergonomic helpers: it
// registers a custom project setting and an input action from Odin, which the GDScript
// driver then reads back — proving the autoload's _ready ran AND the helpers work.
// ----------------------------------------------------------------------------

import gd "godot:godot"

// Sentinel `_ready` writes into `count`, so the driver reading 1000 BEFORE any bump proves
// _ready actually ran (vs. a never-readied zero-initialized struct).
READY_SENTINEL :: 1000

GameManager :: struct {
	owner: gd.Node,
	count: gd.Int,
}

game_manager_ready :: proc(self: ^GameManager) {
	self.count = READY_SENTINEL

	// (2) ProjectSettings ergonomics — register a custom setting from Odin.
	gd.set_setting_int("odin/autoload_marker", 7)

	// (3) InputMap ergonomics — DEFINE a game action from the autoload's _ready, so
	// GDScript's Input.is_action_pressed("odin_fire") / InputMap.has_action see it.
	gd.add_action("odin_fire")
	gd.action_add_key("odin_fire", i64(gd.Key.Space))
	gd.action_add_mouse_button("odin_fire", i64(gd.Mouse_Button.Left))
}

// bump(amount) — mutate the singleton's state. Callable from GDScript:
//   get_node("/root/GameManager").call("bump", 5)
@(gd_method)
game_manager_bump :: proc(self: ^GameManager, amount: int) {
	self.count += gd.Int(amount)
}

// get_count() — read the singleton's state back. Callable from GDScript:
//   get_node("/root/GameManager").call("get_count")
@(gd_method)
game_manager_get_count :: proc(self: ^GameManager) -> int {
	return int(self.count)
}

// read_marker() — read the "odin/autoload_marker" project setting back THROUGH the Odin
// gd.get_setting_int helper. The driver uses this to verify the Odin ProjectSettings
// getters see values set both from Odin (_ready) and from GDScript.
@(gd_method)
game_manager_read_marker :: proc(self: ^GameManager) -> int {
	return int(gd.get_setting_int("odin/autoload_marker"))
}

// settings_selftest() — exercise the typed ProjectSettings ergonomics (float/bool/string +
// has_setting) entirely inside Odin, returning 1 when every round-trip matches, else 0.
@(gd_method)
game_manager_settings_selftest :: proc(self: ^GameManager) -> int {
	gd.set_setting_float("odin/selftest_f", 3.5)
	gd.set_setting_bool("odin/selftest_b", true)
	gd.set_setting_string("odin/selftest_s", "hello")

	ok :=
		gd.has_setting("odin/selftest_f") &&
		!gd.has_setting("odin/definitely_absent") &&
		gd.get_setting_float("odin/selftest_f") == 3.5 &&
		gd.get_setting_bool("odin/selftest_b") == true

	s := gd.get_setting_string("odin/selftest_s")
	defer delete(s)
	ok = ok && s == "hello"

	return ok ? 1 : 0
}
