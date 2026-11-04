This is a real Core/SDK fixture, built by the ordinary `build/build_scripts.sh`
in a NEW copied project with the current verified shared Native library. Root
owns compilation, import and execution of `test_quota.gd`; no support worker
compiler/runtime has run it at the source checkpoint.

The one protected `ProductionQuotaProbe.exercise()` callback constructs separate
Kit and Replay cases. Kit uses the public SDK context and exact provider/author
block leases; Replay uses a real Meter allocator plus image, codec and model
Data_Lease/code owners around an actual complete Timeline/codec. All source data
and callbacks live through their typed teardown. No fake Core service is used.

Each case reuses `tests/box3d_modules/quota_fixture`: actual allocated host blocks
and retained Native-world dump buffers, observed through the common Native owner
ledger. It fills the exact remaining64MiB admission, rejects a real extra-byte
Meter allocation, and refuses the named real framework operation. Kit tests
complete checkpoint export; Replay tests a managed tick. Both retain the prior
complete state, release actual pressure, compare state and resume. Replay compares
all five public canonical parts. Raw Native capture does not implicitly include
HOST; that separate explicit-extra contract is tested by the standalone group.

Case teardown releases pressure, Native auxiliary world, adapters/Timeline/codec,
actual creator owners, Runtime allocation and Meter. Reported cleanup includes
actual Native/wrapper/Meter bytes plus observed global owner baseline/delta,
without assuming the global baseline is zero. Any failed status remains failure.
The project opens no transport and adds no clock, private head/row setter,
manual Replay Reset, Native/Core/codec change or second test framework.
