package main
import "core:fmt"
import "core:os"
import net "godot:replay/net"
import sc "godot:replay/schema"
import lb "godot:replay/lobby"
import game "godot:examples/replay_slopball/shared/pitch"
main :: proc() {
 assert(len(os.args)==2)
 bytes,e:=os.read_entire_file(os.args[1],context.allocator);assert(e==nil);defer delete(bytes)
 cp:net.Checkpoint(game.World,game.Control,game.Action,game.SEATS);defer net.checkpoint_destroy(&cp)
 assert(net.checkpoint_decode(&cp,bytes,game.model(),game.CONTENT)==.None)
 w:=&cp.frame.state;assert(game.state_valid(w^) && w.started && w.won==0 && w.left+w.right>0 && w.ball.owner==1 && w.ball.sequence>0)
 assert(cp.header.epoch==1 && cp.header.local_seat==1 && !cp.settings.require_permit && cp.header.policy_id==0)
 assert(lb.text(&w.names[0])=="Saved Kicker" && w.players[0].connected)
 pose:=w.ball.value
 assert(pose.linear[0]*pose.linear[0]+pose.linear[1]*pose.linear[1]>1600)
 codec:sc.Schema;assert(sc.init(&codec,game.World).error==.None);defer sc.destroy(&codec)
 world:=make([]u8,codec.wire_size);defer delete(world);assert(sc.encode(&codec,w^,world).error==.None)
 fmt.print("{")
 fmt.printf("\"tick\":%d,\"hash\":\"%d\",\"epoch\":%d,\"left\":%d,\"right\":%d,\"pose\":[%v,%v,%v,%v,%v,%v]",cp.frame.tick,sc.digest(world)&0x7fff_ffff_ffff_ffff,cp.header.epoch,w.left,w.right,pose.position[0],pose.position[1],pose.rotation,pose.linear[0],pose.linear[1],pose.angular)
 fmt.println("}")
}
