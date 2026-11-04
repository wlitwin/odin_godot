package kit_authoring_demo

// Process-local bounded observations. Nothing here enters Side, an input,
// admission, caller time, a frame setter, or the protocol's recovery decision.
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import b "godot:box3d"
import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"
import bd "godot:box3d/diagnostics"
import k "godot:kit/sim"

Sample_Telemetry :: struct {
 frames,native_frame,meter_frame:u64,elapsed:f64,go_logged:bool,
 native_observed,meter_observed:bool,ledger:b.Host_Ledger_Stats,meter_live:u64,
 scope_observed:bool,scope_epoch,scope_serial,scope_baseline,recoveries:u64,
}

// Called ONLY by the existing successful new-bootstrap/signature Match branch.
// The baseline does not follow ordinary signatures or a head/confirmed jump.
telemetry_validated_scope :: proc(rt:^Demo,signature:bd.Signature){
 t:=&rt.telemetry
 if t.scope_observed&&(t.scope_epoch!=signature.epoch||t.scope_serial!=rt.scope||t.scope_baseline!=signature.tick){t.recoveries+=1}
 t.scope_observed=true;t.scope_epoch=signature.epoch;t.scope_serial=rt.scope;t.scope_baseline=signature.tick
}

telemetry_final_ack :: proc(rt:^Demo,signature:bd.Signature,player,peer:u64){
 if !rt.scripted{return}
 row:=struct{version:u32,framework,role,scope:string,epoch,tick,player,peer:u64,matched:bool}{1,"kit",role(rt),"verified_terminal_signature_ack",signature.epoch,signature.tick,player,peer,true}
 bytes,error:=json.marshal(row)
 if error!=nil{fmt.eprintf("SAMPLE_ACK encoding_error=%v\n",error);return}
 defer delete(bytes);fmt.printf("SAMPLE_ACK %s\n",string(bytes))
}

status_uint :: proc(builder:^strings.Builder,name:string,value:u64,available:bool){
 fmt.sbprintf(builder,",\"%s\":",name)
 if available{fmt.sbprintf(builder,"%d",value)}else{strings.write_string(builder,"null")}
}

// ONE schema/implementation for the UI method and SAMPLE_STATUS. Frontiers
// are LIVE per call. Resource fields are explicitly historical <=1Hz samples.
// JSON scalar marshal + literal null tokens avoids unsupported pointer/any JSON.
sample_status_json :: proc(rt:^Demo,closed_role:string="",closed_error:string="")->[]u8{
 phase,error,selected_role:="Closed",closed_error,closed_role
 go,frontiers,reset_supported,native_observed,meter_observed,recovery_available:=false,false,false,false,false,false
 head,confirmed,epoch,frames:u64;t:Sample_Telemetry
 if rt!=nil{
  selected_role=role(rt);error="";go=rt.started;frames=rt.telemetry.frames;t=rt.telemetry
  phase=rt.started?"Running":"Waiting";if rt.closing{phase="Closing"}else if rt.failed{phase="Failed"}
  if rt.error_count>0{error=rt.errors[0].site}
  frontiers=rt.model_ready&&rt.lane.world!=nil
  if frontiers{
   head=rt.lane.ticker.tick;confirmed=k.lane_world_confirmed(&rt.lane);epoch=k.lane_world_epoch(&rt.lane)
   if !rt.failed&&!rt.closing&&k.lane_world_needs_resync(&rt.lane){phase="Hold"}
   reset_supported=!rt.host&&!rt.failed&&!rt.closing
   protocol:=k.lane_world_protocol_status(&rt.lane)
   recovery_available=!rt.host&&t.scope_observed&&t.scope_serial!=0&&epoch==t.scope_epoch&&rt.scope==t.scope_serial&&protocol.bootstrap_sequence==t.scope_serial
  }
  native_observed=t.native_observed;meter_observed=t.meter_observed
 }
 base:=struct{version:u32,framework,role,phase,error:string,go,reset_supported,native_observed,meter_observed,recovery_available:bool}{1,"kit",selected_role,phase,error,go,reset_supported,native_observed,meter_observed,recovery_available}
 encoded,encoding_error:=json.marshal(base);if encoding_error!=nil{return nil};defer delete(encoded)
 builder:=strings.builder_make(context.allocator);defer strings.builder_destroy(&builder)
 strings.write_string(&builder,string(encoded[:len(encoded)-1]))
 status_uint(&builder,"head",head,frontiers);status_uint(&builder,"confirmed",confirmed,frontiers);status_uint(&builder,"epoch",epoch,frontiers)
 status_uint(&builder,"frames",frames,rt!=nil)
 status_uint(&builder,"native_sampled_frame",t.native_frame,native_observed);status_uint(&builder,"meter_sampled_frame",t.meter_frame,meter_observed)
 status_uint(&builder,"native_live_bytes",t.ledger.engine_live_bytes,native_observed)
 status_uint(&builder,"wrapper_live_bytes",t.ledger.snapshot_live_bytes,native_observed)
 status_uint(&builder,"host_live_bytes",t.ledger.host_live_bytes,native_observed)
 status_uint(&builder,"reserved_bytes",t.ledger.host_reserved_bytes,native_observed)
 status_uint(&builder,"admitted_bytes",t.ledger.admitted_bytes,native_observed)
 status_uint(&builder,"limit_bytes",t.ledger.limit_bytes,native_observed)
 status_uint(&builder,"owner_count",u64(t.ledger.owner_count),native_observed)
 status_uint(&builder,"meter_live_bytes",t.meter_live,meter_observed)
 status_uint(&builder,"recoveries",t.recoveries,recovery_available)
 status_uint(&builder,"recovery_serial",t.scope_serial,recovery_available)
 status_uint(&builder,"baseline",t.scope_baseline,recovery_available)
 strings.write_byte(&builder,'}')
 text:=strings.to_string(builder);if len(text)>8192{return nil}
 bytes,allocation_error:=mem.alloc_bytes(len(text));if allocation_error!=.None{return nil};copy(bytes,transmute([]u8)text);return bytes
}

telemetry_frame_end :: proc(rt:^Demo,delta:f64){
 if !rt.scripted||rt.closing||math.is_nan(delta)||math.is_inf(delta)||delta<0{return}
 context.allocator=rt.allocator
 t:=&rt.telemetry;t.elapsed+=delta
 due:=t.elapsed>=1;first_go:=rt.started&&!t.go_logged
 if !due&&!first_go{return}
 if first_go{t.go_logged=true} // prompt real GO row; cached memory may be null
 if due{
  t.elapsed=0 // one observation, no catch-up output loop
  contract,cs:=b.domain_contract_get()
  t.native_observed=false
  if cs==.Ok{ledger,status:=b.host_ledger_get(contract.cookie);if status==.Ok{t.ledger=ledger;t.native_frame=t.frames;t.native_observed=true}}
  meter,ms:=bm.category_stats(bg.CATEGORY_KIT_CORE)
  t.meter_observed=ms==bg.OK
  if t.meter_observed{t.meter_live=meter.live_bytes;t.meter_frame=t.frames}
 }
 bytes:=sample_status_json(rt);if len(bytes)==0{fmt.println("SAMPLE_STATUS {\"version\":1,\"framework\":\"kit\",\"error\":\"status.json\"}");return}
 defer delete(bytes,rt.allocator);fmt.printf("SAMPLE_STATUS %s\n",string(bytes))
}
