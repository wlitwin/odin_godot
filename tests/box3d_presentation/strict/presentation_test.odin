package presentation_strict_test

// Test-only gate setup follows tests/box3d_modules/replay/provider/provider_test.
// Native ledger, Host registry, Meter and owner checks are real. The code-image
// validator is deliberately a fake; actual dladdr/reload proof belongs to P4.1.
import "core:testing"
import b "godot:box3d"
import bg "godot:box3d/godot"
import bh "godot:box3d/godot/host"
import meter "godot:box3d/godot/meter"
import p "godot:box3d/presentation"
import r "godot:replay"
import ph "godot:replay/physics"
import rg "godot:replay/godot"
import k "godot:kit/sim"
import kp "godot:kit/physics"

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
    references: u32,
}

depth: u32

enter :: proc "c" (_: rawptr) -> bg.Status {
    depth += 1
    return bg.OK
}

leave :: proc "c" (_: rawptr) {
    depth -= 1
}

protected :: proc "c" (_: rawptr) -> bg.Status {
    return depth != 0 ? bg.OK : bg.INCOMPATIBLE
}

pin :: proc "c" (_: rawptr, code: rawptr) {
    (cast(^Code)code).references += 1
}

unpin :: proc "c" (_: rawptr, code: rawptr) {
    (cast(^Code)code).references -= 1
}

procedure :: proc "c" (_: rawptr, _: rawptr, code: rawptr) -> bg.Status {
    return code != nil ? bg.OK : bg.INCOMPATIBLE
}

Game :: struct {
    key:      b.Body_Key,
    lifetime: u64,
}

project_calls: u32

project :: proc(game: Game, out: []p.Binding) -> (u32, p.Error) {
    project_calls += 1
    out[0] = {
        id    = {1, game.lifetime},
        body  = p.Body_Key(game.key),
        asset = 1,
        alive = true,
    }
    return 1, .None
}

@(test)
managed_checkpoint_projection_requires_origin_realm_and_retained_allocator :: proc(t: ^testing.T) {
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
    testing.expect_value(t, bg.module_install(&service), bg.OK)
    testing.expect_value(t, enter(nil), bg.OK)
    origin, status := bh.origin_enter(service.user)
    testing.expect_value(t, status, bg.OK)
    memory, ms := meter.create(service, bg.CATEGORY_REPLAY_PROVIDER)
    testing.expect_value(t, ms, bg.OK)
    alloc := meter.allocator(memory)
    owner, os := ph.owner_context_create(
        meter.data_lease(memory),
        allocator_data = alloc.data,
        require_live_instance = false,
    )
    testing.expect_value(t, os, r.Error.None)
    world, ws := b.world_create(b.world_def_default())
    testing.expect_value(t, ws, b.Status.Ok)
    def := b.body_def_default()
    def.type = .Dynamic
    body, bs := b.body_create(world, def)
    testing.expect_value(t, bs, b.Status.Ok)
    _, ss := b.shape_box(body, b.shape_def_default(), {.25, .25, .25})
    testing.expect_value(t, ss, b.Status.Ok)
    key, ks := b.body_key(body)
    testing.expect_value(t, ks, b.Status.Ok)
    cfg := ph.config_default(1, b.build_fingerprint())
    cfg.initial_dynamic_bodies = 1
    cp, ce := ph.checkpoint_make(
        r.Frame(Game){state = {key, 3}},
        u64,
        world,
        cfg,
        allocator = alloc,
        ownership = owner,
    )
    testing.expect_value(t, ce, r.Error.None)
    testing.expect_value(t, b.world_destroy(&world), b.Status.Ok)
    testing.expect_value(t, ph.owner_context_destroy(&owner), r.Error.None)
    // Source allocator owner can be released: the CP retains its exact lease.
    testing.expect_value(t, meter.destroy(&memory), bg.OK)
    frame, ve, error := rg.physics_presentation_frame(&cp, project)
    testing.expect(t, error == .None && ve == .None && frame.rows[0].id.lifetime == 3)
    calls := project_calls
    saved_owner := cp.owner
    cp.owner.realm += 1
    _, _, error = rg.physics_presentation_frame(&cp, project)
    testing.expect(t, error != .None && project_calls == calls)
    cp.owner = saved_owner
    bh.origin_leave(origin)
    leave(nil)
    // Rejected read cannot reach typed Game projection; owner remains intact.
    _, _, error = rg.physics_presentation_frame(&cp, project)
    testing.expect(t, error != .None && project_calls == calls && cp.owner == saved_owner)
    forged := k.World_Checkpoint {
        owner = saved_owner,
    }
    forged.owner.realm += 1
    _, _, ke := kp.presentation_frame(&forged, 1, Game, project)
    testing.expect(t, ke != .Ok && project_calls == calls)
    testing.expect_value(t, enter(nil), bg.OK)
    origin, status = bh.origin_enter(service.user)
    testing.expect_value(t, status, bg.OK)
    again, ave, ae := rg.physics_presentation_frame(&cp, project)
    testing.expect(t, ae == .None && ave == .None && again == frame)
    testing.expect_value(t, r.complete_checkpoint_destroy(&cp), r.Error.None)
    testing.expect_value(t, bh.registry_stats().owners, u32(0))
    testing.expect_value(t, bh.registry_stats().marks, u32(0))
    bh.origin_leave(origin)
    leave(nil)
    testing.expect_value(t, bh.producer_destroy(service.user), bg.OK)
    testing.expect_value(t, bh.registry_shutdown(), bg.OK)
    stats: bg.Allocation_Stats
    testing.expect_value(t, engine_stats(&stats), bg.OK)
    testing.expect_value(t, stats.live_bytes, u64(0))
    testing.expect_value(t, wrapper_stats(&stats), bg.OK)
    testing.expect_value(t, stats.live_bytes, u64(0))
    testing.expect(t, code.references == 0 && depth == 0)
    // Copied presentation stays usable with no typed owner/source/native domain.
    view: p.View
    changes: [70]p.Change
    _, pe := p.present(&view, nil, &frame, 1, changes[:])
    testing.expect_value(t, pe, p.Error.None)
}
