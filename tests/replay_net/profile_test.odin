package replay_net_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"

Probe_Time :: struct {
    now:   u64,
    valid: bool,
}

@(test)
profiling_uses_an_optional_clock_without_changing_simulation_or_failure_policy :: proc(t: ^testing.T) {
    a, b: Fixture
    fixture_init(&a)
    fixture_init(&b)
    defer fixture_destroy(&a)
    defer fixture_destroy(&b)
    clock := Probe_Time {
        valid = true,
    }
    a.clients[0].profile_clock = {
        user = &clock,
        read = proc(user: rawptr) -> (u64, bool) {
            clock := cast(^Probe_Time)user
            clock.now += 7
            return clock.now, clock.valid
        },
    }

    for _ in 0 ..< 60 {
        fixture_step(&a, true)
        fixture_step(&b, true)
    }

    stats := a.clients[0].stats
    testing.expect(t, stats.replay_samples > 0)
    testing.expect_value(t, stats.replay_wall_us, stats.replay_samples * 7)
    testing.expect_value(t, stats.replay_max_us, u64(7))
    testing.expect_value(t, stats.replay_histogram[3], stats.replay_samples)
    testing.expect_value(t, net.profile_percentile_upper(stats, 95), u64(7))
    left, _ := r.current(&a.clients[0].timeline)
    right, _ := r.current(&b.clients[0].timeline)
    testing.expect(t, reflect.equal(left, right))
    testing.expect_value(t, b.clients[0].stats.replay_samples, u64(0))
    clock.valid = false

    for _ in 0 ..< 12 {
        fixture_step(&a)
        fixture_step(&b)
    }

    testing.expect(t, a.clients[0].stats.profile_errors > 0)
    testing.expect_value(t, a.clients[0].phase, net.Phase.Running)
    left, _ = r.current(&a.clients[0].timeline)
    right, _ = r.current(&b.clients[0].timeline)
    testing.expect(t, reflect.equal(left, right))
}
