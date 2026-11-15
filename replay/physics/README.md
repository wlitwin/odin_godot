# Managed Box3D state in Replay

This optional package supplies Box3D participation in Replay's existing
`Timeline` records and staging. Importing ordinary `replay`, `replay/net`,
`replay/p2p` or diagnostics does not import this package or require a native
archive. Default value-only frames, steps and schema policy retain their behavior.

The initial mode is a bounded local alpha for one exact build and target. It
uses the [shared contract](../../box3d/docs/framework-contract.md) and the
[Gate A envelope](../../docs/box3d/support.md). This package does not supply
a replacement runner or authority policy. Complete server-authoritative wire and
recovery support is opt-in through `Network_Codec`; see
[Box3D networking](../../docs/replay/box3d-networking.md).

## Complete checkpoints and game values

Create immutable authored assets and an initial native world, then capture a
complete checkpoint. The source world remains caller-owned and can be destroyed
after capture. `asset_id` identifies the exact bounded authored fixture;
`build_id` identifies the exact executable/native manifest. Both are trusted,
nonzero declarations. Counts and the small native fingerprint do not certify
arbitrary geometry or a different build. The provider also records target,
native format and complete immutable asset descriptors in its local contract.

```odin
config := physics.config_default(asset_id, build_id)
config.initial_dynamic_bodies = 32 // verified against the initial captured cache
initial, err := physics.checkpoint_make(frame, Event, source_world, config)
if err != .None {return}
defer replay.complete_checkpoint_destroy(&initial)

timeline: replay.Timeline(State, Input, Event)
timeline_config := physics.timeline_config_default()
timeline_config.events_per_tick = events_per_tick
err = replay.init_complete(&timeline, &initial, step, timeline_config)
if err != .None {return}
defer replay.destroy(&timeline)
```

Canonical typed State, Input and Event values may contain `Body_Key`,
`Shape_Key`, `Joint_Key`, poses and ordinary values. Native `World`, `Body`,
`Shape` and `Joint` handles are rejected recursively, including nested arrays,
structs and unions. A raw integer cast or a newly defined distinct integer erases
that provenance in Odin reflection and remains the author's responsibility.
Keys identify native allocation/generation, so retain durable game entity IDs,
generation counters and key maps in typed State too. A numerical key can recur
after rewind and resimulation.

`Complete_Checkpoint(State, Event)` owns its solver image, typed frame and copied
occurrences. Use by pointer. Assignment aliases ownership; use
`complete_checkpoint_clone` and destroy each owner once. Images contain copied
configuration and retained geometry, with contextless ownership callbacks. A
checkpoint survives ring eviction and destruction of its source Timeline and
provider variables. The allocator used to create an owner and its producer code
must remain available until that owner is destroyed.

`capture_complete(t, tick)` returns an independently owned checkpoint. Plain
`read`/`current` return `false` in managed mode, and plain game-only
`correct`/`reset_checkpoint` return `Incomplete_State`. Use `read_values` or
`current_values` for explicitly game-only presentation. Use `correct_complete`
and `reset_complete` for complete transactions. Correcting from an incompatible
build/target/content contract or provider callback realm fails explicitly.

## A single borrowed execution per callback

`Step.execution` is separate from immutable `Step.user` and `Model.user`.
Its scope is valid only within that callback. Native scope nonces are atomic
and do not restart when a Timeline is destroyed/reinitialized; WASM's pure path
uses a single-caller counter. The owner validates the active thread/scope before
dereferencing borrowed memory. A stale capability cannot revive in reused owner
storage. Capability and provider callbacks must remain loaded while in use.

Commands resolve world-independent keys in the current disposable world. The
model must call `physics.step(ctx.execution)` exactly once per successful tick;
it uses the selected build profile, defaulting to 60 Hz and four substeps. Skipping or repeating the step rejects
the candidate. A native command error poisons staging even if gameplay ignores
the returned error. `abort` and commit rejection leave the published solver,
game values, history, inputs and occurrences unchanged.

The bounded command surface includes declared primitive spawning, destruction,
linear/angular impulses, velocity, sleep/wake, the existing hinge motor and
gravity; overlap/ray queries return copied keyed records. The fixed descriptor
table bounds speculative geometry. New geometry definitions are authored before
capture, not allocated from arbitrary replay-time scene input. Changed assets,
topology or workload need new measurements even within the numerical count cap.

Sensor observations are copied after the fixed step into a bounded keyed cache.
Images/savepoints retain that cache, so later actions see the same completed
observations after an earlier action rejects. Future pending native sensor and
contact end queues are a distinct dependency retained by the shared native
snapshot; the next fixed step exposes them exactly once. The provider does not
read borrowed native event pointers after restore or source destruction.

## Existing transactions and actions

Advance, input revisions and complete correction open a disposable execution
from the exact predecessor checkpoint, then use the existing staged suffix.
Each successful tick captures one matching image. All preparation and admission
finish before the existing commit gate; publication moves owners and swaps the
selected execution. Retired state is released afterward. Missing history,
capture/open failure, resource refusal or a rejected gate never falls back to the
live solver or truncates a suffix.

Ordinary prediction and synchronous repair are limited to `net.PHYSICS_WINDOW`
(32 ticks by default, selected by the build profile) by the provider; a runner's active window is its configured
`max_prediction` (default 30, selected by the build profile). Image capture, clone and restore keep every seal
validation, but the process-local seal is a word-parallel hash and the exact
FNV-1a complete digest is computed on first request. Deeper
required repair returns an explicit limit/history error and needs a complete
recovery policy. `correct_reusing` returns `Reuse_Disabled` for managed state.
Offline audit has a separate bound of the replayable retained window (H-1 transitions); it compares solver bytes, the completed observation cache, game
values and events, then releases each temporary image immediately. It does not
retain a second solver image ring or replace the published world.

`replay/net` exposes `model_callback(State, Control, Action, Event, Seats)` for
local managed execution through its actual existing model/action path. Pass the
immutable `Model` as Timeline metadata and set `model.complete_state = true`.
The callback forwards the borrowed execution into the game Step. Before each
action it pairs a solver savepoint with the existing State/event copies.
Rejected actions restore all three; savepoint or callback errors abort and
discard the complete outer candidate. Accepted control/action ordering stays
the existing model step followed by actions. Physics effects after the fixed
step take effect at the next fixed step.

Server/client wire and durable recovery require the explicit complete codec;
`server_init_complete` binds an owned catalog to an unbound local checkpoint
before publication. Value-only diagnostic recording still refuses managed state. `policy_data`, opaque image bytes,
plain frames and integer byte arrays are not substitutes. Default integer-schema
P2P remains unchanged.

## Admission and observations

Count and byte limits use the shared [capacity profile](../../docs/box3d/capacities.md),
defaulting to 1024 bodies, 4096 shapes, 16384 contacts, 256 joints and 128 assets.
History and fixed cadence follow the shared [timing profile](../../docs/box3d/timing.md),
defaulting to H=128 and 60 Hz/four substeps. Single-caller native use remains required. The initial dynamic
declaration is checked against actual cached body types. Every allocating
operation preflights a future reservation derived from the selected snapshot and
DTO budgets (64 MiB by default); actual cumulative engine/wrapper/Odin ownership
requests are checked afterward. A reservation overrun rejects publication.
Opaque native source images and canonical recovery payloads have separate bounds
(16 MiB and 8 MiB by default); the retained image also owns its eager normalized
cache. These are adapter bounds, not an allocator-level hard cap or recoverable
upstream-engine OOM claim.

The shared admission total (1 GiB by default) includes native engine and snapshot-wrapper live
requests plus provider ownership, typed game/checkpoint payload and both existing
ring/event arenas. Core checks storage arithmetic and the declared byte budget
before allocating rings/staging/events, including large fixed-value State/Event
types. Detached checkpoint owners also reserve their payload; clones share their
native resource and do not multiply its physical storage. The core's logical
image charges are additionally conservative. Allocator headers/rounding, stack
temporaries, native flat-geometry bookkeeping and runtime/RSS overhead are
separate measurements and are not claimed as these requested-byte counters.

`allocation_stats` reports provider ownership charges and observation/request
peaks. `Timeline.external_profile` records preparation and total transaction
nanoseconds outside callbacks and State. The 4 ms normal and 4 ms eligible
correction targets are acceptance observations; wall time never changes inputs,
silently truncates simulation or determines a gameplay result. Measure the
integrated frame and overhead separately. Linux container/Rosetta measurements
are not certified native Linux throughput.

`physics.body_state(checkpoint, key)` reads the immutable native pose cache in
logarithmic time with no allocation or scratch world. `physics.dump` and
`digests` describe normalized native solver state; the complete comparison also
includes provider observations, typed game values and occurrences. Neither dump
bytes nor owned images are a portable recovery format.

Standalone tests may link one static archive. Actual SDK/gameplay modules must
use one shared native DSO domain; the originating provider callbacks and native
DSO must remain loaded until all dependent owners are released. Mutating command
facades dispatch to their Working owner's producer for accounting. Cross-module
ABI/domain/loader and reload acceptance is a separate actual integration test,
not inferred from static tests.

## Validation

Run pure participant tests without any Box3D import or link configuration:

```sh
nix develop --command odin test tests/replay_external -collection:godot=.
```

Run actual native tests with one caller:

```sh
nix develop --command bash tests/replay_physics/run.sh /absolute/libogb3.a
```

`tests/replay_external/fixture` is a failure-injectable, reference-counted generic
participant. `tests/replay_physics/fixture` is the bounded keyed native fixture.
Tests exercise the existing network callback rather than a copied action model.
The native fixture checks exact normalized solver bytes, detached ownership,
sensor/end behavior, contacts/sleep/lifecycle/hinge, history wrap, full-window
streaming audit, count/step limits and a 32-body/H=128/eight-tick staging run.
The [capacity suite](../../tests/box3d_capacity/README.md) adds 1000-body/100-joint
recovery, full-history revision/audit and compound-body network cases.

For measured timing acceptance, run the optimized native archive and Odin
`-o:speed` with `-define:REPLAY_PHYSICS_ACCEPT_TIMING=true`. That opt-in test
compares observed normal/correction maxima with the 4 ms targets outside model
execution; it does not alter or truncate simulation. Debug and emulated-target
tests report their observations without asserting native Release throughput.
# Private provider ABI

Working objects and owned images derive their identity from `REPLB3D3` and the
profile's asset/sensor array dimensions. Configuration contracts also include the
complete capacity fingerprint. Execution/image checks refuse older or differently
sized producer layouts before casting or accessing a command table. This is
separate from Native C ABI2, logical dump4, snapshot resource2 and canonical wire
format versions.
Rebuild producers and consumers together; code ownership alone does not make an
older private layout compatible. Serialized recovery still uses its explicit
build/target/schema checks and constructs current objects.

