# claimball — predict-self + the claim

The third telling of one soccer game, so you can read the models against each
other and pick one:

| example | model | the ball |
|---|---|---|
| [slopball](../slopball/)   | co-op, peer-authoritative | owned by the last toucher (`play.Puppet`) |
| [speedball](../speedball/) | predict-**world** (`echo_inputs`) | every avatar echoed; one predicted timeline |
| **claimball** | predict-**self** + the **claim** | only your avatar predicted; the ball predicted and *claimed* |

Claimball keeps the ball `@(gd_tick = "contested")` — predicted on every screen,
so a touch resolves on your timeline the instant you make it — but a kicker is a
plain `@(gd_tick)` (predict-self, `echo_inputs = false`): each peer predicts only
its OWN kicker and WATCHES the others, an interp-delay behind but exact. No
held-input echo, no constant corrective glide on remote avatars — the price is
paid on the shared ball instead, through the **claim**.

## The claim

A contested ball runs on my predicted timeline, but my opponent renders in the
past. If I always draw the ball from my prediction, a shot my opponent takes
appears a whole interp-delay before their avatar visibly kicks it. So the ball's
*presentation* is claim-weighted — one boolean, asked every tick: **is my sim
driving this ball right now?**

```odin
// claimball.odin, the world pass — LIVE pass only (presentation, never a resim):
if ksim.lane_live(&g.lane) {
	if my_kicker_in_reach || ball_still_fast_from_my_kick {
		ksim.lane_claim(&g.lane, ball.net_id)   // draw it from MY predicted pose
	}
}
```

Claimed, the ball draws instant from your prediction — legitimately, you caused
its motion. Unclaimed, it draws the watched view, so an opponent's touch moves it
beside their delayed avatar, right where they appear to hit it. `lane_claimed`
reads the weight back (near 1 while claiming, decaying to 0 over ~¼s after).

**The one footgun:** release the claim when the ball **slows**, never on mere
distance. Your kick's whole flight is your consequence — hold the claim while the
ball is fast and far. Release on distance and the fade target (the watched view,
sitting a timeline-skew *behind* a fast ball) yanks your own kick backward
mid-flight. Release on slow, the timelines have converged, and the handback is
invisible (`util.odin`'s `RELEASE_SPEED`).

Also here, unchanged from the twin: the GOAL RESET is predicted (every screen
snaps the ball home the instant its sim crosses the line), the SCORE is
authority-only (`ball_tick_then`, delta lane).

```sh
bash build/build_scripts.sh examples/claimball
$GODOT --path examples/claimball                  # host, join from a second window
CLB_LATENCY=120 $GODOT --path examples/claimball  # feel the touches at 240ms RTT

bash examples/claimball/run.sh          # solo gate (CLAIMBALL_SINGLE_OK)
bash examples/claimball/native_run.sh   # the claim-mode acid, three peers (CLAIMBALL_NATIVE_OK):
                                        # a striker drives + claims the ball to a goal (claim near 1),
                                        # an idle watcher sees the same ball watched (claim 0)
```

WASD move · Space kick (aim with your movement) · Tab scores · Enter chat.
Env: `CLB_ROLE` (host/join/single/serve) · `CLB_PORT` · `CLB_NAME` ·
`CLB_TOKEN` · `CLB_LATENCY` · `CLB_BOT` (striker/idle) · `CLB_GOALS`.

See [docs/onboarding/07-the-competitive-turn.md](../../docs/onboarding/07-the-competitive-turn.md)
for the walkthrough and [docs/kit/sim.md](../../docs/kit/sim.md) for the full lane.
