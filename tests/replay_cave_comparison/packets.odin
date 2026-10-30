package replay_cavecrawl
import gd "godot:godot"
import tr "godot:replay/transport"
import sc "godot:replay/schema"

Packet_Meter :: struct {base:tr.Transport,active:bool,counts,bytes:[64]u64,observation_body,observation_sparse:u64}
packet_meter:Packet_Meter
packet_meter_begin :: proc(self:^ReplayCave) {
 if gd.env_int("CAVE_COMPARE_PACKETS",0)!=1 {return}
 assert(self.session.link.ready)
 packet_meter={base=self.session.link.router.wire,active=true}
 self.session.link.router.wire={user=&packet_meter,
  send=proc(user:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {
   meter:=cast(^Packet_Meter)user;result:=tr.send(&meter.base,to,channel,bytes)
   if result==.Sent {
    meta,_,report:=sc.inspect(bytes);kind:=int(meta.kind)
    if report.error!=.None || kind>=63 {kind=63}
    meter.counts[kind]+=1;meter.bytes[kind]+=u64(len(bytes))
    if report.error==.None && kind==14 {
     body:=bytes[sc.HEADER_BYTES:];nonzero:=0;for b in body {if b!=0 {nonzero+=1}}
     meter.observation_body+=u64(len(body))
     meter.observation_sparse+=u64(min(len(body),(len(body)+7)/8+nonzero))
    }
   }
   return result
  },
  receive=proc(user:rawptr,dst:[]u8)->tr.Received{return tr.receive(&(cast(^Packet_Meter)user).base,dst)},
  poll=proc(user:rawptr){tr.poll(&(cast(^Packet_Meter)user).base)},
  status=proc(user:rawptr)->tr.Status{return tr.status(&(cast(^Packet_Meter)user).base)},
  connected=proc(user:rawptr,peer:tr.Peer_Id)->bool{return tr.peer_connected(&(cast(^Packet_Meter)user).base,peer)},
  generation=proc(user:rawptr,peer:tr.Peer_Id)->u64{return tr.peer_generation(&(cast(^Packet_Meter)user).base,peer)},
 }
}
packet_meter_end :: proc(self:^ReplayCave) {if packet_meter.active {self.session.link.router.wire=packet_meter.base;packet_meter.active=false}}
@(gd_method)
replay_cave_bench_packet :: proc(self:^ReplayCave,kind:gd.Int,bytes:bool)->gd.Int {
 if kind==-1 {return gd.Int(packet_meter.observation_body)}
 if kind==-2 {return gd.Int(packet_meter.observation_sparse)}
 if kind<0 || kind>=64 {return -1}
 return gd.Int(bytes ? packet_meter.bytes[kind] : packet_meter.counts[kind])
}
