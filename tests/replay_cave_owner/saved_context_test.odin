package cave_owner_test
import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import game "../../examples/replay_cavecrawl/shared/owner_cave"
import base "../../examples/replay_cavecrawl/shared/cave"

@(test)
saved_accepted_pose_action_retains_its_meaning_and_settles_once :: proc(t: ^testing.T) {
    bytes := #load("fixtures/current/accepted-pose.checkpoint", []u8)
    current: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&current)
    testing.expect_value(t, net.checkpoint_decode(&current, bytes, game.model(), game.CONTENT), net.Error.None)
    testing.expect(t, current.frame.tick == 1 && current.header.epoch == 1 && len(current.actions) == 1)
    testing.expect(t, current.actions[0].value.origin_kind == .Accepted_Pose && current.actions[0].value.verb == .Door)
    testing.expect(
        t,
        current.actions[0].sequence == 1 && current.actions[0].tick == 2 && current.actions[0].reason == .None,
    )
    encoded, written := net.checkpoint_encode(&current, game.model())
    defer delete(encoded)
    testing.expect_value(t, written, net.Error.None)
    testing.expect(
        t,
        reflect.equal(bytes, encoded, true),
        "preserve the complete pending payload and receipt metadata",
    )
    resumed: Server
    defer net.server_destroy(&resumed)
    testing.expect_value(
        t,
        net.server_restore(
            &resumed,
            &current,
            game.model(),
            {},
            {epoch = 2, local_seat = 1, retain_membership = true, preserve_pending = true},
        ),
        net.Error.None,
    )
    before, _ := r.current(&resumed.timeline)
    testing.expect(t, reflect.equal(before, current.frame))
    testing.expect_value(t, net.server_step(&resumed), net.Error.None)
    after, _ := r.current(&resumed.timeline)
    testing.expect(t, !after.state.door_open && after.state.epoch == 2)
    events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(base.Event))
    count, copied := r.copy_events(&resumed.timeline, after.tick, events[:])
    testing.expect_value(t, copied, r.Error.None)
    verdicts := 0
    for event in events[:count] {
        if event.value.kind == .Action_Result &&
           event.value.sequence == current.actions[0].sequence &&
           event.value.seat == 1 {
            verdicts += 1
            testing.expect(t, !event.value.applied && event.value.reason == .Predicate)
        }
    }
    testing.expect_value(t, verdicts, 1)
    testing.expect_value(t, resumed.peers[int(current.actions[0].peer)].action_settled, current.actions[0].sequence)
    // Accepted-pose commands use the accepted position, not a fabricated origin.
}
