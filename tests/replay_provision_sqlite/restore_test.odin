package replay_provision_sqlite_test

import "core:fmt"
import "core:mem"
import "core:testing"
import auth "godot:replay/authority"
import ck "godot:replay/provision/checkpoint"
import db "godot:replay/provision/sqlite"
import net "godot:replay/net"
import p "godot:replay/provision"
import r "godot:replay"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import f "publication_fixture"

restore_rpc :: proc(x:^Protocol_Fixture,command:auth.Command)->auth.Reply {
	assert(auth.rpc_begin(&x.rpc,command)==.None)
	for _ in 0..<100 {
		x.now+=10;tr.memory_advance(&x.memory,x.now/10)
		auth.rpc_client_pump(&x.rpc);auth.service_pump(&x.base.room.service)
		if !x.rpc.pending {return x.rpc.reply}
	}
	panic("restore registration reply missing")
}
restore_fresh_owner :: proc(x:^Protocol_Fixture,slot:int=0) {
	ck.client_close(&x.client);auth.rpc_client_destroy(&x.rpc);x.lease={}
	assert(auth.lease_init(&x.lease,x.base.room.bundle.record.members[slot].identity,44,55,{x,protocol_clock},false)==.None)
	assert(auth.rpc_client_init(&x.rpc,&x.lease,x.base.room.bundle.enrollments[slot].key,auth.Nonce{0=u8(88+slot)},tr.memory_transport(&x.endpoints[1])))
	reply:=restore_rpc(x,{verb=.Challenge});assert(reply.result==.None)
	reply=restore_rpc(x,{verb=.Rebind,incarnation=reply.registration_identity.incarnation,challenge=reply.challenge});assert(reply.result==.None)
	assert(ck.client_open(&x.client,x.rpc.key,{x,protocol_clock},tr.memory_transport(&x.endpoints[1])))
}
restore_download :: proc(x:^Protocol_Fixture,prepared:^auth.Prepared)->ck.Publication {
	assert(ck.client_begin(&x.client,protocol_request(x,.Download,1,1))==.None);protocol_finish(x)
	assert(x.client.phase==.Complete && ck.client_prepare(&x.client,prepared,f.model())==.None)
	return x.client.saved.publication
}

@(test)
fresh_owner_registration_does_not_grant_but_published_restore_advances_epoch_and_continues :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/restore-fresh.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	_,error:=db.checkpoint_publish(&x.base.store,x.base.room.bundle.record,0,point,bytes,f.model());assert(error==.None)
	old_packet,old_count:=x.rpc.txb,x.rpc.count;old_identity:=x.lease.identity
	x.now=2500;restore_fresh_owner(x)
	testing.expect(t,x.lease.identity.incarnation==2 && x.base.room.bundle.record.owner==old_identity && x.lease.view.remaining_ms==0 && !auth.lease_live(&x.lease,1))
	before:=x.base.room.bundle.record
	auth.service_receive(&x.base.room.service,2,old_packet[:old_count]);testing.expect_value(t,x.base.room.bundle.record,before)
	prepared:auth.Prepared;defer auth.prepared_destroy(&prepared);publication:=restore_download(x,&prepared)
	assert(ck.client_restore(&x.client,&x.lease,publication,&prepared)==.None);protocol_finish(x)
	testing.expect(t,x.client.phase==.Complete && x.lease.view.epoch==2 && x.lease.require_owner && auth.lease_live(&x.lease,2))
	testing.expect(t,x.base.room.bundle.record.owner==x.lease.identity && x.base.room.bundle.record.recovered==point && x.base.room.bundle.record.revision==before.revision+1)
	server:=new(f.Server);defer free(server);defer net.server_destroy(server)
	testing.expect_value(t,auth.prepared_restore(&prepared,server,f.model(),{},&x.lease,1,options={local_incarnation=x.lease.identity.incarnation}),net.Error.None)
	testing.expect_value(t,server.peers[0].incarnation,u64(2))
	net.server_local(server,1);testing.expect_value(t,net.server_step(server),net.Error.None)
	frame,_:=r.current(&server.timeline);testing.expect(t,frame.tick==point.archive.tick+1 && frame.state.value==9)
	current:net.Checkpoint(f.World,u8,u8,1);defer net.checkpoint_destroy(&current)
	assert(net.checkpoint_capture(server,&current)==.None)
	stale:=new(f.Server);defer free(stale);defer net.server_destroy(stale)
	testing.expect_value(t,net.server_restore(stale,&current,f.model(),{},{epoch=3,local_seat=1,local_incarnation=1,permit=auth.lease_permit(&x.lease)}),net.Error.Invalid_Config)
	testing.expect(t,!stale.initialized && len(stale.inputs)==0 && stale.peers[0].incarnation==0)
	// Replaying the exact signed grant request acknowledges one durable decision.
	revision:=x.base.room.bundle.record.revision
	load:=x.server.backend.load;x.server.backend.load=proc(_:rawptr,_:u64,_:u64,_:mem.Allocator)->(ck.Saved,bool,ck.Error){panic("exact restore retry decoded storage again")}
	testing.expect(t,ck.server_receive(&x.server,2,x.client.txb[:x.client.count]))
	x.server.backend.load=load
	testing.expect_value(t,x.base.room.bundle.record.revision,revision)
	testing.expect(t,restore_rpc(x,{verb=.Renew,epoch=2,tick=frame.tick}).result==.None)
}

@(test)
published_restore_refuses_live_lease_and_known_excessive_rollback :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/restore-policy.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	_,error:=db.checkpoint_publish(&x.base.store,x.base.room.bundle.record,0,point,bytes,f.model());assert(error==.None)
	prepared:auth.Prepared;defer auth.prepared_destroy(&prepared);publication:=restore_download(x,&prepared)
	before:=x.base.room.bundle.record
	assert(ck.client_restore(&x.client,&x.lease,publication,&prepared)==.None);protocol_finish(x)
	testing.expect(t,x.client.phase==.Failed && x.client.reply.recovery_result==.Busy && x.base.room.bundle.record.epoch==before.epoch && !x.lease.pending)
	busy_packet,busy_count:=x.client.txb,x.client.count
	busy_revision:=x.base.room.bundle.record.revision
	assert(restore_rpc(x,{verb=.Renew,epoch=1,tick=1000}).result==.None)
	x.now+=2500;restore_fresh_owner(x)
	auth.prepared_destroy(&prepared);publication=restore_download(x,&prepared);before=x.base.room.bundle.record
	assert(ck.client_restore(&x.client,&x.lease,publication,&prepared)==.None);protocol_finish(x)
	testing.expect(t,x.client.phase==.Failed && x.client.reply.recovery_result==.Too_Old && x.base.room.bundle.record.epoch==before.epoch && x.base.room.bundle.record.owner==before.owner)
	// The old process nonce cannot replay its rejected request after rebind.
	testing.expect(t,!ck.server_receive(&x.server,2,busy_packet[:busy_count]) && x.base.room.bundle.record.revision>busy_revision)
}

@(test)
coordinator_restart_quarantine_and_lost_grant_point_remain_fenced :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/restore-restart.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	_,error:=db.checkpoint_publish(&x.base.store,x.base.room.bundle.record,0,point,bytes,f.model());assert(error==.None)
	x.now=2500;restore_fresh_owner(x)
	prepared:auth.Prepared;defer auth.prepared_destroy(&prepared);publication:=restore_download(x,&prepared)
	assert(ck.client_restore(&x.client,&x.lease,publication,&prepared)==.None);protocol_finish(x);assert(x.client.phase==.Complete)
	ck.client_close(&x.client);ck.server_close(&x.server);auth.rpc_client_destroy(&x.rpc)
	p.close(&x.base.room)
	b,found,loaded:=db.load(&x.base.store,44,55);assert(found && loaded==.None)
	assert(p.open(&x.base.room,b,db.commit,&x.base.store,{x,protocol_clock},tr.memory_transport(&x.endpoints[0]))==.None)
	assert(ck.server_open(&x.server,&x.base.room.service,db.checkpoint_backend(&x.backend),tr.memory_transport(&x.endpoints[0])))
	x.lease={};assert(auth.lease_init(&x.lease,b.record.owner,44,55,{x,protocol_clock},false)==.None)
	assert(auth.rpc_client_init(&x.rpc,&x.lease,b.enrollments[0].key,auth.Nonce{0=99},tr.memory_transport(&x.endpoints[1])))
	testing.expect(t,restore_rpc(x,{verb=.Challenge}).result==.Busy)
	x.now=x.base.room.service.coordinator.quarantine_until+100
	// Newer process after a lost/expired grant still uses the exact persisted old
	// source Point; it cannot invent a checkpoint in the unplayed grant epoch.
	auth.rpc_client_destroy(&x.rpc);x.lease={}
	assert(auth.lease_init(&x.lease,b.record.owner,44,55,{x,protocol_clock},false)==.None)
	assert(auth.rpc_client_init(&x.rpc,&x.lease,b.enrollments[0].key,auth.Nonce{0=100},tr.memory_transport(&x.endpoints[1])))
	reply:=restore_rpc(x,{verb=.Challenge});assert(reply.result==.None)
	assert(restore_rpc(x,{verb=.Rebind,challenge=reply.challenge,incarnation=reply.registration_identity.incarnation}).result==.None)
	assert(ck.client_open(&x.client,x.rpc.key,{x,protocol_clock},tr.memory_transport(&x.endpoints[1])))
	auth.prepared_destroy(&prepared);publication=restore_download(x,&prepared)
	assert(ck.client_restore(&x.client,&x.lease,publication,&prepared)==.None);protocol_finish(x)
	testing.expect(t,x.client.phase==.Complete && x.lease.view.epoch==3 && x.lease.identity.incarnation==3 && x.lease.view.recovered==point)
}

@(test)
rejected_restore_request_cannot_become_a_grant_when_replayed_after_expiry :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/restore-rejected-replay.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	_,error:=db.checkpoint_publish(&x.base.store,x.base.room.bundle.record,0,point,bytes,f.model());assert(error==.None)
	prepared:auth.Prepared;defer auth.prepared_destroy(&prepared);publication:=restore_download(x,&prepared)
	assert(ck.client_restore(&x.client,&x.lease,publication,&prepared)==.None);protocol_finish(x)
	assert(x.client.reply.recovery_result==.Busy)
	revision:=x.base.room.bundle.record.revision;x.now=2500
	assert(ck.server_receive(&x.server,2,x.client.txb[:x.client.count]))
	reply:ck.Reply;n:=sc.HEADER_BYTES+x.server.codecs.reply.wire_size
	_,report:=sc.unpack(&x.server.codecs.reply,&reply,x.server.txb[:n],{kind=ck.REPLY_KIND,epoch=u64(ck.VERSION),content=55})
	testing.expect(t,report.error==.None && reply.replayed && reply.recovery_result==.Busy && reply.view.remaining_ms==0)
	testing.expect(t,x.base.room.bundle.record.revision==revision && x.base.room.bundle.record.epoch==1)
}

@(test)
enrolled_trusted_peer_without_saved_playable_reservation_cannot_restore_as_local_owner :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/restore-reservation.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	ticket,e1:=p.invite(&x.base.room,p.Secret{0=41},p.Secret{0=42},.Trusted_Peer);assert(e1==.None)
	_,e2:=p.join(&x.base.room,ticket,p.Secret{0=43},address());assert(e2==.None)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	_,error:=db.checkpoint_publish(&x.base.store,x.base.room.bundle.record,0,point,bytes,f.model());assert(error==.None)
	x.now=2500;restore_fresh_owner(x,1)
	prepared:auth.Prepared;defer auth.prepared_destroy(&prepared);publication:=restore_download(x,&prepared)
	before:=x.base.room.bundle.record
	assert(ck.client_restore(&x.client,&x.lease,publication,&prepared)==.None);protocol_finish(x)
	testing.expect(t,x.client.phase==.Failed && x.client.reply.recovery_result==.Denied && x.base.room.bundle.record==before)
}

Restore_Gate :: struct {base:tr.Transport,coordinator:^auth.Coordinator,drop:bool,dropped:u64}
restore_gate_wire :: proc(g:^Restore_Gate)->tr.Transport {
	return {user=g,
		send=proc(user:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {
			g:=cast(^Restore_Gate)user
			if g.drop && g.coordinator.record.epoch==2 && len(bytes)>32 {
				meta,_,report:=sc.inspect(bytes[:len(bytes)-32])
				if report.error==.None && meta.kind==ck.REPLY_KIND {g.dropped+=1;return .Sent}
			}
			return tr.send(&g.base,to,channel,bytes)
		},
		connected=proc(user:rawptr,peer:tr.Peer_Id)->bool{return tr.peer_connected(&(cast(^Restore_Gate)user).base,peer)},
		generation=proc(user:rawptr,peer:tr.Peer_Id)->u64{return tr.peer_generation(&(cast(^Restore_Gate)user).base,peer)}}
}
@(test)
lost_restore_grant_reply_retries_one_durable_epoch_and_frontier :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/restore-lost-grant.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	_,error:=db.checkpoint_publish(&x.base.store,x.base.room.bundle.record,0,point,bytes,f.model());assert(error==.None)
	x.now=2500;restore_fresh_owner(x)
	prepared:auth.Prepared;defer auth.prepared_destroy(&prepared);publication:=restore_download(x,&prepared)
	gate:=Restore_Gate{tr.memory_transport(&x.endpoints[0]),&x.base.room.service.coordinator,true,0};x.server.wire=restore_gate_wire(&gate)
	before:=x.base.room.bundle.record.revision
	assert(ck.client_restore(&x.client,&x.lease,publication,&prepared)==.None)
	for _ in 0..<100 {protocol_step(x);if gate.dropped>=2 {break}}
	testing.expect(t,gate.dropped>=2 && x.client.phase==.Requesting && x.base.room.bundle.record.epoch==2 && x.base.room.bundle.record.revision==before+1)
	gate.drop=false;protocol_finish(x)
	testing.expect(t,x.client.phase==.Complete && x.client.reply.replayed && x.base.room.bundle.record.revision==before+1 && auth.lease_live(&x.lease,2))
}

@(test)
restore_storage_guard_rejects_substituted_point_and_replaced_publication :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/restore-storage-guard.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	publication,error:=db.checkpoint_publish(&x.base.store,x.base.room.bundle.record,0,point,bytes,f.model());assert(error==.None)
	candidate:=x.base.room.service.coordinator;candidate.commit=proc(_:rawptr,_:u64,_:auth.Record)->bool{return true}
	assert(auth.coordinator_recover_published(&candidate,{1,1},1,2,point,2500)==.None)
	next:=x.base.room.bundle;next.record=candidate.record
	x.base.store.recovery_publication=&publication;defer {x.base.store.recovery_publication=nil}
	substituted:=next;substituted.record.recovered.archive.hash[0]~=1
	testing.expect(t,!db.commit(&x.base.store,x.base.room.bundle.record.revision,substituted) && x.base.store.error==.Conflict)
	second,new_bytes:=f.checkpoint(&x.base,2);defer delete(new_bytes)
	_,updated:=db.checkpoint_publish(&x.base.store,x.base.room.bundle.record,1,second,new_bytes,f.model());assert(updated==.None)
	testing.expect(t,!db.commit(&x.base.store,x.base.room.bundle.record.revision,next) && x.base.store.error==.Conflict)
	stored,found,loaded:=db.load(&x.base.store,44,55)
	testing.expect(t,found && loaded==.None && stored.record==x.base.room.bundle.record)
}
