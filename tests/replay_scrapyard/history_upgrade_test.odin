package replay_scrapyard_test
import "core:testing"
import "core:reflect"
import assets "godot:replay/assets"
import net "godot:replay/net"
import game "../../examples/replay_scrapyard/shared/game"
import upgrade "../../examples/replay_scrapyard/shared/upgrade"

@(test)
content47_visibility_upgrade_preserves_full_history_and_pending_membership :: proc(t: ^testing.T) {
    bytes := transmute([]u8)#load("fixtures/content47/run.replay")
    bundle, err := assets.bundle_decode(bytes, upgrade.CONTENT_47)
    testing.expect_value(t, err, assets.Bundle_Error.None)
    old: net.Checkpoint(upgrade.World_47, game.Control, upgrade.Action_50, game.SEATS)
    defer net.checkpoint_destroy(&old)
    testing.expect_value(
        t,
        net.checkpoint_decode(&old, bundle.root, upgrade.model_47(), upgrade.CONTENT_47),
        net.Error.None,
    )
    converted, result := upgrade.root_47(bundle.root)
    defer delete(converted)
    testing.expect_value(t, result, net.Error.None)
    current: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&current)
    testing.expect_value(t, net.checkpoint_decode(&current, converted, game.model(), game.CONTENT), net.Error.None)
    expected, valid := upgrade.map_world_47(old.frame.state)
    expected.authority_epoch = old.header.epoch
    testing.expect(t, valid && reflect.equal(current.frame.state, expected))
    testing.expect(t, reflect.equal(current.frame.state.hit_history, old.frame.state.hit_history))
    testing.expect(t, reflect.equal(current.peers[:], old.peers[:], true) && current.frame.tick == old.frame.tick)
    testing.expect_value(t, len(current.actions), len(old.actions))

    for prior, i in old.actions {
        mapped, ok := upgrade.map_action_50(prior.value)
        testing.expect(
            t,
            ok &&
            reflect.equal(current.actions[i].value, mapped) &&
            current.actions[i].peer == prior.peer &&
            current.actions[i].sequence == prior.sequence &&
            current.actions[i].tick == prior.tick &&
            current.actions[i].reason == prior.reason,
        )
    }
}
