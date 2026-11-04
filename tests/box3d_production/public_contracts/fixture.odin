// Public, standalone Native/Kit/Replay contracts. Nil Owner/static linkage;
// not an actual SDK allocator/Core/performance or packet-impairment claim.
package box3d_production_public_test

import "core:mem"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import pf "godot:tests/replay_physics_net/fixture"
import kf "godot:tests/kit_box3d_net"
import k "godot:kit/sim"
import r "godot:replay"
import rn "godot:replay/net"
import ph "godot:replay/physics"
import ar "godot:tests/box3d_soak/replay/action_retire"

Pressure :: struct {
    cookie: u64,
    owner:  b.Host_Owner,
    bytes:  []u8,
}

pressure_fill :: proc(t: ^testing.T, p: ^Pressure) -> bool {
    contract, cs := b.domain_contract_get()
    testing.expect_value(t, cs, b.Status.Ok)

    if cs != .Ok {
        return false
    }

    p.cookie = contract.cookie
    owner, status := b.host_owner_open(p.cookie, 0x50524f445543544e, 1)
    testing.expect_value(t, status, b.Status.Ok)

    if status != .Ok {
        return false
    }

    p.owner = owner
    before, bs := b.host_ledger_get(p.cookie)
    testing.expect_value(t, bs, b.Status.Ok)

    if bs != .Ok {
        return false
    }

    testing.expect(t, before.limit_bytes == 67108864 && before.admitted_bytes < before.limit_bytes)
    size := before.limit_bytes - before.admitted_bytes
    bytes, error := mem.alloc_bytes(int(size))
    testing.expect(t, error == .None)

    if error != .None {
        return false
    }

    p.bytes = bytes

    // Actual owned host storage, touched page-by-page: never a scalar-only quota.
    for at := 0; at < len(bytes); at += 4096 {
        bytes[at] = 1
    }

    if len(bytes) > 0 {
        bytes[len(bytes) - 1] = 1
    }

    status = b.host_owner_set(p.cookie, p.owner, u64(len(bytes)), 0)
    testing.expect_value(t, status, b.Status.Ok)

    if status != .Ok {
        return false
    }

    full, fs := b.host_ledger_get(p.cookie)
    testing.expect(t, fs == .Ok && full.admitted_bytes == full.limit_bytes && full.limit_bytes == 67108864)
    _, one := b.host_memory_check(p.cookie, additional_live = 1)
    testing.expect_value(t, one, b.Status.Capacity)
    rejected := b.host_owner_set(p.cookie, p.owner, u64(len(bytes)) + 1, 0)
    testing.expect_value(t, rejected, b.Status.Capacity)
    after, rs := b.host_ledger_get(p.cookie)
    testing.expect(
        t,
        rs == .Ok &&
        after.live_bytes == full.live_bytes &&
        after.admitted_bytes == full.admitted_bytes &&
        after.owner_count == full.owner_count,
        "extra-byte refusal preserves actual accounting",
    )
    return fs == .Ok && one == .Capacity && rejected == .Capacity
}

pressure_drop :: proc(t: ^testing.T, p: ^Pressure) {
    if len(p.bytes) > 0 {
        delete(p.bytes)
        p.bytes = nil
    }

    if p.owner != 0 {
        testing.expect_value(t, b.host_owner_close(p.cookie, &p.owner), b.Status.Ok)
    }
}

catalog :: proc(t: ^testing.T) -> b.Recovery_Catalog {
    config := b.recovery_config_default()
    config.profile = pf.PROFILE
    assets: [4]b.Recovery_Asset

    for value, i in pf.assets() {
        assets[i] = {
            id     = value.id,
            kind   = b.Recovery_Asset_Kind(value.kind),
            a      = value.a,
            b      = value.b,
            radius = value.radius,
        }
    }

    result, status := b.recovery_catalog_create(config, assets[:])
    testing.expect_value(t, status, b.Status.Ok)
    return result
}

native_bytes :: proc(t: ^testing.T, snapshot: ^b.Snapshot) -> []u8 {
    size, status := b.snapshot_dump(snapshot, nil)
    testing.expect_value(t, status, b.Status.Ok)
    data := make([]u8, int(size))
    _, status = b.snapshot_dump(snapshot, data)
    testing.expect_value(t, status, b.Status.Ok)
    return data
}

discard :: proc(box: ^kf.Box) {
    for parcel in box.out {
        delete(parcel.bytes)
    }

    clear(&box.out)
}

kit_same :: proc(t: ^testing.T, left, right: ^k.World_Checkpoint) {
    same, error := k.world_checkpoint_equal(left, right)
    testing.expect(t, error == .Ok && same, "complete Native/Side/fields/effects preserved")
}

replay_same :: proc(t: ^testing.T, p: ^ar.Pair, left, right: ^r.Complete_Checkpoint(pf.Game, rn.Net_Event(pf.Event))) {
    a, ae := rn.complete_view(
        p.codec.value,
        left,
        &p.server.physics.schemas.state,
        &p.server.physics.schemas.occurrence,
    )
    testing.expect_value(t, ae, rn.Error.None)

    if ae != .None {
        return
    }

    defer rn.complete_view_destroy(&a)
    z, ze := rn.complete_view(
        p.codec.value,
        right,
        &p.server.physics.schemas.state,
        &p.server.physics.schemas.occurrence,
    )
    testing.expect_value(t, ze, rn.Error.None)

    if ze != .None {
        return
    }

    defer rn.complete_view_destroy(&z)

    for part in bd.Part {
        testing.expect(
            t,
            mem.compare(a.frame.parts[part], z.frame.parts[part]) == 0,
            "actual canonical five-part state unchanged",
        )
    }
}

cleanup :: proc(t: ^testing.T) {
    native, ns := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    contract, cs := b.domain_contract_get()
    ledger, ls := b.host_ledger_get(contract.cookie)
    testing.expect(
        t,
        ns == .Ok &&
        ws == .Ok &&
        cs == .Ok &&
        ls == .Ok &&
        native.live_bytes == 0 &&
        wrapper.live_bytes == 0 &&
        ledger.admitted_bytes == 0 &&
        ledger.owner_count == 0 &&
        ph.allocation_stats().live_bytes == 0,
    )
}
