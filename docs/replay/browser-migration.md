# Browser authority migration work

Browser authority migration must preserve the native Room's lease, recovery,
and fencing rules. WebRTC packet exchange or a working P2P duel alone does not
validate those requirements.

Implemented and tested prerequisites:

1. Raw WebSocket control transport, including binary/text separation, bounded
   queues, full-size packets and retained small reads.
2. A real Chrome client obtains signed grants from the native SQLite-backed
   authority Service; a corrupted MAC is rejected. Control reconnection preserves
   the RPC nonce/sequence state.
3. Native Room can use WebSocket control while retaining ENet gameplay. Planned
   and crash handoff use the existing checkpoint/lease/session machinery.
4. Paired wall/monotonic clock implementation and explicit failure semantics.
5. Pure challenged rendezvous signing/verification: room creation requires the
   current approved owner, rather than possession of a room code.

The native challenged signaling frontend and RTC authorization callback are now
implemented. A three-browser gate rejects non-owner creation, duplicate creators,
proof replay across connections and expired challenges, then exchanges full-size
game packets. Room owns its browser clock, nonce provider, copied RTC configuration
and grant authorization through role changes. `Migration_Transport` explicitly
describes the RTC destination as a trusted provider URL plus a code derived from
the signed view. This preserves the coordinator wire and durable-record formats.

The actual Cavecrawl browser project passes planned handoff and killed-host
recovery with a surviving guest, preserved inventory/seats, and new accepted
actions. Planned mode also rejoins the old host. The gate additionally covers
two handoffs, control partition/fencing, successor loss during handoff and a killed
host returning with a fresh incarnation. Monotonic driver receipts distinguish
fault-to-action time from the narrower Room timer.

Additional verified integration:

Coturn relay gates pass Cavecrawl over UDP/TCP and Scrapyard's asset-aware
combat flow over UDP. Selected browser candidate pairs and Coturn logs prove relayed
traffic at join, handoff and rejoin. Incorrect relay credentials do not fall back to
direct gameplay in relay-only mode. See [relay evidence](results/turn-relay-2026-09-07/README.md).

The [online Cavecrawl menu](../../examples/replay_cavecrawl/online.md) now creates,
joins and durably rejoins parties through the standalone room service. A real
Chrome gate covers automatic successor selection, a zero-loss handoff and concurrent
isolated rooms. This uses explicit loopback WS with RTC gameplay; public WSS/TURN
deployment is still separate work.

Remaining acceptance and integration:

- Public account/room provisioning and trust boundaries. Authenticated
  signaling-only reconnect now preserves healthy channels and peer IDs; broader
  network/provider-outage envelopes still need measurement.
- External asset dependencies and gameplay recovery in richer browser game ports;
  broader workloads and repeated timing measurements for the existing failure matrix.
- Browser sleep/clock anomalies, deployed TLS/TURN configurations, and
  additional browser engines.
- Broader interruption measurements, including time before local fencing, and
  checkpoint age/lost ticks/transfer size under representative gameplay.

These remain required work; local planned/crash success does not establish the
remaining failure matrix or public deployment envelope.

See [WebSocket](../../replay/godot/transport/websocket.md),
[paired clock](../../replay/authority/paired_clock.md) and
[rendezvous](../../replay/authority/rendezvous.md) for current APIs and limits.
These local results do not complete another milestone. The remaining gates
still belong to the active M0–M9 objective.
