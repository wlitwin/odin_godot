package main

import "core:fmt"
import "core:os"
import net "godot:replay/net"
import lb "godot:replay/lobby"
import game "godot:examples/replay_claimball/shared/pitch"

main :: proc() {
    continued := len(os.args) == 3 && os.args[1] == "--continued"
    assert(len(os.args) == 4 || continued)
    bytes, read := os.read_entire_file(continued ? os.args[2] : os.args[1], context.allocator)
    assert(read == nil)
    defer delete(bytes)
    cp: net.Checkpoint(game.World, game.Controls, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&cp)
    assert(net.checkpoint_decode(&cp, bytes, game.model(), game.CONTENT) == .None)
    w := &cp.frame.state
    v := w.ball.motion.velocity

    if continued {
        assert(
            w.round == 2 &&
            cp.header.epoch == 2 &&
            w.started &&
            w.score == game.Score{} &&
            w.kicks == 0 &&
            w.spikes == 0,
        )
        assert(w.group_seat == 0 && !w.outside.valid && w.players[0].connected && w.players[1].connected)
        assert(lb.text(&w.names[0]) == "Saver" && lb.text(&w.names[1]) == "Friend Ω")
        fmt.printf(
            "RCB_SAVE_CONTINUED_ARCHIVE_OK tick=%d bytes=%d round=2 epoch=2 names=true complete_world=true\n",
            cp.frame.tick,
            len(bytes),
        )
        return
    }

    assert(w.group_seat == 0 && !w.outside.valid && w.started && w.round == 1 && w.score.winner == 0)
    assert(w.ball.hold == 0 && v[0] * v[0] + v[1] * v[1] > 0.25 && u16(w.score.left) + u16(w.score.right) > 0)
    assert(w.players[0].connected && w.players[1].connected && w.players[0].kick_cd > 0)
    assert(lb.text(&w.names[0]) == "Saver" && lb.text(&w.names[1]) == "Friend Ω")
    fmt.printf(
        "RCB_SAVE_ARCHIVE_OK tick=%d bytes=%d round=%d score=%d-%d kick_cd=%d position=%v velocity=%v names=true complete_world=true pending=%d\n",
        cp.frame.tick,
        len(bytes),
        w.round,
        w.score.left,
        w.score.right,
        w.players[0].kick_cd,
        w.ball.motion.position,
        v,
        len(cp.actions),
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
        check: net.Checkpoint(game.World, game.Controls, game.Action, game.SEATS)
        defer net.checkpoint_destroy(&check)
        assert(net.checkpoint_decode(&check, data, game.model(), game.CONTENT) == .None)
    }
}
