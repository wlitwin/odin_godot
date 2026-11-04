package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import game "../../examples/replay_scrapyard/shared/game"
import arena "../../examples/replay_scrapyard/shared/arena"

@(test)
staging_requires_ready_players_and_host_start_and_preserves_loadouts :: proc(t: ^testing.T) {
    w := game.initial()
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 1,
        epoch  = 1,
        events = storage[:],
    }
    game.step(&w, [game.SEATS]game.Control{}, 3, 0, &ctx)
    before := w
    testing.expect(t, !game.action(&w, 1, game.Action{kind = .Start}, &ctx))
    testing.expect(t, reflect.equal(before, w))
    profile := game.Profile {
        name = game.name("axle"),
        look = 2,
        iron = 1,
    }
    testing.expect(t, game.action(&w, 1, game.Action{kind = .Profile, profile = profile}, &ctx))

    for seat in u16(1) ..= 2 {
        testing.expect(t, game.action(&w, seat, game.Action{kind = .Ready, ready = true}, &ctx))
    }

    testing.expect(t, !game.action(&w, 2, game.Action{kind = .Start}, &ctx))
    testing.expect(t, game.action(&w, 1, game.Action{kind = .Start}, &ctx))
    testing.expect_value(t, w.stage, game.Stage.Yard)
    testing.expect(t, w.players[0].in_yard && w.players[1].in_yard)
    testing.expect_value(t, w.players[0].profile.look, u8(2))
    testing.expect_value(t, w.players[0].profile.iron, u8(1))
    testing.expect_value(t, ctx.count, 3)
    testing.expect(t, !game.action(&w, 1, game.Action{kind = .Profile, profile = profile}, &ctx))
    testing.expect(t, game.state_valid(w))
}

Input :: struct {
    controls: [game.SEATS]game.Control,
    dash:     bool,
}

step :: proc(w: ^game.World, input: Input, ctx: ^r.Step(game.Event)) {
    game.step(w, input.controls, 0, 0, ctx)

    if input.dash {
        game.action(w, 1, game.Action{kind = .Dash, aim = input.controls[0].move}, ctx)
    }
}

@(test)
dash_rewind_keeps_complete_movement_state :: proc(t: ^testing.T) {
    w := game.initial()
    w.stage = .Yard
    w.players[0].connected, w.players[0].in_yard = true, true
    w.players[0].position = {24, 1040} // open southern lane
    timeline: r.Timeline(game.World, Input, game.Event)
    r.init(&timeline, r.Frame(game.World){state = w}, step)
    defer r.destroy(&timeline)

    for tick in 1 ..= 80 {
        input := Input {
            dash = tick == 10,
        }
        input.controls[0] = {
            move = {1, 0},
            aim  = {1, 0},
        }
        testing.expect_value(t, r.advance(&timeline, input).error, r.Error.None)
    }

    before, _ := r.current(&timeline)
    testing.expect_value(t, before.state.players[0].dashes, u32(1))
    changed := Input{}
    changed.controls[0] = {
        move = {1, 0},
        aim  = {1, 0},
    }
    testing.expect_value(t, r.revise_input(&timeline, 10, changed).error, r.Error.None)
    after, _ := r.current(&timeline)
    testing.expect_value(t, after.state.players[0].dashes, u32(0))
    testing.expect(t, after.state.players[0].position[0] < before.state.players[0].position[0])
    testing.expect_value(t, r.audit(&timeline, 10).error, r.Error.None)
    testing.expect(t, arena.valid(after.state.layout, after.state.seed, after.state.floor))
}

@(test)
mid_dash_authority_checkpoint_resumes_the_same_movement :: proc(t: ^testing.T) {
    Server :: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
    Checkpoint :: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    server, resumed: Server
    defer net.server_destroy(&server)
    defer net.server_destroy(&resumed)
    config := net.DEFAULT_CONFIG
    config.content = game.CONTENT
    testing.expect_value(
        t,
        net.server_init(
            &server,
            r.Frame(game.World){state = game.initial()},
            game.model(),
            {},
            config,
            local_seat = 1,
        ),
        net.Error.None,
    )
    net.server_set_local_token(&server, net.Token{0 = 9})
    net.server_step(&server)
    net.server_issue(&server, game.Action{kind = .Ready, ready = true})
    net.server_step(&server)
    net.server_issue(&server, game.Action{kind = .Start})
    net.server_step(&server)
    net.server_issue(&server, game.Action{kind = .Dash, aim = {1, 0}})
    net.server_step(&server)
    cp, decoded: Checkpoint
    defer net.checkpoint_destroy(&cp)
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(t, net.checkpoint_capture(&server, &cp), net.Error.None)
    testing.expect(t, cp.frame.state.players[0].dash_until > cp.frame.tick)
    bytes, err := net.checkpoint_encode(&cp, game.model())
    defer delete(bytes)
    testing.expect_value(t, err, net.Error.None)
    testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, game.model(), game.CONTENT), net.Error.None)
    testing.expect_value(
        t,
        net.server_restore(&resumed, &decoded, game.model(), {}, {epoch = 2, local_seat = 1}),
        net.Error.None,
    )
    before, _ := r.current(&resumed.timeline)
    testing.expect(t, reflect.equal(before, decoded.frame))
    reference_authority_epoch(&server, 2)

    for _ in 0 ..< 40 {
        control := game.Control {
            move = {1, 0},
            aim  = {1, 0},
        }
        net.server_local(&server, control)
        net.server_local(&resumed, control)
        net.server_step(&server)
        net.server_step(&resumed)
    }

    a, _ := r.current(&server.timeline)
    b, _ := r.current(&resumed.timeline)
    testing.expect(t, reflect.equal(a, b))
}

@(test)
cover_forgiveness_and_unicode_name_boundaries_remain_explicit :: proc(t: ^testing.T) {
    covers := [1]arena.Cover{{100, 100, 20, 20, 0}}
    testing.expect_value(t, arena.block_cover(covers[:], {110, 110}, {140, 110}, 12), [2]f32{140, 110})
    testing.expect_value(t, arena.block_cover(covers[:], {80, 110}, {100, 110}, 12), [2]f32{80, 110})
    name := game.name("こんにちは世界こんにちは世界")
    testing.expect(t, game.name_valid(name) && name.count <= 31)
    name.bytes[0] = 0
    testing.expect(t, !game.name_valid(name))
}
