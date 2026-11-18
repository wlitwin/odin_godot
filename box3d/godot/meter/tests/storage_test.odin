package box3d_godot_meter_test

import "base:runtime"
import "core:testing"
import "core:mem"
import bm ".."
import bg "godot:box3d/godot"

Storage_Host :: struct {
    meter: Host,
    owners: [16]Storage_Owner,
    created, fail_create: int,
}
Storage_Owner :: struct {
    lease: bg.Data_Lease,
    refs: u32,
    deny_drop: bool,
}
Payload :: struct { a: u64, b: [8]u8 }

storage_test_check :: proc "c" (user: rawptr, _: u32) -> bg.Status {
    return (cast(^Storage_Owner)user).refs > 0 ? bg.OK : bg.INVALID_HANDLE
}
storage_test_retain :: proc "c" (user: rawptr) -> bg.Status {
    o := cast(^Storage_Owner)user
    if o.refs == 0 { return bg.INVALID_HANDLE }
    o.refs += 1
    return bg.OK
}
storage_test_drop :: proc "c" (user: rawptr) -> bg.Status {
    o := cast(^Storage_Owner)user
    if o.refs == 0 { return bg.INVALID_HANDLE }
    if o.deny_drop { return bg.CAPACITY }
    if o.refs == 1 {
        if status := o.lease.drop(o.lease.user); status != bg.OK { return status }
    }
    o.refs -= 1
    return bg.OK
}
storage_test_service :: proc(h: ^Storage_Host) -> bg.Service {
    result := service(&h.meter)
    result.owner_create = proc "c" (user: rawptr, live: u32, lease: ^bg.Data_Lease, out: ^bg.Owner) -> bg.Status {
        // meter is the first field; the ordinary accounting fixture uses it.
        h := cast(^Storage_Host)user
        h.created += 1
        if h.created == h.fail_create { return bg.CAPACITY }
        if h.created > len(h.owners) { return bg.CAPACITY }
        o := &h.owners[h.created - 1]
        if status := lease.retain(lease.user); status != bg.OK { return status }
        o.lease = lease^
        o.refs = 1
        out^ = {user = o, realm = 31, context_caps = bg.MANAGED_DATA | (live != 0 ? bg.WEAK_INSTANCE : bg.INDEPENDENT_CONTEXT),
            check = storage_test_check, retain = storage_test_retain, drop = storage_test_drop}
        return bg.OK
    }
    return result
}
storage_test_host :: proc() -> Storage_Host {
    return {meter = {protected = true, limit = 64*1024*1024, requested = requested_baseline()}}
}

@(test)
storage_exact_alias_and_detached_allocator_keep_payload_until_last_drop :: proc(t: ^testing.T) {
    h := storage_test_host()
    storage: bm.Storage(Payload)
    testing.expect_value(t, bm.storage_open(&storage, storage_test_service(&h), 1, true), bg.OK)
    data := storage.data
    data.a = 71
    alias, error := bm.storage_bind(&storage, &data.a)
    testing.expect_value(t, error, bg.OK)
    again, ae := bm.storage_bind(&storage, &data.a)
    testing.expect_value(t, ae, bg.OK)
    testing.expect(t, again.user == alias.user)
    root, root_error := bm.storage_bind(&storage, data)
    testing.expect_value(t, root_error, bg.OK)
    testing.expect(t, root.user == alias.user) // first field and whole payload share an address
    live, live_error := bm.storage_bind(&storage,&data.a,true)
    testing.expect_value(t,live_error,bg.OK)
    testing.expect(t,live.user != alias.user && live.context_caps & bg.WEAK_INSTANCE != 0)
    // A retained allocator alone must preserve retired callback addresses while
    // the context lives; a new source cannot inherit them through malloc reuse.
    detached := storage.allocator_owner
    testing.expect_value(t, detached.retain(detached.user), bg.OK)
    testing.expect_value(t, bm.storage_close(&storage), bg.OK)
    testing.expect(t, storage.data == nil && storage.memory == nil)
    testing.expect_value(t, data.a, 71)
    testing.expect(t, h.meter.live > 0)
    other: bm.Storage(Payload)
    testing.expect_value(t, bm.storage_open(&other, storage_test_service(&h), 1), bg.OK)
    testing.expect(t, other.data != data)
    _, oe := bm.storage_bind(&other, &other.data.a)
    testing.expect_value(t, oe, bg.OK)
    testing.expect_value(t, bm.storage_close(&other), bg.OK)
    testing.expect_value(t, detached.drop(detached.user), bg.OK)
    testing.expect_value(t, h.meter.live, 0)
    testing.expect_value(t, bm.storage_close(&storage), bg.OK)
}

@(test)
storage_late_drop_failure_retains_control_after_payload_is_retired :: proc(t: ^testing.T) {
    h := storage_test_host()
    storage: bm.Storage(Payload)
    testing.expect_value(t, bm.storage_open(&storage, storage_test_service(&h), 1, true), bg.OK)
    _, ae := bm.storage_bind(&storage, &storage.data.b)
    testing.expect_value(t, ae, bg.OK)
    h.owners[0].deny_drop = true
    testing.expect_value(t, bm.storage_close(&storage), bg.CAPACITY)
    testing.expect(t, storage.closing && storage.creator_released && storage.data == nil && storage.memory != nil)
    testing.expect_value(t, h.owners[0].refs, 1)
    h.owners[0].deny_drop = false
    testing.expect_value(t, bm.storage_close(&storage), bg.OK)
    testing.expect_value(t, h.meter.live, 0)
}

@(test)
storage_partial_creation_and_alias_failure_are_destroyable :: proc(t: ^testing.T) {
    for failure in 1 ..= 3 {
        h := storage_test_host()
        h.fail_create = failure
        storage: bm.Storage(Payload)
        opened := bm.storage_open(&storage, storage_test_service(&h), 1, true)
        if failure <= 2 {
            testing.expect_value(t, opened, bg.CAPACITY)
        } else {
            testing.expect_value(t, opened, bg.OK)
            _, error := bm.storage_bind(&storage, &storage.data.a)
            testing.expect_value(t, error, bg.CAPACITY)
        }
        testing.expect_value(t, bm.storage_close(&storage), bg.OK)
        testing.expect_value(t, h.meter.live, 0)
        for owner in h.owners { testing.expect_value(t, owner.refs, 0) }
    }
}

@(test)
storage_final_context_refusal_does_not_retire_its_retry_alias :: proc(t: ^testing.T) {
    h := storage_test_host()
    storage: bm.Storage(Payload)
    testing.expect_value(t, bm.storage_open(&storage, storage_test_service(&h), 1), bg.OK)
    allocator := bm.allocator(storage.memory)
    extra := new(u64, allocator)
    extra^ = 42
    testing.expect_value(t, bm.storage_close(&storage), bg.INVALID_HANDLE)
    testing.expect(t, storage.closing && storage.memory != nil && storage.allocator_owner.user != nil)
    testing.expect_value(t, h.owners[0].refs, 1)
    mem.free(extra, allocator)
    testing.expect_value(t, bm.storage_close(&storage), bg.OK)
    testing.expect_value(t, h.meter.live, 0)
}

@(test)
storage_rejects_missing_owner_service_without_allocation :: proc(t: ^testing.T) {
    h := storage_test_host()
    storage: bm.Storage(Payload)
    testing.expect_value(t, bm.storage_open(&storage, service(&h.meter), 1), bg.INVALID_ARGUMENT)
    testing.expect(t, storage.memory == nil && storage.data == nil)
    testing.expect_value(t, h.meter.live, 0)
}
