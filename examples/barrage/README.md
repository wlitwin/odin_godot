<a id="barrage--the-data-oriented-odin_godot-showcase"></a>

# Barrage — data-oriented odin_godot example

Barrage is a top-down bullet-hell game with escalating waves and a three-phase
boss. It simulates thousands of bullets in an Odin `#soa` pool and renders them
through one RenderingServer MultiMesh in one draw call. Individual bullets have
no nodes or physics bodies. The headless suite drives the game and checks >4000
live bullets (`run.sh`, sentinel `BARRAGE_OK`).

Run it: open this folder in Godot (build first: `Project > Tools > Build Odin Scripts`
or `bash ../../build/build_scripts.sh .`), press Play.

<a id="why-its-shaped-like-this"></a>

## Script module layout

The game uses five isolated script modules, each compiled into its own dll.
The build prohibits imports between modules. `scripts/` contains the GameState
autoload and Player; `modules/barrage` handles the SOA bullet simulation;
`modules/enemies` handles waves and the boss; `modules/powerups` contains
resources and pickups; and `modules/ui` provides menu, HUD, and game-over scenes.

Modules communicate through Godot groups, name-based `object_call`, typed signals
connected in `game.tscn` through `[connection]` entries, and the autoload. Saving
a script rebuilds only its module's dll.

## Feature → file map

| Feature (docs) | Where |
|---|---|
| `#soa` pool, swap-remove sim, circle collision | `modules/barrage/field.odin` |
| RenderingServer MultiMesh + direct `Packed_Float32_Array` buffer write | `field.odin` (`field_upload_buffer`) |
| Typed signals: `Signal0/1/2`, **`SignalN` struct payload** | `game_state.odin`, `field.odin`, `boss.odin` (`phase_changed`) |
| Scene-declared cross-module signal `[connection]`s | `game.tscn` (field → Player / Spawner) |
| `flow` sequencer (phases, repeat, call, wait) | `modules/enemies/boss.odin` |
| `flowgd.tween` (engine tween as a flow Action) | `modules/ui/title.odin` |
| Custom `Resource` class + `enum=`/`range=` exports + `.tres` assets | `modules/powerups/powerup_config.odin`, `config/*.tres` |
| `resource=` PackedScene/typed-resource exports | `spawner.odin`, `manager.odin` |
| **Typed-array export** (`array=`), assigned from the scene | `manager.odin` (`drop_table`), `game.tscn` |
| `@(gd_connect)` declarative signal wiring | `modules/powerups/pickup.odin` (`body_entered`) |
| **Pure-Odin `events.Event(T)`** (same-module fan-out; cross-module notification uses one engine call) | `spawner.odin` (`slow_changed`), `enemy.odin` (subscribe/exit_tree/reload) |
| Typed Resource access within a module (`rt.script_of`) | `pickup.odin` (PowerupConfig) |
| Autoload + engine-mediated state | `scripts/game_state.odin` |
| Scene loading (title → game → game-over) | `modules/ui/*.odin` |
| Group discovery, `instantiate` + `add_child_deferred` | `spawner.odin`, `manager.odin` |
| Export groups, ranges on every tunable | `scripts/player.odin` |

For `gd_rpc` and multiplayer examples, see the coop layer in `examples/survivors`.

## Web export

The `.gdextension`'s `web.*.wasm32` entry points to
`res://bin/libodin_godot.wasm`. Exporting the Web preset compiles all five script
modules into one Emscripten SIDE_MODULE. Run `bash web_run.sh` inside the
development shell to export headlessly and check browser startup and gameplay
(`BARRAGE_WEB_OK`). Scripts use the engine's `OS` singleton for environment
checks because `core:os` has no WASM OS layer; see `game_state.odin`, `is_test`.
