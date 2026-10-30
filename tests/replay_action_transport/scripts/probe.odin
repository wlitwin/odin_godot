//gd:extends Node
//gd:class ReplayActionProbe
package replay_action_probe
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import v "godot:replay/view"
import transportgd "godot:replay/godot/transport"

World :: struct {tick:u64,actions:u32,padding:[4096]u8}
ReplayActionProbe :: struct {
 owner:gd.Node,enet:transportgd.Enet,base,wire:tr.Transport,clock:r.Clock,
 server:net.Server(World,u8,u8,u8,1),client:net.Client(World,u8,u8,u8,1),
 authority,ready,done,armed:bool,sequence,sent_at,elapsed,heartbeat_reliable,heartbeat_unreliable,primary,copies:u64,
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
 self:=cast(^ReplayActionProbe)user
 meta,_,report:=sc.inspect(bytes)
 if self.armed && report.error==.None {
  if meta.kind==9 {if channel==.Reliable {self.heartbeat_reliable+=1} else {self.heartbeat_unreliable+=1}}
  if meta.kind==5 {self.primary+=1};if meta.kind==25 {self.copies+=1}
 }
 return tr.send(&self.base,to,channel,bytes)
}
receive :: proc(user:rawptr,bytes:[]u8)->tr.Received {self:=cast(^ReplayActionProbe)user;return tr.receive(&self.base,bytes)}
poll :: proc(user:rawptr) {self:=cast(^ReplayActionProbe)user;tr.poll(&self.base)}
status :: proc(user:rawptr)->tr.Status {self:=cast(^ReplayActionProbe)user;return tr.status(&self.base)}
connected :: proc(user:rawptr,id:tr.Peer_Id)->bool {self:=cast(^ReplayActionProbe)user;return tr.peer_connected(&self.base,id)}
generation :: proc(user:rawptr,id:tr.Peer_Id)->u64 {self:=cast(^ReplayActionProbe)user;return tr.peer_generation(&self.base,id)}

replay_action_probe_ready :: proc(self:^ReplayActionProbe) {
 self.authority=gd.env_string("REPLAY_ACTION_ROLE","")=="host"
 port:=gd.env_int("REPLAY_ACTION_PORT",0);assert(port>0 && port<65536)
 assert(self.authority ? transportgd.enet_host(&self.enet,u16(port),1,"127.0.0.1") : transportgd.enet_join(&self.enet,"127.0.0.1",u16(port)))
 self.base=transportgd.enet_transport(&self.enet);self.wire={user=self,send=send,receive=receive,poll=poll,status=status,connected=connected,generation=generation}
 cfg:=net.DEFAULT_CONFIG;cfg.content=0x41434b5445535431;cfg.unreliable_packet_limit=512;cfg.delta_snapshots=false
 if self.authority {assert(net.server_init(&self.server,r.Frame(World){},model(),self.wire,cfg)==.None)} else {
  assert(net.client_init(&self.client,model(),self.wire,net.Token{0=31},cfg=cfg)==.None)
 }
 assert(r.clock_init(&self.clock,60));self.ready=true
}
replay_action_probe_process :: proc(self:^ReplayActionProbe,dt:f64) {
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
replay_action_probe_arm :: proc(self:^ReplayActionProbe) {self.armed=true}
@(gd_method)
replay_action_probe_issue :: proc(self:^ReplayActionProbe) {
 assert(!self.authority && self.sequence==0)
 sequence,error:=net.client_issue(&self.client,1);assert(error==.None)
 self.sequence,self.sent_at=sequence,gd.time_get_ticks_msec(gd.singleton_time())
}
@(gd_method)
replay_action_probe_probe :: proc(self:^ReplayActionProbe,key:string)->gd.Int {
 switch key {
 case "ready":return gd.Int(self.ready && (self.authority || self.client.phase==.Running && self.client.snapshot_latest>2))
 case "done":return gd.Int(self.done)
 case "elapsed":return gd.Int(self.elapsed)
 case "sequence":return gd.Int(self.sequence)
 case "heartbeat_reliable":return gd.Int(self.heartbeat_reliable)
 case "heartbeat_unreliable":return gd.Int(self.heartbeat_unreliable)
 case "primary":return gd.Int(self.primary)
 case "copies":return gd.Int(self.copies)
 case "actions":frame,_:=r.current(&self.server.timeline);return gd.Int(frame.state.actions)
 }
 return -1
}
replay_action_probe_exit_tree :: proc(self:^ReplayActionProbe) {
 if self.authority {net.server_destroy(&self.server)} else {net.client_destroy(&self.client)}
 tr.close(&self.base)
}
