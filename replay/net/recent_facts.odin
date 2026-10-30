package replay_net
import "core:reflect"
import r "godot:replay"
import sc "godot:replay/schema"

// One small bundle every other tick, containing up to four recent facts. The
// reliable stream remains the guarantee. Batching avoids consuming one transport
// packet/credit per copied fact. Existing peer/global budgets still apply.
@(private)
server_recent_facts :: proc(s:^Server($S,$C,$A,$E,$N),index:int) {
 peer:=&s.peers[index]
 if !s.snapshot_tx[index].recent_facts_enabled || peer.recent_facts_sent==s.timeline.head || s.timeline.head==0 || s.timeline.head%2!=0 {return}
 peer.recent_facts_sent=s.timeline.head
 if s.snapshot_tx[index].compact_recent_facts {server_recent_facts_compact(s,index);return}
 limit:=min(s.cfg.unreliable_packet_limit,SNAPSHOT_PART_BYTES)
 cursor:=sc.HEADER_BYTES+s.codecs.recent_facts.wire_size;count:=u8(0)
 first:=s.timeline.head>3 ? s.timeline.head-3 : 1
 for tick:=first;tick<=s.timeline.head;tick+=1 {
  fact:=s.facts[tick%u64(s.cfg.history)];if fact.tick!=tick {continue}
  fact.generation,fact.serial=peer.generation,peer.serial
  if s.model.replication.id!=0 {
   historical,found:=r.read(&s.timeline,tick);if !found {continue}
   fact=replica_facts(s.model,historical,Recipient{peer.seat,peer.spectator},fact)
  }
  if cursor+2>=limit {break}
  meta:=sc.Envelope_Meta{kind=u16(Kind.Facts),epoch=s.cfg.epoch,tick=tick,content=s.cfg.content}
  size,ok:=pack_facts(&s.codecs,fact,meta,s.txb[cursor+2:limit]);if !ok {continue}
  s.txb[cursor],s.txb[cursor+1]=u8(size),u8(size>>8);cursor+=2+size;count+=1
 }
 if count==0 {return}
 header:=Recent_Facts_Header{peer.generation,peer.serial,count}
 body:=s.txb[sc.HEADER_BYTES:cursor]
 if sc.encode(&s.codecs.recent_facts,header,body[:s.codecs.recent_facts.wire_size]).error!=.None {return}
 meta:=sc.Envelope_Meta{kind=u16(Kind.Recent_Facts),epoch=s.cfg.epoch,tick=s.timeline.head,content=s.cfg.content}
 if sc.pack_bytes(s.codecs.recent_facts.fingerprint,meta,body,s.txb).error!=.None {return}
 if server_send(s,peer.connection,.Unreliable,s.txb[:cursor])==.Sent {s.stats.redundant_facts+=u64(count);s.stats.redundant_fact_bytes+=u64(cursor)}
}

@(private)
client_recent_facts :: proc(c:^Client($S,$C,$A,$E,$N),bytes:[]u8,expected:sc.Envelope_Meta) -> (error:Error) {
 meta,body,report:=sc.unpack_bytes(c.codecs.recent_facts.fingerprint,bytes,expected)
 header:Recent_Facts_Header;header_size:=c.codecs.recent_facts.wire_size
 if report.error!=.None || len(bytes)>min(c.cfg.unreliable_packet_limit,SNAPSHOT_PART_BYTES) || len(body)<header_size ||
    sc.decode(&c.codecs.recent_facts,&header,body[:header_size]).error!=.None || header.generation!=c.generation || header.serial!=c.serial || header.count==0 || header.count>4 {c.stats.rejected_packets+=1;return}
 spans:[4][2]int;cursor:=header_size;previous:u64
 // Validate the whole bundle before passing its independent facts through the
 // normal receiver, including exact scope, occurrence identity and retained data.
 for i in 0..<int(header.count) {
  if len(body)-cursor<2 {c.stats.rejected_packets+=1;return}
  size:=int(body[cursor])|int(body[cursor+1])<<8;cursor+=2
  if size>len(body)-cursor {c.stats.rejected_packets+=1;return}
  packet:Facts_Packet(E)
  fact_expected:=sc.Envelope_Meta{kind=u16(Kind.Facts),epoch=c.cfg.epoch,content=c.cfg.content}
  if !unpack_facts(&c.codecs,&packet,body[cursor:cursor+size],fact_expected) || packet.generation!=c.generation || packet.serial!=c.serial || packet.tick<=previous || packet.tick>meta.tick || meta.tick-packet.tick>3 {c.stats.rejected_packets+=1;return}
  previous=packet.tick
  for occurrence,j in packet.events[:packet.count] {
   if occurrence.id.epoch!=c.cfg.epoch || occurrence.id.tick!=packet.tick {c.stats.rejected_packets+=1;return}
   for prior in packet.events[:j] {if prior.id==occurrence.id {c.stats.rejected_packets+=1;return}}
  }
  slot:=&c.facts[packet.tick%u64(c.cfg.history)]
  if slot.tick==packet.tick && !reflect.equal(slot^,packet) {c.stats.rejected_packets+=1;return}
  spans[i]={cursor,size};cursor+=size
 }
 if cursor!=len(body) {c.stats.rejected_packets+=1;return}
 for span in spans[:header.count] {if err:=client_receive(c,body[span[0]:span[0]+span[1]]);err!=.None {return err}}
 return
}
