# Snapshot extension compatibility

```sh
nix develop --command bash tests/replay_snapshot_compat/run.sh
```

The `reference/` directory freezes Replay's network runner—the runtime that
schedules simulation steps and manages network input/history—immediately before
the snapshot-parts extension, which splits snapshots for transfer. Its package declaration alone is renamed so both versions
can be linked in one process; the script verifies original and adapted hashes.
Do not silently refresh this reference when changing the current protocol.

Three actual pairs run: old server/new client, new server/old client, and new/new.
They use the same changing world and delayed memory transport. Base contract hashes
must match, received world ticks/payloads must advance and validate, and no resync
may occur. Only the new/new pair may send snapshot parts. This proves compatibility
with this pre-extension protocol-7 runner, not Kit, every historical protocol or a
real network/performance result.

The `parts_reference/` snapshot captures the intermediate protocol-7 runner with
fragmentation support but no LZ4 codec. The gate also executes all three pairings
against that version. Parts-only clients continue receiving their existing
encoding; LZ4 is selected only when its distinct capability bit was advertised.
The final acceptance marker is `REPLAY_SNAPSHOT_COMPAT_ALL_OK` after all six cases.
