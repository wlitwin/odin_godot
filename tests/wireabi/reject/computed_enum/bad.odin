//gd:extends Node
//gd:class BadComputedEnumWire
package bad_computed_enum_wire

import gd "godot:godot"

FIRST :: 3

Mode :: enum u8 {
	Idle = FIRST,
	Run,
}

BadComputedEnumWire :: struct {
	owner: gd.Node,
	mode:  Mode `gd:"replicate"`,
}
