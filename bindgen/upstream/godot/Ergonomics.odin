package godot

// Ergonomic helpers over the generated binding for common — but otherwise verbose — Godot
// patterns. Hand-written (like Strings.odin / Variant.odin), and mirrored in
// bindgen/upstream/godot/ so it survives binding regeneration.
//
// Object handles (Node2d, Area2d, …) are all type-aliases up to `Object`, so these helpers
// take `Object` and accept any node handle (e.g. a script's `self.owner`) with no cast.

// connect wires `obj`'s `signal` to `obj`'s OWN method `method` — the common self-connection
// (e.g. a node connecting its `body_entered` to its `collect` method). Collapses the
// StringName + Callable + object_connect dance into one call:
//
//     gd.connect(self.owner, "body_entered", "collect")
//
// `method` must name a method the engine can dispatch (for an Odin script, a `@(gd_method)`).
connect :: proc "contextless" (obj: Object, signal: cstring, method: cstring, flags := i64(0)) -> Error {
	s := new_string_name_cstring(signal, true)
	m := new_string_name_cstring(method, true)
	cb := new_callable_object_string_name(obj, m)
	return object_connect(obj, s, cb, Int(flags))
}

// connect_to wires `emitter`'s `signal` to `target`'s method `method` (cross-object).
connect_to :: proc "contextless" (
	emitter: Object,
	signal: cstring,
	target: Object,
	method: cstring,
	flags := i64(0),
) -> Error {
	s := new_string_name_cstring(signal, true)
	m := new_string_name_cstring(method, true)
	cb := new_callable_object_string_name(target, m)
	return object_connect(emitter, s, cb, Int(flags))
}

// callable builds a Callable bound to `obj`'s method `method` (for connect/emit/Timer/etc.).
callable :: proc "contextless" (obj: Object, method: cstring) -> Callable {
	m := new_string_name_cstring(method, true)
	return new_callable_object_string_name(obj, m)
}

// is_editor reports whether the code is running inside the Godot editor (edit mode), i.e.
// `Engine.is_editor_hint()`. For a `//gd:tool` script — which the engine instantiates and
// runs in the editor too — this is how editor-only branches read cleanly:
//
//     if gd.is_editor() {
//         // editor-side setup only (the running game skips this)
//     }
//
// Returns false at game runtime (including exported builds), true while the editor holds
// the scene open. Use inside `//gd:tool` scripts; non-tool scripts only run at game time,
// where this is always false.
is_editor :: proc "contextless" () -> bool {
	return bool(engine_is_editor_hint(singleton_engine()))
}

// sname interns a cstring as a Godot StringName — the concise inline form of
// `new_string_name_cstring(name, true)`. The many bound methods that take a `String_Name`
// (method / signal / action / animation / property names) almost always want a string LITERAL,
// and `static = true` interns it once and keeps it. Use this when no higher-level `gd.*` helper
// exists for the call:
//
//     gd.animation_player_play(p, gd.sname("run"), -1, 1, false)
//     gd.object_has_method(obj, gd.sname("attack"))
sname :: proc "contextless" (name: cstring) -> String_Name {
	return new_string_name_cstring(name, true)
}

// gstr builds a Godot String from a cstring — the inline form of `new_string_cstring`, for the
// bound methods that take a `String` (rather than a `String_Name`).
//
//     gd.label_set_text(lbl, gd.gstr("Score: 0"))   // or just gd.set_text(lbl, "Score: 0")
gstr :: proc "contextless" (s: cstring) -> String {
	return new_string_cstring(s)
}
