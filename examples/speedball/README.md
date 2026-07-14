# speedball — the contested twin

The same game as [slopball](../slopball/), the OTHER netcode — read them side
by side to pick a model. Where slopball hands the ball's simulation seat to
the last toucher (peer-authoritative, `play.Puppet`, never mispredicts, pays
in seat arbitration), speedball keeps ONE authority and lets **every peer
predict the ball**:

```odin
@(gd_tick = "contested")
ball_tick :: proc(self: ^Ball) -> (scored: u8) { ... }
```

That one config token is the **predict-the-contested-object** pattern (the
Rocket League middle path): your dribbles and kicks resolve on YOUR screen
the frame you make them, at any latency — the acid proves a striker driving
the ball to a goal through 240ms RTT on local touches alone. The server's
simulation stays the only truth; when an opponent you render in the past
touches it first, the reconcile snaps your ball and the glide hides the
loss. Costs, paid honestly: resim CPU on every peer, and that mispredict.

Also showcased: the GOAL RESET is predicted (detection + kickoff freeze live
in the ball's own tick — every screen snaps the ball home the instant its
sim crosses the line), while the SCORE is authority-only (`ball_tick_then`,
delta lane). The world pass is pure sim — contact and kicks for whichever
kicker⟷ball pairs this peer has inputs for, no role gates anywhere.

And the pattern's finishing move, `lane_claim`: the ball's SIM is predicted
everywhere, but its PRESENTATION follows the claim — near your kicker it
draws from your predicted timeline (your touches answer your feet); loose,
it draws the watched view, so an opponent's kick moves it beside their
rendered avatar instead of a whole lead early.

```sh
bash build/build_scripts.sh examples/speedball
$GODOT --path examples/speedball                  # host, join from a second window
SPB_LATENCY=120 $GODOT --path examples/speedball  # feel the touches at 240ms RTT

bash examples/speedball/run.sh          # solo gate (SPEEDBALL_SINGLE_OK)
bash examples/speedball/native_run.sh   # the contested-ball acid (three peers)
```

WASD move · Space kick (aim with your movement) · Tab scores · Enter chat.
Env: `SPB_ROLE` (host/join/single/serve) · `SPB_PORT` · `SPB_NAME` ·
`SPB_TOKEN` · `SPB_LATENCY` · `SPB_BOT` (striker/idle) · `SPB_GOALS`.
