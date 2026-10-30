package replay_net_test
import "core:testing"
import "core:reflect"
import net "godot:replay/net"
import r "godot:replay"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

frontier_snapshot :: proc(f:^Fixture,valid:bool=true) {
 c:=&f.clients[0];frame:=c.authority_frame;frame.tick=c.timeline.head+5
 packet:=c.pending;packet.generation=c.generation+(valid ? u64(0) : u64(1));packet.serial=c.serial;packet.frame=frame;packet.held=c.held;packet.snapshot_id=c.snapshot_latest+100
 bytes:[8192]u8;count:=sc.HEADER_BYTES+c.codecs.snapshot.wire_size
 meta:=sc.Envelope_Meta{kind=7,epoch=c.cfg.epoch,tick=frame.tick,content=c.cfg.content}
 assert(sc.pack(&c.codecs.snapshot,packet,meta,bytes[:]).error==.None)
 assert(tr.send(&f.server.wire,2,.Unreliable,bytes[:count])==.Sent)
 tr.memory_advance(&f.network,f.clock)
 assert(net.client_pump(c,f.clock*1000/60)==.None)
}
@(test)
known_authority_frontier_blocks_sampling_before_its_facts_arrive :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f);defer fixture_destroy(&f)
 for _ in 0..<45 {fixture_step(&f)}
 c:=&f.clients[0];frontier_snapshot(&f)
 before,_:=r.current(&c.timeline);resyncs:=c.stats.resyncs
 testing.expect(t,c.timeline.head-c.timeline.confirmed<u64(c.cfg.max_prediction))
 testing.expect_value(t,net.client_step(c,Control{move=1}),net.Error.Capacity)
 after,_:=r.current(&c.timeline)
 testing.expect(t,reflect.equal(before,after) && c.phase==.Running && c.has_world && c.stats.resyncs==resyncs)
}
@(test)
wrong_generation_snapshot_cannot_block_input_sampling :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f);defer fixture_destroy(&f)
 for _ in 0..<45 {fixture_step(&f)}
 frontier_snapshot(&f,false)
 testing.expect_value(t,net.client_step(&f.clients[0],Control{move=1}),net.Error.None)
}

frontier_partial_snapshot :: proc(f:^Parts_Fixture,valid:bool=true)->u64 {
 c:=&f.client
 // Continue the real authority until its generated snapshot is ahead. Retire
 // its delivery queue and release only one scoped part, with no complete state.
 for _ in 0..<35 {
  tr.memory_advance(&f.memory,f.clock);now:=f.clock*1000/60
  net.server_pump(&f.server,now);net.server_step(&f.server);f.clock+=1
 }
 bytes:[8192]u8;count:=0;latest:u64
 for packet,i in f.memory.packets {if packet.active && packet.from==1 && packet.to==2 {
  data:=f.memory.bytes[i*f.memory.config.packet_bytes:i*f.memory.config.packet_bytes+packet.count]
  meta,_,report:=sc.inspect(data)
  if report.error==.None && meta.kind==17 && meta.tick>latest {latest=meta.tick;count=copy(bytes[:],data)}
 }}
 assert(count>0 && latest>c.timeline.head)
 for &packet in f.memory.packets {packet.active=false}
 if !valid {
  meta,body,report:=sc.unpack_bytes(c.codecs.snapshot_part.fingerprint,bytes[:count],{kind=17,epoch=c.cfg.epoch,content=c.cfg.content});assert(report.error==.None)
  body[0]~=1 // First canonical header field is the connection generation.
  encoded:[8192]u8;assert(sc.pack_bytes(c.codecs.snapshot_part.fingerprint,meta,body,encoded[:]).error==.None);copy(bytes[:],encoded[:count])
 }
 raw:=tr.memory_transport(&f.ends[0]);assert(tr.send(&raw,2,.Unreliable,bytes[:count])==.Sent)
 f.clock+=20;tr.memory_advance(&f.memory,f.clock);assert(net.client_pump(c,f.clock*1000/60)==.None)
 return latest
}
@(test)
scoped_partial_snapshot_also_fences_obsolete_input_ticks :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f);defer parts_destroy(&f)
 for _ in 0..<80 {parts_step(&f)}
 frontier_partial_snapshot(&f)
 before,_:=r.current(&f.client.timeline)
 testing.expect_value(t,net.client_step(&f.client,Control{move=1}),net.Error.Capacity)
 after,_:=r.current(&f.client.timeline);testing.expect(t,reflect.equal(before,after) && f.client.has_world)
}
@(test)
wrong_generation_partial_snapshot_cannot_fence_input :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f);defer parts_destroy(&f)
 for _ in 0..<80 {parts_step(&f)}
 frontier_partial_snapshot(&f,false)
 testing.expect_value(t,net.client_step(&f.client,Control{move=1}),net.Error.None)
}
