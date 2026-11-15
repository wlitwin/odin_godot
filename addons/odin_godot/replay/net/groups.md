# Authored prediction groups

Use a prediction group when a client should simulate a declared subset of the
world. By default, the client predicts the complete public world. `Model.group`
projects that world into a subset stored in the same `State` type. Include
every mutable dependency its gameplay rules need:

```odin
Prediction_Group(State){
    id = 1,
    project = project_local_group, // received replica Frame + seat -> group State
    valid = validate_group,        // checks membership and dependency invariants
}
```

The authority always simulates and archives the complete world. Player clients
project each received Welcome/snapshot into their prediction group before resetting or
correcting the timeline. Nonmembers must be removed from active simulation
storage, not left as apparently current entities at an older tick. The same
gameplay step runs over the remaining members. Local controls, commands and view
stamps retain their identity; remote control slots become the model's neutral
input. Recorded group/seat metadata protects replay from a changed definition.

The runner validates the projection before installing it and validates the group
after every step/action batch. If membership or dependencies violate the game's
invariant, the entire candidate transaction aborts. This relies on the game's
validation procedure: the runner cannot infer dependencies or prevent arbitrary
reads inside Odin code. Include every mutable dependency in the group, or
define how the group obtains values from outside it. If an action cannot run
with those dependencies, expand the group or choose a different prediction policy.

`client_prediction` returns a detached `Prediction_View` containing the group's
frame, ID and seat. ID zero denotes the complete public group. A scoped client
timeline is a prediction group, never a complete authority checkpoint.
`client.authority_frame` and `client_observed` retain received replicas for
UI/remote presentation: complete public worlds under the default policy, or
[recipient-filtered values](replication.md) under an explicit transmission
policy. Observers do not project. Reconnect and a newer authority Welcome
reapply the projection. Server recovery uses the complete approved archive;
an old host projects its world when it becomes a client.

Group IDs are local prediction policy, not privileges or authority. They are not
client-supplied packet fields. Different clients may choose different prediction
strategies under the same authoritative game contract. Models remain immutable
while a timeline is live; hot scope changes need explicit teardown/reinitialization.

## Outside state and time

`replay/history.Boundary(T)` stores an owned value, source tick and availability.
`boundary_sample` requires an explicit `Exact` or bounded `Hold` policy and returns
Missing/Future/Exact/Held/Expired. A held value approximates outside state using
a previous sample and an explicit age limit; it does not simulate that state
at the query tick. Missing or expired data provides no usable value. The game
must stall, decline the interaction, or apply another explicit policy rather
than reading current engine nodes during replay.

Store these boundary values in the group state so correction, replay and audit
use the same historical dependency. Projection from a newer authoritative frame
refreshes the boundary before replay. A native moving-gate fixture verifies held
collision, age exhaustion, changed-boundary correction and reproducible replay.

Claimball predicts the local avatar and shared ball. It stores timestamped
samples of outside avatars but does not predict their contacts, matching the
original example. Authority corrections supply their interactions, while
observed frames supply their visible poses independently of the prediction
group. This example does not establish general remote collision prediction.
More elaborate boundary extrapolation and history policies remain unimplemented.

<a id="current-envelope"></a>

## Supported group configurations

One group per player client is implemented, with one to eight seats in the
existing runner. It uses the authority's `State` type: zeroing absent members
excludes them from simulation but does not reduce storage size or bandwidth.
Claimball's boundary fields also increase the size of that state. Different
projected state types, multiple independent groups, and automatic dependency
analysis remain unimplemented. [Recipient views](replication.md)
filter state/controls/events before transmission. Prediction with omitted
authority-only fields requires both that explicit policy and a validated group;
unscoped prediction remains rejected.

The initial native and real-process Claimball tests establish scoped simulation
and presentation for the configurations above. They do not establish deterministic P2P,
arbitrary cross-group transactions or the full roadmap's completion.
