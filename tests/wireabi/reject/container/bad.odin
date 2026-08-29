//gd:extends Node
//gd:class BadContainerWire
package bad_container_wire

import gd "godot:godot"

Nested :: struct {
	values: []u8,
}
BadContainerWire :: struct {
	owner: gd.Node,
	state: Nested `gd:"replicate"`,
}
