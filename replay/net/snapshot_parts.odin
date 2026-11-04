package replay_net

import sc "godot:replay/schema"
import tr "godot:replay/transport"
import delta "godot:replay/delta"
import erasure "godot:replay/erasure"

// Small enough for Replay's RTC routing/fragment headers as well as an ENet
// datagram. The logical snapshot and canonical codecs remain unchanged.
SNAPSHOT_PARTS_FEATURE :: u64(1)
SNAPSHOT_LZ4_FEATURE :: u64(2)
RECENT_FACTS_FEATURE :: u64(4)
FACT_REPAIR_FEATURE :: u64(8)
SNAPSHOT_ERASURE_FEATURE :: u64(16)
SNAPSHOT_SHUFFLE_FEATURE :: u64(32)
RECENT_ACTIONS_FEATURE :: u64(64)
CHECKPOINT_COMPRESSION_FEATURE :: u64(128)
CHECKPOINT_SHUFFLE_FEATURE :: u64(256)
CHECKPOINT_RELIABLE_FEATURE :: u64(512)
OBSERVER_NAMES_FEATURE :: u64(1024)
OBSERVATION_COMPACT_FEATURE :: u64(2048)
RECENT_FACTS_COMPACT_FEATURE :: u64(4096)
SNAPSHOT_PART_BYTES :: 1024
SNAPSHOT_ASSEMBLIES :: 4
SNAPSHOT_PART_TIMEOUT_MS :: u64(2000)

@(private)
Snapshot_Assembly :: struct {
 id,tick,digest,started:u64,
 data,parity:[]u8,
 parity_mask:u64,
 mask:[4]u64,
 received,parts,part_bytes:int,
}

@(private)
client_features :: proc(c:^Client($S,$C,$A,$E,$N)) {
 if c.physics!=nil {c.features_sent=true;return}
 if c.features_sent {return}
 if !c.snapshot_parts_enabled {c.features_sent=true;return}
 features:=SNAPSHOT_PARTS_FEATURE|RECENT_FACTS_FEATURE|CHECKPOINT_COMPRESSION_FEATURE|CHECKPOINT_SHUFFLE_FEATURE|CHECKPOINT_RELIABLE_FEATURE|OBSERVER_NAMES_FEATURE
 if c.compact_recent_facts_enabled {features|=RECENT_FACTS_COMPACT_FEATURE}
 if c.lz4_snapshots_enabled {features|=SNAPSHOT_LZ4_FEATURE}
 if c.compact_observations_enabled && c.model.control_timing==.Latest_Observation && !c.spectator {features|=OBSERVATION_COMPACT_FEATURE}
 if c.fact_repair_enabled {features|=FACT_REPAIR_FEATURE}
 if c.action_copies_enabled {features|=RECENT_ACTIONS_FEATURE}
 if c.snapshot_erasure_enabled {features|=SNAPSHOT_ERASURE_FEATURE}
 if c.snapshot_shuffle_enabled && c.lz4_snapshots_enabled {features|=SNAPSHOT_SHUFFLE_FEATURE}
 packet:=Features_Packet{c.generation,c.serial,features,u16(min(c.cfg.unreliable_packet_limit,SNAPSHOT_PART_BYTES))}
 c.features_sent=client_send(c,&c.codecs.features,.Features,packet,c.timeline.head,.Reliable)==.Sent
}

// At most one encoded snapshot is retained per recipient. Backpressure resumes
// its remaining pieces before encoding another world; there is no stale-world
// application queue. IDs are reserved even if a reset abandons a partial send.
@(private)
server_snapshot_parts_flush :: proc(s:^Server($S,$C,$A,$E,$N),index:int) {
 peer:=&s.peers[index];tx:=&s.snapshot_tx[index]
 if tx.part_size==0 {return}
 lap,lap_valid:=profile_start(s.profile_clock)
 payload:=tx.part_bytes-sc.HEADER_BYTES-s.codecs.snapshot_part.wire_size
 parts:=(tx.part_size+payload-1)/payload
 groups:=(parts+erasure.DATA_SHARDS-1)/erasure.DATA_SHARDS
 total:=parts;if tx.erasure_enabled {total+=groups*erasure.PARITY_SHARDS}
 parity:[2][SNAPSHOT_PART_BYTES]u8;cached_group:=-1
 for tx.part_next<total {
  data_index,group,row:=tx.part_next,0,-1
  if tx.erasure_enabled {
   group=tx.part_next/(erasure.DATA_SHARDS+erasure.PARITY_SHARDS)
   within:=tx.part_next%(erasure.DATA_SHARDS+erasure.PARITY_SHARDS)
   count:=min(erasure.DATA_SHARDS,parts-group*erasure.DATA_SHARDS)
   if within<count {data_index=group*erasure.DATA_SHARDS+within} else {row=within-count}
  }
  at,count:=data_index*payload,0;kind:=Kind.Snapshot_Part;wire_index:=data_index
  source:[]u8
  if row<0 {count=min(payload,tx.part_size-at);source=tx.part_wire[at:at+count]} else {
   shards:[erasure.DATA_SHARDS][]u8
   count=min(payload,tx.part_size-group*erasure.DATA_SHARDS*payload)
   n:=min(erasure.DATA_SHARDS,parts-group*erasure.DATA_SHARDS)
   if cached_group!=group {
    for i in 0..<n {start:=(group*erasure.DATA_SHARDS+i)*payload;shards[i]=tx.part_wire[start:min(start+payload,tx.part_size)]}
    assert(erasure.encode(shards[:n],{parity[0][:count],parity[1][:count]}));cached_group=group
   }
   source=parity[row][:count];kind=.Snapshot_Parity;wire_index=group*erasure.PARITY_SHARDS+row
  }
  header:=Snapshot_Part_Header{peer.generation,peer.serial,tx.next_id,tx.part_digest,u32(tx.part_size),u16(wire_index),u16(tx.part_bytes)}
  body:=s.txb[sc.HEADER_BYTES:sc.HEADER_BYTES+s.codecs.snapshot_part.wire_size+count]
  if sc.encode(&s.codecs.snapshot_part,header,body[:s.codecs.snapshot_part.wire_size]).error!=.None {return}
  copy(body[s.codecs.snapshot_part.wire_size:],source)
  meta:=sc.Envelope_Meta{kind=u16(kind),epoch=s.cfg.epoch,tick=tx.part_tick,content=s.cfg.content}
  if sc.pack_bytes(s.codecs.snapshot_part.fingerprint,meta,body,s.txb).error!=.None {return}
  if server_send(s,peer.connection,.Unreliable,s.txb[:sc.HEADER_BYTES+len(body)])!=.Sent {return}
  tx.part_next+=1
  if row<0 {s.stats.snapshot_parts_sent+=1} else {s.stats.snapshot_parity_sent+=1;s.stats.snapshot_parity_bytes+=u64(sc.HEADER_BYTES+len(body))}
  // The recipient may ACK after the last data shard, before the last parity
  // shards clear backpressure. Retain its canonical value at that point.
  if row<0 && data_index==parts-1 && !tx.part_cached {
   profile_lap(&s.profile_metrics,.Snapshot_Send,s.profile_clock,&lap,&lap_valid,s.profile_user,s.profile_sample)
   slot:=tx.sent.next
   assert(delta.cache_note_prehashed(&tx.sent,tx.next_id,tx.scratch,tx.part_hash))
   tx.views[slot]={tx.next_id,tx.part_tick,s.now,true};tx.part_cached=true
   profile_lap(&s.profile_metrics,.Snapshot_Cache,s.profile_clock,&lap,&lap_valid,s.profile_user,s.profile_sample)
  }
 }
 profile_lap(&s.profile_metrics,.Snapshot_Send,s.profile_clock,&lap,&lap_valid,s.profile_user,s.profile_sample)
 tx.force_full=false;peer.snapshot_sent=tx.part_tick
 if tx.part_compressed {s.stats.delta_snapshots+=1;s.stats.snapshot_bytes_saved+=u64(sc.HEADER_BYTES+len(tx.scratch)-tx.part_size)} else {s.stats.full_snapshots+=1}
 if tx.part_lz4 {s.stats.lz4_snapshots+=1}
 if tx.part_shuffled {s.stats.shuffled_snapshots+=1;s.stats.shuffle_bytes_saved+=tx.part_shuffle_saved}
 s.stats.fragmented_snapshots+=1
 tx.part_size,tx.part_next=0,0
}

@(private)
client_part_drop :: proc(c:^Client($S,$C,$A,$E,$N),slot:^Snapshot_Assembly) {
 delete(slot.data,c.allocator);delete(slot.parity,c.allocator);slot^={}
}
@(private)
client_parts_reset :: proc(c:^Client($S,$C,$A,$E,$N)) {
 for &slot in c.snapshot_parts {client_part_drop(c,&slot)}
}
@(private)
client_parts_expire :: proc(c:^Client($S,$C,$A,$E,$N)) {
 for &slot in c.snapshot_parts {
  if slot.id!=0 && (slot.id<=c.snapshot_latest || c.now-slot.started>=SNAPSHOT_PART_TIMEOUT_MS) {
   client_part_drop(c,&slot);c.stats.snapshot_parts_expired+=1
  }
 }
}
@(private)
client_snapshot_part :: proc(c:^Client($S,$C,$A,$E,$N),bytes:[]u8,expected:sc.Envelope_Meta) {
 meta,body,report:=sc.unpack_bytes(c.codecs.snapshot_part.fingerprint,bytes,expected)
 header:Snapshot_Part_Header
 size:=c.codecs.snapshot_part.wire_size
 if report.error!=.None || len(bytes)>SNAPSHOT_PART_BYTES || len(body)<size ||
    sc.decode(&c.codecs.snapshot_part,&header,body[:size]).error!=.None ||
    header.generation!=c.generation || header.serial!=c.serial || header.id==0 ||
    header.part_bytes<512 || int(header.part_bytes)>min(SNAPSHOT_PART_BYTES,c.cfg.unreliable_packet_limit) || len(bytes)>int(header.part_bytes) ||
    header.total<sc.HEADER_BYTES || int(header.total)>min(tr.MAX_PACKET_BYTES,c.codecs.snapshot.wire_size+sc.HEADER_BYTES) {c.stats.rejected_packets+=1;return}
 if header.id<=c.snapshot_latest {return}
 payload:=int(header.part_bytes)-sc.HEADER_BYTES-size
 parts:=(int(header.total)+payload-1)/payload
 index:=int(header.index);parity_packet:=meta.kind==u16(Kind.Snapshot_Parity)
 groups:=(parts+erasure.DATA_SHARDS-1)/erasure.DATA_SHARDS
 if parts>256 {c.stats.rejected_packets+=1;return}
 if parity_packet {
  if !c.snapshot_erasure_enabled || index>=groups*erasure.PARITY_SHARDS || len(body)-size!=min(payload,int(header.total)-(index/erasure.PARITY_SHARDS)*erasure.DATA_SHARDS*payload) {c.stats.rejected_packets+=1;return}
  c.stats.snapshot_parity_received+=1
 } else {
  if index>=parts || len(body)-size!=min(payload,int(header.total)-index*payload) {c.stats.rejected_packets+=1;return}
  c.stats.snapshot_parts_received+=1
 }
 at,free,oldest:=-1,-1,0
 for slot,i in c.snapshot_parts {
  if slot.id==header.id {at=i;break}
  if slot.id==0 {free=i}
  if slot.id<c.snapshot_parts[oldest].id {oldest=i}
 }
 if at<0 {
  if free>=0 {at=free} else {
   if header.id<c.snapshot_parts[oldest].id {return}
   at=oldest;client_part_drop(c,&c.snapshot_parts[at]);c.stats.snapshot_parts_expired+=1
  }
  c.snapshot_parts[at]={id=header.id,tick=meta.tick,digest=header.digest,started=c.now,
    data=make([]u8,int(header.total),c.allocator),parts=parts,part_bytes=int(header.part_bytes)}
 }
 slot:=&c.snapshot_parts[at]
 if len(slot.data)!=int(header.total) || slot.tick!=meta.tick || slot.digest!=header.digest || slot.part_bytes!=int(header.part_bytes) {
  client_part_drop(c,slot);c.stats.rejected_packets+=1;return
 }
 group:=index/erasure.DATA_SHARDS
 if parity_packet {
  group=index/erasure.PARITY_SHARDS
  if slot.parity==nil {slot.parity=make([]u8,groups*erasure.PARITY_SHARDS*payload,c.allocator)}
  offset:=index*payload;incoming:=body[size:];bit:=u64(1)<<uint(index)
  if slot.parity_mask&bit!=0 {
   for value,i in incoming {if value!=slot.parity[offset+i] {client_part_drop(c,slot);c.stats.rejected_packets+=1;return}}
   return
  }
  copy(slot.parity[offset:offset+len(incoming)],incoming);slot.parity_mask|=bit
 } else {
  offset:=index*payload;incoming:=body[size:];word:=index/64;bit:=u64(1)<<uint(index%64)
  if slot.mask[word]&bit!=0 {
   for value,i in incoming {if value!=slot.data[offset+i] {client_part_drop(c,slot);c.stats.rejected_packets+=1;return}}
   return
  }
  copy(slot.data[offset:offset+len(incoming)],incoming);slot.mask[word]|=bit;slot.received+=1
 }
 if c.snapshot_erasure_enabled {client_parts_recover(c,slot,group,payload)}
 // The scoped, validated part already proves authority progress, even while
 // other parts/facts prevent using its world. Do not sample into that past.
 c.authority_tick_seen=max(c.authority_tick_seen,meta.tick)
 if slot.received!=slot.parts {return}
 defer client_part_drop(c,slot)
 if sc.digest(slot.data)!=slot.digest {c.stats.rejected_packets+=1;return}
 inner,_,inner_report:=sc.inspect(slot.data)
 if inner_report.error!=.None || inner.epoch!=c.cfg.epoch || inner.content!=c.cfg.content || inner.tick!=slot.tick {
  c.stats.rejected_packets+=1;return
 }
 content:=slot.data[sc.HEADER_BYTES:]
 compressed:=inner.kind==u16(Kind.Snapshot_Delta) || snapshot_lz4_kind(inner.kind)
 if (inner.kind!=u16(Kind.Snapshot) && !compressed) || len(content)<(compressed ? 40 : 8) ||
    get64(compressed ? content[32:40] : content[:8])!=slot.id {c.stats.rejected_packets+=1;return}
 client_snapshot(c,slot.data,inner,compressed)
}

@(private)
client_parts_recover :: proc(c:^Client($S,$C,$A,$E,$N),slot:^Snapshot_Assembly,group,payload:int) {
 present:=u8((slot.parity_mask>>uint(group*erasure.PARITY_SHARDS))&3)
 if present==0 {return}
 first:=group*erasure.DATA_SHARDS;n:=min(erasure.DATA_SHARDS,slot.parts-first)
 missing:=u8(0);count:=0;shards:[erasure.DATA_SHARDS][]u8
 for i in 0..<n {
  index:=first+i;start:=index*payload;shards[i]=slot.data[start:min(start+payload,len(slot.data))]
  if slot.mask[index/64]&(u64(1)<<uint(index%64))==0 {missing|=u8(1)<<uint(i);count+=1}
 }
 if count==0 || count>2 || count==2 && present!=3 {return}
 width:=len(shards[0]);start:=group*erasure.PARITY_SHARDS*payload
 if !erasure.recover(shards[:n],{slot.parity[start:start+width],slot.parity[start+payload:start+payload+width]},missing,present) {return}
 for i in 0..<n {if missing&(u8(1)<<uint(i))!=0 {index:=first+i;slot.mask[index/64]|=u64(1)<<uint(index%64);slot.received+=1;c.stats.snapshot_shards_recovered+=1}}
}
