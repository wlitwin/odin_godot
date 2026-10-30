# Godot bridge performance assessment

Measurements on macOS arm64, Odin dev-2026-04, Godot 4.7.1, optimized native builds.
These are isolated elapsed costs with fixed workloads, not rendered-frame rates,
confidence intervals or a general guarantee for every game. Raw receipts, binaries'
hashes, source hashes and workload details are in the
[delivery evidence](results/godot-bridge-2026-09-20/README.md).

## View ownership

The initial dense benchmark justified replacing repeated linear lookup and making
root-property caching opt-in. The final comparison also includes small and sparse
pools and the additional typed owner. Every timed frame moves x; rotation, scale,
color and typed paint payload remain constant. Scenes are already instantiated.
Typed paint is empty here, so real child painting can add game-specific work.

At 1,024 active views, the first expanded comparison measured original Nodes2 at
609.7 µs, indexing at 107.0 µs, cached Nodes2 at 45.05 µs and typed ownership at
70.58 µs per presentation call. Caching avoided roughly 75% of root property writes.
Typed lifetime/payload bookkeeping adds work; ergonomics are not cost-free.

That comparison exposed a sparse regression: one active view in a capacity-1,024
pool still scanned capacity and cleared whole indexes. The final implementation
tracks occupied buckets and uses a retained-membership path after full duplicate/
identity preflight. Sparse index clearing visits occupied buckets; dense clearing
stays contiguous. Unchanged membership skips lifecycle/free-slot/index rebuilding.
Reordered input is supported; changed membership uses the ordinary lifecycle path.

An alternating comparison of frozen before/after binaries measured:

| Active / capacity | Cached Nodes2 before → after, µs | Typed owner before → after, µs |
| --- | ---: | ---: |
| 1 / 1 | 0.033 → 0.033 | 0.058 → 0.050 |
| 8 / 8 | 0.300 → 0.275 | 0.442 → 0.425 |
| 1 / 1,024 | 2.167 → 0.033 | 4.208 → 0.050 |
| 8 / 1,024 | 2.442 → 0.258 | 4.533 → 0.358 |
| 64 / 64 | 2.317 → 2.242 | 3.500 → 3.200 |
| 512 / 512 | 21.217 → 20.467 | 32.542 → 29.667 |
| 1,024 / 1,024 | 44.017 → 42.142 | 67.458 → 61.892 |

Each table cell is the median across three process medians, each with five timed
120-call batches after warmup. Very small values approach timer granularity;
interpret broad changes rather than the last decimal. Indexed uncached dense
1,024-view calls also improved slightly, 106.08 → 103.08 µs. Counts match exactly.
The two comparisons were separate runs; do not mix their numbers as one paired
experiment. Membership churn/scene construction, GPU and rendering are excluded.

Memory increases: each index now retains four bytes per configured entry for its
occupied-bucket list, in addition to its existing keys/values. Nodes2 owns two
indexes; the typed owner owns two additional indexes and rig/value/batch storage.
All remain presentation-only. Stable presentation calls allocate no Odin storage;
scene entry/exit still creates and retires engine objects. Capacity scans remain
when membership changes or owners clear/destroy.

## Copy, codec and replay costs

A second optimized benchmark uses actual Hello and Scrapyard models, a 32-byte
selective display output, a 64-frame history and a 16-tick replay suffix. Scrapyard
starts with two players and 40 mobs under the documented combat fixture. Medians:

| Operation | Hello | Scrapyard |
| --- | ---: | ---: |
| State bytes | 960 | 61,536 |
| Complete canonical bytes | 896 | 52,608 |
| Public canonical bytes | 896 | 24,032 |
| Materialized frame read | 0.016 µs | 0.926 µs |
| Ordinary read then selective projection | 0.0013 µs | 0.0012 µs |
| Detached `replay.project` | 0.0131 µs | 0.0108 µs |
| Authority encode / hash | 0.331 / 0.141 µs | 33.641 / 24.474 µs |
| Public encode / hash | 0.335 / 0.131 µs | 10.101 / 4.920 µs |
| Advance one tick | 0.105 µs | 11.351 µs |
| Replay 16 ticks | 1.406 µs | 149.332 µs |

The selective projection timing intentionally permits optimizer elimination of
unused fields. It is not evidence of physically copying 61 KB in a nanosecond.
`project` has validation/reentry overhead; its primary benefit here is an explicit
detached ownership contract, not a speedup over an optimized ordinary read.
The materialized case retains every field and gives a useful separate copy cost.
Hello's real full view-batch adapter expands its small World; it is an ergonomics
example, not a smaller-buffer optimization.

Scrapyard's retained records and replay scratch each occupy 3,941,376 bytes at 64
frames, excluding separate events and allocator metadata. Default 128-frame
retention roughly doubles those arrays. Immutable definition catalogs can remove
truly static data from future Worlds, but the catalog/dependency lifetime must stay
complete across replay, saves and migration. Cavecrawl intentionally still embeds
its small baked definitions to preserve its existing checkpoint contract.

## Decisions

Implemented: indexed identity lookup, exclusive property caching/invalidation,
changed-value paint, retained-membership fast paths and sparse index clearing.
These reduce measured repeated work without changing gameplay assignments.

Keep detached projections for ownership/ergonomics; make no universal zero-copy
promise. The measured copy cost does not justify introducing chunked/COW storage
and mandatory mutation tracking now. Memory can still become significant for much
larger Worlds/history; revisit with an actual target workload and a storage design
that retains ordinary assignments and transactional replay.

Do not add a broad snapshot encoding/hash cache here. Inspection shows snapshot
construction includes recipient projection, connection generation/serial, action
settlement/input frontiers and per-recipient baselines. Private authority fields
and public values are different contracts. Canonical bytes are already retained
for delta baselines. Safe reuse requires explicit equality of all these dependencies;
a frame tick alone is insufficient. Public encode/hash costs are material, but this
bridge profile does not isolate a redundant network call to remove safely.

Existing opt-in exact correction reuse remains available under its documented full-
dependency rules. This work leaves wire hashes, schemas, checkpoint versions and
replay semantics unchanged. A future optimization must preserve those contracts
or introduce an explicit compatibility change.
