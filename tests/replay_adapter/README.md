<a id="adapter-ergonomics-gate"></a>

# Typed scene-adapter acceptance

Run in the Nix development shell:

```sh
REPLAY_ADAPTER_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_adapter/run.sh
```

The gate builds scriptgen and checks seven declaration/signature cases plus
stable WASM generation. It runs existing scriptgen regressions and the
scope/bake/view/display and Stormcaller tests, then compares executed native
and WASM takeover results.

It also builds an isolated Godot Scrapyard copy to check composed previews and
bindings, canonical exports, three-peer revival, and crash takeover. The committed
stock artifact must be current (`tools/stock.py --check`).

The engine probe verifies generated callback equivalence, independent retained
appearance ownership, typed handle visitation, skipped paints, epoch retirement,
invalid/duplicate input rejection, rich component diagnostics, and persistent
player-character scene identity across epoch/body-generation changes. These
characters are called runners in Scrapyard. Preview ID 7 uses an authored pulse
radius without opening a live game. The migration wrapper changes only the
existing migration fixture's project/output paths and uses bounded process-group
ownership; no protocol or acceptance assertions are duplicated.

The gate also runs lower-level Node/View_Pool lifecycle compatibility and wrong
scene-root rejection. Run that subset alone with
`REPLAY_NODES_OUT=/absolute/fresh/path bash tests/replay_nodes/run.sh`.
Raw logs and failed runs should be preserved. No probes ship in the game.
