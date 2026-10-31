# Editor workflow completion

This record covers completion of the first milestone and all six
[planned gates](editor-workflow-plan.md).

| Gate | Result |
| --- | --- |
| W1 | Editor validation/baking, clickable errors, stale status and bounded jobs |
| W2 | Isolated refresh, state/playback controls, guides and rejected-edit preservation |
| W3 | Resource cross-references baked to stable IDs with unchanged canonical data |
| W4 | Complete Salvefield authoring/workbench example, shared extractors and authored runner looks |
| W5 | Built/previewed actor and ability drafts, stable ID reservation, non-overwriting publication and explicit TODOs |
| W6 | Real latency encounter, reproduction verification, correction and checkpoint takeover from the workbench/editor |

The milestone acceptance used the actual editor and F6 workbench: invalid field →
clickable issue → fix/validate/bake, refreshable preview, admitted ability encounter,
recording, return to preview and correction. Focused regressions preserve the
existing gameplay: 108 model tests, four Stormcaller tests, native/WASM equality,
scene/lifecycle checks and unchanged protected sources/canonical catalog bytes.

See the [workflow](../../examples/replay_scrapyard/editor-workflow.md),
[tooling contract](../../replay/editor/README.md) and
[durable receipts/limits](results/editor-workflow-2026-09-21/README.md).
Working logs and the pre-change snapshot remain at
`/private/tmp/replay-editor-workflow-20260921`. No Kit/original-game changes or
full-game parity campaign.
