package main
import "core:fmt"
import "core:os"
import net "godot:replay/net"
import lb "godot:replay/lobby"
import game "godot:examples/replay_slopball/shared/pitch"

main :: proc() {
    continued := len(os.args) == 3 && os.args[1] == "--continued"
    assert(len(os.args) == 4 || continued)
    bytes, read := os.read_entire_file(continued ? os.args[2] : os.args[1], context.allocator)
    assert(read == nil)
    defer delete(bytes)
    cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&cp)
    assert(net.checkpoint_decode(&cp, bytes, game.model(), game.CONTENT) == .None)
    w := &cp.frame.state
    assert(game.state_valid(w^) && w.started)
    assert(lb.text(&w.names[0]) == "Saver" && lb.text(&w.names[1]) == "Friend Ω")
    assert(w.players[0].connected && w.players[1].connected)

    if continued {
        assert(cp.header.epoch == 2 && w.won > 0 && w.left + w.right >= 2)
        fmt.printf(
            "RSL_SAVE_CONTINUED_ARCHIVE_OK tick=%d bytes=%d epoch=2 score=%d-%d names=true\n",
            cp.frame.tick,
            len(bytes),
            w.left,
            w.right,
        )
        return
    }

    velocity := w.ball.value.linear
    assert(w.won == 0 && w.left + w.right > 0 && w.tick >= w.kickoff_until && w.ball.owner == 1 && w.ball.sequence > 0)
    assert(velocity[0] * velocity[0] + velocity[1] * velocity[1] > 1600)
    fmt.printf(
        "RSL_SAVE_ARCHIVE_OK tick=%d bytes=%d score=%d-%d owner=%d sequence=%d position=%v velocity=%v angular=%v rotation=%v names=true stride=true\n",
        cp.frame.tick,
        len(bytes),
        w.left,
        w.right,
        w.ball.owner,
        w.ball.sequence,
        w.ball.value.position,
        velocity,
        w.ball.value.angular,
        w.ball.value.rotation,
    )
    cp.header.policy_id = 42
    policy, err := net.checkpoint_encode(&cp, game.model())
    assert(err == .None)
    defer delete(policy)
    assert(os.write_entire_file(os.args[2], policy) == nil)
    cp.header.policy_id = 0
    cp.header.epoch = max(u64)
    exhausted, err2 := net.checkpoint_encode(&cp, game.model())
    assert(err2 == .None)
    defer delete(exhausted)
    assert(os.write_entire_file(os.args[3], exhausted) == nil)

    for path in os.args[2:4] {
        data, e := os.read_entire_file(path, context.allocator)
        assert(e == nil)
        defer delete(data)
        check: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
        defer net.checkpoint_destroy(&check)
        assert(net.checkpoint_decode(&check, data, game.model(), game.CONTENT) == .None)
    }
}
