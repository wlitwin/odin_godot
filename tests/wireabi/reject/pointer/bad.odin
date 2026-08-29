//gd:extends Node
//gd:class BadPointerWire
package bad_pointer_wire

import gd "godot:godot"

Nested :: struct {
	target: ^u8,
}
BadPointerWire :: struct {
	owner: gd.Node,
	state: Nested `gd:"replicate"`,
}
