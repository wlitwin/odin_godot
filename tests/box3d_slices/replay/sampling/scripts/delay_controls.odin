package replay_public_sampling_test

import "core:fmt"
import gd "godot:godot"
import b "godot:box3d"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import r "godot:replay"
import ph "godot:replay/physics"
import rg "godot:replay/godot"
import net "godot:replay/net"
import tr "godot:replay/transport"
import rec "godot:replay/recovery"
import auth "godot:replay/authority"

// Nil-owner value-only Session exercises the existing legacy branch. Delay is
// constructed/freed through its public API; only session_frame advances time.
delay_legacy_open :: proc(self:^SamplingProbe){
 self.legacy=new(rg.Session(u32,u8,u8,u8,1))
 model:=net.Model(u32,u8,u8,u8,1){step=proc(state:^u32,input:[1]u8,joins,leaves:u64,ctx:^r.Step(u8)){state^+=1},control_valid=proc(u8)->bool{return true},state_valid=proc(u32)->bool{return true},hold=proc(v:u8)->u8{return v}}
 if rg.session_open(self.legacy,r.Frame(u32){},model)!=.None || !tr.delay_init(&self.legacy.delay,{},10){finish(self,false)}
}
delay_legacy_frame :: proc(self:^SamplingProbe){
 if rg.session_frame(self.legacy,0,u8(0))!=.None{finish(self,false);return}
 self.control_ok=self.legacy.connection==nil && self.legacy.delay.packets!=nil && self.legacy.delay.now>0
 gd.print_str(fmt.tprintf("REPLAY_DELAY_CLOCK legacy active_owned=false now=%d progressed=%v",self.legacy.delay.now,self.control_ok));finish(self,true)
}
delay_legacy_close :: proc(self:^SamplingProbe)->bool{
 if self.legacy==nil{return true}
 if self.legacy.delay.packets!=nil{wire:=tr.delay_transport(&self.legacy.delay);tr.close(&wire)}
 if rg.session_close(self.legacy)!=.None{return false}
 free(self.legacy);self.legacy=nil;return true
}

delay_owned_frame :: proc(self:^SamplingProbe){
 s:=&self.client.session
 if self.mode==.Delay_Zero{
  self.control_ok=s.connection!=nil && s.connection.delay.packets==nil && s.delay.packets==nil
  gd.print_str(fmt.tprintf("REPLAY_DELAY_CLOCK default_zero delay_unallocated=%v",self.control_ok));finish(self,true);return
 }
 if self.mode==.Delay_Owned{
  self.control_ok=s.connection!=nil && s.connection.delay.packets!=nil && s.connection.delay.now>0 && s.client.phase==.Running && s.client.stats.rx_packets>0 && s.delay.packets==nil
  gd.print_str(fmt.tprintf("REPLAY_DELAY_CLOCK owned now=%d received=%d running=%v progressed=%v",s.connection.delay.now,s.client.stats.rx_packets,s.client.phase==.Running,self.control_ok));finish(self,true);return
 }
 if self.stage==1{
  // Holding the public old lane owner keeps the retired connection data alive
  // while ordinary authenticated redirect publishes a fresh owned generation.
  self.held_wire=rec.link_game_owner(rg.session_link(s));if r.owner_retain(self.held_wire.owner)!=.None{finish(self,false);return}
  a:=self.client;clock:=auth.Clock_Source{read=proc(_:rawptr)->(u64,bool){return u64(gd.time_get_ticks_msec(gd.singleton_time())),true}}
  if auth.lease_init(&a.lease,{member=202,incarnation=1},1,s.client.cfg.content,clock,false)!=.None{finish(self,false);return}
  request,error:=auth.lease_request(&a.lease);if error!=.None{finish(self,false);return}
  endpoint,valid:=auth.endpoint("127.0.0.1",49818);if !valid{finish(self,false);return}
  policy:=auth.DEFAULT_POLICY;policy.lease_ms=30000
  if auth.lease_accept(&a.lease,request,{room=1,content=s.client.cfg.content,revision=1,epoch=s.client.cfg.epoch,coordinator_generation=1,owner={member=101,incarnation=1},endpoint=endpoint,remaining_ms=30000,policy=policy})!=.None{finish(self,false);return}
  block,status:=meter.block_lease(a.scope,a,size_of(Actor),&a.lease,size_of(a.lease));if status!=bg.OK{finish(self,false);return}
  owner_error:r.Error
  a.lease_owner,owner_error=ph.owner_context_create(block,user_data=&a.lease,require_live_instance=false);if owner_error!=.None{finish(self,false);return}
  if rg.session_redirect(s,&a.lease,permit_context={a.lease_owner.owner,&a.lease})!=.None || s.retired_connection==nil{finish(self,false);return}
  self.retired_now=s.retired_connection.delay.now;self.stage=2;return
 }
 if !frame(self.host,0,{}) || !frame(self.client,0,{}){finish(self,false);return}
 self.control_ok=s.retired_connection!=nil && s.retired_connection.delay.now==self.retired_now && s.connection.delay.packets!=nil && s.connection.delay.now>0
 gd.print_str(fmt.tprintf("REPLAY_DELAY_CLOCK retired now_before=%d now_after=%d active_now=%d only_active_progressed=%v",self.retired_now,s.retired_connection!=nil?s.retired_connection.delay.now:0,s.connection.delay.now,self.control_ok))
 if r.owner_drop(&self.held_wire.owner)!=.None{finish(self,false);return}
 if !frame(self.client,0,{}){finish(self,false);return}
 self.control_ok=self.control_ok && s.retired_connection==nil
 finish(self,true)
}
