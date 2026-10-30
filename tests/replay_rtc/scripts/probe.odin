//gd:extends Node
//gd:class ReplayRtcProbe
package replay_rtc_probe

import "core:fmt"
import abi "godot:tests/replay_ptrcall_abi/checks"
import gd "godot:godot"
import "godot:gdext"
import tr "godot:replay/transport"
import transportgd "godot:replay/godot/transport"

ReplayRtcProbe :: struct {
 owner:gd.Node,
 rtc:transportgd.Rtc,
 wire:tr.Transport,
 ready,failed,room_reported,done:bool,
 started,last_send:u64,
 budget_deferrals:u32,
 sent,large,small,unreliable,seen,gone,verified:[17]bool,
 buffer:[tr.MAX_PACKET_BYTES]u8,
}
@(gd_method="borrowed_args")
replay_rtc_probe_start :: proc(self:^ReplayRtcProbe,role,url,room:gd.String) {
 abi.run()
 a,b,c:=probe_string(role),probe_string(url),probe_string(room);defer delete(a);defer delete(b);defer delete(c)
 if !transportgd.rtc_open(&self.rtc,{url=b,room=c,host=a=="host"}) {probe_fail(self,"open");return}
 self.wire=transportgd.rtc_transport(&self.rtc);self.ready=true;self.started=u64(gd.time_get_ticks_msec(gd.singleton_time()))
 gd.print_str("REPLAY_RTC_BOOT")
}
replay_rtc_probe_process :: proc(self:^ReplayRtcProbe,dt:f64) {
 if !self.ready || self.failed {return}
 tr.poll(&self.wire)
 now:=u64(gd.time_get_ticks_msec(gd.singleton_time()))
 if self.rtc.error!=.None {probe_fail(self,fmt.tprintf("adapter %v",self.rtc.error));return}
 if self.rtc.registered && !self.room_reported {self.room_reported=true;gd.print_str(fmt.tprintf("REPLAY_RTC_ROOM %s id=%d",self.rtc.room,self.rtc.id))}
 for id in 1..<17 {
  if tr.peer_connected(&self.wire,tr.Peer_Id(id)) {
   if !self.seen[id] {self.seen[id]=true;gd.print_str(fmt.tprintf("REPLAY_RTC_CONNECTED id=%d from=%d",self.rtc.id,id))}
   if !self.sent[id] {
    for &b,i in self.buffer {b=u8((i+int(self.rtc.id))%251)}
    if tr.send(&self.wire,tr.Peer_Id(id),.Reliable,self.buffer[:])!=.Sent {probe_fail(self,"large send");return}
    small:=[2]u8{0xac,u8(self.rtc.id)}
    if tr.send(&self.wire,tr.Peer_Id(id),.Reliable,small[:])!=.Sent {probe_fail(self,"small send");return}
    self.sent[id]=true
   }
   if now-self.last_send>=100 {
    bytes:=[3]u8{0xbe,0xef,u8(self.rtc.id)};tr.send(&self.wire,tr.Peer_Id(id),.Unreliable,bytes[:])
   }
  } else if self.seen[id] && !self.gone[id] {
   self.gone[id]=true;gd.print_str(fmt.tprintf("REPLAY_RTC_GONE id=%d from=%d",self.rtc.id,id))
  }
 }
 if now-self.last_send>=100 {self.last_send=now}
 for _ in 0..<128 {
  p:=tr.receive(&self.wire,self.buffer[:1]);if p.state==.Empty {break}
  if p.state!=.Buffer_Too_Small {probe_fail(self,"short receive did not retain payload");return}
  self.budget_deferrals+=1
  p=tr.receive(&self.wire,self.buffer[:])
  if p.state!=.Received || p.from<1 || p.from>=17 || p.from==self.rtc.id {probe_fail(self,"receive metadata");return}
  if p.channel==.Reliable {
   if !self.large[p.from] {
    if p.count!=tr.MAX_PACKET_BYTES {probe_fail(self,"reliable order");return}
    for b,i in self.buffer {if b!=u8((i+int(p.from))%251) {probe_fail(self,"large bytes");return}}
    self.large[p.from]=true
   } else {
    if p.count!=2 || self.buffer[0]!=0xac || self.buffer[1]!=u8(p.from) || self.small[p.from] {probe_fail(self,"small bytes/order");return}
    self.small[p.from]=true
   }
  } else {
   if p.count!=3 || self.buffer[0]!=0xbe || self.buffer[1]!=0xef || self.buffer[2]!=u8(p.from) {probe_fail(self,"unreliable bytes");return}
   self.unreliable[p.from]=true
  }
 }
 count:=0;for i in 1..<17 {if self.large[i] && self.small[i] && self.unreliable[i] {count+=1;if !self.verified[i] {self.verified[i]=true;gd.print_str(fmt.tprintf("REPLAY_RTC_VERIFIED id=%d from=%d",self.rtc.id,i))}}}
 if count>=2 && !self.done {
  if self.budget_deferrals<6 {probe_fail(self,"receive retention not exercised");return}
  self.done=true;gd.print_str(fmt.tprintf("REPLAY_RTC_DONE id=%d peers=%d retained=%d",self.rtc.id,count,self.budget_deferrals))
 }
 if !self.done && now-self.started>45000 {probe_fail(self,"timeout")}
}
replay_rtc_probe_exit_tree :: proc(self:^ReplayRtcProbe) {tr.close(&self.wire)}
probe_fail :: proc(self:^ReplayRtcProbe,reason:string) {self.failed=true;gd.print_str(fmt.tprintf("REPLAY_RTC_FAIL %s",reason))}
probe_string :: proc(value:gd.String)->string {
 value:=value;n:=gdext.string_to_utf8_chars(&value,nil,0);if n<0 || n>8192 {return ""}
 b:=make([]u8,int(n));if n>0 {gdext.string_to_utf8_chars(&value,cstring(raw_data(b)),n)};return string(b)
}

@(gd_method)
replay_rtc_probe_restart :: proc(self:^ReplayRtcProbe) {
 // Reuse the same adapter address, while every old Callable has been invalidated.
 url:=gd.new_string_odin(self.rtc.config.url);room:=gd.new_string_odin(self.rtc.room);role:=gd.new_string_odin("join")
 defer gd.free_string(url);defer gd.free_string(room);defer gd.free_string(role)
 owner:=self.owner;tr.close(&self.wire);self^={owner=owner}
 replay_rtc_probe_start(self,role,url,room)
 gd.print_str("REPLAY_RTC_RESTARTED")
}
