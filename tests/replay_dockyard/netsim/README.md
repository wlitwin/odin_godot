# Dockyard network-condition harness

`main.odin` runs the actual Dockyard model (authored world, rules, complete
Box3D codec) as a listen host and one predicting client in one process, joined
by the deterministic `Memory` transport with per-direction latency, jitter,
loss, reliable retransmission with head-of-line blocking, and a bandwidth
serialization queue. Dockyard's own carry controller drives both seats from
each side's own view, and each side renders on its own jittered frame clock and
drives the runner the way `replay/godot` `session_frame` does.

It reports what a player feels and what the wire costs: host-held (late) client
inputs, client stalls and frozen frames, prediction depth, lead and arrival
margin, raw local-robot snaps against the authority's own baseline, displayed
local/remote robot error against the authority pose for the same tick, runner
CPU per frame, bytes per second, and a complete-state (solver dump + game)
equality check every two seconds.

```sh
nix develop
# definition.json comes from tests/replay_dockyard/rounds/extract.gd on a prepared project
bash tests/replay_dockyard/netsim/build.sh /abs/libogb3.dylib /abs/definition.json /tmp/netsim
/tmp/netsim/netsim rtt=100 jitter=10 loss=100 kbps=5000 seconds=60   # one condition, JSON line
python3 tests/replay_dockyard/netsim/matrix.py /tmp/netsim out.jsonl seconds=60 [delay=4]
```

`godot_pair.py` runs a scripted native host and client over real ENet in two
Godot processes with Dockyard's `DOCKYARD_LATENCY/JITTER/LOSS` options and
checks that both end on the same complete signature.

## 2026-11-04 results (macOS ARM64, native Release, 60 s per condition)

Conditions: `rtt` is the round trip, jitter one tenth of it, 1% loss on both
channels (0.5% at 50 ms); the last two rows add a per-direction bandwidth cap.
Raw rows: [before](results/before-8tick-window.jsonl), [after](results/after.jsonl),
[after with input delay ≤ 4](results/after-input-delay4.jsonl), and the
intermediate [window](results/step-window30.jsonl) and
[status-protocol](results/step-status-protocol.jsonl) steps. Every run's
equality checks matched.

| Condition | Client inputs late at host | Frozen client frames | Big local snaps/min | Host upload kbit/s |
| --- | --- | --- | --- | --- |
| LAN | 0% → 0% | 0% → 0% | 0 → 0 | 22,594 → 416 |
| 100 ms | 47% → 0.2% | 7.6% → 0% | 30 → 0 | 3,358 → 416 |
| 150 ms | 99.9% → 0.3% | 10.9% → 0% | 0 → 0 | 2,420 → 416 |
| 200 ms | 99.8% → 0.4% | 12.9% → 0.03% | 3 → 0 | 1,950 → 416 |
| 100 ms, 10 Mbit/s | 81.5% → 0.3% | 12.8% → 0% | 45 → 0 | 2,706 → 416 |
| 100 ms, 5 Mbit/s | 99.2% → 0.4% | 12.5% → 0% | 50 → 0 | 2,295 → 416 |

The authority's own robot (no corrections) shows 2–8 big second-difference
events per minute from ordinary driving; that is the noise floor of the snap
column. Displayed local-robot error p95 at 100 ms fell from 2.0 cm to 0.1 cm.
Client runner CPU p95 per frame fell from 1.3–1.6 ms to 0.45–1.2 ms despite
predicting up to 19 ticks instead of 8.

Prediction depth now follows the round trip (p95 12 at 100 ms, 19 at 200 ms)
instead of pinning at the old window of 8. Predicting further ahead keeps the
local robot responsive but guesses the other player further ahead too: remote
robot error p95 is 2.3 cm at 100 ms and 10.5 cm at 200 ms. Input delay
(`delay=4`, from 100 ms) cuts that to 0.8 cm and 5.1 cm and depth to 10 and 15,
for up to four ticks of local input lag.

### Real Godot pairs

`godot_pair.py`, two headless native Godot processes over ENet, scripted carry
play for 3,600 ticks, jitter one tenth of the one-way delay, 1% unreliable
loss. Both sides ended on the identical complete signature in every run.

| Round trip | Input delay | Host-held client inputs | Client stalls / resyncs | Max prediction ahead | Host upload |
| --- | --- | --- | --- | --- | --- |
| 100 ms | off | 9 of 3,600 | 0 / 0 | 16 | 417 kbit/s |
| 200 ms | off | 16 of 3,600 | 0 / 0 | 21 | 417 kbit/s |
| 200 ms | ≤ 4 | 16 of 3,600 | 0 / 0 | 19 | 417 kbit/s |

## What changed and why

1. **Window.** Physics mode allowed eight ticks of prediction. Confirmation lags
   the client's head by the round trip plus the three-tick arrival reserve, so
   the window was already full on one machine and could not keep inputs on time
   past roughly 80 ms. The lead controller then sped into the cap, stalled and
   dropped controls, while the host held stale inputs. Default is now 30 ticks
   (`PHYSICS_DEFAULT_WINDOW`, ceiling `PHYSICS_WINDOW` 32), and the controller no
   longer speeds up when the window is nearly full.
2. **Steady-state traffic (wire revision 2).** The host sent a complete image
   (about 42 KB) per round trip on the same ordered reliable channel as facts.
   Drivers now confirm from facts carrying a 32-byte complete digest, receive a
   small `Physics_Status` for lead feedback, and get every fact twice (reliable
   plus an unreliable copy) so one loss does not stall the stream for a
   retransmission. Images remain for Welcome, mismatch requests and spectators.
3. **Correction work.** Confirmations re-simulated the whole predicted suffix
   even when nothing changed. They now start at the first step-relevant input
   difference (or skip entirely), and Dockyard zeroes aim while not grabbing so
   a driving player's held input predicts exactly.
4. **Image cost.** A Box3D step was ~0.015 ms but saving its image ~0.33 ms,
   nearly all byte-serial FNV hashing: the seal on every capture/clone/restore
   and an eager complete digest. The seal is now a word-parallel hash (every
   validation retained), the digest is computed on first request, and contract
   hashes are cached per image.
5. **Optional input delay.** Quantum-style input offset, off by default.
