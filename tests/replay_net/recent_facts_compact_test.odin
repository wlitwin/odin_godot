package replay_net_test

import "core:testing"
import "core:reflect"
import net "godot:replay/net"
import r "godot:replay"
import tr "godot:replay/transport"
import sc "godot:replay/schema"

#assert(net.PROTOCOL_VERSION==7)

recent_compact_capture :: proc(f:^Fixture,events:bool=false)->[]u8 {
 for _ in 0..<40 {fixture_step(f)}
 assert(tr.memory_advance(&f.network,f.clock))
 assert(net.client_pump(&f.clients[0],f.clock*1000/60)==.None)
 if events {_,err:=net.client_issue(&f.clients[0],Action{take=true});assert(err==.None)}
 for _ in 0..<4 {
  tr.memory_advance(&f.network,f.clock)
  assert(net.server_pump(&f.server,f.clock*1000/60)==.None)
  assert(net.server_step(&f.server)==.None);f.clock+=1
 }
 packet:[]u8;newest:u64
 for p,i in f.network.packets {if p.active && p.to==2 && p.from==1 {
  bytes:=f.network.bytes[i*f.network.config.packet_bytes:i*f.network.config.packet_bytes+p.count]
  meta,_,report:=sc.inspect(bytes)
  if report.error==.None && meta.kind==27 && meta.tick>newest {
   delete(packet);packet=make([]u8,p.count);copy(packet,bytes);newest=meta.tick
  }
 }}
 assert(packet!=nil)
 for &p in f.network.packets {if p.to==2 {p.active=false}}
 return packet
}

recent_compact_checksum :: proc(packet:[]u8) {
 sum:=sc.digest(packet[sc.HEADER_BYTES:],sc.digest(packet[:44]))
 for i in 0..<8 {packet[44+i]=u8(sum>>uint(i*8))}
}
recent_compact_deliver :: proc(f:^Fixture,packet:[]u8) {
 assert(tr.send(&f.server.wire,2,.Unreliable,packet)==.Sent)
 assert(tr.memory_advance(&f.network,f.clock))
 assert(net.client_pump(&f.clients[0],f.clock*1000/60)==.None)
}

@(test)
compact_recent_facts_decode_without_prior_bundles_and_accept_reliable_duplicates :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f,action_timing=.Receipt);defer fixture_destroy(&f)
 packet:=recent_compact_capture(&f,true);defer delete(packet)
 c:=&f.clients[0];meta,_,_:=sc.inspect(packet)
 testing.expect(t,meta.tick>c.facts_contiguous)
 recent_compact_deliver(&f,packet)
 testing.expect_value(t,c.facts_contiguous,meta.tick)
 found:=false
 for tick:=meta.tick-3;tick<=meta.tick;tick+=1 {
  expected:=f.server.facts[tick%u64(f.server.cfg.history)]
  expected.generation,expected.serial=c.generation,c.serial
  testing.expect(t,reflect.equal(c.facts[tick%u64(c.cfg.history)],expected))
  found=found || expected.count>0
 }
 testing.expect(t,found)
 recent_compact_deliver(&f,packet)
 // Deliver the same logical facts again in their original reliable encoding.
 for tick:=meta.tick-3;tick<=meta.tick;tick+=1 {
  fact:=f.server.facts[tick%u64(f.server.cfg.history)]
  header:=struct {generation,serial,tick:u64,count:u16}{c.generation,c.serial,tick,fact.count}
  header_schema:sc.Schema;assert(sc.init(&header_schema,type_of(header)).error==.None);defer sc.destroy(&header_schema)
  assert(header_schema.fingerprint==c.codecs.fact_header.fingerprint)
  bytes:[8192]u8
  size:=c.codecs.fact_header.wire_size+int(fact.count)*c.codecs.occurrence.wire_size
  body:=bytes[sc.HEADER_BYTES:sc.HEADER_BYTES+size]
  assert(sc.encode(&header_schema,header,body[:c.codecs.fact_header.wire_size]).error==.None)
  for event,i in fact.events[:fact.count] {
   at:=c.codecs.fact_header.wire_size+i*c.codecs.occurrence.wire_size
   assert(sc.encode(&c.codecs.occurrence,event,body[at:at+c.codecs.occurrence.wire_size]).error==.None)
  }
  assert(sc.pack_bytes(c.codecs.facts.fingerprint,{kind=6,epoch=c.cfg.epoch,content=c.cfg.content,tick=tick},body,bytes[:]).error==.None)
  assert(tr.send(&f.server.wire,2,.Reliable,bytes[:sc.HEADER_BYTES+size])==.Sent)
 }
 assert(tr.memory_advance(&f.network,f.clock))
 assert(net.client_pump(c,f.clock*1000/60)==.None)
 for _ in 0..<30 {fixture_step(&f)}
 testing.expect_value(t,c.stats.rejected_packets,u64(0))
 testing.expect_value(t,c.stats.resyncs,u64(0))
 testing.expect_value(t,c.authority_frame.state.players[f.clients[0].seat-1].bag,u32(5))
 testing.expect(t,f.server.stats.compact_recent_facts>0 && f.server.stats.recent_fact_bytes_saved>0)
}

@(test)
compact_empty_recent_bundle_has_one_scope_and_four_explicit_ages :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f,action_timing=.Receipt);defer fixture_destroy(&f)
 packet:=recent_compact_capture(&f);defer delete(packet)
 testing.expect_value(t,len(packet),sc.HEADER_BYTES+17+4*3)
 body:=packet[sc.HEADER_BYTES:]
 testing.expect_value(t,body[16],u8(4))
 for i in 0..<4 {
  testing.expect_value(t,body[17+i*3],u8(3-i))
  testing.expect_value(t,body[18+i*3],u8(0));testing.expect_value(t,body[19+i*3],u8(0))
 }
}

@(test)
compact_recent_bundle_validates_all_entries_before_mutation :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f,action_timing=.Receipt);defer fixture_destroy(&f)
 packet:=recent_compact_capture(&f);defer delete(packet)
 before:=make([]u8,len(packet)+1);defer delete(before)
 c:=&f.clients[0];contiguous:=c.facts_contiguous
 // Compare each logical slot below, avoiding padding as an equality contract.
 facts:=make(type_of(c.facts),len(c.facts));defer delete(facts);copy(facts,c.facts)
 for variant in 0..<9 {
  copy(before,packet);candidate:=before[:len(packet)];body:=candidate[sc.HEADER_BYTES:]
  switch variant {
  case 0:body[0]~=1 // wrong generation
  case 1:body[8]~=1 // wrong serial
  case 2:body[16]=5 // too many entries
  case 3:body[26]=1 // repeated tick in final entry
  case 4:body[26]=4 // age outside retained bundle
  case 5:body[27]=1 // truncated occurrence in final entry
  case 6:candidate=before[:] // trailing byte
  case 7:candidate=candidate[:len(candidate)-1]
  case 8:body[16]=0
  }
  recent_compact_checksum(candidate)
  rejected:=c.stats.rejected_packets
  recent_compact_deliver(&f,candidate)
  testing.expect_value(t,c.stats.rejected_packets,rejected+1)
  testing.expect_value(t,c.facts_contiguous,contiguous)
  for fact,i in c.facts {testing.expect(t,reflect.equal(fact,facts[i]))}
 }
 recent_compact_deliver(&f,packet)
 meta,_,_:=sc.inspect(packet);testing.expect_value(t,c.facts_contiguous,meta.tick)
}

@(test)
compact_recent_facts_are_optional_and_converge_under_faults :: proc(t:^testing.T) {
 for mode in 0..<3 {
  f:Fixture;fixture_init(&f,{latency_ticks=3,jitter_ticks=2,loss_permyriad=2000,duplicate_permyriad=1500,retry_ticks=3},action_timing=.Receipt);defer fixture_destroy(&f)
  if mode==0 {for &c in f.clients {c.compact_recent_facts_enabled=false}}
  if mode==1 {f.server.compact_recent_facts_disabled=true}
  for _ in 0..<70 {fixture_step(&f)}
  _,err:=net.client_issue(&f.clients[0],Action{take=true});testing.expect_value(t,err,net.Error.None)
  for _ in 0..<200 {fixture_step(&f)}
  tr.memory_set_faults(&f.network,tr.DEFAULT_FAULTS)
  for _ in 0..<40 {fixture_step(&f)}
  testing.expect(t,(f.server.stats.compact_recent_facts>0)==(mode==2))
  for &c in f.clients {
   testing.expect_value(t,c.authority_frame.state.players[f.clients[0].seat-1].bag,u32(5))
   testing.expect_value(t,c.stats.rejected_packets,u64(0));testing.expect_value(t,c.stats.resyncs,u64(0))
  }
 }
}

@(test)
compact_recent_events_reject_wrong_identity_and_retained_conflicts_atomically :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f,action_timing=.Receipt);defer fixture_destroy(&f)
 packet:=recent_compact_capture(&f,true);defer delete(packet)
 c:=&f.clients[0];meta,_,_:=sc.inspect(packet)
 offset:=sc.HEADER_BYTES+17;event_offset:=0;last_offset:=offset
 for _ in 0..<4 {
  count:=int(packet[offset+1])|int(packet[offset+2])<<8
  if count>0 {event_offset=offset+3}
  last_offset=offset;offset+=3+count*c.codecs.occurrence.wire_size
 }
 assert(event_offset!=0)
 bad:=make([]u8,len(packet));defer delete(bad)
 for delta in ([?]int{0,8}) { // occurrence epoch and tick
  copy(bad,packet);bad[event_offset+delta]~=1;recent_compact_checksum(bad)
  before:=c.stats.rejected_packets
  recent_compact_deliver(&f,bad)
  testing.expect_value(t,c.stats.rejected_packets,before+1)
  for tick:=meta.tick-3;tick<=meta.tick;tick+=1 {testing.expect(t,c.facts[tick%u64(c.cfg.history)].tick!=tick)}
 }
 // An existing conflicting final fact must also reject the earlier valid ones.
 conflict_tick:=meta.tick-u64(packet[last_offset]);slot:=&c.facts[conflict_tick%u64(c.cfg.history)]
 saved:=slot^;slot^={tick=conflict_tick,generation=c.generation+1,serial=c.serial}
 before:=c.stats.rejected_packets
 recent_compact_deliver(&f,packet)
 testing.expect_value(t,c.stats.rejected_packets,before+1)
 testing.expect(t,c.facts[(meta.tick-3)%u64(c.cfg.history)].tick!=meta.tick-3)
 slot^=saved
 recent_compact_deliver(&f,packet)
 testing.expect_value(t,c.facts_contiguous,meta.tick)
}

@(test)
compact_recent_facts_honor_the_recipients_smaller_datagram_limit :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f);defer fixture_destroy(&f)
 // Emit a fact that fits the server limit but not this recipient's limit.
 step:=proc(w:^World,controls:[2]Control,joins,leaves:u64,ctx:^r.Step(Event)) {
  model_step(w,controls,joins,leaves,ctx)
  if ctx.tick%5==0 {for i in 0..<12 {r.emit(ctx,u64(100+i),0,Event{1,u32(i)})}}
 }
 f.server.model.step=step
 for &c in f.clients {c.cfg.unreliable_packet_limit=512;c.model.step=step}
 oversized:=0
 for _ in 0..<90 {
  fixture_step(&f)
  for p,i in f.network.packets {if p.active && p.from==1 {
   bytes:=f.network.bytes[i*f.network.config.packet_bytes:i*f.network.config.packet_bytes+p.count]
   meta,_,report:=sc.inspect(bytes)
   if report.error==.None && meta.kind==27 && p.count>512 {oversized+=1}
  }}
 }
 testing.expect_value(t,oversized,0)
 testing.expect(t,f.server.stats.compact_recent_facts>0)
 for &c in f.clients {
  testing.expect_value(t,c.stats.rejected_packets,u64(0))
  testing.expect_value(t,c.stats.resyncs,u64(0))
  // The larger event list still arrives intact on the reliable fact stream.
  testing.expect_value(t,c.facts[85%u64(c.cfg.history)].count,u16(12))
 }
}
