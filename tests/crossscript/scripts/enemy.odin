//gd:extends Node
//gd:class Enemy
package crossscript_scripts

// ----------------------------------------------------------------------------
// Enemy — a trivial Node script (script "B" in the cross-script test). It owns an
// `@export hp` field and a `heal` method. Another Odin script (Controller) obtains a
// TYPED `^Enemy` reference to a live Enemy node at runtime and mutates `hp` DIRECTLY
// (no Variant marshaling), proving typed cross-script field + struct access.
// ----------------------------------------------------------------------------

import gd "godot:godot"

Enemy :: struct {
	owner: gd.Node,
	hp:    gd.Int `gd:"export"`,
	hurt:  gd.Signal1(int) `gd:"args=amount"`, // declared signal — Wingman path-connects to it
}

// A custom method, callable from GDScript and (typed) from Odin via an ^Enemy reference.
@(gd_method)
enemy_heal :: proc(self: ^Enemy, amount: gd.Int) {
	self.hp += amount
}

// shout(amount): emit the declared `hurt` signal — the driver triggers it to prove a
// path-qualified @(gd_connect) fires the connected handler with args intact.
@(gd_method)
enemy_shout :: proc(self: ^Enemy, amount: gd.Int) {
	enemy_emit_hurt(self, i64(amount))
}

// power(mult): an int-returning method — the gd.vcall_int by-name target.
@(gd_method)
enemy_power :: proc(self: ^Enemy, mult: gd.Int) -> int {
	return int(self.hp) * int(mult)
}
