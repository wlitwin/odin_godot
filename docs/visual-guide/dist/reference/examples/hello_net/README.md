<a id="hello_net--the-co-op-quickstarts-living-copy"></a>

# hello_net — session replication example

This small Kit game opens two windows with one colored square per player; both
screens display both players' movement. `scripts/hello.odin` handles the session
and `scripts/player.odin` defines the moving player entity. Two 15-line scenes
provide their Godot nodes. The walkthrough is
[docs/kit/quickstart.md](../../docs/kit/quickstart.md); the server-authority
promotion of this exact game is `examples/hello_sim`.

```sh
bash build/build_scripts.sh examples/hello_net
$GODOT --path examples/hello_net &          # window 1: press Host
$GODOT --path examples/hello_net            # window 2: press Join
```

`HELLO_LATENCY=120` on either window injects 120ms of network latency.
`bash examples/hello_net/run.sh` is the same scenario headless: two
processes under latency, observed through generated read-only probes
(`probe_player_count` / `probe_my_player` / `probe_player_x`). It demonstrates
how to drive a game through the integration harness and scriptgen's probes.

The generated attach selects `.Friends_Coop`: each entity owner—the player
allowed to write that entity's owner-controlled fields—streams their movement.
The host controls shared state and validates Kit commands, the generated requests
that change entity state.
