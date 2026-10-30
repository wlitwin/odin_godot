# Sustained Scrapyard faults below ENet

```sh
REPLAY_NETWORK_FAULT_OUT=/private/tmp/replay-udp-new \
  nix develop --command bash tests/replay_network_faults/run.sh
```

The gate prepares separate scratch games and runs Replay's real native ENet host
and client through a loopback UDP proxy. App-level delay/loss decorators are disabled.
The proxy delays and drops actual datagrams, including ENet's reliable traffic;
ENet handles acknowledgments/retransmissions/congestion in the real processes.
The old framework and original sibling Scrapyard remain untouched. This is Replay
acceptance, not a Kit/Replay performance comparison.

Both conditions use 120 ms one-way delay plus 0–20 ms jitter and bounded 64-KiB /
128-packet queues. `lossy` injects 5% random loss and duplication; `rate_limited`
uses 2% and a 256-KiB/s per-direction token bucket with a 1,500-byte burst allowance. Queue overflow is an
additional measured drop source. All receive/schedule/forward/drop events are
recorded with identities, sizes, digests and monotonic timestamps. The report
reconstructs accounting, queue peaks and token-bucket credit from these events.

The game uses the existing twenty-second offensive swarm: forty replenished
stock enemies, two stationary bolter users, zero-bite and large-magazine/no-jam
fixtures. Authority population/churn and health/kill/loot conservation must hold.
Clients may use bounded resync recovery, recorded as unavailable-state intervals.
Final receipts must be captured from a live authoritative state and converge on
health, damage, kills, scrap, loot, population and shots after settling. An enemy's
short life may be absent from the client's observational census, so historical
observed-ID count is not treated as replicated game state.

The full contract requires both conditions twice. `REPLAY_NETWORK_FAULT_PILOT=1`
runs one lossy pair and cannot satisfy full acceptance. Optional
`REPLAY_NETWORK_FAULT_REUSE=/path/to/previous-run` verifies compiled content,
framework and exact binaries before copying them into freshly prepared projects;
only the external GDScript driver and isolated namespace may differ.

These are configured loopback datagram faults, not an Internet route, arbitrary
congestion model, browser/SCTP credit test, movement/status workload or human
responsiveness result. Proxy traffic covers its full process lifetime; game
callback/application counters cover their stated measurement window.
