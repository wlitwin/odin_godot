package replay_net_test
import "core:testing"
import tr "godot:replay/transport"
import net "godot:replay/net"
import sc "godot:replay/schema"

@(test)
recent_fact_copies_bridge_a_reliable_channel_hole_without_losing_confirmation :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f);defer fixture_destroy(&f)
 for &c in f.clients {c.compact_recent_facts_enabled=false}
 for _ in 0..<40 {fixture_step(&f)}
 // Queue reliable traffic twenty ticks behind unreliable traffic. It is still
 // delivered in order; the check occurs before the delayed facts can arrive.
 lag:=Fact_Lag{f.server.wire,&f.network,20}
 f.server.wire={user=&lag,send=lag_send,
  receive=proc(user:rawptr,dst:[]u8)->tr.Received{return tr.receive(&(cast(^Fact_Lag)user).base,dst)},
  status=proc(user:rawptr)->tr.Status{return tr.status(&(cast(^Fact_Lag)user).base)},
  connected=proc(user:rawptr,id:tr.Peer_Id)->bool{return tr.peer_connected(&(cast(^Fact_Lag)user).base,id)}}
 for _ in 0..<15 {fixture_step(&f)}
 for &c in f.clients {
  testing.expect(t,c.facts_contiguous+4>=f.server.timeline.head)
  testing.expect(t,c.journal.confirmed+6>=f.server.timeline.head)
  testing.expect_value(t,c.stats.resyncs,u64(0))
 }
}

@(test)
recent_fact_bundle_rejects_a_bad_tail_before_committing_earlier_facts :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f);defer fixture_destroy(&f)
 for &c in f.clients {c.compact_recent_facts_enabled=false}
 for _ in 0..<40 {fixture_step(&f)}
 c:=&f.clients[0];before:=c.facts_contiguous
 for _ in 0..<4 {
  tr.memory_advance(&f.network,f.clock);net.server_pump(&f.server,f.clock*1000/60);net.server_step(&f.server);f.clock+=1
 }
 packet:[]u8;newest:u64
 for p,i in f.network.packets {if p.active && p.to==2 && p.from==1 {
  bytes:=f.network.bytes[i*f.network.config.packet_bytes:i*f.network.config.packet_bytes+p.count]
  meta,_,report:=sc.inspect(bytes)
  if report.error==.None && meta.kind==19 && meta.tick>newest {
   delete(packet);packet=make([]u8,p.count);copy(packet,bytes);newest=meta.tick
  }
 }}
 testing.expect(t,packet!=nil && newest>before+1);if packet==nil {return};defer delete(packet)
 for &p in f.network.packets {if p.to==2 {p.active=false}}
 packet[len(packet)-1]~=1
 sum:=sc.digest(packet[sc.HEADER_BYTES:],sc.digest(packet[:44]))
 for i in 0..<8 {packet[44+i]=u8(sum>>uint(i*8))}
 rejected:=c.stats.rejected_packets
 testing.expect_value(t,tr.send(&f.server.wire,2,.Unreliable,packet),tr.Send_Result.Sent)
 tr.memory_advance(&f.network,f.clock);net.client_pump(c,f.clock*1000/60)
 testing.expect_value(t,c.stats.rejected_packets,rejected+1)
 testing.expect_value(t,c.facts_contiguous,before)
}
