package kit_combat

// trail — THE AUTHORITY'S LEDGER: where something was, a moment ago. The
// receive side of the kit already keeps this ring (the stream ring: where
// things were, AS SEEN); Trail is the authority-side twin (AS TRUE), indexed
// by tick. Lag-compensated hitscan judges a shot where the SHOOTER saw the
// target; a recall ability rewinds its owner; a death recap points backward.
//
//   Mob_Brain :: struct { hist: kcombat.Trail(30), ... }  // 30 ticks of truth
//   kcombat.trail_note(&m.brain.hist, tick, m.x, m.y)     // top of the host tick
//   if at, ok := kcombat.trail_read(&m.brain.hist, tick - rewind) { ... }
//
// Born in play/ and moved DOWN here when the arrow demanded it: play is
// replicated state + generated hooks, kit is mechanism, and a pure off-wire
// ring is mechanism — the coop lag-comp option lands beside it and could
// never have imported play to get it. play.Trail remains as the alias.
// Graduated from the recipes idiom by its second consumer (scrapyard's
// mender rewinds RUNNERS the same way the lance rewinds mobs). Each slot
// stores the tick that wrote it, so an unwritten or lapped slot reads
// ok=false instead of a sentinel value — a target younger than the window
// tests live, by the caller's choice, not by accident. Pure and off-wire:
// history is derived state; it must never replicate.

Trail :: struct($N: int) {
	at:   [N][2]f32,
	tick: [N]u64, // which tick wrote each slot (0 = never — tick 0 predates any note)
}

// trail_note — the owner of the truth, once per tick.
trail_note :: proc "contextless" (t: ^Trail($N), tick: u64, x, y: f32) {
	i := int(tick % u64(N))
	t.at[i] = {x, y}
	t.tick[i] = tick
}

// trail_read — the value AT `tick`, if the ledger still holds it. ok=false
// for a tick never written or already lapped by the ring.
trail_read :: proc "contextless" (t: ^Trail($N), tick: u64) -> (at: [2]f32, ok: bool) {
	i := int(tick % u64(N))
	return t.at[i], t.tick[i] == tick && tick != 0
}
