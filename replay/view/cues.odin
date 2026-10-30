package replay_view

import "core:math"
import "core:mem"
import r "godot:replay"

// Bounded, reversible visual instances. Values carry detached presentation data;
// neither the simulation nor an entity node is needed after an occurrence begins.
Cue :: struct($Value:typeid) {
 id:r.Event_Id,
 key:u64, // unique instance identity; never a hash of the event ID
 value:Value,
 age,seconds:f64,
 active,confirmed:bool,
}
Cue_Stats :: struct {begun,updated,confirmed,canceled,duplicates,dropped:u64}
Cues :: struct($Value:typeid) {
 ledger:One_Shots,
 slots:[]Cue(Value),
 serial:u64,
 stats:Cue_Stats,
}
cues_init :: proc(c:^Cues($T),epoch:u64,baseline:u64=0,capacity:int=128,history:int=512,per_tick:int=40,allocator:=context.allocator)->bool {
 if len(c.slots)!=0 || !r.value_supported(T) || capacity<1 || capacity>4096 {return false}
 if !one_shots_init(&c.ledger,epoch,baseline,history,per_tick,allocator) {return false}
 c.slots=make([]Cue(T),capacity,allocator)
 return true
}
cues_destroy :: proc(c:^Cues($T)) {delete(c.slots,c.ledger.allocator);one_shots_destroy(&c.ledger);c^={}}
// Clearing active visuals does not make already consumed occurrences new again.
cues_clear :: proc(c:^Cues($T)) {for &slot in c.slots {slot.active=false}}
cues_epoch :: proc(c:^Cues($T),epoch,baseline:u64)->bool {
 if !one_shots_reset(&c.ledger,epoch,baseline) {return false}
 cues_clear(c);return true
}
cues_advance :: proc(c:^Cues($T),dt:f64)->bool {
 if dt<0 || math.is_nan(dt) || math.is_inf(dt) {return false}
 for &slot in c.slots {if slot.active {
  slot.age=min(slot.age+dt,slot.seconds)
  if slot.age>=slot.seconds {slot.active=false}
 }}
 return true
}
// Returns true only when a new instance starts. Confirmation and updates never
// restart its lifetime. Canceled/expired/dropped IDs retain consumption tombstones.
cues_change :: proc(c:^Cues($T),change:Change(T),seconds:f64)->bool {
 id:=change.occurrence.id
 if len(c.slots)==0 || id.epoch!=c.ledger.epoch {return false}
 for &slot in c.slots {if slot.active && slot.id==id {
  switch change.kind {
  case .Cancel:slot.active=false;c.stats.canceled+=1
  case .Update:slot.value=change.occurrence.value;c.stats.updated+=1
  case .Confirm:if !slot.confirmed {slot.confirmed=true;c.stats.confirmed+=1}
  case .Begin:c.stats.duplicates+=1
  }
  return false
 }}
 if change.kind!=.Begin {return false}
 if seconds<=0 || math.is_nan(seconds) || math.is_inf(seconds) {return false}
 result:=one_shot_note(&c.ledger,id)
 if result==.Duplicate {c.stats.duplicates+=1;return false}
 if result!=.New {c.stats.dropped+=1;return false}
 if c.serial==max(u64) {c.stats.dropped+=1;return false}
 for &slot in c.slots {if !slot.active {
  c.serial+=1
  slot={id=id,key=c.serial,value=change.occurrence.value,seconds=seconds,active=true,confirmed=change.confirmed}
  c.stats.begun+=1;return true
 }}
 c.stats.dropped+=1;return false
}
