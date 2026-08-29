//gd:extends Node
//gd:class BadProfileWire
package bad_profile_wire

import gd "godot:godot"
import ksess "godot:kit/session"

Bad_Profile :: struct {
	target: ^u8,
}

BadProfileWire :: struct {
	owner: gd.Node,
	ses:   ksess.Session `gd:"profile=Bad_Profile"`,
}

bad_profile_wire_ready :: proc(self: ^BadProfileWire) {
	_ = self
}
