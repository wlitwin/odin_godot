//gd:extends Node
//gd:class ReplayGateBProbe
package replay_gate_b_probe

import "core:fmt"
import "core:mem"
import gd "godot:godot"
import b "godot:box3d"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import view "godot:replay/view"
import dense "godot:tests/replay_physics_net/fixture"
import common "godot:examples/box3d_common"
import adapter "godot:examples/replay_box3d/shared/adapter"

Operation :: struct {head_before,head_after,confirmed_before,confirmed_after,steps_before,steps_after:u64,error:net.Error,exact8,verified:bool}
ReplayGateBProbe :: struct {
 owner:gd.Node,fixture:Fixture,prepared,correct,closed:bool,
 source_dense,client_dense:^Actor(dense.Game,dense.Control,dense.Action,dense.Event),
 source_common,client_common:^Actor(common.Game,common.Control,common.Action,common.Event),
 operation:Operation,expected,actual:bd.Signature,
 sample_seq:u64,
 cleanup_native,cleanup_snapshot,cleanup_host:u64,cleanup_ok:bool,
 phase_result:Phase_Recorder,phase_context_exact:bool,
 mode:Probe_Mode,normal:Normal_Proof,
 oracle_dense:^Dense_Actor,
 prediction_bytes:^Prediction_Byte_Store,
 reference_contexts_before,reference_contexts_after:u64,
 reference_fully_destroyed:bool,
}
hex :: proc(value:[]u8)->string{buffer:[64]u8;digits:="0123456789abcdef";for byte,index in value{buffer[index*2]=digits[byte>>4];buffer[index*2+1]=digits[byte&15]};return fmt.tprintf("%s",string(buffer[:len(value)*2]))}

@(gd_method)
replay_gate_b_probe_probe_native_images :: proc(self:^ReplayGateBProbe)->gd.Int{return gd.Int(native_image_count())}

@(gd_method)
replay_gate_b_probe_probe_native_contract :: proc(self:^ReplayGateBProbe)->gd.String{
 contract,status:=b.domain_contract_get()
 return gd.new_string(fmt.tprintf("{{\"status\":%d,\"cookie_hex\":\"%x\",\"build\":\"%s\",\"target\":\"%s\"}}",status,contract.cookie,hex(contract.build[:]),hex(contract.target[:])))
}

// Test-only activity observation OUTSIDE the repair timer, before the extra
// source oracle. Meter allocation_count is LIVE blocks, not allocation calls.
allocation_snapshot :: proc(source,receiver:^Actor($S,$C,$A,$E))->gd.String{
 if receiver==nil{return gd.new_string(string("{\"ok\":false,\"reason\":\"missing_candidate_actor\"}"))}
 s:meter.Stats;ss:=bg.OK
 if source!=nil{s,ss=meter.stats(source.scope)} // absent B reference is explicit below
 c,cs:=meter.stats(receiver.scope)
 category,ps:=meter.category_stats(bg.CATEGORY_REPLAY_PROVIDER)
 core,rs:=meter.category_stats(bg.CATEGORY_REPLAY_CORE)
 engine,es:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats()
 return gd.new_string(fmt.tprintf("{{\"ok\":%v,\"scope\":\"outside_operation_before_extra_oracle\",\"source\":{{\"present\":%v,\"status\":%d,\"live_bytes\":%d,\"requested_bytes\":%d,\"peak_bytes\":%d,\"live_blocks\":%d}},\"receiver\":{{\"status\":%d,\"live_bytes\":%d,\"requested_bytes\":%d,\"peak_bytes\":%d,\"live_blocks\":%d}},\"provider_category\":{{\"status\":%d,\"live_bytes\":%d,\"requested_bytes\":%d,\"contexts\":%d,\"live_blocks\":%d}},\"core_category\":{{\"status\":%d,\"live_bytes\":%d,\"requested_bytes\":%d,\"contexts\":%d,\"live_blocks\":%d}},\"native_engine\":{{\"status\":%d,\"live_bytes\":%d,\"total_bytes\":%d,\"total_calls\":%d,\"peak_bytes\":%d}},\"snapshot_wrapper\":{{\"status\":%d,\"live_bytes\":%d,\"total_bytes\":%d,\"total_calls\":%d,\"peak_bytes\":%d}}}}",ss==bg.OK&&cs==bg.OK&&ps==bg.OK&&rs==bg.OK&&es==.Ok&&ws==.Ok,source!=nil,ss,s.live_bytes,s.requested_bytes,s.peak_bytes,s.allocation_count,cs,c.live_bytes,c.requested_bytes,c.peak_bytes,c.allocation_count,ps,category.live_bytes,category.requested_bytes,category.contexts,category.allocations,rs,core.live_bytes,core.requested_bytes,core.contexts,core.allocations,es,engine.live_bytes,engine.total_bytes,engine.total_calls,engine.high_water_bytes,ws,wrapper.live_bytes,wrapper.total_bytes,wrapper.total_calls,wrapper.high_water_bytes))
}
@(gd_method)
replay_gate_b_probe_probe_allocations :: proc(self:^ReplayGateBProbe)->gd.String{
 if self.fixture==.Dense{return allocation_snapshot(self.source_dense,self.client_dense)}
 return allocation_snapshot(self.source_common,self.client_common)
}
normal_context_diagnostic :: proc(a:^Dense_Actor)->string{
 if a==nil{return "null"}
 stats,status:=meter.stats(a.scope)
 return fmt.tprintf("{{\"status\":%d,\"context_references\":%d,\"live_blocks\":%d,\"codec_runtime_leases\":%d,\"golden_bytes\":%d,\"client_history\":%d,\"server_history\":%d,\"link_ready\":%v,\"lane0_user\":\"%x\",\"lane1_user\":\"%x\",\"diagnostic_stage\":%d,\"diagnostic_status\":%d,\"diagnostic_user\":\"%x\"}}",status,stats.references,stats.allocation_count,a.codec.runtime_leases,len(a.golden.storage),len(a.client.timeline.records),len(a.source.timeline.records),a.link.ready,u64(uintptr(a.lane_leases[0].user)),u64(uintptr(a.lane_leases[1].user)),a.diagnostic_stage,a.diagnostic_status,a.diagnostic_user)
}
@(gd_method)
replay_gate_b_probe_probe_preparation_diagnostics :: proc(self:^ReplayGateBProbe)->gd.String{
 store_bytes:=0;if self.prediction_bytes!=nil{store_bytes=len(self.prediction_bytes.storage)}
 return gd.new_string(fmt.tprintf("{{\"source\":%s,\"oracle\":%s,\"candidate\":%s,\"reference_fully_destroyed\":%v,\"reference_contexts_before\":%d,\"reference_contexts_after\":%d,\"independent_store_bytes\":%d,\"stage310_status_domain\":\"public Meter.block_lease\",\"stage311_status_domain\":\"public owner_context_create\",\"stage410_status_domain\":\"public client_init\"}}",normal_context_diagnostic(self.source_dense),normal_context_diagnostic(self.oracle_dense),normal_context_diagnostic(self.client_dense),self.reference_fully_destroyed,self.reference_contexts_before,self.reference_contexts_after,store_bytes))
}

@(gd_method)
replay_gate_b_probe_probe_prepare :: proc(self:^ReplayGateBProbe)->gd.Int{
 if self.source_dense!=nil || self.client_dense!=nil || self.source_common!=nil || self.client_common!=nil || self.oracle_dense!=nil || self.prediction_bytes!=nil{return 99}
 self.prepared=false;self.correct=false;self.closed=false;self.cleanup_ok=false;self.operation={};self.expected={};self.actual={};self.phase_result={};self.phase_context_exact=false
 if !phase_controls(){return 98}
 name:=gd.env_string("GATE_B_FIXTURE","dense");if name=="common"{self.fixture=.Common}else if name!="dense"{return 1}
 operation:=gd.env_string("GATE_B_OPERATION","repair8");self.mode=.Repair8;self.normal={}
 self.reference_contexts_before=0;self.reference_contexts_after=0;self.reference_fully_destroyed=false
 if operation=="client_prediction_send"{self.mode=.Client_Normal}else if operation=="authority_step_requested_canonical"{self.mode=.Authority_Normal}else if operation!="repair8"{return 97}
 observed_counts={};observed_peak={}
 if self.mode!=.Repair8{
  if self.fixture!=.Dense{return 96}
  if code:=normal_prepare(self);code!=0{return gd.Int(code)}
  self.prepared=true;return 0
 }
 if self.fixture==.Dense{
  self.source_dense=actor_create(dense.Game,dense.Control,dense.Action,dense.Event);if self.source_dense==nil{return 2}
  source:=self.source_dense;catalog,status:=dense_catalog();if status!=.Ok{return 3};config:=dense_config(&catalog)
  if !actor_codec(source,catalog,config,dense_rules()){return 4}
  world,game,ws:=dense.world(32);if ws!=.Ok{return 5};model:=dense_model(&source.codec);model.step=dense_observed
  if !actor_source_prepare(source,world,game,config,model,dense_stimulus){return 6}
  self.client_dense=actor_create(dense.Game,dense.Control,dense.Action,dense.Event);if self.client_dense==nil{return 7}
  client:=self.client_dense;receiver_catalog,rs:=dense_catalog();if rs!=.Ok{return 8}
  if !actor_codec(client,receiver_catalog,dense_config(&receiver_catalog),dense_rules()){return 9}
  receiver_model:=dense_model(&client.codec);receiver_model.step=dense_observed
  if !actor_receiver_prepare(client,source,receiver_model) || !actor_queue_repair(client,source){return 10}
  actor_phase_install(client)
  self.phase_context_exact=!client.recorder.requested || (client.client.ownership.profile_clock.data==rawptr(&client.recorder) && client.client.ownership.profile_sample.data==rawptr(&client.recorder) && !r.owner_is_nil(client.client.ownership.profile_clock.owner) && !r.owner_is_nil(client.client.ownership.profile_sample.owner))
 }else{
  self.source_common=actor_create(common.Game,common.Control,common.Action,common.Event);if self.source_common==nil{return 12}
  source:=self.source_common;catalog,status:=common_catalog();if status!=.Ok{return 13};config:=adapter.config(&catalog,32)
  if !actor_codec(source,catalog,config,adapter.rules(32,1)){return 14}
  world,game,ws:=common.world(32,1);if ws!=.Ok{return 15};model:=adapter.model(&source.codec);model.step=common_observed
  if !actor_source_prepare(source,world,game,config,model,common_stimulus){return 16}
  self.client_common=actor_create(common.Game,common.Control,common.Action,common.Event);if self.client_common==nil{return 17}
  client:=self.client_common;receiver_catalog,rs:=common_catalog();if rs!=.Ok{return 18}
  if !actor_codec(client,receiver_catalog,adapter.config(&receiver_catalog,32),adapter.rules(32,1)){return 19}
  receiver_model:=adapter.model(&client.codec);receiver_model.step=common_observed
  if !actor_receiver_prepare(client,source,receiver_model) || !actor_queue_repair(client,source){return 20}
  actor_phase_install(client)
  self.phase_context_exact=!client.recorder.requested || (client.client.ownership.profile_clock.data==rawptr(&client.recorder) && client.client.ownership.profile_sample.data==rawptr(&client.recorder) && !r.owner_is_nil(client.client.ownership.profile_clock.owner) && !r.owner_is_nil(client.client.ownership.profile_sample.owner))
 }
 self.prepared=true;return 0
}
repair :: proc(a:^Actor($S,$C,$A,$E))->Operation{
 c:=&a.client
 result:=Operation{head_before=c.timeline.head,confirmed_before=c.timeline.confirmed,steps_before=c.stats.replayed_ticks}
 before_repairs,before_verified:=c.physics.repairs,c.physics.verified_compares
 if result.head_before!=160 || result.confirmed_before!=152{result.error=.Invalid_Frame;return result}
 // Actual lower public Memory packet receive/routing/reassembly stays INSIDE
 // this method, before the existing public Client decode/revision pipeline.
 link_started,_:=phase_now(&a.recorder)
 if !rec.link_pump(&a.link,2560){result.error=.Invalid_Time;return result}
 link_ended,_:=phase_now(&a.recorder);phase_push(&a.recorder,.Link,.Pump,link_started,link_ended)
 client_started,_:=phase_now(&a.recorder)
 result.error=net.client_pump(c,2560)
 client_ended,_:=phase_now(&a.recorder);phase_push(&a.recorder,.Client,.Pump,client_started,client_ended)
 journal_started,_:=phase_now(&a.recorder)
 actor_drain(a)
 journal_ended,_:=phase_now(&a.recorder);phase_push(&a.recorder,.Journal,.Pump,journal_started,journal_ended)
 result.head_after=c.timeline.head;result.confirmed_after=c.timeline.confirmed;result.steps_after=c.stats.replayed_ticks
 result.exact8=result.error==.None && result.steps_after-result.steps_before==8 && c.physics.repairs==before_repairs+1 && result.head_after==160 && result.confirmed_after==160
 result.verified=c.physics.verified_compares==before_verified+1 && !c.physics.trace.ready
 return result
}
@(gd_method)
replay_gate_b_probe_probe_repair :: proc(self:^ReplayGateBProbe)->gd.Int{
 if !self.prepared{return 1}
 self.sample_seq+=1
 if self.mode!=.Repair8{
  if self.mode==.Client_Normal{self.normal=normal_client(self.client_dense)}else{self.normal=normal_authority(self.client_dense)}
  return normal_ok(self.normal)?0:2
 }
 recorder:^Phase_Recorder
 if self.fixture==.Dense{recorder=&self.client_dense.recorder;self.client_dense.codec.native_decode={}}else{recorder=&self.client_common.recorder;self.client_common.codec.native_decode={}}
 phase_begin(recorder)
 if self.fixture==.Dense{self.operation=repair(self.client_dense)}else{self.operation=repair(self.client_common)}
 if self.fixture==.Dense{recorder.native=self.client_dense.codec.native_decode}else{recorder.native=self.client_common.codec.native_decode}
 phase_end(recorder)
 self.phase_result=recorder^
 return self.operation.exact8 && self.operation.verified && phase_ok(recorder) && self.phase_context_exact?0:2
}
verify :: proc(a:^Actor($S,$C,$A,$E),source:^Actor(S,C,A,E),authority:bool=false)->(bd.Signature,bd.Signature,bool){
 cp:r.Complete_Checkpoint(S,net.Net_Event(E));error:r.Error
 if authority{cp,error=r.capture_complete(&a.source.timeline,160,a.allocator)}else{cp,error=r.capture_complete(&a.client.timeline,160,a.allocator)}
 if error!=.None{return {},{},false};defer r.complete_checkpoint_destroy(&cp)
 actual_view:net.Complete_View;ve:net.Error
 if authority{actual_view,ve=net.complete_view(a.codec.value,&cp,&a.source.physics.schemas.state,&a.source.physics.schemas.occurrence,a.allocator)}else{actual_view,ve=net.complete_view(a.codec.value,&cp,&a.client.physics.schemas.state,&a.client.physics.schemas.occurrence,a.allocator)}
 if ve!=.None{return {},{},false};defer net.complete_view_destroy(&actual_view)
 signature,se:=bd.sign(actual_view.frame);expected,expected_error:=bd.sign(source.golden.frame)
 equal:=se==.None && expected_error==.None && bd.compare(expected,signature)==.Match
 for part in bd.Part{if mem.compare(source.golden.frame.parts[part],actual_view.frame.parts[part])!=0{equal=false}}
 return expected,signature,equal
}
@(gd_method)
replay_gate_b_probe_probe_verify :: proc(self:^ReplayGateBProbe)->gd.Int{
 if self.mode!=.Repair8{
  if self.mode==.Client_Normal{self.expected,self.actual,self.correct=verify_prediction_bytes(self.client_dense,self.prediction_bytes);self.correct=self.correct&&normal_input_oracle(self.client_dense)}else{self.expected,self.actual,self.correct=verify_prediction_bytes(self.client_dense,self.prediction_bytes,true);self.correct=self.correct&&normal_chunks_oracle(self.client_dense,self.normal)}
  return self.correct && normal_ok(self.normal)?0:1
 }
 if self.fixture==.Dense{self.expected,self.actual,self.correct=verify(self.client_dense,self.source_dense)}else{self.expected,self.actual,self.correct=verify(self.client_common,self.source_common)}
 return self.correct && self.operation.exact8 && self.operation.verified?0:1
}
@(gd_method)
replay_gate_b_probe_probe_cleanup :: proc(self:^ReplayGateBProbe)->gd.Int{
 ok:=actor_destroy(&self.client_dense);ok=actor_destroy(&self.source_dense)&&ok
 ok=actor_destroy(&self.oracle_dense)&&ok
 ok=(byte_store_destroy(&self.prediction_bytes)==.None)&&ok
 ok=actor_destroy(&self.client_common)&&ok;ok=actor_destroy(&self.source_common)&&ok
 native,ns:=b.engine_allocation_stats();snapshot,ss:=b.snapshot_allocation_stats();host,hs:=meter.category_stats(bg.CATEGORY_REPLAY_PROVIDER);other,os:=meter.category_stats(bg.CATEGORY_REPLAY_CORE)
 self.cleanup_native=native.live_bytes;self.cleanup_snapshot=snapshot.live_bytes;self.cleanup_host=host.live_bytes+other.live_bytes
 self.cleanup_ok=ok && ns==.Ok && ss==.Ok && hs==bg.OK && os==bg.OK && native.live_bytes==0 && snapshot.live_bytes==0 && self.cleanup_host==0
 self.closed=true;return self.cleanup_ok?0:1
}
@(gd_method)
replay_gate_b_probe_probe_records :: proc(self:^ReplayGateBProbe,seq,start_us,end_us:gd.Int)->gd.String{
 if gd.env_string("GATE_B_TIMING_MODE","functional_only")!="profile"{return gd.new_string(string(""))}
 if self.mode!=.Repair8{return normal_records(self,seq,start_us,end_us)}
 contract,status:=b.domain_contract_get();ledger,ledger_status:=b.host_ledger_get(contract.cookie)
 quota_ok:=status==.Ok && ledger_status==.Ok && ledger.live_bytes+ledger.host_reserved_bytes==ledger.admitted_bytes && ledger.admitted_bytes<=ledger.limit_bytes
 o:=self.operation
 recorder:=&self.phase_result
 phase_buffer:[65536]u8
 phases,phases_valid:=phases_write(recorder,u64(start_us),u64(end_us),phase_buffer[:])
 if !phases_valid{self.correct=false}
 outcome:=self.correct && o.exact8 && o.verified?"committed":"error"
 return gd.new_string(fmt.tprintf("{{\"event\":\"GATE_B_SAMPLE\",\"schema\":1,\"run_id\":\"%s\",\"seq\":%d,\"operation\":\"repair8\",\"epoch\":1,\"base_tick\":%d,\"head_before\":%d,\"head_after\":%d,\"confirmed_before\":%d,\"confirmed_after\":%d,\"requested_depth\":8,\"actual_steps_before\":%d,\"actual_steps_after\":%d,\"outcome\":\"%s\",\"outer_start_us\":%d,\"outer_end_us\":%d,\"whole_ns\":%d,\"included_work\":[\"public_dispatch\",\"envelope_reassembly_inspect\",\"canonical_native_read_build_verify_reencode\",\"typed_decode\",\"accepted_input_replay\",\"complete_paired_compare\",\"publication_events\",\"operation_cleanup\",\"core_return\"],\"proof\":{{\"full_state_equal\":%v,\"publication_atomic\":%v,\"quota_ok\":%v,\"expected_complete_sha256\":\"%s\",\"actual_complete_sha256\":\"%s\"}},\"counts\":{{\"bodies\":%d,\"shapes\":%d,\"contacts\":%d,\"joints\":%d}},\"counts_scope\":\"last_actual_replayed_candidate_step; sourceandcandidateRunPeakReportedSeparately\",\"ledger\":{{\"live_bytes\":%d,\"reserved_bytes\":%d,\"admitted_bytes\":%d,\"limit_bytes\":%d,\"committed_peak_bytes\":%d,\"storage_bytes\":%d}},\"phases\":%s,\"phase_observation\":{{\"active\":%v,\"span_count\":%d,\"clock_reads\":%d,\"net_callbacks\":%d,\"clock_errors\":%d,\"overflow\":%d,\"native_calls\":%d,\"native_errors\":%d,\"fallback_compare_calls\":%d,\"layout_valid\":%v}}}}",gd.env_string("GATE_B_RUN_ID","unset"),seq,o.confirmed_before,o.head_before,o.head_after,o.confirmed_before,o.confirmed_after,o.steps_before,o.steps_after,outcome,start_us,end_us,(end_us-start_us)*1000,self.correct,o.exact8 && o.verified,quota_ok,hex(self.expected.complete[:]),hex(self.actual.complete[:]),observed_counts.body_count,observed_counts.shape_count,observed_counts.contact_count,observed_counts.joint_count,ledger.live_bytes,ledger.host_reserved_bytes,ledger.admitted_bytes,ledger.limit_bytes,ledger.committed_peak_bytes,ledger.ledger_storage_bytes,phases,recorder.active,recorder.count,recorder.read_count,recorder.callbacks,recorder.clock_errors,recorder.overflow,recorder.native.samples,recorder.native.errors,phase_calls(recorder,.Physics_Compare),phases_valid))
}
@(gd_method)
replay_gate_b_probe_probe_result :: proc(self:^ReplayGateBProbe)->gd.String{
 if self.mode!=.Repair8{return normal_result(self)}
 return gd.new_string(fmt.tprintf("{{\"correctness_ok\":%v,\"operation\":{{\"head_before\":%d,\"head_after\":%d,\"confirmed_before\":%d,\"confirmed_after\":%d,\"steps_before\":%d,\"steps_after\":%d,\"exact8\":%v,\"verified\":%v}},\"expected_complete_sha256\":\"%s\",\"actual_complete_sha256\":\"%s\",\"counts\":{{\"bodies\":%d,\"shapes\":%d,\"contacts\":%d,\"joints\":%d}},\"phase_observation\":{{\"requested\":%v,\"active\":%v,\"exact_retained_context\":%v,\"clock_reads\":%d,\"clock_errors\":%d,\"overflow\":%d}},\"run_peak\":{{\"bodies\":%d,\"shapes\":%d,\"contacts\":%d,\"joints\":%d}},\"cleanup\":{{\"native_live_bytes\":%d,\"snapshot_live_bytes\":%d,\"host_application_live_bytes\":%d,\"all_explicit_drops_ok\":%v,\"ownership_evidence\":\"checked explicit drops and Meter0; shutdown checked by outer controller\"}}}}",self.correct && self.operation.exact8 && self.operation.verified,self.operation.head_before,self.operation.head_after,self.operation.confirmed_before,self.operation.confirmed_after,self.operation.steps_before,self.operation.steps_after,self.operation.exact8,self.operation.verified,hex(self.expected.complete[:]),hex(self.actual.complete[:]),observed_counts.body_count,observed_counts.shape_count,observed_counts.contact_count,observed_counts.joint_count,self.phase_result.requested,self.phase_result.active,self.phase_context_exact,self.phase_result.read_count,self.phase_result.clock_errors,self.phase_result.overflow,observed_peak.body_count,observed_peak.shape_count,observed_peak.contact_count,observed_peak.joint_count,self.cleanup_native,self.cleanup_snapshot,self.cleanup_host,self.cleanup_ok))
}
replay_gate_b_probe_exit_tree :: proc(self:^ReplayGateBProbe){if !self.closed{replay_gate_b_probe_probe_cleanup(self)}}
