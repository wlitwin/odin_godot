package main

import "core:fmt"
import "core:os"
import db "godot:replay/provision/sqlite"
import p "godot:replay/provision"
import net "godot:replay/net"
import play "godot:replay/play"
import cave "godot:examples/replay_cavecrawl/shared/cave"

main :: proc() {
	assert(len(os.args)==2)
	store:db.Store;assert(db.open(&store,os.args[1])==.None);defer db.close(&store)
	rooms:[2]p.Bundle;count,error:=db.load_all(&store,cave.CONTENT,rooms[:]);assert(error==.None && count==1)
	room:=rooms[0].record;assert(room.epoch==2 && room.members[0].identity.incarnation==3 && room.members[1].identity.incarnation==3)
	saved,found,loaded:=db.checkpoint_load(&store,room.room,cave.CONTENT,cave.model());defer db.stored_checkpoint_destroy(&saved)
	assert(found && loaded==.None && saved.publication.revision==2 && saved.publication.publisher==room.owner)
	cp:net.Checkpoint(cave.World,cave.Control,cave.Action,cave.SEATS);defer net.checkpoint_destroy(&cp)
	assert(net.checkpoint_decode(&cp,saved.bytes,cave.model(),cave.CONTENT)==.None && cp.header.epoch==2 && u64(cp.header.local_seat)==room.owner.member)
	gems:=play.inventory_count(cp.frame.state.players[0].bag[:],cave.GEM)+play.inventory_count(cp.frame.state.players[1].bag[:],cave.GEM)
	assert(gems==3 && play.inventory_count(cp.frame.state.chest[:],cave.GEM)==0)
	fmt.printf("REPLAY_RESTORE_CONTENTION_DURABLE_OK epoch=2 owner=%d publication=2 tick=%d gems=3\n",room.owner.member,cp.frame.tick)
}
