package main
import "core:fmt"
import "core:os"
import net "godot:replay/net"
import sc "godot:replay/schema"
import game "godot:examples/replay_claimball/shared/pitch"

main :: proc() {
    for T in ([4]typeid{game.World, game.Controls, game.Action, game.Event}) {
        schema: sc.Schema
        assert(sc.init(&schema, T).error == .None)
        fmt.printf("CLAIMBALL_SCHEMA fingerprint=%d bytes=%d\n", schema.fingerprint, schema.wire_size)
        sc.destroy(&schema)
    }

    cfg := net.DEFAULT_CONFIG
    cfg.content = game.CONTENT
    client: net.Client(game.World, game.Controls, game.Action, game.Event, game.SEATS)
    assert(net.client_init(&client, game.model(), {}, net.Token{0 = 1}, cfg = cfg) == .None)
    defer net.client_destroy(&client)
    fmt.printf(
        "CLAIMBALL_CONTRACT content=%x contract=%d welcome=%d snapshot=%d facts=%d\n",
        game.CONTENT,
        client.contract,
        client.codecs.welcome.fingerprint,
        client.codecs.snapshot.fingerprint,
        client.codecs.facts.fingerprint,
    )

    if len(os.args) > 1 {
        bytes, err := os.read_entire_file(os.args[1], context.allocator)
        assert(err == nil)
        defer delete(bytes)
        cp: net.Checkpoint(game.World, game.Controls, game.Action, game.SEATS)
        defer net.checkpoint_destroy(&cp)
        assert(net.checkpoint_decode(&cp, bytes, game.model(), game.CONTENT) == .None)
        fmt.printf(
            "CLAIMBALL_C3_ARCHIVE_COMPATIBLE tick=%d epoch=%d round=%d\n",
            cp.frame.tick,
            cp.header.epoch,
            cp.frame.state.round,
        )
    }
}
