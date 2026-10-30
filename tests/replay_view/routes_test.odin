package replay_view_test
import "core:testing"
import r "godot:replay"
import v "godot:replay/view"
@(test)
confirmed_routes_delay_begin_and_never_restart_expired_or_canceled_effects :: proc(t:^testing.T) {
    route:v.Cue_Route(i32,i32)
    assert(v.cue_route_init(&route,1,.5,proc(event:i32)->(i32,bool){return event,event>0},.Confirmed,capacity=1,history=8));defer v.cue_route_destroy(&route)
    change:=v.Change(i32){kind=.Begin,occurrence=r.Occurrence(i32){id={1,1,1,1},value=7}}
    testing.expect(t,!v.cue_route_change(&route,change))
    change.kind=.Confirm;testing.expect(t,v.cue_route_change(&route,change))
    key:=route.cues.slots[0].key;v.cues_advance(&route.cues,.2)
    testing.expect(t,!v.cue_route_change(&route,change) && route.cues.slots[0].age==.2 && route.cues.slots[0].key==key)
    change.kind=.Update;change.confirmed=true;change.occurrence.value=9;v.cue_route_change(&route,change)
    testing.expect_value(t,route.cues.slots[0].value,i32(9))
    v.cues_advance(&route.cues,1);change.kind=.Confirm
    testing.expect(t,!v.cue_route_change(&route,change) && !route.cues.slots[0].active)
    change.occurrence.id.tick=2;testing.expect(t,v.cue_route_change(&route,change))
    change.kind=.Cancel;v.cue_route_change(&route,change)
    change.kind=.Confirm;testing.expect(t,!v.cue_route_change(&route,change))
}
