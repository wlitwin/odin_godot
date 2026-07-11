package play

// play/fsm — a state machine that OWNS its current state.
//
// The machine carries its state directly (`cur`, a replicated field) plus a local
// edge shadow — you embed ONE field on your entity and drive it through set/step.
// You never hand-wire a parallel shadow or keep the state as a separate flat field:
//
//   Runner :: struct {
//       gun: play.Machine(Gun_State),   // gun.cur replicates; gun.shadow stays local
//       ...
//   }
//   Gun_State :: enum u8 { Ready, Reload, Jam }
//
// This is possible because scriptgen recurses into nested structs — including
// generic instantiations — so embedding `play.Machine(S)` replicates its inner
// `cur` like any flat field (the local `shadow` is untagged, so it never crosses
// the wire). Before scriptgen learned nesting the state HAD to live outside the
// machine with the shadow wired up separately; that indirection is gone. The
// abstraction now hides its own mechanism, which is the point — the cost of the old
// rule was mental overhead, and overhead is worse than the "magic" it avoided.
//
// The kit contract holds, now INSIDE the abstraction:
//   HOST writes the transition (the only side that may):
//     if play.set(&r.gun, .Reload) { play.arm(&reload_pace, now + RELOAD_T) }
//   EVERY PEER reads the change and runs the SAME enter/exit locally, no RPC:
//     from, to, moved := play.step(&r.gun)
//     if moved {
//         #partial switch from { case .Reload: stop_reload_anim() }   // on_exit
//         #partial switch to   { case .Jam:    spark(); banner("JAM") // on_enter
//                                case .Ready:  click() }
//     }
//
// The host sees its own `set` land; each client sees replication deliver `cur`; both
// drive `step`, so enter/exit fire identically on every screen. `cur` is a plain
// field — read it directly (`r.gun.cur`). State is host-authoritative by
// construction (plain `replicate`); an owner-authored machine is a different animal
// and would not use this. The composition is the point: STATE is a Machine, each
// state's DWELL is a play.Pace, the once-on-entry cues are play.Edge underneath. A
// library you call, not a framework you live inside.
//
// THE MATCH-PHASE SINGLETON is just this at game scope: a Machine on your world /
// session singleton entity, replicating the run's global phase (lobby → playing →
// over, or waves, or day/night) to every screen. No separate primitive — scrapyard's
// World.stage IS a match-phase Machine, read by every system to gate what it does;
// per-phase timers ride a play.Pace beside it (scrapyard's over_at).
Machine :: struct($S: typeid) {
	cur:    S `gd:"replicate"`, // authoritative state — host writes via set, replicated to all peers
	shadow: Edge(S),            // local per-peer scratch — the edge step reads to fire enter/exit
}

// set writes the state — HOST ONLY — and returns whether it changed, so the caller
// can gate the once-per-transition work (start a timer, bank a reward, play a cue).
// `play.set(&r.gun, .Jam)`.
set :: proc(m: ^Machine($S), to: S) -> (changed: bool) {
	changed = m.cur != to
	m.cur = to
	return changed
}

// step reports the transition since the last step: the state we LEFT, the state we
// are in NOW, and whether it moved. Call it every frame on host and client alike and
// branch on (from, to) for exit/enter side effects — the host observes its own set,
// each client observes the replicated `cur`, so the hooks fire on every screen with
// no coordination.
step :: proc(m: ^Machine($S)) -> (from, to: S, moved: bool) {
	from, moved = see(&m.shadow, m.cur)
	return from, m.cur, moved
}
