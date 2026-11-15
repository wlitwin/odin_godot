<a id="7--the-competitive-turn"></a>

# 7 · Server-authoritative simulation

The co-op model gives each player authority over their own avatar: you write
your position, everyone else reads it. That works when you trust the other
players. The authority accepts their motion, so this policy cannot prevent a
modified client from inventing a position.

For contested motion, the **server** runs the authoritative simulation. A
client **predicts** its own input before the server replies. When an update
disagrees, the client restores historical state and reruns subsequent ticks
with the correction. Presentation then blends toward that result.

`kit/sim` implements this simulation lane. It uses the same field declarations
and generated callbacks as cooperative replication, with additional input,
tick, and history configuration. Each field selects its replication policy,
so a game can combine lobby and scoreboard deltas with server-authoritative
hitboxes. Presentation still needs to align effects with their visible causes.

## Predict-self: your avatar on both timelines

In the co-op lane your avatar's `x, y` are `gd:"owner"`: you own them and you
stream them. In the sim lane they become predicted state, and the tick that
moves them is a plain proc with a tag:

```odin
Fighter :: struct {
	body: psim.Mover,          // x/y/vx/vy — predicted, resimmable
	hp:   i32 `gd:"replicate"`, // authority-owned state on the delta lane
}

@(gd_tick)                     // "predict-self": predict the local fighter; authority judges it
fighter_tick :: proc(self: ^Fighter, input: Fighter_Input) {
	// Read input and write intent. Runs live on the client each simulation
	// tick, re-runs during a resim after a server correction, and runs on
	// the authority. The generated scheduler handles is_host role selection.
}
```

`@(gd_tick)` registers the tick procedure. With the session and predicted
fields configured, the simulation lane runs it locally and on the authority.
It delivers typed input, retains history, and applies corrections; gameplay
code does not send the input packets directly.

## Choosing per object: predict-self and contested

A remote avatar renders in the past (see [timelines](../kit/timelines.md)).
Choose which objects to predict locally and which to display from received
authority history:

- **Predict-self**: the default `@(gd_tick)`. Predict only *your* fighter;
  display the opponent from accepted history an interp-delay behind. Use this
  for interactions judged against the displayed opponent, such as hitscan
  shots and parry windows. Quickdraw uses this model.
- **Contested**: `@(gd_tick = "contested")`. For a shared object both players
  hit: a ball, a flag, or a bomb. Marking it `contested` makes every peer
  predict it, so local simulation can respond to contact before a round trip. The
  server remains authoritative. A disagreement restores and replays the
  predicted state, while presentation blends toward the corrected result.

Three soccer examples demonstrate different prediction and presentation
models:

| example | model | the ball is… |
|---|---|---|
| `examples/slopball`  | co-op               | owned by the last toucher; peer-authoritative |
| `examples/speedball` | predict-**world**   | predicted on every peer along with avatars; one timeline with blended corrections |
| `examples/claimball` | predict-self + **claim** | only *your* avatar predicted; the ball predicted and **claimed** |

<a id="the-claim"></a>

## Presentation claims

`claimball` combines predict-self with a contested ball. The local peer
predicts the ball while displaying the opponent from delayed authority
history. Always drawing the predicted ball can therefore show an opponent's
shot an interp-delay before the opponent visibly kicks it.

A **presentation claim** chooses the local predicted view while the local
player drives the ball. It does not transfer network authority. Update it
continuously from the local influence on the ball:

```odin
// In the world pass, claim each tick while the local fighter influences the ball:
if ksim.lane_live(&g.lane) {          // presentation — live pass only, never a resim
	if my_kicker_in_reach || ball_still_fast_from_my_kick {
		ksim.lane_claim(&g.lane, ball.net_id)   // draw from the local predicted pose
	}
}
```

While claimed, the ball draws from local prediction to respond to the local
player's influence. Without a claim, it draws from watched history to align
with the opponent's delayed avatar. When local influence ends, the claim
decays over a quarter second and blends toward the watched view.

Keep the claim while the ball remains fast from the local kick, even after it
moves far from the player. Releasing it based only on distance blends toward
the older watched position and can visibly pull the ball backward mid-flight.
Release when the ball slows: the position gap between the timelines is then
smaller, reducing the visible correction during the handoff.

## Lag compensation

For a hitscan shot, the server's current target position may differ from what
the shooter saw. The lane retains recent entity history so the authority can
temporarily rewind targets to the shooter's view for the hit test:

```odin
judged := ksim.lane_rewound_begin(&g.lane, shooter) // rewind other entities with history
g.hit = trace_shot(g)                               // back to the shooter's view
ksim.lane_rewound_end(&g.lane)
```

Call this pair on the authority inside its simulation step. Begin and end
must occur in the same frame, must not nest, and must not surround changes to
the lane's tracked entity set. The end call restores the live state.

<a id="what-carries-over"></a>

## Session features and migration limits

Reconnects, drop-in joins, saves, wire-version compatibility checks, and
transports use the same session. A game can keep cooperative lobby/chat state
and authoritative hitboxes together. Live host migration is supported only
for the cooperative lane; `boot_migration` requires that no simulation lane is
installed.
A simulation save can resume under a restarted authority, with fresh lane
history; see [the save contract](../kit/save.md).

**Run it:**

```
nix develop --command bash -c 'bash examples/claimball/native_run.sh'  # CLAIMBALL_NATIVE_OK
```

The test runs three headless processes at 240ms round-trip. A striker predicts
and claims the ball through its flight to the goal, presenting from the
striker's timeline with `claim` near 1. A watcher that never touches it uses
the watched view with `claim` 0. These checks exercise the two presentation
choices for that scenario.

See [kit/sim](../kit/sim.md) for simulation setup and APIs, and
[timelines](../kit/timelines.md) for choosing a replication and authority
policy for each field.
