#+build !freestanding
package callback_game

import "core:testing"
import knet "godot:kit/net"
import ksim "godot:kit/sim"
import ksess "godot:kit/session"
import actors "actors"
import rt "godot:runtime"

@(test)
owner_tables_keep_callbacks_per_game :: proc(t: ^testing.T) {
    testing.expect_value(t, len(rt.registration_errors()), 0)
    a: GameA
    b: GameB
    sessions: [2]ksess.Session
    lanes: [2]ksim.Lane
    bodies: [2]actors.Actor
    walkers: [2]actors.Walker
    defer {
        for &lane in lanes {ksim.lane_destroy(&lane)}
        for &session in sessions {ksess.session_destroy(&session)}
    }
    for &session, i in sessions {
        session.reg = knet.registry_make()
        session.ctx = knet.command_ctx_make()
        session.is_host, session.ran, session.joined = true, true, true
        session.me = 1
        session.ctx.is_authority, session.ctx.me = true, 1
        user := i == 0 ? rawptr(&a) : rawptr(&b)
        session.ctx.game_user = user
        kinds := i == 0 ? game_a_entity_kinds[:] : game_b_entity_kinds[:]
        knet.registry_insert(&session.reg, 1, &bodies[i], kinds[0].set, 1)
        knet.registry_insert(&session.reg, 2, &walkers[i], kinds[1].set, 1)
        knet.registry_edges_tick(&session.reg, user)
        boot := i == 0 ? &a.boot : &b.boot
        boot.ses = &session
        boot.lane = &lanes[i]
        if i == 0 {
            game_a_lane_init(&a, &lanes[i], &session)
        } else {
            ksim.lane_init(&lanes[i], &session, kinds[1].sim_set.input_size)
            ksim.lane_set_sim(&lanes[i], &b, nil, nil, nil)
        }
        ksim.lane_track_set(&lanes[i], 2, &walkers[i], kinds[1].sim_set, 1)
        result := actors.actor_add_cmd(boot, &bodies[i], 3)
        testing.expect(t, result.state == .Applied)
        knet.registry_edges_tick(&session.reg, user)
        result = actors.actor_add_cmd(boot, &bodies[i], -2)
        testing.expect(t, result.reason == .Predicate)
        testing.expect_value(t, bodies[i].value, i32(3))
        result = actors.actor_counter_gain_cmd(boot, &bodies[i], 2)
        testing.expect(t, result.state == .Applied)
        testing.expect_value(t, bodies[i].counter.value, i32(2))
        testing.expect_value(t, bodies[i].local_calls, i32(0))
        input := actors._kit_walker_Input{move = 1}
        kinds[1].sim_set.tick(&walkers[i], &input, &lanes[i], 1)
        writer := knet.writer_make()
        knet.write_i32(&writer, 4)
        reason := kinds[1].sim_set.commands[0].exec(&walkers[i], knet.writer_bytes(&writer), &lanes[i], 1)
        testing.expect(t, reason == .None)
        knet.writer_reset(&writer)
        knet.write_bool(&writer, true)
        knet.write_i32(&writer, 5)
        kinds[1].sim_set.fx(&walkers[i], &lanes[i], false, knet.writer_bytes(&writer))
        // A truncated delayed fact must never reach the callback.
        kinds[1].sim_set.fx(&walkers[i], &lanes[i], false, knet.writer_bytes(&writer)[:1])
        knet.writer_destroy(&writer)
        testing.expect_value(t, walkers[i].value, i32(5))
        testing.expect_value(t, walkers[i].score, i32(4))
        // Prediction/replay mutates entity state without authority consequences
        // or a second presentation of an already replayed tick.
        session.is_host, session.ctx.is_authority = false, false
        lanes[i].resimming = true
        kinds[1].sim_set.tick(&walkers[i], &input, &lanes[i], 1)
        result = actors.actor_add_cmd(boot, &bodies[i], 1)
        testing.expect(t, result.state == .Predicted)
    }
    testing.expect_value(t, a.points, i32(12))
    testing.expect_value(t, b.points, i32(120))
    testing.expect_value(t, a.edges, i32(1))
    testing.expect_value(t, b.edges, i32(10))
    testing.expect_value(t, a.tick_points, i32(1))
    testing.expect_value(t, b.tick_points, i32(10))
    testing.expect_value(t, a.effects, i32(2))
    testing.expect_value(t, b.effects, i32(20))
    testing.expect(t, !a.last_mine && !b.last_mine)
    testing.expect_value(t, len(lanes[0].inputs), 1)
    testing.expect(t, lanes[0].inputs[0].sample == nil && lanes[0].inputs[0].validate != nil)
    input := actors._kit_walker_Input{move = 99}
    testing.expect(t, lanes[0].inputs[0].validate(&a, &input))
    testing.expect_value(t, input.move, i32(1))
}

@(test)
default_and_owner_only_presentation :: proc(t: ^testing.T) {
    game: GameC
    session: ksess.Session
    lane: ksim.Lane
    session.reg = knet.registry_make()
    session.ctx = knet.command_ctx_make()
    session.is_host, session.ran, session.joined = true, true, true
    session.me, session.ctx.me = 1, 1
    session.ctx.is_authority = true
    session.ctx.game_user = &game
    defer ksess.session_destroy(&session)
    game.boot.ses = &session
    ksim.lane_init(&lane, &session, game_c_entity_kinds[1].sim_set.input_size)
    defer ksim.lane_destroy(&lane)
    ksim.lane_set_sim(&lane, &game, nil, nil, nil)
    actor: actors.Actor
    walker: actors.Walker
    testing.expect(t, game_c_entity_kinds[0].set == &actors.actor_command_set)
    knet.registry_insert(&session.reg, 1, &actor, game_c_entity_kinds[0].set, 1)
    result := actors.actor_add_cmd(&game.boot, &actor, 1)
    testing.expect(t, result.state == .Applied)
    testing.expect_value(t, actor.local_calls, i32(1))
    input := actors._kit_walker_Input{move = 1}
    set := game_c_entity_kinds[1].sim_set
    testing.expect(t, set.fx == nil)
    set.tick(&walker, &input, &lane, 1)
    set.tick(&walker, &input, &lane, 2) // remote owner: no owner-only presentation
    session.is_host = false
    lane.resimming = true
    set.tick(&walker, &input, &lane, 1)
    testing.expect_value(t, game.effects, i32(1))
}
