<a id="editor-first-replay-authoring-and-canonical-scrapyard"></a>

# Editor-first Replay authoring with Scrapyard

Completed 2026-09-20; see [delivery assessment](editor-first-progress.md).

This completed plan defined a Godot scene-composition workflow for presentation
around Replay's composed value simulation. Replay Scrapyard was the worked
example, alongside the untouched original game. The scope followed the completed
bridge and initial Scrapyard integration, without adding a full-game parity campaign.

## Ownership rules

- Editor scenes own visual hierarchy, authored assets, layout and presentation
  tuning. Scene-local scripts own cached children and animation clocks.
- Gameplay modules own replayable state/rules. Authoring Resources become validated
  immutable values before runner admission. Node animation cannot commit damage.
- Adapters choose predicted/observed/authority values and feed detached displays.
  They own view identity and session/recovery boundaries, not sprite animation.
- Composition exists on both sides: typed state/modules for gameplay, reusable
  child scenes/scripts for presentation. No mandatory ECS or extra Replay-specific code generation.
- Root transforms have one owner. Authored offsets/animation belong beneath that
  root. Views may run their normal Godot process lifecycle; framework frame hooks
  remain available for deliberately centralized/batched renderers.
- Procedural arenas, trails and high-churn batches may remain procedural when
  their geometry/data is generated. Document those exceptions and their ownership.

## Delivery sequence

| Gate | Work | Required evidence |
| --- | --- | --- |
| E1 | Typed scripted-scene binding and practical ownership contract | Wrong script/invalid component rejection, ready/present/process/retire lifetime, native/WASM |
| E2 | Authored enemy appearance and reusable telegraph component | Scene-local enemy animation, no Session/World access; independent preview; real actor/feedback behavior and editor-authored changes |
| E3 | Authored player scene composed with weapon/equipment views | Detached display/cue inputs, child-owned visuals, preserved prediction/smoothing and fixed-seat semantics; down/respawn/equipment/camera checks |
| E4 | Validated Resource authoring and gameplay composition recipe | Scrapyard catalog bake with useful source errors, duplicate IDs/ranges rejected atomically; stock/hash and representative edits; documented composed gameplay components |
| E5 | Canonical onboarding and editor workflow | Scene map, responsibility map, F6 previews, extending an enemy/weapon/behavior; explicit procedural exceptions and multiplayer/recovery policy |
| E6 | Integration and performance assessment | Focused scene/native/WASM checks, host/client/observer agreement, recovery-sensitive scopes, representative measured costs without unfair old/new animation timing; preserve originals and model/wire contracts |

Success means a developer can open an actor scene, edit its visual children or
presentation settings, preview it independently, and connect it to replayable
state through a small typed adapter. New gameplay behavior remains an explicit
state/rule change with a documented authoring/baking path. Scrapyard should teach
that distinction through runnable code, not only prose.

<a id="current-status"></a>

## Recorded completion status

E1–E6 were completed. The authoring guide describes the migrated scenes, typed
adapters, Resource baking, procedural exceptions, and measured/validated
configurations.
