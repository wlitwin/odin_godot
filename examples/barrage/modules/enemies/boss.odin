//gd:extends Node2D
//gd:class Boss
package barrage_enemies

// ----------------------------------------------------------------------------
// Boss — the flow-sequencer showcase. Its whole fight is ONE declarative timeline
// (flow.sequence + repeat_n + parallel), ticked from _physics_process: three phases,
// each = telegraph -> pattern barrage -> vulnerable window, escalating in density.
// Phase transitions emit `phase_changed` — a SignalN whose STRUCT payload carries the
// phase number and its name (docs: signals, general form).
//
// The Boss registers with the BulletField like any enemy (id + radius per tick) and
// takes hits the same way (`take_hit`, routed by the Spawner). Its patterns hammer
// spawn_ring — phase 3 is the deliberate stress test (thousands of live bullets).
// ----------------------------------------------------------------------------

import "core:math"
import gd "godot:godot"
import flow "godot:flow"

Boss :: struct {
	owner: gd.Node2d,

	phase_changed: gd.SignalN(struct {
		phase: int,
		name:  gd.String,
	}),
	defeated: gd.Signal0,

	max_hp: int `gd:"export,range=50:2000:10"`,

	// runtime
	hp:        int,
	phase:     int,
	script:    flow.Action,
	built:     bool,
	ring_t:    f32, // spiral angle accumulator
	fast:      bool, // BARRAGE_TEST: compressed timings
	field:     gd.Object,
}

BOSS_RADIUS :: 36

boss_ready :: proc(self: ^Boss) {
	if self.max_hp == 0 {self.max_hp = 300}
	self.hp = self.max_hp
	grp := gd.new_string_name_cstring("enemies", true)
	gd.node_add_to_group(cast(gd.Node)self.owner, grp, false)
	bgrp := gd.new_string_name_cstring("boss", true)
	gd.node_add_to_group(cast(gd.Node)self.owner, bgrp, false)
	gd.node2d_set_position(self.owner, gd.Vector2{480, 160})

	// One flag read decides pacing for the whole fight (see game_state_is_test).
	gs := gd.node_get_node(cast(gd.Node)self.owner, gd.new_node_path_cstring("/root/GameState"))
	if gs != nil {
		m := gd.sname("is_test")
		v := gd.object_call(cast(gd.Object)gs, m)
		self.fast = bool(gd.variant_to_bool(&v))
	}

	// The fight, declared once. Odin procs aren't closures — each step reaches its
	// state through the ctx pointer tick() passes (= ^Boss).
	w :: proc(fast: bool, secs: f64) -> f64 {return fast ? secs * 0.12 : secs}
	self.script = flow.sequence(
		flow.call(boss_enter_phase_1),
		flow.repeat(self.fast ? 3 : 10, flow.sequence(flow.call(boss_ring_slow), flow.wait(w(self.fast, 0.8)))),
		flow.call(boss_enter_phase_2),
		flow.repeat(self.fast ? 4 : 14, flow.sequence(flow.call(boss_ring_double), flow.wait(w(self.fast, 0.55)))),
		flow.call(boss_enter_phase_3),
		// The stress phase: dense spiral rings until the boss dies (wait_flag-style —
		// the sequence just never advances past a repeat that outlives the boss's hp).
		flow.repeat(self.fast ? 6 : 60, flow.sequence(flow.call(boss_ring_storm), flow.wait(w(self.fast, 0.35)))),
	)
	self.built = true
}

@(private = "file")
boss_emit_phase :: proc(self: ^Boss, phase: int, name: cstring) {
	self.phase = phase
	boss_emit_phase_changed(self, i64(phase), gd.new_string_cstring(name))
}

@(private = "file")
boss_enter_phase_1 :: proc(ctx: rawptr) {boss_emit_phase(cast(^Boss)ctx, 1, "warmup")}
@(private = "file")
boss_enter_phase_2 :: proc(ctx: rawptr) {boss_emit_phase(cast(^Boss)ctx, 2, "crossfire")}
@(private = "file")
boss_enter_phase_3 :: proc(ctx: rawptr) {boss_emit_phase(cast(^Boss)ctx, 3, "storm")}

@(private = "file")
boss_ring :: proc(self: ^Boss, n: int, speed: f64, phase_off: f32) {
	field := find_field(cast(gd.Node)self.owner, &self.field)
	if field == nil {return}
	pos := gd.node2d_get_position(self.owner)
	m := gd.sname("spawn_ring")
	pv := gd.variant_from(&pos)
	nn := gd.Int(n)
	nv := gd.variant_from(&nn)
	sp := speed
	sv := gd.variant_from(&sp)
	ph := f64(phase_off)
	phv := gd.variant_from(&ph)
	dmg := gd.Int(1)
	dv := gd.variant_from(&dmg)
	_ = gd.object_call(field, m, pv, nv, sv, phv, dv)
}

@(private = "file")
boss_ring_slow :: proc(ctx: rawptr) {
	self := cast(^Boss)ctx
	self.ring_t += 0.35
	boss_ring(self, 24, 120, self.ring_t)
}

@(private = "file")
boss_ring_double :: proc(ctx: rawptr) {
	self := cast(^Boss)ctx
	self.ring_t += 0.22
	boss_ring(self, 36, 150, self.ring_t)
	boss_ring(self, 36, 100, -self.ring_t)
}

@(private = "file")
boss_ring_storm :: proc(ctx: rawptr) {
	self := cast(^Boss)ctx
	self.ring_t += math.TAU / 7
	boss_ring(self, 64, 180, self.ring_t)
	boss_ring(self, 48, 120, self.ring_t * 0.5)
	boss_ring(self, 32, 80, -self.ring_t)
}

boss_physics_process :: proc(self: ^Boss, delta: f64) {
	if !self.built {return}
	flow.tick(&self.script, self, delta)

	// Register with the field (same contract as Enemy; bigger circle).
	field := find_field(cast(gd.Node)self.owner, &self.field)
	if field == nil {return}
	pos := gd.node2d_get_position(self.owner)
	// Slow horizontal weave so the fight isn't a turret shoot.
	pos.x = 480 + 260 * math.sin(self.ring_t * 0.25)
	gd.node2d_set_position(self.owner, pos)
	m := gd.sname("register_enemy")
	id := gd.Int(gd.object_get_instance_id(cast(gd.Object)self.owner))
	iv := gd.variant_from(&id)
	pv := gd.variant_from(&pos)
	r := f64(BOSS_RADIUS)
	rv := gd.variant_from(&r)
	_ = gd.object_call(field, m, iv, pv, rv)
}

@(gd_method)
boss_take_hit :: proc(self: ^Boss, damage: gd.Int) -> gd.Bool {
	self.hp -= int(damage)
	if self.hp <= 0 {
		if field := find_field(cast(gd.Node)self.owner, &self.field); field != nil {
			m := gd.sname("unregister_enemy")
			id := gd.Int(gd.object_get_instance_id(cast(gd.Object)self.owner))
			iv := gd.variant_from(&id)
			_ = gd.object_call(field, m, iv)
		}
		boss_emit_defeated(self)
		gd.node_queue_free(cast(gd.Node)self.owner)
		return true
	}
	return false
}

@(gd_method)
boss_get_phase :: proc(self: ^Boss) -> gd.Int {return gd.Int(self.phase)}
