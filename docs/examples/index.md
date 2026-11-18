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
| `examples/replay_scrapyard` | [Scrapyard on itch.io](https://itchyitches.itch.io/scrapyard) | Combat, pickups, and [feature walkthroughs](../multiplayer/recipes/index.md) |

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

## Engine interop examples

`examples/hello` hand-registers a GDExtension class. `examples/coop_arena` uses
Godot's native multiplayer APIs. `tests/showcase` combines basic scripting
features in a coin collector. These help with bridge internals or interop;
begin with the framework tutorials when building a new multiplayer game.
