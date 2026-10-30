# Replay editor authoring workflow

Completed goal: complete the six authoring improvements after the typed adapter work.
Keep simulation policy explicit and preserve Kit, the original game and existing
canonical game data/rules. Use isolated authored drafts for new-feature exercises.

| Gate | Deliverable | Acceptance |
| --- | --- | --- |
| W1 | Opt-in Godot authoring panel/actions for validate, bake and stale status | Uses existing typed extractors/exporter; clickable source/scene diagnostics; failed/stale work cannot replace valid content; UI stays responsive |
| W2 | Isolated preview refresh, state/playback controls and spatial guides | Refresh safely admits authored preview data; charging/attack/hurt/death/speed/radius are testable without a live match; game state unaffected |
| W3 | Resource pickers for definition references, baked to stable IDs | Ability/status/combo/mob references validate type, path, range and membership; old canonical catalog bytes unchanged |
| W4 | Complete ability authoring + wider helper adoption | Salvefield demonstrates definition/status selection, preview, explicit isolated encounter admission and tests; shared extractors replace category mapping duplication; runner appearances become authored entries |
| W5 | Actor/ability scaffolding | Creates view/scene/registration/preview/test drafts or a complete ability draft; explicit rules/validation TODOs; non-overwriting atomic output and explicit stable IDs |
| W6 | Workbench testing tools | Accessible latency profile, recording/reproduction, correction replay and checkpoint takeover; reuses existing scenario/recording/recovery APIs; bounded jobs, visible results, cleanup |

## First milestone: validation + preview refresh + a complete ability

A developer opens Godot, selects Salvefield (or an isolated scaffolded variant),
chooses its status Resource, adjusts radius/duration/pulse tuning, and refreshes a
preview with guides. Validation points at a deliberately invalid field or reference
and preserves the last valid output. A valid draft runs through an explicit isolated
encounter; correction/takeover tests verify its behavior. The developer can bake and
see current/stale status without assembling a terminal command. Document and test
these concrete actions; this milestone is intermediate, not the goal's finish.

Editor tooling is an optional thin UI over existing Odin code and explicit build
commands. It may use Godot-native editor scripting; game/model/validation code stays
in Odin. No automatic mutation of live matches, inferred authority/effect policies,
or full-game parity campaign. Acceptance is recorded in [editor-workflow-progress.md](editor-workflow-progress.md)
and [results](results/editor-workflow-2026-09-21/README.md).
