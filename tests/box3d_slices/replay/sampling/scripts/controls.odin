package replay_public_sampling_test

import "core:fmt"
import "core:mem"
import gd "godot:godot"
import meter "godot:box3d/godot/meter"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import rg "godot:replay/godot"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

// Construct a genuine idempotent Hello through its existing public Schema
// metadata and normal transport. It changes no Client phase/head/clock fields.
queue_hello :: proc(a:^Actor)->bool{
 c:=&a.session.client;schema:=&c.codecs.hello;allocator:=meter.allocator(a.scope)
 bytes,error:=mem.alloc_bytes(sc.HEADER_BYTES+schema.wire_size,allocator=allocator);if error!=.None{return false};defer delete(bytes,allocator)
 body:=bytes[sc.HEADER_BYTES:]
 for field in schema.fields {
  value:u64
  switch field.path{
  case "$.contract":value=c.contract
  case "$.spectator":value=c.spectator?1:0
  case "$.sent_ms":value=u64(gd.time_get_ticks_msec(gd.singleton_time()))
  case "$.incarnation":value=c.incarnation
  case:
   found:=false
   for byte,index in c.token{if field.path==fmt.tprintf("$.token[%d]",index){value=u64(byte);found=true;break}}
   if !found{return false}
  }
  for i in 0..<field.width{body[field.wire_offset+i]=u8(value>>uint(i*8))}
 }
 if sc.pack_bytes(schema.fingerprint,{kind=1,epoch=c.cfg.epoch,content=c.cfg.content},body,bytes).error!=.None{return false}
 return tr.send(&c.wire,c.authority,.Reliable,bytes)==.Sent
}
sampling_controls :: proc(self:^SamplingProbe){
 c:=&self.client.session.client
 if self.mode==.No_Catchup{
  if !frame(self.host,0,{}) || !rec.link_pump(rg.session_link(&self.client.session),u64(gd.time_get_ticks_msec(gd.singleton_time()))){finish(self,false);return}
  if net.client_pump(c,u64(gd.time_get_ticks_msec(gd.singleton_time())))!=.None{finish(self,false);return}
  self.window+=1
  if c.timeline.head!=self.start_head || c.stats.snapshot_catchups!=self.start_catchups{self.control_ok=false}
  if self.window==32{gd.print_str(fmt.tprintf("REPLAY_SAMPLING_CONTROL no_catchup head_before=%d head_after=%d catchup_delta=%d bounded=%v",self.start_head,c.timeline.head,c.stats.snapshot_catchups-self.start_catchups,self.control_ok));finish(self,true)}
  return
 }
 if self.stage==1{
  distance:=c.timeline.head-self.host.session.server.timeline.head+1
  if distance>8{finish(self,false);return}
  if !frame(self.host,f64(distance)/60+1e-9,{}){finish(self,false);return};self.stage=2;self.wait=0;return
 }
 if !frame(self.host,0,{}) || !rec.link_pump(rg.session_link(&self.client.session),u64(gd.time_get_ticks_msec(gd.singleton_time()))){finish(self,false);return}
 self.wait+=1;if self.wait<8{return}
 if self.stage==2{
  gd.print_str(fmt.tprintf("REPLAY_SAMPLING_CONTROL before_hello hosthead=%d clienthead=%d cf=%d queued_rx=%d",self.host.session.server.timeline.head,c.timeline.head,c.timeline.confirmed,rg.session_link(&self.client.session).router.stats.received))
  if !queue_hello(self.client){finish(self,false);return};self.stage=3;self.wait=0;return
 }
 before_catchups,before_serial:=c.stats.snapshot_catchups,c.serial
 gd.print_str(fmt.tprintf("REPLAY_SAMPLING_CONTROL queued hosthead=%d clienthead=%d cf=%d queued_rx=%d rejected=%d peerphase=%v peerserial=%d",self.host.session.server.timeline.head,c.timeline.head,c.timeline.confirmed,rg.session_link(&self.client.session).router.stats.received,self.host.session.server.stats.rejected_packets,self.host.session.server.peers[1].phase,self.host.session.server.peers[1].serial))
 if net.client_pump(c,u64(gd.time_get_ticks_msec(gd.singleton_time())))!=.None{finish(self,false);return}
 depth:=c.timeline.head-c.timeline.confirmed
 self.control_ok=c.stats.snapshot_catchups>before_catchups && c.serial>before_serial && depth==u64(c.lead_ticks) && depth<=u64(c.cfg.max_prediction)
 gd.print_str(fmt.tprintf("REPLAY_SAMPLING_CONTROL later_welcome catchup_delta=%d serial_before=%d serial_after=%d depth=%d configured_lead=%d bounded=%v rejected=%d",c.stats.snapshot_catchups-before_catchups,before_serial,c.serial,depth,c.lead_ticks,self.control_ok,c.stats.rejected_packets))
 finish(self,true)
}
