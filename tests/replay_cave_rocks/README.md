# Rock motion between simulation ticks

```sh
REPLAY_CAVE_ROCKS_OUT=/absolute/fresh/output nix develop --command bash tests/replay_cave_rocks/run.sh
```

The fixture prepares isolated server-motion and owner-motion projects. At 30, 60
and 144 FPS, real host/client/observer processes admit two players, move the host
away from the other body, and fire an ordinary rock across open space. Every
render-frame sample records the source tick/position, shown position, velocity,
phase and glyph center. The verifier requires motion while the simulation tick
stays fixed, a maximum one-tick preview, monotonic motion within an unchanged
source tick, motion in at least 65% of same-tick frame pairs, no backward step
between advancing source ticks, centered glyphs, and removal of the expired view.

Pure tests cover contact clipping, ignored shooter/corpses, unchanged world values,
phase stalls/reset validation, and Session's authority/client/fencing/pause paths.
Native and Chrome visual checks explicitly paint several fractions against a
frozen complete frame and require identical hashes. Full normal/faulted C9 and O3
campaigns retain combat, impact, inventory, heal-transition and victory checks.

The sample counts are frame observations, not input-device latency or process CPU
measurements. This does not claim immediate pre-tick cast visuals or independent
render-time damage/contact effects. Those differences from Kit remain explicit.
