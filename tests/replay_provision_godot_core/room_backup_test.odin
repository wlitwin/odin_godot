package provision_godot_test
import "core:testing"
import "core:reflect"
import rgd "godot:replay/godot"
import auth "godot:replay/authority"
import net "godot:replay/net"
import tr "godot:replay/transport"
Room :: rgd.Room(u32,u8,u8,u8,2)
backup_fixture :: proc(room:^Room) {
 room.ready,room.registered,room.session.ready=true,true,true
 room.phase=.Following;room.options.identity={2,22};room.options.room=44;room.options.session.network.content=55
 room.session.client.phase=.Running;room.session.client.cfg.epoch=3;room.session.client.authority_frame.tick=180
 view:=auth.View{room=44,content=55,revision=7,coordinator_generation=4,epoch=3,owner={1,11},last_known_tick=200,policy=auth.DEFAULT_POLICY}
 room.lease={ready=true,identity={2,22},room=44,content=55,now=1000,deadline=2000,view=view}
 point:=auth.Point{scope={44,3,9,55},archive={sequence=4,tick=100,bytes=100,hash={0=1}}}
 room.backup_observation={view=view,nominee={2,22},binding=9,point=point,observed_at=1000,prepared=true,ready=true}
 room.members[0]={identity={2,22},enabled=true,can_host=true,trusted_authority=true}
 room.prepared.ready,room.prepared.point=true,point
}
@(test)
backup_status_requires_approval_retention_scope_and_unexpired_control :: proc(t:^testing.T) {
 room:=new(Room);defer free(room);backup_fixture(room)
 before:=room.lease;s:=rgd.room_backup_status(room,1100)
 testing.expect_value(t,s.phase,rgd.Room_Backup_Phase.Ready);testing.expect_value(t,s.age_ticks,u64(100));testing.expect(t,s.locally_retained && reflect.equal(before,room.lease))
 room.rpc.pending=true;room.rpc.reply={};testing.expect_value(t,rgd.room_backup_status(room,1101).phase,rgd.Room_Backup_Phase.Ready)
 room.prepared.ready=false;testing.expect_value(t,rgd.room_backup_status(room,1101).phase,rgd.Room_Backup_Phase.Transferring)
 room.prepared.ready=true;room.backup_observation.prepared=false;testing.expect_value(t,rgd.room_backup_status(room,1101).phase,rgd.Room_Backup_Phase.Transferring)
 room.backup_observation.prepared=true;room.backup_observation.point.scope.binding=10;testing.expect_value(t,rgd.room_backup_status(room,1101).phase,rgd.Room_Backup_Phase.Checking)
 backup_fixture(room);testing.expect_value(t,rgd.room_backup_status(room,2000).phase,rgd.Room_Backup_Phase.Checking)
 testing.expect_value(t,rgd.room_backup_status(room,999).phase,rgd.Room_Backup_Phase.Checking)
 room.lease.poisoned=true;testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Checking)
}
@(test)
backup_status_uses_known_age_and_current_epoch_not_past_recovery :: proc(t:^testing.T) {
 room:=new(Room);defer free(room);backup_fixture(room)
 room.recovery.ready=true;room.recovery.from_publication=true
 room.backup_observation.view.last_known_tick=220;room.lease.view.last_known_tick=220;testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Ready)
 room.backup_observation.view.last_known_tick=221;room.lease.view.last_known_tick=221;testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Stale)
 room.session.client.authority_frame.tick=260;testing.expect_value(t,rgd.room_backup_status(room,1100).age_ticks,u64(160))
 room.session.client.cfg.epoch=4;testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Checking)
 backup_fixture(room);room.lease.view.coordinator_generation+=1;testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Checking)
 backup_fixture(room);room.session.fenced=true;testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Recovering)
}
@(test)
backup_status_respects_trust_and_observer_role_without_requiring_their_own_archive :: proc(t:^testing.T) {
 room:=new(Room);defer free(room);backup_fixture(room)
 room.options.identity={3,33};room.lease.identity={3,33};room.prepared={};room.session.client.spectator=true
 testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Ready)
 room.members[0].trusted_authority=false;testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Waiting_Peer)
 backup_fixture(room);room.backup_observation.view.policy.mode=.Dedicated;room.lease.view.policy.mode=.Dedicated;testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Waiting_Peer)
 room.members[0].infrastructure=true;testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Ready)
}

@(test)
host_backup_status_checks_the_actual_nominee_connection_and_local_progress :: proc(t:^testing.T) {
 room:=new(Room);defer free(room);backup_fixture(room)
 room.phase=.Hosting;room.session.authority=true;room.session.server.initialized=true;room.session.server.cfg.epoch=3
 room.options.identity={1,11};room.lease.identity={1,11};room.options.successor={2,22};room.options.successor_seat=2
 alive:=true
 room.session.server.wire={user=&alive,connected=proc(p:rawptr,id:tr.Peer_Id)->bool {return (cast(^bool)p)^ && id==7}}
 hash:=net.token_hash({0=9});room.members[0].game_token_hash=hash
 room.session.server.peers[0]={phase=.Running,connection=7,seat=2,incarnation=22,generation=9,token_hash=hash}
 testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Ready)
 room.session.server.timeline.head=221;testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Stale)
 room.session.server.timeline.head=200;alive=false;testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Waiting_Peer)
 alive=true;room.session.server.peers[0].incarnation=23;testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Waiting_Peer)
 room.session.server.peers[0].incarnation=22;room.session.server.peers[0].generation=10;testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Waiting_Peer)
 room.session.server.peers[0].generation=9;room.members[0].game_token_hash={};testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Waiting_Peer)
}
@(test)
recovery_disclosure_does_not_substitute_for_backup_readiness :: proc(t:^testing.T) {
 room:=new(Room);defer free(room);backup_fixture(room)
 room.recovery={ready=true,from_publication=true,known_lost_ticks=15};room.backup_observation.prepared=false
 status:=rgd.room_backup_status(room,1100)
 testing.expect_value(t,status.phase,rgd.Room_Backup_Phase.Transferring)
 testing.expect_value(t,rgd.room_recovery_message(room,status),"Party restored; recent progress lost · backup pending")
 room.handoff_requested=true;status=rgd.room_backup_status(room,1100)
 testing.expect_value(t,status.phase,rgd.Room_Backup_Phase.Recovering)
 testing.expect_value(t,rgd.room_recovery_message(room,status),"Recovering the session…")
}

@(test)
infrastructure_standby_can_hold_a_backup_without_a_playable_seat :: proc(t:^testing.T) {
 room:=new(Room);defer free(room);backup_fixture(room)
 room.phase=.Hosting;room.session.authority=true;room.session.server.initialized=true;room.session.server.cfg.epoch=3
 room.options.identity={1,11};room.lease.identity={1,11};room.options.successor={2,22};room.options.successor_seat=0
 room.lease.view.policy.mode=.Dedicated;room.backup_observation.view.policy.mode=.Dedicated
 room.members[0].infrastructure=true
 room.session.server.wire={connected=proc(_:rawptr,id:tr.Peer_Id)->bool {return id==7}}
 hash:=net.token_hash({0=9});room.members[0].game_token_hash=hash
 room.session.server.peers[0]={phase=.Running,connection=7,seat=0,spectator=true,incarnation=22,generation=9,token_hash=hash}
 testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Ready)
 room.members[0].infrastructure=false
 testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Waiting_Peer)
 room.lease.view.policy.mode=.Cooperative;room.backup_observation.view.policy.mode=.Cooperative
 testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Waiting_Peer)
 room.members[0].infrastructure=true
 testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Ready)
 room.members[0].infrastructure=true;room.session.server.peers[0].incarnation=23
 testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Waiting_Peer)
}

@(test)
explicit_successor_identity_resolves_independently_of_playable_seat :: proc(t:^testing.T) {
 room:=new(Room);defer free(room);backup_fixture(room)
 room.phase=.Hosting;room.session.authority=true;room.session.server.initialized=true;room.session.server.cfg.epoch=3
 room.options.identity={1,11};room.lease.identity={1,11};room.options.successor={2,22}
 room.session.server.wire={connected=proc(_:rawptr,id:tr.Peer_Id)->bool {return id==7}}
 hash:=net.token_hash({0=9});room.members[0].game_token_hash=hash
 room.session.server.peers[0]={phase=.Running,connection=7,seat=2,incarnation=22,generation=9,token_hash=hash}
 testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Ready)
 room.options.successor_seat=1 // Explicit nonzero constraints still apply.
 testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Waiting_Peer)
 room.options.successor_seat=0;room.members[0].game_token_hash={}
 testing.expect_value(t,rgd.room_backup_status(room,1100).phase,rgd.Room_Backup_Phase.Waiting_Peer)
}

@(test)
status_clock_observation_never_poison_or_renews_the_lease :: proc(t:^testing.T) {
 room:=new(Room);defer free(room);backup_fixture(room)
 clock:=Expiry_Clock{now=1100};room.clock={user=&clock,read=expiry_clock}
 before:=room.lease
 testing.expect_value(t,rgd.room_backup_status(room).phase,rgd.Room_Backup_Phase.Ready)
 testing.expect(t,reflect.equal(before,room.lease));testing.expect_value(t,clock.reads,1)
 clock.now=room.lease.deadline
 testing.expect_value(t,rgd.room_backup_status(room).phase,rgd.Room_Backup_Phase.Checking)
 testing.expect(t,reflect.equal(before,room.lease))
 room.clock.read=proc(user:rawptr)->(u64,bool){return 0,false}
 testing.expect_value(t,rgd.room_backup_status(room).phase,rgd.Room_Backup_Phase.Checking)
 testing.expect(t,reflect.equal(before,room.lease))
}
