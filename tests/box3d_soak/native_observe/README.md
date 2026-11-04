# Opt-in Native observation controls

This is a diagnostic test ABI, not a production physics API. Build with
`-DOGB3_NATIVE_OBSERVATION=ON`; the default is OFF. OFF excludes the control
object and all observer symbols. ON adds exactly the three versioned ABI,
begin and end exports, retaining the ordinary 96 exports and resource2/dump3/
recovery1. The actual Native build identity changes; old canonical fixtures
must not be relabelled as coming from this build.

`native_observe_test.c` exercises the fixed 49392-byte layout, domain/config/
token preservation, masks and recorded ancestry, 1024-slot overflow, depth16,
error/unclosed detachment, synthetic-clock failure/regression/reentry, and
actual step/capture/canonical read/write/admission failure cleanup. Synthetic
counter clocks are controls, not performance samples. Token exhaustion has
an explicit nonwrapping guard; iterating 2^64 scopes is not a test claim.

`observer.odin` is imported only by test producers. It allocates one exact
49392-byte block through an installed SDK Meter, passes an explicit exact
block DataLease to actual stable Core, and retains the returned code/data
Owner. **Owner.user is an opaque Core token**, distinct from DataLease.user.
The allocator context and block Owner are separate. Realm/domain checks run
before foreign calls. Rejected end preserves the token and owners. Destroy
first ends a live scope, then requests free of the pinned block, then drops
the Core Owner. A declined drop retains a cleanup handle; its retry does not
free the block twice. Repeated successful destruction is harmless.

The 32-byte fixed test DataLease wrapper in `ownership_controls.odin` declines
one actual final block drop to exercise that path under real Core. It never
replaces or forwards the Core Owner callbacks. Its own fixed static storage
and Native control storage (48 bytes on tested macOS arm64) are reported
separately from requested allocation bytes. The actual Meter context
metadata is charged through its allocator as usual.

The existing Kit CPU fixture enables the binding with
`--native-observation` in `build_probe.py`. Functional runs accept observation
`off` (same opted-in binary, no scope) or `structure`. Structure invokes no
clock, produces no timing SAMPLE and retains all eight steps/captures,
independent canonical read/build/reencode, full five-part comparison, FX and
cleanup. A separate public Node call reads diagnostic records only after the
apply operation has returned through real Core. The old dense and common
trajectories, windows and limits remain unchanged.

Timed Native mode accepts a caller-provided C clock with user exactly the
leased block. An actual timed producer must prewarm and use the same Godot
clock as its outer Core-return timer, keep clock/code/data ownership valid,
and obtain Root's explicit exclusive grant. No timing run is authorized by
these controls or their successful functional results. Structure/no-scope
functional success is not CPU, long-soak or Gate B acceptance.

The timed-preparation consumer caches the actual Godot Time singleton and
prewarms its existing method binding only behind profile + timed + explicit
grant gates. Its C callback checks the exact leased block pointer and reads
only that same Godot microsecond clock. The 24-byte fixed clock-binding state
is reported separately. Functional mode rejects timed selection; OFF and
structure execute zero clock prewarm calls. The rolling profile remains 19
whole calls at heads8..152; final tick160 uses structure mode with zero Native
clock reads and is not a twentieth SAMPLE.

After each complete public Core return, raw serialization copies every C
header field, all16 stack slots and every recorded span without changing
status or ancestry. Its bounded 528384-byte transient buffer is allocated and
freed through the retained SDK Meter, outside the timed operation. Derived
phase durations use only each span's own endpoints; no phase sums or residual
subtraction are allowed. Raw attribution failures are retained separately
from the actual game outcome. A future timed command still requires an
explicit new Root exclusive grant; compiling this path grants no execution.

The integer-preserving producer keeps prepared metadata and original Odin
Native/facts/cleanup JSON as raw tokens. Its GDScript composer decodes only
quoted object keys and SHA strings. Native values never pass through a numeric
Variant. Odin derives phase JSON from checked `u64` endpoints directly; no
counter is repaired by a post-run float-to-int conversion. JSONL framing
removes only insignificant whitespace outside strings. Producer controls
retain `2^53+1`, `2^63` and `UINT64_MAX`, including a synthetic maximum cookie/
token and one-microsecond phase beyond `2^53`. These controls are explicitly
not Native calls or timing samples. The earlier float-producing 19-call run
remains `OBSERVATION_SCHEMA_FAIL` with its original raw bytes unchanged.
