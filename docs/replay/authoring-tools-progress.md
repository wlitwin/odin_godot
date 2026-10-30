# Authoring tools completion

All gates in [the plan](authoring-tools-plan.md) are complete. The
[public Scrapyard workflow](../../examples/replay_scrapyard/authoring-tools.md)
connects the framework APIs to the canonical example.

| Gate | Status | Evidence |
| --- | --- | --- |
| T1 — archetype registration | Complete | Atomic typed registry, resource ownership, different scene bindings; six authored-scene cases including invalid/duplicate/missing and added registration |
| T2 — canonical bake/export | Complete | Shared extractor and headless artifact, nested edit, corruption/contract rejection, stale source/bindings/binary detection and preserved output on invalid export |
| T3 — frozen evolution | Complete | Self-contained historical catalog, schema contracts, compiling disabled scaffold, explicit defaults and preservation, actual old checkpoint and upgrade CLI |
| T4 — feature test harness | Complete | Correction/takeover frame/event equality and audits, structured results, native/WASM hash equality, bounded real peers and helper failure tests |
| Delivery | Complete | Public guides, 152 Odin tests, engine/export/peer gates, measured costs, source receipts and preservation checks |

[Acceptance receipts and limitations](results/authoring-tools-2026-09-20/README.md)
record exact hashes, tests, allocation/load costs and diagnosed failures. Working
logs remain in `/private/tmp/replay-authoring-tools-20260921`; durable receipts
are checked into the results directory. No Kit or gameplay-source changes, no
original-game changes, and no full-game parity campaign.
