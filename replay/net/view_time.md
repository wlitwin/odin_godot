# Aim and historical queries

Use `Model.step_view` when hit judgment or another historical query must refer to
the remote state a player aimed at. It is the simulation callback for games that
need the displayed view associated with each control sample. It replaces `Model.step` for that model; existing models
can keep `step`. Both execute the same complete-world prediction/correction loop.

Draw remote players with `client_present(&client)`. It returns two authoritative
frames and a quantized interpolation fraction and remembers their snapshot IDs.
Compute aim from those same drawn positions. Subsequent `client_step` calls bind
that bracket to their controls; receiving a newer snapshot does not rewrite the
earlier aiming context. Calling `client_observed` alone does not bind a context.

Presentation drift is bounded by `watch_delay + view_slack` behind the latest
installed authority frame. After a sparse delivery or local stall, the observed
clock catches up to that bound. If the available interpolation endpoints exceed
`max_view_span`, it advances to the newer received endpoint. `Stats.watch_catchups`
counts these advances. Watched events advance with that same clock. This may skip
an old visual interval; it prevents lingering on views whose proofs have expired.
Previously captured aiming stamps stay unchanged, and the server still validates
their identity and age. Catch-up does not turn rejected history into a live query.

The server resolves the transmitted `View_Stamp` into a `View_Time`:

- `Historical`: both snapshot IDs/ticks were sent to this connection in its
  current generation/checkpoint serial, the bracket is bounded, and its age at
  receipt is within policy.
- `Live`: authority-local input, querying the current simulation step.
- `Unavailable`: no observed view was supplied.
- `Invalid`: malformed bracket or unknown/mismatched snapshot identity.
- `Expired`: a known view exceeds the allowed age. A previously accepted view can
  also expire before its scheduled simulation tick executes.

Only control ownership and ordinary input validity determine whether movement is
accepted. An invalid view disables that input's historical query; it does not
discard otherwise valid movement. Reliable actions remain a separate API.

Defaults allow 30 ticks of rewind, a 12-tick interpolation span and four ticks of
timing slack. At receipt, the age bound is the smaller of `max_rewind` and the
measured snapshot-ack RTT floor in ticks plus `watch_delay + view_slack`. Until an
RTT observation exists, the absolute bound applies. A two-second measurement
window lets the floor adapt to route changes. Execution applies `max_rewind`
again so queued or held inputs cannot keep a historical query alive indefinitely.
These settings, including watch delay, participate in the connection contract.

These are bounded, validated hints, not proof of what a physical display showed.
A client can select another known bracket within policy or delay acknowledgements;
the absolute cap still applies. Competitive deployments must choose suitable
caps and trust only their authority's world/collision data.

## Collision storage

`replay/history.History(T, N)` is a value-owned ring. Put it in `World` when its
contents influence simulation. It then participates in correction, canonical
snapshots, saves and migration. `read`/`bracket` return copies and explicit misses;
they never temporarily move live entities. This initial representation trades
copying/bandwidth for a straightforward complete-world contract.

`query_view(&history, view, live, tick, blend)` resolves the validated `View_Time`
against that ring and returns `{value, status, tick, available}`. Live requests use
the supplied current value. Historical requests require both retained endpoints;
missing history becomes Unavailable, malformed ranges become Invalid, and rejected
view statuses stay unavailable. There is no live fallback. Read `value` only when
`available` is true. The helper does not authenticate raw client stamps; the runner
does that before supplying `View_Time` to `step_view`.

The game supplies a pure `blend(a, b, fraction)` for its collision-history value and
checks the resulting lifetime IDs against current entities before applying effects.
Quickdraw and Scrapyard use this helper with different proxy representations.
History values, including generation changes, remain part of rollback/checkpoints.

Quickdraw records four `replay/play.Hurtbox2` proxies after movement each tick.
Its ray starts at the live shooter's position, queries the validated historical
target bracket, and clips against authored static walls/crates. A life identifier
prevents an old body from hitting a respawned player. Missing history or rejected
view context produces an explicit miss. The A/B control intentionally queries
live targets instead. A game chooses its own policy; there is no hidden fallback
to current collision poses.

Validated held/future view contexts are archived alongside controls. Network
snapshot proofs are connection-local and rebuilt on rejoin. As with existing
control streams, reconnect retires archived remote inputs and samples a fresh
stream; archived reliable action IDs follow the selected recovery policy.

## Presentation and spawn identity

Supply `Model.event_owner` and call `client_remote_observed` to present local
effects speculatively and remote effects on the observed clock. The journal still
delivers Begin/Update/Cancel/Confirm. Clients that do not opt in retain their
existing policy. Keep the client at a stable address: the policy carries
a borrowed pointer to that client.

Godot Session/Room callers can set `Session_Options.remote_observed=true` instead
of reinstalling the policy after role changes. Quickdraw clears scene instances
on epoch/Welcome reset and scopes active beam cancellation to the full event ID,
so cancellation of an old shot cannot erase a newer shot's beam.

Quickdraw predicts the complete world but draws remote bodies/projectiles from
observed frames. This is mixed presentation, not a partial-world predictor or an
owner-authoritative physics mode. [Owner observations](../owned/README.md) and
prediction groups have separate contracts.

`replay/play.spawn_key(tick, seat, ordinal)` supplies a bounded semantic ID for
predicted view lifetime. Authority and prediction can allocate different pool
slots and still identify the same projectile. Pool generations continue to govern
simulation handles. An application must reset its view namespace on authority
epoch changes; the spawn key alone is not an epoch-qualified global ID.

Gameplay protocol is version 7; complete authority archives are version 4. Earlier
experimental packets/archives are rejected. Authority control RPC and coordinator
decision record versions are independent.
