package replay_net_test

import "core:testing"
import "core:fmt"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import v "godot:replay/view"
import sc "godot:replay/schema"

@(test)
queued_complete_snapshots_allow_fact_history_to_advance_during_a_receive_burst :: proc(t:^testing.T) {
 for paused in ([2]int{0,2}) {for delay_fact in ([2]bool{false,true}) {
  cfg:=net.DEFAULT_CONFIG;cfg.packets_per_pump=256
  f:Fixture;fixture_init(&f,config=cfg);defer fixture_destroy(&f)
  step:=proc(w:^World,controls:[2]Control,joins,leaves:u64,ctx:^r.Step(Event)) {
   model_step(w,controls,joins,leaves,ctx)
   if ctx.tick%10==0 {r.emit(ctx,100,1,Event{seat=1,value=u32(ctx.tick)})}
  }
  f.server.model.step=step
  for &client in f.clients {
   client.model.step=step
   client.model.event_policy=proc(e:Event)->v.Policy{return .Watched}
   // Exercise the supported legacy stream: one reliable fact per tick and
   // complete snapshots, without redundant recent-fact packets filling a pump.
   client.snapshot_parts_enabled=false
  }
  for _ in 0..<60 {fixture_step(&f)}
  c:=&f.clients[paused];watched:=c.journal.watch_tick;confirmed:=c.journal.confirmed
  backlog_pause(&f,paused,140)
  delayed:[]u8;defer delete(delayed)
  if delay_fact {
   for &packet,i in f.network.packets {if packet.active && packet.to==tr.Peer_Id(paused+2) {
    bytes:=f.network.bytes[i*f.network.config.packet_bytes:i*f.network.config.packet_bytes+packet.count]
    meta,_,report:=sc.inspect(bytes)
    if report.error==.None && meta.kind==6 && meta.tick==confirmed+70 {
     delayed=make([]u8,packet.count);copy(delayed,bytes);packet.active=false;break
    }
   }}
   testing.expect(t,len(delayed)>0)
  }
  assert(tr.memory_advance(&f.network,f.clock))
  err:=net.client_pump(c,f.clock*1000/60)
  fmt.printf("RECEIVE_BACKLOG spectator=%v delayed_fact=%v error=%v phase=%v confirmed_before=%d confirmed_after=%d facts=%d resync=%v\n",c.spectator,delay_fact,err,c.phase,confirmed,c.journal.confirmed,c.facts_contiguous,c.resync_notice)
  testing.expect_value(t,err,net.Error.None)
  testing.expect_value(t,c.phase,net.Phase.Running)
  testing.expect_value(t,c.stats.resyncs,u64(0))
  if err!=.None || c.phase!=.Running {continue}
  testing.expect(t,c.journal.confirmed>confirmed)
  if delay_fact {
   testing.expect(t,c.facts_contiguous<confirmed+70)
   testing.expect_value(t,tr.send(&f.server.wire,tr.Peer_Id(paused+2),.Reliable,delayed),tr.Send_Result.Sent)
  }
  seen:[512]bool
  // Drain explicitly across continuation so missing or duplicated watched
  // events cannot be hidden by the fixture's ordinary presentation drain.
  for _ in 0..<80 {
   backlog_drain(t,c,watched,&seen)
   assert(tr.memory_advance(&f.network,f.clock));now:=f.clock*1000/60
   assert(net.server_pump(&f.server,now)==.None)
   assert(net.server_step(&f.server)==.None)
   testing.expect_value(t,net.client_pump(c,now),net.Error.None)
   if c.phase==.Running && !c.spectator {step_error:=net.client_step(c,Control{});testing.expect(t,step_error==.None || step_error==.Capacity)}
   f.clock+=1
  }
  backlog_drain(t,c,watched,&seen)
  for tick:=watched+1;tick<=c.journal.watch_tick;tick+=1 {if tick%10==0 {testing.expect(t,seen[tick])}}
  testing.expect(t,c.journal.confirmed+20>=f.server.timeline.head)
  testing.expect_value(t,c.stats.resyncs,u64(0))
 }}
}

backlog_pause :: proc(f:^Fixture,paused,ticks:int) {
 for _ in 0..<ticks {
   assert(tr.memory_advance(&f.network,f.clock));now:=f.clock*1000/60
   assert(net.server_pump(&f.server,now)==.None)
   for &client,i in f.clients {if i!=paused {assert(net.client_pump(&client,now)==.None)}}
   assert(net.server_step(&f.server)==.None)
   for &client,i in f.clients {if i!=paused {
    if client.phase==.Running && !client.spectator {assert(net.client_step(&client,Control{})==.None)}
    changes:[512]v.Change(net.Net_Event(Event));for v.drain(&client.journal,changes[:])>0 {}
   }}
   f.clock+=1
  }
}
backlog_drain :: proc(t:^testing.T,c:^Client,watched:u64,seen:^[512]bool) {
 changes:[512]v.Change(net.Net_Event(Event))
 for {
  n:=v.drain(&c.journal,changes[:]);if n==0 {break}
  for change in changes[:n] {if change.kind==.Begin && change.occurrence.value.kind==.Gameplay {
   tick:=change.occurrence.id.tick
   testing.expect(t,change.confirmed && tick>watched && tick<=c.journal.watch_tick)
   testing.expect(t,!seen[tick]);seen[tick]=true
  }}
 }
}

@(test)
receive_burst_still_resynchronizes_when_no_complete_snapshot_can_release_history :: proc(t:^testing.T) {
 cfg:=net.DEFAULT_CONFIG;cfg.packets_per_pump=256
 f:Fixture;fixture_init(&f,config=cfg);defer fixture_destroy(&f)
 for &client in f.clients {client.snapshot_parts_enabled=false}
 for _ in 0..<60 {fixture_step(&f)}
 c:=&f.clients[2];confirmed:=c.journal.confirmed
 backlog_pause(&f,2,140)
 dropped:=0
 for &packet,i in f.network.packets {if packet.active && packet.to==4 {
  bytes:=f.network.bytes[i*f.network.config.packet_bytes:i*f.network.config.packet_bytes+packet.count]
  meta,_,report:=sc.inspect(bytes)
  if report.error==.None && (meta.kind==7 || meta.kind==10) {packet.active=false;dropped+=1}
 }}
 testing.expect(t,dropped>0)
 assert(tr.memory_advance(&f.network,f.clock))
 testing.expect_value(t,net.client_pump(c,f.clock*1000/60),net.Error.None)
 testing.expect_value(t,c.phase,net.Phase.Resyncing)
 testing.expect_value(t,c.resync_notice.reason,net.Resync_Reason.Facts_Overflow)
 testing.expect_value(t,c.journal.confirmed,confirmed)
 testing.expect_value(t,c.stats.resyncs,u64(1))
}
