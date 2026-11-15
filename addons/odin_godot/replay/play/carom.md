# Carom and beam queries

Use `Carom2` for the defined bouncing-shell motion rule and beam helpers for
closed-segment hit queries. `Carom2` is a value-owned position/velocity pair. `carom2_step` advances it against
static AABBs and arena bounds, with caller-provided time, restitution and face
clearance. It implements the original Scrapyard shell law: up to three cover legs,
axis-normal reflection, then arena-wall clamp/reflection. The caller owns fuse,
contact detection, damage and presentation.

```odin
body := p.Carom2{shot.position, shot.velocity}
if !p.carom2_step(&body, 1, 0.72, 0.1, arena_bounds, cover_boxes[:]) {
    r.abort(ctx)
    return
}
shot.position, shot.velocity = body.position, body.velocity
```

Positions use pixels and velocities use pixels per tick; time/clearance use ticks.
Invalid finite/bounds/coefficient inputs reject without changing the body. An
origin inside cover can exit. `first_face2` queries the nearest strict entry before
the time limit and returns the face normal. Its inputs must already be valid.

`beam_circle` implements the original lance/mender judge: closest point on a closed
segment versus a target circle. Its fraction orders targets by center projection.
Use `segment_circle` instead when the desired rule is first surface contact.

`tests/replay_carom/run.sh` compares 72 motion traces (300 steps each; four layouts,
six launch cases, three frame durations) and 513 beam judgments against the original
expressions compiled in isolation. The extracted motion block excludes node/trail
presentation and fuse/contact damage; those are tested in the game. Cached original
results permit standalone repository tests; `REPLAY_REQUIRE_BASELINE=1` requires
the sibling source too. Native boundaries and freestanding WASM checking pass.

These helpers define a reproducible kinematic rule for the authoritative/co-op
runner. They do not establish cross-platform deterministic P2P for floating-point
worlds or reproduce every aspect of the original render-frame grenade simulation.
