# Paired elapsed clock

Timed authority leases require elapsed time to include suspension. Native Replay
uses the platform's continuous clock. Browser embeddings lack a uniformly
suspend-inclusive steady source, so `Paired_Clock` accepts wall and monotonic
millisecond samples and advances by the larger **incremental** delta.

A wall-clock advance accounts for a stopped monotonic clock during sleep. A
monotonic advance accounts for a slowly adjusted wall clock. Incremental deltas
avoid freezing the clock after a large forward wall offset. Quantization can
advance the combined clock faster and expire a grant early. Any observed backward
sample or arithmetic overflow permanently poisons it; it cannot revive a lease.
`Browser_Lease_Clock` supplies Godot's system Unix time and tick count to this core.

This contract assumes wall time does not conceal suspension by a backward
adjustment between samples. It does not resist a malicious authority process or
prove every browser/OS clock combination suitable. Poisoning requires a fresh
session; silently resetting the clock under an old lease would be unsafe. Tests
exercise stopped monotonic time against an actual Lease, backward samples,
post-offset progress and overflow. The browser control gate verifies real grant
acceptance followed by clock poisoning. Wider sleep/resume/clock-change acceptance
remains required before a broad browser-migration claim.
