package dockyard_round_test

import "core:testing"
import game "godot:examples/replay_dockyard/modules/dockyard"

@(test)
remote_visual_reconciles_once_and_cuts_on_lifetime_and_history_loss :: proc(t: ^testing.T) {
    runtime := new(game.Runtime)
    defer free(runtime)
    runtime.session = &runtime.room.session
    runtime.session.client.seat = 2
    actor := game.DockyardDuo{state = runtime}
    state: game.Game
    state.bodies[1], state.lives[1] = 1, 1
    positions: [2][3]f32
    game.remote_robot_present(&actor, &state, 4, 20, positions, 0)
    positions[0].x = -0.2
    runtime.session.client.stats.corrections += 1
    game.remote_robot_present(&actor, &state, 4, 20, positions, 0)
    testing.expect_value(t, actor.remote_robot.smoother.shown.position.x, f32(0))
    game.remote_robot_present(&actor, &state, 4, 20, positions, 0.08)
    testing.expect(t, abs(actor.remote_robot.smoother.shown.position.x + 0.1) < .0001)
    positions[0].x += 0.5
    game.remote_robot_present(&actor, &state, 4, 21, positions, 0)
    testing.expect(t, abs(actor.remote_robot.smoother.shown.position.x - 0.4) < .0001)
    state.lives[1] += 1
    game.remote_robot_present(&actor, &state, 4, 22, positions, 0)
    testing.expect_value(t, actor.remote_robot.smoother.shown.position, positions[0])
    runtime.session.client.stats.corrections += 1
    positions[0].z += 0.3
    game.remote_robot_present(&actor, &state, 4, 22, positions, 0)
    testing.expect(t, actor.remote_robot.smoother.shown.position != positions[0])
    // An unavailable old checkpoint cannot supply a same-tick correction.
    runtime.session.client.stats.corrections += 1
    game.remote_robot_present(&actor, &state, 4, 23, positions, 0)
    testing.expect_value(t, actor.remote_robot.smoother.shown.position, positions[0])
    runtime.session.client.spectator = true
    game.remote_robot_present(&actor, &state, 4, 24, positions, 0)
    testing.expect(t, !actor.remote_robot.smoother.initialized)
}
