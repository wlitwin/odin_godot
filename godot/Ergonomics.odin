package godot

import "core:math"
import gdext "godot:gdext"

// Ergonomic helpers over the generated binding for common — but otherwise verbose — Godot
// patterns. Hand-written (like Strings.odin / Variant.odin) and owned here: binding
// regeneration only rewrites `*.gen.odin`, never these files.
//
// Object handles (Node2d, Area2d, …) are all type-aliases up to `Object`, so these helpers
// take `Object` and accept any node handle (e.g. a script's `self.owner`) with no cast.
//
// NAME INTERNING: every helper that takes a name cstring (signal / method / action / group /
// animation / property names) interns it as a STATIC StringName — per the GDExtension
// contract the engine may keep that buffer for the lifetime of the program. So those name
// arguments MUST be string literals (or other program-lifetime, never-freed ASCII cstrings);
// do NOT pass `fmt.ctprintf`-built or otherwise dynamic strings. For a dynamic name, build it
// yourself with `new_string_name_cstring(name, false)` and free it with `free_string_name`.

// variant_destroy releases the engine-side resources a Variant may hold (a String / Array /
// Dictionary / Object reference, …). Variants holding POD content (ints, floats, vectors, …)
// own nothing, so destroying them is a safe no-op. Helpers that RETURN a Variant
// (gd.get_value, gd.get_setting, …) transfer ownership to the caller — destroy the Variant
// with this when done with it.
variant_destroy :: proc "contextless" (v: ^Variant) {
	gdext.variant_destroy(cast(gdext.VariantPtr)v)
}

// connect wires `obj`'s `signal` to `obj`'s OWN method `method` — the common self-connection
// (e.g. a node connecting its `body_entered` to its `collect` method). Collapses the
// StringName + Callable + object_connect dance into one call:
//
//     gd.connect(self.owner, "body_entered", "collect")
//
// `method` must name a method the engine can dispatch (for an Odin script, a `@(gd_method)`).
// `signal`/`method` must be string literals (they are interned — see the file header).
connect :: proc "contextless" (obj: Object, signal: cstring, method: cstring, flags := i64(0)) -> Error {
	s := new_string_name_cstring(signal, true)
	m := new_string_name_cstring(method, true)
	// The Callable is a ptrcall argument — the engine copies it into the connection, so our
	// temporary still owns a Callable reference and must be released after the call.
	cb := new_callable_object_string_name(obj, m)
	defer free_callable(cb)
	return object_connect(obj, s, cb, Int(flags))
}

// connect_to wires `emitter`'s `signal` to `target`'s method `method` (cross-object).
// `signal`/`method` must be string literals (they are interned — see the file header).
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
	defer free_callable(cb)
	return object_connect(emitter, s, cb, Int(flags))
}

// connect_to_bound is connect_to with ONE bound integer argument appended to the
// callable: the engine passes it AFTER the signal's own args on every dispatch. This is
// the mechanism behind the indexed `@(gd_connect="Panel/Choice%d:pressed")` form — N
// sibling emitters share one handler, which tells them apart by the bound index (its
// trailing parameter). `signal`/`method` must be string literals or otherwise
// program-lifetime cstrings (interned; see the file header).
connect_to_bound :: proc "contextless" (
	emitter: Object,
	signal: cstring,
	target: Object,
	method: cstring,
	bound: i64,
	flags := i64(0),
) -> Error {
	s := new_string_name_cstring(signal, true)
	m := new_string_name_cstring(method, true)
	cb := new_callable_object_string_name(target, m)
	defer free_callable(cb)
	// bindv takes the bound args as an engine Array of Variants; every temporary here
	// is released once the engine holds its own copy inside the bound Callable.
	idx := Int(bound)
	iv := variant_from_int(&idx)
	defer variant_destroy(&iv)
	arr := new_array_default()
	defer free_array(arr)
	array_push_back(&arr, iv)
	bcb := callable_bindv(&cb, arr)
	defer free_callable(bcb)
	return object_connect(emitter, s, bcb, Int(flags))
}

// callable builds a Callable bound to `obj`'s method `method` (for connect/emit/Timer/etc.).
// `method` must be a string literal (it is interned — see the file header). The returned
// Callable is OWNED BY THE CALLER: release it with `free_callable` once the engine holds its
// own copy (e.g. after the object_connect / timer call it was built for).
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
//
// CONTRACT: `name` MUST be a string literal (or another program-lifetime, never-freed cstring)
// and ASCII — the engine may keep referencing the buffer forever. Do NOT pass a
// `fmt.ctprintf`-built or otherwise dynamic cstring; for those use
// `new_string_name_cstring(name, false)` + `free_string_name`.
sname :: proc "contextless" (name: cstring) -> String_Name {
	return new_string_name_cstring(name, true)
}

// gstr builds a Godot String from a cstring — the inline form of `new_string_cstring`, for the
// bound methods that take a `String` (rather than a `String_Name`). The returned String is
// OWNED BY THE CALLER — release it with `free_string` after the call that consumes it.
//
//     gd.label_set_text(lbl, gd.gstr("Score: 0"))   // or just gd.set_text(lbl, "Score: 0")
gstr :: proc "contextless" (s: cstring) -> String {
	return new_string_cstring(s)
}

// normalized — value-form vector normalization (the generated `vector2_normalized`
// takes a pointer, so three example games each wrote this wrapper; `gd.Vector2` is a
// plain [2]f32, so this is pure Odin math — no engine round-trip). Returns the zero
// vector for near-zero input, the branch every hand-rolled copy carried.
normalized :: proc "contextless" (v: Vector2) -> Vector2 {
	l := math.sqrt(v.x * v.x + v.y * v.y)
	if l <= 0.00001 {return Vector2{}}
	return Vector2{v.x / l, v.y / l}
}

// normalized3 — the Vector3 form (slopball3d's `_xz` helper generalized).
normalized3 :: proc "contextless" (v: Vector3) -> Vector3 {
	l := math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
	if l <= 0.00001 {return Vector3{}}
	return Vector3{v.x / l, v.y / l, v.z / l}
}
