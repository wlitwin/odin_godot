package replay_capsule_test

import "core:testing"
import "base:runtime"
import bg "godot:box3d/godot"
import bh "godot:box3d/godot/host"
import r "godot:replay"
import f "godot:tests/replay_external/fixture"
import life "../fixture"

LIB :: #config(BOX3D_LIBRARY, "")
foreign import native {"system:" + LIB}

when ODIN_OS == .Linux {
    foreign import math "system:m"
}

foreign native {
    @(link_name = "ogb3_domain_contract_get")
    contract_get :: proc(_: ^bg.Domain_Contract) -> bg.Status ---
    @(link_name = "ogb3_engine_allocation_stats")
    engine_stats :: proc(_: ^bg.Allocation_Stats) -> bg.Status ---
    @(link_name = "ogb3_snapshot_allocation_stats")
    wrapper_stats :: proc(_: ^bg.Allocation_Stats) -> bg.Status ---
    @(link_name = "ogb3_host_owner_open")
    owner_open :: proc(_: u64, _: u64, _: u64, _: ^u64) -> bg.Status ---
    @(link_name = "ogb3_host_owner_set")
    owner_set :: proc(_: u64, _: u64, _: u64, _: u64) -> bg.Status ---
    @(link_name = "ogb3_host_owner_close")
    owner_close :: proc(_: u64, _: u64) -> bg.Status ---
    @(link_name = "ogb3_host_ledger_get")
    ledger_get :: proc(_: u64, _: ^bg.Ledger_Stats) -> bg.Status ---
}

Code :: struct {
    refs: u32,
}

Gate :: struct {
    depth: u32,
    code:  Code,
}

@(private)
gate: Gate

enter :: proc "c" (_: rawptr) -> bg.Status {
    gate.depth += 1
    return bg.OK
}

leave :: proc "c" (_: rawptr) {
    gate.depth -= 1
}

protected :: proc "c" (_: rawptr) -> bg.Status {
    return gate.depth > 0 ? bg.OK : bg.INCOMPATIBLE
}

code_retain :: proc "c" (rawptr, pointer: rawptr) {
    (cast(^Code)pointer).refs += 1
}

code_drop :: proc "c" (rawptr, pointer: rawptr) {
    (cast(^Code)pointer).refs -= 1
}

// Test gate only: actual Core uses loaded-image membership via dladdr.
procedure :: proc "c" (_: rawptr, _: rawptr, pointer: rawptr) -> bg.Status {
    return pointer != nil ? bg.OK : bg.INCOMPATIBLE
}

// Exact allocator subfield lease: the source dispatcher knows its own enclosing
// managed context layout. No other module reinterprets that typed context.
lease_retain :: proc "c" (pointer: rawptr) -> bg.Status {
    context = runtime.default_context()
    ctx := cast(^life.Context)(uintptr(pointer) - offset_of(life.Context, tracker))
    life.context_retain(ctx)
    return bg.OK
}

lease_drop :: proc "c" (pointer: rawptr) -> bg.Status {
    context = runtime.default_context()
    ctx := cast(^life.Context)(uintptr(pointer) - offset_of(life.Context, tracker))
    life.context_release(&ctx)
    return bg.OK
}

@(test)
real_host_registry_wraps_whole_replay_capsule_cleanup_and_preserves_freed_source_context :: proc(t: ^testing.T) {
    contract: bg.Domain_Contract
    testing.expect_value(t, contract_get(&contract), bg.OK)
    api := bg.Native_API{contract, engine_stats, wrapper_stats, owner_open, owner_set, owner_close, ledger_get}
    hooks := bg.Core_Hooks {
        enter       = enter,
        leave       = leave,
        protected   = protected,
        code_retain = code_retain,
        code_drop   = code_drop,
        procedure   = procedure,
    }
    testing.expect_value(t, bh.registry_init(api, hooks), bg.OK)
    service: bg.Service
    testing.expect_value(t, bh.producer_create(&gate.code, &service), bg.OK)
    testing.expect_value(t, r.owner_realm_install(service.realm), r.Error.None)
    testing.expect_value(t, enter(nil), bg.OK)
    scope, status := bh.origin_enter(service.user)
    testing.expect_value(t, status, bg.OK)
    weak: u64
    testing.expect_value(t, bh.context_create(service.user, &weak), bg.OK)
    bh.origin_leave(scope)
    scope, status = bh.origin_enter(service.user, weak)
    testing.expect_value(t, status, bg.OK)
    log: life.Log
    source := life.source_create(&log, 31)
    allocator := life.context_allocator(source.ctx)
    lease := bg.Data_Lease{allocator.data, lease_retain, lease_drop}
    owner: bg.Owner
    testing.expect_value(t, service.owner_create(service.user, 1, &lease, &owner), bg.OK)
    stats: f.Stats
    base, base_owner := f.checkpoint(i64, &stats, 9)
    external := base._external
    external.owner = owner
    external.owner_allocator_data = allocator.data
    image, ie := external.clone(base._image)
    testing.expect_value(t, ie, r.Error.None)
    events := []r.Occurrence(i64){{id = {epoch = 1, tick = 0, source = 1, key = 1}, value = 8}}
    checkpoint, ce := r.complete_checkpoint_adopt(
        base.frame,
        i64,
        external,
        image,
        base._image_bytes,
        1,
        events,
        allocator,
    )
    testing.expect_value(t, ce, r.Error.None)
    capsule, capsule_error := r.complete_capsule_create(&checkpoint, service, allocator)
    testing.expect_value(t, capsule_error, r.Error.None)
    testing.expect_value(t, r.complete_checkpoint_destroy(&checkpoint), r.Error.None)
    testing.expect_value(t, r.owner_drop(&owner), r.Error.None)
    testing.expect_value(t, bh.context_invalidate(weak), bg.OK)
    life.source_destroy(&source)
    testing.expect_value(t, bh.context_release(weak), bg.OK)
    testing.expect_value(t, log.instances_freed, u64(1))
    testing.expect_value(t, log.contexts_freed, u64(0))
    bh.origin_leave(scope)
    leave(nil)
    // Direct access is rejected; the stable host owns the outermost call/pin.
    clone: bg.Capsule
    args := bg.Capsule_Clone_Args{&clone}
    testing.expect_value(t, capsule.invoke(capsule.user, bg.CAPSULE_CLONE, &args), bg.OK)
    testing.expect_value(t, capsule.destroy(capsule.user), bg.OK)
    testing.expect_value(t, log.contexts_freed, u64(0))
    testing.expect_value(t, clone.destroy(clone.user), bg.OK)
    testing.expect_value(t, log.contexts_freed, u64(1))
    testing.expect_value(t, gate.code.refs, u32(0))
    testing.expect_value(t, gate.depth, u32(0))
    testing.expect_value(t, r.complete_checkpoint_destroy(&base), r.Error.None)
    f.owner_destroy(&base_owner)
    testing.expect_value(t, bh.producer_destroy(service.user), bg.OK)
    testing.expect_value(t, bh.registry_shutdown(), bg.OK)
}
