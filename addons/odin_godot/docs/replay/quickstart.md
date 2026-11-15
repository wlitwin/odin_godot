# Correct an inventory transfer

Run a small Replay simulation in which two players contest a chest. Change the
winner after eight ticks and inspect how Replay restores both inventories,
the chest, and projectile lifetime together. This tutorial starts without Godot
so you can see the simulation boundary directly.

You need the repository checkout and Nix shell from
[the scripting tutorial](../scripting/first-scene.md).

## 1. Run the local model

From the repository root:

```sh
nix develop --command bash examples/replay_loot/run.sh
```

The final output is:

```text
REPLAY_LOOT predicted=5,0 corrected=0,5 replayed=8 checkpoint_tick=4
REPLAY_LOOT_OK
```

Player one initially receives five items. After correction, player two has them.
The example also checks that the result matches a fresh run supplied with the
correct input from the beginning.

## 2. Find all the state that must return

Open [game/game.odin](https://github.com/wlitwin/odin_godot/blob/main/examples/replay_loot/game/game.odin).
The model's World is:

```odin
import r "godot:replay"

World :: struct {
    players:  [2]Player,
    entities: r.Pool(Entity, 16),
    chest:    r.Handle(Entity),
    rng:      r.Rng,
}
```

This is an excerpt; `Player` and `Entity` are defined in the linked file. The
entity pool includes membership and generation state. Keeping it inside World
lets a replay restore a removed chest and reuse handles consistently. RNG is
also part of World because it changes projectile lifetime.

Godot nodes, audio players, sockets, and system time stay outside this value.

## 3. Follow the timeline lifecycle

Open [main.odin](https://github.com/wlitwin/odin_godot/blob/main/examples/replay_loot/main.odin).
It creates one owner, initializes it with a starting frame, and destroys it at
the end:

```odin
local: loot.Timeline
assert(r.init(&local, r.Frame(loot.World){state = loot.initial()}, loot.step) == .None)
defer r.destroy(&local)
```

Each `r.advance` records a new input and frame. The eight input batches initially
give the chest to player one. The correction changes that first input:

```odin
inputs[0].players[0].take = false
inputs[0].players[1] = {
    take = true,
    seq  = 1,
}
revision := r.revise_input(&local, 1, inputs[0])
assert(revision.error == .None && revision.steps == 8)
```

Replay restores the predecessor of tick one and stages all eight replacement
ticks before publishing. Chest membership, inventories, pool metadata, RNG,
and occurrence history follow the same replay.

## 4. Change the interaction

In `game/game.odin`, change the initial chest's `items = 5` to `items = 9`.
In `main.odin`, change the two assertions that expect a bag of five to expect
nine. Run the command again. The final line should now contain
`predicted=9,0 corrected=0,9` and still end with `REPLAY_LOOT_OK`.

The transfer rule needs no separate correction handler: both normal execution
and replay run the same step procedure. Restore the value and assertions when
you finish exploring.

## 5. See the same model in Godot

First configure the native backend as described in
[the Godot Session setup](godot.md). The current Godot example package imports
that adapter even for the Loot scene. Open the editor for its initial import:

```sh
bash build/build_scripts.sh examples/replay_hello
"$GODOT" --editor --path examples/replay_hello res://loot.tscn
```

Run the scene, then press **Space** to revise the pickup winner. The view updates to the corrected
world. Presentation handles occurrences outside the step, so it can cancel or
replace effects whose predicted result changed.

Local `revise_input` demonstrates history restoration. Network games obtain
accepted input and state from their selected authority or peer protocol;
changing a local input does not grant network authority.

## Next

- [Connect a Godot session](godot.md) to build a small solo and host/client game.
- Read [World and history](architecture.md) before designing your own World.
- Use [Presentation](presentation.md) when adding effects.
