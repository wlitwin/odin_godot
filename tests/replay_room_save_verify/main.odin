package main

import "core:fmt"
import "core:os"
import db "godot:replay/provision/sqlite"
import p "godot:replay/provision"
import net "godot:replay/net"
import play "godot:replay/play"
import cave "godot:examples/replay_cavecrawl/shared/cave"

main :: proc() {
    assert(len(os.args) == 2 || (len(os.args) == 3 && os.args[2] == "creator"))
    seat := len(os.args) == 3 ? u16(1) : u16(2)
    store: db.Store
    assert(db.open(&store, os.args[1]) == .None)
    defer db.close(&store)
    rooms: [2]p.Bundle
    count, error := db.load_all(&store, cave.CONTENT, rooms[:])
    assert(error == .None && count >= 1 && count <= 2)
    published := 0

    for room in rooms[:count] {
        saved, found, loaded := db.checkpoint_load(&store, room.record.room, cave.CONTENT, cave.model())
        defer db.stored_checkpoint_destroy(&saved)
        assert(loaded == .None)

        if !found {
            continue
        }

        published += 1
        assert(saved.publication.revision >= 2 && saved.publication.point.scope.epoch == 2)
        cp: net.Checkpoint(cave.World, cave.Control, cave.Action, cave.SEATS)
        defer net.checkpoint_destroy(&cp)
        assert(net.checkpoint_decode(&cp, saved.bytes, cave.model(), cave.CONTENT) == .None)
        assert(cp.header.epoch == 2 && cp.header.local_seat == seat && cp.frame.tick > 0)
        assert(saved.publication.publisher == room.record.owner && saved.publication.publisher.member == u64(seat))
        gems := play.inventory_count(cp.frame.state.players[seat - 1].bag[:], cave.GEM)
        torches := play.inventory_count(cp.frame.state.players[2 - seat].bag[:], cave.TORCH)
        assert(gems == 3 && torches >= 1)
        fmt.printf(
            "REPLAY_ROOM_SAVE_DURABLE_OK revision=%d tick=%d epoch=2 local_seat=%d gems=%d torches=%d\n",
            saved.publication.revision,
            cp.frame.tick,
            seat,
            gems,
            torches,
        )
    }

    assert(published == 1)
}
