package replay_net_test

import "core:testing"
import "core:fmt"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import v "godot:replay/view"

@(test)
same_epoch_welcome_preserves_confirmed_observer_effects :: proc(t: ^testing.T) {
    for already_queued in ([2]bool{false, true}) {
        f: Fixture
        fixture_init(&f)
        defer fixture_destroy(&f)
        f.server.model.step = proc(w: ^World, c: [2]Control, j, l: u64, ctx: ^r.Step(Event)) {
            model_step(w, c, j, l, ctx)

            if ctx.tick == 55 {
                r.emit(ctx, 100, 1, Event{seat = 1, value = 55})
            }
        }

        for _ in 0 ..< 45 {
            fixture_step(&f)
        }

        c := &f.clients[2]

        for _ in 0 ..< 60 {
            resync_effect_step(&f)

            if c.journal.confirmed >= 55 && (already_queued ? c.journal.watch_tick >= 55 : c.journal.watch_tick < 55) {
                break
            }
        }

        testing.expect(t, c.journal.confirmed >= 55)
        testing.expect(t, already_queued ? c.journal.queue_count > 0 : c.journal.watch_tick < 55)
        serial := c.serial
        begin_test_resync(c)

        // The ordinary wire request/Welcome path installs a fresh snapshot. Do not
        // drain this observer until after that installation; other clients keep up.
        for _ in 0 ..< 60 {
            resync_effect_step(&f)

            if c.serial > serial && c.phase == .Running {
                break
            }
        }

        testing.expect(t, c.serial > serial && c.phase == .Running)
        changes: [512]v.Change(net.Net_Event(Event))
        begins := 0

        for {
            n := v.drain(&c.journal, changes[:])

            if n == 0 {
                break
            }

            for change in changes[:n] {
                if change.occurrence.value.kind == .Gameplay && change.occurrence.id.tick == 55 {
                    testing.expect(t, change.kind == .Begin && change.confirmed)
                    begins += int(change.kind == .Begin)
                }
            }
        }

        fmt.printf(
            "RESYNC_EFFECT queued=%v begins=%d serial=%d->%d baseline=%d\n",
            already_queued,
            begins,
            serial,
            c.serial,
            c.baseline,
        )
        testing.expect_value(t, begins, 1)

        for _ in 0 ..< 15 {
            resync_effect_step(&f)
        }

        testing.expect_value(t, v.drain(&c.journal, changes[:]), 0)
    }
}

resync_effect_step :: proc(f: ^Fixture, retained: int = 2) {
    assert(tr.memory_advance(&f.network, f.clock))
    now := f.clock * 1000 / 60
    assert(net.server_pump(&f.server, now) == .None)

    for &client in f.clients {
        assert(net.client_pump(&client, now) == .None)
    }

    assert(net.server_step(&f.server) == .None)

    for &client, i in f.clients {
        if !client.spectator && client.phase == .Running {
            err := net.client_step(&client, Control{})
            assert(err == .None || err == .Capacity)
        }

        if i != retained {
            changes: [512]v.Change(net.Net_Event(Event))

            for v.drain(&client.journal, changes[:]) > 0 {}
        }
    }

    f.clock += 1
}

@(test)
same_epoch_welcome_does_not_duplicate_an_already_journaled_action_verdict :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, action_timing = .Receipt)
    defer fixture_destroy(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    c := &f.clients[0]
    sequence, error := net.client_issue(c, Action{take = true})
    testing.expect_value(t, error, net.Error.None)

    for _ in 0 ..< 45 {
        resync_effect_step(&f, 0)

        if c.outcome_count > 0 {
            break
        }
    }

    testing.expect_value(t, c.outcome_count, 1)
    serial := c.serial
    begin_test_resync(c)

    for _ in 0 ..< 60 {
        resync_effect_step(&f, 0)

        if c.serial > serial && c.phase == .Running {
            break
        }
    }

    testing.expect(t, c.serial > serial && c.phase == .Running)
    changes: [512]v.Change(net.Net_Event(Event))
    finals := 0

    for {
        n := v.drain(&c.journal, changes[:])

        if n == 0 {
            break
        }

        for change in changes[:n] {
            if change.occurrence.value.kind == .Action_Result &&
               change.occurrence.value.sequence == sequence &&
               change.confirmed &&
               (change.kind == .Begin || change.kind == .Confirm) {
                finals += 1
            }
        }
    }

    outcomes: [8]net.Action_Outcome
    recovered: [8]bool
    testing.expect_value(t, net.client_outcomes(c, outcomes[:], recovered[:]), 1)
    testing.expect(t, finals == 1 && outcomes[0].sequence == sequence && outcomes[0].applied && !recovered[0])
}

@(test)
same_epoch_welcome_defers_atomically_until_effect_output_is_drained :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    c := &f.clients[0]
    baseline := c.journal.confirmed
    // Small, valid output capacity makes normal speculative batches apply
    // backpressure before a Welcome would need to append their cancellations.
    v.journal_destroy(&c.journal)
    testing.expect_value(
        t,
        v.journal_init(
            &c.journal,
            epoch = c.cfg.epoch,
            baseline = baseline,
            cfg = {int(c.cfg.history), net.WIRE_EVENTS, 2 * net.WIRE_EVENTS},
        ),
        v.Error.None,
    )

    for offset in u64(1) ..= 2 {
        tick := baseline + offset
        events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(Event))

        for &event, i in events {
            event = {
                id = {c.cfg.epoch, tick, 100, u64(i)},
                value = {kind = .Gameplay, value = {seat = 1, value = u32(i)}},
            }
        }

        testing.expect_value(t, v.sync_tick(&c.journal, tick, events[:]), v.Error.None)
    }

    testing.expect_value(t, c.journal.queue_count, 2 * net.WIRE_EVENTS)
    serial := c.serial
    before, _ := r.current(&c.timeline)
    begin_test_resync(c)

    for _ in 0 ..< 12 {
        resync_effect_step(&f, 0)
    }

    after, _ := r.current(&c.timeline)
    testing.expect(
        t,
        c.phase == .Resyncing && c.serial == serial && reflect.equal(before, after) && c.journal.baseline == baseline,
    )
    testing.expect_value(t, c.journal.queue_count, 2 * net.WIRE_EVENTS)
    changes: [2 * net.WIRE_EVENTS]v.Change(net.Net_Event(Event))
    testing.expect_value(t, v.drain(&c.journal, changes[:]), len(changes))

    for _ in 0 ..< 90 {
        resync_effect_step(&f, 0)

        if c.serial > serial && c.phase == .Running {
            break
        }
    }

    testing.expect(t, c.serial > serial && c.phase == .Running)
    testing.expect_value(t, v.drain(&c.journal, changes[:]), len(changes))

    for change in changes {
        testing.expect(t, change.kind == .Cancel && !change.confirmed)
    }
}
