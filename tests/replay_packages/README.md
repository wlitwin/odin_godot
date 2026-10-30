# Replay Godot package boundaries

```sh
nix develop --command bash tests/replay_packages/run.sh
```

This gate checks that Session/Room orchestration remains separate from optional
transport, storage, scene, input, and debug features. It opens no engine process,
network endpoint, account, or browser. It is included in the 14-gate framework
smoke and the consolidated suite.

It verifies:

- Canonical imports and representative owner operations compile natively and for
  freestanding WASM.
- Moved root names fail with the expected missing-name diagnostic on both targets.
- Compiler documentation exposes at most 160 root declarations, retains the core
  session owners, and contains no re-exports of child-package declarations.
- Core does not import scene/input/debug. Foundational transport/storage/internal
  wire packages do not import core. Collection and relative imports are checked.

The compiler documentation command in the pinned toolchain returns status 1 even
for valid output. The gate first compiles the imports, then validates the package
header, sections, and declarations; an empty/error listing cannot pass the count.

Set `REPLAY_PACKAGES_OUT` to a fresh directory to retain `result.json`, inventories,
and compiler receipts at a chosen path. No generated declaration baseline is
needed: comparing each feature's actual compiler inventory with core catches
compatibility aliases and future feature re-exports.
