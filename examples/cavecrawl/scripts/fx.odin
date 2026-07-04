package cavecrawl_scripts

// Juice, driven entirely from code: CPUParticles2D bursts and Tween flashes,
// no scene assets. Two shapes:
//   * fx_flash — a tween proof: paint the victim red NOW, tween back to
//     white; the engine animates, we fire-and-forget.
//   * fx_burst_at — a particles proof: a one-shot spark burst parented to
//     the WORLD (not the victim), so it outlives despawns — a slain
//     dweller's node is gone next frame, its ashes are not.
// Bursts are tracked with a time-to-live and reaped in fx_frame; a tween
// dies with its node, so flashes need no bookkeeping.

import gd "godot:godot"

FX_BURST_TTL :: f32(0.8) // seconds a spent emitter node lingers before reaping

Fx_Burst :: struct {
	node: gd.Cpu_Particles2d,
	left: f32,
}

// The emitter itself: a configured one-shot spark burst under `parent` at a
// parent-relative position, already emitting. Entities may hang one on
// themselves (see spelunker.odin's pyre); world-positioned bursts go
// through fx_burst_at so they get reaped.
fx_burst_node :: proc(parent: gd.Node, x, y: f32, color: gd.Color) -> gd.Cpu_Particles2d {
	p := gd.new_cpu_particles2d()
	gd.add_child(parent, cast(gd.Node)p)
	gd.node2d_set_position(cast(gd.Node2d)p, {x, y})
	gd.cpu_particles2d_set_amount(p, 12)
	gd.cpu_particles2d_set_lifetime(p, 0.4)
	gd.cpu_particles2d_set_one_shot(p, true)
	gd.cpu_particles2d_set_explosiveness_ratio(p, 1.0) // all at once: a burst, not a stream
	gd.cpu_particles2d_set_spread(p, 180)
	gd.cpu_particles2d_set_param_min(p, .Param_Initial_Linear_Velocity, 40)
	gd.cpu_particles2d_set_param_max(p, .Param_Initial_Linear_Velocity, 90)
	gd.cpu_particles2d_set_color(p, color)
	gd.cpu_particles2d_set_emitting(p, true)
	gd.print_str("CAVE_FX burst")
	return p
}

// A one-shot spark burst at a world position, in `color`.
fx_burst_at :: proc(self: ^CaveLobby, x, y: f32, color: gd.Color) {
	p := fx_burst_node(self.world, x, y, color)
	append(&self.bursts, Fx_Burst{node = p, left = FX_BURST_TTL})
}

// Reap spent burst emitters (called once per frame from process).
fx_frame :: proc(self: ^CaveLobby, delta: f64) {
	for i := 0; i < len(self.bursts); {
		b := &self.bursts[i]
		b.left -= f32(delta)
		if b.left <= 0 {
			gd.node_queue_free(cast(gd.Node)b.node)
			unordered_remove(&self.bursts, i)
			continue
		}
		i += 1
	}
}

// Flash a canvas item `color` and tween it back to white — the standard
// hit-feedback animation, from code: set the property, let a Tween walk it
// home. The tween is owned by the node; if the node dies mid-flash the
// tween dies with it.
fx_flash :: proc(node: gd.Node, color: gd.Color) {
	if cast(rawptr)node == nil {return}
	gd.canvas_item_set_modulate(cast(gd.Canvas_Item)node, color)
	tw := gd.node_create_tween(node)
	white := gd.Color{1, 1, 1, 1}
	v := gd.variant_from_color(&white)
	_ = gd.tween_tween_property(tw, cast(gd.Object)node, gd.new_node_path_string(gd.new_string_cstring("modulate")), v, 0.3)
	gd.print_str("CAVE_FX flash")
}
