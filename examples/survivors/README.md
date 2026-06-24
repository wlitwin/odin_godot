# Odin Survivors

A small but complete **top-down arena shooter**, written entirely in **Odin** with
**zero GDScript gameplay code**. You move a hero around an arena; enemies stream in from the
edges and chase you; you auto-fire at the nearest one; bullets kill enemies for score;
enemies chip your health on contact; at 0 HP the run ends.

It is the headline example for [odin_godot](../../README.md): every node in `game.tscn`
carries a compiled `.odin` script, all visuals are plain `Polygon2D` geometry (no external
art), and the whole thing is meant to be **read as a tutorial** — each script is heavily
commented to teach one slice of the binding.

## Run it

```sh
# from the repo root, inside the Nix dev shell
nix develop --command bash -c 'bash build/build_scripts.sh examples/survivors'
/Applications/Godot.app/Contents/MacOS/Godot --path examples/survivors
```

- **Arrow keys** move the player (the blue triangle in the center).
- Your hero **auto-fires** at the nearest enemy — just keep moving and dodging.
- **Cyan grunts** are weak and fast; the **red brute** is tanky and slow (different
  `EnemyConfig` resources).
- Survive! Your **Score** and **HP** are shown top-left; at 0 HP the HUD reads **GAME OVER**.

## Verify it (headless)

```sh
nix develop --command bash -c 'bash examples/survivors/run.sh'   # prints SURVIVORS_OK
```

`run.sh` (a) opens the project in the headless **editor** briefly as a crash/missing-virtual
smoke test, then (b) runs `test_survivors.gd`, which drives the **real** game loop through
actual physics overlaps (never faked `emit_signal`):

1. `Input.action_press("ui_right")` → the Odin `_process` walks the player right.
2. A bullet placed overlapping an enemy, stepped through physics → `area_entered` →
   the bullet calls the enemy's `take_damage` **typed** → the enemy dies → the shared
   `game_state` score increments → the HUD's text updates.
3. An enemy placed on the player, stepped through physics → `body_entered` → the enemy calls
   the player's `take_damage` **typed** → the player emits `health_changed` → the HUD shows
   the new HP.

This example is also wired into the repo-wide suite (`tests/run_all.sh`, as
`survivors | SURVIVORS_OK`).

## Feature map — learn odin_godot by reading these scripts

Every script lives in `scripts/` and is a single authored `.odin` file (its `*.gen.odin`
sibling is generated boilerplate you never edit). The shared *module* files
(`game_state.odin`, `util.odin`) have no owner-struct, so they are just ordinary package
code compiled into the one scripts dll.

| Script | odin_godot features it teaches |
| --- | --- |
| **`game_state.odin`** | Shared cross-script **module** pattern (package-global singleton state, no owner-struct, no Godot autoload). Writers/readers across scripts share it. |
| **`util.odin`** | **Groups** as a decoupled "find that kind of thing" query (`gd.get_tree` + `scene_tree_get_first_node_in_group` / `get_nodes_in_group` + `Array` iteration). Plain shared helpers in a no-owner file. |
| **`enemy_config.odin`** | **Custom Resource** (`//gd:extends Resource`); `@export` of `int` / `f32` (with a `range=` slider hint) / `gd.Color`; **global `class_name`** (`//gd:class EnemyConfig`) so it can type-filter a picker. Two `.tres` instances: `grunt.tres`, `brute.tres`. |
| **`enemy.odin`** | `@export` of a **custom-Resource slot** (`resource=EnemyConfig`); **typed cross-script READ** (`rt.script_of(config, EnemyConfig)`); `add_to_group`; lifecycle **`_physics_process`** (chase); custom **`@(gd_method)` `take_damage`**; **`@(gd_connect="body_entered")`** declarative signal wiring; **typed cross-script WRITE** (calls the player's `take_damage`); script-declared **`//gd:signal died()`**. |
| **`bullet.odin`** | `@export` `int`/`f32`; lifecycle `_physics_process` (move + lifetime); **`@(gd_connect="area_entered")`**; **typed cross-script** (`rt.script_of(area, Enemy)`) to damage only real enemies. |
| **`player.odin`** | **Input** (`input_get_axis` over `ui_*` actions); `@export` incl. a **`PackedScene`** slot + a `range=` hint; `gd.instantiate`/`gd.add_child` instancing; **groups + typed cross-script** auto-aim (find nearest "enemies" member, set the bullet's `dir` typed); custom `@(gd_method) take_damage`; script-declared **signals** `health_changed(value)` + `died()`; shared-module reset/write. |
| **`spawner.odin`** | `@export` `PackedScene` + tunable `interval`; **timed spawning** (a delta accumulator in `_process`); `gd.instantiate` + `gd.add_child` at random arena edges. |
| **`hud.odin`** | Reads the shared **module** (`game_state`) each frame; **typed cross-script signal CONNECT** (`gd.connect_to(player, "health_changed", …)`) with a `@(gd_method)` handler; label text via `core:fmt` + `gd.label_set_text`. |

### `gd.*` ergonomic helpers used throughout

`get_node` · `get_parent` · `get_tree` · `add_child` · `add_to_group` · `instantiate` ·
`load_scene` · `connect_to` · `node_queue_free` · `polygon2d_set_color` ·
`node2d_get/set_(global_)position` · `label_set_text` · `print` / `print_int`. See
[`docs/authoring-guide.md`](../../docs/authoring-guide.md) for the full list and the
authoring conventions (struct tags, `@(gd_method)`, `@(gd_connect)`, `//gd:` markers).

## Files

```
examples/survivors/
  project.godot          # 640x360 window, main scene = game.tscn
  odin_godot.gdextension # loads the core (+ scripts) dll
  game.tscn              # arena: Player, Spawner, HUD, a placed Brute, background
  enemy.tscn             # spawnable grunt (Area2D + Polygon2D + collision)
  bullet.tscn            # spawnable bullet (Area2D + Polygon2D + collision)
  grunt.tres brute.tres  # two EnemyConfig data assets (different stats + colors)
  scripts/*.odin         # the 8 authored scripts (+ generated *.gen.odin)
  run.sh                 # build + editor-smoke + headless combat-loop test
  test_survivors.gd      # the headless driver (the ONLY GDScript — a test harness)
```

## Notes / simplifications

- **Movement** translates the `CharacterBody2D` directly (a kinematic position move), the
  same approach the coin-collector showcase uses — it keeps the input→movement teaching
  point front-and-center without a full `move_and_slide` collision setup.
- **Spawning** uses a `_process` time accumulator rather than a `Timer` node + signal — it
  is fewer moving parts to read while still demonstrating the `@export interval` knob.
- **Contact damage** is applied on `body_entered` (once per touch), which is exactly the
  signal + typed-cross-script path the test verifies; it is not continuous tick damage.
- The headless test pauses the player's auto-fire and the spawner during the bullet/enemy
  assertions so the kill it checks is the one it drives (deterministic), then verifies the
  HUD via real frame stepping.
