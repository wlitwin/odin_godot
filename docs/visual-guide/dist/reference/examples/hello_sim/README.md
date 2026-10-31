<a id="hello_sim--the-sim-quickstarts-living-copy"></a>

# hello_sim — server authority and client prediction

This version of `examples/hello_net` lets the server settle movement while clients
predict their own square locally. Kit's simulation lane schedules fixed ticks and
retains the history needed for correction. The conversion makes five changes, following the
[promotion checklist](../../docs/kit/sim.md#promoting-a-coop-game):

1. Retag simulated state from `owner` to `predict`.
2. Move frame-rate movement into a fixed-tick `@(gd_tick)` procedure.
3. Declare safe input ranges with `@(gd_input)`.
4. Sample device input with `@(gd_sample)`.
5. Attach the lane through the generated network facade.

See [docs/kit/quickstart-sim.md](../../docs/kit/quickstart-sim.md) for the walkthrough.

```sh
bash build/build_scripts.sh examples/hello_sim
$GODOT --path examples/hello_sim &                      # window 1: Host
HELLO_LATENCY=120 $GODOT --path examples/hello_sim      # window 2: Join and compare prediction
```

Under the injected latency, your own square responds through local prediction.
The remote square is displayed from delayed authority history (the watched view).
`HELLO_ROLE=serve $GODOT --headless --path examples/hello_sim` runs the
dedicated, avatarless authority. The role selects
`.Dedicated_Competitive`; the normal Host path uses
`.Listen_Server_Action`, with the same simulation code. `bash
examples/hello_sim/run.sh` checks both
profiles headless through generated read-only probes.
