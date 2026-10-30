//gd:extends Node
//gd:class WebAuthorityClient
package web_authority_client

import "core:fmt"
import gd "godot:godot"
import auth "godot:replay/authority"
import tr "godot:replay/transport"
import rgd "godot:replay/godot"

WebAuthorityClient :: struct {
 owner:gd.Node,socket:rgd.Websocket,wire:tr.Transport,
 clock:rgd.Browser_Lease_Clock,lease:auth.Lease,rpc:auth.Rpc_Client,
 ready,sent,large,text,retained,done,failed:bool,
 last_reply,started:u64,stage:int,
 buffer:[tr.MAX_PACKET_BYTES]u8,
}
web_authority_client_ready :: proc(self:^WebAuthorityClient) {
 url:=gd.web_query("url")
 if !rgd.websocket_join(&self.socket,url) {fail(self,"socket");return}
 self.wire=rgd.websocket_transport(&self.socket)
 if auth.lease_init(&self.lease,{1,101},44,55,rgd.browser_lease_clock(&self.clock),true)!=.None {fail(self,"clock");return}
 self.started,_=self.lease.clock.read(self.lease.clock.user)
 self.ready=true
}
web_authority_client_process :: proc(self:^WebAuthorityClient,dt:f64) {
 if !self.ready || self.failed || self.done {return}
 now,valid:=self.lease.clock.read(self.lease.clock.user)
 if !valid || now-self.started>20000 {fail(self,"clock/timeout");return}
 if !self.rpc.ready {
  tr.poll(&self.wire)
  if !self.sent && tr.status(&self.wire)==.Connected {
   for &b,i in self.buffer {b=u8(i%251)};self.buffer[0]=0xa7
   if tr.send(&self.wire,1,.Reliable,self.buffer[:])!=.Sent || rgd.websocket_send_text(&self.socket,1,"rendezvous-text-probe")!=.Sent {fail(self,"send");return}
   if tr.send(&self.wire,1,.Unreliable,self.buffer[:1])!=.Invalid {fail(self,"reliable-only contract");return}
   self.sent=true
  }
  for _ in 0..<8 {
   packet:=rgd.websocket_receive(&self.socket,self.retained ? self.buffer[:] : self.buffer[:1])
   if packet.state==.Empty {break}
   if packet.state==.Buffer_Too_Small {self.retained=true;continue}
   if packet.state!=.Received || packet.from!=1 {fail(self,"metadata");return}
   if packet.text {if string(self.buffer[:packet.count])!="rendezvous-text-ack" {fail(self,"text");return};self.text=true} else {
    if packet.count!=tr.MAX_PACKET_BYTES || self.buffer[0]!=0xa7 {fail(self,"large packet");return}
    for b,i in self.buffer {if i>0 && b!=u8(i%251) {fail(self,"large contents");return}};self.large=true
   }
  }
  if !self.large || !self.text {return}
  nonce:=auth.Nonce(rgd.session_token())
  if !auth.rpc_client_init(&self.rpc,&self.lease,{0=21},nonce,self.wire) {fail(self,"RPC init");return}
  gd.print_str("WEB_AUTHORITY_TRANSPORT_OK")
 }
 if err:=auth.rpc_client_pump(&self.rpc);err!=.None && err!=.Busy {fail(self,fmt.tprintf("RPC %v",err));return}
 if reply,complete:=auth.rpc_completed(&self.rpc);complete && reply.sequence!=self.last_reply {
  self.last_reply=reply.sequence
  if reply.result!=.None {fail(self,fmt.tprintf("reply %v",reply.result));return}
  if self.stage==1 {
   tr.close(&self.wire)
   if !rgd.websocket_join(&self.socket,gd.web_query("url")) {fail(self,"control reconnect");return}
   self.wire=rgd.websocket_transport(&self.socket);self.rpc.wire=self.wire
   gd.print_str("WEB_AUTHORITY_RECONNECTED")
  }
  if self.stage==2 {
   bad:[auth.RPC_BYTES]u8;copy(bad[:],self.rpc.txb[:self.rpc.count]);bad[self.rpc.count-1]~=1
   if tr.send(&self.wire,1,.Reliable,bad[:self.rpc.count])!=.Sent {fail(self,"bad MAC probe");return}
  }
  if self.stage>=2 && (!auth.lease_live(&self.lease,1) || reply.view.owner!=(auth.Identity{1,101})) {fail(self,"authenticated lease");return}
  if self.stage==4 {
   // A later backward wall sample permanently poisons this source and its lease.
   self.clock.paired.last_wall=max(u64)
   if auth.lease_live(&self.lease,1) || !self.lease.poisoned {fail(self,"clock fencing");return}
   gd.print_str(fmt.tprintf("WEB_AUTHORITY_CLIENT_OK epoch=%d revision=%d",reply.view.epoch,reply.view.revision));self.done=true;return
  }
 }
 if !self.rpc.pending {
  command:auth.Command
  switch self.stage {case 0:command.verb=.Query;case 1:command.verb=.Start;case 2,3:command={verb=.Renew,epoch=1,tick=u64(self.stage)};case:return}
  if auth.rpc_begin(&self.rpc,command)!=.None {fail(self,"begin");return};self.stage+=1
 }
}
web_authority_client_exit_tree :: proc(self:^WebAuthorityClient) {auth.rpc_client_destroy(&self.rpc);tr.close(&self.wire)}
fail :: proc(self:^WebAuthorityClient,reason:string) {self.failed=true;gd.print_str(fmt.tprintf("WEB_AUTHORITY_FAIL %s",reason))}
