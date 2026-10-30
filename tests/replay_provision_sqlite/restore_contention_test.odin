package replay_provision_sqlite_test

import "core:fmt"
import "core:mem"
import "core:testing"
import auth "godot:replay/authority"
import ck "godot:replay/provision/checkpoint"
import db "godot:replay/provision/sqlite"
import rgd "godot:replay/godot"
import tr "godot:replay/transport"
import f "publication_fixture"

Busy_Restore_Load :: struct {backend:ck.Backend,remaining,rejected:int}
@(test)
fresh_room_retries_busy_checkpoint_service_without_becoming_a_terminal_failure :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/restore-contention.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	_,error:=db.checkpoint_publish(&x.base.store,x.base.room.bundle.record,0,point,bytes,f.model());assert(error==.None)
	x.now=2500;restore_fresh_owner(x)
	room:=new(Save_Room);defer free(room);restore_room_open(room,x);defer restore_room_close(room)
	busy:=Busy_Restore_Load{backend=x.server.backend,remaining=2}
	x.server.backend={user=&busy,
		load=proc(user:rawptr,room,content:u64,allocator:mem.Allocator)->(ck.Saved,bool,ck.Error) {
			b:=cast(^Busy_Restore_Load)user
			if b.remaining>0 {b.remaining-=1;b.rejected+=1;return {},false,.Busy}
			return b.backend.load(b.backend.user,room,content,allocator)
		},
		recover=proc(user:rawptr,s:^auth.Service,from:tr.Peer_Id,actor:auth.Identity,nonce:auth.Nonce,sequence:u64,digest:[32]u8,epoch:u64,publication:ck.Publication)->(auth.Error,bool) {
			b:=cast(^Busy_Restore_Load)user;return b.backend.recover(b.backend.user,s,from,actor,nonce,sequence,digest,epoch,publication)
		}}
	for _ in 0..<250 {restore_room_step(room,x);if room.restore.phase==.Granted {break}}
	testing.expect(t,busy.rejected==2 && room.restore.phase==.Granted && room.restore.error==.None)
	testing.expect(t,room.restore.prepared.point==point && x.base.room.bundle.record.epoch==2 && !room.session.ready)
}
