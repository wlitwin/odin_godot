# Canonical editor-first Replay example

Scrapyard shows the recommended separation between authored Godot composition and
replayable Odin gameplay. The original sibling Scrapyard remains independently
runnable. This example uses authority/prediction/observed presentation; use Duel
for deterministic peer rollback and Slopball for cooperative engine physics.

## Start in the editor

Build the project with the repository's normal Odin/Godot build workflow, then open
`project.godot` in Godot. The project plugin also rebuilds script bindings as needed.

```sh
nix develop --command bash build/build_scripts.sh examples/replay_scrapyard
nix develop --command bash examples/replay_scrapyard/play.sh
```

The following scenes run independently with F6. The enemy, runner and HUD view
previews create no Session or World; the gameplay workbench runs a real game session:

| Scene | Try changing | What owns the change |
| --- | --- | --- |
| `dev/enemy_view.tscn` | Preview-state Resource, Body offset, style tint/texture/fps, Telegraph color | Enemy scene, preview and appearance Resources |
| `dev/runner_view.tscn` | Preview down/reload, Gun/Flash offsets, Reload/Beacon origins | Runner scene and composed weapon/equipment scripts |
| `dev/hud_view.tscn` | Vitals layout, labels/theme, HUD anchors | Authored HUD scene with sample display values |
| `dev/workbench.tscn` | Hurt/jam/statuses, boss, kegs, shop | The real game, driven through admitted development actions |

The standalone view previews are cosmetic inspection tools. The workbench tests
gameplay and multiplayer-facing behavior through the actual runner. They serve
different editing tasks, and neither writes arbitrary live World fields.

## Scene map

```text
entities/mob.tscn                 ScrapEnemyView
  Body                           authored Sprite2D
  Telegraph                      views/components/telegraph.tscn
visuals/enemies/*.tres            ScrapEnemyStyle Resources
archetypes/enemies/*.tres         MobDef + scene + appearance registrations

entities/runner.tscn              ScrapRunnerView
  Body                           authored Sprite2D
  Gun                            views/components/weapon.tscn
    Flash                        authored child atlas/offset
  Reload                         views/components/reload.tscn
  Beacon                         views/components/beacon.tscn
  Nameplate                      authored Label/layout

ui/hud.tscn                      ReplayScrapyardHud
  Vitals, Ammo, BossPlate, Prompt authored UI layout
```

`scripts/views` owns the actors' local appearance and process callbacks. Weapon
flashes and equipment bob/pulse are reusable child behaviors. Geometry, textures,
origins and tuning live in scenes/Resources. Scripts capture authored origins before
animating relative to them; ordinary scene composition survives the runtime binding.

`shared/presentation` owns pure projection into Mob_View, Runner_View and Hud_View.
These contain bounded values without scene or mutable Resource pointers.
`scripts/mob_bridge.odin` uses an owned typed script/archetype binding and forwards
local impact notices through a typed visitor. Generated view descriptors select
the explicit hooks; a shared scope tracker compares the explicit run/floor key.
`drawing.odin` selects the timelines, applies existing smoothing and feeds runner/HUD
values. It no longer contains actor frame-selection/equipment animation loops.

The [Stormcaller walkthrough](stormcaller.md) records adding a new enemy through this
path, including the actual authoring glue and save-version work it required.

## Gameplay is also composed

`shared/game/game.odin` defines the snapshot boundary and Player's composed state:
Gun_State, revive Channel, effect slots, cooldowns, progression and motion values.
`combat.odin`, `brains.odin`, `abilities.odin`, `effects.odin` and the shared
`replay/play` mechanisms contain rules. Node animation never determines a hit.
The small [component recipe](../replay_recipes/components.odin) demonstrates composing
state and procedures without a scene, ECS or new framework registration layer.

Keep mutable gameplay state here, including RNG and allocation/lifetime state.
Keep visual timers, cached child references and particle resources in view scripts.
The framework handles replay/history/transport; the game continues to choose its
prediction, authority, admission and recovery policies.

## Edit appearance or gameplay deliberately

For a new look for an existing enemy, duplicate a Resource in `visuals/enemies`,
edit its texture/frame counts/tint/fps, and assign it to an enemy archetype
registration. Standalone scenes expose one `appearance` for F6 preview. This changes presentation only. Required
styles/components are validated when binding; incomplete scenes are rejected.

For different health, speed, radius or weapon mechanics, edit the corresponding
Resource under `data`. `scripts/content.odin` uses Replay's definition baker to
validate a complete catalog and rejects duplicate IDs or invalid fields with source
paths. The baked catalog is a value in World and recovery checkpoints. Editing a
Resource afterward cannot mutate a running simulation. Reopen a run to admit a new
catalog. Export the same typed bake with `tools/stock.py --project PATH` for
headless stock/tests; `--check` detects stale content. The host's catalog travels in snapshots; semantic code/schema changes still
follow the game's version/conversion policy.

For new behavior, add explicit owned component state if necessary, implement its
pure tick/action rule, validate it, and expose any authoring configuration through
Resource baking. Add the required display fields/projection and let an appropriate
view component render them. Cosmetic child composition alone needs no wire change.
A new enemy kind needs a stable gameplay ID, explicit behavior and one authored
[archetype registration](authoring-tools.md);
attaching a script to a Node does not automatically register multiplayer gameplay.

## Identities, input, and recovery

Enemies and loot follow entity generations. New generations and epoch/reset/floor
boundaries get new view lifetimes. Initial observations seed silently. Runners are
four permanent seat views; generation/warp/epoch changes reset local body cues while
preserving seat/node identity for camera and UI references. This distinction is
intentional, rather than forcing every view to have the same lifetime.

Movement/held controls and discrete actions retain their existing admission paths.
Scene/UI signals can request actions; they do not mutate World. Local player poses
use prediction and smoothing, remote actors use observed presentation, and permission
checks use authority state. Camera following preserves the authoritative roster and
matches the displayed body's generation.

Client wound effects use exact retained public event-tick frames because ordinary
snapshots omit the server's hit_history. Such frames may contain corrected or locally
predicted poses; they are cosmetic placement, not hit evidence. Missing ticks or a
mismatched generation refuse placement. Authority hit judgment/history remain intact.

## Deliberately specialized paths

Seeded arena dressing, projectile/beam/glob batches, particles/trails and some
presentation-service orchestration remain procedural. Their geometry or membership
is generated/high-churn, and the previous migration already measured a cost to
replacing preallocated slots with per-lifetime scenes. Audio routing, lobby/shop
signals and existing authored menu/HUD scenes retain their appropriate APIs.
They are documented examples of specialized rendering, not hidden gameplay state.
This migration does not require every line of rendering to become an inspector knob.

The example still contains older features and a historical parity ledger. The
canonical recommendation is the ownership/composition workflow described here;
it is not a claim that every subsystem is the only correct implementation.

## Validation

```sh
REPLAY_EDITOR_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_editor/run.sh
```

The gate builds an isolated project, checks native/WASM script compilation,
independent scene previews, edited child offsets/Resources, script/component
rejection, catalog baking, actor/feedback/audio/HUD behavior, and combat/revive
host-client-observer agreement. Recovery/performance receipts and exact limits are
recorded in the [delivery assessment](../../docs/replay/editor-first-progress.md).
No original game or simulation schema is replaced by this workflow.
