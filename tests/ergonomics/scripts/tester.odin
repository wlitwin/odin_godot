//gd:extends Node2D
//gd:class Tester
//gd:signal pinged(value: int)
//gd:signal triggered()
package ergonomics_scripts

// ----------------------------------------------------------------------------
// Tester — a Node2D that, on _ready, exercises EVERY ergonomic helper against the REAL
// running scene and records a per-helper pass bitmask into its `result` @export so the
// GDScript driver can assert it. Signal emission is driven separately (do_emit/do_trigger),
// after the driver has connected its listeners.
//
// Pure Odin: every line below is a `gd.<helper>(...)` one-liner — no raw StringName /
// Variant / method-bind dances.
// ----------------------------------------------------------------------------

import gd "godot:godot"

Tester :: struct {
	owner:  gd.Node2d,
	result: gd.Int `gd:"export"`,
}

BIT_GET_NODE :: 1 << 0
BIT_GET_PARENT :: 1 << 1
BIT_GET_TREE :: 1 << 2
BIT_GROUP :: 1 << 3
BIT_SPAWN :: 1 << 4
BIT_INT :: 1 << 5
BIT_FLOAT :: 1 << 6
BIT_BOOL :: 1 << 7
BIT_STRING :: 1 << 8

tester_ready :: proc(self: ^Tester) {
	r: i64 = 0

	// --- nodes ---
	target := gd.get_node(self.owner, "Target")
	if target != nil {r |= BIT_GET_NODE}
	if gd.get_parent(self.owner) != nil {r |= BIT_GET_PARENT}
	if gd.get_tree(self.owner) != nil {r |= BIT_GET_TREE}

	// --- groups ---
	gd.add_to_group(self.owner, "ergo")
	if gd.is_in_group(self.owner, "ergo") {r |= BIT_GROUP}
	// prove remove works too (re-add so the driver still sees membership).
	gd.remove_from_group(self.owner, "ergo")
	if !gd.is_in_group(self.owner, "ergo") {
		gd.add_to_group(self.owner, "ergo")
	} else {
		r &~= BIT_GROUP // remove_from_group did nothing -> fail the bit
	}

	// --- scenes: spawn = load_scene + instantiate + add_child ---
	bullet := gd.spawn(self.owner, "res://bullet.tscn")
	if bullet != nil && gd.get_node(self.owner, "Bullet") != nil {r |= BIT_SPAWN}

	// --- dynamic properties on the Target node, by name ---
	if target != nil {
		gd.set_int(target, "z_index", 7)
		if gd.get_int(target, "z_index") == 7 {r |= BIT_INT}

		gd.set_float(target, "rotation", 0.5)
		f := gd.get_float(target, "rotation")
		if f > 0.49 && f < 0.51 {r |= BIT_FLOAT}

		gd.set_bool(target, "visible", false)
		if gd.get_bool(target, "visible") == false {r |= BIT_BOOL}

		gd.set_string(target, "text", "hello")
		if gd.get_string(target, "text") == "hello" {r |= BIT_STRING}
	}

	self.result = r
}

// do_emit fires the script-declared `pinged` signal WITH a payload (gd.emit_args).
@(gd_method)
tester_do_emit :: proc(self: ^Tester, value: i64) {
	v := value
	gd.emit_args(self.owner, "pinged", gd.variant_from(&v))
}

// do_trigger fires the zero-payload `triggered` signal (gd.emit).
@(gd_method)
tester_do_trigger :: proc(self: ^Tester) {
	gd.emit(self.owner, "triggered")
}
