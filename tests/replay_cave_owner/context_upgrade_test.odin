package cave_owner_test
import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import game "../../examples/replay_cavecrawl/shared/owner_cave"
import base "../../examples/replay_cavecrawl/shared/cave"
import upgrade "../../examples/replay_cavecrawl/shared/owner_upgrade"

@(test)
owner1_archive_preserves_world_and_pending_action_meaning :: proc(t:^testing.T) {
 bytes:=transmute([]u8)#load("fixtures/owner1/pending.checkpoint")
 old:net.Checkpoint(game.World,game.Control,base.Action,game.SEATS);defer net.checkpoint_destroy(&old)
 testing.expect_value(t,net.checkpoint_decode(&old,bytes,upgrade.model_1(),upgrade.CONTENT_1),net.Error.None)
 converted,error:=upgrade.convert_archive(bytes);defer delete(converted);testing.expect_value(t,error,net.Error.None)
 current:net.Checkpoint(game.World,game.Control,game.Action,game.SEATS);defer net.checkpoint_destroy(&current)
 testing.expect_value(t,net.checkpoint_decode(&current,converted,game.model(),game.CONTENT),net.Error.None)
 testing.expect(t,reflect.equal(old.frame,current.frame) && reflect.equal(old.held,current.held) && reflect.equal(old.peers[:],current.peers[:],true))
 testing.expect_value(t,len(current.actions),1)
 testing.expect(t,current.actions[0].value.origin_kind==.Accepted_Pose && reflect.equal(game.command(current.actions[0].value),old.actions[0].value))
 testing.expect(t,current.actions[0].sequence==old.actions[0].sequence && current.actions[0].tick==old.actions[0].tick && current.actions[0].reason==old.actions[0].reason)
 resumed:Server;defer net.server_destroy(&resumed)
 testing.expect_value(t,net.server_restore(&resumed,&current,game.model(),{}, {epoch=2,local_seat=1,retain_membership=true,preserve_pending=true}),net.Error.None)
 before,_:=r.current(&resumed.timeline);testing.expect(t,reflect.equal(before,current.frame))
 testing.expect_value(t,net.server_step(&resumed),net.Error.None)
 after,_:=r.current(&resumed.timeline);testing.expect(t,!after.state.door_open && after.state.epoch==2)
 // An old action had no caller origin; its out-of-range door stays refused.
}
