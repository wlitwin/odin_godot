//gd:extends Node
//gd:class BadPlatformWire
package bad_platform_wire

import gd "godot:godot"

Nested :: struct {
	count: int,
}
BadPlatformWire :: struct {
	owner: gd.Node,
	state: Nested `gd:"replicate"`,
}
