package replay_input_fidelity_test

// Public complete-physics generic4/static OFFddff/nilOwner baseline.
// No private packet parser, state setter, copied Kernel or new timing algorithm.
import "core:encoding/json"
import "core:mem"
import "core:os"
import "core:testing"
import b "godot:box3d"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"
import tr "godot:replay/transport"
import ar "godot:tests/box3d_soak/replay/action_retire"
import f "godot:tests/replay_physics_net/fixture"

Observation :: struct {
 scope,stage:string,setup_complete,control_admitted,control_executed,header_current_scope,complete_applied,full5_equal,cleanup_observed:bool,
 initial_host_head,initial_client_head,initial_confirmed,target,epoch,generation,serial:u64,
 submitted,accepted,executed:f.Control,origin:u32,
 server_input_newest,snapshot_input_newest,snapshot_id,snapshot_tick,final_head,final_confirmed:u64,
 compares_before,compares_after,timing_samples_before,timing_samples_after:u64,
 scale_before,scale_after:f64,feedback_inactive,feedback_active:bool,
 transport_trace_count,transport_trace_dropped:int,transport_trace_hash:u64,
 native_live,wrapper_live,provider_live,odin_live:u64,
}
write_json :: proc(name:string,value:$T){bytes,error:=json.marshal(value);assert(error==nil);defer delete(bytes);assert(os.write_entire_file(name,bytes)==nil)}
gate :: proc(t:^testing.T,ok:bool,o:^Observation,stage:string)->bool{o.stage=stage;testing.expect(t,ok,stage);return ok}

@(test)
complete_snapshot_existing_input_feedback_is_active :: proc(t:^testing.T){
 backing:=context.allocator;tracking:mem.Tracking_Allocator
 mem.tracking_allocator_init(&tracking,backing,backing);context.allocator=mem.tracking_allocator(&tracking)
 o:=Observation{scope="public_generic4_static_OFFddff_nilOwner_completePhysics_ServerClient_Memory_NOT_CoreSDK32_or_GateB",stage="open"}
 pair:=new(ar.Pair)
 defer {
  o.transport_trace_count=pair.memory.trace_count;o.transport_trace_dropped=pair.memory.trace_dropped;o.transport_trace_hash=pair.memory.trace_hash
  if pair.memory.trace_count>0{write_json("actual-memory-trace.json",pair.memory.trace[:pair.memory.trace_count])}
  ar.close(t,pair);free(pair)
  engine,es:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats();provider:=ph.allocation_stats()
  o.native_live=engine.live_bytes;o.wrapper_live=wrapper.live_bytes;o.provider_live=provider.live_bytes;o.odin_live=u64(tracking.current_memory_allocated)
  o.cleanup_observed=es==.Ok&&ws==.Ok&&o.native_live==0&&o.wrapper_live==0&&o.provider_live==0&&o.odin_live==0
  testing.expect(t,o.cleanup_observed)
  context.allocator=backing;mem.tracking_allocator_destroy(&tracking);write_json("observation.json",o)
 }
 if !ar.open(t,pair){return}
 o.initial_host_head=pair.server.timeline.head;o.initial_client_head=pair.client.timeline.head;o.initial_confirmed=pair.client.timeline.confirmed
 o.epoch=pair.client.cfg.epoch;o.generation=pair.client.generation;o.serial=pair.client.serial
 o.target=o.initial_client_head+1;o.submitted={x=100,z=0}
 o.timing_samples_before=pair.client.stats.timing_samples;o.scale_before=pair.client.clock_scale
 o.compares_before=pair.client.physics.verified_compares+pair.client.physics.full_compares
 if !gate(t,o.target>o.initial_host_head&&o.target-o.initial_host_head<=8,&o,"public_target_within_existing_window"){return}
 if !ar.none(t,net.client_step(&pair.client,o.submitted),"genuine nonzero client control"){return}
 if !gate(t,pair.client.timeline.head==o.target,&o,"actual_client_proposal_tick"){return}
 if !gate(t,tr.memory_advance(&pair.memory,17),&o,"public_memory_delivery"){return}
 if !ar.none(t,net.server_pump(&pair.server,17),"receive genuine client proposal"){return}
 found_peer:=false
 for peer in pair.server.peers{if peer.seat==pair.client.seat&&!peer.local{o.server_input_newest=peer.input_newest;found_peer=true;break}}
 if !gate(t,found_peer&&o.server_input_newest==o.target&&o.server_input_newest>0,&o,"actual_authority_input_newest"){return}
 // Drive only the existing public runner, with the existing bounded gap<=8.
 for index in 0..<int(o.target-o.initial_host_head){
  now:=u64(34+index*17)
  if !gate(t,tr.memory_advance(&pair.memory,now),&o,"public_next_service_time"){return}
  if !ar.none(t,net.server_pump(&pair.server,now),"ordinary input and ACK pump"){return}
  if !ar.none(t,net.server_step(&pair.server),"ordinary authority step"){return}
  if !gate(t,tr.memory_advance(&pair.memory,now),&o,"real authority response delivery"){return}
  if !ar.none(t,net.client_pump(&pair.client,now),"validated complete physics snapshot"){return}
 }
 accepted,found:=net.server_accepted_input(&pair.server,o.target)
 if !gate(t,found&&pair.client.seat==2,&o,"actual_published_authority_input"){return}
 o.accepted=accepted.batch.controls[1];o.origin=u32(accepted.decisions.origins[1])
 o.control_admitted=o.accepted==o.submitted&&accepted.decisions.origins[1]==.Sample
 if !gate(t,o.control_admitted,&o,"nonzero_control_admitted_separately_from_state_equality"){return}
 executed,executed_found:=r.read_input(&pair.server.timeline,o.target)
 if executed_found{o.executed=executed.controls[1]}
 checkpoint,checkpoint_error:=r.capture_complete(&pair.server.timeline,o.target)
 committed_tick:=u64(0);if checkpoint_error==.None{committed_tick=checkpoint.frame.state.tick;r.complete_checkpoint_destroy(&checkpoint)}
 o.control_executed=executed_found&&o.executed==o.submitted&&checkpoint_error==.None&&committed_tick==o.target
 if !gate(t,o.control_executed,&o,"nonzero_committed_execution_input_and_real_frame"){return}
 // Public pump leaves the typed Snapshot header value even after pending data
 // is destroyed. No private complete-packet parser or synthetic header needed.
 header:=pair.client.pending
 o.snapshot_input_newest=header.input_newest;o.snapshot_id=header.snapshot_id;o.snapshot_tick=header.frame.tick
 o.final_head=pair.client.timeline.head;o.final_confirmed=pair.client.timeline.confirmed
 o.compares_after=pair.client.physics.verified_compares+pair.client.physics.full_compares
 o.header_current_scope=header.generation==o.generation&&header.serial==o.serial&&pair.client.cfg.epoch==o.epoch&&header.frame.tick==o.target&&header.snapshot_id>0
 o.complete_applied=o.header_current_scope&&o.snapshot_input_newest==o.server_input_newest&&o.snapshot_input_newest>0&&o.final_confirmed>=o.target&&o.compares_after>o.compares_before
 if !gate(t,o.complete_applied,&o,"actual_current_scope_input_echo_on_verified_complete_snapshot"){return}
 o.full5_equal=ar.full_pair(t,pair,o.target)
 if !gate(t,o.full5_equal,&o,"fullfive_signature_pair"){return}
 o.timing_samples_after=pair.client.stats.timing_samples;o.scale_after=pair.client.clock_scale
 o.feedback_inactive=o.timing_samples_after==o.timing_samples_before&&o.scale_after==1
 o.feedback_active=o.timing_samples_after>o.timing_samples_before&&o.scale_after>1&&o.scale_after<=1.02
 o.setup_complete=true;o.stage="ONE_EXISTING_FEEDBACK_ACTIVITY_ASSERTION"
 testing.expect(t,o.feedback_active,"EXPECTED baseline RED: validated complete Snapshot input_newest must activate the EXISTING input feedback routine; current physics path leaves samples0/scale1")
}
