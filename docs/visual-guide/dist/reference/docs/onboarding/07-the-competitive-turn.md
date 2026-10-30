# 7 · The competitive turn

The co-op model gives each player authority over their own avatar: you write
your position, everyone else reads it. That works when you trust the other
players. A client lying about where it stands is a social problem, not a
netcode one.

Competitive games invert that. In a duel, a ranked arena, or a fighting game the
opponent is not a friend, and "trust the client's own position" is the first
thing a cheater breaks. So the **server** simulates the truth, every client
**predicts** it locally so the game still feels instant, and when a prediction
turns out wrong the server's word wins: the screen **rolls back and
resimulates** to match. This is rollback netcode, the model that fighting games
and Rocket League are built on.

The competitive lane is `kit/sim`, and it is the same declarative surface as the
co-op lane. You do not learn a new engine; you tag a different handful of fields,
and the two-timelines discipline carries over. The lane is chosen per **field**,
so one game can be co-op in its chat and its scoreboard and server-authoritative
in its hitboxes.

## Predict-self: your avatar on both timelines

In the co-op lane your avatar's `x, y` are `gd:"owner"`: you own them and you
stream them. In the sim lane they become predicted state, and the tick that
moves them is a plain proc with a tag:

```odin
Fighter :: struct {
	body: psim.Mover,          // x/y/vx/vy — predicted, resimmable
	hp:   i32 `gd:"replicate"`, // the delta lane, as before — the server's ledger
}

@(gd_tick)                     // "predict-self": I predict MY fighter; the server reconciles
fighter_tick :: proc(self: ^Fighter, input: Fighter_Input) {
	// read the stick, write intent. That's it. Runs live on my screen every
	// frame, re-runs during a resim when the server corrects me, and runs on
	// the server as the one truth. No is_host, no role branches.
}
```

`@(gd_tick)` is the entire opt-in. Your fighter runs on your predicted timeline
(instant to your hand) and on the server (the truth), and the lane reconciles
the two behind your back. The input you read is delivered by the lane. You
never send a packet.

## Choosing per object: predict-self and contested

A remote avatar renders in the past (see [timelines](../kit/timelines.md)).
Competitive games make you choose, per object, whether to keep it that way:

- **Predict-self**: the default `@(gd_tick)`. Predict only *your* fighter;
  watch the opponent an interp-delay behind, but *accurately*. Use it wherever a
  correctly-placed opponent matters: a hitscan shot, a parry window. This is
  what quickdraw ships.
- **Contested**: `@(gd_tick = "contested")`. For a shared object both players
  hit: a ball, a flag, a bomb. Marking it `contested` makes **every** peer
  predict it, so your touch resolves on your screen the instant you make it. The
  server still owns the truth; a disagreement rolls back and glides.

The soccer example ships three times, one game per model, so you can read the
difference side by side:

| example | model | the ball is… |
|---|---|---|
| `examples/slopball`  | co-op               | owned by the last toucher; peer-authoritative |
| `examples/speedball` | predict-**world**   | *everyone* predicted (avatars too), one timeline, constant tiny glides |
| `examples/claimball` | predict-self + **claim** | only *your* avatar predicted; the ball predicted and **claimed** |

## The claim

`claimball` combines predict-self with a contested ball, which raises a question
the other two models avoid. The ball runs on *your* predicted timeline, but your
*opponent* renders in the past. If you always draw the ball from your
prediction, a shot your opponent takes appears a whole interp-delay *before*
their avatar visibly kicks it. The result is a predicted ball, a past-rendered
player, and one shared screen.

The fix is one boolean, asked continuously: **is my simulation the one driving
this ball right now?**

```odin
// in the world pass, every tick MY fighter is influencing the ball:
if ksim.lane_live(&g.lane) {          // presentation — live pass only, never a resim
	if my_kicker_in_reach || ball_still_fast_from_my_kick {
		ksim.lane_claim(&g.lane, ball.net_id)   // draw it from MY predicted pose
	}
}
```

Claimed, the ball draws from your prediction instantly and correctly, because
*you* caused its motion. Unclaimed, it draws the watched view, so your
opponent's touch moves it *beside their delayed avatar*, exactly where they will
appear to hit it. The claim decays over a quarter second when you stop
influencing the ball, so the handback is a glide, not a snap.

One rule to get right: **release the claim when the ball slows, never on mere
distance.** Your kick's whole flight is your consequence, so keep the claim
while the ball is fast and far. If you drop it just because the ball got far from
your feet, the fade target (the watched view, sitting a timeline-skew behind a
fast ball) yanks your own kick *backwards* mid-flight. Release when the ball is
slow: the two timelines have converged, and nobody sees the handoff.

## Lag compensation

The hitscan problem ("I shot where my screen showed the target, but the server
says I missed because its copy already moved") is one call, because the lane
keeps every entity's recent history:

```odin
judged := ksim.lane_rewound_begin(&g.lane, shooter) // wind every OTHER entity
g.hit = trace_shot(g)                               // back to the shooter's view
ksim.lane_rewound_end(&g.lane)
```

## What carries over

Everything from the co-op lane still holds: reconnects, drop-in joins, saves,
host migration, the wire-version door, Steam. The sim lane rides the same
session: a game is co-op in its lobby and its chat and server-authoritative in
its hitboxes, and the reconnect path treats them the same.

**Run it:**

```
nix develop --command bash -c 'bash examples/claimball/native_run.sh'  # CLAIMBALL_NATIVE_OK
```

Three headless processes at 240ms round-trip: a striker drives a ball it
predicts to a goal, *claiming* it the whole way (so it presents from the
striker's timeline, with `claim` riding near 1), while a watcher who never
touches it sees it watched (`claim` 0). It all resolves to one ball, two
timelines, and one screen each.

Deeper reference: [kit/sim](../kit/sim.md) for the full lane, and
[timelines](../kit/timelines.md) for the per-field guide to deciding what's
co-op and what's contested in *your* game.
