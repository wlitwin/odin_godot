package play

// play/actions — the input-map install every game rewrote as install_controls:
// a table of (action, key) and (action, mouse button) rows, added once —
// IDEMPOTENT, because scene reloads re-run ready() and a second add would
// stack duplicate events (the `if gd.has_action(first) return` guard each
// copy carried, now the shelf's).
//
//	play.actions_install(
//	    {{"sy_up", .W}, {"sy_down", .S}, {"sy_talk", .Enter}},
//	    {{"sy_fire", .Left}, {"sy_ping", .Middle}},
//	)
//
// Gamepad axes/buttons stay yours (their deadzone/threshold knobs are
// per-game); these two tables cover the keyboard-and-mouse ceremony.

import gd "godot:godot"

Key_Row :: struct {
	action: cstring,
	key:    gd.Key,
}

Mouse_Row :: struct {
	action: cstring,
	button: gd.Mouse_Button,
}

actions_install :: proc "contextless" (keys: []Key_Row, mice: []Mouse_Row = nil) {
	if len(keys) > 0 && gd.has_action(keys[0].action) {
		return // a scene reload re-ran ready — the map is already in
	}
	if len(keys) == 0 && len(mice) > 0 && gd.has_action(mice[0].action) {
		return
	}
	for k in keys {
		gd.add_action(k.action)
		gd.action_add_key(k.action, i64(k.key))
	}
	for m in mice {
		gd.add_action(m.action)
		gd.action_add_mouse_button(m.action, i64(m.button))
	}
}
