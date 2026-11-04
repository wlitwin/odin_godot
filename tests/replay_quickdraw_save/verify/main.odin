package main

import "core:fmt"
import "core:os"
import net "godot:replay/net"
import lb "godot:replay/lobby"
import game "godot:examples/replay_quickdraw/shared/duel"

main :: proc() {
    assert(len(os.args) == 4)
    bytes, read := os.read_entire_file(os.args[1], context.allocator)
    assert(read == nil)
    defer delete(bytes)
    cp: net.Checkpoint(game.World, game.Controls, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&cp)
    assert(net.checkpoint_decode(&cp, bytes, game.model(), game.CONTENT) == .None)
    w := &cp.frame.state
    assert(w.started && w.players[0].boots && w.players[0].fire_cd > 0 && w.players[0].kills == 1)
    assert(w.players[1].hp == 0 && w.players[1].respawn_at > w.clock && w.players[1].deaths == 1)
    assert(w.bullets.count > 0 && w.history.entries[w.clock % 32].valid)
    assert(lb.text(&w.names[0]) == "Keeper" && lb.text(&w.names[1]) == "Partner Ω")
    fmt.printf(
        "RQ_SAVE_ARCHIVE_OK tick=%d bytes=%d hp2=%d respawn=%d fire_cd=%d bullets=%d history=true names=true pending=%d\n",
        cp.frame.tick,
        len(bytes),
        w.players[1].hp,
        w.players[1].respawn_at,
        w.players[0].fire_cd,
        w.bullets.count,
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

    // Both negative fixtures are valid archives; refusal belongs to resume policy.
    for path in os.args[2:4] {
        data, e := os.read_entire_file(path, context.allocator)
        assert(e == nil)
        defer delete(data)
        check: net.Checkpoint(game.World, game.Controls, game.Action, game.SEATS)
        defer net.checkpoint_destroy(&check)
        assert(net.checkpoint_decode(&check, data, game.model(), game.CONTENT) == .None)
    }
}
