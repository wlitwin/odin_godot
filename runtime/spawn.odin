package script_runtime

import "godot:gdext"
import gd "godot:godot"

// ----------------------------------------------------------------------------
// Typed spawning — instantiate + rt.script_of in one call. The manual ritual was five
// steps (instantiate, nil-guard, add_child, script_of, nil-guard) with two encoded
// hazards that only lived in comments:
//
//   * POKE ORDER — fields poked BEFORE add_child are visible to the spawnee's _ready;
//     poked after, _ready ran against defaults. `spawn_scripted` is the poke-first
//     shape (it does NOT parent — you add_child after); `spawn_as` is the
//     just-spawn-it shape (parents first, poke after _ready).
//   * DEFERRED PARENTING — adding children from a physics callback (body_entered, …)
//     must go through add_child_deferred. `spawn_as_deferred` is that shape; note the
//     spawnee's _ready then runs at idle time, AFTER your pokes, which conveniently
//     makes deferred spawning poke-first by construction.
//
// All are nil-safe: a nil scene or failed instantiate returns nils; a root that does
// not carry the expected script returns the node with a nil ^T (same contract as
// rt.script_of — the caller's nil-check decides whether that's fatal).
// Main-thread only, like script_of.
// ----------------------------------------------------------------------------

// spawn_scripted instantiates `scene` and resolves its root's script struct WITHOUT
// parenting it: poke fields through ^T first, then `gd.add_child(parent, node)` — the
// spawnee's _ready sees the poked values.
//
//	node, b := rt.spawn_scripted(self.bullet_scene, Bullet)
//	if b == nil {return}
//	b.dir = dir; b.damage = dmg
//	gd.add_child(arena, node)
spawn_scripted :: proc "contextless" (scene: gd.Packed_Scene, $T: typeid) -> (node: gd.Node, s: ^T) {
	if scene == nil {
		return nil, nil
	}
	node = gd.instantiate(scene)
	if node == nil {
		return nil, nil
	}
	s = script_of(cast(gdext.ObjectPtr)node, T)
	return
}

// spawn_as instantiates `scene`, parents it under `parent`, and returns the root's
// typed script struct — the just-spawn-it form. The spawnee's _ready has RUN by the
// time this returns; use spawn_scripted when _ready must see poked fields.
spawn_as :: proc "contextless" (parent: gd.Node, scene: gd.Packed_Scene, $T: typeid) -> ^T {
	node, s := spawn_scripted(scene, T)
	if node == nil {
		return nil
	}
	gd.add_child(cast(gd.Object)parent, cast(gd.Object)node)
	return s
}

// spawn_as_deferred — spawn_as via add_child_deferred, REQUIRED when spawning from a
// physics callback (body_entered/area_entered handlers, _physics_process contact
// resolution). The parenting (and thus the spawnee's _ready) happens at idle time, so
// fields poked through the returned ^T right after this call are ready-visible.
spawn_as_deferred :: proc "contextless" (parent: gd.Node, scene: gd.Packed_Scene, $T: typeid) -> ^T {
	node, s := spawn_scripted(scene, T)
	if node == nil {
		return nil
	}
	gd.add_child_deferred(cast(gd.Object)parent, cast(gd.Object)node)
	return s
}
