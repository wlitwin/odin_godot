# Knock down a tower offline

Run a single-player game that launches a ball at a pyramid of fifteen boxes.
Then change the ball's mass and inspect the loop that connects Box3D to ordinary
Godot nodes. Kit and Replay are optional for this tutorial.

You need the repository checkout, Nix shell, and working Godot executable from
[the scripting tutorial](../scripting/first-scene.md). Run commands from the
repository root. The native build needs to download its pinned engine source
on the first run.

## 1. Build and play

```sh
nix develop --command bash examples/box3d_offline/play.sh -e
```

The helper builds the native backend into `.box3d-cache`, builds the Odin
scripts, and opens the editor. Wait for its initial import, then press **F6**.
A pyramid should stand on the ground.

| Control | Action |
| --- | --- |
| Left click or Space | Launch a ball toward the mouse |
| Hold right mouse and drag | Orbit the camera |
| W / S or Up / Down | Move the camera in or out |
| R | Rebuild the tower |

Aim near the base and launch. Boxes fall and the HUD counts knocked-down boxes.
Press **R** to return to the initial scene.

If setup fails, inspect the native build error before the script build. To use
an existing compatible shared backend, set `BOX3D_NATIVE_LIBRARY` as described in
[Build and export](building.md).

## 2. Find the world owner

Open [scripts/tower.odin](https://github.com/wlitwin/odin_godot/blob/main/examples/box3d_offline/scripts/tower.odin).
Its script stores a `b.World`, body handles, and the corresponding mesh nodes.

```odin
import b "godot:box3d"
import gd "godot:godot"
```

Follow these procedures in that file:

| Procedure | Responsibility |
| --- | --- |
| `build_world` | Create the world, static ground, dynamic boxes, and shapes |
| `box_tower_physics_process` | Handle launches and call `b.world_step_fixed` once per physics frame |
| `sync_nodes` | Read each body's pose and copy it to its mesh node |
| `box_tower_process` | Update camera controls once per rendered frame |
| `destroy_world` | Destroy the world and clear body handles on reset or scene exit |

With the default build profile, `world_step_fixed` advances 1/60 second with four
substeps. Keep Godot's physics rate at 60 Hz for this loop. A custom
[timing profile](timing.md) changes that fixed duration and substep count; match
the callback rate or use an explicit fixed-step accumulator. Passing a frame
delta does not change `world_step_fixed`.

The mesh nodes display solver results. Moving one of them manually does not move
its physics body. Read [Physics ownership](ownership.md) before adding a second
system that changes poses.

## 3. Change the ball's density

Open the project in the editor through the same helper:

```sh
nix develop --command bash examples/box3d_offline/play.sh -e
```

In `scripts/tower.odin`, change `BALL_DENSITY` from 4000 to 250. Save, wait for
the script build to finish, and run the scene. The ball has the same radius and
launch speed but much less mass, so it transfers less momentum to the boxes.

The boxes use a density of 250 kg/m³; shapes otherwise default to 1000 kg/m³.
Density and shape volume determine mass. Restore `BALL_DENSITY` to 4000 when you
finish comparing.

Launch the editor through `play.sh` so rebuilds inherit `BOX3D_NATIVE_LIBRARY`.
Opening it from the Project Manager without that environment can leave saving
unable to link Box3D; inspect the build error if a change does not appear.

## 4. Make a browser build

```sh
nix develop --command bash examples/box3d_offline/export_web.sh
nix develop --command bash build/serve.sh examples/box3d_offline/out/web
```

Open `http://localhost:8099/`. The export writes `out/web/` and
`out/box3d-offline-web.zip` inside the example. The server supplies headers
needed by the threaded build. The example's
[README](https://github.com/wlitwin/odin_godot/blob/main/examples/box3d_offline/README.md)
has itch.io upload settings.

## Next

- [Author a world](authoring.md) to move initial collision data into the editor.
- Read [Build and export](building.md) before creating your own Box3D project.
- Use [Multiplayer integration](multiplayer.md) when a framework should own ticks and history.
