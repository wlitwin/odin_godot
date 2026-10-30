package replay_provision_test

import "core:testing"
import auth "godot:replay/authority"
import p "godot:replay/provision"
import tr "godot:replay/transport"

@(test)
host_removal_commits_with_enrollment_and_denies_join_retries_after_restart :: proc(t:^testing.T) {
 room:p.Room;ledger:Ledger;clock:Clock;rng:Random
 setup(&room,&ledger,&clock,&rng);defer p.close(&room)
 ticket,error:=p.invite(&room,ADMIN,INVITE,.Trusted_Peer);testing.expect_value(t,error,p.Error.None)
 guest,error2:=p.join(&room,ticket,CLAIM,address(45002));testing.expect_value(t,error2,p.Error.None)
 testing.expect_value(t,auth.coordinator_start(&room.service.coordinator,{1,1},1,0),auth.Error.None)
 testing.expect_value(t,auth.coordinator_remove(&room.service.coordinator,{1,1},1,guest.identity,0),auth.Error.None)
 testing.expect(t,!ledger.bundle.record.members[1].enabled && p.bundle_valid(ledger.bundle))
 _,denied:=p.join(&room,ticket,CLAIM,address(45002));testing.expect_value(t,denied,p.Error.Denied)
 p.close(&room);clock.now=3000
 testing.expect_value(t,p.open(&room,ledger.bundle,commit,&ledger,{&clock,clock_read},entropy={&rng,random_read}),p.Error.None)
 _,denied=p.join(&room,ticket,CLAIM,address(45002));testing.expect_value(t,denied,p.Error.Denied)
 testing.expect(t,!room.service.coordinator.record.members[1].enabled)
 testing.expect_value(t,room.service.disabled_credentials[1].key,guest.key)
}

@(test)
hub_routes_authenticated_removal_without_changing_ordinary_rpc_schema :: proc(t:^testing.T) {
 f:Hub_Fixture;hub_setup(&f);defer hub_destroy(&f)
 creator:=hub_call(&f,create_request());testing.expect_value(t,creator.result,p.Error.None)
 q:=p.Request{version=p.PROTOCOL,verb=.Invite,room=44,content=55,claim=ADMIN,ticket=INVITE,role=.Trusted_Peer,uses=1}
 testing.expect_value(t,hub_call(&f,q).result,p.Error.None)
 guest:=hub_call(&f,{version=p.PROTOCOL,verb=.Join,room=44,content=55,claim=CLAIM,ticket=INVITE,endpoint=address(45002)})
 lease:auth.Lease;assert(auth.lease_init(&lease,creator.grant.identity,44,55,{&f.clock,clock_read},true)==.None)
 rpc:auth.Rpc_Client;assert(auth.rpc_client_init(&rpc,&lease,creator.grant.key,{0=13},tr.memory_transport(&f.endpoints[1])));defer auth.rpc_client_destroy(&rpc)
 for operation in 0..<2 {
  if operation==0 {assert(auth.rpc_begin(&rpc,{verb=.Start})==.None)} else {assert(auth.rpc_remove(&rpc,1,guest.grant.identity)==.None)}
  testing.expect(t,p.hub_control_receive(&f.hub,2,rpc.txb[:rpc.count]))
  for _ in 0..<10 {
   f.clock.now+=10;assert(tr.memory_advance(&f.memory,f.clock.now/10))
   assert(auth.rpc_client_pump(&rpc)==.None)
   if _,done:=auth.rpc_completed(&rpc);done {break}
  }
  reply,done:=auth.rpc_completed(&rpc);testing.expect(t,done && reply.result==.None)
 }
 testing.expect(t,!f.ledger.rooms[0].record.members[1].enabled)
}
