# Barrage — the data-oriented odin_godot showcase

A top-down bullet-hell: survive escalating waves, beat the three-phase boss. Thousands
of simultaneous bullets are simulated in an Odin `#soa` pool and rendered through **one
RenderingServer MultiMesh** — no nodes, no physics bodies, one draw call. The suite
drives the real game headless and asserts >4000 live bullets (`run.sh`, sentinel
`BARRAGE_OK`).

Run it: open this folder in Godot (build first: `Project > Tools > Build Odin Scripts`
or `bash ../../build/build_scripts.sh .`), press Play.

## Why it's shaped like this

Five **isolated script modules** (each its own dll; no cross-imports — the build
enforces it): `scripts/` (main: GameState autoload + Player), `modules/barrage`
(the SOA bullet core), `modules/enemies` (waves + boss), `modules/powerups`
(resources + pickups), `modules/ui` (menu/HUD/game-over). Every arrow between them is
engine-mediated: groups + `object_call` by name, typed signals wired in `game.tscn`
`[connection]`s, and the autoload. Saving a file in one module rebuilds only that dll.

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
| `@(gd_connect)` declarative signal wiring | `modules/powerups/pickup.odin` (`body_entered`) |
| Typed cross-dll reads (`rt.script_of`) | `pickup.odin` (PowerupConfig) |
| Autoload + engine-mediated state | `scripts/game_state.odin` |
| Scene loading (title → game → game-over) | `modules/ui/*.odin` |
| Group discovery, `instantiate` + `add_child_deferred` | `spawner.odin`, `manager.odin` |
| Export groups, ranges on every tunable | `scripts/player.odin` |

Not here: `gd_rpc`/multiplayer — see `examples/survivors` (co-op) for that story.
