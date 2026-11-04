package replay_claimball_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import v "godot:replay/view"
import game "../../examples/replay_claimball/shared/pitch"

@(test)
projection_removes_remote_simulation_but_keeps_timestamped_boundary_values :: proc(t: ^testing.T) {
    w := game.initial()
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 20,
        epoch  = 1,
        events = storage[:],
    }
    game.reset_player(&w, 1, &ctx)
    game.reset_player(&w, 2, &ctx)
    w.started, w.clock, w.ball.hold = true, 20, 0
    projected := game.project(r.Frame(game.World){20, w}, 1)
    testing.expect(t, game.group_valid(projected, 1))
    testing.expect(t, !game.state_valid(projected)) // cannot masquerade as a complete authority world
    testing.expect_value(t, projected.players[1], game.Player{})
    testing.expect_value(t, projected.outside.tick, u64(20))
    testing.expect(t, reflect.equal(projected.outside.value[1], w.players[1]))
    input: [game.SEATS]game.Controls
    input[0].move[0], input[1].move[0] = 1, -1
    ctx.tick = 21
    game.step(&projected, input, 0, 0, &ctx)
    testing.expect(t, projected.players[0].motion.position != w.players[0].motion.position)
    testing.expect_value(t, projected.players[1], game.Player{})
    testing.expect(t, reflect.equal(projected.outside.value[1], w.players[1]))
    testing.expect(t, game.group_valid(projected, 1))
}

@(test)
claim_retains_local_fast_flight_and_never_claims_an_untouched_remote_ball :: proc(t: ^testing.T) {
    claim, idle: v.Claim2
    v.claim_update(&idle, false, 81, 1)
    testing.expect_value(t, idle.weight, f32(0))
    v.claim_update(&claim, true, 4, 0)
    v.claim_update(&claim, false, 81, 3) // far away, still my fast flight
    testing.expect_value(t, claim.weight, f32(1))
    v.claim_update(&claim, false, 0.25, 0.125)
    testing.expect_value(t, claim.weight, f32(0.5))
    pose := v.claim_pose(claim, {position = {0, 0}}, {position = {10, 0}})
    testing.expect_value(t, pose.position, [2]f32{5, 0})
    v.claim_update(&claim, false, 0, 0.125)
    testing.expect_value(t, claim.weight, f32(0))
}

@(test)
claimed_reset_stays_predicted_until_observed_reset_catches_up :: proc(t: ^testing.T) {
    claim := v.Claim2 {
        active = true,
        weight = 1,
    }
    v.claim_update(&claim, false, 0, 0.5, retain_reset = true)
    testing.expect_value(t, claim.weight, f32(1))
    v.claim_update(&claim, false, 0, 0.25)
    testing.expect_value(t, claim.weight, f32(0))
    before := claim
    testing.expect(t, !v.claim_update(&claim, true, 0, -1))
    testing.expect_value(t, claim, before)
}
