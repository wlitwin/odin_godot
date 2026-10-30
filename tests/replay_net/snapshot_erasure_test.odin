package replay_net_test
import "core:testing"
import "core:fmt"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

@(test)
repeated_missing_snapshot_fragments_do_not_force_a_world_resync :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f);defer parts_destroy(&f)
 for _ in 0..<100 {parts_step(&f)}
 start:=f.client.authority_frame.tick;dropped:=0
 for _ in 0..<100 {
  parts_step(&f)
  for &packet,i in f.memory.packets {
   if !packet.active || packet.from!=1 || parts_packet_kind(&f,i)!=17 {continue}
   bytes:=f.memory.bytes[i*f.memory.config.packet_bytes:i*f.memory.config.packet_bytes+packet.count]
   // Lose the first two data shards of every newly emitted world, after the
   // transport accepted them. Facts and later snapshots continue normally.
   index:=int(bytes[sc.HEADER_BYTES+36])|int(bytes[sc.HEADER_BYTES+37])<<8
   if index==0 || index==1 {packet.active=false;dropped+=1}
  }
 }
 fmt.printf("SNAPSHOT_ERASURE start=%d confirmed=%d facts=%d head=%d dropped=%d resyncs=%d\n",start,f.client.authority_frame.tick,f.client.facts_contiguous,f.server.timeline.head,dropped,f.client.stats.resyncs)
 testing.expect(t,dropped>100)
 testing.expect(t,f.client.authority_frame.tick+12>=f.server.timeline.head)
 testing.expect_value(t,f.client.stats.resyncs,u64(0))
 testing.expect_value(t,f.client.phase,net.Phase.Running)
}

fec_capture :: proc(f:^Parts_Fixture)->(packets:[][]u8,id:u64) {
 for _ in 0..<100 {parts_step(f)}
 for packet,i in f.memory.packets {
  if !packet.active || packet.from!=1 || parts_packet_kind(f,i)!=17 {continue}
  bytes:=f.memory.bytes[i*f.memory.config.packet_bytes:i*f.memory.config.packet_bytes+packet.count]
  candidate:=parts_read64(bytes[sc.HEADER_BYTES+16:sc.HEADER_BYTES+24])
  if candidate<=f.client.snapshot_latest {continue}
  n:=0
  for p,j in f.memory.packets {
   if !p.active || p.from!=1 || (parts_packet_kind(f,j)!=17 && parts_packet_kind(f,j)!=23) {continue}
   value:=f.memory.bytes[j*f.memory.config.packet_bytes:j*f.memory.config.packet_bytes+p.count]
   if parts_read64(value[sc.HEADER_BYTES+16:sc.HEADER_BYTES+24])==candidate {n+=1}
  }
  if n==6 {id=candidate;break}
 }
 assert(id!=0)
 packets=make([][]u8,6);at:=0
 for packet,i in f.memory.packets {
  kind:=parts_packet_kind(f,i)
  if !packet.active || packet.from!=1 || (kind!=17 && kind!=23) {continue}
  bytes:=f.memory.bytes[i*f.memory.config.packet_bytes:i*f.memory.config.packet_bytes+packet.count]
  if parts_read64(bytes[sc.HEADER_BYTES+16:sc.HEADER_BYTES+24])!=id {continue}
  index:=int(bytes[sc.HEADER_BYTES+36])|int(bytes[sc.HEADER_BYTES+37])<<8
  at=kind==17 ? index : 4+index
  packets[at]=make([]u8,len(bytes));copy(packets[at],bytes)
 }
 for packet in packets {assert(len(packet)>0)}
 for &packet in f.memory.packets {packet.active=false}
 tr.memory_set_faults(&f.memory,tr.DEFAULT_FAULTS)
 return
}

@(test)
snapshot_parity_reconstructs_only_after_sufficient_shards_and_full_validation :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f);defer parts_destroy(&f)
 packets,id:=fec_capture(&f);defer parts_packets_free(packets)
 before:=f.client.snapshot_latest
 for i in ([3]int{2,3,4}) {parts_deliver(&f,packets[i]);testing.expect_value(t,f.client.snapshot_latest,before)}
 parts_deliver(&f,packets[5]);testing.expect_value(t,f.client.snapshot_latest,id)
 testing.expect_value(t,f.client.stats.snapshot_shards_recovered,u64(2))
 for packet in packets {parts_deliver(&f,packet)}
 testing.expect_value(t,f.client.snapshot_latest,id)
 testing.expect_value(t,f.client.stats.rejected_packets,u64(0))
}

@(test)
snapshot_parity_rejects_bad_scope_index_duplicates_and_reconstructed_digest :: proc(t:^testing.T) {
 for mode in 0..<4 {
  f:Parts_Fixture;parts_init(&f)
  packets,id:=fec_capture(&f);before:=f.client.snapshot_latest;rejected:=f.client.stats.rejected_packets
  parts_deliver(&f,packets[2]);parts_deliver(&f,packets[3])
  switch mode {
  case 0:parts_put64(packets[4][sc.HEADER_BYTES+8:sc.HEADER_BYTES+16],f.client.serial+1);parts_checksum(packets[4]);parts_deliver(&f,packets[4])
  case 1:packets[4][sc.HEADER_BYTES+36]=2;parts_checksum(packets[4]);parts_deliver(&f,packets[4])
  case 2:
   parts_deliver(&f,packets[4]);packets[4][len(packets[4])-1]~=1;parts_checksum(packets[4]);parts_deliver(&f,packets[4])
  case 3:
   packets[4][sc.HEADER_BYTES+40]~=1;parts_checksum(packets[4]);parts_deliver(&f,packets[4]);parts_deliver(&f,packets[5])
  }
  testing.expect(t,id>before);testing.expect_value(t,f.client.snapshot_latest,before)
  testing.expect_value(t,f.client.stats.rejected_packets,rejected+1)
  parts_packets_free(packets);parts_destroy(&f)
 }
}

@(test)
snapshot_parity_buffers_are_bounded_and_expire_when_loss_exceeds_repair_capacity :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f);defer parts_destroy(&f)
 for _ in 0..<100 {parts_step(&f)}
 for _ in 0..<80 {
  parts_step(&f)
  for &packet,i in f.memory.packets {
   if !packet.active || packet.from!=1 || parts_packet_kind(&f,i)!=17 {continue}
   bytes:=f.memory.bytes[i*f.memory.config.packet_bytes:i*f.memory.config.packet_bytes+packet.count]
   index:=int(bytes[sc.HEADER_BYTES+36])|int(bytes[sc.HEADER_BYTES+37])<<8
   if index<3 {packet.active=false}
  }
  for slot in f.client.snapshot_parts {
   if slot.id==0 {testing.expect(t,slot.data==nil && slot.parity==nil);continue}
   payload:=slot.part_bytes-sc.HEADER_BYTES-f.client.codecs.snapshot_part.wire_size
   testing.expect(t,len(slot.parity)<=2*((slot.parts+7)/8)*payload)
  }
 }
 testing.expect(t,f.client.stats.snapshot_parts_expired>10)
 for _ in 0..<60 {parts_step(&f)}
 testing.expect(t,f.client.authority_frame.tick+12>=f.server.timeline.head)
 testing.expect_value(t,f.client.stats.rejected_packets,u64(0))
}

@(test)
snapshot_parity_uses_existing_egress_budget_and_does_not_delay_ack_eligibility :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f,faults=tr.DEFAULT_FAULTS);defer parts_destroy(&f)
 for _ in 0..<100 {parts_step(&f)}
 f.server.cfg.egress_bytes_per_pump=1300
 for _ in 0..<150 {parts_step(&f)}
 testing.expect(t,f.server.stats.snapshot_parity_sent>20 && f.server.stats.egress_deferred>0)
 testing.expect_value(t,f.server.stats.rejected_acks,u64(0))
 testing.expect_value(t,f.client.stats.rejected_packets,u64(0))
 testing.expect(t,f.client.authority_frame.tick+12>=f.server.timeline.head)
}

@(test)
snapshot_parity_is_not_sent_to_a_peer_that_did_not_advertise_it :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f);f.client.snapshot_erasure_enabled=false;defer parts_destroy(&f)
 for _ in 0..<200 {parts_step(&f)}
 testing.expect(t,f.server.stats.fragmented_snapshots>100)
 testing.expect_value(t,f.server.stats.snapshot_parity_sent,u64(0))
 testing.expect_value(t,f.client.stats.snapshot_parity_received,u64(0))
 testing.expect_value(t,f.client.stats.rejected_packets,u64(0))
}
