# Production validation

The production runner uses the ordinary authored Kit and Replay exports. Each
framework/target/case has a fresh output directory and separate evidence. Current
runner source and pure Python checks alone establish no exported result. Actual
current runs are recorded in the [production report](../../../tests/box3d_production/report.json).
Existing Gate B, Gate C and desktop reports remain their original scoped evidence.

## Recorded production runs

The 2026-11-02 execution used the four-body/four-asset/one-hinge authored scene,
two real exported processes per pair, and scripted inputs from both seats.

| Target | Framework | Observed seconds after both GO | Final confirmed tick | Sampled per-process RSS peak, bytes |
| --- | --- | ---: | ---: | ---: |
| macOS arm64, native | Kit | 1809.9187175 | 108600 | 122404864 |
| macOS arm64, native | Replay | 1809.173003958 | 108600 | 128974848 |
| Linux x86_64, translated | Kit | 1810.3640276289989 | 108600 | 181174272 |
| Linux x86_64, translated | Replay | 1809.417124058 | 108600 | 185798656 |

All four pairs matched the five complete state parts byte-for-byte at the target,
observed their real terminal signature ACK, exited naturally with code0, drained
and fsynced intake, and returned Native/wrapper/Meter allocations and sample-owned
owners to their observed baselines. Peak tracked admission was16621917 bytes,
below67108864. Both300ms and3000ms service-pause cases passed on every pair;
actual observed head gaps were16–17 and176–179 respectively. Kit used validated
canonical recovery; Replay's short pause used bounded same-scope catchup and its
deep pause used validated canonical recovery.

The shared-domain64MiB refusal/preservation/resume checks and public H128/window
tests have separate records. Ten current Native whole-call streams retain all190
CPU samples: none exceeded4ms and the largest was3.572ms. The analyzer's individual
normal-only/repair-only coverage labels remain INCOMPLETE; this is no combined
hardware or general application CPU qualification. The older8.894ms failure is
preserved with cause unknown.

These are bounded headless functional observations. RSS is outside the tracked
physics quota, includes startup and teardown, and establishes no longer-horizon
bound. One Linux RSS endpoint was0 during exit; it remains in the raw record and
is not used as a leak diagnosis. The task container's OOM-kill counter stayed1
before/after the corrected runs; that existing count and historical peak belong
to the preserved earlier failed run. No resource limit or counter was reset.

Native Linux hardware, remote CI execution, cross-target state equality, packet
loss/jitter certification and manual visual/usability qualification remain outside
these records. The remaining hardening cards and whole project are not complete.

## Commands

`tests/box3d_production/runner/run.py` defaults to writing `plan.json` with
`STAGED_ONLY` and zero jobs. Tools and Native inputs are explicit absolute paths;
the output must be new and outside the repository. A typical declaration is:

```sh
python3 tests/box3d_production/runner/run.py \
  --target macos-arm64 --framework kit --case functional \
  --godot /absolute/Godot --odin /absolute/odin \
  --native-library /absolute/libogb3.dylib --native-sha256 "$NATIVE_SHA256" \
  --out /absolute/new-case-output --port 42120
```

Add `--execute` only for an assigned actual run. It invokes the existing normal
export helper, then `runner/controller.py` against the actual export record and
exported executable, with `--headless` and no project/runtime-library override.
`--framework replay` selects the sibling implementation. Linux uses
`--target linux-x86_64`, explicit `--execution-mode native` or
`translated-linux-x86_64`, and `--toolchain-report /absolute/preflight.json`.
It runs inside the selected Linux userspace. Native hardware and translated
functional evidence remain distinct; the runner validates actual tool hashes
against the existing desktop preflight contract. No VM is started by this CLI.

| Case | Terminal tick | Required workload | Minimum observed duration | Supervisor |
| --- | ---: | ---: | ---: | ---: |
| `functional` | 120 default; explicit 120–3600 | terminal | 0 | 180 s default |
| `long` | 108600 | 108000 | 1800 s after both actual GO observations | 2400 s |
| `pause300` | 1200 default | terminal | actual stopped interval ≥300 ms | 240 s default |
| `pause3000` | 1200 default | terminal | actual stopped interval ≥3000 ms | 240 s default |

Short declarations accept `--ticks` and `--timeout`; pause cases also accept
`--pause-at` (default confirmed tick 240), with at least 512 ticks of observation
window plus 120 future ticks before the terminal target. The long declaration
is fixed: 600 extra terminal ticks provide duration-observation headroom without
lowering the required 108000 ticks or the measured 1800 seconds.

## Controlled logging and delivery/service pause proof

Every production case adds the bound, test-only `pause_overlay` to a new derived
project through `--project-overlay` and `--project-overlay-sha256` on the normal
export helpers. Both flags are paired; ordinary exports without them retain
their default flow. The overlay descriptor, source bytes, helper, copied script
and derived project settings are hashed and checked before accepting the export.
Overlay version 2 sets `application/run/flush_stdout_on_print=true` only in that
derived project's `[application]` section, recording the prior presence/value,
new value and before/after project hashes. Godot documents this setting as
flushing stdout for each printed line; release defaults differ from debug.
See the [official ProjectSettings reference](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-application-run-flush-stdout-on-print).
This is a controlled logging choice, not proof of the old buffered-arrival cause.
Old buffered exports/reports remain unchanged. Functional/long cases set no
pause environment variables, so the overlay's process callback is inactive.

The autoload calls the existing public sample `status()` after normal processing.
It requires actual GO and available live head/confirmed values. The Client emits
its original status JSON, then immediately invokes synchronous self SIGSTOP.
No Session/World frame, network advance, input or reset call occurs between that
getter and the stop. The external controller verifies the exact owned PID/PGID
in state `T`, waits the declared interval, verifies `T` again and resumes only
that PID. A bounded Host observation window retains at most 529 live public
head boundaries; the resume proof requires a recently received boundary and an
actual head gap strictly greater than 8 or 128. Intake timestamps describe
external observations, not an invented engine timestamp or a stale 1 Hz estimate.

Final confirmed complete-five-part equality, real authority controls and the
actual terminal signature ACK establish resumed progress. Recovery is labelled
canonical only when actual validated epoch/generation/serial/baseline scope
metadata and its recovery count establish it. Same-scope catchup is separately
labelled and also requires that final complete-state proof; a head jump alone
proves neither. Missing scope/context fails the observation rather than creating
a notice. There is no manual Replay Reset. These pauses test delivery/service
gaps, not packet-loss/jitter certification.

## Retained evidence and bounds

The controller streams each role's stdout to a fsynced raw log, with a bounded
disk SQLite index and at most 64 parsed events consumed per batch. Per-role
bounds are 128 MiB raw log, 128 MiB index, 65536 events and 1 MiB per line;
overflow is failure/incomplete evidence. Raw logs, index hashes, actual PIDs,
argv, role environment, executable/export-record hashes and natural exit/drain
facts are retained. A signal exit fails immediately even without a producer
RESULT; an ordinary exit waits for queued stdout and EOF before checking RESULT.
Signal exits are never labelled natural. Failure/timeout cleanup kills only owned
remaining process groups and preserves their actual exit codes. Final output
checks reuse the existing authored-sample five-part manifest/hash helper.
No whole-run row array, outlier filtering, retry or data reconstruction is used.

`SAMPLE_STATUS` frontiers are live per getter. Native/Meter values are cached
public observations at bounded 1 Hz, identified by `native_sampled_frame` and
`meter_sampled_frame`, with null/unavailable preserved. The runner records actual
admission against 67108864 bytes and component peaks without summing overlapping
ledgers. OS RSS is sampled separately with first/last/min/peak and an endpoint
slope; long runs require a measured trend. RSS is neither the Native quota nor
a leak/cause diagnosis. Historical memory samples are not same-frame reads.

Actual ACK sources are Kit Host `SAMPLE_ACK` with scope
`verified_terminal_signature_ack`/`matched:true`, and Replay Host
`SAMPLE_TAIL` with `stage:final_accepted`/`signature_match:true`. The final epoch
and terminal tick must match. Both natural exits, Native/wrapper/Meter zero
cleanup, observed owner-baseline return, one Native image, complete final bytes,
nonzero remote authority input and current bundle/helper fences are required.
Exact script-module runtime copies are bound to their actual owned PIDs and
source hashes; unexpected file/byte changes fail the fence.

CPU certification remains a separate Root-owned whole-call measurement.
Public memory-cap and history/window fixtures are separate checks. This runner
does not establish hardware CI execution, cross-target equality, a protocol
change, an old-failure cause or a whole Gate/production acceptance by itself.

The source-only check is:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s tests/box3d_production/runner -p test_runner.py -v
```

It checks planning/no-process defaults, strict parsing, bounded disk consumption,
actual-status availability, ACK identity, pause/scope proof rules, overlay byte
binding and Python syntax. It executes no exporter, compiler, Godot, VM or network.

## Callback allocation lifetime

Fresh owning Godot builtin returns use the existing `gd_method="owned_return"`
contract. Callbacks borrowing converted Godot arguments use `borrowed_args` when
their callees do not consume those references. Native callbacks also delimit their
default TLS temporary arena with Odin's nested `default_temp_allocator_temp_begin`
and `default_temp_allocator_temp_end`; resetting the default context does not free
that arena, and `free_all` would invalidate a caller's outstanding temporaries.
These are sample/editor callback boundaries, without a Core, Native or protocol
change.

The [callback lifetime fixture](../../../tests/box3d_production/callback_lifetime/README.md)
uses real SDK methods and primitive allocator observations added only to copied
test projects. After128 warmup pairs it calls the actual status/presentation
getters in two identical10000-pair batches, drops returned values, and requires
exact TLS used/capacity/temp-count restoration, non-growing Godot heap on the
second batch, unchanged pre-GO frontiers, checked close and Node destruction.
Kit uses its interactive pre-GO close contract; a scripted Kit run correctly
requires its declared target/ACK before successful close.

The preserved old Replay module failed: Godot heap grew31583859→68183859→104783859
bytes, and TLS capacity grew4→16→32MiB. Corrected Replay measured31112719 bytes at
all three anchors with TLS `[297,4194304,0]`; corrected Kit measured31120203 bytes
with TLS `[13,4194304,0]`. No tolerance, subtraction or relaxed cleanup assertion
was used. These allocator observations are separate from Native admission and OS
RSS. The original long-run signal9/OOM observations and the original scripted
pre-GO fixture failure remain unchanged; the kernel victim attribution of the
earlier OOM was not established.
