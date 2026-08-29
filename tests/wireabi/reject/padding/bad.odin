//gd:extends Node
//gd:class BadPaddingWire
package bad_padding_wire

import gd "godot:godot"

Nested :: struct {
	flag:  u8,
	count: u32,
}
BadPaddingWire :: struct {
	owner: gd.Node,
	state: Nested `gd:"replicate"`,
}
