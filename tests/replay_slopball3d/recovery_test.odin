package replay_slopball3d_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import own "godot:replay/owned"
import net "godot:replay/net"
import game "../../examples/replay_slopball3d/shared/pitch"

Server :: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
Checkpoint :: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)

@(test)
restored_game_keeps_momentum_but_rejects_old_epoch_observations :: proc(t: ^testing.T) {
    server: Server
    defer net.server_destroy(&server)
    cfg := net.DEFAULT_CONFIG
    cfg.content = game.CONTENT
    testing.expect_value(
        t,
        net.server_init(&server, r.Frame(game.World){state = game.initial()}, game.model(), {}, cfg, local_seat = 1),
        net.Error.None,
    )
    net.server_set_local_token(&server, net.Token{0 = 7})
    net.server_step(&server)
    frame, _ := r.current(&server.timeline)
    pose := own.Pose3 {
        position = {10, 0.5, 4.5},
        rotation = {0, 0.5, 0, 0.8660254},
        linear   = {2, -1, 1},
        angular  = {1, 2, 3},
    }
    control := game.Control {
        ball = {own.scope(frame.state.ball), 1, 1, pose},
    }
    net.server_local(&server, control)
    net.server_step(&server)
    before, _ := r.current(&server.timeline)
    testing.expect(t, reflect.equal(before.state.ball.value, pose))
    cp, decoded: Checkpoint
    defer net.checkpoint_destroy(&cp)
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(t, net.checkpoint_capture(&server, &cp), net.Error.None)
    bytes, err := net.checkpoint_encode(&cp, game.model())
    defer delete(bytes)
    testing.expect_value(t, err, net.Error.None)
    testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, game.model(), game.CONTENT), net.Error.None)
    resumed: Server
    defer net.server_destroy(&resumed)
    testing.expect_value(
        t,
        net.server_restore(&resumed, &decoded, game.model(), {}, {epoch = 2, local_seat = 1}),
        net.Error.None,
    )
    restored, _ := r.current(&resumed.timeline)
    testing.expect(t, reflect.equal(before, restored))
    control.ball.sequence = 2
    control.ball.produced = 2
    control.ball.value.position[0] = 12
    net.server_local(&resumed, control)
    testing.expect_value(t, net.server_step(&resumed), net.Error.None)
    after, _ := r.current(&resumed.timeline)
    testing.expect(t, reflect.equal(after.state.ball.value, pose))
    testing.expect_value(t, after.state.ball.epoch, u64(2))
    testing.expect(t, after.state.ball.revision > before.state.ball.revision)
    testing.expect_value(t, after.state.ball.sequence, u64(0))
    testing.expect_value(t, after.state.rejected, before.state.rejected + 1)
    control.ball = {own.scope(after.state.ball), 1, 1, pose}
    control.ball.value.position[0] = 10.2
    net.server_local(&resumed, control)
    testing.expect_value(t, net.server_step(&resumed), net.Error.None)
    after, _ = r.current(&resumed.timeline)
    testing.expect_value(t, after.state.ball.value.position[0], f32(10.2))
    testing.expect_value(t, after.state.ball.sequence, u64(1))
    testing.expect_value(t, r.audit(&resumed.timeline, before.tick + 1).error, r.Error.None)
}
