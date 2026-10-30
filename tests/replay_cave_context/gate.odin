package replay_cavecrawl
import gd "godot:godot"
import net "godot:replay/net"
#assert(net.PROTOCOL_VERSION==7)
// Protocol-7 Observation kind; the production packet enum is private.
OBSERVATION_KIND :: u16(14)
OBSERVATION_COMPACT_KIND :: u16(26)
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import rgd "godot:replay/godot"
import game "godot:examples/replay_cavecrawl/shared/owner_cave"

Context_Gate :: struct {base:tr.Transport,active,blocked:bool,dropped:u64}
context_gate_open :: proc(self:^ReplayCave) {
 if self.session.authority || self.session.client.spectator {return}
 gate:=&self.context_gate[0];gate.base=self.session.client.wire;gate.active=true
 self.session.client.wire={user=gate,
  send=proc(user:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {
   g:=cast(^Context_Gate)user;meta,_,report:=sc.inspect(bytes)
   if g.blocked && report.error==.None && (meta.kind==OBSERVATION_KIND || meta.kind==OBSERVATION_COMPACT_KIND) {g.dropped+=1;return .Sent}
   return tr.send(&g.base,to,channel,bytes)
  },
  receive=proc(user:rawptr,dst:[]u8)->tr.Received{return tr.receive(&(cast(^Context_Gate)user).base,dst)},
  poll=proc(user:rawptr){tr.poll(&(cast(^Context_Gate)user).base)},
  status=proc(user:rawptr)->tr.Status{return tr.status(&(cast(^Context_Gate)user).base)},
  connected=proc(user:rawptr,peer:tr.Peer_Id)->bool{return tr.peer_connected(&(cast(^Context_Gate)user).base,peer)},
  generation=proc(user:rawptr,peer:tr.Peer_Id)->u64{return tr.peer_generation(&(cast(^Context_Gate)user).base,peer)},
 }
}
context_gate_close :: proc(self:^ReplayCave) {
 if self.context_gate[0].active {self.session.client.wire=self.context_gate[0].base;self.context_gate[0].active=false}
}
@(gd_method)
replay_cave_context_block :: proc(self:^ReplayCave,value:bool) {self.context_gate[0].blocked=value}
@(gd_method)
replay_cave_context_local_x :: proc(self:^ReplayCave)->gd.Float {return gd.Float(self.motion.avatar.position[0])}
@(gd_method)
replay_cave_context_dropped :: proc(self:^ReplayCave)->gd.Int {return gd.Int(self.context_gate[0].dropped)}
@(gd_method)
replay_cave_context_legacy_loot :: proc(self:^ReplayCave) {
 // Explicit O1-compatible accepted-pose semantics through the ordinary action
 // protocol. Only this comparison request bypasses the UI's new context capture.
 rgd.session_issue(self.session,game.Action{verb=.Take,index=0,origin_kind=.Accepted_Pose})
}
