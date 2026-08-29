//gd:extends Node
//gd:class BadUintWire
package bad_uint_wire

import gd "godot:godot"

Nested :: struct {
	count: uint,
}
BadUintWire :: struct {
	owner: gd.Node,
	state: Nested `gd:"replicate"`,
}
