package main

import "core:fmt"
import "core:os"
import a "godot:replay/assets"
import ck "godot:replay/provision/checkpoint"
import db "godot:replay/provision/sqlite"
import p "godot:replay/provision"
import net "godot:replay/net"
import game "godot:examples/replay_scrapyard/shared/game"

main :: proc() {
	assert(len(os.args)==3)
	expected,read:=os.read_entire_file(os.args[2],context.allocator);assert(read==nil);defer delete(expected)
	ref:=a.reference(expected)
	policy:=ck.Asset_Policy{collect=game.checkpoint_assets,validate=proc(_:rawptr,_:a.Ref,bytes:[]u8)->bool {_,valid:=a.png_info(bytes);return valid}}
	store:db.Store;assert(db.open(&store,os.args[1])==.None);defer db.close(&store)
	rooms:[2]p.Bundle;count,error:=db.load_all(&store,game.CONTENT,rooms[:]);assert(error==.None && count==1)
	saved,found,loaded:=db.checkpoint_load(&store,rooms[0].record.room,game.CONTENT,game.model(),assets=policy);defer db.stored_checkpoint_destroy(&saved)
	assert(found && loaded==.None && saved.publication.revision>=2 && saved.publication.point.scope.epoch==2 && len(saved.payload)>0)
	cp:=new(net.Checkpoint(game.World,game.Control,game.Action,game.SEATS));defer free(cp);defer net.checkpoint_destroy(cp)
	assert(net.checkpoint_decode(cp,saved.bytes,game.model(),game.CONTENT)==.None)
	assert(cp.header.local_seat==1 && cp.frame.state.players[0].spray.image==ref && cp.frame.state.players[0].spray.stamp>0 && cp.frame.state.players[0].shots>0)
	cache:a.Cache;assert(a.cache_init(&cache)==.None);defer a.cache_destroy(&cache)
	assert(ck.package_install(saved.payload,saved.bytes,saved.publication.point,&cache,policy)==.None && cache.count==1)
	actual,copied:=a.cache_copy(&cache,ref);defer delete(actual);assert(copied==.None && a.reference(actual)==ref)
	fmt.printf("REPLAY_SCRAPYARD_DURABLE_ASSET_VERIFIED revision=%d epoch=2 tick=%d shots=%d assets=%d asset_bytes=%d payload_bytes=%d\n",saved.publication.revision,cp.frame.tick,cp.frame.state.players[0].shots,cache.count,cache.bytes,len(saved.payload))
}
