//gd:extends Node
//gd:class RoomCheckpointProbe
package room_checkpoint_probe

import "core:fmt"
import "core:os"
import gd "godot:godot"
import "godot:gdext"
import auth "godot:replay/authority"
import p "godot:replay/provision"
import ck "godot:replay/provision/checkpoint"
import net "godot:replay/net"
import r "godot:replay"
import tf "godot:replay/transfer"
import rgd "godot:replay/godot"
import tr "godot:replay/transport"
import cave "godot:examples/replay_cavecrawl/shared/cave"
import cave_owned "godot:examples/replay_cavecrawl/shared/owner_cave"
import pitch "godot:examples/replay_speedball/shared/pitch"
import scrapyard "godot:examples/replay_scrapyard/shared/game"

RoomCheckpointProbe :: struct {
	owner:gd.Node,
	content:u64,
	phase:int,
	resume,done:bool,
	restore_mode:bool,
	started,last_renew:u64,
	restore_delay_ms,restore_send_at,restore_deferred:u64,
	restore_refresh_sequence:u64,
	tls:gd.Tls_Options,
	connection:rgd.Provision_Connection,
	wire:tr.Transport,
	creator,guest:p.Grant,
	lease:auth.Lease,
	rpc:auth.Rpc_Client,
	client:ck.Client,
	prepared:auth.Prepared,
	contract:u64,
}
unref :: proc(o:gd.Ref_Counted) {if o!=nil && gd.ref_counted_unreference(o) {gdext.object_destroy(o)}}
room_checkpoint_probe_ready :: proc(self:^RoomCheckpointProbe) {
	self.resume=gd.env_int("CHECKPOINT_RESUME",0)==1
	self.restore_mode=gd.env_int("CHECKPOINT_RESTORE",0)==1
	delay:=gd.env_int("CHECKPOINT_RESTORE_DELAY_MS",0)
	if delay<0 || delay>5000 {fail(self,"restore delay outside fixture bounds");return}
	self.restore_delay_ms=u64(delay)
	switch gd.env_string("CHECKPOINT_GAME","") {case "cavecrawl":self.content=cave.CONTENT;case "cavecrawl-owned":self.content=cave_owned.CONTENT;case "speedball":self.content=pitch.CONTENT;case "scrapyard":self.content=scrapyard.CONTENT}
	if self.content==0 {fail(self,"game selection");return}
	self.started=gd.time_get_ticks_msec(gd.singleton_time())
	cert:=gd.new_x509_certificate();gd.ref_counted_init_ref(cert);defer unref(cert)
	path:=gd.new_string_odin(gd.env_string("CHECKPOINT_CERT",""));defer gd.free_string(path)
	if gd.x509_certificate_load(cert,path)!=.Ok {fail(self,"certificate");return}
	self.tls=gd.tls_options_client(cert,gd.string_empty())
	if rgd.provision_connect(&self.connection,fmt.tprintf("wss://localhost:%d",gd.env_int("CHECKPOINT_PORT",49740)),tls=self.tls)!=.None {fail(self,"connect");return}
	self.wire=self.connection.client.wire
}
request :: proc(self:^RoomCheckpointProbe,verb:p.Verb) {
	endpoint,_:=auth.endpoint("127.0.0.1",49731)
	q:=p.Request{version=p.PROTOCOL,verb=verb,room=44,content=self.content,claim=p.Secret{0=41}}
	switch verb {case .Create:q.endpoint=endpoint;case .Invite:q.ticket,q.role,q.uses=p.Secret{0=42},.Trusted_Peer,1;case .Join:q.claim,q.ticket,q.endpoint=p.Secret{0=43},p.Secret{0=42},endpoint;case .Revoke:fail(self,"unexpected revoke");return}
	if rgd.provision_request(&self.connection,q)!=.None {fail(self,"provision request");return}
}
room_checkpoint_probe_process :: proc(self:^RoomCheckpointProbe,dt:f64) {
	if self.done {return}
	now:=gd.time_get_ticks_msec(gd.singleton_time())
	if now-self.started>60000 {fail(self,fmt.tprintf("timeout phase=%d",self.phase));return}
	if self.phase<4 {
		if rgd.provision_frame(&self.connection)!=.None {fail(self,"provision frame");return}
		if self.phase==0 && tr.status(&self.wire)==.Connected {request(self,.Create);self.phase=1;return}
		if !self.connection.client.complete {return}
		reply:=self.connection.client.reply;self.connection.client.complete=false
		if reply.result!=.None {fail(self,fmt.tprintf("provision %v",reply.result));return}
		switch self.phase {
		case 1:self.creator=reply.grant;request(self,.Invite);self.phase=2
		case 2:request(self,.Join);self.phase=3
		case 3:
			self.guest=reply.grant;actor:=self.resume && !self.restore_mode ? self.guest : self.creator
			if auth.lease_init(&self.lease,actor.identity,44,self.content,auth.native_clock(),!self.resume)!=.None {fail(self,"lease");return}
			nonce,valid:=auth.rpc_nonce()
			if !valid || !auth.rpc_client_init(&self.rpc,&self.lease,actor.key,nonce,self.wire) {fail(self,"RPC init");return}
			// Receive is owned by the multiplexer below. RPC pump only sends and
			// advances its clock, so checkpoint packets cannot be drained by it.
			self.rpc.wire.receive,self.rpc.wire.poll=nil,nil
			if auth.rpc_begin(&self.rpc,{verb=self.resume ? .Challenge : .Start})!=.None {fail(self,"authority begin");return}
			self.phase=4
		}
		return
	}
	tr.poll(&self.wire);buffer:[tr.MAX_PACKET_BYTES]u8
	for _ in 0..<32 {
		packet:=tr.receive(&self.wire,buffer[:]);if packet.state!=.Received {break}
		if !ck.client_receive(&self.client,packet.from,buffer[:packet.count]) {auth.rpc_client_receive(&self.rpc,packet.from,buffer[:packet.count])}
	}
	if auth.rpc_client_pump(&self.rpc)!=.None {fail(self,"RPC pump");return}
	if self.phase==4 || self.phase==5 {
		reply,complete:=auth.rpc_completed(&self.rpc);if !complete {return}
		if reply.result==.Busy && self.resume && self.restore_mode {
			if now-self.last_renew>=150 {auth.rpc_begin(&self.rpc,{verb=.Challenge});self.phase=4;self.last_renew=now}
			return
		}
		if reply.result!=.None {fail(self,fmt.tprintf("authority %v",reply.result));return}
		if self.resume && self.phase==4 {
			if auth.rpc_begin(&self.rpc,{verb=.Rebind,incarnation=reply.registration_identity.incarnation,challenge=reply.challenge})!=.None {fail(self,"rebind");return}
			self.phase=5;return
		}
		if !begin(self) {return};self.phase=10;self.last_renew=now
	}
	if !self.resume && !self.rpc.pending && now-self.last_renew>=500 {
		if auth.rpc_begin(&self.rpc,{verb=.Renew,epoch=1,tick=1})!=.None {fail(self,"renew begin");return};self.last_renew=now
	}
	if ck.client_update(&self.client)!=.None || self.client.phase==.Failed {fail(self,fmt.tprintf("checkpoint %v",self.client.error));return}
	if self.client.phase!=.Complete {return}
	if self.phase==20 {
		gd.print_str(fmt.tprintf("ROOM_CHECKPOINT_RESTORE_GRANT epoch=%d live=%v remaining=%d request_age=%d",self.lease.view.epoch,auth.lease_live(&self.lease,self.lease.view.epoch),self.lease.deadline>self.lease.now ? self.lease.deadline-self.lease.now : 0,self.lease.now-self.lease.sent_at))
		// Match Room's install protocol: the expensive Restore response is not
		// the last lease refresh before validating/allocating the runtime.
		if auth.rpc_begin(&self.rpc,{verb=.Renew,epoch=self.lease.view.epoch,tick=self.prepared.point.archive.tick})!=.None {fail(self,"restore renewal begin");return}
		self.restore_refresh_sequence=self.rpc.request.sequence;self.phase=21;return
	}
	if self.phase==21 {
		reply,complete:=auth.rpc_completed(&self.rpc);if !complete {return}
		if reply.result!=.None || self.rpc.request.sequence!=self.restore_refresh_sequence || self.rpc.request.command.verb!=.Renew || self.rpc.request.command.epoch!=2 || !auth.lease_live(&self.lease,2) {fail(self,"restore renewal grant");return}
		gd.print_str(fmt.tprintf("ROOM_CHECKPOINT_RESTORE_REFRESH epoch=%d remaining=%d",self.lease.view.epoch,self.lease.deadline-self.lease.now))
		valid:=false
		switch self.content {case cave.CONTENT:valid=continue_restore(self,cave.model());case cave_owned.CONTENT:valid=continue_restore(self,cave_owned.model());case pitch.CONTENT:valid=continue_restore(self,pitch.model());case scrapyard.CONTENT:valid=continue_restore(self,scrapyard.model())}
		if !valid {fail(self,"granted restore continuation");return}
		self.done=true;gd.scene_tree_quit(gd.get_tree(self.owner),0);return
	}
	if !self.resume && self.phase==10 {
		gd.print_str(fmt.tprintf("ROOM_CHECKPOINT_UPLOAD_OK game=%s bytes=%d revision=%d tick=1",gd.env_string("CHECKPOINT_GAME",""),len(self.prepared.bytes),self.client.reply.publication.revision))
		q:=self.client.lane.request;q.verb,q.sequence,q.revision,q.point=.Download,2,1,{}
		if ck.client_begin(&self.client,q)!=.None {fail(self,"download begin");return};self.phase=11;return
	}
	valid:=false
	switch self.content {case cave.CONTENT:valid=validate(self,cave.model());case cave_owned.CONTENT:valid=validate(self,cave_owned.model());case pitch.CONTENT:valid=validate(self,pitch.model());case scrapyard.CONTENT:valid=validate(self,scrapyard.model())}
	if !valid {fail(self,"typed download validation");return}
	if self.resume && (self.lease.identity.incarnation!=2 || self.lease.view.remaining_ms!=0 || self.lease.view.epoch!=1) {fail(self,"fresh reader authority");return}
	expected,read_error:=os.read_entire_file(gd.env_string("CHECKPOINT_EXPECTED",""),context.allocator);defer delete(expected)
	hash:=fmt.tprintf("%x",tf.hash(self.client.saved.bytes))
	if read_error!=nil || string(expected)!=hash {fail(self,"saved archive changed across download/restart");return}
	gd.print_str(fmt.tprintf("ROOM_CHECKPOINT_DOWNLOAD_OK game=%s resume=%t revision=1 tick=1 bytes=%d incarnation=%d remaining_ms=%d hash=%s",gd.env_string("CHECKPOINT_GAME",""),self.resume,len(self.client.saved.bytes),self.lease.identity.incarnation,self.lease.view.remaining_ms,hash))
	if self.resume && self.restore_mode {
		valid:=false
		switch self.content {case cave.CONTENT:valid=ck.client_prepare(&self.client,&self.prepared,cave.model())==.None;case cave_owned.CONTENT:valid=ck.client_prepare(&self.client,&self.prepared,cave_owned.model())==.None;case pitch.CONTENT:valid=ck.client_prepare(&self.client,&self.prepared,pitch.model())==.None;case scrapyard.CONTENT:valid=ck.client_prepare(&self.client,&self.prepared,scrapyard.model())==.None}
		if self.restore_delay_ms>0 {
			self.restore_send_at=gd.time_get_ticks_msec(gd.singleton_time())+self.restore_delay_ms
			self.client.lane.wire={user=self,send=delayed_restore_send,
			 connected=proc(user:rawptr,peer:tr.Peer_Id)->bool {return tr.peer_connected(&(cast(^RoomCheckpointProbe)user).wire,peer)}}
		}
		if !valid || ck.client_restore(&self.client,&self.lease,self.client.saved.publication,&self.prepared)!=.None {fail(self,"restore request");return}
		self.phase=20;return
	}
	self.done=true;gd.scene_tree_quit(gd.get_tree(self.owner),0)
}

// Test-only backpressure before the first Restore request reaches the service.
// It never changes a lease timestamp or the coordinator/system clock.
delayed_restore_send :: proc(user:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {
	self:=cast(^RoomCheckpointProbe)user
	now:=gd.time_get_ticks_msec(gd.singleton_time())
	if now<self.restore_send_at {self.restore_deferred+=1;return .Backpressure}
	if self.restore_send_at!=0 {
		gd.print_str(fmt.tprintf("ROOM_CHECKPOINT_RESTORE_DELAY ms=%d deferred=%d",self.restore_delay_ms,self.restore_deferred));self.restore_send_at=0
	}
	return tr.send(&self.wire,to,channel,bytes)
}
begin :: proc(self:^RoomCheckpointProbe)->bool {
	if !ck.client_open(&self.client,self.rpc.key,auth.native_clock(),self.wire) {fail(self,"checkpoint client");return false}
	valid:=false
	switch self.content {
	case cave.CONTENT:valid=capture(self,cave.model(),cave.initial(staging=true),cave.HZ)
	case cave_owned.CONTENT:valid=capture(self,cave_owned.model(),cave_owned.initial(staging=true),cave_owned.HZ)
	case pitch.CONTENT:valid=capture(self,pitch.model(),pitch.initial(manual_start=true),pitch.HZ)
	case scrapyard.CONTENT:valid=capture(self,scrapyard.model(),scrapyard.initial(),scrapyard.HZ)
	}
	if !valid {fail(self,"game checkpoint capture");return false}
	q:=ck.Request{version=ck.VERSION,verb=self.resume ? .Download : .Upload,room=44,content=self.content,sequence=1,generation=self.lease.view.coordinator_generation,
		identity=self.lease.identity,nonce=self.rpc.nonce,revision=self.resume ? u64(1) : u64(0),contract=self.contract,point=self.prepared.point}
	if ck.client_begin(&self.client,q,self.prepared.bytes)!=.None {fail(self,"checkpoint begin");return false}
	return true
}
capture :: proc(self:^RoomCheckpointProbe,model:net.Model($S,$C,$A,$E,$N),world:S,hz:u32)->bool {
	server:=new(net.Server(S,C,A,E,N));defer free(server);defer net.server_destroy(server)
	cfg:=net.DEFAULT_CONFIG;cfg.content,cfg.hz,cfg.require_permit=self.content,hz,true
	if net.server_init(server,r.Frame(S){state=world},model,{},cfg,local_seat=1,permit=auth.lease_permit(&self.lease))!=.None {return false}
	self.contract=server.contract;if self.resume {return true}
	if net.server_set_local_token(server,self.creator.token)!=.None {return false}
	net.server_local(server,C{})
	if net.server_step(server)!=.None || auth.prepared_capture(&self.prepared,server,44,7)!=.None {return false}
	return os.write_entire_file(gd.env_string("CHECKPOINT_EXPECTED",""),fmt.tprintf("%x",tf.hash(self.prepared.bytes)))==nil
}
validate :: proc(self:^RoomCheckpointProbe,model:net.Model($S,$C,$A,$E,$N))->bool {
	cp:=new(net.Checkpoint(S,C,A,N));defer free(cp);defer net.checkpoint_destroy(cp)
	return ck.client_decode(&self.client,cp,model)==.None && cp.frame.tick==1 && cp.header.epoch==1 && cp.settings.require_permit && cp.header.content==self.content
}
continue_restore :: proc(self:^RoomCheckpointProbe,model:net.Model($S,$C,$A,$E,$N))->bool {
	if self.lease.view.epoch!=2 || self.lease.identity.incarnation!=2 || !self.lease.require_owner || !auth.lease_live(&self.lease,2) {
		gd.print_str(fmt.tprintf("ROOM_CHECKPOINT_RESTORE_DETAIL stage=lease epoch=%d incarnation=%d require_owner=%v live=%v",self.lease.view.epoch,self.lease.identity.incarnation,self.lease.require_owner,auth.lease_live(&self.lease,2)));return false
	}
	server:=new(net.Server(S,C,A,E,N));defer free(server);defer net.server_destroy(server)
	if error:=auth.prepared_restore(&self.prepared,server,model,{},&self.lease,1,options={local_incarnation=self.lease.identity.incarnation});error!=.None {
		gd.print_str(fmt.tprintf("ROOM_CHECKPOINT_RESTORE_DETAIL stage=restore error=%v live=%v",error,auth.lease_live(&self.lease,2)));return false
	}
	for index in 0..<10 {net.server_local(server,C{});if error:=net.server_step(server);error!=.None {
		gd.print_str(fmt.tprintf("ROOM_CHECKPOINT_RESTORE_DETAIL stage=step index=%d error=%v frame=%v live=%v",index,error,server.frame_error,auth.lease_live(&self.lease,2)));return false
	}}
	frame,_:=r.current(&server.timeline)
	if frame.tick!=11 || server.peers[0].incarnation!=2 {return false}
	gd.print_str(fmt.tprintf("ROOM_CHECKPOINT_RESTORE_OK game=%s epoch=2 incarnation=2 tick=%d owner=%d",gd.env_string("CHECKPOINT_GAME",""),frame.tick,self.lease.view.owner.member))
	return true
}
fail :: proc(self:^RoomCheckpointProbe,reason:string) {gd.print_str(fmt.tprintf("ROOM_CHECKPOINT_FAIL %s",reason));self.done=true;gd.scene_tree_quit(gd.get_tree(self.owner),1)}
room_checkpoint_probe_exit_tree :: proc(self:^RoomCheckpointProbe) {
	ck.client_close(&self.client);auth.prepared_destroy(&self.prepared);auth.rpc_client_destroy(&self.rpc)
	rgd.provision_disconnect(&self.connection);unref(self.tls)
}
