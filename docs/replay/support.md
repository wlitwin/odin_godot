# Replay support and compatibility

Replay is experimental. Choose a runtime, transport, recovery policy, and target
together, then measure that configuration with your World and workload.

## Runtime choices

| Mode | Available behavior | Requirements |
| --- | --- | --- |
| Local value simulation | Timeline history, correction, pools, RNG, recordings | Explicit bounded value state; every mutable simulation dependency belongs in World |
| Authoritative networking | Host/server/client/observer roles, action delivery, prediction, recipient filtering | Trusted authority, authored input validation, versioned content and schema |
| Cooperative owner physics | Body2/Body3 observations and ownership transfer | Trusted owners; Godot contact solving cannot be deterministically replayed from poses |
| Room recovery | Checkpoint-backed planned handoff and crash recovery | Reachable trusted coordinator, authority fencing, eligible complete backup |
| Deterministic P2P | Fixed-roster input exchange, rollback, participant archives | A deterministic game model on the selected targets; sufficient input/history retention |
| Provisioned native P2P | Two-player TLS enrollment and encrypted ENet pair flow | Configured reachable endpoints; automatic NAT traversal is unavailable |
| Browser P2P | Authenticated RTC mesh and participant recovery | Fixed roster, signaling, relay configuration, enrollment, and retained participant history |

## Platforms and transports

The current `replay/godot` Session package imports the native Box3D presentation
adapter. A fresh Session build requires a selected Box3D backend, including for
games that do not simulate physics. The [Session tutorial](godot.md) includes
this setup. The core local Timeline has no native physics dependency.

The main Godot runtime coverage is macOS arm64 with Godot 4.7.1 and Chrome.
Standalone WASM and translated x86 binaries have focused coverage; independent
Linux/Windows hardware and other browser engines need deployment validation.

Native sessions use ENet; browser sessions use WebRTC. A native ENet peer cannot
join a browser RTC peer directly. Mixed native/browser sessions require a common
backend and the appropriate native RTC extension. Plain ENet is unencrypted.
Steam integration remains experimental and needs live multi-account validation.

## Runtime bounds

| Surface | Limit |
| --- | --- |
| Local Timeline | 2–4096 history frames; 0–4096 events per tick |
| Authoritative runner | 1–8 playable seats; 16 peer records; 16 queued/recent actions per peer |
| P2P runner | 2–8 participants; 32–1024 history frames; input encoding up to 256 bytes |
| P2P history configuration | Input delay + prediction + 2 must fit the history window |
| Complete authority checkpoint | 1 MiB |
| P2P archive | 16 MiB |
| Transport packet ceiling | 65536 bytes, with additional per-lane budgets |

These are storage and validation bounds. Measure memory and correction time for
your concrete World, inputs, events, history length, and hardware. Box3D has its
own [bounded runtime profile](../box3d/support.md).

## Recovery and services

Crash takeover can lose work newer than the newest usable accepted checkpoint.
Only a trusted successor may receive complete private authority state. A public
projection is insufficient as an authority backup.

P2P return requires compatible participant history and a new admitted incarnation;
a saved World alone is insufficient. After provisioning control failure, the
current native owner requires an explicit close/reopen and durable restore to
rejoin. Existing authenticated links can continue during a control outage, but
new joins cannot be authorized while that service is unavailable.

## Compatibility

Pin SDK and toolchain versions. Treat source APIs, network protocol/schema,
content identity, local frames, and durable archives as separate compatibility
contracts. Reject mismatches or supply an explicit converter. Never reinterpret
old bytes as a changed layout. See the
[compatibility contract](https://github.com/wlitwin/odin_godot/blob/main/replay/compatibility.md)
for the version rules.

Checksums detect differences; they do not authenticate a sender. Account systems,
general NAT services, arbitrary reference-graph snapshots, and exactly-once
external business effects are application responsibilities.
