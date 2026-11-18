# Present frames and effects

Read copied simulation frames to place Godot nodes, and consume occurrence
changes to manage effects. Keep both operations outside the replayed step.
This guide assumes the [Session starter](godot.md).

## Draw the selected frame

Call `session_frame`, then drain changes and read `session_state`. The returned
state supplies values to display; changing a node transform does not change
the World. Keep device sampling before the frame call and rendering after it.

For interpolation, historical views, and custom scheduling, use
[`replay/view`](https://github.com/wlitwin/odin_godot/blob/main/replay/view/README.md).
Choose the display time deliberately: predicted local state and confirmed
remote observations may use different times.

## Give gameplay results identities

A step emits an occurrence for a semantic event such as a shot or pickup. Its
identity must let presentation recognize the same event after replay. Use stable
entity/generation and action identity; avoid native pointers or a fresh random
ID on each execution.

The Loot model uses player identity and the control sequence to identify its
pickup and fire events. See the complete
[step procedure](https://github.com/wlitwin/odin_godot/blob/main/examples/replay_loot/game/game.odin).

## Handle changes

| Change | Presentation action |
| --- | --- |
| Begin | Create an effect and retain its handle under the occurrence ID |
| Update | Revise that effect's payload, location, or timing |
| Confirm | Settle an effect whose result is now accepted |
| Cancel | Stop or remove an effect that disappeared during correction |

An unchanged occurrence should keep its existing effect. Playing a new sound
every time a tick is replayed produces duplicates. Once heard, a sound cannot
be removed from the listener's past; decide whether a particular effect can
play speculatively or should wait for confirmation.

## Add a pickup flash and sound

The packaged starter already includes this recipe in `scripts/effects.odin`.
Taking the coin emits the existing gameplay event; the simulation never loads a
scene or plays audio. Two typed routes consume that event:

- `Effect_Route2` projects the pickup into a colored flash at the coin. Its
  `animate` callback expands, raises, and fades the flash over 0.45 seconds.
  The default `Journal` policy shows it when the journal delivers the event.
- `Audio_Route` projects the same pickup into `effects/pickup.wav`. Its
  `Confirmed` policy waits for acceptance, because cancellation cannot undo
  sound already heard. This nonspatial cue uses two screen voices and no world
  voices.

To replace the effect, edit `effects/pickup.tscn`, the visual projection and
animation, or the audio cue's stream, pitch, and gain. For a moving pickup,
include its position in the event instead of using the starter's fixed coin
position. Keep event identity and the change loop intact:

```odin
for change in changes {
    scene.effect_route_change(&fx.flash, change)
    scene.audio_route_change(&fx.sound, change)
}
scene.effect_route_frame(&fx.flash, dt)
```

Forward each original change, including its occurrence ID and confirmation
state. An update or confirmation preserves a live visual's age; cancellation
removes it. The routes remember consumed IDs after expiry or cancellation, so
replaying the same occurrence does not create another flash or sound. A `false`
return from a route's change function normally means no new effect was started,
including updates, cancellations, filtering, and duplicate suppression.

Drain Session changes every rendered frame. The starter's `effects_retire`
advances the consumed-ID floor only after the delivered, reset, and journal
queues are drained. It uses the authority head or the client's minimum
confirmed/watched tick for these gameplay events. A predicted or rendered tick
is not a safe retirement frontier: an older event may still be waiting for
delivery. Recovered action-result notices need their own delivery policy.

The script owns both routes and their borrowed audio stream until `finalize`.
Destroy the routes before releasing that stream. A temporary tree exit does
not end the script instance's lifetime. See the
[route reference](https://github.com/wlitwin/odin_godot/blob/main/replay/godot/scene/effect-routes.md)
for capacity, voice stealing, spatial sound, and contextual projectors.

## Reset presentation with the simulation

Use `session_presentation` for the current seat, admitted epoch, reset identity,
authority/observer role and latest correction serial. It returns no context for
an unopened/closed Session or a client that has not received its first World.
During recovery it describes the retained World, rather than the next epoch
hint. A fenced Session can still have a displayable World; this context does
not grant authority to issue gameplay or publish state.

```odin
scope, available := rgd.session_presentation(&session)
if !available {return}
if !rgd.presentation_same_scope(scope, previous) {
    smoothing = {} // the game's chosen reset policy
}
if scope.correction_serial != 0 && scope != previous {
    correction: net.State_Correction(World)
    if rgd.session_correction(&session, scope, &correction) {
        // Compare correction.before/after at the same prediction tick.
        // Keep entity-generation, teleport and camera policies here.
    }
}
previous = scope
```

Store `previous` per Session and clear it when closing/reopening that Session.
Corrections are identified by their complete context, including epoch, reset
and serial. Zero serial means none. A stale context cannot retrieve a newer
correction. Reading does not consume it, so independent camera and actor views
can each track their own last-seen context. The API exposes the latest
value-prediction correction, not a queue of every correction in a pump.
Complete-physics sessions do not synthesize an ordinary `State_Correction`.

The context is small and copies no World frames. Only `session_correction`
copies the requested before/after frames. Use `scope.epoch` and `scope.reset`
with `Scope_Tracker`, but pass the tick of the frame you actually selected for
display. A presentation reset is also distinct from a connection generation:
ordinary catch-up should not reset unrelated menu/admission choices.

A recovery or epoch change can invalidate retained effect identities and
historical views. Rebase or clear presentation under the chosen runtime's reset
contract. The starter forwards a strictly newer occurrence epoch to both routes,
which clears the old effects and consumed IDs. Clearing live effects within the
same epoch preserves consumed IDs. A fresh epoch scopes occurrences; it does not
authorize a new host.

## Next

Read [Recovery](recovery.md) for authority changes, or study the
[Godot Loot view](https://github.com/wlitwin/odin_godot/blob/main/examples/replay_hello/README.md)
for a visible input revision and effect cancellation.
