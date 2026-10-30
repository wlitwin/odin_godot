# Tagged-union acceptance

```sh
nix develop --command bash tests/replay_unions/run.sh
nix develop --command bash tests/replay_unions/enet_run.sh
```

The target corpus compares actual native/WASM execution, default/optimized builds,
and x86-64 execution when Rosetta is available. The ENet project demonstrates typed
`Take`/`Put` actions, optional `Move` controls, `Coins` state and `Taken`/`Returned`
events. It transfers three coins to the host, two to the client, then returns one
and two respectively. The final chest contains three, the host two, and the client's
pocket is nil. Both processes compare their canonical world hash.

The ENet fixture uses 120 ms receive delay, 20 ms jitter, 5% loss and duplication.
It counts final Begin/Confirm events correctly: a speculative Begin is not itself
a final delivery. Capture/restoration and deterministic transport faults are also
covered by `tests/replay_net/union_test.odin` using this shared model.
