# 7 · The competitive turn

Everything in posts 1–6 rested on one quiet assumption, and post 4 said it out
loud: **your friends don't cheat.** The co-op model hands each player authority
over their own avatar — you write your position, everyone else reads it — because
in a game you play with friends, a client lying about where it stands is a
problem you solve by finding new friends, not new netcode.

Now you want a *duel*. A ranked arena. A fighting game. Something where the other
player is an opponent, and "trust the client's own position" is the first thing a
cheater breaks. The whole authority model inverts: the **server** simulates the
truth, every client **predicts** it locally so the game still feels instant, and
when a prediction turns out wrong the server's word wins and the screen
**rolls back and resimulates** to match. Rollback netcode — the thing fighting
games and Rocket League are built on.

Here is the good news, and it is the whole reason this post is short: **it is the
same declarative surface.** You do not learn a new engine. You tag a different
handful of fields, and the two-timelines discipline from post 5 carries over
almost unchanged. The competitive lane is called `kit/sim`, and it is chosen
per **field**, so one game can be co-op in its chat and its scoreboard and
server-authoritative in its hitboxes.

## Predict-self: your avatar, on both clocks

In co-op, your avatar's `x, y` were `gd:"owner"` — you owned them, you streamed
them. In the sim lane they become predicted state, and the tick that moves them
is a plain proc with a tag:

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

That `@(gd_tick)` is the entire opt-in. Your fighter now runs on your predicted
timeline (instant to your hand) *and* on the server (the truth), and the lane
reconciles the two behind your back. The input you read is delivered by the lane,
not by you — you never send a packet. This is post 4's "verbs, not RPCs" with the
verb widened to *every frame*.

## The two timelines, again — but now the other guy is predicted too

Post 5's lesson was that a remote avatar is rendered in the *past*. Competitive
games make you decide, per object, whether to keep it that way:

- **Predict-self** (the default `@(gd_tick)`): predict only *your* fighter; watch
  the opponent an interp-delay behind, but *accurately*. Right for anything where
  a correctly-placed opponent matters — a hitscan shot, a parry window. This is
  what quickdraw ships.
- **The shared object** (`@(gd_tick = "contested")`): a ball, a flag, a bomb —
  something *both* players hit. Marking it `contested` means **every** peer
  predicts it, so your touch resolves on your screen the instant you make it. The
  server still owns the truth; a disagreement rolls back and glides.

The soccer example ships **three times**, one game per model, so you can read the
difference instead of taking it on faith:

| example | model | the ball is… |
|---|---|---|
| `examples/slopball`  | co-op (post 5)      | owned by the last toucher; peer-authoritative |
| `examples/speedball` | predict-**world**   | *everyone* predicted (avatars too) — one timeline, constant tiny glides |
| `examples/claimball` | predict-self + **claim** | only *your* avatar predicted; the ball predicted and **claimed** |

## The claim — the one genuinely new idea

`claimball` is the interesting one, because predict-self plus a contested ball
raises a question the other two dodge: the ball runs on *your* predicted timeline,
but your *opponent* is rendered in the past. If you always draw the ball from your
prediction, a shot your opponent takes appears a whole interp-delay *before* their
avatar visibly kicks it — predicted ball, past-rendered player, one screen. The
mixed-timelines artifact from post 5, back with a vengeance.

The fix is one boolean asked continuously — the sim-lane echo of post 5's
`mine?`: **is my simulation the one driving this ball right now?**

```odin
// in the world pass, every tick MY fighter is influencing the ball:
if ksim.lane_live(&g.lane) {          // presentation — live pass only, never a resim
	if my_kicker_in_reach || ball_still_fast_from_my_kick {
		ksim.lane_claim(&g.lane, ball.net_id)   // draw it from MY predicted pose
	}
}
```

Claimed, the ball draws from your prediction — instant, and legitimately, because
*you* caused its motion. Unclaimed, it draws the watched view, so your opponent's
touch moves it *beside their delayed avatar*, exactly where they'll appear to hit
it. The claim decays over a quarter second when you stop influencing it, so the
handback is a glide, not a snap.

There is exactly one footgun, and `claimball` exists partly to name it: **release
the claim when the ball SLOWS, never on mere distance.** Your kick's whole flight
is your consequence — keep the claim while the ball is fast and far. Drop it just
because the ball got far from your feet and the fade target (the watched view,
sitting a timeline-skew behind a fast ball) yanks your own kick *backwards*
mid-flight. Release when it's slow, the two timelines have converged, and nobody
sees the handoff.

## Lag compensation comes for free

The hitscan problem — "I shot where my screen showed the target, but the server
says I missed because its copy already moved" — is one call, because the lane
already keeps every entity's recent history:

```odin
judged := ksim.lane_rewound_begin(&g.lane, shooter) // wind every OTHER entity
g.hit = trace_shot(g)                               // back to the shooter's view
ksim.lane_rewound_end(&g.lane)
```

## What you keep

Everything post 6 promised is still yours: reconnects, drop-in joins, saves, host
migration, the wire-version door, Steam. The sim lane rides the same session; a
game is co-op in its lobby and its chat and server-authoritative in its
hitboxes, and the reconnect story doesn't know the difference.

**Run it:**

```
nix develop --command bash -c 'bash examples/claimball/native_run.sh'  # CLAIMBALL_NATIVE_OK
```

Three headless processes at 240ms round-trip: a striker drives a ball it
predicts to a goal, *claiming* it the whole way (so it presents from the
striker's timeline — `claim` rides near 1), while a watcher who never touches it
sees it watched (`claim` 0). One ball, two timelines, one screen each — the
competitive turn, working.

Deeper reference: [kit/sim](../kit/sim.md) (the full lane), and
[timelines](../kit/timelines.md) (the per-field choosing guide — the map for
deciding what's co-op and what's contested in *your* game).
