package kit_combat_test

// Standalone tests for kit/combat — the deterministic ops that run inside
// predicted commands and host ticks. No Godot runtime:
//
//   odin test tests/kitcombat -collection:godot=$PWD

import "core:testing"
import kcombat "godot:kit/combat"
import knet "godot:kit/net"
import ksess "godot:kit/session"

@(test)
hit_clamps_and_kills_once :: proc(t: ^testing.T) {
	hp := i32(10)
	testing.expect(t, !kcombat.hit(&hp, 7))
	testing.expect_value(t, hp, i32(3))
	testing.expect(t, kcombat.hit(&hp, 99), "the killing blow reports")
	testing.expect_value(t, hp, i32(0)) // clamped, never negative
	testing.expect(t, !kcombat.hit(&hp, 5), "corpses don't die twice")
	testing.expect_value(t, hp, i32(0))
	hp = 5
	testing.expect(t, !kcombat.hit(&hp, 0), "zero and negative damage are no-ops")
	testing.expect(t, !kcombat.hit(&hp, -3))
	testing.expect_value(t, hp, i32(5))
}

ROCK :: kcombat.Ability_Def{name = "rock", cooldown = 20, cost = 3}

@(test)
casts_gate_on_cooldown_and_cost :: proc(t: ^testing.T) {
	cds: [4]u16
	stamina := i32(7)

	testing.expect(t, kcombat.ability_try(cds[:], 0, ROCK, &stamina))
	testing.expect_value(t, stamina, i32(4))
	testing.expect_value(t, cds[0], u16(20))
	testing.expect(t, !kcombat.ability_try(cds[:], 0, ROCK, &stamina), "still hot")
	testing.expect_value(t, stamina, i32(4)) // a refused cast costs nothing

	// A different slot is its own clock, but the resource is shared.
	testing.expect(t, kcombat.ability_try(cds[:], 1, ROCK, &stamina))
	testing.expect_value(t, stamina, i32(1))
	testing.expect(t, !kcombat.ability_try(cds[:], 2, ROCK, &stamina), "too broke")
	testing.expect(t, !kcombat.ability_try(cds[:], 9, ROCK, &stamina), "no such slot")

	// The authority's decay brings it back, tick by tick.
	for _ in 0 ..< 19 {
		kcombat.abilities_tick(cds[:])
	}
	testing.expect(t, !kcombat.ability_ready(cds[:], 0))
	kcombat.abilities_tick(cds[:])
	testing.expect(t, kcombat.ability_ready(cds[:], 0))
	stamina = 100
	testing.expect(t, kcombat.ability_try(cds[:], 0, ROCK, &stamina))
}

CHILL :: u8(1)
BURN :: u8(2)

@(test)
effects_refresh_and_expire :: proc(t: ^testing.T) {
	fx: [2]kcombat.Effect

	testing.expect(t, kcombat.effects_add(fx[:], CHILL, 30, 10))
	testing.expect(t, kcombat.effects_add(fx[:], CHILL, 20, 25), "same kind refreshes")
	e, ok := kcombat.effect_of(fx[:], CHILL)
	testing.expect(t, ok)
	testing.expect_value(t, e.power, i8(30)) // strongest power...
	testing.expect_value(t, e.left, u16(25)) // ...longest clock

	testing.expect(t, kcombat.effects_add(fx[:], BURN, 5, 40))
	testing.expect(t, !kcombat.effects_add(fx[:], u8(3), 1, 10), "slots full")
	testing.expect(t, !kcombat.effects_add(fx[:], kcombat.EFFECT_NONE, 1, 10))

	for _ in 0 ..< 25 {
		kcombat.effects_tick(fx[:])
	}
	_, still := kcombat.effect_of(fx[:], CHILL)
	testing.expect(t, !still, "the chill wore off")
	testing.expect_value(t, fx[0], kcombat.Effect{}) // the EXACT empty value
	b, bok := kcombat.effect_of(fx[:], BURN)
	testing.expect(t, bok && b.left == 15)
}

@(test)
projectiles_fly_and_expire :: proc(t: ^testing.T) {
	p := kcombat.Projectile{pos = {0, 0, 0}, vel = {10, 0, 0}, left = 3}
	testing.expect(t, kcombat.projectile_step(&p))
	testing.expect_value(t, p.pos, [3]f32{10, 0, 0})
	testing.expect(t, kcombat.projectile_step(&p))
	testing.expect(t, !kcombat.projectile_step(&p), "ttl up")
	testing.expect_value(t, p.pos, [3]f32{30, 0, 0})
}

@(test)
fast_rocks_do_not_tunnel :: proc(t: ^testing.T) {
	// A body 8 units wide, a rock crossing 100 units in one tick: the naive
	// point test misses at both endpoints; the swept segment connects.
	body := []kcombat.Target{{id = 7, pos = {50, 1, 0}, radius = 4}}
	hit, ok := kcombat.projectile_hit({0, 0, 0}, {100, 0, 0}, body)
	testing.expect(t, ok, "the whole tick's travel is one hit test")
	testing.expect_value(t, hit.id, u32(7))

	// Off to the side: no hit.
	_, miss := kcombat.projectile_hit({0, 0, 0}, {100, 0, 0}, []kcombat.Target{{id = 8, pos = {50, 9, 0}, radius = 4}})
	testing.expect(t, !miss)

	// Behind the muzzle: the segment starts AT the muzzle, not before it.
	_, behind := kcombat.projectile_hit({0, 0, 0}, {100, 0, 0}, []kcombat.Target{{id = 9, pos = {-20, 0, 0}, radius = 4}})
	testing.expect(t, !behind)
}

@(test)
earliest_along_the_path_wins :: proc(t: ^testing.T) {
	// Two bodies on the same line: the rock hits the one it REACHES first,
	// even though both are within the swept segment.
	bodies := []kcombat.Target {
		{id = 1, pos = {80, 0, 0}, radius = 4},
		{id = 2, pos = {30, 0, 0}, radius = 4},
	}
	hit, ok := kcombat.projectile_hit({0, 0, 0}, {100, 0, 0}, bodies)
	testing.expect(t, ok)
	testing.expect_value(t, hit.id, u32(2))
}

@(test)
combat_stats_publish_into_the_registry :: proc(t: ^testing.T) {
	s: ksess.Session
	dummy_send :: proc(user: rawptr, to_peer: int, bytes: []u8, channel: ksess.Channel) {}
	s.send = dummy_send
	ksess.session_host_start(&s, "hosty")
	defer ksess.session_destroy(&s)

	cols := kcombat.combat_columns(&s)
	cols2 := kcombat.combat_columns(&s)
	testing.expect_value(t, cols, cols2) // idempotent, ready()-safe

	attacker := knet.Player_Id(2)
	victim := knet.Player_Id(3)
	kcombat.credit_hit(&s, cols, attacker, 25)
	kcombat.credit_hit(&s, cols, attacker, 10)
	kcombat.credit_kill(&s, cols, attacker, victim)
	testing.expect_value(t, ksess.session_stat(&s, attacker, cols.damage), i64(35))
	testing.expect_value(t, ksess.session_stat(&s, attacker, cols.kills), i64(1))
	testing.expect_value(t, ksess.session_stat(&s, victim, cols.deaths), i64(1))

	// Environmental deaths tally the victim; nobody gets the kill.
	kcombat.credit_kill(&s, cols, knet.PLAYER_ID_INVALID, victim)
	testing.expect_value(t, ksess.session_stat(&s, victim, cols.deaths), i64(2))
	// Falling on your own rock is only ever sad.
	kcombat.credit_kill(&s, cols, victim, victim)
	testing.expect_value(t, ksess.session_stat(&s, victim, cols.kills), i64(0))
	testing.expect_value(t, ksess.session_stat(&s, victim, cols.deaths), i64(3))
}
