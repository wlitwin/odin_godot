package replay_provision_sqlite_test

import "core:fmt"
import "core:mem"
import "core:testing"
import auth "godot:replay/authority"
import ck "godot:replay/provision/checkpoint"
import db "godot:replay/provision/sqlite"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import tr "godot:replay/transport"
import tf "godot:replay/transfer"
import sc "godot:replay/schema"
import f "publication_fixture"

Restore_Preparation :: struct {allowed:bool,calls:u64}
Restore_Ack_Gate :: struct {base:tr.Transport,client:^ck.Client,dropped:u64}
restore_ack_wire :: proc(g:^Restore_Ack_Gate)->tr.Transport {
	return {user=g,send=proc(user:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {
		g:=cast(^Restore_Ack_Gate)user
		if g.dropped==0 && len(bytes)>32 {
			data:ck.Data
			_,report:=sc.unpack(&g.client.codecs.data,&data,bytes[:len(bytes)-32],{kind=ck.UPSTREAM_KIND,epoch=u64(ck.VERSION),content=55})
			if report.error==.None && data.count<=len(data.bytes) {
				meta,_,inner:=sc.inspect(data.bytes[:data.count])
				if inner.error==.None && meta.kind==ck.TRANSFER_BASE+4 {g.dropped+=1;return .Sent}
			}
		}
		return tr.send(&g.base,to,channel,bytes)
	},connected=proc(user:rawptr,peer:tr.Peer_Id)->bool{return tr.peer_connected(&(cast(^Restore_Ack_Gate)user).base,peer)}}
}
restore_room_open :: proc(room:^Save_Room,x:^Protocol_Fixture) {
	room.allocator=context.allocator;room.ready,room.registered=true,true;room.phase=.Connecting
	room.options={room=44,identity=x.lease.identity,control_backend=.Websocket,coordinator="wss://fixture.invalid",restore_published=true,session=rgd.SESSION_OPTIONS}
	room.options.session.network=x.base.server.cfg;room.options.session.token=x.base.room.bundle.enrollments[0].token
	room.clock={x,protocol_clock};room.control_wire=tr.memory_transport(&x.endpoints[1]);room.model=f.model()
	room.members=x.base.room.bundle.record.members
	room.lease=x.lease;room.rpc=x.rpc;x.rpc={};room.rpc.lease=&room.lease
}
restore_room_close :: proc(room:^Save_Room) {
	net.checkpoint_codec_destroy(&room.checkpoint_codec)
	ck.client_close(&room.restore.client);auth.prepared_destroy(&room.restore.prepared);auth.rpc_client_destroy(&room.rpc)
}
restore_room_step :: proc(room:^Save_Room,x:^Protocol_Fixture) {
	x.now+=10;tr.memory_advance(&x.memory,x.now/10)
	assert(rgd.room_control_pump(room)==.None);rgd.room_restore_frame(room,x.now);ck.server_update(&x.server)
	buffer:[tr.MAX_PACKET_BYTES]u8;wire:=tr.memory_transport(&x.endpoints[0])
	for _ in 0..<32 {packet:=tr.receive(&wire,buffer[:]);if packet.state!=.Received {break};if !ck.server_receive(&x.server,packet.from,buffer[:packet.count]) {auth.service_receive(&x.base.room.service,packet.from,buffer[:packet.count])}}
}

@(test)
room_waits_for_asset_preparation_before_requesting_published_authority :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/room-restore-preparation.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	_,error:=db.checkpoint_publish(&x.base.store,x.base.room.bundle.record,0,point,bytes,f.model());assert(error==.None)
	x.now=2500;restore_fresh_owner(x)
	room:=new(Save_Room);defer free(room);restore_room_open(room,x);defer restore_room_close(room)
	gate:Restore_Preparation
	room.options.preparation_user=&gate
	room.options.preparation_ready=proc(user:rawptr,point:auth.Point,bytes:[]u8)->bool {
		g:=cast(^Restore_Preparation)user;g.calls+=1;assert(point.archive.bytes==u32(len(bytes)));return g.allowed
	}
	for _ in 0..<100 {restore_room_step(room,x);if room.restore.phase==.Downloading {break}}
	ack:=Restore_Ack_Gate{room.restore.client.lane.wire,&room.restore.client,0};room.restore.client.lane.wire=restore_ack_wire(&ack)
	for _ in 0..<100 {restore_room_step(room,x);if gate.calls>=3 {break}}
	testing.expect(t,room.restore.phase==.Preparing && gate.calls>=3 && room.restore.prepared.ready && !room.session.ready)
	testing.expect(t,x.base.room.bundle.record.epoch==1 && room.lease.view.remaining_ms==0 && !room.lease.pending)
	for _ in 0..<25 {restore_room_step(room,x)}
	testing.expect(t,ack.dropped==1 && x.server.sender.stats.retries>0)
	testing.expect_value(t,x.server.sender.phase,tf.Phase.Complete)
	gate.allowed=true
	for _ in 0..<100 {restore_room_step(room,x);if room.restore.phase==.Granted {break}}
	testing.expect(t,room.restore.phase==.Granted && x.base.room.bundle.record.epoch==2 && auth.lease_live(&room.lease,2) && !room.session.ready)
	testing.expect(t,room.restore.prepared.point==point && room.restore.local_seat==1)
	testing.expect_value(t,room.restore.renewed_epoch,u64(0))
	assert(auth.rpc_begin(&room.rpc,{verb=.Renew,epoch=2,tick=point.archive.tick})==.None)
	for _ in 0..<100 {restore_room_step(room,x);if room.restore.renewed_epoch==2 {break}}
	testing.expect(t,room.restore.renewed_epoch==2 && !room.session.ready && auth.lease_live(&room.lease,2))
}

@(test)
room_restore_storage_error_is_visible_and_explicit_retry_keeps_existing_save :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/room-restore-retry.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	_,error:=db.checkpoint_publish(&x.base.store,x.base.room.bundle.record,0,point,bytes,f.model());assert(error==.None)
	x.now=2500;restore_fresh_owner(x)
	room:=new(Save_Room);defer free(room);restore_room_open(room,x);defer restore_room_close(room)
	load:=x.server.backend.load;x.server.backend.load=proc(_:rawptr,_:u64,_:u64,_:mem.Allocator)->(ck.Saved,bool,ck.Error){return {},false,.Storage}
	for _ in 0..<100 {restore_room_step(room,x);if room.restore.phase==.Failed {break}}
	testing.expect(t,room.restore.phase==.Failed && room.restore.error==.Storage && !room.session.ready && x.base.room.bundle.record.epoch==1)
	x.server.backend.load=load
	testing.expect(t,rgd.room_restore_retry(room))
	for _ in 0..<100 {restore_room_step(room,x);if room.restore.phase==.Granted {break}}
	testing.expect(t,room.restore.phase==.Granted && room.restore.prepared.point==point && room.restore.publication.revision==1)
}
