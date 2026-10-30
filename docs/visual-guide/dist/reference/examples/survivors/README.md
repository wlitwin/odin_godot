# Odin Survivors

This survival arena game uses compiled Odin scripts for gameplay. It demonstrates
[odin_godot](../../README.md) input, signals, custom Resources, and scene spawning
through a move, fight, upgrade, and restart loop. The visuals use `Polygon2D`
geometry without external art assets.

## The loop

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
  (tanky), **tank** (huge/slow) — each a different `EnemyConfig` `.tres`.

The headless checks below verify the gameplay loop. Use a windowed run to assess
pacing, feedback, and controls.

## Co-op — the HOST-authoritative variant

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
- **MultiplayerSpawner** — the host spawns `coop_enemy.tscn` into `Enemies`; the engine
  auto-instantiates (and auto-despawns) it on every client.
- **MultiplayerSynchronizer** — streams continuous state from the authority: each player's
  `position` + Odin `@export hp` (authority = the owning peer), each enemy's `position`/`hp`/`id`
  (authority = host). Configs live in the `.tscn` (see the gotcha below).
- **`@(gd_rpc)`** carries discrete events: player spawn (peer→authority), the client's
  `request_damage`, shared score, and per-player level-up XP grants.

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

`run.sh` runs four checks: (1) a headless **editor-open** smoke test (no crash / missing
virtual), (2) a **live `game.tscn`** run for 600 frames that must log no script/engine errors,
(3) `test_survivors.gd`, which drives the **real** loop through actual physics overlaps +
frame stepping, rather than manually emitting signals, and asserts each link; and (4) a **unified
single-mode** smoke of `coop.tscn` (`COOP_ROLE=single`, host-with-no-net) that must boot + run
clean (`SINGLE_DONE`):

| Milestone | What it proves |
| --- | --- |
| `base-types` | `//gd:extends` resolves (Player = CharacterBody2D, Hud = CanvasLayer). |
| `weapon-equipped` | the player auto-spawns its starting Weapon child (auto-attack). |
| `input-move` | `Input.action_press` → the Odin `_process` walks the player. |
| `kill+gem` | a real bullet overlap → typed `take_damage` → enemy dies → a **kill** is counted **and** an XP gem drops. |
| `gem-xp` | the player overlaps the gem → shared `game_state` **XP** increases. |
| `levelup` | enough XP → `leveled_up` → the upgrade **menu is visible** and the **tree is paused**. |
| `upgrade-applied` | invoking a menu button handler (as a click would) **applies** the upgrade (an observable player stat / weapon changes) and **resumes**. |
| `difficulty` | the spawn interval **shrinks** as run-time grows. |
| `game-over` | a real contact hit drops HP to 0 → `died` → **GameOver** state + the screen shows. |
| `restart` | the restart handler reloads + resets to a fresh run (level 1, 0 kills, Playing). |

It is also wired into the repo-wide suite (`tests/run_all.sh`, as `survivors | SURVIVORS_OK`).

## Feature map — which odin_godot feature each file demonstrates

Scripts live in `scripts/` (each a single authored `.odin`; its `*.gen.odin` sibling is
generated boilerplate). `game_state.odin` / `util.odin` are shared *module* files without an attached
Godot node or script-state owner.

### Custom Resources (data-driven; `//gd:extends Resource` + `.tres` instances)

| Script / assets | Features |
| --- | --- |
| **`enemy_config.odin`** + `config/{swarmer,grunt,brute,tank}.tres` | custom Resource; `@export` of int / f32 (`range=` sliders) / `gd.Color`; global `class_name` so it type-filters a picker. hp, speed, damage, xp_value, points, radius, color. |
| **`weapon_config.odin`** + `config/{pistol,orbit_blade,aura}.tres` | a custom Resource with an `enum=` int `@export` (`kind`: Projectile/Orbit/Aura) the `weapon` switch reads; many `range=` sliders; String name + Color. |
| **`upgrade_config.odin`** + `config/up_*.tres` (10) | a Resource mixing a String name, a `multiline` String description, **two** `enum=` ints (kind + stat), an f32 amount, **and** a typed cross-resource picker (`resource=WeaponConfig`) — one custom resource referencing another. |

### Modules (owner-less shared package code)

| Script | Features |
| --- | --- |
| **`game_state.odin`** | the shared cross-script **module** pattern — run time, kills, score, level, the XP curve + `add_xp`/`add_kill`, the run state machine (Playing/LevelUp/GameOver), and `pending_levelups`. No owner struct, no Godot glue; every script shares these package globals. |
| **`util.odin`** | **groups** as a decoupled "find that kind of thing" query (`find_player`/`find_game`/`nearest_enemy`); typed area damage (`damage_enemies_in_radius` calls `enemy_take_damage` typed); vector helpers. |

### Node scripts

| Script | Features |
| --- | --- |
| **`game.odin`** | the root scene controller and state machine: `@onready` child refs; scene-tree pausing (`gd.scene_tree_set_pause`); the **Input** ergonomics (`gd.action_add_key`) to bind WASD onto the `ui_*` actions; typed cross-script **connects** (player `leveled_up`/`died`) + calls into the menus/player; `@(gd_method)` accessors so GDScript/the test can read the module's state. |
| **`player.odin`** | **input** axes; `@export` stats + combat **multipliers** (groups) that upgrades mutate; PackedScene + WeaponConfig slots; spawns Weapon children; XP/leveling (`player_gain_xp` → emits `leveled_up`); `@(gd_method) apply_upgrade` (the `Upgrade_Kind`/`Upgrade_Stat` switch — observable effect); signals `health_changed`/`leveled_up`/`died`; `@(gd_method) take_damage`. |
| **`weapon.odin`** | **one script, three behaviors** switched on the WeaponConfig enum: Projectile (auto-fires bullets at the nearest in-range enemy, multishot fan), Orbit (runtime-built spinning blade `Polygon2D`s + area damage), Aura (periodic radius damage). Reads the WeaponConfig and the parent Player’s current multipliers for each shot; constructs nodes at runtime. |
| **`bullet.odin`** | `@export` damage/speed/**pierce**; `_physics_process`; `@(gd_connect="area_entered")`; typed cross-script (`rt.script_of → Enemy`) so it only damages enemies and pierces N before despawning. |
| **`enemy.odin`** | `@export` of a custom-Resource slot **and** a PackedScene (gem); reads EnemyConfig; runtime restyle (`node2d_set_scale` + recolor from config); `_physics_process` chase; `@(gd_method) take_damage`; `@(gd_connect="body_entered")` contact; **`gd.add_child_deferred`** to drop the gem safely during a physics flush; the `died` signal field. |
| **`xp_gem.odin`** | `@export value`; `_physics_process` magnet that reads the player's live `pickup_range` (typed); `@(gd_connect="body_entered")` collect → `player_gain_xp` (typed, may level up). |
| **`spawner.odin`** | `@export` PackedScene + four EnemyConfig slots; **difficulty scaling** (`interval_at(t)` + a time-shifted weighted type pick); writes the chosen config onto a fresh enemy before `add_child`; `@(gd_method) interval_at` exposed for the test. |
| **`hud.odin`** | `@onready` auto-wired child refs (XP/Health `ProgressBar` + info `Label`); reads the shared module each frame; property helpers (`gd.set_float`/`gd.set_string`); typed cross-script signal **connect** to `health_changed`. |
| **`levelup_menu.odin`** | a bank of 10 typed custom-resource `@export` slots (the pool); `@onready` button refs; `gd.connect_to` wiring each Button's `pressed` to a `@(gd_method)`; reading a resource's String fields generically (`gd.get_string`); typed calls into the player (`apply_upgrade`) and Game (`after_pick`). `process_mode=Always` keeps it live while paused. |
| **`game_over.odin`** | `@onready` refs; reads the module for the run summary; `gd.connect_to` on the Restart button; a typed call into `game_restart` (reload + reset). |

### `gd.*` ergonomic helpers used throughout

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

- **Movement** translates the `CharacterBody2D` directly (a kinematic position move) rather than
  `move_and_slide` — it keeps the input→movement point front-and-center.
- **Orbit / Aura** weapons apply damage by a group + distance query (`damage_enemies_in_radius`)
  rather than per-blade `Area2D`s; the **Projectile** weapon uses real `Area2D` bullets, which is
  the physics path the headless test asserts the kill through.
- Spawn an XP gem with `gd.add_child_deferred` when handling a bullet’s
  `area_entered` signal. Godot cannot change collision monitoring while flushing
  physics queries.
