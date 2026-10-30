# Scrapyard startup scheduling corpus

```sh
nix develop --command bash tests/replay_scrapyard_startup/run.sh
```

Ninety-six deterministic schedules use Scrapyard's actual model, profile/ready/
start actions, canonical snapshots, prediction, event journal, AI and forty
ordinary development spawn actions. A two-endpoint memory transport adds seven
ticks of one-way delay and zero to three ticks of jitter. Schedules vary client
join alignment, individual skipped client frames and bounded 40–72 tick stalls
in later cases. Both worlds must end with forty enemies, and the client must see
exactly one confirmed start plus two confirmed player entries without duplication.

The first thirty-two schedules must have no resync. Later stall cases allow at
most one explicit prediction-limit resync and must still converge with all three
transition effects exactly once. The actual recovery notice is printed. This is
a deterministic channel/service model, not an ENet, Godot rendering, wall-time or
performance comparison. It supplements the real swarm gate.

The focused journal-ring regression lives in
[`tests/replay_net/catchup_watch_test.odin`](../replay_net/catchup_watch_test.odin).
A valid high prediction lead and receive budget let one pump consume a long
stalled interval. Old watched events must mature in order before new prediction
reuses their ring slots. Increasing journal capacity is not part of that fix.
