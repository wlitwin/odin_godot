package play

// play/telegraph — a WIND-UP THAT LANDS: the "get out of the circle" shape. The host starts a
// countdown every screen can watch grow (a warning ring, a charging beam, a shockwave shadow),
// and when it expires the payload lands — on the host as sim, on every peer as an eruption cue,
// all in lockstep off the same replicated ticks.
//
//   Mob :: struct { ... tele: play.Telegraph, ... }
//
// Verb-free, like play.Health: a telegraph is HOST-DRIVEN drama (an AI wind-up, a trap arming —
// never a client intent), so nothing composes onto the command table. What composes is the state
// — `left` AND `wind` both replicate, so every peer computes the exact growth fraction even when
// the wind VARIES (an enraged boss winding up in half the time: hardcoding the nominal wind in
// presentation draws that ring half-grown from the start — replicating the denominator is the
// point).
//
// THE LANDING is the game's edge half on `left`, generated — declare it on the embedding
// entity and ask telegraph_landed whether THIS change is the eruption (it holds the cancel
// contract; a late joiner's first sight seeds silently, so no phantom landing exists):
//
//   mob_tele_left_edge :: proc(g: ^Game, self: ^Mob, old, new: u16) {
//       if play.telegraph_landed(&self.tele, old, new) { erupt(g, self) }
//   }
//
// WHAT STAYS YOURS: the GEOMETRY and the PAYLOAD. A ring, a line, a cone — and what the landing
// does (an AoE, a projectile barrage, a door slamming) — are the game's; the block owns only the
// clock, its broadcast, and the landing test. Root-while-winding (the boss stands still) is your
// brain's policy around telegraph_active.

Telegraph :: struct {
	left: u16 `gd:"replicate"`, // ticks until it lands (0 = idle) — every screen's countdown
	wind: u16 `gd:"replicate"`, // the full wind THIS telegraph started with — frac's denominator
}

// telegraph_start — host: begin a wind-up of `wind` ticks. Every screen sees it grow from zero
// (frac uses this start's own wind, so a hastened wind-up still reads 0 -> 1).
telegraph_start :: proc(t: ^Telegraph, wind: u16) {
	t.wind = wind
	t.left = wind
}

// telegraph_tick — host, once per net tick while active: count down. Returns true exactly ON the
// landing tick — run the payload (the AoE, the barrage) right there. No-op when idle.
telegraph_tick :: proc(t: ^Telegraph) -> (landed: bool) {
	if t.left == 0 {return false}
	t.left -= 1
	return t.left == 0
}

// telegraph_cancel — host: abort a wind-up (the boss died, the trap disarmed). Zeroing `wind`
// too is what keeps every peer's telegraph_step QUIET — a cancel must never present as a landing.
telegraph_cancel :: proc(t: ^Telegraph) {
	t.left = 0
	t.wind = 0
}

// telegraph_active / telegraph_frac — the presentation reads: is it winding, and how grown
// (0 at the start, 1 as it lands). Drive the ring's scale off frac; gate its visibility on active.
telegraph_active :: proc "contextless" (t: ^Telegraph) -> bool {
	return t.left > 0
}
telegraph_frac :: proc "contextless" (t: ^Telegraph) -> f32 {
	return t.wind > 0 ? 1 - f32(t.left) / f32(t.wind) : 0
}

// telegraph_landed — the landing test for the game's `<entity>_tele_left_edge` half: did THIS
// net change land the wind-up? Holds the cancel contract — telegraph_cancel zeroes `wind` in
// the same host mutation, so the delta that drops `left` to 0 arrives with `wind` already 0
// and stays quiet; a real landing arrives with the wind still stamped. (First sight seeds the
// edge silently, so a late joiner who never saw the wind-up gets no phantom eruption — that
// used to be this block's own shadow + sync ritual; the kit's edge halves absorbed it.)
telegraph_landed :: proc "contextless" (t: ^Telegraph, old_left, new_left: u16) -> bool {
	return old_left > 0 && new_left == 0 && t.wind > 0
}
