# Build a game with Replay

Replay organizes gameplay around a complete typed World. The runner retains
frames and input, restores a prior frame when necessary, and steps the changed
suffix again. Godot owns input devices, scenes, animation, and effects outside
that world. Replay is experimental; consult the support and runner contracts
for the configuration you intend to ship.

## Run the engine-free model

Start with Loot, a small Odin executable that changes the winner of a pickup:

```sh
nix develop --command bash examples/replay_loot/run.sh
```

The model predicts one inventory transfer, revises the input at tick 1, rebuilds
eight ticks, and compares the result with an independent run. The same operation
restores the chest, both inventories, entity lifetime, pool metadata, and RNG.

Read [the complete model](../../../examples/replay_loot/game/game.odin) and
[its timeline lifecycle](../../../examples/replay_loot/main.odin). A local input
revision demonstrates restoration; network authority is established by the
network runner and session policy.

## Choose the runtime owner

| Need | Owner | Small reference |
| --- | --- | --- |
| Local replayable simulation | `Timeline` | Loot |
| Godot game with direct offline, host, server, client, or observer roles | `Session` | [Session starter](../../../build/template/replay/README.md) |
| Invitations, enrollment, rejoin, and elected authority recovery | `Party` and `Room` | [Replay Cavecrawl](../../../examples/replay_cavecrawl/README.md) |
| Deterministic fixed-roster peer rollback | Admitted P2P setup and `p2p.Runner` | [Duel](../../../examples/replay_duel/README.md) |

Pump the owner you chose. Room drives its Session; a direct Session drives its
clock, transport, and runner. Keep live runtime owners at stable addresses and
close dependent objects before their borrowed resources.

## Put gameplay dependencies in World

Include every mutable value needed for the next tick: positions, health,
inventories, cooldowns, scheduled work, RNG, entity membership, and allocation
metadata. Use supported value types and handles. Keep node references, sockets,
audio playback, and persistent storage outside the frame.

A step reads the world, typed input, simulation tick, and fixed versioned
definitions. Read devices before stepping. Record semantic occurrences during
the step and reconcile their Begin, Update, Confirm, and Cancel changes in
presentation. The [frame contract](../../replay/architecture.md) describes
transaction boundaries and history limits.

## Connect Godot

The [Session starter](../../../build/template/replay/README.md) contains an offline
and native host/client game. Edit `shared/game/game.odin` for rules and
`scripts/starter.odin` for input and presentation. Use its documented role
environment variables to start separate local host and client processes.

The [checked lifecycle recipes](../../../examples/replay_recipes/README.md)
instantiate Session, Party → Room, and P2P setup against the public API. Hello's
network scene shows the lower-level runner integration when you need custom
orchestration. Follow [starting a Replay game](../../../replay/getting-started.md)
for the full choice of owners and imports.

## Author a larger game

The [Scrapyard contributor guide](../../../examples/replay_scrapyard/contributor-guide.md)
follows a shared turret from authored Resources through World, actions, and
scene views. Use its workbench to change one feature in isolation. The
[code guide](../../../examples/replay_scrapyard/code-guide.md) maps responsibilities
to files; the [support envelope](../../../replay/support.md) records the limits
of tested configurations.
