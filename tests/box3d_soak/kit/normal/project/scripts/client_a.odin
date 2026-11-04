//gd:extends Node
//gd:class KitNormalA
package kit_normal_project

import "core:fmt"
import gd "godot:godot"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import p "godot:kit/physics"
import k "godot:kit/sim"
import f "godot:tests/box3d_soak/kit/fixture"
import a "godot:tests/box3d_soak/kit/normal/fixture"

KitNormalA :: struct {owner:gd.Node,state:a.Client_A,repair:^f.State,kind:string,owned:bool,repair_ok:bool,cleanup:f.Cleanup}
@(gd_method)
kit_normal_a_native_images :: proc(self:^KitNormalA)->gd.Int {return gd.Int(native_image_count())}
@(gd_method)
kit_normal_a_prepare :: proc(self:^KitNormalA)->gd.Int {
 if self.owned {return -1};profile:=f.Profile.Dense
 if gd.env_string("GATE_B_FIXTURE","dense")=="common" {profile=.Common}
 self.kind=gd.env_string("GATE_B_NORMAL_KIND","client_prediction");self.owned=true
 if self.kind=="default_repair" {
  root,e:=f.create(profile);self.repair=root
  if e==.Ok && !f.receiver_start(root) {return -1};return gd.Int(e)
 }
 state:a.Client_A;error:k.World_Error
 if self.kind=="authority_step_with_due_signature" {state,error=a.authority_b_create(profile)
 }else if self.kind=="client_prediction" {state,error=a.client_a_create(profile)
 }else{return -1}
 self.state=state;return gd.Int(error)
}
// Functional/public entry. No timer/diagnostic export in the operation.
@(gd_method)
kit_normal_a_operation :: proc(self:^KitNormalA)->bool {
 if !self.owned {return false}
 if self.kind=="default_repair" {
  if self.repair==nil {return false}
  for _ in 0..<20 {if !f.prepare_operation(self.repair) || !f.apply_operation(self.repair) || !f.proof(self.repair) {return false}}
  self.repair_ok=self.repair.operations==20 && self.repair.head_after==162 && self.repair.confirmed_after==162;return self.repair_ok
 }
 if self.kind=="authority_step_with_due_signature" {return a.authority_b_operation(&self.state)}
 return a.client_a_operation(&self.state)
}
@(gd_method)
kit_normal_a_proof :: proc(self:^KitNormalA)->bool {
 if !self.owned {return false}
 if self.kind=="default_repair" {return self.repair_ok}
 if self.kind=="authority_step_with_due_signature" {return a.authority_b_proof(&self.state)}
 return a.client_a_proof(&self.state)
}
// All diagnostics occur in a SEPARATE public Core call AFTER operation return.
normal_observation :: proc(ep:^f.Endpoint($G,$C,$A))->(b.World_Counters,u64,k.World_Error) {
 if ep==nil {return {},0,.Missing_Attachment}
 value,e:=p.observe(&ep.physics);if e!=.Ok {return {},0,e}
 epoch:=k.lane_world_epoch(&ep.lane);if epoch==0 {return {},0,.Incompatible}
 return value.counts,epoch,.Ok
}
digest_token :: proc(d:bd.Digest)->string {
 zero:bd.Digest;if d==zero {return "null"}
 out:[66]u8;out[0]='"';out[65]='"';digits:="0123456789abcdef"
 for value,i in d {out[1+2*i]=digits[value>>4];out[2+2*i]=digits[value&15]}
 return fmt.tprintf("%s",string(out[:]))
}
@(gd_method)
kit_normal_a_facts :: proc(self:^KitNormalA)->gd.String {
 if self.kind=="default_repair" && self.repair!=nil {
  root:=self.repair
  return gd.new_string(fmt.tprintf("{{\"default_repair\":true,\"operations\":%d,\"head\":%d,\"confirmed\":%d,\"full5_equal\":%v,\"first_error\":\"%v\"}}",root.operations,root.head_after,root.confirmed_after,root.equal,root.last_error))
 }
 state:=&self.state
 if state.candidate==nil || state.oracle_handle.data==nil {return gd.new_string_odin("{\"diagnostic_error\":\"missing_owned_state\"}")}
 root:=state.candidate;authority:=self.kind=="authority_step_with_due_signature"
 counts:b.World_Counters;epoch:u64;observation_error:k.World_Error
 if root.profile==.Dense {
  ep:=authority?root.source_dense:root.receiver_dense;counts,epoch,observation_error=normal_observation(ep)
 }else{
  ep:=authority?root.source_common:root.receiver_common;counts,epoch,observation_error=normal_observation(ep)
 }
 domain,de:=b.domain_contract_get();if de!=.Ok {return gd.new_string_odin("{\"diagnostic_error\":\"domain_query\"}")}
 ledger,le:=b.host_ledger_get(domain.cookie)
 if observation_error!=.Ok || le!=.Ok {return gd.new_string_odin("{\"diagnostic_error\":\"counts_or_ledger_query\"}")}
 sink:=state.oracle_handle.data.sink
 published:=state.returned_ticks==1 && state.after_steps==state.before_steps+1 && state.head_after==state.head_before+1 && state.error==.Ok
 outcome:=published?"committed":"error"
 return gd.new_string(fmt.tprintf("{{\"counter_kind\":\"model_step_callback\",\"wire_input_decoder_available\":false,\"return_ticks\":%d,\"actual_steps_before\":%d,\"actual_steps_after\":%d,\"head_before\":%d,\"head_after\":%d,\"confirmed_before\":%d,\"confirmed_after\":%d,\"epoch\":%d,\"base_tick\":%d,\"requested_depth\":0,\"outcome\":\"%s\",\"reference_context_destroyed\":%v,\"full5_equal\":%v,\"publication_atomic\":%v,\"quota_ok\":%v,\"send_calls\":%d,\"send_copies\":%d,\"send_freed\":%d,\"send_bytes\":%d,\"input_packets\":%d,\"accepted_packets\":%d,\"world_chunks\":%d,\"signature_packets\":%d,\"signatures_before\":%d,\"signatures_after\":%d,\"full_states_before\":%d,\"full_states_after\":%d,\"explicit_corrections\":%d,\"authority_peer\":%d,\"expected_tag_stream_ok\":%v,\"send_ok\":%v,\"first_error\":\"%v\",\"cleanup_error\":\"%v\",\"cleanup_tombstone\":%v,\"counts_scope\":\"published_world_only\",\"counts\":{{\"bodies\":%d,\"shapes\":%d,\"contacts\":%d,\"joints\":%d}},\"ledger\":{{\"live_bytes\":%d,\"reserved_bytes\":%d,\"admitted_bytes\":%d,\"limit_bytes\":%d,\"committed_peak_bytes\":%d,\"storage_bytes\":%d}},\"expected_complete_sha256\":%s,\"actual_complete_sha256\":%s}}",state.returned_ticks,state.before_steps,state.after_steps,state.head_before,state.head_after,state.confirmed_before,state.confirmed_after,epoch,state.head_before,outcome,state.reference_context_destroyed,state.full5_equal,published,ledger.admitted_bytes<=ledger.limit_bytes,sink.calls,sink.copies,sink.freed,sink.bytes,sink.input_packets,sink.accepted_packets,sink.world_chunks,sink.signature_packets,state.signatures_before,state.signatures_after,state.full_before,state.full_after,state.explicit_corrections,state.authority_peer,sink.expected_tag_stream_ok,sink.ok,state.error,state.cleanup_error,state.fixture_cleanup_failed,counts.body_count,counts.shape_count,counts.contact_count,counts.joint_count,ledger.live_bytes,ledger.host_reserved_bytes,ledger.admitted_bytes,ledger.limit_bytes,ledger.committed_peak_bytes,ledger.ledger_storage_bytes,digest_token(state.oracle_handle.data.signature.complete),digest_token(state.actual.complete)))
}
@(gd_method)
kit_normal_a_close :: proc(self:^KitNormalA)->gd.String {
 if self.kind=="default_repair" {self.cleanup=f.destroy(&self.repair)}else{self.cleanup=a.client_a_destroy(&self.state)};c:=self.cleanup
 if c.ok {self.owned=false}
 return gd.new_string(fmt.tprintf("{{\"native_live_bytes\":%d,\"snapshot_live_bytes\":%d,\"host_application_live_bytes\":%d,\"ledger_live_bytes\":%d,\"ledger_reserved_bytes\":%d,\"committed_peak_bytes\":%d,\"all_explicit_drops_ok\":%v,\"stats_ok\":%v,\"cleanup_tombstone\":%v,\"first_error\":\"%v\",\"cleanup_error\":\"%v\",\"ownership_evidence\":\"checkedactualSDKhandles_plainoracle_sourcecontextdestroyed\"}}",c.native_live,c.snapshot_live,c.meter_live,c.ledger_live,c.ledger_reserved,c.ledger_peak,c.ok,c.stats_ok,self.state.fixture_cleanup_failed,self.state.error,self.state.cleanup_error))
}
kit_normal_a_exit_tree :: proc(self:^KitNormalA) {if self.owned {if self.kind=="default_repair" {self.cleanup=f.destroy(&self.repair)}else{self.cleanup=a.client_a_destroy(&self.state)};if self.cleanup.ok {self.owned=false}}}
