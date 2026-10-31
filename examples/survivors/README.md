# Odin Survivors

This survival arena game uses compiled Odin scripts for gameplay. It demonstrates
[odin_godot](../../README.md) input, signals, custom Resources, and scene spawning
through a move, fight, upgrade, and restart loop. The visuals use `Polygon2D`
geometry without external art assets.

<a id="the-loop"></a>

## Gameplay loop

Move with the arrow keys or WASD. Weapons attack nearby enemies automatically;
defeated enemies drop XP gems. Collect gems to fill the XP bar.

Each level-up pauses the game and offers three random upgrades. Pick a stat
upgrade or a weapon, then play resumes. Enemy spawning becomes faster and the mix
of enemies changes as the run progresses.

At 0 HP, the game-over screen shows time, level, kills, and score. Restart reloads
the scene and resets the run.

## Run it

```sh
# from the repo root, inside the Nix dev shell
nix develop --command bash -c 'bash build/build_scripts.sh examples/survivors'
/Applications/Godot.app/Contents/MacOS/Godot --path examples/survivors
```

- **Arrows / WASD** move the blue hero.
- Weapons fire automatically while you move and dodge.
- Walk over the green **XP gems** (they magnet toward you within pickup range).
- On **LEVEL UP**, click one of the three upgrade buttons.
- Four enemy types ramp in over time: **swarmer** (fast/weak), **grunt** (baseline), **brute**
  (high health), **tank** (large/slow). Each uses a different `EnemyConfig` `.tres`.

The headless checks below verify the gameplay loop. Use a windowed run to assess
pacing, feedback, and controls.

<a id="co-op--the-host-authoritative-variant"></a>

## Host-authoritative co-op

> For peer-authoritative engine-native co-op, read
> [`examples/coop_arena`](../coop_arena/README.md). It simulates player actions locally
> and trusts peer damage reports. This project retains the *host-authoritative*
> variant and regression tests for MultiplayerSpawner / MultiplayerSynchronizer /
> `@(gd_rpc)`.

The project’s main scene, `coop.tscn`, offers three modes: Single Player, Host,
and Join. The two-player co-op example uses Godot’s engine-native replication
nodes. Native builds select ENet; web builds select WebRTC. Single Player uses
the same host-owned enemy spawning, deaths, and score with zero peers and no
open transport.

`game.tscn` is the separate single-player scene exercised by
`test_survivors.gd` (`SURVIVORS_OK`). The co-op game uses `scripts/net.odin`,
`coop_player.tscn`, and `coop_enemy.tscn`.

Replication uses these Godot facilities:

- **MultiplayerSpawner** creates `coop_enemy.tscn` under `Enemies` when the host
  spawns an enemy, then replicates creation and despawn to clients.
- **MultiplayerSynchronizer** streams continuous state. Each player's owning
  peer supplies `position` and Odin `@export hp`; the host supplies each enemy's
  `position`/`hp`/`id`. Author the replication configuration in the `.tscn`, as
  described below.
- **`@(gd_rpc)`** carries discrete events: player spawn requests from peers to
  the authority, the client's `request_damage`, shared score, and per-player
  level-up XP grants.

The host owns enemies, waves, and enemy deaths. A client submits a
`request_damage` RPC, which the host applies to its enemy state. Each player
levels independently from XP awarded on shared kills.

```sh
# co-op native (two ENet processes): prints COOP_NATIVE_OK
nix develop --command bash -c 'bash examples/survivors/coop_native_run.sh'
# co-op web (two headless-Chrome peers over WebRTC): prints COOP_WEB_OK (SKIPs without Chrome)
nix develop --command bash -c 'bash examples/survivors/coop_web_run.sh'
```

> **Gotcha (replication nodes + Odin):** a `MultiplayerSynchronizer`'s `SceneReplicationConfig`
> must be authored in the `.tscn` (present when the node enters the tree). Applying it in the
> root script's `_ready` is too late — `on_replication_start` fires during `add_child` and
> errors `ERR_UNCONFIGURED`, so nothing syncs. See `tests/repl_spike` for the minimal proof.
>
These checks exercise synchronization over native ENet and browser WebRTC.
Use two interactive clients to assess the effect of latency on play.

## Verify it (headless)

```sh
nix develop --command bash -c 'bash examples/survivors/run.sh'   # prints SURVIVORS_OK
```

`run.sh` runs four checks:

1. Open the editor headlessly and check for crashes or missing virtual methods.
2. Run `game.tscn` for 600 frames without script/engine errors.
3. Run `test_survivors.gd` through physics overlaps and frame stepping, checking
   each gameplay milestone below.
4. Run `coop.tscn` in single mode (`COOP_ROLE=single`, host with no network) and
   require successful startup and completion (`SINGLE_DONE`).

| Milestone | What it proves |
| --- | --- |
| `base-types` | `//gd:extends` resolves (Player = CharacterBody2D, Hud = CanvasLayer). |
| `weapon-equipped` | the player auto-spawns its starting Weapon child (auto-attack). |
| `input-move` | `Input.action_press` → the Odin `_process` walks the player. |
| `kill+gem` | a real bullet overlap → typed `take_damage` → enemy dies → a kill is counted and an XP gem drops. |
| `gem-xp` | the player overlaps the gem → shared `game_state` XP increases. |
| `levelup` | enough XP → `leveled_up` → the upgrade menu is visible and the tree is paused. |
| `upgrade-applied` | invoking a menu button handler (as a click would) applies the upgrade (an observable player stat / weapon changes) and resumes. |
| `difficulty` | the spawn interval shrinks as run-time grows. |
| `game-over` | a real contact hit drops HP to 0 → `died` → GameOver state + the screen shows. |
| `restart` | the restart handler reloads + resets to a fresh run (level 1, 0 kills, Playing). |

It is also wired into the repo-wide suite (`tests/run_all.sh`, as `survivors | SURVIVORS_OK`).

<a id="feature-map--which-odin_godot-feature-each-file-demonstrates"></a>

## SDK features by script

Authored `.odin` scripts live in `scripts/`; builds also produce `*.gen.odin`
registration code. `game_state.odin` and `util.odin` are shared package files
without an attached Godot node or script-state owner. Here, shared package code
runs in the same scripts library; it is not a separately compiled script module.

### Custom Resources (data-driven; `//gd:extends Resource` + `.tres` instances)

| Script / assets | Features |
| --- | --- |
| **`enemy_config.odin`** + `config/{swarmer,grunt,brute,tank}.tres` | Defines a custom Resource with int / f32 `@export` fields (`range=` sliders), `gd.Color`, and a global `class_name` for typed Inspector pickers. Fields include hp, speed, damage, xp_value, points, radius, and color. |
| **`weapon_config.odin`** + `config/{pistol,orbit_blade,aura}.tres` | Defines a Resource with an `enum=` int `@export` (`kind`: Projectile/Orbit/Aura), `range=` sliders, String name, and Color. The `weapon` script selects behavior from `kind`. |
| **`upgrade_config.odin`** + `config/up_*.tres` (10) | Defines String name and `multiline` description, two `enum=` ints (kind + stat), an f32 amount, and a typed cross-resource picker (`resource=WeaponConfig`). Demonstrates one custom Resource referencing another. |

<a id="modules-owner-less-shared-package-code"></a>

### Shared package code without a node

| Script | Features |
| --- | --- |
| **`game_state.odin`** | Stores package globals for run time, kills, score, level, the XP curve, `add_xp`/`add_kill`, Playing/LevelUp/GameOver state, and `pending_levelups`. Every script in the package shares them; no owner struct or Godot attachment is required. |
| **`util.odin`** | Queries Godot groups through `find_player`/`find_game`/`nearest_enemy`, applies typed area damage with `damage_enemies_in_radius` calling `enemy_take_damage`, and supplies vector helpers. |

### Node scripts

For node scripts, `self` points to the Odin script data and `self.owner` holds
the Godot node handle.

| Script | Features |
| --- | --- |
| **`game.odin`** | Controls the root scene and run state. Uses `@onready` child references, `gd.scene_tree_set_pause`, and `gd.action_add_key` to bind WASD to `ui_*` actions. Connects typed player `leveled_up`/`died` signals, calls menus/player scripts, and exposes module state through `@(gd_method)` accessors for GDScript/tests. |
| **`player.odin`** | Reads input axes; exports stats, grouped combat multipliers, PackedScene, and WeaponConfig slots; spawns Weapon children. `player_gain_xp` emits `leveled_up`; `@(gd_method) apply_upgrade` uses `Upgrade_Kind`/`Upgrade_Stat`. Declares `health_changed`/`leveled_up`/`died` and exposes `@(gd_method) take_damage`. |
| **`weapon.odin`** | Selects three behaviors from WeaponConfig: Projectile fires at the nearest in-range enemy with a multishot fan; Orbit creates spinning blade `Polygon2D`s and applies area damage; Aura applies periodic radius damage. Reads the parent Player’s current multipliers for each shot and constructs effect nodes at runtime. |
| **`bullet.odin`** | Exports damage/speed/pierce, moves in `_physics_process`, and receives `@(gd_connect="area_entered")`. Resolves `rt.script_of → Enemy` for typed cross-script damage, piercing N enemies before despawn. |
| **`enemy.odin`** | Exports a custom-Resource slot and PackedScene for gems. Reads EnemyConfig, applies `node2d_set_scale` and config color, chases in `_physics_process`, and exposes `@(gd_method) take_damage`. Uses `@(gd_connect="body_entered")` for contact, `gd.add_child_deferred` for gem drops during physics flush, and a `died` signal field. |
| **`xp_gem.odin`** | Declares `@export value`, follows the player within its typed `pickup_range` in `_physics_process`, and collects through `@(gd_connect="body_entered")` calling `player_gain_xp`, which can trigger level-up. |
| **`spawner.odin`** | Exports a PackedScene and four EnemyConfig slots. Uses `interval_at(t)` and a time-shifted weighted type selection for difficulty. Sets the fresh enemy’s config before `add_child` and exposes `@(gd_method) interval_at` to tests. |
| **`hud.odin`** | Resolves XP/Health `ProgressBar` and info `Label` children through `@onready`, reads shared package state each frame, writes properties through `gd.set_float`/`gd.set_string`, and connects the typed `health_changed` signal. |
| **`levelup_menu.odin`** | Holds 10 typed custom-resource `@export` slots and `@onready` buttons. Uses `gd.connect_to` to route Button `pressed` to `@(gd_method)`, reads Resource Strings through `gd.get_string`, and calls `apply_upgrade` and Game `after_pick`. `process_mode=Always` keeps the menu active while paused. |
| **`game_over.odin`** | Uses `@onready` references, reads shared run-summary state, connects Restart through `gd.connect_to`, and calls typed `game_restart` to reload and reset. |

<a id="gd-ergonomic-helpers-used-throughout"></a>

### `gd.*` helper procedures

`get_node` · `get_parent` · `get_tree` · `add_child` · **`add_child_deferred`** · `add_to_group`
· `instantiate` · `load_scene` · `connect`/`connect_to` · `set_bool`/`set_float`/`set_string` ·
`get_string` · `action_add_key` · `scene_tree_set_pause` · `scene_tree_reload_current_scene` ·
`node2d_*` · `polygon2d_*` · `node_queue_free`. See
[`docs/authoring-guide.md`](../../docs/authoring-guide.md) for the full catalog.

## Files

```
examples/survivors/
  project.godot            # 640x360, main scene = coop.tscn
  coop.tscn                # Single Player / Host / Join start screen
  game.tscn                # Game root + Player + Spawner + Hud + LevelUpMenu + GameOver
  enemy.tscn bullet.tscn   # spawnable Area2Ds (Polygon2D + collision)
  xp_gem.tscn weapon.tscn  # the pickup + the weapon node
  config/*.tres            # EnemyConfig (4), WeaponConfig (3), UpgradeConfig (10) data assets
  scripts/*.odin           # the authored scripts (+ generated *.gen.odin)
  run.sh test_survivors.gd # build + 4 headless checks
```

## Notes / scope

- **Movement** translates the `CharacterBody2D` directly instead of calling
  `move_and_slide`. The example demonstrates the input-to-position update
  without solver-based movement.
- **Orbit / Aura** weapons use a group and distance query
  (`damage_enemies_in_radius`) for damage. **Projectile** weapons use `Area2D`
  bullets; the headless test checks kills through their physics overlaps.
- Spawn an XP gem with `gd.add_child_deferred` when handling a bullet’s
  `area_entered` signal. Godot cannot change collision monitoring while flushing
  physics queries.
