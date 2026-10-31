# Cavecrawl combat presentation

```sh
REPLAY_CAVE_FEEDBACK_OUT=/absolute/fresh/output nix develop --command bash tests/replay_cave_feedback/run.sh
```

Creates separate copied server-motion and owner-motion projects. The test-only
probe can feed synthetic presentation changes; it cannot alter the gameplay world.
Native and rendered lifecycle checks verify authored particles, detached placement,
correction, confirmation, cancellation, deduplication, unchanged simulation hashes
and Leave cleanup. The browser repeats that lifecycle with real Chrome/WebGL.

Full host/client/observer campaigns use ordinary movement and actions, retaining
the complete existing inventory/combat/revive/respawn/floor/victory assertions.
Each also requires both player deaths, all 12 dweller deaths, 24 dweller hits,
player hits, and zero cue overflow; host/observer counts must be exact. The server-motion campaign also runs
with 120 ms receive delay, 20 ms jitter, 10% loss and 10% duplication. The world
hash comparison and actual injected-fault counts remain checked.

The synthetic visual case is a renderer/journal adapter test; it is not evidence
of gameplay occurring at the injected pose. The campaign supplies real gameplay
evidence. C9/O3 dweller-impact checks are extended in `tests/replay_cave_impact`; render-rate
rock-tracer parity remains open.
