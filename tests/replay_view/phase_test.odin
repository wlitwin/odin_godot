package replay_view_test

import "core:testing"
import "core:reflect"
import v "godot:replay/view"

@(test)
render_phase_stays_bounded_and_does_not_wrap_during_prediction_stalls :: proc(t:^testing.T) {
 phase:v.Tick_Phase
 testing.expect(t,v.tick_phase(&phase,1,0,10,.2,.01,20))
 testing.expect_value(t,phase.fraction,f32(.2))
 testing.expect(t,v.tick_phase(&phase,1,0,10,.5,.015,20))
 testing.expect_value(t,phase.fraction,f32(.5))
 // Clock consumption without a committed tick must not pull the view backward.
 testing.expect(t,v.tick_phase(&phase,1,0,10,0,.05,20))
 testing.expect_value(t,phase.fraction,f32(1))
 testing.expect(t,v.tick_phase(&phase,1,0,10,0,1e200,20))
 testing.expect_value(t,phase.fraction,f32(1))
 testing.expect(t,v.tick_phase(&phase,1,0,11,.1,.01,20))
 testing.expect_value(t,phase.fraction,f32(.1))
 testing.expect(t,v.tick_phase(&phase,1,0,11,.9,.1,20,false))
 testing.expect_value(t,phase.fraction,f32(.1))
 testing.expect(t,v.tick_phase(&phase,1,1,8,0,0,20)) // explicit view reset
 testing.expect_value(t,phase.fraction,f32(0))
 testing.expect(t,v.tick_phase(&phase,2,0,6,0,0,20)) // recovered epoch
 testing.expect_value(t,phase.tick,u64(6))
}

@(test)
phase_validation_is_atomic_and_linear_preview_never_passes_its_contact_bound :: proc(t:^testing.T) {
 phase:v.Tick_Phase;assert(v.tick_phase(&phase,2,4,10,.5,0,20));before:=phase
 testing.expect(t,!v.tick_phase(&phase,1,4,10,.5,0,20))
 testing.expect(t,!v.tick_phase(&phase,2,4,9,.5,0,20))
 testing.expect(t,!v.tick_phase(&phase,2,4,10,.5,-1,20))
 testing.expect(t,!v.tick_phase(&phase,2,4,10,transmute(f32)u32(0x7fc00000),0,20))
 testing.expect(t,!v.tick_phase(&phase,2,4,10,.5,0,60))
 testing.expect(t,reflect.equal(phase,before))
 position,ok:=v.linear_preview2({100,100},{12,0},.5)
 testing.expect(t,ok && position==([2]f32{106,100}))
 position,ok=v.linear_preview2({100,100},{12,0},5,.25)
 testing.expect(t,ok && position==([2]f32{103,100}))
 position,ok=v.linear_preview2({100,100},{12,0},.5,-1)
 testing.expect(t,ok && position==([2]f32{100,100}))
 position,ok=v.linear_preview2({100,100},{transmute(f32)u32(0x7f800000),0},.5)
 testing.expect(t,!ok && position==([2]f32{100,100}))
}
