package kit_slice_cache_test

import "core:testing"
import bg "godot:box3d/godot"
import bh "godot:box3d/godot/host"
import bm "godot:box3d/godot/meter"
import b "godot:box3d"
import p "godot:kit/physics"
import sim "godot:kit/sim"
import s "godot:kit/session"
import n "godot:kit/net"
import common "godot:examples/box3d_common"

LIB :: #config(BOX3D_LIBRARY,"")
foreign import native {"system:"+LIB}
when ODIN_OS==.Linux {foreign import math "system:m"}
foreign native {
 @(link_name="ogb3_domain_contract_get") contract_get::proc(^bg.Domain_Contract)->bg.Status---
 @(link_name="ogb3_engine_allocation_stats") engine_stats::proc(^bg.Allocation_Stats)->bg.Status---
 @(link_name="ogb3_snapshot_allocation_stats") wrapper_stats::proc(^bg.Allocation_Stats)->bg.Status---
 @(link_name="ogb3_host_owner_open") owner_open::proc(u64,u64,u64,^u64)->bg.Status---
 @(link_name="ogb3_host_owner_set") owner_set::proc(u64,u64,u64,u64)->bg.Status---
 @(link_name="ogb3_host_owner_close") owner_close::proc(u64,u64)->bg.Status---
 @(link_name="ogb3_host_ledger_get") ledger_get::proc(u64,^bg.Ledger_Stats)->bg.Status---
}
Code :: struct {references:u64}
@(private) depth:u32
enter :: proc "c"(_:rawptr)->bg.Status {depth+=1;return bg.OK}
leave :: proc "c"(_:rawptr) {depth-=1}
protected :: proc "c"(_:rawptr)->bg.Status {return depth!=0?bg.OK:bg.INCOMPATIBLE}
pin :: proc "c"(_:rawptr,code:rawptr) {(cast(^Code)code).references+=1}
unpin :: proc "c"(_:rawptr,code:rawptr) {(cast(^Code)code).references-=1}
// Unit-only procedure validator. Actual SDK validation belongs to Core dladdr.
procedure :: proc "c"(_:rawptr,_:rawptr,code:rawptr)->bg.Status {return code!=nil?bg.OK:bg.INCOMPATIBLE}
Source :: struct {lane:sim.Lane,ses:s.Session,physics:p.Instance(common.Game),proxy:u32}

@(test)
bulk_cache_survives_source_free_and_preserves_output_on_capacity_or_guard_failure :: proc(t:^testing.T) {
 contract:bg.Domain_Contract;testing.expect_value(t,contract_get(&contract),bg.OK)
 api:=bg.Native_API{contract,engine_stats,wrapper_stats,owner_open,owner_set,owner_close,ledger_get}
 testing.expect_value(t,bh.registry_init(api,{enter=enter,leave=leave,protected=protected,code_retain=pin,code_drop=unpin,procedure=procedure}),bg.OK)
 code:Code;service:bg.Service;testing.expect_value(t,bh.producer_create(&code,&service),bg.OK)
 testing.expect_value(t,bg.module_install(&service),bg.OK)
 testing.expect_value(t,enter(nil),bg.OK);previous,status:=bh.origin_enter(service.user);testing.expect_value(t,status,bg.OK)
 weak:u64;testing.expect_value(t,bh.context_create(service.user,&weak),bg.OK)
 backing:=context.allocator;instance:=new(u64,backing)
 testing.expect_value(t,bh.context_bind(weak,instance,8),bg.OK)
 bh.origin_leave(previous);previous,status=bh.origin_enter(service.user,weak);testing.expect_value(t,status,bg.OK)
 managed,me:=p.sdk_context_create();testing.expect_value(t,me,sim.World_Error.Ok)
 alloc:=bm.allocator(managed.memory);context.allocator=alloc
 source:=new(Source,alloc);source.ses.is_host=true;source.ses.me=1;source.ses.allocator=alloc
 sim.lane_init(&source.lane,&source.ses,0,allocator=alloc)
 @(static) fields:=[]n.Field_Desc{{offset=0,size=4,flags={.Predicted}}}
 descriptor:=n.Entity_Desc{fields=fields}
 sim.lane_track(&source.lane,1,&source.proxy,&descriptor,1)
 provider,pe:=p.sdk_user_owner_create(managed.memory,source,u64(size_of(source^)),&source.physics,u64(size_of(source.physics)))
 testing.expect_value(t,pe,sim.World_Error.Ok)
 world,game,ws:=common.world(4,1);testing.expect_value(t,ws,b.Status.Ok)
 testing.expect_value(t,p.attach(&source.physics,&source.lane,&world,game,[]sim.World_Field_Type{sim.world_field_type(1,u32)},p.sdk_context_config(managed,common.ASSET_DECLARATION,provider=provider)),sim.World_Error.Ok)
 checkpoint,ce:=sim.lane_world_checkpoint(&source.lane,0);testing.expect_value(t,ce,sim.World_Error.Ok)
 testing.expect_value(t,p.detach(&source.physics),sim.World_Error.Ok)
 sim.lane_destroy(&source.lane);s.session_destroy(&source.ses)
 free(source,alloc);testing.expect_value(t,p.sdk_user_owner_destroy(&provider),sim.World_Error.Ok)
 testing.expect_value(t,bh.context_invalidate(weak),bg.OK);free(instance,backing);testing.expect_value(t,bh.context_release(weak),bg.OK)
 count,query:=p.checkpoint_body_states(&checkpoint,nil,common.Game)
 testing.expect_value(t,query,sim.World_Error.Ok);testing.expect_value(t,count,u32(6))
 small:[1]b.Body_State;small[0].pose.position={123,456,789};unchanged:=small
 required,capacity:=p.checkpoint_body_states(&checkpoint,small[:],common.Game)
 testing.expect_value(t,capacity,sim.World_Error.Capacity);testing.expect_value(t,required,u32(6));testing.expect_value(t,small,unchanged)
 invalid:=checkpoint;invalid.owner.realm+=1
 _,foreign_error:=p.checkpoint_body_states(&invalid,small[:],common.Game);testing.expect_value(t,foreign_error,sim.World_Error.Incompatible);testing.expect_value(t,small,unchanged)
 _,type_error:=p.checkpoint_body_states(&checkpoint,small[:],u64);testing.expect_value(t,type_error,sim.World_Error.Incompatible);testing.expect_value(t,small,unchanged)
 invalid=checkpoint;invalid.asset_id+=1
 _,asset_error:=p.checkpoint_body_states(&invalid,small[:],common.Game);testing.expect_value(t,asset_error,sim.World_Error.Incompatible);testing.expect_value(t,small,unchanged)
 states:[35]b.Body_State
 engine_before,es:=b.engine_allocation_stats();wrapper_before,wrs:=b.snapshot_allocation_stats();testing.expect_value(t,es,b.Status.Ok);testing.expect_value(t,wrs,b.Status.Ok)
 for _ in 0..<16 {
  count,read:=p.checkpoint_body_states(&checkpoint,states[:],common.Game);testing.expect_value(t,count,u32(6));testing.expect_value(t,read,sim.World_Error.Ok)
 }
 for state in states[:count] {
  one,error:=p.checkpoint_body_state(&checkpoint,state.key,common.Game);testing.expect_value(t,error,sim.World_Error.Ok);testing.expect_value(t,one,state)
 }
 engine_after,_:=b.engine_allocation_stats();wrapper_after,_:=b.snapshot_allocation_stats()
 testing.expect_value(t,engine_after,engine_before);testing.expect_value(t,wrapper_after,wrapper_before)
 testing.expect_value(t,sim.world_checkpoint_destroy(&checkpoint),sim.World_Error.Ok)
 testing.expect_value(t,p.sdk_context_destroy(&managed),sim.World_Error.Ok)
 testing.expect_value(t,p.owned_bytes(),u64(0));testing.expect_value(t,sim.world_checkpoint_owned_bytes(),u64(0))
 bh.origin_leave(previous);leave(nil)
 testing.expect_value(t,code.references,u64(0));testing.expect_value(t,bh.producer_destroy(service.user),bg.OK);testing.expect_value(t,bh.registry_shutdown(),bg.OK)
}
