package replay_net_test

import "core:testing"
import "core:fmt"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import v "godot:replay/view"
import sc "godot:replay/schema"

@(test)
catchup_matures_old_watched_events_before_prediction_reuses_their_slots :: proc(t:^testing.T) {
 // A supported receive budget consumes the whole stalled interval in one pump.
 cfg:=net.DEFAULT_CONFIG;cfg.lead=62;cfg.packets_per_pump=256
 f:Fixture;fixture_init(&f,config=cfg);defer fixture_destroy(&f)
 events_step:=proc(w:^World,controls:[2]Control,joins,leaves:u64,ctx:^r.Step(Event)) {
  model_step(w,controls,joins,leaves,ctx)
  r.emit(ctx,100,1,Event{seat=1,value=u32(ctx.tick)})
 }
 f.server.model.step=events_step
 for &c in f.clients {
  c.model.step=events_step
  c.model.event_policy=proc(e:Event)->v.Policy{return .Watched}

 }
 for _ in 0..<60 {fixture_step(&f)}
 c:=&f.clients[0];watched:=c.journal.watch_tick;confirmed:=c.journal.confirmed
 for _ in 0..<70 {
  assert(tr.memory_advance(&f.network,f.clock));now:=f.clock*1000/60
  assert(net.server_pump(&f.server,now)==.None)
  for &other in f.clients[1:] {assert(net.client_pump(&other,now)==.None)}
  assert(net.server_step(&f.server)==.None)
  // Lose only optional unreliable fact copies to this paused client. Reliable
  // facts and snapshots still queue, preserving the original ahead-snapshot case.
  for &packet,i in f.network.packets {if packet.active && packet.to==2 && packet.channel==.Unreliable {
   bytes:=f.network.bytes[i*f.network.config.packet_bytes:i*f.network.config.packet_bytes+packet.count]
   meta,_,report:=sc.inspect(bytes);if report.error==.None && meta.kind==6 {packet.active=false}
  }}
  if f.clients[1].phase==.Running {assert(net.client_step(&f.clients[1],Control{})==.None)}
  changes:[512]v.Change(net.Net_Event(Event))
  for &other in f.clients[1:] {for v.drain(&other.journal,changes[:])>0 {}}
  f.clock+=1
 }
 assert(tr.memory_advance(&f.network,f.clock))
 err:=net.client_pump(c,f.clock*1000/60)
 fmt.printf("CATCHUP_WATCH error=%v detail=%v old_confirmed=%d old_watch=%d catchups=%d\n",err,c.presentation_failure,confirmed,watched,c.stats.snapshot_catchups)
 testing.expect_value(t,err,net.Error.None)
 if err!=.None {return}
 testing.expect_value(t,c.stats.snapshot_catchups,u64(1))
 testing.expect_value(t,c.stats.resyncs,u64(0))
 changes:[512]v.Change(net.Net_Event(Event));seen:[256]bool;begins:=0
 for {
  n:=v.drain(&c.journal,changes[:]);if n==0 {break}
  for change in changes[:n] {if change.kind==.Begin && change.occurrence.value.kind==.Gameplay {
   tick:=change.occurrence.id.tick
   testing.expect_value(t,tick,watched+u64(begins)+1)
   testing.expect(t,change.confirmed && tick>watched && tick<=c.journal.watch_tick)
   testing.expect(t,!seen[tick]);seen[tick]=true;begins+=1
  }}
 }
 testing.expect_value(t,begins,int(c.journal.watch_tick-watched))
 for tick:=watched+1;tick<=c.journal.watch_tick;tick+=1 {testing.expect(t,seen[tick])}
 testing.expect_value(t,c.timeline.head,c.authority_frame.tick+u64(c.lead_ticks))
 for _ in 0..<30 {fixture_step(&f)}
}

@(test)
invalid_authored_event_policy_reports_the_failed_operation :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f);defer fixture_destroy(&f)
 for _ in 0..<30 {fixture_step(&f)}
 c:=&f.clients[0]
 c.model.event_policy=proc(e:Event)->v.Policy{return v.Policy(99)}
 net.client_remote_observed(c)
 _,err:=net.client_issue(c,Action{take=true});testing.expect_value(t,err,net.Error.None)
 err=net.client_step(c,Control{})
 testing.expect_value(t,err,net.Error.Presentation)
 failure:=c.presentation_failure
 testing.expect_value(t,failure.serial,u64(1))
 testing.expect_value(t,failure.stage,net.Presentation_Stage.Predicted_Batch)
 testing.expect_value(t,failure.error,v.Error.Invalid_Policy)
 testing.expect_value(t,failure.tick,c.timeline.head)
 testing.expect_value(t,failure.confirmed,c.journal.confirmed)
 testing.expect_value(t,failure.watch_tick,c.journal.watch_tick)
 testing.expect_value(t,failure.epoch,c.cfg.epoch)
}
