# Browser qualification

`plan.json` declares the sample populations and bounds before operation timing.
`tests/box3d_web/contract.json` owns the unchanged acceptance thresholds.
The game emits telemetry only when explicitly launched with `profile=1|2|3|4` or
`DOCKYARD_PROFILE=1|2|3|4`. Mode 1 emits batches during play. Mode 2 stores at most
65536 rows in an SDK-metered allocation and emits them after successful
Room/Session close, then frees the allocation before checked cleanup statistics.
The ordinary game leaves telemetry disabled. Each row times the entire existing public `Room.frame`
or `Session.frame` call with Godot's monotonic microsecond clock. No timing
overhead is subtracted. Buffered fields contain values with stable lifetimes.

Rows include the before/after head, confirmation, generation, serial and actual
repair counter. Eight-step repair samples require exactly one committed repair
and actual planned/executed counts of eight. Bootstrap, pump, replacement,
other repair depths, multiple-step advances, errors and outliers remain in the
raw console file. The sampler has a fixed capacity and reports overflow.

`run.py` reuses the existing local Room/Party/TURN runner. It runs two independent
installed browser processes through real production canvas widgets and collects
raw operation batches, presentation intervals, visibility changes, timer deltas,
linear-memory observations, real selected ICE routes and actual five-part final
state/acknowledgement/cleanup evidence. It does not install a test autoload.
Select `Q1_BROWSER=chrome` or `Q1_BROWSER=firefox`. Use a fresh output directory
and a separate copied service project; do not rebuild the service used by an
interactive game or run simultaneous benchmark actors on shared Native inputs.
Select `Q1_BUFFERED=1` for mode 2, as declared in `buffered-plan.json`.

An example inside the development shell, with absolute paths filled in:

```sh
Q1_BROWSER=chrome python3 -B tests/replay_dockyard/qualification/run.py \
  --production-ui --export-record "$EXPORT_RECORD" \
  --service-record "$SERVICE_RECORD" --out "$NEW_OUTPUT" \
  --godot "$GODOT" --ticks 1800 --turnserver "$COTURN" --provider
python3 -B tests/replay_dockyard/qualification/assess.py "$NEW_OUTPUT" \
  --out "$NEW_OUTPUT/assessment.json"
```

The optional `--turn-bind-address` selects a specific private IPv4 interface
for the owned local relay; its default is loopback. It does not establish
public Internet reachability. Browser security preferences are not disabled.
Firefox does not accept Chromium's clipboard permission names through BiDi.
On this macOS reference host its real Copy button is observed using `pbpaste`,
with the original clipboard restored using `pbcopy`; the page implementation
and the production invitation validation remain intact.

Set `Q1_SOAK=1` and `--ticks 36600` for the declared sustained case in
`soak-plan.json`. It attempts the real host NEXT JOB widget after 90 seconds
and then every 10 seconds, requires actual round/layout progression, and
checks at least 600 seconds from the real GO to `SAMPLE_OPERATION_END`, emitted
before close and telemetry serialization. Older artifacts use the checked
result marker. A buffered run must have exactly one end marker and retain every
operation row in sequence; teardown emission cannot extend measured play time.
It retains the first result-panel screenshot and every input attempt. It does
not write Game fields or replace the production action path.

Cold-load admission uses `cold_usable_menu_ms`, which includes visual preparation
and stored-membership readiness. The earlier `cold_lobby_ms` backend marker is
retained separately. The Compatibility renderer draws the real effects during
loading before crew enrollment can acquire a live lease. Tethers and confetti
share the dock's opaque material family; this does not add physics bodies.

The assessor uses nearest-rank quantiles in milliseconds and retains all rows.
An incomplete population or short duration cannot pass the whole contract.
The complete producer transfer is observed through public `complete_inspect`;
the entire attachment is a conservative upper bound on its Native payload,
not an exact Native byte measurement. Memory readings are sampled values,
with the existing Native admission limit and cleanup checks assessed separately.
Browser presentation intervals include startup stalls and live logging work.
All raw intervals remain available; the end marker separates teardown intervals
from the measured presentation population. Terminal Wasm memory is also read
after emission so linear-memory growth during serialization is retained. The
operation boundary does not include separately called presentation/getter APIs.

The later [telemetry experiment](telemetry-report.json) retained all 73798 rows
from a 610-second Firefox 159.0.1/Chrome pair and passed Native/Web cleanup.
Its Firefox normal maximum was 29.56 ms against the unchanged 10 ms limit.
Buffered telemetry did not resolve the rare stalls, whose cause remains unknown.
The earlier candidate report and packaged review archive retain their own hashes
and measurements; this experiment does not relabel them or admit a release.

The [Snapshot signature reuse experiment](tx-signature-report.json) checks work
reduction separately from latency. Its Native fixture counts actual solver-part
materializations, compares all five parts and the complete wire against the
standalone encoder, confirms driver/observer state, and checks corrupt-header
fallback, serialization failure and balanced resources. Run it with a built
Native archive in the development shell:

```sh
odin test tests/replay_dockyard/qualification/tx_signature \
  -collection:godot="$PWD" -define:BOX3D_LIBRARY="$NATIVE_ARCHIVE" \
  -define:ODIN_TEST_THREADS=1 -define:ODIN_TEST_FANCY=false
```

The declared short browser comparison still rejects the original maximum:
30.600 ms baseline and 18.299 ms candidate. Host p95 is 3.799 ms versus
3.800 ms, so a latency gain is not established. Correct complete state and less
duplicate encoding work do not qualify that candidate. A sustained run was not
repeated after its short case had already violated the unchanged threshold.

Mode 3 (`Q1_INTERNAL_PHASES=1` in the diagnostic driver) enables the existing
stateless network profiling clock on the ready authority and reads cumulative
profile metrics around each whole call. It also binds the current external
transaction profiler to Godot monotonic microseconds converted to nanoseconds;
the installed freestanding `core:time` fallback otherwise returns zero.
This override is diagnostic only and is recorded as `external_godot_clock`.
Callback presence alone must never turn an unsupported zero interval into a
zero-cost claim. The [clock validation](godot-clock-report.json) covers actual
Native and Web actors with state agreement and cleanup. Slow rows get a matching
`SAMPLE_OPERATION_PHASES` record; `SAMPLE_PHASE_TOTALS` precedes checked close.
The phases are nested or partial: `Advance` times `r.advance`, `Pump` times its
network pump, and the complete-physics outbound route does not necessarily use
the ordinary `Snapshot` metrics. A zero sample count means unobserved work,
not zero cost. Never sum or subtract these phases into an adjusted call budget.
Epoch/role replacement, total regressions and clock errors invalidate the phase
sample. This mode is diagnostic and cannot qualify the uninstrumented contract.
The external transaction profiler additionally reports open, model-scope and
staged-capture totals/counts/clock errors. They aggregate repeated replay steps
within the most recent transaction. The model scope includes its callback and
accepted-action savepoints; staged capture does not duplicate those nested
savepoint captures. Disabled clocks leave phases unobserved. Backend failures
stay in the operation result and are independent of profiling-clock errors.

Mode 4 (`Q1_COUNTERS=1`) samples existing host counters before the start clock
and after the end clock, with no additional clocks or counter updates inside
`Room.frame`. A separate `SAMPLE_OPERATION_COUNTERS` sidecar matches every row by
sequence. Its 128-row value buffer is allocated only in this mode, metered by
the SDK, and freed during close. The diagnostic cannot qualify the ordinary
timing contract and cannot be combined with the other probes.

`next_id` deltas count successful transfer preparations. Transfer slot tick,
stored bytes, part progress and waiting state are snapshots, not cumulative
send counters. Peer slot details require exactly one remote peer and stable
scope. Server packet/byte totals describe gameplay transport; fragmentation
adds raw RTC messages. Host `executed_steps=0` is an unavailable client repair
metric, not evidence that the host did no work. Lease wall/monotonic deltas
span clock observations and must not replace the measured whole-call duration.

The [frame egress regression](frame-egress-report.json) reproduces a delayed ACK
with a pump-before-step Snapshot for the old head and a separate new-head fact.
It checks one current-head materialization, normative complete-wire equality,
real receiver confirmation, zero-step flushing, permit refusal and balanced
resources. The default standalone pump behavior remains unchanged. This work
reduction is separate from the unresolved strict maximum and requires actual
browser validation before any latency claim.

`Q1_GECKO_PROFILE=1` enables the installed Firefox startup CPU sampler only in
the owned isolated browser processes. It retains four million entries at a
one-millisecond sampling interval and writes per-actor `gecko-profile.json` on
normal browser shutdown. `profile_summary.py` reads those files without starting
processes, reports their retained ring-buffer ranges and leaves unresolved
frames explicit. Such a run is marked `CPU_PROFILER_DIAGNOSTIC_NOT_ADMISSION`;
its timing cannot qualify the unprofiled contract. A failure to reproduce a rare
spike while sampling does not establish its cause or erase the earlier failure.

`Q1_TRACE_FIRST_SLOW=1` stops an owned profiler diagnostic after the first normal
whole-call row over 10 ms. It records a browser clock marker and requests checked
Engine shutdown before closing the browsers, preserving the sampler's recent
window. `trace-plan.json` declares this trigger; the stopped diagnostic does not
claim a complete round, final five-part comparison, or qualification pass.
`trigger_summary.py` reads the retained profile and reports nearby samples and
markers with explicit console-delivery and sampling uncertainty. Its four format
tests cover sparse rows and split marker boundaries, whose unused time fields
must not be interpreted as real intervals.

The broad `Q1_TRACE_SYSTEM` experiment is archived and rejected by the active
runner after malformed, incomplete and failed-save recording attempts.
`Q1_PROCESS_STATE=1` instead uses a companion owned-process controller with
`process-state.controller.json`, ready, stop, saved and failed handshakes.
The runner waits for terminal status while that exact controller is alive.
It is not a standalone option without the companion. `process_state.py` samples
one verified-owned process through read-only `proc_pidinfo`, retaining at most
8192 rows and 8 MiB. Its CPU counters include every thread, use the observed
Mach timebase, and are calibrated against the observer's process clock before
measurement. They are an upper bound for game-thread CPU, not exact call CPU.
The first [bounded observer run](process-observer-report.json) saved about 800 KB
cleanly but captured no slow call; it cannot attribute a missing event.
Never replace missing trace data or a wait timeout with a scheduling-cause claim.
See the retained [causal trace observations](trace-report.json), including failed
recording attempts and unresolved clock alignment.

`Q1_SHADER_DIAGNOSTIC=1` on the startup probe records transparent WebGL method
durations and shader feature summaries through the real visual-preparation
marker, without online configuration. It is a graphics startup diagnosis, not
multiplayer or frame-budget qualification. Its own earlier failed setup and
subsequent corrections remain separate records.

`capability.py` and `automation_probe.py` record bounded startup and automation
prerequisites only. They do not qualify multiplayer, complete state or frame
performance. Actual Safari requires its own working automation prerequisite
and actual runtime evidence before admission; WebKit emulation is separate.

Keep failed attempts, raw files, cold starts, browser versions, source/tool and
artifact hashes alongside the assessment. Local functional success does not
complete the separate public-endpoint, human co-op review or release gates.
