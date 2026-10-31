# Replay starter

This is a separate optional starter for the experimental `godot:replay` library.
It does not replace the addon's ordinary Hello template or the Kit framework.
Copy this directory's contents into a **new** project root containing the installed
`addons/odin_godot` folder. The project includes its scene and pure gameplay model.

Build with the packaged helpers:

```sh
ODIN_GODOT_ROOT="$PWD/addons/odin_godot" SKIP_CORE=1 \
bash addons/odin_godot/build/build_scripts.sh .
```

Open the project in Godot and run `main.tscn`. Arrows move; Space takes the center
coin when close enough. The coin and both bags belong to one World, the value
that holds mutable simulation state. A step transfers the coin atomically.
The same model runs offline or with a server:

```sh
# Separate terminals, native ENet on the same machine:
REPLAY_STARTER_ROLE=host godot --path .
REPLAY_STARTER_ROLE=client godot --path .
REPLAY_STARTER_ROLE=observer godot --path .
```

`godot` above is your Godot executable. Default role is `solo`, port 49480 and
address `127.0.0.1`; override `REPLAY_STARTER_PORT` / `REPLAY_STARTER_ADDRESS` for
other native setups. These commands are a local networking example, not a public
matchmaking/NAT solution. Browser exports run the default offline model; networked
browser deployment requires an RTC/Party configuration supplied by your game.

Edit `shared/game/game.odin` for simulation rules. It has no Godot objects or I/O.
`scripts/starter.odin` owns Session, samples input, and displays frames: retained
copies of the World at individual ticks. Keep scene effects outside the simulation.
The starter consumes occurrence notifications without playing irreversible effects.
When adding effects, use occurrence IDs to revise or cancel them if prediction changes.

Build artifacts and generated scripts remain in your project, not in the addon.
The installed `addons/odin_godot/docs/replay.md` guide describes the model,
supported configurations and more advanced components. The project is intentionally
small; it does not claim host migration, persistence or competitive rollback merely
because those library packages are present.
