# Browser RTC stress and credit recovery

```sh
REPLAY_BROWSER_STRESS_OUT=/absolute/fresh/build \
  nix develop --command bash tests/replay_browser_stress/run.sh
```

The fixture prepares a separate Scrapyard copy using the existing jam workload
(forty replenished mobs, movement, casts, ten dashes, jam clearing, burn/healing and
conservation). Its browser bridge shares the native workload driver. The report
uses the same extracted gameplay/observation checks and the strict delay policy;
actual RTC message faults are recorded separately. This is not a Kit comparison
or a raw UDP/SCTP packet-loss test.

The data-channel interceptor owns copies of outgoing RPC buffers. It delays
messages by 40±10 ms, preserves reliable order through one FIFO drain per channel,
and applies 5% loss/duplication only to unreliable data. It never erases reliable
control messages. Queues are capped at 128 messages/64 KiB per browser. It is
installed after Replay has charged send credit. Erased messages therefore test
credit-fence recovery: reclaiming send-window capacity for lost unreliable
packets without retransmitting their gameplay payloads. See the
[RTC flow-control rules](../../replay/godot/transport/rtc.md#packet-limits-and-flow-control). A separate post-workload 400 ms blackout requires a new dash,
credit-fence progress and at least ten common canonical world hashes.

Speed-optimized WASM and the available hardware WebGL renderer are used, while
keeping the 1280×704 viewport and the original sample-rate gate. The renderer is
recorded. `REPLAY_STRESS_SOFTWARE=1` selects SwiftShader for a separate diagnostic;
`REPLAY_STRESS_PROFILE=1` records CDP CPU profiles. Software-renderer failures do
not count as passing this workload. RSS is summed browser-process-tree RSS and
must not be compared directly to native single-process RSS.

`execute.sh BUILT_DIRECTORY FRESH_OUTPUT` verifies and reuses an unchanged build
for driver-only fixes or diagnostics. Source and binary hashes are checked before
reuse. Failed runtime receipts are preserved before browser cleanup. Only owned
processes are shut down. The first two synthetic members use the existing local
signaling fixture with its explicit expected member count of two.

RTC limits staged unreliable datagrams to eight per destination, in addition
to its existing 16 in-flight credits. The large-message exception and ordinary
memory limits preserve sendability without queuing several stale worlds. The
fixture checks that bound, records memory/credit high-water marks, and waits up to
15 seconds after blackout for an acknowledged checkpoint to advance. This proves
replication progress, not a maximum checkpoint age or migration availability.

The queue-priority candidate was rejected after it did not resolve freshness.
It is not part of the implementation. FIFO timer, startup and cleanup fixes belong
to this harness; their earlier failures are retained separately from library data.
