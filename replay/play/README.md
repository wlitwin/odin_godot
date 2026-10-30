# Replay gameplay helpers

These are engine-independent operations on frame-owned values. Games choose the
system order and pass immutable rules; helpers do not select authority or access
scene nodes. Units are per simulation tick unless specified otherwise.

- `Body2`/`move`: axis-separated movement against authored static AABBs.
- `Motion2`/`momentum_step`: velocity approaches a target, then position integrates
  and clamps to bounds. `roll_step` applies friction, speed cap and wall restitution
  from `Roll_Law2`. `soft_contact` separates half the overlap and applies a bounded
  motion-directed dribble nudge. These are a defined kinematic subset, not a
  general rigid-body solver or a proof of cross-platform determinism.
- `Cooldown`: frame-owned countdown with tick/ready/arm operations and `cooldown_try`
  for admission that starts the clock only when ready.
- [`Gun_State`](gun.md): magazine, reload and deterministic jam/clear transitions;
  the caller owns cadence and shot effects.
- [`Carom2` and beam queries](carom.md): value-owned bouncing ordnance and the
  closed-segment judge used by the Scrapyard lance/mender.
- [`Effect` and `Telegraph`](effects.md): bounded stack/duration state and explicit
  wind-up/landing clocks; games supply reactions, attribution and payloads.
- [`Director` and `Channel`](director.md): paced waves with spawn backpressure and
  validated tick-owned holds such as revives.
- Inventory, damage/reach and navigation helpers support the Cavecrawl model.
- Ray/AABB/circle queries, life-aware hurtbox interpolation and semantic spawn
  keys support [Quickdraw](../../examples/replay_quickdraw/README.md).

[Speedball](../../examples/replay_speedball/README.md) is the motion/contact example.
Its movement, ball integration and contacts execute identically in native tests,
the server and full-world client prediction. Godot presentation reads copies.
