package replay_input_fidelity_test

// The unchanged ar.open sends Hello, Welcome and its real ACK at Memory time0.
// This is a zero-RTT public generic4 regression, not positive-latency evidence.
import "core:mem"
import "core:testing"
import b "godot:box3d"
import ph "godot:replay/physics"
import net "godot:replay/net"
import ar "godot:tests/box3d_soak/replay/action_retire"

Welcome_Observation :: struct {
 scope,stage:string,
 setup_complete,current_scope,full5_equal,cleanup_observed:bool,
 phase:net.Phase,
 configured_lead,lead_ticks,hz,max_prediction,max_future,seed_upper_bound:u32,
 history:int,
 expected_zero_rtt_seed:u32,
 epoch,generation,serial,seat,server_head,head,confirmed,baseline,authority_tick_seen:u64,
 client_now_ms,memory_now:u64,
 timing_samples:u64,clock_scale:f64,
 transport_trace_count,transport_trace_dropped:int,transport_trace_hash:u64,
 native_live,wrapper_live,provider_live,odin_live:u64,
}
welcome_gate :: proc(t:^testing.T,ok:bool,o:^Welcome_Observation,stage:string)->bool {
 o.stage=stage;testing.expect(t,ok,stage);return ok
}

@(test)
complete_physics_welcome_uses_existing_zero_rtt_lead_seed :: proc(t:^testing.T) {
 backing:=context.allocator;tracking:mem.Tracking_Allocator
 mem.tracking_allocator_init(&tracking,backing,backing);context.allocator=mem.tracking_allocator(&tracking)
 o:=Welcome_Observation{scope="public_generic4_static_OFFddff_nilOwner_unchanged_ar_open_ZERO_RTT_NOT_positive_latency_CoreSDK32_or_GateB",stage="open",expected_zero_rtt_seed=4}
 pair:=new(ar.Pair)
 defer {
  o.transport_trace_count=pair.memory.trace_count;o.transport_trace_dropped=pair.memory.trace_dropped;o.transport_trace_hash=pair.memory.trace_hash
  if pair.memory.trace_count>0 {write_json("welcome-memory-trace.json",pair.memory.trace[:pair.memory.trace_count])}
  ar.close(t,pair);free(pair)
  engine,es:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats();provider:=ph.allocation_stats()
  o.native_live=engine.live_bytes;o.wrapper_live=wrapper.live_bytes;o.provider_live=provider.live_bytes;o.odin_live=u64(tracking.current_memory_allocated)
  o.cleanup_observed=es==.Ok&&ws==.Ok&&o.native_live==0&&o.wrapper_live==0&&o.provider_live==0&&o.odin_live==0
  testing.expect(t,o.cleanup_observed)
  context.allocator=backing;mem.tracking_allocator_destroy(&tracking);write_json("welcome-observation.json",o)
 }
 if !ar.open(t,pair) {return}
 c:=&pair.client
 o.phase=c.phase;o.configured_lead=c.cfg.lead;o.lead_ticks=c.lead_ticks;o.hz=c.cfg.hz;o.history=c.cfg.history
 o.max_prediction=c.cfg.max_prediction;o.max_future=c.cfg.max_future;o.seed_upper_bound=min(c.cfg.max_future-2,c.cfg.max_prediction-2)
 o.epoch=c.cfg.epoch;o.generation=c.generation;o.serial=c.serial;o.seat=u64(c.seat)
 o.server_head=pair.server.timeline.head;o.head=c.timeline.head;o.confirmed=c.timeline.confirmed;o.baseline=c.baseline;o.authority_tick_seen=c.authority_tick_seen
 o.client_now_ms=c.now;o.memory_now=pair.memory.now;o.timing_samples=c.stats.timing_samples;o.clock_scale=c.clock_scale
 if !welcome_gate(t,o.configured_lead==2&&o.hz==60&&o.history==128&&o.max_prediction==8&&o.max_future==8&&o.seed_upper_bound==6,&o,"unchanged_actual_physics_configuration") {return}
 if !welcome_gate(t,c.time_set&&o.client_now_ms==0&&o.memory_now==0,&o,"unchanged_fixture_zero_time_pumps_NOT_positive_RTT") {return}
 peer_matches:=false
 for peer in pair.server.peers {
  if !peer.local&&peer.phase==.Running&&peer.seat==c.seat&&peer.generation==c.generation&&peer.serial==c.serial {peer_matches=true;break}
 }
 o.current_scope=c.initialized&&c.has_world&&c.physics!=nil&&c.phase==.Running&&c.cfg.epoch==pair.server.cfg.epoch&&c.generation>0&&c.serial>0&&peer_matches
 if !welcome_gate(t,o.current_scope,&o,"actual_complete_Welcome_scope_and_real_ACK") {return}
 if !welcome_gate(t,o.confirmed==o.baseline&&o.baseline==o.server_head&&o.head==o.confirmed+u64(o.lead_ticks)&&o.head-o.confirmed<=u64(o.max_prediction),&o,"actual_Welcome_baseline_and_bounded_held_bootstrap") {return}
 o.full5_equal=ar.full_pair(t,pair,o.confirmed)
 if !welcome_gate(t,o.full5_equal,&o,"actual_confirmed_fullfive_and_signatures") {return}
 o.setup_complete=true;o.stage="ONE_EXISTING_ZERO_RTT_WELCOME_SEED_ASSERTION"
 testing.expect(t,o.lead_ticks==o.expected_zero_rtt_seed,"EXPECTED baseline RED: genuine zero-RTT complete-physics Welcome uses existing +4 RTT seed, not cold configured lead2")
}
