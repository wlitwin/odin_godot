# 5 · The two timelines

Picture a co-op game with a powerup gem on the course. When the host's ball
rolls over it, the gem disappears too early for clients. When a client's ball
rolls over it, the gem disappears too late.

Nothing is out of sync. Every machine agrees on the state, promptly. The game
still looks wrong on every screen but the picker-upper's: the gem vanishes
while the rolling ball is still visibly half a meter away, or lingers after
the ball has visibly rolled through it.

This is a mental-model shift, and it isn't about the toolkit — it's about
physics. **Your screen and a remote screen do not show the same moment.**
Once you stop fighting that, one small discipline fixes every "the effect
fired at the wrong time" bug.

## Why remote motion renders behind

Owner-streamed motion (post 3) is rendered by everyone else through a short
interpolation buffer — a few ticks of samples, so jitter and dropped packets
smooth out instead of stuttering. A remote ball you're watching is rendered
~100ms behind where its owner's machine says it is. Call these the two
timelines:

- **State time** — replicated fields, arriving as fast as the wire allows.
  The gem's `taken` byte flips *now*.
- **Render time** — where remote *motion* is drawn: interp-delay in the
  past. The ball *reaches* the gem on your screen 100ms from now.

That explains the symptom. The gem's disappearance was keyed to state time;
the cause you can *see* — the ball rolling into it — plays out in render
time. React to the state delta and the effect precedes its visible cause. No
amount of "better netcode" fixes it, because nothing is broken. The state was
never wrong; it was *early*.

The picker-upper's own screen is different again: their prediction ran the
pickup *this frame*, in local time, and it stays that way — that instant
local response is the point of prediction (post 4).

## The rule

One rule covers it: **present a consequence on the timeline of its visible
cause.**

The toolkit gives this a primitive. Instead of showing an effect where you
detect the state change, hand it to the session with one honest boolean —
*was this my own simulation's doing?*

```odin
// The taken-edge, ONE place, identical on every peer:
ksess.session_present(&self.ses,
	p.net_id == self.my_claim,   // mine? show it NOW (my sim touched it)
	self, present_gem_gone, p.net_id, u64(p.kind))
```

If it's mine, the callback runs this frame. If not, the session queues it for
`interp_delay` from now — the moment *your screen's* rendition of the cause
catches up. Transit time cancels out; the gem vanishes as the rolled ball
touches it, on every screen, and `present_gem_gone` neither knows nor cares
which timing path it took. One presentation proc, every peer, every case.

The instinct carried over from GDScript — hide the gem in the setter, the
moment the value changes — is exactly the bug. State changes are facts;
showings are scheduled.

## What delays and what doesn't

The rule is "timeline of the visible cause," not "delay everything." The full
catalog lives in [kit/net](../kit/net.md):

| The consequence of… | …presents |
| --- | --- |
| my own sim / my prediction | **now** — responsiveness is sacred |
| a remote *moving* cause (ball hits gem, avatar steps on plate) | at **render time** — `session_present` |
| no spatial cause at all (score, hp bar, chat, UI) | **wire-fresh, never delayed** — delaying truth with no visible cause is just lag you added |
| a per-peer local flourish (muzzle flash, footsteps) | from local fx hooks — it never rode the wire at all |
| a global transition (level change, round end) | after a **dwell** — see below |

The third row bites people who over-learn the lesson: your scoreboard should
never wait for a render clock. Delay is a tool for *reconciling an effect with
its visible cause*; where there's no cause on screen, fresh truth wins.

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
send it as an explicit message — don't pulse a field.

## Put effects in the presentation proc, not the command

Presentation code belongs in the presentation proc, never in a command proc.
Commands run on the claimer and the host (post 4), so an effect spawned inside
a command proc — say, a pickup particle burst inside the `powerup_claim`
command proc — never reaches observers at all, and reconciliation re-runs can
spawn it twice.

Spawn the burst inside `present_gem_gone` instead: post 4's hook and this
post's scheduling deliver it to every peer, exactly once, at each screen's
correct moment. When you find yourself asking *"where do I put the juice?"*,
the answer is always in the presentation proc, next to the state edge it
decorates.

That completes the model. State that converges (post 3), verbs that predict
(post 4), and showings that respect the render clock (this post). What remains
is the encouraging part: seeing how far those three ideas carry a real,
shippable game — and what the toolkit hands you at the finish line.

*Next: [The shape of a shippable game →](06-the-shape-of-a-shippable-game.md)*
