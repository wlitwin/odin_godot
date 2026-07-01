# Odin Survivors

A complete **survivors-like** game (Vampire Survivors / Brotato / Soulstone Survivors style),
written entirely in **Odin** with **zero GDScript gameplay code**. It is the headline example
for [odin_godot](../../README.md) and a deliberate stress-test of the binding: every node in
`game.tscn` carries a compiled `.odin` script, all visuals are plain `Polygon2D` geometry (no
art assets), and the project leans on the binding's features heavily and idiomatically.

## The loop

Move (arrows / WASD) → your weapons **auto-attack** nearby enemies → enemies die and drop **XP
gems** → collect gems to fill the **XP bar** → **LEVEL UP** pauses the game and offers a choice
of **3 random upgrades** → pick one (stronger stats / a new weapon) → resume → enemies **scale
up** (faster spawns, tougher + more varied mix) → survive as long as you can → at 0 HP the run
ends on a **game-over** screen (time / level / kills / score) → **Restart**.

## Run it

```sh
# from the repo root, inside the Nix dev shell
nix develop --command bash -c 'bash build/build_scripts.sh examples/survivors'
/Applications/Godot.app/Contents/MacOS/Godot --path examples/survivors
```

- **Arrows / WASD** move the blue hero.
- Weapons fire automatically — keep moving and dodging.
- Walk over the green **XP gems** (they magnet toward you within pickup range).
- On **LEVEL UP**, click one of the three upgrade buttons.
- Four enemy types ramp in over time: **swarmer** (fast/weak), **grunt** (baseline), **brute**
  (tanky), **tank** (huge/slow) — each a different `EnemyConfig` `.tres`.

> The windowed *feel* (juice, pacing, "is it fun") can only be judged by a human — the headless
> harness proves the **loop works**, not that it is fun.

## Co-op — the HOST-authoritative variant

> **Looking for the co-op reference?** The canonical, peer-authoritative co-op example is
> [`examples/coop_arena`](../coop_arena/README.md) — one codebase, three modes, owner-auth
> netcode (your own actions are instant, no host round-trip). The co-op layer below is
> **retained** as the *host-authoritative* variant and as regression tests for the
> MultiplayerSpawner / MultiplayerSynchronizer / `@(gd_rpc)` machinery; read coop_arena's
> README for why peer authority is the recommended model.

The same project also ships a **2-player co-op** built from ONE codebase that runs in **three
modes**, selected from a start screen (`coop.tscn`, the project's main scene): **Single
Player** / **Host** / **Join**. Transport is auto-selected by platform — **native → ENet**,
**web (wasm) → WebRTC** — behind one UI. The KEY UNIFICATION: **single-player == host with
zero peers**, so the authoritative simulation (enemy spawning, enemy deaths, score) runs
identically whether or not a client is present; Single mode just never opens a transport.

The classic single-player example above (`game.tscn` + `test_survivors.gd`) is **unchanged** —
it remains the canonical full-loop regression (`SURVIVORS_OK`). The co-op game is a separate
scene/orchestrator (`scripts/net.odin`, `coop_player.tscn`, `coop_enemy.tscn`).

**Replication uses Godot's high-level nodes (proven to work with Odin scripts):**
- **MultiplayerSpawner** — the host spawns `coop_enemy.tscn` into `Enemies`; the engine
  auto-instantiates (and auto-despawns) it on every client.
- **MultiplayerSynchronizer** — streams continuous state from the authority: each player's
  `position` + Odin `@export hp` (authority = the owning peer), each enemy's `position`/`hp`/`id`
  (authority = host). Configs live in the `.tscn` (see the gotcha below).
- **`@(gd_rpc)`** carries discrete events: player spawn (peer→authority), the client's
  `request_damage`, shared score, and per-player level-up XP grants.

The host is authoritative: enemies, waves, and enemy deaths are host-owned; a client hit is a
`request_damage` RPC the host applies to the authoritative enemy. Each player levels
independently from XP awarded on shared kills.

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
> The two-window / two-browser co-op *feel* (latency, juice) still needs a human; the headless
> harnesses prove the **sync loop** holds over both ENet and WebRTC.

## Verify it (headless)

```sh
nix develop --command bash -c 'bash examples/survivors/run.sh'   # prints SURVIVORS_OK
```

`run.sh` runs three gates: (1) a headless **editor-open** smoke test (no crash / missing
virtual), (2) a **live `game.tscn`** run for 600 frames that must log no script/engine errors,
(3) `test_survivors.gd`, which drives the **real** loop through actual physics overlaps +
frame stepping (never faked `emit_signal`) and asserts each link; and (4) a **unified
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
generated boilerplate). `game_state.odin` / `util.odin` are owner-less *module* files.

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
| **`game.odin`** | the root **orchestrator + state machine**: `@onready` child refs; tree **PAUSE** (`gd.scene_tree_set_pause`); the **Input** ergonomics (`gd.action_add_key`) to bind WASD onto the `ui_*` actions; typed cross-script **connects** (player `leveled_up`/`died`) + calls into the menus/player; `@(gd_method)` accessors so GDScript/the test can read the module's state. |
| **`player.odin`** | **input** axes; `@export` stats + combat **multipliers** (groups) that upgrades mutate; PackedScene + WeaponConfig slots; spawns Weapon children; XP/leveling (`player_gain_xp` → emits `leveled_up`); `@(gd_method) apply_upgrade` (the `Upgrade_Kind`/`Upgrade_Stat` switch — observable effect); signals `health_changed`/`leveled_up`/`died`; `@(gd_method) take_damage`. |
| **`weapon.odin`** | **one script, three behaviours** switched on the WeaponConfig enum: Projectile (auto-fires bullets at the nearest in-range enemy, multishot fan), Orbit (runtime-built spinning blade `Polygon2D`s + area damage), Aura (periodic radius damage). Typed READ of the WeaponConfig **and** of the parent Player's live mults each shot; runtime node construction. |
| **`bullet.odin`** | `@export` damage/speed/**pierce**; `_physics_process`; `@(gd_connect="area_entered")`; typed cross-script (`rt.script_of → Enemy`) so it only damages enemies and pierces N before despawning. |
| **`enemy.odin`** | `@export` of a custom-Resource slot **and** a PackedScene (gem); typed READ of EnemyConfig; runtime restyle (`node2d_set_scale` + recolor from config); `_physics_process` chase; `@(gd_method) take_damage`; `@(gd_connect="body_entered")` contact; **`gd.add_child_deferred`** to drop the gem safely during a physics flush; `//gd:signal died()`. |
| **`xp_gem.odin`** | `@export value`; `_physics_process` magnet that reads the player's live `pickup_range` (typed); `@(gd_connect="body_entered")` collect → `player_gain_xp` (typed, may level up). |
| **`spawner.odin`** | `@export` PackedScene + four EnemyConfig slots; **difficulty scaling** (`interval_at(t)` + a time-shifted weighted type pick); typed WRITE of the chosen config onto a fresh enemy before `add_child`; `@(gd_method) interval_at` exposed for the test. |
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
  project.godot            # 640x360, main scene = game.tscn
  game.tscn                # Game root + Player + Spawner + Hud + LevelUpMenu + GameOver
  enemy.tscn bullet.tscn   # spawnable Area2Ds (Polygon2D + collision)
  xp_gem.tscn weapon.tscn  # the pickup + the weapon node
  config/*.tres            # EnemyConfig (4), WeaponConfig (3), UpgradeConfig (10) data assets
  scripts/*.odin           # the authored scripts (+ generated *.gen.odin)
  run.sh test_survivors.gd # build + 3 headless gates (the ONLY GDScript is the test harness)
```

## Notes / scope

- **Movement** translates the `CharacterBody2D` directly (a kinematic position move) rather than
  `move_and_slide` — it keeps the input→movement point front-and-center.
- **Orbit / Aura** weapons apply damage by a group + distance query (`damage_enemies_in_radius`)
  rather than per-blade `Area2D`s; the **Projectile** weapon uses real `Area2D` bullets, which is
  the physics path the headless test asserts the kill through.
- A real binding bug was found and fixed while building this (a zero-arg `@(gd_method)` emitted an
  `_ensure_ctors()` call with no matching definition) — see the repo notes. Spawning the XP gem
  during a bullet's `area_entered` also needed `gd.add_child_deferred` (a new ergonomic helper) to
  avoid Godot's "change monitoring state while flushing queries" guard.
```
