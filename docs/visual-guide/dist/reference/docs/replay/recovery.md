# Replay checkpoint and recovery contract

A Replay authority archive lets a fresh process restore the World, player
reservations, room rules, and action frontiers from a checkpoint. Recovery
combines that state with an authorized successor, a newer authority epoch, and
a handshake that reconciles surviving clients. An archive alone does not elect
an authority or recover work accepted after its capture tick.

The implementation includes bounded replication to an explicitly trusted peer,
authenticated coordinator RPCs with SQLite storage, durable provisioning,
checkpoint publication, and cold restore. Native and browser gates cover planned
and crash handoff, old-owner return, repeated handoff, control partition, and
successor loss. The [framework audit](framework-audit.md) records the evidence
and remaining deployment/recovery limits.

The [explicit protocol-6 to 7 archive bridge](../../replay/net/checkpoint_upgrade.md)
preserves compatible Worlds while validating the old contract. It grants no
new lease; coordinated upgrade remains an application transition. Normal loaders
continue to reject incompatible versions.

## Data boundary

`net.Checkpoint(State, Control, Action, Seats)` owns:

| Section | Restored meaning |
| --- | --- |
| Version/contract | Archive version, network protocol, schema/content contract, tick rate |
| Authority frame | Exact tick and **all** state fields, including `replay:"authority"` fields |
| Configuration | History, lead/prediction limits, timing, packet and traffic limits |
| Authority identity | Previous epoch and generation counter; restore requires a newer epoch |
| Roster | Stable seats, spectator/local status, token digests, connection-generation/serial counters |
| Membership decisions | Pending join/leave/fresh-occupant masks and held controls |
| Action ledger | Per-peer received/settled sequences, accepted queues, recent settled outcomes |
| Input buffer | Accepted future input samples still relevant at the capture tick |
| Room policy | Lock, banned credential digests, custom policy ID and bounded policy bytes |

Entity IDs, pool generations, RNG, inventories, scheduled spawns, cooldowns, AI
phase, ownership versions, and game progression are restored because they live in
the complete authority frame. Game-specific state outside that frame is not
implicitly captured. Immutable definitions are selected by the application and
gated by content/schema identity.

An archive contains authority-only information and must only be disclosed to a
trusted successor. Public client snapshots are a separate codec projection.
Bearer reconnect tokens are not archived: the roster contains SHA-256 digests.
The Godot profile file retains the player's actual token separately.

Runtime connections, allocators, callback addresses, transport queues, wall-clock
timestamps, delta baselines, frame/event histories, and presentation journals are
not serialized. Restore constructs fresh owners at stable addresses. There is no
committed external-effect outbox implementation yet; do not use this archive as
an exactly-once ledger for payments, achievements, or other persistent services.

## API and ownership

For an already initialized authority:

```odin
checkpoint: net.Checkpoint(World, Control, Action, SEATS)
defer net.checkpoint_destroy(&checkpoint)
error := net.checkpoint_capture(&server, &checkpoint)
// Check error before continuing.
bytes, encode_error := net.checkpoint_encode(&checkpoint, model)
defer delete(bytes)
```

Low-level listen hosts first install their local credential with
`server_set_local_token`. Godot's `session_open` handles this. A custom admission
callback requires a nonzero policy ID when capturing; callers supply its immutable
serialized policy data. Restore requires the same policy ID and an explicitly
reinstalled callback/user descriptor. Callback addresses are never decoded.

For restore, decode into an empty checkpoint with the application's expected
content ID, then call `server_restore` into an uninitialized server. The two owned
objects must not be shallow-copied. Destroy a checkpoint once, including after a
failed read; decode failure leaves an empty destination, and decoding into an
existing owner returns `Wrong_Phase` without modifying it. `server_restore` never
overwrites an initialized server.

`Resume_Options` makes recovery decisions explicit:

- `epoch` must be strictly newer than the archive epoch. Packet envelopes use it
  to reject delayed old-authority traffic. It does not itself establish legitimate
  leadership or prevent another process from continuing independently.
- `local_seat` is zero for a dedicated authority or an existing playable seat for
  the new listen host. The Godot facade verifies its profile token against that
  reservation. Promoting a guest preserves their previous action sequence.
- `preserve_pending=true` retains accepted action values, sequence IDs, scheduling,
  and rejection reasons. The caller must choose an appropriate membership policy
  and resume schedule. `false` explicitly settles those actions as `Disconnected`
  on subsequent ticks, preserving their IDs and the action frontier.
- `retain_membership=true` preserves simulation membership while the migration
  driver pauses for peer recovery. Transport bindings still begin disconnected;
  the driver must enforce its pause/deadline policy. With `false`, formerly active
  remote seats leave on the first resumed tick. Rejoining before that tick replaces
  the pending leave. A reservation reconnect does not run fresh-player reset.

Accepted control samples can be retained with pending work, but input streams from
old connections are retired on reconnect. The promoted seat resumes local device
sampling; archived remote samples cannot override its new local input. Complete
replay of every input after a crash requires a separate accepted-decision log.

Already executed gameplay is in the frame. Recent verdicts and settled/received
frontiers prevent accepted sequence IDs from being applied again. Lost work after
the archive tick is outside this guarantee. A surviving client that observed such
work needs the recovery handshake to reconcile its newer frontier;
changing its epoch is not a complete abrupt-recovery protocol.

## Wire/file format

Archive version 4 uses the canonical `RPLY` envelope (52 bytes), custom message
kind `0x434b`, and a fingerprint of the ordered section schemas. Network protocol
version 7 and the complete runtime contract are checked inside the body. The body
contains header, settings, authority frame, held controls/view contexts, sparse roster/actions/
inputs/outcomes/bans, and opaque policy bytes, in that order.

Limits include 1 MiB total archive, 16 peer records, 16 queued actions and 16 recent
outcomes per peer, 64 bans, and 64 KiB of custom policy bytes. Future inputs are
bounded by the restored configuration and exact body length. Header/configuration
and all section sizes are checked before count-driven allocation. Field codecs
validate canonical booleans/enums/finite floats; semantic checks validate unique
seats, credential digests, action frontiers, scheduling, and outcome order. A
malformed/truncated/oversized/wrong-content archive cannot partially install a
world. The checksum detects accidental corruption; it is not authentication.

Schema/content/version mismatches currently reject the archive. There is no
automatic schema upgrade. Converters must explicitly decode an old schema,
convert the complete frame/session contract, validate the new result, and retain
the old file until a new archive has been successfully written.

The archive can exceed the 64 KiB transport packet limit. The recovery transfer
chunks it, bounds reassembly, verifies the complete archive, and acknowledges an
archive identity before considering it usable. A packet send is not a durability
acknowledgement.

## Godot persistence

`session_save` captures the authority and writes the archive. `checkpoint_read`
reads and validates it; `session_resume` opens a fresh authority with explicit
resume options. `session_profile` loads/creates a local credential and fails on an
unreadable or malformed existing file. Use distinct profile paths for simultaneous
players on the same machine.

The file adapter writes `<path>.pending`, checks the write/length/error, flushes and
closes it, then renames it onto the destination. A later interrupted staging write
does not replace a completed archive. This follows Godot's
[FileAccess flush/close](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html#class-fileaccess-method-flush)
and [DirAccess replacement](https://docs.godotengine.org/en/stable/classes/class_diraccess.html#class-diraccess-method-rename-absolute)
APIs. The adapter assumes one writer per path and an existing parent directory.
The tested boundary is process crash/restart on native macOS. Power-loss durability,
directory fsync behavior, concurrent writers, and browser persistence are not
established by these tests.

## Verified gates

```sh
nix develop --command bash tests/replay_net/run.sh
nix develop --command bash examples/replay_cavecrawl/save_run.sh
nix develop --command bash examples/replay_cavecrawl/recovery_run.sh
```

The runner has 24 native tests with allocator tracking and an instantiated WASM
type-check. Seven checkpoint scenarios cover canonical roundtrip, hidden authority
fields, promotion, pending actions, malformed/count/content/contract failures,
policy and ban restoration, new-epoch rejection, and fresh clients reclaiming
reserved seats without resetting loot. A local host credential cannot reserve a
second remote seat.

The solo Godot gate creates/replaces a save after looting, opening a door, and
throwing a rock; leaves a deliberately incomplete staging file; kills the writer;
and starts a fresh process using the saved profile. The entire restored frame's
canonical hash/tick match, and the next action succeeds without repeating old
outcomes. The co-op gate runs a host and guest at 120 ms receive delay each, saves
the guest's looted world, kills/replaces the processes, and checks guest identity,
inventory conservation, door state, and continued actions under epoch 2. It
supplies the new epoch explicitly. These gates are registered in `tests/run_all.sh`.

## Next M5 implementation sequence

1. **Bounded checkpoint transfer — implemented component:** explicit trusted-peer
   scope, indexed chunks, duplicate/reorder handling, complete validation,
   acknowledgement, and retention of the authority's last acknowledged checkpoint
   now pass eight native tests and a real ENet large-archive gate. See the
   [replication package](../../replay/recovery/README.md). Integration with gameplay
   packet routing/traffic budgets and reusable archive schema metadata now also
   exists as `recovery.Link` and the Godot Session facade. A live Cavecrawl gate
   validates gameplay and repeated backups on one connection under network faults.
2. **Authority decision service — implemented component:** the
   [authority package](../../replay/authority/README.md) defines durable CAS decisions,
   eligible successors, conservative leases, planned retirement, restart quarantine,
   and runner enforcement. [Authenticated RPCs and SQLite storage](../../replay/authority/service.md)
   now have real-process handoff and coordinator crash/restart gates. The test
   transfers the simulation. The Room driver additionally passes live Cavecrawl
   client migration; dynamic provisioning and the full failure matrix remain open.
   Dedicated competitive failover stays within trusted
   infrastructure.
3. **Recovery handshake:** coordinator-approved authority/epoch discovery, reconnect
   retries, old/new frontier reconciliation, deliberate retirement of unreplicated
   actions, and local presentation reset/cancellation at the recovered tick.
4. **Planned handoff:** freeze admission at a final tick/frontier, replicate and
   acknowledge that checkpoint, authorize the successor, reconnect, and resume.
   Verify no accepted work is omitted and old authority packets remain rejected.
5. **Abrupt takeover:** restore the newest acknowledged eligible checkpoint,
   explicitly report the lost tick interval, handle successor failure/consecutive
   migrations/old-host return, and keep divergent partitions from silently merging.
6. **Gameplay acceptance:** real-process kills during Cavecrawl combat and loot,
   then a competitive replayed example. Record interruption, rollback distance,
   checkpoint age and size, restore cost, and responsiveness after recovery.

Checkpoint-plus-log recovery, service outboxes, and broader schema upgrades follow
this snapshot-based acceptance. M5 remains incomplete until the driver, fencing,
partition policy, and real successor takeover gates exist.
