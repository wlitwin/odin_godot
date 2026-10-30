package replay_view

import "core:reflect"
import r "godot:replay"

Scope_Observation :: struct {epoch,reset,tick:u64}
Scope_Error :: enum {None,Invalid,Stale,Exhausted}
// Caller chooses what identifies a world/view lifetime; no game field or
// authority policy is inferred. A stable tick or ordinary forward correction
// does not reset views. Tick rewind is an explicit caller option.
Scope_Tracker :: struct($Key:typeid) {observation:Scope_Observation,key:Key,revision:u64,ready:bool}
scope_update :: proc(tracker:^Scope_Tracker($Key),observation:Scope_Observation,key:Key,rewind_resets:bool)->(View_Scope,Scope_Error) {
    if observation.epoch==0 || !r.value_supported(Key) {return {},.Invalid}
    if tracker.ready && observation.epoch<tracker.observation.epoch {return {},.Stale}
    changed:=!tracker.ready || observation.epoch!=tracker.observation.epoch || observation.reset!=tracker.observation.reset ||
        !reflect.equal(key,tracker.key) || rewind_resets && observation.tick<tracker.observation.tick
    if changed && tracker.revision==max(u64) {return {},.Exhausted}
    if changed {tracker.revision+=1}
    tracker.observation,tracker.key,tracker.ready=observation,key,true
    return {observation.epoch,tracker.revision},.None
}
