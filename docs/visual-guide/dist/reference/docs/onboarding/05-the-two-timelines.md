# 5 · The two timelines

Picture a co-op game with a powerup gem on the course. When the host's ball
rolls over it, the gem disappears too early for clients. When a client's ball
rolls over it, the gem disappears too late.

Replicated state can be correct while presentation looks wrong to observers: the gem vanishes
while the rolling ball is still visibly half a meter away, or lingers after
the ball has visibly rolled through it.

**Local prediction and remote interpolation display different moments.**
Schedule a spatial effect on the same timeline as its visible cause.

## Why remote motion renders behind

Owner-streamed motion (post 3) is rendered by everyone else through a short
interpolation buffer (a few ticks of samples), so jitter and dropped packets
smooth out instead of stuttering. A remote ball you're watching is rendered
~100ms behind where its owner's machine says it is. Call these the two
timelines:

- **State time** is for replicated fields, which arrive as fast as the wire
  allows. The gem's `taken` byte flips *now*.
- **Render time** is where remote *motion* is drawn, at interp-delay in the
  past. The ball *reaches* the gem on your screen 100ms from now.

That explains the symptom. The gem's disappearance was keyed to state time;
the cause you can *see* (the ball rolling into it) plays out in render
time. Reacting immediately to the state delta makes the effect precede its
visible cause. Changing packet delivery alone does not align those clocks.

The picker-upper's own screen is different again: their prediction ran the
pickup *this frame*, in local time, and it stays that way. That instant
local response is the point of prediction (post 4).

## The rule

One rule covers it: **present a consequence on the timeline of its visible
cause.**

The toolkit gives this a primitive. Instead of showing an effect where you
detect the state change, pass a callback to the session and indicate whether
the cause came from the local simulation:

```odin
// The taken-edge, ONE place, identical on every peer:
ksess.session_present(&self.ses,
	p.net_id == self.my_claim,   // mine? show it NOW (my sim touched it)
	self, present_gem_gone, p.net_id, u64(p.kind))
```

If it's mine, the callback runs this frame. If not, the session queues it for
`interp_delay` from now, the moment *your screen's* rendition of the cause
catches up. Transit time cancels out; the gem vanishes as the rolled ball
touches it, on every screen, and `present_gem_gone` neither knows nor cares
which timing path it took. The same presentation proc handles every peer and
every case.

Hiding the gem in a field setter ties presentation to packet arrival. Keep
the state update immediate and schedule the visible disappearance separately.

## What delays and what doesn't

The rule is "timeline of the visible cause," not "delay everything." The full
catalog lives in [kit/net](../kit/net.md):

| The consequence of… | …presents |
| --- | --- |
| my own simulation / my prediction | **now**, with local input |
| a remote *moving* cause (ball hits gem, avatar steps on plate) | at **render time** (`session_present`) |
| no spatial cause at all (score, hp bar, chat, UI) | when the authoritative update arrives |
| a per-peer local flourish (muzzle flash, footsteps) | from local fx hooks (it never rode the wire at all) |
| a global transition (level change, round end) | after a **dwell** (see below) |

A scoreboard has no spatial cause to align with a moving object, so update
it when state arrives. Reserve the render delay for effects that need that
spatial alignment.

## Edges must outlive the slowest observer

When the ball drops in the cup, puttputt holds the sunk ball there for a
couple of seconds before building the next hole:

```odin
SINK_DWELL :: 2.5
```

This dwell is for the observers. Every remote screen is watching the roll up
to interp-delay late; if the host advanced the hole the instant *its* copy
sank, half the room would see the world change while their rendition of the
ball was still rolling toward the cup. A shared moment must stay on screen
long enough for the *slowest* view of it to arrive and be seen.

One corollary: **deltas carry state, not events.** A flag you flip on and off
within one tick may never ship at all (the diff sees no change). If something
is genuinely momentary, either let the edge live long enough to be seen, or
send it as an explicit message: don't pulse a field.

## Put effects in the presentation proc, not the command

Presentation code belongs in the presentation proc, never in a command proc.
Commands run on the claimer and the host (post 4), so an effect spawned inside
a command proc (say, a pickup particle burst inside the `powerup_claim`
command proc) never reaches observers at all, and reconciliation re-runs can
spawn it twice.

Spawn the burst inside `present_gem_gone` instead: post 4's hook and this
post's scheduling deliver it to every peer, exactly once, at each screen's
correct moment. Keep particles, sounds, and other visible consequences beside
the presentation callback for the state change.

The first three pieces now fit together: replicated state (post 3), predicted
commands (post 4), and effects scheduled for each screen's presentation clock.
The next post adds persistent identity, recovery, and deployment checks.

*Next: [The shape of a shippable game →](06-the-shape-of-a-shippable-game.md)*
