package replay_provision_sqlite_test

import "core:fmt"
import "core:mem"
import "core:slice"
import "core:testing"
import auth "godot:replay/authority"
import ck "godot:replay/provision/checkpoint"
import db "godot:replay/provision/sqlite"
import p "godot:replay/provision"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tf "godot:replay/transfer"
import tr "godot:replay/transport"
import f "publication_fixture"
import a "godot:replay/assets"

Protocol_Fixture :: struct {
	base:f.Fixture,
	now:u64,
	memory:tr.Memory,
	endpoints:[2]tr.Memory_Endpoint,
	lease:auth.Lease,
	rpc:auth.Rpc_Client,
	backend:db.Checkpoint_Backend(f.World,u8,u8,u8,1),
	server:ck.Server,
	client:ck.Client,
	renew:bool,
}
protocol_clock :: proc(user:rawptr)->(u64,bool) {return (cast(^Protocol_Fixture)user).now,true}
protocol_open :: proc(x:^Protocol_Fixture,path:string,images:[2]a.Ref={}) {
	f.open(&x.base,path,images)
	tr.memory_init(&x.memory,cfg={2,128,tr.MAX_PACKET_BYTES,8192},faults={latency_ticks=1,retry_ticks=3})
	for &e,i in x.endpoints {tr.memory_open(&x.memory,&e,tr.Peer_Id(i+1))}
	w0,w1:=tr.memory_transport(&x.endpoints[0]),tr.memory_transport(&x.endpoints[1])
	x.base.room.service.clock={x,protocol_clock};x.base.room.service.wire=w0
	assert(auth.lease_init(&x.lease,{1,1},44,55,{x,protocol_clock},true)==.None)
	key:=x.base.room.bundle.enrollments[0].key
	assert(auth.rpc_client_init(&x.rpc,&x.lease,key,auth.Nonce{0=77},w1))
	assert(auth.rpc_begin(&x.rpc,{verb=.Query})==.None)
	for _ in 0..<30 {
		x.now+=10;tr.memory_advance(&x.memory,x.now/10)
		auth.rpc_client_pump(&x.rpc);auth.service_pump(&x.base.room.service)
		if !x.rpc.pending {break}
	}
	assert(!x.rpc.pending && x.rpc.reply.result==.None && x.base.room.service.active_peer[0]==2)
	x.backend={store=&x.base.store,model=f.model()}
	assert(ck.server_open(&x.server,&x.base.room.service,db.checkpoint_backend(&x.backend),w0,data_channel=.Unreliable))
	assert(ck.client_open(&x.client,key,{x,protocol_clock},w1,data_channel=.Unreliable))
}
protocol_close :: proc(x:^Protocol_Fixture) {
	ck.client_close(&x.client);ck.server_close(&x.server);auth.rpc_client_destroy(&x.rpc)
	for &e in x.endpoints {wire:=tr.memory_transport(&e);tr.close(&wire)}
	tr.memory_destroy(&x.memory);f.close(&x.base)
}
protocol_step :: proc(x:^Protocol_Fixture) {
	x.now+=10;tr.memory_advance(&x.memory,x.now/10)
	if x.renew && x.now%500==0 {
		c:=&x.base.room.service.coordinator
		assert(auth.coordinator_renew(c,c.record.owner,c.record.epoch,c.record.owner_request+1,1,x.now)==.None)
	}
	ck.client_update(&x.client);ck.server_update(&x.server)
	buffer:[tr.MAX_PACKET_BYTES]u8
	for i in 0..<2 {
		wire:=tr.memory_transport(&x.endpoints[i])
		for _ in 0..<32 {
			packet:=tr.receive(&wire,buffer[:]);if packet.state!=.Received {break}
			if i==0 {ck.server_receive(&x.server,packet.from,buffer[:packet.count])}
			else {ck.client_receive(&x.client,packet.from,buffer[:packet.count])}
		}
	}
}
protocol_finish :: proc(x:^Protocol_Fixture) {
 for _ in 0..<1000 {protocol_step(x);if x.client.phase==.Complete || x.client.phase==.Failed {return}}
	panic("checkpoint operation did not finish")
}
protocol_request :: proc(x:^Protocol_Fixture,verb:ck.Verb,sequence,revision:u64,point:auth.Point={})->ck.Request {
	return {version=ck.VERSION,verb=verb,room=44,content=55,sequence=sequence,generation=x.base.room.bundle.record.coordinator_generation,
		identity=x.lease.identity,nonce=x.rpc.nonce,revision=revision,contract=x.base.server.contract,point=point}
}

@(test)
authenticated_upload_download_uses_registered_rpc_and_owned_durable_bytes :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/protocol-roundtrip.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	before:=x.base.room.bundle.record
	assert(ck.client_begin(&x.client,protocol_request(x,.Upload,1,0,point),bytes)==.None);protocol_finish(x)
	testing.expect(t,x.client.phase==.Complete && x.client.reply.publication.revision==1 && x.server.published==1)
	testing.expect_value(t,x.base.room.bundle.record,before)
	assert(ck.client_begin(&x.client,protocol_request(x,.Download,2,1))==.None);protocol_finish(x)
	testing.expect(t,x.client.phase==.Complete && x.client.saved.ready && slice.equal(x.client.saved.bytes,bytes))
	cp:net.Checkpoint(f.World,u8,u8,1);defer net.checkpoint_destroy(&cp)
	testing.expect_value(t,ck.client_decode(&x.client,&cp,f.model()),net.Error.None)
	testing.expect(t,cp.frame.state.value==8 && cp.header.epoch==1)
	// Lost completion reply can be resolved by an exact new request after expiry.
	x.now=2100
	assert(ck.client_begin(&x.client,protocol_request(x,.Upload,3,0,point),bytes)==.None);protocol_finish(x)
	testing.expect(t,x.client.phase==.Complete && x.client.reply.publication.revision==1 && x.server.published==1)
}

@(test)
publication_rechecks_lease_after_partial_upload_and_never_commits_expired_host :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/protocol-expired.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	assert(ck.client_begin(&x.client,protocol_request(x,.Upload,1,0,point),bytes)==.None)
	for _ in 0..<20 {protocol_step(x);if x.server.receiver.active {break}}
	testing.expect(t,x.server.receiver.active && x.server.receiver.count==0)
	x.now=2100;protocol_finish(x)
	testing.expect(t,x.client.phase==.Failed && x.client.error==.Denied && x.server.published==0)
	value,found,error:=db.checkpoint_load(&x.base.store,44,55,f.model());defer db.stored_checkpoint_destroy(&value)
	testing.expect(t,!found && error==.None)
}

@(test)
unregistered_wrong_connection_nonce_identity_generation_and_mac_cannot_allocate :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/protocol-auth.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	q:=protocol_request(x,.Upload,1,0,point);packet:[ck.PACKET_BYTES]u8
	for kind in 0..<6 {
		bad:=q;peer:=tr.Peer_Id(2);key:=x.rpc.key
		switch kind {case 0:bad.nonce[0]+=1;case 1:bad.identity.incarnation+=1;case 2:bad.generation+=1;case 3:peer=3;case 4:key[0]+=1;case 5:x.base.room.service.active_peer[0]=0}
		n:=ck.request_pack(&x.client.codecs,bad,key,packet[:]);assert(n>0)
		testing.expect(t,!ck.server_receive(&x.server,peer,packet[:n]) && !x.server.active && !x.server.receiver.ready)
	}
	testing.expect_value(t,x.server.published,u64(0))
}

@(test)
client_supplied_contract_is_checked_before_storage_and_same_sequence_cannot_change_transfer :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/protocol-contract.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	q:=protocol_request(x,.Upload,1,0,point);q.contract+=1
	assert(ck.client_begin(&x.client,q,bytes)==.None)
	for _ in 0..<30 {protocol_step(x);if x.server.active {break}}
	before:=x.server.lane.transfer;bad:=q;bad.point.archive.hash[0]~=1
	packet:[ck.PACKET_BYTES]u8;n:=ck.request_pack(&x.client.codecs,bad,x.rpc.key,packet[:])
	testing.expect(t,ck.server_receive(&x.server,2,packet[:n]) && x.server.lane.transfer==before && x.server.lane.request==q)
	protocol_finish(x)
	testing.expect(t,x.client.phase==.Failed && x.client.error==.Schema)
	value,found,error:=db.checkpoint_load(&x.base.store,44,55,f.model());defer db.stored_checkpoint_destroy(&value)
	testing.expect(t,!found && error==.None)
}

@(test)
faulted_multichunk_roundtrip_and_lost_completion_retry_commit_once :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/protocol-faults.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x);x.renew=true
	assert(tr.memory_set_faults(&x.memory,{latency_ticks=3,jitter_ticks=4,loss_permyriad=2500,duplicate_permyriad=2500,retry_ticks=3}))
	point,bytes:=f.checkpoint(&x.base,4);defer delete(bytes)
	assert(ck.client_begin(&x.client,protocol_request(x,.Upload,1,0,point),bytes)==.None);protocol_finish(x)
	testing.expect(t,x.client.phase==.Complete && x.client.reply.publication.point==point && x.server.published==1)
	assert(ck.client_begin(&x.client,protocol_request(x,.Download,2,1))==.None);protocol_finish(x)
	testing.expect(t,x.client.phase==.Complete && slice.equal(x.client.saved.bytes,bytes))
	// Closing/reopening only the checkpoint endpoint loses its volatile receipt.
	// The RPC identity remains registered; the durable exact retry still resolves.
	ck.client_close(&x.client);ck.server_close(&x.server)
	assert(ck.server_open(&x.server,&x.base.room.service,db.checkpoint_backend(&x.backend),tr.memory_transport(&x.endpoints[0]),data_channel=.Unreliable))
	assert(ck.client_open(&x.client,x.rpc.key,{x,protocol_clock},tr.memory_transport(&x.endpoints[1]),data_channel=.Unreliable))
	assert(ck.client_begin(&x.client,protocol_request(x,.Upload,3,0,point),bytes)==.None);protocol_finish(x)
	testing.expect(t,x.client.phase==.Complete && x.client.reply.publication.revision==1 && x.server.published==0)
}

@(test)
revoked_download_and_reused_connection_cannot_continue_or_start_transfer :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/protocol-revocation.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	_,error:=db.checkpoint_publish(&x.base.store,x.base.room.bundle.record,0,point,bytes,f.model());assert(error==.None)
	q:=protocol_request(x,.Download,1,1);packet:[ck.PACKET_BYTES]u8
	original_generation:=x.server.wire.generation
	x.server.wire.generation=proc(_:rawptr,_:tr.Peer_Id)->u64{return 2}
	n:=ck.request_pack(&x.client.codecs,q,x.rpc.key,packet[:])
	testing.expect(t,!ck.server_receive(&x.server,2,packet[:n]) && !x.server.active)
	x.server.wire.generation=original_generation
	assert(ck.client_begin(&x.client,q)==.None)
	for _ in 0..<30 {protocol_step(x);if x.server.sender.phase==.Sending {break}}
	testing.expect(t,x.server.sender.phase==.Sending && !x.client.saved.ready)
	member:=x.base.room.bundle.record.members[0];member.trusted_authority=false
	assert(auth.coordinator_member(&x.base.room.service.coordinator,member,x.now)==.None)
	ck.server_update(&x.server)
	testing.expect(t,!x.server.active && !x.server.sender.ready && !x.server.receiver.ready)
	n=ck.request_pack(&x.client.codecs,q,x.rpc.key,packet[:])
	testing.expect(t,!ck.server_receive(&x.server,2,packet[:n]))
}

@(test)
competing_coordinator_commit_fences_in_progress_upload :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/protocol-cas.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	assert(ck.client_begin(&x.client,protocol_request(x,.Upload,1,0,point),bytes)==.None)
	for _ in 0..<30 {protocol_step(x);if x.server.receiver.active {break}}
	other:db.Store;defer db.close(&other);assert(db.open(&other,path)==.None)
	b,found,loaded:=db.load(&other,44,55);assert(found && loaded==.None)
	restarted:p.Room;defer p.close(&restarted);assert(p.open(&restarted,b,db.commit,&other,{x,protocol_clock})==.None)
	protocol_finish(x)
	testing.expect(t,x.client.phase==.Failed && x.client.error==.Stale && x.server.published==0)
	value,exists,error:=db.checkpoint_load(&other,44,55,f.model());defer db.stored_checkpoint_destroy(&value)
	testing.expect(t,!exists && error==.None)
}

@(test)
abandoned_upload_has_bounded_lifetime_and_old_transfer_packets_are_fenced :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/protocol-bounds.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	assert(ck.client_begin(&x.client,protocol_request(x,.Upload,1,0,point),bytes)==.None)
	for _ in 0..<30 {protocol_step(x);if x.server.receiver.active {break}}
	old:=x.client.lane.txb
	n:=sc.HEADER_BYTES+x.client.codecs.data.wire_size+32
	q:=protocol_request(x,.Upload,2,0,point);packet:[ck.PACKET_BYTES]u8
	count:=ck.request_pack(&x.client.codecs,q,x.rpc.key,packet[:])
	assert(ck.server_receive(&x.server,2,packet[:count]))
	testing.expect(t,x.server.lane.transfer==2 && x.server.receiver.count==0)
	testing.expect(t,!ck.server_receive(&x.server,2,old[:n]) && x.server.receiver.count==0)
	x.now+=tf.DEFAULT_CONFIG.timeout_ms
	testing.expect_value(t,ck.server_update(&x.server),ck.Error.Timeout)
	testing.expect(t,!x.server.active && !x.server.receiver.ready && len(x.server.receiver.bytes)==0)
}

Late_Backend :: struct {base:ck.Backend,fixture:^Protocol_Fixture}
@(test)
lease_expiring_during_backend_work_rolls_back_at_final_commit_guard :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/protocol-commit-guard.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	late:=Late_Backend{db.checkpoint_backend(&x.backend),x}
	x.server.backend={user=&late,
		load=proc(user:rawptr,room,content:u64,allocator:mem.Allocator)->(ck.Saved,bool,ck.Error) {
			b:=cast(^Late_Backend)user;return b.base.load(b.base.user,room,content,allocator)
		},
		publish=proc(user:rawptr,expected:auth.Record,revision,contract:u64,point:auth.Point,bytes:[]u8,guard:ck.Commit_Guard,payload:[]u8)->(ck.Publication,ck.Error) {
			b:=cast(^Late_Backend)user;b.fixture.now=2100
			return b.base.publish(b.base.user,expected,revision,contract,point,bytes,guard,payload)
		}}
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	assert(ck.client_begin(&x.client,protocol_request(x,.Upload,1,0,point),bytes)==.None);protocol_finish(x)
	testing.expect(t,x.client.phase==.Failed && x.client.error==.Denied && x.server.published==0 && !x.base.store.connection.transaction)
	value,found,error:=db.checkpoint_load(&x.base.store,44,55,f.model());defer db.stored_checkpoint_destroy(&value)
	testing.expect(t,!found && error==.None)
}

@(test)
registered_player_permission_cannot_read_checkpoint_metadata_or_bytes :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/protocol-player.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	point,bytes:=f.checkpoint(&x.base,1);defer delete(bytes)
	_,error:=db.checkpoint_publish(&x.base.store,x.base.room.bundle.record,0,point,bytes,f.model());assert(error==.None)
	member:=x.base.room.bundle.record.members[0];member.can_host=false;member.trusted_authority=false
	assert(auth.coordinator_member(&x.base.room.service.coordinator,member,x.now)==.None)
	for verb in ck.Verb {
		if verb==.Restore {continue}
		q:=protocol_request(x,verb,1,verb==.Download ? u64(1) : u64(0),verb==.Upload ? point : auth.Point{})
		packet:[ck.PACKET_BYTES]u8;n:=ck.request_pack(&x.client.codecs,q,x.rpc.key,packet[:]);assert(n>0)
		testing.expect(t,!ck.server_receive(&x.server,2,packet[:n]) && !x.server.active)
	}
}

@(test)
status_retry_reuses_one_authenticated_read_but_new_sequence_observes_new_publication :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/status-retry.sqlite3",DIRECTORY);defer delete(path)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path);defer protocol_close(x)
	first,root:=f.checkpoint(&x.base,1);defer delete(root)
	_,e1:=db.checkpoint_publish(&x.base.store,x.base.room.bundle.record,0,first,root,f.model());assert(e1==.None)
	assert(ck.client_begin(&x.client,protocol_request(x,.Status,1,0))==.None);protocol_finish(x)
	assert(x.client.reply.publication.revision==1)
	second,next:=f.checkpoint(&x.base,2);defer delete(next)
	_,e2:=db.checkpoint_publish(&x.base.store,x.base.room.bundle.record,1,second,next,f.model());assert(e2==.None)
	load:=x.server.backend.load
	x.server.backend.load=proc(_:rawptr,_:u64,_:u64,_:mem.Allocator)->(ck.Saved,bool,ck.Error){panic("status retry loaded storage")}
	testing.expect(t,ck.server_receive(&x.server,2,x.client.txb[:x.client.count]))
	x.server.backend.load=load
	assert(ck.client_begin(&x.client,protocol_request(x,.Status,2,0))==.None);protocol_finish(x)
	testing.expect(t,x.client.phase==.Complete && x.client.reply.publication.revision==2)
	member:=x.base.room.bundle.record.members[0];member.enabled=false;assert(auth.coordinator_member(&x.base.room.service.coordinator,member,x.now)==.None)
	testing.expect(t,!ck.server_receive(&x.server,2,x.client.txb[:x.client.count]))
}
