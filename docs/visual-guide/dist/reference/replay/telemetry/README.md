# Session round-trip telemetry

`Diagnostics` owns optional connection measurements outside the simulation,
checkpoint and rollback timeline. Initialize/destroy it beside the session, add
`session_diagnostics_enable(&options)` before opening, and call
`session_diagnostics_frame(&diagnostics, &session)` after each outer session pump.
`read(&diagnostics, seat)` returns presence, known status, milliseconds and age.
Godot is optional: the core accepts an admitted roster and borrowed Transport.

The authority sends an unreliable probe and measures its echo using only its own
monotonic clock. Once per second it distributes a bounded 16-seat report to admitted
players and observers. This is application round-trip time, including both peers'
pump cadence and queues. It is neither pure network RTT nor input-to-visible delay.
The local authority reads zero; unmeasured or stale peers read unknown. Spectators
receive reports without creating player rows. Dedicated authorities have no row.

One outstanding probe per peer is retained for up to five seconds so long round
trips can complete. A lost probe may delay the next sample by that interval; the
next report follows within one second. Samples/reports expire after five seconds.
Backpressure does not start a measurement; lost reports are replaced by the next
report. Metadata uses a separate versioned packet kind on the session router's
shared background budget. Enabling it adds traffic and some work to the outer
callback; it does not modify gameplay protocol or checkpoint versions.

The admitted transport peer, connection generation, room, content and authority
epoch scope every packet. Clients only echo current-authority probes and accept
current-authority reports; they cannot write a peer's reported ping. Duplicate
nonces/reports and malformed rows are rejected. This is diagnostic metadata, not
an anti-cheat latency certificate: a participant can delay its own replies.

Fencing disables output/readback and clears measurements. Replacing authority,
connection or scope starts fresh; long local pump stalls discard outstanding
measurements. Baseline Resyncing on an admitted connection stays eligible. No
telemetry state is restored from a save or transferred to the successor.

Bounds: 16 peers, 16 seats, 64 received packets per frame, at most one probe and
one report per peer per second, each packet at most 512 bytes. The component owns
only its schema allocation and fixed buffers; it never closes its borrowed wire.
Run `nix develop --command bash tests/replay_telemetry/run.sh` for deterministic
memory-transport checks and the WASM check. Actual native/browser integration
coverage is recorded with the Scrapyard tally evidence.
