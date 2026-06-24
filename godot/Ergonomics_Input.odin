package godot

// Ergonomic helpers for InputMap — hand-written, mirrored in bindgen/upstream/godot/ so
// they survive binding regeneration.
//
// These let Odin code DEFINE input actions at runtime (the autoload-style "register the
// game's actions on _ready" pattern), wrapping the InputMap singleton
// (`singleton_input_map()`) plus the generated `input_map_*` procs and constructing the
// InputEvent* objects for you:
//
//     gd.add_action("fire")
//     gd.action_add_key("fire", i64(gd.Key.Space))         // or a raw keycode
//     gd.action_add_mouse_button("fire", i64(gd.Mouse_Button.Left))
//     ...
//     if gd.is_action_pressed("fire") { shoot() }
//
// Once registered, the action is visible to GDScript too (InputMap.has_action,
// Input.is_action_pressed, Input.action_press). Actions added at runtime are NOT written
// to project.godot; this is for in-session registration.

// add_action defines a new input action `name`. `deadzone` is the analog dead-zone
// threshold (matches Godot's default of 0.5).
add_action :: proc "contextless" (name: cstring, deadzone := f32(0.5)) {
	im := singleton_input_map()
	n := new_string_name_cstring(name, true)
	input_map_add_action(im, n, f64(deadzone))
}

// has_action reports whether action `name` is currently defined.
has_action :: proc "contextless" (name: cstring) -> bool {
	im := singleton_input_map()
	n := new_string_name_cstring(name, true)
	return bool(input_map_has_action(im, n))
}

// erase_action removes the action `name`.
erase_action :: proc "contextless" (name: cstring) {
	im := singleton_input_map()
	n := new_string_name_cstring(name, true)
	input_map_erase_action(im, n)
}

// action_add_key binds a keyboard key to `action`. `keycode` is a Godot `Key` value
// (pass `i64(gd.Key.Space)` etc.); both keycode and physical_keycode are set so the
// binding works regardless of keyboard layout matching.
action_add_key :: proc "contextless" (action: cstring, keycode: i64) {
	im := singleton_input_map()
	ev := new_input_event_key()
	input_event_key_set_keycode(ev, Key(keycode))
	input_event_key_set_physical_keycode(ev, Key(keycode))
	n := new_string_name_cstring(action, true)
	input_map_action_add_event(im, n, ev)
}

// action_add_mouse_button binds a mouse button to `action`. `button_index` is a Godot
// `Mouse_Button` value (pass `i64(gd.Mouse_Button.Left)` etc.).
action_add_mouse_button :: proc "contextless" (action: cstring, button_index: i64) {
	im := singleton_input_map()
	ev := new_input_event_mouse_button()
	input_event_mouse_button_set_button_index(ev, Mouse_Button(button_index))
	n := new_string_name_cstring(action, true)
	input_map_action_add_event(im, n, ev)
}

// is_action_pressed reports whether `action` is currently held down (collapses the Input
// singleton + StringName + exact_match=false dance over `input_is_action_pressed`).
is_action_pressed :: proc "contextless" (action: cstring) -> bool {
	n := new_string_name_cstring(action, true)
	return bool(input_is_action_pressed(singleton_input(), n, false))
}
