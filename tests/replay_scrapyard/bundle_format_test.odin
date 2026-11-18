package replay_scrapyard_test

import "core:testing"
import assets "godot:replay/assets"
import net "godot:replay/net"
import storage "godot:replay/godot/storage"
import game "../../examples/replay_scrapyard/shared/game"

@(test)
bundle_reader_requires_its_envelope_and_raw_checkpoint_reader_stays_explicit :: proc(t: ^testing.T) {
    bytes := #load("fixtures/current/plain.replay", []u8)
    bundle, decoded := assets.bundle_decode(bytes, game.CONTENT)
    testing.expect_value(t, decoded, assets.Bundle_Error.None)
    wrapped: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&wrapped)
    _, accepted := storage.checkpoint_bundle_decode(&wrapped, game.model(), bytes, game.CONTENT)
    testing.expect(t, accepted.error == .None && wrapped.ready)
    refused: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&refused)
    _, result := storage.checkpoint_bundle_decode(&refused, game.model(), bundle.root, game.CONTENT)
    testing.expect(t, result.error == .Codec && result.network == .Invalid_Checkpoint && !refused.ready)
    testing.expect_value(t, net.checkpoint_decode(&refused, bundle.root, game.model(), game.CONTENT), net.Error.None)
}
