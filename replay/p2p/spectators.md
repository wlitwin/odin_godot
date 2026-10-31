# Confirmed P2P spectators

Use `Watch(State, Input, Event, Seats)` to show a P2P match without joining its
player roster. It consumes history already confirmed by the player protocol, sent by an
admitted source participant. The watcher occupies no player slot, samples no
input, and does not advance the players' confirmation frontier. One `Watch_Source` serves one spectator;
applications can provision several bounded source streams. The source borrows its
participant Runner and a separate transport lane or connection.

```odin
// Source participant; binding identifies this admitted spectator connection.
error := p2p.watch_source_init(&source, &peer, spectator_id, spectator_transport, binding)
error = p2p.watch_source_pump(&source, monotonic_ms)

// Spectator; use the same initial frame, model, roster and player configuration.
error = p2p.watch_init(&watch, initial_frame, model, roster, source_id,
                      spectator_transport, binding, player_config)
error = p2p.watch_pump(&watch, monotonic_ms)
frame, available := p2p.watch_current(&watch)
timeline := p2p.watch_timeline(&watch) // read-only borrow, valid until next pump
```

Keep both owners at stable addresses. Destroy with `watch_source_destroy` and
`watch_destroy`; their borrowed transports are closed separately. A source stream
must be destroyed/rebound when its participant runner or admitted connection is
replaced. The stream's session/epoch/content/binding remain fixed for its lifetime.

## Delivery and validation

Each version-1 watch record contains a confirmed base frame and its occurrence
batch, the original match contract, rolling base anchor, and later confirmed input
batches with per-tick rolling state/event hashes. It contains no speculative world,
future captured inputs, or player delivery frontiers. Its canonical encoded size
is limited to 1 MiB; count and exact-length validation precede replay allocation.

The first record selects the source's current confirmed tick. Following records
start at the spectator's last acknowledged tick and reexecute through the new
confirmed head. A shadow runtime stages the complete candidate. Installation occurs
only after every input, state/event digest and final chain passes. Overlapping
history must agree with the spectator's existing confirmed world. A changed
already-observed baseline or divergent execution preserves the previous world and
leaves a stopped error/report, rather than silently accepting the next baseline.

Delivery uses `recovery.Sender` and `Blob_Receiver`: 1,024-byte chunks, bounded
reassembly, SHA-256 integrity, explicit receipts, retries, timeout and byte/work
budgets. Metadata/schema/CRC validation remains separate from callback validation.
Lost Ready packets do not reinstall a completed record. A timeout can start a
new transfer; a rejected archive or missing retained receipt is explicit. The
source publishes at a configurable interval (50 ms by default), and only after
the previous transfer completes. This favors bounded work over minimum viewer
latency; snapshot cadence and codec/replay costs need larger-workload measurement.

The player Runner's receive/ACK frontiers remain unchanged by all spectator
traffic, even when spectator delivery stalls. Shared connections should use the
transport Router's background budgets; the Duel uses a separate ENet connection.

## History gaps and presentation

When the source no longer retains the last acknowledged frame, it sends a current
confirmed baseline. `watch.reset` supplies an increasing sequence and the previous/
new baseline ticks. `stats.skipped_ticks` records the omitted interval. The first
late join is also a reset from the known initial tick. This is an explicit spectator
resynchronization; it never changes a player's world or stalls simulation.

On a new reset sequence, seed the event journal at `baseline_tick` and reconstruct
views from the new complete world. Skip historical cosmetics through that baseline.
For later delivered ticks, consume occurrences normally; they are already confirmed.
The Duel verifies its new shot occurrences against the new baseline's shot counter.
`watch.transfer.latest.at_ms` exposes the last validated receipt time for a stale
view indicator. `watch_current` retains the last valid world when transport is lost.

## Trust and scope

The watcher validates configuration, ordered roster, content, and schemas;
the transport/admission layer must authenticate the selected source and binding.
A late spectator accepts a rolling anchor for history it never executed. It trusts
that source for the initial world: these hashes do not prove agreement of all
participants, prevent a dishonest broadcaster, or authenticate packets. Full P2P
world values are disclosed to spectators; games needing delayed disclosure or
recipient filtering need an explicit viewing policy.

Spectators can change admitted sources within a fixed-epoch match using the
continuity API below. Automatic spectator restoration after process restart,
match-recording playback UI and delayed anti-coaching feeds remain application
work. Browser viewing is implemented; browser provider integration for source
failover still needs work beyond the native test. The implementation uses
a whole-frame base and two staged value runtimes. Measure their memory and
codec costs before changing to input-only incremental records or storage reuse.

See [Replay Duel](../../examples/replay_duel/README.md) for the separate three-process
late-join/blackout test. The spectator fixture uses the same deterministic model
and Godot views as the participating players.

## Changing the source without discarding the world

After the provider authenticates a replacement participant and fences the old
connection, rebind the existing watcher at a stable runner boundary:

```odin
anchor, error := p2p.watch_rebind(&watch, replacement_source_id,
                                 replacement_transport, next_binding, now_ms)
// Send this anchor to the admitted replacement through the provider's control path.
error = p2p.watch_source_init(&source, &replacement_player, spectator_id,
                              source_transport, next_binding, resume = &anchor)
```

The binding is a strictly increasing generation for this spectator stream, even
when the physical source ID is reused. Rebind resets only the blob-transfer owner;
the last confirmed world, chain, event history and presentation-reset sequence
remain available. The caller owns both transport lifetimes. Invalid arguments,
backward time or a busy timeline leave the watcher untouched. A detected divergence
or replay mismatch cannot be cleared through this API.

`Watch_Anchor` identifies session, epoch, content, match contract, confirmed tick,
rolling chain and the state/event digest at that tick. The replacement must retain
that confirmed tick and agree with both hashes. A source still behind it returns
`Waiting`; missing retained history returns `History`; conflicting hashes return
`Diverged` without changing its player runner. The source rechecks retention before
its first publication, since history may expire while the provider connects peers.

Until the first valid record installs, the watcher refuses a base later than its
retained head. Thus an incorrect source cannot substitute a fresh baseline to
bypass continuity. Successful replay through the anchor clears `rebind_pending`
without a presentation reset or duplicated old cosmetics. Later ordinary history
exhaustion retains the existing explicit reset behavior.

`watch_anchor` also exposes the current continuity point without rebinding. Keep
control-path ordering explicit: do not continue accepting old-source updates after
publishing a point that the replacement will use. `watch_rebind` returns the exact
point it retained, avoiding that race when provisioning follows the rebind.

This is continuity validation, not authentication, source election or a proof that
all participants are honest. The native Duel fixture uses two configured loopback
participants and a private control file to exercise replacement; public spectator
admission and automatic selection remain application/provider work.
