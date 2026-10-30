package replay_transport

import "core:mem"

FRAGMENT_HEADER :: 20
Fragment_Config :: struct {mtu, messages, tx_bytes, rx_bytes, packets_per_poll: int, timeout_ms: u64}
DEFAULT_FRAGMENT_CONFIG :: Fragment_Config{1200,32,1024*1024,2*1024*1024,128,2000}
Fragment_Stats :: struct {tx_packets, rx_packets, rejected, expired, assembled, deferred, retired, queue_limited: u64}
Fragments :: struct {
 ready: bool,
 unreliable_queue_packets: int,
 allocator: mem.Allocator,
 base: Transport,
 cfg: Fragment_Config,
 clock_user: rawptr,
 clock: proc(user:rawptr)->u64,
 now,next_id: u64,
 tx: []Fragment_Tx,
 rx: []Fragment_Rx,
 delivered: map[Fragment_Key]u64,
 tx_bytes,rx_bytes,remaining,rx_cursor: int,
 pending: bool,
 packet: Received,
 buffer,send_buffer: []u8,
 stats: Fragment_Stats,
}
@(private)
Fragment_Tx :: struct {id,generation:u64,to:Peer_Id,channel:Channel,data:[]u8,next:u16}
@(private)
Fragment_Rx :: struct {id,mask,started,generation:u64,from:Peer_Id,channel:Channel,data:[]u8,parts:u16,complete:bool}
@(private)
Fragment_Key :: struct {peer:Peer_Id,channel:Channel,generation:u64}

fragments_init :: proc(f:^Fragments,base:Transport,clock:proc(user:rawptr)->u64,user:rawptr=nil,
                       cfg:=DEFAULT_FRAGMENT_CONFIG,allocator:=context.allocator)->bool {
 if f.ready || clock==nil || cfg.mtu<1044 || cfg.mtu>8192 || cfg.messages<1 || cfg.messages>128 || cfg.tx_bytes<MAX_PACKET_BYTES ||
    cfg.tx_bytes>16*1024*1024 || cfg.rx_bytes<MAX_PACKET_BYTES || cfg.rx_bytes>16*1024*1024 || cfg.packets_per_poll<1 || cfg.packets_per_poll>1024 || cfg.timeout_ms<100 || cfg.timeout_ms>120000 {return false}
 f.allocator,f.base,f.cfg,f.clock,f.clock_user=allocator,base,cfg,clock,user
 f.tx=make([]Fragment_Tx,cfg.messages,allocator);f.rx=make([]Fragment_Rx,cfg.messages,allocator)
 f.delivered=make(map[Fragment_Key]u64,allocator)
 f.buffer=make([]u8,MAX_PACKET_BYTES,allocator);f.send_buffer=make([]u8,cfg.mtu,allocator)
 f.ready=true;return true
}
// Local queue bound in raw datagram units, per destination. Zero retains the
// configured message/byte limits alone. Set before admitting transmit work.
fragments_limit_unreliable :: proc(f:^Fragments,packets:int)->bool {
 if !f.ready || packets<0 || packets>1024 {return false}
 for item in f.tx {if item.id!=0 {return false}}
 f.unreliable_queue_packets=packets;return true
}
fragments_destroy :: proc(f:^Fragments) {
 for item in f.tx {delete(item.data,f.allocator)};for item in f.rx {delete(item.data,f.allocator)}
 delete(f.delivered);delete(f.tx,f.allocator);delete(f.rx,f.allocator);delete(f.buffer,f.allocator);delete(f.send_buffer,f.allocator);f^={}
}
fragments_transport :: proc(f:^Fragments)->Transport {
 return {user=f,send=fragment_send,receive=fragment_receive,poll=fragment_poll,status=fragment_status,connected=fragment_connected,generation=fragment_generation,close=fragment_close}
}
@(private)
fragment_send :: proc(user:rawptr,to:Peer_Id,channel:Channel,bytes:[]u8)->Send_Result {
 f:=cast(^Fragments)user
 if !f.ready || !peer_connected(&f.base,to) {return .Disconnected}
 if len(bytes)<1 || len(bytes)>MAX_PACKET_BYTES || channel>.Unreliable {return .Invalid}
 if f.next_id==max(u64) || len(bytes)>f.cfg.tx_bytes-f.tx_bytes {return .Backpressure}
 if channel==.Unreliable && f.unreliable_queue_packets>0 {
  payload:=f.cfg.mtu-FRAGMENT_HEADER;queued:=0
  for item in f.tx {if item.id!=0 && item.to==to && item.channel==channel {queued+=(len(item.data)+payload-1)/payload-int(item.next)}}
  // One large logical message may exceed the pacing bound by itself; it must
  // still remain sendable. Existing total byte/message limits always apply.
  needed:=(len(bytes)+payload-1)/payload
  if queued>0 && queued+needed>f.unreliable_queue_packets {f.stats.queue_limited+=1;return .Backpressure}
 }
 at:=-1;for item,i in f.tx {if item.id==0 {at=i;break}};if at<0 {return .Backpressure}
 data:=make([]u8,len(bytes),f.allocator);copy(data,bytes);f.next_id+=1
 f.tx[at]={id=f.next_id,generation=peer_generation(&f.base,to),to=to,channel=channel,data=data};f.tx_bytes+=len(bytes)
 return .Sent
}
@(private)
fragment_poll :: proc(user:rawptr) {
 f:=cast(^Fragments)user;if !f.ready {return}
 now:=f.clock(f.clock_user);if now<f.now {return};f.now=now
 poll(&f.base)
 fragment_prune_generations(f)
 for &item in f.rx {
  if item.id!=0 && ((!item.complete && item.channel==.Unreliable && now-item.started>=f.cfg.timeout_ms) || !peer_connected(&f.base,item.from)) {fragment_drop_rx(f,&item);f.stats.expired+=1}
 }
 for key in f.delivered {if !peer_connected(&f.base,key.peer) {delete_key(&f.delivered,key)}}
 f.remaining=f.cfg.packets_per_poll
 fragment_ingest(f)
 budget:=f.cfg.packets_per_poll
 blocked:[128]bool
 for budget>0 {
  at:=-1
  for item,i in f.tx {if item.id!=0 && !blocked[i] && (at<0 || item.id<f.tx[at].id) {at=i}}
  if at<0 {break}
  item:=&f.tx[at]
  if !peer_connected(&f.base,item.to) || item.generation!=peer_generation(&f.base,item.to) {fragment_drop_tx(f,item);continue}
  payload:=f.cfg.mtu-FRAGMENT_HEADER;parts:=(len(item.data)+payload-1)/payload
  for int(item.next)<parts && budget>0 {
   index:=int(item.next);start:=index*payload;size:=min(payload,len(item.data)-start)
   dst:=f.send_buffer;dst[0],dst[1],dst[2],dst[3]='R','P','F',1
   fragment_put(dst[4:12],item.id);fragment_put(dst[12:16],u64(len(item.data)));fragment_put(dst[16:18],u64(index));fragment_put(dst[18:20],u64(parts))
   copy(dst[FRAGMENT_HEADER:FRAGMENT_HEADER+size],item.data[start:start+size])
   result:=send(&f.base,item.to,item.channel,dst[:FRAGMENT_HEADER+size])
   if result!=.Sent {
    f.stats.deferred+=1
    for other,i in f.tx {if other.id!=0 && other.to==item.to && other.channel==item.channel {blocked[i]=true}}
    break
   }
   item.next+=1;budget-=1;f.stats.tx_packets+=1
  }
  if int(item.next)==parts {fragment_drop_tx(f,item)}
  if budget==0 {break}
 }
}
@(private)
fragment_ingest :: proc(f:^Fragments) {
 for f.remaining>0 {
  packet:=f.packet
  if !f.pending {packet=receive(&f.base,f.buffer)}
  if packet.state==.Empty || packet.state==.Disconnected {return}
  if packet.state!=.Received {f.stats.rejected+=1;return}
  if !f.pending {f.stats.rx_packets+=1;f.remaining-=1}
  f.pending=false
  bytes:=f.buffer[:packet.count]
  if len(bytes)<FRAGMENT_HEADER || len(bytes)>f.cfg.mtu || packet.channel>.Unreliable || bytes[0]!='R' || bytes[1]!='P' || bytes[2]!='F' || bytes[3]!=1 || !peer_connected(&f.base,packet.from) {f.stats.rejected+=1;continue}
  id,total,index,parts:=fragment_get(bytes[4:12]),fragment_get(bytes[12:16]),fragment_get(bytes[16:18]),fragment_get(bytes[18:20])
  payload:=f.cfg.mtu-FRAGMENT_HEADER
  if id==0 || total==0 || total>MAX_PACKET_BYTES || parts!=(total+u64(payload)-1)/u64(payload) || parts>64 || index>=parts ||
     len(bytes)-FRAGMENT_HEADER!=min(payload,int(total)-int(index)*payload) {f.stats.rejected+=1;continue}
  if packet.channel==.Reliable && id<=f.delivered[Fragment_Key{packet.from,packet.channel,packet.generation}] {continue}
  at:=-1;free:=-1
  for item,i in f.rx {if item.id==id && item.from==packet.from && item.channel==packet.channel {at=i;break};if item.id==0 {free=i}}
  if at<0 {
   if packet.channel==.Reliable {
    out_of_order:=false
    for item in f.rx {if item.id!=0 && item.from==packet.from && item.channel==packet.channel && !item.complete {out_of_order=true;break}}
    if out_of_order {f.stats.rejected+=1;continue}
   }
   if free<0 || int(total)>f.cfg.rx_bytes-f.rx_bytes {
    if packet.channel==.Reliable {f.pending,f.packet=true,packet;return}
    f.stats.rejected+=1;continue
   }
   at=free;f.rx[at]={id=id,generation=packet.generation,from=packet.from,channel=packet.channel,data=make([]u8,int(total),f.allocator),parts=u16(parts),started=f.now};f.rx_bytes+=int(total)
  }
  item:=&f.rx[at]
  if len(item.data)!=int(total) || item.parts!=u16(parts) {f.stats.rejected+=1;continue}
  start:=int(index)*payload;incoming:=bytes[FRAGMENT_HEADER:];bit:=u64(1)<<uint(index)
  if item.mask&bit!=0 {
   equal:=true;for b,i in incoming {if item.data[start+i]!=b {equal=false;break}}
   if !equal {fragment_drop_rx(f,item);f.stats.rejected+=1};continue
  }
  copy(item.data[start:start+len(incoming)],incoming);item.mask|=bit
  complete_mask:=parts==64 ? max(u64) : (u64(1)<<uint(parts))-1
  if item.mask==complete_mask {item.complete=true;f.stats.assembled+=1}
 }
}
@(private)
fragment_receive :: proc(user:rawptr,dst:[]u8)->Received {
 f:=cast(^Fragments)user;if !f.ready {return {state=.Disconnected}}
 fragment_prune_generations(f)
 fragment_ingest(f)
 for n in 0..<len(f.rx) {
  at:=(f.rx_cursor+n)%len(f.rx);item:=&f.rx[at];if item.id==0 || !item.complete {continue}
  earlier:=false
  if item.channel==.Reliable {for other in f.rx {if other.id!=0 && other.id<item.id && other.from==item.from && other.channel==item.channel {earlier=true;break}}}
  if earlier {continue}
  packet:=Received{state=.Received,from=item.from,generation=item.generation,channel=item.channel,count=len(item.data)}
  if len(dst)<len(item.data) {packet.state=.Buffer_Too_Small;return packet}
  if item.channel==.Reliable {
   key:=Fragment_Key{item.from,item.channel,item.generation}
   if _,exists:=f.delivered[key];!exists && len(f.delivered)>=f.cfg.messages {return {state=.Empty}}
   f.delivered[key]=item.id
  }
  copy(dst,item.data);fragment_drop_rx(f,item);f.rx_cursor=(at+1)%len(f.rx)
  return packet
 }
 return {state=status(&f.base)==.Disconnected ? .Disconnected : .Empty}
}
@(private)
fragment_drop_tx :: proc(f:^Fragments,item:^Fragment_Tx) {f.tx_bytes-=len(item.data);delete(item.data,f.allocator);item^={}}
@(private)
fragment_drop_rx :: proc(f:^Fragments,item:^Fragment_Rx) {f.rx_bytes-=len(item.data);delete(item.data,f.allocator);item^={}}
@(private)
fragment_status :: proc(user:rawptr)->Status {f:=cast(^Fragments)user;return f.ready ? status(&f.base) : .Disconnected}
@(private)
fragment_connected :: proc(user:rawptr,peer:Peer_Id)->bool {f:=cast(^Fragments)user;return f.ready && peer_connected(&f.base,peer)}
@(private)
fragment_close :: proc(user:rawptr) {fragments_destroy(cast(^Fragments)user)}
@(private)
fragment_put :: proc(dst:[]u8,value:u64) {for &b,i in dst {b=u8(value>>uint(i*8))}}
@(private)
fragment_get :: proc(src:[]u8)->u64 {v:=u64(0);for b,i in src {v|=u64(b)<<uint(i*8)};return v}

@(private)
fragment_generation :: proc(user:rawptr,peer:Peer_Id)->u64 {return peer_generation(&(cast(^Fragments)user).base,peer)}
@(private)
fragment_prune_generations :: proc(f:^Fragments) {
 for &item in f.rx {if item.id!=0 && item.generation!=peer_generation(&f.base,item.from) {fragment_drop_rx(f,&item);f.stats.retired+=1}}
 for &item in f.tx {if item.id!=0 && item.generation!=peer_generation(&f.base,item.to) {fragment_drop_tx(f,&item);f.stats.retired+=1}}
 for key in f.delivered {if key.generation!=peer_generation(&f.base,key.peer) {delete_key(&f.delivered,key)}}
 if f.pending && f.packet.generation!=peer_generation(&f.base,f.packet.from) {f.pending=false;f.packet={};f.stats.retired+=1}
}
