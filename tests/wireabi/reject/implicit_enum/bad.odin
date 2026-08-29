//gd:extends Node
//gd:class BadEnumWire
package bad_enum_wire

import gd "godot:godot"

Mode :: enum {
	Idle,
	Run,
}
Nested :: struct {
	mode: Mode,
}
BadEnumWire :: struct {
	owner: gd.Node,
	state: Nested `gd:"replicate"`,
}
