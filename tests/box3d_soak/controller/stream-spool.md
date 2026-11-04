# Bounded disk intake

`Actor` retains stdout in exclusive `godot.log` and valid decoded events in
`intake.index` as references to that raw log. It keeps no event backlog in RAM.
The parser is unchanged. `observed_at` is read once at the original post-decode
reader point and stored as its binary f64; consumption never invents a new time.

`StreamBounds.log_bytes` bounds raw storage. `index_bytes` is a separate finite
bound including the96-byte header; its default equals `log_bytes`.
`pending_events` now limits records per consume call, together with optional
`consume(max_records=64)` and `consume_bytes` (default4MiB). It is not a retention
cap. The byte budget covers raw bytes, index/header reads and identity reads and
must fit one maximum-size record. A disk backlog can exceed1024 events while
RAM retains bounded working lines/records. Controller disk limits are separate
from the native/runtime64MiB requested-byte budget.

## API and finalization

- `Actor(..., identity=dict)` binds the Root-supplied source/build/role identity.
  Default identity is explicitly `{"status":"unknown"}` for legacy fixtures.
  The canonical JSON identity is bounded16KiB and stored in `intake-identity.json`.
- `pending_event_count`, `records_consumed`, `reader_eof` expose current facts;
  `events.qsize()/empty()/get_nowait()` remain available. Callback attempts count
  as consumed even when the callback rejects a record; they are never replayed.
- `consume(callback, max_records=64)` returns a batch count. It preserves the
  first callback exception but still consumes the rest of that bounded batch.
  Reader/index failure is explicit; a corrupt prefix is not skipped, so pending
  count can remain positive with zero progress.
- `finish()` waits for the actual process/reader, flushes/fsyncs/closes writer
  handles, and preserves the read handles. Its returned counters are a snapshot.
- Root must drain all valid batches fairly after EOF/fatal callback, preserving
  the first failure, and explicitly reject pending-with-zero-progress. Refresh
  `intake_facts()` or full `facts()` after draining before accepting cleanup.
- `close()` releases consumer handles idempotently after the reader ends.
  Closing with pending records latches failure and preserves their count.

`intake_facts()` reports raw/index paths, SHA256, actual bytes, both byte caps,
published/seen/consumed/pending/peak backlog counts, EOF, fsync and source identity.
An integrity failure remains in `integrity_error` and `Actor.error`; it does not
erase useful counters. Natural exit alone does not qualify endpoint cleanup.

## Binary format

All integers and f64 values are little-endian. Header96bytes:

| Offset | Field |
| --- | --- |
| 0 | magic `B3INTK01` (8bytes) |
| 8 | version u32 (1), record size u32 (96) |
| 16 | raw byte limit u64, index byte limit u64 |
| 32 | identity JSON SHA256 (32bytes) |
| 64 | SHA256 of preceding64 header bytes |

Each record is exactly96bytes:

| Offset | Field |
| --- | --- |
| 0 | sequence u64, raw offset u64, raw length u64 |
| 24 | original observed_at f64 |
| 32 | raw record SHA256 |
| 64 | SHA256(previous chain + preceding64 record bytes) |

The first chain predecessor is the header SHA256. Consumption verifies the
header/identity, sequence, nonoverlapping range, length, time, raw SHA and chain;
the committed-prefix tail also matches the producer's in-memory chain anchor.
The final whole-file proofs match the producer's byte counts and hashes. These
checks provide integrity evidence, not authentication.

Raw writes precede index writes; only complete entries become visible. FileIO
writes are unbuffered, and final EOF flush/fsync is required. This does not waive
the existing archive/SQLite durability or introduce crash-recovery acceptance.
Partial writes, exhausted disk/log/index bounds, overlong lines, parser errors,
tampering or fsync failures make evidence incomplete. The reader continues
draining stdout for real cleanup, retaining raw bytes up to the declared cap.
Successful acceptance requires all evidence retained and all committed entries
consumed; failures never become a reduced-work pass.

Pure controls use fake subprocess stdout and temporary files, not Godot/Native:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tests/box3d_soak/controller/test_stream_spool.py
```
