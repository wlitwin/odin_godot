# Example projects

Choose an example for the next behavior you want to build. Start with a small
project in your chosen framework before reading a complete game. Commands below
run from the repository root inside `nix develop`.

## Play a game first

Try a complete game before opening its source, then choose one feature to trace
through input, gameplay state, and presentation.

| Game | Play in the browser | What to study next |
| --- | --- | --- |
| `examples/replay_dockyard` | [Dockyard on itch.io](https://itchyitches.itch.io/dockyard) | Shared cargo, cooperative hauling, and [physics simulation](../box3d/concepts/simulation-and-rollback.md) |
| Parallax | [Parallax on itch.io](https://itchyitches.itch.io/parallax) | First-person aim, reversible target feedback and historical hit validation |
| Second Helping | [Second Helping on itch.io](https://itchyitches.itch.io/second-helping) | Boomerang turns, moving obstacles and shared hit presentation |
| Standalone Kit Scrapyard | [Scrapyard on itch.io](https://itchyitches.itch.io/scrapyard) | Compare combat and pickups with the Replay port’s [feature walkthroughs](../multiplayer/recipes/index.md) |

The [multiplayer concepts](../multiplayer/concepts/index.md) explain the design
problems behind those features. Use the smaller projects below to learn each
part before navigating a full game.

## Learn in steps

| Step | Project | What to learn | Run or read |
| --- | --- | --- | --- |
| 1 | First Odin scene | Script state, lifecycle, Inspector properties, compilation | [Create it from scratch](../scripting/first-scene.md) |
| 2 | `examples/survivors` | Input, scenes, signals, resources, a complete game loop | [README](https://github.com/wlitwin/odin_godot/blob/main/examples/survivors/README.md) |
| 3a | `examples/hello_net` | Kit sessions, spawned entities, owner-streamed movement | [Kit tutorial](../kit/quickstart.md) |
| 3b | `examples/hello_sim` | Kit authority, fixed ticks, input prediction, reconciliation | [Simulation tutorial](../kit/quickstart-sim.md) |
| 3c | `examples/replay_loot` | Complete state and corrected input without Godot | [Replay tutorial](../replay/quickstart.md) |
| 3d | `build/template/replay` | Replay Session, devices, Godot presentation, direct host/client | [Session tutorial](../replay/godot.md) |
| 4 | `examples/box3d_starter` | Editor-authored physics, automatic visual bindings and checked cleanup | [Box3D tutorial](../box3d/quickstart.md) |
| 5 | `examples/kit_box3d_authoring`, `examples/replay_box3d_authoring` | Shared authored collision with separate framework owners | [Sample preparation](../box3d/multiplayer.md) |

Steps 3a–3d are choices, rather than prerequisites for one another. Box3D can also
follow directly after the scripting tutorial.

## Run a standard project

For projects that use the ordinary scripts layout:

```sh
bash build/build_scripts.sh examples/survivors
"$GODOT" --editor --path examples/survivors
```

Let the initial editor import finish, then press **F6** to run. Substitute `examples/hello_net` or `examples/hello_sim` for the small Kit projects.
The Replay and Box3D tutorials use their specific helpers because they prepare
additional content or native libraries.

## Study a complete game

| Project | Framework | Useful next topic |
| --- | --- | --- |
| `examples/slopball`, `examples/slopball3d` | Kit | Cooperative Godot body replication |
| `examples/cavecrawl` | Kit | Items, interactions, reconnect, saves, and a larger session |
| `examples/quickdraw` | Kit simulation | Authoritative hitscan and lag compensation |
| `examples/speedball` | Kit simulation | Predicting shared ball motion |
| `examples/replay_hello` | Replay | Copied views and occurrence cancellation |
| `examples/replay_cavecrawl` | Replay | Party, Room, recovery, and authored content |
| `examples/replay_scrapyard` | Replay | Feature work across content, World, actions, and presentation |
| `examples/replay_dockyard` | Replay and Box3D | Shared physics, hauling, and game state separated from Godot presentation |
| `examples/replay_duel` | Replay P2P | Deterministic fixed-roster input exchange |

The [Scrapyard contributor guide](https://github.com/wlitwin/odin_godot/blob/main/examples/replay_scrapyard/contributor-guide.md)
traces a feature through its files. Its
[code guide](https://github.com/wlitwin/odin_godot/blob/main/examples/replay_scrapyard/code-guide.md)
maps responsibilities for larger changes.

## Choose a Replay presentation example

| Example | What drives its visible world |
| --- | --- |
| Replay starter and Hello | The starter samples the Session once and previews a local pickup. Hello demonstrates the lower-level network runner, including interpolation between received frames for spectators. |
| Cavecrawl and Cavecrawl Owned | Characters, enemies and rocks share a contact timeline. Rock launches and impacts identify pool slots and lifetimes. Local owner physics still supplies the owned variant’s action origins. |
| Quickdraw | Gunners, drones and lob flights share one sample. The muzzle responds locally. Hitscan judges the displayed target bracket and lobs show their accepted landing point. |
| Replay Scrapyard | Runners, enemies, shots, ability lobs and turrets share a render sample. Muzzle and input cues can anticipate the result. Damage notices may aggregate multiple hits in a tick. |
| Speedball and Claimball | Speedball demonstrates whole-pitch prediction with an interpolated observer. Claimball deliberately demonstrates a smaller prediction group and a local ball claim that blends back to the watched ball. |
| Slopball and Slopball3D | Local owners run the engine body. Other participants interpolate the authoritative poses with ownership, revision and handoff checks. |
| Dockyard Duo, Replay Box3D and Box3D Authoring | The actors and cargo come from one complete physics checkpoint. Dockyard smooths a remote robot’s visible correction. A value-only snapshot cannot supply native body poses. |
| Replay Duel | Deterministic peers draw both fighters and projectiles from the same predicted P2P frame. |
| Loot, Recipes, Duel Service and Room Service | Loot demonstrates engine-free resimulation. Recipes demonstrate integration. The two services have no rendered game world. |
| Parallax | The FPS camera responds to local movement. Remote hitboxes use the exact quantized bracket consumed by rewind. Life changes cut interpolation, and score changes take effect on their displayed tick. |
| Second Helping | All fruit, moving lids and boomerangs share a contact view. Local wind-up and aim respond immediately. |

The public Scrapyard page runs the standalone Kit game. The Replay port is the
source example in this repository. See the [Replay presentation guide](../replay/presentation.md)
for the APIs used by these examples.

## Engine interop examples

`examples/hello` hand-registers a GDExtension class. `examples/coop_arena` uses
Godot's native multiplayer APIs. `tests/showcase` combines basic scripting
features in a coin collector. These help with bridge internals or interop;
begin with the framework tutorials when building a new multiplayer game.
