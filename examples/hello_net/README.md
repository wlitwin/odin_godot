# hello_net — the co-op quickstart's living copy

The smallest complete kit game: two windows, one colored square each, moving
on both screens. Two authored files (`scripts/hello.odin`,
`scripts/player.odin`), two 15-line scenes. The walkthrough is
[docs/kit/quickstart.md](../../docs/kit/quickstart.md); the server-authority
promotion of this exact game is `examples/hello_sim`.

```sh
bash build/build_scripts.sh examples/hello_net
$GODOT --path examples/hello_net &          # window 1: press Host
$GODOT --path examples/hello_net            # window 2: press Join
```

`HELLO_LATENCY=120` on either window injects a 120ms bad link.
`bash examples/hello_net/run.sh` is the same scenario headless: two
processes under latency, read through GENERATED probes
(`probe_player_count` / `probe_my_player` / `probe_player_x`), one verdict —
the smallest consumer of the integration harness and scriptgen's probes.
