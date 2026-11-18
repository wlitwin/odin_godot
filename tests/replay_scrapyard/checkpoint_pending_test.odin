package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import sc "godot:replay/schema"
import game "../../examples/replay_scrapyard/shared/game"

@(test)
current_checkpoint_preserves_admitted_and_refused_pending_actions :: proc(t: ^testing.T) {
    server: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
    defer net.server_destroy(&server)
    cfg := net.DEFAULT_CONFIG
    cfg.content = game.CONTENT
    model := game.model()
    testing.expect_value(
        t,
        net.server_init(
            &server,
            r.Frame(game.World){state = game.initial(encounter_count = 0)},
            model,
            {},
            cfg,
            local_seat = 1,
        ),
        net.Error.None,
    )
    testing.expect_value(t, net.server_set_local_token(&server, net.Token{0 = 1}), net.Error.None)
    sequence, issued := net.server_issue(&server, game.Action{kind = .Ready, ready = true})
    testing.expect_value(t, issued, net.Error.None)
    source: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&source)
    testing.expect_value(t, net.checkpoint_capture(&server, &source), net.Error.None)
    testing.expect_value(t, len(source.actions), 1)
    // A refused request awaiting settlement retains its application-invalid
    // payload and receipt frontier; decoding must not re-admit or normalize it.
    rejected := source.actions[0]
    rejected.sequence += 1
    rejected.reason = .Invalid
    rejected.value = {
        kind = .Cast,
        slot = 99,
    }
    append(&source.actions, rejected)
    source.header.actions += 1
    for &peer in source.peers {
        if peer.index == rejected.peer {peer.action_received += 1}
    }
    testing.expect(t, net.checkpoint_valid(&source, model))
    bytes, encoded := net.checkpoint_encode(&source, model)
    defer delete(bytes)
    testing.expect_value(t, encoded, net.Error.None)
    hash := sc.digest(bytes)
    restored: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&restored)
    testing.expect_value(t, net.checkpoint_decode(&restored, bytes, model, game.CONTENT), net.Error.None)
    testing.expect_value(t, sc.digest(bytes), hash)
    testing.expect(t, reflect.equal(restored.frame, source.frame))
    testing.expect(t, reflect.equal(restored.actions[:], source.actions[:], true))
    testing.expect(t, reflect.equal(restored.peers[:], source.peers[:], true))
    testing.expect(t, restored.header.joins != 0 && restored.header.fresh != 0)
    testing.expect_value(t, len(restored.actions), 2)
    testing.expect(t, restored.actions[0].sequence == sequence && restored.actions[0].value.ready)
    testing.expect_value(t, restored.actions[1].reason, net.Action_Reason.Invalid)
    testing.expect_value(t, restored.actions[1].value.slot, u8(99))
}
