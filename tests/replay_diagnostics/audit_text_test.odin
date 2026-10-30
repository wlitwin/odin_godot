package diagnostic_test

import "core:strings"
import "core:testing"
import r "godot:replay"
import d "godot:replay/diagnostic"

State :: struct {inventory:[2]u32}
Event :: struct {amount:u32}
@(test)
formatted_audit_retains_state_event_and_truncation_evidence :: proc(t:^testing.T) {
	capture:=r.Audit_Capture(State,u8,Event){ready=true,parent={tick=8},expected={tick=9,state={{1,2}}},actual={tick=9,state={{3,4}}}}
	left:=[1]r.Occurrence(Event){{id={1,9,1,1},value={5}}};right:=left;right[0].value.amount=6
	capture.expected_events,capture.actual_events=left[:],right[:]
	result:=r.Result{error=.Diverged_State,tick=9,steps=1}
	text:=d.audit_text(result,&capture,1);defer delete(text)
	testing.expect(t,strings.contains(text,"parent frame 8"))
	testing.expect(t,strings.contains(text,"$.inventory[0]: 1 -> 3"))
	testing.expect(t,strings.contains(text,"showing 1 of 2 fields"))
	testing.expect(t,strings.contains(text,"$.value.amount: 5 -> 6"))
	testing.expect_value(t,capture.expected.state.inventory[0],u32(1))
}
@(test)
no_capture_and_unsupported_schema_stay_explicit :: proc(t:^testing.T) {
	capture:r.Audit_Capture(State,u8,Event)
	text:=d.audit_text(r.Result{error=.Initial_Frame,tick=20},&capture);defer delete(text)
	testing.expect(t,strings.contains(text,"Initial_Frame") && !strings.contains(text,"state:"))
	Unsupported :: struct {value:int}
	other:=r.Audit_Capture(Unsupported,u8,Event){ready=true}
	failed:=d.audit_text(r.Result{error=.Diverged_State,tick=1},&other);defer delete(failed)
	testing.expect(t,strings.contains(failed,"Platform_Integer") && strings.contains(failed,"$.value"))
}
