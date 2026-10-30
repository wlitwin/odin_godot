# Adapter ergonomics gate

Run in the Nix development shell:

```sh
REPLAY_ADAPTER_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_adapter/run.sh
```

The gate builds scriptgen, checks seven declaration/signature cases and stable
WASM generation, runs the existing scriptgen regressions, scope/bake/view/display
and Stormcaller tests, compares executed native/WASM takeover, builds an isolated
Godot Scrapyard, checks composed scene previews and bindings, canonical exports,
three-peer revive and actual crash takeover. It requires the committed stock
artifact to be current (`tools/stock.py --check`).

The engine probe verifies generated callback equivalence, independent retained
appearance ownership, typed handle visitation, skipped paints, epoch retirement,
invalid/duplicate input rejection, rich component diagnostics, and persistent
runner scene identity across epoch/body-generation changes. Preview ID 7 uses an
authored pulse radius with no live game. The migration wrapper changes only the
existing migration fixture's project/output paths and uses bounded process-group
ownership; no protocol or acceptance assertions are duplicated.

The gate also runs lower-level Node/View_Pool lifecycle compatibility and wrong
scene-root rejection. Run that subset alone with
`REPLAY_NODES_OUT=/absolute/fresh/path bash tests/replay_nodes/run.sh`.
Raw logs and failed runs should be preserved. No probes ship in the game.
