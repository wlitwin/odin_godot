# Inspect two Replay Scrapyard saves

From the repository root:

```sh
nix develop --command odin build examples/replay_scrapyard/tools/inspect_run \
  -collection:godot=. -out:/tmp/replay-inspect-run
/tmp/replay-inspect-run first.replay second.replay --limit 32
```

The tool reads current-compatible checkpoints or complete save bundles, validates
their contracts/container metadata and required image references, then compares
canonical simulation fields. It accepts archives requiring a coordinator permit
for read-only inspection; it cannot grant a lease or resume a session. Old content
must first use the explicit save-conversion path.

Default comparison requires equal frame ticks and tick rates. Different epochs
are reported in metadata and do not prevent comparing a preserved checkpoint
across migration. `--allow-different-ticks` explicitly permits a before/after save
comparison; it is not a determinism test. Tick-rate mismatch always fails.

`--limit N` accepts 1–256 displayed differences (default 32). The report always
counts all differences and marks truncation. `--public` uses the public schema
projection, excluding authority-only fields from the output. The default authority
projection is for trusted local debugging.

The JSON report contains source paths, epoch/tick/content metadata, schema and
projection, equality/truncation flags and changed field paths with values and
canonical bits. Large integers remain strings so browser/JSON tools retain every
bit. A pool generation, ability timer or inventory count can therefore be identified
without comparing opaque whole-world hashes.

Exit codes: 0 for equal worlds, 1 for differences, 2 for invalid/incompatible input
or command-line arguments. Errors go to stderr; failed validation emits no partial
JSON report. Both input files remain unchanged. Reads are bounded to 16 MiB before
allocation. The tool compares the simulation world, not every transport/roster or
checkpoint-policy field; metadata and scope stay explicit in its output.

```sh
nix develop --command bash tests/replay_diagnostics/run.sh
```

The gate starts with a genuine current save, creates a separately validated
checkpoint changing health, scrap, an ability timer and an unused projectile-slot
generation, and checks the exact reported paths/values. It also tests equal input,
truncation, explicit cross-tick comparison, corruption, obsolete content and bad
limits. Hashes prove the inspection does not modify its sources.
