package replay_runner_host_test
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
