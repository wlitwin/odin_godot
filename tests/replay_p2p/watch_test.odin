package replay_p2p_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import rb "godot:replay/p2p"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"

Watch_Fixture :: struct {
    game:      Fixture,
    network:   tr.Memory,
    endpoints: [2]tr.Memory_Endpoint,
    watch:     rb.Watch(World, Input, Event, 2),
    source:    rb.Watch_Source(World, Input, Event, 2),
}

watch_setup :: proc(f: ^Watch_Fixture) {
    setup(&f.game)

    for _ in 0 ..< 80 {
        cycle(&f.game, 30)
    }

    assert(
        tr.memory_init(
            &f.network,
            seed = 58,
            cfg = {2, 512, 8192, 65536},
            faults = {
                latency_ticks = 3,
                jitter_ticks = 2,
                loss_permyriad = 1000,
                duplicate_permyriad = 1000,
                retry_ticks = 3,
            },
        ),
    )

    for &endpoint, i in f.endpoints {
        assert(tr.memory_open(&f.network, &endpoint, tr.Peer_Id(i + 1)))
    }

    cfg := rec.DEFAULT_CONFIG
    cfg.retry_ms, cfg.timeout_ms = 30, 500
    assert(
        rb.watch_init(
            &f.watch,
            r.Frame(World){},
            model(),
            [2]tr.Peer_Id{1, 2},
            1,
            tr.memory_transport(&f.endpoints[1]),
            77,
            f.game.peers[0].cfg,
            cfg,
        ) ==
        .None,
    )
    assert(
        rb.watch_source_init(&f.source, &f.game.peers[0], 2, tr.memory_transport(&f.endpoints[0]), 77, cfg) == .None,
    )
}

watch_cleanup :: proc(f: ^Watch_Fixture) {
    rb.watch_destroy(&f.watch)
    rb.watch_source_destroy(&f.source)

    for &endpoint in f.endpoints {
        wire := tr.memory_transport(&endpoint)
        tr.close(&wire)
    }

    tr.memory_destroy(&f.network)
    cleanup(&f.game)
}

watch_cycle :: proc(f: ^Watch_Fixture, until: u64) -> rb.Error {
    cycle(&f.game, until)
    tr.memory_advance(&f.network, f.game.clock)
    sent := rb.watch_source_pump(&f.source, f.game.clock * 1000 / 60)
    seen := rb.watch_pump(&f.watch, f.game.clock * 1000 / 60)

    if seen != .None {
        return seen
    }

    return sent
}

@(test)
late_spectator_replays_only_confirmed_values_without_joining_the_player_roster :: proc(t: ^testing.T) {
    f: Watch_Fixture
    watch_setup(&f)
    defer watch_cleanup(&f)
    _, known := rb.watch_current(&f.watch)
    testing.expect(t, !known)

    for _ in 0 ..< 500 {
        testing.expect_value(t, watch_cycle(&f, 240), rb.Error.None)
        frame, seen := rb.watch_current(&f.watch)

        if seen {
            testing.expect(t, frame.tick <= f.game.peers[0].timeline.confirmed)
        }
    }

    expect_reference(t, &f.game, 240)
    actual, seen := rb.watch_current(&f.watch)
    expected, _ := r.current(&f.game.peers[0].timeline)
    testing.expect(t, seen && reflect.equal(actual, expected))
    testing.expect_value(t, f.watch.states[f.watch.active].chain, f.game.peers[0].chain)
    testing.expect(t, f.watch.stats.installed > 1 && f.watch.stats.replayed > 0 && f.watch.stats.skipped_ticks >= 30)
    testing.expect_value(t, f.watch.stats.resets, u64(1))
    testing.expect_value(t, f.game.peers[0].roster, [2]tr.Peer_Id{1, 2})
    _, future := r.read(rb.watch_timeline(&f.watch), actual.tick + 1)
    testing.expect(t, !future)
}

@(test)
spectator_blackout_never_stalls_players_and_history_exhaustion_reports_a_new_baseline :: proc(t: ^testing.T) {
    f: Watch_Fixture
    watch_setup(&f)
    defer watch_cleanup(&f)

    for _ in 0 ..< 140 {
        testing.expect_value(t, watch_cycle(&f, 120), rb.Error.None)
    }

    tr.memory_set_faults(&f.network, {loss_permyriad = 10000, retry_ticks = 3})

    // Already delivered packets can still complete a transfer. Exhaust the
    // bounded transfer timeout and the player's retained history deliberately.
    for _ in 0 ..< 220 {
        testing.expect_value(t, watch_cycle(&f, 360), rb.Error.None)
    }

    before, _ := rb.watch_current(&f.watch)
    testing.expect(t, f.game.peers[0].timeline.confirmed > before.tick + u64(f.game.peers[0].cfg.history))
    tr.memory_set_faults(&f.network, tr.DEFAULT_FAULTS)

    for _ in 0 ..< 300 {
        testing.expect_value(t, watch_cycle(&f, 400), rb.Error.None)
    }

    expect_reference(t, &f.game, 400)
    after, _ := rb.watch_current(&f.watch)
    expected, _ := r.current(&f.game.peers[0].timeline)
    testing.expect(t, reflect.equal(after, expected))
    testing.expect(t, f.watch.stats.resets >= 2 && f.watch.reset.baseline_tick > f.watch.reset.previous_tick)
    testing.expect(t, f.watch.stats.skipped_ticks > 64)
}

@(test)
spectator_execution_mismatch_keeps_the_previous_complete_world_and_stops_installing :: proc(t: ^testing.T) {
    f: Watch_Fixture
    watch_setup(&f)
    defer watch_cleanup(&f)
    f.watch.states[0].model.step = proc(w: ^World, inputs: [2]Input, ctx: ^r.Step(Event)) {
        model_step(w, inputs, ctx)

        if ctx.tick == 50 {
            w.x[0] += 1
        }
    }
    detected := false

    for _ in 0 ..< 300 {
        if watch_cycle(&f, 160) == .Replay_Mismatch {
            detected = true
            break
        }
    }

    testing.expect(t, detected)
    testing.expect_value(t, f.watch.report.tick, u64(50))
    before, known := rb.watch_current(&f.watch)
    testing.expect(t, known && before.tick < 50)

    for _ in 0 ..< 30 {
        watch_cycle(&f, 160)
    }

    after, _ := rb.watch_current(&f.watch)
    testing.expect(t, reflect.equal(before, after))
    testing.expect_value(t, f.watch.error, rb.Error.Replay_Mismatch)
}

@(test)
spectator_refuses_a_changed_already_observed_baseline_even_if_the_chain_anchor_is_reused :: proc(t: ^testing.T) {
    f: Watch_Fixture
    watch_setup(&f)
    defer watch_cleanup(&f)

    for _ in 0 ..< 100 {
        testing.expect_value(t, watch_cycle(&f, 30), rb.Error.None)
    }

    before, known := rb.watch_current(&f.watch)
    testing.expect(t, known)
    changed := before
    changed.state.x[0] += 1
    testing.expect_value(t, r.reset_checkpoint(&f.game.peers[0].timeline, changed, 1), r.Error.None)
    f.source.transfer.acknowledged = {}

    for _ in 0 ..< 100 {
        f.game.clock += 1
        tr.memory_advance(&f.network, f.game.clock)
        rb.watch_source_pump(&f.source, f.game.clock * 1000 / 60)
        rb.watch_pump(&f.watch, f.game.clock * 1000 / 60)

        if f.watch.error == .Diverged {
            break
        }
    }

    testing.expect_value(t, f.watch.error, rb.Error.Diverged)
    testing.expect_value(t, f.watch.report.tick, before.tick)
    testing.expect(t, f.watch.report.expected != f.watch.report.actual)
    after, _ := rb.watch_current(&f.watch)
    testing.expect(t, reflect.equal(before, after))
}

@(test)
spectator_transfer_binding_is_checked_without_interfering_with_players :: proc(t: ^testing.T) {
    f: Watch_Fixture
    watch_setup(&f)
    defer watch_cleanup(&f)
    f.source.transfer.scope.binding = 78

    for _ in 0 ..< 180 {
        testing.expect_value(t, watch_cycle(&f, 120), rb.Error.None)
    }

    _, known := rb.watch_current(&f.watch)
    testing.expect(t, !known && f.watch.transfer.stats.rejected > 0)
    expect_reference(t, &f.game, 120)
}

@(test)
fresh_spectator_cannot_silently_reuse_a_sources_retained_delivery_session :: proc(t: ^testing.T) {
    f: Watch_Fixture
    watch_setup(&f)
    defer watch_cleanup(&f)

    for _ in 0 ..< 100 {
        testing.expect_value(t, watch_cycle(&f, 30), rb.Error.None)
    }

    testing.expect(t, f.source.transfer.acknowledged.archive.sequence > 0)
    rb.watch_destroy(&f.watch)
    cfg := rec.DEFAULT_CONFIG
    cfg.retry_ms, cfg.timeout_ms = 30, 500
    testing.expect_value(
        t,
        rb.watch_init(
            &f.watch,
            r.Frame(World){},
            model(),
            [2]tr.Peer_Id{1, 2},
            1,
            tr.memory_transport(&f.endpoints[1]),
            77,
            f.game.peers[0].cfg,
            cfg,
        ),
        rb.Error.None,
    )
    detected := false

    for _ in 0 ..< 100 {
        if watch_cycle(&f, 120) == .History {
            detected = true
            break
        }
    }

    testing.expect(t, detected)
    _, known := rb.watch_current(&f.watch)
    testing.expect(t, !known)
    testing.expect_value(t, f.source.transfer.remote_failure, rec.Failure.Retention)
}
