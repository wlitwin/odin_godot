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

// ---- The any-class resolver (the static-dispatch door) ----

// The core's `obj -> (script struct, class identity)` resolver — Script_Struct_Proc's
// sibling for when the caller does NOT know the class: instead of verifying a requested
// name, the core REPORTS the instance's class (ptr + len of its heap-copy name — not
// NUL-terminated, valid while the instance lives) and returns the struct pointer.
Script_Struct_Any_Proc :: proc "c" (obj: gdext.ObjectPtr, class_ptr: ^[^]u8, class_len: ^int) -> rawptr

@(private)
core_script_struct_any: Script_Struct_Any_Proc

// Called by the core right after boot (dlsym'd, same pattern as odin_scripts_set_core_api).
// Optional in both skew directions: an older core never calls it and `script_any` below
// just returns nil; an older scripts dll lacks this export and the core skips it.
@(export)
odin_scripts_set_core_api2 :: proc "c" (script_struct_any: Script_Struct_Any_Proc) {
	core_script_struct_any = script_struct_any
}

// script_any resolves a live Godot object to its Odin script struct WITHOUT naming the
// class: `(pointer, typeid)`, or `(nil, nil)` when `obj` is nil, carries no Odin script,
// or carries a class THIS dll didn't register. That last clause is the type-safety story
// (script_of's class compare, relocated): the reported name is resolved against this
// dll's own registry, so another module's instance misses and can never be handed out
// under a wrong layout.
//
// The typeid is the door to per-TYPE dispatch — the static-vtable pattern where N
// damageable/interactable/savable classes share one table and instances carry nothing:
//
//	ptr, id := rt.script_any(body)
//	for e in DAMAGE_IMPLS {           // static [?]struct{id: typeid, hurt: proc(...)}
//		if e.id == id { e.hurt(ptr, amount); break }
//	}
//
// Same main-thread contract as script_of.
script_any :: proc "contextless" (obj: gdext.ObjectPtr) -> (ptr: rawptr, id: typeid) {
	if core_script_struct_any == nil || obj == nil {
		return nil, nil
	}
	name_ptr: [^]u8
	name_len: int
	p := core_script_struct_any(obj, &name_ptr, &name_len)
	if p == nil || name_ptr == nil || name_len <= 0 {
		return nil, nil
	}
	id = typeid_for_class_name(string(name_ptr[:name_len]))
	if id == nil {
		return nil, nil
	}
	return p, id
}

// lookup finds the table entry whose `id` field matches — the scan behind a per-type
// dispatch table, packaged as the two-value form Odin ifs want:
//
//	if e, ok := rt.lookup(DAMAGE_IMPLS[:], id); ok { e.hurt(ptr, amount) }
//
// Generic on the ENTRY type: any struct with an `id: typeid` field fits (checked at
// instantiation), so Damageable/Interactable/Savable tables all share this one helper —
// no common header, no id-first layout convention, no casts. The slice param is the
// LENGTH eraser: `[2]Damage_Entry` and `[7]Interact_Entry` both pass as `TABLE[:]`.
lookup :: proc "contextless" (table: []$E, id: typeid) -> (entry: E, ok: bool) {
	if id != nil {
		for e in table {
			if e.id == id {
				return e, true
			}
		}
	}
	return {}, false
}

// dispatch composes script_any + lookup — the whole "interface" pattern in one call:
//
//	if d, ptr, ok := rt.dispatch(DAMAGE_IMPLS[:], body); ok { d.hurt(ptr, amount) }
//
// ok=false folds "not an Odin script" and "no table entry for its class" together; when
// a call site needs to tell those apart (rare), use script_any + lookup separately.
dispatch :: proc "contextless" (table: []$E, obj: gdext.ObjectPtr) -> (entry: E, ctx: rawptr, ok: bool) {
	ptr, id := script_any(obj)
	if ptr == nil {
		return {}, nil, false
	}
	e, found := lookup(table, id)
	return e, ptr, found
}
