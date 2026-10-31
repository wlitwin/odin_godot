# Adapter ergonomics completion

All six criteria in [the plan](adapter-plan.md) were completed for the recorded
adapter milestone.

| Gate | Result |
| --- | --- |
| A1 | Owned typed archetype/script configuration and permanent-scene binding; Scrapyard enemy and runner use distinct lifetimes |
| A2 | Explicit scope tracker, public typed visitor/stats and contextual owned diagnostics |
| A3 | Resource batch ownership, checked typed Resource access/narrowing; shared explicit mob extraction |
| A4 | Existing typed onready composition adopted; authored preview samples replace known-kind switches |
| A5 | Optional view descriptors generated over public helpers; signature/declaration checks; existing Kit/scriptgen regression passes |
| A6 | Public docs, 38 Odin tests, seven codegen cases, eight Godot scenes/adapter cases, low-level lifecycle, native/WASM equality, export/provenance, real revive and crash-takeover gates |

The [API guide](../../replay/godot/scene/adapter-bindings.md) and
[canonical example](../../examples/replay_scrapyard/authoring-tools.md) describe
manual/generated declarations, ownership and explicit policy boundaries.
[Durable receipts](results/adapter-2026-09-21/README.md) record source hashes,
validation, limitations and diagnosed failures. Working logs are retained in
`/private/tmp/replay-adapter-20260920`.

Typed Resource and bake mapping convenience is implemented through reusable checked
helpers and one shared extractor. A second mapping generator would duplicate the game validation already
performed by that extractor. No gameplay policy was inferred from Inspector
hints. No World schema/rule changes, Kit implementation changes or original-game
changes; stock provenance was rebaked with identical canonical data.
