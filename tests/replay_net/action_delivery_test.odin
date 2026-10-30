package replay_net_test
import "core:testing"
import "core:fmt"
import r "godot:replay"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
import v "godot:replay/view"
import game "../../examples/replay_hello/shared/hello"

@(test)
a_delayed_heartbeat_does_not_hold_a_receipt_action :: proc(t:^testing.T) {
 f:Hello_Fixture;hello_fixture_init(&f,action_timing=.Receipt);defer hello_fixture_destroy(&f)
 // Isolate heartbeat delivery; the pre-change runner had no action copies.
 f.clients[0].action_copies_enabled=false
 index:=-1
 for _ in 0..<100 {
  hello_fixture_step(&f)
  for packet,i in f.network.packets {
   if !packet.active || packet.from!=2 {continue}
   bytes:=f.network.bytes[i*f.network.config.packet_bytes:i*f.network.config.packet_bytes+packet.count]
   meta,_,report:=sc.inspect(bytes);if report.error==.None && meta.kind==9 {index=i;break}
  }
  if index>=0 {break}
 }
 testing.expect(t,index>=0);if index<0 {return}
 channel:=f.network.packets[index].channel;release:=f.clock+60
 f.network.packets[index].ready=false;f.network.packets[index].due=release
 _,error:=net.client_issue(&f.clients[0],game.Action{fire=true});testing.expect_value(t,error,net.Error.None)
 for _ in 0..<10 {hello_fixture_step(&f)}
 frame,_:=r.current(&f.server.timeline)
 fmt.printf("HEARTBEAT_ACTION channel=%v shots=%d now=%d held_until=%d\n",channel,frame.state.shots,f.clock,release)
 testing.expect_value(t,frame.state.shots,u32(1))
}

@(test)
receipt_action_copies_bridge_a_held_reliable_action :: proc(t:^testing.T) {
 f:Hello_Fixture;hello_fixture_init(&f,action_timing=.Receipt);defer hello_fixture_destroy(&f)
 for _ in 0..<70 {hello_fixture_step(&f)}
 sequence,error:=net.client_issue(&f.clients[0],game.Action{fire=true});testing.expect_value(t,error,net.Error.None)
 release:=f.clock+60;held,lost_copy:=false,false
 for _ in 0..<18 {
  for &packet,i in f.network.packets {
   if !packet.active || packet.from!=2 {continue}
   bytes:=f.network.bytes[i*f.network.config.packet_bytes:i*f.network.config.packet_bytes+packet.count]
   meta,_,report:=sc.inspect(bytes)
   if report.error==.None && meta.kind==5 && packet.channel==.Reliable {packet.ready=false;packet.due=release;held=true}
   if report.error==.None && meta.kind==25 && !lost_copy {packet.active=false;lost_copy=true}
  }
  hello_fixture_step(&f)
 }
 frame,_:=r.current(&f.server.timeline)
 fmt.printf("ACTION_REPAIR shots=%d now=%d held_until=%d\n",frame.state.shots,f.clock,release)
 testing.expect(t,held && lost_copy && f.clock<release);testing.expect_value(t,frame.state.shots,u32(1))
 for _ in 0..<100 {hello_fixture_step(&f)}
 outcomes:[8]net.Action_Outcome;n:=net.client_outcomes(&f.clients[0],outcomes[:]);testing.expect_value(t,n,1)
 if n==1 {testing.expect(t,outcomes[0].sequence==sequence && outcomes[0].applied)}
 frame,_=r.current(&f.server.timeline);testing.expect_value(t,frame.state.shots,u32(1))
}

copy_bundle_capture :: proc(f:^Fixture)->[]u8 {
 for _ in 0..<50 {fixture_step(f)}
 _,a:=net.client_issue(&f.clients[0],Action{take=true})
 _,b:=net.client_issue(&f.clients[0],Action{fail_after_mutation=true})
 _,c:=net.client_issue(&f.clients[0],Action{take=true});assert(a==.None && b==.None && c==.None)
 // Keep the authority still while the client reaches the next repeat interval.
 for _ in 0..<8 {f.clock+=1;tr.memory_advance(&f.network,f.clock);assert(net.client_pump(&f.clients[0],f.clock*1000/60)==.None)}
 saved:[]u8
 for packet,i in f.network.packets {
  if !packet.active || packet.from!=2 {continue}
  bytes:=f.network.bytes[i*f.network.config.packet_bytes:i*f.network.config.packet_bytes+packet.count]
  meta,_,report:=sc.inspect(bytes)
  if report.error==.None && meta.kind==25 && bytes[sc.HEADER_BYTES+16]==3 {saved=make([]u8,len(bytes));copy(saved,bytes);break}
 }
 assert(saved!=nil)
 for &packet in f.network.packets {packet.active=false}
 tr.memory_set_faults(&f.network,tr.DEFAULT_FAULTS)
 return saved
}

@(test)
action_bundle_bad_tail_rejects_before_any_prefix_action_is_received :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f,action_timing=.Receipt);defer fixture_destroy(&f)
 packet:=copy_bundle_capture(&f);defer delete(packet)
 rejected:=f.server.stats.rejected_packets
 packet[len(packet)-1]~=0x80;parts_checksum(packet) // outer valid, inner tail invalid
 testing.expect_value(t,tr.send(&f.clients[0].wire,1,.Unreliable,packet),tr.Send_Result.Sent)
 tr.memory_advance(&f.network,f.clock);net.server_pump(&f.server,f.clock*1000/60)
 testing.expect_value(t,f.server.stats.rejected_packets,rejected+1)
 for peer in f.server.peers {if peer.connection==2 {testing.expect_value(t,peer.action_received,u64(0));testing.expect_value(t,peer.action_count,0)}}
}

@(test)
action_bundle_preserves_order_predicate_atomicity_admission_and_duplicate_results :: proc(t:^testing.T) {
 for denied in ([2]bool{false,true}) {
  f:Fixture;fixture_init(&f,action_timing=.Receipt)
  packet:=copy_bundle_capture(&f)
  if denied {f.server.model.action_admit=proc(_:rawptr,_:u16,_:Action)->bool{return false}}
  for _ in 0..<2 {testing.expect_value(t,tr.send(&f.clients[0].wire,1,.Unreliable,packet),tr.Send_Result.Sent)}
  for _ in 0..<30 {fixture_step(&f)}
  outcomes:[8]net.Action_Outcome;n:=net.client_outcomes(&f.clients[0],outcomes[:]);testing.expect_value(t,n,3)
  if n==3 {
   for outcome,i in outcomes[:n] {testing.expect_value(t,outcome.sequence,u64(i+1));if i>0 {testing.expect(t,outcome.tick>outcomes[i-1].tick)}}
   if denied {for outcome in outcomes[:n] {testing.expect(t,!outcome.applied && outcome.reason==.Invalid)}} else {
    testing.expect(t,outcomes[0].applied && !outcomes[1].applied && !outcomes[2].applied && outcomes[1].reason==.Predicate && outcomes[2].reason==.Predicate)
   }
  }
  testing.expect_value(t,net.client_outcomes(&f.clients[0],outcomes[:]),0)
  frame,_:=r.current(&f.server.timeline);testing.expect(t,frame.state.chest==(denied ? 5 : 0) && frame.state.players[0].bag==(denied ? 0 : 5) && frame.state.players[0].x==0)
  testing.expect(t,f.server.stats.duplicate_actions>=3)
  delete(packet);fixture_destroy(&f)
 }
}

@(test)
action_bundle_is_bounded_and_repeats_only_at_its_interval :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f,action_timing=.Receipt);defer fixture_destroy(&f)
 packet:=copy_bundle_capture(&f);defer delete(packet)
 for _ in 0..<8 {_,error:=net.client_issue(&f.clients[0],Action{take=true});testing.expect_value(t,error,net.Error.None)}
 before:=f.clients[0].stats.action_copy_batches
 for _ in 0..<100 {net.client_pump(&f.clients[0],f.clock*1000/60)}
 testing.expect_value(t,f.clients[0].stats.action_copy_batches,before)
 f.clock+=7;net.client_pump(&f.clients[0],f.clock*1000/60)
 testing.expect_value(t,f.clients[0].stats.action_copy_batches,before+1)
 found:=false
 for p,i in f.network.packets {if p.active && p.from==2 {
  bytes:=f.network.bytes[i*f.network.config.packet_bytes:i*f.network.config.packet_bytes+p.count]
  meta,_,report:=sc.inspect(bytes);if report.error==.None && meta.kind==25 {testing.expect(t,len(bytes)<=1024 && bytes[sc.HEADER_BYTES+16]<=4);if bytes[sc.HEADER_BYTES+16]==4 {found=true}}
 }}
 testing.expect(t,found)
}

@(test)
action_copies_stay_off_without_a_server_capability_reply :: proc(t:^testing.T) {
 f:Hello_Fixture;hello_fixture_init(&f,action_timing=.Receipt);defer hello_fixture_destroy(&f)
 for _ in 0..<70 {
  hello_fixture_step(&f)
  for &packet,i in f.network.packets {
   if !packet.active || packet.from!=1 {continue}
   bytes:=f.network.bytes[i*f.network.config.packet_bytes:i*f.network.config.packet_bytes+packet.count]
   meta,_,report:=sc.inspect(bytes);if report.error==.None && meta.kind==16 {packet.active=false}
  }
 }
 testing.expect(t,!f.clients[0].action_copies_negotiated)
 _,error:=net.client_issue(&f.clients[0],game.Action{fire=true});testing.expect_value(t,error,net.Error.None)
 for _ in 0..<40 {hello_fixture_step(&f)}
 frame,_:=r.current(&f.server.timeline);testing.expect_value(t,frame.state.shots,u32(1))
 testing.expect_value(t,f.clients[0].stats.action_copy_batches,u64(0))
}

@(test)
action_bundle_scope_and_weighted_ingress_limit_reject_before_admission :: proc(t:^testing.T) {
 for mode in 0..<4 {
  f:Fixture;fixture_init(&f,action_timing=.Receipt)
  packet:=copy_bundle_capture(&f);rejected:=f.server.stats.rejected_packets
  if mode==0 {parts_put64(packet[sc.HEADER_BYTES:sc.HEADER_BYTES+8],f.clients[0].generation+1);parts_checksum(packet)}
  if mode==1 {parts_put64(packet[sc.HEADER_BYTES+8:sc.HEADER_BYTES+16],f.clients[0].serial+1);parts_checksum(packet)}
  if mode==2 {packet[sc.HEADER_BYTES+16]=5;parts_checksum(packet)}
  if mode==3 {for &peer in f.server.peers {if peer.connection==2 {peer.budget_packets=2}}}
  testing.expect_value(t,tr.send(&f.clients[0].wire,1,.Unreliable,packet),tr.Send_Result.Sent)
  tr.memory_advance(&f.network,f.clock);net.server_pump(&f.server,f.server.now) // no token refill
  testing.expect_value(t,f.server.stats.rejected_packets,rejected+1)
  for peer in f.server.peers {if peer.connection==2 {testing.expect_value(t,peer.action_received,u64(0));testing.expect_value(t,peer.action_count,0)}}
  delete(packet);fixture_destroy(&f)
 }
}

Wide_Copy_Action :: struct {value:u8,padding:[2048]u8}
@(test)
large_actions_retain_reliable_fallback_without_oversized_copy_packets :: proc(t:^testing.T) {
 memory:tr.Memory;assert(tr.memory_init(&memory,912,{2,128,8192,16384}));defer tr.memory_destroy(&memory)
 ends:[2]tr.Memory_Endpoint;for &end,i in ends {assert(tr.memory_open(&memory,&end,tr.Peer_Id(i+1)))}
 defer for &end in ends {wire:=tr.memory_transport(&end);tr.close(&wire)}
 model:=net.Model(u32,u8,Wide_Copy_Action,u8,1){action_timing=.Receipt,
 step=proc(_: ^u32,_:[1]u8,_:u64,_:u64,_:^r.Step(u8)) {},
 action=proc(w:^u32,_:u16,a:Wide_Copy_Action,_:^r.Step(u8))->bool {w^+=u32(a.value);return true},
 control_valid=proc(c:u8)->bool{return c==0},action_valid=proc(a:Wide_Copy_Action)->bool {return a.value==1},
 state_valid=proc(w:u32)->bool{return w<=1},hold=proc(_:u8)->u8{return 0}}
 server:net.Server(u32,u8,Wide_Copy_Action,u8,1);client:net.Client(u32,u8,Wide_Copy_Action,u8,1)
 assert(net.server_init(&server,r.Frame(u32){},model,tr.memory_transport(&ends[0]))==.None);defer net.server_destroy(&server)
 assert(net.client_init(&client,model,tr.memory_transport(&ends[1]),net.Token{0=1})==.None);defer net.client_destroy(&client)
 for tick in u64(0)..<100 {
  tr.memory_advance(&memory,tick);assert(net.server_pump(&server,tick*1000/60)==.None);assert(net.client_pump(&client,tick*1000/60)==.None)
  if tick==40 {_,error:=net.client_issue(&client,Wide_Copy_Action{value=1});testing.expect_value(t,error,net.Error.None)}
  assert(net.server_step(&server)==.None)
  if client.phase==.Running {error:=net.client_step(&client,0);assert(error==.None || error==.Capacity)}
  changes:[256]v.Change(net.Net_Event(u8));for v.drain(&client.journal,changes[:])>0 {}
 }
 frame,_:=r.current(&server.timeline);testing.expect_value(t,frame.state,u32(1))
 testing.expect(t,client.action_copies_negotiated && client.stats.action_copy_oversize>0)
 testing.expect_value(t,client.stats.action_copy_batches,u64(0))
 outcomes:[4]net.Action_Outcome;n:=net.client_outcomes(&client,outcomes[:]);testing.expect_value(t,n,1)
 if n==1 {testing.expect(t,outcomes[0].applied)}
}
