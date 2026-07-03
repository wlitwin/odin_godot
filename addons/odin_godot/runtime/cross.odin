package script_runtime

import "godot:gdext"

// ----------------------------------------------------------------------------
// Typed cross-script references (Option A — direct struct pointer).
//
// All Odin scripts share ONE dll, so the struct type `Enemy` declared in one script is
// the SAME type everywhere in that dll. The only missing piece is mapping a live Godot
// object back to the Odin script struct the core allocated for it — and that mapping
// lives in the CORE (the `Odin_Instance.user` pointer is core-private).
//
// The core hands us a resolver fn ptr at boot:
//   * NATIVE: the core dlsym's `odin_scripts_set_core_api` out of the scripts dll and
//     calls it right after `odin_scripts_boot`, passing core's `odin_script_struct`.
//   * WEB (single module): the core calls `odin_scripts_set_core_api` directly.
//
// A script then writes:
//   enemy := rt.script_of(get_node(...), Enemy)   // -> ^Enemy (nil if not an Odin node)
//   if enemy != nil { enemy.hp -= 5 }             // direct typed field + proc access
//
// This is PURE plumbing in the same spirit as the rest of this package: it stores a fn
// ptr and casts a returned rawptr; it never calls into godot/gdext itself.
// ----------------------------------------------------------------------------

// The core's `obj -> Odin script struct pointer` resolver. Returns nil when `obj` has no
// OUR-language Odin script instance attached (foreign language / placeholder / no script) OR
// when the attached instance's class is NOT `want_class`. The CLASS CHECK is essential: every
// Odin script shares one struct namespace in this dll, so without verifying the class the core
// would blindly hand back WHATEVER struct is attached, reinterpreted as `^T` — a type confusion
// that defeats the caller's `if x == nil` guard (e.g. a Bullet returned as a non-nil `^Enemy`).
// `want_class` is the registered class name (a static cstring owned by the scripts dll); the
// core compares it by VALUE against the instance's class name, so it is robust across dll swaps.
Script_Struct_Proc :: proc "c" (obj: gdext.ObjectPtr, want_class: cstring) -> rawptr

@(private)
core_script_struct: Script_Struct_Proc

// Called by the core to hand the scripts dll its `obj -> script struct` resolver. Exported
// so the native core can resolve it by name (dlsym) after boot; called directly on web.
@(export)
odin_scripts_set_core_api :: proc "c" (script_struct: Script_Struct_Proc) {
	core_script_struct = script_struct
}

// Typed reference to another node's/resource's Odin script struct. Returns nil when `obj`
// is nil, the core API has not been wired, `obj` carries no OUR-language Odin script instance,
// OR `obj`'s attached script is NOT class `T`.
//
// MAIN-THREAD CONTRACT: call this only from the engine's main thread (script lifecycle
// callbacks, @(gd_method) bodies, signal handlers — i.e. everywhere the engine already
// dispatches your script code). The core-side registry lookup itself is mutex-guarded
// (core/instance.odin `live_lock`), but the POINTER you get back is not: from a spawned
// thread it can be freed under you by a main-thread instance teardown the moment the
// resolver returns. The class check is what makes this TYPE-SAFE:
// `T` is resolved to its registered class name (via the runtime registry's typeid->name map),
// and the core only returns the struct pointer when the live instance's class matches. Without
// it, `script_of(a_bullet, Enemy)` would return the Bullet struct cast to `^Enemy` (non-nil
// garbage). Because every script lives in one dll, `T` is the real script struct type, so a
// matching `script_of(node, Enemy).hp` is a direct field access — no Variant marshaling.
script_of :: proc "contextless" (obj: gdext.ObjectPtr, $T: typeid) -> ^T {
	if core_script_struct == nil || obj == nil {
		return nil
	}
	want := class_name_for_typeid(typeid_of(T))
	if want == nil {
		return nil
	}
	return cast(^T)core_script_struct(obj, want)
}
