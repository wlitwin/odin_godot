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
// OUR-language Odin script instance attached (foreign language / placeholder / no script).
Script_Struct_Proc :: proc "c" (obj: gdext.ObjectPtr) -> rawptr

@(private)
core_script_struct: Script_Struct_Proc

// Called by the core to hand the scripts dll its `obj -> script struct` resolver. Exported
// so the native core can resolve it by name (dlsym) after boot; called directly on web.
@(export)
odin_scripts_set_core_api :: proc "c" (script_struct: Script_Struct_Proc) {
	core_script_struct = script_struct
}

// Typed reference to another node's/resource's Odin script struct. Returns nil when `obj`
// is nil, the core API has not been wired, or `obj` carries no OUR-language Odin script
// instance. Because every script lives in one dll, `T` is the real script struct type, so
// `script_of(node, Enemy).hp` is a direct field access — no Variant marshaling.
script_of :: proc "contextless" (obj: gdext.ObjectPtr, $T: typeid) -> ^T {
	if core_script_struct == nil || obj == nil {
		return nil
	}
	return cast(^T)core_script_struct(obj)
}
