<a id="godot-bridge-and-measured-optimization-goal"></a>

# Godot bridge implementation plan

Completed 2026-09-20. See [delivery evidence](results/godot-bridge-2026-09-20/README.md).

This completed plan defined improvements to the API connecting replayable
gameplay values and authored Godot scenes, together with measured overhead
reductions. It followed the framework-first implementation and required
preserving Kit, original games, and separate Replay versions without adding a
game-parity campaign.

Implementation and evidence are tracked in [bridge progress](godot-bridge-progress.md).

## Invariants

- Mutable gameplay remains in the replayable World. Godot nodes, input devices,
  storage and presentation timers stay outside it.
- Definitions are immutable, validated and versioned. Retain every definition
  version needed by live history/checkpoints; never hide mutable gameplay behind
  an asset pointer to reduce copying.
- Presentation receives detached values with explicit predicted/observed/authority
  sampling policy. Presentation selection grants no simulation authority.
- Entity/view identity includes lifetime generation. View reuse cannot retain
  stale effects, child state or references to a prior entity.
- Cached property updates require declared ownership of those properties and an
  explicit invalidation path for external writers.
- Keep plain APIs usable without codegen. Add generated mapping only after a
  typed manual mapping demonstrates useful repetition to remove.

## Implementation sequence and gates

| Step | Shared primitive | Acceptance |
| --- | --- | --- |
| B1 | Bounded indexed identity lookup and opt-in cached node updates | Duplicate/invalid input preflight, retained identities and lifecycle replacement; actual Godot properties/resource cleanup; before/after operation counts and representative timings |
| B2 | Typed entity/view pool and small presentation projections | Typed project/paint callbacks, generation-safe views, cached child bindings, explicit sampling/teleports; rewind spawn/death in one small game without changing World hashes |
| B3 | Resource/scene definition baking | Typed bounded values, stable content identities, useful field/path errors, atomic rejection, resource ownership and retained-version rules; one existing authored level/resource integration |
| B4 | Input/signal bindings over Controls and Action_Intent | Tick-edge capture, pause/focus/menu policy, submission retry and epoch-scoped outcomes; no direct UI mutation of World and no ambiguous click queue |
| B5 | Declarative visual/audio effect routes | Existing journal IDs/policies, bounded pools, update/confirm without restart, cancel and lifetime reuse; native/WASM and focused actual-engine checks |
| B6 | Explicit simulation-driven and cooperative body bindings | Authored transform ownership, authority-gated observations, freeze/reseed/transfer/correction; no claim that Godot physics becomes deterministic |
| B7 | Measured optimization and delivery | Compare representative lookup/property/copy/encoding/replay costs; implement justified improvements, document public APIs and remaining limits, maintain compile-checked examples |

The plan started with B1/B2 because the original `Nodes2` implementation
repeatedly scanned arrays and applied all four properties on every presentation
call. Preserve its default
behavior for existing games; higher-level bindings can opt into property caching.
Current scene/resource extraction, input latches, cues, Audio_Pool and Body2/Body3
are implementation foundations, not functionality to rewrite under new names.

## Optimization decisions

First measure indexed lookup, skipped Godot calls and small detached projections.
Then identify immutable data that can safely leave history, and repeated canonical
encoding/hashing that can be shared without crossing recipient privacy boundaries.
Existing exact correction reuse remains opt-in and must retain full dependencies.

Evaluate chunked/copy-on-write history only if representative profiles show a
remaining storage/copy bottleneck. Ordinary gameplay assignments are a central
benefit; do not introduce mandatory mutation APIs merely to make dirty tracking
easy. Document a decision to defer this optimization when evidence does not justify
its complexity; do not report an unimplemented optimization as a speedup.

## Validation and working record

Use focused pure/native/WASM tests and one or two existing examples to exercise
each boundary. Reuse existing recovery and journal contracts. No full-game parity
matrix is required. Record changed sources, relevant logs, exact workload and
measurement limitations; avoid duplicating the whole repository per increment.
B1–B7's required behavior and evidence are complete; see the linked delivery assessment.
