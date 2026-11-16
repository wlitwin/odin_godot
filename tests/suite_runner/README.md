# Suite selection and results

Run the suite from the repository root inside `nix develop`. Engine checks need
`GODOT` to name the matching executable on Linux. With no arguments, every manifest entry is
selected. Exact names select focused checks:

```sh
bash tests/run_all.sh --list
SKIP_WEB=1 bash tests/run_all.sh flow replaybrowsercheckpoint replayslop3
```

The small core in `tests/core.tsv` has 20 entry points, grouped by component:

```sh
bash tests/run_core.sh bridge
env -u GODOT bash tests/run_core.sh kit
bash tests/run_core.sh replay
env -u GODOT bash tests/run_core.sh utilities
bash tests/run_core.sh all --list
env -u GODOT bash tests/run_core.sh replay --unit
```

`--unit` selects only the component's explicitly engine-free entries. Kit and
utilities are entirely engine-free; Replay has eight engine-free entries plus
one real ENet recovery test. Bridge includes three Godot integration checks.
Native/WASM simulation equality is executed by `replaydeterministic`; the actual
network recovery test remains independently selectable as `replayreplica`.

`run_core.sh` only selects names and delegates to `run_all.sh`. It clears inherited
shard settings so a focused component cannot silently omit checks. Reports and
per-check logs default to `tests/.logs/core/<component>` (with `-unit` when used);
`SUITE_LOGDIR` still overrides that location. The existing result schema, limits,
failure handling and omitted-entry counts are shared with the full catalog.

Only a selection consisting entirely of entries explicitly marked engine-free
in `core.tsv` may run without `GODOT`. Other or mixed selections retain the engine
preflight. This is an execution boundary, not a claim that omitted example,
browser, physics or integration tests passed. Box3D workflows remain separate.

Each entry in `tests/run_all.sh` declares its execution capability:

| Capability | `SKIP_WEB=1` behavior |
| --- | --- |
| `native` | Runs, including Node-only tests and WebAssembly compile checks |
| `browser` | Reports SKIP without running browser setup |
| `mixed` | Runs required native checks, then reports the omitted browser portion as SKIP |
| `gated-browser` | Legacy export/browser check; reports SKIP |

A mixed script emits `SUITE_NATIVE_ONLY_OK` only after its native assertions
complete. A nonzero exit remains a failure even if a pass or skip marker was
printed earlier. Browser-enabled execution still requires the full completion
marker. Do not label a test by whether its name contains “web” or “browser.”

Partition the manifest by stable row position with a zero-based shard index:

```sh
SKIP_WEB=1 SUITE_SHARD_INDEX=0 SUITE_SHARD_COUNT=4 bash tests/run_all.sh
```

Run parallel shards in separate checkouts because example build paths are
shared within a checkout. Exact-name selection and sharding can be combined.
Unknown names, missing capabilities, empty selections, and invalid shard
settings fail before execution.

`tests/.logs/report.json` records the full manifest size, selected/omitted
counts, shard, per-check status, exit code, elapsed time, log, and whether a
mixed check completed its native portion. It is updated after every check and
on interruption. `complete=false` identifies an interrupted or aborted suite;
`success` applies to the selected checks. A focused or skipped run prints
`SELECTED CHECKS PASSED` rather than claiming the whole suite was green.

Set `SUITE_LOGDIR` for an external log/report directory and `TIMEOUT_SECS` for
the per-check wall-clock cap. The default is 600 seconds, with ten more seconds
for a terminated child's cleanup before a forced kill.

The runner sets the soft OS core-file limit to zero. Crash tests still inspect
the SDK's crash reports and debugger state. On Linux hosts that pipe crashes to
a core collector, configure that collector's storage/processing separately.

The runner's capability, sharding, failure, timeout, and interruption regressions
use isolated shell fixtures:

```sh
python3 -m unittest discover -s tests/suite_runner -v
```
