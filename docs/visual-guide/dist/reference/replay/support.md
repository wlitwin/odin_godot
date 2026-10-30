# Experimental support envelope

This is the support assessment for the framework-first implementation as of
2026-09-20. **Retain Replay as an experimental library alongside Kit.** It has
working primitives for the requested multiplayer styles and representative
integration evidence. It is not a certified production service, an automatic
replacement for Kit, or proof that arbitrary gameplay is deterministic.

Start with [getting started](getting-started.md), then use the
[compatibility policy](compatibility.md) and the exact package contracts below.
The [framework audit](../docs/replay/framework-audit.md) maps implementation gates.

## Modes and tested combinations

| Mode | Implementation and representative evidence | Boundary |
| --- | --- | --- |
| Offline value simulation | Timeline/pools/RNG; standalone Loot; Godot Hello input, history and recordings | All mutable simulation dependencies must be explicit; bounded value storage, not arbitrary node/reference snapshots |
| Server authority and competitive prediction | `net` + Session/Room; Quickdraw/Claimball, recipient filtering and historical-view tests | Authority rules, prediction footprint, action timing and disclosure policies remain authored game decisions |
| Cooperative owner-driven physics | `owned`, Body2/Body3 and authoritative observations; Slopball and owner Cavecrawl | Cooperative trust; Godot contact solving is not deterministic rollback or an anti-cheat proof |
| Host migration and durable recovery | Room/coordinator/leases, private checkpoints; planned/crash, repeat, partition, successor loss, return and cold restore fixtures | Requires a reachable trusted coordinator and eligible complete backup; crash loss is bounded by the accepted checkpoint, not zero by definition |
| Deterministic P2P | Fixed-roster runner; native/WASM/Rosetta corpus, participant archives and spectator failover | Determinism is established for tested models/targets, not arbitrary floats/physics/callbacks; missing history stalls or fails explicitly |
| Native provisioned P2P | P2P_Party + P2P_Direct; two-player TLS enrollment/pair service and encrypted ENet recovery | Convenience owner supports two players. Reachable/forwarded endpoints are configured; no automatic NAT traversal |
| Browser provisioned P2P | P2P_Party + authenticated RTC mesh; independent Chrome profiles and guest/creator archive return | Fixed roster; credentials and participant history are separate. Authenticated spectator enrollment is not supplied by this party flow |
| Dedicated authority | Server/Observer infrastructure Room profile; native and Chrome recovery | Infrastructure identities/standbys must be provisioned; player-hosted backup disclosure is a different trust choice |

ENet gameplay is native. Browser gameplay uses WebRTC; a native ENet peer cannot
directly join a browser RTC peer. A common backend/native RTC extension is required
for such mixed-platform matches. The shared Transport API does not confer backend
availability or network reachability.

Most live integration evidence is macOS arm64 + Godot 4.7.1 and local Chrome.
Standalone WASM is executed, not only type-checked, in deterministic/archive/trace
fixtures. Rosetta checks another ISA binary on the same Mac; it is not independent
x86 hardware, Linux or Windows validation. SQLite adapters currently have native
darwin/linux implementations; available source is not proof of deployment on both.

RTC/TURN evidence includes local Coturn relay-only UDP/TCP configurations and real
datagram loss/delay tests, including migration. Native service fixtures verify
localhost TLS with a test CA. Public WSS certificates, real Internet NAT/relay
availability, independent hardware and other browser engines remain deployment
acceptance work. See [TURN datagram evidence](../docs/replay/results/browser-turn-udp-faults-2026-09-14/README.md).

Steam's packet/Room lifecycle integration has native ABI and local API-contract
tests. Live multi-account Valve networking, lobby UX and SteamGameServer are not
validated by those fixtures. They remain experimental integrations, not supported
live-network claims. See [Steam](godot/transport/steam.md) and [Steam Room](godot/steam_room.md).

## Recovery and failure policy

Room planned handoff freezes after accepted work settles and transfers an approved
final checkpoint. Abrupt takeover uses the newest approved usable checkpoint after
authority fencing; it can lose later unreplicated work. Retained, rejected, retired
and unknown command outcomes have explicit recovery classifications. Complete
authority state must only go to a trusted successor. Public projections are not
authority archives. See [recovery guarantees](../docs/replay/recovery.md).

P2P peers retain simulation/input history; a returning process restores its own
compatible participant archive and registers a newer incarnation. The native
owner refreshes pair decisions for a replacement connection and rejects retired
connection generations. A saved world alone is insufficient.

**P2P control outage policy:** registration/pair control failure clears Party
readiness and prevents new admission. It does not by itself invalidate an already
authenticated direct link. A signed denial/invalid registration does retire the
native link's keys. The current owner does not automatically reconnect failed
background control; after service recovery, the application closes/reopens the
party and restores/rejoins using its durable enrollment and participant archive.
This deliberate distinction prevents an unreviewed background rebind from changing
an active process identity underneath its transport. Continuous automatic control
recovery is a follow-up capability, not a claimed guarantee.

A final native test kills the actual service after admission. Party readiness
fails after about 10.46 seconds while both existing encrypted links remain live;
the peers still match the full reference at tick 1200. See the
[release receipts](../docs/replay/results/framework-release-2026-09-20/README.md).

The service cannot authorize new joins/rebinds while unavailable. Existing-link
continuation is not offline revocation awareness. Applications requiring continuous
online authorization must choose a stricter session policy.

## Bounds, not scale promises

| Surface | Enforced implementation bounds |
| --- | --- |
| Local timeline | 2–4096 history frames; 0–4096 events/tick; complete staged suffix before commit |
| Authoritative model | 1–8 playable seats; 16 peer records including nonplayer connections; 16 queued/recent actions per peer |
| P2P runner | 2–8 participants; 32–1024 history frames; delay + prediction + 2 must fit history; input encoding ≤256 bytes; initialization storage guard 256 MiB |
| Complete authority checkpoint | 1 MiB archive, explicit policy/asset validation; runtime history/transport queues are not serialized |
| P2P archive | 16 MiB maximum; retained input/checksum/history windows remain bounded |
| Provisioning service | Up to 32 resident rooms; fixed P2P rooms 2–8 members; bounded invitation and request budgets |
| Packet/router | 65536-byte Transport ceiling; bounded per-lane buffers, ingress/egress budgets and retention on short receives |

These are validation/allocation limits. They do not promise that a maximum-size
world or maximum population meets a frame budget. Timeline storage includes both
history and replay scratch; server peer/baseline caches add further state copies.
Measure the concrete World/input/event types, history, packet settings and target
hardware. Profile callbacks must not change simulation or block network progress.

## Authoring and performance assessment

The strongest authoring result is specific: the same paid-revive transfer in
isolated Scrapyard variants added the predicate and both wallet assignments to
Replay's existing value reducer, reused for prediction and authority. Its feature
patch changed 3 files with 11 added physical lines versus Kit's 4 files/19 added
lines, and the 72 peer receipts preserved the agreed transfer behavior. These are
agent-authored structural measurements, not human productivity or debugging-time
proof. A separate existing-family weapon required the same authored resource in
both implementations. See [revive](../docs/replay/results/paid-revive-authoring-2026-09-08/README.md)
and [weapon](../docs/replay/results/weapon-authoring-2026-09-08/README.md).

Costs are mixed. The quiet Cavecrawl comparison measured Replay callbacks around
340–401 µs mean versus Kit's 81–85 µs on one machine, while owner motion had similar
local-response ranges and Replay predicted the complete inventory transfer.
Subsequent same-binary encoding pairs reduced client application traffic 41.7%
and host traffic 30.6%, respectively; they did not demonstrate CPU speedups.
See [comparison](../docs/replay/results/cave-profile-comparison-2026-09-20/README.md),
[observations](../docs/replay/results/compact-observations-2026-09-20/README.md) and
[facts](../docs/replay/results/compact-recent-facts-2026-09-20/README.md).

The older Scrapyard encounter comparison also measured higher Replay callback and
bandwidth costs. Its peak RSS was lower for the Replay host but higher for the
Replay client; process-lifetime peaks include startup and cannot be summed as
simultaneous memory use. Those historical game/protocol builds are evidence of
tradeoffs, not current universal benchmarks. The small 520-byte-world P2P benchmark
measured about 19.5–21.4 ms process CPU for two peers over 2400 ticks in accelerated
test time. It does not predict full-game rollback cost. See [combat](../docs/replay/results/scrapyard-combat-comparison-2026-09-08/README.md)
and [P2P profiling](../docs/replay/results/p2p-profile-2026-09-05/README.md).

The evidence supports trying the complete-world authoring approach and profiling
representative workloads. It does **not** justify replacing Kit everywhere or
claiming performance/ergonomic superiority. Keep both implementations available.

## Security and compatibility boundaries

Canonical checksums are not authentication. Plain direct Session/ENet fixtures
must not be described as encrypted Internet sessions merely because they use
tokens. Use the appropriate authenticated/confidential setup and transport policy.
Native P2P pair-link framing uses core cryptographic primitives but is new,
experimental framing without independent review or forward secrecy against later
enrollment/service-key compromise. Functional packet tests are not certification.

There is no human account system, exactly-once external-effect outbox, arbitrary
dynamic reference-graph snapshotter, deterministic Godot physics solver, general
NAT service or automatic game-content converter. Those are explicit support
boundaries. Full game parity and subjective play-feel superiority remain separate
follow-up work under the user's framework-first direction.

Run [the smoke command](../tests/replay_framework/run.sh), then the focused
integration gate for your selected transport and recovery profile. Pin source and
toolchain versions. Future source/API, protocol, content and archive changes must
follow [compatibility](compatibility.md); experimental status does not excuse
silently loading incompatible data.
