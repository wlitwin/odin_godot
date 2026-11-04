package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import "core:math"
import r "godot:replay"
import net "godot:replay/net"
import game "../../examples/replay_scrapyard/shared/game"
import upgrade "../../examples/replay_scrapyard/shared/upgrade"

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
content46_conversion_preserves_pending_action_and_legacy_dash_control :: proc(t: ^testing.T) {
    w := game.initial(encounter_count = 0)
    w.stage = .Yard
    w.players[0].connected, w.players[0].in_yard = true, true
    w.players[0].position = {320, 1040}
    m := upgrade.model_46()
    m.hold = game.model().hold
    #assert(size_of(upgrade.World_47) == size_of(upgrade.World_48))
    // Execute ordinary legacy controls through explicit world conversion.
    m.step = proc(old: ^upgrade.World_47, c: [game.SEATS]game.Control, j, l: u64, ctx: ^r.Step(game.Event)) {
        w, _ := upgrade.map_world_47(old^)
        game.step(&w, c, j, l, ctx)
        old^ = transmute(upgrade.World_47)upgrade.world_48(w)
    }
    old: net.Server(upgrade.World_47, game.Control, upgrade.Action_46, game.Event, game.SEATS)
    defer net.server_destroy(&old)
    cfg := net.DEFAULT_CONFIG
    cfg.content = upgrade.CONTENT_46
    testing.expect_value(
        t,
        net.server_init(
            &old,
            r.Frame(upgrade.World_47){state = transmute(upgrade.World_47)upgrade.world_48(w)},
            m,
            {},
            cfg,
            local_seat = 1,
        ),
        net.Error.None,
    )
    // This archive represents an existing runner in the yard, not its first join.
    old.fresh, old.joins = 0, 0
    net.server_set_local_token(&old, net.Token{0 = 9})
    net.server_local(&old, game.Control{move = {1, 0}, dash = true})
    sequence, issued := net.server_issue(&old, upgrade.Action_46{kind = .Ready, ready = true})
    testing.expect_value(t, issued, net.Error.None)
    cp: net.Checkpoint(upgrade.World_47, game.Control, upgrade.Action_46, game.SEATS)
    defer net.checkpoint_destroy(&cp)
    testing.expect_value(t, net.checkpoint_capture(&old, &cp), net.Error.None)
    bytes, encoded := net.checkpoint_encode(&cp, m)
    defer delete(bytes)
    testing.expect_value(t, encoded, net.Error.None)
    converted, error := upgrade.root_46(bytes)
    defer delete(converted)
    testing.expect_value(t, error, net.Error.None)
    current: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&current)
    testing.expect_value(t, net.checkpoint_decode(&current, converted, game.model(), game.CONTENT), net.Error.None)
    testing.expect(
        t,
        len(current.actions) == 1 &&
        current.actions[0].sequence == sequence &&
        current.actions[0].tick == cp.actions[0].tick &&
        current.held[0].dash,
    )
    resumed: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
    defer net.server_destroy(&resumed)
    testing.expect_value(
        t,
        net.server_restore(
            &resumed,
            &current,
            game.model(),
            {},
            {epoch = 2, local_seat = 1, preserve_pending = true, retain_membership = true},
        ),
        net.Error.None,
    )
    testing.expect_value(t, net.server_step(&resumed), net.Error.None)
    frame, _ := r.current(&resumed.timeline)
    testing.expect_value(t, frame.state.players[0].dashes, u32(1))
    testing.expect_value(t, frame.state.players[0].position[0], f32(334))
}
