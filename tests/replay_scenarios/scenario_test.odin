package scenario_test
import "core:testing"
import r "godot:replay"
import s "godot:replay/testing"
import n "godot:replay/net"
State :: struct {value:i32}
step :: proc(w:^State,input:i32,ctx:^r.Step(i32)) {w.value+=input;if input!=0 {r.emit(ctx,1,1,input)}}
@(test)
correction_compares_frames_and_events_and_reports_invalid_ranges :: proc(t:^testing.T) {
 predicted:=[4]i32{1,0,0,0};actual:=[4]i32{1,2,3,4}
 result:=s.correction(r.Frame(State){},step,predicted[:],actual[:],2)
 testing.expect(t,result.report.phase==.Complete && result.before.state.value==1 && result.after.state.value==10 && result.report.hash!=0)
 result=s.correction(r.Frame(State){},step,predicted[:],actual[:],3)
 testing.expect(t,result.report.phase==.Compare && result.report.tick==2,"uncorrected prefix must remain a visible failure")
 result=s.correction(r.Frame(State){},step,predicted[:],actual[:],0)
 testing.expect_value(t,result.report.phase,s.Phase.Invalid)
}
net_step :: proc(w:^State,controls:[1]i32,joins,leaves:u64,ctx:^r.Step(i32)) {step(w,1,ctx)}
@(test)
takeover_checks_events_and_reports_drive_failure :: proc(t:^testing.T) {
 model:=n.Model(State,i32,u8,i32,1){step=net_step,control_valid=proc(i:i32)->bool{return true},state_valid=proc(s:State)->bool{return true},hold=proc(i:i32)->i32{return i}}
 drive:proc(^n.Server(State,i32,u8,i32,1),u64)->n.Error
 result:=s.takeover(r.Frame(State){},model,n.DEFAULT_CONFIG,3,8,drive)
 testing.expect(t,result.report.phase==.Complete && result.before.state.value==3 && result.after.state.value==8)
 drive=proc(_: ^n.Server(State,i32,u8,i32,1),tick:u64)->n.Error {return tick==5 ? .Invalid_Input : .None}
 result=s.takeover(r.Frame(State){},model,n.DEFAULT_CONFIG,3,8,drive)
 testing.expect(t,result.report.phase==.Continue && result.report.network_error==.Invalid_Input)
}
