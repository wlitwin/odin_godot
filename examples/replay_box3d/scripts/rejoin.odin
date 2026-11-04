// Bounded sample lifecycle/diagnostics around ordinary Session Client admission.
package replay_box3d

import "core:fmt"
import "core:strconv"
import gd "godot:godot"
import b "godot:box3d"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import net "godot:replay/net"
import rt "godot:runtime"
import rgd "godot:replay/godot"

SLICE_INITIAL_PHASES :: [6]u64{40,56,80,120,136,160}
Rejoin_Sample :: struct {
 process_generation,exit_at,expected_epoch:u64,
 expected_seat:u16,
 expected_token:net.Token,
 expect_token,initial_intents_done:bool,
 member_connected:[16]bool,
 member_peer,member_generation,member_serial:[16]u64,
}

slice_rejoin_options :: proc(self:^ReplayBox3d)->bool{
 p:=&self.rejoin
 generation,gok:=strconv.parse_u64(gd.env_string("B3_GENERATION","1"))
 exit_at,xok:=strconv.parse_u64(gd.env_string("B3_EXIT_AT","0"))
 epoch,eok:=strconv.parse_u64(gd.env_string("B3_EXPECT_EPOCH","0"))
 seat,sok:=strconv.parse_u64(gd.env_string("B3_EXPECT_SEAT","0"))
 token,tok:=strconv.parse_u64(gd.env_string("B3_EXPECT_TOKEN","0"))
 if !gok || !xok || !eok || !sok || !tok || generation==0 || seat>2{return false}
 if exit_at!=0 && (self.role!="client" || self.end_tick==0 || exit_at>=self.end_tick){return false}
 if generation>1 && (self.role!="client" || seat==0 || token==0 || epoch==0 || self.end_tick==0 || self.required_ticks==0){return false}
 p.process_generation=generation;p.exit_at=exit_at;p.expected_epoch=epoch;p.expected_seat=u16(seat);p.expect_token=token!=0
 for i in 0..<8{p.expected_token[i]=u8(token>>uint(i*8))}
 return true
}
slice_token_text :: proc(token:net.Token)->string{
 hex:[32]u8;digits:="0123456789abcdef"
 for byte,i in token{hex[2*i]=digits[byte>>4];hex[2*i+1]=digits[byte&15]}
 return fmt.tprintf("%s",string(hex[:]))
}
// These are actual Session/network membership scope counters. Authority has no
// corresponding own remote-peer scope; its diagnostic values are explicitly0.
slice_client_scope :: proc(self:^ReplayBox3d)->(u64,u64){
 if self.hosting{return 0,0}
 return self.state.session.client.generation,self.state.session.client.serial
}
slice_initial_identity :: proc(self:^ReplayBox3d)->bool{
 s:=&self.state.session;p:=&self.rejoin
 epoch:=self.hosting?s.server.cfg.epoch:s.client.cfg.epoch
 if p.expected_epoch!=0 && epoch!=p.expected_epoch{return false}
 if p.expected_seat!=0 && rgd.session_seat(s)!=p.expected_seat{return false}
 if p.expect_token && s.token!=p.expected_token{return false}
 if p.process_generation>1 && (self.target<self.baseline || self.target-self.baseline<32){return false}
 return true
}

slice_initial_intents :: proc(self:^ReplayBox3d)->bool{
 p:=&self.rejoin;if p.initial_intents_done{return false};p.initial_intents_done=true
 if !self.scripted{return true}
 s:=&self.state.session;head:=self.hosting?s.server.timeline.head:s.client.timeline.head
 epoch:=self.hosting?s.server.cfg.epoch:s.client.cfg.epoch
 generation,serial:=slice_client_scope(self)
 // Each entry is an exact initial plan index0..5, never an issued sequence.
 buffer:[1024]u8;used:=0;entries:=0
 for original,index in SLICE_INITIAL_PHASES {
  if self.sent[index] || self.planned[index]!=original || self.planned_original[index]!=original{return false}
  if original>head{continue}
  cycles:=(head-original)/240+1
  if cycles>(max(u64)-original)/240{return false}
  next:=original+240*cycles;if next<=head{return false}
  if entries>0{buffer[used]=',';used+=1}
  entry:=fmt.bprintf(buffer[used:],"{{\"phase\":%d,\"old_tick\":%d,\"next_tick\":%d,\"cycles\":%d}}",index,original,next,cycles)
  used+=len(entry);entries+=1
  self.planned[index]=next;self.planned_original[index]=next
 }
 gd.print_str(fmt.tprintf("BOX3D_SLICE_INTENT_BASELINE {{\"role\":\"%s\",\"process_generation\":%d,\"epoch\":%d,\"generation\":%d,\"serial\":%d,\"initial_baseline\":%d,\"initial_head\":%d,\"seat\":%d,\"retired\":[%s]}}",self.actor,p.process_generation,epoch,generation,serial,self.baseline,head,rgd.session_seat(s),string(buffer[:used])))
 return true
}
slice_ready_log :: proc(self:^ReplayBox3d){
 s:=&self.state.session;generation,serial:=slice_client_scope(self)
 gd.print_str(fmt.tprintf("BOX3D_SLICE_READY {{\"role\":\"%s\",\"epoch\":%d,\"seat\":%d,\"token_hex\":\"%s\",\"stage\":\"complete_welcome\",\"baseline\":%d,\"target\":%d,\"snapshot_every\":1,\"action_timing\":\"Receipt\",\"contract\":%d,\"game_rules\":\"%s\",\"game_schema\":\"%s\",\"process_generation\":%d,\"generation\":%d,\"serial\":%d,\"impairment\":%s}}",self.actor,self.hosting?s.server.cfg.epoch:s.client.cfg.epoch,rgd.session_seat(s),slice_token_text(s.token),self.baseline,self.target,self.hosting?s.server.contract:s.client.contract,digest_hex(self.state.codec.value.game_rules),digest_hex(self.state.codec.value.identity.game_schema),self.rejoin.process_generation,generation,serial,slice_impairment_json(self)))
}

slice_member_running :: proc(self:^ReplayBox3d,index:int){
 s:=&self.state.session;peer:=s.server.peers[index];p:=&self.rejoin
 first:=!p.member_connected[index] || p.member_generation[index]!=peer.generation
 p.member_connected[index]=true;p.member_peer[index]=u64(peer.connection);p.member_generation[index]=peer.generation;p.member_serial[index]=peer.serial
 if first{slice_member_log(self,index,"running",u64(peer.connection),peer.generation,peer.serial)}
}
slice_member_log :: proc(self:^ReplayBox3d,index:int,stage:string,peer_id,generation,serial:u64){
 s:=&self.state.session;peer:=s.server.peers[index]
 gd.print_str(fmt.tprintf("BOX3D_SLICE_MEMBER {{\"role\":\"%s\",\"stage\":\"%s\",\"epoch\":%d,\"tick\":%d,\"seat\":%d,\"token_hex\":\"%s\",\"generation\":%d,\"serial\":%d,\"peer\":%d}}",self.actor,stage,s.server.cfg.epoch,s.server.timeline.head,peer.seat,slice_token_text(self.role_tokens[index]),generation,serial,peer_id))
}
slice_membership :: proc(self:^ReplayBox3d){
 if !self.hosting{return};s:=&self.state.session;p:=&self.rejoin
 for peer,index in s.server.peers {
  if !p.member_connected[index] || p.member_generation[index]!=peer.generation{continue}
  if peer.phase==.Disconnected{
   slice_member_log(self,index,"disconnected",p.member_peer[index],peer.generation,peer.serial);p.member_connected[index]=false
  }else if peer.phase==.Running{p.member_serial[index]=peer.serial}
 }
}

slice_interim_exit :: proc(self:^ReplayBox3d)->bool{
 p:=&self.rejoin;if self.hosting || p.exit_at==0{return false}
 s:=&self.state.session
 if s.client.phase!=.Running || !s.client.has_world || s.client.timeline.confirmed<p.exit_at{return false}
 epoch,head,confirmed:=s.client.cfg.epoch,s.client.timeline.head,s.client.timeline.confirmed
 generation,serial,seat,token:=s.client.generation,s.client.serial,s.client.seat,s.token
 self.finished=true;self.ready=false;slice_flow(self,"before_close");slice_ledger(self,"before_close")
 cleanup:=slice_close(self);slice_ledger(self,"after_cleanup")
 engine,es:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats()
 provider,ps:=meter.category_stats(bg.CATEGORY_REPLAY_PROVIDER);core,cs:=meter.category_stats(bg.CATEGORY_REPLAY_CORE)
 callbacks,callback_status:=rt.managed_callable_stats()
 contract,domain_status:=b.domain_contract_get();ledger,ledger_status:=b.host_ledger_get(contract.cookie)
 zero:=domain_status==.Ok && ledger_status==.Ok && ledger.host_reserved_bytes==0 && cleanup==.None && es==.Ok && ws==.Ok && ps==bg.OK && cs==bg.OK && callback_status==bg.OK && engine.live_bytes==0 && wrapper.live_bytes==0 && provider.live_bytes+core.live_bytes==0 && provider.contexts+core.contexts==0 && callbacks.live_records==0 && callbacks.pending_records==0 && callbacks.open_records==0 && callbacks.inflight_calls==0
 gd.print_str(fmt.tprintf("BOX3D_SLICE_SESSION_EXIT {{\"role\":\"%s\",\"process_generation\":%d,\"epoch\":%d,\"head\":%d,\"confirmed\":%d,\"seat\":%d,\"token_hex\":\"%s\",\"generation\":%d,\"serial\":%d,\"exit_at\":%d,\"cleanup\":\"%v\",\"engine_live\":%d,\"wrapper_live\":%d,\"meter_live\":%d,\"owners_live\":%d,\"managed_callbacks_live\":%d,\"callback_status\":%d,\"ok\":%v}}",self.actor,p.process_generation,epoch,head,confirmed,seat,slice_token_text(token),generation,serial,p.exit_at,cleanup,engine.live_bytes,wrapper.live_bytes,provider.live_bytes+core.live_bytes,provider.contexts+core.contexts,callbacks.live_records,callback_status,zero))
 gd.scene_tree_quit(gd.node_get_tree(self.owner),zero?0:1)
 return true
}
