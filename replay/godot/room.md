# Coordinator-driven game rooms

Use `Room(State, Control, Action, Event, Seats)` when a game needs
coordinator-approved authority and host migration. It combines an authenticated
coordinator client, a time-limited authority lease, independently owned prepared
checkpoints, and the gameplay `Session`. It runs
initial hosting/joining, periodic trusted backups, planned handoff, abrupt takeover,
old-owner rejoin, and surviving-client redirection.

[Dedicated infrastructure rooms](dedicated.md) keep authorities and standbys
avatarless through bootstrap, failover and return; authenticated member identity
is independent of a playable seat.

Gameplay can use native ENet or authenticated RTC. The control connection can
use ENet or WebSocket (`control_backend = .Websocket`, with a full URL in
`coordinator`). For RTC, set `session.backend = .Rtc` and `session.rtc.url` to the
trusted signaling provider. Room derives the authority-specific room code from
the verified view and supplies its challenged authorization callback.
Member IDs/keys/game tokens remain provisioned. Browser Room instances use the
[paired clock](../authority/paired_clock.md) and Godot cryptographic nonces. It obtains fresh process
incarnations through the [registration handshake](../authority/registration.md).

```odin
options := replaygd.Room_Options{
    identity = provision.identity,
    key = provision.control_key,
    room = provision.room,
    coordinator = provision.coordinator_address,
    control_port = provision.control_port,
    bootstrap = provision.bootstrap,
    session = replaygd.SESSION_OPTIONS,
}
options.session.network = game_network_config
options.session.token = player_game_token
options.session.replication.accept_checkpoints = true // trusted successor opt-in
options.successor = provision.successor
options.successor_seat = provision.successor_game_seat

error := replaygd.room_open(&room, initial_frame, model, options)
// Every frame: room_frame, then consume changes from room.session.
error = replaygd.room_frame(&room, delta_seconds, controls)
count := replaygd.session_changes(&room.session, changes[:])
frame, valid := replaygd.session_state(&room.session)
```

Gameplay still uses the same typed controls/actions/model. `room_issue` sends an
action, and `room_handoff` requests a planned transfer. Dispose with `room_close`.
`room_save` requests a [durable service checkpoint](room_save.md); optional automatic
publication runs in `room_frame` alongside the existing lease and migration work.
Trusted Party members can also [resume published progress](room_restore.md) from a
fresh process when no live authority remains, using a new fenced grant.
Runtime owners remain at stable addresses; models/immutable asset descriptors must remain
valid across role changes. A selected successor receives complete authority data.
The room does not choose arbitrary peers or grant hosting permission itself.

## Transition behavior

The coordinator's authenticated live view determines the endpoint and epoch.
Clients reconnect their gameplay transport while retaining their runtime and old
action/presentation ledgers. A lower restored connection generation is valid in a
new epoch; old-epoch traffic remains rejected. Initial joins still require a valid
Welcome before exposing a world. A recovering client can retain its previous frame
for presentation until the new checkpoint arrives.

`net.client_authority` quarantines outstanding actions. The new authority's durable
received/settled frontiers classify each old ID as Applied, Rejected, Retained,
Retired, or Settled_Unknown. Retained commands await the authority's verdict;
unreplicated commands are not blindly retried. New sequence numbers start from the
recovered ledger, so losing an old suffix does not create a permanent sequence gap.
The epoch distinguishes newly issued IDs from retired ones. Unconsumed outcomes
and presentation changes must be drained before changing authority.

The low-level client exposes `client_recovery`; Session captures its latest report
and increments `recovery_serial`. A promoted client also receives reconciliation
against the prepared checkpoint. The old owner retains its local pending ledger
when becoming a client, so its new Welcome resolves those IDs too.

Presentation resets close retained old-epoch effects with Cancel changes, including
confirmed continuous effects. They do not replay the new checkpoint's historical
cosmetics. Applications should treat cancellation of an already-finished one-shot
as harmless and derive ongoing world presentation from the current frame. Counters
or action UI keyed by sequence must include epoch; Cavecrawl now does this. These
cosmetic resets do not implement an external persistent-effect outbox.

Planned handoff waits for local queued commands to settle, then freezes gameplay
with a phase-aware permit while retaining control-plane renewal of the owner's
lease. The frozen owner drains unadmitted gameplay traffic so a full primary queue
cannot block checkpoint acknowledgments on the shared transport. Neither draining
nor renewal advances the world or admits new commands. Once the successor has
prepared the exact acknowledged final point, the owner retires its lease and
release/claim establishes the newer epoch. The old host can then rejoin as a player.
The phase gate is reinstalled after runtime replacement for subsequent handoffs.
Successor loss or a failed final transfer stops renewal and enters fenced owner
recovery; it does not resume the retired epoch. In-flight accepted remote
commands are explicitly retired by this profile's restore policy; their IDs and
verdicts remain accounted for. Abrupt takeover uses the latest owned, coordinator-
accepted checkpoint after lease expiry.

A transition checks its lease after Room's initial preflight. If a valid clock
reaches the deadline between those checks, Room keeps the old runtime/prepared
checkpoint, marks gameplay fenced and waits for fresh authenticated control
progress. It does not extend that deadline, reset the lease clock or count the
transition as complete. Poisoned clocks and unrelated failures remain fatal.
Redirect, old-owner rejoin, takeover and published-checkpoint installation use
this handling. See the [transition-expiry regression](../../docs/replay/results/room-transition-expiry-2026-09-13/README.md).

`Room.phase`, `control_error`, and the underlying Session's fenced state describe
progress/failure. The driver keeps the control connection alive while gameplay is
fenced and retries disconnected transports. A surviving owner that loses its lease
may request a new epoch from the coordinator using its retained world, provided no
successor has already won. This never revives the expired epoch. A granted successor
renews its reservation while it finishes installing the runtime/presentation.

## Recovery measurements

A rejected `Claim` returns the driver to Following so it can prepare newer
replicas. Retrying the same rejected point would prevent preparation from making
progress even while checkpoint transfer continued. `last_command`/`last_result` retain the latest
completed coordinator decision, and `claim_rejections`/`busy_claims` count rejected
attempts. These diagnostics are distinct from `control_error`, which reports
local RPC/control operations. Coordinator fencing and rollback limits are unchanged;
a failed claim does not make an old archive eligible or establish authority.

`examples/replay_quickdraw/early_claim_run.sh` injects an early signed claim while
the owner is live, requires a Busy response followed by a newer prepared point,
then kills the owner after tick 600 and checks continued combat. The controlled
failure before the fix froze preparation at sequence 2 while transfer advanced to
sequence 72. Both normal and gameplay-fault runs pass after the change.

`Room.recovery` reports source/destination epochs, the actual approved checkpoint
tick, previous locally confirmed tick, known lost ticks, archive bytes, and observed
protocol interruption. `install_us` measures elapsed wall time of the successful
authority-runtime replacement call, including archive decode and runtime setup;
it is not CPU time or total disruption. Takeover can reuse the receiver's existing
checkpoint schema cache before releasing the old Session. The checkpoint tick is distinct from the later Welcome tick
when the guest finally joins. `known_lost_ticks` cannot describe work no participant
reported; it is not proof that unobserved work was preserved. Interruption is measured
from the local recognition of fencing/transition until the replacement is usable,
not from an unknowable remote crash time or a physical input-to-display measurement.

Cavecrawl displays reconnect/host-change feedback and notes known rollback. Its
four-process gates run coordinator, initial host, trusted successor, and a third
guest. The guest loots and opens a door, stays alive through migration, retains its
bag, and performs a newly acknowledged action in epoch 2. Planned mode additionally
checks that the old host rejoins; crash mode kills it.

```sh
nix develop --command bash tests/replay_migration/run.sh
nix develop --command bash tests/replay_migration/crash_run.sh
```

Both passed with 120 ms gameplay receive delay on each process. An additional
planned run passed with 20 ms jitter, 10% loss, and 10% duplication. Individual
receipts included checkpoint 112 / zero known lost ticks / 436 ms local interruption
for planned transfer, and checkpoint 101 / six known lost ticks / 558 ms for crash
recovery. These are scenario receipts, not latency percentiles or a full comparison.
The coordinator explicitly reported Planned versus Abrupt recovery in the matching
gates. All original games remain separate.

Quickdraw now exercises the same driver during active hitscan/lob combat:

```sh
nix develop --command bash examples/replay_quickdraw/migration_run.sh
```

The successor compares its installed baseline with the exact coordinator-approved
frame containing live projectiles, a pending respawn, weapon cooldowns, equipment
and collision history. Surviving clients then land fresh historical-query hits,
settle a new purchase and compare canonical world digests at a common tick. Planned
mode also checks the old host's stable seat and restored mixed presentation policy.
The harness separately measures trigger-to-ready time on the same machine, so lease
expiry/discovery time is visible alongside Room's narrower interruption metric.
The test's two hosting members are explicitly trusted; this does not authorize
passing competitive authority secrets to an arbitrary player.

## Remaining M5 work

Replay Slopball additionally exercises planned and crash migration while an
owner-streamed RigidBody2D is moving. The successor checks the exact approved world,
reseeds pose and momentum, accepts fresh ownership scopes and continues kicking/
scoring. Surviving peers compare whole-world hashes at a common tick. See
`examples/replay_slopball/migration_run.sh`. This restores accepted engine state;
it does not replay or transfer Godot solver contact caches.

- Public room/invite deployment and richer lobby controls; known-member process
  registration and endpoint rebinding exist.
- Broader failure timing/topology coverage beyond the tested successor loss,
  repeated handoff, isolated-host control partition, and returned killed host.
- Recovery during the remaining combat/loot scenario corpus beyond the initial
  Cavecrawl and Quickdraw gates.
- Broader error/retry UX and platform/network reachability coverage.
  [Dedicated-server policy](dedicated.md) has its own integration gates.
- External outbox/idempotency integration where games need persistent services.

These gates cover the scenarios described above; the remaining migration and
roadmap cases need separate acceptance.

## External checkpoint dependencies

`Room_Options.preparation_ready(user, point, bytes)` may gate coordinator preparation
on external dependencies. It receives an already validated candidate archive as a
read-only borrow; it must not mutate it or retain the slice. The application can
memoize dependencies by point and service their asynchronous loading outside the
simulation. Nil keeps the ordinary checkpoint-only behavior.

An incomplete candidate may be replaced by a newer fully received archive while
its dependencies load. This avoids waiting indefinitely on an obsolete candidate.
An incomplete newer candidate does not invalidate a previously prepared point.
If the lease expires and the service still approves the older point, Room discards
the incomplete candidate and claims that approved point. This preserves the stated
rollback boundary; it does not claim that unavailable content has been recovered.
Applications must retain the dependencies of every point they advertise as prepared.

## Displaying backup preparation

Use the [backup-status observation](room_backup.md) for waiting, transferring,
approved, stale and uncertain states. It retains accepted coordinator metadata
across pending requests and does not modify authority decisions or permits.
