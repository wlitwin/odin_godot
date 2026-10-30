# Snapshot ACK loss over real ENet

```sh
nix develop --command bash tests/replay_ack_transport/run.sh
```

Two native Godot processes use Replay over ENet with a 4 KiB world, snapshot
parts, receipt-time actions and 120 ms raw UDP delay in each direction. After
warmup, the proxy drops exactly one datagram containing a snapshot ACK. It excludes
datagrams carrying other application reliable messages; neutral input envelopes
may share the packet. The client submits one action only after the drop receipt.

The action must receive one applied outcome within 450 ms. The client's armed
send probe must report only unreliable snapshot ACKs. The proxy must record one
targeted drop, with no capacity drops or socket errors. `proxy_test.py` checks
message-kind selection and envelope checksums; the protocol-7 input kinds are 4
and 15, while Action is 5 and Features is 16 and must be excluded.

`REPLAY_ACK_CAPTURE_ONLY=1` retains observations without applying the new ACK-mode
or latency gate, for a deliberately captured older implementation. Outputs include
the client receipt, targeted-drop metadata and raw proxy packet hashes. This is a
controlled transport regression, not a general network-latency guarantee.
