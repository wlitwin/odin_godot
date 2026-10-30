# Transport recording contract checks

`run.sh` runs native tests and a WASM type check for the optional transport trace
package. Tests cover exact round-trip calls/results, immutable payload copies,
callback absence/fallback behavior, zero generation forwarding, bounded recording
that still forwards after capacity/allocation failure, replay order/argument errors,
and transactional rejection of corrupted or forged out-of-bounds records.

No network connection or Godot process is required for these contract tests.
The companion Claimball trace fixture records and replays a real faulted ENet
observer with caller configuration, clock and state/effect expectations.
