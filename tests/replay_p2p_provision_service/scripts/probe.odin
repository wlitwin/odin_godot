//gd:extends Node
//gd:class ReplayProvisionPeer
package p2p_provision_probe

import "core:fmt"
import "core:os"
import gd "godot:godot"
import "godot:gdext"
import auth "godot:replay/authority"
import adm "godot:replay/p2p/admission"
import pp "godot:replay/p2p/provision"
import db "godot:replay/p2p/provision/sqlite"
import p "godot:replay/provision"
import rec "godot:replay/recovery"
import rgd "godot:replay/godot"
import tr "godot:replay/transport"

ReplayProvisionPeer :: struct {
    owner:gd.Node,
    server,resume,done:bool,
    started:u64,
    phase:int,
    tls:gd.Tls_Options,
    socket:rgd.Websocket,
    wire:tr.Transport,
    store:db.Store,
    hub:pp.Hub,
    connection:rgd.Provision_Connection,
    grants:[3]p.Grant,
    lease:auth.Lease,
    rpc:auth.Rpc_Client,
}
endpoint :: proc()->auth.Endpoint {e,_:=auth.endpoint("127.0.0.1",49731);return e}
replay_provision_peer_ready :: proc(self:^ReplayProvisionPeer) {
    self.server=gd.env_string("RPP_ROLE","client")=="server"
    self.resume=gd.env_int("RPP_RESUME",0)==1
    self.started=gd.time_get_ticks_msec(gd.singleton_time())
    self.tls=tls_options(self.server,gd.env_string("RPP_CERT",""))
    if self.tls==nil {fail(self,"TLS options");return}
    if self.server {
        if db.open(&self.store,gd.env_string("RPP_DB",""),!self.resume)!=.None {fail(self,"store");return}
        existing:[2]pp.Bundle
        count,error:=db.load_all(&self.store,55,existing[:]);if error!=.None {fail(self,"inventory");return}
        if !rgd.websocket_host(&self.socket,u16(gd.env_int("RPP_PORT",49740)),tls=self.tls) {fail(self,"listen");return}
        self.wire=rgd.websocket_transport(&self.socket)
        cfg:=pp.HUB_CONFIG;cfg.content,cfg.players,cfg.rooms=55,3,2
        if pp.hub_open(&self.hub,cfg,existing[:count],db.commit,&self.store,auth.native_clock(),self.wire)!=.None {fail(self,"hub");return}
        gd.print_str(fmt.tprintf("P2P_PROVISION_SERVICE_READY rooms=%d",count))
    } else {
        if rgd.provision_connect(&self.connection,fmt.tprintf("wss://localhost:%d",gd.env_int("RPP_PORT",49740)),tls=self.tls)!=.None {fail(self,"connect");return}
        self.wire=self.connection.client.wire
    }
}
enroll :: proc(self:^ReplayProvisionPeer,phase:int) {
    q:=p.Request{version=p.PROTOCOL,room=871,content=55,claim={0=41}}
    switch phase {
    case 1:q.verb,q.endpoint=.Create,endpoint()
    case 2:q.verb,q.ticket,q.role,q.uses=.Invite,{0=42},.Player,2
    case 3,4:q.verb,q.ticket,q.claim,q.endpoint=.Join,{0=42},{0=u8(phase+40)},endpoint()
    }
    if rgd.provision_request(&self.connection,q)!=.None {fail(self,"enrollment request");return}
    self.phase=phase
}
replay_provision_peer_process :: proc(self:^ReplayProvisionPeer,dt:f64) {
    if self.done {return}
    if gd.time_get_ticks_msec(gd.singleton_time())-self.started>20000 {fail(self,"timeout");return}
    if self.server {
        tr.poll(&self.wire);buffer:[tr.MAX_PACKET_BYTES]u8
        for _ in 0..<32 {
            packet:=rgd.websocket_receive(&self.socket,buffer[:]);if packet.state!=.Received {break}
            if !packet.text && !pp.hub_receive(&self.hub,packet.from,buffer[:packet.count]) {pp.hub_control_receive(&self.hub,packet.from,buffer[:packet.count])}
        }
        path:=gd.new_string_odin(gd.env_string("RPP_DONE",""));defer gd.free_string(path)
        if gd.file_access_file_exists(path) {
            room:=pp.hub_room(&self.hub,871);if room==nil {fail(self,"missing room");return}
            reg,error:=pp.registry(room)
            if error!=.None || reg.match.count!=3 || room.bundle.enrollment.record.epoch!=0 {fail(self,"final registry");return}
            provider:=rgd.rendezvous_p2p_room_provider(room)
            state,err:=provider.state(provider.user,0)
            if err!=.None || !state.active || state.code!=adm.code(reg.match) {fail(self,"signaling roster");return}
            gd.print_str(fmt.tprintf("P2P_PROVISION_SERVICE_OK resume=%t players=3 epoch=0 generation=%d",self.resume,room.bundle.enrollment.record.coordinator_generation))
            self.done=true;gd.scene_tree_quit(gd.get_tree(self.owner),0)
        }
        return
    }
    if self.phase<5 {
        if rgd.provision_frame(&self.connection)!=.None {fail(self,"enrollment pump");return}
        if self.phase==0 && tr.status(&self.wire)==.Connected {enroll(self,1);return}
        if !self.connection.client.complete {return}
        reply:=self.connection.client.reply;self.connection.client.complete=false
        if reply.result!=.None {fail(self,fmt.tprintf("enrollment %v",reply.result));return}
        if self.phase==1 {self.grants[0]=reply.grant}
        if self.phase>=3 {self.grants[self.phase-2]=reply.grant}
        if self.phase<4 {enroll(self,self.phase+1);return}
        for g,i in self.grants {if g.identity.member!=u64(i+1) || g.can_host || g.trusted_authority || g.infrastructure {fail(self,"authority granted");return}}
        g:=self.grants[2]
        if auth.lease_init(&self.lease,g.identity,g.room,g.content,auth.native_clock(),false)!=.None {fail(self,"control scope");return}
        nonce,ok:=auth.rpc_nonce()
        if !ok || !auth.rpc_client_init(&self.rpc,&self.lease,g.key,nonce,self.wire) {fail(self,"RPC init");return}
        if auth.rpc_begin(&self.rpc,{verb=.Challenge})!=.None {fail(self,"challenge");return}
        self.phase=5;return
    }
    if auth.rpc_client_pump(&self.rpc)!=.None {fail(self,"RPC pump");return}
    reply,complete:=auth.rpc_completed(&self.rpc);if !complete {return}
    if reply.result!=.None || reply.view.epoch!=0 || reply.view.remaining_ms!=0 {fail(self,fmt.tprintf("RPC reply %v",reply.result));return}
    if self.phase==5 {
        if auth.rpc_begin(&self.rpc,{verb=.Rebind,challenge=reply.challenge,incarnation=reply.registration_identity.incarnation})!=.None {fail(self,"rebind");return}
        self.phase=6;return
    }
    if self.phase==6 {
        if auth.rpc_begin(&self.rpc,{verb=.Query})!=.None {fail(self,"query");return}
        self.phase=7;return
    }
    match,error:=pp.match_from_reply(reply,871,55,3,self.lease.identity)
    if error!=.None || match.members[2]!=3 || self.lease.identity.incarnation!=(self.resume ? u64(3) : u64(2)) {fail(self,"roster");return}
    keys:[96]u8
    for g,i in self.grants {key:=g.key;copy(keys[i*32:(i+1)*32],key[:])}
    fingerprint:=fmt.aprintf("%x",rec.hash(keys[:]));defer delete(fingerprint)
    file:=gd.env_string("RPP_FINGERPRINT","")
    if self.resume {
        bytes,e:=os.read_entire_file(file,context.allocator);defer delete(bytes)
        if e!=nil || string(bytes)!=fingerprint {fail(self,"credentials changed");return}
    } else if os.write_entire_file(file,fingerprint)!=nil {fail(self,"fingerprint");return}
    if os.write_entire_file(gd.env_string("RPP_DONE",""),"done")!=nil {fail(self,"done");return}
    gd.print_str(fmt.tprintf("P2P_PROVISION_CLIENT_OK resume=%t players=3 session=%d incarnation=%d stable_keys=true",self.resume,match.session,self.lease.identity.incarnation))
    self.done=true;gd.scene_tree_quit(gd.get_tree(self.owner),0)
}
replay_provision_peer_exit_tree :: proc(self:^ReplayProvisionPeer) {
    auth.rpc_client_destroy(&self.rpc);rgd.provision_disconnect(&self.connection)
    pp.hub_close(&self.hub);rgd.websocket_close(&self.socket);db.close(&self.store)
    unref(self.tls)
}
fail :: proc(self:^ReplayProvisionPeer,reason:string) {gd.print_str(fmt.tprintf("P2P_PROVISION_FAIL %s",reason));self.done=true;gd.scene_tree_quit(gd.get_tree(self.owner),1)}
unref :: proc(object: gd.Ref_Counted) {if object != nil && gd.ref_counted_unreference(object) {gdext.object_destroy(object)}}
tls_options :: proc(server: bool, cert_path: string) -> gd.Tls_Options {
	certificate := gd.new_x509_certificate(); gd.ref_counted_init_ref(certificate); defer unref(certificate)
	path := gd.new_string_odin(cert_path); defer gd.free_string(path)
	if gd.x509_certificate_load(certificate, path) != .Ok {return nil}
	if server {
		key := gd.new_crypto_key(); gd.ref_counted_init_ref(key); defer unref(key)
		key_path := gd.new_string_odin(gd.env_string("RPP_KEY", "")); defer gd.free_string(key_path)
		if gd.crypto_key_load(key, key_path, false) != .Ok {return nil}
		return gd.tls_options_server(key, certificate)
	}
	return gd.tls_options_client(certificate, gd.string_empty())
}
