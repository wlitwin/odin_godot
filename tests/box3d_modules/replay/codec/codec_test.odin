package replay_codec_host_test
import "core:testing"
import "core:mem"
import "base:runtime"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import bh "godot:box3d/godot/host"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import ph "godot:replay/physics"
import r "godot:replay"
import net "godot:replay/net"
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
Code :: struct {refs:u32}
Gate :: struct {depth:u32,code:Code}
@(private) gate:Gate
enter :: proc "c"(rawptr)->bg.Status{gate.depth+=1;return bg.OK}
leave :: proc "c"(rawptr){gate.depth-=1}
protected :: proc "c"(rawptr)->bg.Status{return gate.depth>0?bg.OK:bg.INCOMPATIBLE}
code_retain :: proc "c"(rawptr,pointer:rawptr){(cast(^Code)pointer).refs+=1}
code_drop :: proc "c"(rawptr,pointer:rawptr){(cast(^Code)pointer).refs-=1}
// Test gate only: actual Core uses loaded-image membership via dladdr.
procedure :: proc "c"(_:rawptr,_:rawptr,pointer:rawptr)->bg.Status{return pointer!=nil?bg.OK:bg.INCOMPATIBLE}



Managed_Codec :: struct {references:u32,allocator:mem.Allocator,codec:ph.Network_Codec(u64,i64,i64,i64,1)}
@(private) freed:u64
retain_data :: proc "c"(pointer:rawptr)->bg.Status {
 managed:=cast(^Managed_Codec)(uintptr(pointer)-offset_of(Managed_Codec,codec));managed.references+=1;return bg.OK
}
drop_data :: proc "c"(pointer:rawptr)->bg.Status {
 context=runtime.default_context()
 managed:=cast(^Managed_Codec)(uintptr(pointer)-offset_of(Managed_Codec,codec));managed.references-=1
 if managed.references==0{freed+=1;mem.free(managed,managed.allocator)}
 return bg.OK
}
@(test)
actual_codec_budget_callbacks_retain_managed_context_after_source_owner_release :: proc(t:^testing.T){
 contract:bg.Domain_Contract;testing.expect_value(t,contract_get(&contract),bg.OK)
 api:=bg.Native_API{contract,engine_stats,wrapper_stats,owner_open,owner_set,owner_close,ledger_get}
 hooks:=bg.Core_Hooks{enter=enter,leave=leave,protected=protected,code_retain=code_retain,code_drop=code_drop,procedure=procedure}
 testing.expect_value(t,bh.registry_init(api,hooks),bg.OK)
 service:bg.Service;testing.expect_value(t,bh.producer_create(&gate.code,&service),bg.OK)
 testing.expect_value(t,bg.module_install(&service),bg.OK)
 testing.expect_value(t,enter(nil),bg.OK);scope,status:=bh.origin_enter(service.user);testing.expect_value(t,status,bg.OK)
 meter_context,ms:=meter.create(service,bg.CATEGORY_REPLAY_PROVIDER);testing.expect_value(t,ms,bg.OK)
 alloc:=meter.allocator(meter_context)
 image_owner,io:=ph.owner_context_create(meter.data_lease(meter_context),allocator_data=alloc.data,require_live_instance=false);testing.expect_value(t,io,r.Error.None)
 managed:=new(Managed_Codec,alloc);managed.references=1;managed.allocator=alloc
 lease:=bg.Data_Lease{user=&managed.codec,retain=retain_data,drop=drop_data}
 context_owner,co:=ph.owner_context_create(lease,user_data=&managed.codec,require_live_instance=false);testing.expect_value(t,co,r.Error.None)
 config:=b.recovery_config_default();config.profile=17
 assets:=[]b.Recovery_Asset{b.recovery_asset_box(1,{.25,.25,.25}),b.recovery_asset_sphere(2,{},.25)}
 catalog,cs:=b.recovery_catalog_create(config,assets);testing.expect_value(t,cs,b.Status.Ok)
 provider:=ph.config_default(9,b.build_fingerprint())
 rules:=bd.hash_bytes([]u8{1,2,3})
 codec:=&managed.codec
 testing.expect_value(t,ph.network_codec_init(codec,&catalog,provider,rules,allocator=alloc,ownership=image_owner,context_ownership=context_owner),net.Error.None)
 testing.expect_value(t,b.recovery_catalog_destroy(&catalog),b.Status.Ok)
 testing.expect_value(t,ph.owner_context_destroy(&context_owner),r.Error.None)
 // This drops the actual source allocation reference, not merely a still-live
 // stack fixture. Only the explicit retained codec context now prevents free.
 testing.expect_value(t,drop_data(codec),bg.OK);managed=nil
 testing.expect_value(t,freed,u64(0))
 testing.expect_value(t,codec.value.reserve(codec.value.catalog,256),net.Error.None)
 testing.expect_value(t,ph.network_codec_destroy(codec),net.Error.Wrong_Phase)
 testing.expect_value(t,freed,u64(0))
 codec.value.release(codec.value.catalog,256)
 testing.expect_value(t,ph.network_codec_destroy(codec),net.Error.None)
 codec=nil;testing.expect_value(t,freed,u64(1))
 testing.expect_value(t,ph.owner_context_destroy(&image_owner),r.Error.None)
 testing.expect_value(t,meter.destroy(&meter_context),bg.OK)
 testing.expect_value(t,ph.allocation_stats().live_bytes,u64(0))
 testing.expect_value(t,bh.registry_stats().marks,u32(0));testing.expect_value(t,bh.registry_stats().owners,u32(0))
 bh.origin_leave(scope);leave(nil)
 testing.expect_value(t,bh.producer_destroy(service.user),bg.OK);testing.expect_value(t,bh.registry_shutdown(),bg.OK)
 testing.expect_value(t,gate.code.refs,u32(0));testing.expect_value(t,gate.depth,u32(0))
}
