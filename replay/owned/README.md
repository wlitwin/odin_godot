# Owner-streamed values

`State(Value)` stores ownership, current value, sample frontiers and pending handoff
in ordinary replayable world state. `Sample(Value)` is an external observation;
the library never invokes a physics solver during replay. `Rules(Value)` supplies
immutable validation policy outside the saved state.

```odin
owned.init(&body, object_key, epoch, tick, initial_owner, initial_pose, rules)
owned.offer(&body, next_owner, tick, timeout_ticks)
result := owned.accept(&body, authenticated_sender, sample, tick, rules)
// result.transferred identifies the tick that commits the prepared owner.
```

An object key includes kind, slot and generation. Epoch/revision scopes fence old
authority and ownership messages. Owner zero denotes no active producer; nonzero
owner IDs are mapped by the application to authenticated senders. A sample carries
no sender identity of its own. Nonempty samples require a sequence; exact duplicates
do not mutate state, changed values at the same sequence conflict, and older scopes/
sequences or decreasing producer ticks are rejected.

An offer reserves a new revision and a complete preparation baseline. The old owner
remains accepted until the first valid sample for the proposed revision commits at
an authority tick. Cancel/expiry burn the reserved revision. `cut` explicitly changes
the complete value/owner and advances its discontinuity marker; `bind_epoch` preserves
value and owner while invalidating prior scopes and pending offers. Overflow never
wraps a revision. These primitives do not elect/fence a legitimate session authority.

`valid` checks structural state and value constraints. `sample_valid` additionally
accepts a canonical zero sample as an empty upstream control slot. Values containing
references are rejected. `Pose2` and `Pose3` include position, rotation, linear and
angular velocity and sleeping state. Limit validators reject nonfinite/out-of-bounds
values, excessive velocity norms and non-unit 3D quaternions. A transition predicate
may impose additional game constraints; it cannot prove an untrusted solver was honest.

`Driver` lives outside world state. `drive` selects Observer/Owner/Preparing from
authority-observed state, local identity, live epoch and connection eligibility.
It reports reseeds separately from cuts. Preparing → Owner retains the same revision
and local solver; a fresh producer rebases sequence/tick counters from accepted state.
`capture` cannot publish from an observer. Producer ticks order that producer's
lineage; `accepted_at` is the authority's history timestamp.

The Godot [Body2](../godot/scene/body2.md) and [Body3](../godot/scene/body3.md) adapters supply
actual rigid/character handling.
The [profile design](../../docs/replay/owner-streams.md) and separate
[Replay Slopball](../../examples/replay_slopball/README.md) describe integration and
the tested envelope. This supports cooperative trust models. It does not make Godot
contact solving deterministic, provide competitive anti-cheat, or turn live engine
casts into historical collision queries.

## Context carried by a reliable action

`Action_Context(Value)` carries a producer value plus its ownership scope.
`capture_context(&driver, value)` requires a committed Owner role and leaves the
pose sequence/producer clock unchanged. `read_context(&state, authenticated_sender,
claim, authority_tick, rules)` validates the current owner, exact object/epoch/
revision, time and value bounds, then returns the value without mutating state.
It cannot accept a pending ownership offer or advance a stream frontier.

Use this when a reliable interaction must retain the caller's pose even if its
unreliable movement observation is delayed, or a newer pose overtakes the command.
The outer action supplies sequencing/deduplication. Scope changes fence old claims;
new samples in the same scope do not. `Rules.transition` is a stream update policy
and is not invoked by context reads. The game must explicitly select range, leash
or age constraints appropriate to its trust model. A context has no authority
history timestamp and does not certify an honest engine result.

Owner Cavecrawl uses this for original-style issued-position interactions and a
64-pixel throw-origin leash, while preserving current replicated avatar positions.
