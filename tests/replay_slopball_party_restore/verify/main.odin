package main
import "core:fmt"
import "core:os"
import db "godot:replay/provision/sqlite"
import p "godot:replay/provision"
import net "godot:replay/net"
import lb "godot:replay/lobby"
import sc "godot:replay/schema"
import game "godot:examples/replay_slopball/shared/pitch"
main :: proc() {
 assert((len(os.args)==3 || len(os.args)==4) && (os.args[2]=="source" || os.args[2]=="continued"))
 if len(os.args)==4 {assert(os.args[3]=="host" || os.args[3]=="striker")}
 owner:=len(os.args)==4 && os.args[3]=="striker" ? u16(2) : u16(1)
 source:=os.args[2]=="source"
 store:db.Store;assert(db.open(&store,os.args[1])==.None);defer db.close(&store)
 rooms:[8]p.Bundle;n,err:=db.load_all(&store,game.CONTENT,rooms[:]);assert(err==.None && n==1)
 saved,found,loaded:=db.checkpoint_load(&store,rooms[0].record.room,game.CONTENT,game.model());defer db.stored_checkpoint_destroy(&saved)
 assert(found && loaded==.None && saved.publication.revision==(source ? u64(1) : u64(2)))
 cp:net.Checkpoint(game.World,game.Control,game.Action,game.SEATS);defer net.checkpoint_destroy(&cp)
 assert(net.checkpoint_decode(&cp,saved.bytes,game.model(),game.CONTENT)==.None)
 w:=&cp.frame.state;assert(game.state_valid(w^) && w.started)
 assert(cp.header.epoch==(source ? u64(1) : u64(2)) && w.ball.epoch==cp.header.epoch)
 assert(lb.text(&w.names[0])=="Captain" && lb.text(&w.names[1])=="Striker" && lb.text(&w.names[2])=="Wing")
 for player in w.players[:3] {assert(player.initialized && player.connected)}
 if source {velocity:=w.ball.value.linear;assert(w.won==0 && w.tick>=w.kickoff_until && w.ball.owner==1 && w.ball.sequence>0 && velocity[0]*velocity[0]+velocity[1]*velocity[1]>1600 && w.left+w.right>0)}
 else {assert(cp.header.local_seat==owner && saved.publication.publisher.member==u64(owner) && w.ball.sequence>0);if owner==1 {assert(w.left>=2)} else {assert(w.right>0)}}
 schema:sc.Schema;assert(sc.init(&schema,game.World).error==.None);defer sc.destroy(&schema)
 bytes:=make([]u8,schema.wire_size);defer delete(bytes);assert(sc.encode(&schema,w^,bytes).error==.None)
 fmt.printf("SLOPBALL_PUBLISHED_STATE stage=%s tick=%d hash=%d epoch=%d revision=%d round=%d score=%d-%d owner=%d sequence=%d authority_seat=%d complete=true names=true\n",os.args[2],cp.frame.tick,sc.digest(bytes)&0x7fff_ffff_ffff_ffff,cp.header.epoch,saved.publication.revision,w.round,w.left,w.right,w.ball.owner,w.ball.sequence,cp.header.local_seat)
 pose:=w.ball.value
 fmt.printf("SLOPBALL_PUBLISHED_POSE [%v,%v,%v,%v,%v,%v]\n",pose.position[0],pose.position[1],pose.rotation,pose.linear[0],pose.linear[1],pose.angular)
}
