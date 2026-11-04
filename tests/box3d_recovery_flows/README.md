# Complete Box3D recovery flows

This suite keeps Kit and Replay's existing recovery/session contracts separate.
It adds current public late-join, spectator, identity-replacement and canonical
recovery cases. `legacy-kit` selects the migrated existing Kit network suite;
its original source and failing records remain archived outside the workspace.

`run.py` defaults to a new inspectable plan and starts no jobs. Supply explicit
absolute Odin/Native/output paths, the exact current Native SHA and
`--suite kit|replay|legacy-kit|all`. Root schedules `--execute` after source freezes.
One test thread preserves each process's global Native allocation accounting.

Standalone results establish their declared public contracts, not Core/SDK global
ownership, actual exported process behavior, CPU bounds or cross-target equality.
Real lifecycle evidence and unsupported combinations must be reported separately.

The [current report](report.json) records 14 migrated Kit, three new Kit and four
new Replay groups passing separately on native macOS arm64 and translated Linux
x86_64. It also records fresh SDK Kit observer and both-framework reconnect
passes. The SDK Replay observer's action-conflict failure remains FAIL, with its
exact saved decisions and independent public spectator coverage stated explicitly.
Earlier failed compile/setup runs remain retained. No new long soak or CPU gate
was added, and no production source changed for this card.
