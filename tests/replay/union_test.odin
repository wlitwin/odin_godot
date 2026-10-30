package replay_test

import "core:testing"
import "core:reflect"
import r "godot:replay"

Union_Idle :: struct {ticks:u32}
Union_Moving :: struct {position:i32}
Union_Command :: union {Union_Idle,Union_Moving}
Union_World :: struct {state:Union_Command}
union_step :: proc(w:^Union_World,input:Union_Command,ctx:^r.Step(Union_Command)) {
	w.state=input;r.emit(ctx,1,1,input)
}
@(test)
value_unions_restore_active_variants_in_state_input_and_events :: proc(t:^testing.T) {
	testing.expect(t,r.value_supported(Union_World) && r.value_supported(union #no_nil{Union_Idle,Union_Moving}))
	testing.expect(t,!r.value_supported(union{Union_Idle,string}))
	a,b:r.Timeline(Union_World,Union_Command,Union_Command)
	r.init(&a,r.Frame(Union_World){},union_step);defer r.destroy(&a)
	r.init(&b,r.Frame(Union_World){},union_step);defer r.destroy(&b)
	one:Union_Command=Union_Idle{3};two:Union_Command=Union_Moving{12}
	r.advance(&a,one);r.advance(&a,two);r.advance(&a,Union_Command(nil))
	testing.expect_value(t,r.revise_input(&a,1,two).error,r.Error.None)
	r.advance(&b,two);r.advance(&b,two);r.advance(&b,Union_Command(nil))
	left,_:=r.current(&a);right,_:=r.current(&b);testing.expect(t,reflect.equal(left,right))
	testing.expect_value(t,r.audit(&a,1).error,r.Error.None)
	frame,_:=r.read(&a,1);value,ok:=frame.state.state.(Union_Moving);testing.expect(t,ok && value.position==12)
	events:[2]r.Occurrence(Union_Command);count,err:=r.copy_events(&a,1,events[:]);testing.expect(t,err==.None && count==1)
	shot,matched:=events[0].value.(Union_Moving);testing.expect(t,matched && shot.position==12)
}
