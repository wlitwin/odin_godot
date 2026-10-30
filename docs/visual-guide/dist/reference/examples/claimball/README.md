# claimball — predict-self + the claim

Run Claimball to compare local avatar prediction with prediction of the whole
world. These three soccer examples use different authority and display policies:

| example | model | the ball |
|---|---|---|
| [slopball](../slopball/)   | co-op, peer-authoritative | owned by the last toucher (`play.Puppet`) |
| [speedball](../speedball/) | predict-**world** (`echo_inputs`) | every avatar echoed; one predicted timeline |
| **claimball** | predict-**self** + the **claim** | only your avatar predicted; the ball predicted and *claimed* |

Claimball keeps the ball `@(gd_tick = "contested")`, so each peer predicts the
ball locally before the authority settles its state. A kicker uses plain
`@(gd_tick)` (predict-self, `echo_inputs = false`): each peer predicts its own
kicker and displays remote kickers from authority history with an interpolation
delay. The game does not echo held input for remote prediction. A **claim**
chooses how to display the ball as it moves between these timelines; it does not
transfer gameplay authority.

## The claim

A contested ball runs on the local predicted timeline while a remote kicker is
drawn from delayed authority history. Drawing every ball pose from local
prediction would show a remote shot before the remote avatar visibly kicks it.
The ball's presentation—the displayed state and effects—therefore uses a claim
weight. The live world pass claims the ball while the local kicker is in reach
or the ball is still moving fast from that kicker's shot.

```odin
// claimball.odin, the world pass — LIVE pass only (presentation, never a resim):
if ksim.lane_live(&g.lane) {
	if my_kicker_in_reach || ball_still_fast_from_my_kick {
		ksim.lane_claim(&g.lane, ball.net_id)   // draw it from MY predicted pose
	}
}
```

Claimed, the ball draws from your prediction. Unclaimed, it draws from the
watched authority history, so an opponent's touch moves it beside their delayed
avatar. `lane_claimed`
reads the weight back (near 1 while claiming, decaying to 0 over ~¼s after).

**Release the claim when the ball slows**, never on mere
distance. Your kick's whole flight is your consequence — hold the claim while the
ball is fast and far. Release on distance and the fade target (the watched view,
sitting a timeline-skew *behind* a fast ball) yanks your own kick backward
mid-flight. Releasing when it slows lets the timelines converge before the display returns
to the watched view (`util.odin`'s `RELEASE_SPEED`).

The goal reset is predicted: each screen snaps the ball home when its simulation
crosses the line. The score changes only on the authority in `ball_tick_then`
and replicates through the delta lane, Kit's field-change replication path.

```sh
bash build/build_scripts.sh examples/claimball
$GODOT --path examples/claimball                  # host, join from a second window
CLB_LATENCY=120 $GODOT --path examples/claimball  # feel the touches at 240ms RTT

bash examples/claimball/run.sh          # solo gate (CLAIMBALL_SINGLE_OK)
bash examples/claimball/native_run.sh   # claim-mode integration test, three peers (CLAIMBALL_NATIVE_OK):
                                        # a striker drives + claims the ball to a goal (claim near 1),
                                        # an idle watcher sees the same ball watched (claim 0)
```

WASD move · Space kick (aim with your movement) · Tab scores · Enter chat.
Env: `CLB_ROLE` (host/join/single/serve) · `CLB_PORT` · `CLB_NAME` ·
`CLB_TOKEN` · `CLB_LATENCY` · `CLB_BOT` (striker/idle) · `CLB_GOALS`.

See [docs/onboarding/07-the-competitive-turn.md](../../docs/onboarding/07-the-competitive-turn.md)
for the walkthrough and [docs/kit/sim.md](../../docs/kit/sim.md) for the full lane.
