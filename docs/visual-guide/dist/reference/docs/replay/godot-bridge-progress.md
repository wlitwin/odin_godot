# Godot bridge goal progress

Completed scope: [B1–B7 plan](godot-bridge-plan.md). This is separate from the completed
framework-first implementation. The typed authoring layers and final measured delivery gate are now complete.

## B1 foundation — 2026-09-20

Implemented bounded `view.Key_Index`, lifetime-preserving handle keys, indexed
`Nodes2` reconciliation/lookup, opt-in property caching and explicit invalidation.
Default callers continue reapplying root properties. Duplicate/zero IDs are
preflighted before scene changes, and full-capacity replacement remains supported.

Twenty-six view tests/WASM checking, a real Godot lifecycle/property/resource test,
and existing Hello/Loot presentation tests in an isolated copy pass. A dense
presentation-call benchmark compares the preserved old owner, indexing alone and
caching with identical moving-position input. At 1,024 views the median call is
630.4 / 111.6 / 46.1 microseconds. Caching avoids about 75% of property calls in that
workload. These are not rendered-frame/GPU or whole-game timings. Extra bounded
index/cache memory is a tradeoff; sparse and very small pools need separate
measurement before universal performance claims.

See [API/lifetime contract](../../replay/godot/scene/view-pools.md) and
[focused evidence](results/view-index-2026-09-20/README.md).

## B2 typed views and projections — 2026-09-20

Implemented detached `replay.project`, bounded typed entity projections, explicit
predicted/observed/authoritative selection, interpolation and teleport cuts, and
`View_Pool2(Entity, Value, Rig)`. Child bindings attach once per lifetime, paint
skips unchanged values, and epoch/reset changes recreate rigs. Hello now uses the
bridge; gameplay code and World hashes remain unchanged.

32 core tests and 29 view tests pass, with WASM compilation. Actual Godot checks
cover lifecycle, cached child properties, invalidation and failure cleanup. Existing
Hello/Loot, rewind, inspector/branching, recording verification, rendered inspector
and network inspection checks pass. See [evidence](results/typed-views-2026-09-20/README.md).
No projection speedup is claimed yet; Hello's expanded view batch is larger than
its tiny World, and by-value projection may still copy State.

## B3 definition baking — 2026-09-20

Implemented typed immutable definition stores, semantic/schema/content identity,
owned field diagnostics, explicit retained-version pins and transactional baking.
The Godot scope owns temporary scenes and supports validated nested marker
transforms. Cavecrawl uses one atomic bake for its authored two-floor set, retaining
presentation scenes only after success. Definitions remain embedded in World,
so its checkpoint format is unchanged.

Pure store/WASM and real Godot extraction checks pass, including failure cleanup.
Existing Cavecrawl authored-content, mutation isolation, save/reload and six invalid
input cases pass; all scripts also compile for WASM. See
[evidence](results/definitions-2026-09-20/README.md).

## B4 input and signals — 2026-09-20

Implemented engine-free buffered Control_Capture, typed InputMap bindings and a
stable-address Signal_Action owner over existing Action_Intent. Gates suppress
held inputs across pause/focus/menu boundaries; signal payloads are copied on click,
with explicit one-slot overflow and cancel/keep policy. Recovery still rebinds
accepted tickets while UI submission is paused.

33 core tests/Loot/WASM and actual Godot input/signal/retry/epoch/recovery/disconnect
checks pass. Complete native fixture scripts also compile for WASM. See
[evidence](results/input-bindings-2026-09-20/README.md) and
[API contracts](../../replay/godot/input/controls.md).

## B5 visual/audio routes — 2026-09-20

Implemented declarative Cue_Route, Effect_Route2 and Audio_Route over existing
journal IDs, bounded cue/voice pools and typed views. Routes follow journal policy
or delay until confirmation. Updates/confirmation preserve scene and playback
lifetimes; canceled/expired/dropped IDs remain consumed, and slot reuse gets new
view generations.

30 view tests/WASM, a shared native/executed WASM lifecycle corpus, and actual
Godot scene/audio identity, cancellation and cleanup checks pass. Complete engine
fixture scripts compile for WASM. See [evidence](results/effect-routes-2026-09-20/README.md)
and [route contracts](../../replay/godot/scene/effect-routes.md).

## B6 body contracts — 2026-09-20

Implemented distinct Simulation_Body2/3 pose bindings and Session adapters selecting
only authority state for cooperative Body2/3. The sample facade rechecks fencing,
phase, pause and epoch; missing state suspends the producer. Existing transfer,
reseed, correction and admission semantics remain in the owned-body protocol.

11 owned-protocol tests/WASM and actual Godot checks in both dimensions pass for
authored offsets, freeze, invalid input, preparing/accepted transfer, cuts,
fencing, recovered epochs and pause. Complete fixture scripts compile for WASM.
See [evidence](results/body-bindings-2026-09-20/README.md) and
[body contracts](../../replay/godot/scene/body-bindings.md).

## B7 measurement and delivery — 2026-09-20

Completed sparse/dense comparisons including the typed owner, and actual Hello/
Scrapyard copy, public/authority encode/hash, advance and suffix-replay profiles.
The sparse comparison exposed avoidable capacity work. Occupied-bucket clearing
and a fully retained membership path remove it without changing lifecycle or
preflight behavior; dense cases improved too. Typed 1/1024 calls measured
4.208 → 0.050 µs; typed 1024/1024 measured 67.458 → 61.892 µs in paired runs.

The selective read benchmark allows compiler copy elimination; detached projection
has a small validation cost and is not claimed as a universal copy speedup.
Materialized Scrapyard reads measured 0.926 µs and 16-tick replay 149.332 µs in the
final profile. COW/chunked history is deferred; broader encoding caches need exact
recipient/connection/content dependencies before safe implementation.

Final validation passes 76 pure tests, native/WASM recipes, executed WASM route
checks and the actual Godot bridge fixture. Rebuilt Hello/Loot and inspector/
recording/network checks pass. All 65 baseline Kit hashes match, original game
directories and sibling Scrapyard remain clean. No parity expansion was needed.

The goal is complete. See [performance and tradeoffs](godot-bridge-performance.md),
[delivery evidence](results/godot-bridge-2026-09-20/README.md) and public contracts
linked from the [Godot integration entry point](../../replay/godot/README.md).
