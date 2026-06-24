package godot

import gdext "godot:gdext"

// Ergonomic helpers for ProjectSettings — hand-written, mirrored in
// bindgen/upstream/godot/ so they survive binding regeneration.
//
// These wrap the ProjectSettings singleton (`singleton_project_settings()`) plus the
// generated `project_settings_*` procs, building the String + Variant for you so a
// project setting can be read/written by name without the raw Variant + singleton dance:
//
//     gd.set_setting_int("game/lives", 3)
//     lives := gd.get_setting_int("game/lives")
//     if gd.has_setting("game/lives") { ... }
//
// A setting set at runtime is NOT persisted to project.godot unless you also call
// ProjectSettings.save(); these helpers are for the in-session, autoload-style "register
// my game's settings on _ready" pattern (read back anywhere, GDScript or Odin).

// get_setting reads `name` as a raw Variant. Returns a NIL Variant when the setting is
// absent (same as ProjectSettings.get_setting with a null default).
get_setting :: proc "contextless" (name: cstring) -> Variant {
	ps := singleton_project_settings()
	n := new_string_cstring(name)
	return project_settings_get_setting(ps, n, Variant{})
}

// get_setting_or reads `name`, returning `default` (already a Variant) when it is absent.
get_setting_or :: proc "contextless" (name: cstring, default: Variant) -> Variant {
	ps := singleton_project_settings()
	n := new_string_cstring(name)
	return project_settings_get_setting(ps, n, default)
}

// set_setting writes `value` (an already-built Variant) to `name`.
set_setting :: proc "contextless" (name: cstring, value: Variant) {
	ps := singleton_project_settings()
	n := new_string_cstring(name)
	project_settings_set_setting(ps, n, value)
}

// has_setting reports whether `name` is currently defined.
has_setting :: proc "contextless" (name: cstring) -> bool {
	ps := singleton_project_settings()
	n := new_string_cstring(name)
	return bool(project_settings_has_setting(ps, n))
}

// ---- typed convenience setters (build the Variant for you) ----

// set_setting_int writes an integer setting by name.
set_setting_int :: proc "contextless" (name: cstring, v: i64) {
	i := Int(v)
	set_setting(name, variant_from_int(&i))
}

// set_setting_float writes a float setting by name.
set_setting_float :: proc "contextless" (name: cstring, v: f64) {
	f := Float(v)
	set_setting(name, variant_from_float(&f))
}

// set_setting_bool writes a bool setting by name.
set_setting_bool :: proc "contextless" (name: cstring, v: bool) {
	b := v
	set_setting(name, variant_from_bool(&b))
}

// set_setting_string writes a String setting by name (from an Odin cstring).
set_setting_string :: proc "contextless" (name: cstring, v: cstring) {
	s := new_string_cstring(v)
	set_setting(name, variant_from_string(&s))
}

// ---- typed convenience getters (variant_to_* the result) ----

// get_setting_int reads an integer setting by name (0 when absent/non-int).
get_setting_int :: proc "contextless" (name: cstring) -> i64 {
	v := get_setting(name)
	return variant_to_int(&v)
}

// get_setting_float reads a float setting by name.
get_setting_float :: proc "contextless" (name: cstring) -> f64 {
	v := get_setting(name)
	return variant_to_float(&v)
}

// get_setting_bool reads a bool setting by name.
get_setting_bool :: proc "contextless" (name: cstring) -> bool {
	v := get_setting(name)
	return variant_to_bool(&v)
}

// get_setting_string reads a String setting by name and returns it as an Odin `string`,
// allocated in `context.allocator` (Odin scripts run with the script context set, so this
// Just Works inside script procs). NOTE: this is the one helper that needs a context (it
// allocates) — mirrors gd.get_string in Ergonomics_Properties.odin.
get_setting_string :: proc(name: cstring, allocator := context.allocator) -> string {
	v := get_setting(name)
	s := variant_to_string(&v)
	length := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, nil, 0)
	if length <= 0 {
		return ""
	}
	buf := make([]u8, length, allocator)
	gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, cast(cstring)raw_data(buf), length)
	return string(buf)
}
