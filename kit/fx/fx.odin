package kit_fx

// kit/fx — code-driven juice: one-shot particle bursts, hit-flash tweens,
// and the projectile TRACER pool (tracers.odin). No scene assets to install;
// any script can summon these — an entity that keeps its own emitter (a
// carried torch, a pyre) authors it in its scene instead.
//
// 2D ONLY, stated plainly: bursts are Cpu_Particles2d, floats are
// Control-positioned Labels, and the SHIPPED appliers move a Node2d — a 3D
// game gets no ready-made juice here and authors its own. The exception is
// the shake TRAUMA MODEL, whose pure core (shake_tick + shake_sample) is
// dimension-free: a 3D game ticks it once a frame and samples the rotation
// channels for its own Camera3d (see the shake section), rather than getting
// no screen shake at all. The (x, y) applier args stay honest about the 2D
// stance; the toolkit's [3]f32 position convention resumes where the math is
// dimension-agnostic (combat/interact/ai), which this package's appliers
// deliberately are not.
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
import "core:math/noise"
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
// trauma decays linearly, and the applied amplitude is trauma^exponent times
// a jitter — so small hits whisper and big ones slam, with no lingering
// wobble. The jitter is COHERENT (a continuous function of the model's clock,
// never per-frame randoms): adjacent frames land near each other, so the
// shake pans instead of teleporting and slows correctly under
// Engine.time_scale / slow-mo. Apply it to the boot stage/world containers
// (Node2D since kit/boot made them so): both nudge together and every child
// rides along.
//
//     kfx.shake_add(&self.shake, 0.3)                  // on impact
//     kfx.shake_frame(&self.shake, delta,              // once per frame
//         self.boot.stage, self.boot.world)
//
// The ZERO VALUE is the kit feel it always had: 7 px, trauma², 1.6 trauma/s,
// sine-pair noise, translation only. Every knob on Shake is opt-in
// (0/nil = that default): `max_offset` for bigger slams, `exponent` for the
// response curve (3 whispers longer, then slams harder), `decay` for the
// settle time, `noise` to swap the driver (shake_noise_simplex ships as the
// band-limited upgrade), and `max_roll` for the ROTATION channel — the
// highest-value juice per the trauma talk. A 2D camera reads offset + roll;
// a 3D camera mostly wants rotation and little or no translation:
//
//     // 2D: offset + roll on a Camera2d (roll needs ignore_rotation=false)
//     ox, oy := kfx.shake_offset(&self.shake, delta)   // ticks the model
//     gd.camera2d_set_offset(cam, {ox, oy})
//     gd.node2d_set_rotation(cast(gd.Node2d)cam, f64(kfx.shake_roll(&self.shake)))
//
//     // 3D: rotation only, applied to the game's own Camera3d
//     kfx.shake_tick(&self.shake, delta)               // tick ONCE...
//     roll, pitch, yaw := kfx.shake_angles(&self.shake) // ...then sample
//
// Tick exactly once per frame: shake_offset/shake_frame tick internally; the
// sampling procs (shake_sample/shake_roll/shake_angles) never do. Pick ONE
// ticker per frame — shake_offset (2D) or shake_tick (3D) — and sample the
// rest off it.

// A noise driver: a smooth value in [-1, 1] for `channel` at clock `t`.
// Must be coherent (continuous in t) — that is the whole point — and the
// channels must be mutually independent (x, y, and each rotation axis pull
// from different streams, or the shake collapses to a diagonal slide).
Shake_Noise :: #type proc(channel: int, t: f32) -> f32

// Channel indices for shake_sample. What a channel MEANS is the applier's
// choice: shake_offset reads X/Y in px, shake_roll/shake_angles read the
// rotation rows in radians.
SHAKE_X :: 0
SHAKE_Y :: 1
SHAKE_ROLL :: 2
SHAKE_PITCH :: 3
SHAKE_YAW :: 4

Shake :: struct {
	trauma:     f32, // 0..1
	t:          f32, // running clock driving the jitter
	// ---- knobs — the zero value of each keeps the kit default ----
	max_offset: f32,         // px at full trauma            (0 → SHAKE_MAX)
	max_roll:   f32,         // radians at full trauma       (0 → SHAKE_MAX_ROLL)
	decay:      f32,         // trauma lost per second       (0 → SHAKE_DECAY)
	exponent:   f32,         // amplitude = trauma^exponent  (0 → 2)
	noise:      Shake_Noise, // channel driver               (nil → shake_noise_sines)
}

// Add trauma, optionally capped PER SOURCE. The cap solves the rapid-fire
// ratchet: a 0.25 kick every 0.15 s adds ~1.67 trauma/s against 1.6/s decay,
// so sustained fire slowly climbs to a full slam. With a cap, each shot still
// kicks fresh trauma but the SUM can never push past it —
//
//     kfx.shake_add(&s.shake, 0.25, 0.35)   // rifle: holds ~0.35 under autofire
//     kfx.shake_add(&s.shake, 0.6)          // explosion: may slam toward 1
//
// — while the outer max keeps a capped add from ever REDUCING trauma a bigger
// event already banked (a gunshot during an explosion is a no-op, not a damper).
shake_add :: proc(s: ^Shake, amount: f32, cap: f32 = 1) {
	s.trauma = max(s.trauma, min(s.trauma + amount, cap))
}

SHAKE_DECAY :: f32(1.6) // trauma/s — a full slam settles in ~0.6s
SHAKE_MAX :: f32(7) // px at trauma 1
SHAKE_MAX_ROLL :: f32(0.05) // radians at trauma 1 (~2.9° — rotation reads strong; start small)

// The default driver: one sine per channel at mutually incommensurate
// frequencies (they beat like noise) — deterministic, allocation-free, and
// exactly the pair the kit always used on X/Y. ~15 Hz feature rate.
@(private = "file")
SHAKE_FREQ := [5]f32{91.7, 113.3, 71.9, 127.1, 83.9}
@(private = "file")
SHAKE_PHASE := [5]f32{0, 1.7, 3.1, 0.9, 2.3}

shake_noise_sines :: proc(channel: int, t: f32) -> f32 {
	return math.sin(t * SHAKE_FREQ[channel % 5] + SHAKE_PHASE[channel % 5])
}

// The band-limited upgrade: OpenSimplex2 sampled along t, seeded per channel.
// Richer spectrum than the sine pair — no perceptible ring on long or
// high-trauma shakes — still deterministic and allocation-free. The x15 walk
// speed matches the sine driver's ~15 Hz feature rate, so swapping drivers
// keeps the same perceived tempo:
//
//     self.shake.noise = kfx.shake_noise_simplex
shake_noise_simplex :: proc(channel: int, t: f32) -> f32 {
	return noise.noise_2d(i64(channel) + 1, {f64(t) * 15, 0})
}

// Advance the trauma model one frame WITHOUT sampling: decay trauma, advance
// the clock. Idle (no trauma) does not advance, so a settled shake stays
// settled. This is the 3D/multi-channel entry point — tick once, then
// shake_sample/shake_angles any channels. (shake_offset ticks internally —
// never call both in the same frame or the model advances twice.)
shake_tick :: proc(s: ^Shake, delta: f64) {
	if s.trauma <= 0 {
		return
	}
	d := s.decay == 0 ? SHAKE_DECAY : s.decay
	s.trauma = max(s.trauma - d * f32(delta), 0)
	s.t += f32(delta)
}

// The shaped 0..1 envelope this frame: trauma^exponent. The power is the
// feel-knob from the trauma talk — 2 (default) is the classic; 3 makes small
// hits whisper even quieter while full slams stay full.
shake_amp :: proc(s: ^Shake) -> f32 {
	e := s.exponent == 0 ? 2 : s.exponent
	if e == 2 {
		return s.trauma * s.trauma
	}
	return math.pow(s.trauma, e)
}

// This frame's shaped, UNIT-SCALE sample for `channel`: envelope × noise, in
// [-amp, amp]. Multiply by your own max (px, radians, FOV degrees, …) — the
// shipped appliers below do exactly that with the struct's knobs. Sampling
// never advances the model; tick first. Idle → 0.
shake_sample :: proc(s: ^Shake, channel: int) -> f32 {
	if s.trauma <= 0 {
		return 0
	}
	n := s.noise == nil ? Shake_Noise(shake_noise_sines) : s.noise
	return shake_amp(s) * n(channel, s.t)
}

// The 2D translation applier core — advance the model and return this frame's
// (ox, oy) pixel offset, scaled by max_offset. Deterministic,
// allocation-free. Idle (no trauma) returns (0, 0) without advancing, so a
// settled shake stays home; the frame trauma reaches 0 lands EXACTLY home.
shake_offset :: proc(s: ^Shake, delta: f64) -> (ox, oy: f32) {
	if s.trauma <= 0 {
		return 0, 0
	}
	shake_tick(s, delta)
	n := s.noise == nil ? Shake_Noise(shake_noise_sines) : s.noise
	m := s.max_offset == 0 ? SHAKE_MAX : s.max_offset
	amp := shake_amp(s) * m
	ox = amp * n(SHAKE_X, s.t)
	oy = amp * n(SHAKE_Y, s.t)
	if s.trauma == 0 {ox, oy = 0, 0} // settle EXACTLY home on the last frame
	return
}

// This frame's roll in radians (SHAKE_ROLL × max_roll) — the 2D juice knob to
// add on top of shake_offset (which already ticked). Camera2d note: rotation
// only shows with ignore_rotation=false.
shake_roll :: proc(s: ^Shake) -> f32 {
	m := s.max_roll == 0 ? SHAKE_MAX_ROLL : s.max_roll
	return m * shake_sample(s, SHAKE_ROLL)
}

// The 3D rotational triple (roll, pitch, yaw), each in radians scaled by
// max_roll. Sampling only — shake_tick first. Per the trauma talk, rotation
// is most of what a 3D camera wants; games that want per-axis maxes sample
// the channels directly instead.
shake_angles :: proc(s: ^Shake) -> (roll, pitch, yaw: f32) {
	m := s.max_roll == 0 ? SHAKE_MAX_ROLL : s.max_roll
	return m * shake_sample(s, SHAKE_ROLL),
		m * shake_sample(s, SHAKE_PITCH),
		m * shake_sample(s, SHAKE_YAW)
}

// The 2D applier: advance the model via shake_offset and nudge every node to
// this frame's offset (the boot stage/world Node2Ds — both move together and
// every child rides along). A thin convenience over the pure core; idle is a
// no-op (the last settle frame already put them home).
shake_frame :: proc(s: ^Shake, delta: f64, nodes: ..gd.Node) {
	if s.trauma <= 0 {
		return
	}
	ox, oy := shake_offset(s, delta)
	for n in nodes {
		gd.node2d_set_position(cast(gd.Node2d)n, {ox, oy})
	}
}
