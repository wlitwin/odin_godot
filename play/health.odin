package play

// play/health — HIT POINTS as a drop-in block: hp + max replicated through the embed.
//
//   Runner :: struct { ... health: play.Health, ... }
//   Mob    :: struct { ... health: play.Health, ... }   // same block, any entity type
//
// THE FIRST VERB-FREE BLOCK. play.Gun/Ability/Channel each compose a command; Health composes
// NONE — damage is HOST-INTERNAL (a bite, a slug, a splash: consequences of the sim, never a
// client intent), so there is no client→host seam to generate. What composes is the STATE:
// every screen's HUD and gates read the same replicated hp/max. A block doesn't need verbs to
// be worth being a block.
//
// THE PRESENTATION EDGE IS THE GAME'S HALF, generated: declare the name-paired half on the
// embedding entity and the session's per-frame pass hands you the net change — a hit
// (new < old, the delta is the damage number), a death (new == 0), a revive (old == 0) —
// with first sight and resyncs seeding SILENTLY, so there is no birth guard and no
// resync re-baseline ritual to write:
//
//   mob_health_hp_edge :: proc(g: ^Game, self: ^Mob, old, new: u16) { ... }
//
// (This block used to carry its own shadow + health_step/health_sync — the kit's edge halves
// made that whole mechanism the framework's; a block never shadows a replicated field now.)
//
// WHAT STAYS YOURS: the MEANING. Who takes damage, what a death pays out (credit, loot, reaping),
// what a heal is allowed to do — game logic wrapped AROUND health_hurt/health_kill/health_heal.
// The fields are public; an odd policy (a revive that sets hp to a stake, a heal-to-base that
// ignores a raised max) is an honest direct write, host-side.
//
// The host writes (plain replicated fields); every peer reads. u16 spans a player's
// handful to a boss's hundreds.
//
// THE LAYERING (play is policy, kit is mechanism): the damage clamp and the heal clamp
// delegate to kcombat.hurt/heal — the same scalar core kcombat.hit wraps for raw-field
// games, so a block game and a bare-i32 game can never disagree on what a death is. The
// SEEN-before-confirmed overlay (dip the displayed hp at visual contact, reconcile when
// the wire agrees) is kit mechanism too: kcombat.Predicted_Hp — pair it with this block
// in the game's presentation half, never inside the replicated fields.

import kcombat "godot:kit/combat"

Health :: struct {
	hp:  u16 `gd:"replicate"`, // host-authoritative; 0 = dead/downed (what that MEANS is yours)
	max: u16 `gd:"replicate"`, // stamped by health_arm; replicated so every screen can draw a bar
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
	return kcombat.hurt(&h.hp, dmg)
}

// health_kill — host: drop to 0 outright (a self-destruct, a detonate combo, a dev cheat).
health_kill :: proc(h: ^Health) {
	h.hp = 0
}

// health_heal — host: restore `amount`, clamped to max. Reviving a corpse is a heal from 0 —
// gate "may this target be healed" yourself (that's policy).
health_heal :: proc(h: ^Health, amount: u16) {
	kcombat.heal(&h.hp, h.max, amount)
}

// health_dead / health_frac — the two reads every gate and bar wants, named. `hp`/`max` are
// public; these state the intent (frac guards an unarmed max).
health_dead :: proc "contextless" (h: ^Health) -> bool {
	return h.hp == 0
}
health_frac :: proc "contextless" (h: ^Health) -> f32 {
	return h.max > 0 ? f32(h.hp) / f32(h.max) : 0
}

