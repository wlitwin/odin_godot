package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import sc "godot:replay/schema"
import game "../../examples/replay_scrapyard/shared/game"
import upgrade "../../examples/replay_scrapyard/shared/upgrade"

@(test)
content42_import_preserves_a_pending_original_action :: proc(t: ^testing.T) {
    server: net.Server(upgrade.World_45, game.Control, upgrade.Action_42, upgrade.Event_43, game.SEATS)
    defer net.server_destroy(&server)
    cfg := net.DEFAULT_CONFIG
    cfg.content = upgrade.CONTENT_42
    source_model := upgrade.model_42()
    source_model.step = proc(
        _: ^upgrade.World_45,
        _: [game.SEATS]game.Control,
        _: u64,
        _: u64,
        _: ^r.Step(upgrade.Event_43),
    ) {}
    source_model.hold = game.model().hold
    testing.expect_value(
        t,
        net.server_init(
            &server,
            r.Frame(upgrade.World_45) {
                state = transmute(upgrade.World_45)upgrade.world_48(game.initial(encounter_count = 0)),
            },
            source_model,
            {},
            cfg,
            local_seat = 1,
        ),
        net.Error.None,
    )
    net.server_set_local_token(&server, net.Token{0 = 1})
    _, issued := net.server_issue(&server, upgrade.Action_42{kind = .Ready, ready = true})
    testing.expect_value(t, issued, net.Error.None)
    old: net.Checkpoint(upgrade.World_45, game.Control, upgrade.Action_42, game.SEATS)
    defer net.checkpoint_destroy(&old)
    testing.expect_value(t, net.checkpoint_capture(&server, &old), net.Error.None)
    testing.expect_value(t, len(old.actions), 1)
    // A refused request still awaiting settlement can contain an application-
    // invalid value. Conversion preserves that value and its refusal frontier.
    rejected := old.actions[0]
    rejected.sequence += 1
    rejected.reason = .Invalid
    rejected.value = {
        kind = .Cast,
        slot = 99,
    }
    append(&old.actions, rejected)
    old.header.actions += 1

    for &peer in old.peers {
        if peer.index == rejected.peer {
            peer.action_received += 1
        }
    }

    testing.expect(t, net.checkpoint_valid(&old, upgrade.model_42()))
    bytes, encoded := net.checkpoint_encode(&old, upgrade.model_42())
    defer delete(bytes)
    testing.expect_value(t, encoded, net.Error.None)
    hash := sc.digest(bytes)
    out, err := upgrade.root_42(bytes)
    defer delete(out)
    testing.expect_value(t, err, net.Error.None)

    if err != .None {
        return
    }

    cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&cp)
    testing.expect_value(t, net.checkpoint_decode(&cp, out, game.model(), game.CONTENT), net.Error.None)
    expected, _ := upgrade.map_world(old.frame.state)
    expected.authority_epoch = old.header.epoch
    testing.expect_value(t, sc.digest(bytes), hash)
    testing.expect(t, reflect.equal(cp.frame.state, expected))
    testing.expect_value(t, len(cp.actions), 2)
    testing.expect_value(t, cp.actions[0].sequence, old.actions[0].sequence)
    testing.expect_value(t, cp.actions[0].tick, old.actions[0].tick)
    testing.expect_value(t, cp.actions[0].value.kind, game.Action_Kind.Ready)
    testing.expect(t, cp.actions[0].value.ready && cp.actions[0].value.development == (game.Development{}))
    testing.expect_value(t, cp.actions[1].reason, net.Action_Reason.Invalid)
    testing.expect_value(t, cp.actions[1].value.slot, u8(99))
}
