# hello_sim — the sim quickstart's living copy

`examples/hello_net`, promoted to the server-authority sim lane in four
diffs (the [promotion checklist](../../docs/kit/sim.md#promoting-a-coop-game)
in miniature): the retag (`owner` → `predict`), the `@(gd_tick)`, the
`@(gd_sample)`, and two wiring lines. Walkthrough:
[docs/kit/quickstart-sim.md](../../docs/kit/quickstart-sim.md).

```sh
bash build/build_scripts.sh examples/hello_sim
$GODOT --path examples/hello_sim &                      # window 1: Host
HELLO_LATENCY=120 $GODOT --path examples/hello_sim      # window 2: Join — feel it
```

Under the injected latency your own square still snaps to your keys
(prediction) while the remote square glides a breath behind (watched).
`HELLO_ROLE=serve $GODOT --headless --path examples/hello_sim` runs the
dedicated, avatarless authority. `bash examples/hello_sim/run.sh` pins both
receipts headless through generated probes.
