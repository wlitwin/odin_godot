# Canonical codec microbenchmark

```sh
nix develop --command bash tests/replay_schema_bench/run.sh
```

The benchmark builds with `-debug -o:speed`, initializes a public schema for a
Scrapyard-shaped snapshot, warms it, then times seven batches of 1,000 encode and
decode calls. It repeats the executable three times. All batches must produce the
same canonical byte hash. The report records native platform/compiler, exact
binary hashes, schema shape and median batch timings. There is no performance
threshold in this functional gate. The same large snapshot also executes through
the WASM codec, compares its canonical hash/size and rejects a late invalid float
without changing the decoded value.

`REPLAY_SCHEMA_BENCH_OUT` selects the result directory. To compare against an
explicitly retained schema source directory, set `REPLAY_SCHEMA_REFERENCE`. The
helper creates a temporary collection root: unchanged packages are borrowed through
symlinks and the reference schema is copied into that root. Both executables use
the same current benchmark/game value and build flags. Reference/current ordering
alternates across three pairs. The originals are never modified.

The reference directory must contain a coherent complete schema package; it is not
inferred from whichever source revision happens to be nearby. The comparison
artifact retains the actual reference source. Times describe warmed, in-process
codec calls, not whole-game callbacks or a statistical confidence interval.

Validation-density cases now accompany the initial Scrapyard-shaped snapshot:
zero, dense, sparse and alternating finite floats/booleans/enums. A varying
unconstrained counter byte prevents repeated decode inputs from being identical.
Each version runs seven trials per process and three alternating process pairs;
all canonical hashes must agree. The extra cases do not change the original
world-hash/WASM receipt. They measure codec calls, not a full-game speedup.
