# Replay adapter ergonomics

This record summarizes completed reusable scene-adapter work, its Scrapyard
integration, and optional generation over the public helpers. In the table,
runner means Scrapyard's character scene, not the simulation runtime.

| Gate | Implementation | Acceptance |
| --- | --- | --- |
| A1 | Owned typed archetype/script bindings, shared borrowed fixed-scene binding | Enemy adapter loses raw callback casts/configuration lifetime plumbing; runner keeps permanent scene identity |
| A2 | Explicit scope tracker, public typed iteration, contextual diagnostics | Epoch/reset/game-key/rewind tests; adapters avoid pool internals; failures identify archetype/scene/entity/component |
| A3 | Owned Resource batches and checked typed access; explicit numeric bake conveniences | Candidate lifetime and atomic publication; missing/wrong scripts/ranges fail with source paths; Scrapyard loader uses shared code |
| A4 | Typed onready composition and authored enemy preview inputs | Enemy/runner components bind through existing support; preview new archetype without kind switches; unchanged gameplay and independent F6 scenes |
| A5 | Optional view-descriptor codegen using public helpers | Enemy and runner declarations; generated/manual equivalence; useful malformed/signature diagnostics; Kit generator regression gate |
| A6 | Docs, integration and evidence | Focused native/WASM/real Godot lifecycle, correction/takeover and diagnostics; preserved Kit, World rules/schema, original game |

Generation declares bindings only. Authority, sampling, effects, admission,
world lifetime keys and schema conversion policies remain explicit game code.
Resource/scene validation that needs Godot runs at the authoring/runtime boundary;
Odin compilation validates typed callback contracts. No new DSL for gameplay.

Typed Resource access and bake mapping are assessed through the loader integration.
Prefer existing reflection/generic facilities for checked mechanical work; do not
infer game validation from Inspector hints or generate a second extractor.

All gates and acceptance evidence are recorded in [adapter-progress.md](adapter-progress.md)
and [results](results/adapter-2026-09-21/README.md). Previous goal receipts are preserved.
