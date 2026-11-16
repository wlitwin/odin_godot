# CI review and test boundaries

The default CI should answer whether the bridge, Kit, Replay and native physics
contracts still work. A game scenario can exercise those contracts, but its
camera, menu, loot distribution or bot timing must not define framework behavior.

The November 2026 review found substantial duplication and fragile setup in the
381-entry suite. The complete [eight-job run](https://github.com/wlitwin/odin_godot/actions/runs/43789842136)
reported 297 passes, 14 failures and 70 explicit skips. Its checks consumed
14,532 aggregate job-seconds, about four runner-hours. These are observed costs,
not performance requirements. A script registration is not an independent test:
several registrations invoke the same lower-level suites and application builds.

## Framework defects that warranted changes

| Issue | Ordinary usage affected | Evidence and retained coverage |
| --- | --- | --- |
| Optional physics leaked through shared presentation imports | A value-only Replay game failed to link without `libogb3` | `replaypackages` builds the public surface with a deliberately missing native library. Physics presentation has its own import. |
| The native domain flag required ownership for generic value-only recovery | A normal Room failed on its first backup with `Invalid_Model` | `replayrecovery` runs with strict admission and no native library. Complete-state ownership remains mandatory. |
| A backup receipt passed a receiver by value | Instantiating the public helper failed compilation | The package boundary fixture now instantiates that generic call in native and WASM checks. |
| Error stack dictionaries used the wrong Godot fields | Reporting an Odin error produced engine contract errors | A real nonfatal error test requires valid stack dictionaries and return to the caller. |
| Linux symbol lookup missed internal Odin procedures | Debug and crash reports lost useful caller names | ELF bounds/lifetime tests and real Linux stack/crash probes cover the bounded metadata cache. |
| Facts received during resync were discarded | The world restored correctly while a confirmed gameplay effect disappeared | `replaynet` and `replayview` cover matching-stream retention, exactly-once output, queue pressure, failed reset and stateful policy callbacks. A live recording reproduced the lost effect. |
| A physics refresh could disagree with retained facts | Retained effects could be published against a contradictory replacement checkpoint | The strict complete-state runner rejects signature, accepted-input and event contradictions before decode/install, and accepts matching and large-gap restores. |
| Backup readiness compared a stale configured incarnation | A valid current successor remained reported as waiting | Selector tests preserve checks against the authenticated nominee, connection incarnation, generation and token. This changes readiness reporting, not authority. |

The ELF cache and journal transaction carry the most implementation complexity.
Their malformed-input, borrowed-lifetime, output-pressure and rollback controls
belong in independent regression tests. A passing game bot is insufficient proof
of either contract.

## Failures that did not justify changing framework behavior

| Failure | Classification | Appropriate response |
| --- | --- | --- |
| Formatting changed frozen reference and generated-source files | Fixture integrity | Restore the recorded bytes and exclude immutable fixtures from ordinary formatting. Keep versioned wire/source equality checks. |
| Whitespace-based patches silently stopped adding test fields or hooks | Fixture construction | Assert unique semantic anchors or replace the source-patching fixture. Do not modify the library to accommodate missing test setup. |
| Launchers deployed an older content ID than their game | Fixture configuration | Obtain the current declaration used by producer and validator; retain mismatched-content rejection. |
| An editor quit after a fixed frame count | Fixture preparation and an upstream engine issue | Declare extensions before startup and wait for import completion through the shared helper. Do not suppress import errors. |
| A color test froze before the player node existed | Visual readiness race | Wait for the actual node before freezing. Keep visual assertions in the application acceptance lane. |
| Mod-picker and physical-ping scenarios still failed after proposed timing fixes | Unresolved application fixtures | Preserve the failure and archived experiments. Menu ordering and input-guard explanations are not established fixes. |
| A shop test assumed both players collected enough loot | Scenario precondition | Test affordability explicitly. Do not change loot distribution or prices for the test. |
| A short measurement missed a transient status | Sampling assumption | Keep deterministic status rules in unit tests; treat the timed stress sweep as a separate workload. |
| A historical combat marker selected a later non-combat backup | Scenario synchronization | Bind the crash to the actual approved checkpoint. Do not change cooldowns, damage or recovery rules to manufacture the expected state. |
| An exact notice prefix failed despite exact restoration and a truthful loss disclosure | Presentation wording | Assert restoration and disclosure semantics. Do not change product copy solely to match a literal. |
| MP3 playback remained alive during immediate process exit | Asynchronous test teardown | Await the existing scene/audio teardown; retain leak checks. |
| Native verification was slow and a WASM arena exhausted despite schema destruction | Validation harness configuration | Optimize the verifier and use a fixed-capacity allocator that supports frees. Memory allowances and rejection checks stay unchanged. |

The cold-import issue is documented by the engine in
[Godot #111645](https://github.com/godotengine/godot/issues/111645).
The fixture bootstrap avoids late extension discovery; it is not an upstream
engine fix.

## Small component core

The core has 20 existing entrypoints, each runnable independently. Entrypoints
contain many assertions; the count is not a target to grow.

| Component | Core contracts |
| --- | --- |
| Bridge | Script generation, canonical wire ABI, a generated script in Godot, reference lifetimes, hot reload |
| Kit | Network protocol, prediction/repair, session state machine, WASM package compilation |
| Replay | Rollback, public package boundary, native/WASM deterministic parity, protocol, effect journal, complete recovery, authority rules, durable authority storage, one real ENet recovery |
| Utilities | Event and sequencing contracts |

Use the [testing guide](testing.md) for the component commands and the exact
selection in `tests/core.tsv`. Pure checks can run without a Godot executable.
The runner preserves each command's exit status and reports only its selected
checks; running the core does not claim that the full application matrix passed.

Box3D retains separate native C ABI, sanitizer, capacity and timing checks. Its
managed Odin runner is an independent strict-domain test over a verified shared
library. It covers real solver state and allocator/model/codec/transfer ownership;
its simulated host hooks do not replace real Godot module/reload tests when those
boundaries change.

## Broader coverage

The full suite remains available explicitly. Large game matrices, visual checks,
long bot matches and historical comparisons are application acceptance and
diagnostic workflows. Preserve their assertions and logs, but run them separately
from the default component core. Extract unique schema, artifact-provenance,
publication-atomicity and compatibility assertions before removing an aggregate
from a required lane.

Examples of duplication found during the review include seven routes through the
Cave core, five through view tests, and three each through network and authority
tests. Editor, bridge and authoring aggregates also rebuild or rerun Stormcaller
and shared UI fixtures. Those repeated builds do not provide independent evidence.

## Open findings

- Two compiler exits with signal 11 were reported on Linux x86-64: a Slopball
  WASM type check and `replay_browser_checkpoint`. The commands have not reproduced
  in the local macOS/ARM Linux checks. They remain unresolved toolchain findings;
  changing the lane does not prove them fixed.
- The legacy Kit Cave comparison reported retained multiplayer references after
  gameplay completed. A teardown candidate was not accepted as a verified fix.
- The independent managed-runner command exposed an allocation-layout assumption
  in its older fixture: it allocates a resumed Server in the same live meter after
  freeing the source. The meter deliberately rejects rebinding a retired alias,
  so reusing that address can fail the fixture. The first failure is retained;
  a successful retry is not proof of a fix. The command remains independently
  available, but it is not added automatically to capacity CI. Neither the meter
  nor allocation order was changed to make it pass.
- Experimental scenario changes that did not pass their full assertions are
  excluded from the publishable fixes. No gameplay balance, framework capacity,
  authority rule or assertion should be relaxed to make such a scenario green.

The full suite is not green. The component core is a smaller statement of what
default CI proves, with the remaining findings tracked separately.
