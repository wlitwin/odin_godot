package kit_module_fixture_test

import kf ".."
import "core:testing"
import bh "godot:box3d/godot/host"

import "base:runtime"
import "core:mem"
import b "godot:box3d"
import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"
import net "godot:kit/net"
import p "godot:kit/physics"
import sim "godot:kit/sim"

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

@(private)
Code :: struct {
    references: u64,
}

@(private)
gate_depth: u64

@(private)
enter :: proc "c" (_: rawptr) -> bg.Status {
    gate_depth += 1
    return bg.OK
}

@(private)
leave :: proc "c" (_: rawptr) {
    gate_depth -= 1
}

@(private)
protected :: proc "c" (_: rawptr) -> bg.Status {
    return gate_depth != 0 ? bg.OK : bg.INCOMPATIBLE
}

@(private)
pin :: proc "c" (_: rawptr, code: rawptr) {
    (cast(^Code)code).references += 1
}

@(private)
unpin :: proc "c" (_: rawptr, code: rawptr) {
    (cast(^Code)code).references -= 1
}

// Test-only procedure validator. Actual Godot Core uses loaded image dladdr.
@(private)
procedure :: proc "c" (_: rawptr, _: rawptr, pointer: rawptr) -> bg.Status {
    return pointer != nil ? bg.OK : bg.INCOMPATIBLE
}

@(private)
install :: proc "c" (service: ^bg.Service) -> bg.Status {
    return sim.world_owner_realm_install(service.realm) == .Ok ? bg.OK : bg.INCOMPATIBLE
}

@(test)
real_kit_checkpoint_capsule_has_no_source_and_frees_all_allocator_data :: proc(t: ^testing.T) {
    contract: bg.Domain_Contract
    testing.expect_value(t, contract_get(&contract), bg.OK)
    api := bg.Native_API{contract, engine_stats, wrapper_stats, owner_open, owner_set, owner_close, ledger_get}
    testing.expect_value(
        t,
        bh.registry_init(
            api,
            {
                enter = enter,
                leave = leave,
                protected = protected,
                code_retain = pin,
                code_drop = unpin,
                procedure = procedure,
            },
        ),
        bg.OK,
    )
    code: Code
    service: bg.Service
    testing.expect_value(t, bh.producer_create(&code, &service), bg.OK)

    when !#config(BOX3D_REQUIRE_DOMAIN, false) {
        testing.expect_value(t, bg.module_register(contract_get, install), bg.OK)
    }

    testing.expect_value(t, bg.module_install(&service), bg.OK)
    testing.expect_value(t, enter(nil), bg.OK)
    scope, status := bh.origin_enter(service.user)
    testing.expect_value(t, status, bg.OK)
    weak: u64
    testing.expect_value(t, bh.context_create(service.user, &weak), bg.OK)
    weak_source := new(u64)
    testing.expect_value(t, bh.context_bind(weak, weak_source, u64(size_of(u64))), bg.OK)
    bh.origin_leave(scope)
    scope, status = bh.origin_enter(service.user, weak)
    testing.expect_value(t, status, bg.OK)
    capsule: bg.Capsule
    info: kf.Factory_Info
    last: kf.Stats
    testing.expect_value(t, kf.create(&capsule, &info), bg.OK)
    testing.expect_value(t, info.source_objects_live, u64(0))
    testing.expect_value(t, info.managed_contexts_live, u64(1))
    testing.expect(t, info.host_live > 0)
    testing.expect_value(t, info.tick, u64(4))
    // A codec's allocator owner is distinct from its exact callback-user block.
    // Descriptor inputs are copied, so actual source metadata may be freed.
    managed, managed_error := p.sdk_context_create()
    testing.expect_value(t, managed_error, sim.World_Error.Ok)
    codec_allocator := bm.allocator(managed.memory)
    codec := new(p.Typed_Codec(u32), codec_allocator)
    codec_user, codec_user_error := p.sdk_user_owner_create(
        managed.memory,
        codec,
        u64(size_of(codec^)),
        codec,
        u64(size_of(codec^)),
    )
    testing.expect_value(t, codec_user_error, sim.World_Error.Ok)
    descriptor := new(net.Entity_Desc, codec_allocator)
    descriptor.fields = make([]net.Field_Desc, 1, codec_allocator)
    descriptor.fields[0] = {
        offset = 0,
        size   = size_of(u32),
        name   = "count",
        flags  = {.Predicted},
    }

    when #config(BOX3D_REQUIRE_DOMAIN, false) {
        before_requests: bg.Request_Totals
        after_requests: bg.Request_Totals
        testing.expect_value(t, service.request_totals(service.user, &before_requests), bg.OK)
        testing.expect_value(t, p.codec_init(codec, descriptor, codec_allocator), sim.World_Error.Unsupported)
        foreign_owner := codec_user
        foreign_owner.owner.realm += 1
        testing.expect_value(
            t,
            p.codec_init(codec, descriptor, codec_allocator, ownership = foreign_owner),
            sim.World_Error.Incompatible,
        )
        testing.expect_value(t, service.request_totals(service.user, &after_requests), bg.OK)
        testing.expect_value(t, after_requests, before_requests)
        testing.expect(t, !codec.schema.initialized)
    }

    testing.expect_value(
        t,
        p.codec_init(codec, descriptor, codec_allocator, ownership = codec_user),
        sim.World_Error.Ok,
    )
    delete(descriptor.fields, codec_allocator)
    free(descriptor, codec_allocator)
    value_codec := codec.value
    testing.expect_value(t, value_codec.acquire(value_codec.user), sim.World_Error.Ok)
    testing.expect_value(t, p.codec_destroy(codec), sim.World_Error.Busy)
    testing.expect_value(t, p.sdk_user_owner_destroy(&codec_user), sim.World_Error.Ok)
    codec_pointer := rawptr(codec)
    free(codec, codec_allocator)
    testing.expect(t, bm.owns(managed.memory, codec_pointer, u64(size_of(p.Typed_Codec(u32)))))
    local := u32(57)
    wire: [4]u8
    testing.expect_value(t, value_codec.encode(value_codec.user, (cast([^]u8)&local)[:4], wire[:]), sim.World_Error.Ok)
    testing.expect_value(t, wire[0], u8(57))
    testing.expect_value(t, value_codec.release(value_codec.user), sim.World_Error.Ok)
    testing.expect_value(t, p.codec_destroy(codec), sim.World_Error.Ok)
    testing.expect(t, !bm.owns(managed.memory, codec_pointer, u64(size_of(p.Typed_Codec(u32)))))
    testing.expect_value(t, p.sdk_context_destroy(&managed), sim.World_Error.Ok)
    envelope(t, service)
    testing.expect_value(t, bh.context_invalidate(weak), bg.OK)
    free(weak_source)
    testing.expect_value(t, bh.context_release(weak), bg.OK)
    bh.origin_leave(scope)
    leave(nil)
    // No protected origin remains in the test caller. Stable Core owns entry,
    // pinning and the return after every whole producer operation/destructor.
    state: b.Body_State
    body_args := p.SDK_Checkpoint_Body_Args {
        key   = info.key,
        state = &state,
    }
    testing.expect_value(t, capsule.invoke(capsule.user, p.SDK_CHECKPOINT_BODY_STATE, &body_args), bg.OK)
    testing.expect_value(t, u64(state.key), info.key)
    testing.expect(t, state.pose.position.y < 2)
    bytes := make([]u8, int(info.dump_bytes))
    defer delete(bytes)
    required: u64
    dump_args := p.SDK_Checkpoint_Dump_Args{raw_data(bytes), u64(len(bytes)), &required}
    testing.expect_value(t, capsule.invoke(capsule.user, p.SDK_CHECKPOINT_DUMP, &dump_args), bg.OK)
    testing.expect_value(t, required, info.dump_bytes)
    clone: bg.Capsule
    clone_args := bg.Capsule_Clone_Args{&clone}
    testing.expect_value(t, capsule.invoke(capsule.user, bg.CAPSULE_CLONE, &clone_args), bg.OK)
    clone_bytes := make([]u8, len(bytes))
    defer delete(clone_bytes)
    dump_args.out = raw_data(clone_bytes)
    testing.expect_value(t, clone.invoke(clone.user, p.SDK_CHECKPOINT_DUMP, &dump_args), bg.OK)
    testing.expect_value(t, mem.compare(bytes, clone_bytes), 0)
    testing.expect_value(t, capsule.destroy(capsule.user), bg.OK)
    _ = kf.stats(&last)
    testing.expect_value(t, last.managed_contexts_live, u64(1))
    testing.expect_value(t, clone.invoke(clone.user, p.SDK_CHECKPOINT_BODY_STATE, &body_args), bg.OK)
    testing.expect_value(t, clone.destroy(clone.user), bg.OK)
    _ = kf.stats(&last)
    testing.expect_value(t, last.managed_contexts_live, u64(0))
    testing.expect_value(t, last.host_live, u64(0))
    testing.expect_value(t, sim.world_checkpoint_owned_bytes(), u64(0))
    testing.expect_value(t, p.owned_bytes(), u64(0))
    testing.expect_value(t, code.references, u64(0))
    testing.expect_value(t, gate_depth, u64(0))
    testing.expect_value(t, bh.producer_destroy(service.user), bg.OK)
    testing.expect_value(t, bh.registry_shutdown(), bg.OK)
}
