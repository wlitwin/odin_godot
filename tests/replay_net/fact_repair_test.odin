package replay_net_test

import "core:testing"
import "core:fmt"
import sc "godot:replay/schema"
import net "godot:replay/net"
import tr "godot:replay/transport"

@(test)
a_missing_fact_is_repaired_before_a_held_reliable_stream_recovers :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f);defer parts_destroy(&f)
 for _ in 0..<100 {parts_step(&f)}
 target:=f.server.timeline.head+1
 release:=f.clock+90
 held,dropped:=false,0
 for _ in 0..<45 {
  parts_step(&f)
  for &packet,i in f.memory.packets {
   if !packet.active || packet.from!=1 {continue}
   bytes:=f.memory.bytes[i*f.memory.config.packet_bytes:i*f.memory.config.packet_bytes+packet.count]
   meta,_,report:=sc.inspect(bytes);if report.error!=.None {continue}
   if meta.kind==6 && meta.tick==target && packet.channel==.Reliable {
    packet.ready=false;packet.due=release;held=true
   }
   if (meta.kind==19 || meta.kind==27) && meta.tick>=target && meta.tick-target<=3 {packet.active=false;dropped+=1}
  }
 }
 fmt.printf("FACT_GAP target=%d confirmed=%d snapshot=%d head=%d held_until=%d now=%d recent_dropped=%d\n",target,f.client.facts_contiguous,f.client.authority_frame.tick,f.server.timeline.head,release,f.clock,dropped)
 testing.expect(t,held && dropped>0 && f.clock<release)
 testing.expect(t,f.client.facts_contiguous>target+20)
 testing.expect(t,f.client.authority_frame.tick>target+20)
 testing.expect_value(t,f.client.stats.resyncs,u64(0))
 testing.expect_value(t,f.client.stats.rejected_packets,u64(0))
}

Repair_Request_Record :: struct {generation,serial,first:u64,missing:u32}

repair_inject :: proc(f:^Parts_Fixture,request:Repair_Request_Record,epoch:u64=0) {
 schema:sc.Schema;assert(sc.init(&schema,Repair_Request_Record).error==.None);defer sc.destroy(&schema)
 bytes:[128]u8
 assert(sc.pack(&schema,request,{kind=22,epoch=epoch==0 ? f.server.cfg.epoch : epoch,content=f.server.cfg.content},bytes[:]).error==.None)
 assert(tr.send(&f.client.wire,1,.Unreliable,bytes[:sc.HEADER_BYTES+schema.wire_size])==.Sent)
}
repair_pump_server :: proc(f:^Parts_Fixture) {
 assert(tr.memory_advance(&f.memory,f.clock))
 assert(net.server_pump(&f.server,f.clock*1000/60)==.None)
}

@(test)
fact_repair_rejects_invalid_scope_ranges_and_unbounded_requests :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f,faults=tr.DEFAULT_FAULTS);defer parts_destroy(&f)
 for _ in 0..<100 {parts_step(&f)}
 testing.expect(t,f.client.fact_repair_negotiated)
 for &p in f.memory.packets {p.active=false}
 before:=f.server.stats.rejected_packets;repairs:=f.server.stats.fact_repairs
 good:=Repair_Request_Record{f.client.generation,f.client.serial,90,1}
 for i in 0..<8 {
  packet:=good;epoch:=f.server.cfg.epoch
  switch i {
  case 0:packet.generation+=1
  case 1:packet.serial+=1
  case 2:epoch+=1
  case 3:packet.first=0
  case 4:packet.first=f.server.timeline.head+1
  case 5:packet.missing=0
  case 6:packet.missing=2
  case 7:packet.missing=31
  }
  repair_inject(&f,packet,epoch)
 }
 repair_pump_server(&f)
 testing.expect_value(t,f.server.stats.rejected_packets,before+8)
 testing.expect_value(t,f.server.stats.fact_repairs,repairs)
 // A valid request following malformed traffic still works. Four replies is
 // the per-interval ceiling even when the peer repeats its request immediately.
 good.missing=15
 for _ in 0..<10 {repair_inject(&f,good)}
 repair_pump_server(&f)
 testing.expect_value(t,f.server.stats.fact_repairs,repairs+4)
 testing.expect_value(t,f.server.stats.fact_repair_requests,u64(1))
}

@(test)
fact_repair_respects_egress_budget_and_leaves_large_facts_on_reliable_stream :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f,faults=tr.DEFAULT_FAULTS);defer parts_destroy(&f)
 for _ in 0..<100 {parts_step(&f)}
 for &p in f.memory.packets {p.active=false}
 good:=Repair_Request_Record{f.client.generation,f.client.serial,90,1}
 before:=f.server.stats.fact_repairs
 f.server.cfg.egress_bytes_per_pump=1
 repair_inject(&f,good);repair_pump_server(&f)
 testing.expect_value(t,f.server.stats.fact_repairs,before)
 testing.expect(t,f.server.stats.egress_deferred>0)
 f.clock+=7;f.server.cfg.egress_bytes_per_pump=net.DEFAULT_CONFIG.egress_bytes_per_pump
 repair_inject(&f,good);repair_pump_server(&f)
 testing.expect_value(t,f.server.stats.fact_repairs,before+1)
 // Exercise the size fallback with an actual retained, canonical event list.
 slot:=&f.server.facts[90%f.server.cfg.history]
 slot.count=net.WIRE_EVENTS
 for &event,i in slot.events {event={id={epoch=f.server.cfg.epoch,tick=90,source=u64(i+1),key=0},value={kind=.Gameplay}}}
 f.clock+=7;repair_inject(&f,good);repair_pump_server(&f)
 testing.expect_value(t,f.server.stats.fact_repairs,before+1)
 testing.expect_value(t,f.server.stats.fact_repair_oversize,u64(1))
}

@(test)
fact_repair_is_not_requested_without_a_server_capability_reply :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f,faults=tr.DEFAULT_FAULTS);defer parts_destroy(&f)
 // Suppress only the capability acknowledgment, as an older server would.
 for _ in 0..<100 {
  parts_step(&f)
  for &packet,i in f.memory.packets {if packet.active && packet.from==1 && parts_packet_kind(&f,i)==16 {packet.active=false}}
 }
 testing.expect(t,!f.client.fact_repair_negotiated)
 f.client.authority_tick_seen=f.client.facts_contiguous+5
 net.client_pump(&f.client,f.clock*1000/60)
 testing.expect_value(t,f.client.stats.fact_repair_requests,u64(0))
}

@(test)
fact_repair_retries_lost_requests_and_replies_and_accepts_late_reliable_duplicates :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f,faults=tr.Faults{latency_ticks=3,retry_ticks=3});defer parts_destroy(&f)
 for _ in 0..<100 {parts_step(&f)}
 target:=f.server.timeline.head+1;release:=f.clock+90
 request_lost,reply_lost:=false,false
 for _ in 0..<60 {
  parts_step(&f)
  for &packet,i in f.memory.packets {
   if !packet.active {continue}
   bytes:=f.memory.bytes[i*f.memory.config.packet_bytes:i*f.memory.config.packet_bytes+packet.count]
   meta,_,report:=sc.inspect(bytes);if report.error!=.None {continue}
   if packet.from==2 && meta.kind==22 && !request_lost {packet.active=false;request_lost=true}
   if packet.from!=1 {continue}
   if meta.kind==6 && meta.tick==target {
    if packet.channel==.Reliable {packet.ready=false;packet.due=release}
    else if !reply_lost {packet.active=false;reply_lost=true}
   }
   if (meta.kind==19 || meta.kind==27) && meta.tick>=target && meta.tick-target<=3 {packet.active=false}
  }
 }
 testing.expect(t,request_lost && reply_lost && f.clock<release)
 testing.expect(t,f.client.facts_contiguous>target+30 && f.client.authority_frame.tick>target+30)
 testing.expect(t,f.client.stats.fact_repair_requests>=3)
 for _ in 0..<60 {parts_step(&f)}
 testing.expect(t,f.client.facts_contiguous+4>=f.server.timeline.head)
 testing.expect_value(t,f.client.stats.resyncs,u64(0))
 testing.expect_value(t,f.client.stats.rejected_packets,u64(0))
}
