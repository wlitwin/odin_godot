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

// The runtime polling helpers below mirror Godot's `Input.*` method names (so a GDScript habit
// transfers directly), each collapsing the Input singleton + StringName interning + the
// exact_match/deadzone arguments. Action NAMES are plain cstrings.

// is_action_pressed reports whether `action` is currently held down.
is_action_pressed :: proc "contextless" (action: cstring) -> bool {
	n := new_string_name_cstring(action, true)
	return bool(input_is_action_pressed(singleton_input(), n, false))
}

// is_action_just_pressed / is_action_just_released — true only on the frame the action's state
// changed (the usual "fire on press, not while held" check).
is_action_just_pressed :: proc "contextless" (action: cstring) -> bool {
	n := new_string_name_cstring(action, true)
	return bool(input_is_action_just_pressed(singleton_input(), n, false))
}
is_action_just_released :: proc "contextless" (action: cstring) -> bool {
	n := new_string_name_cstring(action, true)
	return bool(input_is_action_just_released(singleton_input(), n, false))
}

// get_action_strength — analog strength of `action` in 0..1 (1 for a pressed digital input).
get_action_strength :: proc "contextless" (action: cstring) -> f64 {
	n := new_string_name_cstring(action, true)
	return input_get_action_strength(singleton_input(), n, false)
}

// get_axis — `positive` strength minus `negative` strength (e.g. "ui_right" minus "ui_left"), in
// -1..1. The classic 1-D movement input.
get_axis :: proc "contextless" (negative, positive: cstring) -> f64 {
	neg := new_string_name_cstring(negative, true)
	pos := new_string_name_cstring(positive, true)
	return input_get_axis(singleton_input(), neg, pos)
}

// get_vector — a 2-D input vector from four actions (the classic WASD / left-stick movement),
// already deadzone-clamped and length-limited by Godot. A negative `deadzone` (the default) uses
// each action's own configured deadzone.
get_vector :: proc "contextless" (
	negative_x, positive_x, negative_y, positive_y: cstring,
	deadzone := f32(-1),
) -> Vector2 {
	nx := new_string_name_cstring(negative_x, true)
	px := new_string_name_cstring(positive_x, true)
	ny := new_string_name_cstring(negative_y, true)
	py := new_string_name_cstring(positive_y, true)
	return input_get_vector(singleton_input(), nx, px, ny, py, f64(deadzone))
}

// action_press / action_release — synthesize an action press (optionally analog `strength`) or
// release, as if the player triggered it (handy for AI, replays, tests, on-screen buttons).
action_press :: proc "contextless" (action: cstring, strength := f32(1)) {
	n := new_string_name_cstring(action, true)
	input_action_press(singleton_input(), n, f64(strength))
}
action_release :: proc "contextless" (action: cstring) {
	n := new_string_name_cstring(action, true)
	input_action_release(singleton_input(), n)
}
