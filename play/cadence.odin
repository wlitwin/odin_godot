package play

// play/cadence — the DELTA-TIME cousins of play/pace. Pace deadlines compare against a
// clock you already have (net tick, monotonic seconds); these two carry their own tiny
// state and eat per-frame `delta` directly — the shapes every `_process` hand-rolls:
//
//   * a dedicated `f32` accumulator + subtract/compare/reset (ten near-identical sites
//     across the examples: spawn cadence, fire cooldown, drip timers), and
//   * a dedicated `bool` checked every frame forever to catch ONE first arrival (a
//     replicated field's first nonzero value, a one-shot scene reaction).
//
// Both are plain value state — struct fields in host/entity scratch, never wire state
// (the play/edge discipline).

// every accumulates `dt` and fires once per `period`, carrying the remainder so a long
// frame doesn't drop time (a 2×period frame fires this call and again next call, not
// twice silently). The recurring-action one-liner:
//
//	if play.every(&self.spawn_acc, f32(delta), self.rate) { spawn_one(self) }
//
// The remainder carry makes it a fixed-CADENCE timer; for a cooldown that must NOT
// burst after a stall, use play.ready with a real clock (see play/pace's header).
every :: proc "contextless" (acc: ^f32, dt, period: f32) -> bool {
	if period <= 0 {return false}
	acc^ += dt
	if acc^ < period {return false}
	acc^ -= period
	return true
}

// latch fires exactly ONCE: the first call where `cond` is true. The stored bool is the
// "already fired" memory the games kept as a hand-named field + guard pair:
//
//	if play.latch(&self.painted, self.color != 0) { apply_team_color(self) }
latch :: proc "contextless" (fired: ^bool, cond: bool) -> bool {
	if fired^ || !cond {return false}
	fired^ = true
	return true
}
