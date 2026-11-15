# P2P timing and benchmark contract

Use P2P profiling to measure step, replay, checksum and pump costs, and the delay
between local input capture and simulation. Profiling is optional runtime state. It is excluded from the match contract,
canonical state, archives and checksums. Enable it with a monotonic microsecond
clock after creating or restoring the Runner:

```odin
p2p.profile_set(&peer, replay.Profile_Clock{user = clock_data, read = clock_read})
samples := peer.profile.metrics[.Replay]
p95_upper_us := replay.timing_percentile_upper(samples, 95)
```

`profile_set` resets metrics and pending capture marks. Use it whenever changing
clock domains; assigning a new clock directly could combine incompatible timestamps.
Passing an empty clock disables collection and frees capture-mark storage. Destroy
frees it as part of the Runner. A failed/backward clock records diagnostic errors
without changing gameplay or network policy. Disabled collection has no clock calls
or capture allocation. The remaining branches are still part of runner execution.

| Metric | Measured interval |
| --- | --- |
| `Step` | One attempted forward `Timeline.advance`, including state/input validation and commit |
| `Replay` | One attempted suffix revision, including prediction rewriting and staged simulation |
| `Hash` | One confirmed canonical state/event chain update |
| `Pump` | Protocol polling/decoding, repair, confirmation, retransmission and timeout work |
| `Input_Latency` | Local input capture to the end of the first successful forward step that uses it |

Step/Replay/Hash/Pump are **operation wall times**, not CPU accounting. Pump contains
some replay/hash intervals, so their totals must not be added together. They exclude
Godot rendering, normal event-journal processing and game UI; the clock itself adds
measurement overhead. Histogram percentiles are conservative bounds. The final
overflow bucket uses the maximum observed duration. Zero samples return zero.

Input latency is separate from work time. A configured delay of `D` at `hz` gives
`D/hz` seconds of nominal scheduling delay; waiting at the prediction horizon and
frame catch-up change elapsed time. The metric covers the captured value, including
held/neutral inputs, and records it once on first application. It does not measure
device polling delay, an engine render submission, physical display latency or final
confirmation. A restored future input has no valid timestamp from the new process,
so it contributes no latency sample. Samples begin with newly captured inputs.
`stats.max_replay_depth` records the maximum completed successful revision depth.
The authoritative runner's `net.Profile_Clock` aliases the same clock type, so one
provider can instrument both runner styles. Keep borrowed clock user data alive
until profiling is disabled or the runtime is destroyed.

## Measurements

```sh
nix develop --command bash tests/replay_p2p/bench.sh
REPLAY_KEEP_LOGS=1 nix develop --command bash examples/replay_duel/profile_run.sh
```

The native benchmark executes two complete peers plus deterministic Memory transport
for 2,400 ticks. LAN and faulted two/eight-delay cases use the same inputs, including
eight initial neutral ticks, and must produce the same whole reference world and
event chain. The fault clock is accelerated: seven latency ticks, two jitter ticks,
10% loss and 10% duplication. CPU is measured with `getrusage(SELF)` user+system time;
wall time uses a monotonic clock. Setup, reference construction/comparison and cleanup
are excluded. Memory transport and codec work are included. These totals are not
per-peer CPU or Godot CPU measurements.

Five measured trials follow a warm-up per case, alternating profiling on/off order.
The report uses medians and verifies identical protocol work with profiling enabled.
Its operation histograms describe the optimized native build. Input-latency samples
are intentionally omitted from this accelerated-loop report because they would
describe execution speed, not real-time network delay. The benchmark is a standalone
measurement tool; it imposes no machine-dependent performance threshold.

The Godot comparison runs actual ENet processes with 120 ms receive delay per side,
0–20 ms jitter, 10% loss and 10% duplication. It compares two/eight input-delay ticks,
an eight-tick prediction limit and the same 600-tick input sequence (eight initial
neutral ticks). Both configurations verify the same whole world; each reports
capture-to-simulation latency, work timing, replay depth, waiting attempts, elapsed
time and dropped render-clock accumulation. Results are individual-run observations,
not a hardware-independent responsiveness guarantee or a Kit-versus-Replay comparison.

Set `RDP_PROFILE=1` on other Duel runs to collect timings. `RDP_DELAY` and
`RDP_PREDICTION` select the fixed protocol configuration; all participants must agree.
`RDP_NEUTRAL` controls only the automated fixture's initial neutral-input prefix.
