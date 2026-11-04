package replay_provider_host_test

import "core:testing"
import "core:mem"
import "base:runtime"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import bh "godot:box3d/godot/host"
import b "godot:box3d"
import ph "godot:replay/physics"
import r "godot:replay"

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
    depth:            u32,
    code, other_code: Code,
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


User_Config :: struct {
    amount: u64,
}

step :: proc(game: ^u64, input: i64, ctx: ^r.Step(i64)) {
    if ph.step(ctx.execution) != .None {
        r.abort(ctx)
        return
    }

    if input == 1 {
        definition := b.body_def_default()
        definition.type = .Dynamic
        ph.spawn(ctx.execution, 9999, definition)
        return
    }

    game^ += (cast(^User_Config)ctx.user).amount
}

@(test)
actual_host_service_composes_provider_owner_and_closes_nested_allocation_marks :: proc(t: ^testing.T) {
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
    service, other: bg.Service
    testing.expect_value(t, bh.producer_create(&gate.code, &service), bg.OK)
    testing.expect_value(t, bh.producer_create(&gate.other_code, &other), bg.OK)
    testing.expect_value(t, bg.module_profile(), u32(1))
    testing.expect_value(t, bg.module_install(&service), bg.OK)
    testing.expect_value(t, enter(nil), bg.OK)
    scope, status := bh.origin_enter(service.user)
    testing.expect_value(t, status, bg.OK)
    meter_context, ms := meter.create(service, bg.CATEGORY_REPLAY_PROVIDER)
    testing.expect_value(t, ms, bg.OK)
    alloc := meter.allocator(meter_context)
    ownership, oe := ph.owner_context_create(
        meter.data_lease(meter_context),
        allocator_data = alloc.data,
        require_live_instance = false,
    )
    testing.expect_value(t, oe, r.Error.None)
    world, ws := b.world_create(b.world_def_default())
    testing.expect_value(t, ws, b.Status.Ok)
    body_def := b.body_def_default()
    body_def.type = .Dynamic
    body_def.pose.position = {0, 2, 0}
    one, os := b.body_create(world, body_def)
    testing.expect_value(t, os, b.Status.Ok)
    _, one_shape := b.shape_box(one, b.shape_def_default(), {.25, .25, .25})
    testing.expect_value(t, one_shape, b.Status.Ok)
    body_def.pose.position = {1, 2, 0}
    two, ts := b.body_create(world, body_def)
    testing.expect_value(t, ts, b.Status.Ok)
    _, two_shape := b.shape_box(two, b.shape_def_default(), {.25, .25, .25})
    testing.expect_value(t, two_shape, b.Status.Ok)
    key, ks := b.body_key(one)
    testing.expect_value(t, ks, b.Status.Ok)
    config := ph.config_default(1, b.build_fingerprint())
    config.initial_dynamic_bodies = 2
    checkpoint, ce := ph.checkpoint_make(r.Frame(u64){}, i64, world, config, allocator = alloc, ownership = ownership)
    testing.expect_value(t, ce, r.Error.None)
    testing.expect_value(t, b.world_destroy(&world), b.Status.Ok)
    timeline: r.Timeline(u64, i64, i64)
    user := new(User_Config, alloc)
    user.amount = 1
    user_pointer := rawptr(user)
    lease, ls := meter.block_lease(meter_context, user, size_of(User_Config), user, size_of(User_Config))
    testing.expect_value(t, ls, bg.OK)
    user_binding, ubs := ph.owner_context_create(lease, user_data = user, require_live_instance = false)
    testing.expect_value(t, ubs, r.Error.None)
    testing.expect_value(
        t,
        r.init_complete(
            &timeline,
            &checkpoint,
            step,
            {128, 40},
            allocator = alloc,
            user = user,
            user_owner = user_binding.owner,
            user_data = user,
        ),
        r.Error.None,
    )
    testing.expect_value(t, ph.owner_context_destroy(&user_binding), r.Error.None)
    // Direct source free is deferred by this exact block/subfield lease. The
    // separate Timeline userOwner keeps the actual callback allocation alive.
    mem.free(user, alloc)
    user = nil
    testing.expect(t, meter.owns(meter_context, user_pointer, size_of(User_Config)))

    for _ in 0 ..< 3 {
        testing.expect_value(t, r.advance(&timeline, i64(0)).error, r.Error.None)
        testing.expect_value(t, r.confirm_through(&timeline, timeline.head), r.Error.None)
        testing.expect_value(t, bh.registry_stats().marks, u32(0))
    }

    current, found := r.current_values(&timeline)
    testing.expect(t, found && current.tick == 3 && current.state == 3)
    // Invalid command after a real fixed step must unwind its own child ticket
    // and the whole unpublished native execution, preserving the old pair.
    failed := r.advance(&timeline, i64(1))
    testing.expect_value(t, failed.error, r.Error.Invalid_Config)
    testing.expect_value(t, bh.registry_stats().marks, u32(0))
    unchanged, still := r.current_values(&timeline)
    testing.expect(t, still)
    testing.expect_value(t, unchanged, current)
    testing.expect_value(t, r.destroy(&timeline), r.Error.None)
    testing.expect(t, !meter.owns(meter_context, user_pointer, size_of(User_Config)))
    capsule, cap_error := ph.checkpoint_capsule_create(&checkpoint, service, allocator = alloc)
    testing.expect_value(t, cap_error, r.Error.None)
    borrowed, bws := b.world_create(b.world_def_default())
    testing.expect_value(t, bws, b.Status.Ok)
    testing.expect_value(t, r.complete_checkpoint_destroy(&checkpoint), r.Error.None)
    testing.expect_value(t, ph.owner_context_destroy(&ownership), r.Error.None)
    testing.expect_value(t, meter.destroy(&meter_context), bg.OK)
    bh.origin_leave(scope)
    leave(nil)
    // Only C-shaped args and the32-byte opaque Core capsule cross this boundary.
    state: b.Body_State
    read := ph.Capsule_Body_State_Args{key, &state}
    testing.expect_value(t, capsule.invoke(capsule.user, ph.PHYSICS_CAPSULE_BODY_STATE, &read), bg.OK)
    testing.expect_value(t, state.key, key)
    testing.expect_value(t, state.pose.position.y, f32(2))
    digest: b.World_Digests
    digests := ph.Capsule_Digests_Args{&digest}
    testing.expect_value(t, capsule.invoke(capsule.user, ph.PHYSICS_CAPSULE_DIGESTS, &digests), bg.OK)
    testing.expect(t, digest.complete_solver_digest != 0)
    required: u64
    query := ph.Capsule_Dump_Args {
        required = &required,
    }
    testing.expect_value(t, capsule.invoke(capsule.user, ph.PHYSICS_CAPSULE_DUMP, &query), bg.OK)
    bytes := make([]u8, int(required), runtime.heap_allocator())
    defer delete(bytes, runtime.heap_allocator())
    query.bytes = raw_data(bytes)
    query.capacity = required
    testing.expect_value(t, capsule.invoke(capsule.user, ph.PHYSICS_CAPSULE_DUMP, &query), bg.OK)
    clone: bg.Capsule
    clone_args := bg.Capsule_Clone_Args{&clone}
    testing.expect_value(t, capsule.invoke(capsule.user, bg.CAPSULE_CLONE, &clone_args), bg.OK)
    restore := ph.Capsule_Native_Restore_Args {
        world = borrowed,
    }
    // B holds an allocation promise. Origin-A cached reads remain valid, while
    // cloning and native restore must reject BEFORE changing B or its world.
    testing.expect_value(t, enter(nil), bg.OK)
    foreign_scope, fs := bh.origin_enter(other.user)
    testing.expect_value(t, fs, bg.OK)
    ticket: u64
    testing.expect_value(t, other.budget_begin(other.user, 1024 * 1024, &ticket), bg.OK)
    denied: bg.Capsule
    denied_args := bg.Capsule_Clone_Args{&denied}
    testing.expect_value(t, clone.invoke(clone.user, ph.PHYSICS_CAPSULE_BODY_STATE, &read), bg.OK)
    testing.expect_value(t, clone.invoke(clone.user, bg.CAPSULE_CLONE, &denied_args), bg.UNSUPPORTED)
    testing.expect(t, denied.user == nil)
    testing.expect_value(t, clone.invoke(clone.user, ph.PHYSICS_CAPSULE_NATIVE_RESTORE, &restore), bg.UNSUPPORTED)
    testing.expect_value(t, bh.registry_stats().marks, u32(1))
    testing.expect_value(t, other.budget_end(other.user, ticket), bg.OK)
    bh.origin_leave(foreign_scope)
    leave(nil)
    testing.expect_value(t, enter(nil), bg.OK)
    verify_scope, vs := bh.origin_enter(service.user)
    testing.expect_value(t, vs, bg.OK)
    untouched, us := b.world_counters(borrowed)
    testing.expect_value(t, us, b.Status.Ok)
    testing.expect_value(t, untouched.body_count, u32(0))
    bh.origin_leave(verify_scope)
    leave(nil)
    testing.expect_value(t, clone.invoke(clone.user, ph.PHYSICS_CAPSULE_NATIVE_RESTORE, &restore), bg.OK)
    testing.expect_value(t, capsule.destroy(capsule.user), bg.OK)
    testing.expect_value(t, clone.destroy(clone.user), bg.OK)
    testing.expect_value(t, enter(nil), bg.OK)
    scope, status = bh.origin_enter(service.user)
    testing.expect_value(t, status, bg.OK)
    restored, rs := b.body_resolve(borrowed, key)
    testing.expect_value(t, rs, b.Status.Ok)
    pose, ps := b.body_get_pose(restored)
    testing.expect_value(t, ps, b.Status.Ok)
    testing.expect_value(t, pose.position, state.pose.position)
    testing.expect_value(t, b.world_destroy(&borrowed), b.Status.Ok)
    testing.expect_value(t, ph.allocation_stats().live_bytes, u64(0))
    testing.expect_value(t, bh.registry_stats().marks, u32(0))
    testing.expect_value(t, bh.registry_stats().owners, u32(0))
    bh.origin_leave(scope)
    leave(nil)
    testing.expect_value(t, bh.producer_destroy(other.user), bg.OK)
    testing.expect_value(t, bh.producer_destroy(service.user), bg.OK)
    testing.expect_value(t, bh.registry_shutdown(), bg.OK)
    native: bg.Allocation_Stats
    testing.expect_value(t, engine_stats(&native), bg.OK)
    testing.expect_value(t, native.live_bytes, u64(0))
    testing.expect_value(t, wrapper_stats(&native), bg.OK)
    testing.expect_value(t, native.live_bytes, u64(0))
    testing.expect_value(t, gate.other_code.refs, u32(0))
    testing.expect_value(t, gate.code.refs, u32(0))
    testing.expect_value(t, gate.depth, u32(0))
}
