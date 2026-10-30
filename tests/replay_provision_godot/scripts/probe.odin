//gd:extends Node
//gd:class ProvisionProbe
package provision_probe

import "core:fmt"
import "core:os"
import "core:strings"
import gd "godot:godot"
import "godot:gdext"
import auth "godot:replay/authority"
import p "godot:replay/provision"
import db "godot:replay/provision/sqlite"
import rec "godot:replay/recovery"
import rgd "godot:replay/godot"
import tr "godot:replay/transport"
import ck "godot:replay/provision/checkpoint"
import net "godot:replay/net"
import r "godot:replay"
import fixture "../shared/checkpoint_model"
import transportgd "godot:replay/godot/transport"

ADMIN :: p.Secret{0 = 41}
INVITE :: p.Secret{0 = 42}
CLAIM :: p.Secret{0 = 43}
ProvisionProbe :: struct {
	owner: gd.Node,
	server, resume, done, negative, enrollment_mode: bool,
	started: u64,
	phase: int,
	socket: transportgd.Websocket,
	wire: tr.Transport,
	tls: gd.Tls_Options,
	store: db.Store,
	hub: p.Hub,
	connection: rgd.Provision_Connection,
	creator, guest: p.Grant,
	lease: auth.Lease,
	rpc: auth.Rpc_Client,
	checkpoint_mode: bool,
	checkpoint_trace_phase: int,
	checkpoint_server: ck.Server,
	checkpoint_client: ck.Client,
	checkpoint_backend: db.Checkpoint_Backend(fixture.World,u8,u8,u8,1),
	checkpoint_game: net.Server(fixture.World,u8,u8,u8,1),
	checkpoint_prepared: auth.Prepared,
}
endpoint :: proc() -> auth.Endpoint {e, _ := auth.endpoint("127.0.0.1", 49731); return e}
unref :: proc(object: gd.Ref_Counted) {if object != nil && gd.ref_counted_unreference(object) {gdext.object_destroy(object)}}
tls_options :: proc(server: bool, cert_path: string) -> gd.Tls_Options {
	certificate := gd.new_x509_certificate(); gd.ref_counted_init_ref(certificate); defer unref(certificate)
	path := gd.new_string_odin(cert_path); defer gd.free_string(path)
	if gd.x509_certificate_load(certificate, path) != .Ok {return nil}
	if server {
		key := gd.new_crypto_key(); gd.ref_counted_init_ref(key); defer unref(key)
		key_path := gd.new_string_odin(gd.env_string("PROVISION_KEY", "")); defer gd.free_string(key_path)
		if gd.crypto_key_load(key, key_path, false) != .Ok {return nil}
		return gd.tls_options_server(key, certificate)
	}
	return gd.tls_options_client(certificate, gd.string_empty())
}
connect :: proc(self: ^ProvisionProbe) -> bool {
	name := self.negative && gd.env_string("PROVISION_NEGATIVE", "") == "hostname" ? "127.0.0.1" : "localhost"
	url := fmt.tprintf("wss://%s:%d", name, gd.env_int("PROVISION_PORT", 49740))
	if self.negative {return transportgd.websocket_join(&self.socket, url, tls = self.tls)}
	return rgd.provision_connect(&self.connection, url, tls = self.tls) == .None
}
provision_probe_ready :: proc(self: ^ProvisionProbe) {
	self.server = gd.env_string("PROVISION_ROLE", "client") == "server"
	self.enrollment_mode = gd.env_int("PROVISION_ENROLLMENT", 0) == 1
	self.checkpoint_mode = gd.env_int("PROVISION_CHECKPOINT", 0) == 1
	self.checkpoint_trace_phase=-1
	self.resume = gd.env_int("PROVISION_RESUME", 0) == 1
	self.negative = len(gd.env_string("PROVISION_NEGATIVE", "")) != 0
	self.started = gd.time_get_ticks_msec(gd.singleton_time())
	cert := gd.env_string("PROVISION_CERT", "")
	if self.negative && gd.env_string("PROVISION_NEGATIVE", "") == "trust" {cert = gd.env_string("PROVISION_WRONG_CERT", "")}
	plain := self.server && self.enrollment_mode && gd.env_int("PROVISION_PLAIN", 0) == 1
	if !plain {self.tls = tls_options(self.server, cert); if self.tls == nil {fail(self, "TLS options"); return}}
	if self.negative && gd.env_string("PROVISION_NEGATIVE", "") == "options" {
		unsafe := gd.tls_options_client_unsafe(nil); defer unref(unsafe)
		probe: transportgd.Websocket
		if transportgd.websocket_join(&probe, "wss://localhost:49740", tls = unsafe) || probe.ready ||
		   transportgd.websocket_host(&probe, 49740, tls = self.tls) || probe.ready {fail(self, "TLS option guards"); return}
		gd.print_str("PROVISION_TLS_REJECT_OK"); self.done = true; gd.scene_tree_quit(gd.get_tree(self.owner), 0); return
	}
	if self.server {
		if db.open(&self.store, gd.env_string("PROVISION_DB", ""), !self.resume) != .None {fail(self, "store"); return}
		existing: [2]p.Bundle
		count, err := db.load_all(&self.store, 55, existing[:])
		if err != .None {fail(self, "inventory"); return}
		if !transportgd.websocket_host(&self.socket, u16(gd.env_int("PROVISION_PORT", 49740)), tls = self.tls) {fail(self, "TLS listen"); return}
		self.wire = transportgd.websocket_transport(&self.socket)
		cfg := p.HUB_CONFIG; cfg.content, cfg.rooms = 55, 2
		if p.hub_open(&self.hub, cfg, existing[:count], db.commit, &self.store, auth.native_clock(), self.wire) != .None {fail(self, "hub"); return}
		gd.print_str(fmt.tprintf("PROVISION_TLS_SERVER_READY rooms=%d", count))
	} else {
		if !connect(self) {fail(self, "TLS connect"); return}
		self.wire = self.negative ? transportgd.websocket_transport(&self.socket) : self.connection.client.wire
	}
}
request :: proc(self: ^ProvisionProbe, verb: p.Verb) {
	q := p.Request{version = p.PROTOCOL, verb = verb, room = 44, content = 55, claim = ADMIN}
	switch verb {
	case .Create: q.endpoint = endpoint()
	case .Invite: q.ticket, q.role, q.uses = INVITE, .Trusted_Peer, 1
	case .Join: q.claim, q.ticket, q.endpoint = CLAIM, INVITE, endpoint()
	case .Revoke: q.ticket = INVITE
	}
	if rgd.provision_request(&self.connection, q) != .None {fail(self, "request"); return}
}
fingerprint :: proc(g: p.Grant) -> string {
	bytes: [48]u8; g := g; copy(bytes[:32], g.key[:]); copy(bytes[32:], g.token[:])
	return fmt.aprintf("%x", rec.hash(bytes[:]))
}
finish_client :: proc(self: ^ProvisionProbe) {
	a, b := fingerprint(self.creator), fingerprint(self.guest); defer delete(a); defer delete(b)
	value := fmt.aprintf("%s\n%s\n", a, b); defer delete(value)
	path := gd.env_string("PROVISION_FINGERPRINT", "")
	if self.resume {
		bytes, ok := os.read_entire_file(path, context.allocator); defer delete(bytes)
		if ok != nil || string(bytes) != value {fail(self, "fresh-process credentials changed"); return}
	} else if os.write_entire_file(path, value) != nil {fail(self, "fingerprint write"); return}
	if os.write_entire_file(gd.env_string("PROVISION_DONE", ""), "done") != nil {fail(self, "done write"); return}
	gd.print_str(fmt.tprintf("PROVISION_TLS_CLIENT_OK resume=%t member=2 trusted=true stable_credentials=true", self.resume))
	self.done = true; gd.scene_tree_quit(gd.get_tree(self.owner), 0)
}
provision_probe_process :: proc(self: ^ProvisionProbe, dt: f64) {
	if self.done {return}
	if self.checkpoint_mode && !self.server && self.phase!=self.checkpoint_trace_phase {gd.print_str(fmt.tprintf("PROVISION_CHECKPOINT_PHASE %d",self.phase));self.checkpoint_trace_phase=self.phase}
	elapsed := gd.time_get_ticks_msec(gd.singleton_time()) - self.started
	if elapsed > (self.enrollment_mode ? u64(120000) : u64(20000)) {fail(self, "timeout"); return}
	if self.server {
		tr.poll(&self.wire); buffer: [tr.MAX_PACKET_BYTES]u8
		for _ in 0 ..< 32 {
			packet := transportgd.websocket_receive(&self.socket, buffer[:]); if packet.state != .Received {break}
			if packet.text {continue}
			if !ck.server_receive(&self.checkpoint_server,packet.from,buffer[:packet.count]) && !p.hub_receive(&self.hub, packet.from, buffer[:packet.count]) {p.hub_control_receive(&self.hub, packet.from, buffer[:packet.count])}
		}
		if self.checkpoint_mode {
			room:=p.hub_room(&self.hub,44)
			if room!=nil && !self.checkpoint_server.ready {
				self.checkpoint_backend={store=&self.store,model=fixture.model()}
				if !ck.server_open(&self.checkpoint_server,&room.service,db.checkpoint_backend(&self.checkpoint_backend),self.wire) {fail(self,"checkpoint server");return}
			}
			if self.checkpoint_server.ready {ck.server_update(&self.checkpoint_server)}
		}
		done := gd.new_string_odin(gd.env_string("PROVISION_DONE", "")); defer gd.free_string(done)
		if gd.file_access_file_exists(done) && self.phase == 0 {
			if self.enrollment_mode {
				rooms, members := 0, 0
				for room in self.hub.rooms {if room != nil {rooms += 1; for member in room.bundle.record.members {if member.enabled {members += 1}}}}
				gd.print_str(fmt.tprintf("ENROLLMENT_SERVER_OK rooms=%d members=%d", rooms, members))
				self.done = true; gd.scene_tree_quit(gd.get_tree(self.owner), 0); return
			}
			room := p.hub_room(&self.hub, 44)
			if room == nil || room.bundle.record.epoch != 1 || room.bundle.record.members[1].identity.member != 2 || room.bundle.invites[0].remaining != 0 {fail(self, "final room"); return}
			if self.checkpoint_mode {
				saved,found,error:=db.checkpoint_load(&self.store,44,55,fixture.model());defer db.stored_checkpoint_destroy(&saved)
				if !found || error!=.None || saved.publication.revision!=1 || saved.publication.point.archive.tick!=1 {fail(self,"durable checkpoint");return}
				gd.print_str(fmt.tprintf("PROVISION_CHECKPOINT_SERVER_OK resume=%t publication=1 tick=1",self.resume))
			}
			gd.print_str(fmt.tprintf("PROVISION_TLS_SERVER_OK resume=%t epoch=1 generation=%d members=2 invite_remaining=0", self.resume, room.bundle.record.coordinator_generation))
			self.phase = 1
			if self.resume {self.done = true; gd.scene_tree_quit(gd.get_tree(self.owner), 0)}
		}
		return
	}
	if self.negative {
		tr.poll(&self.wire)
		if tr.status(&self.wire) == .Connected {fail(self, "untrusted TLS accepted"); return}
		if tr.status(&self.wire) == .Disconnected && elapsed > 100 {
			gd.print_str("PROVISION_TLS_REJECT_OK"); self.done = true; gd.scene_tree_quit(gd.get_tree(self.owner), 0)
		}
		return
	}
	if self.phase>=10 {checkpoint_frame(self);return}
	if self.phase < 4 || self.phase >= 7 {
		if rgd.provision_frame(&self.connection) != .None {fail(self, "provision pump"); return}
		if self.phase == 0 && tr.status(&self.wire) == .Connected {request(self, .Create); self.phase = 1; return}
		if !self.connection.client.complete {return}
		reply := self.connection.client.reply; self.connection.client.complete = false
		if reply.result != .None {fail(self, fmt.tprintf("provision result %v", reply.result)); return}
		switch self.phase {
		case 1: self.creator = reply.grant; request(self, .Invite); self.phase = 2
		case 2: request(self, .Join); self.phase = 3
		case 3:
			self.guest = reply.grant
			if !self.guest.can_host || self.guest.identity.member != 2 {fail(self, "guest permissions"); return}
			actor := self.resume ? self.guest : self.creator
			if auth.lease_init(&self.lease, actor.identity, 44, 55, auth.native_clock(), !self.resume) != .None {fail(self, "lease"); return}
			nonce, ok := auth.rpc_nonce()
			if !ok || !auth.rpc_client_init(&self.rpc, &self.lease, actor.key, nonce, self.wire) {fail(self, "RPC init"); return}
			if auth.rpc_begin(&self.rpc, {verb = self.resume ? .Challenge : .Start}) != .None {fail(self, "start"); return}
			self.phase = 4
		case 7:
			if reply.grant != self.creator {fail(self, "creator retry changed"); return}
			request(self, .Join); self.phase = 8
		case 8:
			if reply.grant != self.guest {fail(self, "join retry changed"); return}
			finish_client(self)
		case: fail(self, "provision phase")
		}
		return
	}
	if auth.rpc_client_pump(&self.rpc) != .None {fail(self, "RPC pump"); return}
	if reply, done := auth.rpc_completed(&self.rpc); done {
		if reply.result != .None {fail(self, fmt.tprintf("RPC result %v", reply.result)); return}
		if reply.view.epoch != 1 {fail(self, "epoch"); return}
		if self.phase == 4 && !self.resume {
			if auth.rpc_begin(&self.rpc, {verb = .Nominate, epoch = 1, successor = self.guest.identity, binding = 9}) != .None {fail(self, "nominate"); return}
			self.phase = 5; return
		}
		if self.checkpoint_mode {
			if self.resume && self.phase==4 {
				if auth.rpc_begin(&self.rpc,{verb=.Rebind,challenge=reply.challenge,incarnation=reply.registration_identity.incarnation})!=.None {fail(self,"checkpoint rebind");return}
				self.phase=6;return
			}
			if self.resume {self.guest.identity=self.lease.identity}
			checkpoint_start(self);return
		}
		auth.rpc_client_destroy(&self.rpc)
		transportgd.websocket_close(&self.connection.socket)
		request(self, .Create); self.phase = 7
	}
}
fail :: proc(self: ^ProvisionProbe, reason: string) {gd.print_str(fmt.tprintf("PROVISION_TLS_FAIL %s", reason)); self.done = true; gd.scene_tree_quit(gd.get_tree(self.owner), 1)}
provision_probe_exit_tree :: proc(self: ^ProvisionProbe) {
	ck.client_close(&self.checkpoint_client);ck.server_close(&self.checkpoint_server)
	net.server_destroy(&self.checkpoint_game);auth.prepared_destroy(&self.checkpoint_prepared)
	auth.rpc_client_destroy(&self.rpc); rgd.provision_disconnect(&self.connection); p.hub_close(&self.hub)
	transportgd.websocket_close(&self.socket); db.close(&self.store); unref(self.tls)
}

checkpoint_start :: proc(self:^ProvisionProbe) {
	if !ck.client_open(&self.checkpoint_client,self.rpc.key,auth.native_clock(),self.wire) {fail(self,"checkpoint client");return}
	// Build the fixture contract from the same deployment model/configuration.
	cfg:=net.DEFAULT_CONFIG;cfg.content=55;cfg.require_permit=true
	if net.server_init(&self.checkpoint_game,r.Frame(fixture.World){state={value=7}},fixture.model(),{},cfg,local_seat=1,permit=auth.lease_permit(&self.lease))!=.None {fail(self,"checkpoint model");return}
	q:=ck.Request{version=ck.VERSION,verb=self.resume ? .Download : .Upload,room=44,content=55,sequence=1,generation=self.lease.view.coordinator_generation,
		identity=self.lease.identity,nonce=self.rpc.nonce,revision=self.resume ? u64(1) : u64(0),contract=self.checkpoint_game.contract}
	if !self.resume {
		if net.server_set_local_token(&self.checkpoint_game,self.creator.token)!=.None {fail(self,"checkpoint local token");return}
		net.server_local(&self.checkpoint_game,1)
		if net.server_step(&self.checkpoint_game)!=.None || auth.prepared_capture(&self.checkpoint_prepared,&self.checkpoint_game,44,9)!=.None {fail(self,"checkpoint capture");return}
		q.point=self.checkpoint_prepared.point
	}
	if ck.client_begin(&self.checkpoint_client,q,self.checkpoint_prepared.bytes)!=.None {fail(self,"checkpoint begin");return}
	self.phase=10
}
checkpoint_frame :: proc(self:^ProvisionProbe) {
	tr.poll(&self.wire);buffer:[tr.MAX_PACKET_BYTES]u8
	for _ in 0..<32 {packet:=tr.receive(&self.wire,buffer[:]);if packet.state!=.Received {break};ck.client_receive(&self.checkpoint_client,packet.from,buffer[:packet.count])}
	if ck.client_update(&self.checkpoint_client)!=.None || self.checkpoint_client.phase==.Failed {fail(self,fmt.tprintf("checkpoint transfer %v",self.checkpoint_client.error));return}
	if self.checkpoint_client.phase!=.Complete {return}
	if !self.resume && self.phase==10 {
		gd.print_str("PROVISION_CHECKPOINT_UPLOAD_OK publication=1 tick=1")
		q:=self.checkpoint_client.lane.request;q.verb,q.sequence,q.revision,q.point=.Download,2,1,{}
		if ck.client_begin(&self.checkpoint_client,q)!=.None {fail(self,"checkpoint download");return}
		self.phase=11;return
	}
	cp:net.Checkpoint(fixture.World,u8,u8,1);defer net.checkpoint_destroy(&cp)
	if ck.client_decode(&self.checkpoint_client,&cp,fixture.model())!=.None || cp.frame.state.value!=8 || cp.frame.tick!=1 || cp.header.epoch!=1 {fail(self,"downloaded checkpoint");return}
	if self.resume && self.lease.view.remaining_ms!=0 {fail(self,"download granted authority");return}
	gd.print_str(fmt.tprintf("PROVISION_CHECKPOINT_DOWNLOAD_OK resume=%t publication=1 tick=1 value=8 incarnation=%d remaining_ms=%d",self.resume,self.lease.identity.incarnation,self.lease.view.remaining_ms))
	ck.client_close(&self.checkpoint_client);auth.rpc_client_destroy(&self.rpc)
	transportgd.websocket_close(&self.connection.socket);request(self,.Create);self.phase=7
}
