package main

import "core:crypto/sha2"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import net "godot:replay/net"
import sc "godot:replay/schema"
import storage "godot:replay/godot/storage"
import game "../../../examples/replay_scrapyard/shared/game"

main :: proc() {
    assert(len(os.args) == 3, "usage: fixture_info FILE TOKEN_LABEL")
    data, read := os.read_entire_file(os.args[1], context.allocator)
    assert(read == nil)
    defer delete(data)
    cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&cp)
    bundle, decoded := storage.checkpoint_bundle_decode(&cp, game.model(), data, game.CONTENT)
    assert(decoded.error == .None)
    hash: sha2.Context_256
    sha2.init_256(&hash)
    sha2.update(&hash, transmute([]u8)os.args[2])
    digest: [32]u8
    sha2.final(&hash, digest[:])
    token: net.Token
    copy(token[:], digest[:16])
    seat, found := net.checkpoint_seat(&cp, token)
    assert(found && seat == 1)
    options := sc.DEFAULT_OPTIONS
    options.projection = .Public
    schema: sc.Schema
    defer sc.destroy(&schema)
    assert(sc.init(&schema, game.World, options).error == .None)
    state := make([]u8, schema.wire_size)
    defer delete(state)
    assert(sc.encode(&schema, cp.frame.state, state).error == .None)
    asset_bytes := 0
    for asset in bundle.assets[:bundle.count] {asset_bytes += len(asset.bytes)}
    summary := struct {
        tick, hash:          string,
        epoch:               u64,
        assets, asset_bytes: int,
    } {
        fmt.tprintf("%d", cp.frame.tick),
        fmt.tprintf("%d", sc.digest(state) & 0x7fff_ffff_ffff_ffff),
        cp.header.epoch,
        bundle.count,
        asset_bytes,
    }
    text, encoded := json.marshal(summary)
    assert(encoded == nil)
    defer delete(text)
    fmt.println(string(text))
}
