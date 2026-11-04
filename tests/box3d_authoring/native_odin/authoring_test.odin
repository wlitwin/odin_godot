package box3d_authoring_native_test

import "core:fmt"
import "core:mem"
import "core:testing"
import a "godot:box3d/authoring"
import b "godot:box3d"
import f "godot:tests/box3d_authoring/pure"

ok :: proc(t:^testing.T,status:b.Status,stage:string)->bool{testing.expect(t,status==.Ok,fmt.tprintf("%s status=%v",stage,status));return status==.Ok}
dump :: proc(t:^testing.T,world:b.World)->[]u8{
 size,status:=b.world_dump(world,{});if !ok(t,status,"dump size"){return {}}
 bytes:=make([]u8,int(size));_,status=b.world_dump(world,bytes);if !ok(t,status,"dump bytes"){delete(bytes);return {}};return bytes
}
cleanup0 :: proc(t:^testing.T){engine,e:=b.engine_allocation_stats();wrapper,w:=b.snapshot_allocation_stats();testing.expect(t,e==.Ok&&w==.Ok&&engine.live_bytes==0&&wrapper.live_bytes==0);fmt.printf("AUTHORING_CLEANUP native=%d wrapper=%d\n",engine.live_bytes,wrapper.live_bytes)}

@(test)
all_six_shapes_sensor_detached_sources_restore_and_canonical_roundtrip :: proc(t:^testing.T){
 backing:=context.allocator;tracking:mem.Tracking_Allocator;mem.tracking_allocator_init(&tracking,backing,backing);context.allocator=mem.tracking_allocator(&tracking)
 input:f.Fixture;f.fixture_init(&input)
 baked,problem:=a.bake(input.scene);built:a.Built_Scene;catalog:b.Recovery_Catalog;snapshot,decoded:b.Snapshot;scratch:b.World
 defer {
  if scratch!=0{ok(t,b.world_destroy(&scratch),"scratch cleanup")}
  if !b.snapshot_is_empty(&snapshot){ok(t,b.snapshot_destroy(&snapshot),"snapshot cleanup")}
  if !b.snapshot_is_empty(&decoded){ok(t,b.snapshot_destroy(&decoded),"decoded cleanup")}
  ok(t,a.built_destroy(&built),"built cleanup");a.destroy(&baked)
  if catalog._handle!=nil{ok(t,b.recovery_catalog_destroy(&catalog),"catalog cleanup")}
  cleanup0(t);testing.expect_value(t,tracking.current_memory_allocated,0)
  context.allocator=backing;mem.tracking_allocator_destroy(&tracking)
 }
 if !f.valid(t,problem){return}
 if !ok(t,b.authoring_asset_abi_check(),"actual C/Odin V2 layout"){return}
 built,problem=a.build(&baked,0x415554484f523501);if !f.valid(t,problem){return}
 testing.expect_value(t,len(built.bodies),8);testing.expect_value(t,len(built.shapes),8)
 // Baked input/resources may be destroyed before world use or canonical export.
 a.destroy(&baked);input.hull[1]={99,99,99};input.heights[0]=99
 identity,is:=b.recovery_catalog_identity(&built.catalog);if !ok(t,is,"catalog identity"){return};testing.expect_value(t,identity.recovery_format,u32(2))
 counts,cs:=b.world_counters(built.world);if !ok(t,cs,"real constructed counts"){return};testing.expect(t,counts.body_count==8&&counts.shape_count==8)
 status:b.Status;catalog,status=b.recovery_catalog_clone(&built.catalog);if !ok(t,status,"retain catalog"){return}
 snapshot,status=b.snapshot_capture(built.world);if !ok(t,status,"all-six/sensor snapshot"){return}
 original:=dump(t,built.world);if len(original)==0{return};defer delete(original)
 if !ok(t,b.world_step_fixed(built.world),"real fixed step")||!ok(t,b.snapshot_restore(built.world,&snapshot),"same-world complete restore"){return}
 restored:=dump(t,built.world);defer delete(restored);testing.expect(t,mem.compare(original,restored)==0,"complete solver/material/filter/sensor definition equality")
 required,ws:=b.recovery_write(&catalog,&snapshot,{});if !ok(t,ws,"canonical V2 size"){return}
 wire:=make([]u8,int(required));defer delete(wire);_,ws=b.recovery_write(&catalog,&snapshot,wire);if !ok(t,ws,"canonical V2 export"){return}
 decoded,status=b.recovery_read(&catalog,wire);if !ok(t,status,"canonical trusted authored import"){return}
 n,ns:=b.recovery_write(&catalog,&decoded,{});if !ok(t,ns,"reencode size"){return}
 again:=make([]u8,int(n));defer delete(again);_,ns=b.recovery_write(&catalog,&decoded,again);if !ok(t,ns,"canonical reencode"){return};testing.expect(t,mem.compare(wire,again)==0)
 if !ok(t,a.built_destroy(&built),"source world/catalog owner destroyed"){return}
 scratch,status=b.world_create(b.world_def_default());if !ok(t,status,"fresh scratch"){return}
 if !ok(t,b.snapshot_restore(scratch,&decoded),"cross-world canonical complete restore"){return}
 copied:=dump(t,scratch);defer delete(copied);testing.expect(t,mem.compare(original,copied)==0,"all normalized fields survive source/geometry-owner destruction")
 fmt.printf("AUTHORING_NATIVE six_shape_kinds=6 bodies=8 shapes=8 sensor=1 transformed_box_hull=1 full_normalized_equal=true wire_format=%d bytes=%d\n",identity.recovery_format,len(wire))
}

@(test)
malformed_canonical_and_mutated_bake_leave_live_world_unchanged :: proc(t:^testing.T){
 input:f.Fixture;f.fixture_init(&input);baked,p:=a.bake(input.scene);defer a.destroy(&baked);if !f.valid(t,p){return}
 built,build_problem:=a.build(&baked,0x415554484f523501);defer {ok(t,a.built_destroy(&built),"build drop");cleanup0(t)}
 if !f.valid(t,build_problem){return}
 snapshot,s:=b.snapshot_capture(built.world);if !ok(t,s,"capture"){return};defer ok(t,b.snapshot_destroy(&snapshot),"snapshot drop")
 before:=dump(t,built.world);defer delete(before)
 size,write_status:=b.recovery_write(&built.catalog,&snapshot,{});if !ok(t,write_status,"wire size"){return};wire:=make([]u8,int(size));defer delete(wire)
 _,write_status=b.recovery_write(&built.catalog,&snapshot,wire);if !ok(t,write_status,"wire export"){return}
 rejected,rs:=b.recovery_read(&built.catalog,wire[:len(wire)-1]);testing.expect(t,rs!=.Ok&&b.snapshot_is_empty(&rejected))
 wire[len(wire)-1]~=1;rejected,rs=b.recovery_read(&built.catalog,wire);testing.expect(t,rs!=.Ok&&b.snapshot_is_empty(&rejected))
 after:=dump(t,built.world);defer delete(after);testing.expect(t,mem.compare(before,after)==0)
 baked.data.shapes[0].definition.friction+=0.1
 failed,fp:=a.build(&baked,0x415554484f523501);defer ok(t,a.built_destroy(&failed),"unpublished failure cleanup")
 testing.expect(t,fp.error==.Corrupt&&failed.world==0&&failed.catalog._handle==nil)
}

@(test)
legacy_primitive_catalog_identity_and_v2_layout_compatibility :: proc(t:^testing.T){
 defer cleanup0(t)
 if !ok(t,b.authoring_asset_abi_check(),"layout72 actual C query"){return}
 config:=b.recovery_config_default();config.profile=0x415554484f523501
 assets:=[3]b.Recovery_Asset{b.recovery_asset_box(1,{1,1,1}),b.recovery_asset_sphere(2,{},1),b.recovery_asset_capsule(3,{0,-1,0},{0,1,0},0.5)}
 catalog,status:=b.recovery_catalog_create(config,assets[:]);if !ok(t,status,"legacy primitive constructor"){return};defer ok(t,b.recovery_catalog_destroy(&catalog),"legacy drop")
 identity,identity_status:=b.recovery_catalog_identity(&catalog);if ok(t,identity_status,"legacy identity"){testing.expect_value(t,identity.recovery_format,u32(1))}
 bad:=[1]b.Recovery_Asset_V2{{version=99,struct_bytes=u32(size_of(b.Recovery_Asset_V2)),base=assets[0]}}
 invalid,is:=b.recovery_catalog_create_v2(config,bad[:]);testing.expect(t,is!=.Ok&&invalid._handle==nil)
}
