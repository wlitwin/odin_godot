package play

// play/health — HIT POINTS as a drop-in block: hp + max replicated through the embed, plus the
// per-peer damage EDGE every screen presents from (numbers, topples, revive pops).
//
//   Runner :: struct { ... health: play.Health, ... }
//   Mob    :: struct { ... health: play.Health, ... }   // same block, any entity type
//
// THE FIRST VERB-FREE BLOCK. play.Gun/Ability/Channel each compose a command; Health composes
// NONE — damage is HOST-INTERNAL (a bite, a slug, a splash: consequences of the sim, never a
// client intent), so there is no client→host seam to generate. What composes is the STATE (every
// screen's HUD and gates read the same replicated hp/max) and the presentation EDGE
// (health_step — the once-per-change hook, same peer-symmetric contract as play.Machine's step).
// A block doesn't need verbs to be worth being a block.
//
// WHAT STAYS YOURS: the MEANING. Who takes damage, what a death pays out (credit, loot, reaping),
// what a heal is allowed to do — game logic wrapped AROUND health_hurt/health_kill/health_heal.
// The fields are public; an odd policy (a revive that sets hp to a stake, a heal-to-base that
// ignores a raised max) is an honest direct write, host-side.
//
// The host writes (plain replicated fields); every peer reads and steps. u16 spans a player's
// handful to a boss's hundreds.

Health :: struct {
	hp:   u16 `gd:"replicate"`, // host-authoritative; 0 = dead/downed (what that MEANS is yours)
	max:  u16 `gd:"replicate"`, // stamped by health_arm; replicated so every screen can draw a bar
	seen: Edge(u16),            // per-peer scratch — health_step's shadow, never on the wire
}

// health_arm — host, at spawn / a max change (a plate part, a boss dialing its pool): stamp the
// max and fill to it. A max change that should NOT full-heal is a direct `h.max = ...` instead.
health_arm :: proc(h: ^Health, max: u16) {
	h.max = max
	h.hp = max
}

// health_hurt — host: take `dmg`, clamped. Returns what actually landed (`dealt`, for hit credit
// — 0 on a corpse) and whether THIS hit was the killing one (false on a corpse: a death edge
// fires once).
health_hurt :: proc(h: ^Health, dmg: u16) -> (dealt: u16, died: bool) {
	if h.hp == 0 {return 0, false}
	dealt = min(dmg, h.hp)
	h.hp -= dealt
	return dealt, h.hp == 0
}

// health_kill — host: drop to 0 outright (a self-destruct, a detonate combo, a dev cheat).
health_kill :: proc(h: ^Health) {
	h.hp = 0
}

// health_heal — host: restore `amount`, clamped to max. Reviving a corpse is a heal from 0 —
// gate "may this target be healed" yourself (that's policy).
health_heal :: proc(h: ^Health, amount: u16) {
	h.hp = min(h.hp + amount, h.max)
}

// health_dead / health_frac — the two reads every gate and bar wants, named. `hp`/`max` are
// public; these state the intent (frac guards an unarmed max).
health_dead :: proc "contextless" (h: ^Health) -> bool {
	return h.hp == 0
}
health_frac :: proc "contextless" (h: ^Health) -> f32 {
	return h.max > 0 ? f32(h.hp) / f32(h.max) : 0
}

// health_step — the presentation edge: call every frame on every peer and branch on (prev, cur)
// — prev > cur is a hit (the delta is the damage number), cur == 0 a death, prev == 0 && cur > 0
// a revive. A first sighting (prev == 0 at birth) is a BIRTH, not a hit — the caller's usual
// `if prev == 0 {continue}` applies, exactly as with a hand-rolled Edge.
health_step :: proc(h: ^Health) -> (prev, cur: u16, moved: bool) {
	prev, moved = see(&h.seen, h.hp)
	return prev, h.hp, moved
}

// health_sync — resync pre-pass: re-baseline the edge so a snapshot catch-up (late join,
// interest re-entry) doesn't present a wholesale hp jump as a fresh wound.
health_sync :: proc(h: ^Health) {
	sync(&h.seen, h.hp)
}
