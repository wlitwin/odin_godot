# Bounded motion between ticks

`Tick_Phase` tracks a render fraction against a specific simulation epoch,
presentation revision and retained head tick. `tick_phase` seeds from the fixed
clock's fraction when the head advances. If the head stays fixed, it advances
monotonically to one tick and then holds. A prediction stall cannot wrap the
visual back to zero when the caller's fixed clock consumes time without a
committed simulation tick.

Pass `live=false` to hold the current fraction. A newer epoch or changed revision
explicitly starts a new scope; a backward tick without that reset, an older epoch,
or a tick-rate change within a scope is rejected without mutation. Invalid times
and nonfinite fractions are also rejected. Clear the value when leaving for an
independent session.

Godot's `session_tick_phase(session, &phase, dt)` selects the current epoch/head,
client view-reset revision, clock fraction and rate. Observers seed each newly
received head at zero and advance from arrival time, because their local fixed
clock does not advance the observed simulation. It holds during fencing,
pauses and non-running client phases. Call it once after Session/Room frame work.
This helper does not step simulation or change the network presentation clock.

`linear_preview2(position, per_tick_step, fraction, stop=1)` returns a detached
position at most one tick ahead. The optional contact fraction bounds it further.
Invalid inputs return the source position and false. A game supplies any visual
contact query; previewing a contact never authorizes damage or an impact event.

Use this for short, predictable linear motion where a bounded preview is useful.
It is extrapolation, not interpolation or proof of the next authoritative frame.
Corrections can move the source pose, and this helper does not smooth them. Use
retained-frame sampling for views that require interpolation and explicit
correction smoothing when a game wants it.
