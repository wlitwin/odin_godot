# Deterministic peer rollback — initial runner

Use `Runner(State, Input, Event, Seats)` for a fixed-roster match whose peers
replay the same deterministic simulation. The runner schedules steps and manages
input delivery, prediction and rollback independently of the server-authoritative
runner. Each participant owns its input stream and simulates the same complete
match. No participant supplies authoritative state corrections to another.

```odin
model := p2p.Model(World, Input, Event, 2){
    step = step_world,
    input_valid = valid_input,
    state_valid = valid_world,
    hold = predict_missing_input,
}
error := p2p.init(&peer, initial_frame, model, roster, local_slot, transport)
error = p2p.pump(&peer, monotonic_ms)
result := p2p.advance(&peer, sampled_input)
// Consume device edges when result.captured. Consume the clock tick on success.
// Waiting preserves the already captured future input and stalls simulation.
```

The roster is ordered, fixed and supplied by an external admission/transport
provider. Slot numbers are zero-based. Transport peer IDs determine input ownership;
packets cannot name another slot. The native Godot example establishes two peers
through an ENet listening/dialing pair. Listening chooses the transport topology,
not a simulation authority. A larger roster requires full-mesh delivery through the
transport abstraction. Native tests exercise two- and three-peer meshes.

## Input and confirmation contract

- Session/epoch/content, ordered roster, schema, tick rate, delay, history,
  prediction limit and initial state hash are gated before play.
- The first `delay` ticks after the initial checkpoint use known neutral input.
  `advance` captures one immutable local sample for `head + delay + 1`. A repeated
  call while stalled does not replace that sample. `Result.captured` identifies
  the capture boundary for short presses; it is separate from successful stepping.
- Peers resend bounded windows from their oldest unacknowledged input. ACKs describe
  received input, not simulated or globally committed gameplay. Out-of-order
  receipt advances a contiguous frontier only when all earlier samples exist.
- Missing remote input is derived with `hold(previous)`. A changed late input
  replays the complete affected suffix, refreshing guesses from actual received
  samples. `replay.revise_inputs` commits that suffix transactionally without
  incorrectly confirming still-guessed earlier ticks.
- Confirmation advances only through ticks whose inputs from every participant
  are known. The prediction horizon bounds how far simulation can run ahead.
  Blackout exhaustion returns Waiting; it does not approximate a resync from one
  peer's world. Local input history is also retained until peers acknowledge it.
- A rolling checksum chains every confirmed canonical state and occurrence batch.
  Disagreement produces a Diverged phase and mismatch tick/peer/hash diagnostics.
  Conflicting values for an already received input fail the match. The runner
  does not silently pick a winner or merge states.

The wire uses canonical RPLY framing, fixed-size input windows and bounded decode
storage. Input schemas are limited to 256 wire bytes; packet size is at most 8192
bytes. The pump receives at most 64 packets per call. Configuration allows 2–8
seats, 32–1024 history frames and a prediction+delay horizon below history capacity.
Runtime owners contain allocations and must remain at stable addresses.

## Determinism and trust

The runner rejects float-bearing state/input/event schemas and platform-sized
integer fields. This is a useful constraint, not proof of a deterministic callback:
authors must avoid hidden state, floating intermediates, unstable ordering and
external side effects. `replay/deterministic` supplies checked Q24.8 operations and
integer queries; the duel uses fixed-width values, deterministic pool allocation
and frame-owned RNG. Native arm64 and freestanding WASM execute the same four-seed
2,400-tick corpus to identical canonical state/event hashes.

Checksums are consistency diagnostics, not authentication or cheat resistance.
The transport/roster provider must authenticate peers for deployments that need it.
A peer can withhold inputs; the chosen policy stalls and ultimately disconnects
after timeout. That does not establish fair-play adjudication.

## Archives and participant recovery

`archive_capture`, `archive_encode`, `archive_decode` and `restore` preserve the
complete retained execution and protocol state. An archive contains its oldest
retained frame and occurrences, subsequent input batches and per-tick digests,
confirmed rolling hashes, speculative suffix, captured future local inputs,
sparse received inputs, receive/ACK frontiers, roster and original match contract.
Archives own their storage; destroy them with `archive_destroy`. The transport
and callback/user pointers are supplied afresh and are never serialized.

```odin
archive: p2p.Archive(World, Input, Event, 2)
error = p2p.archive_capture(&peer, &archive)
bytes, error := p2p.archive_encode(&archive, model)
// Persist bytes with an application save boundary, then release owned storage.
// Decode into an empty Archive; restore into an empty, stable-address Runner.
report: p2p.Replay_Report
error = p2p.restore(&fresh_peer, &archive, model, roster, local_slot, fresh_transport,
                    report = &report)
```

The version-1 archive envelope is canonical, content/schema gated and limited to
16 MiB. Counts and exact payload length are checked before count-driven allocation.
Restore validates frontiers and reexecutes the retained input sequence before
installing the runtime. A changed model produces `Replay_Mismatch` with the first
retained failing tick and expected/actual digest; failure releases staged storage.
The rolling hash at a wrapped base is an anchor for earlier history, not a replay
of that discarded history. Archives contain complete private world data, and CRC/
hash checks provide integrity diagnostics, not authenticity.

Participants may restore together on fresh transport bindings, or one participant
may restore while survivors retain their live runners and explicitly reconnect.
Saves may have different receive/confirmation frontiers:
protocol version 2 exchanges each peer's durable received frontier in Hello and
resends any formerly acknowledged suffix it still retains. If a peer has received
local inputs that this archive forgot, or the required retransmission history is
gone, recovery fails with `History`. Old captured inputs are never regenerated.
The admission provider must exclude old connection traffic and rebind the same
ordered logical identities. `transport.Remap` supplies explicit, one-to-one logical
to physical bindings; it does not authenticate them.

For a live rejoin, restore the returning participant's own archive, then call
`reconnect(&survivor, replacement_transport, monotonic_ms)` on every affected
survivor after the provider verifies the replacement bindings. This restarts Hello
and its retry/timeout clock while retaining the survivor's exact timeline,
captured inputs, ACK/receive frontiers, checksums and allocations. Advancement waits
for the roster handshake. Reconnect is permitted after a timeout (`Disconnected`)
or during a running/connecting session, at a settled runner boundary. It refuses
failed/divergent runners, an active timeline operation, unresolved input repair,
backward time and missing transport callbacks. Both transports are borrowed;
the caller owns their lifetimes and retirement.

```odin
// Provider has authenticated the same ordered identities and fenced old traffic.
error = p2p.reconnect(&survivor, replacement_transport, monotonic_ms)
// Continue pumping and advancing normally once phase is Running.
```

The native Duel exercises either participant returning. When the original
listener returns, the surviving dialing process closes/reopens its ENet transport,
rebuilds logical mappings and reconnects the retained runner even though the
remote physical server ID is again 1. Closing the transport owner retires the old
receive/delay buffers. This configured loopback provider is not authentication or
source election; see the example's native creator-rejoin gate.

This requires a compatible durable archive. If a crashed player continued sampling
after its last save, survivors may have inputs that the archive no longer contains;
that recovery fails with `History`. A retained input log or another compatible save
boundary is needed to cover that crash window. Reconnect does not choose another
peer's world, change the roster, elect an authority or recover forgotten inputs.
Caller verification and old-traffic exclusion are requirements, not services
implemented by this function.

Capture a settled `Diverged` runner to retain its mismatch metadata and local
execution. Replaying with its original deterministic callback reproduces that
execution and preserves the stopped phase. Replaying with a changed callback
locates the first different retained state/event digest; it does not identify the
root cause or prove that either participant was correct. Callback code is not
serialized, so keep the corresponding build/content version with a recording.
The Duel includes an offline [verifier](../../examples/replay_duel/verify.sh).

The two-process Godot recovery gate saves at speculative tick 240, kills both
processes, binds fresh ENet IDs, restores and continues to tick 600 with reference
world and occurrence reconciliation checks. Native-created session/divergence
archives also decode and replay inside freestanding WASM to identical reports.
The separate native `rejoin_run.sh` saves and kills only the dialing participant,
keeps the listener alive through timeout, and restores against a new ENet binding.
Both reach the same tick-600 world and reconciled occurrences. A three-player
native/WASM corpus exercises two successive individual rejoins after timeout under
four loss/jitter/duplication seeds, in default and speed builds.
The browser Duel also exercises a single returning participant in fresh Chrome:
its Save & pause control freezes capture before download, the process is killed,
and its file is imported while the other browser retains the running match.
The joining player receives a new physical RTC ID, rebound to its logical roster
slot. The authenticated provider also supports the creator returning at the same
ID 1 with a new connection generation. Delay/fragment/router buffers fence retired
work; either survivor retains its runner. Both reach the tick-600 reference world.

## Implemented envelope and remaining M7 work

The initial runner, integer duel, loss/reordering/duplication tests, timeout,
divergence checks and native two-process ENet gate exist. A lost input burst
recovers through retransmission and bounded rollback. The Godot demo reconciles
speculative events and compares the final world with an independent reference.

Confirmed [spectators](spectators.md) join a running match, replay received
history, and reset explicitly after a blackout exceeds retained history. They use
separate bounded transfer streams and never join the player confirmation roster.
An admitted spectator can rebind to another participant using a retained
state/event/chain anchor. The replacement must prove overlap; missing history or
conflict is explicit. Native Duel and repeated native/WASM source-switch gates
exercise this [continuity contract](spectators.md#changing-the-source-without-discarding-the-world).
Optional [profiling](profiling.md) separates forward/replay/hash/pump wall time from
capture-to-simulation input latency. Standalone benchmarks measure process CPU and
the effect of fixed input-delay settings using matched recorded gameplay.

An initial [authenticated admission provider](admission/README.md) checks
fixed-roster credentials before initial binding and browser rejoin. It reuses the
bounded challenged signaling frontend and supports full-mesh introductions.

[Fixed-roster provisioning](provision/README.md) supplies durable room/invite
enrollment, exact retries and authenticated incarnation changes. Its native TLS
service/client and SQLite crash gates pass. The [P2P party client](../godot/p2p_party.md)
connects browser Duel's invite menus to authenticated gameplay and fresh-process
guest/creator return. The native [P2P Direct owner](../godot/p2p_direct.md) supports authenticated two-player ENet and fresh-process endpoint replacement.

Roster changes, public authenticated provisioning,
cross-native-platform execution and deployment integration remain pending. A
copied Frame alone does not resume this session protocol. The fixed-point corpus
and archive replay execute in WASM. The playable Duel also passes real WebRTC
Chrome-process gates for delayed/lost inputs, a bounded blackout, late spectator
reset and coordinated participant-file restoration. Public rendezvous/TURN and
other browser engines are not established by these local gates.
The archive retains a bounded diagnostic window, not a complete input/arrival log
for arbitrarily long matches. Broader recording tools and field-level diffs remain
debugger work.

See [Replay Duel](../../examples/replay_duel/README.md) and the full
[roadmap](../../docs/replay/roadmap.md). These tests cover the implemented fixed-roster contract; the remaining P2P
capabilities and Replay roadmap work need separate acceptance.
