# M2 acceptance audit — 2026-09-20

As of this 2026-09-20 audit, M2 remained open. The technical presentation/input
gates had implementation and runtime evidence. The shared-type alias authoring
defect was fixed and validated; human visual/play-feel review had not been performed.
That remaining review is not waived by automated tests or screenshot inspection.

## Implementation requirements

| Roadmap item | Current implementation and evidence | Assessment |
| --- | --- | --- |
| 1. Detached frame/pose sampling, teleports, correction smoothing | `view.frames_at`, 2D/3D pose and angular smoothers; detached-copy/unit tests, Body2/Body3 integration and rock frame-sampling checks | Implemented; tested scopes documented |
| 2. Semantic event journals, prediction/confirmation/update/cancel, retention and rejoin seeding | `view/events.odin`, `one_shots.odin`, `cues.odin`; queue/rebase tests, actual Hello correction and Cavecrawl detached impact/death effects | Implemented; broader network observer issue remains tracked in M3/M6 |
| 3. Explicit confirmation and effect policies | `replay.confirm_through`, journal Speculative/Confirmed/Watched policies, consumed-ID audio/visual ledgers | Implemented; irreversible external work stays outside speculative steps |
| 4. Godot handle-to-node lifetime adapter | `godot.Nodes2`; Hello projectile expiry/rewind, pool-generation tests and Cavecrawl generation-bound impact checks | Implemented and runtime-tested |
| 5. Render input to fixed ticks, bounded catch-up, edge handling | `Clock`/`Buttons`; production Hello process; new ordinary pause fix and 30/60/120/144-FPS checks | Passing after this audit's reproduced/fixed pause-input bug |
| 6. Kinematics, static queries, tick timers, authored definitions | `play.move`, segment queries, cooldowns/director; shared Hello reducer and captured Cavecrawl Resources/markers | Implemented with pure/runtime/authoring evidence |
| 7. Diagnostics and codegen only where warranted; independent simulation | Debug overlay, history/field editor, recordings/playback; pure model packages run without Godot | Implemented; shared `Timeline` alias resolution now passes focused guard tests and the actual Hello application |

## Acceptance gates

| Gate | Evidence inspected or rerun | Practical limit |
| --- | --- | --- |
| Same movement/input reducer in headless and Godot execution | `shared/hello/game.odin` is imported by pure tests and the real script; controlled production-process runs deliver 60 ticks, five held shots and identical movement per second at four frame rates | Explicit frame-duration fixture controls scheduling; separate live-frame pause tests and Chrome use real engine frames |
| Rewind across spawn/death restores views without stale handles | Existing Hello expiry/rewind gate, native/rendered history seeking and branching, Chrome history/playback; pure pool-generation checks | Does not claim full-game presentation parity |
| Replayed effects deduplicate; abandoned effects cancel; detached effects outlive entities | Hello model correction, Loot correction/duplicate-correction fixture, journal/cue tests, Cavecrawl actual hit/death campaigns and native/Chrome lifecycle checks | Already shown/heard output cannot be undone; active effects can be moved/stopped |
| Presentation does not alter simulation checksums | Hello audit after painting, detached frame/smoother tests, playback's unchanged live head, explicit frozen-frame Cavecrawl render hashes | No claim about arbitrary game code outside these adapters |
| Held/short inputs, pause and variable render rates remain consistent | New native four-rate pause tests and controlled edge/catch-up tests; Chrome keyboard pause test; full inspector/recording regressions | Two same-button presses before a tick coalesce by the documented Buttons contract |

<a id="open-follow-through"></a>

## Authoring fix and outstanding human review

**Closed authoring defect:** [shared runtime alias resolution](results/shared-alias-2026-09-20/README.md)
accepts `timeline: game.Timeline` through `../shared/hello` after proving that
no Godot composition metadata is lost. Tagged fields/methods/signals, ambiguous
imports and unresolved types remain refused. The real Hello script uses the alias;
31 focused cases, the full generator suite and native/Chrome workflows pass.

**Human visual/play-feel review.** Rendered native/Chrome captures establish
   layout and observable state, not subjective usability or feel. This remains
   part of the original roadmap's review/comparison scope.

The [pause fix and current receipts](results/hello-input-2026-09-20/README.md)
retain both the failing pause baseline and successful cases, plus the historical
alias diagnostic. The later alias result records its fix and current acceptance. M3–M9 gates remain independent and unchanged.
