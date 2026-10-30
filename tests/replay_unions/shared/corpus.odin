package union_corpus

import r "godot:replay"
import sc "godot:replay/schema"
import "core:reflect"

Move :: struct {dx:i32,kind:u8}
Wait :: struct {ticks:u16}
Command :: union {Move,Wait}
State :: struct {choice:Command,history:[2]Command,position:i32}
Result :: struct {ok:bool,fingerprint,hash:u64,bytes:[128]u8,count:int}
step :: proc(w:^State,input:Command,ctx:^r.Step(Command)) {
	w.history[1]=w.history[0];w.history[0]=w.choice;w.choice=input
	if move,ok:=input.(Move);ok {w.position+=move.dx}
	r.emit(ctx,1,1,input)
}
run :: proc()->Result {
	schema:sc.Schema;defer sc.destroy(&schema)
	if sc.init(&schema,State).error!=.None {return {}}
	timeline:r.Timeline(State,Command,Command);defer r.destroy(&timeline)
	if r.init(&timeline,r.Frame(State){},step,cfg={history_frames=32,events_per_tick=4})!=.None {return {}}
	for tick in 1..=20 {
		command:Command
		if tick%3==0 {command=Wait{u16(tick)}} else {command=Move{i32(tick)-10,u8(tick%4)}}
		if r.advance(&timeline,command).error!=.None {return {}}
	}
	if r.revise_input(&timeline,5,Command(Move{99,3})).error!=.None || r.audit(&timeline,1).error!=.None {return {}}
	frame,_:=r.current(&timeline);result:=Result{fingerprint=schema.fingerprint,count=schema.wire_size}
	if result.count>len(result.bytes) || sc.encode(&schema,frame.state,result.bytes[:]).error!=.None {return {}}
	decoded:State;if sc.decode(&schema,&decoded,result.bytes[:result.count]).error!=.None || !reflect.equal(decoded,frame.state) {return {}}
	result.hash=sc.digest(result.bytes[:result.count]);result.ok=true;return result
}
