# hello_sim — the sim quickstart's living copy

This version of `examples/hello_net` lets the server settle movement while clients
predict their own square locally. Kit's simulation lane schedules fixed ticks and
retains the history needed for correction. The conversion follows five
steps (the [promotion checklist](../../docs/kit/sim.md#promoting-a-coop-game)
in miniature): retag the state (`owner` → `predict`), add `@(gd_tick)`, declare
safe input ranges with `@(gd_input)`, sample with `@(gd_sample)`, let the generated network
facade attach the lane, and remove frame-rate movement. Walkthrough:
[docs/kit/quickstart-sim.md](../../docs/kit/quickstart-sim.md).

```sh
bash build/build_scripts.sh examples/hello_sim
$GODOT --path examples/hello_sim &                      # window 1: Host
HELLO_LATENCY=120 $GODOT --path examples/hello_sim      # window 2: Join — feel it
```

Under the injected latency, your own square responds through local prediction.
The remote square is displayed from delayed authority history (the watched view).
`HELLO_ROLE=serve $GODOT --headless --path examples/hello_sim` runs the
dedicated, avatarless authority. The role selects
`.Dedicated_Competitive`; the normal Host path uses
`.Listen_Server_Action`, with the same simulation code. `bash
examples/hello_sim/run.sh` checks both
profiles headless through generated read-only probes.
