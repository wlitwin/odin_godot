# Replay Claimball

Run this [Claimball](../claimball/README.md) port to predict only the local
avatar and shared ball before the authority settles their state. Replay
Speedball instead predicts the complete pitch. Other active avatars are removed
from the prediction group; the
authority continues to simulate everyone. Original Claimball/Speedball/Slopball
remain runnable in their original directories.

```sh
nix develop --command bash examples/replay_claimball/play.sh
nix develop --command bash tests/replay_claimball/run.sh
nix develop --command bash examples/replay_claimball/run.sh
nix develop --command bash examples/replay_claimball/network_run.sh
nix develop --command bash examples/replay_claimball/compete_run.sh
nix develop --command bash examples/replay_claimball/fault_run.sh
nix develop --command bash examples/replay_claimball/stall_run.sh
```

The default opens a [session menu](session-ui.md) with Solo, Host, Join and Watch.
For automatic separate windows, set `RCB_ROLE=host` and
`RCB_ROLE=client`; `server` and `observer` also work. Port defaults to 49490.
`RCB_PLAYERS` is the start threshold, `RCB_GOALS` the winning score, and
`RCB_TOKEN` a deterministic test identity label. Normal native menu play persists
its identity and name in a separate profile. Launchers use localhost. WASD moves,
Space kicks, and E spikes.
`RCB_BOT=striker` drives a match; `idle` watches; `spiker` retains the optional
two-command scenario. Fault controls are `RCB_LATENCY`/`RCB_JITTER` in milliseconds
and `RCB_LOSS`/`RCB_DUPLICATE` in ten-thousandths. Native macOS is tested; the WASM
fixture is a type-check, not browser multiplayer acceptance.

<a id="the-group-and-the-claim"></a>

## Prediction groups and ball presentation claims

[`shared/pitch`](shared/pitch/types.odin) declares a `Prediction_Group`, the subset
of world state a client simulates speculatively. Projection builds that subset
from an authority frame: it retains the local player/ball and records timestamped
remote players (outsiders) separately. Its validator rejects reintroduced remote simulation members. The ordinary gameplay
step iterates the group's connected players. Outside avatars do not produce
predicted contacts, matching the original's predict-self policy; remote touches
arrive through authoritative correction. See the [group contract](../../replay/net/groups.md).

Presentation draws remote players from observed authority frames. When the
local player influences the ball within 38 pixels, the display begins using
that player's predicted ball pose, called a claim. The claim stays active through fast flight, including
when the ball leaves reach. Once untouched and below 0.6 units/tick, it fades back
to observed presentation over 0.25 seconds. A fast ball that this player never
influenced does not create a claim. Claim state is presentation-only.

A claimed predicted goal reset stays on the predicted timeline until the observed
reset catches up, then releases. This explicit reset latch prevents blending a
new kickoff back toward the old goal position. It is an intentional clarification
of the original's claim/reset behavior. Score/winner presentation remains
authoritative, while the complete score and reset state participate in replay.

<a id="what-is-preserved-and-what-is-pending"></a>

## Ported behavior and validation limits

Pitch geometry, movement/momentum, kick cadence/reach/power, dribble contact,
rolling friction/cap/bounce, goals, kickoff hold, team/spawn correspondence, claim
reach and release thresholds are ported. Geometry provenance is in [assets.md](assets.md).
The common rules were copied from the new Speedball port into this separate
project, so each game remains independently buildable.

As in Replay Speedball, spikes carry intent and use the issuing seat's current
world position rather than supplied coordinates; two queued commands run on
successive ticks. The HUD/team tint are initial replacements. Native session menus, names, chat,
scoreboard, leave/rejoin, Play again and native save/resume now have automated
acceptance. Initial native Room handoff/crash migration is tested. Party menus
and browser RTC handoff/crash paths are tested locally. Steam,
broader contested scenarios and human visual review remain pending. This is an
initial M6 slice, not full parity or a paired performance comparison.

The four-process gate runs authority, striker, idle player and true observer at
240 ms gameplay RTT. It checks one predicted avatar per player, local speculative
kicks, matching score/reset, five-authority-kick agreement in the recorded match,
claim retention during fast distant flight, and actual Godot-node agreement with
the selected predicted/observed pose. The idle player's underlying ball prediction
can still receive large corrections; those are hidden by its observed presentation.
`RCB_GROUP` and `RCB_METRICS` expose both facts. The original gate uses an idle
opponent. `compete_run.sh` adds a second active striker, stops bot controls at tick
1800, lets the ball settle, and checks agreement/effect reconciliation. It need not
finish a match; winning three goals is not its time limit. `fault_run.sh` adds
0–20 ms receive jitter, 10% unreliable-packet loss and 10% duplication, with seed
42 per adapter. Reliable application traffic stays ordered and delivered; this
does not model ENet's lower-level retransmission/congestion loop. The gate requires
observed drops/duplicates and both players' authoritative kicks, claims and views.

`RCB_CONTEST` counts remote kick effects presented while a local claim was active.
This demonstrates overlapping interactions, not proof that a claim was obsolete:
the local player may already have made a newer predicted touch. Claims still
release under the authored proximity/speed/reset policy. The tests do not establish
subjective quality during takeovers. `RCB_PROFILE` reports replay wall time and
conservative histogram percentile bounds.

`stall_run.sh` pauses the idle client's main thread for 800 ms while the match
continues. It requires an ahead-snapshot catch-up, no full resync, and preservation
of all kick effects and final gameplay state. This covers a short local stall,
not a blackout longer than the retained history. `RCB_RESYNC` prints reasons and
tick frontiers if a full resync becomes necessary.

The [native UI receipts](../../docs/replay/results/claimball-ui-2026-09-13/README.md)
retain an intermittent fault failure: the observer resynchronized and missed four
kick presentations, despite converged final state. Later instrumented runs do not
establish its cause or resolve that failure.
The [same-epoch resync fix](../../docs/replay/results/resync-effects-2026-09-19/README.md)
separately proves and fixes loss of already confirmed effects when Welcome replaced
the journal. A faulted checkpoint-refresh run preserves all eleven kicks, and
old/current native plus WASM trace comparisons isolate the lost output. The cause
of the older Facts_Overflow remains unestablished.

Play again is a round-scoped command in the current session. It retains identities
and chat while resetting match state. Content C3 includes the round and event
scope; C1/C2 peers and archives remain explicitly incompatible. See the
[session guide](session-ui.md#play-again) for behavior and reproduction.

Native authority saves and fresh-process solo/host resume are described in the
[session guide](session-ui.md#native-match-saves). The default checkpoint path is
`user://claimball.replay`, configurable with `RCB_SAVE`; the matching host profile
is required to resume. `tests/replay_claimball_save/run.sh` verifies exact moving
state, ownership/error handling, rejoin, continued commands and match restart.

Native coordinator-driven handoff and crash recovery have a separate
[migration guide](migration.md). A successor restores the complete authority world
while clients continue to predict one avatar. The shared package is named
`claimball_pitch` to coexist with Speedball's `pitch` in service programs; its import
path and verified C3 wire/save contracts remain unchanged.

[Party menus and browser play](online.md) use the shared provisioned Room adapters.
Configure `RCB_ROOM_SERVICE` (browser query `room_service`) to create or join an
invited party. Native/browser profiles remain separate from Party credentials;
observers keep seat zero and do not receive succession checkpoints. The service
can persist complete C3 checkpoints, with publication before and after browser
migration independently decoded. Local test success does not establish a deployed
public service or resolve the retained first-run browser fencing failure.
