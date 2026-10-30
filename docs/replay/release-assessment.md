# Framework-first completion and experimental release assessment

Assessment date: 2026-09-20. This evaluates the user's revised priority: finish
the framework and use games as representative validation, while deferring
exhaustive game parity. It does not retroactively declare every historical
M0–M9 port/deployment checkbox complete.

**Decision: retain and deliver Replay as an experimental library alongside Kit.**
The requested multiplayer styles have implemented primitives and representative
acceptance. The current framework closure queue is satisfied within the explicit
[support envelope](../../replay/support.md). Neither human productivity superiority
nor universal production/platform readiness is claimed. No release was published.

## Final requirement audit

| User-facing requirement | Authoritative evidence inspected | Conclusion |
| --- | --- | --- |
| A separate Odin/Godot library with a coherent gameplay foundation | `replay` value timeline/pool/RNG/correction APIs; engine-free Loot; Hello models and Session adapter | Implemented. Mutable gameplay dependencies are explicit; rendering and I/O remain outside simulation. |
| Offline, co-op, competitive authority and deterministic peer rollback | Current net/group/interest/owned/P2P tests; representative Hello, Cavecrawl/Slopball, Quickdraw/Claimball and Duel integrations | Implemented under separate explicit policies. No false claim of deterministic Godot contact physics or unrestricted concurrent writers. |
| Framework-owned difficult networking work | Scheduling/action ledgers, prediction/correction, snapshots/deltas, recipient views, journals, bounded transport/routing, Party/Room/P2P setup | Implemented and documented. Applications still choose game rules, trust and prediction scope. |
| Host migration and recovery | Complete checkpoint/identity/action state; coordinator fencing; planned/crash/repeat/partition/successor-loss/return/cold-restore evidence | Implemented for the tested contracts. Crash recovery may lose work after the accepted checkpoint; external exactly-once side effects are not promised. |
| Native/browser integration and reconnect identity | Current authenticated native two-player ENet, browser RTC, durable enrollment and process-generation tests; forwarded-port creator return | Implemented. Native and browser backends must match for cross-platform gameplay; validated combinations are listed in support.md. |
| Practical authoring/debugging | Input capture and detached presentation; diagnostics/recordings/playback; checked API recipes; paid-revive/weapon authoring comparisons | Implemented with structural and runtime evidence. Human authoring speed/play-feel superiority remains unproven. |
| Preserve both implementations and separately runnable games, including sibling Scrapyard | Kit baseline hashes, clean original game paths, clean sibling revision; distinct Replay projects and isolated test profiles | Preserved. Remaining full-game parity is deferred by user direction, not claimed complete. |
| Comparison and stabilization | Current 13-gate framework smoke (400 unit tests plus recipe/target/archive checks), observer trace, protocol/fixture fixes and prior representative cost measurements | Verified selection passes. The historical C2 failure's cause remains unestablished; no failing current trace or invented fix is claimed. |
| Deliver usable library entry points | Getting-started guide, compatibility policy, checked lifecycle recipes, supported-envelope assessment and existing addon packaging | Delivered in the workspace. Actual package installs/builds/runs outside the source checkout; no deployment or publication performed. |

The [implementation audit](framework-audit.md) provides source/test mappings.
[Framework delivery receipts](results/framework-delivery-2026-09-20/README.md)
cover the smoke, recipes and forwarded endpoint case. The final assessment's
[receipts](results/framework-release-2026-09-20/README.md) cover actual control
service loss and a freshly built isolated consumer addon.

## Final failure-policy check

The native P2P service is killed after both encrypted links are admitted. Party
readiness fails after about 10.46 seconds, and neither party claims readiness for
new admissions. Existing authenticated links remain at generation 1 and both
games continue to the full-reference tick-1200 hash **9004447930841423017**.

Thus current behavior is explicit: existing P2P gameplay can survive background
control loss, but new admission cannot. Automatic control reconnection is not
implemented by the current Party owner. The application may close/reopen and
restore/rejoin after service recovery. Signed denial/invalidity has a different
policy and clears native link keys. This boundary is documented, not hidden behind
an unbounded retry or a claim of seamless recovery from every outage.

## Adoption rationale

Replay makes cross-entity operations ordinary value-world code, with shared replay
and authority execution. The paid-revive comparison demonstrates that property
for one real feature. It does not prove every feature is easier. Runtime costs in
representative comparisons are often higher than Kit's; measured compression
improvements do not remove the CPU/copying tradeoff. The result supports keeping
Replay available for experiments and game-specific evaluation, rather than
replacing Kit automatically. Both game versions remain useful for that evaluation.

## Follow-up boundaries

These remain visible follow-ups, outside the completed framework-first closure
queue: exhaustive game content/visual/audio parity; human comparative playtests;
broader independent OS/hardware/browser validation; live Steam/GameServer and public
account/deployment operations; arbitrary NAT and outage combinations; independent
cryptographic review; automatic failed-control reconnection; and storage/prediction
extensions beyond the documented bounded model.

They are not being represented as finished. Advertising any of them as validated
requires new evidence. The original detailed roadmap and historical results remain
available for future work. The delivered experimental framework should be pinned
to a source/toolchain revision and used according to its compatibility policy.
