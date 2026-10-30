package replay_godot

import "core:mem"
import "core:crypto"
import gd "godot:godot"
import "godot:gdext"
import auth "godot:replay/authority"
import tr "godot:replay/transport"
import wiregd "godot:replay/godot/internal/wire"
import transportgd "godot:replay/godot/transport"

Rendezvous_Config :: struct {connections:int,challenge_ms:u64,rate,burst:f64,resume_ms:u64,mesh:bool}
DEFAULT_RENDEZVOUS_CONFIG :: Rendezvous_Config{32,5000,32,64,15000,false}
Rendezvous_Stats :: struct {challenged,admitted,rejected,relayed,departed,expired,budget_drops,resumed:u64}
Rendezvous :: struct {
 ready:bool,allocator:mem.Allocator,
 service:^auth.Service,provider:Rendezvous_Provider,now:u64,time_set:bool,socket:^transportgd.Websocket,config:Rendezvous_Config,
 peers:[]Rendezvous_Peer,epoch:u64,code:[64]u8,next_id:i64,
 stats:Rendezvous_Stats,
}
@(private)
Rendezvous_Peer :: struct {
 physical:tr.Peer_Id,id:i64,identity:auth.Identity,
 challenge,resume:auth.Nonce,deadline,at:u64,
 create,closing,preserve:bool,room:[64]u8,budget:f64,
}

// Borrows the service/socket; caller polls the socket once, routes text here and
// binary packets to service_receive, then pumps this frontend each frame.
rendezvous_init :: proc(r:^Rendezvous,s:^auth.Service,w:^transportgd.Websocket,cfg:=DEFAULT_RENDEZVOUS_CONFIG,allocator:=context.allocator)->bool {
 if s==nil || !s.ready {return false}
 if !rendezvous_provider_init(r,rendezvous_service_provider(s),w,cfg,allocator) {return false}
 r.service=s;return true
}
rendezvous_provider_init :: proc(r:^Rendezvous,provider:Rendezvous_Provider,w:^transportgd.Websocket,cfg:=DEFAULT_RENDEZVOUS_CONFIG,allocator:=context.allocator)->bool {
 if r.ready || w==nil || !w.ready || !w.server || provider.clock.read==nil || provider.state==nil || provider.enabled==nil || provider.verify==nil ||
    cfg.connections<2 || cfg.connections>128 || cfg.challenge_ms<250 || cfg.challenge_ms>15000 ||
    cfg.resume_ms<1000 || cfg.resume_ms>120000 || !(cfg.rate>=1 && cfg.rate<=256) || !(cfg.burst>=1 && cfg.burst<=512) {return false}
 r.provider,r.socket,r.config,r.allocator=provider,w,cfg,allocator
 r.peers=make([]Rendezvous_Peer,cfg.connections,allocator);r.next_id=2;r.ready=true;return true
}

rendezvous_destroy :: proc(r:^Rendezvous) {
 if !r.ready {return}
 for peer in r.peers {if peer.physical!=0 {transportgd.websocket_disconnect(r.socket,peer.physical)}}
 delete(r.peers,r.allocator);r^={}
}
rendezvous_pump :: proc(r:^Rendezvous)->auth.Error {
 if !r.ready {return .Not_Ready}
 now,ok:=r.provider.clock.read(r.provider.clock.user)
 if !ok || (r.time_set && now<r.now) {
  if r.service!=nil {r.service.coordinator.poisoned=true;r.service.coordinator.active=false}
  return .Clock
 }
 r.now,r.time_set=now,true
 view,err:=r.provider.state(r.provider.user,now);if err!=.None {return err}
 code:=view.code
 if r.epoch!=view.epoch || r.code!=code {
  for &peer in r.peers {if peer.physical!=0 {transportgd.websocket_disconnect(r.socket,peer.physical)};peer={}}
  r.epoch,r.code,r.next_id=view.epoch,code,2
 }
 for &peer in r.peers {
  if peer.physical==0 && peer.id==0 {continue}
  member_valid:=peer.id==0 || r.provider.enabled(r.provider.user,peer.identity)
  if !member_valid || (peer.id!=0 && !view.active) ||
     (peer.physical==0 && now>=peer.deadline) || (peer.closing && now>=peer.deadline) || (peer.id==0 && now>=peer.deadline) {
   if peer.id==0 && now>=peer.deadline {r.stats.expired+=1}
   rendezvous_remove(r,&peer);continue
  }
  if peer.physical!=0 && !rendezvous_connection_live(r.socket,peer.physical) {
   if peer.id==0 || peer.closing {rendezvous_remove(r,&peer)} else {
    // Keep the identity/ID only for an authenticated continuation of this RTC
    // instance. No departure is announced while its direct channels may survive.
    peer.physical=0;peer.deadline=now+r.config.resume_ms
   }
  }
 }
 return .None
}
rendezvous_receive :: proc(r:^Rendezvous,from:tr.Peer_Id,bytes:[]u8)->bool {
 if !r.ready || rendezvous_pump(r)!=.None || !rendezvous_connection_live(r.socket,from) {return false}
 if len(bytes)>32768 || !wiregd.json_depth(bytes) {transportgd.websocket_disconnect(r.socket,from);r.stats.rejected+=1;return false}
 now:=r.now
 peer:=rendezvous_find(r,from)
 if peer==nil {
  for &slot in r.peers {if slot.physical==0 && slot.id==0 {peer=&slot;peer^={physical=from,at=now,deadline=now+r.config.challenge_ms,budget=r.config.burst};break}}
  if peer==nil {transportgd.websocket_disconnect(r.socket,from);r.stats.rejected+=1;return false}
 }
 if peer.closing {return false}
 peer.budget=min(r.config.burst,peer.budget+f64(now-peer.at)*r.config.rate/1000);peer.at=now
 if peer.budget<1 {r.stats.budget_drops+=1;rendezvous_reject(r,peer,"rate",now);return false};peer.budget-=1
 text:=gd.new_string_odin(string(bytes));defer gd.free_string(text)
 v:=gd.json_parse_string(text);defer gd.variant_destroy(&v)
 if gdext.variant_get_type(&v)!=.Dictionary {rendezvous_reject(r,peer,"bad_msg",now);return false}
 data:=gd.variant_to_dictionary(&v);defer gd.free_dictionary(data)
 typ:=wiregd.get_string(&data,"type",32);defer delete(typ)
 switch typ {
 case "create","join":return rendezvous_register(r,peer,&data,typ=="create",now)
 case "signal":
  if peer.id==0 {rendezvous_reject(r,peer,"auth",now);return false}
  to:=wiregd.get_int(&data,"to");target:^Rendezvous_Peer
  if to<=0 || to>i64(max(i32)) {rendezvous_reject(r,peer,"peer",now);return false}
  for &other in r.peers {if other.id==to && other.physical!=0 && !other.closing {target=&other;break}}
  // Authority star: gameplay clients do not signal each other through this relay.
  if target==nil || target==peer || (!r.config.mesh && peer.id!=1 && to!=1) {rendezvous_reject(r,peer,"peer",now);return false}
  payload:=wiregd.get(&data,"data");defer gd.variant_destroy(&payload)
  if gdext.variant_get_type(&payload)!=.Dictionary {rendezvous_reject(r,peer,"bad_msg",now);return false}
  out:=gd.new_dictionary_default();defer gd.free_dictionary(out)
  wiregd.set_string(&out,"type","signal");wiregd.set_int(&out,"from",peer.id)
  copied:gd.Variant;gdext.variant_new_copy(&copied,&payload);wiregd.set(&out,"data",copied)
  if !rendezvous_send(r,target,&out) {return false};r.stats.relayed+=1;return true
 case "leave":rendezvous_remove(r,peer);return true
 case:rendezvous_reject(r,peer,"bad_msg",now);return false
 }
}
@(private)
rendezvous_register :: proc(r:^Rendezvous,p:^Rendezvous_Peer,data:^gd.Dictionary,create:bool,now:u64)->bool {
 room:=wiregd.get_string(data,"room",64);defer delete(room)
 token:=wiregd.get_string(data,"auth",auth.RENDEZVOUS_BYTES*2);defer delete(token)
 resume_text:=wiregd.get_string(data,"resume",32);defer delete(resume_text)
 preserve_text:=wiregd.get_string(data,"preserve",8);defer delete(preserve_text)
 if p.id!=0 || len(room)!=64 {rendezvous_reject(r,p,"bad_msg",now);return false}
 empty:auth.Nonce
 if len(token)==0 {
  if p.challenge!=empty {rendezvous_reject(r,p,"challenge",now);return false}
  nonce,ok:=auth.rpc_nonce();if !ok || nonce==empty {rendezvous_reject(r,p,"auth",now);return false}
  p.challenge,p.create,p.deadline=nonce,create,now+r.config.challenge_ms;p.preserve=preserve_text=="yes";copy(p.room[:],transmute([]u8)room)
  response:=gd.new_dictionary_default();defer gd.free_dictionary(response)
  wiregd.set_string(&response,"type","auth_challenge");wiregd.set_string(&response,"challenge",wiregd.hex_encode(nonce[:]))
  r.stats.challenged+=1;return rendezvous_send(r,p,&response)
 }
 challenge:=p.challenge;p.challenge={}
 if challenge==empty || now>=p.deadline || create!=p.create || room!=string(p.room[:]) {rendezvous_reject(r,p,"challenge",now);return false}
 proof:auth.Rendezvous_Proof
 if !wiregd.hex_decode(proof[:],token) {rendezvous_reject(r,p,"auth",now);return false}
 identity,code,err:=r.provider.verify(r.provider.user,proof[:],challenge,create)
 if err!=.None || room!=string(code[:]) || code!=r.code {rendezvous_reject(r,p,"auth",now);return false}
 owner,continuation:^Rendezvous_Peer
 for &other in r.peers {
  if other.id==0 || other.closing {continue}
  if other.identity==identity {
   candidate:auth.Nonce
   if other.physical!=0 {rendezvous_reject(r,p,"duplicate",now);return false}
   if !wiregd.hex_decode(candidate[:],resume_text) || crypto.compare_constant_time(candidate[:],other.resume[:])!=1 {rendezvous_reject(r,p,"resume",now);return false}
   continuation=&other
  }
  if other.id==1 && other.physical!=0 {owner=&other}
 }
 if resume_text!="" && continuation==nil {rendezvous_reject(r,p,"resume",now);return false}
 if (create && owner!=nil) || (!create && owner==nil) || (continuation==nil && r.next_id>i64(max(i32))) {rendezvous_reject(r,p,"no_room",now);return false}
 resumed:=continuation!=nil
 p.identity=identity
 if resumed {p.id,p.resume=continuation.id,continuation.resume;continuation^={};r.stats.resumed+=1} else {
  token,generated:=auth.rpc_nonce();if !generated || token==(auth.Nonce{}) {rendezvous_reject(r,p,"auth",now);return false}
  p.resume=token;p.id=create ? 1 : r.next_id;if !create {r.next_id+=1}
 }
 response:=gd.new_dictionary_default();defer gd.free_dictionary(response)
 wiregd.set_string(&response,"type",create ? "created" : "joined");wiregd.set_string(&response,"room",room);wiregd.set_int(&response,"id",p.id)
 wiregd.set_string(&response,"resume",wiregd.hex_encode(p.resume[:]))
 if !rendezvous_send(r,p,&response) {return false}
 for &other in r.peers {
  if other.id==0 || other.physical==0 || other.closing || &other==p || (!r.config.mesh && p.id!=1 && other.id!=1) {continue}
  if !rendezvous_notice(r,p,"peer",other.id,!(resumed && p.preserve)) || !rendezvous_notice(r,&other,"peer",p.id,!(resumed && p.preserve)) {return false}
 }
 r.stats.admitted+=1;return true
}
@(private)
rendezvous_find :: proc(r:^Rendezvous,from:tr.Peer_Id)->^Rendezvous_Peer {for &peer in r.peers {if peer.physical==from {return &peer}};return nil}
@(private)
rendezvous_remove :: proc(r:^Rendezvous,p:^Rendezvous_Peer) {
 id:=p.id;transportgd.websocket_disconnect(r.socket,p.physical);p^={}
 if id!=0 {r.stats.departed+=1;for &other in r.peers {if other.id!=0 && other.physical!=0 && !other.closing {rendezvous_notice(r,&other,"peer_left",id)}}}
}
@(private)
rendezvous_reject :: proc(r:^Rendezvous,p:^Rendezvous_Peer,reason:string,now:u64) {
 response:=gd.new_dictionary_default();defer gd.free_dictionary(response)
 wiregd.set_string(&response,"type","error");wiregd.set_string(&response,"reason",reason);rendezvous_send(r,p,&response)
 p.closing=true;p.deadline=now+100;r.stats.rejected+=1
}
@(private)
rendezvous_notice :: proc(r:^Rendezvous,p:^Rendezvous_Peer,typ:string,id:i64,replace:bool=false)->bool {
 out:=gd.new_dictionary_default();defer gd.free_dictionary(out);wiregd.set_string(&out,"type",typ);wiregd.set_int(&out,"id",id);wiregd.set_string(&out,"replace",replace ? "yes" : "no")
 if typ=="peer" {
  for other in r.peers {if other.id==id {
   wiregd.set_string(&out,"member",wiregd.identity_hex(other.identity.member))
   wiregd.set_string(&out,"incarnation",wiregd.identity_hex(other.identity.incarnation));break
  }}
 }
 return rendezvous_send(r,p,&out)
}
@(private)
rendezvous_send :: proc(r:^Rendezvous,p:^Rendezvous_Peer,out:^gd.Dictionary)->bool {
 v:=gd.variant_from_dictionary(out);defer gd.variant_destroy(&v)
 s:=gd.json_stringify(v,gd.string_empty(),false,false);defer gd.free_string(s)
 text:=gd.gd_string_to_odin(s)
 if transportgd.websocket_send_text(r.socket,p.physical,text)!=.Sent {transportgd.websocket_disconnect(r.socket,p.physical);p.closing=true;return false}
 return true
}
