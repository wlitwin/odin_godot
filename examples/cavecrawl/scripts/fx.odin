package cavecrawl_scripts

// Juice via kit/fx — the game keeps only these thin wrappers so the acid
// test's CAVE_FX log lines survive (the library is silent; the game
// narrates). An entity that keeps its own emitter — the spelunker's pyre —
// authors it in its scene instead; these are for FX with no authored home.

import gd "godot:godot"
import kfx "godot:kit/fx"

// A one-shot spark burst at a world position, in `color` (world-parented so
// it outlives despawns; kfx.frame in process reaps the spent emitters).
fx_burst_at :: proc(self: ^CaveLobby, x, y: f32, color: gd.Color) {
	kfx.burst_at(&self.fx, self.world, x, y, color)
	gd.print_str("CAVE_FX burst")
}

// Flash a victim `color` and let the Tween walk it back to white.
fx_flash :: proc(node: gd.Node, color: gd.Color) {
	if cast(rawptr)node == nil {return}
	kfx.flash(node, color)
	gd.print_str("CAVE_FX flash")
}
