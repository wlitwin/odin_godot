package kit_fx

// kit/fx — code-driven juice: one-shot particle bursts, hit-flash tweens,
// and the projectile TRACER pool (tracers.odin). No scene assets to install;
// any script can summon these — an entity that keeps its own emitter (a
// carried torch, a pyre) authors it in its scene instead.
//
// 2D ONLY, stated plainly: bursts are Cpu_Particles2d, floats are
// Control-positioned Labels, shake moves a Node2d — a 3D game gets nothing
// from this package (including screen shake) and authors its own juice.
// The (x, y) args are honest about that; the toolkit's [3]f32 position
// convention resumes where the math is dimension-agnostic (combat/interact/
// ai), which this package deliberately is not.
//
// Two lifetimes, two shapes:
//   * flash — fire-and-forget: paint the node a color NOW, let a Tween walk
//     it back to white. The tween is owned by the node; if the node dies
//     mid-flash the tween dies with it. No bookkeeping.
//   * burst_at — a one-shot spark burst parented to the WORLD (not the
//     victim), so it outlives despawns: a slain enemy's node is gone next
//     frame, its ashes are not. Spent emitters carry a time-to-live in a
//     Bursts pool the game owns; call frame() once per frame to reap them.

import "core:math"
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

// Reap spent burst emitters (call once per frame from process). Named like
// its pool siblings floats_frame/shake_frame/tracers_frame — the bare
// `frame` this file shipped with was the one outlier in its own convention.
bursts_frame :: proc(fx: ^Bursts, delta: f64) {
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
	defer gd.variant_destroy(&v)
	// Caller-owned engine values, released after the call that consumes them
	// (tracer_add's discipline) — the inline chain leaked a String and a
	// NodePath per flash, ~forever on a hit-heavy screen.
	s := gd.new_string_cstring("modulate")
	defer gd.free_string(s)
	np := gd.new_node_path_string(s)
	defer gd.free_node_path(np)
	_ = gd.tween_tween_property(tw, cast(gd.Object)node, np, v, 0.3)
}

// ---- floating text ---------------------------------------------------------------
//
// The "+2 wood" / "-14" number that pops off a spot and drifts up while
// fading — the cheapest juice-per-line in the toolkit. Pool-driven like
// Bursts: the game owns a Floats, calls floats_frame once per frame, and the
// labels animate and reap themselves. Parent to the WORLD (they must outlive
// whatever they announce).

FLOAT_TTL :: f32(0.9) // seconds aloft
FLOAT_RISE :: f32(46) // px/s upward drift

Float :: struct {
	node: gd.Label,
	left: f32,
}

Floats :: struct {
	live: [dynamic]Float,
}

floats_destroy :: proc(fx: ^Floats) {
	delete(fx.live)
	fx^ = {}
}

// Pop `text` at a parent-relative position in `color`. The cstring is copied
// by the engine; temp-allocated text is fine.
float_text :: proc(fx: ^Floats, parent: gd.Node, x, y: f32, text: cstring, color := gd.Color{1, 1, 1, 1}) {
	l := gd.new_label()
	gd.set_text(cast(gd.Object)l, text)
	gd.add_child(parent, cast(gd.Node)l)
	gd.control_set_position(cast(gd.Control)l, {x, y}, false)
	gd.canvas_item_set_modulate(cast(gd.Canvas_Item)l, color)
	append(&fx.live, Float{node = l, left = FLOAT_TTL})
}

floats_frame :: proc(fx: ^Floats, delta: f64) {
	for i := 0; i < len(fx.live); {
		f := &fx.live[i]
		f.left -= f32(delta)
		if f.left <= 0 {
			gd.node_queue_free(cast(gd.Node)f.node)
			unordered_remove(&fx.live, i)
			continue
		}
		pos := gd.control_get_position(cast(gd.Control)f.node)
		gd.control_set_position(cast(gd.Control)f.node, {pos.x, pos.y - FLOAT_RISE * f32(delta)}, false)
		t := f.left / FLOAT_TTL
		gd.canvas_item_set_modulate(cast(gd.Canvas_Item)f.node, {1, 1, 1, t < 0.6 ? t / 0.6 : 1})
		i += 1
	}
}

// ---- screen shake -----------------------------------------------------------------
//
// Trauma-model shake (the industry-standard feel): impacts ADD trauma,
// trauma decays linearly, and the applied offset is trauma² times a jitter —
// so small hits whisper and big ones slam, with no lingering wobble. Apply
// it to the boot stage/world containers (Node2D since kit/boot made them
// so): both nudge together and every child rides along.
//
//     kfx.shake_add(&self.shake, 0.3)                  // on impact
//     kfx.shake_frame(&self.shake, delta,              // once per frame
//         self.boot.stage, self.boot.world)

Shake :: struct {
	trauma: f32, // 0..1
	t:      f32, // running clock driving the jitter
}

shake_add :: proc(s: ^Shake, amount: f32) {
	s.trauma = min(s.trauma + amount, 1)
}

SHAKE_DECAY :: f32(1.6) // trauma/s — a full slam settles in ~0.6s
SHAKE_MAX :: f32(7) // px at trauma 1

shake_frame :: proc(s: ^Shake, delta: f64, nodes: ..gd.Node) {
	if s.trauma <= 0 {
		return
	}
	s.trauma = max(s.trauma - SHAKE_DECAY * f32(delta), 0)
	s.t += f32(delta)
	amp := s.trauma * s.trauma * SHAKE_MAX
	// Two incommensurate sines beat like noise — deterministic, allocation-free.
	ox := amp * math.sin(s.t * 91.7)
	oy := amp * math.sin(s.t * 113.3 + 1.7)
	if s.trauma == 0 {ox, oy = 0, 0} // settle EXACTLY home on the last frame
	for n in nodes {
		gd.node2d_set_position(cast(gd.Node2d)n, {ox, oy})
	}
}
