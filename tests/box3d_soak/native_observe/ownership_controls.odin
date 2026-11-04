package native_observe_test

import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"

// A bounded TEST DataLease wrapper, not an Owner forwarding trampoline. Core's
// actual Owner check/retain/drop callbacks are never replaced. The wrapper is
// producer code pinned by Core, and forwards the exact real Meter block lease.
// Its fixed static bytes are reported separately; it allocates nothing.
Drop_Test :: struct {
    lease:        bg.Data_Lease,
    decline_once: bool,
}

@(private)
drop_test: Drop_Test
drop_test_static_bytes :: u64(size_of(Drop_Test))

@(private)
drop_test_wrap :: proc(lease: bg.Data_Lease) -> (bg.Data_Lease, bg.Status) {
    if drop_test.lease.user != nil {
        return {}, bg.UNSUPPORTED
    }

    drop_test = {lease, true}
    return {lease.user, drop_test_retain, drop_test_drop}, bg.OK
}

@(private)
drop_test_cancel :: proc() {
    drop_test = {}
}

@(private)
drop_test_retain :: proc "c" (user: rawptr) -> bg.Status {
    if user != drop_test.lease.user || user == nil {
        return bg.INVALID_HANDLE
    }

    return drop_test.lease.retain(user)
}

@(private)
drop_test_drop :: proc "c" (user: rawptr) -> bg.Status {
    if user != drop_test.lease.user || user == nil {
        return bg.INVALID_HANDLE
    }

    if drop_test.decline_once {
        drop_test.decline_once = false
        return bg.UNSUPPORTED
    }

    status := drop_test.lease.drop(user)

    if status == bg.OK {
        drop_test = {}
    }

    return status
}

// Called under the actual public Node/Core origin gate, AFTER all source
// endpoints are really freed. No native world/step/clock or simulation occurs.
ownership_controls :: proc(memory: ^bm.Context) -> bool {
    before, be := bm.stats(memory)

    if be != bg.OK {
        return false
    }

    owner, ce := create(memory, true)

    if ce != bg.OK {
        return false
    }

    block := owner.block
    bad := owner
    bad.code_data.realm ~= 1
    ok := begin(&bad, .Structure) == bg.INCOMPATIBLE && owner.token == 0 && block.state == 0
    bad = owner
    bad.cookie ~= 1
    ok = ok && begin(&bad, .Structure) == bg.INCOMPATIBLE && owner.token == 0 && block.state == 0
    ok = ok && begin(&owner, .Structure) == bg.OK
    token := owner.token
    bad = owner
    bad.token += 1
    ok = ok && end(&bad) == bg.INVALID_HANDLE && bad.token == token + 1 && owner.token == token && block.state == 1
    ok = ok && end(&owner) == bg.OK && owner.token == 0 && block.state == 2
    // First drop declines AFTER free has marked the pinned block pending-free.
    // Owner, code/data and allocation remain retryable; the second attempt must
    // NOT issue a second free. Third destruction is harmless.
    ok = ok && destroy(&owner) == bg.UNSUPPORTED && owner.block == block && owner.free_requested && owner.token == 0
    ok = ok && bm.owns(memory, block, u64(size_of(Block))) && check(&owner, bg.READ) == bg.OK
    ok = ok && destroy(&owner) == bg.OK && owner.block == nil
    ok = ok && !bm.owns(memory, block, u64(size_of(Block))) && destroy(&owner) == bg.OK
    after, ae := bm.stats(memory)
    return(
        ok &&
        ae == bg.OK &&
        after.live_bytes == before.live_bytes &&
        after.references == before.references &&
        after.allocation_count == before.allocation_count &&
        after.requested_bytes == before.requested_bytes + u64(size_of(Block)) \
    )
}
