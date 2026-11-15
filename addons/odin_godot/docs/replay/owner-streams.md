# Owner observations and engine physics

Record motion from a trusted external physics owner and transfer that producer
between participants. This guide assumes [Replay sessions](godot.md).

An engine-owned body is an external observation producer. A Godot solver may run on
the currently authorized participant; Replay records accepted pose/velocity samples
and gameplay decisions in its ordinary value world. Replaying those values does not
rewind or reproduce Godot's contact solver. Deterministic P2P remains a separate
profile. Historical gameplay queries may use recorded accepted values, but cannot
substitute a current engine query for a historical dynamic collision query.

## Transport and admission

The authoritative runner supports an explicit `Latest_Observation` control policy.
Normal scheduled input remains the default. The policy participates in the existing
session/checkpoint contract hash, so peers must agree before play. Latest samples
are coalesced into the next authority tick; they are not queued until a predicted
client tick. Sender identity, connection generation, epoch, serial, bounds and
monotonic input-frontier validation still apply. A separate bounded single-observation
packet avoids transmitting a padded multi-tick command window. Scheduled contracts
and archive/wire layouts remain compatible with the existing default profile.
One-shot gameplay actions keep their existing sequenced acceptance/outcome
semantics.

The owner protocol stores its state as values independently of Godot and the
transport. Each body stores its current owner, epoch/revision, last accepted sample sequence/source tick,
authority acceptance tick, complete value, and an optional pending handoff. An
authenticated sender's seat is supplied separately from the sample. Samples cannot
name another owner. Finite-value, world-bound and motion predicates are application
policy, not proof that an untrusted peer honestly ran the solver.

## Handoff and reset

An offer reserves a new monotonically increasing revision and carries the current
complete pose/linear/angular velocity as the preparation baseline. The old owner
remains the accepted source while the proposed owner prepares. The first valid sample
for the reserved revision commits the transfer at an authority tick. Old-revision
samples then fail. Offers can expire or be canceled; canceled revisions are never
reused. The game remains responsible for eligibility/proximity arbitration.

Explicit cuts, owner revocation and authority-epoch changes preserve or replace a
specified complete value and invalidate prior sample scopes. Checkpoints contain
the ownership/offer/frontier state as part of the world. A fresh engine adapter
seeds its transform and both velocities from that value, then resumes observation
production with the appropriate sequence. Solver contact caches are not preserved;
any settling/grace behavior must be explicit.

The initial Godot 2D adapter imposes rigid-body states through PhysicsServer,
freezes observers, and separates local solver state from presentation
smoothing. Provisional possession may run a speculative local solver, but only an
authority-issued revision can publish accepted samples. Score, goals, inventory and
other shared decisions remain ordinary authority gameplay over accepted values.

## Cavecrawl profile

The separate [owner-motion Cavecrawl](https://github.com/wlitwin/odin_godot/blob/main/examples/replay_cavecrawl_owned/README.md)
composes the existing gameplay World with versioned avatar/relic observations.
It shares gameplay code with the server-simulated example while keeping distinct
content identity and app state. Its manual producer supplies poses. Use the
[support guide](support.md) to select a runtime, transport, and deployment target.


## Reliable interaction context

[Scoped action context](https://github.com/wlitwin/odin_godot/blob/main/replay/owned/README.md#context-carried-by-a-reliable-action)
separates an action's claimed owner pose from the coalesced motion stream.
Cavecrawl uses issued positions for range checks and a 64-pixel throw-origin
leash without moving its current avatar pose. Treat this as cooperative claimed
context. Historical collision queries require their own validated history.
