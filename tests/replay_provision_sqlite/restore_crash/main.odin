package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:time"
import auth "godot:replay/authority"
import sql "godot:replay/authority/sqlite"
import p "godot:replay/provision"
import db "godot:replay/provision/sqlite"
import ck "godot:replay/provision/checkpoint"
import net "godot:replay/net"
import tr "godot:replay/transport"
import f "../publication_fixture"

foreign import sqlite "system:sqlite3"
foreign sqlite {sqlite3_commit_hook :: proc "c" (sql.DB,proc "c" (rawptr)->i32,rawptr)->rawptr ---}
stall :: proc "c" (_:rawptr)->i32 {
	context=runtime.default_context();fmt.println("REPLAY_RESTORE_UNCOMMITTED")
	for {time.sleep(100*time.Millisecond)}
}
Fixture :: struct {now:u64,store:db.Store,room:p.Room,memory:tr.Memory,endpoints:[2]tr.Memory_Endpoint,lease:auth.Lease,rpc:auth.Rpc_Client,client:ck.Client,server:ck.Server,backend:db.Checkpoint_Backend(f.World,u8,u8,u8,1)}
clock :: proc(user:rawptr)->(u64,bool) {return (cast(^Fixture)user).now,true}
step :: proc(x:^Fixture) {
	x.now+=10;tr.memory_advance(&x.memory,x.now/10)
	auth.rpc_client_pump(&x.rpc);if x.client.ready {ck.client_update(&x.client)};ck.server_update(&x.server)
	buffer:[tr.MAX_PACKET_BYTES]u8
	for i in 0..<2 {
		wire:=tr.memory_transport(&x.endpoints[i])
		for _ in 0..<32 {
			packet:=tr.receive(&wire,buffer[:]);if packet.state!=.Received {break}
			if i==0 {if !ck.server_receive(&x.server,packet.from,buffer[:packet.count]) {auth.service_receive(&x.room.service,packet.from,buffer[:packet.count])}}
			else if !ck.client_receive(&x.client,packet.from,buffer[:packet.count]) {auth.rpc_client_receive(&x.rpc,packet.from,buffer[:packet.count])}
		}
	}
}
rpc :: proc(x:^Fixture,command:auth.Command)->auth.Reply {
	assert(auth.rpc_begin(&x.rpc,command)==.None)
	for _ in 0..<100 {step(x);if !x.rpc.pending {assert(x.rpc.reply.result==.None);return x.rpc.reply}}
	panic("RPC timed out")
}
finish :: proc(x:^Fixture) {for _ in 0..<300 {step(x);assert(x.client.phase!=.Failed);if x.client.phase==.Complete {return}};panic("checkpoint timed out")}
main :: proc() {
	assert(len(os.args)==3);mode,path:=os.args[1],os.args[2]
	if mode=="create" {
		x:=new(f.Fixture);defer free(x);f.open(x,path);defer f.close(x)
		point,bytes:=f.checkpoint(x,1);defer delete(bytes)
		_,error:=db.checkpoint_publish(&x.store,x.room.bundle.record,0,point,bytes,f.model());assert(error==.None)
		fmt.println("REPLAY_RESTORE_CREATED");return
	}
	x:=new(Fixture);defer free(x)
	assert(db.open(&x.store,path)==.None);defer db.close(&x.store)
	b,found,error:=db.load(&x.store,44,55);assert(found && error==.None)
	if mode=="verify-uncommitted" || mode=="verify-committed" {
		epoch:=mode=="verify-uncommitted" ? u64(1) : u64(2)
		assert(b.record.epoch==epoch && b.record.members[0].identity.incarnation==2)
		assert(b.record.requests[0].sequence==epoch+1 && b.record.requests[0].nonce==(auth.Nonce{0=88}))
		assert(b.record.owner.incarnation==epoch)
		saved,exists,loaded:=db.checkpoint_load(&x.store,44,55,f.model());defer db.stored_checkpoint_destroy(&saved)
		assert(exists && loaded==.None && saved.publication.revision==1 && saved.publication.point.scope.epoch==1)
		if epoch==2 {assert(b.record.recovered==saved.publication.point)} else {assert(b.record.recovered==(auth.Point{}))}
		cp:net.Checkpoint(f.World,u8,u8,1);defer net.checkpoint_destroy(&cp)
		assert(net.checkpoint_decode(&cp,saved.bytes,f.model(),55)==.None && cp.frame.tick==1 && cp.frame.state.value==8)
		assert(p.open(&x.room,b,db.commit,&x.store,{x,clock})==.None);defer p.close(&x.room)
		assert(!x.room.service.coordinator.active && x.room.service.coordinator.restarted)
		fmt.printf("REPLAY_RESTORE_CRASH_OK mode=%s epoch=%d incarnation=2 request=%d publication=1 tick=1 value=8 active=false\n",mode,epoch,b.record.requests[0].sequence);return
	}
	assert(mode=="uncommitted" || mode=="committed")
	tr.memory_init(&x.memory,cfg={2,128,tr.MAX_PACKET_BYTES,8192},faults={latency_ticks=1,retry_ticks=3});defer tr.memory_destroy(&x.memory)
	for &e,i in x.endpoints {tr.memory_open(&x.memory,&e,tr.Peer_Id(i+1))}
	defer for &e in x.endpoints {wire:=tr.memory_transport(&e);tr.close(&wire)}
	assert(p.open(&x.room,b,db.commit,&x.store,{x,clock},tr.memory_transport(&x.endpoints[0]))==.None);defer p.close(&x.room)
	x.backend={store=&x.store,model=f.model()};assert(ck.server_open(&x.server,&x.room.service,db.checkpoint_backend(&x.backend),tr.memory_transport(&x.endpoints[0])));defer ck.server_close(&x.server)
	x.now=x.room.service.coordinator.quarantine_until+100
	assert(auth.lease_init(&x.lease,b.record.owner,44,55,{x,clock},false)==.None)
	assert(auth.rpc_client_init(&x.rpc,&x.lease,b.enrollments[0].key,auth.Nonce{0=88},tr.memory_transport(&x.endpoints[1])));defer auth.rpc_client_destroy(&x.rpc)
	x.rpc.wire.receive,x.rpc.wire.poll=nil,nil
	reply:=rpc(x,{verb=.Challenge});rpc(x,{verb=.Rebind,incarnation=reply.registration_identity.incarnation,challenge=reply.challenge})
	assert(ck.client_open(&x.client,x.rpc.key,{x,clock},tr.memory_transport(&x.endpoints[1])));defer ck.client_close(&x.client)
	saved,exists,loaded:=db.checkpoint_load(&x.store,44,55,f.model());defer db.stored_checkpoint_destroy(&saved);assert(exists && loaded==.None)
	q:=ck.Request{version=ck.VERSION,verb=.Download,room=44,content=55,sequence=1,generation=x.lease.view.coordinator_generation,
		identity=x.lease.identity,nonce=x.rpc.nonce,revision=1,contract=saved.publication.contract}
	assert(ck.client_begin(&x.client,q)==.None);finish(x)
	prepared:auth.Prepared;defer auth.prepared_destroy(&prepared)
	assert(ck.client_prepare(&x.client,&prepared,f.model())==.None)
	if mode=="uncommitted" {sqlite3_commit_hook(x.store.connection.db,stall,nil)}
	assert(ck.client_restore(&x.client,&x.lease,saved.publication,&prepared)==.None);finish(x)
	assert(x.lease.view.epoch==2 && x.room.bundle.record.requests[0].sequence==3)
	fmt.println("REPLAY_RESTORE_COMMITTED");for {time.sleep(100*time.Millisecond)}
}
