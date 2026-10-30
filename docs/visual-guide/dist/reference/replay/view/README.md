# Replay presentation

Use Replay's presentation helpers to draw copied simulation state and reconcile
effects after correction. Simulation state stays in `replay.Timeline`; presentation
reads detached frames and owns its own smoothing, scene nodes and effect state.

## Frames and poses

`frames_at(&timeline, lower_tick, alpha)` copies two adjacent frames. A missing
lower frame is an explicit failure; sampling the current head holds that frame
without extrapolation. Use the lower frame's entity membership/discrete state
until the presentation clock reaches the next tick. Extract poses and pass them
through `pose_blend`; a teleport explicitly selects the destination pose.

`Smoother2` and `Smoother3` carry position and angular correction error. Use
`smooth_correct_pose` / `smooth3_correct_pose` for same-tick corrections, then
present each render frame; ordinary motion continues while the error decays.
Large discontinuities cut. [Angular smoothing](rotation.md) documents shortest
arcs, quaternion composition, finite-input handling and Godot integration.

## Event journal

```odin
journal: view.Journal(Event)
err := view.journal_init(&journal, epoch = epoch, baseline = checkpoint_tick)
// Optional: view.journal_set_policy(&journal, classify_event)
// For every complete tick batch (empty ticks included):
err = view.sync_tick(&journal, tick, occurrences)
err = view.advance_time(&journal, confirmed_tick, watched_tick)
count := view.drain(&journal, changes[:])
```

An occurrence is a recorded gameplay event with an identity used to match it
across replay. Its payload holds game-specific data; its identity lets the journal
update, confirm or cancel the same effect. Each new occurrence receives a policy.
Existing IDs keep their policy:

| Policy | When it begins |
| --- | --- |
| `Speculative` (default) | On first observation; later changes may update/cancel it |
| `Confirmed` | When authority confirms its tick |
| `Watched` | When confirmed and the visible cause's watch clock reaches its tick |

Drain notifications outside simulation:

- `Begin`: start the effect. `confirmed` distinguishes an already final occurrence.
- `Update`: adjust an existing speculative effect; `previous` carries its old payload.
- `Cancel`: remove or stop an effect whose occurrence disappeared during replay.
- `Confirm`: an already begun speculative occurrence has become final; do not begin it again.

Payloads are stored by value, independent of live entity pointers. An impact or
death effect can still begin after its source entity is destroyed. Put the
required pose/details in its payload.

The journal has bounded tick/event history and a bounded output queue. Each
`sync_tick` or `advance_time` is atomic with respect to tracked events and output.
On `Output_Full`, drain and retry. It will not evict unconfirmed events or pending
watched effects to make room. Capacity/history errors require backpressure or an
explicit presentation reset/resync; do not silently drop them.

Synchronize complete batches through a frontier before confirming them. Once
confirmed, batch membership and payloads cannot change. `advance_time` is monotonic
within an epoch. To inspect an older committed playback, use a fresh epoch and
explicitly tear down old effects/views. Rejoin initialization sets a baseline so
historical one-shots cannot replay as new occurrences.

A newer checkpoint in the **same epoch** uses `journal_rebase(&journal, tick)`.
It retains already queued output, matures effects from previously confirmed
batches at the new visible baseline, and cancels abandoned speculative effects.
Already final effects do not begin again. Unconfirmed occurrences and missing
batches in the gap do not become confirmed merely because a newer checkpoint
exists. The new baseline must be at least the old confirmed and watched ticks.

Rebase is atomic. `journal_rebase_check` lets a runner check queue capacity before
resetting its simulation timeline; the journal must stay unchanged between that
check and commit. `Output_Full` requires draining and retrying. `Capacity` means
the required notifications cannot fit even in an empty queue. A **new epoch**
still uses `journal_reset`, with its separate old-scope cancellation contract.

`replay.confirm_through` separately protects the simulation frontier. A runner
must establish that the ticks are settled under its authority or peer-commit
protocol before calling it. Neither counter elects a host,
authenticates packets, or guarantees durable external effects; those belong to
the network/session authority contract and any application outbox or external
service.


`One_Shots` retains consumed event IDs independently of active effects. It prevents
an already heard one-shot from replaying when a cancelled occurrence reappears.
Retirement is explicit and monotonic; retired IDs remain expired after their ring
slots are reused. See the [Godot audio adapter](../godot/scene/audio.md) for the consumer
contract, bounded capacities and voice-reuse behavior.

[Visual cues](cues.md) turn journal changes into bounded, detached render instances
with correction, cancellation, expiry and consumed-ID retention. Cavecrawl uses
them for its event-backed combat bursts and hit flashes.

[Bounded tick phases and linear previews](phase.md) support render-frame motion
without stepping simulation or wrapping backward during prediction stalls.
