package kit_fx

// The projectile TRACER pool — the visual half of the zero-felt-lag story.
// A kcombat.Fire describes the authoritative cast (px/TICK velocity, tick
// ttl); a tracer is that cast on THIS screen: a plain glyph Label flying on
// the FRAME clock (px/s), no entity, no wire. The pattern (proven by
// cavecrawl and the latency-injected acid tests):
//
//   * the shooter draws its tracer at CAST time (prediction — this frame);
//   * the host launches the authoritative sim rock AND announces the Fire
//     (session_app_send) so every other screen draws one;
//   * everyone skips their own echo (fire.shooter == me at the handler);
//   * per frame, tracers_frame flies each tracer and sweeps the same
//     segments the host's tick sim does, just finer — on visual contact the
//     game plays the impact NOW (predicted hp dip, sparks, flash) while
//     truth arrives a beat later as ordinary deltas and squares the number.
//
// The pool owns flight, node bookkeeping, and contact detection; the GAME
// owns what a hit means (the callbacks). Targets are rebuilt per tracer per
// frame because eligibility depends on the shooter (never hit your own
// avatar) — return them from temp_allocator.

import gd "godot:godot"
import kcombat "godot:kit/combat"
import knet "godot:kit/net"

Tracer :: struct {
	pos:     [3]f32,
	vel:     [3]f32, // px/s (converted from the Fire's px/tick)
	left:    f32, // seconds
	shooter: knet.Player_Id,
	node:    gd.Label,
	half:    gd.Vector2, // half the glyph's box — Controls anchor TOP-LEFT, flights are centers
}

Tracers :: struct {
	live: [dynamic]Tracer,
}

// Who can this shooter's tracer hit, right now. Slice from temp_allocator.
Targets_Proc :: proc(user: rawptr, shooter: knet.Player_Id) -> []kcombat.Target

Tracer_Hit :: struct {
	shooter: knet.Player_Id,
	target:  u32, // the kcombat.Target id the game supplied (a Net_Id, usually)
	pos:     [3]f32, // the victim's position (where the sparks go)
}

On_Hit_Proc :: proc(user: rawptr, hit: Tracer_Hit)

tracers_destroy :: proc(t: ^Tracers) {
	delete(t.live)
	t^ = {}
}

// Wipe every tracer (a level change: old rocks die with the old floor).
tracers_clear :: proc(t: ^Tracers) {
	for v in t.live {
		gd.node_queue_free(cast(gd.Node)v.node)
	}
	clear(&t.live)
}

// A tracer for `f` on this screen: a `glyph` Label under `parent`. The
// Fire's px/tick velocity and tick ttl become px/s and seconds here —
// visuals live on the frame clock. `tick_hz` is the session's rate
// (ksess.session_tick_hz).
tracer_add :: proc(t: ^Tracers, parent: gd.Node, f: kcombat.Fire, glyph: string, tick_hz: int) {
	node := gd.new_label()
	s := gd.new_string_odin(glyph)
	defer gd.free_string(s)
	sv := gd.variant_from_string(&s)
	defer gd.variant_destroy(&sv)
	gd.set_value(cast(gd.Object)node, "text", sv)
	gd.add_child(parent, cast(gd.Node)node)
	// A Label positions by its TOP-LEFT, but a flight position is the slug's
	// CENTER — uncorrected, every glyph hangs half a line-height below (and
	// right of) the true line, which reads as "bullets leave below the
	// barrel". Center the box on the flight.
	min_sz := gd.control_get_combined_minimum_size(cast(gd.Control)node)
	half := gd.Vector2{min_sz.x / 2, min_sz.y / 2}
	gd.control_set_position(cast(gd.Control)node, {f.origin.x - half.x, f.origin.y - half.y}, false)
	hz := f32(tick_hz)
	append(&t.live, Tracer {
		pos = f.origin,
		vel = f.vel * hz,
		left = f32(f.ttl) / hz,
		shooter = f.shooter,
		node = node,
		half = half,
	})
}

// Fly every tracer one frame; on visual contact call `on_hit` (the game
// plays its impact: predicted hp dip, burst, flash, hud) and reap. Expired
// tracers reap silently. Contact sweeps the frame's segment, so it lands on
// the frame the crossing happens — never after the authority's tick.
tracers_frame :: proc(t: ^Tracers, delta: f64, user: rawptr, targets: Targets_Proc, on_hit: On_Hit_Proc) {
	dt := f32(delta)
	for i := 0; i < len(t.live); {
		v := &t.live[i]
		from := v.pos
		step_vel := v.vel * dt
		v.pos += step_vel
		v.left -= dt
		gd.control_set_position(cast(gd.Control)v.node, {v.pos.x - v.half.x, v.pos.y - v.half.y}, false)

		if hit, hit_ok := kcombat.projectile_hit(from, step_vel, targets(user, v.shooter)); hit_ok {
			on_hit(user, Tracer_Hit{shooter = v.shooter, target = hit.id, pos = hit.pos})
			gd.node_queue_free(cast(gd.Node)v.node)
			unordered_remove(&t.live, i)
			continue
		}
		if v.left <= 0 {
			gd.node_queue_free(cast(gd.Node)v.node)
			unordered_remove(&t.live, i)
			continue
		}
		i += 1
	}
}
