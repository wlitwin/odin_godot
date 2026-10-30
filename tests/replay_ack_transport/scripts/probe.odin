//gd:extends Node
//gd:class ReplayAckProbe
package replay_ack_probe
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import rgd "godot:replay/godot"
import v "godot:replay/view"

World :: struct {tick:u64,actions:u32,padding:[4096]u8}
ReplayAckProbe :: struct {
 owner:gd.Node,enet:rgd.Enet,base,wire:tr.Transport,clock:r.Clock,
 server:net.Server(World,u8,u8,u8,1),client:net.Client(World,u8,u8,u8,1),
 authority,ready,done,armed:bool,sequence,sent_at,elapsed,ack_reliable,ack_unreliable:u64,
}
model :: proc()->net.Model(World,u8,u8,u8,1) {
 return {action_timing=.Receipt,
 step=proc(w:^World,_:[1]u8,_:u64,_:u64,ctx:^r.Step(u8)) {w.tick=ctx.tick},
 action=proc(w:^World,_:u16,a:u8,ctx:^r.Step(u8))->bool {if a!=1 {return false};w.actions+=1;r.emit(ctx,1,1,1);return true},
 control_valid=proc(c:u8)->bool{return c==0},action_valid=proc(a:u8)->bool{return a==1},
 state_valid=proc(w:World)->bool {if w.actions>1 {return false};for b in w.padding {if b!=0 {return false}};return true},
 hold=proc(_:u8)->u8{return 0}}
}
send :: proc(user:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {
 self:=cast(^ReplayAckProbe)user
 meta,_,report:=sc.inspect(bytes)
 if self.armed && report.error==.None && meta.kind==11 {if channel==.Reliable {self.ack_reliable+=1} else {self.ack_unreliable+=1}}
 return tr.send(&self.base,to,channel,bytes)
}
receive :: proc(user:rawptr,bytes:[]u8)->tr.Received {self:=cast(^ReplayAckProbe)user;return tr.receive(&self.base,bytes)}
poll :: proc(user:rawptr) {self:=cast(^ReplayAckProbe)user;tr.poll(&self.base)}
status :: proc(user:rawptr)->tr.Status {self:=cast(^ReplayAckProbe)user;return tr.status(&self.base)}
connected :: proc(user:rawptr,id:tr.Peer_Id)->bool {self:=cast(^ReplayAckProbe)user;return tr.peer_connected(&self.base,id)}
generation :: proc(user:rawptr,id:tr.Peer_Id)->u64 {self:=cast(^ReplayAckProbe)user;return tr.peer_generation(&self.base,id)}

replay_ack_probe_ready :: proc(self:^ReplayAckProbe) {
 self.authority=gd.env_string("REPLAY_ACK_ROLE","")=="host"
 port:=gd.env_int("REPLAY_ACK_PORT",0);assert(port>0 && port<65536)
 assert(self.authority ? rgd.enet_host(&self.enet,u16(port),1,"127.0.0.1") : rgd.enet_join(&self.enet,"127.0.0.1",u16(port)))
 self.base=rgd.enet_transport(&self.enet);self.wire={user=self,send=send,receive=receive,poll=poll,status=status,connected=connected,generation=generation}
 cfg:=net.DEFAULT_CONFIG;cfg.content=0x41434b5445535431;cfg.unreliable_packet_limit=512;cfg.delta_snapshots=false
 if self.authority {assert(net.server_init(&self.server,r.Frame(World){},model(),self.wire,cfg)==.None)} else {
  assert(net.client_init(&self.client,model(),self.wire,net.Token{0=31},cfg=cfg)==.None)
 }
 assert(r.clock_init(&self.clock,60));self.ready=true
}
replay_ack_probe_process :: proc(self:^ReplayAckProbe,dt:f64) {
 if !self.ready || self.done {return}
 now:=gd.time_get_ticks_msec(gd.singleton_time())
 assert(self.authority ? net.server_pump(&self.server,now)==.None : net.client_pump(&self.client,now)==.None)
 count,valid:=r.clock_add(&self.clock,dt);assert(valid)
 for _ in 0..<count {
  if self.authority {assert(net.server_step(&self.server)==.None)} else if self.client.phase==.Running {
   error:=net.client_step(&self.client,0);assert(error==.None || error==.Capacity)
  }
  assert(r.clock_consume(&self.clock))
 }
 if !self.authority {
  changes:[256]v.Change(net.Net_Event(u8));for v.drain(&self.client.journal,changes[:])>0 {}
  outcomes:[8]net.Action_Outcome;n:=net.client_outcomes(&self.client,outcomes[:])
  for outcome in outcomes[:n] {assert(outcome.sequence==self.sequence && outcome.applied && !self.done);self.elapsed=now-self.sent_at;self.done=true}
 }
}
@(gd_method)
replay_ack_probe_arm :: proc(self:^ReplayAckProbe) {self.armed=true}
@(gd_method)
replay_ack_probe_issue :: proc(self:^ReplayAckProbe) {
 assert(!self.authority && self.sequence==0)
 sequence,error:=net.client_issue(&self.client,1);assert(error==.None)
 self.sequence,self.sent_at=sequence,gd.time_get_ticks_msec(gd.singleton_time())
}
@(gd_method)
replay_ack_probe_probe :: proc(self:^ReplayAckProbe,key:string)->gd.Int {
 switch key {
 case "ready":return gd.Int(self.ready && (self.authority || self.client.phase==.Running && self.client.snapshot_latest>2))
 case "done":return gd.Int(self.done)
 case "elapsed":return gd.Int(self.elapsed)
 case "sequence":return gd.Int(self.sequence)
 case "ack_reliable":return gd.Int(self.ack_reliable)
 case "ack_unreliable":return gd.Int(self.ack_unreliable)
 }
 return -1
}
replay_ack_probe_exit_tree :: proc(self:^ReplayAckProbe) {
 if self.authority {net.server_destroy(&self.server)} else {net.client_destroy(&self.client)}
 tr.close(&self.base)
}
