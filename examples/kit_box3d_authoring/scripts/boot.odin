//gd:extends Node
//gd:class KitAuthoringBoot
package kit_authoring_boot

import gd "godot:godot"

// A real root script keeps the ordinary SDK scripts library nonempty. The
// actual project driver is the separate authoring_demo module, not this node.
KitAuthoringBoot :: struct {
    owner: gd.Node,
    ready: bool,
}

kit_authoring_boot_ready :: proc(self: ^KitAuthoringBoot) {
    self.ready = true
}
