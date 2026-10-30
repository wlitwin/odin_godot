package replay_view

import "core:math"
import r "godot:replay"

Route_Policy :: enum {Journal,Confirmed}
Cue_Route :: struct($Event,$Value:typeid) {
    cues:Cues(Value),
    project:proc(Event)->(Value,bool),
    seconds:f64,
    policy:Route_Policy,
}
cue_route_init :: proc(route:^Cue_Route($Event,$Value),epoch:u64,seconds:f64,project:proc(Event)->(Value,bool),
                       policy:Route_Policy=.Journal,baseline:u64=0,capacity:int=128,history:int=512,per_tick:int=40,
                       allocator:=context.allocator)->bool {
    if project==nil || !r.value_supported(Event) || policy>.Confirmed || seconds<=0 || math.is_nan(seconds) || math.is_inf(seconds) {return false}
    if !cues_init(&route.cues,epoch,baseline,capacity,history,per_tick,allocator) {return false}
    route.project,route.seconds,route.policy=project,seconds,policy;return true
}
cue_route_destroy :: proc(route:^Cue_Route($Event,$Value)) {cues_destroy(&route.cues);route^={}}
// Journal already decides speculative/watched delivery. Confirmed optionally
// delays this particular route. Selection should use stable event kind; an
// Update cannot manufacture a new speculative effect that had no Begin.
cue_route_change :: proc(route:^Cue_Route($Event,$Value),change:Change(Event))->bool {
    if route.project==nil {return false}
    mapped:=Change(Value){kind=change.kind,occurrence={id=change.occurrence.id},confirmed=change.confirmed}
    if change.kind==.Cancel {return cues_change(&route.cues,mapped,route.seconds)}
    if route.policy==.Confirmed && !change.confirmed && change.kind!=.Confirm {return false}
    value,include:=route.project(change.occurrence.value)
    if !include {
        mapped.kind=.Cancel;return cues_change(&route.cues,mapped,route.seconds)
    }
    mapped.occurrence.value=value
    if route.policy==.Confirmed && change.kind==.Confirm {
        active:=false
        for slot in route.cues.slots {if slot.active && slot.id==change.occurrence.id {active=true;break}}
        if !active {mapped.kind=.Begin;mapped.confirmed=true}
    }
    return cues_change(&route.cues,mapped,route.seconds)
}
