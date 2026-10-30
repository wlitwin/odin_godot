# Replay Slopball

Run this [Slopball](../slopball/README.md) port to use Godot physics with Replay.
Kickers use CharacterBody2D nodes and the ball uses a RigidBody2D. The entity owner
is the player permitted to submit that body's pose and momentum observations. Kit and all original
projects remain intact. Reused scenes and modifications are recorded in [assets](assets.md).

```sh
nix develop --command bash examples/replay_slopball/play.sh
RSL_ROLE=host nix develop --command bash examples/replay_slopball/play.sh
RSL_ROLE=client nix develop --command bash examples/replay_slopball/play.sh
RSL_ROLE=observer nix develop --command bash examples/replay_slopball/play.sh

nix develop --command bash examples/replay_slopball/run.sh
nix develop --command bash examples/replay_slopball/network_run.sh
RSL_JITTER=20 RSL_LOSS=1000 RSL_DUPLICATE=1000 nix develop --command bash examples/replay_slopball/network_run.sh
nix develop --command bash tests/replay_owned_godot/run.sh
nix develop --command bash examples/replay_slopball/migration_run.sh
```

The default opens the [session menu](session-ui.md). Configure a Room service for
[Party invitations, browser play and recovery](online.md). Explicit role settings
retain automatic launches. Start network roles in separate terminals; the default
port is 49570. WASD moves and Space kicks. `RSL_BOT=striker`, `chaser` or `idle` drives
the same physics path for tests. The network gate uses host + client striker +
observer and 120 ms receive delay per peer. The original game uses separate ports,
scripts and project state.

Player samples and ball samples use Replay's negotiated latest-observation policy.
The authority coalesces them into the next gameplay tick, validates sender/ownership
scope and records accepted values. The game reducer contains joins/leaves, ownership
arbitration, score and kickoff decisions; it never calls Godot. Owner scopes, pending
offers, sample frontiers and full pose/momentum are part of the saved world.

The shared Body2 adapter connects a Godot physics body to these recorded
observations. The local solver prepares an authority-issued handoff before its first valid sample
commits the reserved revision. The old revision then loses admission. Local possession
preview, authoritative reseeding, observer freezing and skin smoothing are handled
by that adapter. Goals use a persistent confirmed event policy, including
after Welcome/resync/recovery journal reconstruction. The initial 2D solo, normal
three-process and jitter/loss/duplication gates pass with one goal occurrence per
screen. The separate solver probe checks nonzero linear/angular velocity at handoff.

This is initial gameplay coverage, not full parity. Ownership intent now uses accepted displacement at arbitration passes, matching
the original measure and threshold.
Ownership uses a prepare/commit protocol rather than an immediate SETOWNER. Native
lobby, names, chat, scoreboard and leave/rejoin now have acceptance. Netgraph UX, dedicated-server parity,
multi-goal/reconnect scenarios, broader migration timing, moving contests, precise common-tick view
comparisons and human feel review remain pending. The fault gate compares settled
positions near tick 600 within four pixels; it does not prove arbitrary dynamic
same-tick visual agreement. The separate [3D port](../replay_slopball3d/README.md)
now has initial solver, network and migration coverage.

The Room migration gate now runs a coordinator, host, trusted successor and guest.
It starts a moving-ball handoff or kills the host, compares the exact approved
checkpoint with the installed world, validates the new solver's momentum seed,
continues with new successor kicks and a goal for its team, and compares surviving
clients with the authority at a common tick. Planned mode also rejoins the old host.
This checks pose/velocity recovery; Godot solver contact caches are not restored.
The separate native game test verifies that old-epoch body samples cannot overwrite
the recovered value and that fresh scoped samples can resume it.

See [owner streams](../../docs/replay/owner-streams.md) and the [roadmap](../../docs/replay/roadmap.md).

The UI world/action schema uses content B24 (`0x52534c4f50423234`), intentionally
incompatible with B21/B22/B23. Names/start commands do not drive the Godot solver; Body2
still gates and seeds it from authority observations. See [UI receipts and limits](../../docs/replay/results/slopball-ui-2026-09-13/README.md).

See [measured ownership intent](../../docs/replay/results/slopball-measured-intent-2026-09-14/README.md)
for blocked/sparse/discontinuous observations, replayable baselines and retained
network/migration receipts.

Native Save/F5 and fresh-process Resume solo/host are described in the
[session guide](session-ui.md#native-checkpoint-saves). The checkpoint and first
solver seed are verified separately, including pose/momentum, retained seat/name,
continued goals and successful replacement. See [the receipts](../../docs/replay/results/slopball-native-save-2026-09-14/README.md).

Published Party progress can also survive loss of every game process and the
service; see [reopening a saved party](online.md#reopening-a-saved-party).
