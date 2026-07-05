package kit_fx

// kit/fx — code-driven juice: one-shot particle bursts, hit-flash tweens,
// and the projectile TRACER pool (tracers.odin). No scene assets to install;
// any script can summon these — an entity that keeps its own emitter (a
// carried torch, a pyre) authors it in its scene instead.
//
// Two lifetimes, two shapes:
//   * flash — fire-and-forget: paint the node a color NOW, let a Tween walk
//     it back to white. The tween is owned by the node; if the node dies
//     mid-flash the tween dies with it. No bookkeeping.
//   * burst_at — a one-shot spark burst parented to the WORLD (not the
//     victim), so it outlives despawns: a slain enemy's node is gone next
//     frame, its ashes are not. Spent emitters carry a time-to-live in a
//     Bursts pool the game owns; call frame() once per frame to reap them.

import gd "godot:godot"

BURST_TTL :: f32(0.8) // seconds a spent emitter node lingers before reaping

Burst :: struct {
	node: gd.Cpu_Particles2d,
	left: f32,
}

// The game owns one of these (a field on the script struct); destroy() on
// exit frees the tracking list (nodes belong to the scene tree).
Bursts :: struct {
	live: [dynamic]Burst,
}

bursts_destroy :: proc(fx: ^Bursts) {
	delete(fx.live)
	fx^ = {}
}

// The emitter itself: a configured one-shot spark burst under `parent` at a
// parent-relative position, already emitting. World-positioned bursts go
// through burst_at so they get reaped; this is the escape hatch for FX with
// a home of their own.
burst_node :: proc(parent: gd.Node, x, y: f32, color: gd.Color) -> gd.Cpu_Particles2d {
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
	return p
}

// A one-shot spark burst at a world position, in `color`, tracked for reaping.
burst_at :: proc(fx: ^Bursts, parent: gd.Node, x, y: f32, color: gd.Color) {
	p := burst_node(parent, x, y, color)
	append(&fx.live, Burst{node = p, left = BURST_TTL})
}

// Reap spent burst emitters (call once per frame from process).
frame :: proc(fx: ^Bursts, delta: f64) {
	for i := 0; i < len(fx.live); {
		b := &fx.live[i]
		b.left -= f32(delta)
		if b.left <= 0 {
			gd.node_queue_free(cast(gd.Node)b.node)
			unordered_remove(&fx.live, i)
			continue
		}
		i += 1
	}
}

// Flash a canvas item `color` and tween it back to white — the standard
// hit-feedback animation, from code: set the property, let a Tween walk it
// home. nil-safe (a victim's node may already be gone).
flash :: proc(node: gd.Node, color: gd.Color) {
	if cast(rawptr)node == nil {return}
	gd.canvas_item_set_modulate(cast(gd.Canvas_Item)node, color)
	tw := gd.node_create_tween(node)
	white := gd.Color{1, 1, 1, 1}
	v := gd.variant_from_color(&white)
	_ = gd.tween_tween_property(tw, cast(gd.Object)node, gd.new_node_path_string(gd.new_string_cstring("modulate")), v, 0.3)
}
