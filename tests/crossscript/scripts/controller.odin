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
