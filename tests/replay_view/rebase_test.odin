package replay_view_test

import "core:testing"
import "core:reflect"
import "core:mem"
import r "godot:replay"
import v "godot:replay/view"

@(test)
checkpoint_rebase_preserves_queued_output_matures_known_effects_and_cancels_prediction :: proc(t:^testing.T) {
 j:v.Journal(Event);v.journal_init(&j,cfg={4,3,16});defer v.journal_destroy(&j);v.journal_set_policy(&j,policy)
 events:=[2]r.Occurrence(Event){occ(1,1,.Confirmed),occ(1,2,.Watched)}
 testing.expect_value(t,v.sync_tick(&j,1,events[:]),v.Error.None)
 testing.expect_value(t,v.advance_time(&j,1,0),v.Error.None)
 future:=[2]r.Occurrence(Event){occ(3,3,.Speculative),occ(3,4,.Confirmed)}
 testing.expect_value(t,v.sync_tick(&j,3,future[:]),v.Error.None)
 testing.expect_value(t,j.queue_count,2)
 testing.expect_value(t,v.journal_rebase(&j,100),v.Error.None)
 testing.expect(t,j.epoch==1 && j.baseline==100 && j.confirmed==100 && j.watch_tick==100)
 out:[8]v.Change(Event);testing.expect_value(t,v.drain(&j,out[:]),4)
 testing.expect(t,out[0].kind==.Begin && out[0].confirmed && out[0].occurrence.id.key==1)
 testing.expect(t,out[1].kind==.Begin && !out[1].confirmed && out[1].occurrence.id.key==3)
 testing.expect(t,out[2].kind==.Begin && out[2].confirmed && out[2].occurrence.id.key==2)
 testing.expect(t,out[3].kind==.Cancel && !out[3].confirmed && out[3].occurrence.id.key==3)
 for b in j.batches {testing.expect(t,!b.valid && b.count==0)}
 // No event in the unknown gap is manufactured; already final effects don't
 // restart on another checkpoint. Future authority events can begin normally.
 testing.expect_value(t,v.journal_rebase(&j,120),v.Error.None);testing.expect_value(t,v.drain(&j,out[:]),0)
 fresh:=[1]r.Occurrence(Event){occ(121,5,.Watched)}
 testing.expect_value(t,v.sync_tick(&j,121,fresh[:]),v.Error.None)
 testing.expect_value(t,v.advance_time(&j,121,121),v.Error.None)
 testing.expect_value(t,v.drain(&j,out[:]),1);testing.expect_value(t,out[0].occurrence.id.key,u64(5))
}

@(test)
checkpoint_rebase_backpressure_is_atomic_and_retryable :: proc(t:^testing.T) {
 j:v.Journal(Event);v.journal_init(&j,cfg={4,1,2});defer v.journal_destroy(&j);v.journal_set_policy(&j,policy)
 for tick in u64(1)..=2 {
  event:=[1]r.Occurrence(Event){occ(tick,tick,.Confirmed)}
  testing.expect_value(t,v.sync_tick(&j,tick,event[:]),v.Error.None)
  testing.expect_value(t,v.advance_time(&j,tick,tick-1),v.Error.None)
 }
 prediction:=[1]r.Occurrence(Event){occ(3,3,.Speculative)}
 out:[1]v.Change(Event);testing.expect_value(t,v.drain(&j,out[:]),1)
 testing.expect_value(t,v.sync_tick(&j,3,prediction[:]),v.Error.None)
 storage:=make([]u8,len(j.storage)*size_of(j.storage[0]));defer delete(storage)
 copy(storage,mem.slice_to_bytes(j.storage))
 testing.expect_value(t,v.journal_rebase_check(&j,10),v.Error.Output_Full)
 testing.expect_value(t,v.journal_rebase(&j,10),v.Error.Output_Full)
 testing.expect(t,j.baseline==0 && j.confirmed==2 && j.watch_tick==1 && j.queue_count==2)
 testing.expect(t,reflect.equal(storage,mem.slice_to_bytes(j.storage),true))
 testing.expect_value(t,v.drain(&j,out[:]),1)
 testing.expect_value(t,v.journal_rebase(&j,10),v.Error.None)
 testing.expect_value(t,v.drain(&j,out[:]),1);testing.expect_value(t,out[0].kind,v.Change_Kind.Begin)
 testing.expect_value(t,v.drain(&j,out[:]),1);testing.expect_value(t,out[0].kind,v.Change_Kind.Cancel)
 testing.expect_value(t,v.journal_rebase(&j,9),v.Error.Time_Reversed)
 testing.expect_value(t,j.baseline,u64(10))
}

@(test)
checkpoint_rebase_handles_wrapped_and_sparse_future_ticks :: proc(t:^testing.T) {
 j:v.Journal(Event);v.journal_init(&j,cfg={4,1,16});defer v.journal_destroy(&j);v.journal_set_policy(&j,policy)
 out:[16]v.Change(Event)
 for tick in u64(1)..=7 {
  event:=[1]r.Occurrence(Event){occ(tick,tick,.Watched)}
  testing.expect_value(t,v.sync_tick(&j,tick,event[:]),v.Error.None)
  testing.expect_value(t,v.advance_time(&j,tick,tick>2 ? tick-2 : 0),v.Error.None)
  v.drain(&j,out[:])
 }
 // Tick 9 replaces a confirmed, already-presented slot. Its speculative
 // occurrence must be cancelled even though older batches remain elsewhere.
 future:=[1]r.Occurrence(Event){occ(9,9,.Speculative)}
 testing.expect_value(t,v.sync_tick(&j,9,future[:]),v.Error.None)
 v.drain(&j,out[:])
 testing.expect_value(t,v.journal_rebase(&j,20),v.Error.None)
 testing.expect_value(t,v.drain(&j,out[:]),3)
 testing.expect(t,out[0].occurrence.id.tick==6 && out[1].occurrence.id.tick==7 && out[2].occurrence.id.tick==9 && out[2].kind==.Cancel)
 for b in j.batches {testing.expect(t,!b.valid)}
}
