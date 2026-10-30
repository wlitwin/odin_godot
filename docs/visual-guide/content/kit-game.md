# Build a game with Kit

Kit registers game objects as entities: script structs with a network identity.
Their fields declare which machine
writes each value and how it is synchronized. Commands express a player action
that the authority can accept or reject. Use this path when the game's natural
authoring unit is a Godot script entity.

## Run the smallest game

From the repository root, enter the development shell and build Hello Net:

```sh
nix develop
bash build/build_scripts.sh examples/hello_net
"$GODOT" --path examples/hello_net
```

Choose Host. In a second terminal with the same environment, launch another copy
and choose Join. Arrow keys move the local player's square.

```sh
HELLO_LATENCY=120 "$GODOT" --path examples/hello_net
```

The delay makes the two presentation clocks visible: local movement responds
immediately, while a remote square is interpolated from buffered observations.

## Declare the writers

The Hello Net player has owner-streamed coordinates and an authority-written seat:

```odin
x, y: f32 `gd:"owner,wire=f16"`,
pid:  u8  `gd:"replicate"`,
```

Untagged fields remain local. The scene factory and network registry track entity
identity, creation, ownership, and removal. Follow the
[Kit quickstart](../../kit/quickstart.md) for the complete entity declaration,
session setup, frame pump, and teardown.

## Add a shared interaction

Write a command that validates and mutates its target. Local prediction can run
that target mutation before the host's verdict. Keep cross-entity consequences
in the authority command hook: a chest command removes loot from the chest;
the accepted consequence credits the player's inventory.

The [command guide](../../onboarding/04-verbs-not-rpcs.md) explains submission,
rejection, and the target-local mutation rule. Start with a range check and one
item before adding an inventory, quest reward, or ownership transfer.

## Move fast state to authority when needed

Hello Sim runs the square through Kit's simulation lane, which advances
authoritative state at fixed ticks and replays local input after a correction.
Predicted fields use
`gd:"predict,interp"`; a pure `@(gd_tick)` procedure advances them from typed input.
The authority runs the same tick and supplies corrections.

Work through the [simulation quickstart](../../kit/quickstart-sim.md), then select
the [network profile](../../kit/profiles.md) that matches invited co-op, a listen
server, or a trusted dedicated process. For contested objects, use the
[timeline guide](../../kit/timelines.md) to choose prediction and presentation.

## Grow the game

[Cavecrawl](../../../examples/cavecrawl/README.md) combines interactions, inventory,
AI, progression, and recovery. The [Kit package overview](../../kit/index.md)
maps those systems to their imports. Keep the smallest example's frame and
shutdown lifecycle working as new systems are added.
