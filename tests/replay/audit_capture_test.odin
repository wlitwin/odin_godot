package replay_test

import "core:testing"
import r "godot:replay"

Audit_State :: struct {value:i32}
Audit_Input :: struct {add:i32}
Audit_Fault :: struct {state,event,abort_tick:bool}
audit_probe_step :: proc(w:^Audit_State,input:Audit_Input,ctx:^r.Step(i32)) {
	fault:=cast(^Audit_Fault)ctx.user
	w.value+=input.add
	if ctx.tick==2 && fault.abort_tick {r.abort(ctx);return}
	if ctx.tick==2 && fault.state {w.value+=1}
	payload:=input.add
	if ctx.tick==2 && fault.event {payload+=10}
	r.emit(ctx,1,1,payload)
}
@(test)
audit_capture_owns_first_failure_and_survives_scratch_reuse :: proc(t:^testing.T) {
	fault:Audit_Fault;timeline:r.Timeline(Audit_State,Audit_Input,i32)
	r.init(&timeline,r.Frame(Audit_State){},audit_probe_step,user=&fault);defer r.destroy(&timeline)
	for _ in 0..<3 {r.advance(&timeline,Audit_Input{2})}
	fault.state=true
	capture:r.Audit_Capture(Audit_State,Audit_Input,i32);defer r.audit_capture_destroy(&capture)
	result:=r.audit_capture(&timeline,1,&capture)
	testing.expect_value(t,result.error,r.Error.Diverged_State);testing.expect_value(t,result.tick,u64(2))
	testing.expect(t,capture.ready);testing.expect_value(t,capture.expected.state.value,i32(4));testing.expect_value(t,capture.actual.state.value,i32(5))
	testing.expect_value(t,capture.input,Audit_Input{2});testing.expect_value(t,len(capture.expected_events),1)
	fault.state=false;r.advance(&timeline,Audit_Input{3});r.audit(&timeline,1)
	testing.expect_value(t,capture.actual.state.value,i32(5))
	capture.expected.state.value=999;capture.expected_events[0].value=999
	frame,_:=r.read(&timeline,2);events:[4]r.Occurrence(i32);count,_:=r.copy_events(&timeline,2,events[:])
	testing.expect_value(t,frame.state.value,i32(4));testing.expect_value(t,count,1);testing.expect_value(t,events[0].value,i32(2))
	testing.expect_value(t,r.audit_capture(&timeline,1,&capture).error,r.Error.Invalid_Config)
	testing.expect_value(t,capture.expected.state.value,i32(999))
}
@(test)
audit_capture_distinguishes_event_failure_and_nondivergence_errors :: proc(t:^testing.T) {
	fault:Audit_Fault;timeline:r.Timeline(Audit_State,Audit_Input,i32)
	r.init(&timeline,r.Frame(Audit_State){},audit_probe_step,user=&fault);defer r.destroy(&timeline)
	for _ in 0..<3 {r.advance(&timeline,Audit_Input{2})}
	capture:r.Audit_Capture(Audit_State,Audit_Input,i32);defer r.audit_capture_destroy(&capture)
	fault.event=true
	testing.expect_value(t,r.audit_capture(&timeline,1,&capture).error,r.Error.Diverged_Event)
	testing.expect_value(t,capture.expected.state,capture.actual.state)
	testing.expect_value(t,capture.actual_events[0].value,i32(12));testing.expect_value(t,capture.expected_events[0].value,i32(2))
	r.audit_capture_destroy(&capture);fault.event=false
	testing.expect_value(t,r.audit_capture(&timeline,1,&capture).error,r.Error.None);testing.expect(t,!capture.ready)
	fault.abort_tick=true
	testing.expect_value(t,r.audit_capture(&timeline,1,&capture).error,r.Error.Aborted);testing.expect(t,!capture.ready)
	testing.expect_value(t,r.audit_capture(&timeline,0,&capture).error,r.Error.Initial_Frame)
}

@(test)
recent_audit_stops_at_authority_boundaries_and_ring_edges :: proc(t:^testing.T) {
	fault:Audit_Fault;timeline:r.Timeline(Audit_State,Audit_Input,i32)
	r.init(&timeline,r.Frame(Audit_State){},audit_probe_step,cfg={history_frames=4,events_per_tick=2},user=&fault);defer r.destroy(&timeline)
	for _ in 0..<8 {r.advance(&timeline,Audit_Input{2})}
	from,to,err:=r.audit_window(&timeline,120)
	testing.expect_value(t,err,r.Error.None);testing.expect_value(t,from,u64(6));testing.expect_value(t,to,u64(8))
	capture:r.Audit_Capture(Audit_State,Audit_Input,i32);defer r.audit_capture_destroy(&capture)
	testing.expect_value(t,r.audit_recent(&timeline,&capture).error,r.Error.None)
	frame,_:=r.read(&timeline,7);frame.state.value=100
	testing.expect_value(t,r.correct(&timeline,frame,nil).error,r.Error.None)
	from,to,err=r.audit_window(&timeline,120)
	testing.expect_value(t,from,u64(8));testing.expect_value(t,to,u64(8))
	testing.expect_value(t,r.audit_recent(&timeline,&capture).error,r.Error.None)
	current,_:=r.current(&timeline);r.reset_checkpoint(&timeline,current,2)
	_,_,err=r.audit_window(&timeline);testing.expect_value(t,err,r.Error.Initial_Frame)
	_,_,err=r.audit_window(&timeline,0);testing.expect_value(t,err,r.Error.Invalid_Config)
}
