# Framework acceptance audit — 2026-09-20

This audits the eight [framework completion gates](framework-completion.md).
It reuses existing integration evidence and runs focused current checks. The
[final assessment](release-assessment.md) closes the revised framework-first scope;
it does not require every game to become a complete remake or claim unverified
public/platform support.

## Requirement-to-evidence table

| Gate | Implementation inspected | Evidence and assessment |
| --- | --- | --- |
| Complete simulation/replay state | `replay/timeline.odin`, `correction.odin`, `pool.odin`, `random.odin`, `value.odin` | Current core tests cover transactional history, lifetime, RNG, rejected references and failed suffix replay. Implemented for bounded owned values, including tagged unions; dynamic reference graphs are outside the current storage contract. |
| Godot authoring/presentation | `godot/session.odin`, `nodes.odin`, input clocks/buttons, `view/events.odin`, cues and diagnostics | Current view/diagnostic tests plus [M2 technical evidence](m2-acceptance.md) cover input edges, pause, view lifetime, reconciliation and detached presentation. [Paid revive](results/paid-revive-authoring-2026-09-08/README.md) is an existing cross-entity authoring comparison. Implementation present; consolidated onboarding and checked lifecycle recipes now exist. Human productivity/play-feel superiority is unproven. |
| Server, co-op and competitive policies | `net/types.odin`, `groups.odin`, replication policy, `owned`, Body2/Body3 adapters | Current network/interest/owned suites exercise correction, authored footprints, hidden-state projection, ownership scope and reliable action context. This is explicit cooperative ownership coordinated by an authority, not arbitrary simultaneous writers or deterministic Godot physics. Representative game integrations already exist. |
| Deterministic P2P | `p2p/runner.odin`, archives, spectator/watch/rebind and provisioning | Current units and complete default/optimized native/WASM archive, rejoin and spectator-failover corpora pass. The audit exposed an arm64 compiler miscompile in an inlined test-model factory; a fixture-only no-inline workaround and callback-owner assertions preserve the original acceptance checks. Runner semantics are unchanged. |
| Reusable setup and identity | Party/Room, durable enrollment, registration, P2P party/pair service and native links | [Native P2P](results/native-p2p-2026-09-20/README.md) and browser receipts cover persisted create/join/rejoin, current incarnations, authenticated connection generations and returned endpoints. The two-peer native owner now separates bind and advertised endpoints, with a real forwarded-port recovery gate. |
| Session recovery | Authority records/leases, complete checkpoints, bounded transfer, Room transitions/publication/restore | Current authority/recovery suites plus [browser failure matrix](results/browser-failure-matrix-2026-09-06/README.md), [transition expiry](results/room-transition-expiry-2026-09-13/README.md), dedicated and recent native/browser migration evidence establish the documented local envelopes. Cold restore and pending-command classification are implemented. Arbitrary partitions/outages and live Steam are not universally validated. |
| Transport/resource stabilization | Common Transport/Router, ENet/RTC, generation fences, canonical codecs, budgets and profiling | Current schema/network tests cover malformed inputs, channel/packet limits, transactional decode, baseline recovery and bounded work. Existing native/browser/TURN evidence is scoped. [Cavecrawl comparison](results/cave-profile-comparison-2026-09-20/README.md) records higher Replay costs; later compression results address measured traffic overhead only. The consolidated supported-envelope/release assessment records these tradeoffs. |
| Delivery and compatibility | Package docs, runnable examples, versioned schemas/content, explicit checkpoint converters | Obsolete capability/version claims were corrected. Consolidated onboarding, compatibility policy, native/WASM checked API recipes and a bounded framework smoke command now exist. The supported-envelope/release assessment and isolated addon gate complete the delivery assessment. |

The source paths above refer to current implementation, not planned package names.
There is no missing `replay/session` package to scaffold: its responsibilities are
implemented by `net`, `authority`, `provision`, `recovery` and the Godot owners.

## Observer-effect classification

The current four-process fault/refresh scenario reaches tick 2400 with all 21
authoritative kicks presented. It requests a same-epoch checkpoint while the
tick-220 effect is confirmed (222) but not yet visible (watched 214); that effect
is emitted exactly once after refresh. Native and standalone WASM consume the
same 5,669-frame / 28,085-operation trace and reject corruption.

This verifies the current retained-effect/rebase contract. The older C2 case that
lost four effects has no failing delivery trace; its cause remains unestablished.
The [prior investigation](results/claimball-c2-recording-2026-09-14/README.md) already
failed to reproduce it in seven captured schedules. Treat it as a historical,
unreproduced report rather than indefinitely rerunning full games or declaring an
invented fix. A new failing trace reopens a concrete shared defect.

## Concrete closure work

No implementation item remains in the framework-first closure queue. The
[support envelope](../../replay/support.md) and [release assessment](release-assessment.md)
classify the modes, limits, comparisons, distribution and P2P control-loss behavior.

No new game-content or visual parity task is implied by this list.

Endpoint separation and setup/compatibility delivery are now verified in the
[delivery increment](results/framework-delivery-2026-09-20/README.md).

## Current verification

The audit ran 30 core, 24 view, 182 network, 7 interest, 11 owner-stream,
36 authority, 11 recovery, 33 P2P and 28 schema unit tests: **362 tests**.
Their scripts also run package-specific WASM/recording checks. The diagnostic
script exercises actual checkpoint upgrades and field inspection. The focused
observer trace runs separately. This is a framework audit selection, not a claim
that the entire repository suite ran.

The initial P2P command failed in optimized native execution. Correct LLVM IR
stored the model callback, but final arm64 instructions overwrote its register
with an endpoint address before storing `Model.step`. The no-inline fixture
factory avoids that code shape. Split assignments and no-inline runner init did
not fix it; none of those experiments changed shipping runtime sources. The final
P2P command passes with its direct `model()` calls and all original world/hash
checks. See [receipts and assembly excerpt](results/framework-audit-2026-09-20/README.md).

## Explicit nonclaims

Managed variable-size simulation collections, multiple independent prediction
timelines per client, static schema code generation, and exactly-once external
service outboxes are not implemented. The current library uses bounded value
storage, one authored prediction group and runtime-compiled canonical codecs.
Those are documented design/support boundaries, not hidden fallback behavior.
External persistent effects remain outside speculative simulation; frame migration
must not be advertised as an exactly-once payment/achievement ledger.

These boundaries do not remove a promised multiplayer style: server authority,
cooperative owner streams, competitive prediction and deterministic rollback each
have explicit implementations. Additional platforms/backends and public security
claims require their own evidence. Original games and all separate ports remain.
