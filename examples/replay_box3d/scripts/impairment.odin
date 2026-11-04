// Startup-only consumption of the existing local receive decorator.
package replay_box3d

import "core:fmt"
import gd "godot:godot"
import bp "godot:box3d/presentation"

Scene_Impairment :: struct {request,effective:bp.Impairment,delay_active:bool}

slice_impairment_decimal_value :: proc(text:string,maximum:u64)->(u32,bool){
 if len(text)==0 || len(text)>20{return 0,false}
 value:=u64(0)
 for byte in transmute([]u8)text{
  if byte<'0' || byte>'9'{return 0,false}
  digit:=u64(byte-'0')
  if value>maximum/10 || (value==maximum/10 && digit>maximum%10){return 0,false}
  value=value*10+digit
 }
 return u32(value),true
}
slice_impairment_decimal :: proc(name:cstring,maximum:u64)->(u32,bool){
 return slice_impairment_decimal_value(gd.env_string(name,"0"),maximum)
}

slice_impairment_parse :: proc(self:^ReplayBox3d)->bool{
 fields:=[?]struct{name:cstring,maximum:u64}{{"B3_LATENCY",10000},{"B3_JITTER",10000},{"B3_LOSS",100},{"B3_DUPLICATE",100},{"B3_REORDER",1}}
 values:[5]u32
 for field,index in fields{
  value,ok:=slice_impairment_decimal(field.name,field.maximum);if !ok{return false};values[index]=value
 }
 self.impairment.request={latency_ms=values[0],jitter_ms=values[1],loss_permyriad=values[2]*100,duplicate_permyriad=values[3]*100,reorder=values[4]==1}
 return true
}
slice_impairment_reject :: proc(self:^ReplayBox3d,error:bp.Error){
 self.failed=true
 gd.print_str(fmt.tprintf("BOX3D_SLICE_ERROR {{\"where\":\"impairment_preflight\",\"status\":\"%v\",\"before_transport\":true,\"before_physics\":true}}",error))
 text:=gd.new_string(fmt.tprintf("Impairment startup rejected: %v",error));gd.label_set_text(self.status,text);gd.free_string(text)
 slice_finish(self)
}
// This reads actual installed metadata after ordinary Session open; it neither
// constructs a decorator nor changes its queues, RNG, ownership or fault policy.
slice_impairment_applied :: proc(self:^ReplayBox3d){
 s:=&self.state.session
 if s.connection==nil{return}
 delay:=&s.connection.delay
 self.impairment.delay_active=delay.packets!=nil
 self.impairment.effective={latency_ms=delay.latency_ms,jitter_ms=delay.jitter_ms,loss_permyriad=delay.loss_permyriad,duplicate_permyriad=delay.duplicate_permyriad}
}
slice_impairment_json :: proc(self:^ReplayBox3d)->string{
 request,effective:=self.impairment.request,self.impairment.effective
 return fmt.tprintf("{{\"request\":{{\"latency_ms\":%d,\"jitter_ms\":%d,\"loss_percent\":%d,\"duplicate_percent\":%d,\"reorder\":%v}},\"effective\":{{\"latency_ms\":%d,\"jitter_ms\":%d,\"loss_permyriad\":%d,\"duplicate_permyriad\":%d,\"delay_active\":%v,\"unreliable_may_reorder\":%v}},\"channel\":{{\"scope\":\"local_receive\",\"reliable\":\"ordered_no_modeled_loss_or_dup\",\"unreliable\":\"modeled_loss_dup_jitter\",\"reorder_disable_supported\":false}}}}",request.latency_ms,request.jitter_ms,request.loss_permyriad/100,request.duplicate_permyriad/100,request.reorder,effective.latency_ms,effective.jitter_ms,effective.loss_permyriad,effective.duplicate_permyriad,self.impairment.delay_active,effective.jitter_ms>0)
}
slice_impairment_text :: proc(self:^ReplayBox3d)->string{
 request,effective:=self.impairment.request,self.impairment.effective
 return fmt.tprintf("Local receive above ENet requested latency/jitter %d/%d ms loss/dup %d/%d%% reorder=%v\nEffective latency/jitter %d/%d ms loss/dup %d/%d permyriad active=%v\nReliable ordered/no modeled loss or dup; Unreliable faults/jitter may-reorder=%v (no independent reorder-disable)",request.latency_ms,request.jitter_ms,request.loss_permyriad/100,request.duplicate_permyriad/100,request.reorder,effective.latency_ms,effective.jitter_ms,effective.loss_permyriad,effective.duplicate_permyriad,self.impairment.delay_active,effective.jitter_ms>0)
}
