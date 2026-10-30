# Slopball browser-local checkpoint acceptance

```sh
REPLAY_SLOPBALL_BROWSER_SAVE_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_slopball_browser_save/run.sh
```

The runner builds an isolated native app, runs UI/profile/WASM prerequisites and
exports speed WASM. Chrome uses an isolated origin/profile. It scores through real
physics, saves while moving, checks that Leave is blocked during the write, and
waits for a durable receipt. An independent Odin reader decodes the actual IndexedDB
checkpoint before Chrome is SIGKILLed.

A fresh browser must retain identity/name, restore the exact saved world in a new
epoch and seed its actual solver from the independently decoded pose/momentum.
New kicks and a goal, Play again, another save and automatic URL resume follow.
The 3D source additionally requires nontrivial quaternion orientation and spin.

Two tabs load the same revision: one commits, the stale writer must fail and keep
the committed bytes/revision. Corrupt slots and identity records are preserved;
invalid labels are refused and an alternate slot can be saved. Corruption occurs
only inside the isolated fixture profile, and the fixture restores original bytes.
Graphics errors are rejected. Companion Party gates check that publication creates
no local slots.

`execute.sh WEB_OUTPUT FRESH_RESULTS` reuses a prepared export. `verify/` decodes
its stored source checkpoint independently. Raw browser profiles, identity bytes
and checkpoint files are private; archive decoded receipts and hashes instead.
