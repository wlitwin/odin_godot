//gd:extends Node2D
//gd:class CodegenProbe
package codegen_scripts

// ----------------------------------------------------------------------------
// CodegenProbe — exercises ALL FOUR richer-authoring codegen features in one script:
//
//   (1) @onready node refs   — `sprite`/`label` auto-resolve to child nodes on _ready.
//   (2) @export groups        — `speed` opens a "Movement" header, `hp` a "Combat" header.
//   (3) @export defaults       — `speed := 200`, `jump := 12.5` initialize + report a default.
//   (4) getter/setter props    — `hp` reads/writes route through procs that clamp to 0..100.
//
// See docs/authoring-guide.md (#@onready / #@export groups / #defaults / #getters-setters).
// ----------------------------------------------------------------------------

import gd "godot:godot"

Probe :: struct {
	owner:  gd.Node2d,

	// (1) @onready — node-path relative to owner; resolved on READY (private, not exported).
	sprite: gd.Node2d `gd:"onready=Sprite"`,
	label:  gd.Node `gd:"onready=HUD/Label"`,

	// (2) group "Movement" + (3) defaults.
	speed:  f32 `gd:"export,group=Movement,default=200"`,
	jump:   f32 `gd:"export,default=12.5"`,

	// (2) group "Combat" + (4) getter/setter (clamped).
	hp:     i32 `gd:"export,group=Combat,get=probe_get_hp,set=probe_set_hp"`,

	// private bookkeeping for the @onready assertion.
	onready_resolved: bool,
}

probe_ready :: proc(self: ^Probe) {
	if self.sprite != nil && self.label != nil {
		// Prove a resolved ref is USABLE: read the child node's name (exercises the handle).
		_ = gd.node_get_name(self.label)
		self.onready_resolved = true
	}
}

// onready_ok() -> bool — true iff BOTH @onready refs resolved (and were usable) on _ready.
@(gd_method)
probe_onready_ok :: proc(self: ^Probe) -> bool {
	return self.onready_resolved
}

// getter/setter for the `hp` @export (richer-authoring #4). The setter CLAMPS writes into
// [0,100], so `set("hp", 500)` is observably stored as 100 when read back through the getter.
probe_get_hp :: proc(self: ^Probe) -> i32 {
	return self.hp
}
probe_set_hp :: proc(self: ^Probe, v: i32) {
	self.hp = clamp(v, 0, 100)
}
