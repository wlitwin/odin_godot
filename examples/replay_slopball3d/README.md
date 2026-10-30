# Replay Slopball3D

A separate initial port of [Slopball3D](../slopball3d/README.md), preserving its original
project. The new version uses Replay owner observations, real CharacterBody3D kickers
and a RigidBody3D ball with gravity, loft and tumble. Reused pitch, camera, materials
and body scenes have [asset provenance](assets.md).

```sh
nix develop --command bash examples/replay_slopball3d/play.sh
RS3_ROLE=host nix develop --command bash examples/replay_slopball3d/play.sh
RS3_ROLE=client nix develop --command bash examples/replay_slopball3d/play.sh
RS3_ROLE=observer nix develop --command bash examples/replay_slopball3d/play.sh

nix develop --command bash examples/replay_slopball3d/run.sh
nix develop --command bash examples/replay_slopball3d/network_run.sh
RS3_JITTER=20 RS3_LOSS=1000 RS3_DUPLICATE=1000 nix develop --command bash examples/replay_slopball3d/network_run.sh
nix develop --command bash tests/replay_owned3_godot/run.sh
nix develop --command bash examples/replay_slopball3d/migration_run.sh
```

The default opens the [session menu](session-ui.md), port 49580. A configured Room
service adds [Party invitations and browser play](online.md). Explicit
role settings retain automatic launches. WASD moves on XZ; Space kicks with loft. Network
roles run in separate processes. `RS3_BOT=striker`, `chaser` or `idle` drives the same
physics path. The network gate uses host + client striker + observer and 120 ms
receive delay per process, requiring ownership transfer, one goal per screen,
vertical motion, tumble and settled convergence within 10 cm near tick 600.

The game reducer records accepted observations, ownership and scoring without engine
calls. Body3 handles solver preparation/seeding, frozen observers, quaternion-aware
view interpolation and skin smoothing. The moving/spinning handoff probe checks all
velocity components and orientation. Planned/crash Room gates compare the exact
approved checkpoint, validate the new solver seed, require new kicks and a goal for
the successor's team, and compare surviving clients at a common tick. The old host
rejoins in planned mode.

The first implementation had a material-reference ownership error at shutdown.
Raw RefCounted materials now receive an explicit owned reference before assignment
and local release. Subsequent solo/network/probe/migration runs exit cleanly.

This is initial coverage, not full game parity. Native lobby, profiles, chat,
scoreboard and leave/rejoin now have acceptance. Netgraph UI, broader multi-goal
contests, preview denial/
timeout, broader reconnect/recovery and human feel review remain pending. Ownership intent now uses accepted ground-plane displacement at arbitration
passes, matching the original measure and threshold. Handoff still uses
prepare/commit rather than immediate SETOWNER. Solver contacts/joints
are not serialized or replayed. Broader browser deployment and independent platform testing
remain open. See [Body3](../../replay/godot/body3.md) and the [roadmap](../../docs/replay/roadmap.md).

The UI's world/action changes use content D4 (`0x52534c4f50334434`), intentionally
incompatible with D1/D2/D3. The shared coordinator reads this model constant. See the
[UI receipts](../../docs/replay/results/slopball3d-ui-2026-09-14/README.md) for native
model/profile/render checks and the preserved physics/migration gates.

See [measured ownership intent](../../docs/replay/results/slopball-measured-intent-2026-09-14/README.md)
for blocked/sparse/discontinuous observations, replayable baselines and retained
network/migration receipts.

Native Save/F5 and fresh-process Resume solo/host are described in the
[session guide](session-ui.md#native-checkpoint-saves). The checkpoint and first
solver seed are verified separately, including pose/momentum, retained seat/name,
continued goals and successful replacement. See [the receipts](../../docs/replay/results/slopball-native-save-2026-09-14/README.md).

The optional striker fixture bot uses a reachable side stance when its usual
behind-ball target is blocked by a boundary. This does not change human input,
kick impulses, collision settings or the replicated game model.

Published progress also supports [whole-party recovery](online.md#reopening-a-saved-party),
including restoration by another trusted member before the creator returns.
