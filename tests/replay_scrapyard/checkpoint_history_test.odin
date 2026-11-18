package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import assets "godot:replay/assets"
import net "godot:replay/net"
import game "../../examples/replay_scrapyard/shared/game"

@(test)
saved_hit_history_and_current_pending_state_survive_checkpoint_roundtrip :: proc(t: ^testing.T) {
    bytes := #load("fixtures/current/history.replay", []u8)
    bundle, err := assets.bundle_decode(bytes, game.CONTENT)
    testing.expect_value(t, err, assets.Bundle_Error.None)
    saved: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&saved)
    testing.expect_value(t, net.checkpoint_decode(&saved, bundle.root, game.model(), game.CONTENT), net.Error.None)
    valid_history := 0
    for entry in saved.frame.state.hit_history.entries {if entry.valid {valid_history += 1}}
    testing.expect(t, saved.frame.tick == 13 && valid_history > 1 && len(saved.peers) > 0)
    server: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
    defer net.server_destroy(&server)
    testing.expect_value(
        t,
        net.server_restore(
            &server,
            &saved,
            game.model(),
            {},
            {epoch = 2, local_seat = 1, preserve_pending = true, retain_membership = true},
        ),
        net.Error.None,
    )
    control := game.Control {
        move = {1, 0},
        aim  = {0, 1},
        fire = true,
    }
    testing.expect_value(t, net.server_local(&server, control), net.Error.None)
    _, issued := net.server_issue(&server, game.Action{kind = .Ready, ready = true})
    testing.expect_value(t, issued, net.Error.None)
    pending: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&pending)
    testing.expect_value(t, net.checkpoint_capture(&server, &pending), net.Error.None)
    testing.expect(t, len(pending.actions) == 1 && pending.held[0] == control)
    testing.expect(t, reflect.equal(pending.frame.state.hit_history, saved.frame.state.hit_history))
    encoded, written := net.checkpoint_encode(&pending, game.model())
    defer delete(encoded)
    testing.expect_value(t, written, net.Error.None)
    restored: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&restored)
    testing.expect_value(t, net.checkpoint_decode(&restored, encoded, game.model(), game.CONTENT), net.Error.None)
    testing.expect(t, reflect.equal(restored.frame, pending.frame))
    testing.expect(t, reflect.equal(restored.peers[:], pending.peers[:], true))
    testing.expect(t, reflect.equal(restored.actions[:], pending.actions[:], true))
    testing.expect(t, restored.held == pending.held && restored.held_views == pending.held_views)
    testing.expect(
        t,
        restored.header.joins == pending.header.joins &&
        restored.header.leaves == pending.header.leaves &&
        restored.header.fresh == pending.header.fresh,
    )
}
