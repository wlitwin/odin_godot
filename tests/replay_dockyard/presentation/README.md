# Presentation evidence

`controls.py` stages the actual view, authored visuals and display settings in a
temporary project and exercises real Godot input events with a copied-state
fixture and control sink. It checks nearest-load selection for each robot,
retaining a moving load until release, reacquisition, delivered/lost exclusions,
menu/settings/observer suppression, movement/boost while hauling and instruction
layout at seven window sizes. It requires no Native library and supplies no
physics or network verdict.

```sh
python3 -B tests/replay_dockyard/presentation/controls.py --godot "$GODOT"
```

## Remote robot turning

The upright shell used the displacement between two rendered poses as its facing
direction. A position correction could point backward while the robot continued
moving forward. A vertical bounce could also trigger `atan2(0, 0)`. Dockyard now
reads each robot's horizontal velocity from the same complete checkpoint as its
pose. Below 0.2 m/s it holds its heading. The turn response uses elapsed render
time and matches the previous blend at 60 Hz. The rolling physics sphere, cargo
poses, and magnet targeting still use the simulated positions.

The native trace came from two Godot processes running the carry controller for
1,800 ticks on macOS arm64, with 100 ms added round trip, 5 ms jitter on each
receiver and 1% unreliable loss. `remote-heading.csv.gz` records the joining
client's view of the host robot before the change. Each row contains the head
tick, render delta in seconds, actual shell yaw in radians, checkpoint velocity
(x/z in m/s), and displayed position (x/z in metres). The control test replays
the identical samples through the current facing function. It also tests genuine
180° reversals, near-rest vertical motion, both seats, and 30/60/120 Hz response
using the real view and mock presentation input.

| Same trace, 1,740 successive render intervals | Previous shell | Velocity-driven shell |
| --- | ---: | ---: |
| One-frame turns over 25° | 16 | 5 |
| 99th-percentile one-frame turn | 23.9° | 13.0° |
| Near-rest turns over 5° | 2 | 0 |

The comparison excludes the first 60 ticks and the stopping boundary. Ten
moving intervals had a displayed displacement pointing against physics velocity.
The 95th-percentile lag behind physical heading was 15.0° before and 17.7° after
on this trace. The reduction is in abrupt false turns. Independent ENet runs of
the original and changed game each ended with both peers agreeing on the
complete state and no stalls or resyncs.

The remaining cost is predicting another driver's next input. With a stationary
guest and identical deterministic transport settings, changing the host's
direction every eight ticks instead of every 60 increased corrections from 29
to 224 in 30 seconds. Replayed steps rose from 313 to 2,360 and p95 predicted
remote position error rose from 12.5 to 17.6 cm. All 15 complete-state comparisons
matched in each case. That positional error remains visible when an input reversal
reaches the predicting client.

Two rendered Chrome 157 processes on an Apple M3 also passed Host/Join on the
ordinary export and agreed on all five state parts. In the separate 1,800-tick
scripted timing run, p95 client `Room.frame` was 1.09 ms for a one-tick advance,
1.61 ms for confirmation without replaying a suffix, and 4.10 ms when replaying
a suffix. The last group had 838 calls and a maximum of 5.62 ms. The ~83 ms
client pump outlier occurred at tick zero. These are whole networking/simulation
calls, excluding rendering, on local WebRTC with injected conditions. Public
relay routing and other browsers were outside this run. Normal play now reads
the full diagnostic JSON only while F3 is open. The grade of evidence for that
change is the eliminated calls. Its effect on total frame time remains unmeasured.

The [measurement report](remote-motion-report.json) includes sample counts,
tails, CPU groupings and position errors. The deterministic reversal case can
be rerun with the [netsim harness](../netsim/README.md).

## Remote position smoothing and the cost of a tick

Dockyard stores the last raw position it displayed for the other robot on a
predicting client. When Replay repairs history, the view reads that *same tick*
from the repaired history and gives the difference to `Smoother3`. The mesh
offset decays with its default 80 ms half-life. A new body lifetime, changed
connection or epoch, missing history, or a correction above the smoother's cut
distance clears the offset. The local robot and cargo use their simulation poses.
The visible beam connects the displayed mesh to the load. Grab selection and
aim use raw positions.

Two native ENet processes ran the carry controller and a second case in which
the host reversed every eight ticks. Each case lasted 1,800 ticks at 100 ms
added RTT, 5 ms receive jitter and 1% unreliable loss. Each client observer
recorded raw and displayed positions on the same render frames. The residual
below is horizontal displacement minus the movement explained by the current
velocity and elapsed simulation ticks, measured in centimetres. It includes
ordinary acceleration. Both peers agreed on complete state in both runs.

| Client measurement | Hauling | Rapid reversals |
| --- | ---: | ---: |
| P99 residual, raw → displayed | 9.78 → 1.58 cm | 30.21 → 3.09 cm |
| Residual over 5 cm, raw → displayed | 21 → 0 | 218 → 0 |
| P95 distance between mesh and simulation | 6.16 cm | 16.66 cm |
| Maximum distance between mesh and simulation | 18.87 cm | 24.75 cm |

The local mesh offset was zero throughout. Both magnets pulled the same load
for 1,097 recorded frames, with beam endpoint error below 0.001 mm. A separate
native probe timed the new smoothing work outside `Room.frame`. Its p95 was
3 µs without a historical read and 94 µs when a repair required that read.

The earlier **1.09 ms** was p95 for the entire ordinary one-tick client
`Room.frame` in Chrome. To break it down we timed the network pump, timeline
advance, world open, game callback and checkpoint capture. An extra pair of
clocks bracketed `ph.step`, which includes the four-substep solver, reading
sensors and command bookkeeping. The isolated diagnostic collected ordinary
one-tick advances with exactly one open, model and capture after tick 50.
The phases nest, and percentiles do not add up to the whole frame.

| Client phase, before optimization | Chrome median | Chrome p95 | Native median |
| --- | ---: | ---: | ---: |
| Network pump | 0.019 ms | 0.045 ms | 0.008 ms |
| Open working world from checkpoint | 0.144 ms | 0.340 ms | 0.199 ms |
| Complete game callback | 0.156 ms | 0.411 ms | 0.171 ms |
| Managed physics step inside callback | 0.116 ms | 0.336 ms | 0.104 ms |
| Capture next checkpoint | 0.125 ms | 0.251 ms | 0.152 ms |
| Timeline advance, including publication | 0.625 ms | 0.960 ms | 0.725 ms |
| Whole call | 0.840 ms | 1.195 ms | 1.004 ms |

These runs used an Apple M3, rendered Chrome 157 over local WebRTC and native
headless Godot 4.7.1 over ENet. The native call is `Session.frame`; the browser
call also includes Room orchestration. The native timings establish that the
checkpoint costs occur outside the browser too. Rendering and presentation
getters are outside both whole-call timers.

The SDK now validates immutable C/Odin layouts once per module, and each loaded
native image memoizes its own build and target contract. Each operation still
checks the caller's actual domain and owner. A standalone matching-domain
check fell from a median 75.19 ns to 5.21 ns over five batches of a million
calls. In an old/new/new/old comparison of ordinary browser exports, one-tick
p95 was 1.15–1.19 ms in *both* versions. P95 for calls replaying a suffix was
4.14–4.26 ms before and 3.79–3.94 ms after. Peer inputs and packet timings vary
across live runs. The remaining normal-tick target is opening and retiring a
working world each tick while preserving error-path atomicity and exact replay.

The Box3D source change gives the native/Web backends a new build identity.
The online service and players need the matching Web cohort when rolling this
out. The [timing and alignment data](smoothing-cost-report.json) retain the
individual run distributions, benchmark scopes and cohort IDs.

### How much of a correction is physics?

The 3.79–3.94 ms p95 above times the joining client's `Room.frame` on calls
that replayed at least one tick. It includes receiving inputs, repairing history
and advancing the current simulation when due. The two runs replayed a median
of 15 ticks per correction, and 1,594 of 1,635 such calls also advanced one
new tick. Browser presentation was measured separately. Across those same
two runs, the median interval between animation callbacks was 16.67 ms and
the p95 was 17.57–18.26 ms, from startup through the end-of-play marker.
These intervals include waiting for the display.

Three 1,800-tick pairs on the Apple M3 measured the cost inside the repair.
Both players used the carry controller. The 100 ms cases added 50 ms receive
delay at each peer, 5 ms jitter and 1% unreliable loss. Each cell with two
values gives the median and p95 across corrections on the joining client.

| Client and transport | Corrections | Ticks replayed | Whole update | Checked revision | Managed physics inside revision | Checkpoint capture inside revision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Chrome 157, WebRTC, 100 ms added RTT | 845 | 15 / 21 | 3.29 / 3.89 ms | 2.89 / 3.42 ms | 0.75 / 0.99 ms | 0.83 / 1.04 ms |
| Chrome 157, WebRTC, local with no added impairment | 1,076 | 7 / 11 | 2.37 / 2.87 ms | 1.96 / 2.45 ms | 0.47 / 0.69 ms | 0.49 / 0.66 ms |
| Headless native Godot 4.7.1, ENet, 100 ms added RTT | 837 | 12 / 16 | 5.47 / 7.65 ms | 4.58 / 6.57 ms | 0.83 / 1.23 ms | 1.63 / 2.47 ms |

In the 100 ms Chrome run, dividing each revision by its actual tick count
gave a median **0.184 ms per replayed tick**, including the cost of opening,
checking and publishing the revision. The corresponding averages for managed
physics and checkpoint capture were 0.048 and 0.053 ms per tick at the
median. Across all 13,321 replayed ticks those phases accounted for 26% and
29% of checked revision time. Checkpoint capture is a candidate for further
optimization as the world grows. On every replayed tick it serializes a
restorable solver image and writes a separate normalized representation for
comparison. At exactly 15 replayed ticks, median revision
time was 2.80 ms in Chrome (477 corrections) and 4.91 ms in native Godot
(75 corrections). The runs used different transports and builds.

The probe ran in isolated copies of the game at `df5f5f7f`. It read Replay's
`Physics_Repair` duration immediately after `revise_inputs_checked` returned,
while that transaction's world-open, model and capture counters were still
available. It also bracketed every `ph.step`, matching tick IDs to the repaired
suffix. This includes all four solver substeps, the sensor read and command
bookkeeping. Each sampled revision had one open and one model and capture
sample per replayed tick. Sample counts and depths covered every correction
and replayed tick reported by the client. All three pairs finished at tick
1,800 with identical bytes for all five canonical parts, zero resyncs and
clean teardown. The per-correction timings are in [the compressed CSV](repair-cost.csv.gz).

### Checkpoint capture and retained memory

Replay previously reserved the profile maximum of 8,192 sensor events in
every captured and cloned image. Each image now owns exactly the completed
events from its tick, in the same allocation as its header. In a seeded
30-second native run with 128 history slots, the client replayed the same
10,586 ticks in both versions. Its final charged history fell from 41.05 to
17.05 MiB. An empty-event initial image fell from 331,424 to 134,824 bytes.
All five canonical parts matched across versions and peers at 15 checkpoints.

Four 1,800-tick Chrome runs used the same repair probes and network conditions
as above, in new/old/old/new order. Median capture time per replayed tick went
from 52.4–52.5 µs to 47.7–49.0 µs. P95 went from 64.7–64.9 µs to 60.2 µs.
Whole-update p95 ranged from 3.94–3.98 ms before and 3.88–4.03 ms after.
Every peer pair reached byte-identical final state and released its resources.

We also measured the cost of the two native representations. Across 12,389
client captures, writing the restorable solver image averaged 4.7 µs and
building its normalized comparison bytes averaged 10.4 µs. In a separate
two-player run, 3,378 of 14,189 distinct images had their normalized bytes read.
A first-read experiment retained the required size at capture time, restored
the historical state into a temporary world, and filled the comparison buffer.
Every read matched the eager bytes. Across three repetitions the projected
saving averaged about 1 µs per capture, and reading required spare world
slots. Replay keeps the eager comparison data so detached reads work when
those slots are occupied. The [measurement report](checkpoint-capture-report.json)
includes the per-run timings and exact byte totals.

`run.py` reuses the bounded online runner and actual production menu inputs. It
opens two headed Chrome processes with rendering enabled and without software-GL
fallback flags, records the actual WebGL renderer/viewport/DPR, captures play and
settings screenshots and uses Puppeteer's real page recorder with installed
FFmpeg. The WebM recorder outputs 30 FPS; this is not a measurement of game FPS.
The complete state, acknowledgement and typed teardown checks still run.

The page initializer inserts a pass-through WebAudio analyser in the real
destination graph. It records output RMS and context state; it does not inject
test audio. Nonzero signal proves rendered audio output, not a human hearing or
usability judgment. The sound samples are original deterministic synthesis from
`make_audio.py`, with provenance beside the generated assets.

```sh
nix develop --command python3 -B tests/replay_dockyard/presentation/run.py \
  --production-ui --ticks 6000 \
  --export-record /ABS/ordinary-export/report.json \
  --service-record /ABS/prepared-service/report.json \
  --out /ABS/NEW-render-case --godot /ABS/Godot
```

The caller-selected 6,000-tick/360-second capture bounds do not change the shared
runner's shorter functional defaults. No backend, model, controller, round rule
or collision-profile change is needed for audio/particles. Confirmed boost and
delivery/latch cues populate a 16-entry local presentation FIFO; the view consumes
each sequence once. The latch thud/score chime is not a claim of a newly exposed
Native collision-contact stream.

`serve.py` starts a private, local-only interactive server from an actual accepted
production export and binds it to the accepted cohort. The existing room service
issues authenticated expiring relay credentials to the ordinary browser. Private
keys, databases, TURN configuration and browser profiles must not be published.
It emits `INTERACTIVE_ONLY_NO_GAME_VERDICT`, never a human-gameplay PASS.
Use distinct browser profiles for separate memberships; the URL is local to the
reference machine. Real two-person co-op feedback remains separate and required.

Actual presentation captures do not qualify the final hardware time/memory/load
contract. Q1 measures those boundaries on the final frozen candidate, retaining
all raw samples, failures and outliers.

## Viewport and DPI checks

`layout.gd` loads the actual prepared SDK scene and checks seven window sizes:
corner margins, panel bounds, centered modals, camera fit and pointer projection.
The fixture observes real Controls and changes their visibility only for modal
geometry checks; it supplies no simulation or networking verdict.

```sh
DOCKYARD_LAYOUT_OUTPUT=/NEW/layout.json GODOT --headless --path /ABS/SDK/PROJECT \
  --script /ABS/REPO/tests/replay_dockyard/presentation/layout.gd
node tests/replay_dockyard/presentation/layout.mjs /ABS/EXPORTED_WEB_DIR /NEW/OUTPUT
```

The browser check runs the ordinary Web export through eight CSS-size/DPR
arrangements, including normal and 2× DPI, small landscape, ultrawide and portrait.
It checks actual corner placement, centered settings, field hit targets, the
native room-code dialog, matching CSS geometry across DPR values, screenshots
and full engine exit. Software WebGL is allowed for this layout check; these are
not GPU performance or mobile-support results.

The read-only `ui_layout=1` query (or native `DOCKYARD_LAYOUT_PROBE=1`) emits
settled Control rectangles on layout/focus changes. It is disabled by default
and contains no field text or invitation codes. The online UI harness uses those
logical rectangles and the canvas's CSS bounds to target controls after resize.
