# Godot connection-generation boundary

```sh
nix develop --command bash tests/replay_multiplayer_generation/run.sh
```

A scripted MultiplayerPeerExtension exercises the real adapter's signals and
packet API. The fixture reuses peer ID 7, checks duplicate-connect behavior, keeps
one packet pending behind a short destination, and leaves another in the backend
queue. Both old packets must retire while peer 9's packet and the replacement's
packet retain their proper generations.

Further cases cover packets queued before a new connection, multiple replacements
without draining, whole-connection failure, active-capacity refusal, generation
exhaustion and callback cleanup. A Delay wrapper must discard a retired packet
without dropping another peer's traffic. This is a deterministic API-contract
fixture; real ENet and ENet-backed Steam adapter regressions run separately.
