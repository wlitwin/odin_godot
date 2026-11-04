package replay_net_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import tr "godot:replay/transport"

@(test)
correction_notice_samples_one_tick_and_owns_detached_frames :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, tr.Faults{latency_ticks = 3, retry_ticks = 3})
    defer fixture_destroy(&f)
    found_difference := false

    for _ in 0 ..< 90 {
        fixture_step(&f, true)
        n := f.clients[0].correction

        if n.serial == 0 {
            continue
        }

        testing.expect_value(t, n.before.tick, n.after.tick)
        testing.expect(t, n.authority_tick <= n.after.tick)
        testing.expect_value(t, u64(n.replayed_ticks), n.after.tick - n.authority_tick)
        stored, ok := r.read(&f.clients[0].timeline, n.after.tick)
        testing.expect(t, ok && reflect.equal(stored, n.after))

        if !reflect.equal(n.before.state, n.after.state) {
            found_difference = true
        }

        n.after.state.players[0].x = max(i32)
        testing.expect(t, f.clients[0].correction.after.state.players[0].x != max(i32))
    }

    testing.expect(t, found_difference)
}

@(test)
remote_hold_evolves_on_every_replayed_and_live_prediction_tick :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, tr.Faults{latency_ticks = 3, retry_ticks = 3})
    defer fixture_destroy(&f)

    // A legal non-idempotent hold exposes accidental reuse of the unadvanced
    // snapshot boundary on every prediction tick.
    toggle := proc(c: Control) -> Control {
        return {move = c.move == 0 ? 1 : 0}
    }

    f.server.model.hold = toggle

    for &client in f.clients {
        client.model.hold = toggle
    }

    checked := false

    for _ in 0 ..< 45 {
        fixture_step(&f)
        c := &f.clients[0]

        if c.correction.serial == 0 || !c.authority_frame.state.players[1].active {
            continue
        }

        steps := i32(c.correction.replayed_ticks)
        boundary := c.pending.held[1].move
        expected := c.authority_frame.state.players[1].x + (boundary == 0 ? (steps + 1) / 2 : steps / 2)
        testing.expect_value(t, c.correction.after.state.players[1].x, expected)
        frame, _ := r.current(&c.timeline)

        if frame.tick == c.correction.after.tick + 1 {
            testing.expect_value(t, frame.state.players[1].x, expected + i32(c.held[1].move))
            checked = true
        }
    }

    testing.expect(t, checked)
}

@(test)
new_authoritative_held_input_replaces_older_remote_guesses_in_replay :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, tr.Faults{latency_ticks = 3, retry_ticks = 3})
    defer fixture_destroy(&f)
    checked := false

    for _ in 0 ..< 90 {
        fixture_step(&f, true)
        c := &f.clients[0]

        if c.correction.serial == 0 || c.held[1].move == 0 {
            continue
        }

        expected := c.authority_frame.state.players[1].x + i32(c.held[1].move) * i32(c.correction.replayed_ticks)
        testing.expect_value(t, c.correction.after.state.players[1].x, expected)
        checked = true
        break
    }

    testing.expect(t, checked)
}
