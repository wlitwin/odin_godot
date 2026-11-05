package replay_provision_test

import "core:testing"
import p "godot:replay/provision"
import auth "godot:replay/authority"
import tr "godot:replay/transport"

Retired_Test :: struct {fixture:^Hub_Fixture, archived:[8]p.Bundle, count:int, fail:bool}
archive_test :: proc(user:rawptr,expected:p.Bundle)->bool {
    state:=cast(^Retired_Test)user
    if state.fail || state.count==len(state.archived) {return false}
    for &bundle in state.fixture.ledger.rooms {
        if bundle.record.room==expected.record.room {
            if bundle!=expected{return false}
            state.archived[state.count]=bundle;state.count+=1;bundle={};return true
        }
    }
    return false
}
guard_test :: proc(user:rawptr,id:u64)->p.Error {
    state:=cast(^Retired_Test)user
    for b in state.archived[:state.count] {if b.record.room==id{return .Denied}}
    return .None
}
reclaim_test :: proc(user:rawptr,h:^p.Hub)->p.Error {
    for room,i in h.rooms {
        if room==nil{continue}
        eligible,error:=p.hub_room_idle(h,i,1000)
        if error!=.None{return error}
        if eligible{return p.hub_archive_room(h,i,1000,archive_test,user)}
    }
    return .Capacity
}
retirement_setup :: proc(f:^Hub_Fixture,state:^Retired_Test){
    hub_setup(f,1);p.hub_close(&f.hub);state.fixture=f
    cfg:=p.HUB_CONFIG;cfg.content=55;cfg.rooms=1
    assert(p.hub_open(&f.hub,cfg,nil,hub_commit,&f.ledger,{&f.clock,clock_read},tr.memory_transport(&f.endpoints[0]),
        {&f.rng,random_read},creation_guard=guard_test,reclaim=reclaim_test,lifecycle_user=state)==.None)
}

@(test)
expired_rooms_are_archived_and_resident_capacity_is_reusable_without_id_reuse :: proc(t:^testing.T){
    f:Hub_Fixture;state:Retired_Test;retirement_setup(&f,&state);defer hub_destroy(&f)
    for i in 0..<6 {
        f.clock.now+=1100
        reply:=hub_call(&f,create_request(u64(44+i)))
        testing.expect_value(t,reply.result,p.Error.None)
        testing.expect_value(t,len(f.hub.rooms),1)
    }
    testing.expect_value(t,state.count,5)
    testing.expect(t,state.archived[0].record.room==44&&p.bundle_valid(state.archived[0]))
    testing.expect_value(t,hub_call(&f,create_request(44)).result,p.Error.Denied)
    testing.expect(t,!f.hub.poisoned&&f.hub.rooms[0].bundle.record.room==49)
}

@(test)
bootstrap_grace_and_live_lease_prevent_reclamation :: proc(t:^testing.T){
    f:Hub_Fixture;state:Retired_Test;retirement_setup(&f,&state);defer hub_destroy(&f)
    assert(hub_call(&f,create_request()).result==.None)
    testing.expect_value(t,hub_call(&f,create_request(45)).result,p.Error.Capacity)
    room:=f.hub.rooms[0]
    assert(auth.coordinator_start(&room.service.coordinator,{1,1},1,f.clock.now)==.None)
    f.clock.now+=1500
    testing.expect_value(t,hub_call(&f,create_request(45)).result,p.Error.Capacity)
    testing.expect(t,state.count==0&&f.hub.rooms[0]==room&&!f.hub.poisoned)
    f.clock.now+=1000
    testing.expect_value(t,hub_call(&f,create_request(45)).result,p.Error.None)
    testing.expect_value(t,state.count,1)
}

@(test)
failed_archive_preserves_owner_and_fences_uncertain_storage :: proc(t:^testing.T){
    f:Hub_Fixture;state:Retired_Test;retirement_setup(&f,&state);defer hub_destroy(&f)
    assert(hub_call(&f,create_request()).result==.None)
    before:=f.hub.rooms[0].bundle;state.fail=true;f.clock.now+=1100
    testing.expect_value(t,hub_call(&f,create_request(45)).result,p.Error.Storage)
    testing.expect(t,f.hub.poisoned&&f.hub.rooms[0]!=nil&&f.hub.rooms[0].bundle==before&&state.count==0)
}
