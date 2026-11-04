package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import p "godot:replay/play"
import net "godot:replay/net"
import d "godot:replay/diagnostic"
import game "../../examples/replay_scrapyard/shared/game"
import upgrade "../../examples/replay_scrapyard/shared/upgrade"

// Test oracle for archive round trips: the uninterrupted source receives the
// same new epoch as the decoded server, without altering either world. This is
// test-only metadata injection, not a production authority-grant operation.
reference_authority_epoch :: proc(
    s: ^net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS),
    epoch: u64,
) {
    s.cfg.epoch = epoch
    s.timeline.epoch = epoch
}

@(test)
takeover_rearms_once_and_replays_even_between_dedicated_authorities :: proc(t: ^testing.T) {
    w := game.initial(dedicated = true, encounter_count = 0)
    w.director.rest_until = 900
    game.spawn_mob(&w, 0, {700, 1040})
    w.mobs.values[0].next_act = 12
    w.mobs.values[0].next_add = 999
    model := game.model()
    cfg := net.DEFAULT_CONFIG
    cfg.content = game.CONTENT
    s, resumed, again: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
    defer net.server_destroy(&s)
    defer net.server_destroy(&resumed)
    defer net.server_destroy(&again)
    testing.expect_value(
        t,
        net.server_init(&s, r.Frame(game.World){state = w, tick = 100}, model, {}, cfg),
        net.Error.None,
    )
    testing.expect_value(t, net.server_step(&s), net.Error.None)
    first, _ := r.current(&s.timeline)
    testing.expect_value(t, first.state.authority_epoch, u64(1))
    testing.expect_value(t, first.state.director.rest_until, u64(900))
    testing.expect_value(t, first.state.mobs.values[0].next_act, u64(12))
    cp, pending: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&cp)
    defer net.checkpoint_destroy(&pending)
    testing.expect_value(t, net.checkpoint_capture(&s, &cp), net.Error.None)
    testing.expect_value(t, net.server_restore(&resumed, &cp, model, {}, {epoch = 2, local_seat = 0}), net.Error.None)
    restored, _ := r.current(&resumed.timeline)
    testing.expect(t, reflect.equal(restored, cp.frame))
    // Recovery again before any committed tick must not lose the pending reset.
    testing.expect_value(t, net.checkpoint_capture(&resumed, &pending), net.Error.None)
    testing.expect_value(
        t,
        net.server_restore(&again, &pending, model, {}, {epoch = 3, local_seat = 0}),
        net.Error.None,
    )

    for _ in 0 ..< 3 {
        testing.expect_value(t, net.server_step(&resumed), net.Error.None)
        testing.expect_value(t, net.server_step(&again), net.Error.None)
    }

    a, _ := r.current(&resumed.timeline)
    b, _ := r.current(&again.timeline)
    testing.expect_value(t, a.state.authority_epoch, u64(2))
    testing.expect_value(t, b.state.authority_epoch, u64(3))
    // Explicit original-rule oracle: restore tick 101 + 150, not current tick + 150.
    testing.expect_value(t, a.state.director.rest_until, u64(251))
    testing.expect_value(t, b.state.director.rest_until, u64(251))
    testing.expect_value(t, a.state.mobs.values[0].next_act, u64(251))
    testing.expect_value(t, a.state.mobs.values[0].next_add, u64(251))
    b.state.authority_epoch = 2
    testing.expect(t, reflect.equal(a, b))
    testing.expect_value(t, r.audit(&resumed.timeline, 102).error, r.Error.None)
    archive: d.Recording(game.World, net.Batch(game.Control, game.Action, game.SEATS), net.Net_Event(game.Event))
    defer d.recording_destroy(&archive)
    identity := d.Recording_Context {
        content = game.CONTENT,
        build   = 1,
        tick_hz = game.HZ,
    }
    testing.expect_value(t, d.recording_capture(&archive, &resumed.timeline, identity).error, d.Recording_Error.None)
    capture: r.Audit_Capture(game.World, net.Batch(game.Control, game.Action, game.SEATS), net.Net_Event(game.Event))
    defer r.audit_capture_destroy(&capture)
    testing.expect_value(
        t,
        d.recording_verify(&archive, identity, net.recording_model(&model), &capture).error,
        d.Recording_Error.None,
    )
}

@(test)
takeover_grace_does_not_cancel_boss_telegraph_or_popper_damage :: proc(t: ^testing.T) {
    kinds := [2]u8{3, 4}

    for kind in kinds {
        w := yard()
        w.authority_epoch = 1
        w.clock = 100
        game.spawn_mob(&w, kind, {520, 1040})

        if kind == 4 {
            p.telegraph_start(&w.mobs.values[0].tele, 1)
        }

        model := game.model()
        model.reset_player = nil
        cfg := net.DEFAULT_CONFIG
        cfg.content = game.CONTENT
        cfg.epoch = 2
        s: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
        defer net.server_destroy(&s)
        testing.expect_value(
            t,
            net.server_init(&s, r.Frame(game.World){state = w, tick = 100}, model, {}, cfg, local_seat = 1),
            net.Error.None,
        )
        testing.expect_value(t, net.server_step(&s), net.Error.None)
        frame, _ := r.current(&s.timeline)
        testing.expect_value(t, frame.state.players[0].hp, u8(8))
        testing.expect_value(t, frame.state.pops + frame.state.slams, u32(1))
    }
}

@(test)
takeover_over_dwell_and_failed_tick_are_transactional :: proc(t: ^testing.T) {
    w := game.initial(dedicated = true, encounter_count = 0)
    w.authority_epoch = 1
    w.stage = .Over
    w.over_until = 101
    model := game.model()
    cfg := net.DEFAULT_CONFIG
    cfg.content = game.CONTENT
    cfg.epoch = 2
    s: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
    defer net.server_destroy(&s)
    testing.expect_value(
        t,
        net.server_init(&s, r.Frame(game.World){state = w, tick = 100}, model, {}, cfg),
        net.Error.None,
    )
    testing.expect_value(t, net.server_step(&s), net.Error.None)
    frame, _ := r.current(&s.timeline)
    testing.expect_value(t, frame.state.over_until, u64(250))
    testing.expect_value(t, frame.state.stage, game.Stage.Over)
    net.server_destroy(&s)
    model.step_view = proc(
        _: ^game.World,
        _: [game.SEATS]game.Control,
        _: [game.SEATS]net.View_Time,
        _, _: u64,
        ctx: ^r.Step(game.Event),
    ) {
        r.abort(ctx)
    }
    testing.expect_value(
        t,
        net.server_init(&s, r.Frame(game.World){state = w, tick = 100}, model, {}, cfg),
        net.Error.None,
    )

    for _ in 0 ..< 2 {
        testing.expect_value(t, net.server_step(&s), net.Error.Simulation)
        frame, _ = r.current(&s.timeline)
        testing.expect_value(t, frame.tick, u64(100))
        testing.expect(t, reflect.equal(frame.state, w))
    }
}

@(test)
historical_content48_import_preserves_frame_then_applies_takeover :: proc(t: ^testing.T) {
    bytes := transmute([]u8)#load("fixtures/content48/dedicated.checkpoint")
    old: net.Checkpoint(upgrade.World_48, game.Control, upgrade.Action_50, game.SEATS)
    defer net.checkpoint_destroy(&old)
    testing.expect_value(t, net.checkpoint_decode(&old, bytes, upgrade.model_48(), upgrade.CONTENT_48), net.Error.None)
    converted, err := upgrade.root_48(bytes)
    defer delete(converted)
    testing.expect_value(t, err, net.Error.None)
    current: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&current)
    testing.expect_value(t, net.checkpoint_decode(&current, converted, game.model(), game.CONTENT), net.Error.None)
    expected, ok := upgrade.map_world_48(old.frame.state)
    expected.authority_epoch = old.header.epoch
    testing.expect(t, ok && reflect.equal(current.frame.state, expected))
    s: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
    defer net.server_destroy(&s)
    testing.expect_value(
        t,
        net.server_restore(&s, &current, game.model(), {}, {epoch = 2, local_seat = 0}),
        net.Error.None,
    )
    before, _ := r.current(&s.timeline)
    testing.expect(t, reflect.equal(before, current.frame))
    testing.expect_value(t, net.server_step(&s), net.Error.None)
    after, _ := r.current(&s.timeline)
    testing.expect_value(t, after.state.authority_epoch, u64(2))
    testing.expect_value(t, after.state.director.rest_until, u64(253))
}

@(test)
takeover_attack_grace_ends_at_the_original_deadline :: proc(t: ^testing.T) {
    w := yard()
    w.authority_epoch = 1
    w.clock = 100
    game.spawn_mob(&w, 0, {520, 1040})
    model := game.model()
    model.reset_player = nil
    cfg := net.DEFAULT_CONFIG
    cfg.content = game.CONTENT
    cfg.epoch = 2
    s: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
    defer net.server_destroy(&s)
    testing.expect_value(
        t,
        net.server_init(&s, r.Frame(game.World){state = w, tick = 100}, model, {}, cfg, local_seat = 1),
        net.Error.None,
    )

    for _ in 0 ..< 149 {
        testing.expect_value(t, net.server_step(&s), net.Error.None)
    }

    before, _ := r.current(&s.timeline)
    testing.expect_value(t, before.tick, u64(249))
    testing.expect_value(t, before.state.players[0].hp, u8(10))
    testing.expect_value(t, net.server_step(&s), net.Error.None)
    after, _ := r.current(&s.timeline)
    testing.expect_value(t, after.tick, u64(250))
    testing.expect_value(t, after.state.players[0].hp, u8(9))
}

@(test)
takeover_invalid_epoch_or_timer_overflow_cannot_change_the_world :: proc(t: ^testing.T) {
    w := game.initial(dedicated = true, encounter_count = 0)
    w.authority_epoch = 2
    w.director.rest_until = 9
    cases := [3][2]u64{{1, 10}, {0, 10}, {3, max(u64)}}

    for pair in cases {
        candidate := w
        ctx := r.Step(game.Event) {
            epoch = pair[0],
            tick  = pair[1],
        }
        game.observe_authority(&candidate, {known = true, seat = 0}, &ctx)
        testing.expect(t, ctx.error != .None && reflect.equal(candidate, w))
    }
}
