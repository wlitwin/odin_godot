# Choosing a timeline model

Every multiplayer artifact you will ever debug — the ball that moves before
the kicker arrives, the shot that misses a target you were dead-on, the
avatar that rubber-bands when it stops — is the same question wearing
different clothes: **whose timeline is each thing on this screen presenting
from, and who arbitrates when two screens disagree?** This toolkit ships
FOUR answers, each proven by a worked game. Pick by what your game contests.

## The four models

| model | one screen shows | arbiter | never happens | structural cost | worked proof |
| --- | --- | --- | --- | --- | --- |
| **Coop** (kit/net + session) | my sim NOW, others `interp_delay` in the past | the host, via commands | mispredicts, correction pops | the two-timelines presentation discipline | cavecrawl, slopball |
| **Predict-self** (kit/sim) | my avatar NOW, others watched (past) | the server, every tick | trusting anyone's position | lag comp for anything aimed | quickdraw |
| **Contested object** (kit/sim, claim) | mine NOW, others past, the OBJECT claim-weighted | the server | round-trip waits on YOUR touches | the claim discipline (below) | the lane's claim machinery + kitsim |
| **Predict-world** (kit/sim, echo) | EVERYTHING at my predicted now | the server | mixed-timeline artifacts, wholesale | constant small corrections on remotes; resim per batch | speedball |

And the fifth, deliberately not shipped: **deterministic lockstep** (the
fighting-game answer — GGPO-style). One timeline by CONSENSUS: every peer
simulates every tick from everyone's inputs, rolling back on late arrivals.
Contact is bit-exact every frame, which is why the genre that is nothing
but contact lives there. The costs are why nobody ships a 16-player
lockstep shooter: cross-machine determinism (a real tax this toolkit's
server-auth models get to skip — the server's word is final, so approximate
re-execution self-heals), rollback cost scaling with peers, no referee
(desyncs detect, aimbots see truth), and late-join being nearly impossible.
If you are building a 1v1 game that is all contact, lockstep beats
everything here; for everything else, one of the four above does.

## How to choose

Ask what is CONTESTED — fought over by players in real time:

- **Nothing, really** (co-op loot, building, exploration): the coop kit.
  Friends don't cheat friends, owner streams never mispredict, and the
  session's identity machinery (reconnect, migration, saves) is the actual
  product. Read [net](net.md) and [session](session.md).
- **Aim** (shots at moving targets): predict-self + `lane_rewound`. Targets
  must render ACCURATELY (a delayed truth beats an extrapolated guess when
  a hit is judged against it), so remotes stay watched, and the rewind
  reconstructs the shooter's exact drawn view — quickdraw's duel acid
  proves the shot that lands at 240ms RTT, A/B against the same duel
  judged live.
- **One object** (the ball, the flag, the crown): contested + claim, or go
  straight to predict-world. The claim keeps remote players cheap
  (watched) while YOUR touches resolve instantly; predict-world buys
  timeline coherence for everyone at resim cost.
- **Contact itself** (bodies, tackles, scrums): predict-world. Mixing a
  predicted object with past-rendered players ships the artifact where the
  ball moves before its kicker visibly arrives — speedball shipped it for
  exactly one playtest.

Hybrids are per-entity and per-field, not per-game: quickdraw's hp and
score ride the coop delta lane inside sim-lane entities; speedball's match
state does the same. One session carries all of it.

## The laws (learned the hard way, each one test-pinned)

1. **Present consequences on the timeline of their cause.** The coop kit's
   `session_present(mine?)` boolean, the sim lane's `lane_claim` — same
   law. A remote cause presents beside its remotely-rendered actor; your
   cause presents now.
2. **The claim follows the cause and releases when the cause ends** — never
   on distance. Your kick's whole flight is your consequence; releasing a
   claim on a fast object blends across `speed × timeline-skew` and pulls
   your own kick backward mid-flight.
3. **Judge what was DRAWN.** Lag comp rewinds to the view bound to the
   very input that pulled the trigger (the ack that rode its packet, minus
   the watch delay, blended to the exact bracket) — never the shooter's
   freshest ack, which advances a whole lead-plus-transit between aiming
   and adjudication.
4. **Extrapolation fails only at input changes** — so put INERTIA in the
   movement model. A car can't stop instantly; that's not flavor, it's why
   Rocket League's remotes look smooth. Instant-velocity avatars turn every
   remote stop into a pull-back.
5. **Contested entities must be self-simulating.** A ball integrates its
   own flight, so every peer's between-batch prediction is good. An
   input-driven entity coasts frozen without its inputs and fights
   corrections forever.
6. **Hand-rolled contact must be capped and soft, inside the sim.** Clamp
   speeds in the tick (every peer clamps identically), separate overlaps
   gradually along STABLE directions (center-to-center flips sign in deep
   overlap), push along motion. Prediction quality and feel are the same
   fix. (`psim.Roller` packages #5 and #6 — embed it and both hold by
   construction; speedball's ball is the worked proof.)
7. **Corrections are for divergence, not float noise.** Exact compares
   resim on every batch of held-input drift; a float epsilon
   (`Lane_Config.tolerance`) lets sub-pixel drift ride until it
   accumulates. Discrete fields never get slack — a differing flag byte is
   a real event.
8. **Authority snaps; the eye glides.** Sim state adopts truth instantly,
   the render error decays with a half-life, and a big-enough jump CUTS
   (smoothing a teleport looks worse than the teleport). Everywhere: the
   puppet, the lane's glide, predict-world's remote corrections.

## Reading order

[sim](sim.md) for the machinery; `examples/quickdraw` then
`examples/speedball` as the worked contrasts — and read speedball against
[slopball](../../examples/slopball/README.md), the same game on the coop
model, to feel what each arbiter buys. The design history, playtest by
playtest, lives in the project's `server-authority-resim-companion` ledger.

Already shipped on the coop model and outgrowing it? The choice is not
all-or-nothing: sim.md's **"Promoting a coop game"** checklist migrates one
contested entity at a time (slopball → speedball is the worked diff), and a
hybrid is a supported end state.

## What follows a promotion — the gameplay modules

"Two netcodes, one surface" is exact at the session layer (identity, chat,
transfers, saves, the boot ride along untouched). The GAMEPLAY shelves were
grown on the coop model, and each doc now opens with its lane stance; the
map:

| Module | Stance |
|---|---|
| comms, xfer, save, ui | **Lane-agnostic** — session-level, use as-is |
| interact | Pure geometry, sim-safe; the prompt pattern is coop-shaped |
| items | Slot math sim-safe; inventories ride the delta lane (hybrid per-field) |
| combat | **Coop wire** — sim games use predict fields, verbs, and declared facts instead; math ports |
| ai | Coop NPC shape; brains move to the authority pass, math ports |
| fx | Presentation ports; the tracer pool is coop's projectile answer (sim projectiles are entities) |
| nav | **Never in a resimulating pass** — coop host brains and the sim authority pass only |

The open question (deliberately unresolved, not silently assumed): whether
`Inventory($N)`/`Cooldowns` embed-bundles can sit under a sim snapshot
descriptor. Until a game forces it, a hybrid keeps those fields on the
delta lane.
