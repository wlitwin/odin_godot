package replay_test

import "core:testing"
import r "godot:replay"

Projection_World :: struct {value:i32,padding:[4096]u8}
@(test)
projected_frame_is_detached_and_rejects_missing_or_reference_results :: proc(t:^testing.T) {
    timeline:r.Timeline(Projection_World,i32,u8)
    assert(r.init(&timeline,r.Frame(Projection_World){state={value=7}},proc(w:^Projection_World,input:i32,ctx:^r.Step(u8)){w.value+=input})==.None)
    defer r.destroy(&timeline)
    assert(r.advance(&timeline,2).error==.None)
    value,error:=r.project(&timeline,1,proc(w:Projection_World)->i32 {local:=w;local.value+=1;return local.value})
    testing.expect(t,error==.None && value==10)
    frame,_:=r.current(&timeline);testing.expect_value(t,frame.state.value,i32(9))
    _,error=r.project(&timeline,2,proc(w:Projection_World)->i32{return w.value});testing.expect_value(t,error,r.Error.History_Missing)
    _,invalid:=r.project(&timeline,1,proc(w:Projection_World)->string{return "not owned"});testing.expect_value(t,invalid,r.Error.Unsupported_Value)
    testing.expect_value(t,r.audit(&timeline,1).error,r.Error.None)
}

projection_timeline: ^r.Timeline(Projection_World,i32,u8)
@(test)
project_callback_cannot_reenter_timeline :: proc(t:^testing.T) {
    timeline:r.Timeline(Projection_World,i32,u8)
    assert(r.init(&timeline,r.Frame(Projection_World){},proc(w:^Projection_World,input:i32,ctx:^r.Step(u8)){})==.None)
    defer r.destroy(&timeline)
    projection_timeline=&timeline;defer projection_timeline=nil
    result,error:=r.project(&timeline,0,proc(w:Projection_World)->r.Error{return r.advance(projection_timeline,1).error})
    testing.expect_value(t,error,r.Error.None);testing.expect_value(t,result,r.Error.Reentrant)
    testing.expect_value(t,timeline.head,u64(0));testing.expect(t,!timeline.busy)
}
