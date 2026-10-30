package replay_net_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"

Timing_Probe :: struct {now:u64, samples:[net.Profile_Metric]u64}
@(test)
phase_timing_and_sample_callbacks_do_not_change_network_execution :: proc(t:^testing.T) {
 plain,measured:Fixture;fixture_init(&plain);fixture_init(&measured);defer fixture_destroy(&plain);defer fixture_destroy(&measured)
 probes:[4]Timing_Probe
 clock:=proc(user:rawptr)->(u64,bool) {p:=cast(^Timing_Probe)user;p.now+=5;return p.now,true}
 sample:=proc(user:rawptr,metric:net.Profile_Metric,elapsed:u64) {p:=cast(^Timing_Probe)user;p.samples[metric]+=1}
 measured.server.profile_clock={&probes[0],clock};measured.server.profile_user=&probes[0];measured.server.profile_sample=sample
 for &client,i in measured.clients {client.profile_clock={&probes[i+1],clock};client.profile_user=&probes[i+1];client.profile_sample=sample}
 for tick in 0..<160 {
  if tick==40 {net.client_issue(&plain.clients[0],Action{take=true});net.client_issue(&measured.clients[0],Action{take=true})}
  fixture_step(&plain,true);fixture_step(&measured,true)
 }
 a,_:=r.current(&plain.server.timeline);b,_:=r.current(&measured.server.timeline);testing.expect(t,reflect.equal(a,b))
 testing.expect(t,probes[0].samples[.Advance]>0 && probes[0].samples[.Pump]>0 && probes[0].samples[.Snapshot]>0)
 testing.expect(t,probes[0].samples[.Snapshot_Encode]>0 && probes[0].samples[.Snapshot_Hash]>0 && probes[0].samples[.Snapshot_Cache]>0)
 for &client,i in measured.clients {
  frame,_:=r.current(&client.timeline);reference,_:=r.current(&plain.clients[i].timeline);testing.expect(t,reflect.equal(frame,reference))
  testing.expect(t,probes[i+1].samples[.Pump]>0 && probes[i+1].samples[.Snapshot]>0)
  testing.expect(t,probes[i+1].samples[.Snapshot_Validate]>0 && probes[i+1].samples[.Snapshot_Cache]>0)
  if !client.spectator {testing.expect(t,probes[i+1].samples[.Advance]>0 && probes[i+1].samples[.Replay]>0)}
 }
 testing.expect_value(t,plain.server.stats.tx_bytes,measured.server.stats.tx_bytes)
}
