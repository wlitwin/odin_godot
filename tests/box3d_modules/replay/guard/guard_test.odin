package replay_guard_test

import "core:testing"
import b "godot:box3d"
import bg "godot:box3d/godot"

Scope :: struct {
    allowed: bool,
    calls:   u64,
    cookie:  u64,
}

@(private)
scope: Scope

check :: proc "c" (pointer: rawptr, cookie: u64) -> bg.Status {
    gate := cast(^Scope)pointer
    gate.calls += 1

    if !gate.allowed || cookie != gate.cookie {
        return bg.INCOMPATIBLE
    }

    return bg.OK
}

EXPECTED_MISMATCH :: #config(TEST_EXPECTED_MISMATCH, false)

@(test)
required_domain_guard_preserves_all_owning_releases_and_denies_preinstall_native_calls :: proc(t: ^testing.T) {
    testing.expect(t, b.BOX3D_REQUIRE_DOMAIN)
    contract, cs := b.domain_contract_get()
    testing.expect_value(t, cs, b.Status.Ok)
    testing.expect_value(t, b.abi_check(), b.Status.Ok) // allocation-free discovery only

    when EXPECTED_MISMATCH {
        scope = {
            allowed = true,
            cookie  = contract.cookie,
        }
        testing.expect_value(t, b.domain_install(contract, &scope, check), b.Status.Incompatible)
        advertised: bg.Domain_Contract
        testing.expect_value(t, bg.module_contract(&advertised), bg.INCOMPATIBLE)
        testing.expect_value(t, scope.calls, u64(0))
        return
    }

    world, status := b.world_create(b.World_Def{})
    testing.expect_value(t, status, b.Status.Incompatible)
    testing.expect_value(t, world, b.World(0))
    _, ss := b.snapshot_capture(0)
    testing.expect_value(t, ss, b.Status.Incompatible)
    wrong := contract
    wrong.cookie += 1
    scope = {
        allowed = true,
        cookie  = contract.cookie,
    }
    testing.expect_value(t, b.domain_install(wrong, &scope, check), b.Status.Incompatible)
    testing.expect_value(t, scope.calls, u64(0))
    testing.expect_value(t, b.domain_install(contract, &scope, check), b.Status.Ok)
    world, status = b.world_create(b.world_def_default())
    testing.expect_value(t, status, b.Status.Ok)
    snapshot, snapshot_status := b.snapshot_capture(world)
    testing.expect_value(t, snapshot_status, b.Status.Ok)
    config := b.recovery_config_default()
    config.profile = 1
    assets := []b.Recovery_Asset{b.recovery_asset_box(1, {.25, .25, .25})}
    catalog, catalog_status := b.recovery_catalog_create(config, assets)
    testing.expect_value(t, catalog_status, b.Status.Ok)
    points := []b.Vec3{{0, 0, 0}, {1, 0, 0}, {0, 1, 0}, {0, 0, 1}}
    geometry, gs := b.geometry_hull(points)
    testing.expect_value(t, gs, b.Status.Ok)
    old_snapshot, old_catalog, old_geometry, old_world := snapshot._handle, catalog._handle, geometry._handle, world
    scope.allowed = false
    testing.expect_value(t, b.snapshot_destroy(&snapshot), b.Status.Incompatible)
    testing.expect_value(t, snapshot._handle, old_snapshot)
    testing.expect_value(t, b.recovery_catalog_destroy(&catalog), b.Status.Incompatible)
    testing.expect_value(t, catalog._handle, old_catalog)
    testing.expect_value(t, b.geometry_destroy(&geometry), b.Status.Incompatible)
    testing.expect_value(t, geometry._handle, old_geometry)
    testing.expect_value(t, b.world_destroy(&world), b.Status.Incompatible)
    testing.expect_value(t, world, old_world)
    _, clone_status := b.snapshot_clone(&snapshot)
    testing.expect_value(t, clone_status, b.Status.Incompatible)
    scope.allowed = true
    testing.expect_value(t, b.geometry_destroy(&geometry), b.Status.Ok)
    testing.expect_value(t, b.recovery_catalog_destroy(&catalog), b.Status.Ok)
    testing.expect_value(t, b.snapshot_destroy(&snapshot), b.Status.Ok)
    testing.expect_value(t, b.world_destroy(&world), b.Status.Ok)
    stats, st := b.engine_allocation_stats()
    testing.expect_value(t, st, b.Status.Ok)
    testing.expect_value(t, stats.live_bytes, u64(0))
    wrapper, wt := b.snapshot_allocation_stats()
    testing.expect_value(t, wt, b.Status.Ok)
    testing.expect_value(t, wrapper.live_bytes, u64(0))
}
