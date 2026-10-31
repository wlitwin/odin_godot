# 5 · The two timelines

In a cooperative game, a gem can disappear before a remote ball visibly
reaches it, or remain visible after the local player's ball has passed it.

Replicated state can be correct while presentation looks wrong to observers: the gem vanishes
while the rolling ball is still visibly half a meter away, or lingers after
the ball has visibly rolled through it.

Local prediction and remote interpolation display different moments. Schedule
a spatial effect on the same timeline as its visible cause.

## Why remote motion renders behind

Owner-streamed motion (post 3) is rendered by everyone else through a short
interpolation buffer containing a few ticks of samples. This absorbs some
jitter and packet loss. A remote ball you're watching is rendered
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

The collecting player's screen uses local prediction. It can show the pickup
in the frame when the command runs, before the authority result arrives,
as described in post 4.

<a id="the-rule"></a>

## Scheduling spatial effects

When a state change has a moving visible cause, schedule its effect on that
cause's presentation clock. Pass a callback to the session and indicate
whether the cause came from local simulation:

```odin
// Schedule from the taken-edge on each peer:
ksess.session_present(&self.ses,
	p.net_id == self.my_claim,   // local simulation caused the pickup
	self, present_gem_gone, p.net_id, u64(p.kind))
```

For a local cause, the callback runs this frame. Otherwise, the session queues
it for `interp_delay` from now to align with the delayed owner stream. Both
paths call `present_gem_gone`, so the presentation procedure can show the same
effect without choosing the clock itself. This helper assumes the remote
cause is rendered through Kit's interpolated stream; a game-rendered cause
must use its own clock, as explained in [kit/net](../kit/net.md).

Hiding the gem in a field setter ties presentation to packet arrival. Keep
the state update immediate and schedule the visible disappearance separately.

<a id="what-delays-and-what-doesnt"></a>

## Presentation timing by cause

Use the cause to choose which effects need delayed presentation. The full
reference is in [kit/net](../kit/net.md):

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

<a id="edges-must-outlive-the-slowest-observer"></a>

## Holding state for delayed observers

When the ball drops in the cup, puttputt holds the sunk ball there for a
couple of seconds before building the next hole:

```odin
SINK_DWELL :: 2.5
```

Remote screens display the roll up to interp-delay late. If the host advanced
the hole as soon as its ball sank, an observer could see the world change
while the displayed ball was still approaching the cup. Hold the completed
state long enough for the most delayed observer to display it before moving
to the next hole.

Deltas send the value present at a network tick. A flag turned on and off
within that tick may equal its shadow when compared, so no change is sent.
Retain the changed value long enough for replication and presentation, or
send a momentary occurrence as an explicit message.

<a id="put-effects-in-the-presentation-proc-not-the-command"></a>

## Presentation callbacks

Presentation code belongs in the presentation proc, never in a command proc.
Commands run on the claimer and the host (post 4), so an effect spawned inside
a command proc (say, a pickup particle burst inside the `powerup_claim`
command proc) never reaches observers at all, and reconciliation re-runs can
spawn it twice.

Spawn the burst inside `present_gem_gone`. React to the replicated pickup
state and schedule that callback for the appropriate display time. Field
edges report the net change per frame; if individual occurrences or their
counts matter, use a declared presentation event. Keep particles, sounds, and
other visible consequences in the presentation callback.

The first three pieces now fit together: replicated state (post 3), predicted
commands (post 4), and effects scheduled for each screen's presentation clock.
The next post adds persistent identity, recovery, and deployment checks.

*Next: [Identity, recovery, and transport testing →](06-the-shape-of-a-shippable-game.md)*
