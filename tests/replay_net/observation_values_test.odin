package replay_net_test
import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"

Value_Fixture :: struct($C:typeid) {
 memory:tr.Memory,
 endpoints:[2]tr.Memory_Endpoint,
 server:net.Server(C,C,u8,u8,2),
 client:net.Client(C,C,u8,u8,2),
 clock:u64,
}
value_fixture_init :: proc(f:^Value_Fixture($C)) {
 assert(tr.memory_init(&f.memory,cfg={2,128,8192,16384}))
 for &endpoint,i in f.endpoints {assert(tr.memory_open(&f.memory,&endpoint,tr.Peer_Id(i+1)))}
 m:=net.Model(C,C,u8,u8,2){control_timing=.Latest_Observation,
  step=proc(w:^C,inputs:[2]C,_,_:u64,_:^r.Step(u8)){w^=inputs[1]},
  control_valid=proc(_:C)->bool{return true},state_valid=proc(_:C)->bool{return true},hold=proc(c:C)->C{return c}}
 assert(net.server_init(&f.server,r.Frame(C){},m,tr.memory_transport(&f.endpoints[0]),local_seat=1)==.None)
 assert(net.client_init(&f.client,m,tr.memory_transport(&f.endpoints[1]),net.Token{0=2})==.None)
 for _ in 0..<16 {
  assert(tr.memory_advance(&f.memory,f.clock));now:=f.clock*16;f.clock+=1
  assert(net.server_pump(&f.server,now)==.None);assert(net.client_pump(&f.client,now)==.None);assert(net.server_step(&f.server)==.None)
 }
 assert(f.client.phase==.Running && f.client.compact_observations_negotiated)
}
value_fixture_destroy :: proc(f:^Value_Fixture($C)) {
 net.client_destroy(&f.client);net.server_destroy(&f.server)
 for &endpoint in f.endpoints {wire:=tr.memory_transport(&endpoint);tr.close(&wire)}
 tr.memory_destroy(&f.memory)
}
value_packet :: proc(f:^Value_Fixture($C),value:C)->[]u8 {
 assert(net.client_step(&f.client,value)==.None)
 tr.memory_advance(&f.memory,f.clock);f.clock+=1
 buffer:[8192]u8;result:[]u8
 for {
  packet:=tr.receive(&f.server.wire,buffer[:]);if packet.state==.Empty {break};assert(packet.state==.Received)
  meta,_,report:=sc.inspect(buffer[:packet.count]);if report.error!=.None || meta.kind!=14 && meta.kind!=26 {continue}
  delete(result);result=make([]u8,packet.count);copy(result,buffer[:packet.count])
 }
 assert(len(result)>0);return result
}

@(test)
dense_observations_use_the_full_format_without_inflation :: proc(t:^testing.T) {
 f:Value_Fixture([512]u8);value_fixture_init(&f);defer value_fixture_destroy(&f)
 value:[512]u8;for &b in value {b=0xff}
 bytes:=value_packet(&f,value);defer delete(bytes)
 meta,_,_:=sc.inspect(bytes);testing.expect_value(t,meta.kind,u16(14))
 testing.expect_value(t,len(bytes),sc.HEADER_BYTES+f.client.codecs.observation.wire_size)
 testing.expect_value(t,f.client.stats.compact_observations,u64(0))
 assert(tr.send(&f.client.wire,1,.Unreliable,bytes)==.Sent);tr.memory_advance(&f.memory,f.clock)
 net.server_pump(&f.server,f.clock*16);net.server_step(&f.server)
 frame,_:=r.current(&f.server.timeline);testing.expect_value(t,frame.state,value)
}

Bit_Control :: struct {negative_zero:f32,active:bool,spare:[32]u8}
@(test)
compact_observations_preserve_signed_zero_and_reject_bad_canonical_values :: proc(t:^testing.T) {
 f:Value_Fixture(Bit_Control);value_fixture_init(&f);defer value_fixture_destroy(&f)
 value:=Bit_Control{negative_zero=transmute(f32)u32(0x80000000),active=true}
 bytes:=value_packet(&f,value);defer delete(bytes)
 meta,fingerprint,_:=sc.inspect(bytes);testing.expect_value(t,meta.kind,u16(26))
 assert(tr.send(&f.client.wire,1,.Unreliable,bytes)==.Sent);tr.memory_advance(&f.memory,f.clock);f.clock+=1
 net.server_pump(&f.server,f.clock*16);net.server_step(&f.server)
 frame,_:=r.current(&f.server.timeline)
 testing.expect_value(t,transmute(u32)frame.state.negative_zero,u32(0x80000000));testing.expect(t,frame.state.active)
 // The canonical Boolean is at offset 16+8+4. Set its encoded nonzero value
 // to 2 and reseal the envelope, so rejection must come from canonical decode.
 payload:=make([]u8,len(bytes)-sc.HEADER_BYTES);defer delete(payload);copy(payload,bytes[sc.HEADER_BYTES:])
 bitmap:=(f.client.codecs.observation.wire_size+7)/8;cursor:=bitmap
 for i in 0..<28 {if payload[i/8]&(u8(1)<<uint(i%8))!=0 {cursor+=1}}
 assert(payload[28/8]&(u8(1)<<uint(28%8))!=0 && payload[cursor]==1);payload[cursor]=2
 bad:=make([]u8,len(bytes));defer delete(bad);assert(sc.pack_bytes(fingerprint,meta,payload,bad).error==.None)
 before:=f.server.held;rejected:=f.server.stats.rejected_inputs
 assert(tr.send(&f.client.wire,1,.Unreliable,bad)==.Sent);tr.memory_advance(&f.memory,f.clock);f.clock+=1
 net.server_pump(&f.server,f.clock*16)
 testing.expect_value(t,f.server.stats.rejected_inputs,rejected+1);testing.expect(t,reflect.equal(before,f.server.held))
}
