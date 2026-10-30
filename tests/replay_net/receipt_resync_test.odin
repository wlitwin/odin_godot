package replay_net_test
import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"

begin_test_resync :: proc(c:^Client) {c.phase=.Resyncing;c.hello_sent=false;c.has_pending=false;c.request_sequence+=1}

@(test)
receipt_action_queued_during_resync_waits_for_welcome_and_settles_once :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f,action_timing=.Receipt);defer fixture_destroy(&f)
 for _ in 0..<45 {fixture_step(&f)}
 c:=&f.clients[0]
 first,issued:=net.client_issue(c,Action{take=true});testing.expect_value(t,issued,net.Error.None)
 // Authority commits the first action, but its result has not reached this client.
 tr.memory_advance(&f.network,f.clock);net.server_pump(&f.server,f.clock*1000/60);net.server_step(&f.server);f.clock+=1
 begin_test_resync(c)
 before,_:=r.current(&c.timeline);sent:=c.stats.tx_packets;serial:=c.serial
 second,error:=net.client_issue(c,Action{fail_after_mutation=true})
 testing.expect_value(t,error,net.Error.None);testing.expect_value(t,second,first+1)
 after,_:=r.current(&c.timeline)
 testing.expect(t,reflect.equal(before,after) && c.stats.tx_packets==sent && c.phase==.Resyncing)
 if error==.None {testing.expect(t,!c.actions[c.action_count-1].sent && !c.actions[c.action_count-1].predicted)}
 for _ in 0..<150 {fixture_step(&f)}
 testing.expect(t,c.phase==.Running && c.serial>serial)
 outcomes:[8]net.Action_Outcome;n:=net.client_outcomes(c,outcomes[:]);testing.expect_value(t,n,2)
 if n==2 {testing.expect(t,outcomes[0].sequence==first && outcomes[0].applied && outcomes[1].sequence==second && !outcomes[1].applied && outcomes[1].reason==.Predicate)}
 testing.expect_value(t,net.client_outcomes(c,outcomes[:]),0)
 truth,_:=r.current(&f.server.timeline);testing.expect(t,truth.state.players[0].bag==5 && truth.state.chest==0 && truth.state.players[0].x==0)
}

@(test)
resync_queue_keeps_phase_identity_validation_and_capacity_boundaries :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f,action_timing=.Receipt);defer fixture_destroy(&f)
 c:=&f.clients[0]
 _,error:=net.client_issue(c,Action{take=true});testing.expect_value(t,error,net.Error.Wrong_Phase)
 for _ in 0..<45 {fixture_step(&f)}
 begin_test_resync(c)
 _,error=net.client_issue(c,Action{});testing.expect_value(t,error,net.Error.Invalid_Input)
 c.recovering=true;_,error=net.client_issue(c,Action{take=true});testing.expect_value(t,error,net.Error.Wrong_Phase);c.recovering=false
 c.model.action_timing=.Scheduled;_,error=net.client_issue(c,Action{take=true});testing.expect_value(t,error,net.Error.Wrong_Phase);c.model.action_timing=.Receipt
 c.cfg.require_permit=true;_,error=net.client_issue(c,Action{take=true});testing.expect_value(t,error,net.Error.Fenced);c.cfg.require_permit=false
 for phase in ([3]net.Phase{.Failed,.Disconnected,.Rejected}) {c.phase=phase;_,error=net.client_issue(c,Action{take=true});testing.expect_value(t,error,net.Error.Wrong_Phase)}
 c.phase=.Resyncing
 for _ in 0..<net.ACTION_CAPACITY {_,error=net.client_issue(c,Action{take=true});testing.expect_value(t,error,net.Error.None)}
 prior:=c.next_action;_,error=net.client_issue(c,Action{take=true});testing.expect_value(t,error,net.Error.Capacity);testing.expect_value(t,c.next_action,prior)
}

@(test)
receipt_request_after_wire_fact_overflow_survives_the_actual_resync_path :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f,action_timing=.Receipt);defer fixture_destroy(&f)
 for _ in 0..<45 {fixture_step(&f)}
 c:=&f.clients[0]
 for _ in 0..<int(c.cfg.history)+4 {testing.expect_value(t,net.server_step(&f.server),net.Error.None);f.clock+=1}
 // Deliver the authority's newest fact without its evicted predecessors.
 fact:=f.server.facts[f.server.timeline.head%u64(f.server.cfg.history)]
 fact.generation,fact.serial=c.generation,c.serial
 body,packet:[8192]u8
 testing.expect_value(t,sc.encode(&c.codecs.facts,fact,body[:]).error,sc.Error.None)
 size:=c.codecs.fact_header.wire_size+int(fact.count)*c.codecs.occurrence.wire_size
 // No gameplay events occur in this stationary interval, so the canonical
 // header is also the complete variable-length fact payload.
 testing.expect_value(t,fact.count,u16(0))
 testing.expect_value(t,sc.pack_bytes(c.codecs.facts.fingerprint,{kind=6,epoch=c.cfg.epoch,tick=fact.tick,content=c.cfg.content},body[:size],packet[:]).error,sc.Error.None)
 for &pending in f.network.packets {pending.active=false}
 testing.expect_value(t,tr.send(&f.server.wire,2,.Reliable,packet[:sc.HEADER_BYTES+size]),tr.Send_Result.Sent)
 tr.memory_advance(&f.network,f.clock);testing.expect_value(t,net.client_pump(c,f.clock*1000/60),net.Error.None)
 testing.expect_value(t,c.phase,net.Phase.Resyncing);testing.expect_value(t,c.resync_notice.reason,net.Resync_Reason.Facts_Overflow)
 sequence,error:=net.client_issue(c,Action{take=true});testing.expect_value(t,error,net.Error.None)
 for _ in 0..<160 {fixture_step(&f)}
 outcomes:[8]net.Action_Outcome;n:=net.client_outcomes(c,outcomes[:]);testing.expect_value(t,n,1)
 if n==1 {testing.expect(t,outcomes[0].sequence==sequence && outcomes[0].applied)}
 truth,_:=r.current(&f.server.timeline);testing.expect(t,truth.state.players[0].bag==5 && c.phase==.Running)
}
