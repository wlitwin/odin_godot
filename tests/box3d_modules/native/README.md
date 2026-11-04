P4 native domain and ledger support
===================================

`api.h` is authoritative. `ogb3_domain_contract_get/check` do not allocate,
initialize Box3D or probe/create a world. The cookie is an address in the loaded
native image. It distinguishes concurrent identical native copies; it is valid
only while that image remains loaded, is not an unload/reload generation, and
is never a persistent/network ID. The host must retain its DSO/code lease and
check the contract before passing foreign handles. ABI/logical/resource/recovery
versions remain 1/3/2/1. Build and target digests bind effective CMake inputs;
`build` is the raw native source/configuration SHA, not recovery's derived
build/fingerprint digest. `native-domain-identity.txt` records both embedded IDs.

The fixed ledger has 256 reusable generational token slots. Generation exhaustion
retires a slot. Tokens are possession capabilities, not an authentication scheme;
the host authenticates producer/component IDs and calls from the appropriate
producer realm. Distinct live producer/component pairs register once. Aggregate
one component's absolute host live/reserved bytes per token, not one token per
history image. The host controls resource and producer-code lifetimes.

For owner t, proposed admission is:

    engine requested + snapshot-wrapper requested
      + registered host live/reserved excluding t
      + proposed t live/reserved + unregistered extra live/reserved

Every native quantity occurs once. The bound is 67,108,864 bytes (64 MiB).
`set` atomically replaces t; convert a reservation to live in the same call.
`check` is read-only and returns the required total only on success. Token zero
means no replacement, so both proposed amounts must be zero. Additional amounts
exclude all already registered charges. Failed calls preserve outputs, tokens,
counters and the ledger. Release failed/unused reservations. Close after actual
host storage has been freed. A nonincreasing set or close remains available if a
legacy native allocation has already put the process over budget; an increasing
set and all checks still reject an over-budget total. This is admission and
requested-byte accounting, not an allocator hard cap or recoverable native OOM.

Legacy codec admission takes explicit `additional_owned_bytes` and adds its own
operation staging reserve. An adapter using this ledger must pass all registered
host live + OTHER registered reservations + unregistered extras, excluding only
the exact current operation reservation which that legacy codec itself adds.
The new host check always sees every ticket. Do not remove an unrelated ticket
or charge a registered component again. Owner_get and ledger_get permit this
exact subtraction under the single caller contract; neither guesses a producer.

Stats include current engine/wrapper bytes, aggregate host live and reservation
bytes, their live/admitted sums, successful ledger updates and the sampled
committed peak. The peak samples ledger commits, not every engine allocation.
Static ledger storage is an explicit overhead field, separate from requested
bytes. Allocator rounding, RSS and other previously documented overhead remain
separate measurements. The fixed ledger itself uses no malloc.

CMake adds `domain_static`, `domain_shared` and `domain_modules` to the existing
seven native test groups. The first two exercise all POD layouts, allocation-free
metadata before first initialization, every-byte contract mismatch, two owners,
exact bound/+1/overflow, reservation conversion, failures preserving outputs and
publication, stale/malformed/released tokens, all 256 slots, real native and
snapshot byte parity, source destruction and zero teardown. The third actually
loads two separately linked caller modules sharing the DSO and a forbidden
static-copy module. It verifies equal shared cookies/accounting, rejection of
the duplicate domain, and ledger survival after one caller module is unloaded.
Linux's negative static-copy fixture uses `-Bsymbolic` only to keep its deliberate
copy local in that fixture. Production shared compilation is unchanged.

These C tests are native support evidence. Actual Godot module code/allocator/
context leases, stable destructors, hot reload and the one-loaded-image production
inspection belong to the coordinator's integrated P4 acceptance. Whole adapter
4 ms Gate B remains unmet; these tests make no timing claim.
