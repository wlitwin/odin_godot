package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import "core:math"
import r "godot:replay"
import net "godot:replay/net"
import game "../../examples/replay_scrapyard/shared/game"

@(test)
dash_action_preserves_ten_movement_ticks_and_predicate_failure :: proc(t: ^testing.T) {
    w := game.initial(encounter_count = 0)
    w.stage = .Yard
    w.players[0].connected, w.players[0].in_yard = true, true
    w.players[0].position = {320, 1040}
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 1,
        epoch  = 1,
        events = storage[:],
    }
    game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    testing.expect(t, game.action(&w, 1, game.Action{kind = .Dash, aim = {1, 0}}, &ctx))
    before := w
    testing.expect(t, !game.action(&w, 1, game.Action{kind = .Dash, aim = {0, 1}}, &ctx) && reflect.equal(w, before))

    for tick in 2 ..= 12 {
        ctx.tick, ctx.count = u64(tick), 0
        game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    }

    testing.expect(
        t,
        math.abs(w.players[0].position[0] - 460) < 0.001 &&
        w.players[0].position[1] == 1040 &&
        w.players[0].dashes == 1,
    )
    testing.expect_value(t, game.model().action_schedule.timing(game.Action{kind = .Dash}), net.Action_Timing.Receipt)
    testing.expect_value(
        t,
        game.model().action_schedule.timing(game.Action{kind = .Cast}),
        net.Action_Timing.Scheduled,
    )
    testing.expect(
        t,
        !game.action_valid(game.Action{kind = .Dash, aim = {2, 0}}) &&
        !game.action_valid(game.Action{kind = .Dash, aim_is_point = true}),
    )
    w.players[0].hp = 0
    ctx.tick = 100
    before = w
    testing.expect(t, !game.action(&w, 1, game.Action{kind = .Dash}, &ctx) && reflect.equal(w, before))
}

@(test)
active_dash_and_pending_action_continue_once_after_restore :: proc(t: ^testing.T) {
    w := game.initial(encounter_count = 0)
    w.stage = .Yard
    w.players[0].connected, w.players[0].in_yard = true, true
    w.players[0].position = {320, 1040}
    model := game.model()
    model.reset_player = nil
    server: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
    defer net.server_destroy(&server)
    cfg := net.DEFAULT_CONFIG
    cfg.content = game.CONTENT
    testing.expect_value(
        t,
        net.server_init(&server, r.Frame(game.World){state = w}, model, {}, cfg, local_seat = 1),
        net.Error.None,
    )
    server.fresh, server.joins = 0, 0
    testing.expect_value(t, net.server_set_local_token(&server, net.Token{0 = 9}), net.Error.None)
    net.server_local(&server, game.Control{move = {1, 0}})
    _, issued := net.server_issue(&server, game.Action{kind = .Dash, aim = {1, 0}})
    testing.expect_value(t, issued, net.Error.None)
    for _ in 0 ..< 4 {testing.expect_value(t, net.server_step(&server), net.Error.None)}
    sequence, pending := net.server_issue(&server, game.Action{kind = .Ready, ready = true})
    testing.expect_value(t, pending, net.Error.None)
    source: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&source)
    testing.expect_value(t, net.checkpoint_capture(&server, &source), net.Error.None)
    testing.expect(
        t,
        source.frame.state.players[0].dashes == 1 && source.frame.state.players[0].dash_until > source.frame.tick,
    )
    testing.expect(t, !source.frame.state.players[0].profile.ready)
    encoded, written := net.checkpoint_encode(&source, model)
    defer delete(encoded)
    testing.expect_value(t, written, net.Error.None)
    saved: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&saved)
    testing.expect_value(t, net.checkpoint_decode(&saved, encoded, model, game.CONTENT), net.Error.None)
    testing.expect(
        t,
        len(saved.actions) == 1 &&
        saved.actions[0].sequence == sequence &&
        reflect.equal(saved.actions[:], source.actions[:], true),
    )
    resumed: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
    defer net.server_destroy(&resumed)
    testing.expect_value(
        t,
        net.server_restore(
            &resumed,
            &saved,
            model,
            {},
            {epoch = 2, local_seat = 1, preserve_pending = true, retain_membership = true},
        ),
        net.Error.None,
    )
    verdicts: [2]int
    events: [256]r.Occurrence(net.Net_Event(game.Event))
    for _ in 0 ..< 14 {
        testing.expect_value(t, net.server_step(&server), net.Error.None)
        testing.expect_value(t, net.server_step(&resumed), net.Error.None)
        expected, _ := r.current(&server.timeline)
        actual, _ := r.current(&resumed.timeline)
        testing.expect(t, actual.state.players[0].position == expected.state.players[0].position)
        testing.expect(
            t,
            actual.state.players[0].dash_until == expected.state.players[0].dash_until &&
            actual.state.players[0].dash_ready == expected.state.players[0].dash_ready,
        )
        testing.expect_value(t, actual.state.players[0].dashes, u32(1))
        for timeline, index in ([2]^r.Timeline(
                game.World,
                net.Batch(game.Control, game.Action, game.SEATS),
                net.Net_Event(game.Event),
            ){&server.timeline, &resumed.timeline}) {
            count, copied := r.copy_events(timeline, actual.tick, events[:])
            testing.expect_value(t, copied, r.Error.None)
            for event in events[:count] {
                if event.value.kind == .Action_Result && event.value.seat == 1 && event.value.sequence == sequence {
                    testing.expect(t, event.value.applied && event.value.reason == .None)
                    verdicts[index] += 1
                }
            }
        }
    }
    expected, _ := r.current(&server.timeline)
    actual, _ := r.current(&resumed.timeline)
    testing.expect(t, expected.state.players[0].profile.ready && actual.state.players[0].profile.ready)
    testing.expect(t, verdicts == ([2]int{1, 1}))
    peer := int(saved.actions[0].peer)
    testing.expect(t, server.peers[peer].action_settled == sequence && resumed.peers[peer].action_settled == sequence)
}
