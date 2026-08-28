# speedball — the contested twin

This is the same game as [slopball](../slopball/) implemented on the simulation
lane; read them side by side to compare the models. Slopball hands the ball's
simulation seat to the last toucher using `play.Puppet`. Speedball keeps one
authority and lets every peer
predict the ball**:

```odin
@(gd_tick = "contested")
ball_tick :: proc(self: ^Ball) -> (scored: u8) { ... }
```

That one config token is the **predict-the-contested-object** pattern (the
Rocket League middle path): local dribbles and kicks resolve immediately. The
integration test drives a ball to goal through 240 ms RTT using local touches.
The server's
simulation stays the only truth; when an opponent you render in the past
touches it first, the reconcile snaps your ball and the glide hides the
loss. Costs, paid honestly: resim CPU on every peer, and that mispredict.

Also showcased: the GOAL RESET is predicted (detection + kickoff freeze live
in the ball's own tick — every screen snaps the ball home the instant its
sim crosses the line), while the SCORE is authority-only (`ball_tick_then`,
delta lane). The world pass is pure sim — contact and kicks for whichever
kicker⟷ball pairs this peer has inputs for, no role gates anywhere.

And the full send: speedball runs PREDICT-WORLD (`echo_inputs` — the Rocket
League model). The kickers are `contested` too, batches echo every player's
held input, and every peer simulates the whole pitch on one predicted
timeline — your touches answer your feet, an opponent's tackle plays out
beside their avatar immediately, and the server's word arrives as small
glided corrections. (The claim-weighted middle path — predict only the
ball, watch the players — remains in the lane for games that want it; see
docs/kit/sim.md's contested section for when to pick which.)

```sh
bash build/build_scripts.sh examples/speedball
$GODOT --path examples/speedball                  # host, join from a second window
SPB_LATENCY=120 $GODOT --path examples/speedball  # feel the touches at 240ms RTT

bash examples/speedball/run.sh          # solo gate (SPEEDBALL_SINGLE_OK)
bash examples/speedball/native_run.sh   # contested-ball integration test (three peers)
```

WASD move · Space kick (aim with your movement) · Tab scores · Enter chat.
Env: `SPB_ROLE` (host/join/single/serve) · `SPB_PORT` · `SPB_NAME` ·
`SPB_TOKEN` · `SPB_LATENCY` · `SPB_BOT` (striker/idle) · `SPB_GOALS`.
