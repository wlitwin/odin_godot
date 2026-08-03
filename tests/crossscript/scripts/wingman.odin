//gd:extends Node
//gd:class Wingman
//gd:group wingmen escorts
package crossscript_scripts

// ----------------------------------------------------------------------------
// Wingman — the DECLARED form of Controller's get_node + rt.script_of pattern: a
// script-resolving @onready. `buddy: ^Enemy` with `gd:"onready=Enemy"` makes the core
// resolve get_node("Enemy") AND its typed Odin script struct BEFORE _ready — the
// two-field handle + rt.script_of-in-ready idiom collapsed into one declaration.
// Nil when the node is missing or carries no Enemy script (loud, never a wrong cast).
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

Wingman :: struct {
	owner:     gd.Node,
	buddy:     ^Enemy `gd:"onready=Enemy"`,
	// ARRAY onready: `%d` substituted with 0-based indices at READY — children named
	// Squad0/Squad1, each element a TYPED script ref (nil where unresolvable).
	squad:          [2]^Enemy `gd:"onready=Squad%d"`,
	// SCENE-UNIQUE-NAME onready: `%doc` is Godot's unique-name NodePath syntax, passed
	// through to get_node — deliberately a name starting with 'd', so the path CONTAINS
	// the bytes "%d" and proves the marker is never read as an array template.
	doc:            ^Enemy `gd:"onready=%doc"`,
	sig_total:      int,
	squad_weighted: int,
	doc_total:      int,
}

// squad_hp(): sum of the squad's hp through the auto-wired TYPED array — -1 when any
// element failed to resolve (the driver's assertion surface for the array form).
@(gd_method)
wingman_squad_hp :: proc(self: ^Wingman) -> int {
	total := 0
	for s in self.squad {
		if s == nil {
			return -1
		}
		total += int(s.hp)
	}
	return total
}

// The path-qualified @(gd_connect): the CHILD's declared `hurt` signal -> this method,
// wired by the core at READY (the emitter is resolved like an `onready=` ref, so any
// get_node path works — not just the owner's own signals).
@(gd_method, gd_connect = "Enemy:hurt")
wingman_buddy_hurt :: proc(self: ^Wingman, amount: gd.Int) {
	self.sig_total += int(amount)
}

// sig_total(): what the connected handler accumulated (driver assertion surface).
@(gd_method)
wingman_sig_total :: proc(self: ^Wingman) -> int {
	return self.sig_total
}

// INDEXED @(gd_connect): Squad0/Squad1's `hurt` each wire here with their index BOUND
// as the trailing arg — one handler, N sibling emitters. Weighting by (idx+1) makes a
// wrong/missing index observably wrong in the driver's arithmetic.
@(gd_method, gd_connect = "Squad%d:hurt")
wingman_squad_hurt :: proc(self: ^Wingman, amount: gd.Int, idx: gd.Int) {
	self.squad_weighted += int(amount) * (int(idx) + 1)
}

@(gd_method)
wingman_squad_weighted :: proc(self: ^Wingman) -> int {
	return self.squad_weighted
}

// SCENE-UNIQUE @(gd_connect): the emitter path is a unique-name lookup, not a child
// path — same READY wiring, resolved through the owner's unique-name registry.
@(gd_method, gd_connect = "%doc:hurt")
wingman_doc_hurt :: proc(self: ^Wingman, amount: gd.Int) {
	self.doc_total += int(amount)
}

// doc_wired()/doc_total(): assertion surface for the `%doc` onready + connect pair.
@(gd_method)
wingman_doc_wired :: proc(self: ^Wingman) -> int {
	return self.doc != nil ? 1 : 0
}

@(gd_method)
wingman_doc_total :: proc(self: ^Wingman) -> int {
	return self.doc_total
}

// spawn_probe(scene): the typed-spawn family. spawn_scripted pokes hp BEFORE parenting
// (the ready-visible shape); spawn_as parents first and pokes after. Returns the two
// hp values summed so the driver can see both instances resolved typed.
@(gd_method)
wingman_spawn_probe :: proc(self: ^Wingman, scene: gd.Packed_Scene) -> int {
	node, e := rt.spawn_scripted(scene, Enemy)
	if e == nil {
		return -1
	}
	e.hp = 77
	gd.add_child(self.owner, node)
	s2 := rt.spawn_as(self.owner, scene, Enemy)
	if s2 == nil {
		return -2
	}
	s2.hp = 5
	return int(e.hp) + int(s2.hp)
}

// vcall_probe(amount): the BY-NAME call family (gd.vcall_*) — heal the buddy through a
// void call with an int arg, then read a computed int back through vcall_int. This is
// the cross-module spelling (engine-mediated, no shared types), exercised in-module
// where the result is checkable.
@(gd_method)
wingman_vcall_probe :: proc(self: ^Wingman, amount: gd.Int) -> int {
	if self.buddy == nil {
		return -1
	}
	target := cast(gd.Object)self.buddy.owner
	gd.vcall_void(target, "heal", amount)
	return int(gd.vcall_int(target, "power", 2))
}

// hit(amount): typed write through the auto-wired ref. -1 when the ref did not resolve.
@(gd_method)
wingman_hit :: proc(self: ^Wingman, amount: gd.Int) -> int {
	if self.buddy == nil {
		return -1
	}
	self.buddy.hp -= amount
	return int(self.buddy.hp)
}

// wired(): 1 when the auto-wired ref resolved non-nil (the positive proof the nil
// case in the driver contrasts against).
@(gd_method)
wingman_wired :: proc(self: ^Wingman) -> int {
	return self.buddy != nil ? 1 : 0
}
