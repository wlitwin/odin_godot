package phase35_scripts

import gd "godot:godot"

// No //gd:class and no //gd:extends: the authored source path is this script's
// identity, while the owner handle supplies its engine base.
PathAlpha :: struct {
	owner: gd.Node,
}

@(gd_method)
path_alpha_identity :: proc(self: ^PathAlpha) -> i64 {
	return 101
}
