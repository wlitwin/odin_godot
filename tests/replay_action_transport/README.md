# Controlled action delivery on real ENet

```sh
REPLAY_ACTION_MODE=heartbeat REPLAY_ACTION_OUT=/absolute/fresh/heartbeat \
  nix develop --command bash tests/replay_action_transport/run.sh
REPLAY_ACTION_MODE=action REPLAY_ACTION_OUT=/absolute/fresh/action \
  nix develop --command bash tests/replay_action_transport/run.sh
```

Two native Godot processes run a receipt-action model. The UDP proxy adds 120 ms
in each direction, then drops exactly one armed upstream datagram. Heartbeat mode
excludes action/copy envelopes and submits the action only after the heartbeat
was dropped. Action mode targets the sole primary action and excludes copy bundles, whose
nested Action envelopes must not be mistaken for a primary. ENet retransmission remains real.

Each run requires one applied action, a matching final outcome, no capacity/socket
errors and a round trip no greater than 450 ms. The proxy records the dropped
packet's hash and validated application envelope kinds. `REPLAY_ACTION_CAPTURE_ONLY=1`
records a pre-change implementation without applying the new latency/channel gate.
It still requires eventual delivery and exactly one targeted drop.

The launcher captures source/binary hashes and waits for editor rebuilds before
its final build. Use a separate collection/project for a before implementation;
do not overwrite a live or unrecorded binary. These individual regressions are
separate from full-game acceptance and general latency percentiles.
