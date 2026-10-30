//gd:extends Node
//gd:class WebAuthorityServer
package web_authority_server

import cave "godot:examples/replay_cavecrawl/shared/cave"
import cave_owned "godot:examples/replay_cavecrawl/shared/owner_cave"
import "core:fmt"
import gd "godot:godot"
import auth "godot:replay/authority"
import db "godot:replay/authority/sqlite"
import tr "godot:replay/transport"
import net "godot:replay/net"
import scrap "godot:examples/replay_scrapyard/shared/game"
import rgd "godot:replay/godot"
import storagegd "godot:replay/godot/storage"
import transportgd "godot:replay/godot/transport"

WebAuthorityServer :: struct {owner:gd.Node,socket:transportgd.Websocket,wire:tr.Transport,service:auth.Service,signal:rgd.Rendezvous,signal_mode,cave_mode,scrap_mode:bool,store:db.Store,ready:bool,last_revision:u64}
web_authority_server_ready :: proc(self:^WebAuthorityServer) {
 self.scrap_mode=gd.env_string("RWA_GAME","")=="scrapyard"
 owned:=gd.env_string("RWA_GAME","")=="cave-owned"
 self.cave_mode=owned || gd.env_string("RWA_GAME","")=="cave"
 self.signal_mode=gd.env_int("RWA_SIGNAL",0)==1
 port:=gd.env_int("RWA_PORT",49730)
 if port<1 || port>65535 || !transportgd.websocket_host(&self.socket,u16(port),cfg={32,64,256*1024,10000}) {fail(self,"socket");return}
 self.wire=transportgd.websocket_transport(&self.socket)
 if db.open(&self.store,gd.env_string("RWA_DB",""),true)!=.None {fail(self,"database");return}
 record:=auth.record_make(self.scrap_mode ? 48 : 44,self.scrap_mode ? scrap.CONTENT : owned ? cave_owned.CONTENT : self.cave_mode ? cave.CONTENT : 55,{1,101})
 endpoint,_:=auth.endpoint("127.0.0.1",49731)
 count:=self.signal_mode ? ((self.cave_mode || self.scrap_mode) ? 3 : 4) : 1
 if self.signal_mode {record.policy.lease_ms=self.scrap_mode ? 5000 : self.cave_mode ? 3000 : 10000}
 keys:[4]auth.Credential
 for i in 0..<count {
  id:=auth.Identity{u64(i+1),u64(i+101)}
  record.members[i]={identity=id,endpoint=endpoint,enabled=true,can_host=i<2,trusted_authority=i<2}
  if self.cave_mode || self.scrap_mode {record.members[i].game_token_hash=net.token_hash(storagegd.session_token(fmt.tprintf("browser-room-%d",i+1)))}
  keys[i]={identity=id,key={0=u8(21+i)}}
 }
 if auth.service_init(&self.service,record,db.commit,&self.store,auth.native_clock(),self.wire,keys[:count])!=.None {fail(self,"service");return}
 if self.signal_mode && !rgd.rendezvous_init(&self.signal,&self.service,&self.socket) {fail(self,"rendezvous");return}
 self.ready=true;gd.print_str("WEB_AUTHORITY_SERVER_READY")
}
web_authority_server_process :: proc(self:^WebAuthorityServer,dt:f64) {
 if !self.ready {return}
 done:=gd.new_string_odin(gd.env_string("RWA_DONE",""));defer gd.free_string(done)
 if gd.file_access_file_exists(done) {
  if ((self.cave_mode || self.scrap_mode) ? self.service.coordinator.record.epoch<(gd.env_int("RWA_SIGNAL_ONLY",0)==1 ? u64(1) : u64(2)) : self.service.coordinator.record.epoch!=1) || (!self.signal_mode && self.service.stats.rejected<1) || (self.signal_mode && (self.signal.stats.admitted<u64(clamp(gd.env_int("RWA_SIGNAL_MEMBERS",3),2,16)) || (!self.cave_mode && !self.scrap_mode && self.signal.stats.rejected<3))) {fail(self,"final service state");return}
  if self.signal_mode {gd.print_str(fmt.tprintf("RZA_SERVER_OK admitted=%d rejected=%d relayed=%d expired=%d resumed=%d",self.signal.stats.admitted,self.signal.stats.rejected,self.signal.stats.relayed,self.signal.stats.expired,self.signal.stats.resumed))}
  gd.print_str(fmt.tprintf("WEB_AUTHORITY_SERVER_OK epoch=%d rejected=%d",self.service.coordinator.record.epoch,self.service.stats.rejected));gd.scene_tree_quit(gd.get_tree(self.owner),0);return
 }
 tr.poll(&self.wire)
 buffer:[tr.MAX_PACKET_BYTES]u8
 for _ in 0..<32 {
  packet:=transportgd.websocket_receive(&self.socket,buffer[:]);if packet.state==.Empty {break}
  if packet.state!=.Received {fail(self,"receive");return}
  if packet.text && self.signal_mode {rgd.rendezvous_receive(&self.signal,packet.from,buffer[:packet.count]);continue}
  if packet.text {
   if string(buffer[:packet.count])!="rendezvous-text-probe" {fail(self,"text");return}
   if transportgd.websocket_send_text(&self.socket,packet.from,"rendezvous-text-ack")!=.Sent {fail(self,"text reply");return}
  } else if packet.count==tr.MAX_PACKET_BYTES && buffer[0]==0xa7 {
   if tr.send(&self.wire,packet.from,.Reliable,buffer[:])!=.Sent {fail(self,"large reply");return}
  } else {auth.service_receive(&self.service,packet.from,buffer[:packet.count])}
 }
 if self.signal_mode && rgd.rendezvous_pump(&self.signal)!=.None {fail(self,"signal pump");return}
 if self.service.coordinator.record.revision!=self.last_revision {
  self.last_revision=self.service.coordinator.record.revision
  gd.print_str(fmt.tprintf("WEB_AUTHORITY_COMMIT revision=%d epoch=%d rejected=%d",self.last_revision,self.service.coordinator.record.epoch,self.service.stats.rejected))
 }
}
web_authority_server_exit_tree :: proc(self:^WebAuthorityServer) {rgd.rendezvous_destroy(&self.signal);auth.service_destroy(&self.service);tr.close(&self.wire);db.close(&self.store)}
fail :: proc(self:^WebAuthorityServer,reason:string) {gd.print_str(fmt.tprintf("WEB_AUTHORITY_FAIL %s",reason));gd.scene_tree_quit(gd.get_tree(self.owner),1)}
