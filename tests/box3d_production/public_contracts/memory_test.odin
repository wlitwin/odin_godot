package box3d_production_public_test

import "core:mem"
import "core:testing"
import b "godot:box3d"
import k "godot:kit/sim"
import r "godot:replay"
import rn "godot:replay/net"
import pf "godot:tests/replay_physics_net/fixture"
import kf "godot:tests/kit_box3d_net"
import ar "godot:tests/box3d_soak/replay/action_retire"

@(test)
native_actual_host_storage_at64m_extra_byte_and_operation_refuse_resume :: proc(t: ^testing.T) {
    defer cleanup(t)
    world, _, status := pf.world(4)
    testing.expect_value(t, status, b.Status.Ok)

    if status != .Ok {
        return
    }

    defer b.world_destroy(&world)
    cat := catalog(t)
    defer b.recovery_catalog_destroy(&cat)
    before, bs := b.snapshot_capture(world)
    testing.expect_value(t, bs, b.Status.Ok)

    if bs != .Ok {
        return
    }

    defer b.snapshot_destroy(&before)
    expected := native_bytes(t, &before)
    defer delete(expected)
    pressure: Pressure
    defer pressure_drop(t, &pressure)

    if !pressure_fill(t, &pressure) {
        return
    }

    _, refused := b.recovery_world_admit(&cat, world, u64(len(pressure.bytes)))
    testing.expect_value(t, refused, b.Status.Capacity)
    pressure_drop(t, &pressure)
    after, after_status := b.snapshot_capture(world)
    testing.expect_value(t, after_status, b.Status.Ok)

    if after_status != .Ok {
        return
    }

    defer b.snapshot_destroy(&after)
    actual := native_bytes(t, &after)
    defer delete(actual)
    testing.expect(
        t,
        mem.compare(expected, actual) == 0,
        "failed actual canonical operation cannot mutate published Native state",
    )
    _, resumed := b.recovery_world_admit(&cat, world)
    testing.expect_value(t, resumed, b.Status.Ok)
    testing.expect_value(t, b.world_step_fixed(world), b.Status.Ok)
}
