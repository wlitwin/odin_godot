# Bounded transport recording and strict replay

This optional package records a borrowed `Transport` interface and replays its
observations without opening a real endpoint. It records send attempts/results,
receive capacity/results/payloads, polling, status, connectivity, generation queries
and close. Nil callbacks remain nil: fallback status and generation behavior stays
with the ordinary Transport helpers. Payload bytes are copied into owned storage.

```odin
log: trace.Log
assert(trace.init(&log))
capture: trace.Capture
wire := trace.capture(&capture, &log, existing_transport)
// Use wire with the normal caller. Caller marks can record clock/configuration.
trace.mark(&log, 1, now_ms)
```

Limits bound retained event count and payload storage (default one million events
and 64 MiB). Capacity or allocation failure stops recording; it does not change
underlying sends, receives or return values. Such logs cannot encode or replay as
complete records. The wrapper adds allocations/copying and is not performance-neutral.
Destroying the log frees only its storage; a close through the wrapper forwards to
the endpoint. The caller owns the capture/log lifetime and must stop using borrowed
handles before destroying them.

`encode` writes a versioned canonical representation, independent of native padding
and endianness. `decode` checks limits before allocation, validates entry/payload
bounds and preserves the destination on failure. Its digest detects corruption; it
is not authentication. Packet payloads can contain credentials or private game data.
Treat recordings accordingly and share only authorized test data.

`replay` exposes the same callback presence and returns recorded observations.
It checks operation order, destinations/channels, outbound bytes and receive buffer
capacity. The first mismatch is sticky and identifies the cursor/error; `finished`
requires full consumption without error. User marks can describe pump times and
configuration; `next_mark` looks ahead and `read_mark` consumes one. Do not mutate
or destroy a log while replay borrows it.

A transport recording alone does not reproduce its caller. The caller must restore
its configuration, model, clocks, local inputs and other external decisions. Strict
replay verifies the captured call sequence; it is not a counterfactual server that
reacts to changed outbound traffic. Broader replay can deliberately use a different
input-only harness, but must state that distinction.

The Claimball observer fixture uses marks for client configuration and each actual
pump time, then checks state/effect hashes against a standalone replay. This keeps
Godot rendering and live ENet scheduling out of receiver reproduction.
