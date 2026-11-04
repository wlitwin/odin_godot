//gd:extends Node
//gd:class KitGateB
package kit_gate_b_project

import "core:fmt"
import gd "godot:godot"
import b "godot:box3d"
import bg "godot:box3d/godot"
import bp "godot:box3d/diagnostics"
import f "godot:tests/box3d_soak/kit/fixture"
import p "godot:kit/physics"
import bm "godot:box3d/godot/meter"
import obs "godot:tests/box3d_soak/native_observe"

OBSERVATION_COMPILED :: #config(GATE_B_NATIVE_OBSERVATION,false)
KitGateB :: struct {owner:gd.Node,state:^f.State,cleanup:f.Cleanup,failed:bool,
 observation:obs.Owner,observation_sdk:p.SDK_Context,observation_mode:obs.Mode,
 observation_controls:bool,
 observation_operations,observation_steps,observation_captures:u64}
@(gd_method)
kit_gate_b_native_images :: proc(self:^KitGateB)->gd.Int {return gd.Int(native_image_count())}
@(gd_method)
kit_gate_b_failure :: proc(self:^KitGateB)->gd.String {
 r:=self.state;if r==nil{return gd.new_string_odin("{}")}
 return gd.new_string(fmt.tprintf("{{\"stage\":%d,\"progress_tick\":%d,\"last_error\":\"%v\",\"saved_packet_bytes\":%d,\"source_freed\":%v}}",r.stage,r.progress_tick,r.last_error,r.saved_bytes,r.source_freed))
}
@(gd_method)
kit_gate_b_prepare :: proc(self:^KitGateB)->gd.Int {
 if self.state!=nil{return -1}
 when OBSERVATION_COMPILED {
  mode:=gd.env_string("GATE_B_OBSERVATION","off")
  if mode!="off" && mode!="structure" && mode!="timed" {self.failed=true;return -1}
  if mode=="timed" && (gd.env_string("GATE_B_MODE","")!="profile" || gd.env_string("GATE_B_EXCLUSIVE_GRANT","")=="") {self.failed=true;return -1}
  self.observation_mode=mode=="timed"?.Timed:(mode=="structure"?.Structure:.Off)
  // Independent managed allocator/block/code owners exist BEFORE the source
  // endpoints are constructed and actually destroyed by fixture preparation.
  sdk,se:=p.sdk_context_create();if se!=.Ok {self.failed=true;return gd.Int(se)}
  self.observation_sdk=sdk
  observation,oe:=obs.create(sdk.memory);self.observation=observation
  if oe!=bg.OK {self.failed=true;return gd.Int(oe)}
  if self.observation_mode==.Timed && !native_clock_prepare(observation.block) {self.failed=true;return -1}
 }
 which:=f.Profile.Dense;if gd.env_string("GATE_B_FIXTURE","dense")=="common"{which=.Common}
 state,e:=f.create(which);self.state=state;self.failed=e!=.Ok
 when OBSERVATION_COMPILED {
  if e==.Ok {self.observation_controls=obs.ownership_controls(self.observation_sdk.memory);if !self.observation_controls {self.failed=true;return -1}}
 }
 return gd.Int(e)
}
@(gd_method)
kit_gate_b_start :: proc(self:^KitGateB)->bool {ok:=self.state!=nil&&f.receiver_start(self.state);self.failed=self.failed||!ok;return ok}
@(gd_method)
kit_gate_b_predict :: proc(self:^KitGateB)->bool {ok:=self.state!=nil&&f.prepare_operation(self.state);self.failed=self.failed||!ok;return ok}
// Whole receiver boundary. The GDScript caller may time THIS public call only
// after Root grants profiling. No extra timer/diagnostic capture in this method.
@(gd_method)
kit_gate_b_apply :: proc(self:^KitGateB,timed:bool)->bool {
 when OBSERVATION_COMPILED {
  mode:=self.observation_mode
  // The twentieth fresh154->162 ownership/oracle control remains UNTIMED.
  if mode==.Timed && !timed {mode=.Structure}
  if mode!=.Off {
   clock:obs.Clock;if mode==.Timed {clock=native_clock_read}
   if obs.begin(&self.observation,mode,clock)!=bg.OK {self.failed=true;return false}
   ok:=self.state!=nil&&f.apply_operation(self.state)
   // A valid end always detaches even if the diagnostic block reports errors.
   ended:=obs.end(&self.observation)==bg.OK
   self.failed=self.failed||!ok||!ended;return ok&&ended
  }
 }
 ok:=self.state!=nil&&f.apply_operation(self.state);self.failed=self.failed||!ok;return ok
}
// Diagnostic scanning/formatting is deliberately a SEPARATE public Core call,
// after apply has completely returned. Structure mode never reads a clock.
@(gd_method)
kit_gate_b_observation :: proc(self:^KitGateB,validate:bool)->gd.String {
 when OBSERVATION_COMPILED {
  block:=self.observation.block
  if block==nil{return gd.new_string_odin("{\"valid\":false}")}
  steps,captures,root_captures,reads:=u64(0),u64(0),u64(0),u64(0)
  for span in block.spans[:block.count] {
   if span.phase==1 {steps+=1};if span.phase==2 {captures+=1;if span.parent_id==0 {root_captures+=1}}
   if span.phase==8 {reads+=1}
  }
  memory,me:=bm.stats(self.observation_sdk.memory)
  expected_clock_reads:=block.mode==2?u64(block.count)*2:0
  valid:=self.observation_controls && me==bg.OK && self.observation.token==0 && block.clock_reads==expected_clock_reads && block.error_flags==0 && block.stack_depth==0
  if validate && self.observation_mode!=.Off {
   valid=valid && block.state==2 && steps==8 && root_captures==8 && reads==0
   self.observation_operations+=1;self.observation_steps+=steps;self.observation_captures+=captures
  }
  // Attribution validity fails the PROBE separately; it never rewrites the
  // actual committed game outcome or introduces a simulation admission rule.
  name:=self.observation_mode==.Timed?"timed":(self.observation_mode==.Structure?"structure":"off")
  return gd.new_string(fmt.tprintf("{{\"compiled\":true,\"mode\":\"%s\",\"scope_mode\":%d,\"valid\":%v,\"block_bytes\":49392,\"native_static_bytes\":%d,\"binding_test_static_bytes\":%d,\"clock_binding_static_bytes\":%d,\"clock_prewarm_reads\":%d,\"raw_json_capacity_bytes\":%d,\"meter_live_bytes\":%d,\"meter_requested_bytes\":%d,\"meter_references\":%d,\"lease_controls_ok\":%v,\"span_count\":%d,\"root_count\":%d,\"steps\":%d,\"captures\":%d,\"root_captures\":%d,\"reads\":%d,\"clock_reads\":%d,\"errors\":%d,\"operations\":%d,\"total_steps\":%d,\"total_captures\":%d,\"source_freed\":%v}}",name,block.mode,valid,self.observation.static_bytes,obs.drop_test_static_bytes,size_of(Native_Clock_State),native_clock.prewarm_reads,obs.RAW_JSON_BYTES,memory.live_bytes,memory.requested_bytes,memory.references,self.observation_controls,block.count,block.root_count,steps,captures,root_captures,reads,block.clock_reads,block.error_flags,self.observation_operations,self.observation_steps,self.observation_captures,self.state!=nil&&self.state.source_freed))
 }
 return gd.new_string_odin("{\"compiled\":false,\"mode\":\"off\",\"valid\":true}")
}
// Raw/derived/control JSON remains original Odin integer text all the way to
// the GDScript record composer. No numeric Variant decoder is on this path.
native_export :: proc(self:^KitGateB,kind:u32)->gd.String {
 when OBSERVATION_COMPILED {
  if obs.check(&self.observation,bg.READ)!=bg.OK {return gd.new_string_odin("{\"export_error\":\"owner\"}")}
  buffer,allocation_error:=make([]u8,obs.RAW_JSON_BYTES,self.observation.allocator)
  if allocation_error!=nil {return gd.new_string_odin("{\"export_error\":\"allocation\"}")}
  defer delete(buffer,self.observation.allocator)
  text:string;status:bg.Status
  switch kind {case 0:text,status=obs.raw_write(&self.observation,buffer);case 1:text,status=obs.phases_write(&self.observation,buffer);case 2:text,status=obs.precision_write(&self.observation,buffer);case:return gd.new_string_odin("{}")}
  if status!=bg.OK {return gd.new_string_odin("{\"export_error\":\"write\"}")}
  return gd.new_string_odin(text)
 }
 return gd.new_string_odin("{}")
}
@(gd_method)
kit_gate_b_native_spans :: proc(self:^KitGateB)->gd.String {return native_export(self,0)}
@(gd_method)
kit_gate_b_native_phases :: proc(self:^KitGateB)->gd.String {return native_export(self,1)}
@(gd_method)
kit_gate_b_precision :: proc(self:^KitGateB)->gd.String {return native_export(self,2)}
@(gd_method)
kit_gate_b_proof :: proc(self:^KitGateB)->bool {ok:=self.state!=nil&&f.proof(self.state);self.failed=self.failed||!ok;return ok}
@(gd_method)
kit_gate_b_descriptor :: proc(self:^KitGateB)->gd.String {
 r:=self.state;if r==nil{return gd.new_string_odin("{}")}
 definition:=f.rules(r.profile);accepted:=r.accepted_trace
 windows:=bp.hash_bytes(transmute([]u8)#load("../functional.gd"))
 bound,e:=bp.hash_descriptors("kit-gate-b-actual-descriptor-v1",[]bp.Descriptor{{"accepted",accepted[:]},{"definition",definition[:]},{"measurement_windows",windows[:]}});assert(e==.None)
 return gd.new_string(fmt.tprintf("{{\"descriptor_sha256\":\"%s\",\"accepted_trajectory_sha256\":\"%s\",\"accepted_rows\":%d,\"source_freed\":%v}}",hex(bound),hex(accepted),r.accepted_rows,r.source_freed))
}
hex :: proc(value:bp.Digest)->string {bytes:[64]u8;digits:="0123456789abcdef";for v,i in value {bytes[2*i]=digits[v>>4];bytes[2*i+1]=digits[v&15]};return fmt.tprintf("%s",string(bytes[:]))}
@(gd_method)
kit_gate_b_facts :: proc(self:^KitGateB)->gd.String {
 r:=self.state;if r==nil{return gd.new_string_odin("{}")}
 c:=f.observe(r);domain,de:=b.domain_contract_get();ledger,le:=b.host_ledger_get(domain.cookie)
 assert(de==.Ok&&le==.Ok)
 text:=fmt.tprintf("{{\"epoch\":%d,\"base_tick\":%d,\"head_before\":%d,\"head_after\":%d,\"confirmed_before\":%d,\"confirmed_after\":%d,\"requested_depth\":8,\"counter_kind\":\"model_step_callback\",\"actual_steps_before\":%d,\"actual_steps_after\":%d,\"outcome\":\"%s\",\"counts\":{{\"bodies\":%d,\"shapes\":%d,\"contacts\":%d,\"joints\":%d}},\"counts_scope\":\"published_world_only\",\"ledger\":{{\"live_bytes\":%d,\"reserved_bytes\":%d,\"admitted_bytes\":%d,\"limit_bytes\":%d,\"committed_peak_bytes\":%d,\"storage_bytes\":%d}},\"fx_delta\":%d,\"source_freed\":%v,\"saved_packet_bytes\":%d,\"accepted_packets\":%d,\"signature_packets\":%d,\"signatures_before\":%d,\"signatures_after\":%d,\"full_states_before\":%d,\"full_states_after\":%d,\"run_peak\":{{\"bodies\":%d,\"shapes\":%d,\"contacts\":%d,\"joints\":%d}},\"expected_complete_sha256\":\"%s\",\"actual_complete_sha256\":\"%s\",\"full_state_equal\":%v,\"publication_atomic\":%v,\"quota_ok\":%v}}",r.actual_signature.epoch,r.confirmed_before,r.head_before,r.head_after,r.confirmed_before,r.confirmed_after,r.before_steps,r.after_steps,self.failed?"error":"committed",c.body_count,c.shape_count,c.contact_count,c.joint_count,ledger.live_bytes,ledger.host_reserved_bytes,ledger.admitted_bytes,ledger.limit_bytes,ledger.committed_peak_bytes,ledger.ledger_storage_bytes,r.fx_after-r.fx_before,r.source_freed,r.saved_bytes,r.received_accepted,r.received_signatures,r.matched_before,r.matched_after,r.full_before,r.full_after,r.peak.body_count,r.peak.shape_count,r.peak.contact_count,r.peak.joint_count,hex(r.current_expected_signature.complete),hex(r.actual_signature.complete),r.equal,r.publication_atomic,ledger.admitted_bytes<=ledger.limit_bytes)
 return gd.new_string(text)
}
@(gd_method)
kit_gate_b_close :: proc(self:^KitGateB)->gd.String {
 when OBSERVATION_COMPILED {
  if obs.destroy(&self.observation)!=bg.OK || p.sdk_context_destroy(&self.observation_sdk)!=.Ok {self.failed=true}
  if self.observation.token==0 {native_clock_clear()}
 }
 self.cleanup=f.destroy(&self.state);c:=self.cleanup
 c.ok=c.ok&&!self.failed
 return gd.new_string(fmt.tprintf("{{\"native_live_bytes\":%d,\"snapshot_live_bytes\":%d,\"host_application_live_bytes\":%d,\"all_explicit_drops_ok\":%v,\"stats_ok\":%v,\"ledger_live_bytes\":%d,\"ledger_reserved_bytes\":%d,\"committed_peak_bytes\":%d,\"ownership_evidence\":\"explicitcheckedSDKdrops_plus_Meter0_realCore\"}}",c.native_live,c.snapshot_live,c.meter_live,c.ok,c.stats_ok,c.ledger_live,c.ledger_reserved,c.ledger_peak))
}
kit_gate_b_exit_tree :: proc(self:^KitGateB) {
 when OBSERVATION_COMPILED {_=obs.destroy(&self.observation);if self.observation.token==0 {native_clock_clear()};_=p.sdk_context_destroy(&self.observation_sdk)}
 if self.state!=nil{self.cleanup=f.destroy(&self.state)}
}
