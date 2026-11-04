package caller_capacity_retention_test

// PURE prospective example-caller requirement, using actual imported helpers.
// OwnedAll is test metadata, not a live Lane receipt or a Kernel guarantee.
import "core:encoding/json"
import "core:os"
import "core:testing"
import app "godot:examples/kit_box3d/scripts"

DT :: f64(1.0/60)
Observation :: struct {
 scope,stage:string,setup_complete,combined_prospective_criterion:bool,
 offered_valid,settled_valid,conservation_valid,exact_offered_debit:bool,
 before_bits,eligible_bits,offered_bits,owned_bits,pending_bits,unresolved_bits,excluded_bits,capacity_excluded_bits,end_excluded_bits,scaled_receipt_bits,expected_pending_bits:u64,
 room,end_ticks:u64,end_limited:bool,receipt:app.Caller_Receipt,
}
save :: proc(o:Observation) {
 bytes,error:=json.marshal(o);assert(error==nil);defer delete(bytes)
 assert(os.write_entire_file("retention-observation.json",bytes)==nil)
}

@(test)
recorded_owned_current_capacity_should_remain_pending :: proc(t:^testing.T) {
 o:=Observation{scope="PURE_actual_default_caller_helpers_synthetic_OwnedAll_NO_Runtime_Lane_World_Native_or_historical_cause",stage="actual_offer",room=3,end_ticks=130,end_limited=true,expected_pending_bits=transmute(u64)f64(6.5*DT)}
 defer {save(o)}
 offered:=app.caller_credit_offer({pending_seconds=8*DT},DT/2,DT,1,o.room,o.end_ticks,o.end_limited,false)
 o.offered_valid=offered.valid
 testing.expect(t,o.offered_valid&&offered.offered==2*DT&&offered.pending==6*DT&&offered.capacity_excluded>0,"actual recorded offer is valid, clipped, and offers exactly2dt")
 if !o.offered_valid||offered.offered!=2*DT||offered.pending!=6*DT||offered.capacity_excluded<=0{return}
 o.stage="actual_settlement"
 settled:=app.caller_credit_settle(offered,.OwnedAll,offered.offered,DT,1)
 o.receipt=settled.receipt;o.settled_valid=settled.valid;o.conservation_valid=app.caller_account_valid(settled,DT,1)
 o.exact_offered_debit=transmute(u64)settled.lane_owned==transmute(u64)offered.offered
 o.before_bits=transmute(u64)settled.before;o.eligible_bits=transmute(u64)settled.eligible;o.offered_bits=transmute(u64)settled.offered
 o.owned_bits=transmute(u64)settled.lane_owned;o.pending_bits=transmute(u64)settled.pending;o.unresolved_bits=transmute(u64)settled.unresolved
 o.excluded_bits=transmute(u64)settled.excluded;o.capacity_excluded_bits=transmute(u64)settled.capacity_excluded;o.end_excluded_bits=transmute(u64)settled.end_excluded;o.scaled_receipt_bits=transmute(u64)settled.scaled_receipt
 testing.expect(t,o.settled_valid&&o.conservation_valid&&o.exact_offered_debit&&settled.receipt==.OwnedAll&&settled.unresolved==0&&settled.end_excluded==0,"actual helper validity/conservation/exact debit remain true")
 if !o.settled_valid||!o.conservation_valid||!o.exact_offered_debit||settled.receipt!=.OwnedAll||settled.unresolved!=0||settled.end_excluded!=0{return}
 o.setup_complete=true;o.stage="ONE_PROSPECTIVE_CURRENT_CAPACITY_RETENTION_CRITERION"
 o.combined_prospective_criterion=settled.pending==6.5*DT&&settled.excluded==0
 testing.expect(t,o.combined_prospective_criterion,"EXPECTED prospective RED: retain this OwnedAll call's current capacity portion in pending6.5dt with zero net exclusion; not a Kernel or historical-cause claim")
}
