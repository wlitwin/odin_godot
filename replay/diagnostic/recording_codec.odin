package replay_diagnostic

import "core:mem"
import r "godot:replay"
import sc "godot:replay/schema"

// File = header envelope, base-frame envelope, then one envelope per tick.
// Every envelope is independently checksummed; the header declares exact total
// length/counts and each tick is stamped. This framing is not authentication.
@(private)
RECORDING_HEADER_KIND :: 0x5240
@(private)
RECORDING_BASE_KIND :: 0x5241
@(private)
RECORDING_TICK_KIND :: 0x5242
@(private)
Recording_Codecs :: struct {header,base,tick,event:sc.Schema,tick_fingerprint,file_fingerprint:u64}
@(private)
recording_codecs_init :: proc(c:^Recording_Codecs,$S,$I,$E:typeid,allocator:mem.Allocator)->bool {
 if sc.init(&c.header,Recording_Header,allocator=allocator).error!=.None ||
    sc.init(&c.base,r.Frame(S),allocator=allocator).error!=.None ||
    sc.init(&c.tick,Recorded_Tick(S,I),allocator=allocator).error!=.None ||
    sc.init(&c.event,r.Occurrence(E),allocator=allocator).error!=.None {return false}
 pair:=[2]u64{c.tick.fingerprint,c.event.fingerprint}
 // Encode the pair explicitly, independent of host endianness.
 bytes:[16]u8
 for value,index in pair {for b in 0..<8 {bytes[index*8+b]=u8(value>>uint(b*8))}}
 c.tick_fingerprint=sc.digest(bytes[:])
 // Even a zero-step file binds all three gameplay types and the format header.
 pair={c.header.fingerprint,c.base.fingerprint}
 for value,index in pair {for b in 0..<8 {bytes[index*8+b]=u8(value>>uint(b*8))}}
 c.file_fingerprint=sc.digest(bytes[:],c.tick_fingerprint)
 return true
}
@(private)
recording_codecs_destroy :: proc(c:^Recording_Codecs) {sc.destroy(&c.header);sc.destroy(&c.base);sc.destroy(&c.tick);sc.destroy(&c.event)}
@(private)
recording_wire_size :: proc(c:^Recording_Codecs,h:Recording_Header)->(int,bool) {
 if !recording_header_valid(h) {return 0,false}
 size:=u64(sc.HEADER_BYTES*2+c.header.wire_size+c.base.wire_size)+u64(h.ticks)*u64(sc.HEADER_BYTES+c.tick.wire_size)+u64(h.events)*u64(c.event.wire_size)
 return size<=MAX_RECORDING_BYTES ? int(size) : 0,size<=MAX_RECORDING_BYTES
}

recording_encode :: proc(a:^Recording($S,$I,$E),allocator:=context.allocator)->([]u8,Recording_Error) {
 if !recording_valid(a) {return nil,.Invalid}
 c:Recording_Codecs;defer recording_codecs_destroy(&c)
 if !recording_codecs_init(&c,S,I,E,allocator) {return nil,.Schema}
 size,bounded:=recording_wire_size(&c,a.header);if !bounded {return nil,.Capacity}
 for entry in a.ticks {if u64(c.tick.wire_size)+u64(entry.event_count)*u64(c.event.wire_size)>1024*1024 {return nil,.Capacity}}
 bytes:=make([]u8,size,allocator);committed:=false;defer if !committed {delete(bytes,allocator)}
 h:=a.header;h.total_bytes=u64(size)
 meta:=sc.Envelope_Meta{kind=RECORDING_HEADER_KIND,epoch=a.epoch,content=h.identity.content,tick=h.head}
 at:=sc.HEADER_BYTES+c.header.wire_size
 header_body:=bytes[sc.HEADER_BYTES:at]
 if sc.encode(&c.header,h,header_body).error!=.None || sc.pack_bytes(c.file_fingerprint,meta,header_body,bytes[:at]).error!=.None {return nil,.Codec}
 meta.kind=RECORDING_BASE_KIND;meta.tick=h.first
 if sc.pack(&c.base,a.base,meta,bytes[at:]).error!=.None {return nil,.Codec};at+=sc.HEADER_BYTES+c.base.wire_size
 for entry in a.ticks {
  body_size:=c.tick.wire_size+int(entry.event_count)*c.event.wire_size
  packet:=bytes[at:at+sc.HEADER_BYTES+body_size];body:=packet[sc.HEADER_BYTES:]
  if sc.encode(&c.tick,entry,body).error!=.None {return nil,.Codec}
  offset:=c.tick.wire_size
  for event in a.events[entry.event_start:entry.event_start+entry.event_count] {
   if sc.encode(&c.event,event,body[offset:]).error!=.None {return nil,.Codec};offset+=c.event.wire_size
  }
  meta.kind=RECORDING_TICK_KIND;meta.tick=entry.frame.tick
  if sc.pack_bytes(c.tick_fingerprint,meta,body,packet).error!=.None {return nil,.Codec}
  at+=len(packet)
 }
 if at!=size {return nil,.Codec}
 committed=true;return bytes,.None
}

// Strict bounded decode into an empty owner. Any failure leaves it empty.
// It never executes the simulation; verification is a separate explicit action.
recording_decode :: proc(a:^Recording($S,$I,$E),bytes:[]u8,identity:Recording_Context,allocator:=context.allocator)->Recording_Error {
 if !recording_empty(a) {return .Occupied}
 if !recording_context_valid(identity) {return .Context}
 if len(bytes)<sc.HEADER_BYTES || len(bytes)>MAX_RECORDING_BYTES {return .Capacity}
 c:Recording_Codecs;defer recording_codecs_destroy(&c)
 if !recording_codecs_init(&c,S,I,E,allocator) {return .Schema}
 header_size:=sc.HEADER_BYTES+c.header.wire_size
 if len(bytes)<header_size {return .Codec}
 meta,_,report:=sc.inspect(bytes[:header_size]);if report.error!=.None {return .Codec}
 tmp:=Recording(S,I,E){allocator=allocator,epoch=meta.epoch}
 _,header_body,header_report:=sc.unpack_bytes(c.file_fingerprint,bytes[:header_size],{kind=RECORDING_HEADER_KIND,epoch=meta.epoch,content=identity.content})
 if header_report.error!=.None || sc.decode(&c.header,&tmp.header,header_body).error!=.None {return .Codec}
 h:=tmp.header
 if h.identity!=identity {return .Context}
 size,bounded:=recording_wire_size(&c,h)
 if !bounded || size!=len(bytes) || h.total_bytes!=u64(size) || h.head!=meta.tick || !recording_memory_valid(h,S,I,E) {return .Invalid}
 at:=header_size;base_size:=sc.HEADER_BYTES+c.base.wire_size
 if _,report:=sc.unpack(&c.base,&tmp.base,bytes[at:at+base_size],{kind=RECORDING_BASE_KIND,epoch=meta.epoch,content=identity.content});report.error!=.None {return .Codec}
 base_meta,_,_:=sc.inspect(bytes[at:at+base_size]);if base_meta.tick!=h.first || tmp.base.tick!=h.first {return .Invalid};at+=base_size
 tmp.ticks=make([]Recorded_Tick(S,I),h.ticks,allocator);tmp.events=make([]r.Occurrence(E),h.events,allocator)
 committed:=false;defer if !committed {recording_destroy(&tmp)}
 event_at:=0
 for &entry,index in tmp.ticks {
  // Read the declared envelope length only after its fixed header is available.
  if len(bytes)-at<sc.HEADER_BYTES {return .Codec}
  body_size:u64
  for b in 0..<4 {body_size|=u64(bytes[at+40+b])<<uint(b*8)}
  if body_size>1024*1024 || body_size<u64(c.tick.wire_size) || body_size>u64(len(bytes)-at-sc.HEADER_BYTES) {return .Codec}
  packet:=bytes[at:at+sc.HEADER_BYTES+int(body_size)]
  stamp,body,report:=sc.unpack_bytes(c.tick_fingerprint,packet,{kind=RECORDING_TICK_KIND,epoch=meta.epoch,content=identity.content})
  if report.error!=.None {return .Codec}
  if sc.decode(&c.tick,&entry,body[:c.tick.wire_size]).error!=.None {return .Codec}
  tick:=h.first+u64(index)+1
  if stamp.tick!=tick || entry.frame.tick!=tick || entry.event_start!=u32(event_at) || entry.event_count>h.event_capacity || int(entry.event_count)>len(tmp.events)-event_at ||
     body_size!=u64(c.tick.wire_size)+u64(entry.event_count)*u64(c.event.wire_size) {return .Invalid}
  offset:=c.tick.wire_size
  for &event in tmp.events[event_at:event_at+int(entry.event_count)] {
   if sc.decode(&c.event,&event,body[offset:offset+c.event.wire_size]).error!=.None {return .Codec};offset+=c.event.wire_size
  }
  event_at+=int(entry.event_count);at+=len(packet)
 }
 tmp.ready=true
 if at!=len(bytes) || !recording_valid(&tmp) {return .Invalid}
 a^=tmp;committed=true;return .None
}
