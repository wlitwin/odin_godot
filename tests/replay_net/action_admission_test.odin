package replay_net_test

import "core:testing"
import r "godot:replay"
import net "godot:replay/net"

Admission :: struct {allowed: bool, calls: int}
@(test)
authority_admission_is_recorded_and_not_reconsulted_during_replay :: proc(t:^testing.T) {
 state:=World{chest=5};rules:=model();admission:Admission
 rules.action_admission_user=&admission
 rules.action_admit=proc(user:rawptr,seat:u16,action:Action)->bool {a:=cast(^Admission)user;a.calls+=1;return a.allowed}
 server:net.Server(World,Control,Action,Event,2);defer net.server_destroy(&server)
 testing.expect_value(t,net.server_init(&server,r.Frame(World){state=state},rules,{},local_seat=1),net.Error.None)
 net.server_set_local_token(&server,net.Token{0=7});net.server_step(&server)
 _,err:=net.server_issue(&server,Action{take=true});testing.expect_value(t,err,net.Error.None)
 testing.expect_value(t,admission.calls,1)
 net.server_step(&server)
 first,_:=r.current(&server.timeline)
 admission.allowed=true
 testing.expect_value(t,r.audit(&server.timeline,1).error,r.Error.None)
 testing.expect_value(t,admission.calls,1)
 testing.expect_value(t,server.peers[0].recent[0].reason,net.Action_Reason.Invalid)
 testing.expect(t,!server.peers[0].recent[0].applied)
 second,_:=r.current(&server.timeline);testing.expect_value(t,first,second)
}
