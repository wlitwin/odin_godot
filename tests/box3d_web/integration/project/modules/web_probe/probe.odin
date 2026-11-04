//gd:extends Node
//gd:class WebProbe
package web_probe

import "base:runtime"
import "core:mem"
import "core:fmt"
import "core:encoding/json"
import gd "godot:godot"
import b "godot:box3d"
import a "godot:box3d/authoring"
import ga "godot:box3d/godot/authoring"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"

State :: struct {
    built:  a.Built_Scene,
    player: b.Body_Key,
    keys:   [4]b.Body_Key,
}

NAMES :: [4]string{"ground", "pendulum", "player", "sensor"}

WebProbe :: struct {
    owner: gd.Node,
    scope: ^meter.Context,
    state: ^State,
    ready: bool,
}

weak_owner: bg.Owner
bad_callback_calls: u32
PROFILE :: u64(0x57454250524f4245)

@(private)
ok :: proc(status: b.Status) {
    assert(status == .Ok, fmt.tprintf("native status %v", status))
}

json_result :: proc(value: $T) -> gd.String {
    bytes, error := json.marshal(value)
    assert(error == nil)
    defer delete(bytes)
    return gd.new_string_odin(string(bytes))
}

web_probe_ready :: proc(self: ^WebProbe) {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)
    service := bg.service_get()
    assert(service.realm != 0 && service.domain.pointer_bits == u32(size_of(rawptr) * 8))
    ok(b.abi_check())
    ok(b.recovery_abi_check())
    ok(b.authoring_asset_abi_check())
    ok(b.motion_abi_check())
    status: bg.Status
    self.scope, status = meter.create(service, bg.CATEGORY_KIT_PROVIDER)
    assert(status == bg.OK)
    allocator := meter.allocator(self.scope)
    self.state = new(State, allocator)
    assert(self.state != nil)
    source := gd.get_node(self.owner, "AuthoredWorld")
    assert(source != nil)
    baked, diagnostic := ga.extract(source, allocator)
    defer ga.diagnostic_destroy(&diagnostic)
    assert(diagnostic.error == .None, fmt.tprintf("extract %v %s", diagnostic.error, diagnostic.bake_diagnostic.field))
    body_id: u64

    for body in baked.data.bodies {
        if body.stable_key == "player" {
            body_id = body.logical_id
            break
        }
    }

    problem: a.Diagnostic
    self.state.built, problem = a.build(&baked, PROFILE)
    assert(problem.error == .None)

    for body in self.state.built.bodies {
        if body.logical_id == body_id {
            self.state.player = body.key
            break
        }
    }

    assert(self.state.player != 0)

    for name, index in NAMES {
        for body in baked.data.bodies {
            if body.stable_key == name {
                for mapping in self.state.built.bodies {
                    if mapping.logical_id == body.logical_id {
                        self.state.keys[index] = mapping.key
                        break
                    }
                }

                break
            }
        }

        assert(self.state.keys[index] != 0)
    }

    a.destroy(&baked)
    // A real weak owner is retained across this actual Odin Node's destruction.
    assert(service.owner_create(service.user, 1, nil, &weak_owner) == bg.OK)
    gd.node_queue_free(source)
    self.ready = true
    gd.print_str("WEBBOX_READY actual Core service, Meter callbacks and C/Odin ABI admitted")
}

Row :: struct {
    key:      string,
    position: [3]f32,
    rotation: [4]f32,
}

@(gd_method = "owned_return")
web_probe_step :: proc(self: ^WebProbe) -> gd.String {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)
    assert(self.ready && self.state != nil)
    ok(b.world_step_fixed(self.state.built.world))
    rows: [4]Row
    names := NAMES

    for key, index in self.state.keys {
        body, status := b.body_resolve(self.state.built.world, key)
        ok(status)
        pose, read := b.body_get_pose(body)
        ok(read)
        rows[index] = {
            names[index],
            {pose.position.x, pose.position.y, pose.position.z},
            {pose.rotation.x, pose.rotation.y, pose.rotation.z, pose.rotation.w},
        }
    }

    return json_result(rows)
}

world_bytes :: proc(world: b.World, allocator: mem.Allocator) -> []u8 {
    n, status := b.world_dump(world, nil)
    ok(status)
    out := make([]u8, int(n), allocator)
    m, filled := b.world_dump(world, out)
    ok(filled)
    assert(m == n)
    return out
}

world_equal :: proc(left, right: b.World, allocator: mem.Allocator) {
    a := world_bytes(left, allocator)
    defer delete(a, allocator)
    c := world_bytes(right, allocator)
    defer delete(c, allocator)
    assert(len(a) == len(c) && mem.compare_ptrs(raw_data(a), raw_data(c), len(a)) == 0)
}

exercise :: proc(self: ^WebProbe) -> u64 {
    assert(self.ready && self.state != nil)
    allocator := meter.allocator(self.scope)
    state := self.state
    player, status := b.body_resolve(state.built.world, state.player)
    ok(status)
    ok(b.body_apply_impulse(player, {.2, .1, .05}))

    for _ in 0 ..< 32 {
        ok(b.world_step_fixed(state.built.world))
    }

    saved, capture := b.snapshot_capture(state.built.world)
    ok(capture)

    defer {
        ok(b.snapshot_destroy(&saved))
    }

    n, queried := b.recovery_write(&state.built.catalog, &saved, nil)
    ok(queried)
    assert(n > 0 && n <= b.RECOVERY_MAX_BYTES)
    bytes := make([]u8, int(n), allocator)
    defer delete(bytes, allocator)
    again := make([]u8, int(n), allocator)
    defer delete(again, allocator)
    _, written := b.recovery_write(&state.built.catalog, &saved, bytes)
    ok(written)
    before := world_bytes(state.built.world, allocator)
    defer delete(before, allocator)
    domain, domain_status := b.domain_contract_get()
    ok(domain_status)
    ledger, ledger_status := b.host_ledger_get(domain.cookie)
    ok(ledger_status)
    external := ledger.host_live_bytes + ledger.host_reserved_bytes
    rejected, bad := b.recovery_read(&state.built.catalog, bytes[:len(bytes) - 1], external)
    assert(bad != .Ok && rejected._handle == nil)
    after := world_bytes(state.built.world, allocator)
    defer delete(after, allocator)
    assert(len(before) == len(after) && mem.compare_ptrs(raw_data(before), raw_data(after), len(before)) == 0)
    decoded, read_status := b.recovery_read(&state.built.catalog, bytes, external)
    ok(read_status)

    defer {
        ok(b.snapshot_destroy(&decoded))
    }

    m, reencoded := b.recovery_write(&state.built.catalog, &decoded, again)
    ok(reencoded)
    assert(m == n && mem.compare_ptrs(raw_data(bytes), raw_data(again), int(n)) == 0)
    // Release the original world, catalog and baked maps before restoration.
    ok(a.built_destroy(&state.built))
    left, left_status := b.world_create(b.world_def_default())
    ok(left_status)

    defer {
        ok(b.world_destroy(&left))
    }

    right, right_status := b.world_create(b.world_def_default())
    ok(right_status)

    defer {
        ok(b.world_destroy(&right))
    }

    ok(b.snapshot_restore(left, &saved))
    ok(b.snapshot_restore(right, &decoded))
    world_equal(left, right, allocator)

    for _ in 0 ..< 16 {
        ok(b.world_step_fixed(left))
        ok(b.world_step_fixed(right))
        world_equal(left, right, allocator)
    }

    return n
}

@(gd_method = "owned_return")
web_probe_exercise :: proc(self: ^WebProbe) -> gd.String {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)
    bytes := exercise(self)
    allocator := meter.allocator(self.scope)
    mem.free(self.state, allocator)
    self.state = nil
    assert(meter.destroy(&self.scope) == bg.OK)
    engine, es := b.engine_allocation_stats()
    ok(es)
    wrapper, ws := b.snapshot_allocation_stats()
    ok(ws)
    assert(engine.live_bytes == 0 && wrapper.live_bytes == 0)
    return json_result(struct {
        ok:                                         bool,
        pointer_bits, asset_bytes, asset_align:     u32,
        canonical_bytes, native_live, wrapper_live: u64,
        source_free_steps:                          u32,
    } {
        true,
        u32(size_of(rawptr) * 8),
        u32(size_of(b.Recovery_Asset_V2)),
        u32(align_of(b.Recovery_Asset_V2)),
        bytes,
        engine.live_bytes,
        wrapper.live_bytes,
        16,
    })
}

@(gd_method = "owned_return")
web_probe_text :: proc(self: ^WebProbe) -> gd.String {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)
    return gd.new_string_odin(fmt.tprintf("actual web callback %d", self.ready ? 1 : 0))
}

temp_value :: proc(index: int) -> i64 {
    if context.temp_allocator.procedure != runtime.arena_allocator_proc || context.temp_allocator.data == nil {
        return -1
    }

    arena := cast(^runtime.Arena)context.temp_allocator.data

    switch index {
    case 0:
        return i64(arena.total_used)
    case 1:
        return i64(arena.total_capacity)
    case 2:
        return i64(arena.temp_count)
    }

    return -1
}

@(gd_method)
web_probe_temp_used :: proc(self: ^WebProbe) -> i64 {
    return temp_value(0)
}

@(gd_method)
web_probe_temp_capacity :: proc(self: ^WebProbe) -> i64 {
    return temp_value(1)
}

@(gd_method)
web_probe_temp_count :: proc(self: ^WebProbe) -> i64 {
    return temp_value(2)
}

@(gd_method)
web_probe_churn :: proc(self: ^WebProbe) -> u32 {
    service := bg.service_get()
    first: bg.Owner
    completed: u32

    for index in 0 ..< 70000 {
        owner: bg.Owner
        assert(service.owner_create(service.user, 1, nil, &owner) == bg.OK)

        if index == 0 {
            first = owner
        }

        assert(owner.check(owner.user, bg.EXECUTE) == bg.OK)
        dropped := owner.drop(owner.user)

        if dropped != bg.OK {
            panic("actual owner drop failed")
        }

        completed += 1
    }

    stale := first.check(first.user, bg.EXECUTE)

    if stale != bg.INVALID_HANDLE {
        panic("retired owner aliased a newer allocation")
    }

    return completed
}

@(gd_method)
web_probe_weak_live :: proc(self: ^WebProbe) -> bool {
    return weak_owner.check(weak_owner.user, bg.EXECUTE) == bg.OK
}

web_probe_exit_tree :: proc(self: ^WebProbe) {
    assert(self.state == nil && self.scope == nil)
}

when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
    foreign import image_bridge "env.o"

    foreign image_bridge {
        odin_box3d_table_base :: proc "c" () -> uintptr ---
        odin_box3d_table_size :: proc "c" () -> u32 ---
    }
}

never_drop :: proc "c" (_: rawptr) -> bg.Status {
    bad_callback_calls += 1
    return bg.OK
}

@(gd_method)
web_probe_origin_rejected :: proc(self: ^WebProbe) -> bool {
    when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
        service := bg.service_get()
        base := odin_box3d_table_base()
        count := uintptr(odin_box3d_table_size())
        assert(base > 0 && count > 0)

        for address in ([2]uintptr{base - 1, base + count}) {
            lease := bg.Data_Lease {
                user   = self.scope,
                retain = cast(proc "c" (_: rawptr) -> bg.Status)(rawptr(address)),
                drop   = never_drop,
            }
            owner: bg.Owner
            status := service.owner_create(service.user, 0, &lease, &owner)
            assert(status == bg.INCOMPATIBLE || (address == 0 && status == bg.UNSUPPORTED))
            assert(owner.user == nil && bad_callback_calls == 0)
        }
    }

    return true
}
