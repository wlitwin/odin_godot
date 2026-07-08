package play

// play/fsm — a state machine whose current state lives ON THE WIRE.
//
// The kit rule a networked FSM must obey, and the reason a naive one is a footgun:
// the authoritative state has to be a flat, replicated field the HOST owns. If you
// tuck the state INSIDE the machine struct, scriptgen never sees it (it reads tags
// off a struct's direct fields, not through a nested value), so it never replicates
// — and you have built a state machine that silently diverges per client. So the
// Machine here deliberately does NOT store the state. It holds only a local edge
// SHADOW (built on play/edge — an FSM is Edge + intent), and every call operates on
// YOUR external replicated field:
//
//   Runner :: struct {
//       gun_state: u8 `gd:"replicate"`,   // <- authoritative, flat, host-owned
//       ...
//   }
//   Gun_View :: struct { fsm: play.Machine(u8) }   // <- local shadow, off the wire
//
// The kit contract falls out as two calls with a clean split:
//
//   HOST writes the transition (the only side that may):
//     if play.set(&r.gun_state, GUN_RELOAD) { play.arm(&reload_pace, now + RELOAD_T) }
//
//   EVERY PEER reads the change and runs the SAME enter/exit locally — no RPC, no
//   host-authored events; presentation stays a pure function of replicated state:
//     from, to, moved := play.step(&view.fsm, r.gun_state)
//     if moved {
//         switch from { case GUN_RELOAD: stop_reload_anim() }   // on_exit
//         switch to   { case GUN_JAM:    spark(); banner("JAM") // on_enter
//                       case GUN_READY:  click() }
//     }
//
// The host sees its own `set` land; each client sees replication deliver it; both
// drive `step` with the same field, so enter/exit fire identically on every screen.
// The composition with the other primitives is the whole point: the STATE is an
// fsm.Machine, each state's DWELL is a play.Pace, and the once-on-entry cues are
// play.Edge underneath. Reload/jam/fire, phase machines, run stages — all this shape.
//
// The transition LOGIC stays ordinary code (a switch reading your world) — the
// Machine guarantees the enter/exit hooks fire exactly once per change; it does not
// take over your control flow. A library you call, not a framework you live inside.
Machine :: struct($S: typeid) {
	shadow: Edge(S),
}

// step reports the transition seen since the last step: the state we LEFT, the
// state we are in NOW, and whether it moved. Drive it every frame with your
// replicated field and branch on (from, to) for exit/enter side effects. Call it on
// host and client alike — the host observes its own writes, each client observes the
// replicated change — so the hooks fire on every screen with no coordination.
step :: proc(m: ^Machine($S), cur: S) -> (from, to: S, moved: bool) {
	from, moved = see(&m.shadow, cur)
	return from, cur, moved
}

// set writes the authoritative state — HOST ONLY — and returns whether it changed.
// `cur` is your replicated field: `play.set(&w.stage, STAGE_CLEAR)`. Pure sugar over
// `cur^ = to`, but it is the single greppable transition site and its `changed`
// return gates the once-per-transition work (start a timer, bank a reward).
set :: proc(cur: ^$S, to: S) -> (changed: bool) {
	changed = cur^ != to
	cur^ = to
	return changed
}
