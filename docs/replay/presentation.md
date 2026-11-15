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

The starter drains changes without playing effects. Add your effect map there,
using the same change loop. Drain it once per rendered frame so retained
notifications do not accumulate.

## Reset presentation with the simulation

A recovery or epoch change can invalidate retained effect identities and
historical views. Rebase or clear presentation under the chosen runtime's reset
contract. A fresh epoch scopes occurrences; it does not authorize a new host.

## Next

Read [Recovery](recovery.md) for authority changes, or study the
[Godot Loot view](https://github.com/wlitwin/odin_godot/blob/main/examples/replay_hello/README.md)
for a visible input revision and effect cancellation.
