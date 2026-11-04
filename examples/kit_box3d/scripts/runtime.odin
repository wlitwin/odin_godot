package kit_box3d

import "core:fmt"
import "core:mem"
import "core:os"
import "core:math"
import gd "godot:godot"
import b "godot:box3d"
import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"
import bd "godot:box3d/diagnostics"
import common "godot:examples/box3d_common"
import p "godot:kit/physics"
import k "godot:kit/sim"
import n "godot:kit/net"
import s "godot:kit/session"
import ng "godot:kit/netgd"
import bp "godot:box3d/presentation"

Role :: enum {Host,Client,Observer,Dedicated}
Caller_Delta_Disposition :: enum {Forwarded,Unaccounted}
Caller_Delta_Plan :: struct {
 eligible_delta,offered_delta,unforwarded_delta:f64,
 disposition:Caller_Delta_Disposition,
}
// Pure old eligibility/clamp calculator; caller credit accounting is separate.
caller_delta_plan :: proc(delta:f64,target,head,confirmed:u64,client:bool)->Caller_Delta_Plan {
 eligible:=min(delta,2.0/60)
 if target>0 {eligible=min(eligible,f64(target-min(target,head))/60)}
 offered:=eligible
 if client {available:=u64(8)-min(u64(8),head-confirmed);offered=min(offered,f64(available)/60)}
 plan:=Caller_Delta_Plan{eligible,offered,eligible-offered,.Forwarded}
 if offered<eligible {plan.disposition=.Unaccounted}
 return plan
}
CALLER_RECEIPT_EPS :: f64(0.000000000001)
Caller_Credit :: struct {pending_seconds,unresolved_offer_seconds:f64}
Caller_Receipt :: enum {No_Offer,NotOwned,OwnedAll,Unresolved}
Caller_Disposition :: enum {Offering,Retained,Deferred,Capacity,Start,Hold,Reset,End,Failure,Invalid,Unresolved}
Caller_Account :: struct {
 before,before_pending,before_unresolved,eligible,raw_excess,offered,lane_owned,pending,unresolved,excluded,capacity_excluded,end_excluded,scaled_receipt:f64,
 disposition:Caller_Disposition,receipt:Caller_Receipt,valid:bool,
 reset_baseline,reset_watermark:u64,
}
Caller_Boundary :: struct {
 available,ready,resync,busy,presenting,publishing,applying:bool,
 head,confirmed,epoch,received_sequence:u64,
 acc,dt,scale:f64,status:k.World_Error,
 queue_count,queue_bytes,completed_count,applying_bytes,commands:int,
 transfer_sequence,transfer_epoch,transfer_tick:u64,
 transfer_mode:k.World_Transfer_Mode,
 transfer_chunks,transfer_received,transfer_bytes:int,
 transfer_seen:[32]bool,
}
caller_finite :: proc(x:f64)->bool{return !math.is_nan(x)&&!math.is_inf(x)}
// World v2 ordinary caller: pure scale-aware math, no legacy Fine machinery.
caller_domain :: proc(dt,scale:f64)->bool{return dt==1.0/60&&caller_finite(scale)&&scale>=0.98&&scale<=1.02}
caller_eligible_delta :: proc(delta:f64,target,head:u64,dt,scale,acc:f64)->f64 {
 if !caller_finite(delta)||delta<0||!caller_domain(dt,scale)||!caller_finite(acc)||acc<0{return -1}
 eligible:=min(delta,2*dt)
 if target>0 {remaining:=target-min(target,head);eligible=min(eligible,max(f64(0),f64(remaining)*dt-acc)/scale)}
 return eligible
}
caller_credit_valid :: proc(c:Caller_Credit,dt:f64)->bool {
 return caller_finite(dt)&&dt>0&&caller_finite(c.pending_seconds)&&caller_finite(c.unresolved_offer_seconds)&&c.pending_seconds>=0&&c.unresolved_offer_seconds>=0&&c.pending_seconds+c.unresolved_offer_seconds<=8*dt
}
caller_account_valid :: proc(a:Caller_Account,dt,scale:f64)->bool {
 return caller_domain(dt,scale)&&caller_credit_valid({a.pending,a.unresolved},dt)&&caller_finite(a.before+a.eligible)&&caller_finite(a.lane_owned+a.pending+a.unresolved+a.excluded)&&a.eligible>=0&&a.offered>=0&&a.lane_owned>=0&&a.excluded>=0&&abs(((a.before+a.eligible)-(a.lane_owned+a.pending+a.unresolved+a.excluded))*scale)<=CALLER_RECEIPT_EPS
}
caller_credit_lifecycle :: proc(c:Caller_Credit,eligible,dt,scale:f64,why:Caller_Disposition)->Caller_Account {
 a:=Caller_Account{before=c.pending_seconds+c.unresolved_offer_seconds,before_pending=c.pending_seconds,before_unresolved=c.unresolved_offer_seconds,eligible=eligible,disposition=why}
 if !caller_domain(dt,scale)||!caller_credit_valid(c,dt)||!caller_finite(eligible)||eligible<0 {a.disposition=.Invalid;return a}
 if why==.Hold {a.pending=c.pending_seconds;a.unresolved=c.unresolved_offer_seconds;a.excluded=eligible}
 else {a.excluded=a.before+eligible}
 a.valid=caller_account_valid(a,dt,scale);return a
}
caller_credit_offer :: proc(c:Caller_Credit,eligible,dt,scale:f64,room,end_ticks:u64,end_limited,defer_ingress:bool,acc:f64=0)->Caller_Account {
 if c.unresolved_offer_seconds>0{return caller_credit_lifecycle(c,eligible,dt,scale,.Hold)}
 a:=Caller_Account{before=c.pending_seconds,before_pending=c.pending_seconds,eligible=eligible,disposition=.Offering}
 if !caller_domain(dt,scale)||!caller_credit_valid(c,dt)||!caller_finite(eligible)||eligible<0||!caller_finite(acc)||acc<0{a.disposition=.Invalid;return a}
 total:=a.before+eligible;capped:=min(total,8*dt);a.capacity_excluded=total-capped;a.excluded=a.capacity_excluded
 if end_limited{limit:=max(f64(0),f64(end_ticks)*dt-acc)/scale;if capped>limit{a.end_excluded=capped-limit;a.excluded+=a.end_excluded;capped=limit}}
 if defer_ingress{a.disposition=.Deferred;a.pending=capped}
 else{
  ticks:=min(u64(2),room);if end_limited{ticks=min(ticks,end_ticks)}
  // acc is already Lane-owned scaled seconds, never caller credit.
  budget:=max(f64(0),f64(ticks)*dt-acc)/scale
  a.offered=min(capped,min(2*dt,budget));a.pending=capped-a.offered;if a.offered==0{a.disposition=.Retained}
 }
 a.valid=caller_account_valid(Caller_Account{before=a.before,eligible=a.eligible,lane_owned=a.offered,pending=a.pending,excluded=a.excluded},dt,scale);return a
}
caller_ingress_pending :: proc(b:Caller_Boundary)->bool{return b.queue_count!=0||b.queue_bytes!=0||b.completed_count!=0||b.applying||b.applying_bytes!=0}
caller_boundary :: proc(rt:^Runtime)->Caller_Boundary {
 l:=&rt.lane;if l.world==nil||l.world.network==nil{return {}}
 w:=l.world;n:=w.network;status:=k.lane_world_network_status(l)
 return {available=true,ready=status.ready,resync=status.needs_resync,busy=w.busy,presenting=w.presenting,publishing=w.publishing,applying=n.applying,
 head=l.ticker.tick,confirmed=k.lane_world_confirmed(l),epoch=k.lane_world_epoch(l),received_sequence=n.received_sequence,acc=l.ticker.acc,dt=l.ticker.dt,scale=l.ticker.scale,status=k.lane_world_status(l),
 queue_count=n.queue_count,queue_bytes=n.queue_bytes,completed_count=n.completed_count,applying_bytes=len(n.applying_transfer.bytes),commands=len(l.pending)+len(l.cmd_in)+len(l.cmd_out),
 transfer_sequence=n.transfer_sequence,transfer_epoch=n.transfer_epoch,transfer_tick=n.transfer_tick,transfer_mode=n.transfer_mode,transfer_chunks=n.transfer_chunks,transfer_received=n.transfer_received,transfer_bytes=len(n.transfer),transfer_seen=n.transfer_seen}
}
caller_credit_receipt :: proc(before,after:Caller_Boundary,returned:int,offered:f64)->(Caller_Receipt,f64) {
 if offered==0{return .No_Offer,0}
 q:=(after.acc-before.acc)+f64(returned)*before.dt
 stable:=before.available&&after.available&&returned>=0&&caller_domain(before.dt,before.scale)&&before.dt==after.dt&&before.scale==after.scale&&caller_finite(before.acc)&&caller_finite(after.acc)&&before.acc>=0&&after.acc>=0&&before.epoch==after.epoch&&before.received_sequence==after.received_sequence&&before.confirmed==after.confirmed&&after.head>=before.head&&after.head-before.head==u64(returned)&&!caller_ingress_pending(before)&&!caller_ingress_pending(after)&&!after.busy&&!after.presenting&&!after.publishing&&after.commands==0
 partial_same:=before.transfer_sequence==after.transfer_sequence&&before.transfer_epoch==after.transfer_epoch&&before.transfer_tick==after.transfer_tick&&before.transfer_mode==after.transfer_mode&&before.transfer_chunks==after.transfer_chunks&&before.transfer_received==after.transfer_received&&before.transfer_bytes==after.transfer_bytes&&before.transfer_seen==after.transfer_seen
 if !stable||!partial_same||!caller_finite(q){return .Unresolved,q}
 guard:=before.busy||before.presenting||!before.ready||before.resync||before.commands!=0
 unchanged_acc:=transmute(u64)before.acc==transmute(u64)after.acc
 total:=before.acc+offered*before.scale
 if returned==0&&unchanged_acc&&(guard||(total>=before.dt&&after.status!=.Ok)){return .NotOwned,q}
 ordinary:=before.ready&&!before.resync&&!before.busy&&!before.presenting&&!before.publishing&&before.commands==0
 acquired:=returned>0||(returned==0&&total<before.dt&&before.status==.Ok&&after.status==.Ok)
 if ordinary&&acquired&&abs(q-offered*before.scale)<=CALLER_RECEIPT_EPS{return .OwnedAll,q}
 return .Unresolved,q
}
caller_credit_settle :: proc(a:Caller_Account,receipt:Caller_Receipt,q,dt,scale:f64,end_ticks:u64=0,end_limited:bool=false,acc:f64=0)->Caller_Account {
 result:=a;result.receipt=receipt;result.scaled_receipt=q
 switch receipt {
 case .OwnedAll:
  result.lane_owned=a.offered
  if a.valid&&a.lane_owned==0&&a.offered>0&&caller_domain(dt,scale)&&caller_finite(acc)&&acc>=0&&caller_account_valid(result,dt,scale)&&a.before_unresolved==0&&a.unresolved==0&&result.unresolved==0 {
   pending_limit:=8*dt
   if end_limited {end_budget:=max(f64(0),f64(end_ticks)*dt-acc)/scale;pending_limit=min(pending_limit,max(f64(0),end_budget-result.lane_owned))}
   if pending_limit>=result.pending {
    r:=min(max(f64(0),result.capacity_excluded),min(max(f64(0),result.eligible),min(max(f64(0),result.excluded-result.end_excluded),max(f64(0),pending_limit-result.pending))))
    result.pending=min(pending_limit,result.pending+r)
    // Offer-time capacity/end audit fields stay unchanged; excluded is NET.
    // Positive offer-event counters therefore do not measure net loss.
    result.excluded=max(result.end_excluded,result.excluded-r)
   }
  }
 case .NotOwned:result.pending+=a.offered;result.disposition=.Retained
 case .Unresolved:result.unresolved+=a.offered;result.disposition=.Unresolved
 case .No_Offer:
 }
 result.valid=a.valid&&caller_account_valid(result,dt,scale);return result
}
caller_client :: proc(rt:^Runtime)->bool{return rt.role==.Client&&!rt.ses.is_host}
caller_store :: proc(rt:^Runtime,a:Caller_Account){
 record:=a
 if a.valid {rt.caller_credit={a.pending,a.unresolved}}
 else {record.pending=rt.caller_credit.pending_seconds;record.unresolved=rt.caller_credit.unresolved_offer_seconds;record.disposition=.Invalid}
 rt.caller_account=record
}
caller_error :: proc(rt:^Runtime,reason:string){
 rt.error=.Unsupported;rt.failed=true
 runtime_log(rt,"{\"event\":\"ERROR\",\"framework\":\"kit\",\"where\":\"caller_receipt\",\"reason\":\"%s\",\"offered_bits\":\"%x\",\"receipt_bits\":\"%x\"}\n",reason,transmute(u64)rt.caller_account.offered,transmute(u64)rt.caller_account.scaled_receipt)
}
caller_lifecycle :: proc(rt:^Runtime,delta:f64,why:Caller_Disposition){
 if !caller_client(rt){return}
 dt,scale:=rt.lane.ticker.dt,rt.lane.ticker.scale
 if !rt.model_ready {dt=1.0/60;scale=1}
 if !caller_finite(delta)||delta<0 {caller_error(rt,"invalid_delta");return}
 acc:=rt.model_ready?rt.lane.ticker.acc:f64(0)
 eligible:=caller_eligible_delta(delta,rt.target,rt.lane.ticker.tick,dt,scale,acc)
 a:=caller_credit_lifecycle(rt.caller_credit,eligible,dt,scale,why);a.raw_excess=delta-eligible
 if why==.Reset&&rt.lane.world!=nil {a.reset_baseline=rt.lane.world.network.last_signature.tick;a.reset_watermark=rt.lane.world.network.received_sequence}
 caller_store(rt,a);if !a.valid{caller_error(rt,"lifecycle_invariant")}
}
Ingress :: struct {head,confirmed,checkpoint_tick,checkpoint_sequence,accepted_first,accepted_head:u64,checkpoint_mode:u8,pending:bool}
Final_Receipt :: struct {player:n.Player_Id,peer,pending_peer:s.Peer_Id,token_hash,epoch,target:u64,incarnation:u32,spectator,received,pending_rejoin:bool,signature:bd.Signature}
Rejoin_Guard :: struct {player:n.Player_Id,players:[2]n.Player_Id,seat:u16,epoch,token:u64,source_generation:u32}
// CONTROL_EVIDENCE61_BEGIN: public confirmed class0 evidence only.
CONTROL_EVIDENCE_MAX_TARGET :: u64(65535)
CONTROL_EVIDENCE_MAX_ROWS :: u64(131070)
CONTROL_EVIDENCE_MAX_UNAVAILABLE_STATUS :: u32(8)
Confirmed_Control_Evidence :: struct {
 declared,summary_emitted,domain_invalid:bool,
 epoch,baseline,target,through,emitted,unavailable,capped,duplicates_suppressed:u64,
 unavailable_statuses:u32,
}
confirmed_control_unavailable :: proc(rt:^Runtime,tick:u64,seat:int,reason:string,status:k.World_Error){
 e:=&rt.control_evidence
 if e.unavailable_statuses>=CONTROL_EVIDENCE_MAX_UNAVAILABLE_STATUS{return}
 e.unavailable_statuses+=1
 runtime_log(rt,"{\"event\":\"STATUS\",\"stage\":\"confirmed_control_unavailable\",\"framework\":\"kit\",\"role\":\"%s\",\"epoch\":%d,\"tick\":%d,\"seat\":%d,\"class\":0,\"reason\":\"%s\",\"status\":%d,\"coverage_available\":false}\n",role_name(rt.role),k.lane_world_epoch(&rt.lane),tick,seat,reason,status)
}
confirmed_control_declare :: proc(rt:^Runtime){
 e:=&rt.control_evidence;if e.declared{return};e.declared=true
 e.epoch=k.lane_world_epoch(&rt.lane);e.baseline=rt.baseline;e.target=rt.target;e.through=e.baseline
 e.domain_invalid=!rt.model_ready||e.epoch==0||e.target==0||e.target>CONTROL_EVIDENCE_MAX_TARGET||e.baseline>e.target
 runtime_log(rt,"{\"event\":\"STATUS\",\"stage\":\"confirmed_control_config\",\"framework\":\"kit\",\"role\":\"%s\",\"epoch\":%d,\"baseline\":%d,\"target\":%d,\"max_target\":65535,\"max_input_rows\":131070,\"local_bytes_required\":4,\"max_unavailable_status\":8,\"domain_available\":%v}\n",role_name(rt.role),e.epoch,e.baseline,e.target,!e.domain_invalid)
}
confirmed_control_advance :: proc(rt:^Runtime,tick:u64)->bool{
 confirmed_control_declare(rt);e:=&rt.control_evidence
 if tick<=e.through {e.duplicates_suppressed+=1;return false}
 if !e.domain_invalid&&e.through<e.target {
  gap_end:=min(tick-1,e.target)
  if gap_end>e.through {e.unavailable+=2*(gap_end-e.through);confirmed_control_unavailable(rt,tick,0,"unobserved_confirmed_prefix",.History_Missing)}
 }
 e.through=tick
 if e.epoch!=k.lane_world_epoch(&rt.lane)||e.target!=rt.target||e.baseline!=rt.baseline {e.domain_invalid=true}
 if e.domain_invalid {e.unavailable+=2;confirmed_control_unavailable(rt,tick,0,"invalid_or_changed_domain",.Unsupported);return false}
 if tick>e.target||tick>CONTROL_EVIDENCE_MAX_TARGET {e.capped+=2;confirmed_control_unavailable(rt,tick,0,"target_cap",.Capacity);return false}
 return true
}
confirmed_control_copy :: proc(local_bytes:int,bytes:[]u8,status:k.World_Error,origin:k.World_Input_Origin)->(value:common.Control,valid:bool){
 if local_bytes!=4||size_of(common.Control)!=4||status!=.Ok||len(bytes)!=4||(origin!=.Submitted&&origin!=.Held&&origin!=.Authority){return}
 copy((cast([^]u8)&value)[:size_of(value)],bytes);valid=true;return
}
confirmed_control_missing_checkpoint :: proc(rt:^Runtime,tick:u64,status:k.World_Error){
 if !confirmed_control_advance(rt,tick){return}
 rt.control_evidence.unavailable+=2;confirmed_control_unavailable(rt,tick,0,"confirmed_checkpoint_unavailable",status)
}
confirmed_control_inputs :: proc(rt:^Runtime,tick:u64){
 if !confirmed_control_advance(rt,tick){return};e:=&rt.control_evidence
 for player,i in rt.players {
  if e.emitted>=CONTROL_EVIDENCE_MAX_ROWS {e.capped+=1;confirmed_control_unavailable(rt,tick,i+1,"row_cap",.Capacity);continue}
  if player==0||rt.players[0]==rt.players[1] {e.unavailable+=1;confirmed_control_unavailable(rt,tick,i+1,"player_mapping_unavailable",.Unsupported);continue}
  bytes,origin,sequence,status:=k.lane_world_accepted_input(&rt.lane,tick,player,0)
  value,valid:=confirmed_control_copy(rt.controls.value.local_bytes,bytes,status,origin)
  if !valid {e.unavailable+=1;confirmed_control_unavailable(rt,tick,i+1,"accepted_control_unavailable_or_malformed",status);continue}
  runtime_log(rt,"{\"event\":\"INPUT\",\"framework\":\"kit\",\"role\":\"%s\",\"epoch\":%d,\"tick\":%d,\"seat\":%d,\"player\":%d,\"class\":0,\"x\":%d,\"z\":%d,\"origin\":%d,\"sequence\":%d,\"accepted\":true,\"status\":%d}\n",role_name(rt.role),e.epoch,tick,i+1,player,value.x,value.z,origin,sequence,status)
  e.emitted+=1
 }
}
confirmed_control_summary :: proc(rt:^Runtime){
 confirmed_control_declare(rt);e:=&rt.control_evidence;if e.summary_emitted{return};e.summary_emitted=true
 expected:=u64(0);if e.target>0&&e.target<=CONTROL_EVIDENCE_MAX_TARGET&&e.baseline<=e.target {expected=2*(e.target-e.baseline)}
 complete:=!e.domain_invalid&&e.through>=e.target&&e.emitted==expected&&e.unavailable==0&&e.capped==0&&e.duplicates_suppressed==0
 runtime_log(rt,"{\"event\":\"STATUS\",\"stage\":\"confirmed_control_summary\",\"framework\":\"kit\",\"role\":\"%s\",\"epoch\":%d,\"baseline\":%d,\"target\":%d,\"max_target\":65535,\"max_input_rows\":131070,\"expected\":%d,\"emitted\":%d,\"unavailable\":%d,\"capped\":%d,\"duplicates_suppressed\":%d,\"through\":%d,\"unavailable_statuses\":%d,\"domain_complete\":%v,\"evidence_size\":%d,\"runtime_size\":%d}\n",role_name(rt.role),e.epoch,e.baseline,e.target,expected,e.emitted,e.unavailable,e.capped,e.duplicates_suppressed,e.through,e.unavailable_statuses,complete,size_of(Confirmed_Control_Evidence),size_of(Runtime))
}
// CONTROL_EVIDENCE61_END
Runtime :: struct {
 sdk:p.SDK_Context,
 allocator:mem.Allocator,
 bindings:[8]p.SDK_User_Owner,
 wire_owner:bg.Owner,
 node:gd.Node,
 ses:s.Session,
 wire:ng.Session_Wire,
 lane:k.Lane,
 physics:p.Instance(Side),
 network:p.Network(Side),
 controls:p.Typed_Codec(common.Control),
 action_codec:p.Typed_Codec(common.Action),
 proxy_codec:p.Typed_Codec(Proxy),
 event_codec:p.Typed_Codec(Stamped_Event),
 proxies:[common.MAX_DYNAMIC]Proxy,
 descriptor:n.Entity_Desc,
 sink:^FX_Sink,
 role:Role,
 players:[2]n.Player_Id,
 seat:u16,
 initial,seed:u32,
 target,baseline,last_logged,last_written:u64,
 output:string,
 scripted,model_ready,ready_sent,ready_logged,lead_applied,started,finished,failed:bool,
 client_done:bool,
 start_after,finish_after,created_at:f64,
 ready_peers:[8]s.Peer_Id,
 ready_count:int,
 actions:[2]common.Action,
 native_failed:bool,
 control:common.Control,
 action:common.Action,
 error:k.World_Error,
 ingress:Ingress,
 recovering:bool,
 recovery_head,recovery_confirmed:u64,
 generation:u32,
 requested_ticks,end_tick:u64,
 expected_observers:int,
 welcomed:[8]bool,
 done_peers:[8]bool,
 acked_peers:[8]bool,
 baseline_ready,tail_logged:bool,
 recovery_pumps:u64,
 finals:[9]Final_Receipt,
 final_count:int,
 raw_send:s.Send_Proc,
 raw_send_user:rawptr,
 probe_expected:u32,
 recovery_sequence:u64,
 reanchor_baseline,reanchor_bootstrap:u64,
 rejoin:Rejoin_Guard,
 exit_at:u64,
 observations:Published_Observations,
 diagnostic_pumps:u64,
 diagnostic_next,diagnostic_dt:f64,
 intents:Intent_Catalog,
 presentation_effect_count:u64,
 presentation_effect:bp.Effect_Observation,
 impairment:Scene_Impairment,
 caller_credit:Caller_Credit,
 caller_account:Caller_Account,
 control_evidence:Confirmed_Control_Evidence, // CONTROL_EVIDENCE61_STATE
}
capture_ingress :: proc(rt:^Runtime) {
 net:=rt.lane.world.network
 rt.ingress={head=rt.lane.ticker.tick,confirmed=k.lane_world_confirmed(&rt.lane),checkpoint_tick=net.transfer_tick,checkpoint_sequence=net.transfer_sequence,checkpoint_mode=u8(net.transfer_mode),pending=len(net.transfer)>0 && net.transfer_received==net.transfer_chunks,accepted_first=max(u64)}
 for packet in net.queue[:net.queue_count] {if packet.kind==k.SIM_WORLD_ACCEPTED {
  r:=n.reader_make(packet.bytes);_=n.read_u32(&r);_=n.reader_view(&r,32);_=n.read_u64(&r)
  head:=n.read_u64(&r);first:=n.read_u64(&r)
  if !r.err {rt.ingress.accepted_first=min(rt.ingress.accepted_first,first);rt.ingress.accepted_head=max(rt.ingress.accepted_head,head)}
 }}
}
request_reset_observed :: proc(rt:^Runtime,code:k.World_Error,request_source:string)->(k.World_Error,bool) {
 before,be:=k.lane_world_checkpoint(&rt.lane,rt.lane.ticker.tick)
 rt.recovery_head=rt.lane.ticker.tick;rt.recovery_confirmed=k.lane_world_confirmed(&rt.lane)
 rt.recovery_sequence=rt.lane.world.network.received_sequence
 status:=k.lane_world_request_reset(&rt.lane)
 after,ae:=k.lane_world_checkpoint(&rt.lane,rt.lane.ticker.tick)
 preserved:=false
 if be==.Ok && ae==.Ok {same,ee:=k.world_checkpoint_equal(&before,&after);preserved=same && ee==.Ok}
 _=k.world_checkpoint_destroy(&before);_=k.world_checkpoint_destroy(&after)
 runtime_log(rt,"{\"event\":\"RECOVERY_REQUESTED\",\"framework\":\"kit\",\"reason\":%d,\"head\":%d,\"confirmed\":%d,\"checkpoint_tick\":%d,\"checkpoint_mode\":%d,\"checkpoint_sequence\":%d,\"checkpoint_pending\":%v,\"pre_head\":%d,\"pre_confirmed\":%d,\"accepted_first\":%d,\"accepted_head\":%d,\"published_preserved\":%v,\"request_status\":%d,\"request_source\":\"%s\"}\n",code,rt.recovery_head,rt.recovery_confirmed,rt.ingress.checkpoint_tick,rt.ingress.checkpoint_mode,rt.ingress.checkpoint_sequence,rt.ingress.pending,rt.ingress.head,rt.ingress.confirmed,rt.ingress.accepted_first,rt.ingress.accepted_head,preserved,status,request_source)
 return status,preserved
}
handle_hold :: proc(rt:^Runtime)->bool {
 if !k.lane_world_needs_resync(&rt.lane) {return false}
 code:=k.lane_world_status(&rt.lane)
 if !rt.ses.is_host && !rt.recovering && (code==.Repair_Limit || code==.Prediction_Limit || code==.History_Missing) {
  status,preserved:=request_reset_observed(rt,code,"hold")
  if status!=.Ok || !preserved {rt.failed=true}else{rt.recovering=true}
  return true
 }
 if !rt.recovering {runtime_log(rt,"{\"event\":\"ERROR\",\"framework\":\"kit\",\"where\":\"lane\",\"code\":%d,\"head\":%d,\"confirmed\":%d}\n",code,rt.lane.ticker.tick,k.lane_world_confirmed(&rt.lane));rt.failed=true}
 return true
}
observe_recovered :: proc(rt:^Runtime)->bool {
 if !rt.recovering {return false}
 net:=rt.lane.world.network
 if !k.lane_world_network_status(&rt.lane).ready || net.received_sequence<=rt.recovery_sequence {return false}
 signature,error:=k.lane_world_confirmed_signature(&rt.lane,net.last_signature.tick)
 if error!=.Ok || bd.compare(signature,net.last_signature)!=.Match {rt.failed=true;return false}
 if caller_client(rt)&&rt.started {rt.reanchor_baseline=signature.tick;rt.reanchor_bootstrap=net.received_sequence}
 rt.lead_applied=false
 // A later queued row may have hit another bound after this reset committed.
 // Acknowledge the real validated baseline before classifying that later hold.
 rt.recovering=false;rt.last_logged=signature.tick
 bytes:[bd.SIGNATURE_BYTES]u8;_,encoding_error:=bd.signature_encode(signature,bytes[:]);if encoding_error!=.None {rt.failed=true;return true}
 digits:="0123456789abcdef";hex:[bd.SIGNATURE_BYTES*2]u8
 for byte,i in bytes {hex[2*i]=digits[byte>>4];hex[2*i+1]=digits[byte&15]}
 runtime_log(rt,"{\"event\":\"RECOVERED\",\"framework\":\"kit\",\"epoch\":%d,\"baseline\":%d,\"previous_head\":%d,\"previous_confirmed\":%d,\"head\":%d,\"confirmed\":%d,\"request_sequence\":%d,\"received_sequence\":%d,\"signature_hex\":\"%s\"}\n",signature.epoch,signature.tick,rt.recovery_head,rt.recovery_confirmed,rt.lane.ticker.tick,k.lane_world_confirmed(&rt.lane),rt.recovery_sequence,net.received_sequence,string(hex[:]))
 intent_rebase(rt,rt.recovery_head,signature.tick,rt.recovery_sequence,net.received_sequence)
 return true
}
bind :: proc(rt:^Runtime,index:int,user:rawptr,size:u64)->bool {
 value,error:=p.sdk_user_owner_create(rt.sdk.memory,rt,u64(size_of(rt^)),user,size)
 if error!=.Ok {rt.error=error;return false};rt.bindings[index]=value
 return true
}
runtime_create :: proc(node:gd.Node,role:Role,generation:u32=1,rejoin:Rejoin_Guard={})->^Runtime {
 impairment,impairment_error,bad_field:=scene_impairment()
 if impairment_error!=.None {scene_impairment_reject(node,role,generation,impairment,impairment_error,bad_field);return nil}
 sdk,error:=p.sdk_context_create();if error!=.Ok {json_line("{\"event\":\"ERROR\",\"framework\":\"kit\",\"where\":\"context\",\"code\":%d}\n",error);return nil}
 alloc:=bm.allocator(sdk.memory);context.allocator=alloc
 allocation_before,allocation_before_status:=bm.stats(sdk.memory)
 rt:=new(Runtime,alloc)
 allocation_after,allocation_after_status:=bm.stats(sdk.memory)
 rt.sdk=sdk;rt.allocator=alloc;rt.node=node;rt.role=role;rt.created_at=n.now_s();rt.generation=generation
 rt.impairment=impairment
 rt.rejoin=rejoin
 if rejoin.player==0 && gd.env_int("B3_EXPECT_PLAYER",0)!=0 {
  player:=gd.env_int("B3_EXPECT_PLAYER",0);first:=gd.env_int("B3_EXPECT_PLAYER1",0);second:=gd.env_int("B3_EXPECT_PLAYER2",0);seat:=gd.env_int("B3_EXPECT_SEAT",0);epoch:=gd.env_int("B3_EXPECT_EPOCH",0);source:=gd.env_int("B3_SOURCE_GEN",0)
  if player<1 || player>65535 || first<1 || first>65535 || second<1 || second>65535 || first>=second || seat<1 || seat>2 || epoch<1 || source<1 || source>=int(generation) {rt.failed=true;rt.error=.Invalid;return rt}
  rt.rejoin={player=n.Player_Id(player),players={n.Player_Id(first),n.Player_Id(second)},seat=u16(seat),epoch=u64(epoch),token=u64(gd.env_int("B3_TOKEN",202)),source_generation=u32(source)}
 }
 if rt.rejoin.player!=0 && (role!=.Client || rt.rejoin.source_generation>=generation || rt.rejoin.token==0) {rt.failed=true;rt.error=.Unsupported;return rt}
 if rt.rejoin.player!=0 {runtime_log(rt,"{\"event\":\"REJOIN_GUARD\",\"framework\":\"kit\",\"source_generation\":%d,\"new_generation\":%d,\"expected_player\":%d,\"expected_seat\":%d,\"expected_epoch\":%d,\"token\":%d}\n",rt.rejoin.source_generation,generation,rt.rejoin.player,rt.rejoin.seat,rt.rejoin.epoch,rt.rejoin.token)}
 automatic:=gd.env_string("B3_ROLE","")!=""
 rt.scripted=gd.env_int("B3_SCRIPTED",automatic?1:0)!=0
 if rt.scripted {
  allocation_observed:=allocation_before_status==bg.OK&&allocation_after_status==bg.OK&&allocation_after.requested_bytes>=allocation_before.requested_bytes&&allocation_after.live_bytes>=allocation_before.live_bytes
  requested_delta,live_delta:=u64(0),u64(0)
  if allocation_observed {requested_delta=allocation_after.requested_bytes-allocation_before.requested_bytes;live_delta=allocation_after.live_bytes-allocation_before.live_bytes}
  runtime_log(rt,"{\"event\":\"STATUS\",\"framework\":\"kit\",\"stage\":\"runtime_allocation\",\"role\":\"%s\",\"runtime_size\":%d,\"before_status\":%d,\"after_status\":%d,\"observed\":%v,\"requested_before\":%d,\"requested_after\":%d,\"live_before\":%d,\"live_after\":%d,\"requested_delta\":%d,\"live_delta\":%d}\n",role_name(role),size_of(Runtime),allocation_before_status,allocation_after_status,allocation_observed,allocation_before.requested_bytes,allocation_after.requested_bytes,allocation_before.live_bytes,allocation_after.live_bytes,requested_delta,live_delta)
 }
 rt.seed=u32(gd.env_int("B3_SEED",1));rt.initial=u32(gd.env_int("B3_BODIES",4));rt.requested_ticks=u64(gd.env_int("B3_TICKS",rt.scripted?240:0));rt.target=rt.requested_ticks
 rt.end_tick=u64(gd.env_int("B3_END_TICK",0));if rt.end_tick!=0 {rt.target=rt.end_tick}
 rt.exit_at=u64(gd.env_int("B3_EXIT_AT",0))
 if rt.exit_at!=0 && (role!=.Client || generation!=1 || (rt.target!=0 && rt.exit_at>=rt.target)) {rt.failed=true;rt.error=.Invalid;return rt}
 if rt.end_tick!=0 && rt.end_tick<rt.requested_ticks {rt.failed=true;return rt}
 rt.expected_observers=gd.env_int("B3_EXPECT_OBSERVERS",0)
 root_output:=gd.env_string("B3_OUTPUT","",alloc)
 if root_output!="" {rt.output=fmt.aprintf("%s/g%d",root_output,generation);_=os.make_directory_all(rt.output);delete(root_output,alloc)}
 if rt.output!="" {_=os.make_directory(rt.output)}
 if !bind(rt,0,rt,u64(size_of(rt^))) || !bind(rt,1,&rt.physics,u64(size_of(rt.physics))) || !bind(rt,2,&rt.network,u64(size_of(rt.network))) || !bind(rt,3,&rt.controls,u64(size_of(rt.controls))) || !bind(rt,4,&rt.action_codec,u64(size_of(rt.action_codec))) || !bind(rt,5,&rt.proxy_codec,u64(size_of(rt.proxy_codec))) || !bind(rt,6,&rt.event_codec,u64(size_of(rt.event_codec))) {rt.failed=true;return rt}
 rt.sink=new(FX_Sink,alloc)
 sink,se:=p.sdk_user_owner_create(sdk.memory,rt.sink,u64(size_of(FX_Sink)),rt.sink,u64(size_of(FX_Sink)));if se!=.Ok {rt.failed=true;return rt};rt.bindings[7]=sink
 lease,ls:=bm.block_lease(sdk.memory,rt,u64(size_of(rt^)),&rt.wire,u64(size_of(rt.wire)))
 if ls!=bg.OK {rt.failed=true;return rt}
 rt.wire_owner,error=p.sdk_owner_create(true,lease);if error!=.Ok {rt.failed=true;return rt}
 if ng.wire_configure(&rt.wire,{allocator=alloc,owner=rt.wire_owner,user_data=&rt.wire,allocator_owner=sdk.detached,allocator_data=alloc.data,seed=u64(rt.seed)})!=.Ok {rt.failed=true;return rt}
 rt.ses.allocator=alloc;s.session_configure(&rt.ses,{tick_hz=60,max_players=2})
 // Kit Session supplies the authoritative roster/relay. SceneMultiplayer's
 // unrelated client-to-client relay must not notify already-closing ENet peers.
 mp:=gd.node_get_multiplayer(node)
 gd.scene_multiplayer_set_server_relay_enabled(cast(gd.Scene_Multiplayer)mp,false)
 gd.release_ref(mp)
 ng.wire_attach(&rt.wire,node,&rt.ses,0)
 if gd.env_int("B3_TRACE_SEND",0)!=0 {rt.raw_send=rt.ses.send;rt.raw_send_user=rt.ses.send_user;s.session_set_transport(&rt.ses,rt,trace_send)} else if rt.scripted {rt.raw_send=rt.ses.send;rt.raw_send_user=rt.ses.send_user;s.session_set_transport(&rt.ses,rt,intent_send)}
 if ng.wire_listen(&rt.wire,"on_packet","on_peer_left","on_net_up","on_net_down")!=.Ok {rt.failed=true;return rt}
 s.session_app_route(&rt.ses,4,rt,control_packet)
 port:=gd.env_int("B3_PORT",43123)
 opened:bool
 if role==.Host || role==.Dedicated {opened=ng.transport_host(&rt.wire,&ng.ENET,{port=port,max_peers=8},"Kit host",token=101,dedicated=role==.Dedicated)}
 else {address:=gd.env_string("B3_ADDRESS","127.0.0.1");token:=rt.rejoin.player!=0?rt.rejoin.token:u64(gd.env_int("B3_TOKEN",role==.Observer?303:202));opened=ng.transport_join(&rt.wire,&ng.ENET,{addr=fmt.ctprintf("%s",address),port=port},"Kit peer",token,spectate=role==.Observer)}
 if !opened {rt.failed=true}
 if opened && rt.ses.is_host && gd.env_int("B3_WIRE_PROBE",0)!=0 {empty_send_probe(rt,"before")}
 ng.wire_set_latency(&rt.wire,impairment.latency_ms,impairment.jitter_ms,impairment.loss_percent)
 runtime_log(rt,"{\"event\":\"BOOT\",\"framework\":\"kit\",\"role\":\"%s\",\"opened\":%v,\"initial\":%d,\"seed\":%d}\n",role_name(role),opened,rt.initial,rt.seed)
 return rt
}
empty_send_probe :: proc(rt:^Runtime,phase:string) {
 mp:=gd.node_get_multiplayer(rt.node);defer gd.release_ref(mp)
 peers:=gd.multiplayer_api_get_peers(mp);count:=gd.packed_int32_array_size(&peers);defer gd.free_packed_int32_array(peers)
 if count!=0 {runtime_log(rt,"{\"event\":\"WIRE_PROBE_EMPTY\",\"phase\":\"%s\",\"remote_count\":%d,\"tested\":false}\n",phase,count);return}
 for channel in ([]s.Channel{.Reliable,.Stream}) {
  writer:=s.session_app_begin(&rt.ses,4);n.write_u8(writer,255);s.session_app_flush(&rt.ses,s.BROADCAST_PEER,channel)
 }
 runtime_log(rt,"{\"event\":\"WIRE_PROBE_EMPTY\",\"phase\":\"%s\",\"remote_count\":0,\"tested\":true,\"wire_status\":%d}\n",phase,ng.wire_status(&rt.wire).error)
}
trace_send :: proc(user:rawptr,peer:s.Peer_Id,bytes:[]u8,channel:s.Channel) {
 rt:=cast(^Runtime)user
 if rt.wire.config.owner.check(rt.wire.config.owner.user,bg.EXECUTE)!=bg.OK {return}
 mp:=gd.node_get_multiplayer(rt.node);defer gd.release_ref(mp)
 peers:=gd.multiplayer_api_get_peers(mp);count:=gd.packed_int32_array_size(&peers);defer gd.free_packed_int32_array(peers)
 traced:=rt.model_ready && rt.target>0 && rt.lane.ticker.tick>=rt.target
 if traced {runtime_log(rt,"{\"event\":\"SEND_TRACE_ENTER\",\"framework\":\"kit\",\"peer\":%d,\"remote_count\":%d,\"channel\":%d,\"bytes\":%d,\"kind\":%d}\n",peer,count,channel,len(bytes),len(bytes)>0?bytes[0]:0)}
 before:=ng.wire_status(&rt.wire)
 rt.raw_send(rt.raw_send_user,peer,bytes,channel)
 if rt.scripted {intent_note_send(rt,bytes,channel,before,ng.wire_status(&rt.wire))}
 if traced {runtime_log(rt,"{\"event\":\"SEND_TRACE_EXIT\",\"framework\":\"kit\",\"channel\":%d}\n",channel)}
}
role_name :: proc(role:Role)->string {switch role {case .Host:return "host";case .Client:return "client";case .Observer:return "observer";case .Dedicated:return "server"};return "unknown"}
roster :: proc(rt:^Runtime)->bool {
 if !rt.ses.joined {return false}
 players:=s.session_roster(&rt.ses,rt.allocator);defer delete(players,rt.allocator)
 count:=0
 for player in players {if !player.spectator && !player.dedicated && player.connected {if count==2 {return false};rt.players[count]=player.id;count+=1}}
 if count!=2 {return false}
 for player,i in rt.players {if player==rt.ses.me {rt.seat=u16(i+1)}}
 if rt.rejoin.player!=0 && (rt.ses.me!=rt.rejoin.player || rt.players!=rt.rejoin.players || rt.seat!=rt.rejoin.seat || rt.ses.token!=rt.rejoin.token) {
  runtime_log(rt,"{\"event\":\"ERROR\",\"framework\":\"kit\",\"where\":\"rejoin_identity\",\"me\":%d,\"expected_player\":%d,\"seat\":%d,\"expected_seat\":%d}\n",rt.ses.me,rt.rejoin.player,rt.seat,rt.rejoin.seat);rt.failed=true;rt.error=.Incompatible;return false
 }
 return true
}
model_create :: proc(rt:^Runtime)->bool {
 context.allocator=rt.allocator
 if !roster(rt) {return false}
 k.lane_init(&rt.lane,&rt.ses,size_of(common.Control),cfg={slots=128,snap_every=3},allocator=rt.allocator)
 k.lane_set_sim(&rt.lane,rt,sample_control,model_step)
 k.lane_class_set_type(&rt.lane,0,common.Control);k.lane_class_set_validate(&rt.lane,0,validate_control)
 k.lane_add_input_class(&rt.lane,1,size_of(common.Action),sample_action);k.lane_class_set_type(&rt.lane,1,common.Action);k.lane_class_set_validate(&rt.lane,1,validate_action)
 @(static) fields:=[]n.Field_Desc{{offset=offset_of(Proxy,pose),size=size_of(b.Pose),name="pose",flags={.Predicted}},{offset=offset_of(Proxy,lifetime),size=8,name="lifetime",flags={.Predicted}},{offset=offset_of(Proxy,alive),size=1,name="alive",flags={.Predicted}}}
 rt.descriptor={fields=fields};types:[common.MAX_DYNAMIC]k.World_Field_Type
 for &proxy,i in rt.proxies {k.lane_track(&rt.lane,n.Net_Id(i+1),&proxy,&rt.descriptor,rt.ses.me);types[i]=k.world_field_type(n.Net_Id(i+1),Proxy)}
 world,game,status:=common.world(rt.initial,rt.seed);if status!=.Ok {rt.error=.Step_Failed;rt.failed=true;return false}
 for &proxy,i in rt.proxies {
  proxy={alive=game.alive[i],lifetime=game.lifetimes[i]}
  if proxy.alive {body,bs:=b.body_resolve(world,game.bodies[i]);if bs!=.Ok {_=b.world_destroy(&world);rt.failed=true;return false};proxy.pose,bs=b.body_get_pose(body);if bs!=.Ok {_=b.world_destroy(&world);rt.failed=true;return false}}
 }
 cfg:=p.sdk_context_config(rt.sdk,common.ASSET_DECLARATION,provider=rt.bindings[1],author=rt.bindings[0],effects=rt.bindings[7])
 error:=p.attach(&rt.physics,&rt.lane,&world,Side{game=game,players={u16(rt.players[0]),u16(rt.players[1])}},types[:],cfg,model_settle)
 if error!=.Ok {_=b.world_destroy(&world);rt.error=error;rt.failed=true;return false}
 if p.codec_init(&rt.controls,allocator=rt.allocator,ownership=rt.bindings[3])!=.Ok || p.codec_init(&rt.action_codec,allocator=rt.allocator,ownership=rt.bindings[4])!=.Ok || p.codec_init(&rt.proxy_codec,&rt.descriptor,rt.allocator,ownership=rt.bindings[5])!=.Ok || p.codec_init(&rt.event_codec,allocator=rt.allocator,ownership=rt.bindings[6])!=.Ok {rt.failed=true;return false}
 native:=b.recovery_config_default();native.profile=common.PROFILE;assets:=common.assets()
 catalog,cs:=b.recovery_catalog_create(native,assets[:]);if cs!=.Ok {rt.failed=true;return false};defer b.recovery_catalog_destroy(&catalog)
 wire_fields:[common.MAX_DYNAMIC]k.World_Wire_Field
 for &field,i in wire_fields {field={n.Net_Id(i+1),rt.proxy_codec.value}}
 inputs:=[]k.World_Wire_Input{{0,rt.controls.value,.Hold},{1,rt.action_codec.value,.Neutral}}
 drivers:=[]k.World_Driver{{rt.players[0],0},{rt.players[0],1},{rt.players[1],0},{rt.players[1],1}}
 effects:=[]k.World_Effect_Def{{1,record_effect,rt.sink,rt.event_codec.value}}
 parameters:[8]u8;for i in 0..<4 {parameters[i]=u8(rt.initial>>uint(8*i));parameters[i+4]=u8(rt.seed>>uint(8*i))}
 shared:=common.game_rules();rules,re:=bd.hash_descriptors("kit-box3d-playable-rules-v1",[]bd.Descriptor{{"adapter",transmute([]u8)#load("model.odin")},{"intent_policy",transmute([]u8)#load("intents.odin")},{"parameters",parameters[:]},{"shared",shared[:]}})
 if re!=.None {rt.failed=true;return false}
 rt.network.side_valid=side_valid
 error=p.network_attach(&rt.network,&rt.physics,&catalog,wire_fields[:],inputs,drivers,effects,rules,ownership=rt.bindings[2])
 if error!=.Ok {rt.error=error;rt.failed=true;return false}
 rt.model_ready=true
 return true
}
send_ready :: proc(rt:^Runtime) {
 w:=s.session_app_begin(&rt.ses,4);n.write_u8(w,1);n.write_u32(w,1);n.write_u32(w,rt.initial);n.write_u32(w,rt.seed)
 for player in rt.players {n.write_u16(w,u16(player))};digest:=common.game_rules();n.write_bytes(w,digest[:]);s.session_app_flush(&rt.ses,s.HOST_PEER,.Reliable);rt.ready_sent=true
}
control_packet :: proc(user:rawptr,from:n.Player_Id,peer:s.Peer_Id,r:^n.Reader) {
 rt:=cast(^Runtime)user
 kind:=n.read_u8(r)
 if !rt.ses.is_host {
  if kind==250 && peer==s.HOST_PEER {
   sequence:=n.read_u32(r)
   if r.err || sequence!=rt.probe_expected || len(n.reader_remaining(r))!=0 {rt.failed=true;return}
   rt.probe_expected+=1
   runtime_log(rt,"{\"event\":\"WIRE_PROBE_FIFO\",\"role\":\"%s\",\"sequence\":%d,\"ordered\":true}\n",role_name(rt.role),sequence)
   return
  }
  if peer==s.HOST_PEER && kind==4 && n.read_u32(r)==1 && rt.baseline_ready && n.read_u64(r)==k.lane_world_epoch(&rt.lane) && !r.err && len(n.reader_remaining(r))==0 {
   if !rt.started {rt.started=true;runtime_log(rt,"{\"event\":\"GO\",\"framework\":\"kit\",\"role\":\"%s\",\"head\":%d,\"confirmed\":%d,\"baseline\":%d}\n",role_name(rt.role),rt.lane.ticker.tick,k.lane_world_confirmed(&rt.lane),rt.baseline)}
  }
  return
 }
 if kind==1 {
  version:=n.read_u32(r);initial:=n.read_u32(r);seed:=n.read_u32(r);players:=[2]u16{n.read_u16(r),n.read_u16(r)};digest:=n.read_bytes_limited(r,32)
  if r.err || version!=1 || initial!=rt.initial || seed!=rt.seed || len(n.reader_remaining(r))!=0 {return}
  expected:=common.game_rules();for byte,i in digest {if byte!=expected[i] {return}}
  if !rt.model_ready || players!=([2]u16{u16(rt.players[0]),u16(rt.players[1])}) {return}
  for old in rt.ready_peers[:rt.ready_count] {if old==peer {return}}
  if rt.ready_count==len(rt.ready_peers) {return}
  rt.ready_peers[rt.ready_count]=peer;rt.ready_count+=1
 }else if kind==2 {
  wire:=n.read_bytes_limited(r,bd.SIGNATURE_BYTES);if r.err {return};signature,error:=bd.signature_decode(wire)
  local,le:=k.lane_world_confirmed_signature(&rt.lane,rt.target)
  if error==.None && le==.Ok && bd.compare(signature,local)==.Match {for &receipt in rt.finals[:rt.final_count] {if receipt.player==from && receipt.peer==peer && receipt.epoch==signature.epoch && receipt.target==signature.tick && !receipt.received {
   receipt.received=true;receipt.signature=signature
   runtime_log(rt,"{\"event\":\"TAIL\",\"framework\":\"kit\",\"role\":\"%s\",\"stage\":\"final_received\",\"tick\":%d,\"from_role\":\"%s\",\"from\":%d,\"peer\":%d,\"from_token_hash\":%d,\"matched\":true}\n",role_name(rt.role),signature.tick,receipt.spectator?"observer":"client",from,peer,receipt.token_hash)
  }}}
 }else if kind==3 {
  bytes:=n.read_bytes_limited(r,bd.SIGNATURE_BYTES)
  if r.err || len(bytes)!=bd.SIGNATURE_BYTES || len(n.reader_remaining(r))!=0 {return}
  signature,se:=bd.signature_decode(bytes);if se!=.None {return}
  local,le:=k.lane_world_confirmed_signature(&rt.lane,signature.tick)
  if le!=.Ok || bd.compare(signature,local)!=.Match {return}
  eligible:=false;for old,i in rt.ready_peers[:rt.ready_count] {if old==peer && rt.welcomed[i] {eligible=true}}
  if !eligible {return}
  if rt.started {
   observer,have_observer:=s.session_player(&rt.ses,from)
   if have_observer&&observer.spectator {
    if !observer.connected||observer.peer!=peer {rt.failed=true;rt.error=.Incompatible;return}
    token_hash:=u64(0);for hash,id in rt.ses.tokens {if id==from {token_hash=u64(hash);break}}
    if token_hash==0 {rt.failed=true;rt.error=.Incompatible;return}
    enrolled:=false
    for receipt in rt.finals[:rt.final_count] {if receipt.player==from {
     if !receipt.spectator||receipt.peer!=peer||receipt.token_hash!=token_hash||receipt.epoch!=signature.epoch||receipt.target!=rt.target||receipt.pending_rejoin {rt.failed=true;rt.error=.Incompatible;return}
     enrolled=true;break
    }}
    if !enrolled {
     if rt.finished||rt.finish_after>0||rt.final_count>=len(rt.finals)||rt.final_count>=16||len(rt.ses.players)>16 {rt.failed=true;rt.error=.Unsupported;return}
     rt.finals[rt.final_count]={player=from,peer=peer,token_hash=token_hash,epoch=signature.epoch,target=rt.target,incarnation=1,spectator=true,received=false}
     rt.final_count+=1
    }
   }
  }
  for &receipt in rt.finals[:rt.final_count] {if receipt.player==from && receipt.peer!=peer {
   if !receipt.pending_rejoin || receipt.pending_peer!=peer || receipt.incarnation==max(u32) {rt.failed=true;rt.error=.Incompatible;return}
   old_peer:=receipt.peer;receipt.peer=peer;receipt.pending_peer=0;receipt.pending_rejoin=false;receipt.received=false;receipt.signature={};receipt.incarnation+=1
   runtime_log(rt,"{\"event\":\"REJOIN_ACCEPTED\",\"framework\":\"kit\",\"epoch\":%d,\"baseline\":%d,\"player\":%d,\"old_peer\":%d,\"peer\":%d,\"from_token_hash\":%d,\"incarnation\":%d,\"matched\":true,\"inherited_ack\":false}\n",signature.epoch,signature.tick,from,old_peer,peer,receipt.token_hash,receipt.incarnation)
  }}
  for old,i in rt.ready_peers[:rt.ready_count] {if old==peer && rt.welcomed[i] && !rt.acked_peers[i] {rt.acked_peers[i]=true;if rt.started {send_go(rt,peer)}}}
 }
}
freeze_final_cohort :: proc(rt:^Runtime) {
 if rt.final_count!=0 {return}
 for id,player in rt.ses.players {
  included:=id==rt.ses.me
  for driver in rt.players {if id==driver {included=true}}
  if player.spectator && player.connected && peer_ready(rt,player.peer,false) {included=true}
  if !included {continue}
  if rt.final_count==len(rt.finals) {rt.failed=true;return}
  hash:=u64(0);for token_hash,owner in rt.ses.tokens {if owner==id {hash=u64(token_hash);break}}
  rt.finals[rt.final_count]={player=id,peer=player.peer,token_hash=hash,epoch=k.lane_world_epoch(&rt.lane),target=rt.target,incarnation=1,spectator=player.spectator}
  rt.final_count+=1
 }
}
all_final_receipts :: proc(rt:^Runtime)->bool {
 if rt.final_count==0 {return false}
 for receipt in rt.finals[:rt.final_count] {if !receipt.received {return false}}
 return true
}
peer_ready :: proc(rt:^Runtime,peer:s.Peer_Id,done:bool)->bool {
 for old,i in rt.ready_peers[:rt.ready_count] {if old==peer {return done?rt.done_peers[i]:rt.acked_peers[i]}}
 return false
}
drivers_ready :: proc(rt:^Runtime,done:bool)->bool {
 for id in rt.players {if id==rt.ses.me {continue};player,ok:=s.session_player(&rt.ses,id);if !ok || !player.connected || !peer_ready(rt,player.peer,done) {return false}}
 if rt.expected_observers>0 {
  count:=0
  for _,player in rt.ses.players {if player.connected && player.spectator && peer_ready(rt,player.peer,done) {count+=1}}
  if count<rt.expected_observers {return false}
 }
 return true
}
runtime_peer_left :: proc(rt:^Runtime,peer:s.Peer_Id) {
 _=k.lane_world_protocol_peer_disconnected(&rt.lane,peer) // Real World v2 disconnect invalidates scope/feedback.
 for i in 0..<rt.ready_count {if rt.ready_peers[i]==peer {
  for j in i..<rt.ready_count-1 {rt.ready_peers[j]=rt.ready_peers[j+1];rt.welcomed[j]=rt.welcomed[j+1];rt.done_peers[j]=rt.done_peers[j+1];rt.acked_peers[j]=rt.acked_peers[j+1]}
  rt.ready_count-=1;rt.ready_peers[rt.ready_count]=0;rt.welcomed[rt.ready_count]=false;rt.done_peers[rt.ready_count]=false;rt.acked_peers[rt.ready_count]=false
  break
 }}
}
send_welcome_ack :: proc(rt:^Runtime) {
 signature,error:=k.lane_world_confirmed_signature(&rt.lane,rt.baseline);if error!=.Ok {rt.failed=true;return}
 bytes:[bd.SIGNATURE_BYTES]u8;_,se:=bd.signature_encode(signature,bytes[:]);if se!=.None {rt.failed=true;return}
 writer:=s.session_app_begin(&rt.ses,4);n.write_u8(writer,3);n.write_bytes(writer,bytes[:]);s.session_app_flush(&rt.ses,s.HOST_PEER,.Reliable)
}
send_go :: proc(rt:^Runtime,peer:s.Peer_Id) {
 writer:=s.session_app_begin(&rt.ses,4);n.write_u8(writer,4);n.write_u32(writer,1);n.write_u64(writer,k.lane_world_epoch(&rt.lane));s.session_app_flush(&rt.ses,peer,.Reliable)
}
log_ready :: proc(rt:^Runtime) {
 if rt.ready_logged {return};rt.ready_logged=true
 protocol:=k.lane_world_protocol_status(&rt.lane)
 runtime_log(rt,"{\"event\":\"READY\",\"framework\":\"kit\",\"role\":\"%s\",\"token\":%d,\"seat\":%d,\"me\":%d,\"players\":[%d,%d],\"epoch\":%d,\"baseline\":%d,\"target\":%d,\"initial\":%d,\"seed\":%d,\"action_timing\":\"Scheduled\",\"intent_source\":\"outside_sim_catalog_class1\",\"intent_contract_version\":2,\"world_wire_revision\":%d,\"world_confirmation\":\"canonical_signature_v2\",\"caller_contract\":\"scaled_ingress0_stable_normal_v2\",\"caller_scale_min_bits\":\"%x\",\"caller_scale_max_bits\":\"%x\",\"impairment\":%s}\n",role_name(rt.role),rt.ses.token,rt.seat,rt.ses.me,rt.players[0],rt.players[1],k.lane_world_epoch(&rt.lane),rt.baseline,rt.target,rt.initial,rt.seed,protocol.wire_revision,transmute(u64)f64(0.98),transmute(u64)f64(1.02),scene_impairment_json(rt.impairment))
}
send_done :: proc(rt:^Runtime) {
 sig,error:=k.lane_world_confirmed_signature(&rt.lane,rt.target);if error!=.Ok {return}
 data:[bd.SIGNATURE_BYTES]u8;_,se:=bd.signature_encode(sig,data[:]);if se!=.None {return}
 w:=s.session_app_begin(&rt.ses,4);n.write_u8(w,2);n.write_bytes(w,data[:]);s.session_app_flush(&rt.ses,s.HOST_PEER,.Reliable)
}
write_frame :: proc(rt:^Runtime,tick:u64) {
 frame:k.World_Diagnostic_Frame
 if k.lane_world_diagnostic_frame(&rt.lane,tick,&frame)!=.Ok {return};defer k.world_diagnostic_frame_destroy(&frame)
 if rt.output=="" {return}
 base:=fmt.aprintf("%s/kit-%s-e%d-t%d",rt.output,role_name(rt.role),frame.view.epoch,tick);defer delete(base,rt.allocator)
 signature:[bd.SIGNATURE_BYTES]u8;_,error:=bd.signature_encode(frame.signature,signature[:]);if error!=.None {return}
 path:=fmt.aprintf("%s.sig",base);defer delete(path,rt.allocator)
 if os.write_entire_file(path,signature[:])!=nil {rt.failed=true;return}
 for part in bd.Part {name:=fmt.aprintf("%s.part%d",base,int(part));status:=os.write_entire_file(name,frame.view.parts[part]);delete(name,rt.allocator);if status!=nil {rt.failed=true;return}}
 runtime_log(rt,"{\"event\":\"FRAME\",\"framework\":\"kit\",\"role\":\"%s\",\"epoch\":%d,\"tick\":%d,\"head\":%d,\"confirmed\":%d,\"basePath\":\"%s\"}\n",role_name(rt.role),frame.view.epoch,tick,rt.lane.ticker.tick,k.lane_world_confirmed(&rt.lane),base)
 rt.last_written=tick
}
confirmed_events :: proc(rt:^Runtime) {
 confirmed:=k.lane_world_confirmed(&rt.lane)
 for tick:=rt.last_logged+1;tick<=confirmed;tick+=1 {
  cp,error:=k.lane_world_checkpoint(&rt.lane,tick);if error!=.Ok {confirmed_control_missing_checkpoint(rt,tick,error);break} // CONTROL_EVIDENCE61_CHECKPOINT
  confirmed_control_inputs(rt,tick) // CONTROL_EVIDENCE61_INPUTS
  side,se:=p.checkpoint_side(&cp,Side)
  if se==.Ok {for receipt,i in side.receipts {if receipt.tick==tick && receipt.kind!=.None {
   _,origin,sequence,ie:=k.lane_world_accepted_input(&rt.lane,tick,rt.players[i],1)
   runtime_log(rt,"{\"event\":\"APPLIED\",\"framework\":\"kit\",\"epoch\":%d,\"tick\":%d,\"seat\":%d,\"kind\":%d,\"applied\":%v,\"origin\":%d,\"sequence\":%d,\"accepted\":%v,\"query_total\":%d}\n",k.lane_world_epoch(&rt.lane),tick,i+1,receipt.kind,receipt.applied,origin,sequence,ie==.Ok,side.game.queries)
  }}}
  for &effect in cp.effects[:cp.effect_count] {
   stamp:Stamped_Event;if effect.count!=size_of(stamp) {continue};copy((cast([^]u8)&stamp)[:size_of(stamp)],effect.args[:effect.count])
   observed:=false;for old in rt.sink.observed[:rt.sink.count] {if old==stamp {observed=true;break}}
   duplicate:=false;for key in rt.sink.delivered[:rt.sink.delivered_count] {if key==effect.key {duplicate=true;break}}
   if !observed || duplicate || rt.sink.delivered_count==u32(len(rt.sink.delivered)) {rt.failed=true;continue}
   rt.sink.delivered[rt.sink.delivered_count]=effect.key;rt.sink.delivered_count+=1
   consumer_settled_effect(rt,stamp,effect.key)
   runtime_log(rt,"{\"event\":\"FX\",\"framework\":\"kit\",\"epoch\":%d,\"tick\":%d,\"serial\":%d,\"lifetime\":%d,\"seat\":%d,\"kind\":%d,\"key\":%d,\"confirmed\":%d,\"observed\":true}\n",stamp.epoch,tick,stamp.value.serial,stamp.value.lifetime,stamp.value.seat,stamp.value.kind,effect.key,confirmed)
  }
  _=k.world_checkpoint_destroy(&cp);rt.last_logged=tick
  if tick%30==0 || tick==rt.target {write_frame(rt,tick)}
 }
}
runtime_session_event :: proc(rt:^Runtime,event:s.Event) {
 #partial switch value in event {
 case s.Ev_Host_Left:
  _=k.lane_world_protocol_peer_disconnected(&rt.lane,s.HOST_PEER)
  rt.failed=true
 case s.Ev_Join_Failed:rt.failed=true
 case s.Ev_Player_Left:
  if rt.ses.is_host && rt.model_ready {
   old_peer:s.Peer_Id;hash:u64
   for receipt in rt.finals[:rt.final_count] {if receipt.player==value.id {old_peer=receipt.peer;hash=receipt.token_hash}}
   runtime_log(rt,"{\"event\":\"PLAYER_LEFT\",\"framework\":\"kit\",\"epoch\":%d,\"player\":%d,\"peer\":%d,\"token_hash\":%d,\"head\":%d,\"confirmed\":%d,\"reason\":%d}\n",k.lane_world_epoch(&rt.lane),value.id,old_peer,hash,rt.lane.ticker.tick,k.lane_world_confirmed(&rt.lane),value.reason)
  }
 case s.Ev_Player_Joined:
  if !rt.ses.is_host || !rt.started {return}
  player,ok:=s.session_player(&rt.ses,value.id);if !ok {rt.failed=true;return}
  if player.spectator {return}
  hash:u64;for token_hash,id in rt.ses.tokens {if id==value.id {hash=token_hash;break}}
  for &receipt in rt.finals[:rt.final_count] {if receipt.player==value.id {
   if !value.rejoin || hash==0 || hash!=receipt.token_hash || player.peer==receipt.peer || receipt.pending_rejoin {rt.failed=true;rt.error=.Incompatible;return}
   receipt.pending_rejoin=true;receipt.pending_peer=player.peer
   runtime_log(rt,"{\"event\":\"REJOIN_ADMITTED\",\"framework\":\"kit\",\"epoch\":%d,\"player\":%d,\"old_peer\":%d,\"peer\":%d,\"token_hash\":%d,\"head\":%d,\"confirmed\":%d,\"same_identity\":true}\n",k.lane_world_epoch(&rt.lane),value.id,receipt.peer,player.peer,hash,rt.lane.ticker.tick,k.lane_world_confirmed(&rt.lane))
   return
  }}
  // A new logical driver requires a new immutable game/input contract.
  runtime_log(rt,"{\"event\":\"ERROR\",\"framework\":\"kit\",\"where\":\"new_driver_after_go\",\"player\":%d}\n",value.id);rt.failed=true;rt.error=.Unsupported
 }
}
runtime_frame :: proc(rt:^Runtime,delta:f64) {
 context.allocator=rt.allocator
 account_handled:=false;reset_this_frame:=false
 defer {
  if caller_client(rt)&&!account_handled {
   why:Caller_Disposition=.Start
   if rt.failed {why=.Failure}
   else if rt.target>0&&rt.lane.ticker.tick>=rt.target {why=.End}
   else if rt.started {why=.Hold}
   caller_lifecycle(rt,delta,why)
  }
 }
 if rt.failed {return}
 if caller_client(rt)&&(!caller_finite(delta)||delta<0){caller_error(rt,"invalid_delta");return}
 ng.transport_service(&rt.wire);ng.wire_pump(&rt.wire,n.now_s());_,_=s.session_tick(&rt.ses,delta,n.now_s())
 telemetry_pump(rt)
 if rt.model_ready && rt.ses.is_host {
  net:=rt.lane.world.network
  for packet in net.queue[:net.queue_count] {if packet.kind==k.SIM_WORLD_REQUEST {
   player,_:=s.session_player(&rt.ses,packet.from)
   runtime_log(rt,"{\"event\":\"RECOVERY_REQUEST_OBSERVED\",\"framework\":\"kit\",\"from\":%d,\"peer\":%d,\"head\":%d,\"sequence\":%d,\"queue_count\":%d}\n",packet.from,player.peer,rt.lane.ticker.tick,net.sequence,net.queue_count)
  }}
 }
 for {event,ok:=s.session_poll(&rt.ses);if !ok {break};runtime_session_event(rt,event)}
 if rt.failed {return}
 if ng.wire_status(&rt.wire).error!=.Ok {rt.error=.Step_Failed;rt.failed=true;return}
 if !rt.model_ready {if !model_create(rt) {return}}
 if rt.ses.is_host {log_ready(rt)}
 if !rt.ses.is_host && !rt.ready_sent {send_ready(rt)}
 if rt.ses.is_host {
  for peer,i in rt.ready_peers[:rt.ready_count] {
   if !rt.welcomed[i] {if k.lane_world_send_checkpoint(&rt.lane,peer,.Welcome)!=.Ok {rt.failed=true;return};rt.welcomed[i]=true}
  }
  if !rt.started && drivers_ready(rt,false) {
   freeze_final_cohort(rt);if rt.failed {return}
   rt.started=true;rt.start_after=n.now_s()+.08
   for peer in rt.ready_peers[:rt.ready_count] {send_go(rt,peer)}
   if gd.env_int("B3_WIRE_PROBE",0)!=0 {for sequence in 0..<16 {writer:=s.session_app_begin(&rt.ses,4);n.write_u8(writer,250);n.write_u32(writer,u32(sequence));s.session_app_flush(&rt.ses,s.BROADCAST_PEER,.Reliable)}}
   runtime_log(rt,"{\"event\":\"GO\",\"framework\":\"kit\",\"role\":\"%s\",\"ready_drivers\":2,\"ready_observers\":%d,\"head\":%d,\"confirmed\":%d}\n",role_name(rt.role),rt.expected_observers,rt.lane.ticker.tick,k.lane_world_confirmed(&rt.lane))
  }
  if !rt.started || n.now_s()<rt.start_after {return}
 }else {
  capture_ingress(rt)
  _=k.lane_frame(&rt.lane,0)
  reset_this_frame=observe_recovered(rt)
  if reset_this_frame&&caller_client(rt){caller_lifecycle(rt,delta,.Reset);account_handled=true}
  if rt.recovering {
   rt.recovery_pumps+=1
   if rt.recovery_pumps%30==1 {
    net:=rt.lane.world.network;wire:=ng.wire_status(&rt.wire)
    wait:=f64(0);if len(rt.wire.delayed)>0 {wait=rt.wire.delayed[0].due-n.now_s()}
    runtime_log(rt,"{\"event\":\"RECOVERY_WIRE\",\"framework\":\"kit\",\"packets\":%d,\"bytes\":%d,\"first_due_in\":%f,\"latency\":%f,\"bandwidth\":%d}\n",wire.queued_packets,wire.queued_bytes,wait,rt.wire.latency,rt.wire.bandwidth)
    runtime_log(rt,"{\"event\":\"RECOVERY_WAIT\",\"framework\":\"kit\",\"head\":%d,\"confirmed\":%d,\"world_status\":%d,\"net_status\":%d,\"ready\":%v,\"transfer_tick\":%d,\"transfer_mode\":%d,\"transfer_sequence\":%d,\"transfer_received\":%d,\"transfer_chunks\":%d,\"last_signature\":%d,\"rejected\":%d,\"queue_count\":%d,\"wire_status\":%d,\"joined\":%v,\"malformed\":%d}\n",rt.lane.ticker.tick,k.lane_world_confirmed(&rt.lane),k.lane_world_status(&rt.lane),net.status,net.ready,net.transfer_tick,net.transfer_mode,net.transfer_sequence,net.transfer_received,net.transfer_chunks,net.last_signature.tick,net.rejected,net.queue_count,wire.error,rt.ses.joined,rt.ses.malformed)
   }
  }
  if handle_hold(rt) {return}
  if !k.lane_world_network_status(&rt.lane).ready {return}
  if !rt.baseline_ready {
   if rt.rejoin.player!=0 && k.lane_world_epoch(&rt.lane)!=rt.rejoin.epoch {rt.failed=true;rt.error=.Incompatible;return}
   rt.baseline=rt.lane.ticker.tick
   if rt.end_tick==0 {rt.target=rt.requested_ticks==0?0:rt.requested_ticks+rt.baseline}
   else if rt.end_tick<rt.baseline+rt.requested_ticks {rt.failed=true;return}
   rt.last_logged=rt.baseline;rt.baseline_ready=true;log_ready(rt);send_welcome_ack(rt)
  }
 }
 log_ready(rt)
 if !rt.started {return}
 post_reset:=caller_client(rt)&&rt.reanchor_bootstrap!=0
 reanchor_protocol:k.World_Protocol_Status
 if post_reset {
  reanchor_protocol=k.lane_world_protocol_status(&rt.lane)
  waiting:=caller_boundary(rt)
  if !waiting.available||reanchor_protocol.bootstrap_sequence!=rt.reanchor_bootstrap {caller_error(rt,"reanchor_scope_unproven");return}
  if reanchor_protocol.error!=.Ok||reanchor_protocol.matched_signature_tick<=rt.reanchor_baseline||reanchor_protocol.accepted_through<reanchor_protocol.matched_signature_tick||reanchor_protocol.pending_signature_tick!=0||!waiting.ready||waiting.resync||caller_ingress_pending(waiting)||waiting.busy||waiting.presenting||waiting.publishing||waiting.commands!=0 {
   confirmed_events(rt);return
  }
 }
 intent_prepare(rt)
 if rt.failed {return}
 if !rt.ses.is_host && !rt.lead_applied {
  before_lead:Caller_Boundary;lead_room,lead_end:u64
  if post_reset {
   before_lead=caller_boundary(rt)
   if !before_lead.available||!caller_domain(before_lead.dt,before_lead.scale)||!caller_finite(before_lead.acc)||before_lead.acc<0||before_lead.head<before_lead.confirmed {caller_error(rt,"reanchor_boundary_unproven");return}
   lead_room=8-min(u64(8),before_lead.head-before_lead.confirmed)
   lead_end=rt.target-min(rt.target,before_lead.head)
   limit:=lead_room;if rt.target>0 {limit=min(limit,lead_end)}
   if caller_ingress_pending(before_lead)||before_lead.busy||before_lead.presenting||before_lead.publishing||before_lead.commands!=0||!before_lead.ready||before_lead.resync||before_lead.acc+(4.0/60)*before_lead.scale>f64(limit)*before_lead.dt {caller_error(rt,"reanchor_room_or_end_unproven");return}
  }else{rt.lead_applied=true}
  lead_returned:=k.lane_frame(&rt.lane,4.0/60)
  if post_reset {
   after_lead:=caller_boundary(rt);receipt,q:=caller_credit_receipt(before_lead,after_lead,lead_returned,4.0/60)
   if receipt==.OwnedAll {rt.lead_applied=true}
   if receipt==.NotOwned {confirmed_events(rt);return}
   progress:=receipt==.OwnedAll&&lead_returned>0&&u64(lead_returned)<=lead_room&&(rt.target==0||u64(lead_returned)<=lead_end)&&after_lead.ready&&!after_lead.resync&&after_lead.status==.Ok&&!rt.failed
   runtime_log(rt,"{\"event\":\"STATUS\",\"framework\":\"kit\",\"stage\":\"recovery_bootstrap\",\"anchor_baseline\":%d,\"bootstrap_sequence\":%d,\"matched_signature_tick\":%d,\"accepted_through\":%d,\"before_head\":%d,\"before_confirmed\":%d,\"after_head\":%d,\"after_confirmed\":%d,\"room\":%d,\"end_ticks\":%d,\"supplied_bits\":\"%x\",\"receipt_bits\":\"%x\",\"returned_steps\":%d,\"receipt\":%d,\"owned_once\":%v,\"progress_proven\":%v}\n",rt.reanchor_baseline,rt.reanchor_bootstrap,reanchor_protocol.matched_signature_tick,reanchor_protocol.accepted_through,before_lead.head,before_lead.confirmed,after_lead.head,after_lead.confirmed,lead_room,lead_end,transmute(u64)f64(4.0/60),transmute(u64)q,lead_returned,receipt,rt.lead_applied,progress)
   if !progress {caller_error(rt,"reanchor_receipt_or_progress_unproven");return}
   rt.reanchor_baseline=0;rt.reanchor_bootstrap=0
  }
  intent_published(rt)
 }
 confirmed:=u64(0)
 if !rt.ses.is_host {confirmed=k.lane_world_confirmed(&rt.lane)}
 if caller_client(rt)&&confirmed>rt.lane.ticker.tick {caller_error(rt,"invalid_head_confirmed");return}
 dt:=caller_delta_plan(delta,rt.target,rt.lane.ticker.tick,confirmed,!rt.ses.is_host).offered_delta
 boundary:Caller_Boundary;account:Caller_Account
 settlement_end_ticks:u64;settlement_end_limited:bool
 if caller_client(rt) {
  if reset_this_frame {dt=0}
  else {
   boundary=caller_boundary(rt)
   eligible:=caller_eligible_delta(delta,rt.target,rt.lane.ticker.tick,boundary.dt,boundary.scale,boundary.acc)
   room:=u64(8)-min(u64(8),rt.lane.ticker.tick-confirmed)
   remaining:=rt.target-min(rt.target,rt.lane.ticker.tick)
   settlement_end_ticks=remaining;settlement_end_limited=rt.target>0
   account=caller_credit_offer(rt.caller_credit,eligible,boundary.dt,boundary.scale,room,remaining,rt.target>0,caller_ingress_pending(boundary),boundary.acc)
   account.raw_excess=delta-eligible
   if !boundary.available||!account.valid {caller_store(rt,account);account_handled=true;caller_error(rt,"offer_invariant");return}
   dt=account.offered
  }
 }
 rt.diagnostic_dt=dt
 returned:=k.lane_frame(&rt.lane,dt)
 if caller_client(rt)&&!reset_this_frame {
  after:=caller_boundary(rt);receipt:Caller_Receipt;q:f64;settled:Caller_Account
  receipt,q=caller_credit_receipt(boundary,after,returned,dt);settled=caller_credit_settle(account,receipt,q,boundary.dt,boundary.scale,settlement_end_ticks,settlement_end_limited,boundary.acc)
  caller_store(rt,settled);account_handled=true
  if !settled.valid||receipt==.Unresolved {caller_error(rt,"unresolved_normal_boundary");return}
 }
 intent_published(rt)
 if handle_hold(rt) {return}
 confirmed_events(rt)
 if rt.target>0 && k.lane_world_confirmed(&rt.lane)>=rt.target {
  if rt.last_written!=rt.target {write_frame(rt,rt.target)}
  if !rt.tail_logged {
   rt.tail_logged=true
   if rt.ses.is_host {signature,se:=k.lane_world_confirmed_signature(&rt.lane,rt.target);if se==.Ok {for &receipt in rt.finals[:rt.final_count] {if receipt.player==rt.ses.me && receipt.epoch==signature.epoch && receipt.target==signature.tick {receipt.received=true;receipt.signature=signature}}}}
   runtime_log(rt,"{\"event\":\"TAIL\",\"framework\":\"kit\",\"role\":\"%s\",\"stage\":\"final_received\",\"tick\":%d,\"head\":%d,\"confirmed\":%d,\"matched\":true}\n",role_name(rt.role),rt.target,rt.lane.ticker.tick,k.lane_world_confirmed(&rt.lane))
  }
  if !rt.ses.is_host {send_done(rt);if rt.finish_after==0 {rt.finish_after=n.now_s()+.25}}
  else if all_final_receipts(rt) && rt.finish_after==0 {rt.finish_after=n.now_s()+.6}
  if rt.finish_after>0 && n.now_s()>=rt.finish_after {rt.finished=true}
 }
}
runtime_destroy :: proc(rt:^Runtime,final:bool=true)->bool {
 if rt==nil {return true}
 context.allocator=rt.allocator
 if caller_client(rt){caller_lifecycle(rt,0,rt.failed?Caller_Disposition.Failure:Caller_Disposition.End)}
 confirmed_control_summary(rt) // CONTROL_EVIDENCE61_SUMMARY
 caller_final:=rt.caller_account
 sdk,alloc,bindings,wire_owner,output,sink,role:=rt.sdk,rt.allocator,rt.bindings,rt.wire_owner,rt.output,rt.sink,rt.role
 initial:=rt.initial
 tick:=rt.model_ready?k.lane_world_confirmed(&rt.lane):0;failed:=rt.failed;generation:=rt.generation
 if rt.initial==32 {telemetry_ledger(generation,role,"before_close")}
 errors:=0
 if rt.ses.is_host && gd.env_int("B3_WIRE_PROBE",0)!=0 {empty_send_probe(rt,"after")}
 if rt.raw_send!=nil {generation_log(generation,"{\"event\":\"CLOSE_TRACE\",\"stage\":\"wire_enter\"}\n")}
 if ng.wire_detach(&rt.wire)!=.Ok {errors+=1}
 if rt.raw_send!=nil {generation_log(generation,"{\"event\":\"CLOSE_TRACE\",\"stage\":\"wire_exit\"}\n")}
 if p.network_destroy(&rt.network)!=.Ok {errors+=1}
 if p.codec_destroy(&rt.controls)!=.Ok {errors+=1};if p.codec_destroy(&rt.action_codec)!=.Ok {errors+=1};if p.codec_destroy(&rt.proxy_codec)!=.Ok {errors+=1};if p.codec_destroy(&rt.event_codec)!=.Ok {errors+=1}
 if p.detach(&rt.physics)!=.Ok {errors+=1}
 k.lane_destroy(&rt.lane);s.session_destroy(&rt.ses)
 if sink!=nil {free(sink,alloc)};if output!="" {delete(output,alloc)}
 free(rt,alloc)
 for &binding in bindings {if p.sdk_user_owner_destroy(&binding)!=.Ok {errors+=1}}
 if wire_owner.user!=nil && wire_owner.drop(wire_owner.user)!=bg.OK {errors+=1}
 if p.sdk_context_destroy(&sdk)!=.Ok {errors+=1}
 if initial==32 {telemetry_ledger(generation,role,"after_cleanup")}
 engine,es:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats();meter,_:=bm.category_stats(bg.CATEGORY_KIT_CORE)
 clean:=errors==0 && es==.Ok && ws==.Ok && engine.live_bytes==0 && wrapper.live_bytes==0 && meter.live_bytes==0
 generation_log(generation,"{\"event\":\"%s\",\"framework\":\"kit\",\"role\":\"%s\",\"tick\":%d,\"ok\":%v,\"errors\":%d,\"engine_live\":%d,\"wrapper_live\":%d,\"meter_live\":%d,\"cleanup_errors\":%d,\"native_stats_ok\":%v,\"caller_disposition\":%d,\"caller_disposed_bits\":\"%x\"}\n",final?"RESULT":"SESSION_EXIT",role_name(role),tick,!failed&&clean,errors,engine.live_bytes,wrapper.live_bytes,meter.live_bytes,errors,es==.Ok&&ws==.Ok,caller_final.disposition,transmute(u64)caller_final.excluded)
 return clean
}

json_line :: proc(format:string,args:..any) {end:=len(format);if end>0 && format[end-1]=='\n' {end-=1};if end>=2 && format[0]=='{' && format[end-1]=='}' {fmt.print("{");fmt.printf(format[1:end-1],..args);fmt.print("}\n")}else{fmt.printf(format,..args)}}

runtime_log :: proc(rt:^Runtime,format:string,args:..any) {generation_log(rt.generation,format,..args)}
generation_log :: proc(generation:u32,format:string,args:..any) {end:=len(format);if end>0 && format[end-1]=='\n' {end-=1};fmt.print("{");fmt.printf("\"session_generation\":%d,",generation);fmt.printf(format[1:end-1],..args);fmt.print("}\n")}
