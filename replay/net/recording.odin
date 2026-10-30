package replay_net

import r "godot:replay"
import d "godot:replay/diagnostic"

// Replay the exact Batch/Net_Event contract used by server and client timelines.
// Keep model and its immutable user data alive at a stable address throughout
// verification. Admission, transport, scheduling and presentation are not rerun:
// their accepted/rejected decisions are already represented in each batch.
recording_model :: proc(model:^Model($S,$C,$A,$E,$N))->d.Recording_Model(S,Batch(C,A,N),Net_Event(E)) {
 #assert(N>=1 && N<=8)
 if model==nil || model.control_valid==nil || model.state_valid==nil || (model.step==nil && model.step_view==nil) || !group_config_valid(model.group) || !authority_policy_valid(model.authority) {return {}}
 return {
  step=proc(state:^S,input:Batch(C,A,N),ctx:^r.Step(Net_Event(E))) {network_step(state,input,ctx)},
  state_valid=model.state_valid,
  input_check=proc(input:Batch(C,A,N),tick:u64,user:rawptr)->bool {
   return recording_batch_valid(cast(^Model(S,C,A,E,N))user,input)
  },
  user=model,
 }
}

@(private)
recording_batch_valid :: proc(model:^Model($S,$C,$A,$E,$N),input:Batch(C,A,N))->bool {
	if !authority_observation_valid(model.authority,input.authority,N) {return false}
 mask:=(u64(1)<<uint(N))-1
 if (input.joins|input.leaves|input.fresh)&~mask!=0 {return false}
 if (input.prediction_group==0)!=(input.prediction_seat==0) || input.prediction_seat>u16(N) {return false}
 if input.prediction_group!=0 && input.prediction_group!=model.group.id {return false}
 for control,index in input.controls {
  if !model.control_valid(control) {return false}
  view:=input.views[index]
  if view.status>.Invalid {return false}
  if view.status==.Historical && view.from>view.to {return false}
  if view.status==.Live && (view.from!=view.to || view.fraction!=0) {return false}
  if !input.has_action[index] {continue}
  if input.sequences[index]==0 || input.sequences[index]>max(u64)>>8 || input.rejections[index]>.Disconnected {return false}
  // Invalid/stale/disconnected requests may retain invalid payloads. They must
  // stay rejected without invoking game predicates or today's admission policy.
  if input.rejections[index]==.None && (model.action==nil || model.action_valid==nil || !model.action_valid(input.actions[index])) {return false}
 }
 return true
}
