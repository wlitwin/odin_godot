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
// AND THEY STAY HERE. Splitting the session-coupled half into its own package
// (the way kit/fx's tracers went) was weighed and REFUSED: the tracers are a
// VISUAL half, a genuinely separate concern, while the Fire half is a WIRE
// half serving the very math it sits beside. Two facts settle it. fire_announce
// takes a bare ^ksess.Session so the authority can announce without holding a
// listener — cavecrawl calls it exactly that way — and Fire.shooter is a public
// payload field games read, which is why the fire lane deliberately did NOT
// ride kit/session's host_relay when that primitive absorbed comms and xfer:
// the relay's stamp would duplicate a field the game already owns. That is a
// deliberately game-facing surface, not a layering violation hiding in a
// header, and a package holding one struct and two procs would be inventory.
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
// clamp, generic over the game's hp integer (play.Health's i32, a raw i32
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

// The status EDGE helpers — for the `<entity>_fx_edge(old, new: [N]Effect)`
// half: a tagged fixed array is ONE diff atom (kit/net/edge.odin), so the
// generated half hands you the whole old/new array once per net change, and
// "the slime just LANDED" is a question about the pair — present in `new`,
// absent in `old` — not a shadow bool kept beside the entity with its own
// first-sight/resync rules. landed = the kind appeared; faded = it left.
// (A same-kind REFRESH — power/clock bumped while already present — is
// neither: the half still fires, both read false; compare the rows yourself
// for a re-apply cue.)
effects_landed :: proc "contextless" (old, new: []Effect, kind: u8) -> bool {
	_, was := effect_of(old, kind)
	_, is := effect_of(new, kind)
	return is && !was
}

effects_faded :: proc "contextless" (old, new: []Effect, kind: u8) -> bool {
	_, was := effect_of(old, kind)
	_, is := effect_of(new, kind)
	return was && !is
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
	shooter: knet.Player_Id, // WHO CAUSED IT — always honest: the echo skip
	                         // reads `predicted`, so a host-authored instant
	                         // (a nova, a reaction) keeps its real causer
	origin:  [3]f32,
	vel:     [3]f32, // per tick. A no-flight kind (a ring, a zone flash) may
	                 // reuse these spatial slots for spatial payload (a radius,
	                 // an offset) — vel is genuinely unused there. IDS do not
	                 // ride here: an ability/status id packed into vel.z works
	                 // only in 2D — that is what `arg` is for.
	ttl:     u16,
	kind:    u8, // game-defined (which ability/visual)
	arg:     u16, // the game's payload word beside `kind` — an ability id, a
	              // status id, a variant — instead of a float-packed vel lane
	// The shooter's OWN screen already drew this at cast time (a predicted
	// cast, a client-side tracer): its echo is skipped, everyone else draws.
	// False = nobody has drawn it yet — EVERY screen draws from the lane, the
	// causer's included (host-authored instants stopped spoofing `shooter`
	// to reach the caster's screen the day this bit existed).
	predicted: bool,
}

fire_write :: proc(w: ^knet.Writer, f: Fire) {
	knet.write_player_id(w, f.shooter)
	for i in 0 ..< 3 {knet.write_f32(w, f.origin[i])}
	for i in 0 ..< 3 {knet.write_f32(w, f.vel[i])}
	knet.write_u16(w, f.ttl)
	knet.write_u8(w, f.kind)
	knet.write_u16(w, f.arg)
	knet.write_bool(w, f.predicted)
}

fire_read :: proc(r: ^knet.Reader) -> (f: Fire, ok: bool) {
	f.shooter = knet.read_player_id(r)
	for i in 0 ..< 3 {f.origin[i] = knet.read_f32(r)}
	for i in 0 ..< 3 {f.vel[i] = knet.read_f32(r)}
	f.ttl = knet.read_u16(r)
	f.kind = knet.read_u8(r)
	f.arg = knet.read_u16(r)
	f.predicted = knet.read_bool(r)
	return f, !r.err
}

// The fire lane's own wire revision — folded into the session fingerprint at
// load (the shift is this package's lane; sim 16, netgd 24). A Fire wire
// change bumps THIS constant in the same commit.
WIRE_REV :: u64(2) // 1: the first Fire wire · 2: Fire carries arg (u16) + predicted (bool)

@(init, private = "file")
register_wire_rev :: proc "contextless" () {
	ksess.session_register_wire_rev(WIRE_REV, 32)
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
	// THE LOOPBACK: the broadcast is wire-only, so the host's own screen used
	// to be the one place the lane didn't reach — every consumer hand-drew
	// other players' fires at the announce site (`if shooter != me
	// { draw }`) and its own at cast. The announcer's copy lands in its own
	// route's queue instead (the relay's echo pattern), under the SAME skip
	// rule every receiver applies — one drain draws on every screen.
	if user, handler := ksess.session_app_route_of(s, tag); handler == fire_handle && user != nil {
		fr := cast(^Fire_Route)user
		if !(f.predicted && f.shooter == s.me) {
			ksess.appq_push(&fr.fires, f)
		}
	}
}

// Announce a Fire to ONE peer instead of the room — the addressed half. A game
// catching a just-joined player up on a recent event sends only to them, instead
// of re-broadcasting to everyone and making every other screen dedupe the echo
// (which is the shape a game reaches for without this: a broadcast replay carries
// a game-level seq so existing screens can drop the double). `peer` is a joiner's
// ksess.Peer_Id, from the roster on Ev_Player_Joined.
//
// A caution that decides whether you want this at all: `fire_poll` DROPS a
// PREDICTED fire whose shooter is the receiver (they drew it live at cast
// time), so an addressed replay of one to the ORIGINAL caster — a reconnect
// reclaiming their id — is dropped too. That is correct for a TRANSIENT
// one-shot (they already saw it), and it is
// standing zone, a lingering glow, anything with a ttl that outlives its frame,
// should be an ENTITY. Entities replicate to a joiner through the world snapshot
// by construction — no replay, no dedupe, no shooter spoof, no reclaim hole. Use
// fire_announce_to for the tail of a transient a specific peer should still catch;
// use an entity for anything that stands.
fire_announce_to :: proc(s: ^ksess.Session, peer: ksess.Peer_Id, f: Fire, tag: u8 = FIRE_TAG) {
	assert(s.is_host, "fire_announce_to is the AUTHORITY's half — clients see fires through fire_poll, they never author them")
	w := ksess.session_app_begin(s, tag)
	fire_write(w, f)
	ksess.session_app_flush(s, peer)
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

// ...and every peer listens — the HOST INCLUDED, through the loopback in
// fire_announce. The guards each game used to hand-roll live here now: only
// the HOST authors fires (a spoofed peer announcement is dropped), and a
// PREDICTED fire skips its own shooter's echo (that screen drew at cast
// time). Everything else in the queue is "a fire this screen has not drawn
// yet — draw it": another player's rock on any screen, and a host-authored
// instant (a nova, a reaction — predicted=false) on EVERY screen, its
// causer's too, under its causer's honest name.
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
	if fr.ses.is_host || from_peer != ksess.HOST_PEER {return} // wire copies are for clients; the host's rides the loopback
	f, ok := fire_read(r)
	if !ok || (f.predicted && f.shooter == fr.ses.me) {return}
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
