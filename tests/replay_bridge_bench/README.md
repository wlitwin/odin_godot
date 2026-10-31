# Bridge cost profile

Run `nix develop --command python3 tests/replay_bridge_bench/run.py /absolute/fresh/output`.
The script builds with `-o:speed` and records three processes, five timed trials
per operation after warmup. It pins input/output hashes, type sizes, compiler,
platform and binary digest. Timings are descriptive, not acceptance thresholds.

The profile uses actual Hello and Scrapyard World/reducer types. Scrapyard starts
with two players and 40 mobs, no generated encounter, no enemy bite damage, a large
magazine and no jams. One player alternates horizontal controls and fires. This is
a bounded offline cost fixture, not game parity, network traffic or rendered FPS.

Operations measure ordinary read-then-project, detached `replay.project`, schema
encoding/hashing for complete authority and public projections, committed advance,
16-tick input suffix replay, and reads whose entire frame is retained in a 64-slot
consumer buffer. The ordinary read baseline permits inlining and compiler
elimination of unused fields or copies. The fixture does not force copies or
disable inlining to make that baseline slower. Afterward, it canonicalizes the
full retained buffer so all of its fields remain observable.
The display contains 32 bytes; the timing sink consumes count/tick, so unused
position work can be removed. This is a narrow display query, not full rendering.

Encoding/hash use the fixed warmed frame; advance/replay/read costs use the evolving
timeline. Replay repeats the same input through 16 ticks and verifies the final
history with audit. It does not include packet handling or correction admission.
Record/scratch bytes exclude separate event storage and allocator metadata.

`tests/replay_nodes/benchmark.py` compares frozen original Nodes2, indexing,
caching and typed binding. `compare_sparse.py` alternates pre/post sparse-fix
binaries across seven occupancy/capacity cases and verifies identical property
write counts and typed paint counts. All benchmarks run without concurrent builds.
Use the archived bridge performance assessment for results and limitations.
