package replay_net_test

import "core:testing"
import "core:fmt"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import delta "godot:replay/delta"
import v "godot:replay/view"

Parts_World :: struct {tick:u64,payload:[768]u32,total:u32}
Parts_Model :: net.Model(Parts_World,Control,Action,Event,2)
Parts_Fixture :: struct {
 memory:tr.Memory,
 ends:[2]tr.Memory_Endpoint,
 server:net.Server(Parts_World,Control,Action,Event,2),
 client:net.Client(Parts_World,Control,Action,Event,2),
 clock:u64,
}
parts_model :: proc()->Parts_Model {
 return {step=proc(w:^Parts_World,controls:[2]Control,joins,leaves:u64,ctx:^r.Step(Event)) {
  w.tick=ctx.tick
  for &value,i in w.payload {value=u32(ctx.tick*1234567)~u32(i*65537)}
 },action=proc(w:^Parts_World,seat:u16,a:Action,ctx:^r.Step(Event))->bool {
  if !a.take {return false};w.total+=1;r.emit(ctx,u64(seat),1,Event{seat,w.total});return true
 },control_valid=control_valid,action_valid=action_valid,hold=hold,
 state_valid=proc(w:Parts_World)->bool {
  if w.tick==0 {return true}
  for value,i in w.payload {if value!=u32(w.tick*1234567)~u32(i*65537) {return false}}
  return true
 }}
}
parts_init :: proc(f:^Parts_Fixture,enabled:bool=true,faults:=tr.Faults{latency_ticks=7,retry_ticks=3}) {
 assert(tr.memory_init(&f.memory,44,{2,512,8192,32768},faults))
 for &e,i in f.ends {assert(tr.memory_open(&f.memory,&e,tr.Peer_Id(i+1)))}
 cfg:=net.DEFAULT_CONFIG;cfg.snapshot_every=1
 assert(net.server_init(&f.server,r.Frame(Parts_World){},parts_model(),tr.memory_transport(&f.ends[0]),cfg,local_seat=1)==.None)
 assert(net.client_init(&f.client,parts_model(),tr.memory_transport(&f.ends[1]),net.Token{0=2},cfg=cfg)==.None)
 f.client.snapshot_parts_enabled=enabled
 f.client.lz4_snapshots_enabled=false
}
parts_destroy :: proc(f:^Parts_Fixture) {
 net.client_destroy(&f.client);net.server_destroy(&f.server)
 for &e in f.ends {wire:=tr.memory_transport(&e);tr.close(&wire)}
 tr.memory_destroy(&f.memory)
}
parts_step :: proc(f:^Parts_Fixture) {
 assert(tr.memory_advance(&f.memory,f.clock));now:=f.clock*1000/60
 assert(net.server_pump(&f.server,now)==.None)
 err:=net.client_pump(&f.client,now);assert(err==.None,fmt.tprintf("pump %v %v",err,f.client.presentation_failure))
 assert(net.server_step(&f.server)==.None)
 if f.client.phase==.Running {err=net.client_step(&f.client,Control{});assert(err==.None || err==.Capacity)}
 changes:[512]v.Change(net.Net_Event(Event));for v.drain(&f.client.journal,changes[:])>0 {}
 f.clock+=1
}
parts_packet_kind :: proc(f:^Parts_Fixture,index:int)->u16 {
 p:=f.memory.packets[index]
 _,_,report:=sc.inspect(f.memory.bytes[index*f.memory.config.packet_bytes:index*f.memory.config.packet_bytes+p.count])
 if report.error!=.None {return 0}
 meta,_,_:=sc.inspect(f.memory.bytes[index*f.memory.config.packet_bytes:index*f.memory.config.packet_bytes+p.count]);return meta.kind
}
@(test)
fragmented_snapshots_keep_large_changing_worlds_near_received_facts :: proc(t:^testing.T) {
 modern,legacy:Parts_Fixture;parts_init(&modern);parts_init(&legacy,false)
 defer parts_destroy(&modern);defer parts_destroy(&legacy)
 fresh_lag,old_lag:u64;fresh_max:u64
 for i in 0..<600 {
  parts_step(&modern);parts_step(&legacy)
  if i>=100 {
   a:=modern.client.facts_contiguous-modern.client.authority_frame.tick
   fresh_lag+=a;old_lag+=legacy.client.facts_contiguous-legacy.client.authority_frame.tick;fresh_max=max(fresh_max,a)
  }
 }
 testing.expect(t,modern.server.stats.fragmented_snapshots>400)
 testing.expect_value(t,legacy.server.stats.fragmented_snapshots,u64(0))
 testing.expect(t,fresh_max<=2 && old_lag>5*500)
 testing.expect_value(t,modern.client.stats.resyncs,u64(0))
 testing.expect_value(t,modern.client.stats.rejected_packets,u64(0))
 a,_:=r.current(&modern.server.timeline);b,_:=r.current(&legacy.server.timeline);testing.expect(t,reflect.equal(a,b))
 fmt.printf("SNAPSHOT_FRESHNESS modern_mean=%.2f legacy_mean=%.2f modern_max=%d modern_bytes=%d legacy_bytes=%d\n",f64(fresh_lag)/500,f64(old_lag)/500,fresh_max,modern.server.stats.tx_bytes,legacy.server.stats.tx_bytes)
}
@(test)
fragment_loss_reordering_and_duplicate_packets_preserve_authority_and_actions :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f,faults={latency_ticks=4,jitter_ticks=3,loss_permyriad=1000,duplicate_permyriad=2000,retry_ticks=3});defer parts_destroy(&f)
 for i in 0..<700 {
  if i==100 || i==300 {_,err:=net.server_issue(&f.server,Action{take=true});testing.expect_value(t,err,net.Error.None)}
  parts_step(&f)
  bytes:=0;for slot in f.client.snapshot_parts {bytes+=len(slot.data)}
  testing.expect(t,bytes<=net.SNAPSHOT_ASSEMBLIES*tr.MAX_PACKET_BYTES)
 }
 tr.memory_set_faults(&f.memory,tr.DEFAULT_FAULTS)
 for _ in 0..<100 {parts_step(&f)}
 testing.expect_value(t,f.client.phase,net.Phase.Running)
 testing.expect_value(t,f.client.authority_frame.state.total,u32(2))
 testing.expect(t,f.client.authority_frame.tick+4>=f.server.timeline.head)
 testing.expect(t,f.server.stats.fragmented_snapshots>100)
 testing.expect_value(t,f.client.presentation_failure.serial,u64(0))
}
@(test)
fragment_transfer_resumes_under_budget_backpressure_without_reusing_ids :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f);defer parts_destroy(&f)
 for _ in 0..<100 {parts_step(&f)}
 f.server.cfg.egress_bytes_per_pump=1300
 last_id:=f.client.snapshot_latest;last_tick:=f.client.authority_frame.tick;progress:=0
 for _ in 0..<200 {
  parts_step(&f)
  testing.expect(t,f.client.snapshot_latest>=last_id)
  if f.client.snapshot_latest>last_id {progress+=1;testing.expect(t,f.client.authority_frame.tick>last_tick)}
  last_id,last_tick=f.client.snapshot_latest,f.client.authority_frame.tick
 }
 testing.expect(t,progress>20 && f.server.stats.egress_deferred>0)
 f.server.cfg.egress_bytes_per_pump=256*1024
 for _ in 0..<100 {parts_step(&f)}
 testing.expect(t,f.client.authority_frame.tick+10>=f.server.timeline.head)
 testing.expect_value(t,f.client.stats.rejected_packets,u64(0))
}
@(test)
fragmented_full_snapshots_remain_usable_without_cached_delta_bases :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f);defer parts_destroy(&f)
 for _ in 0..<100 {parts_step(&f)}
 delta.cache_clear(&f.client.snapshot_rx);before:=f.server.stats.full_snapshots
 for _ in 0..<150 {parts_step(&f)}
 // Dense full snapshots need no delta baseline. A full packet is still accepted
 // through the same canonical path; the separate sparse-world test covers misses.
 testing.expect(t,f.server.stats.full_snapshots>before)
 testing.expect(t,f.client.authority_frame.tick+10>=f.server.timeline.head)
}

// Capture one real encoded snapshot's datagrams, then isolate their delivery.
parts_capture :: proc(f:^Parts_Fixture)->(packets:[][]u8,id:u64) {
 for _ in 0..<100 {parts_step(f)}
 for p,i in f.memory.packets {
  if !p.active || p.from!=1 || p.to!=2 || parts_packet_kind(f,i)!=17 {continue}
  bytes:=f.memory.bytes[i*f.memory.config.packet_bytes:i*f.memory.config.packet_bytes+p.count]
  candidate:=parts_read64(bytes[sc.HEADER_BYTES+16:sc.HEADER_BYTES+24])
  if candidate>f.client.snapshot_latest {id=candidate;break}
 }
 assert(id!=0)
 list: [128][]u8;count:=0
 for p,i in f.memory.packets {
  if !p.active || p.from!=1 || p.to!=2 || parts_packet_kind(f,i)!=17 {continue}
  bytes:=f.memory.bytes[i*f.memory.config.packet_bytes:i*f.memory.config.packet_bytes+p.count]
  if parts_read64(bytes[sc.HEADER_BYTES+16:sc.HEADER_BYTES+24])!=id {continue}
  list[count]=make([]u8,p.count);copy(list[count],bytes);count+=1
 }
 assert(count>=3);packets=make([][]u8,count);copy(packets,list[:count])
 for &p in f.memory.packets {p.active=false}
 tr.memory_set_faults(&f.memory,tr.DEFAULT_FAULTS)
 return
}
parts_packets_free :: proc(packets:[][]u8) {for packet in packets {delete(packet)};delete(packets)}
parts_read64 :: proc(bytes:[]u8)->u64 {value:u64;for b,i in bytes {value|=u64(b)<<uint(i*8)};return value}
parts_put64 :: proc(bytes:[]u8,value:u64) {for &b,i in bytes {b=u8(value>>uint(i*8))}}
parts_checksum :: proc(packet:[]u8) {parts_put64(packet[44:52],sc.digest(packet[sc.HEADER_BYTES:],sc.digest(packet[:44])))}
parts_deliver :: proc(f:^Parts_Fixture,packet:[]u8) {
 assert(tr.send(&f.server.wire,2,.Unreliable,packet)==.Sent)
 assert(tr.memory_advance(&f.memory,f.clock))
 assert(net.client_pump(&f.client,f.clock*1000/60)==.None)
 f.clock+=1
}
@(test)
parts_publish_only_complete_valid_snapshots_despite_reordering_and_duplicates :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f);defer parts_destroy(&f)
 packets,id:=parts_capture(&f);defer parts_packets_free(packets)
 before:=f.client.snapshot_latest
 for i:=len(packets)-1;i>0;i-=1 {
  parts_deliver(&f,packets[i]);parts_deliver(&f,packets[i])
  testing.expect_value(t,f.client.snapshot_latest,before)
 }
 parts_deliver(&f,packets[0]);testing.expect_value(t,f.client.snapshot_latest,id)
 for packet in packets {parts_deliver(&f,packet)}
 testing.expect_value(t,f.client.snapshot_latest,id)
 testing.expect_value(t,f.client.stats.rejected_packets,u64(0))
}
@(test)
parts_reject_wrong_scope_conflicts_and_whole_message_corruption :: proc(t:^testing.T) {
 for mode in 0..<4 {
  f:Parts_Fixture;parts_init(&f)
  packets,id:=parts_capture(&f);before:=f.client.stats.rejected_packets;latest:=f.client.snapshot_latest
  if mode==0 { // Stale generation with a valid envelope checksum.
   parts_put64(packets[0][sc.HEADER_BYTES:sc.HEADER_BYTES+8],f.client.generation+1);parts_checksum(packets[0]);parts_deliver(&f,packets[0])
  } else if mode==1 { // Conflicting duplicate; neither body may be published.
   parts_deliver(&f,packets[0]);packets[0][len(packets[0])-1]~=1;parts_checksum(packets[0]);parts_deliver(&f,packets[0])
  } else if mode==2 { // Parts agree on a false whole-message digest.
   for packet in packets {packet[sc.HEADER_BYTES+24]~=1;parts_checksum(packet);parts_deliver(&f,packet)}
  } else { // The outer ID may not rename a different inner snapshot.
   for packet in packets {parts_put64(packet[sc.HEADER_BYTES+16:sc.HEADER_BYTES+24],id+1000);parts_checksum(packet);parts_deliver(&f,packet)}
  }
  testing.expect(t,f.client.stats.rejected_packets>before)
  testing.expect_value(t,f.client.snapshot_latest,latest)
  parts_packets_free(packets);parts_destroy(&f)
 }
}
@(test)
incomplete_snapshot_assemblies_are_bounded_evicted_and_expired :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f);defer parts_destroy(&f)
 packets,id:=parts_capture(&f);defer parts_packets_free(packets)
 latest:=f.client.snapshot_latest
 for i in u64(0)..<20 {
  parts_put64(packets[0][sc.HEADER_BYTES+16:sc.HEADER_BYTES+24],id+i);parts_checksum(packets[0]);parts_deliver(&f,packets[0])
  live,bytes:=0,0;for slot in f.client.snapshot_parts {if slot.id!=0 {live+=1};bytes+=len(slot.data)}
  testing.expect(t,live<=4 && bytes<=4*(f.client.codecs.snapshot.wire_size+sc.HEADER_BYTES))
 }
 testing.expect_value(t,f.client.snapshot_latest,latest)
 testing.expect(t,f.client.stats.snapshot_parts_expired>=16)
 assert(net.client_pump(&f.client,f.client.now+net.SNAPSHOT_PART_TIMEOUT_MS+1)==.None)
 for slot in f.client.snapshot_parts {testing.expect_value(t,len(slot.data),0)}
 testing.expect_value(t,f.client.snapshot_latest,latest)
}

@(test)
parts_negotiate_the_smaller_unreliable_datagram_limit :: proc(t:^testing.T) {
 for small_client in ([2]bool{true,false}) {
  f:Parts_Fixture;parts_init(&f)
  if small_client {f.client.cfg.unreliable_packet_limit=512} else {f.server.cfg.unreliable_packet_limit=512}
  seen:=0
  for _ in 0..<300 {
   parts_step(&f)
   for p,i in f.memory.packets {if p.active && p.from==1 && parts_packet_kind(&f,i)==17 {
    testing.expect(t,p.count<=512 && p.channel==.Unreliable);seen+=1
   }}
  }
  testing.expect(t,seen>100 && f.client.authority_frame.tick+10>=f.server.timeline.head)
  testing.expect_value(t,f.client.stats.rejected_packets,u64(0))
  parts_destroy(&f)
 }
}

@(test)
welcome_retires_old_part_assemblies_and_renegotiates_delivery :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f);defer parts_destroy(&f)
 packets,_:=parts_capture(&f);defer parts_packets_free(packets)
 parts_deliver(&f,packets[0]);old_generation:=f.client.generation
 tr.close(&f.client.wire);parts_step(&f)
 assert(tr.memory_open(&f.memory,&f.ends[1],2))
 assert(net.client_reconnect(&f.client,tr.memory_transport(&f.ends[1]))==.None)
 for _ in 0..<100 {parts_step(&f)}
 testing.expect(t,f.client.generation>old_generation && f.client.features_sent)
 for &packet in f.memory.packets {packet.active=false}
 before:=f.client.snapshot_latest
 parts_deliver(&f,packets[0]);testing.expect_value(t,f.client.snapshot_latest,before)
 testing.expect(t,f.client.stats.rejected_packets>0)
 for slot in f.client.snapshot_parts {testing.expect(t,slot.id==0 || slot.tick>100)}
 testing.expect_value(t,f.client.phase,net.Phase.Running)
}
