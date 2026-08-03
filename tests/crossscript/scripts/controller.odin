//gd:extends Node
//gd:class Controller
package crossscript_scripts

// ----------------------------------------------------------------------------
// Controller — script "A" in the cross-script test. At runtime it obtains a TYPED
// reference to a B-scripted (Enemy) node and reads/writes its exported field + calls its
// method DIRECTLY through the Odin struct, with no Variant marshaling. This is the payoff
// of Option A typed cross-script references: every script shares one dll, so `Enemy` is a
// shared type and `rt.script_of(node, Enemy)` returns a real `^Enemy`.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

Controller :: struct {
	owner: gd.Node,
}

// attack(amount): find the child "Enemy" node (a get_node node ref), obtain a TYPED
// ^Enemy, and subtract `amount` from its exported `hp` field DIRECTLY. Returns the
// post-hit hp, or -1 if the child is not an Odin Enemy.
@(gd_method)
controller_attack :: proc(self: ^Controller, amount: gd.Int) -> int {
	target := gd.get_node(self.owner, "Enemy")
	enemy := rt.script_of(target, Enemy)
	if enemy == nil {
		return -1
	}
	enemy.hp -= amount
	return int(enemy.hp)
}

// damage(target, amount): same, but for a node reference passed in explicitly (e.g. from
// an @export node ref). Also calls a TYPED Enemy method to prove cross-script proc access.
// Returns the post-hit hp, or -1 if `target` carries no Odin Enemy script (nil-safe).
@(gd_method)
controller_damage :: proc(self: ^Controller, target: gd.Node, amount: gd.Int) -> int {
	enemy := rt.script_of(target, Enemy)
	if enemy == nil {
		return -1
	}
	enemy.hp -= amount
	enemy_heal(enemy, 0) // typed cross-script METHOD call (no-op heal; proves it links)
	return int(enemy.hp)
}

// mistype(target): obtain `script_of(target, Enemy)` for a `target` whose attached Odin script
// is NOT an Enemy (e.g. a Controller). This is the DIRECT regression for the type-confusion hole:
// every Odin script shares one struct namespace in this dll, so before the class-checked resolver,
// `script_of` blindly returned WHATEVER struct was attached cast to `^Enemy` (non-nil garbage),
// defeating the caller's `if enemy == nil` guard. Returns 1 when the resolver correctly returns
// nil (type-safe), 0 when it wrongly returns a non-nil pointer (the bug).
@(gd_method)
controller_mistype :: proc(self: ^Controller, target: gd.Node) -> int {
	enemy := rt.script_of(target, Enemy)
	return enemy == nil ? 1 : 0
}

// ---- rt.script_any: per-TYPE static dispatch (the "interface" pattern) ----

Damage_Entry :: struct {
	id:   typeid,
	hurt: proc(ctx: rawptr, amount: int) -> int,
}

// One entry per TYPE, constant for all instances — the static vtable. Instances carry
// nothing and register nothing; `rt.script_any` recovers (struct, typeid) from the erased
// engine handle and the table picks the impl.
DAMAGE_IMPLS := [?]Damage_Entry {
	{typeid_of(Enemy), proc(ctx: rawptr, amount: int) -> int {
		e := cast(^Enemy)ctx
		e.hp -= gd.Int(amount)
		return int(e.hp)
	}},
	{typeid_of(Controller), proc(ctx: rawptr, amount: int) -> int {
		return 777 // distinct marker: proves the CONTROLLER impl ran, not the Enemy one
	}},
}

// dispatch(target, amount): damage WHATEVER `target` is through the table, via the
// TWO-STEP form (script_any + rt.lookup) — kept split so the outcomes stay separable.
// Returns the impl's result, -1 for a non-Odin node (script_any nil), -2 for an Odin
// script with no table entry.
@(gd_method)
controller_dispatch :: proc(self: ^Controller, target: gd.Node, amount: gd.Int) -> int {
	ptr, id := rt.script_any(target)
	if ptr == nil {
		return -1
	}
	if e, ok := rt.lookup(DAMAGE_IMPLS[:], id); ok {
		return e.hurt(ptr, int(amount))
	}
	return -2
}

// dispatch2(target, amount): the same through the ONE-CALL form (rt.dispatch), the
// pattern's normal spelling. -1 for both "not an Odin script" and "no entry".
@(gd_method)
controller_dispatch2 :: proc(self: ^Controller, target: gd.Node, amount: gd.Int) -> int {
	if d, ptr, ok := rt.dispatch(DAMAGE_IMPLS[:], target); ok {
		return d.hurt(ptr, int(amount))
	}
	return -1
}

// any_matches(target): the any-resolver must hand back the SAME struct pointer as the
// class-checked resolver — 1 when they agree.
@(gd_method)
controller_any_matches :: proc(self: ^Controller, target: gd.Node) -> int {
	ptr, _ := rt.script_any(target)
	return ptr != nil && ptr == rawptr(rt.script_of(target, Enemy)) ? 1 : 0
}
