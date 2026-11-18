package replay_cave_test

import "core:bytes"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import r "godot:replay"
import sc "godot:replay/schema"
import net "godot:replay/net"
import cave "../../examples/replay_cavecrawl/shared/cave"

// Current golden frames are pinned independently of today's default definitions.
load_current_fixture :: proc(id: string) -> net.Checkpoint(cave.World, cave.Control, cave.Action, cave.SEATS) {
    rows: []struct {
        id, path, tick, frame_hash: string,
        epoch:                      u64,
        local_seat:                 u16,
        peers, inputs:              int,
    }
    assert(
        json.unmarshal(#load("fixtures/current/manifest.json", []u8), &rows, allocator = context.temp_allocator) ==
        nil,
    )
    for row in rows {
        if row.id != id {continue}
        data, err := os.read_entire_file(row.path, context.allocator)
        assert(err == nil, row.path)
        defer delete(data)
        cp: net.Checkpoint(cave.World, cave.Control, cave.Action, cave.SEATS)
        assert(net.checkpoint_decode(&cp, data, cave.model(), cave.CONTENT) == .None, id)
        encoded, error := net.checkpoint_encode(&cp, cave.model())
        assert(error == .None && bytes.equal(encoded, data), "current canonical checkpoint roundtrip")
        delete(encoded)
        codec: sc.Schema
        assert(sc.init(&codec, r.Frame(cave.World)).error == .None)
        defer sc.destroy(&codec)
        frame := make([]u8, codec.wire_size, context.temp_allocator)
        assert(sc.encode(&codec, cp.frame, frame).error == .None)
        assert(fmt.tprintf("%d", cp.frame.tick) == row.tick)
        assert(fmt.tprintf("%d", transmute(i64)sc.digest(frame)) == row.frame_hash, "saved frame changed")
        assert(cp.header.epoch == row.epoch && cp.header.local_seat == row.local_seat)
        assert(len(cp.peers) == row.peers && len(cp.inputs) == row.inputs)
        return cp // transfer this owning checkpoint to the caller
    }
    panic(fmt.tprintf("unknown current fixture: %s", id))
}
