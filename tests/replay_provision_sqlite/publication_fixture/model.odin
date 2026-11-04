package publication_fixture
import auth "godot:replay/authority"
import p "godot:replay/provision"
import db "godot:replay/provision/sqlite"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import r "godot:replay"
import game "godot:tests/replay_provision_godot/shared/checkpoint_model"
import a "godot:replay/assets"
import ck "godot:replay/provision/checkpoint"

World :: game.World
Server :: game.Server

Fixture :: struct {
    store:  db.Store,
    room:   p.Room,
    server: Server,
}

clock :: proc(_: rawptr) -> (u64, bool) {
    return 0, true
}

model :: game.model

asset_policy :: proc() -> ck.Asset_Policy {
    return {collect = proc(_: rawptr, root: []u8, dst: []a.Ref, codec: ^net.Checkpoint_Codec) -> (int, bool) {
            cp: net.Checkpoint(World, u8, u8, 1)
            defer net.checkpoint_destroy(&cp)

            if len(dst) < 2 || net.checkpoint_decode(&cp, root, model(), 55, codec = codec) != .None {
                return 0, false
            }

            copy(dst, cp.frame.state.images[:])
            return 2, true
        }, validate = proc(_: rawptr, _: a.Ref, bytes: []u8) -> bool {
            return len(bytes) > 0 && bytes[0] == 'A'
        }}
}

open :: proc(f: ^Fixture, path: string, images: [2]a.Ref = {}) {
    assert(db.open(&f.store, path, true) == .None)
    endpoint, _ := auth.endpoint("127.0.0.1", 45001)
    b, error := p.make_room(44, 55, p.Secret{0 = 41}, endpoint)
    assert(error == .None)
    assert(p.open(&f.room, b, db.commit, &f.store, {read = clock}) == .None)
    assert(auth.coordinator_start(&f.room.service.coordinator, {1, 1}, 1, 0) == .None)
    cfg := net.DEFAULT_CONFIG
    cfg.content = 55
    cfg.require_permit = true
    assert(
        net.server_init(
            &f.server,
            r.Frame(World){state = {value = 7, images = images}},
            model(),
            {},
            cfg,
            local_seat = 1,
            permit = {allow = proc(_: rawptr, epoch: u64) -> bool {
                    return epoch == 1
                }},
        ) ==
        .None,
    )
    assert(net.server_set_local_token(&f.server, f.room.bundle.enrollments[0].token) == .None)
}

close :: proc(f: ^Fixture) {
    net.server_destroy(&f.server)
    p.close(&f.room)
    db.close(&f.store)
}

checkpoint :: proc(f: ^Fixture, sequence: u64, bad_owner: bool = false) -> (auth.Point, []u8) {
    net.server_local(&f.server, 1)
    assert(net.server_step(&f.server) == .None)
    cp: net.Checkpoint(World, u8, u8, 1)
    defer net.checkpoint_destroy(&cp)
    assert(net.checkpoint_capture(&f.server, &cp) == .None)

    if bad_owner {
        cp.peers[0].token_hash = {
            0 = 99,
        }
    }

    bytes, error := net.checkpoint_encode(&cp, model())
    assert(error == .None)
    return {
            {44, 1, 7, 55},
            {sequence = sequence, tick = cp.frame.tick, bytes = u32(len(bytes)), hash = rec.hash(bytes)},
        },
        bytes
}
