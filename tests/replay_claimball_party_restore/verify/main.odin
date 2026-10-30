package main
import "core:fmt"
import "core:os"
import db "godot:replay/provision/sqlite"
import p "godot:replay/provision"
import net "godot:replay/net"
import lb "godot:replay/lobby"
import sc "godot:replay/schema"
import game "godot:examples/replay_claimball/shared/pitch"
main :: proc() {
 assert(len(os.args)==3 && (os.args[2]=="source" || os.args[2]=="continued"))
 source:=os.args[2]=="source"
 store:db.Store;assert(db.open(&store,os.args[1])==.None);defer db.close(&store)
 rooms:[8]p.Bundle;n,err:=db.load_all(&store,game.CONTENT,rooms[:]);assert(err==.None && n==1)
 saved,found,loaded:=db.checkpoint_load(&store,rooms[0].record.room,game.CONTENT,game.model());defer db.stored_checkpoint_destroy(&saved)
 assert(found && loaded==.None && saved.publication.revision==(source ? u64(1) : u64(2)))
 cp:net.Checkpoint(game.World,game.Controls,game.Action,game.SEATS);defer net.checkpoint_destroy(&cp)
 assert(net.checkpoint_decode(&cp,saved.bytes,game.model(),game.CONTENT)==.None)
 w:=&cp.frame.state;assert(game.state_valid(w^) && w.group_seat==0 && !w.outside.valid && w.started)
 assert(cp.header.epoch==(source ? u64(1) : u64(2)))
 assert(lb.text(&w.names[0])=="Captain" && lb.text(&w.names[1])=="Striker" && lb.text(&w.names[2])=="Wing")
 for player in w.players[:3] {assert(player.initialized && player.connected)}
 if source {velocity:=w.ball.motion.velocity;assert(w.score.winner==0 && w.ball.hold==0 && velocity[0]*velocity[0]+velocity[1]*velocity[1]>0.25 && u16(w.score.left)+u16(w.score.right)>0)}
 else {assert(w.spikes>=2 && w.kicks>0)}
 schema:sc.Schema;assert(sc.init(&schema,game.World).error==.None);defer sc.destroy(&schema)
 bytes:=make([]u8,schema.wire_size);defer delete(bytes);assert(sc.encode(&schema,w^,bytes).error==.None)
 fmt.printf("CLAIMBALL_PUBLISHED_STATE stage=%s tick=%d hash=%d epoch=%d revision=%d round=%d score=%d-%d kicks=%d spikes=%d velocity=%v complete=true names=true\n",os.args[2],cp.frame.tick,sc.digest(bytes)&0x7fff_ffff_ffff_ffff,cp.header.epoch,saved.publication.revision,w.round,w.score.left,w.score.right,w.kicks,w.spikes,w.ball.motion.velocity)
}
