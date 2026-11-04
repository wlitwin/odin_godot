# Box3D rewind benchmark

Run from the repository root:

```sh
nix develop --command python3 tests/box3d_bench/run.py --out /tmp/box3d-measurements
```

The output directory must be empty. The default run builds Debug and Release,
then runs 100 and 500 dynamic bodies for four fixed seeds and 2,400 ticks per
case, with 128 retained frames and seeded 1–30-tick rewinds. Build and raw run
logs, exact native manifests, compiler/binary/archive hashes, correctness counts,
memory metrics and nearest-rank p50/p95/max timings remain in the output folder.
Use `--cache PATH` to reuse verified native source/builds; `--skip-native-build`
requires a matching completed native build manifest, rather than trusting an
arbitrary archive. `BOX3D_BENCH_RUNTIME` records container/emulation context.

A short integration run is useful while bringing up the backend:

```sh
nix develop --command python3 tests/box3d_bench/run.py \
  --config Debug --bodies 100 --seeds 1 --ticks 96 --out /tmp/box3d-smoke
```

Short runs are explicitly not the full Gate A corpus. This runner produces
evidence; the separate reviewed Gate A report decides proceed/pivot/stop.

To collect actual contact/joint/body/island and moving-tree height peaks from the
same accepted reference trajectories after the full run:

```sh
nix develop --command python3 tests/box3d_bench/profile_counts.py \
  /tmp/box3d-measurements/summary.json --cache /tmp/box3d-measurements/native-cache
```

This compiles the small C helper with the measured archive's recorded compiler
and ABI flags. It generates a baseline-only entry point from the actual fixture
source and requires the final complete solver and game digests to match each
completed case. It does not guess contact counts from body count or alter the
timed binary. Its peaks describe the accepted reference trajectory, not transient
speculative branch worlds. Both measured archives and generated-source hashes
are retained in the supplemental report.

## What is compared

Two independently constructed worlds execute identical input sequences. The
reference never rewinds. Every forward and replayed candidate tick compares the
complete normalized solver bytes with its retained reference, plus a digest of
game side-state: tick/RNG, input edges, lifecycle counters, sensor observations,
query results, entity generations and entity/body index-generation mappings.
Mappings exclude world indices through the native identity API. A mismatch
retains expected/actual normalized bytes, complete local game-struct bytes and
tick/head/rewind-depth context, then fails the process. Local game artifacts include
native handles and compiler layout; they are diagnostic data, not a wire codec.

The fixture has a static triangle-mesh floor, dynamic boxes, one motorized hinge,
a convex sensor, deterministic impulses and sleep/wake commands, spatial/ray
queries, and sphere spawn/despawn. Every fourth rewind also creates a different
branch at the same tick, clones/releases that snapshot, moves the execution world
to a different state, restores the clone and compares its complete bytes. It then
steps that branch and an independently restored oracle world one tick, compares
both solver bytes and game state, and restores/replays the original suffix.
The first two rewinds force depth 1 and the maximum; later
depths come from a separate seeded rewind RNG. Native lifecycle tests cover other
geometry, failure and ownership cases; this benchmark does not replace them.

The upstream motion hash cannot satisfy this comparison. The normalized dump
still has a declared exact-source coverage/version and host-configuration
prerequisites; this corpus does not prove arbitrary game or cross-target
determinism. There are no framework adapters or audiovisual effects in this
fixture, so their behavior remains a separate acceptance gate.

## Interpreting cost and memory

- `step` times only the normal forward Box3D fixed step.
- `save` includes owned capture, old history-owner release and game-frame copy.
  Additional memory-metric queries and printed samples are outside this timer.
- `restore` times the complete native restore call, including its scratch work.
- `replay` sums game/solver advancement and measured history saves across the
  corrected suffix. Normalized comparison, printed timing samples and history
  accounting scans are outside this sum. Clock overhead is not subtracted.
- `checked_rewind` is the whole diagnostic operation, including comparisons and
  instrumentation. Its extra branch work is reported in a separate phase. It is
  not the production resimulation estimate.
- `dump` measures construction of a normalized comparison image.

Raw samples distinguish the initial capture, history fill, normal ring eviction
after tick H, and replay. The summary retains both aggregate and separate phase
quantiles. First-use fingerprint/setup is not silently folded into steady save
cost. Successful status checks do not format strings or allocate temporary
diagnostic messages.

Engine and owned-snapshot allocation counters measure requested bytes/calls, not
allocator overhead or RSS. Snapshot wrapper high water includes branch resources,
clone owners, imported-world leases, normalization caches and temporary digest
buffers. Per-resource image/geometry metrics are breakdowns, not independent
memory to add again. Distinct captures own distinct resources; transient clones
share their resource. Game history, History/Reference metadata, fixed simulation
storage and reference dumps are reported separately. The second/branch-oracle
worlds and reference dumps are verification costs. Separate maxima must not be
presented as one exact simultaneous peak. Flat-API geometry wrapper bookkeeping,
allocator headers/rounding, general call-stack/runtime and Odin allocation
overhead remain outside requested-byte figures. Native lifecycle tests separately
check zero retained engine and owned-wrapper allocations after teardown.

Keep cold builds/setup separate from warm samples. The environment records load
averages because other work can affect wall-time tails; container/emulated Linux
results identify their execution context and are not native-hardware throughput
claims. The native build manifest records effective SIMD, precision, validation,
assertions, floating-point flags, source pins and patches.
