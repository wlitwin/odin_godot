//gd:extends Node
//gd:class WireAbiProfile
package wireabi_profile

import gd "godot:godot"
import ksess "godot:kit/session"

Profile_Row :: struct {
	color:     u16,
	ready:     bool,
	_reserved: u8,
}

WireAbiProfile :: struct {
	owner: gd.Node,
	ses:   ksess.Session `gd:"profile=Profile_Row"`,
}

wire_abi_profile_ready :: proc(self: ^WireAbiProfile) {
	_ = self
}
