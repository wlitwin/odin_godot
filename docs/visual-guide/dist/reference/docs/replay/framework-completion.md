# Framework completion plan

**Active priority, 2026-09-20:** finish Replay as a usable multiplayer framework.
The user explicitly redirected work away from achieving 100% parity across every
ported game. This plan supersedes exhaustive game-parity requirements in the
original roadmap and individual port ledgers. Those ledgers remain useful history
and follow-up backlogs; their open rows do not automatically block the framework.

Keep Kit, original games and separate Replay versions independently runnable.
Preserving them is still required. Deferred parity is not a claim of equivalence.

**Status:** the framework-first implementation, representative validation and
experimental delivery assessment are complete. See the
[final requirement audit](release-assessment.md). Broader historical parity and
unverified platform/deployment work remain explicitly listed as follow-up.

## Completion gates

| Area | Required framework result | Representative evidence |
| --- | --- | --- |
| Simulation core | Restore/replay includes entity lifetime, RNG, commands and events; invalid operations are transactional and bounded | Existing core/recording tests and Hello |
| Authoring and Godot | Documented offline-to-network workflow, input capture, reusable scene binding and event reconciliation, useful diagnostics | Hello plus one cross-entity gameplay change |
| Networking policies | Explicit working contracts for server authority, cooperative/owner-driven interactions, competitive prediction and deterministic P2P | One representative scenario for each policy, reusing existing ports |
| Identity and setup | Reusable create/join/rejoin; authenticated transport binding; bounded errors and credential persistence | Party/Room and P2P party integration; native two-player and browser recovery now have focused acceptance |
| Recovery | Planned/crash migration, reconnect, late join, returned host, save/restore and content fencing preserve their documented guarantees | Existing recovery fixtures; fix shared defects they reveal |
| Transport support | Supported native/browser combinations work through the common API; deployment requirements and unverified integrations are explicit | Focused ENet/RTC/transport tests; live Steam/platform checks tracked separately until available |
| Stabilization | Resolve shared correctness failures, bound resource use, and measure representative CPU/memory/bandwidth and rollback/recovery cost | Existing comparisons plus focused reruns for changed framework paths |
| Delivery | Coherent public API, runnable minimal examples, setup/recovery documentation, compatibility policy and an evidence-backed experimental release assessment | A concise acceptance audit against these gates |

The final assessment maps each criterion to its evidence and limitations.
Audit that evidence before expanding support claims. A technical gate can close
without every game being a finished remake. The framework still needs credible
authoring/behavior validation; game-specific visual fidelity is separate.

## Order of work

1. Native two-player authenticated P2P integration now passes creator/guest return,
   endpoint replacement and a browser regression. Its bounded support and remaining
   deployment restrictions are recorded in [the current gap list](framework-gaps.md).
2. The [shared framework audit](framework-audit.md) now maps these gates and
   current checks. Its remaining concrete tasks are tracked in the gap list;
   existing recovery/networking evidence is reused where its scope fits.
3. Close that list, including shared event-loss/recovery issues when reproduced.
   Use games to expose library problems; move game-only differences to follow-up.
4. Consolidate public setup APIs, examples and documentation. Complete one
   representative authoring comparison and the supported-envelope assessment.

## Deferred game work

Full Scrapyard content completion, every original gauntlet, exact particles/audio,
matching every menu and game-specific behavior, and repeated full-game parity
campaigns are follow-up work unless they expose a missing framework primitive or
shared correctness defect. Existing ports remain available as testbeds.

Do not expand a port just to make its ledger green. Do not rerun all games after
an isolated change. Run the affected framework checks and representative integration
cases, then continue to the next framework gap.

## Working record

Keep this plan and a short current gap list authoritative. Preserve prior results,
but avoid repeatedly reading or duplicating the complete history. New evidence
should contain the changed sources/identifiers, relevant logs and reproduction
commands; large repeated source snapshots and unrelated game matrices are unnecessary.
