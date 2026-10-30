# Replay authoring and evolution tools

Completed goal: implement the four improvements identified by the Stormcaller exercise,
using Replay Scrapyard as the integration. Preserve Kit and the original game;
keep gameplay semantics and authority/privacy choices explicit.

| Gate | Deliverable | Acceptance |
| --- | --- | --- |
| T1 | Typed archetype registry plus owned Godot scene/appearance associations | Stable IDs; duplicate/missing/range diagnostics; transactional publication; resource lifetime; Scrapyard eliminates fixed per-kind appearance fields/array edits |
| T2 | Canonical definition artifact and one Godot bake/export path | Headless stock/server/tests consume identical canonical data; source manifest detects stale inputs; reject corruption/wrong schema/content; nested PulseDef uses same extractor; remove TRES parsing from stock generator |
| T3 | Frozen revision contracts and conversion scaffolding | Freeze source schema/type dependencies; explicit defaults/conversions; reject unsupported/ambiguous changes; verify old field preservation; demonstrate content49→50 and guard historical contracts |
| T4 | Reusable feature scenario harness | Scripted inputs under late correction, audit and checkpoint takeover; structured results; native/WASM equality runner and bounded peer orchestration; Stormcaller tests use shared helpers |
| Delivery | Public docs, integration and assessment | Focused native/WASM/Godot tests, relevant old-save checks, real peers, exact receipts and preservation checks; no full parity campaign |

Baking is an explicit authoring/build action. Runtime views borrow local resources,
never put resource pointers into World. Artifact/schema hashes establish contracts,
not authentication. Historical gameplay compatibility remains an authored decision;
scaffolding cannot infer it. New scaffolds must be reviewable and fail closed until
required mappings/defaults are supplied. Existing APIs remain usable independently.

Implementation and acceptance are recorded in [authoring-tools-progress.md](authoring-tools-progress.md)
and the [results](results/authoring-tools-2026-09-20/README.md). All gates are complete.
