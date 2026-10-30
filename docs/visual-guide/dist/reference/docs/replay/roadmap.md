# Replay roadmap and implementation plan

**Current priority:** [finish the framework](framework-completion.md). On
2026-09-20 the user redirected work away from exhaustive parity across all games.
That completion plan takes precedence over game-parity gates below. The original
milestones and results remain design/history references, not a requirement to
finish every remake before completing the framework. Both versions stay preserved.

The revised framework-first scope now has a completed
[experimental release assessment](release-assessment.md). Historical open parity
and external/platform rows below remain history/follow-up, not claims of verified
completion or reasons to restart an exhaustive game campaign.

This is an experimental second library for Odin/Godot multiplayer. Its purpose
is to test whether a complete replayable world makes gameplay easier to author,
debug, and migrate than the existing per-field Kit model. The existing framework
and existing games remain available throughout the experiment.

Read [architecture](architecture.md) for invariants and the initial API, and
[comparison](comparison.md) for the game inventory and evaluation protocol.

## Outcomes and constraints

- One gameplay simulation contract for offline play, player-hosted co-op,
  server-authoritative action, and eventually deterministic P2P rollback.
- Ordinary cross-entity gameplay operations, replayable entity lifetime, and
  automatic separation of simulation from presentation.
- Host migration, late join, reconnect, saves, and diagnostics designed around
  explicit checkpoints and session state.
- Godot remains the scene editor and presentation engine; Odin simulation is
  executable without Godot.
- Both versions of every ported game must exist and remain independently
  runnable. Ports use new paths and isolated state/configuration.
- No claimed multiplayer mode before real-process acceptance tests pass. A
  configuration preset cannot confer determinism, authority, or network reachability.
- No automatic replacement of Kit or full-game rewrite before evidence supports
  the new model. Every milestone is independently reviewable.

## Implementation status

Replay includes the local value-state core, presentation journal/clock, Godot
adapters, canonical schemas, server-authoritative networking, deterministic P2P
rollback, complete recovery checkpoints, and separate game ports. Native/browser
recovery, admission, asset dependencies and durable saves have recorded acceptance
cases. This is still an experiment: deployment, platform, parity and comparison
gates below remain open, and a passing local scenario is not a general guarantee.

See [recovery](recovery.md) for guarantees and [progress](progress.md) for evidence.
Framework completion is governed by [the current plan](framework-completion.md).
The historical milestone table below retains implementation status and deferred
game work; an open parity row alone does not imply a missing framework capability.

| Milestone | Status | Completion gate |
| --- | --- | --- |
| M0: architecture and comparison plan | Complete | Explicit model, preserved baselines, measurable port sequence |
| M1: local replay core | Complete for initial value-storage scope | Corrected inputs converge with fresh execution; lifetime/RNG/events restore coherently |
| M2: presentation and Godot hello | Technical presentation/input gates audited; ordinary pause and shared runtime alias authoring fixed; human visual/play-feel review remains open | Playable offline scene, rewindable gameplay, correct effect reconciliation |
| M3: schema and server-authoritative networking | Gameplay, deltas, recipient views, fault gates, WebRTC, TURN UDP/TCP, browser UDP datagram faults and authenticated credential refresh tested; broader deployment/recovery review pending | Real server/client/observer convergence under recorded network faults |
| M4: co-op policies and Cavecrawl port | Captured floors, lobby/social/progression, online create/join/rejoin menus, native/browser migration and durable browser saves tested; public/visual parity pending | Co-op feature parity and cross-entity interaction ergonomics |
| M5: session recovery and host migration | Live failure matrix, durable admission/journals, shared party menus, relay outage and authenticated RTC continuation tested; public deployment and broader recovery work pending | Planned and abrupt takeover preserve documented guarantees |
| M6: competitive examples | Games/groups and session UI tested; current observer fault/refresh contract passes; older C2 effect-loss cause remains historically unestablished; game parity is deferred by the framework-first plan | Quickdraw and ball-game scenarios pass with measured latency/correction behavior |
| M7: deterministic P2P runner | Native/WebRTC duel, archive/spectator recovery, durable provisioning, authenticated native two-player and browser invite/return, cross-target checks and initial CPU/latency measurements pass; broader OS/hardware and public deployment pending | Cross-target state equality and bounded rollback under input loss |
| M8: Scrapyard reimplementation | Separate arena/staging, combat/run loop, profiles/sprays, shared online party menus, native/Chrome asset-aware recovery, editor workbench and audio/settings; full listening/visual parity, recovery and comparison pending | Existing scenario inventory ported and playable feature parity |
| M9: comparison and stabilization | Scoped paired gameplay/authoring comparisons, Godot ABI corrections and loaded browser recovery pass; the recorded public-history bandwidth failure is addressed; broader comparison, presentation, stress and stabilization pending | Measured decision to adopt, revise, or retain as an experiment |

The [recent-fact encoding increment](results/compact-recent-facts-2026-09-20/README.md)
reduces measured quiet Cavecrawl host application traffic by 30.6% while retaining
complete facts and delivery cadence. Negotiation/legacy, bounded decoding,
recipient filtering and native/browser recovery gates pass. This closes that
measured header-overhead follow-up; broader M3/M9 completion remains open.

The latest [authority hit-history increment](results/authority-hit-history-2026-09-14/README.md)
addresses the recorded loaded Scrapyard raw-UDP freshness failure for the tested
planned/crash profile by excluding authority rewind history from public snapshots.
Complete checkpoints, old-save conversion and historical authority combat remain
verified. The measured envelope is local; broader deployment and parity remain open.

Earlier steps established [real browser TURN fault injection](results/browser-turn-udp-faults-2026-09-14/README.md),
[negotiated RTC control delivery and legacy compatibility](results/rtc-control-stream-2026-09-14/README.md),
and [correct Godot scalar/enum call storage](results/ptrcall-abi-2026-09-14/README.md).
Their rejected loaded runs and queue/pacing/fence candidates remain evidence of
those earlier versions, rather than current completion claims.

Sequence is dependency-based, not a calendar estimate. M2 should challenge M1's
API before schema/codegen freezes it. M5 is required before calling the co-op
library a replacement for Kit. M7 can proceed independently after the shared
schema/session prerequisites; Scrapyard's server/co-op port does not require it.

## M0 — Preserve baselines and define the experiment

Implementation:

1. Establish `replay` as an experimental package independent of Kit.
2. Record original source revisions, available games, current capability gaps,
   and a paired-directory convention.
3. Write invariants for frames, event identity, history misses, authority,
   and complete versus recipient-filtered snapshots.
4. Define comparison scenarios, result metadata, and measurements before ports.

Gate: an unfamiliar contributor can identify what exists today, how to run it,
which old game is the baseline for each port, and what would disprove an
ergonomics or performance claim.

## M1 — Local replay core

Initial implementation:

- `Frame(State)` and `Timeline(State, Input, Event)` with explicit starting tick.
- Recursive rejection of reference-bearing state/input/event values.
- Bounded full-frame history and preallocated transactional replay scratch.
- `advance`, `read`, `current`, `rewind`, and full-batch `revise_input`.
- Tick-stamped occurrences with semantic IDs and bounded capacity.
- Value-owned entity pools with generation handles and deterministic allocation.
- Frame-owned RNG and local replay audit.
- Loot/projectile example: contested inventory transfer, despawn, projectile
  creation/expiry, corrected input, independent reference run, checkpoint resume.
- Native behavior tests and WASM type-check integrated into the repository suite.

Acceptance:

- Revised timelines equal a fresh run given the corrected input sequence.
- Both inventories, chest membership, projectile lifetime, allocator state, RNG,
  and occurrence history agree—not only entity positions.
- Event overflow, duplicate identity, or failure late in a replay cannot commit
  a partial candidate or change stored inputs.
- Tick zero is valid. Missing/wrapped history is reported without approximating
  from head state. Tick overflow is explicit.
- Reads cannot mutate saved frames or events; old pool handles reject recycled slots.
- An intentionally impure step is caught by audit as a state or event mismatch.

Follow-up before larger state stores: decide whether the typed whole-world API
remains ergonomic in M2; measure memory/copy cost; add managed variable-size
collections only with a clear ownership and serialization contract. Tagged value
unions now have replay, canonical codec, native/WASM/x86-64 and ENet acceptance.
Immutable asset handles need their own complete storage contract. Owned audit capture and
canonical field diagnostics now have native/WASM checks and a real-save inspection
tool. An opt-in live Godot overlay now exposes local/Session status and bounded
audit reports in Hello and Cavecrawl. The [local history dock](../../replay/godot/debug/scrubber.md)
now inspects retained frames and explicitly resumes or branches Hello's offline
timeline, with native/browser view and input checks. A generic scalar editor now
validates changes to a copied preview before an explicit local branch; see the
[field-editor acceptance](results/field-editor-2026-09-14/README.md). Portable local
recordings now export the replayable suffix and verify complete frames/events in
fresh native/WASM processes; [acceptance](results/local-recording-2026-09-14/README.md)
includes native Godot and completed Chrome downloads. The
[loaded-recording viewer](results/recording-playback-2026-09-14/README.md) now opens
those files in native/Chrome Godot, presents expected frames and mismatch details,
and supports an explicit branch while preserving the original game. The
[network recording adapter](results/network-recording-2026-09-14/README.md) now
preserves full network batches and recorded admission decisions in real Scrapyard
authority/prediction/browser exports, with native/WASM verification. Continuous/
multi-window recording, coordinated multi-field editing and richer network-runner
tools remain additional work.

## M2 — Presentation and Godot hello

Depends on M1. Target: `examples/replay_hello/`, keeping `hello_net` and
`hello_sim` intact.

Implementation:

1. Build `replay/view`: separate current/past frame sampling, pose extraction,
   teleport discontinuities, and correction smoothing. Simulation values never
   become temporary render values.
2. Compare event journals by semantic ID. Define predicted, confirmed, changed,
   and canceled occurrences, retention bounds, and rejoin seeding. Retain event
   payload/pose independently of dead simulation entities.
3. Add explicit confirmation/commit frontier plumbing. Continuous effects and
   one-shots have different presentation policies. Irreversible external effects
   stay outside speculative simulation.
4. Create a small Godot adapter mapping handles to scene instances. Manage
   view creation/destruction independently of frame entity lifetime.
5. Add frame-rate input sampling into fixed ticks and an offline runner with
   bounded catch-up. Document sub-tick input accumulation and button-edge handling.
6. Build reusable kinematic movement, static collision queries, and tick timers.
   Map authored scene data into immutable simulation definitions.
7. Add editor diagnostics and explicit codegen hooks only where hand wiring has
   demonstrated repetition. Keep generated simulation types separate from node
   types and preserve a codegen-free route.

Acceptance:

- Same movement/input code runs in the headless fixture and Godot scene.
- Rewind across spawn/death recreates the right view without stale handles.
- Replaying a shot doesn't double-play an effect; a removed speculative effect
  produces a cancellation; death effects can outlive their source entity.
- Camera smoothing and remote interpolation never alter simulation checksums.
- Held buttons, short presses, pause, and variable render rates behave consistently.

The [M2 acceptance audit](m2-acceptance.md) now maps all seven implementation
items and five acceptance gates to source and runtime evidence. It found and fixed
ordinary Hello pause-input leakage, with native four-rate and Chrome regressions.
The [shared Timeline alias defect](results/shared-alias-2026-09-20/README.md) is now
fixed with guardrail and real-application acceptance. Human play-feel review remains
unperformed, so the milestone stays open rather than being inferred complete from
implementation coverage.

The [bounded rock-presentation increment](results/cave-rocks-2026-09-20/README.md)
adds render-frame motion, centering and stall-safe phase selection to both Cavecrawl
profiles. Native 30/60/144-FPS host/client/observer sampling, immutable-frame render
checks, Chrome and full campaigns pass. Immediate pre-tick cast/contact overlays
and wider presentation parity remain separate gates.

The [C9/O3 impact increment](results/cave-impact-2026-09-20/README.md) now adds
nonlethal/lethal dweller Hit occurrences and generation-bound flashes. Old-save
conversion, explicit old recording rules, native/WASM execution, three full
campaigns, rendering and current-content service/browser recovery pass. Render-rate
projectile presentation and broader parity remain open.

The [Cavecrawl feedback increment](results/cave-feedback-2026-09-20/README.md)
adds reusable bounded visual cues and real combat bursts/flashes. Native/rendered
and Chrome lifecycle checks cover correction, deduplication and cancellation;
three complete multi-process campaigns preserve gameplay and present the expected
death/hit occurrences. Remaining projectile/contact and broader visual parity
remain explicit in the game's ledger.

The [local history-inspection increment](results/history-inspection-2026-09-13/README.md)
adds retained-window metadata and opt-in Godot controls for paused frame selection,
original-future resume and explicit branching. Native, rendered and Chrome checks
cover view lifetime, effect suppression, input guards and bounded retention. A
flash-only immutable mesh fixes the browser rendering error exposed by repeated
shots. These local authoring controls do not pause or rewrite network sessions.

## M3 — Schema and server-authoritative networking

Depends on M1; uses M2 for visual acceptance. Port the server-authoritative hello
into the same new project with an explicit runner choice.

Implementation:

1. Define a logical schema and generated canonical field-wise codecs. Specify
   fixed widths, endianness, finite-value rules, bounds, and protocol/content IDs.
   Compiler padding must not be protocol data. Decode transactionally.
2. Separate complete authority checkpoint serialization from per-recipient state
   projections; hidden state must not leak through normal snapshots.
3. Build a transport interface and deterministic in-memory fault simulator.
   Adapt ENet first; add WebRTC/Steam through the same packet interface.
   WebRTC is exercised by browser games; the [Steam adapter](../../replay/godot/transport/steam.md)
   now has contract/native-capability checks, with live-account acceptance pending.
4. Implement session handshake, stable seats, input ownership, input windows,
   action sequencing/deduplication, timing bounds, and validated admission.
5. Implement authority input scheduling and client prediction. Define held-input
   and one-shot action loss behavior separately. Log accepted input decisions.
6. Add authoritative **state** correction and suffix replay to complement M1's
   explicit input revision. Preserve event reconciliation/commit semantics.
7. Add snapshot acknowledgements, baseline recovery, compression, clock/lead
   control, and a full resync path when history is insufficient.
8. Add per-peer traffic/work budgets, malformed-packet corpora, and diagnostics.

Acceptance:

- Host/client/observer are real separate processes and converge under latency,
  jitter, reordering, duplication, and loss; input correction isn't used as a
  substitute for exercising the actual protocol.
- A client cannot supply another seat's inputs or write authoritative state.
- Wrong schema/content, invalid values, stale/future inputs, and oversized
  payloads are rejected before partial mutation or unbounded allocation.
- Blackouts longer than history trigger deliberate resync, not approximate replay.
- Baseline loss and reconnect do not create ghost entities or repeat accepted actions.
- Same machine/seed/fault schedule produces a reusable failure recording.

The [receive-backlog fix](results/receive-backlog-2026-09-13/README.md) now applies
usable retained snapshots before a receive batch exhausts the fact ring, including
when a later fact is delayed. Player/observer regressions preserve watched effects;
missing snapshots still force explicit resync. History and output budgets remain
bounded. This establishes one failure cause and fix, not the exact cause of the
separate intermittent live Claimball observer failure.

The [live transport recorder](results/transport-recording-2026-09-14/README.md)
now captures real interface observations and caller pump/configuration marks for
strict offline replay. Claimball fault and local-stall schedules reproduce every
transport operation and state/effect hash; altered expectations are rejected.
The historical observer loss remains unestablished: the tested stalled streams
also pass on the archived older receiver. Broader callers and failing schedules
still need coverage.

The [archived C2 investigation](results/claimball-c2-recording-2026-09-14/README.md)
now reconstructs the original app/receiver and compares fault-seeded streams against
old/current receivers using that same model. Seven exact comparisons pass; none
reproduces the historical loss, so its cause remains open.

The [receive-budget fix](results/receive-budget-2026-09-14/README.md) separately
reproduces lost reliable facts/actions when a dequeued packet crosses the pump's
byte budget. Both loops now use the existing short-buffer retention contract.
Unit, real ENet/RTC and current Claimball trace gates pass with unchanged budgets.
The original C2 missing-effect cause remains unestablished.

## M4 — Co-op policies and Cavecrawl port

Depends on M2–M3. Targets: `examples/replay_cavecrawl/` and later
`examples/replay_slopball/` / `examples/replay_slopball3d/`.

Implementation:

1. Separate input ownership from state authority and presentation ownership.
   Make authority handoff explicit, tick-stamped, and versioned.
2. Add owner-streamed objects/physics through a capability profile. Document
   their trust model and interaction with the replayable world; casts against
   current engine poses cannot masquerade as historical dynamic queries.
3. Provide reusable inventory transfers, interactions, cooldowns, damage, AI
   timers, and spawn helpers over managed world state.
   [Versioned per-action timing](results/action-schedule-2026-09-09/README.md) now
   combines receipt-time discrete intents with scheduled actions in one model,
   preserving explicit results, FIFO ordering and recorded checkpoint admission.
   [Copied action intents](results/action-intent-2026-09-09/README.md) now reuse
   input latching and epoch-scoped result/recovery bookkeeping through Session
   and Room. Scrapyard's dash port and native recovery/input gates exercise it.
4. Port Cavecrawl in vertical slices: movement and doors; contested loot and
   inventory; combat; AI and progression; session UI and saves.
   Resource/marker definitions are now captured in the cave world, with original
   seeded decoration and explicit older-Replay-save conversion. See the
   [authoring contract](../../examples/replay_cavecrawl/authoring.md).
5. Add durable save/schema versioning and late-join world reconstruction.
   Persistent services use committed outcomes and explicit idempotency keys.
6. Introduce interest management separately from simulation dependency selection.
   [Recipient views](../../replay/net/replication.md) now filter state, controls and
   events with complete authority archives retained; fixed carrier storage remains.
   Measure full-world copying before considering domain partitioning.

Acceptance:

- Both versions launch independently. Matched item/door/combat scenarios preserve
  the same authored rules and assets.
- Two players contesting an item conserve inventory through correction/reconnect.
- A late join reconstructs the current world without replaying old cosmetic events.
- Owner changes preserve intended momentum/control and reject old-owner messages.
- Collect ergonomic measurements before and after each gameplay slice.

The [Cavecrawl social-detail gate](results/cave-social-details-2026-09-14/README.md)
now covers measured scoreboard latency, stamped ping names, rename/input capture,
expiry/rejoin and a browser handoff with fresh telemetry and old-scope marker
retirement. This closes those presentation rows while broader parity remains open.

The [C4 director comparison](results/cave-director-2026-09-14/README.md) corrects
initial/within-wave pacing, death-anchored rests, empty waves and per-floor den
selection. Original/native/WASM oracle, full campaigns, explicit C1–C3 conversion,
checkpoint service and browser handoff checks pass. Broader floor-state/physics
and human parity boundaries remain explicit.

The [C5 avatar-transition increment](results/cave-floor-state-2026-09-14/README.md)
now preserves vitals/cooldowns/status on descent and separates initial/restart
resets. Native transition frames, rollback, C1–C4 conversion, full campaigns,
checkpoint publication and browser handoff pass. Relic and broader floor/physics
correspondence remain tracked separately.

The [C6 relic-lifetime increment](results/cave-relic-2026-09-14/README.md)
retains resting/carried relics across descent, releases in place on restart, and
matches original initial placement/carry offset. Unit/rollback, native transition,
C1–C5 conversion, complete campaigns, checkpoint-service restore and browser
handoff checks pass.
Server-simulated motion and death/disconnect release remain explicit differences.

The [C7 carrier-lifecycle increment](results/cave-carrier-2026-09-14/README.md)
retains ownership through death/disconnect/rejoin and releases on identity
replacement. Native planned/crash handoffs with successor/guest carriers, a
three-browser carried-relic handoff/release, complete campaigns and C1–C6 save
conversion pass. Kit's separate old-host prop adoption rule remains open: Replay
needs an explicit recorded authority-change policy to reproduce that behavior
without consulting mutable process roles during replay.

The [recorded authority-observation increment](results/authority-observation-2026-09-14/README.md)
adds a versioned network-model policy and C8 old-host relic adoption. The first
committed recovery tick adopts the prop; avatars and unrelated carriers retain
identity. Native planned/crash and browser transfer/release gates pass. Explicit
C1–C7 save conversion seeds the new authority fields from checkpoint metadata;
older diagnostic Batch recordings have a separate explicit conversion path.
Owner-streamed motion and broader parity/shared-authority policies remain open.

The [Cavecrawl owner-motion increment](results/cave-owner-2026-09-19/README.md)
adds a separately runnable latest-observation profile over the common C8 gameplay.
Native loot/door play, relic handoff under faults, planned/crash carrier recovery,
life/floor scope fencing and typed checkpoint-service restore have acceptance
cases. C8 and original Kit projects remain available. Browser execution, full
original command/pose/presentation parity and paired comparison remain required.

The [owner-profile browser increment](results/cave-owner-browser-2026-09-19/README.md)
now verifies real Chrome/WebRTC planned and abrupt carried-relic recovery, fresh
post-takeover samples/release, social state and profile reload. Default-namespace
browser saves preserve exact restored frames, conflicting writes and corrupt data.
Broader browser/public-network, original-rule/presentation and comparison gates remain.

The [owner action-context increment](results/owner-action-context-2026-09-20/README.md)
now carries scope-bound command origins independently of latest motion. Cavecrawl
O2 reproduces original range/throw-origin rules without rewinding the avatar;
real suppressed-motion delivery, old-scope rejection, conversion and native/browser
recovery pass. Unsubmitted startup intents wait for an authorized producer scope.
Full original gameplay/presentation and paired comparison remain required.

## M5 — Session recovery and host migration

Depends on M3 and relevant M4 session/save work. Host migration is a required
capability, not an optional stretch goal. The existing Kit implementation's
`boot_migration` currently rejects a sim lane, so acceptance must include a
running replayed simulation as well as a co-op session.

Implementation:

1. Specify a `Migration_Checkpoint`: complete authority frame, tick and authority
   term, content/schema versions, roster and stable reconnect identity, ownership,
   allocation state, room permissions, accepted action/dedup frontiers, and
   committed-effect/outbox position where relevant.
2. Replicate bounded, acknowledged checkpoints to an eligible successor. A
   successor may need authority-only data absent from its ordinary client view.
   Make that disclosure a trust decision. A dedicated competitive service fails
   over within trusted infrastructure, not automatically to a player.
3. Implement planned handoff with a final accepted frontier. Implement abrupt
   recovery from the latest usable replicated checkpoint.
4. Define leader selection and authority fencing. A term number alone does not
   resolve network partitions or establish a legitimate leader. Select a room
   coordinator or an explicit election/availability policy and test partition cases.
5. Implement rendezvous, successor eligibility/replacement, reconnect retries,
   peer reseating, and a fresh runner's prediction/history initialization.
   The [admission backend](../../replay/provision/README.md) now stores credentials,
   roster changes and invite consumption together, with exact join retries and
   before/after-commit process-kill tests. Its bounded hub and create/join protocol
   now pass native verified-TLS acceptance. The [client journal](../../replay/provision/enrollment.md)
   adds durable native/browser requests and credentials with crash/competing-writer
   tests. Cavecrawl's online menu and repeatable co-op invite now pass native TLS
   and browser RTC gates using the standalone room service. Scrapyard now uses
   the same Party helper with progression/profile separation and asset preparation.
   Other game menus,
   invite rotation/revocation UX and public deployment still need integration.
6. Preserve or deliberately retire in-flight input/action IDs. Reject old-term
   traffic; never infer exactly-once behavior solely from reliable transport.
7. Rebuild views and reconcile speculative occurrences around the resume point.
   Report migration phase, interruption, and recovered/lost tick range.
8. Evaluate checkpoint-plus-log recovery only after snapshot recovery is correct.
   Replaying beyond the checkpoint requires sufficient accepted input and
   authority-decision history plus reproducible simulation.
9. Persist shared room saves independently of connected participants. The native
   [checkpoint store](../../replay/provision/checkpoints.md) now atomically retains
   typed checkpoint bytes and publication metadata, fenced by both publication
   and coordinator revisions, with before/after-commit process-kill tests.
   The [authenticated transfer library](../../replay/provision/checkpoint/README.md)
   now passes registered upload/download, expiry/revocation/CAS fencing and native
   TLS service restart with a fresh trusted reader. The standalone service now
   registers Cavecrawl, Speedball and Scrapyard backends through a bounded room hub;
   all three actual game models pass native publication/download/restart gates.
   Room/Party now handles manual/automatic publication and exact lost-reply recovery;
   Cavecrawl's native and browser gates publish during play and after host migration.
   A separate guarded Restore API now grants a fresh registered process a newer
   epoch for an exact durable publication; native TLS tests restore all three game
   models and advance their simulation after service restart. Expiry/quarantine,
   request replay, policy and atomic epoch/frontier process-kill gates pass.
   Room/Party now drives published restoration and Cavecrawl's rejoin/retry UI
   passes native and browser service-kill tests with new guests and continued saves.
   Atomic checkpoint/asset packages now persist complete declared dependency sets;
   Scrapyard restores its spray from an empty cache in native and browser processes,
   continues firing and republishes. Publication/root/package commit-kill gates pass.
   Competing prepared fresh returners now pass native and browser Cavecrawl races:
   one wins epoch 2, the other follows, and subsequent loot is conserved in a new
   publication. Temporary checkpoint-service Busy responses retry automatically.
   Remaining game save/restore acceptance, broader asset profiles,
   broader recovery policy cases and remaining game UI remain required;
   storing a save does not grant authority. The linked plan specifies these steps.

Acceptance:

- Clean handoff, crash during combat, crash during loot transfer, successor loss,
  consecutive migrations, and old-host return all have explicit outcomes.
- Stale-term messages cannot mutate the resumed world.
- Entity allocation, RNG, attack phase, cooldowns, scheduled spawns, room bans,
  inventory, and stable identities survive within the documented recovery window.
- Retried accepted actions don't award loot twice; unreplicated work is not
  incorrectly claimed as durably preserved.
- A partition has a documented availability policy; peers never silently merge
  divergent authoritative inventories after independent continuations.
- Real-process crash test records interruption, rollback distance, checkpoint age,
  takeover bytes/CPU, and whether play remains responsive afterward.

The [Steam Room integration](results/steam-room-2026-09-20/README.md) adds explicit
Steam endpoint registration and fresh peers through planned/crash/repeated recovery
and returned-host flows. Local API-contract and existing ENet/RTC regressions pass;
live multi-account Steam and deployment acceptance remain required and unclaimed.

The [moderation increment](results/cave-moderation-2026-09-20/README.md) now links
Cavecrawl host removal to durable enrolled-member and prepared-successor exclusion.
Native/Chrome replacement takeover, old-service fallback, lost replies, SQLite
commit-kill, old/new control compatibility and ordinary recovery regressions pass.
Broader moderation UX/deployment and remaining recovery gates remain open.

The [Room transition-expiry fix](results/room-transition-expiry-2026-09-13/README.md)
preserves runtimes/prepared checkpoints when a valid lease reaches its deadline
between preflight checks. Injected planned/crash migrations resume through fresh
control progress; invalid clocks still fail. This fixes a proved boundary without
changing lease/rollback limits. It does not establish the cause of the separate
intermittent browser fencing incident.

The [delayed restore-grant renewal gate](results/restore-renewal-2026-09-14/README.md)
now covers a grant whose conservative local deadline expired before receipt while
the coordinator still reserves the same actor. Room renews that reservation before
installation and retains prepared state; expired coordinator reservations remain
refused. Native/browser full-party restores and the existing handoff-expiry gates
pass, with lease durations and commit requirements unchanged.

The [dedicated Room increment](results/dedicated-rooms-2026-09-14/README.md)
separates infrastructure identity from playable seats through bootstrap, standby,
planned/crash takeover and return. Native repeated failover and cooperative
regressions pass. A paired Scrapyard server act checks avatarless authority through
combat and floor progression; browser/Steam infrastructure and broader combat
recovery remain open.

The [browser infrastructure gate](results/dedicated-browser-2026-09-14/README.md)
now verifies avatarless Server/Observer role changes in four real Chrome processes,
with exact checkpoint restore through planned, crash/return and repeated takeover.
Actual RTC traffic is checked for each participant. This extends local dedicated
Room acceptance; public/Steam infrastructure and combat-stress envelopes remain open.

The [Scrapyard succession increment](results/scrapyard-succession-2026-09-19/README.md)
adds the original 150-tick attack/director timer reset as a recorded epoch policy.
Local native/Chrome planned and crash/return recovery now pass during a forty-enemy
combat wave, preserving the exact checkpoint before committing the policy and
requiring new shots, casts, kills and a reverse backup. Old saves convert explicitly;
historical recordings retain their old rules. Broader fault/deployment envelopes
and game parity remain open.

## M6 — Competitive examples

Depends on M2–M3. Targets: `examples/replay_quickdraw/`,
`examples/replay_speedball/`, and `examples/replay_claimball/`.

Implementation:

- Historical collision queries and bounded lag compensation tied to the shooter's
  validated view/input context.
- Predicted spawn IDs that match authority spawns, with lifetime restored through
  corrections and view events retained independently.
- Explicit prediction scope: self, a contested group, or the complete match.
- Historical remote collision proxies/boundary inputs where only part of a world
  is predicted. Group boundaries are authored and tested before optimization.
- Mixed-timeline presentation for shared objects; preserve the local causal
  response while measuring disagreement around remote interaction.

Acceptance: port Quickdraw's lag-compensation A/B, Speedball's contested ball,
and Claimball's presentation scenarios. Measure input-to-visible response,
correction size/frequency, replay depth/time, and repeated or missing effects.
Run the migrating simulation acceptance from M5 against at least one action game.

The [Speedball UI result](results/speedball-ui-2026-09-08/README.md) adds its direct
session front door, named chat/scoreboard and lifecycle controls, retaining the
contested-ball acceptance gate. The [Speedball migration result](results/speedball-room-2026-09-08/README.md)
adds the native Room path, moving scored checkpoint recovery and new-epoch social/
action acceptance. The [round/profile result](results/speedball-rounds-2026-09-08/README.md)
adds same-session Play again and native persistent identity/name handling. The
[save/discovery result](results/speedball-save-2026-09-08/README.md) adds direct native
save/resume and automatic pre-join epoch discovery. Its port ledger still requires
Steam, public deployment and wider
visual/play-feel work; other game ports remain independent requirements. The
[Speedball party result](results/speedball-party-2026-09-08/README.md) supplies native
create/invite/join/rejoin through a configured service, including true observers
through migration and a fresh-process returning host. The
[browser party result](results/speedball-browser-2026-09-08/README.md) now repeats
that lifecycle over local Chrome/WebRTC with persistent personal identity/name
and room credentials. The [browser solo save result](results/speedball-browser-save-2026-09-08/README.md)
adds exact checkpoint restore after a killed browser, continued play, named slots
and conflict/corruption preservation. Speedball now routes party Save/F5 and optional
cadence through Room. Fresh native/browser rejoin restores a scored first round,
admits a new guest, completes round 2 and republishes it with names/profile preserved.
Other browsers, public relay routing and broader workload acceptance remain required.

Quickdraw's [session UI increment](results/quickdraw-ui-2026-09-13/README.md) now
adds an interactive front door, authority-owned names/start state, literal chat,
named observers, a nonzero scoreboard and same-seat rejoin. The unchanged combat
A/B/lob gates pass, and planned/crash Room gates preserve named rows and chat across
exact combat restoration. Native profile and rendered UI checks pass. Broader
Quickdraw feedback, save/public/browser/Steam paths and human parity remain open.

The subsequent [Quickdraw feedback increment](results/quickdraw-feedback-2026-09-13/README.md)
restores the original sampled-health flash and independent skin/material colors,
and adds detached-pose landing rings with bounded lifetime and journal reconciliation.
Native host/client/observer, geometry, UI/profile and pure journal checks pass.
The original source has no landing-ring renderer; this addition is identified
separately from restored behavior. Broader visual/play-feel and platform gates remain.

Quickdraw's [native save/resume increment](results/quickdraw-save-2026-09-13/README.md)
now captures live combat through Save/F5 and restores exact frames in fresh solo/host
processes. Same-seat rejoin continues respawn, equipment, commands and named chat,
then verifies a common canonical world. Failed writes preserve the prior archive;
wrong-owner, damaged, missing, policy-protected and exhausted-epoch inputs are refused.
Browser/service save integration and broader parity remain independent work.

Quickdraw's [Party/browser increment](results/quickdraw-online-2026-09-13/README.md)
now uses shared enrollment, persistent browser profiles, WebRTC and Room recovery.
Four Chrome processes pass combat, planned/abrupt host replacement, true observer
rejoin and fresh host return with common worlds and named chat. Original/successor
publications reach the typed service backend and are independently decoded. Native
Party and direct file-save regressions pass. Public deployment, browser-local slots,
other platforms and human/paired comparison remain open.

[Quickdraw browser-local saves](results/quickdraw-browser-save-2026-09-13/README.md)
now use the shared IndexedDB checkpoint helper, persistent personal identity and
named slots. Fresh-browser exact restore, continued play, pending-write protection,
automatic resume, stale-tab refusal and corruption preservation pass. Direct native
file saves remain separate; Party publication is checked not to create local slots.
Public deployment and broader platform/play-feel gates remain required.

[Quickdraw abandoned-party restoration](results/quickdraw-party-restore-2026-09-13/README.md)
now exercises whole-party shutdown, restart of the service on its durable database,
guarded published restore, returning players/observer and a new publication. The
restored saved tick/hash and the continued common world are checked independently
of menu status. Native UI/profile checks and browser control-layout checks pass;
public deployment and broader restore races remain separate work.

The [native Quickdraw restoration gate](results/quickdraw-native-restore-2026-09-13/README.md)
now covers individual SQLite credentials, trusted local WSS, ENet gameplay, whole-party
shutdown and service restart. Exact saved-world restoration, returning seats/observer,
continued combat/chat and an independently decoded new publication pass. This adds
native transport/storage evidence without changing the shared recovery policy.

Claimball now has [native session/social UI](results/claimball-ui-2026-09-13/README.md),
[round-scoped Play again](results/claimball-rounds-2026-09-13/README.md),
[native save/resume](results/claimball-save-2026-09-13/README.md) and
[native Room migration](results/claimball-migration-2026-09-13/README.md), and
[Party/browser RTC integration](results/claimball-online-2026-09-13/README.md).
Hosted/dedicated/rendered repeated matches retain identity and chat while cutting
to reset positions. Exact moving/scored save restore, same-seat rejoin and continued
commands pass. Planned handoff and owner loss restore complete authority checkpoints
while clients keep one-avatar prediction, then agree on post-migration worlds.
The unique `claimball_pitch` package composes with other games without changing C3
wire/save contracts. Browser handoff/crash, observer rejoin, fresh host return and
typed durable publication now pass local gates. [Whole-party restoration](results/claimball-party-restore-2026-09-13/README.md)
also passes native WSS/ENet and browser RTC with all processes/service restarted,
independent source/continued checkpoint reads, retained identities/seats and new
gameplay. [Browser-local Solo slots](results/claimball-browser-save-2026-09-13/README.md)
now pass exact fresh-process restore, continuation/restart, automatic resume,
stale-tab conflicts and corruption preservation; Party publication stays separate.
Public deployment, Steam, consecutive failures and broader human comparison remain work. An initial browser Fenced failure remains unexplained.
The [same-epoch journal rebase fix](results/resync-effects-2026-09-19/README.md)
now preserves queued and confirmed watched effects through a checkpoint refresh,
cancels abandoned predictions, and avoids duplicate recovered action verdicts.
A real faulted Claimball refresh and exact old/current receiver comparison prove
this separate loss mechanism; native/WASM trace playback agrees.

The earlier C2 effect-loss cause remains unestablished. The current
[framework audit](framework-audit.md#observer-effect-classification) verifies the
fault/refresh contract and classifies that trace-less case as a historical report,
not a reproduced current blocker. New failing delivery evidence would reopen it;
the current result is not a retrospective fix claim.

The owner-streamed [Slopball native UI increment](results/slopball-ui-2026-09-13/README.md)
adds lobby/start, profiles, social/scoreboard and leave/rejoin around real Godot
bodies. Waiting samples are gated, body drivers reset between sessions, and authored
collision settings are preserved. Model/UI/render checks and original faulted
network/physics-migration gates pass. Wider 2D/3D parity, Party/browser/save flows
and human comparison remain independent requirements.

The [Slopball3D native UI increment](results/slopball3d-ui-2026-09-14/README.md)
adds the corresponding profile/lobby/social/rejoin flow around Body3. Native UI,
viewport-aware rendering and original faulted network/momentum/quaternion migration
gates pass. The 2D and 3D games remain separate, with wider owner-stream parity and
public/browser/save workflows still requiring acceptance.

The [measured ownership-intent increment](results/slopball-measured-intent-2026-09-14/README.md)
replaces requested-input arbitration in both Slopball ports with accepted XY/XZ
stride, using the original measure and thresholds. Replayable scope-aware baselines
pass blocked/sparse/discontinuity/serialization tests; both games retain their live
fault and physics-migration gates. Broader ownership ordering, solver and human
comparison remain separate requirements.

The [native owner-streamed save increment](results/slopball-native-save-2026-09-14/README.md)
adds direct checkpoint save/resume to both Slopball ports. Exact fresh-process world
restore and first solver seeding are checked separately, including nontrivial 3D
spin/orientation. Rejoin, continued goals/chat, common worlds, replacement saves and
preserved invalid data pass. Browser/Party workflows, broader solver/recovery and
human comparison remain additional requirements.

The [Slopball repeated-match increment](results/slopball-rounds-2026-09-14/README.md)
adds round-scoped restart with fresh body publication revisions in both dimensions.
Model replay/stale-sample/exhaustion checks, live two-match/pose gates and original
fault/migration assertions pass. Public/browser workflows, wider solver/recovery and
human comparison remain independent requirements.

The [Slopball Party/browser increment](results/slopball-online-2026-09-14/README.md)
composes the 2D owner-streamed game with shared admission, profiles, RTC and durable
publication. Native UI/save and four-browser planned/crash gates pass exact frame
and solver-seed recovery, new goals, observer/fresh-host rejoin, chat and common
world digests. Immutable authored meshes fix a reproduced WebGL redraw failure.
Whole-party shutdown, local browser saves, 3D Party workflows and broader deployment/
recovery/solver/human comparison remain separate requirements.

The [Slopball published-restore increment](results/slopball-party-restore-2026-09-14/README.md)
adds native WSS/ENet and browser RTC acceptance after every game and the service
are killed. Exact saved worlds and first solver seeds, observer-first registration,
returning seats/names, new goals/chat/common worlds and renewed publication pass.
Seed monitoring now includes Observer-to-Owner reseeding in both dimensions, with
native file-save regressions. Broader returning-host/failure combinations, 3D Party,
local browser saves, deployment and human comparison remain requirements.

The [Slopball3D Party/browser increment](results/slopball3d-online-2026-09-14/README.md)
adds shared profiles/admission/RTC/publication around real 3D bodies. Native Party,
UI/save and original migration gates pass; four-browser planned/crash cases verify
exact approved frames, spinning/quaternion solver seeds, new goals, returning
observers/host, chat/common worlds and independently decoded publication. A reproduced
optional-bot corner stall is corrected and the same saved checkpoint completes. Whole-party
shutdown, local browser saves, wider failures/deployment and human comparison remain.

The [owner-streamed published-recovery matrix](results/owner-streamed-party-restore-2026-09-14/README.md)
covers both Slopball dimensions, native/browser transport, and original-creator or
trusted-seat-two restoration after all games and the service are killed. Exact
world/solver recovery, creator return, observer exclusion, new goals/chat/common
worlds and publication by the selected authority pass through unchanged Room/Party
primitives. Browser-local saves, arbitrary failures, public deployment and broader
solver/human comparison remain requirements.

The [owner-streamed browser-save increment](results/owner-streamed-browser-save-2026-09-14/README.md)
adds named local Solo slots to both Slopball ports. Independent source decode,
fresh-process exact restore and solver seeds, new goals/rounds, asynchronous URL
resume, stale-tab/corruption preservation and alternate slots pass. Native file
and browser Party regressions retain their guarantees and storage separation.
Broader storage/browser/deployment failures and human comparison remain work.

## M7 — Deterministic peer-to-peer rollback

Depends on M1, canonical schema/math, session protocol, and M2 presentation.
Implement a separate runner; server-authoritative reconciliation remains available.

Implementation:

- Strict deterministic math/collision/RNG package and stable system/query order.
- Input exchange, remote-input prediction, bounded prediction horizon, input
  delay, confirmed tick frontier, disconnect policy, and spectator catch-up.
- Full match save/restore, checksums, divergence recordings, and content gating.
- Explicit live-peer transport rebinding while survivors retain simulation and
  input history; reject forgotten/evicted inputs. Native two-player and repeated
  three-player native/WASM gates pass. Browser Save & pause, fresh-process file
  import and rejoin also pass. A challenged fixed-roster admission provider,
  three-member signaling mesh and credential-backed browser rejoin pass. Creator
  return under a reused RTC ID now uses connection-generation fencing; public
  account/invite integration remains open.
  The [fixed-roster provisioning foundation](results/p2p-provision-2026-09-20/README.md)
  now adds durable player counts, bounded invite enrollment, authenticated rebind,
  SQLite crash recovery and native TLS service/client acceptance without granting
  simulation authority. The [P2P party integration](results/p2p-party-2026-09-20/README.md)
  now connects browser Duel's invite menus, IndexedDB enrollment, dynamic runner
  scope and authenticated RTC. Both guest and creator fresh-process archive returns
  converge under faults. The [native P2P integration](results/native-p2p-2026-09-20/README.md)
  now adds encrypted two-player ENet, TLS pair provisioning and returned-creator
  endpoint discovery. Public invite deployment remains unverified; these local
  cases do not establish public reachability.
  The [native creator-return gate](results/native-creator-rejoin-2026-09-09/README.md)
  also replaces the surviving dialer's ENet transport while preserving its runner,
  then reaches the uninterrupted reference with the restored listening participant.
  The shared native MultiplayerPeer adapter now [tracks connection generations](results/native-generations-2026-09-09/README.md),
  including backend-queued packet boundaries and propagation through Steam and
  buffer wrappers. ID reuse, real ENet and both native rejoin gates pass.
- Spectators can rebind to another admitted source using a retained continuity
  anchor and a new stream binding. Native Duel and repeated native/WASM
  three-player switches pass; missing/conflicting history remains explicit.
  See [source-failover evidence](results/watch-failover-2026-09-09/README.md).
- Cross-platform execution checks for the same recorded input corpus. Fixed-point
  math is a candidate, not proof: ordering, overflow rules, and physics still matter.
- A small duel/fighting scenario suited to complete-world rollback. Measure
  CPU and input delay separately from server-mode bandwidth.

Acceptance: native platforms and WASM execute the same corpus to identical logical
state/event hashes; loss/reordering and long stalls recover within declared limits;
history exhaustion stalls/resyncs explicitly; entity spawn/death and simultaneous
hits rewind correctly. Deterministic agreement is not a claim of cheat resistance.

## M8 — Scrapyard reimplementation

The [cover-aware solo cohort](results/solo-navigation-2026-09-14/README.md) now
passes three normal pairs and an explicit obstruction control using ordinary
movement, unchanged cover/barrel placement and the original wave requirements.
The old stationary failure remains a separate record; broader parity and human
comparison remain required below.

Original: sibling `../scrapyard`. New implementation: `examples/replay_scrapyard/`.
Keep original sources, project, saves, ports, and run commands independently usable.
The port starts after M4–M6 have established reusable gameplay/session primitives;
M7 is required only if a deterministic P2P Scrapyard mode is selected.

Vertical slices, each with its old scenario and new acceptance fixture:

1. Seeded arena, runners, local/co-op movement, camera, staging lobby.
2. Ballistic guns, projectiles, reload/jam/cadence, mobs, damage, drops.
3. Combinations, statuses, chained effects, rail/lance and lobber interactions.
4. Waves, bosses, floors, shop/workbench, run transitions, meta progression.
5. Drop-in/reconnect, spectator/server modes where applicable, save/resume,
   host migration during active combat, and return of a departed host.
6. Zones, storms, surges, healing, deliveries, stress/gauntlet scenarios.
7. Spray assets, mod/content compatibility, audio/UI polish, web/Steam paths.

Reuse content/assets with provenance and matching hashes; reimplement gameplay
against Replay. Avoid copying Kit's seven authority/time handlers into a new
namespace as a nominal port. Conversely, retain game-specific decisions such as
takeover grace periods when they are intentional design, and document differences.

Acceptance: parity matrix complete or every intentional gap explicitly agreed;
the old and new scenario harnesses remain runnable; paired human playtests and
recorded workload measurements exist. Do not describe a demo slice as a full port.

## M9 — Compare, optimize, and stabilize

The [borrowed-validation increment](results/borrowed-validation-2026-09-14/README.md)
removes a measured nested copy chain without weakening validation or changing
public APIs. Differential, native/WASM and full paired checks pass; recorded client
p95 improves while other costs remain mixed. This is targeted stabilization, not
completion of the remaining adoption requirements.

The [latest paired native cohort](results/public-history-comparison-2026-09-14/README.md)
passes 24 process windows and 64 report checks after public history projection.
Replay host traffic is lower; client CPU/correction cost remains a measured tradeoff.
This is the current cost baseline. It does not close the broader adoption gates below.

Depends on comparable ports. Publish data using the [comparison protocol](comparison.md).

The [sustained swarm result](results/scrapyard-swarm-2026-09-08/README.md) adds a
replenished offensive workload and records large-snapshot pacing plus an unresolved
presentation failure. Reproduce/fix the failure and improve bounded snapshot
freshness before drawing readiness conclusions; a passing cohort does not waive
these findings or the remaining mixed workloads.

The [watched catch-up regression](results/watched-catchup-2026-09-08/README.md) now
fixes a proven journal-slot reuse ordering defect and adds operation-level failure
diagnostics. The earlier unclassified live failure and a later browser lob timeout
remain separate findings; passing later gates does not establish their causes.

[Negotiated snapshot parts](results/snapshot-parts-2026-09-08/README.md) improve
measured swarm freshness while preserving the base protocol/checkpoints and
pre-extension interoperability. The higher bandwidth and correction costs remain
part of M9: reduce unnecessary payload/history, validate actual network fault/credit
pressure, and compare the resulting supported envelopes before an adoption decision.

[Lossless delta compression](results/lz4-deltas-2026-09-08/README.md) now reduces
encoded history redundancy without changing simulation or query semantics. The
measured payload/freshness improvement retains explicit CPU and correction costs;
further history/prediction design and real fault/credit-pressure validation remain.

The [raw-UDP matrix](results/raw-udp-faults-2026-09-08/README.md) now exercises
native ENet below its reliable channel, with bounded delay/loss/duplication/rate
pressure. Sender bursts, initial-input timing and recent-fact delivery were improved;
explicit recovery intervals and prior failures remain visible. Browser/SCTP fault
pressure and the broader M9 adoption requirements remain open. The
[mixed movement/status cohort](results/scrapyard-mixed-2026-09-08/README.md) now adds
three alternating pairs with movement, frostwave and battlecry, measured status
exposure, conservation and final convergence. Injury/DOT/dash/reload combinations,
changing waves and raw faults combined with this workload remain separate gates. The
[endurance comparison](results/scrapyard-endurance-2026-09-08/README.md) now measures
injury/regen reactions, dash and reload with both delay and raw loss. Its delay
condition passes; raw-loss acceptance remains rejected for missing remote dash
edges and long observed-frame gaps. Bounded prediction stalling and opt-in
receipt-time actions are implemented/tested, but do not close that input problem. The subsequent
[input audit](results/input-frontier-2026-09-08/README.md) identifies obsolete-tick
capture and adds authority-frontier fencing plus explicit control-consumption
receipts. Replay passes the raw-loss workload after those changes; paired acceptance
still fails for a Kit-side cast refusal, which remains recorded work. The
[cast-submission audit](results/cast-submission-2026-09-09/README.md) corrects that
classification: local prediction rejection did not mean the command was unsent.
Contract version 2 records the actual submission receipt. A fresh cohort still
fails raw-loss gameplay/observation gates; delay-only acceptance remains separate. The subsequent
[Receipt resync-queue increment](results/receipt-resync-2026-09-09/README.md) adds
bounded command admission during same-epoch recovery and validates it directly.
Its fresh endurance cohort passes all 24 windows and 56 report cases; previous
failures, long observed-frame gaps and the remaining workloads stay explicit.
The subsequent [jam-clearing profile](results/jam-clearing-2026-09-09/README.md)
adds seeded dud/shot, clear-pull and settled gun-state checks. Twelve delay windows
and 60 report cases pass; the complete matrix fails raw loss for stale Kit
cooldowns and a missing Replay dash. This expands workload coverage while leaving
that input-delivery boundary open.
The [per-action timing increment](results/action-schedule-2026-09-09/README.md)
adds a versioned payload classifier so discrete receipt-time intents can coexist
with scheduled competitive actions. Core, conversion and Godot Session gates pass;
Scrapyard dash authoring/save conversion and a fresh fault comparison remain required.
The subsequent [dash-action port](results/dash-actions-2026-09-09/README.md) implements
that path and explicit content 42–46 conversion. Native input/save/model and WASM
build gates pass; all local dash requests settle in the fresh cohort. The paired
workload still fails its minimum kill count in three Replay games, and observation
freshness remains unresolved. No broader M9 completion is implied.
The [stress-aim correction](results/aim-origin-2026-09-09/README.md) then aligns
automation with ordinary local input geometry and adds exact impact accounting.
Its delay condition passes twelve windows and 61 report cases, while raw loss
still misses a required client cast observation. Freshness and complete fault
acceptance remain required.
The [snapshot-ACK increment](results/snapshot-ack-2026-09-09/README.md) removes a
demonstrated reliable-stream dependency between ACK retransmission and action
delivery. Core, real ENet, recovery and frozen compatibility gates pass. Replay's
fresh delay/raw-loss scope passes; the full paired cohort remains rejected for a
Kit observation failure, and long observed-state gaps remain explicit work.

The [missing-fact repair increment](results/fact-repair-2026-09-09/README.md) now
reproduces complete snapshots waiting on a held reliable fact and repairs small
missing facts through a negotiated, bounded unreliable request path. Historical
recipient filtering, canonical validation and reliable fallback remain intact.
Its full jam cohort passes all 24 windows and 63 report checks. Raw-loss Replay
world-progress gaps are 464/781/601 ms, with no resyncs or prediction stalls; the
remaining gaps and substantially higher CPU/traffic costs keep M9 open. A
single-pair before pilot is diagnostic evidence, not a matched performance ratio.

The [bounded selection increment](results/delta-selection-2026-09-09/README.md)
keeps exact chosen snapshot bytes while reducing measured host delta-selection
CPU. Its fresh delay condition passes, but the full cohort is rejected for Kit's
cast observation and a refused Replay dash during a run with resyncs. During Replay's 3.682 s
gap, facts advance while complete snapshots stop, with downstream proxy capacity
drops. Reproduce and repair that queue/fragment recovery failure; a passing prior
cohort or byte-equivalent optimization does not waive it.

The [snapshot-erasure increment](results/snapshot-erasure-2026-09-09/README.md)
reproduces sustained incomplete worlds and adds negotiated two-erasure parity under
the existing egress budget. Complete digest/state checks and old-peer fallback
remain. Its full jam cohort passes 24 windows and 63 report checks, with raw-loss
world-progress gaps of 482/483/433 ms and zero resyncs/stalls. The three-browser RTC
gate also passes with parity reconstruction and common world hashes. The prior
failed cohort remains evidence; wider fault/credit pressure, total CPU/traffic cost
and adoption gates remain required.

The [schema-shuffle increment](results/schema-shuffle-2026-09-12/README.md)
reduces history-heavy encoded payloads without dropping history or changing
canonical state/checkpoints. Same-binary diagnostics deliver more snapshots under
the same byte cap at higher CPU cost. Its full cohort is rejected for Kit's kill
count and a late Replay cast observation; delay and browser regression gates pass.
Investigate late action delivery, measure snapshot-rate/freshness choices, and
exercise the new format in a heavier browser wire workload. Compression savings
alone do not establish lower total traffic or M9 acceptance.

The [action-delivery increment](results/action-delivery-2026-09-13/README.md)
reproduces reliable heartbeat/action delays and adds unreliable periodic heartbeats
plus negotiated bounded action copies. Admission, timing, sequence/verdict and
reliable fallback guarantees remain. Controlled ENet, the full 24-window/63-check
jam cohort and three-browser RTC gate pass, including cast observations. Total
snapshot traffic/cost, wider loss/credit envelopes and the remaining deployment/
human/authoring requirements still keep the full roadmap open.

The [snapshot-rate decision](results/snapshot-rate-2026-09-13/README.md) evaluates
intervals 1/2/3 with unchanged 60 Hz simulation and gameplay/freshness gates. The
three-tick candidate passes the full 24-window/64-check matrix and reduces measured
host output to about 203–205 KB/s. Scrapyard adopts that default after validation;
a fresh browser run verifies the actual default and gameplay. CPU variation,
remaining total costs, broader browser/fault/deployment and human gates remain.

The [heavy browser RTC increment](results/browser-stress-2026-09-13/README.md)
exercises shuffled snapshots, parity and action copies under bounded message
faults and credit blackout. An eight-datagram staging bound resolves the named
freshness failure in three recorded seeds while preserving checkpoint progress.
It does not establish raw SCTP loss, software-renderer performance or migration
availability with several-second-old checkpoints. Those broader gates remain.

The [owner-unwind control](results/owner-unwind-2026-09-08/README.md) now reproduces
the mixed cohort's principal movement-loss mechanism in Kit and removes it in an
isolated framework copy. Original clients rewind live owner coordinates during
pending-command delta reconciliation; the control preserves them. Earlier timing
results remain recorded, with this baseline defect explicitly qualified. The
[corrected-baseline cohort](results/mixed-owner-control-2026-09-08/README.md) now
repeats the performance comparison with the isolated repair and normal timing
adapters. Kit still records lower callback/traffic costs; movement is much closer,
while shot/kill and other transient differences remain part of the interpretation.

The [staged LZ4 result](results/lz4-staging-2026-09-08/README.md) now targets measured
snapshot encoding work. A bounded output stage removes the duplicate match search
while retaining byte identity and atomic failure, at 65,808 extra workspace bytes.
The corrected mixed cohort still passes; targeted phase improvement and whole-game
variation are recorded separately. Decoder word-loop experiments were rejected.

The [exact correction reuse experiment](results/correction-reuse-2026-09-08/README.md)
adds an opt-in deterministic record-reuse path with byte-exact predecessor/input
checks and unchanged event/atomicity validation. It helps a matching-state synthetic
case, but reuses only about one percent of correction records in the full mixed
cohort and remains off by default. It does not resolve the broader replay cost.

Implementation:

- Measure authored gameplay/plumbing size, number of lifecycle/time concepts,
  change effort for the same feature, debugging effort, CPU/memory, bandwidth,
  join/recovery cost, and perceived responsiveness.
- Profile full-frame copying, replay scratch, query scans, snapshot projection,
  and event retention. Optimize measured hot paths with sparse codecs, indexed
  storage, managed arenas, or page sharing while preserving invariants.
- Test native and browser deployment, allocator ownership, content versioning,
  hot-reload boundaries, API diagnostics, and failure/recovery UX.
- Stabilize the authoring layer after multiple different games have used it.
  Package/distribute Replay as experimental until its supported envelopes and
  compatibility policy are documented.

Decision gate: retain the approach only if it makes realistic gameplay easier
without unacceptable latency/correction, CPU, memory, or operational costs.
Possible results include a broadly adopted library, a competitive-focused library
beside Kit, or useful isolated components. Preserve the comparison games either way.

The [Cavecrawl profile comparison](results/cave-profile-comparison-2026-09-20/README.md)
now covers nine quiet native pairs with common intent, fixed content, 120 ms receive
delay and separate visible/confirmed timing. Owner motion matches the observed
local-response range more closely, while minimum traffic and callback cost remain
higher than Kit. The result keeps Replay experimental and identifies small-world
protocol/copying costs for follow-up; it does not waive broader stress, deployment,
full parity or human authoring/playtest gates.

The [compact-observation increment](results/compact-observations-2026-09-20/README.md)
targets measured owner-profile input traffic. Packet-independent lossless encoding
cuts median client application traffic by 41.7% in six same-binary local pairs,
with unchanged cadence/gameplay and old-peer fallback. Network/WASM, frozen peer,
native recovery/context and Chrome migration/save gates pass. Host traffic and
broader comparison/adoption costs remain work.

## Risks and checkpoints for design changes

| Risk | Evidence to collect | Response |
| --- | --- | --- |
| Whole-world copies cost too much | Bytes/frame and replay p95/p99 at game workloads | Managed storage and incremental snapshots after profiling |
| Simulation contract feels less ergonomic than Kit | Time and edits needed for identical gameplay changes | Improve primitives and diagnostics before more codegen |
| Physics migration dominates game work | Port effort and correction behavior for dynamic contacts | Supply a defined replayable physics subset; keep explicit owner-stream mode |
| Partial prediction lacks coherent dependencies | Divergence around moving doors/players/shared objects | Expand prediction group or supply historical boundary data |
| Event identity is unstable under branching | Missing, duplicated, or misattributed effects | Derive IDs from actions/entities, define updates and lifetime retention |
| Migration loses or duplicates outcomes | Crash-at-every-phase fixtures | Strengthen checkpoint/commit/dedup protocol, document unavoidable loss |
| Benchmark compares different gameplay | Content/rules hashes and parity matrix | Mark unmatched scenarios; do not attribute differences to framework |

## Immediate next implementation

This section's original port-first sequence is superseded by the
[framework completion order](framework-completion.md#order-of-work). Finish native
authenticated P2P integration, audit shared gaps, and stabilize the public API.
The game work below is a follow-up inventory unless it exposes a framework defect.

Continue the [Scrapyard port ledger](../../examples/replay_scrapyard/roadmap.md).
The separate game now has the arena, stock gun/enemy/effect/ability catalog,
run/shop/parts/revive loop, local profiles and initial combat/lobby Room recovery.
Complete the remaining recovery/identity scenarios, original stress/gauntlet and
content/asset-transfer acts, then UI/audio and paired playtests. Record world size,
checkpoint age, transfer duration and continuation evidence as workloads grow.

Close the remaining authored parity and visual/presentation boundaries in the
separate Cavecrawl, Quickdraw, Speedball, Claimball and owner-streamed ball ports.
Their individual ledgers and recorded results distinguish implemented rules from
compared or playtested behavior. Initial Room coverage includes combat, returned
hosts, repeated handoff, isolated-host control partition and successor loss.

The [P2P runner](../../replay/p2p/README.md) has fixed-roster rollback, recovery,
spectator catch-up, divergence recordings and arm64/WASM/Rosetta corpus evidence.
A raw WebRTC mesh, Hello Session and playable P2P Duel now pass real Chrome-process
gates. The Duel includes rollback under input blackout, late spectator reset and
coordinated participant-file recovery. Native/browser live rejoin now retains
survivors through timeout; a repeated three-player corpus executes on native and
WASM. Initial authenticated P2P admission now verifies member identities before
transport binding. Continue broader OS/hardware checks, public P2P provisioning, browser migration
and deployment networking; other ports still need
browser acceptance. The [browser migration work](browser-migration.md) now has
WebSocket authority control, challenged RTC signaling and actual Cavecrawl
planned/crash browser migration, repeated handoff, control partition, successor
loss and fresh-process old-host return. Authenticated signaling continuation now
preserves healthy channels and supports subsequent late join. Broader outage
combinations, richer browser workloads and public provisioning/deployment remain open.

Use comparable workloads to complete M9's authoring/runtime measurements and
stabilization decisions. Keep both frameworks and both versions of each game
independently runnable. Remaining requirements are work, not implicit parity waivers.


The [loaded checkpoint-transfer increment](results/checkpoint-compression-2026-09-13/README.md)
adds negotiated lossless checkpoint compression and a passing loaded browser
planned handoff with exact restore and continued actions/world hashes. Abrupt loss
still fails safely when its prepared point exceeds the unchanged 120-tick limit.
Recovery admission fairness and the recorded browser rendering errors remain open;
this is not completion of M5 or M9.

The [checkpoint admission audit](results/checkpoint-admission-2026-09-13/README.md)
rejects two early-send schedules that recovered from host loss but violated gameplay
freshness. A verified real checkpoint is 29.7% smaller with the existing Frame schema
shuffle plan before compression. Negotiated schema-aware transfer is the next
implementation; the offline diagnostic does not close the migration gate.

The [negotiated checkpoint-layout implementation](results/checkpoint-layout-2026-09-13/README.md)
now transfers schema-grouped archives with exact canonical reconstruction and
legacy fallback. Native/WASM transfer checks and loaded browser planned/crash
cohorts pass with the unchanged gameplay freshness and rollback gates. Broader
network/deployment, normal-play visual/listening, hardware and human comparison
requirements remain open; the full roadmap is not complete.

The [immutable-polygon increment](results/immutable-polygons-2026-09-13/README.md)
adds a bounded mesh helper and passing native/three-peer browser presentation gates
without graphics warnings. A subsequent heavy host-kill run refuses a 165-tick-old
backup against the unchanged 120-tick limit, reopening loaded recovery availability.
The earlier passing migration cohort must not be treated as a general stability
proof. The full roadmap remains active.

The [reliable-checkpoint implementation](results/reliable-checkpoints-2026-09-13/README.md)
negotiates the existing reliable channel, retains legacy fallback and passes loaded
planned/crash cohorts plus a controlled reliable-traffic pause. Measured backup age
improves without widening rollback/gameplay limits or changing canonical state.
Broader models, network/deployment and human/parity gates remain open; the full
roadmap is active.

The [held-checkpoint crash matrix](results/loaded-held-checkpoint-2026-09-14/README.md)
now passes loaded 300/400 ms reliable pauses and two crashes while a newer checkpoint
is still queued. Exact recovery uses the previous approved copy, with held-interval
freshness/credit/memory checks and unchanged 120-tick rollback limits. This broadens
controlled interruption evidence, not raw SCTP/public or universal availability.

The [recovery-backup status](results/recovery-backup-status-2026-09-14/README.md)
now gives five game UIs an observation of scoped approval, retention and known age,
retaining accepted metadata across pending RPCs. Unit/live/browser checks cover
waiting, stale/refreshed backup, handoff and recovery disclosure. The status is not
a permit or a guarantee of future availability.

[Negotiated observer chat labels](results/observer-names-2026-09-13/README.md) now
pass native and browser planned-handoff checks without changing admitted identity,
player seats or observer permissions. Broader spectator/identity parity and the
remaining full-roadmap gates stay open.

The [observer crash/rejoin gate](results/observer-recovery-2026-09-13/README.md)
now verifies exact promotion, fresh host and observer processes, preserved labels
and observer permissions, alongside corrected mode-specific status text. This local
lifecycle evidence does not close the broader spectator/deployment/full-roadmap gates.

The [matched solo gauntlet](results/solo-gauntlet-2026-09-13/README.md) now runs both
real games with fresh profiles and the original-style one-player controller.
All six games pass the three waves/rests/reward checks. One Replay barrel finale
is blocked by cover, so the overall cohort remains rejected. The record separates
sustained solo support from the unresolved stationary-finale and difficulty/feel
comparison. No original framework or game was changed; the full roadmap stays active.
