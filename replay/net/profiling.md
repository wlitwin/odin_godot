# Runner timing diagnostics

Set a runner's `profile_clock` to a monotonic microsecond clock. `profile_metrics`
records bounded histograms and optional `profile_sample(user, metric, elapsed_us)`
receives raw durations. The sample callback should write to preallocated storage;
it must not affect gameplay or block on I/O. Nothing is serialized or transmitted.

| Metric | Measured work |
| --- | --- |
| Advance | An ordinary timeline advance: candidate copy, model execution and timeline validation/commit |
| Pump | Complete network pump, including nested snapshot/replay work |
| Snapshot | Server encoding/delta/send/cache work, or client validation/decompression/decoding/acknowledgment |
| Replay | The authoritative correction and suffix replay operation |
| Snapshot_Encode | Server frame/packet construction and canonical encoding, or client canonical decoding |
| Snapshot_Delta | Server delta/envelope construction, or client envelope validation, reconstruction and target-hash verification |
| Snapshot_Hash | Server digest of the newly encoded canonical snapshot |
| Snapshot_Cache | Retaining the canonical snapshot and its already computed digest |
| Snapshot_Validate | Client metadata, model-state and held-control validation |
| Snapshot_Send | Server transport submission or client acknowledgement submission |

Pump is inclusive; do not add its total to nested Snapshot/Replay totals. Advance
excludes client bootstrap catch-up and replayed ticks (Replay measures the latter
as a complete operation). Snapshot samples include rejected, duplicate and deferred
attempts: that work still consumed time. Server stepping may flush snapshots
outside the network pump. These are elapsed wall times, not thread CPU times.

Snapshot subphases are adjacent portions of the outer measurement. A rejected or
deferred operation may finish before reaching a subphase boundary, so their sample
counts need not equal the outer count. Clock failures increment timing errors;
they do not alter packet decisions. Existing enum values remain stable; new
subphase values are appended, and applications mapping metrics must handle them.

Client replay counters/histograms remain in `Stats` for compatibility. Optional
profiling failures do not fail simulation. Native tests compare profiled/unprofiled
worlds and protocol bytes and verify samples are delivered for the relevant phases.

Scrapyard's `bench_start`/`bench_finish` adds presentation and whole-frame samples,
writes a bounded CSV only after measurement, and reports protocol bytes and timeline
allocation sizes. Presentation measures command submission even in headless mode;
it is not GPU render time. Its final report computes exact nearest-rank percentiles
from raw samples rather than calling histogram bounds exact percentiles.

Large value copies should avoid unnecessary aggregate intermediates. In the
Scrapyard specialization, independent assignments and pointer selection over local
owned presentation copies preserve behavior while avoiding a pathological SLP
compile. See the [recorded IR/build evidence](../../docs/replay/results/scrapyard-copy-lowering-2026-09-06/README.md).
