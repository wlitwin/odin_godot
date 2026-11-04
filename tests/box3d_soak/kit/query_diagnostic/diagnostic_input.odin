package kit_box3d

// COPY-ONLY observational helper. No state/input/wire/clock mutation API.
import "core:fmt"
import k "godot:kit/sim"
import p "godot:kit/physics"
import bm "godot:box3d/godot/meter"
import bg "godot:box3d/godot"
import common "godot:examples/box3d_common"

INPUT_DIAG_TICK :: u64(160)
Input_Diag_Row :: struct {status:k.World_Error,available:bool,kind:u8,origin:k.World_Input_Origin,sequence:u64}
Input_Diag_Point :: struct {
 observed,ready,resync,window_scanned:bool,
 epoch,head,confirmed,window_first,window_last,scan_first,scan_last:u64,
 window_rows:int,
 world_status,net_status:k.World_Error,
 accumulator:f64,
 row:Input_Diag_Row,
}
Input_Diagnostic :: struct {
 epoch,calls,clips:u64,
 caller_records,clip_records,target_records,summaries:int,
 clip_sum:f64,
 last_target_head,last_target_sequence:u64,
 last_target_available,last_target_valid:bool,
 before_ingest,after_ingest,before_normal:Input_Diag_Point,
 raw_delta,after_catchup,after_target,passed_dt:f64,
 input_done,input_emitted:bool,
 input_error:k.World_Error,
 runtime_bytes,base_runtime_bytes,pod_bytes,allocation_requested,allocation_live:u64,
 allocation_observed:bool,
}
input_diagnostic_allocation :: proc(rt:^Runtime,before:bm.Stats,before_status:bg.Status) {
 after,status:=bm.stats(rt.sdk.memory)
 d:=&rt.input_diagnostic
 d.runtime_bytes=u64(size_of(Runtime));d.base_runtime_bytes=u64(offset_of(Runtime,input_diagnostic));d.pod_bytes=u64(size_of(Input_Diagnostic))
 if before_status==bg.OK && status==bg.OK && after.requested_bytes>=before.requested_bytes && after.live_bytes>=before.live_bytes {
  d.allocation_observed=true;d.allocation_requested=after.requested_bytes-before.requested_bytes;d.allocation_live=after.live_bytes-before.live_bytes
 }
}
input_diagnostic_row :: proc(rt:^Runtime)->Input_Diag_Row {
 value,origin,sequence,status:=k.lane_world_accepted_input(&rt.lane,INPUT_DIAG_TICK,rt.players[1],1)
 result:=Input_Diag_Row{status=status}
 if status!=.Ok {return result}
 if len(value)!=size_of(common.Action) {result.status=.Incompatible;return result}
 action:common.Action;copy((cast([^]u8)&action)[:size_of(action)],value)
 result.available=true;result.kind=u8(action.kind);result.origin=origin;result.sequence=sequence
 return result
}
input_diagnostic_point :: proc(rt:^Runtime)->Input_Diag_Point {
 if !rt.model_ready || rt.lane.world==nil {return {}}
 status:=k.lane_world_network_status(&rt.lane)
 result:=Input_Diag_Point{observed=true,ready=status.ready,resync=status.needs_resync,epoch=status.epoch,head=status.head,confirmed=status.confirmed,world_status=k.lane_world_status(&rt.lane),net_status=status.error,accumulator=rt.lane.ticker.acc,row=input_diagnostic_row(rt)}
 if status.head>=152 && status.head<=168 {
  result.window_scanned=true;first:=status.head>135?status.head-135:0;last:=status.head>max(u64)-8?max(u64):status.head+8
  result.scan_first=first;result.scan_last=last
  result.window_first=max(u64)
  for tick:=first;tick<=last;tick+=1 {
   _,_,_,error:=k.lane_world_accepted_input(&rt.lane,tick,rt.players[1],1)
   if error==.Ok {result.window_rows+=1;result.window_first=min(result.window_first,tick);result.window_last=max(result.window_last,tick)}
   if tick==last {break}
  }
  if result.window_rows==0 {result.window_first=0}
 }
 return result
}
input_diagnostic_point_json :: proc(point:Input_Diag_Point)->string {
 if !point.observed {return fmt.aprintf("{{\"observed\":false}}")}
 row:string
 if point.row.available {row=fmt.aprintf("{{\"available\":true,\"status\":%d,\"kind\":%d,\"origin\":%d,\"sequence\":%d}}",point.row.status,point.row.kind,point.row.origin,point.row.sequence)}else{row=fmt.aprintf("{{\"available\":false,\"status\":%d}}",point.row.status)}
 defer delete(row)
 return fmt.aprintf("{{\"observed\":true,\"epoch\":%d,\"head\":%d,\"confirmed\":%d,\"ready\":%v,\"resync\":%v,\"world_status\":%d,\"net_status\":%d,\"accumulator_s\":%.17g,\"accumulator_bits\":\"%016x\",\"accepted\":%s,\"window_scanned\":%v,\"scan_first\":%d,\"scan_last\":%d,\"window_rows\":%d,\"window_first\":%d,\"window_last\":%d}}",point.epoch,point.head,point.confirmed,point.ready,point.resync,point.world_status,point.net_status,point.accumulator,transmute(u64)point.accumulator,row,point.window_scanned,point.scan_first,point.scan_last,point.window_rows,point.window_first,point.window_last)
}
input_diagnostic_before_ingest :: proc(rt:^Runtime,delta:f64) {
 if !rt.started {return}
 rt.input_diagnostic.before_ingest=input_diagnostic_point(rt)
}
input_diagnostic_after_ingest :: proc(rt:^Runtime,delta:f64,steps:int) {
 if !rt.started {return}
 rt.input_diagnostic.after_ingest=input_diagnostic_point(rt)
}
input_diagnostic_before_normal :: proc(rt:^Runtime,delta,after_catchup,after_target,passed:f64) {
 d:=&rt.input_diagnostic
 d.calls+=1;d.before_normal=input_diagnostic_point(rt)
 if d.epoch==0 {d.epoch=d.before_normal.epoch}
 d.raw_delta=delta;d.after_catchup=after_catchup;d.after_target=after_target;d.passed_dt=passed
 if after_target>passed {d.clips+=1;d.clip_sum+=after_target-passed}
}
input_diagnostic_confirmed :: proc(rt:^Runtime) {
 d:=&rt.input_diagnostic
 if d.input_done || k.lane_world_confirmed(&rt.lane)<INPUT_DIAG_TICK {return}
 d.input_done=true
 if k.lane_world_epoch(&rt.lane)!=d.epoch {d.input_error=.Incompatible;return}
 row:=input_diagnostic_row(rt);d.input_error=row.status
 if !row.available {return}
 cp,error:=k.lane_world_checkpoint(&rt.lane,INPUT_DIAG_TICK);d.input_error=error
 if error!=.Ok {return};defer k.world_checkpoint_destroy(&cp)
 side,side_error:=p.checkpoint_side(&cp,Side);d.input_error=side_error
 if side_error!=.Ok {return}
 receipt:=side.receipts[1]
 if receipt.tick!=INPUT_DIAG_TICK || u8(receipt.kind)!=row.kind {d.input_error=.Conflict;return}
 // Match the canonical APPLIED body exactly; class/player/phase are context.
 runtime_log(rt,"{\"event\":\"INPUT\",\"framework\":\"kit\",\"epoch\":%d,\"tick\":160,\"seat\":2,\"kind\":%d,\"applied\":%v,\"origin\":%d,\"sequence\":%d,\"accepted\":true,\"query_total\":%d,\"context\":%s}\n",d.epoch,row.kind,receipt.applied,row.origin,row.sequence,side.game.queries,"{\"diagnostic_only\":true,\"logical_class\":1,\"source\":\"public_accepted_row_and_confirmed_checkpoint\"}")
 d.input_emitted=true
}
input_diagnostic_summary :: proc(rt:^Runtime,phase:string) {
 d:=&rt.input_diagnostic
 if d.summaries>=2 {return};d.summaries+=1
 runtime_log(rt,"{\"event\":\"STATUS\",\"framework\":\"kit\",\"role\":\"%s\",\"topic\":\"kit_input_admission_v1\",\"phase\":\"%s\",\"target_tick\":160,\"target_seat\":2,\"target_player\":%d,\"logical_class\":1,\"calls\":%d,\"caller_records\":%d,\"clip_records\":%d,\"target_records\":%d,\"positive_clip_count\":%d,\"clip_sum_s\":%.17g,\"clip_sum_bits\":\"%016x\",\"input_emitted\":%v,\"input_status\":%d,\"runtime_bytes\":%d,\"base_runtime_bytes\":%d,\"pod_bytes\":%d,\"actual_allocation_requested\":%d,\"actual_allocation_live\":%d,\"allocation_observed\":%v}\n",role_name(rt.role),phase,rt.players[1],d.calls,d.caller_records,d.clip_records,d.target_records,d.clips,d.clip_sum,transmute(u64)d.clip_sum,d.input_emitted,d.input_error,d.runtime_bytes,d.base_runtime_bytes,d.pod_bytes,d.allocation_requested,d.allocation_live,d.allocation_observed)
}
input_diagnostic_after_normal :: proc(rt:^Runtime,steps:int) {
 d:=&rt.input_diagnostic;post:=input_diagnostic_point(rt)
 target:=d.before_normal.head>=158 && d.before_normal.head<=162
 changed:=!d.last_target_valid || d.last_target_head!=d.before_normal.head || d.last_target_available!=d.before_normal.row.available || d.last_target_sequence!=d.before_normal.row.sequence
 clipped:=d.after_target>d.passed_dt
 selected_target:=target && changed && d.target_records<8
 selected_clip:=clipped && d.clip_records<8
 if d.caller_records<16 && (selected_target || selected_clip) {
  if selected_target {d.target_records+=1;d.last_target_valid=true;d.last_target_head=d.before_normal.head;d.last_target_available=d.before_normal.row.available;d.last_target_sequence=d.before_normal.row.sequence}
  if selected_clip {d.clip_records+=1}
  d.caller_records+=1
  pre_ingest:=input_diagnostic_point_json(d.before_ingest);defer delete(pre_ingest)
  after_ingest:=input_diagnostic_point_json(d.after_ingest);defer delete(after_ingest)
  before:=input_diagnostic_point_json(d.before_normal);defer delete(before)
  after:=input_diagnostic_point_json(post);defer delete(after)
  value:=fmt.aprintf("{{\"schema\":1,\"caller_sequence\":%d,\"target_tick\":160,\"target_seat\":2,\"target_player\":%d,\"logical_class\":1,\"raw_delta_s\":%.17g,\"raw_delta_bits\":\"%016x\",\"after_catchup_cap_s\":%.17g,\"after_target_cap_s\":%.17g,\"passed_dt_s\":%.17g,\"passed_dt_bits\":\"%016x\",\"returned_normal_steps\":%d,\"prediction_clip_s\":%.17g,\"positive_clip_count\":%d,\"clip_sum_s\":%.17g,\"before_ingest\":%s,\"after_ingest\":%s,\"before_normal\":%s,\"after_normal\":%s}}",d.calls,rt.players[1],d.raw_delta,transmute(u64)d.raw_delta,d.after_catchup,d.after_target,d.passed_dt,transmute(u64)d.passed_dt,steps,d.after_target-d.passed_dt,d.clips,d.clip_sum,pre_ingest,after_ingest,before,after);defer delete(value)
  runtime_log(rt,"{\"event\":\"STATUS\",\"framework\":\"kit\",\"role\":\"%s\",\"topic\":\"kit_input_admission_v1\",\"phase\":\"caller\",\"observation\":%s}\n",role_name(rt.role),value)
 }
 input_diagnostic_confirmed(rt)
 if d.summaries==0 && post.head>168 {input_diagnostic_summary(rt,"window_complete")}
}
