# Box3D offline: tower knockdown

A single-player Box3D example with no Kit, no Replay and no network: one script
owns a Box3D world and steps it itself. Start here if you want Box3D physics in an
offline game.

A pyramid of 15 boxes stands on the ground. The HUD counts the boxes knocked down.

| Control | Action |
| --- | --- |
| Left click or Space | Launch a ball from the camera toward the mouse |
| Hold right mouse button and drag | Orbit the camera around the middle of the stack |
| W / S (or Up / Down) | Move the camera in and out |
| R | Rebuild the tower |

## Run it

From the repository root:

```sh
nix develop --command bash examples/box3d_offline/play.sh
```

`play.sh` builds the Box3D native library into the ignored `.box3d-cache` (about
15 seconds the first time), builds the scripts, and opens the game. To use a native
library you already built, set `BOX3D_NATIVE_LIBRARY` to its `libogb3.dylib` or
`libogb3.so`. The build copies that library into `bin/` next to the SDK core, which
loads it at startup.

To work on it in the Godot editor, pass `-e`; other arguments go to Godot as well:

```sh
nix develop --command bash examples/box3d_offline/play.sh -e
```

The editor rebuilds the scripts whenever you save an `.odin` file, and that rebuild
needs `BOX3D_NATIVE_LIBRARY`, which `play.sh` sets for you. If you open the project
another way, such as from Godot's Project Manager, it still runs, but saving a
script fails to link Box3D and keeps the previous build until you run `play.sh` again.

## Put it on itch.io

Build the browser version and the zip itch.io expects:

```sh
nix develop --command bash examples/box3d_offline/export_web.sh
```

This writes `out/web/` and `out/box3d-offline-web.zip` (about 12 MB, `index.html` at
its root). It builds Box3D for WebAssembly, links it into the game's single wasm
module, and runs Godot's Web export with the preset in `export_presets.cfg`. Try it
locally before uploading; `serve.sh` adds the headers the browser build needs:

```sh
nix develop --command bash build/serve.sh examples/box3d_offline/out/web
```

Then open <http://localhost:8099/>. On itch.io:

1. Create a new project and set **Kind of project** to **HTML**.
2. Upload `out/box3d-offline-web.zip` and tick **This file will be played in the
   browser**.
3. Under **Embed options**, set the viewport to 1280 × 720 (or enable the fullscreen
   button), and tick **SharedArrayBuffer support**. The build uses threads, which
   need it; without it the page stays blank.
4. Save and view the page.

For repeated uploads, itch's `butler` command-line tool can push the zip:
`butler push examples/box3d_offline/out/box3d-offline-web.zip USER/GAME:html5`.

## How it works

Everything is in [`scripts/tower.odin`](scripts/tower.odin):

- **Building the world.** `build_world` calls `world_create`, then `body_create`
  and `shape_box` for the static ground and each dynamic box. A reset destroys the
  world, which destroys every body in it, and builds a fresh one.
- **Stepping.** `box_tower_physics_process` calls `world_step_fixed` once per Godot
  physics frame. That call always advances 1/60 s, so `project.godot` keeps the
  physics rate at 60 Hz.
- **Launching.** `launch_ball` turns the mouse position into a camera ray and creates
  a dynamic sphere with that starting velocity. `is_bullet` turns on continuous
  collision so a fast ball cannot pass through a box. Up to eight balls exist at
  once; the ninth recycles the oldest.
- **Camera.** `box_tower_process` runs every rendered frame, separately from the
  physics. While the right button is held it turns mouse movement into yaw and
  pitch around the stack, and the zoom keys scale the distance; `place_camera`
  then positions the camera and points it at the stack. Launching uses the camera's
  ray, so it aims correctly from any angle.
- **Drawing.** Each body has an ordinary `MeshInstance3D`. After every step,
  `sync_nodes` copies each body's pose onto its node. The nodes never feed back into
  the simulation.
- **Cleanup.** `box_tower_exit_tree` destroys the world when the scene closes.

Densities are in kg/m³, and Box3D's default is 1000 (water). The boxes use 250 and
the ball 4000, so each box weighs about 128 kg and the ball about 450 kg. Set
densities explicitly: with the default, a small ball barely moves a large box.

## Going further

- Add interpolation if you render faster than 60 Hz: the nodes currently move only
  on physics frames.
- For editor-authored worlds, saved checkpoints, rollback or multiplayer, use the
  [Kit and Replay samples](../../docs/design/box3d/samples.md). The raw API is
  described in [box3d/README.md](../../box3d/README.md).
