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

The default limits retain up to one million events and 64 MiB of payloads.
Reaching capacity or failing an allocation stops recording without changing
underlying sends, receives, or return values. The resulting incomplete log
cannot be encoded or replayed as a complete record. Recording adds allocation
and copy work, so account for that cost when measuring the wrapped system.

Destroying the log releases its storage only; closing through the wrapper
forwards to the endpoint. The caller controls capture/log lifetime and must
stop using borrowed handles before destroying them.

`encode` writes a versioned canonical representation, independent of native padding
and endianness. `decode` checks limits before allocation, validates entry/payload
bounds and preserves the destination on failure. Its digest detects corruption; it
is not authentication. Packet payloads can contain credentials or private game data.
Treat recordings accordingly and share only authorized test data.

`replay` exposes the same callback presence and returns recorded observations.
It checks operation order, destinations/channels, outbound bytes, and receive
buffer capacity. On a mismatch, it retains the first error and its cursor
position. `finished` requires the entire record to be consumed without error.
User marks can describe pump times and configuration; `next_mark` looks ahead
and `read_mark` consumes one. Do not mutate or destroy a log while replay
borrows it.

To reproduce a caller, restore its configuration, model, clocks, local inputs,
and other external decisions alongside the transport log. Strict replay returns
recorded observations and checks that the caller makes the same calls; it does
not compute new server responses when outbound traffic changes. A different
harness can replay only incoming data, but that does not establish the same
call-sequence agreement.

The Claimball observer fixture uses marks for client configuration and each actual
pump time, then checks state/effect hashes against a standalone replay. This keeps
Godot rendering and live ENet scheduling out of receiver reproduction.
