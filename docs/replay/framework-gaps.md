# Current framework closure queue

This short queue implements the [framework completion plan](framework-completion.md).
The [acceptance audit](framework-audit.md) maps the implementation/evidence. This
is a finite shared-framework queue, not a game-parity backlog.

The framework-first closure queue is complete. The
[release assessment](release-assessment.md) maps the final requirements to evidence
and retains the decision to keep Replay experimental alongside Kit. The original
roadmap's broader game/platform/deployment ambitions are not being marked verified.

The audit may reveal additional **concrete shared** defects. Each must have a
reproducer or an explicit missing API/acceptance criterion before expanding this
queue. Do not create tasks just because an old port ledger contains open parity.

## Final assessment evidence

The [support envelope](../../replay/support.md) records mode/backend/platform
coverage, resource bounds, authoring/performance tradeoffs and the P2P control-loss
policy. Killing the actual native service clears party readiness after about
10.46 seconds while both existing encrypted links continue to the tick-1200
reference. The freshly built addon passes offline, native network and Chrome
execution in a consumer project outside the checkout. See
[final receipts](results/framework-release-2026-09-20/README.md).

## Recently closed integration gap

Native P2P now accepts an explicit local listener independently of the advertised
endpoint. A real forwarded-port TLS/ENet case passes initial play and creator return
through a new forwarding port. Setup/recovery [onboarding](../../replay/getting-started.md),
[compatibility policy](../../replay/compatibility.md), native/WASM checked API recipes
and `tests/replay_framework/run.sh` now provide a consolidated entry point. See
[focused receipts](results/framework-delivery-2026-09-20/README.md).

The framework audit now has current selected-suite evidence: 362 unit tests,
package-specific target/recording checks and one real observer fault/refresh
trace. Current observer effects are complete and replay identically on native/WASM;
the older trace-less C2 report remains historically unexplained, not an invented
fix claim. An optimized arm64 corpus miscompile was isolated to the test factory
and has a narrow no-inline workaround with retained evidence.

Native two-player P2P now uses durable enrollment, challenged registration, scoped
pair keys and authenticated/encrypted ENet. Real TLS tests cover creator and guest
process return, new incarnation, new authenticated generation and retained rollback
history. Creator return changes its port and the survivor discovers it. Browser
create/join/rejoin still converges after the shared control-router changes.
See [focused receipts](results/native-p2p-2026-09-20/README.md).

## Explicit support boundaries to retain in the audit

- `P2P_Direct` is a two-player convenience owner; lower-level runners/RTC mesh and
  pair/link primitives have different player-count envelopes.
- Pair-link framing is experimental, lacks forward secrecy against later key
  compromise and has no independent cryptographic review. Do not advertise a
  public security certification based on functional tests.
- Native ENet and browser WebRTC need a common backend for mixed-platform matches.
  Native RTC extension availability cannot be assumed.
- Live Steam accounts/GameServer, additional OS/hardware, public TLS/TURN and
  broader outage profiles need external/platform evidence before being advertised
  as validated. This does not reopen game-content parity work.
- Established P2P links can survive background control failure, but new admission
  needs the service. Automatic failed-control reconnection is explicitly not
  implemented; the application can close/reopen and restore/rejoin. This is now
  classified and tested as an experimental support boundary.
