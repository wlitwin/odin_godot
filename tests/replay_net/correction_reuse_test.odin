package replay_net_test
import "core:reflect"
import "core:testing"
import net "godot:replay/net"
import r "godot:replay"

@(test)
identical_corrections_reuse_steps_without_changing_confirmed_world_or_journal :: proc(t: ^testing.T) {
    plain, cached: Fixture
    fixture_init(&plain)
    fixture_init(&cached)
    defer fixture_destroy(&plain)
    defer fixture_destroy(&cached)

    for &client in cached.clients {
        client.reuse_equal_corrections = true
    }

    for _ in 0 ..< 160 {
        fixture_step(&plain)
        fixture_step(&cached)
    }

    for i in 0 ..< 3 {
        a, b := &plain.clients[i], &cached.clients[i]
        testing.expect_value(t, a.phase, net.Phase.Running)
        testing.expect_value(t, b.phase, net.Phase.Running)
        af, _ := r.current(&a.timeline)
        bf, _ := r.current(&b.timeline)
        testing.expect(t, reflect.equal(af, bf))
        testing.expect(t, reflect.equal(a.authority_frame, b.authority_frame))
        testing.expect_value(t, a.journal.confirmed, b.journal.confirmed)
        testing.expect_value(t, a.journal.watch_tick, b.journal.watch_tick)
        testing.expect_value(t, a.stats.resyncs, b.stats.resyncs)

        if i < 2 {
            testing.expect(t, b.stats.reused_correction_ticks > 0 && b.stats.replayed_ticks < a.stats.replayed_ticks)
        }
    }

    // Changed movement still flows through simulation/correction.
    for _ in 0 ..< 100 {
        fixture_step(&plain, true)
        fixture_step(&cached, true)
    }

    for i in 0 ..< 3 {
        testing.expect(t, reflect.equal(plain.clients[i].authority_frame, cached.clients[i].authority_frame))
    }
}
