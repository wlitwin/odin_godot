package caller_credit_test

// PURE synthetic records passed to the ACTUAL imported Example helpers.
// No Lane/world, Native simulation, Runtime frame, publication or live receipt
// is exercised. Runtime below is zero metadata only for caller_store tests.
import "core:encoding/json"
import "core:os"
import "core:testing"
import app "godot:examples/kit_box3d/scripts"
import old "godot:tests/box3d_soak/kit/input_admission/caller_delta"
import legacy "godot:tests/box3d_slices/kit/intents"

DT :: f64(1.0/60)
boundary :: proc()->app.Caller_Boundary{return {available=true,ready=true,head=10,confirmed=10,epoch=1,received_sequence=3,dt=DT,scale=1,status=.Ok}}
balance :: proc(t:^testing.T,a:app.Caller_Account){testing.expect(t,a.valid);testing.expect(t,app.caller_account_valid(a,DT,1));testing.expect(t,abs(a.before+a.eligible-a.lane_owned-a.pending-a.unresolved-a.excluded)<=app.CALLER_RECEIPT_EPS)}

@(test)
room_zero_represents_the_prior_RED_and_preserves_tiny_credit :: proc(t:^testing.T){
 old_plan:=app.caller_delta_plan(DT,0,8,0,true)
 testing.expect(t,old_plan.offered_delta==0&&old_plan.disposition==.Unaccounted)
 a:=app.caller_credit_offer({},old_plan.eligible_delta,DT,1,0,0,false,false)
 balance(t,a);testing.expect(t,a.offered==0&&a.pending==DT&&a.excluded==0)
 tiny:=app.CALLER_RECEIPT_EPS/10
 b:=app.caller_credit_offer({},tiny,DT,1,0,0,false,false)
 balance(t,b);testing.expect(t,b.pending==tiny&&b.pending>0)
}

@(test)
zero_step_and_normal_step_acquire_exact_offer :: proc(t:^testing.T){
 for offered in ([]f64{0,DT/2,DT,2*DT}) {
  a:=app.caller_credit_offer({},offered,DT,1,8,0,false,false)
  before:=boundary();after:=before
  steps:=int(offered/DT);after.head+=u64(steps);after.acc=offered-f64(steps)*DT
  receipt,q:=app.caller_credit_receipt(before,after,steps,a.offered)
  testing.expect(t,receipt==(offered==0?app.Caller_Receipt.No_Offer:app.Caller_Receipt.OwnedAll))
  settled:=app.caller_credit_settle(a,receipt,q,DT,1)
  balance(t,settled);testing.expect(t,settled.lane_owned==offered&&settled.pending==0&&settled.unresolved==0)
 }
}

@(test)
first_failure_retains_and_partial_success_owns_all :: proc(t:^testing.T){
 a:=app.caller_credit_offer({},2*DT,DT,1,8,0,false,false)
 before:=boundary();after:=before;after.status=.History_Missing
 receipt,q:=app.caller_credit_receipt(before,after,0,a.offered)
 testing.expect(t,receipt==.NotOwned)
 retained:=app.caller_credit_settle(a,receipt,q,DT,1)
 balance(t,retained);testing.expect(t,retained.pending==2*DT&&retained.lane_owned==0)
 after.head+=1;after.acc=DT
 receipt,q=app.caller_credit_receipt(before,after,1,a.offered)
 testing.expect(t,receipt==.OwnedAll)
 owned:=app.caller_credit_settle(a,receipt,q,DT,1)
 balance(t,owned);testing.expect(t,owned.lane_owned==2*DT&&owned.pending==0)
 before.busy=true;after=before;after.busy=false
 receipt,_=app.caller_credit_receipt(before,after,0,DT)
 testing.expect(t,receipt==.NotOwned)
}

@(test)
queued_ingress_defers_without_charging_old_lane_accumulator :: proc(t:^testing.T){
 before:=boundary();before.queue_count=1
 a:=app.caller_credit_offer({pending_seconds=DT},DT,DT,1,8,0,false,app.caller_ingress_pending(before))
 testing.expect(t,a.offered==0&&a.pending==2*DT&&a.disposition==.Deferred)
 after:=before;after.queue_count=0;after.head+=2
 receipt,q:=app.caller_credit_receipt(before,after,2,0)
 testing.expect(t,receipt==.No_Offer)
 settled:=app.caller_credit_settle(a,receipt,q,DT,1)
 balance(t,settled);testing.expect(t,settled.lane_owned==0&&settled.pending==2*DT)
 for mode in 0..<5 {x:=boundary();switch mode {case 0:x.queue_count=1;case 1:x.queue_bytes=1;case 2:x.completed_count=1;case 3:x.applying=true;case 4:x.applying_bytes=1};testing.expect(t,app.caller_ingress_pending(x))}
}

@(test)
inert_partial_is_certified_but_changed_markers_quarantine :: proc(t:^testing.T){
 before:=boundary();before.transfer_sequence=4;before.transfer_epoch=1;before.transfer_tick=12;before.transfer_chunks=3;before.transfer_received=1;before.transfer_bytes=100;before.transfer_seen[0]=true
 after:=before;after.head+=1
 receipt,_:=app.caller_credit_receipt(before,after,1,DT)
 testing.expect(t,receipt==.OwnedAll)
 for mode in 0..<8 {
  changed:=after
  switch mode {case 0:changed.transfer_sequence+=1;case 1:changed.transfer_epoch+=1;case 2:changed.transfer_tick+=1;case 3:changed.transfer_chunks+=1;case 4:changed.transfer_received+=1;case 5:changed.transfer_bytes+=1;case 6:changed.transfer_seen[1]=true;case 7:changed.received_sequence+=1}
  receipt,_=app.caller_credit_receipt(before,changed,1,DT)
  testing.expect(t,receipt==.Unresolved)
 }
 a:=app.caller_credit_offer({},DT,DT,1,8,0,false,false)
 quarantined:=app.caller_credit_settle(a,.Unresolved,0,DT,1)
 balance(t,quarantined);testing.expect(t,quarantined.unresolved==DT&&quarantined.lane_owned==0)
 frozen:=app.caller_credit_offer({pending_seconds=quarantined.pending,unresolved_offer_seconds=quarantined.unresolved},DT,DT,1,8,0,false,false)
 balance(t,frozen);testing.expect(t,frozen.offered==0&&frozen.unresolved==DT&&frozen.excluded==DT&&frozen.disposition==.Hold)
}

@(test)
after_flags_commands_rates_and_head_changes_are_not_receipts :: proc(t:^testing.T){
 before:=boundary();normal:=before;normal.head+=1
 for mode in 0..<12 {
  after:=normal
  switch mode {case 0:after.busy=true;case 1:after.presenting=true;case 2:after.publishing=true;case 3:after.commands=1;case 4:after.dt=DT/2;case 5:after.scale=2;case 6:after.epoch+=1;case 7:after.received_sequence+=1;case 8:after.confirmed+=1;case 9:after.head+=1;case 10:after.available=false;case 11:after.completed_count=1}
  receipt,_:=app.caller_credit_receipt(before,after,1,DT)
  testing.expect(t,receipt==.Unresolved)
 }
}

@(test)
capacity_target_and_per_call_limits_are_explicit :: proc(t:^testing.T){
 a:=app.caller_credit_offer({pending_seconds=8*DT},DT,DT,1,0,0,false,false)
 balance(t,a);testing.expect(t,a.pending==8*DT&&abs(a.capacity_excluded-DT)<app.CALLER_RECEIPT_EPS&&a.excluded==a.capacity_excluded)
 b:=app.caller_credit_offer({pending_seconds=4*DT},DT,DT,1,8,1,true,false)
 testing.expect(t,b.offered==DT&&b.pending==0&&abs(b.end_excluded-4*DT)<app.CALLER_RECEIPT_EPS)
 settled:=app.caller_credit_settle(b,.OwnedAll,DT,DT,1);balance(t,settled)
 c:=app.caller_credit_offer({pending_seconds=7*DT},DT,DT,1,8,0,false,false)
 testing.expect(t,c.offered==2*DT&&c.pending==6*DT)
 for room in 0..=2 {d:=app.caller_credit_offer({pending_seconds=2*DT},0,DT,1,u64(room),0,false,false);testing.expect(t,d.offered==f64(room)*DT)}
}

@(test)
lifecycle_hold_reset_start_end_failure_balance :: proc(t:^testing.T){
 credit:=app.Caller_Credit{pending_seconds=2*DT,unresolved_offer_seconds=DT}
 hold:=app.caller_credit_lifecycle(credit,DT,DT,1,.Hold)
 balance(t,hold);testing.expect(t,hold.pending==credit.pending_seconds&&hold.unresolved==credit.unresolved_offer_seconds&&hold.excluded==DT)
 for why in ([]app.Caller_Disposition{.Start,.Reset,.End,.Failure}) {
  a:=app.caller_credit_lifecycle(credit,DT,DT,1,why)
  balance(t,a);testing.expect(t,a.pending==0&&a.unresolved==0&&a.excluded==4*DT&&a.disposition==why)
 }
 // These synthetic records do NOT claim a live validated Reset/signature.
}

@(test)
invalid_offer_settle_lifecycle_preserve_actual_stored_credit :: proc(t:^testing.T){
 credit:=app.Caller_Credit{pending_seconds=2*DT,unresolved_offer_seconds=DT}
 rt:app.Runtime;rt.caller_credit=credit
 for mode in 0..<3 {
  bad:app.Caller_Account
  switch mode {
  case 0:bad=app.caller_credit_offer(credit,DT,DT,2,8,0,false,false)
  case 1:bad=app.caller_credit_lifecycle(credit,DT,DT/2,1,.End)
  case 2:a:=app.caller_credit_offer({},DT,DT,1,8,0,false,false);bad=app.caller_credit_settle(a,.OwnedAll,DT,DT,2)
  }
  testing.expect(t,!bad.valid)
  app.caller_store(&rt,bad)
  testing.expect(t,rt.caller_credit==credit&&rt.caller_account.disposition==.Invalid&&!rt.caller_account.valid)
  testing.expect(t,rt.caller_account.pending==credit.pending_seconds&&rt.caller_account.unresolved==credit.unresolved_offer_seconds)
 }
 disposed:=app.caller_credit_lifecycle(credit,0,DT,1,.Failure);balance(t,disposed)
 app.caller_store(&rt,disposed);testing.expect(t,rt.caller_credit.pending_seconds==0&&rt.caller_credit.unresolved_offer_seconds==0&&rt.caller_account.excluded==3*DT)
}

@(test)
fixed_example_domain_and_role_bypass :: proc(t:^testing.T){
 testing.expect(t,app.caller_domain(DT,1))
 for rate in ([][2]f64{{DT/2,1},{DT,2},{0,1},{DT,0}}) {
  a:=app.caller_credit_offer({},DT,rate[0],rate[1],8,0,false,false)
  testing.expect(t,!a.valid&&a.disposition==.Invalid&&a.offered==0)
 }
 rt:app.Runtime
 for role in ([]app.Role{.Host,.Dedicated,.Observer}) {rt.role=role;testing.expect(t,!app.caller_client(&rt))}
 rt.role=.Client;testing.expect(t,app.caller_client(&rt));rt.ses.is_host=true;testing.expect(t,!app.caller_client(&rt))
}

@(test)
frozen_eligibility_differential_once :: proc(t:^testing.T){old.actual_helper_matches_frozen_original_finite_arithmetic(t)}
@(test) legacy_prefetch_abort :: proc(t:^testing.T){legacy.prefetch_never_emits_early_and_abort_keeps_same_attempt(t)}
@(test) legacy_reset_links :: proc(t:^testing.T){legacy.two_unsampled_reset_links_keep_original_due(t)}
@(test) legacy_published_identity :: proc(t:^testing.T){legacy.published_sample_without_packet_is_not_retargeted(t)}
@(test) legacy_end_failure :: proc(t:^testing.T){legacy.no_tick_after_end_is_explicit_failure(t)}
@(test) legacy_fresh_catalog :: proc(t:^testing.T){legacy.fresh_source_catalog_does_not_recreate_retired_scenario_inputs(t)}

@(test)
pure_layout_observation_not_actual_allocation :: proc(t:^testing.T){
 bytes,error:=json.marshal(struct{scope:string,runtime_size,credit_size,account_size,boundary_size:int}{"PURE sizeof only; actual constructor Meter STATUS/charged-growth proof remains separate",size_of(app.Runtime),size_of(app.Caller_Credit),size_of(app.Caller_Account),size_of(app.Caller_Boundary)})
 testing.expect(t,error==nil);if error!=nil{return};defer delete(bytes)
 testing.expect(t,os.write_entire_file("layout.json",bytes)==nil)
}
