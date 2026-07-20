package kit_combat

// kit/combat — health, abilities, status effects, projectiles (toolkit
// phase 4). The MATH SHELF — targeting, cooldowns, hurt/heal, leash, the
// projectile pool — is DETERMINISTIC, ALLOCATION-FREE and engine-free,
// because it runs inside predicted commands and host ticks: the casting
// client and the host execute the same gates from the same bytes. The Fire
// wire half (announce/route) and the Predicted_Hp overlay are the exceptions
// — session-coupled presentation conveniences that live beside the math they
// serve, not part of that pure core.
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

// The scalar damage core — THE one implementation of the corpse-guarded
// clamp, generic over the game's hp integer (play.Health's u16, a raw i32
// field, a boss's whatever). `dealt` is what actually landed (0 on a corpse
// or a no-op amount — hit credit reads it); `died` reports the killing blow
// exactly once. hit() below and play.health_hurt both delegate here — the
// same one-gate rule as cast_gate: the two layers can never drift on what a
// death is.
hurt :: proc "contextless" (hp: ^$T, dmg: T) -> (dealt: T, died: bool) {
	if hp^ <= 0 || dmg <= 0 {
		return 0, false
	}
	dealt = min(dmg, hp^)
	hp^ -= dealt
	return dealt, hp^ == 0
}

// The scalar heal: restore `amount`, clamped to `maximum`. Reviving a corpse
// is a heal from 0 — whether that is ALLOWED is policy, gated by the caller.
heal :: proc "contextless" (hp: ^$T, maximum: T, amount: T) {
	hp^ = min(hp^ + amount, maximum)
}

// Apply damage to a raw hp field: clamps at zero, reports the killing blow
// exactly once (hitting a corpse is a no-op — no double kills, no negative
// hp). The died-only convenience over `hurt` for games that keep bare i32
// hp; block games get the same rules through play.Health.
hit :: proc "contextless" (hp: ^i32, amount: i32) -> (died: bool) {
	_, died = hurt(hp, amount)
	return died
}

// ---- abilities: integer costs + tick cooldowns -------------------------------

Ability_Def :: struct {
	name:     string, // for ability bars / logs; kit/combat never allocates it
	cooldown: u16, // ticks of whichever loop calls cd_decay (net ticks on coop, sim ticks on a lane)
	cost:     i32, // spent from whatever resource the game passes in
}

// The single-slot cast gate — THE one implementation of "ready + affordable
// -> pay and start", shared by prediction and authority. ability_try's
// slice+slot form and play.Ability's block form both delegate here (the
// play → kit arrow: the gate lives ONCE, so the two layers can never drift
// on what "ready" means again).
cast_gate :: proc "contextless" (cd: ^u16, cooldown: u16, cost: i32 = 0, resource: ^i32 = nil) -> bool {
	if cd^ != 0 {
		return false
	}
	if cost > 0 {
		if resource == nil || resource^ < cost {
			return false
		}
		resource^ -= cost
	}
	cd^ = cooldown
	return true
}

// One cooldown's per-net-tick decay toward ready — the scalar under
// abilities_tick and play.ability_tick. No-op when ready.
cd_decay :: proc "contextless" (cd: ^u16) {
	if cd^ > 0 {
		cd^ -= 1
	}
}

// The whole cast gate over a slot array. Call from inside the ability's
// command proc. A cost-free ability may pass no resource at all (both
// games' first free casts invented dummy locals for this).
ability_try :: proc "contextless" (cds: []u16, slot: int, def: Ability_Def, resource: ^i32 = nil) -> bool {
	if slot < 0 || slot >= len(cds) {
		return false
	}
	return cast_gate(&cds[slot], def.cooldown, def.cost, resource)
}

ability_ready :: proc "contextless" (cds: []u16, slot: int) -> bool {
	return slot >= 0 && slot < len(cds) && cds[slot] == 0
}

// The authority's per-net-tick decay (clients receive it as deltas).
abilities_tick :: proc "contextless" (cds: []u16) {
	for &c in cds {
		cd_decay(&c)
	}
}

// ---- cooldowns as an embeddable bundle ---------------------------------------
//
// The `cds: [N]u16 gd:"replicate"` field every combatant declares by hand, packaged:
// embed the bundle and the array replicates like a flat field (scriptgen recurses the
// nested struct — nested-replicate-fields), while the ops below forward to `cds[:]` so
// you never spell the slice. N is the ability-slot count, chosen per entity:
//
//     Runner :: struct { ..., using cd: kcombat.Cooldowns(3) }   // 3 ability slots
//     if kcombat.cd_try(&r.cd, SLOT_GUN, GUN_ABILITY) { ...fire... }  // in the command
//     kcombat.cd_tick(&r.cd)                                          // in the host tick
//
// `using` also promotes the array, so read sites stay `r.cds[SLOT]` (HUD gauges, etc.).
Cooldowns :: struct($N: int) {
	cds: [N]u16 `gd:"replicate"`,
}

cd_ready :: proc "contextless" (c: ^Cooldowns($N), slot: int) -> bool {
	return ability_ready(c.cds[:], slot)
}

cd_try :: proc "contextless" (c: ^Cooldowns($N), slot: int, def: Ability_Def, resource: ^i32 = nil) -> bool {
	return ability_try(c.cds[:], slot, def, resource)
}

cd_tick :: proc "contextless" (c: ^Cooldowns($N)) {
	abilities_tick(c.cds[:])
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
		// <= catches a hand-written {kind != 0, left = 0} row — effects_add
		// can't produce it, but a game assigning rows directly can, and the
		// bare decrement underflowed it to a 65535-tick immortal effect.
		if e.left <= 1 {
			e = {}
			continue
		}
		e.left -= 1
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

// leash clamps a CLAIMED point into a disc of radius r around anchor — the
// trust-but-verify for owner-reported cast origins. A moving caster's own
// screen is the truth for where its cast left from (its position is owner-
// authoritative anyway), while the authority's copy lags a stream behind;
// honest latency offsets pass through untouched, teleport-cheese gets
// dragged back to arm's length. Run it in the command proc itself: on the
// caster's own prediction claimed == anchor and it is a no-op — no role
// branch.
leash :: proc "contextless" (claimed, anchor: [3]f32, r: f32) -> [3]f32 {
	d := claimed - anchor
	n := math.sqrt(d.x * d.x + d.y * d.y + d.z * d.z)
	if n <= r {
		return claimed
	}
	return anchor + d * (r / n)
}

// DELIBERATELY kcombat's own vocabulary: kinteract.Candidate and kai.Target
// carry the same (id, pos) shape under their own names, and each package
// keeps a private dist_sq — the three math modules stay import-free of each
// other so a game can take any subset. The cost is a field-copy at the seams
// of a game that wires all three; the rule is INDEPENDENCE OVER SHARING for
// the math cores (kit/fx breaks it toward kcombat on purpose: tracers are
// the visual half of the Fire pattern, not a math module).
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

// ---- fire announcements: everyone draws their own rocks ---------------------------
//
// The wire half of peer-owned visuals: when the host confirms a cast it
// broadcasts a Fire (over the session's SES_APP), and EVERY peer runs the
// same projectile sim locally for the visual — the shooter starts theirs at
// cast time (zero RTT), everyone else on the announcement. Because the
// announcement and the eventual hp delta ride the same one-way path, remote
// visual impacts and health drops naturally coincide.

Fire :: struct {
	shooter: knet.Player_Id,
	origin:  [3]f32,
	vel:     [3]f32, // per tick
	ttl:     u16,
	kind:    u8, // game-defined (which ability/visual)
}

fire_write :: proc(w: ^knet.Writer, f: Fire) {
	knet.write_player_id(w, f.shooter)
	for i in 0 ..< 3 {knet.write_f32(w, f.origin[i])}
	for i in 0 ..< 3 {knet.write_f32(w, f.vel[i])}
	knet.write_u16(w, f.ttl)
	knet.write_u8(w, f.kind)
}

fire_read :: proc(r: ^knet.Reader) -> (f: Fire, ok: bool) {
	f.shooter = knet.read_player_id(r)
	for i in 0 ..< 3 {f.origin[i] = knet.read_f32(r)}
	for i in 0 ..< 3 {f.vel[i] = knet.read_f32(r)}
	f.ttl = knet.read_u16(r)
	f.kind = knet.read_u8(r)
	return f, !r.err
}

// The fire lane's default SES_APP tag, beside its siblings (comms 0, xfer 2,
// sim 3) — cavecrawl picked 1 by convention and every game since copied it.
FIRE_TAG :: u8(1)

// The two halves of the announcement, PACKAGED — the second consumer game
// reproduced cavecrawl's ~25 lines of tag plumbing and guard logic verbatim,
// which is the extraction bar. The HOST announces a confirmed cast — the
// assert is the sender half of the trust gate (the receiver drop below is
// the security boundary; this is the teaching moment: a client calling it
// broadcast frames every receiver silently discarded).
fire_announce :: proc(s: ^ksess.Session, f: Fire, tag: u8 = FIRE_TAG) {
	assert(s.is_host, "fire_announce is the AUTHORITY's half — clients see fires through fire_poll, they never author them")
	w := ksess.session_app_begin(s, tag)
	fire_write(w, f)
	ksess.session_app_flush(s, ksess.BROADCAST_PEER)
}

// The listener's registration record + queue. Owned by the GAME (a struct
// field, one per session) — kit/combat keeps no globals, so parallel
// sessions in one process (the test rig, dedicated hosts) never collide.
Fire_Route :: struct {
	ses:   ^ksess.Session,
	// The shared SES_APP rider queue (ksess.appq): handler pushes, game polls.
	// It used to be a bare [dynamic]Fire plus a hand-written poll — the fourth
	// copy of the same eight lines, which is what made the discipline a TYPE.
	fires: ksess.App_Queue(Fire),
}

// ...and every peer listens. The guards each game used to hand-roll live
// here now: only the HOST authors fires (a spoofed peer announcement is
// dropped), the host itself skips (its screen drew at launch), and your own
// echo skips (your screen drew at cast time). What lands in the queue is
// exactly "someone else's rock — draw it".
//
// EVENTS, NOT CALLBACKS — the handler only FILES into `ksess.App_Queue`; the
// game drains with fire_poll each frame, on its own stack. That discipline is
// a TYPE now, not a habit each package re-earns (comms, xfer, the album and
// this lane all hold the same queue) — the old on_fire callback ran game code
// mid-session-pump, the one reentrancy hole in the subsystem.
fire_listen :: proc(fr: ^Fire_Route, s: ^ksess.Session, tag: u8 = FIRE_TAG) {
	fr^ = Fire_Route{ses = s}
	ksess.session_app_route(s, tag, fr, fire_handle)
}

// Drain one announced fire (call until ok=false each frame, then draw).
fire_poll :: proc(fr: ^Fire_Route) -> (f: Fire, ok: bool) {
	return ksess.appq_poll(&fr.fires)
}

fire_route_destroy :: proc(fr: ^Fire_Route) {
	ksess.appq_destroy(&fr.fires)
	fr^ = {}
}

@(private = "file")
fire_handle :: proc(user: rawptr, from: knet.Player_Id, from_peer: ksess.Peer_Id, r: ^knet.Reader) {
	fr := cast(^Fire_Route)user
	if fr.ses.is_host || from_peer != ksess.HOST_PEER {return}
	f, ok := fire_read(r)
	if !ok || f.shooter == fr.ses.me {return}
	ksess.appq_push(&fr.fires, f)
}

// ---- predicted hp: the impact you SAW, before the wire agrees ---------------------
//
// When your local rock visually contacts a body, the health you display may
// dip immediately — but the REPLICATED hp field is never touched (that is
// how phantom damage stays impossible). The dip lives in this overlay:
//
//     kcombat.php_note_hit(&sp.php, sp.hp, ROCK_DMG, now)   // at visual contact
//     shown := kcombat.php_display(&sp.php, sp.hp, now)     // wherever hp renders
//
// When the authoritative drop lands (a delta moves the real field), the
// overlay is CONSUMED — the displayed number doesn't move twice. If truth
// never confirms it (the host saw a miss), the overlay expires and the bar
// heals back: wrong for a heartbeat, honest forever after. Overlay dips
// never kill — clamp to 1 while the real hp is positive, so corpses appear
// only on truth.

Predicted_Hp :: struct {
	pending: i32, // damage shown locally but not yet confirmed by a delta
	basis:   i32, // the authoritative hp when the overlay was last squared
	expires: f64, // heal-back deadline (seconds, caller's clock)
}

PHP_TTL :: 0.6 // seconds a dip may outrun truth (a generous round trip)

php_note_hit :: proc "contextless" (ph: ^Predicted_Hp, hp_now: i32, amount: i32, now: f64) {
	if ph.pending == 0 {
		ph.basis = hp_now
	}
	ph.pending += amount
	ph.expires = now + PHP_TTL
}

// The number to DRAW. Consumes the overlay as authoritative drops arrive;
// expires it when truth never came.
php_display :: proc "contextless" (ph: ^Predicted_Hp, hp_now: i32, now: f64) -> i32 {
	if ph.pending > 0 {
		if now >= ph.expires {
			ph.pending = 0 // the host never agreed: heal back
		} else if consumed := ph.basis - hp_now; consumed > 0 {
			ph.pending = max(0, ph.pending - consumed) // truth landed: don't dip twice
			ph.basis = hp_now
		}
	}
	shown := max(0, hp_now - ph.pending)
	if hp_now > 0 {
		shown = max(shown, 1) // predictions wound; only truth kills
	}
	return shown
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
