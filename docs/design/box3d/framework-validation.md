# Kit and Replay complete-world transaction validation

P2.4, board `b_cdde1cdfea104035`, recorded 2026-10-30.
Status: local complete-world transaction and integrated envelope gate passed
for the declared alpha; networking, canonical recovery and actual SDK module
deployment remain separate required phases.

The shared native backend participates in the existing Kit lane and Replay
Timeline. Their transaction interfaces stay separate and backend-neutral;
ordinary Kit/Replay users do not acquire a native-library dependency.

## Independent executed checks

[tests/box3d_framework](../../../tests/box3d_framework/README.md) drives both
actual adapters with the same pointer-free game rules and independent native
worlds. Four tests pass in Debug and optimized mode on macOS arm64 and Linux
x86-64 via Podman/Rosetta:

- Game values, native allocation keys, and exact normalized solver bytes agree
  with an independently stepping reference and between Kit and Replay.
- Spawn/removal/impulses, corrected input suffixes, recorded events and cached
  historical poses remain coherent.
- A failed candidate restores Kit registered prediction fields, typed Side,
  native state and post-commit effects together.
- Replay abort preserves the published image/head/events; game-only physics
  truth/export is rejected, while explicit value reads remain available.
- H=128 history evicts old records, and an explicitly owned checkpoint can
  clone/read/resume after the source Timeline/Lane/world is destroyed.
- A stale borrowed execution cannot revive when Timeline storage is reused.
- Teardown returns native, owned-snapshot and concrete-provider live charges
  to zero; the Odin test runner also tracks its allocations.

The native public-operation probe checks a post-step sensor deletion, capture,
restore and next-step observation: the untouched and restored worlds both emit
one end event, followed by zero on the next step. This caught a real missing
future dependency in the older snapshot boundary.

## Corrections exposed by independent integration

The first borrowed-capability implementation restarted its generation on owner
reinitialization. Reusing the same Timeline address made an old capability
appear current. Scope identity now uses process-unique monotonic nonces, validates
the active thread-local producer scope before touching the stored pointer, and
carries the originating validator for valid cross-code-image use. Borrowed
capabilities still must not outlive their callback/code lifetime.

Pinned Box3D writes destruction-generated sensor/contact ends into the current
pending buffer and publishes that buffer after the following fixed step. These
are future observations, not already-consumed output. Shared snapshots now own
those ordered queues, retarget their IDs into staged execution, and preserve them
while clearing completed output buffers. The resource version is 2 and normalized
comparison version is 3 (`ogb3-d421e45c-solver-v3`). Historical
[Gate A measurements](gate-a-measurements.md) remain evidence for their recorded
v2 builds; they are not relabeled as current v3 artifacts.

Replay separately retains completed fixed-step sensor observations in its
provider image/savepoint. A rejected later action therefore cannot change what
another action in the same tick observes. Provider equality covers that state
as well as the native solver image.

Wall-time observations are not gameplay rules. The 4 ms normal/correction
ceilings are integrated acceptance targets and reported profiling values;
deterministic count, history-age and memory limits remain admission checks.


## Integrated bounded-envelope observations

The actual optimized macOS adapter tests meet the proposed 4 ms normal and
4 ms eligible-correction targets in these samples. These are acceptance
measurements, not runtime clock-dependent game rules or a real-time guarantee.
Debug timings and Rosetta timings are reported separately; the latter are not
bare-metal Linux throughput certification.

| Adapter | Executed target/build | Functional tests | Largest normal transaction ms | Largest depth-eight correction ms | Tracked staged live peak MiB |
| --- | --- | ---: | ---: | ---: | ---: |
| Kit | macOS arm64 Debug | 9 | 2.857 | 6.562 | 34.488 |
| Kit | macOS arm64 optimized | 9 | 0.616 | 3.033 | 34.488 |
| Kit | Linux x86-64/Rosetta Debug | 9 | 4.948 | 7.986 | 34.486 |
| Kit | Linux x86-64/Rosetta optimized | 9 | 2.749 | 3.185 | 34.486 |
| Replay | macOS arm64 Debug | 6 | 1.297 | 6.278 | 34.781 |
| Replay | macOS arm64 Release + Odin speed | 6 | 0.803 | 3.539 | 34.781 |
| Replay | Linux x86-64 via Podman/Rosetta Debug | 6 | 2.553 | 7.999 | 34.779 |
| Replay | Linux x86-64 via Podman/Rosetta Release + Odin speed | 6 | 0.695 | 3.734 | 34.779 |

Kit retained 160 raw normal samples and 33 actual eight-tick corrections, with
complete native/Side/registered-field equality and effect deduplication after
each repair. Its largest reserved-operation request was 546,384 bytes on macOS
under a 2 MiB reservation; all reservations and final ownership teardown pass.

Replay's 160-tick test retains H=128 and eight speculative ticks, with eligible
repairs after history fill. Its largest operation requested 548,232 bytes under
2 MiB, with no reservation failures. A separate optimized macOS run measured
39,567,360 bytes maximum RSS and 36,470,175 bytes tracked ownership peak.
The ring/staging/event container charge was 1,163,856 bytes. Component maxima and
RSS are separate domains; they must not be combined into a fabricated
simultaneous peak or exact runtime-overhead identity.

The Replay provider's native-free regression evidence includes core 33, net 182,
P2P 33, recording 10 and diagnostics 10 tests, plus existing default/speed
native/WASM checks. Ten managed generic-participant tests and actual import-free
WASM execution validate the new ownership and stale-scope path without Box3D.
Kit's legacy simulation suite passes 56 tests without the native library.

## Deliberate alpha boundaries

The [Gate A envelope](gate-a.md) remains the target: the measured fixture reaches
35 total bodies/shapes, 147 reference contacts, one hinge, H=128 and at most eight
ordinary prediction/correction ticks. Tracked resources target 64 MiB with
separate allocator/runtime/RSS and staging observations.

Kit's alpha uses fixed registered state proxies and an explicit managed
world-step/settle path. Dynamic native/game entity lifetimes live in typed Side;
scene/lane tracking changes, generated entity thunks, authority callbacks and
scheduled verbs that cannot yet defer side effects fail explicitly. Presentation
effects publish after commit with stable tick-scoped keys and replay deduplication.
Reset is explicit recovery with a new effect epoch; ordinary confirmed history
cannot be unsettled by older or conflicting checkpoints.

Replay retains its existing history/staging and value-only behavior. Optional
managed images participate in initialization, advance, revision, complete
correction/reset, rewind, audit, eviction and destruction. Rejected actions use
native savepoints through the actual network-model callback. Existing game-only
wire/checkpoint paths fail explicitly for managed physics until the complete
codec and accepted-input protocol are integrated in P3.

Typed world-bound native handles are rejected from physics values where runtime
type information preserves their identity. A new distinct integer rewrapping or
raw integer cast erases that provenance; authors must use world-independent
keys and game entity generations, not conceal host-world handles.

Local opaque images are not a recovery/network codec. Same-build correctness
does not imply mixed-target solver equality. Actual Godot core/gameplay modules
must use one loaded native backend and retain producer code for owned callbacks;
standalone static tests do not establish cross-module/reload deployment. Those
remain explicit later implementation and acceptance work.

## Evidence locations

Root independent logs/binaries are under the goal scratch:
`p2-framework-v3-debug`, `p2-framework-v3-release`,
`p2-linux-framework-debug` and `p2-linux-framework-release`.
The public probe source is tracked with the tests. Provider/helper reports retain
their exact source/archive/manifest hashes and separate platform configurations.
The completed P2.4 report copies accepted results, source hashes and integrated
measurements into persistent herdr-tasks report storage.
