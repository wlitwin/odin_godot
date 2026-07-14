package play_sim

// play/sim/cool — the predicted cooldown: play.Pace's twin, one timeline over.
//
// Same three verbs (due / arm / ready), the OTHER clock. Where play.Pace
// stores a deadline against a clock you pass in (host scratch — never on the
// wire), Cool stores the ticks LEFT and counts itself down inside the sim:
// its block tick decrements on the server, on your predicting screen, and in
// every replay, identically. Embed a field and the cadence answers the click
// at any latency — a revolver's fan, a kick's recovery, a dash's recharge:
//
//   Gunner :: struct {
//       ...
//       fire: psim.Cool, // fire.left joins the predict set through the embed
//   }
//
//   // in the entity's @(gd_tick):
//   if input.buttons & BTN_FIRE != 0 && psim.ready(&self.fire, FIRE_CD) {
//       fired = true
//   }
//
// The entity's own tick runs FIRST, the block's decrement after — so a
// `ready` at tick T re-arms to `interval` and the next fire lands at exactly
// T + interval, the same period the hand-rolled decrement-then-check gave.
// Twin-noun rule of thumb: pacing something only the host cares about, on a
// wall clock or the host tick? play.Pace. Gating something the player FEELS,
// that must answer locally and replay exactly? psim.Cool.

Cool :: struct {
	left: u16 `gd:"replicate,predict"`, // ticks until due — the predicted countdown
}

// The block tick: count down, never below zero. Inputless by contract —
// intent (the arming) flows through the verbs the wielder's tick calls.
@(gd_tick)
cool_tick :: proc(c: ^Cool) {
	if c.left > 0 {
		c.left -= 1
	}
}

// due reports whether the countdown has run out. Cheap and pure — safe in a
// compound guard; pair with `arm` when the interval depends on state you
// read after the check.
due :: proc(c: ^Cool) -> bool {
	return c.left == 0
}

// arm starts a countdown of `ticks` (a cooldown, a wind-up, a kickoff hold).
arm :: proc(c: ^Cool, ticks: u16) {
	c.left = ticks
}

// ready is the recurring-cooldown one-liner: if due, re-arm to `interval`
// and return true (fire this tick); otherwise false. Short-circuits cleanly
// as a guard's LAST clause — it re-arms only when everything before it held.
ready :: proc(c: ^Cool, interval: u16) -> bool {
	if c.left > 0 {
		return false
	}
	c.left = interval
	return true
}
