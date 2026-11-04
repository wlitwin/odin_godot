package replay_slopball_test
import "core:testing"
import r "godot:replay"
import sc "godot:replay/schema"
import "core:reflect"
import own "godot:replay/owned"
import game "../../examples/replay_slopball/shared/pitch"

intent_setup :: proc() -> game.World {
    w := game.initial(minimum = 2)
    events: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        epoch  = 1,
        tick   = 1,
        events = events[:],
    }
    game.step(&w, {}, 3, 0, &ctx)
    pose := w.players[1].body.value
    pose.position = {330, 180}
    assert(own.cut(&w.players[1].body, 2, pose, 99, game.rules()) == .None)
    ctx = {
        epoch  = 1,
        tick   = 100,
        events = events[:],
    }
    game.step(&w, {}, 0, 0, &ctx)
    return w
}

intent_step :: proc(w: ^game.World, tick: u64, c: game.Control = {}, epoch: u64 = 1) {
    events: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        epoch  = epoch,
        tick   = tick,
        events = events[:],
    }
    controls: [game.SEATS]game.Control
    controls[1] = c
    game.step(w, controls, 0, 0, &ctx)
    assert(ctx.error == .None && game.state_valid(w^))
}

@(test)
requested_movement_without_accepted_displacement_cannot_claim :: proc(t: ^testing.T) {
    w := intent_setup()
    pose := w.players[1].body.value
    c := game.Control {
        intent = {1, 0},
        player = {own.scope(w.players[1].body), 1, 1, pose},
    }
    intent_step(&w, 101, c)
    testing.expect_value(t, w.ball.pending.revision, u64(0))
    testing.expect_value(t, w.challenger, u16(0))
}

@(test)
accepted_displacement_claims_without_a_requested_input_bit :: proc(t: ^testing.T) {
    w := intent_setup()
    pose := w.players[1].body.value
    pose.position[0] += 1
    intent_step(&w, 101, {player = {own.scope(w.players[1].body), 1, 1, pose}})
    testing.expect_value(t, w.ball.pending.owner, u16(2))
    testing.expect(t, w.ball.pending.revision > 0)
}

@(test)
cooldown_keeps_the_previous_arbitration_position_until_sampling_resumes :: proc(t: ^testing.T) {
    w := intent_setup()
    w.grant_after = 104
    pose := w.players[1].body.value

    for i in 1 ..= 3 {
        pose.position[0] += 0.25
        intent_step(&w, u64(100 + i), {player = {own.scope(w.players[1].body), u64(i), u64(i), pose}})
        testing.expect_value(t, w.ball.pending.revision, u64(0))
    }

    intent_step(&w, 104)
    testing.expect_value(t, w.ball.pending.owner, u16(2))
}

@(test)
duplicate_and_conflicting_samples_do_not_sustain_a_moving_ball_challenge :: proc(t: ^testing.T) {
    w := intent_setup()
    ball := w.ball.value
    ball.linear[0] = 100
    testing.expect_value(t, own.cut(&w.ball, 1, ball, 100, game.rules()), own.Error.None)
    pose := w.players[1].body.value
    pose.position[0] += 1
    c := game.Control {
        intent = {1, 0},
        player = {own.scope(w.players[1].body), 1, 1, pose},
    }
    intent_step(&w, 101, c)
    testing.expect_value(t, w.challenger, u16(2))
    testing.expect_value(t, w.ball.pending.revision, u64(0))

    for tick in u64(102) ..< 110 {
        intent_step(&w, tick, c)
        testing.expect_value(t, w.challenger, u16(0))
        testing.expect_value(t, w.ball.pending.revision, u64(0))
    }

    c.player.value.position[0] += 1
    intent_step(&w, 110, c)
    testing.expect(t, w.rejected > 0)
    testing.expect_value(t, w.ball.pending.revision, u64(0))
}

@(test)
non_ground_displacement_or_reported_velocity_does_not_count_as_stride :: proc(t: ^testing.T) {
    w := intent_setup()
    pose := w.players[1].body.value
    pose.linear[0] = 100
    intent_step(&w, 101, {intent = {1, 0}, player = {own.scope(w.players[1].body), 1, 1, pose}})
    testing.expect_value(t, w.ball.pending.revision, u64(0))
}

@(test)
scope_changes_and_rejoin_do_not_create_phantom_stride :: proc(t: ^testing.T) {
    for mode in 0 ..< 3 {
        w := intent_setup()
        pose := w.players[1].body.value
        pose.position[0] += 1

        if mode == 0 {
            testing.expect_value(t, own.cut(&w.players[1].body, 2, pose, 101, game.rules()), own.Error.None)
            intent_step(&w, 102, {intent = {1, 0}})
        } else {
            w.grant_after = 103
            intent_step(&w, 101, {player = {own.scope(w.players[1].body), 1, 1, pose}})

            if mode == 1 {
                intent_step(&w, 103, epoch = 2)
            } else {
                events: [32]r.Occurrence(game.Event)
                ctx := r.Step(game.Event) {
                    epoch  = 1,
                    tick   = 103,
                    events = events[:],
                }
                game.step(&w, {}, 2, 0, &ctx)
            }
        }

        testing.expect_value(t, w.ball.pending.revision, u64(0))
        testing.expect(t, game.state_valid(w))
    }
}

@(test)
canonical_world_roundtrip_preserves_the_pending_stride_baseline :: proc(t: ^testing.T) {
    w := intent_setup()
    w.grant_after = 103
    pose := w.players[1].body.value
    pose.position[0] += 1
    intent_step(&w, 101, {player = {own.scope(w.players[1].body), 1, 1, pose}})
    testing.expect(t, w.players[1].stride_position != game.stride_position(w.players[1].body.value))
    schema: sc.Schema
    testing.expect_value(t, sc.init(&schema, game.World).error, sc.Error.None)
    defer sc.destroy(&schema)
    bytes := make([]u8, schema.wire_size)
    defer delete(bytes)
    testing.expect_value(t, sc.encode(&schema, w, bytes).error, sc.Error.None)
    restored: game.World
    testing.expect_value(t, sc.decode(&schema, &restored, bytes).error, sc.Error.None)
    testing.expect(t, reflect.equal(w, restored))
    intent_step(&w, 103)
    intent_step(&restored, 103)
    testing.expect(t, reflect.equal(w, restored))
    testing.expect_value(t, restored.ball.pending.owner, u16(2))
}

@(test)
diagonal_stride_uses_the_original_sum_of_absolute_axis_distances :: proc(t: ^testing.T) {
    w := intent_setup()
    pose := w.players[1].body.value
    pose.position[0] += 0.4
    pose.position[1] += 0.4
    intent_step(&w, 101, {player = {own.scope(w.players[1].body), 1, 1, pose}})
    testing.expect_value(t, w.ball.pending.owner, u16(2))
}
