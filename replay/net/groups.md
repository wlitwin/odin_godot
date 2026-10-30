# Authored prediction groups

Use a prediction group when a client should simulate only a declared subset of
the world. The default client predicts the complete public world; `Model.group`
defines a closed subset using the same value carrier, including every mutable
dependency needed by its gameplay rules:

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
after every step/action batch. An invalid footprint aborts the whole candidate
transaction. This checks an **authored invariant**; it does not statically infer
dependencies or prevent arbitrary reads inside an Odin procedure. Include every
mutable dependency in the group or supply an explicit boundary model. A group
that cannot execute a game action coherently needs a larger footprint or a
different prediction policy.

`client_prediction` returns a detached `Prediction_View` containing the group's
frame, ID and seat. ID zero denotes the complete public group. A scoped client
timeline is a prediction group, never a complete authority checkpoint.
`client.authority_frame` and `client_observed` retain received replicas for
UI/remote presentation: complete public worlds under the default policy, or
[recipient-filtered values](replication.md) under an explicit transmission policy. Observers do not project. Reconnect and newer
authority Welcome reapply the projection. Server recovery continues to use the
complete approved archive, and an old host is projected when it becomes a client.

Group IDs are local prediction policy, not privileges or authority. They are not
client-supplied packet fields. Different clients may choose different prediction
strategies under the same authoritative game contract. Models remain immutable
while a timeline is live; hot scope changes need explicit teardown/reinitialization.

## Outside state and time

`replay/history.Boundary(T)` stores an owned value, source tick and availability.
`boundary_sample` requires an explicit `Exact` or bounded `Hold` policy and returns
Missing/Future/Exact/Held/Expired. Holding a proxy is an approximation with a named
age limit, not remote simulation at the query tick. Missing/expired data returns
no usable value; the game chooses to stall, decline the interaction or use another
explicitly authored policy. Do not silently query current engine nodes.

Store these boundary values in the group state so correction, replay and audit
use the same historical dependency. Projection from a newer authoritative frame
refreshes the boundary before replay. A native moving-gate fixture verifies held
collision, age exhaustion, changed-boundary correction and reproducible replay.

Claimball uses a local avatar plus the shared ball. Its outside avatar samples
are timestamped, but it deliberately predicts **no contacts from those avatars**,
matching the original example. Their actual interactions arrive in authoritative
corrections. Their visible poses come from observed frames, independently of the
prediction group. This is a declared coupling policy, not general remote collision
prediction. More elaborate boundary extrapolation/history policies remain work.

## Current envelope

One group per player client is implemented, with one to eight seats in the
existing runner. The carrier type is still the authority's `State`; zeroing absent
members establishes semantics, not sparse memory storage or a bandwidth reduction.
Claimball's boundary fields also increase that carrier. Different projected state types, multiple independent groups and automatic
dependency analysis remain unimplemented. [Recipient views](replication.md)
filter state/controls/events before transmission. Prediction with omitted
authority-only fields requires both that explicit policy and a validated group;
unscoped prediction remains rejected.

The initial native and real-process Claimball tests establish scoped simulation
and presentation in this envelope. They do not establish deterministic P2P,
arbitrary cross-group transactions or the full roadmap's completion.
