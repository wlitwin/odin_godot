# Choose a multiplayer model

Three decisions shape a multiplayer game: where gameplay state lives, whose
result settles a conflict, and which moment each screen displays. Choose them
before adding a transport. A host/client role alone does not define all three.

## Choose the unit of state

| Model | Where you write gameplay | How correction is organized | Start here |
| --- | --- | --- | --- |
| Kit | Script structs, tagged entity fields, generated commands, and optional fixed ticks | Target-local command prediction and the simulation lane's historical state | [Build a Kit game](kit-game.md) |
| Replay | A typed World stepped from inputs, with Godot views outside the simulation | Complete-frame restoration and replay for the authored simulation group | [Build a Replay game](replay-game.md) |

Kit supports both cooperative owner movement and server-authoritative prediction.
Replay supports server authority, cooperative owner streams, and deterministic
peer rollback. Choose by the game's state dependencies and trust model rather
than treating the frameworks as a co-op/competitive switch.

## Choose who decides

**Invited co-op.** Players can author their own motion while the host validates
shared interactions. Kit's owner fields are a small starting point. Replay's
owner streams can record accepted Godot body observations when the game uses
live engine physics.

**Listen-server action.** The hosting player runs the authority. Clients submit
intent, predict locally, and accept corrections. This is convenient for
player-hosted sessions; the host still controls the authoritative process.

**Dedicated authority.** A process on trusted infrastructure judges the game.
Validate game-specific input, choose admission and transport policy, and plan
deployment and recovery. In Kit, the dedicated profile also requires constrained
or validated simulation inputs. In Replay, Session exposes an avatarless Server
role, with Room policies available for trusted infrastructure recovery.

**Deterministic peers.** Admitted players exchange inputs and reproduce the same
steps. Replay's P2P runner requires fixed roster identities and a simulation that
reproduces math, RNG, allocation, and input order across its target platforms.
Use the [Duel example](../../../examples/replay_duel/README.md) for that contract.

## Keep presentation separate

Local prediction responds to current input. Remote interpolation usually presents
a buffered past. Effects need to follow the frame being displayed; applying a
remote pickup effect as soon as a packet arrives can make the item vanish before
the visible player reaches it.

Godot rigid-body solving needs an explicit policy. Saving node poses does not
restore contact solving. Use a replayable query-based model or cooperative body
observations according to the game you are building.

## Test one contested interaction

Give two players one item. Let both predict taking it, delay the connection, and
make one request lose. Check the inventories, entity lifetime, and the record of presented effects.
This exposes the state and presentation boundaries before a large game makes
the failure difficult to isolate.

Continue with [Kit profiles](../../kit/profiles.md),
[Replay's runner guide](../../../replay/getting-started.md), and
[timeline choices](../../kit/timelines.md). The illustrated field guide follows
this pickup through both frameworks with diagrams and a correction lab.
