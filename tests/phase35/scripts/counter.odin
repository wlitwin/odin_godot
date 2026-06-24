//gd:extends RefCounted
//gd:class Counter
package phase35_scripts

// Counter — proves `extends` works for a base OTHER than Node2D (RefCounted, so
// GDScript owns the lifetime). One @export (`count`) and one custom method.

import gd "godot:godot"

Counter :: struct {
	owner: gd.Object,
	count: gd.Int `gd:"export"`,
}

@(gd_method)
counter_increment :: proc(self: ^Counter) -> int {
	self.count += 1
	return int(self.count)
}
