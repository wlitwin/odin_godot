# Scrapyard port ledger

This ledger records port requirements, dated comparisons and remaining validation.
Use the [contributor guide](contributor-guide.md) for the current authoring workflow;
individual receipts below retain their original workloads and failures.

Original repository: `../../../scrapyard`, revision
`6bdef4f437d9a4e2c98f1d49472f840879301ccf`. Its project, source, saves and run commands
remain independent. This project is a reimplementation against Replay, not a renamed
Kit shell. The full [Replay roadmap](../../docs/replay/roadmap.md) records the
original parity scope. The later [framework completion plan](../../docs/replay/framework-completion.md)
defers exhaustive game parity and governs the framework's release scope.

| Slice | Concrete requirements | Status |
| --- | --- | --- |
| Arena and runners | Same cover generator/footprints, movement/cover slide, names/loadouts, ready/start, local prediction, remote views, camera | Native/network gates; original dirt/tufts, animated gate and direction arrow restored; three-floor scene lifecycle and spectator clear-stage visibility tested |
| Guns and enemies | Data resources, ballistic cadence/mag/reload/jam, projectiles, mobs, damage, drops | All stock gun families and enemy brains implemented; baseline/native/network evidence recorded |
| Combat composition | Abilities, statuses, combinations, chain/rail/lance/lobber/mend behavior | Grenade, historical rails/healing, statuses, reaction rules and barrel chains implemented; all stock ability deliveries implemented; full original scenario parity remains pending |
| Run progression | Waves, bosses, floors, gate, shop/workbench, wipe/reset, meta progression | Run/director/gate/shop/parts/revive/reset implemented; local co-op profiles implemented; inspector-driven workbench previews tested; audio/settings and spray preview implemented; complete listening/visual parity pending |
| Recovery and identity | Drop-in/reconnect, spectator/server parity, saves, host migration during combat, returned host | Local profiles, saves, party menus/durable enrollment, and asset-aware combat handoff/rejoin tested; full recovery/identity matrix pending |
| Stress and content | Zones, delivery/storm/surge/healing, gauntlet, spray/mod content, audio/UI polish | Zone/delivery/healing, cross-seat storm/surge, continuous three-wave/barrel finale and fault gates; spray exchange/recovery, host-only JSON overlays and 40-enemy stress tested; matched solo waves and cover-aware finales pass in eight required games plus a reversed obstruction control; difficulty comparison and polish pending |
| Deployment/comparison | Web/Steam paths, matched old/new acts, measurements and human playtests | Local Chrome party enrollment/asset-aware migration, world equality, profiles/run/spray persistence pass; optimized paired idle and firing/reload comparisons pass; public deployment, Steam, full combat comparisons and human playtests pending |

The original harness acts map to the new implementation as follows. “Pending”
identifies an unmet item in that original parity scope. It does not claim an
intentional gameplay difference, and it does not independently block the revised
framework release scope.

| Original act | Replay acceptance |
| --- | --- |
| duo / solo / server | Dedicated server act now passes in both isolated games: two clients, six-enemy clear, rewards and floor advance with no authority avatar; broader mode/movement parity pending |
| guns | Ballistic families, cadence, magazine/reload/jam, mob hits and drops |
| combo / lance | Data-driven effects, directional/time queries and cross-entity effects |
| run / boss / gauntlet | Complete progression/director state and sustained play |
| vault / doppelganger | Durable profiles tested; duplicate live identity policy differs (see below) |
| succession | Complete checkpoint, fenced takeover, recorded 150-tick timer reset; native/Chrome dedicated combat planned/crash continuation passes; broader matrix pending |
| stress | Matched entity/shot workload and CPU/memory/bandwidth measurements |
| spray / mod | Asset transfer, declared content compatibility and late join |
| chain / delivery / zone | Deferred multi-entity consequences and lifetime |
| storm / surge / mend | Area/status/healing behavior and attribution |

The [dedicated-server increment](../../docs/replay/results/dedicated-rooms-2026-09-14/README.md)
compares the original server act in separate projects and fixes avatarless Room
bootstrap/standby/takeover. Native planned, crash/return and repeated infrastructure
failover preserve both real player seats and exact checkpoint frames. The
[browser infrastructure gate](../../docs/replay/results/dedicated-browser-2026-09-14/README.md)
now exercises those role transitions in four real Chrome processes over RTC.
Dedicated combat-failover and broader deployment remain open.

The [network recording increment](../../docs/replay/results/network-recording-2026-09-14/README.md)
adds developer-menu exports and a headless verifier for complete network batches.
Real native authority/prediction and Chrome solo recordings execute in native/WASM,
including accepted/rejected actions and historical aim. It preserves gameplay and
recovery formats; it is an explicit diagnostic with measured synchronous cost,
not a full-game parity or adoption result.

Current comparison boundaries:

- The [cover-aware solo cohort](../../docs/replay/results/solo-navigation-2026-09-14/README.md)
  passes normal stopping positions and a deterministic blocked-shot control using
  ordinary movement. Barrels, cover, damage and all wave/rest/reward requirements
  remain. It is a new controller contract; the older stationary result below stays
  rejected and is not a difficulty or human-feel verdict.

- The [solo gauntlet comparison](../../docs/replay/results/solo-gauntlet-2026-09-13/README.md)
  runs one circle-strafing player with nearest-target autofire in both real games.
  All six fresh-profile games clear 4/4/5 enemies, retain all three 300-tick rests,
  and award one core. Five complete the barrel chain; one Replay stopping position
  leaves both fixed-offset barrels behind cover. That failure is retained, and the
  overall cohort is rejected. This is sustained solo evidence, with differing
  health/timing observations, not difficulty or human-feel equivalence.

- The [action-intent helper](../../docs/replay/results/action-intent-2026-09-09/README.md)
  replaces manual dash ticket storage, preserves input guards and handles recovery
  dispositions across epoch changes. Native input, party and live request checks
  pass; the source-count reduction is not a human usability or performance claim.

- The [snapshot-ACK comparison](../../docs/replay/results/snapshot-ack-2026-09-09/README.md)
  passes Replay's twelve delay/raw-loss windows and paired delay acceptance with
  61 report cases. The paired raw-loss scope still fails a Kit client observation;
  Replay's observed-state gaps reach 1.369 seconds. Controlled ENet and core tests
  verify the removed ACK/action blocking dependency.

- The [stress-aim correction](../../docs/replay/results/aim-origin-2026-09-09/README.md)
  uses the predicted local origin with the observed enemy census. Native regression
  and impact-ledger checks pass; the fresh delay condition passes twelve windows
  and 61 report cases. Raw loss still fails a client battlecry observation, and a
  separate diagnostic records a cooldown refusal caused by bunched arrivals.

- The [dash-action port](../../docs/replay/results/dash-actions-2026-09-09/README.md)
  uses receipt-time dash intents and explicit results, with content 42–46 conversion
  and native input/save/model plus WASM-build validation. All 120 local dash
  requests in the new cohort settle, including raw-loss cases. The paired workload
  still fails minimum kill counts in three Replay games; observation freshness
  and broader authoring/platform/human validation remain open.
  The current-content native TLS party handoff/asset-recovery/returned-host gate
  also passes; a fresh browser party run after this content change remains pending.

- The [jam-clearing comparison](../../docs/replay/results/jam-clearing-2026-09-09/README.md)
  passes twelve delay windows and 60 report cases, including seeded duds, live
  shots, three-pull clears and settled gun-state convergence. Raw-loss acceptance
  remains failed for stale Kit cooldown observations and a lost Replay dash.

- The [latest endurance cohort](../../docs/replay/results/receipt-resync-2026-09-09/README.md)
  passes delay and raw-loss conditions with 24 windows and 56 report cases. Prior
  failures remain recorded; long observation gaps and broader injury/jam/wave,
  platform and human-playtest coverage remain open.

- [Cast submission measurement](../../docs/replay/results/cast-submission-2026-09-09/README.md)
  now distinguishes Kit local prediction rejection from a sent request. The prior
  refusal diagnosis was incorrect; current raw-loss workload failures remain
  recorded and still prevent full paired acceptance.

- The [endurance comparison](../../docs/replay/results/scrapyard-endurance-2026-09-08/README.md)
  adds stock reloads, dash inputs and burn/salve/surge during the moving swarm.
  The delay condition passes, using an explicit Receipt action policy only in the
  isolated Replay copy. Raw-loss acceptance fails for missing remote dash edges;
  the subsequent [input audit](../../docs/replay/results/input-frontier-2026-09-08/README.md)
  fixes Replay capture across catch-up, while the latest paired raw-loss gate
  remains rejected for a Kit-side cast refusal. This is not
  full combat/fault parity or an adoption result.

- Cover generation and ordered axis collision are compared against selected
  unmodified original procedures, compiled in an isolated native oracle. The
  independent project does not run the original harness or touch its user data.
- Ordinary movement preserves the original non-normalized per-axis input rule.
  Replay schedules movement at 60 Hz with server authority and local prediction;
  the original streams owner-local movement at render cadence. Network authority
  and variable-frame timing are therefore not matched yet.
- Dash uses ten simulation ticks and a 66-tick cooldown. The original specifies
  0.16 s / 1.1 s on the owner clock. These require paired feel/timing evaluation.
- The renderer includes original runner strips, weapon regions, ground, solid
  junk, dirt/tufts and animated gate/arrow. [Scenery evidence](../../docs/replay/results/scrapyard-scenery-2026-09-07/README.md)
  covers three peers/floors and visual captures. The [bottom shop cards](shop.md)
  replace the tall overlay, restore the original purchase-key order and validate
  clicks/shortcuts through the same action path. The [combat HUD](hud.md) restores
  health/status/cooldown displays, magazine states, boss health and revive prompts.
  [Run transitions](transitions.md) add departure/wipe panels, current wave/rest
  information and recovery narration. The [downed-player camera](camera.md) now
  follows a living teammate and handles revival, host loss and rendered floor
  warps. [Chat/system history](chat.md) now includes named text, late-join history,
  per-tick yard announcements and asset-aware migration. [Positional pings](pings.md)
  restore middle-mouse input, fading markers and stamped names with expiry and
  floor/run scope checks. Named observer chat now passes native and browser checks, including planned
  host migration and retained historical labels. Broader observer/actor/menu/interaction
  parity remains work.
  [Browser UI acceptance](browser_ui.md) covers chat, pings, shop, HUD and
  camera/revival in three Chrome processes; broader browser/device and presentation
  coverage remains required.
  Audio is implemented, but hardware playback and listening parity
  remain unverified; the local CoreAudio path stalls even in plain Godot.
- [Actor presentation](actors.md) now covers downed poses/beacons, muzzle and
  reload cues, ghost tint, hit feedback, enemy attack/death rows and pooled slot
  reuse. [Combat feedback](feedback.md) supplies bounded bursts/debris, target
  damage numbers and pickup effects. The [Escape menu/tally](menu.md) now adds
  dimming, responsive panels, healing credit, keyboard focus guards and Quit.
  [Staging muster](muster.md) now restores fixed idle previews, readiness rows,
  bidirectional pickers and late Drop In. [Automatic loadouts](automatic.md) now
  preserve choice modes across native/browser restarts and seat changes.
  The tally now includes the original zero-valued deaths column and fresh session
  round-trip measurements; remaining actor/front-door details still need work. [Screen effects](screen.md)
  restore lens kicks, health vignette and transition veil with motion-setting
  and native/browser validation.
- [Directional wounds](wounds.md) now use the hit origin and recorded victim pose,
  reject stale generations/history and correct hurt burst/sound placement.
  [Wall contacts](walls.md) now preserve ballistic/spit endpoints and normals,
  with bounded confirmed sparks, sound and content-45 save conversion.
  [Ordnance presentation](ordnance_view.md) extends contact facts to rails and
  restores grenade shells and confirmed ember trails; bounce/fuse laws are unchanged.
  [Glob discs](globs.md) restore slime/sparkjar/spit shapes, colors and pulse.
  The original has straight-moving discs, correcting the earlier arc/trail claim.
  [Area effects](areas.md) restore filled nova/reaction/blast discs, standing zones
  and buff bursts. [Cast paths](cast_paths.md) now restore local/remote tongues and recorded spread
  bolts, with explicit content-46 conversion. Remaining launch/contact feedback
  and paired timing/feel still need work.
- All stock gun/mob resources load into a validated value catalog carried by the
  host world. Ballistic guns, melee enemies, damage and pickups now run in the
  simulation; [combat.md](combat.md) records timing, ordering, capacity and
  presentation differences. PNG spray transfer is implemented; host-only JSON overlays now ship through the world catalog.

Before claiming full parity, every row needs its real-process scenario, source/content
fingerprints, recovery cases where relevant, and visual/playtest evidence. Initial
movement gates do not establish full-game completion or framework superiority.

Identity policy under review: the original `doppelganger` act assigns a live duplicate
token a fresh seat. Replay currently rejects a duplicate live identity, preserving
one token-to-seat binding and requiring a separate identity for a second player.
The user has been asked whether the new game should retain that rule or create a
fresh guest identity for the duplicate. This row is not an agreed parity waiver.

The [content-49 succession result](../../docs/replay/results/scrapyard-succession-2026-09-19/README.md)
reproduces the original attack/director timer reset on the first committed takeover
tick. Exact restore, replay, repeated pending recovery, active boss/popper damage,
nine old-save Godot resumes, and native/Chrome dedicated combat continuation pass.
Complete projectile/lob/zone preservation remains Replay behavior; the original
clears some transient pools. This does not close full gameplay/identity parity or
the broader recovery/deployment matrix.
