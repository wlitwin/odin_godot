# Replay server/client runner

Use `replay/net` to run a game with an authority that accepts shared gameplay
results and clients that predict local state. The runner schedules simulation
steps and manages input, history, network delivery and correction. The game
supplies its mutable world and simulation rules; the runner encodes values,
associates connections with players, and tracks gameplay occurrences in a
presentation journal. The journal matches predicted and authority occurrences
so effects can be confirmed or cancelled after correction.

The API remains experimental. The sections below describe implemented behavior
and its tests; the [framework audit](../../docs/replay/framework-audit.md) tracks
broader admission, recovery and release acceptance.

`Model.control_timing` defaults to `Scheduled`. The `Latest_Observation` mode
sends one current control sample and coalesces newer producer ticks into the
next authority tick, preserving the accepted value in replay history. It has a
distinct negotiated contract; Scheduled retains its existing wire/archive
encoding. Use latest-observation timing for external outputs such as
[owner-streamed physics](../../docs/replay/owner-streams.md), with game-level
object/owner/sample validation. One-shot actions retain their sequenced
command/outcome path.

`Model.event_policy(event) -> view.Policy` configures when gameplay effects are
presented. The runner reinstalls it when reconstructing the journal after
Welcome, resync, or recovery. Spectators use watched presentation, which follows
authority state on a delayed display clock. Mixed presentation can delay remote
events that would otherwise be speculative. If the game sets a policy directly
on a temporary journal, it must reinstall that policy after reset.

## Gameplay model

Instantiate `Model(State, Control, Action, Event, Seats)` and supply:

- `step(state, controls, joins, leaves, ctx)`: fixed-tick gameplay. Joins/leaves are
  bitmasks delivered exactly at their simulation tick. They are not reads of a
  mutable current roster during replay.
- `action(state, seat, action, ctx) -> bool`: a discrete mutation over the complete
  world. Returning false restores all state and gameplay events produced by that
  action, while the rest of the tick continues.
- `control_valid`, `action_valid`, and `state_valid`: game-defined rules for
  acceptable controls, actions, and state. Before these callbacks, schema
  validation checks structure, finite values, enums, and bit masks.
- `hold`: derive a legal held control from the previous sample. Clear transient
  fields here; continuous movement may remain held. Discrete commands belong in
  `Action`, not a repeated control bit.
- `neutral`: a valid neutral control. `user` optionally points to immutable
  assets/configuration; it must not expose mutable external simulation state.

Simulation uses the same code on authority and predicting clients. Events still
carry game-defined payloads. Source zero is reserved by the network runner for
action verdicts; gameplay emits from nonzero semantic sources.

The runner supports one complete public or [authored partial prediction group](groups.md),
one control and action type, one to eight player seats, and up to sixteen
connections including observers. It refuses unscoped player prediction when
the public projection omits authority-only state. [Recipient views](replication.md)
can filter snapshots, controls and events for players with validated prediction
groups, or for observers. Native and Claimball tests cover group projection,
validation of the group's included dependencies, and timestamped values from
outside the group. Broader group policies remain planned work in milestone M6.

On authority correction, the full-world runner replaces older guesses of remote
held input in the replayed suffix using the snapshot's held-input boundary.
It applies `hold` once per prediction tick, including bootstrap and continuation,
while preserving this client's recorded controls, aiming stamps and action IDs.
For a scoped group, remote control slots are neutral and the game's projection
removes simulation members outside the group. The game must explicitly supply
any values needed from outside that group.

`client.correction` reports the latest successful correction with before/after
frames at the same prediction tick, a serial, authority tick and replayed-tick
count. Read it after each pump (after `session_frame` in the Godot facade).
Copies retain their values independently of the runner, and Welcome resets the
report. Pass matching positions to `view.smooth_correct` to smooth correction
without treating ordinary forward motion as an error. The report stores two
additional world values per client; keep large runtime owners at stable heap
addresses. Further storage and copying changes depend on the workload
measurements planned in the roadmap.

An optional [profiling clock](profiling.md) records replay wall time/depth and
histogram bounds without entering simulation or the network contract. Godot
Sessions install it automatically.

A complete snapshot newer than a briefly stalled client's prediction can be
adopted directly when all intervening authority facts remain available. The
runner preserves the journal and action queues, reprojects the group, and
rebuilds bounded prediction lead. `Stats.snapshot_catchups` records this path,
which avoids a full Welcome/resync round trip. Godot discards the frame backlog
already covered by the snapshot. If required history or facts have expired, the
client still resyncs. `client.resync_notice` records the reason and relevant
tick frontiers for diagnosis. `view_reset` changes on snapshot catch-up so
consumers can discard smoothing based on obsolete state.

## Runtime ownership and loop

`Server(...)` and `Client(...)` own timelines, schemas, queues, and histories.
Keep them at stable addresses and destroy them once. Their transports are borrowed:
destroy the runner before closing the transport adapter. The immutable model is
passed into core stepping via `Step.user`; it is not part of frame state.

On the authority:

1. `server_init` supplies the initial frame and model. A nonzero `local_seat`
   creates a listen-host player; zero is a dedicated authority.
2. Call `server_pump(now_ms)` each render/service frame.
3. For fixed simulation ticks, set local controls if applicable, then call
   `server_step`. `server_issue` queues the host player's discrete action.
4. Read the current frame and emitted events for local presentation.

On a client:

1. `client_init` supplies the same model/content contract, authority connection,
   and a stable opaque token. `spectator = true` allocates no player seat.
2. Call `client_pump(now_ms)` to admit, receive facts/snapshots, reconcile, and
   maintain connection liveness.
3. Once running, `client_step(control)` predicts one fixed tick. The exposed
   `clock_scale` nudges the local clock to maintain input lead. Initial lead uses
   the measured welcome round trip with a configured floor and bounded ceiling.
4. `client_issue(action)` returns a sequence ID for an action predicted at an
   upcoming tick and delivered reliably. Drain authoritative results through
   `client_outcomes` and presentation changes through the client's `journal`.
5. Use `client_observed` for sparse authority frame pairs on the delayed watch
   clock. Older predicted frames are not observations of remote authority state.

## Admission, delivery, and recovery

Snapshot acknowledgments are unreliable latest-state reports regardless of the
logical snapshot size or its delivery channel. New snapshot receipts and the
existing periodic heartbeat path resend the latest validated ID/hash. A lost ACK
can postpone baseline advancement, but cannot hold later actions behind its
retransmission in an ordered reliable stream. The authority ignores older IDs and
requires a retained matching snapshot hash and current binding before advancing.
Large bootstrap snapshots still wait for a valid ACK; periodic resend releases
that gate after loss. Baseline-miss requests and gameplay action delivery retain
their existing reliability policy.

- The handshake checks schema/protocol and content contracts. A connection cannot
  occupy multiple seats, and an already active token cannot be taken over by a
  different connection. Tokens are stored as SHA-256 digests on the server.
- Tokens are bearer reconnect credentials, not account authentication or transport
  encryption. Supply unpredictable tokens and the appropriate transport/deployment
  policy. The Godot sample uses random tokens normally and deterministic labels
  only for tests. `session_profile` from `replay/godot/storage` persists a local credential
  separately from the checkpoint's roster of token hashes.
- A stable seat is reserved across disconnect/reconnect. This initial version
  reserves seats until explicit release. `server_set_locked`, custom admission,
  kick, ban/unban, and `server_release_seat` supply basic room controls. Release
  requires a disconnected seat with settled actions and a model `reset_player`
  callback; initialization for the next occupant occurs inside its joining tick.
  Bans survive reservation release and durable checkpoint recovery. Custom
  admission policy bytes and a policy ID can be archived; the application must
  reinstall the corresponding callback when restoring.
- Input windows contain eight tick-stamped controls. The entire window validates
  before buffer mutation. Sender connection plus connection generation chooses
  the seat; packet data cannot select another player. The first valid value for a
  tick wins, and old/far-future inputs cannot rewrite authority history.
- Actions are reliable, ordered by sequence, and deduplicated. They execute in
  stable seat order. Stale/far-future/invalid actions receive explicit verdicts;
  ordinary game rejection reports `Predicate`. Recent results and both received
  and settled frontiers survive reconnection so new actions cannot reuse an
  unresolved sequence.
- Complete occurrence batches, called facts, use the reliable channel. State
  snapshots normally use the unreliable channel and supersede older pending
  snapshots; large snapshots have the reliable fallback described below. Correction waits for
  matching occurrence history, settles the authoritative prefix, and reconciles
  the speculative suffix.
- Prediction stops at a bounded horizon. Missing history or a long blackout enters
  explicit resync and requests a fresh checkpoint. Connection generations and
  checkpoint serials reject delayed input/snapshot traffic from older bindings. Outstanding action IDs
  are preserved or settled explicitly.
- Per-pump byte/packet caps and per-seated-peer token buckets bound incoming processing work.
  Fixed queue/history limits return backpressure or recovery states. Consumers
  must drain presentation and action results regularly.

## Durable authority checkpoints

`checkpoint_capture`, `checkpoint_encode`, and `checkpoint_decode` produce a
versioned complete authority archive. `server_restore` starts a fresh runtime at
its exact frame under an explicitly newer epoch. It preserves roster reservations,
token hashes, room locks/bans, action received/settled frontiers and recent results,
and pending simulation decisions. The caller chooses whether queued actions are
preserved or explicitly retired. The archive uses authority projection and is
limited to 1 MiB; it must not be sent as an ordinary public snapshot.

Low-level listen hosts must call `server_set_local_token` before capture. The
Godot `Session` does this during opening. `Checkpoint` owns its arrays; keep it by
pointer, destroy it once, and never copy a live owner. Decode requires an empty
destination and expected content ID, and validates before installing any data.
Runtime callbacks, connections, snapshot caches, presentation journals, and live
allocators are rebuilt. [Recovery contract](../../docs/replay/recovery.md) specifies
the format, policies, verified guarantees, and remaining migration work.

For repeated archives, initialize a `Checkpoint_Codec` with the state/control/
action/event types and seat count, then pass it as `codec` to encode/decode.
Destroy it once with `checkpoint_codec_destroy`. It retains schema programs,
not game state. Every call still validates content, policy, values, and the
runtime contract; a cache for a different type set is rejected. The uncached
path remains available and emits identical bytes. Recovery receivers and `Link`
retain and reuse these schema programs automatically.

`client_authority` transitions a surviving client to an approved newer epoch.
Its Welcome resolves pending old IDs against the recovered frontiers, restarts
sequence allocation from the ledger, and resets prediction/presentation. Consume
`client_recovery` for Applied/Rejected/Retained/Retired/Settled_Unknown decisions.
Unknown or lost work is explicit, and already accepted IDs are not awarded twice.
See the [Room driver](../godot/room.md) for the integrated lifecycle and limits.

## Verification and current limits

```sh
nix develop --command bash tests/replay_net/run.sh
nix develop --command bash examples/replay_hello/network_run.sh
```

The engine-free suite covers join/movement/observer convergence, contested action
prediction, rollback of failed mutations, loss/jitter/duplication, blackout resync,
stable-seat reconnect, contract/token rejection, action deduplication, and forged
sender or malformed input-window rejection. Checkpoint tests cover complete private
state, promotion, pending-action policies, malformed archives, policy restoration,
new-epoch fencing, and fresh-process-style stable-seat reconstruction. It also type-checks the instantiated
runner for WASM.

The Godot gate uses four real processes: a dedicated authority, two predicting
players, and an observer. Every process has 120 ms injected receive delay by
default (about 240 ms round trip). Players move immediately, reliable firing
actions settle once, and every participant observes the authoritative shots.

Snapshots use acknowledged canonical baselines and sparse XOR deltas, with
full fallback for dense changes or missing baselines. `snapshot_history` bounds
the cache; `delta_snapshots=false` selects a full-snapshot reference mode. ACKs must
match actual sent IDs/hashes within the current connection/checkpoint context.
Facts encode only active occurrences, so empty ticks have a small header.

`egress_bytes_per_second` and `egress_bytes_per_pump` bound outbound traffic. Peer
iteration rotates; checkpoints/facts precede optional snapshots. Per-peer burst
credit is capped at a quarter-second of the configured rate or one complete
protocol packet, whichever is larger; see [delivery under transport loss](#delivery-under-transport-loss).
Deferral retains reliable work and lets newer state supersede unsent snapshots. Stats expose
full/delta counts, saved bytes, baseline misses, rejected ACKs, and egress deferral.
The protocol contract is version 7, including compact scheduled-input windows,
removal, fresh-seat semantics,
required permits, process incarnation in Hello, and [input-bound aiming context](view_time.md).
Archive format 4 preserves validated held/future view contexts, incarnation metadata
and the permit requirement. Room's identity check binds the
incarnation to the coordinator-provisioned game-token hash before admitting traffic.
Protocol-6 peers and archives require explicit conversion/update; this experimental
version does not silently reinterpret them. [Compact input framing](input_codec.md)
changes bandwidth, not input timing or the eight-sample recovery window.
Snapshots larger than `unreliable_packet_limit` (1,200 bytes by default) use reliable
delivery so large full snapshots do not depend on lossy UDP fragmentation. Small
deltas continue to use the superseding unreliable path. Each peer has at most one
unacknowledged large snapshot; new large snapshots wait for its acknowledgement.
Facts and small deltas may continue. Large snapshots use the same unreliable
latest-state ACKs as smaller snapshots, with the periodic heartbeat ACK as a
fallback. A validated baseline miss releases the gate so an undecodable in-flight delta cannot prevent a replacement full state.
This bounds ordered state backlog during bootstrap and on slow connections;
large-state update frequency is consequently limited by acknowledgement latency.

Failure-corpus expansion and admission/recovery review remain required. These tests
do not establish host migration, owner-streamed co-op, deterministic P2P, browser
runtime behavior, arbitrary scale, or parity with the full comparison games.

## Authority-side infrastructure checks

`Model.action_admit(user, seat, action)` is optional and runs only at authority
admission, after static action/time checks and sequence deduplication. Its separate
`action_admission_user` may query local infrastructure, such as validated asset
availability. Keep the query local and nonblocking; a permit is checked again
before queue mutation. Rejection is recorded as `Invalid` in the normal action
verdict ledger. Prediction, simulation replay and audit use that recorded decision
and never call the infrastructure hook. `Model.user` remains immutable simulation
configuration. Reinstall the correct model when resuming a runtime; callbacks and
pointers are not checkpoint data.

[Runner timing diagnostics](profiling.md) separate ordinary advances, snapshot
processing and correction/replay, with optional bounded raw-sample consumers.

Correction selection retains the tick associated with each canonical snapshot
cache entry. When the newest snapshot is ahead of contiguous reliable facts,
the client can apply the newest older cached snapshot whose facts are complete.
This prevents a continuously advancing unreliable snapshot stream from starving
correction until the prediction horizon is exhausted. Cache/history bounds still
apply. The first snapshot awaiting facts also remains in the pending slot even
if newer snapshots wrap the delta cache. This does not approximate missing facts
or reconstruct evicted state.

`client_outcomes` optionally reports which queued verdicts were recovered through
a Welcome/journal reset. The Godot Session facade presents those as confirmed
action-result changes, so a stale/future action verdict survives a full resync.
Ordinary fact-delivered results retain their existing presentation route.

A same-epoch Welcome rebases the existing presentation journal. Queued changes
survive, already confirmed watched effects mature at the new checkpoint, and
abandoned speculative effects receive cancellations. The runner checks output
capacity before installing the checkpoint; a full queue defers installation until
the consumer drains and the normal Resync request retries. Only newly recovered
Welcome verdicts use Session's synthetic route, avoiding duplicate confirmed
verdicts. First admission and authorized epoch changes retain their distinct
initialization/reset behavior. Unknown effects in missing history are not invented;
this preserves known obligations, not a complete effect log across arbitrary gaps.

Scheduled clients refine their welcome-time prediction lead from
[acknowledged-input turnaround and arrival margin](input_timing.md). Local send
history is bounded, stale samples are rejected, and large excess lead can drain
without retiming queued controls/actions. The existing `clock_scale` contract
remains the integration point; Godot Session applies it automatically.

## Presentation failures and catch-up

On `Error.Presentation`, `Client.presentation_failure` records the last failed
journal operation: predicted or authority batch, confirmation, or watched-clock
advance. It includes the journal's specific error, requested tick, confirmed/watch
frontiers, prediction head, queue count and occupied ring slot, with a serial that
increments on failure. It contains no gameplay payloads, is local to the client,
and is cleared on client destruction. A zero serial means no runner journal
failure was recorded; an adapter can also report undrained presentation output.

After an ahead snapshot, the pump confirms its retained facts and advances the
watched clock before rebuilding prediction lead. This permits old watched effects
to finish before the prediction ring reuses their storage. No history, output
capacity, event identity or timing policy is relaxed. Consumers must still drain
the journal after pumping/stepping; the diagnostic record is not error recovery.

A receive batch may itself span more than the fact ring, even when the transport
retained complete snapshots and every needed event. Before an incoming valid fact
would overflow that ring, the receiver tries to apply a usable retained
snapshot, mature its watched effects and rebuild prediction lead. This can release
an older complete prefix even when a later fact is still delayed. Mid-batch work
uses zero elapsed presentation time; the pump advances that clock once at its end.
If no usable snapshot can release space, the existing Facts_Overflow resync still
applies. Journal output capacity and packet/byte budgets are unchanged. See the
[receive-backlog regression](../../docs/replay/results/receive-backlog-2026-09-13/README.md).

Large snapshots can use [negotiated unreliable parts](snapshot_parts.md), with
bounded send/reassembly storage and existing canonical validation. Bootstrap,
facts and the fallback for pre-extension protocol-7 peers retain their delivery
rules. More frequent received worlds can increase bandwidth and correction cost;
measure freshness and cost together.

## Delivery under transport loss

Capable peers can use [two-erasure snapshot parity](snapshot_parts.md#negotiated-two-erasure-parity)
to complete a fragmented snapshot despite two missing shards per group. The
receiver still verifies the complete digest and canonical state. Extra parity
shares the existing egress budget; it can improve delivery under loss while
reducing send cadence. The extension is negotiated, bounded and locally optional.

Per-peer burst credit is bounded to one quarter-second at the configured rate,
or one complete protocol packet when larger. This permits bootstrap without
banking seconds of traffic for a catch-up burst. Existing steady byte budgets
remain in force.

Peers can negotiate [compact recent facts](recent_facts.md), sharing packet headers
while retaining every occurrence and the same delivery cadence. Older peers retain
the original bundle format.

Up to four recent facts may also be bundled onto the unreliable channel every
other authority tick after capability negotiation. The bundle fits the smaller
of the configured unreliable limit and 1,024 bytes. The original reliable stream
remains the guarantee; copies use normal budgets and exact-tick deduplication.
Facts that do not fit are excluded. Bundling avoids consuming one RTC credit per
copied fact. The complete bundle is validated before any contained fact commits. `Stats.redundant_facts` and
`redundant_fact_bytes` expose that extra traffic. It can shorten a retransmission
gap but is not a congestion-control or loss-free-delivery guarantee.

Peers that also negotiate fact repair (feature bit 8) request up to four missing
facts in a 32-tick window, at most once per 100 ms. The server confirms support
before requests begin. Each reply is an ordinary, independently validated Facts
packet on the unreliable channel; filtering uses the requested historical frame
and recipient. The reliable stream remains active. Missing requests/replies are
retried while a validated authority tick proves the gap exists. Duplicate requests
share the server's per-peer 100 ms limit and normal receive/egress budgets.

Replies must fit the negotiated unreliable packet limit (at most 1,024 bytes).
Oversized facts wait for the reliable stream; this extension does not fragment
facts, guarantee a maximum stall, or recover history that has expired. Binding,
Welcome serial, epoch and content checks fence old requests/replies. Negotiation
and retry state reset at each Welcome; base contract and checkpoint formats stay
unchanged. Set `client.fact_repair_enabled=false` before its first pump to disable
this extension. `Stats.fact_repair_requests`, `fact_repairs`, `fact_repair_bytes`
and `fact_repair_oversize` expose requests, accepted reply traffic and size fallback.

Before any scheduled input is acknowledged, clock feedback gradually increases
prediction lead within the configured bounds. If all initial inputs arrive
stale, the client otherwise has no echoed input to use for calibration. Once
an echo arrives, normal arrival-margin adjustment resumes. No queued action
or input is retimed.

Per-peer rate admission reserves 32 additional bytes per logical packet as modest
framing/retry headroom. Counters remain actual accepted application bytes; the
per-pump buffer budget also remains in application bytes so one maximum packet
can fit. This allowance is not a measurement of every backend's wire overhead.


## Opt-in direct-host epoch discovery

A fresh direct client may call `client_discover_epoch(client, nonce)` before its
first Hello. The nonce must be a fresh, nonzero 16-byte challenge, distinct from
its reconnect token. An unleased host opts in with `server.epoch_discovery=true`.
The query contains that challenge and the existing game contract; the reply echoes
both under the host's current epoch. The client requires the selected transport
peer, matching content/contract/challenge, a valid envelope and no installed world.
Only then does it send the ordinary epoch-scoped Hello with its reconnect token.
The query itself carries no credential and reserves no peer/seat.

This is an optional protocol-7 extension (kinds 20/21), outside the base contract
and checkpoint format. Existing explicit-epoch peers retain their handshake.
Discovery requires both endpoints to support/enable it. Unsupported or disabled
endpoints time out; the client does not fall back to a guessed epoch or older protocol. Retry uses the existing 500 ms joining cadence
and timeout; server ingress/egress budgets still apply. After discovery, subsequent
replies cannot change the client's epoch. Running/resyncing clients must use the
explicit recovery APIs for authority replacement.

This query trusts the endpoint already selected by the application/transport. It
is not endpoint authentication, election or a substitute for a coordinator grant.
Permit-controlled clients cannot enable it, and leased servers never answer it.
The Godot `Session_Options.discover_epoch` convenience option applies those rules
and generates a fresh challenge; it defaults off. Speedball enables it for direct
sessions so Join/Watch works after a manual save/resume without exposing epochs in
the game UI. See the [save/discovery result](../../docs/replay/results/speedball-save-2026-09-08/README.md).

## Prediction limits and cooperative action timing

Reaching `max_prediction` returns `Capacity` from `client_step` and increments
`Stats.stalls` while preserving the readable world, journal and queued actions.
Continue pumping. An ordinary correction or complete ahead snapshot can resume
prediction using retained facts; actual fact/history exhaustion still requests a
resync. A stalled prediction is not a fresh authority observation. Monitor both
stall attempts and received-frame progress when assessing responsiveness.

`Model.action_timing` defaults to `Scheduled`: requests target their proposed
simulation tick and stale/future requests are rejected. `Receipt` is an explicit
cooperative policy that queues a valid request for the next available authority
tick, preserving per-seat FIFO order. The client's proposed tick does not choose
the authority's execution time in that policy. Payload validation, admission,
sequence deduplication, capacity limits, gameplay predicates and atomic failure
remain unchanged. A request arriving during a cooldown may still be rejected by
the game predicate; receipt scheduling is not an automatic gameplay retry.

Clients continue predicting actions locally. Their predicted execution time/state
may differ from the authority's actual receipt-time result, so normal corrections
and event cancellation/confirmation still apply. Use confirmed presentation for
effects that must not occur speculatively. `client_outcomes` reports the actual
settled result once per sequence; receipt policy does not change control timing or
historical-query validation.

For a game with both delivery requirements, set a versioned per-action classifier:

```odin
model.action_schedule = {
    id = 0x4d5947414d450001,
    timing = proc(a: Action) -> net.Action_Timing {
        return a.kind == .Dash || a.kind == .Interact ? .Receipt : .Scheduled
    },
}
```

The callback overrides `action_timing` for validated payloads. It must be pure and
depend only on the action and immutable rules. A nonzero ID and callback must be
provided together; change the ID when the classification changes. The ID joins
the negotiated/checkpoint contract, so a peer with a different policy cannot
silently connect or restore. An unset classifier preserves existing contracts
and wire/archive layouts. Invalid timing values are rejected before admission.

Both kinds share the bounded per-seat FIFO and sequence/outcome stream. A future
scheduled action can therefore delay a later receipt-time action; the classifier
does not create a second priority queue. Only receipt-time payloads may be newly
queued during same-epoch resync. The authority records admission ticks and reasons;
correction, checkpoint restore and explicit checkpoint conversion preserve those
decisions without calling the classifier again. Host-local actions are already
at the authority and use its next available tick.

Short button presses that require a delivery verdict belong in actions. Capturing
a scheduled control only establishes local sampling: retransmission can still
arrive after that tick. Receipt scheduling avoids that deadline, while gameplay
predicates can still reject an intent, such as a dash during cooldown. Consume a
latched intent after successful queue admission and handle its settled outcome.

The action policy is part of the negotiated contract and checkpoint contract.
Scheduled mode preserves its existing contract bytes. Mismatched action policies
cannot join or restore a checkpoint silently. Checkpoint conversions compute the
target model's contract explicitly; already-admitted pending actions retain their
recorded authority schedule. The isolated endurance comparison opts into Receipt;
existing game projects keep their configured policy.

Scheduled input sampling waits when its next tick is at or behind validated
authority progress. `client.authority_tick_seen` tracks accepted snapshot,
scoped snapshot-part, and fact progress even when missing facts prevent snapshot
installation. This prevents an older correction from releasing an obsolete
input step that consumes a new press just before a newer snapshot catches up.
The caller retains pending input. Already-captured samples are not retimed,
and unreliable input still has no delivery guarantee. Latest-observation
controls retain their separate receipt-time semantics. Welcome resets the
frontier to its new scope.

Receipt-time clients may enqueue validated actions during a same-epoch Resyncing
phase when their player identity and prior binding are already established. The
existing bounded action queue owns them; no packet is sent and no prediction runs
until a new Welcome installs the binding. Original sequence IDs remain, prior
outcomes settle normally, and queued requests are then sent through the ordinary
receipt/admission path. This is queue admission, not an authority verdict.
Scheduled-action clients, joining/migrating clients, spectators, terminal phases,
invalid payloads and fenced permits keep their existing rejection rules. Capacity
and timestamp-overflow checks still apply. A later disconnect can leave an
unsubmitted intent unresolved; this is not durable input logging or guaranteed
execution after an arbitrary process crash.

## Small action copies under loss

Periodic heartbeats use unreliable delivery. They refresh liveness for the current
binding and are repeated every 500 ms; they have no ordering dependency with later
actions. The existing timeout and other validated-traffic liveness rules remain.

Capable peers negotiate recent action bundles (feature value 64, kind 25). The
server confirms that capability before the client sends a bundle. The reliable
submission and 500 ms retry path stay active. A client additionally copies up to
four oldest contiguous, already-sent requests at most once per 100 ms. The bundle
fits the configured unreliable limit capped at 1,024 bytes. Large actions retain
reliable-only delivery; the framework does not fragment these copies.

Every enclosed request retains its original generation, Welcome serial, sequence,
prediction tick and value. Copies neither retime nor predict an action again.
The receiver validates the entire bundle before processing its prefix, then uses
the ordinary admission, timing, ordering, deduplication and verdict path. Each
inner action consumes a packet credit; all actual bytes consume the existing
receive byte budget. This does not bypass authority admission or make stale
scheduled commands valid. Missing/reordered copies are retried while requests
remain pending; the reliable stream remains the delivery guarantee.

The bundle uses the generation/serial/count header already used by recent facts,
with a distinct message kind and independently enveloped canonical Action packets.
No base contract or checkpoint format changes. Welcome resets negotiation and
copy timing. Set `Client.action_copies_enabled=false` before first pump, or
`Session_Options.disable_action_copies=true`, to opt out. Scrapyard exposes
`RSY_ACTION_COPIES=0` (browser query `action_copies=0`). Counters are
`action_copy_batches`, `action_copies`, `action_copy_bytes` and
`action_copy_oversize`. Extra copies cost bandwidth and do not guarantee a fixed
latency bound during arbitrary loss or congestion.

## Receive-budget deferral

[Receive budgets preserve packets](receive_budget.md): pumps supply the remaining
byte allowance to the transport and stop on `Buffer_Too_Small`, leaving the packet
queued for the next pump. Crossing the budget no longer discards reliable facts or
actions. Existing packet/byte limits and transport storage bounds remain intact.


Latest-observation clients negotiate [packet-local sparse observations](observations.md)
when both peers support them. Canonical values, cadence, admission and checkpoint
contracts stay unchanged; old peers and dense values use the full packet.
