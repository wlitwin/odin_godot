# Replay transports

Use `Transport` to drive packet delivery independently of the simulation and its
network policy. It is a borrowed interface over a concrete adapter. It provides `send`,
`receive`, `poll`, `status`, `peer_connected`, and `close`. Accepted sends copy payloads; receive
copies into caller storage. `Buffer_Too_Small` retains the pending packet and
reports the required size. A peer ID identifies a transport connection, not a
stable player seat. Session admission and reconnect identity are separate work.

Packets are bounded to 64 KiB at this interface. A transport may have a smaller
configured limit. There is no implicit broadcast: callers explicitly enumerate
recipients. `Reliable` is ordered per direction/channel; `Unreliable` may lose,
duplicate, or reorder messages. Check `Backpressure` and retry according to the
session's delivery policy.

## Closing transport wrappers

A `Transport` value is a borrowed handle, so copying it never creates another
connection owner. Closing a handle invokes its adapter's close callback. Wrapper
callbacks have these specific effects:

| Wrapper interface | Effect of `close` |
| --- | --- |
| `delay_transport` | Closes its base and frees the delay queue. |
| `remap_transport` | Closes its base and clears the mapping. |
| `fragments_transport` | Frees fragmentation storage; leaves its base open. |
| `router_transport` | Closes that lane; leaves the router and base open. |

Close a forwarding wrapper as one stack; do not separately close stale copies of
its base handle. For a borrowing wrapper, destroy its dependent runners first,
close/destroy the wrapper, then close the base adapter. After closing all router
lanes, call `router_destroy` to free the router's buffers, then close its base.
These rules also apply when wrappers are composed: closing Fragments over Delay
leaves Delay open until its own handle is closed.

## Deterministic memory adapter

`Memory` owns preallocated packet storage, endpoint registration, RNG, and bounded
trace storage. Open distinct `Memory_Endpoint`s, obtain their interfaces with
`memory_transport`, and advance the network with `memory_advance`. Nothing uses a
wall clock. Close endpoints before destroying their network owner.

`Faults` controls latency/jitter in ticks, loss and duplication per 10,000 packets,
and reliable retry delay. Reliable packets remain queued through a 100% loss
blackout; unreliable packets drop. Reliable order is preserved even when later
packets become ready first. Full queues return backpressure without partial sends.

This models the service contract of reliable/unreliable channels, not ENet's
congestion/retransmission algorithm. It does not establish a real-network result.
Reproduction requires the initial config/seed, timed fault changes, input/send
schedule, and time-advance schedule. The bounded trace and its logical hash help
compare runs; `trace_dropped` explicitly reports incomplete trace retention.

```sh
nix develop --command bash tests/replay_transport/run.sh
```

## Shared packet routing

`Router` supplies two borrowed transport views over one connection. Call
`router_pump` once before pumping either consumer. Their `Transport.poll` callbacks
do not poll again, so adding consumers cannot multiply the ingress budget.
Bounded packet and byte rings preserve metadata and retain too-small reads.
Unreliable overflow drops only that lane's datagram. Reliable overflow retains one
pending packet until its lane drains, so reliable delivery is not silently weakened;
this can temporarily hold up the underlying queue. The recovery link routes
checkpoint messages to its background lane and negotiates their delivery channel
as described in the [recovery contract](../recovery/README.md#checkpoint-delivery-channel).

Both views share a token bucket and per-pump output limit. Background sends also
leave `primary_reserve` bytes available for gameplay. Callers receive backpressure
instead of an implicit send queue. `router_destroy` frees buffers but does not close
the underlying owner. Three native tests cover queue isolation, reliable retention,
wrapped byte storage, small receives, aggregate output bounds, and reserved capacity.

## Godot ENet adapter

`Enet` from `replay/godot/transport` owns a directly polled `ENetMultiplayerPeer`. It does not
install SceneMultiplayer or use Kit. Construct it with `enet_host`/`enet_join`,
then use `enet_transport`. `enet_id` returns the current connection's ID after it
connects. Host bind defaults to all interfaces; tests explicitly bind loopback.

The adapter uses channel 0's independent reliable/unreliable transfer modes, as
defined by [Godot's MultiplayerPeer contract](https://docs.godotengine.org/en/stable/classes/class_multiplayerpeer.html#class-multiplayerpeer-property-transfer-channel).
It owns/releases its peer reference, connection-tracking callables, and pending
receive buffer. Connection signals maintain a live peer set without game-script
callbacks, so disconnected recipients are rejected before sending. Polling a
disconnected peer is a no-op. ENet constructors return false on Godot web targets;
a WebRTC adapter is still required.

`Delay` is a bounded receive-delay decorator for real transports. It preserves
delivery order, packet ownership, connection visibility, and backpressure. The
Hello network gate uses it to inject 120 ms receive delay on each process.

```sh
nix develop --command bash tests/replay_enet/run.sh
```

That gate starts a server and two client processes, transfers canonical world
envelopes in both delivery modes, verifies sender metadata and decoded data, and
requires clean shutdown. It is a transport/codec acceptance test, **not** the
roadmap's server-prediction/client/observer gameplay acceptance gate.

Fresh project preparation uses a normal headless editor startup for 120 frames,
allowing queued editor work to finish. The immediate `--import` shutdown path
exhibited a first-scan crash in the existing editor integration; this remains an
explicit tooling follow-up, rather than an ignored test failure.


## Fragmentation and browser WebRTC

`fragments_init` wraps a borrowed transport whose reliable channel preserves
packet order. Both ends must use the same MTU. It copies accepted logical messages
into bounded queues, fragments up to 64 KiB, expires partial unreliable assemblies,
and retains reliable data through receiver backpressure. The live peer count must
fit `Fragment_Config.messages`, which also bounds delivery-frontier tracking.
Closing this wrapper does not close its borrowed base.

The [Godot RTC adapter](../godot/transport/rtc.md) composes fragmentation with raw negotiated
data channels and receiver credit. This additional credit prevents Godot's finite
JS ring from dropping already SCTP-delivered reliable data. `rtc_transport` is a
normal Replay interface; `Session_Options.backend = .Rtc` uses it through the same
server/client gameplay runner. Browser migration has separate
[Room acceptance](../godot/room.md); public relay/TURN deployment still needs its
own acceptance.

Fragment transmission selects queued messages by acceptance order and skips a
blocked peer/channel for the current poll. Reused array slots do not determine
send order or prevent the sender from using its remaining packet budget. The
sustained-small-message regression covers queue wrap; reliable ordering and
receiver backpressure tests remain separate checks.

## Connection generations

`Transport.generation` is an optional callback exposed through `peer_generation`.
A versioned adapter supplies a nonzero generation for each connection and changes
it when a numeric peer ID is rebound within the same open transport lifetime.
`Received.generation` carries that local metadata for received/retained packets;
it is not read from a gameplay payload and does not authenticate a member. Closing
an owner ends its borrowed handles. Generations are not persisted across a closed
transport owner or serialized in packets/checkpoints.

Memory increments the generation when an endpoint ID reopens. WebRTC uses its
peer-connection serial, including explicit replacement of creator ID 1. Healthy
signaling continuation preserves the serial. `Delay`, `Router`, `Fragments` and
`Remap` propagate the callback and packet metadata. Delayed and routed packets from
a retired generation are discarded; fragment assemblies, pending input, queued
output and delivery frontiers are retired separately for that connection. The
wrappers expose `retired` counters in their existing diagnostics.

Custom wrappers must forward the callback to retain these guarantees. An adapter
without it remains unversioned (`generation == 0`); `receive` normalizes its
metadata accordingly, preserving the old interface behavior. Such an adapter must
still fence old traffic when reusing IDs, or construct a new wrapper/transport
owner. This feature does not add reliable delivery across a disconnected session;
the enclosing protocol decides what may be retransmitted or recovered.

The transport suite checks ID reuse with delayed/queued/pending reliable packets,
partial and completed fragments, reused message IDs, outbound queues, delivery
frontiers, independent peers and unversioned-wrapper compatibility. The
[creator-recovery browser gate](../../docs/replay/results/p2p-creator-recovery-2026-09-08/README.md)
keeps a live P2P runner while the authenticated creator returns at ID 1 with a new
connection generation.

`fragments_limit_unreliable` optionally bounds staged unreliable datagrams per
recipient. Set it while the transmit queue is empty; zero leaves the ordinary
message/byte limits alone. One large logical packet remains admissible when that
recipient's unreliable queue is empty, even if it exceeds the pacing bound by
itself. Further messages wait for capacity. Reliable messages retain their existing
ordering and admission, and global memory/message limits remain in force.

RTC uses a bound of eight staged unreliable datagrams in addition to its existing
16-packet credit window. This applies backpressure before several stale snapshots
accumulate inside the adapter. It does not drop accepted packets, change wire
framing, enlarge receive buffers or prioritize away checkpoint traffic.
`Fragment_Stats.queue_limited` records those admission deferrals.

## Recording a real interface

The optional [trace package](trace/README.md) captures exact transport callback
observations with bounded owned storage and preserves nil-callback semantics.
Strict playback checks caller operations and outbound bytes without opening a
real endpoint. Caller marks can record pump times/configuration; the Claimball
observer fixture also compares per-frame state and effect hashes.
