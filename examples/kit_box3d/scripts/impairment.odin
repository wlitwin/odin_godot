package kit_box3d

import "core:fmt"
import gd "godot:godot"
import bp "godot:box3d/presentation"
import p "godot:kit/physics"
import b "godot:box3d"
import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"

Scene_Impairment :: struct {
 requested:bp.Impairment,
 latency_ms,jitter_ms,loss_percent:int,
}
scene_decimal :: proc(name:cstring,limit:u32)->(u32,bool) {
 value:=gd.env_string(name,"0") // existing unset/empty convention, no retained string
 if len(value)==0 || len(value)>20 {return 0,false}
 number:=u32(0)
 for byte in value {
  if byte<'0' || byte>'9' {return 0,false}
  digit:=u32(byte-'0')
  if number>limit/10 || (number==limit/10 && digit>limit%10) {return 0,false}
  number=number*10+digit
 }
 return number,true
}
scene_impairment :: proc()->(Scene_Impairment,bp.Error,u8) {
 fields:=([5]cstring{"B3_LATENCY","B3_JITTER","B3_LOSS","B3_DUPLICATE","B3_REORDER"})
 limits:=([5]u32{10000,10000,100,100,1});values:[5]u32
 for field,i in fields {value,ok:=scene_decimal(field,limits[i]);if !ok {return {},.Invalid,u8(i+1)};values[i]=value}
 result:=Scene_Impairment{requested={latency_ms=values[0],jitter_ms=values[1],loss_permyriad=values[2]*100,duplicate_permyriad=values[3]*100,reorder=values[4]!=0}}
 latency,jitter,loss,error:=p.presentation_impairment(result.requested)
 result.latency_ms=latency;result.jitter_ms=jitter;result.loss_percent=loss
 return result,error,0
}
scene_impairment_json :: proc(value:Scene_Impairment,applied:=true)->string {
 r:=value.requested;active:=value.latency_ms>0 || value.jitter_ms>0 || value.loss_percent>0
 return fmt.tprintf("{{\"requested\":{{\"latency_ms\":%d,\"jitter_ms\":%d,\"loss_percent\":%d,\"duplicate_percent\":%d,\"reorder\":%v}},\"effective\":{{\"applied\":%v,\"latency_ms\":%d,\"jitter_ms\":%d,\"loss_permyriad\":%d,\"duplicate_permyriad\":0,\"delay_active\":%v,\"unreliable_may_reorder\":%v}},\"channel\":{{\"scope\":\"local_receive\",\"reliable\":\"ordered_loss_adds_delay\",\"unreliable\":\"modeled_stream_loss_jitter\",\"reorder_disable_supported\":false}}}}",r.latency_ms,r.jitter_ms,r.loss_permyriad/100,r.duplicate_permyriad/100,r.reorder,applied,value.latency_ms,value.jitter_ms,value.loss_percent*100,active,value.jitter_ms>0)
}
scene_impairment_text :: proc(value:Scene_Impairment)->cstring {
 r:=value.requested
 return fmt.ctprintf("Local receive request %d/%d ms loss %d%% dup %d%% reorder %v | effective %d/%d ms loss %d%%\nStream loss may drop; jitter may reorder. Reliable FIFO; loss adds retransmit delay. Above ENet.",r.latency_ms,r.jitter_ms,r.loss_permyriad/100,r.duplicate_permyriad/100,r.reorder,value.latency_ms,value.jitter_ms,value.loss_percent)
}
scene_impairment_reject :: proc(node:gd.Node,role:Role,generation:u32,value:Scene_Impairment,error:bp.Error,field:u8) {
 generation_log(generation,"{\"event\":\"ERROR\",\"framework\":\"kit\",\"where\":\"impairment_preflight\",\"status\":\"%v\",\"field_index\":%d,\"before_transport\":true,\"before_physics\":true,\"sdk_context_created\":false,\"impairment\":%s}\n",error,field,scene_impairment_json(value,false))
 ledger:b.Host_Ledger_Stats;stats_ok:=false;contract,cs:=b.domain_contract_get()
 if cs==.Ok {actual,ls:=b.host_ledger_get(contract.cookie);if ls==.Ok {ledger=actual;stats_ok=true}}
 meter,ms:=bm.category_stats(bg.CATEGORY_KIT_CORE)
 generation_log(generation,"{\"event\":\"RESULT\",\"framework\":\"kit\",\"role\":\"%s\",\"tick\":0,\"ok\":false,\"errors\":1,\"engine_live\":%d,\"wrapper_live\":%d,\"meter_live\":%d,\"cleanup_errors\":0,\"native_stats_ok\":%v,\"before_transport\":true,\"before_physics\":true}\n",role_name(role),ledger.engine_live_bytes,ledger.snapshot_live_bytes,meter.live_bytes,stats_ok&&ms==bg.OK)
 label:=cast(gd.Label)gd.get_node(node,"HUD/Status");gd.set_text(label,fmt.ctprintf("HOLD / impairment %v field %d / no transport or physics opened",error,field))
 if gd.env_string("B3_ROLE","")!="" {gd.scene_tree_quit(gd.get_tree(node),1)}
}
