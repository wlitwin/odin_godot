package replay_transport_trace

import sc "godot:replay/schema"
import tr "godot:replay/transport"

VERSION :: u32(1)
MAGIC :: u32(0x52505452)
Header :: struct {magic,version:u32,capabilities:Capabilities,entries,bytes:u64,digest:u64}

valid :: proc(log:^Log)->bool {
 if log==nil || !log.ready || log.error!=.None || .Mark in log.capabilities || log.limits.events<1 || log.limits.events>DEFAULT_LIMITS.events || log.limits.bytes<1 || log.limits.bytes>DEFAULT_LIMITS.bytes || len(log.entries)>log.limits.events || len(log.data)>log.limits.bytes {return false}
 offset:=u64(0)
 for e in log.entries {
  if e.operation>.Mark || e.channel>.Unreliable || e.offset!=offset || u64(e.size)>u64(len(log.data))-offset || e.count<0 || e.count>i64(max(i32)) || e.capacity>u64(max(i32)) {return false}
  if e.operation!=.Mark && e.operation not_in log.capabilities {return false}
  switch e.operation {
  case .Send:if e.returned>u8(tr.Send_Result.Invalid) || e.size>tr.MAX_PACKET_BYTES {return false}
  case .Receive:
   if e.returned>u8(tr.Receive_State.Disconnected) {return false}
   if tr.Receive_State(e.returned)==.Received {if e.count!=i64(e.size) || e.size>tr.MAX_PACKET_BYTES || u64(e.size)>e.capacity {return false}}
   else if e.size!=0 {return false}
  case .Status:if e.returned>u8(tr.Status.Connected) || e.size!=0 {return false}
  case .Connected:if e.returned>1 || e.size!=0 {return false}
  case .Poll,.Generation,.Close:if e.size!=0 {return false}
  case .Mark:
  }
  offset+=u64(e.size)
 }
 return offset==u64(len(log.data))
}
encode :: proc(log:^Log,allocator:=context.allocator)->([]u8,Error) {
 if !valid(log) {return nil,.Invalid}
 header_codec,entry_codec:sc.Schema
 defer sc.destroy(&header_codec);defer sc.destroy(&entry_codec)
 if sc.init(&header_codec,Header).error!=.None || sc.init(&entry_codec,Entry).error!=.None {return nil,.Invalid}
 size:=header_codec.wire_size+entry_codec.wire_size*len(log.entries)+len(log.data)
 out:=make([]u8,size,allocator);at:=header_codec.wire_size
 for e in log.entries {
  if sc.encode(&entry_codec,e,out[at:at+entry_codec.wire_size]).error!=.None {delete(out,allocator);return nil,.Invalid};at+=entry_codec.wire_size
 }
 copy(out[at:],log.data[:])
 header:=Header{MAGIC,VERSION,log.capabilities,u64(len(log.entries)),u64(len(log.data)),0}
 if sc.encode(&header_codec,header,out[:header_codec.wire_size]).error!=.None {delete(out,allocator);return nil,.Invalid}
 header.digest=sc.digest(out[:header_codec.wire_size-8]) ~ sc.digest(out[header_codec.wire_size:])
 sc.encode(&header_codec,header,out[:header_codec.wire_size])
 return out,.None
}
// Decode transactionally. Limits are checked before allocation; malformed input
// cannot replace a previously valid log. The digest detects corruption, not trust.
decode :: proc(log:^Log,bytes:[]u8,limits:=DEFAULT_LIMITS,allocator:=context.allocator)->Error {
 if limits.events<1 || limits.events>DEFAULT_LIMITS.events || limits.bytes<1 || limits.bytes>DEFAULT_LIMITS.bytes {return .Invalid}
 hc,ec:sc.Schema;defer sc.destroy(&hc);defer sc.destroy(&ec)
 if sc.init(&hc,Header).error!=.None || sc.init(&ec,Entry).error!=.None || len(bytes)<hc.wire_size {return .Invalid}
 h:Header
 if sc.decode(&hc,&h,bytes[:hc.wire_size]).error!=.None || h.magic!=MAGIC || h.version!=VERSION || .Mark in h.capabilities {return .Invalid}
 if h.entries>u64(limits.events) || h.bytes>u64(limits.bytes) {return .Capacity}
 size:=u64(hc.wire_size)+h.entries*u64(ec.wire_size)+h.bytes
 if size!=u64(len(bytes)) || (sc.digest(bytes[:hc.wire_size-8]) ~ sc.digest(bytes[hc.wire_size:]))!=h.digest {return .Invalid}
 candidate:Log;if !init(&candidate,limits,allocator) {return .Invalid};defer destroy(&candidate)
 candidate.capabilities=h.capabilities
 if resize(&candidate.entries,int(h.entries))!=nil || resize(&candidate.data,int(h.bytes))!=nil {return .Allocation}
 at:=hc.wire_size
 for &e in candidate.entries {
  if sc.decode(&ec,&e,bytes[at:at+ec.wire_size]).error!=.None {return .Invalid};at+=ec.wire_size
 }
 copy(candidate.data[:],bytes[at:]);if !valid(&candidate) {return .Invalid}
 destroy(log);log^=candidate;candidate={};return .None
}
