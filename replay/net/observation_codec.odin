package replay_net
import sc "godot:replay/schema"
import tr "godot:replay/transport"

// Independent sparse-zero encoding of the canonical Observation body. The
// bitmap has ceil(canonical_size/8) bytes; set bits select nonzero bytes in order.
// No packet references another packet or a runtime decoding baseline.
@(private)
observation_sparse_encode :: proc(canonical,dst:[]u8)->(int,bool) {
 bitmap:=(len(canonical)+7)/8;needed:=bitmap
 for b in canonical {if b!=0 {needed+=1}}
 if needed>=len(canonical) || needed>len(dst) {return needed,false}
 for &b in dst[:bitmap] {b=0}
 cursor:=bitmap
 for b,i in canonical {if b!=0 {dst[i/8]|=u8(1)<<uint(i%8);dst[cursor]=b;cursor+=1}}
 return needed,true
}

@(private)
observation_sparse_decode :: proc(canonical,body:[]u8)->bool {
 bitmap:=(len(canonical)+7)/8
 if len(body)<bitmap || len(body)>=len(canonical) {return false}
 if remainder:=len(canonical)%8;remainder!=0 && body[bitmap-1]>>uint(remainder)!=0 {return false}
 // Validate the entire representation before modifying the destination.
 cursor:=bitmap
 for i in 0..<len(canonical) {if body[i/8]&(u8(1)<<uint(i%8))!=0 {
  if cursor>=len(body) || body[cursor]==0 {return false};cursor+=1
 }}
 if cursor!=len(body) {return false}
 cursor=bitmap
 for &b,i in canonical {
  b=0
  if body[i/8]&(u8(1)<<uint(i%8))!=0 {b=body[cursor];cursor+=1}
 }
 return true
}

@(private)
compact_observation_decode :: proc(c:^Codecs,dst:^Observation_Packet($C),bytes:[]u8,expected:sc.Envelope_Meta,scratch:[]u8)->bool {
 _,body,report:=sc.unpack_bytes(c.observation.fingerprint,bytes,expected)
 if report.error!=.None || len(scratch)<c.observation.wire_size {return false}
 canonical:=scratch[:c.observation.wire_size]
 if !observation_sparse_decode(canonical,body) {return false}
 candidate:Observation_Packet(C)
 if sc.decode(&c.observation,&candidate,canonical).error!=.None {return false}
 dst^=candidate;return true
}

@(private)
client_send_observation :: proc(c:^Client($S,$C,$A,$E,$N),packet:Observation_Packet(C)) {
 if !permitted(c.cfg.require_permit,c.permit,c.cfg.epoch) {return}
 if c.compact_observations_enabled && c.compact_observations_negotiated {
  canonical:=c.input_scratch[:c.codecs.observation.wire_size]
  if sc.encode(&c.codecs.observation,packet,canonical).error!=.None {return}
  count,compact:=observation_sparse_encode(canonical,c.txb[sc.HEADER_BYTES:])
  if compact {
   meta:=sc.Envelope_Meta{kind=u16(Kind.Observation_Compact),epoch=c.cfg.epoch,tick=packet.sample.tick,content=c.cfg.content}
   if sc.pack_bytes(c.codecs.observation.fingerprint,meta,c.txb[sc.HEADER_BYTES:sc.HEADER_BYTES+count],c.txb).error!=.None {return}
   if tr.send(&c.wire,c.authority,.Unreliable,c.txb[:sc.HEADER_BYTES+count])==.Sent {
    c.stats.tx_packets+=1;c.stats.tx_bytes+=u64(sc.HEADER_BYTES+count)
    c.stats.compact_observations+=1;c.stats.observation_bytes_saved+=u64(len(canonical)-count)
   }
   return
  }
 }
 client_send(c,&c.codecs.observation,.Observation,packet,packet.sample.tick,.Unreliable)
}
