<a id="speedball--the-contested-twin"></a>

# speedball — whole-pitch prediction with Kit

Compare this game with [slopball](../slopball/) to choose a simulation policy.
Slopball hands the ball's physics simulation to the last toucher using
`play.Puppet`. Speedball keeps one authority and lets each peer predict the
ball locally. Kit's simulation lane schedules fixed ticks and retains history
for correction:

```odin
@(gd_tick = "contested")
ball_tick :: proc(self: ^Ball) -> (scored: u8) { ... }
```

The `contested` tag enables local prediction of the shared ball, so local
dribbles and kicks can respond before the server result arrives. The integration
test drives a ball to goal through 240 ms RTT using local touches. The server
settles gameplay: when accepted state disagrees with prediction, the client
applies the correction and replays its remaining predicted ticks. Display
smoothing eases the resulting position change. Each peer pays the CPU cost of
replay and may show a speculative touch that is later corrected.

Goal detection and the kickoff freeze run in the ball's predicted tick.
A peer can therefore reset the ball locally when its simulation detects a
goal. The authority accepts the score through `ball_tick_then` on the delta
lane. The world pass computes contact and kicks for the kicker⟷ball pairs
whose inputs are available to that peer.

Speedball also predicts the players (`echo_inputs`). The kickers are `contested`,
and batches echo each player's held input so every peer simulates the whole
pitch on one predicted timeline. Remote contacts therefore use predicted avatars
as well as a predicted ball. Corrections can affect any of them. The lane also
supports predicting the ball while watching delayed authority poses for remote
players, with a presentation claim selecting the ball's displayed pose; see
docs/kit/sim.md's contested section for the tradeoff.

```sh
bash build/build_scripts.sh examples/speedball
$GODOT --path examples/speedball                  # host, join from a second window
SPB_LATENCY=120 $GODOT --path examples/speedball  # observe local response at 240ms RTT

bash examples/speedball/run.sh          # solo gate (SPEEDBALL_SINGLE_OK)
bash examples/speedball/native_run.sh   # contested-ball integration test (three peers)
```

WASD move · Space kick (aim with your movement) · Tab scores · Enter chat.
Env: `SPB_ROLE` (host/join/single/serve) · `SPB_PORT` · `SPB_NAME` ·
`SPB_TOKEN` · `SPB_LATENCY` · `SPB_BOT` (striker/idle) · `SPB_GOALS`.
