package main

import "core:fmt"
import "core:os"
import db "godot:replay/provision/sqlite"
import p "godot:replay/provision"
import net "godot:replay/net"
import lb "godot:replay/lobby"
import game "godot:examples/replay_speedball/shared/pitch"

main :: proc() {
    assert(len(os.args) == 2)
    store: db.Store
    assert(db.open(&store, os.args[1]) == .None)
    defer db.close(&store)
    rooms: [2]p.Bundle
    count, error := db.load_all(&store, game.CONTENT, rooms[:])
    assert(error == .None && count == 1)
    saved, found, loaded := db.checkpoint_load(&store, rooms[0].record.room, game.CONTENT, game.model())
    defer db.stored_checkpoint_destroy(&saved)
    assert(found && loaded == .None && saved.publication.revision >= 2 && saved.publication.point.scope.epoch == 2)
    cp: net.Checkpoint(game.World, game.Controls, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&cp)
    assert(net.checkpoint_decode(&cp, saved.bytes, game.model(), game.CONTENT) == .None)
    w := &cp.frame.state
    assert(
        cp.header.local_seat == 1 &&
        w.round == 2 &&
        w.started &&
        w.score.winner != 0 &&
        u32(w.score.left) + u32(w.score.right) == 1 &&
        w.kicks > 0,
    )
    assert(lb.text(&w.names[0]) == "Saved Captain" && lb.text(&w.names[1]) == "New Striker")
    fmt.printf(
        "REPLAY_SPEEDBALL_PARTY_RESTORE_DURABLE_OK revision=%d epoch=2 tick=%d round=2 left=%d right=%d kicks=%d names=true\n",
        saved.publication.revision,
        cp.frame.tick,
        w.score.left,
        w.score.right,
        w.kicks,
    )
}
