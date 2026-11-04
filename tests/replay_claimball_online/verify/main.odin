package main

import "core:fmt"
import "core:os"
import db "godot:replay/provision/sqlite"
import p "godot:replay/provision"
import net "godot:replay/net"
import lb "godot:replay/lobby"
import game "godot:examples/replay_claimball/shared/pitch"

main :: proc() {
    assert(len(os.args) == 2)
    store: db.Store
    assert(db.open(&store, os.args[1]) == .None)
    defer db.close(&store)
    rooms: [8]p.Bundle
    count, err := db.load_all(&store, game.CONTENT, rooms[:])
    assert(err == .None && count >= 1)

    for room in rooms[:count] {
        saved, found, loaded := db.checkpoint_load(&store, room.record.room, game.CONTENT, game.model())
        defer db.stored_checkpoint_destroy(&saved)
        assert(found && loaded == .None && saved.publication.revision >= 2 && saved.publication.point.scope.epoch == 2)
        cp: net.Checkpoint(game.World, game.Controls, game.Action, game.SEATS)
        defer net.checkpoint_destroy(&cp)
        assert(net.checkpoint_decode(&cp, saved.bytes, game.model(), game.CONTENT) == .None)
        w := &cp.frame.state
        assert(
            w.started && w.kicks > 0 && w.spikes >= 2 && w.group_seat == 0 && !w.outside.valid && game.state_valid(w^),
        )
        assert(
            lb.text(&w.names[0]) == "Captain" && lb.text(&w.names[1]) == "Striker" && lb.text(&w.names[2]) == "Wing",
        )
        fmt.printf(
            "RCB_PARTY_PUBLICATION_OK room=%d revision=%d epoch=2 tick=%d kicks=%d spikes=%d names=true\n",
            room.record.room,
            saved.publication.revision,
            cp.frame.tick,
            w.kicks,
            w.spikes,
        )
    }
}
