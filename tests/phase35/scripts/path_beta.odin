package phase35_scripts

import gd "godot:godot"

// A second marker-less Node script. Base-type inference used to make this pair
// ambiguous; path identity must bind each file to its own descriptor.
PathBeta :: struct {
	owner: gd.Node,
}

@(gd_method)
path_beta_identity :: proc(self: ^PathBeta) -> i64 {
	return 202
}
