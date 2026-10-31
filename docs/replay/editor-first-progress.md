# Editor-first authoring delivery

This records the completed E1–E6 delivery from the
[editor-first plan](editor-first-plan.md).
[Final source/test receipts](results/editor-first-2026-09-20/README.md) record the
implementation, validation, measured tradeoffs and preserved original sources.
The authoring entry point is [Scrapyard's authoring guide](../../examples/replay_scrapyard/editor-first.md).

| Gate | Delivered |
| --- | --- |
| E1 | `Script_View(Value, Script)` adapts an ordinary typed Odin Node script to a view pool; ready/component validation and retirement preserve ownership |
| E2 | Enemy scene-local script, six authored appearance Resources and a reusable authored telegraph child; independent F6 preview |
| E3 | Authored permanent-seat runner scene with weapon/reload/beacon children; detached runner/HUD values; ordinary Godot process callbacks; independent runner/HUD previews |
| E4 | Scrapyard catalog admission uses atomic typed baking, resource/field diagnostics and duplicate-ID rejection; a compile-checked composed gameplay recipe |
| E5 | Canonical editor/gameplay ownership guide, scene map, extension workflow and explicit procedural-renderer exceptions |
| E6 | Native/WASM scene tests, actual browser previews, host/client/observer combat and revive, crash recovery, measured presentation cost; final receipts below |

## Validation and findings

Independent enemy, runner and HUD previews pass natively. Authored child offsets,
appearance changes, normal animation and scene round-trip checks pass without a
Session or World. A real Chrome export executes the composed scenes and checks
their rendered-node properties. The full game scripts also compile for WASM.

Typed scene tests accept the expected script after ready, reject a wrong script or
missing required appearance, and verify retirement on epoch replacement. Resource
checks bake an edited catalog, reject invalid health and duplicate IDs, restore its
original content hash and verify that the running authority World is unchanged.
Actor, feedback, audio and combat HUD checks pass. The final combat peers agree
at tick 861/hash 1245892162797171220. Native revive/camera agreement
passes at tick 1140/hash 4842865242039378665; crash recovery with a downed player
following the lost host passes at tick 468/hash 3315288502199572453.

A failed revive run exposed an existing presentation bug: public client authority
frames omit hit_history, but wound presentation was reading that server-private
cache. The adapter now uses exact retained public event-tick frames on clients,
with generation checks and explicit missing-history refusal. Authority hit judgment
is unchanged. Client frames may be corrected or predicted; this is cosmetic data.
The passing revive run saw the wound and returned the camera home; one unavailable
history lookup remained explicitly counted. No new private data crosses the wire.

A stale migration test read `.polygon` on a MeshInstance2D. It now uses the existing
representation-independent ViewProbe.vertices helper and keeps the same shape/count
assertion. The failed receipt is preserved. Another initial harness entry referenced
a nonexistent camera_test.gd; the actual revive and crash-camera fixtures are now
used. An early compile failed after removing a local catalog alias still
used by the status display; that alias was retained.

## Measured cost

Three alternating process pairs per size, five 120-call samples after warmup, use
the same detached frames and debug-build settings. The previous bridge advanced
animation inside paint; the new harness explicitly advances the scene-local enemy,
runner, weapon/equipment and HUD callbacks too. It therefore compares paint plus
animation work rather than claiming a speedup by omitting the new callbacks.
Both paths verify the live authority World remains unchanged.

| Enemies and drops, each | Previous typed bridge | Composed scenes |
| --- | ---: | ---: |
| 0 | 65.44 µs | 79.69 µs |
| 8 | 82.43 µs | 83.00 µs |
| 32 | 100.03 µs | 87.19 µs |

These are isolated CPU calls, not rendered FPS, confidence intervals or universal
speedups. Direct callback calls exclude Godot's callback-dispatch cost; scene
construction/churn, GPU work and network/simulation cost are also excluded. The
empty case regressed, the medium case is similar and the larger case improved in
this fixture. Different builds/workloads can differ. Composition is justified by
authoring and ownership, not a blanket performance promise.

The original game, Kit and existing gameplay/content schemas remain unchanged.
Generated arenas, high-churn projectile/beam batches and specialized feedback remain
procedural by explicit design. The guide identifies the rendering paths that remain procedural and explains
their ownership.
