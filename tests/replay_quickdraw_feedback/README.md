# Quickdraw feedback acceptance

```sh
REPLAY_QUICKDRAW_FEEDBACK_OUT=/absolute/fresh/output nix develop --command bash tests/replay_quickdraw_feedback/run.sh
RQ_FEEDBACK_RENDERED=1 nix develop --command python3 tests/replay_quickdraw_feedback/execute.py /absolute/output rendered
```

The native fixture uses real host/client/observer processes at 120 ms receive delay.
It checks the skin palette, independent gun/beam tint, one hurt flash, restoration,
lethal flash/dead tint, respawn seeding, one locally predicted landing ring, geometry,
pose, fade and observer rejoin without historical effects. Damage and lob flight use
the game's ordinary controls. The rendered variant captures the landing ring.

The pure `tests/replay_quickdraw/feedback_test.odin` cases use the real event journal
for corrections, cancellation, confirmation and reappearance, and exercise bounded
ring capacity and stale cancellation after slot reuse. Existing UI, profile, model
and WASM checks are prerequisites in the runner. This is native presentation evidence;
it does not imply browser multiplayer or complete human play-feel parity.
