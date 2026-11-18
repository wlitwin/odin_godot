package kit_box3d_test

import "core:testing"
import "base:runtime"
import b "godot:box3d"
import bg "godot:box3d/godot"
import p "godot:kit/physics"
import k "godot:kit/sim"
import n "godot:kit/net"

Drop_Host :: struct { refs: u32, deny: bool, reenter: ^k.Lane, checks: int }
drop_check :: proc "c" (user: rawptr,_:u32)->bg.Status { return (cast(^Drop_Host)user).refs>0 ? bg.OK : bg.INVALID_HANDLE }
drop_retain :: proc "c" (user: rawptr)->bg.Status { (cast(^Drop_Host)user).refs+=1;return bg.OK }
drop_release :: proc "c" (user: rawptr)->bg.Status {
    context = runtime.default_context()
    h:=cast(^Drop_Host)user
    if h.deny { return bg.CAPACITY }
    if h.reenter != nil {
        if k.lane_frame(h.reenter,1.0/60)==0 {h.checks+=1}
        _,error:=k.lane_world_checkpoint(h.reenter,0)
        if error==.Busy {h.checks+=1}
        if k.lane_destroy(h.reenter)==.Busy {h.checks+=1}
    }
    h.refs-=1
    return bg.OK
}
drop_owner :: proc(h:^Drop_Host)->k.World_Owner {
    assert(k.world_owner_realm_install(71)==.Ok)
    h.refs=1
    return {user=h,realm=71,context_caps=bg.MANAGED_DATA|bg.INDEPENDENT_CONTEXT,check=drop_check,retain=drop_retain,drop=drop_release}
}

@(test)
codec_cleanup_retains_refused_drop_and_rejects_reinitialization :: proc(t:^testing.T) {
    h:Drop_Host
    owner:=drop_owner(&h)
    c:p.Typed_Codec(u64)
    testing.expect_value(t,p.codec_init(&c,ownership={owner=owner,user=&c}),k.World_Error.Ok)
    value:=c.value
    testing.expect_value(t,value.acquire(value.user),k.World_Error.Ok)
    testing.expect_value(t,p.codec_destroy(&c),k.World_Error.Busy)
    testing.expect_value(t,value.release(value.user),k.World_Error.Ok)
    h.deny=true
    testing.expect_value(t,p.codec_destroy(&c),k.World_Error.Rejected)
    testing.expect(t,c.closing && !c.schema.initialized)
    testing.expect_value(t,p.codec_init(&c,ownership={owner=owner,user=&c}),k.World_Error.Invalid)
    testing.expect_value(t,value.acquire(value.user),k.World_Error.Busy)
    h.deny=false
    testing.expect_value(t,p.codec_destroy(&c),k.World_Error.Ok)
    testing.expect_value(t,p.codec_destroy(&c),k.World_Error.Ok)
    testing.expect_value(t,h.refs,1)
    testing.expect_value(t,k.world_owner_drop(owner),k.World_Error.Ok)
}

@(test)
codec_init_rollback_preserves_its_refused_owner :: proc(t:^testing.T) {
    h:Drop_Host
    owner:=drop_owner(&h)
    h.deny=true
    c:p.Typed_Codec(u64)
    fields:[n.MAX_REPLICATED_FIELDS+1]n.Field_Desc
    desc:=n.Entity_Desc{fields=fields[:]}
    testing.expect_value(t,p.codec_init(&c,&desc,ownership={owner=owner,user=&c}),k.World_Error.Capacity)
    testing.expect(t,c.closing && !k.world_owner_is_empty(c.owner))
    testing.expect_value(t,h.refs,2)
    h.deny=false
    testing.expect_value(t,p.codec_destroy(&c),k.World_Error.Ok)
    testing.expect_value(t,k.world_owner_drop(owner),k.World_Error.Ok)
}

@(test)
network_cleanup_only_owner_survives_refused_final_drop :: proc(t:^testing.T) {
    h:Drop_Host
    owner:=drop_owner(&h)
    testing.expect_value(t,k.world_owner_retain(owner),k.World_Error.Ok)
    network:=p.Network(u64){owner=owner}
    h.deny=true
    testing.expect_value(t,p.network_destroy(&network),k.World_Error.Rejected)
    testing.expect(t,!k.world_owner_is_empty(network.owner))
    h.deny=false
    testing.expect_value(t,p.network_destroy(&network),k.World_Error.Ok)
    testing.expect_value(t,p.network_destroy(&network),k.World_Error.Ok)
    testing.expect_value(t,h.refs,1)
    testing.expect_value(t,k.world_owner_drop(owner),k.World_Error.Ok)
}

@(test)
provider_detach_keeps_refused_temporary_retain_for_retry :: proc(t:^testing.T) {
    h:Drop_Host
    owner:=drop_owner(&h)
    f:Fixture
    testing.expect_value(t,init(&f,cfg={asset_id=123,provider_owner=owner,provider_user=&f.p}),k.World_Error.Ok)
    h.deny=true
    testing.expect(t,p.detach(&f.p)!=.Ok)
    testing.expect(t,!k.world_owner_is_empty(f.p.detach_pending))
    h.deny=false
    for _ in 0..<4 {
        if p.detach(&f.p)==.Ok { break }
    }
    testing.expect(t,f.p.lane==nil && k.world_owner_is_empty(f.p.detach_pending))
    destroy(&f)
    testing.expect_value(t,h.refs,1)
    testing.expect_value(t,k.world_owner_drop(owner),k.World_Error.Ok)
}

close_lane: ^k.Lane
original_close: proc(rawptr)
close_reentry_checks: int

@(test)
provider_close_cannot_reenter_freed_history :: proc(t:^testing.T) {
    f:Fixture
    testing.expect_value(t,init(&f),k.World_Error.Ok)
    close_lane=&f.lane
    original_close=f.lane.world.provider.close
    close_reentry_checks=0
    f.lane.world.provider.close=proc(execution:rawptr) {
        if k.lane_frame(close_lane,1.0/60)==0 { close_reentry_checks+=1 }
        _,error:=k.lane_world_checkpoint(close_lane,0)
        if error==.Busy {close_reentry_checks+=1}
        if k.lane_world_detach(close_lane)==.Busy {close_reentry_checks+=1}
        original_close(execution)
    }
    testing.expect_value(t,p.detach(&f.p),k.World_Error.Ok)
    testing.expect_value(t,close_reentry_checks,3)
    testing.expect_value(t,k.lane_destroy(&f.lane),k.World_Error.Ok)
    close_lane=nil
    original_close=nil
}

Release_Probe :: struct { deny:bool, released:int }

@(test)
network_partial_release_keeps_buffers_and_does_not_repeat_successful_drops :: proc(t:^testing.T) {
    f:Fixture
    testing.expect_value(t,init(&f),k.World_Error.Ok)
    h:Drop_Host
    owner:=drop_owner(&h)
    testing.expect_value(t,k.world_owner_retain(owner),k.World_Error.Ok)
    released:=Release_Probe{deny=true}
    network:=new(k.World_Network,f.lane.allocator)
    network.config.codec.owner=owner
    network.wire_owned=true
    network.ready=true
    network.accepted_data=make([]u8,16,f.lane.allocator)
    network.accepted_data[0]=87
    network.owned_codecs[0]={user=&released,release=proc(user:rawptr)->k.World_Error {
        state:=cast(^Release_Probe)user
        if state.deny {return .Rejected}
        state.released+=1
        return .Ok
    }}
    network.owned_codec_count=1
    f.lane.world.network=network
    testing.expect_value(t,k.lane_world_network_detach(&f.lane),k.World_Error.Rejected)
    testing.expect_value(t,network.accepted_data[0],87)
    testing.expect_value(t,network.owned_codec_count,1)
    testing.expect_value(t,k.lane_frame(&f.lane,1.0/60),0)
    released.deny=false;h.deny=true
    testing.expect_value(t,k.lane_world_network_detach(&f.lane),k.World_Error.Rejected)
    testing.expect_value(t,released.released,1)
    testing.expect_value(t,network.owned_codec_count,0)
    testing.expect_value(t,network.accepted_data[0],87)
    h.deny=false
    testing.expect_value(t,k.lane_world_network_detach(&f.lane),k.World_Error.Ok)
    testing.expect_value(t,released.released,1)
    testing.expect(t,f.lane.world.network==nil)
    destroy(&f)
    testing.expect_value(t,h.refs,1)
    testing.expect_value(t,k.world_owner_drop(owner),k.World_Error.Ok)
}

@(test)
final_lane_owner_drop_remains_reentry_guarded_after_container_retirement :: proc(t:^testing.T) {
    h:Drop_Host
    owner:=drop_owner(&h)
    f:Fixture
    testing.expect_value(t,init(&f,cfg={asset_id=123,provider_owner=owner,provider_user=&f.p}),k.World_Error.Ok)
    h.reenter=&f.lane
    testing.expect_value(t,k.lane_destroy(&f.lane),k.World_Error.Ok)
    testing.expect_value(t,h.checks,3)
    h.reenter=nil
    testing.expect_value(t,p.detach(&f.p),k.World_Error.Ok)
    testing.expect_value(t,k.world_owner_drop(owner),k.World_Error.Ok)
}
