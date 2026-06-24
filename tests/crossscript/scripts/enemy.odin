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
}

// A custom method, callable from GDScript and (typed) from Odin via an ^Enemy reference.
@(gd_method)
enemy_heal :: proc(self: ^Enemy, amount: gd.Int) {
	self.hp += amount
}
