# Replay loot: the first local-world experiment

Run from the repository root:

```sh
nix develop --command bash examples/replay_loot/run.sh
```

This is a standalone Odin executable; Godot, sockets, and generated scripts are
not involved. It exercises the new [Replay library](../../replay/README.md).
Existing games remain available in their original directories.

Two players stand beside a chest with five items. The initial input says player
one takes it. After eight ticks, a revised input says player two took it instead.
Replay restores the whole world and rebuilds those ticks. Both inventories,
the chest's destruction, projectile lifetime/allocation, RNG, and occurrence
history are managed by that same operation. An occurrence is a recorded event
with an identity that lets presentation match it across replay.

The executable verifies the corrected result against an independent run that
received the correct input from the start. It also copies the frame at tick four
and continues in a fresh timeline under a new event epoch. This is an in-process
checkpoint test, **not a host migration demo**.

Expected final receipts:

```text
REPLAY_LOOT predicted=5,0 corrected=0,5 replayed=8 checkpoint_tick=4
REPLAY_LOOT_OK
```

- [game/game.odin](game/game.odin): the complete gameplay model, shared by the demo
  and property/behavior tests.
- [main.odin](main.odin): local timeline, input correction, reference run, resume.
- [../../tests/replay/replay_test.odin](../../tests/replay/replay_test.odin): failure
  atomicity, history limits, event replacement, handle lifetime, type constraints,
  and reproducibility tests.

The [Godot loot view](../replay_hello/README.md) now uses this same model and tests
effect cancellation while correcting the winner.
The complete port and comparison sequence is in the [roadmap](../../docs/replay/roadmap.md).
