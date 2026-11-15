# Connect a Godot session

Use the Replay starter to run one game model offline or as a native host/client
pair. You will have a new project with a scene, device input, a pure gameplay
model, and a Session that owns simulation and networking.

Complete [the Replay tutorial](quickstart.md) first. The commands below run from
a repository checkout inside `nix develop`.

## 1. Copy the starter

The starter uses value-only gameplay and needs no Box3D backend. The optional
[Box3D integration](../box3d/multiplayer.md) adds its own backend setup when a
game uses complete native physics.

```sh
mkdir ../first-replay-game
cp -R build/template/replay/. ../first-replay-game/
cp examples/survivors/odin_godot.gdextension ../first-replay-game/
bash build/build_scripts.sh ../first-replay-game
"$GODOT" --editor --path ../first-replay-game
```

Wait for the initial editor import, then press **F6**. The default role is `solo`.
Arrow keys move; **Space** takes the center coin when you are close enough.
The coin disappears and the bag count changes.

The copied extension manifest connects the checkout build's core to Godot. An
installed addon already supplies its own manifest.

These instructions use a checkout. For an installed addon, copy its
`template/replay/` project and use the packaged build helpers with that addon
as `ODIN_GODOT_ROOT`. See [Distribution](../distribution.md).

## 2. Run two roles

Close the solo game. In separate terminals using the same toolchain shell:

```sh
REPLAY_STARTER_ROLE=host "$GODOT" --path ../first-replay-game
```

```sh
REPLAY_STARTER_ROLE=client "$GODOT" --path ../first-replay-game
```

Both windows should show the same players and bag counts after a pickup. An
optional third process uses `REPLAY_STARTER_ROLE=observer`.

| Setting | Default | Purpose |
| --- | --- | --- |
| `REPLAY_STARTER_ROLE` | `solo` | `solo`, `host`, `client`, or `observer` |
| `REPLAY_STARTER_PORT` | `49480` | Native ENet port |
| `REPLAY_STARTER_ADDRESS` | `127.0.0.1` | Client destination |

If the client waits, check that the host is running, both processes use the same
build and port, and the port is available. These are direct local connections;
Internet deployment needs its own reachability and admission configuration.

## 3. Find the responsibilities

| File in your project | Responsibility |
| --- | --- |
| `shared/game/game.odin` | World, initial state, controls, actions, occurrences, and step rules |
| `scripts/starter.odin` | Session lifecycle, device input, action submission, and copied frame presentation |
| `main.tscn` | Nodes that display the players, coin, and status |

In `replay_starter_ready`, the script copies `rgd.SESSION_OPTIONS`, chooses a
role, sets content identity, and calls `rgd.session_open`. Treat a failed open as
a setup error; do not enter the frame loop.

In `_process`, it samples controls, submits discrete actions, calls
`rgd.session_frame`, drains `rgd.session_changes`, and reads
`rgd.session_state` to position nodes. `_exit_tree` calls `rgd.session_close`.
The imports in this script are the complete starting point for your own code.

## Change the game

Change a gameplay predicate in `shared/game/game.odin`, rebuild, and run both
roles from the same build. Keep scene effects and device access in the script.
When adding sound, map occurrence changes to effects using
[the presentation guide](presentation.md).

## Next

Use [Networking](networking.md) to choose prediction and transport policies.
Add [Party and Room](recovery.md) when you need invitations, rejoin, or coordinated
authority recovery. A direct Session is sufficient for this starter.
