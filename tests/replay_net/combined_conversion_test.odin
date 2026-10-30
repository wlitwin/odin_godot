package replay_net_test
import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
Combined_Action :: struct {old:Action,tag:u8}
combined_model :: proc()->net.Model(Expanded_World,Control,Combined_Action,Event,2) {
	return {control_valid=control_valid,state_valid=proc(w:Expanded_World)->bool {return w.definition==7 && state_valid(w.original)},action_valid=proc(a:Combined_Action)->bool {return a.tag==9 && action_valid(a.old)},action=proc(_: ^Expanded_World,_:u16,_:Combined_Action,_:^r.Step(Event))->bool {panic("archive only")}}
}
@(test)
combined_conversion_preserves_pending_acceptance_and_rejects_failed_mapper :: proc(t:^testing.T) {
	f:Fixture;fixture_init(&f);defer fixture_destroy(&f);for _ in 0..<40 {fixture_step(&f)}
	_,issued:=net.client_issue(&f.clients[0],Action{take=true});testing.expect_value(t,issued,net.Error.None)
	tr.memory_advance(&f.network,f.clock);net.server_pump(&f.server,f.clock*1000/60)
	cp:Checkpoint;defer net.checkpoint_destroy(&cp);net.checkpoint_capture(&f.server,&cp)
	testing.expect(t,len(cp.actions)>0)
	bytes,encoded:=net.checkpoint_encode(&cp,model());defer delete(bytes);testing.expect_value(t,encoded,net.Error.None);before:=sc.digest(bytes)
	world:=proc(w:World)->(Expanded_World,bool) {return {w,7},true}
	action:=proc(a:Action)->(Combined_Action,bool) {return {a,9},true}
	out,err:=net.checkpoint_convert(bytes,model(),f.server.cfg.content,combined_model(),99,world,action);defer delete(out)
	testing.expect_value(t,err,net.Error.None);if err!=.None {return}
	decoded:net.Checkpoint(Expanded_World,Control,Combined_Action,2);defer net.checkpoint_destroy(&decoded)
	testing.expect_value(t,net.checkpoint_decode(&decoded,out,combined_model(),99),net.Error.None)
	testing.expect(t,reflect.equal(decoded.frame.state.original,cp.frame.state));testing.expect_value(t,decoded.frame.tick,cp.frame.tick)
	testing.expect_value(t,len(decoded.actions),len(cp.actions))
	for entry,i in cp.actions {testing.expect_value(t,decoded.actions[i].value.old,entry.value);testing.expect_value(t,decoded.actions[i].reason,entry.reason);testing.expect_value(t,decoded.actions[i].sequence,entry.sequence)}
	bad:=proc(_:Action)->(Combined_Action,bool) {return {},false}
	invalid,result:=net.checkpoint_convert(bytes,model(),f.server.cfg.content,combined_model(),99,world,bad);defer delete(invalid)
	testing.expect(t,result!=.None && len(invalid)==0);testing.expect_value(t,sc.digest(bytes),before)
}
