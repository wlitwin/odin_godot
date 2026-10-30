# Replay Godot integration

`Session(State, Control, Action, Event, Seats)` owns the routine local/network
lifecycle around the engine-free runner. The application supplies a typed model,
initial frame, options, sampled controls/actions, and presentation.

Start with a zero-initialized owner and copy `SESSION_OPTIONS` for its settings;
an empty `Session_Options{}` does not contain the network defaults. Keep the live
owner at a stable address, usually a field on the game's Godot script. Call
`session_close` from that script's exit lifecycle. Do not copy an open Session or
defer its close in `_ready`, which would close it as soon as `_ready` returns.

| Task | Normal API |
| --- | --- |
| Direct local or authoritative game | `session_open`, `session_frame`, `session_close` |
| Submit a discrete action | `session_issue`; use `Action_Intent` when retaining and tracking a pending action |
| Read presentation | Drain `session_changes`, then read the copied `session_state` |
| Invitations and durable enrollment | `party_open`, `party_begin`, `party_frame`, `party_room_options`, `party_close` |
| Coordinator-owned recovery | `room_open`, `room_frame`, `room_issue`, `room_close`; read changes/state through `room.session` |

Use one Session or Room owner for a game. Room owns its Session and drives it;
do not call `session_frame` separately on `room.session`. Party remains alive
while Room borrows its authorization. Close Room before Party and its storage.

[Editor-first authoring](editor-first.md) connects ordinary scene-local scripts to
typed display values. Replay Scrapyard is the canonical composition example, with
standalone actor/HUD previews and validated Resource baking.

[Typed view pools](view-pools.md) bind generation-safe entity projections to cached
Godot child references and skip unchanged property writes.

[Definition baking](../definitions/README.md) converts authored Resources and scene
markers to validated immutable values with content identity and retained versions.
Further boundary work is tracked in the [bridge plan](../../docs/replay/godot-bridge-plan.md).

[Local diagnostic overlay](debug.md) adds optional runtime counters and explicit
recent-history audits without game-specific reporting code.

[Local history inspection](scrubber.md) adds a retained-frame slider with explicit
resume/branch commands and validated scalar edits to a copied preview. Replay Hello demonstrates pause, historical views, input
guards and a new presentation epoch for an alternate local future.

[Portable local recordings](../diagnostic/recording.md) export replayable gameplay
windows from the history dock and verify them in a separate headless process.
[Loaded recording playback](../diagnostic/playback.md) opens those files in Godot,
shows recorded frames and mismatch details, and returns explicit branch commands.

[Explicit body contracts](body-bindings.md) distinguish World-driven bodies from
authority-gated cooperative Godot solver observations.

[Declarative effect routes](effect-routes.md) bind events to typed scene/paint
callbacks or sound cues with bounded lifetime and rollback handling.

[Bounded event audio](audio.md) consumes presentation changes with retained
one-shot IDs and bounded Godot voice pools.

[Steam packet transport](steam.md) adds an explicit Session backend with separate
contract, native-capability and live-account acceptance gates.

[Connection generations](multiplayer-generations.md) distinguish successive
MultiplayerPeer connections and fence queued data when numeric IDs are reused.

[Browser identities and local checkpoints](browser_checkpoint.md) add persistent
credentials, validated archive loading and save completion receipts.

[Browser blob storage](browser_store.md) provides asynchronous commit receipts and
revision-checked IndexedDB writes for local identities, profiles and serialized
data. Storage runs outside the simulation contract.

```odin
options := replaygd.SESSION_OPTIONS
options.role = .Host // Solo, Host, Server, Client, Observer
options.network.hz = 20
error := replaygd.session_open(&session, initial_frame, model, options)
if error != .None {
	replaygd.session_close(&session)
	return error
}

// Each frame: sample devices outside simulation.
error = replaygd.session_frame(&session, delta_seconds, controls)
if error != .None {
	return error
}
for {
	count := replaygd.session_changes(&session, changes[:])
	if count == 0 {
		break
	}
	for change in changes[:count] {
		present_change(change) // Application presentation callback.
	}
}
frame, valid := replaygd.session_state(&session)
if valid {
	present_state(frame.state) // Application presentation callback.
}
```

`session_issue` routes a local player's action to the authority or predicting
client. Consume `session_changes` before the next frame. It carries gameplay
effects and action verdicts; an authoritative verdict is a `Confirm`, or a change
whose `confirmed` flag is set. Simulation never renders or accesses device state.
The facade drains the lower-level duplicate outcome convenience queue so normal
games have one presentation-consumer door.

The caller supplies the `changes` scratch array. Drain until zero even when that
array is smaller than the pending batch; leaving changes queued makes the next
`session_frame` return `.Presentation`. The checked
[lifecycle recipes](../../examples/replay_recipes/recipes.odin) show this complete
loop with concrete types.

[Typed InputMap and signal bindings](controls.md) buffer tick edges, apply explicit
pause/focus/menu gates and capture copied UI actions.

[Copied action intents](intents.md) retain a pending payload through submission
failure and track epoch-scoped tickets through confirmation and recovery. They
provide the common latch/result bookkeeping without changing gameplay policy.

For mixed local/remote presentation, supply `Model.event_owner` and set
`options.remote_observed=true`. Local effects remain speculative; remote effects
wait for the observed clock. The option survives Room promotion, redirection and
old-host rejoin. Bind aiming input to the displayed remote frames using
[`net.client_present`](../net/view_time.md). This changes presentation policy;
the default runner predicts the complete public world. `Model.group` can opt into
an authored closed group; see [prediction groups](../net/groups.md).

`Nodes2` maintains bounded scene instances by presentation identity, with retained
scene ownership. `nodes_get` supports game-specific dressing of child nodes.
`scene_instance` loads/instances an authored stage and releases the temporary
resource reference. `bind_key`/`bind_mouse` release constructor references after
InputMap retains the events. `session_token` uses random credentials normally;
deterministic labels are for tests. `session_profile(path)` creates or reads a
persistent local token. Use a separate profile for each player running on one
machine; malformed existing profiles fail instead of silently changing identity.

`session_save(session, path)` captures and writes a complete authority archive.
`checkpoint_read` validates one against the game's model/content, and
`session_resume` opens a fresh authority using explicit newer-epoch/local-seat
options. Host/solo resume verifies that the profile token owns the selected seat.
Writes close a flushed staging file before replacing the destination. Existing
archives survive an interrupted next write; power-loss durability and browser
filesystem persistence have not been verified. One writer may own a path at a time.

The separate Cavecrawl save gate kills its writer and resumes in a fresh process;
the co-op recovery gate replaces both host and guest and checks stable-seat loot
and continued actions. See [recovery](../../docs/replay/recovery.md) for API examples
and the distinction between local recovery and the Room migration driver.

Network sessions now share an ENet connection between gameplay and checkpoint
replication through `recovery.Link`. To accept complete authority backups, set
`options.replication.accept_checkpoints=true` before opening a client. On the
authority, `session_backup_seat(session, seat, interval_ticks)` explicitly authorizes
that admitted player as a recipient. `session_frame` handles routing, periodic
capture, chunk repair, validation, and combined traffic budgets. The default interval
is one simulation second. `session_backup_receipt` reports a validated receipt;
`session.link.error` and `model_error` report backup failures without stopping play.

This authorization discloses authority-only state. It does not make the recipient
an elected host. Connection replacement requires explicit authorization of the new
live binding. The Room driver adds coordinator fencing and tested surviving-client
takeover; broader M5 cases remain open.

The authority model and permit enforcement are now available in `replay/authority`.
For a leased session, set `options.network.require_permit=true` and supply
`options.permit`. `session.fenced` reports an expected pause when it is unavailable;
fixed-step backlog is discarded while fenced. The application must continue its
coordinator/UI loop separately. The authenticated decision service and durable store
are now available, along with the initial Room takeover driver. See the
[service contract](../authority/service.md).

The facade is experimental. It supports full-public and authored group prediction with
the existing ENet/fault adapters. [Room](room.md) now adds coordinator-driven planned
and crash migration with surviving-client reconnection in tested Cavecrawl and
Quickdraw combat scenarios.
[Session communications](../comms/README.md) adds optional bounded chat and markers
through an independent application lane. Owner-streamed physics has separate
[2D](body2.md) and [3D](body3.md) adapters. Matchmaking and a complete lobby UI remain
roadmap work rather than implicit guarantees of the convenience wrapper.


For direct sessions, `Session_Options.discover_epoch=true` enables a small pre-join
query of the selected host. It discovers the current epoch before the strict
Hello/Welcome exchange, so a fresh client can join a manually resumed host. It
must be enabled on both endpoints, defaults off, and is rejected for leased
sessions. It neither elects nor authenticates the host. The [network contract](../net/README.md#opt-in-direct-host-epoch-discovery)
describes challenge matching, timeout and scope restrictions. Room continues to
obtain authority epochs from its coordinator.

`Session_Options.reuse_equal_corrections` opts a client into the core's exact
correction-reuse path. It defaults off and requires stable deterministic step
semantics. `client.stats.reused_correction_ticks` reports retained records while
`replayed_ticks` counts simulated correction steps. It changes local work only,
not snapshot cadence, packet contracts or authoritative validation. Mixed Scrapyard
initially exposes few matching records, so this is not enabled by default as a
universal performance improvement.

`Session.control_consumed` reports whether the supplied control was used by an
actual local/authority input step during the last `session_frame` call. It is false
when there was no prepared tick, prediction is blocked, a snapshot merely moves
or bootstraps the timeline, or the role does not consume local controls. Use this
receipt to clear pending device edges; a larger timeline head alone does not prove
input was sampled. The field resets at each Session or Room frame call, including early returns. It is not an authority acceptance
or delivery acknowledgment.

```odin
error = replaygd.session_frame(&session, dt, control)
if session.control_consumed {replay.buttons_consume(&buttons)}
```

Immutable procedural polygons can use [mesh2_polygon](mesh2.md), with ordinary
Godot node transforms and instance tint for animation.

Room clients can display [recovery-backup status](room_backup.md), including
approval, freshness and uncertainty, without using UI state as authority permission.

For short linear visual motion, `session_tick_phase` feeds a caller-owned
[`view.Tick_Phase`](../view/phase.md) after Session/Room advances. Prediction
stalls and fencing cannot turn a wrapped fixed-clock fraction into backward
render motion. Gameplay membership and collision decisions remain in the model.

[Room moderation](room_moderation.md) queues durable enrolled-member removal and
tracks its result, preserving bans through successor replacement and old-checkpoint
recovery. Direct Session bans retain their checkpoint durability contract.

[Steam Room destinations](steam_room.md) use explicit authenticated endpoint
encoding and fresh peer construction through recovery. Local contract acceptance
is recorded separately from still-pending live multi-account Steam validation.

[Typed archetype registries and scene pools](archetypes.md) connect stable gameplay
IDs and baked definitions to independently authored local scenes and appearances.

[Typed scene adapters and optional view codegen](adapter-bindings.md) provide
owned script/archetype bindings, permanent scene bindings, scope tracking, typed
visitation, contextual errors and checked Resource/bake helpers.
