package kit_combat

// kit/combat — health, abilities, status effects, projectiles (toolkit
// phase 4). Everything here is DETERMINISTIC, ALLOCATION-FREE and engine-
// free, because it runs inside predicted commands and host ticks: the
// casting client and the host execute the same gates from the same bytes.
//
// THE SHAPES:
//
//   * Combat state is plain replicated fields on YOUR entity — `hp: i32`,
//     `cds: [4]u16`, `fx: [4]Effect` — riding the phase-0 delta walk.
//     kit/combat is the OPERATIONS on them.
//   * Cooldowns/effects count NET TICKS, decremented by the AUTHORITY in its
//     game tick (abilities_tick/effects_tick); clients see the countdown
//     through replication. A cast raced against the last few ticks of a
//     cooldown may mispredict locally — the command still ships, and the
//     host's answer stands (that is the whole model).
//   * Projectiles are NOT entities: the shooter's cast is predicted (cost
//     and cooldown bite instantly), everyone draws LOCAL visuals from the
//     same sim math, and only the HOST's sim deals damage — peer-owned
//     visuals, host-validated hits. projectile_hit sweeps the whole tick's
//     segment, so fast rocks can't tunnel through a spelunker.
//   * Damage/kill/death tallies auto-publish into the phase-1 stat registry
//     (combat_columns once at host start, credit_* at the point of impact) —
//     the scoreboard widget renders them like any other column.

import knet "godot:kit/net"
import ksess "godot:kit/session"
import "core:math"

// ---- health ------------------------------------------------------------------

// Apply damage: clamps at zero, reports the killing blow exactly once
// (hitting a corpse is a no-op — no double kills, no negative hp).
hit :: proc "contextless" (hp: ^i32, amount: i32) -> (died: bool) {
	if hp^ <= 0 || amount <= 0 {
		return false
	}
	hp^ = max(0, hp^ - amount)
	return hp^ == 0
}

// ---- abilities: integer costs + tick cooldowns -------------------------------

Ability_Def :: struct {
	name:     string, // for ability bars / logs; kit/combat never allocates it
	cooldown: u16, // net ticks
	cost:     i32, // spent from whatever resource the game passes in
}

// The whole cast gate, shared by prediction and authority: ready + affordable
// -> pay and start the cooldown. Call from inside the ability's command proc.
ability_try :: proc "contextless" (cds: []u16, slot: int, def: Ability_Def, resource: ^i32) -> bool {
	if slot < 0 || slot >= len(cds) {
		return false
	}
	if cds[slot] != 0 || resource^ < def.cost {
		return false
	}
	resource^ -= def.cost
	cds[slot] = def.cooldown
	return true
}

ability_ready :: proc "contextless" (cds: []u16, slot: int) -> bool {
	return slot >= 0 && slot < len(cds) && cds[slot] == 0
}

// The authority's per-net-tick decay (clients receive it as deltas).
abilities_tick :: proc "contextless" (cds: []u16) {
	for &c in cds {
		if c > 0 {
			c -= 1
		}
	}
}

// ---- status effects ------------------------------------------------------------

// One buff/debuff: 4 POD bytes, embedded as a fixed array (`fx: [4]Effect`).
// Kinds are game-defined (0 is reserved for "empty"); power is whatever the
// game means by it (a percent, a per-tick amount, a flag).
Effect :: struct {
	kind:  u8,
	power: i8,
	left:  u16, // ticks remaining
}

EFFECT_NONE :: u8(0)

// Apply an effect: an existing one of the same kind REFRESHES (strongest
// power, longest clock — re-applying never weakens); otherwise the first
// empty slot. False = all slots busy (the game decides if that matters).
effects_add :: proc "contextless" (fx: []Effect, kind: u8, power: i8, ticks: u16) -> bool {
	if kind == EFFECT_NONE || ticks == 0 {
		return false
	}
	for &e in fx {
		if e.kind == kind {
			e.power = max(e.power, power)
			e.left = max(e.left, ticks)
			return true
		}
	}
	for &e in fx {
		if e.kind == EFFECT_NONE {
			e = Effect{kind = kind, power = power, left = ticks}
			return true
		}
	}
	return false
}

// The authority's per-net-tick decay; expired slots zero back to empty (the
// exact empty value — replication diffs bytes).
effects_tick :: proc "contextless" (fx: []Effect) {
	for &e in fx {
		if e.kind == EFFECT_NONE {
			continue
		}
		e.left -= 1
		if e.left == 0 {
			e = {}
		}
	}
}

effect_of :: proc "contextless" (fx: []Effect, kind: u8) -> (Effect, bool) {
	for e in fx {
		if e.kind == kind && e.kind != EFFECT_NONE {
			return e, true
		}
	}
	return {}, false
}

// ---- projectiles: one sim, two jobs --------------------------------------------
//
// The SAME math runs as the host's authoritative sim (damage) and as every
// peer's local visual (tracers) — what you see is what the host computes,
// offset only by latency.

Projectile :: struct {
	pos:  [3]f32,
	vel:  [3]f32, // per TICK, not per second
	left: u16, // ticks to live
}

Target :: struct {
	id:     u32,
	pos:    [3]f32,
	radius: f32,
}

// Advance one tick. False = time to remove it (this tick still happened —
// hit-test the swept segment before discarding).
projectile_step :: proc "contextless" (p: ^Projectile) -> (alive: bool) {
	p.pos += p.vel
	if p.left == 0 {
		return false
	}
	p.left -= 1
	return p.left > 0
}

@(private = "file")
dist_sq :: proc "contextless" (a, b: [3]f32) -> f32 {
	d := b - a
	return d.x * d.x + d.y * d.y + d.z * d.z
}

// Does the segment [from, from+vel] pass within `radius` of `center`?
// Closest-point-on-segment — a whole tick of travel is tested at once, so
// projectiles faster than a body per tick still connect.
@(private = "file")
segment_hits :: proc "contextless" (from, vel, center: [3]f32, radius: f32) -> (t: f32, ok: bool) {
	len_sq := vel.x * vel.x + vel.y * vel.y + vel.z * vel.z
	t = 0
	if len_sq > 0 {
		to := center - from
		t = clamp((to.x * vel.x + to.y * vel.y + to.z * vel.z) / len_sq, 0, 1)
	}
	closest := from + vel * t
	return t, dist_sq(closest, center) <= radius * radius
}

// First target the tick's travel touches (earliest along the path wins, not
// nearest to the muzzle). `from` is the position BEFORE projectile_step.
projectile_hit :: proc "contextless" (from: [3]f32, vel: [3]f32, targets: []Target) -> (best: Target, ok: bool) {
	best_t := math.INF_F32
	for tg in targets {
		if t, h := segment_hits(from, vel, tg.pos, tg.radius); h && t < best_t {
			best_t = t
			best = tg
			ok = true
		}
	}
	return
}

// ---- auto-published combat stats -------------------------------------------------

Combat_Cols :: struct {
	damage: ksess.Stat_Col,
	kills:  ksess.Stat_Col,
	deaths: ksess.Stat_Col,
}

// Host, once at start: declare the standard combat columns (idempotent).
// The phase-1 scoreboard machinery replicates and renders them from here on.
combat_columns :: proc(s: ^ksess.Session) -> Combat_Cols {
	return Combat_Cols {
		damage = ksess.session_stat_column(s, "damage"),
		kills  = ksess.session_stat_column(s, "kills"),
		deaths = ksess.session_stat_column(s, "deaths"),
	}
}

// Host, at the point of impact. Self-damage tallies nothing but the pain.
credit_hit :: proc(s: ^ksess.Session, cols: Combat_Cols, attacker: knet.Player_Id, amount: i32) {
	if attacker == knet.PLAYER_ID_INVALID {
		return
	}
	ksess.session_stat_add(s, attacker, cols.damage, i64(amount))
}

// Host, on a killing blow.
credit_kill :: proc(s: ^ksess.Session, cols: Combat_Cols, attacker, victim: knet.Player_Id) {
	if attacker != knet.PLAYER_ID_INVALID && attacker != victim {
		ksess.session_stat_add(s, attacker, cols.kills, 1)
	}
	if victim != knet.PLAYER_ID_INVALID {
		ksess.session_stat_add(s, victim, cols.deaths, 1)
	}
}
