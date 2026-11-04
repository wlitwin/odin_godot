# Stable Core managed Callables

The optional Runtime API is separate from Host Service version 200 and Native formats.
Names are `managed_callable_create`, `managed_callable_close`,
`managed_callable_collect` and `managed_callable_stats`. Supported 64-bit SDK
records are Managed_Callable 40 bytes, borrowed Managed_Callable_Args 32 and
Managed_Call_Error 12. The API validates version/size/actual layout fingerprint.

Create transfers an explicitly owned origin Capsule only on success. Its data
must independently retain userdata and the allocator context through Meter/block
leases; a code pin alone never retains a scene/self/stack pointer. The capsule
operation receives borrowed variants/count/result/error for the duration of the
callback only. Count is i32, max 32, reserved 0. Core initializes result to nil and
error to Ok. Producers may not retain these arguments.

`handle.value` is BORROWED for Godot connect/disconnect. Never free it separately.
After disconnecting, close alone releases the handle's Callable reference once.
Every explicit close while any call is in flight returns BUSY 8 BEFORE changing
state or ownership; keep the handle and parent/children and retry after return.
Wrong-thread/stale/forged rejection preserves the handle. A declined final data
drop retains a cleanup tombstone for retry, never repeats a freed payload dtor.

Godot call/is-valid/free callbacks point only into Core. Core validates capsule
stable function pointers plus realm/generational token before calling it, enters
its protected outer gate, and dispatches the ENTIRE producer callback through the
origin capsule. Only after producer return may cleanup release code/data pins.
Automatic Godot final free while a call is in flight only marks deferred Core
metadata. Off-main free never calls producer code; main collection drains it.
Closed or stale engine copies stay inert and cannot alias a recycled token.

The bounded Core control table is charged once through a Core Native ledger
token, separate from already-metered producer payload storage. Collection/frame
pump and Scene shutdown are Core code. Script threading flags, generic defaults,
Native wire/resource formats and Host Service version 200 stay unchanged.

The bridge is main-thread-only for create/invoke/close/collect. Explicit close is
conservatively BUSY while *any* managed callback is in flight, before closing any
entry. Stale/forged handles and wrong-thread close leave ownership unchanged.
The fixed 256 record table uses generational tokens and never wraps retired slots.
Its measured retained Core storage is 22576 bytes on the supported 64-bit pair,
charged once via a distinct Core ledger token. Producer payloads are Meter-owned.
Godot's opaque Callable internals/copies are Godot-owned overhead, not reported as
Meter/Box3D allocations. Engine OOM remains the underlying Godot API boundary.

Actual-engine reproduction, inside the Nix development shell:

```sh
python3 tests/box3d_slices/callbacks/run.py \
  --out /absolute/new/scratch \
  --native /absolute/current/libogb3.dylib \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --configuration Debug
```

The runner copies authored files into fresh scratch, uses the existing SDK build
helpers and prepared-import containment, records source/native/binary/log hashes,
then runs actual Godot callbacks/signals, source-free dispatch, producer reload,
BUSY close, worker-thread final copy release, declined-data-drop retry, weak-owner
invalidation, all 256 slots, failed constructor ownership and stale/forged handles.
Release selects speed optimization for both initial modules/Core; the reload
preserves its optimization flags. Linux uses the same runner/official binary in
the existing VM; its Rosetta execution is functional evidence, not throughput.

```sh
cc -std=c17 tests/box3d_slices/callbacks/protocol_layout.c -o /tmp/callback-layout
/tmp/callback-layout
odin test tests/box3d_slices/callbacks/protocol -collection:godot=. \
  -define:MANAGED_C_FINGERPRINT=3803065315553065936 -define:ODIN_TEST_THREADS=1
python3 tests/box3d_slices/callbacks/run_internal.py --out /absolute/new/core-scratch \
  --native /absolute/current/libogb3.dylib
```

The independent C layout and optional-runtime negative controls need no Native
library. The internal runner compiles an unchanged scratch copy of Core plus a
private test: automatic final free during an in-flight producer call cannot clean
before return; a declined drop retains its token; worker final free executes no
producer code until main collect; stale finalizers and invalid C64 argument counts
are safe. This deterministic internal event-order test is separate from the
actual Godot worker-copy test and does not claim an engine-generated in-flight
final-free event through the owning-handle API. No production test hook is added.

Prepared import is the supported containment for the separately recorded official
Godot cold-import issue; these results do not claim that upstream issue is fixed.
The callback support is not ENet/session acceptance or Gate B performance proof.
