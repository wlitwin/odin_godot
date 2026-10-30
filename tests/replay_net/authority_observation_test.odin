package replay_net_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import d "godot:replay/diagnostic"

Authority_World :: struct {known:bool,seat:u16,changes,steps:u32}
authority_test_model :: proc()->net.Model(Authority_World,Control,Action,Event,2) {
 return {authority={id=1,apply=proc(w:^Authority_World,a:net.Authority_Observation,ctx:^r.Step(Event)) {
  if w.known && w.seat!=a.seat {w.changes+=1}
  w.known,w.seat=true,a.seat
 }},step=proc(w:^Authority_World,_:[2]Control,_,_:u64,_:^r.Step(Event)) {w.steps+=1},
 control_valid=control_valid,hold=hold,state_valid=proc(w:Authority_World)->bool {return w.seat<=2}}
}

@(test)
authority_observation_is_recorded_replayed_and_not_inferred_from_replay_process :: proc(t:^testing.T) {
 m:=authority_test_model();s:net.Server(Authority_World,Control,Action,Event,2)
 testing.expect_value(t,net.server_init(&s,r.Frame(Authority_World){},m,{},local_seat=1),net.Error.None);defer net.server_destroy(&s)
 testing.expect_value(t,net.server_set_local_token(&s,net.Token{0=1}),net.Error.None)
 testing.expect_value(t,net.server_step(&s),net.Error.None)
 first,ok:=r.read_input(&s.timeline,1);testing.expect(t,ok);testing.expect_value(t,first.authority,(net.Authority_Observation{true,1}))
 cp:net.Checkpoint(Authority_World,Control,Action,2);defer net.checkpoint_destroy(&cp)
 testing.expect_value(t,net.checkpoint_capture(&s,&cp),net.Error.None)
 // The same captured player-host state resumes under a dedicated authority.
 restored:net.Server(Authority_World,Control,Action,Event,2);defer net.server_destroy(&restored)
 testing.expect_value(t,net.server_restore(&restored,&cp,m,{},net.Resume_Options{epoch=2,local_seat=0}),net.Error.None)
 before,_:=r.current(&restored.timeline);testing.expect(t,reflect.equal(before,cp.frame))
 // Capture before any resumed tick, then recover again. The pending change
 // survives in the unchanged world plus the saved runner's authority metadata.
 pending:net.Checkpoint(Authority_World,Control,Action,2);defer net.checkpoint_destroy(&pending)
 testing.expect_value(t,net.checkpoint_capture(&restored,&pending),net.Error.None)
 again:net.Server(Authority_World,Control,Action,Event,2);defer net.server_destroy(&again)
 testing.expect_value(t,net.server_restore(&again,&pending,m,{},net.Resume_Options{epoch=3,local_seat=0}),net.Error.None)
 testing.expect_value(t,net.server_step(&again),net.Error.None)
 resumed,_:=r.current(&again.timeline);testing.expect_value(t,resumed.state.changes,u32(1));testing.expect_value(t,resumed.state.seat,u16(0))
 for _ in 0..<3 {testing.expect_value(t,net.server_step(&restored),net.Error.None)}
 current,_:=r.current(&restored.timeline);testing.expect_value(t,current.state.seat,u16(0));testing.expect_value(t,current.state.changes,u32(1))
 testing.expect_value(t,r.audit(&restored.timeline,2).error,r.Error.None)
 recording:d.Recording(Authority_World,net.Batch(Control,Action,2),net.Net_Event(Event));defer d.recording_destroy(&recording)
 testing.expect_value(t,d.recording_capture(&recording,&restored.timeline,RECORDING_ID).error,d.Recording_Error.None)
 capture:r.Audit_Capture(Authority_World,net.Batch(Control,Action,2),net.Net_Event(Event));defer r.audit_capture_destroy(&capture)
 testing.expect_value(t,d.recording_verify(&recording,RECORDING_ID,net.recording_model(&m),&capture).error,d.Recording_Error.None)
 // A client forecast has no authority observation and cannot manufacture one
 // by changing the verifier's process role. Invalid metadata fails preflight.
 runner:=net.recording_model(&m);input:=net.Batch(Control,Action,2){}
 state:=Authority_World{known=true,seat=1};events:[net.WIRE_EVENTS]r.Occurrence(net.Net_Event(Event))
 ctx:=r.Step(net.Net_Event(Event)){tick=1,epoch=2,events=events[:],user=runner.user}
 runner.step(&state,input,&ctx);testing.expect_value(t,state.seat,u16(1));testing.expect_value(t,state.changes,u32(0))
 input.authority={known=true,seat=3};testing.expect(t,!runner.input_check(input,1,runner.user))
 input.authority={known=false,seat=1};testing.expect(t,!runner.input_check(input,1,runner.user))
}

@(test)
authority_policy_is_optional_negotiated_and_rejected_when_misconfigured :: proc(t:^testing.T) {
 m:=authority_test_model();enabled,e:=net.model_contract(m,net.DEFAULT_CONFIG);testing.expect_value(t,e,net.Error.None)
 m.authority.id=2;changed,_:=net.model_contract(m,net.DEFAULT_CONFIG);testing.expect(t,enabled!=changed)
 m.authority={};disabled,_:=net.model_contract(m,net.DEFAULT_CONFIG);testing.expect(t,enabled!=disabled)
 runner:=net.recording_model(&m);input:=net.Batch(Control,Action,2){authority={known=true,seat=0}}
 testing.expect(t,!runner.input_check(input,1,runner.user))
 m.authority.id=1
 _,invalid:=net.model_contract(m,net.DEFAULT_CONFIG);testing.expect_value(t,invalid,net.Error.Invalid_Config)
 testing.expect(t,net.recording_model(&m).step==nil)
}

@(test)
authority_policy_abort_leaves_the_tick_and_roster_uncommitted :: proc(t:^testing.T) {
 m:=authority_test_model()
 m.authority.apply=proc(w:^Authority_World,_:net.Authority_Observation,ctx:^r.Step(Event)) {w.changes=999;r.abort(ctx)}
 s:net.Server(Authority_World,Control,Action,Event,2);defer net.server_destroy(&s)
 testing.expect_value(t,net.server_init(&s,r.Frame(Authority_World){},m,{},local_seat=1),net.Error.None)
 for _ in 0..<2 {
  testing.expect_value(t,net.server_step(&s),net.Error.Simulation)
  frame,_:=r.current(&s.timeline);testing.expect_value(t,frame.tick,u64(0));testing.expect_value(t,frame.state,(Authority_World{}))
  testing.expect_value(t,s.joins,u64(1));testing.expect_value(t,s.fresh,u64(1))
 }
}
