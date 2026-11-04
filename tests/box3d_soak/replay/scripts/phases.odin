// Test-only observers for EXISTING public timing callbacks. No model/wire data.
package replay_gate_b_probe

import "core:fmt"
import gd "godot:godot"
import net "godot:replay/net"
import r "godot:replay"

PHASE_CAPACITY :: 64
Phase_Kind :: enum {Net, Link, Client, Journal}
Phase_Span :: struct {kind:Phase_Kind,metric:net.Profile_Metric,started,ended:u64}
Phase_Recorder :: struct {
 requested,active:bool,
 spans:[PHASE_CAPACITY]Phase_Span,count:int,
 read_count,clock_errors,overflow,callbacks,last_read,inner_started,inner_ended:u64,
 native:r.Timing,
}
phase_requested :: proc()->bool{return gd.env_string("GATE_B_PHASE_HOOKS","off")=="existing_callbacks"}
phase_now :: proc(p:^Phase_Recorder)->(u64,bool){
 if !p.active{return 0,false}
 value:=gd.time_get_ticks_usec(gd.singleton_time());p.read_count+=1
 if p.last_read!=0 && value<p.last_read{p.clock_errors+=1;return value,false}
 p.last_read=value;return value,true
}
phase_clock :: proc(user:rawptr)->(u64,bool){return phase_now(cast(^Phase_Recorder)user)}
phase_push :: proc(p:^Phase_Recorder,kind:Phase_Kind,metric:net.Profile_Metric,started,ended:u64){
 if !p.active{return}
 if ended<started{p.clock_errors+=1;return}
 if p.count==len(p.spans){p.overflow+=1;return} // caller FAILS; never truncated evidence
 p.spans[p.count]={kind,metric,started,ended};p.count+=1
}
phase_sample :: proc(user:rawptr,metric:net.Profile_Metric,elapsed:u64){
 p:=cast(^Phase_Recorder)user
 p.callbacks+=1
 // profile_finish invokes this immediately after the ending read, and passes
 // that exact ending-minus-start duration. No clock read/allocation here.
 if elapsed>p.last_read{p.clock_errors+=1;return}
 phase_push(p,.Net,metric,p.last_read-elapsed,p.last_read)
}
phase_begin :: proc(p:^Phase_Recorder){
 requested,active:=p.requested,p.active;p^={requested=requested,active=active}
 p.inner_started,_=phase_now(p)
}
phase_end :: proc(p:^Phase_Recorder){p.inner_ended,_=phase_now(p)}
phase_ok :: proc(p:^Phase_Recorder)->bool{return p.overflow==0 && p.clock_errors==0}
phase_controls :: proc()->bool{
 // Synthetic layout/overflow controls only; no real clock or SDK claim.
 p:=Phase_Recorder{active=true}
 for _ in 0..=PHASE_CAPACITY{phase_push(&p,.Net,.Pump,10,20)}
 if p.count!=PHASE_CAPACITY || p.overflow!=1 || phase_ok(&p){return false}
 p={active=true,last_read=40};phase_sample(&p,.Physics_Inspect,7)
 return phase_ok(&p) && p.callbacks==1 && p.count==1 && p.spans[0].started==33 && p.spans[0].ended==40
}
phase_name :: proc(s:Phase_Span)->string{
 switch s.kind{case .Link:return "public_link_ingress";case .Client:return "public_client_call";case .Journal:return "journal_drain";case .Net:}
 switch s.metric{
 case .Advance:return "Advance";case .Pump:return "Pump";case .Snapshot:return "Snapshot";case .Replay:return "Replay"
 case .Snapshot_Encode:return "Snapshot_Encode";case .Snapshot_Delta:return "Snapshot_Delta";case .Snapshot_Hash:return "Snapshot_Hash"
 case .Snapshot_Cache:return "Snapshot_Cache";case .Snapshot_Validate:return "Snapshot_Validate";case .Snapshot_Send:return "Snapshot_Send"
 case .Physics_Inspect:return "Physics_Inspect";case .Physics_Decode:return "Physics_Decode";case .Physics_Repair:return "Physics_Repair";case .Physics_Compare:return "Physics_Compare"
 }
 return "unknown_metric"
}
phase_relation :: proc(s:Phase_Span)->string{
 if s.kind==.Client{return "inside_whole"}
 if s.kind!=.Net{return "inside_probe_body"}
 return s.metric==.Pump?"nested_in_public_client_call":"nested_in_Pump"
}
phase_calls :: proc(p:^Phase_Recorder,metric:net.Profile_Metric)->u64{count:u64;for span in p.spans[:p.count]{if span.kind==.Net && span.metric==metric{count+=1}};return count}

// Diagnostic serialization AFTER the outer timer. Fixed caller stack buffer,
// no allocation in callbacks, no cross-clock origins or residual subtraction.
phases_write :: proc(p:^Phase_Recorder,outer_started,outer_ended:u64,out:[]u8)->(string,bool){
 if !p.active{return "[]",true}
 if !phase_ok(p) || p.inner_started<outer_started || p.inner_ended>outer_ended{return "[]",false}
 at:=0
 put:=proc(out:[]u8,at:^int,name:string,started,ended:u64,relation:string,comma:bool)->bool{
  if len(out)-at^<512{return false}
  written:=fmt.bprintf(out[at^:],"%s{{\"name\":\"%s\",\"duration_ns\":%d,\"clock_domain\":\"godot_ticks_usec\",\"start_us\":%d,\"end_us\":%d,\"relation\":\"%s\"}}",comma?",":"",name,(ended-started)*1000,started,ended,relation)
  at^+=len(written);return true
 }
 out[at]='[';at+=1
 for span,index in p.spans[:p.count]{if !put(out,&at,phase_name(span),span.started,span.ended,phase_relation(span),index!=0){return "[]",false}}
 if !put(out,&at,"outer_entry_to_probe",outer_started,p.inner_started,"inside_whole",p.count!=0){return "[]",false}
 if !put(out,&at,"probe_body",p.inner_started,p.inner_ended,"inside_whole",true){return "[]",false}
 if !put(out,&at,"probe_to_core_return",p.inner_ended,outer_ended,"inside_whole",true){return "[]",false}
 if len(out)-at<512{return "[]",false}
 written:=fmt.bprintf(out[at:],",{{\"name\":\"native_read_build_verify_reencode\",\"duration_ns\":%d,\"clock_domain\":\"godot_ticks_usec\",\"start_us\":null,\"end_us\":null,\"relation\":\"nested_in_Physics_Decode_duration_only\"}}",p.native.total_us*1000);at+=len(written)
 out[at]=']';at+=1;return string(out[:at]),true
}
