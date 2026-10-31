# Paired game ports and comparison protocol

Both framework implementations and both versions of every ported game must
remain available. A port is a new project with a separate launch command, save
namespace, cache/build output, and network defaults. It never overwrites the
original project's gameplay or turns its original runner into a compatibility shim.

The [three-profile Cavecrawl cohort](results/cave-profile-comparison-2026-09-20/README.md)
adds a quiet two-player comparison of Kit, Replay server motion and Replay owner
motion. Nine pairs pass a common movement/interaction contract with separate
visible/confirmed timing. Owner motion approaches Kit's responsiveness here while
retaining substantially higher application traffic and callback cost. The measured
scope, isolated Kit reference-release overlay and superseded first contract are
explicit; source counts are not a human usability score.

The [public-history cohort](results/public-history-comparison-2026-09-14/README.md)
passes the full 24-window native comparison and 64 report checks. It records lower
Replay host traffic with continued client callback cost. Its report separates the
isolated Kit control, content/prediction differences, and browser TURN conditions.
This record uses it as the loaded Scrapyard native cost baseline; it does not
establish full library readiness.

The [observation encoding A/B](results/compact-observations-2026-09-20/README.md)
compares raw and compact encoding on one owner-profile binary, keeping the accepted
workload, cadence, and recovery settings fixed. Median client application traffic
drops 41.7%. The result does not establish downstream or total-CPU improvement.

The [recent-fact encoding A/B](results/compact-recent-facts-2026-09-20/README.md)
measures shared bundle headers on the downstream path. Six same-binary cases keep
the workload, cadence, complete occurrences, and backups unchanged. Median host
application traffic drops 30.6%, from 9.869 to 6.849 KiB/s, while client traffic
is essentially unchanged. Callback measurements do not establish a CPU
improvement. The quiet-world cost gap, broader comparisons, and adoption decision
remain open.

See [roadmap](roadmap.md) for dependencies and [architecture](architecture.md)
for the frame contract.

The [P2P live rejoin gate](results/p2p-live-rejoin-2026-09-08/README.md) adds
recovery evidence for the separate Duel: one participant restores while survivors
retain their live runners. This validates a bounded recovery capability; it is not
a paired Kit performance measurement or a general stale-save recovery guarantee.
The [browser extension of that gate](results/p2p-browser-rejoin-2026-09-08/README.md)
uses the real Save & pause button and file import in separate Chrome processes,
with only the returning participant killed and restarted.
The [authenticated P2P extension](results/p2p-admission-2026-09-08/README.md)
verifies fixed-roster credentials before binding, including negative admission
cases and a three-member signaling mesh. This is capability evidence, not a
framework performance comparison.
The [creator-recovery gate](results/p2p-creator-recovery-2026-09-08/README.md) now
retains the joining player while creator ID 1 returns under a new connection
generation, with retired transport buffers fenced.

The [spectator source-failover gate](results/watch-failover-2026-09-09/README.md)
adds continuity-checked replacement of a viewing source while players continue.
It preserves spectator state/events and rejects missing or conflicting anchors.
This is native and cross-target capability evidence, not a paired Kit performance
result or public spectator-authentication claim.

The [native creator-return gate](results/native-creator-rejoin-2026-09-09/README.md)
adds transport replacement when the saved listening participant returns. It
preserves the survivor's runner/frontiers and verifies continued reference gameplay.
This is fixed-roster recovery evidence, not a new authority election or a paired
framework performance measurement.

The [native-generation gate](results/native-generations-2026-09-09/README.md)
adds connection metadata and queued-packet fencing to the shared Godot adapter,
with real ENet, Steam API-contract and native rejoin checks. This is transport
correctness evidence, not a new paired performance or live Steam-account result.

The [action-intent authoring slice](results/action-intent-2026-09-09/README.md)
replaces Scrapyard's manual ticket bookkeeping with a reusable helper that also
handles recovery dispositions and epoch-scoped sequence reuse. Mechanical source
counts and functional gates are recorded separately from human usability and
paired runtime performance conclusions.

The [endurance workload](results/scrapyard-endurance-2026-09-08/README.md) adds
injury/healing, surge, dash and reload. Twelve delay-condition windows pass; the
raw-loss condition remains a failed gate for missing short input edges. Its raw
observations are retained separately from the accepted performance comparison.

The [input-frontier audit](results/input-frontier-2026-09-08/README.md) fixes the
observed Replay dash loss. The latest raw-loss Replay scope passes; the paired
condition is rejected for a Kit cast refusal. Scoped acceptance never substitutes
for a complete paired result.

The [cast-submission correction](results/cast-submission-2026-09-09/README.md)
separates Kit local prediction from actual command submission. It corrects the
prior refusal diagnosis; a fresh raw-loss cohort still fails gameplay/observation
gates and is not presented as an accepted paired performance result.

The [latest endurance cohort](results/receipt-resync-2026-09-09/README.md) passes
both conditions: 24 process windows and 56 report cases. It follows the explicit
resync-queue implementation and separate branch tests. Prior failures and temporal
costs remain recorded; this is one supported workload, not a general adoption result.

The separate [jam-clearing workload](results/jam-clearing-2026-09-09/README.md)
passes twelve delay-condition windows and 60 report checks, including seeded
dud/shot and clear-pull accounting. Its full matrix is rejected for stale Kit
cooldown observations and a lost Replay dash under raw loss. The accepted subset
and failed cohort remain distinct from the earlier jam-disabled endurance result.

The [dash-action port](results/dash-actions-2026-09-09/README.md) confirms all 120
local Replay dash requests in a new full cohort, with a separate sequence audit
proving successful late arrivals. The paired workload remains rejected because
three Replay games fall below its kill-count requirement. Delivery acceptance
does not replace matched workload or responsiveness evidence.

The subsequent [aim-origin correction](results/aim-origin-2026-09-09/README.md)
fixes the stress helper's use of an older local-body position. Its fresh delay
condition passes twelve windows and 61 report cases. A ballistic ledger accounts
for the earlier low kill output; the raw-loss condition still fails observation
freshness. No collision/damage rule or acceptance threshold was relaxed.

The [snapshot-ACK result](results/snapshot-ack-2026-09-09/README.md) demonstrates
ACK-induced action blocking and removes that dependency. Replay passes its fresh
delay/raw-loss scope, while paired raw-loss acceptance still fails for a Kit client
observation. The paired delay result and controlled ENet regression remain distinct
from full-matrix acceptance and general responsiveness claims.

## Baseline inventory

Source revisions inspected when this experiment was created:

- odin_godot: `13e7d946223745711fbaafe161c46b204fd38b80`.
- Scrapyard sibling repository: `6bdef4f437d9a4e2c98f1d49472f840879301ccf`;
  its working tree was clean at inspection.

These identify source baselines, not benchmark results. Record the actual old and
new revisions, dirty diff, dependency versions, and content hashes for every
subsequent comparison. Existing projects remain in place; pin a temporary
baseline checkout when source changes would otherwise invalidate paired runs.

| Existing project | New project path | What it tests | Port status |
| --- | --- | --- | --- |
| [hello_net](../../examples/hello_net/README.md), [hello_sim](../../examples/hello_sim/README.md) | [replay_hello](../../examples/replay_hello/README.md) | Common offline/network gameplay, movement, spawn/join, presentation | Offline views and initial real-process networking tested |
| [Cavecrawl](../../examples/cavecrawl/README.md) | [Replay Cavecrawl](../../examples/replay_cavecrawl/README.md) | Doors, contested loot, inventory, AI, progression, recovery | Full normal/faulted gameplay campaign and recovery slices tested; complete authored/UI parity pending |
| [Slopball](../../examples/slopball/README.md), [Slopball3D](../../examples/slopball3d/README.md) | `examples/replay_slopball/`, `examples/replay_slopball3d/` | Owner authority, Godot physics, control handoff | 2D/3D native session/social/rejoin UI and separate solver/network/migration gates pass; fuller parity pending |
| [Quickdraw](../../examples/quickdraw/README.md) | [`examples/replay_quickdraw/`](../../examples/replay_quickdraw/README.md) | Prediction, hitscan rewind, spawning, competitive rules | Initial duel/lob/boots, archive and live combat migration gates; full parity/comparison pending |
| [Speedball](../../examples/speedball/README.md) | [Replay Speedball](../../examples/replay_speedball/README.md) | Full-world contested ball, spikes, goals and correction smoothing | Native contested-ball, UI, migration, restart/saves and native/browser party flows pass; public deployment/visual review pending |
| [Claimball](../../examples/claimball/README.md) | [Replay Claimball](../../examples/replay_claimball/README.md) | Local/shared prediction group and claim-weighted presentation | Group/claim contests, native/browser menus and saves, Party migration/restore tested; intermittent faults and broader parity/comparison remain open |
| Workspace sibling `../scrapyard/` | [Replay Scrapyard](../../examples/replay_scrapyard/README.md) | Full-game complexity, content, sustained churn, migration | Arena/staging, stock combat, abilities, run loop, profiles and initial run/Room recovery; full-game and paired comparison pending |

`examples/replay_loot/` is the first new runnable headless experiment. It borrows
the contested-loot scenario from Cavecrawl but is **not** a Cavecrawl port and
does not yet exercise a network. No full-game parity result is claimed.

## Preservation and content rules

1. Keep the old project and its run/test commands. A new implementation uses its
   new path and explicitly imports `godot:replay`.
2. Share assets only through a deliberate, versioned content boundary. A shared
   mutable resource/configuration must not let one game silently alter the other.
   Copy small assets or use a pinned asset package for independently runnable exports.
3. Preserve attribution/licenses and record asset/content hashes. No need to
   copy generated DLLs, addons, `node_modules`, caches, or exported bundles.
4. Keep per-game save/profile names distinct. Comparison harnesses run scratch
   project copies with isolated user data and ports. They must not clear a
   developer's existing profiles to obtain repeatable tests.
5. A shared test driver may send the same gameplay intent to each game through
   thin adapters. It must not replace gameplay logic with a comparison-only path.
6. If the new framework changes gameplay rules, network trust, physics, tick rate,
   or content, mark the scenario unmatched until the difference is accounted for.

The original Scrapyard `run.sh` currently clears persistent profile files during
setup. Do not execute it unmodified against personal data as part of a benchmark;
establish isolated scratch runs first. Its source was inspected here, not run.

## Scrapyard acceptance inventory

The inspected original harness contains these acts. Use their assertions as
behavioral specifications, and add corresponding Replay fixtures as each slice lands.

| Original acts | New acceptance focus |
| --- | --- |
| `duo`, `solo`, `server` | Seed/content agreement, seat control, mode parity |
| `guns`, `combo`, `lance` | Cadence/reload, weapon variants, statuses, lag compensation |
| `run`, `boss`, `gauntlet` | Wave progression, transitions, boss state, long-run stability |
| `vault`, `doppelganger` | Persistence, stable identity, duplicate-seat behavior |
| `succession` | Abrupt host loss, restored director state, reseating, continued play |
| `stress` | Fire volume, entity churn, CPU, memory, bandwidth |
| `spray`, `mod` | Asset transfer, compatibility/version decisions, late join |
| `chain`, `delivery`, `zone` | Multi-entity effects and delayed consequences |
| `storm`, `surge`, `mend` | Area effects, sustained combat, healing and attribution |

The full-game port should also test migration during these behaviors, even where
the original migration act only covers a simpler case. Record a parity matrix with
`unstarted`, `implemented`, `headless-tested`, and `playtested` independently.

## Scenario matrix

Apply this matrix to each port where meaningful. Fault schedules should be seeded
and recorded, not just random per-run percentages.

| Scenario | Conditions | Assertions/measurements |
| --- | --- | --- |
| Offline reference | Same inputs/content/tick rate | Correct game rules, reproducibility, authored-code comparison |
| Local network | Host/client/observer, no injected faults | Agreement, correct authority and seat identity |
| Latency | 0, 60, 120, 240 ms RTT | Input-to-visible delay, correction magnitude, effects timing |
| Jitter and loss | Seeded jitter, 1%/5% loss, short loss bursts | Convergence, held-input behavior, missing/duplicate effects |
| Disorder | Duplicated/reordered packets | Deduplication and monotonic protocol state |
| Long blackout | Beyond input/history capacity | Explicit stall/resync behavior and time to playable recovery |
| Join/rejoin | Mid-action, mid-wave, after disconnect | State completeness, identity, no historic cosmetic replay |
| Contested action | Both players take/hit/claim together | Conservation, winner rule, reversible feedback |
| Host migration | Planned handoff, crash, successor loss | Interruption, lost ticks, duplicated actions, resumed gameplay |
| Content mismatch | Different schema/content/config version | Clear rejection before live state mutation |
| Sustained workload | Same entity population/action trace | p50/p95/p99 CPU, memory, bytes, replay depth |

RTT is round-trip time. The existing shims may specify per-direction latency;
record the actual injected parameters and measured RTT so a nominal "120 ms"
test cannot accidentally compare 120 ms RTT with 240 ms RTT.

## Measures

### Authoring and maintenance

- Handwritten gameplay and handwritten framework wiring separately; exclude
  generated code and report content/UI separately.
- Number of places changed to implement the same feature: add a weapon, transfer
  an item, spawn an effectful entity, add a replay-dependent status, persist a
  director field, and migrate during an ability.
- Explicit authority/time branches and callbacks an author must understand.
  Count them as evidence, not a target to game by hiding decisions in wrappers.
- Time to identify and fix a seeded issue; number and quality of diagnostics.
- Qualitative port notes: awkward ownership, excessive declarations, missing
  game primitives, and where the new model is less convenient.

### Runtime and player experience

- Simulation, snapshot, presentation, and replay CPU separated; p50/p95/p99 and
  worst replay burst, with warm-up excluded.
- Resident/peak bytes, bytes per stored frame, history length, and allocations
  per normal tick and correction.
- Application and transport bytes per peer by message class, join/checkpoint
  size, send frequency, and ingress/outbound queue pressure.
- Input-to-visible response, correction distance/angle, correction frequency,
  speculative effect duration, cancellation frequency, missing/duplicate effects.
- Migration interruption and rollback distance, checkpoint age, reconnect/resync
  time, and preservation of persistent/session outcomes.
- Human paired playtests, with network conditions and game-rule differences
  disclosed. A numerically converged game can still feel worse.

## Result format and reproducibility

Store runs under ignored `tests/.logs/replay-comparison/`; promote selected
summaries and machine-readable data to a documented results directory after review.
The harness should capture:

```text
scenario and seed
old/new repository revision and dirty diff
Odin, Godot, compiler flags, platform, CPU, render settings
content and gameplay configuration hashes
runner/topology/trust profile, players/entities, tick and send rates
input trace and complete network fault schedule
history, prediction, interpolation, and checkpoint settings
warm-up, repetitions, raw samples, percentile method
scenario invariants and explicit parity gaps
```

Use repeated paired runs on the same machine and alternate run order. Report raw
data and variability; avoid drawing conclusions from a single best run. Measure
optimized builds for performance and keep debug/diagnostic overhead separately.

For host migration, do not describe survival from a recent checkpoint as zero
lost progress. For deterministic P2P, actual execution and matching logical hashes
on each target are required; successful cross-compilation is not that evidence.

## Decision record

For each completed port, publish: which gameplay became simpler, what new
constraints appeared, the latency/performance tradeoffs, unresolved failures,
and whether the next port is justified. Keep the raw scenarios usable even if
the experiment's final outcome is to retain both frameworks for different games.


<a id="active-range-comparison"></a>

## Stationary firing and reload comparison

The [paired harness](../../tests/replay_comparison/README.md) now includes a
stationary firing/reload scenario alongside the idle arena. Each game uses the
same bolter settings and accepts exactly nine rounds per player. Both real input
and weapon paths run; a sampled trace records different firing/reload times and
projectile occupancy instead of presuming them equal. Three alternating pairs
and source/build hashes are required for a comparison result. This adds active
weapon work; AI/damage/movement stress, further ports and human playtests remain
separate requirements of M9.

## Active combat encounter comparison

The [combat harness](../../tests/replay_comparison/README.md#combat-encounter) now
adds four explicit stock-enemy spawn requests, live AI approach/bites, target-seeking
fire, damage/death and scrap collection. Its shared driver requires matching final
kill, damage, pickup and shot totals while recording different player health,
attribution, NPC positions/occupancy and timing. Spawning/targeting run inside each
measured game callback. An additional read-only census is measured separately.

This advances full-combat evidence beyond the firing range. It does not complete
the remaining sustained stress, movement/status/migration comparisons, other ports,
authoring-change measurements or paired human playtests. Exact gameplay parity is
not inferred from matching aggregate totals.

## Measured snapshot scan optimization

The [scan result](results/snapshot-scans-2026-09-08/README.md) pairs independent
byte-format oracles and executed native/WASM equivalence with six input-density
microbenchmarks, three real combat pairs and a separate phase diagnostic. Canonical
hashes and delta bytes remain identical. Long zero/equal regions improve, with a
retained fragmented-input regression. Host callback cost falls in the new cohort;
client median changes little and the overall Kit/Replay cost gap remains. Wider
stress/latency and authoring comparisons remain required for an adoption decision.

<a id="compatibility-authoring-example"></a>

## Adding a field while preserving saves

The [recorded spread-hop change](results/scrapyard-cast-paths-2026-09-08/README.md)
adds one explicit Flash discriminator without widening world bytes. Preserving
older saves still required an old-world descriptor and field mapping (112 lines),
CLI routing and historical/fresh-resume validation. This is concrete compatibility
work beyond gameplay code; it is not a timed comparison against Kit. Include it
in the remaining M9 authoring/API evaluation before claiming singleplayer-like
change effort or deciding to adopt the framework.

## Executable authoring change: paid revive

The [paid-revive experiment](results/paid-revive-authoring-2026-09-08/README.md)
installs the same cross-player wallet/health rule into isolated Kit and Replay
copies, preserves the actual feature patches and runs a shared three-player
contract. The first full matrix covers funded, funding-while-held and contended
revives locally and with receive delay. It separates source-change evidence from
sampled replication behavior and explicitly excludes human productivity claims.
The [harness](../../tests/replay_authoring/README.md) rebuilds both playable variants;
other feature changes and authoring/debugging measurements remain required.

## Executable authoring change: existing-family weapon

The [weapon experiment](results/weapon-authoring-2026-09-08/README.md) adds one
identical resource in both games, with no handwritten gameplay/network changes.
Replay's separate generated stock table is recorded as derived work. Independently
built clients without the resource receive the host's definition and use it for
selection, presentation, damage and reloads. This complements the paid-revive
case; it does not measure human authoring time or a new weapon family's cost.

## Sustained offensive population comparison

The [swarm harness](../../tests/replay_swarm_comparison/README.md) keeps forty stock
scrapbots active for twenty seconds with ordinary combat/pickups and replenishment.
Shared zero-bite and large-magazine fixtures prevent player wipes/reload pauses.
Three alternating pairs and twenty report checks pass with 38–40 living enemies,
measured turnover, authority conservation and converged final peer state.

The [result](results/scrapyard-swarm-2026-09-08/README.md) reports callback cost,
application output, instrumented RSS and receive freshness. Large snapshots awaiting
acknowledgment leave authority frames behind received facts; a separate diagnostic
hit a presentation error during fill. Both remain readiness findings. Versioned
contracts and rejected cohorts are retained. This advances sustained offensive
evidence; movement, statuses/abilities, player damage, faults and full-game/human
comparisons remain distinct requirements.

## Snapshot delivery tradeoff

[Snapshot parts](results/snapshot-parts-2026-09-08/README.md) repeat the same swarm
contract after adding negotiated bounded unreliable delivery for large state.
Median/p95 extra lag behind received facts falls from 9/17 ticks to 4–5/6, while
Replay host output rises from about 43 KB/s to 263 KB/s and client correction work
increases. Kit remains lower in callback and traffic cost. The retained artifacts
include the controlled delivery comparison, current cohort, old/new protocol
interoperability and actual browser part counters. This is measured progress with
visible costs; payload reduction, sustained real faults and the full adoption gate
remain requirements.

## Canonical payload attribution and compression

The [payload/codec result](results/lz4-deltas-2026-09-08/README.md) attributes exact
sparse delta bytes to state groups, then compares lossless encodings while retaining
all history/query data. The selected age-sixteen payload falls from about 9,774 to
6,969 bytes. Native/WASM and reference checks preserve decoded bytes; the repeated
swarm reaches 3/4-tick median/p95 extra lag behind received facts. Host output stays
near its configured budget and client correction work increases. Source/build
identity, initial/final cohorts, rejected prototypes and mixed-peer browser evidence
are retained; this is not a full adoption or human-responsiveness verdict.

## Raw-UDP fault envelope

The [native ENet fault matrix](results/raw-udp-faults-2026-09-08/README.md) adds
packet-level loss/jitter/duplication and a bounded rate/queue model to the sustained
Replay offensive swarm. Both conditions pass twice with final state convergence,
packet accounting and explicitly allowed recovery intervals. It is Replay acceptance,
not a paired Kit benchmark. The evidence includes the corrected token-bucket proxy,
rejected initial runs, sender/timing/fact-delivery changes and browser/migration
follow-up. Full mixed gameplay, wider platforms/routes and adoption remain separate
requirements.

## Speedball session/social port

The [separate Speedball UI result](results/speedball-ui-2026-09-08/README.md) adds
direct session menus, validated names, host-only start, chat/input capture, held
scores/telemetry and leave/rejoin handling. Existing solo/contested-ball rules and
response gates still pass. Native captures provide initial layout evidence; the
port ledger retains trust/timeline differences and unimplemented paths. This is
port acceptance, not a paired authoring-time or performance result.


## Speedball native Room integration

The [Speedball migration result](results/speedball-room-2026-09-08/README.md)
exercises a nonzero score and moving ball through planned handoff and abrupt host
loss. The successor restores the exact prepared frame; surviving peers agree on
a later canonical world after two fresh spikes and new-epoch chat. Rendered native
captures cover the handoff/recovery UI. Existing direct-session and contested-ball
gates remain separate checks.

This is a functional Replay port result, not a matched Kit/Replay timing study.
Reported interruption is the Room driver's local recovery interval; it excludes
some time before failure detection and must not be described as total outage.
The fixed local roster/credentials do not establish public enrollment or discovery.


## Speedball match and local identity lifecycle

The [round/profile result](results/speedball-rounds-2026-09-08/README.md) adds a
validated Play again command and native reconnect/name profiles. Three peers finish
two matches in one session, reject a guest restart, retain their roster and resume
chat. A killed client is replaced by a fresh process using its persisted identity,
which must reclaim seat 2 and the chosen name. Corrupt-profile cases preserve the
files; deterministic token overrides bypass profile storage.

Original Speedball inherits persistent reconnect identity from Kit boot. Its game
scripts do not supply restart or match save/load menus. Play again and persisted
display names are added Replay behavior; this result is not evidence of a matched
legacy authoring/runtime comparison. The subsequent save/discovery result below
supplies the native direct-session save/resume flow.


## Speedball save/resume and direct epoch query

The [save/discovery result](results/speedball-save-2026-09-08/README.md) restores a
scored, moving pitch in fresh solo and host processes, then admits a fresh client
through the normal Join flow. The new opt-in query learns a direct host's epoch
before the existing strict handshake; no epoch number is supplied by the harness.
Wrong-profile and damaged/missing archives fail before creating a session. Continued
spikes, match completion, restart and chat pass after restore.

This fills a Replay lifecycle flow, not an original Speedball save-menu parity
claim or a Kit/Replay timing comparison. Room retains coordinator-controlled
recovery; direct file resume does not elect or fence competing hosts. Browser saves
and public-room integration remain separate work.


## Speedball native parties and observers

The [native party result](results/speedball-party-2026-09-08/README.md) adds the shared
Party helper to Speedball's scene. Verified WSS enrollment and private credential
storage precede Room admission; personal identity/name storage stays separate.
Planned handoff and owner loss restore a moving scored checkpoint, then a fresh
former-host process rejoins the same seat with a stable invite and newer incarnation.
The observer remains seat 0, receives no checkpoint and can leave/rejoin in that
mode. New spikes/chat and a common later world are required among the final trio.

The Room driver had forced joining members to the player role. It now preserves an
explicit Observer request. This result covers that native lifecycle; it does not
establish observer invitation permission isolation, browser/Steam behavior, Internet
reachability or a comparative authoring/performance advantage over Kit.


## Speedball browser party lifecycle

The [Chrome/WebRTC result](results/speedball-browser-2026-09-08/README.md) ports the
same scene/model/Party flow to a Web export. Personal identity/name and room
credentials persist separately. Planned handoff and host-browser closure restore
an exact moving/scored checkpoint; a true observer leaves/rejoins, and the former
host returns in a fresh browser process with the same identity/name/invite/seat.
New spikes/chat precede a common retained canonical world on all three clients.

This is local browser functional evidence, not a native/browser determinism claim
or Kit/Replay performance comparison. The gate does not cover public TLS/TURN,
raw network faults, OS-kill durability or other browser engines. Those remain
separate requirements along with browser saves and broader playtest coverage.


## Speedball browser solo saves

The [browser save result](results/speedball-browser-save-2026-09-08/README.md) adds
named, identity-scoped IndexedDB slots through the existing Browser_Checkpoint
adapter. A completed save survives a killed Chrome process, restores exactly,
continues gameplay and restarts into round 2. Stale tabs cannot replace a newer
revision; damaged archive/identity records remain intact, and a different slot can
be used for new play. Native saves and browser parties remain regression gates.

This measures local process-crash recovery and explicit storage failure behavior,
not a Kit/Replay timing advantage, power-loss guarantee or general browser-storage
availability. Room save publication, other browsers and broader deployment/
playtest/comparison requirements remain.


## Moving/status swarm comparison

The [mixed cohort](results/scrapyard-mixed-2026-09-08/README.md) measures three
alternating Kit/Replay pairs using the existing replenished forty-enemy fixture,
cardinal player movement and stock frostwave/battlecry casts. All twelve processes
pass population/freshness, status/cooldown exposure, movement, conservation and
settled-peer convergence checks; thirty report acceptance/rejection cases pass.

Median p95 callbacks are 791/656 µs for Kit host/client and 1,901/3,229 µs for Replay.
Median application output is about 30,856/2,092 B/s and 252,362/17,583 B/s,
respectively. Replay clients remain at p95 five extra fact-lag ticks with no
measurement resync. Movement paths and kills differ; this is an identical intent/
fixture envelope with measured outcomes, not identical execution or a framework-only
ratio. Kit remains cheaper in these inclusive callback/traffic measurements. The
result advances the mixed-workload gate without settling the full M9 adoption case.


## Owner-unwind qualification of the mixed cohort

The [causal control](results/owner-unwind-2026-09-08/README.md) identifies a reproduced
Kit defect behind the mixed cohort's second-player movement loss. Pending-command
delta unwind restores an older owner-streamed position. An engine-free case fails
at x=100 instead of 140; an isolated owner-preserving control passes it and all 58
existing Kit networking tests. Three live original/control pairs show 401–442
backward packet-processing moves per original client and zero under the control.
The movement step itself never reverses the active input.

Original game/framework sources remain preserved. Earlier costs are still the
observations of those binaries, but now carry this explicit baseline qualification.
The instrumented control is not a replacement timing cohort. Further comparison
with a corrected baseline, plus remaining gameplay/transient differences, is needed
before attributing costs or choosing adoption.


## Mixed comparison with the isolated owner-unwind repair

The [corrected-baseline cohort](results/mixed-owner-control-2026-09-08/README.md)
uses the copied Kit repair from the movement audit and the normal mixed benchmark
adapters, with no extra packet-bracketing instrumentation. Replay uses the original
collection root. Twelve process windows and thirty-five report validation cases
pass; the declared collection/source control is checked explicitly.

No backward owner motion occurs in the corrected Kit client traces. Median p95
callbacks are 899/804 µs for Kit host/client and 2,024/3,467 µs for Replay; application
output is about 29,110/2,092 B/s and 252,349/17,645 B/s. Player travel is much closer
than in the defective baseline, while shots, kills and timeline observations still
differ. The cost gap persists in this supported envelope; it remains an inclusive
product-workload result, not a framework-only ratio or a final adoption decision.
Original Kit and game sources stay untouched.


## Staged LZ4 encoding follow-up

The [staging result](results/lz4-staging-2026-09-08/README.md) replaces two encoder
search passes with one pass into bounded scratch and a final copy. It retains exact
wire bytes and atomic output failure, with 65,808 additional workspace bytes. The
corrected mixed cohort passes again: Replay host median p95 is 1,845 µs versus 2,024
in the preceding cohort. Host p50 does not improve, and separate instrumented
whole-frame means vary upward even while snapshot-delta work falls from 401.1 to
301.9 µs. The result is a targeted encoder improvement, not a uniform game speedup.


## Exact correction reuse experiment

The [reuse result](results/correction-reuse-2026-09-08/README.md) verifies an explicit
fast path for byte-identical predecessor states and rewritten inputs. A matching
64 KiB synthetic state improves substantially, but the mixed cohort reuses only
111–133 correction records per client alongside roughly 9,925 simulated ticks.
Client p95 is 3,266 µs versus 3,273 in the preceding cohort, so no broad workload
speedup is established. It stays opt-in; atomic correction, event handling and
ordinary audit/full-replay behavior remain separately checked.
