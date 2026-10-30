package replay_net_test

import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import v "godot:replay/view"

@(test)
short_client_stall_uses_complete_ahead_snapshot_without_discarding_facts :: proc(t: ^testing.T) {
	f: Fixture; fixture_init(&f); defer fixture_destroy(&f)
	events_step := proc(w: ^World, controls: [2]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
		model_step(w, controls, joins, leaves, ctx)
		if ctx.tick % 10 == 0 {r.emit(ctx, 100, 1, Event{value = u32(ctx.tick)})}
	}
	f.server.model.step = events_step
	for &client in f.clients {client.model.step = events_step}
	for _ in 0 ..< 45 {fixture_step(&f)}
	c := &f.clients[0]
	c.cfg.packets_per_pump=256 // consume the full stalled interval, including redundant facts
	confirmed := c.journal.confirmed
	// Only this client pauses. Reliable facts and complete snapshots continue
	// arriving in its transport, within the configured history capacity.
	for _ in 0 ..< 36 {
		tr.memory_advance(&f.network, f.clock)
		now := f.clock * 1000 / 60
		net.server_pump(&f.server, now)
		for &client in f.clients[1:] {net.client_pump(&client, now)}
		net.server_step(&f.server)
		if f.clients[1].phase == .Running {net.client_step(&f.clients[1], Control{})}
		changes: [512]v.Change(net.Net_Event(Event))
		for &client in f.clients[1:] {for v.drain(&client.journal, changes[:]) > 0 {}}
		f.clock += 1
	}
	now := f.clock * 1000 / 60
	tr.memory_advance(&f.network, f.clock)
	testing.expect_value(t, net.client_pump(c, now), net.Error.None)
	testing.expect_value(t, c.phase, net.Phase.Running)
	testing.expect_value(t, c.stats.resyncs, u64(0))
	testing.expect_value(t, c.stats.snapshot_catchups, u64(1))
	testing.expect(t, c.journal.confirmed > confirmed)
	changes: [512]v.Change(net.Net_Event(Event))
	n := v.drain(&c.journal, changes[:])
	seen: [128]bool
	for change in changes[:n] {if change.occurrence.value.kind == .Gameplay && (change.kind == .Confirm || change.confirmed) {seen[change.occurrence.id.tick % 128] = true}}
	for tick := confirmed + 1; tick <= c.journal.confirmed; tick += 1 {if tick % 10 == 0 {testing.expect(t, seen[tick % 128])}}
}

Fact_Lag :: struct {base:tr.Transport,memory:^tr.Memory,ticks:u32}
lag_send :: proc(user:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {
 lag:=cast(^Fact_Lag)user;saved:=lag.memory.faults.latency_ticks
 lag.memory.faults.latency_ticks=channel==.Reliable ? lag.ticks : 0
 result:=tr.send(&lag.base,to,channel,bytes);lag.memory.faults.latency_ticks=saved;return result
}
@(test)
newer_snapshots_do_not_starve_ready_corrections_when_facts_lag :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f);defer fixture_destroy(&f)
 lag:=Fact_Lag{f.server.wire,&f.network,5}
 f.server.wire={user=&lag,send=lag_send,
  receive=proc(user:rawptr,dst:[]u8)->tr.Received{return tr.receive(&(cast(^Fact_Lag)user).base,dst)},
  status=proc(user:rawptr)->tr.Status{return tr.status(&(cast(^Fact_Lag)user).base)},
  connected=proc(user:rawptr,id:tr.Peer_Id)->bool{return tr.peer_connected(&(cast(^Fact_Lag)user).base,id)}}
 f.server.cfg.snapshot_every=1
 for _ in 0..<360 {fixture_step(&f)}
 for &client in f.clients {
  testing.expect_value(t,client.stats.resyncs,u64(0))
  testing.expect(t,client.timeline.confirmed+20>=f.server.timeline.head)
 }
}


@(test)
first_unready_snapshot_survives_a_fact_delay_longer_than_delta_cache :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f);defer fixture_destroy(&f)
 lag:=Fact_Lag{f.server.wire,&f.network,40}
 f.server.wire={user=&lag,send=lag_send,
  receive=proc(user:rawptr,dst:[]u8)->tr.Received{return tr.receive(&(cast(^Fact_Lag)user).base,dst)},
  status=proc(user:rawptr)->tr.Status{return tr.status(&(cast(^Fact_Lag)user).base)},
  connected=proc(user:rawptr,id:tr.Peer_Id)->bool{return tr.peer_connected(&(cast(^Fact_Lag)user).base,id)}}
 f.server.cfg.snapshot_every=1
 for _ in 0..<500 {fixture_step(&f)}
 for &client in f.clients {
  testing.expect_value(t,client.stats.resyncs,u64(0))
  testing.expect(t,client.timeline.confirmed+90>=f.server.timeline.head)
 }
}

@(test)
released_fact_burst_applies_the_newest_already_cached_snapshot :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f);defer fixture_destroy(&f)
 step:=proc(w:^World,c:[2]Control,j,l:u64,ctx:^r.Step(Event)){model_step(w,c,j,l,ctx);if ctx.tick%5==0 {r.emit(ctx,200,1,Event{value=u32(ctx.tick)})}}
 f.server.model.step=step;for &client in f.clients {client.model.step=step}
 for _ in 0..<45 {fixture_step(&f)}
 // Hold facts while actual authority snapshots continue to enter the cache.
 lag:=Fact_Lag{f.server.wire,&f.network,40}
 f.server.wire={user=&lag,send=proc(user:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {
  l:=cast(^Fact_Lag)user;meta,_,report:=sc.inspect(bytes);saved:=l.memory.faults.latency_ticks
  l.memory.faults.latency_ticks=report.error==.None && (meta.kind==6 || meta.kind==19 || meta.kind==27) ? l.ticks : 0
  result:=tr.send(&l.base,to,channel,bytes);l.memory.faults.latency_ticks=saved;return result
 },
  receive=proc(user:rawptr,dst:[]u8)->tr.Received{return tr.receive(&(cast(^Fact_Lag)user).base,dst)},
  status=proc(user:rawptr)->tr.Status{return tr.status(&(cast(^Fact_Lag)user).base)},
  connected=proc(user:rawptr,id:tr.Peer_Id)->bool{return tr.peer_connected(&(cast(^Fact_Lag)user).base,id)}}
 f.server.cfg.snapshot_every=1
 for _ in 0..<20 {fixture_step(&f)}
 c:=&f.clients[0];c.cfg.packets_per_pump=256
 tr.memory_advance(&f.network,f.clock);assert(net.client_pump(c,f.clock*1000/60)==.None)
 assert(c.has_pending && c.pending.frame.tick>c.facts_contiguous)
 previous:=c.journal.confirmed
 oldest:=c.pending.frame.tick
 newest:=u64(0)
 for id,i in c.snapshot_rx.ids {if id!=0 {newest=max(newest,c.snapshot_ticks[i])}}
 assert(newest>oldest)
 // Release delayed facts in one burst; reliable packets retain their order.
 // No state, decoded snapshot or confirmation field is supplied by the test.
 released:=0
 for &packet,i in f.network.packets {if packet.active && packet.from==1 && packet.to==2 {
  bytes:=f.network.bytes[i*f.network.config.packet_bytes:i*f.network.config.packet_bytes+packet.count]
  meta,_,report:=sc.inspect(bytes);assert(report.error==.None)
  if meta.kind==6 || meta.kind==19 || meta.kind==27 {packet.due=f.clock;released+=1}
 }}
 assert(released>0)
 tr.memory_advance(&f.network,f.clock)
 testing.expect_value(t,net.client_pump(c,f.clock*1000/60),net.Error.None)
 testing.expect(t,c.facts_contiguous>=newest)
 testing.expect_value(t,c.authority_frame.tick,newest)
 testing.expect_value(t,c.stats.resyncs,u64(0))
 changes:[512]v.Change(net.Net_Event(Event));n:=v.drain(&c.journal,changes[:]);seen:[128]bool
 for change in changes[:n] {if change.occurrence.value.kind==.Gameplay && (change.kind==.Confirm || change.confirmed) {seen[change.occurrence.id.tick%128]=true}}
 for tick:=previous+1;tick<=newest;tick+=1 {if tick%5==0 {testing.expect(t,seen[tick%128])}}
}
