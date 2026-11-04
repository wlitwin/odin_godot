package cave_owner_test
import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import o "godot:replay/owned"
import game "../../examples/replay_cavecrawl/shared/owner_cave"
import kcombat "godot:kit/combat"
import kinter "godot:kit/interact"

@(test)
interaction_uses_issued_origin_before_or_after_the_motion_stream :: proc(t: ^testing.T) {
    for newer_motion in ([2]bool{false, true}) {
        s: Server
        start(&s)
        defer net.server_destroy(&s)
        frame, _ := r.current(&s.timeline)
        action := game.Action {
            verb        = .Take,
            index       = 0,
            origin_kind = .Owner_Pose,
            origin      = {o.scope(frame.state.avatars[0]), {position = {300, 180}}},
        }
        testing.expect(t, kinter.in_range({300, 180, 0}, {300, 180, 0}, game.REACH))

        if newer_motion {
            net.server_local(&s, game.Control{avatar = sample(frame.state.avatars[0], {500, 180})})
            net.server_step(&s)
        }

        before, _ := r.current(&s.timeline)
        _, issued := net.server_issue(&s, action)
        testing.expect_value(t, issued, net.Error.None)
        testing.expect_value(t, net.server_step(&s), net.Error.None)
        after, _ := r.current(&s.timeline)
        testing.expect_value(t, after.state.players[0].bag[0].count, u16(3))
        testing.expect_value(t, game.world_items(&after.state, game.GEM), u32(3))
        testing.expect(
            t,
            reflect.equal(after.state.avatars[0], before.state.avatars[0]) &&
            after.state.players[0].position == before.state.players[0].position,
        )
        testing.expect_value(t, r.audit(&s.timeline, before.tick + 1).error, r.Error.None)
    }
}

@(test)
rock_origin_matches_original_leash_without_changing_motion :: proc(t: ^testing.T) {
    points := [4][2]f32{{90, 120}, {144, 120}, {300, 120}, {140, 200}}

    for point in points {
        s: Server
        start(&s)
        defer net.server_destroy(&s)
        frame, _ := r.current(&s.timeline)
        anchor := frame.state.players[0].position
        expected := kcombat.leash({point[0], point[1], 0}, {anchor[0], anchor[1], 0}, 64)
        action := game.Action {
            verb        = .Throw,
            aim         = {1, 0},
            origin_kind = .Owner_Pose,
            origin      = {o.scope(frame.state.avatars[0]), {position = point}},
        }
        net.server_issue(&s, action)
        testing.expect_value(t, net.server_step(&s), net.Error.None)
        after, _ := r.current(&s.timeline)
        testing.expect_value(t, after.state.rocks.count, u32(1))
        testing.expect_value(t, after.state.rocks.values[0].position, ([2]f32{expected[0], expected[1]}))
        testing.expect(
            t,
            after.state.players[0].position == anchor && reflect.equal(after.state.avatars[0], frame.state.avatars[0]),
        )
    }
}

@(test)
old_life_action_context_is_refused_without_spending_or_moving :: proc(t: ^testing.T) {
    s: Server
    start(&s)
    defer net.server_destroy(&s)
    frame, _ := r.current(&s.timeline)
    w := frame.state
    action := game.Action {
        verb        = .Take,
        origin_kind = .Owner_Pose,
        origin      = {o.scope(w.avatars[0]), {position = {300, 180}}},
    }
    events: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        epoch  = 1,
        tick   = frame.tick,
        events = events[:],
    }
    game.reset_player(&w, 1, &ctx)
    w.players[0].connected = true
    before := w
    testing.expect(t, !game.act(&w, 1, action, &ctx) && reflect.equal(w, before))
    action.origin.scope = o.scope(w.avatars[0])
    action.origin.scope.epoch += 1
    testing.expect(t, !game.act(&w, 1, action, &ctx) && reflect.equal(w, before))
    action.origin.scope = o.scope(w.avatars[0])
    action.origin.scope.key.index = 1
    testing.expect(t, !game.act(&w, 1, action, &ctx) && reflect.equal(w, before))
    action.origin_kind = .Accepted_Pose
    testing.expect(t, !game.action_valid(action))
}

@(test)
pending_context_roundtrips_but_cannot_spend_across_an_authority_epoch :: proc(t: ^testing.T) {
    s, resumed: Server
    start(&s)
    defer net.server_destroy(&s)
    defer net.server_destroy(&resumed)
    frame, _ := r.current(&s.timeline)
    net.server_local(&s, game.Control{avatar = sample(frame.state.avatars[0], {300, 180})})
    net.server_step(&s)
    frame, _ = r.current(&s.timeline)
    action := game.Action {
        verb        = .Take,
        index       = 0,
        origin_kind = .Owner_Pose,
        origin      = {o.scope(frame.state.avatars[0]), {position = {300, 180}}},
    }
    sequence, issued := net.server_issue(&s, action)
    testing.expect_value(t, issued, net.Error.None)
    cp, decoded: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&cp)
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(t, net.checkpoint_capture(&s, &cp), net.Error.None)
    bytes, error := net.checkpoint_encode(&cp, game.model())
    defer delete(bytes)
    testing.expect_value(t, error, net.Error.None)
    testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, game.model(), game.CONTENT), net.Error.None)
    testing.expect(
        t,
        len(decoded.actions) == 1 &&
        reflect.equal(decoded.actions[0].value, action) &&
        decoded.actions[0].sequence == sequence,
    )
    testing.expect_value(
        t,
        net.server_restore(
            &resumed,
            &decoded,
            game.model(),
            {},
            {epoch = 2, local_seat = 1, retain_membership = true, preserve_pending = true},
        ),
        net.Error.None,
    )
    testing.expect_value(t, net.server_step(&resumed), net.Error.None)
    after, _ := r.current(&resumed.timeline)
    testing.expect(t, after.state.players[0].bag[0].count == 0 && after.state.chest[0].count == 3)
    action.origin.scope = o.scope(after.state.avatars[0])
    next, next_error := net.server_issue(&resumed, action)
    testing.expect(t, next_error == .None && next > sequence)
    testing.expect_value(t, net.server_step(&resumed), net.Error.None)
    after, _ = r.current(&resumed.timeline)
    testing.expect(t, after.state.players[0].bag[0].count == 3 && after.state.chest[0].count == 0)
    testing.expect_value(t, r.audit(&resumed.timeline, cp.frame.tick + 1).error, r.Error.None)
}
