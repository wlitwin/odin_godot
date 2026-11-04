#+build wasm32, wasm64p32
package core

import "base:intrinsics"
import "core:fmt"
import gd "godot:godot"
import bg "godot:box3d/godot"
import bh "godot:box3d/godot/host"
import meter "godot:box3d/godot/meter"

@(private)
BOX3D_HOST_ENABLED :: #config(BOX3D_HOST_ENABLED, false)
@(private)
Box3D_Web_Image :: struct {
 alive:bool,
 thread,table_base,table_size:uintptr,
 references:u64,
 service:bg.Service,
}
@(private)
box3d_web_image:Box3D_Web_Image

when BOX3D_HOST_ENABLED {
 @(private)
 BOX3D_WEB_ARCHIVE :: #config(BOX3D_LIBRARY, "")
 foreign import box3d_aot "env.o"
 foreign box3d_aot {
  @(link_name="ogb3_domain_contract_get")
  web_domain_get :: proc "c"(^bg.Domain_Contract)->bg.Status ---
  @(link_name="ogb3_engine_allocation_stats")
  web_engine_stats :: proc "c"(^bg.Allocation_Stats)->bg.Status ---
  @(link_name="ogb3_snapshot_allocation_stats")
  web_wrapper_stats :: proc "c"(^bg.Allocation_Stats)->bg.Status ---
  @(link_name="ogb3_host_owner_open")
  web_owner_open :: proc "c"(u64,u64,u64,^u64)->bg.Status ---
  @(link_name="ogb3_host_owner_set")
  web_owner_set :: proc "c"(u64,u64,u64,u64)->bg.Status ---
  @(link_name="ogb3_host_owner_close")
  web_owner_close :: proc "c"(u64,u64)->bg.Status ---
  @(link_name="ogb3_host_ledger_get")
  web_ledger_get :: proc "c"(u64,^bg.Ledger_Stats)->bg.Status ---
  odin_box3d_table_base :: proc "c"()->uintptr ---
  odin_box3d_table_size :: proc "c"()->u32 ---
  odin_box3d_thread_id :: proc "c"()->uintptr ---
  odin_box3d_managed_lock :: proc "c"() ---
  odin_box3d_managed_unlock :: proc "c"() ---
  odin_box3d_managed_mutex_bytes :: proc "c"()->u32 ---
 }
}

@(private)
box3d_web_on_thread :: proc "contextless"()->bool {
 when BOX3D_HOST_ENABLED {
  return !box3d_web_image.alive||odin_box3d_thread_id()==box3d_web_image.thread
 } else {return true}
}
@(private)
box3d_web_required :: proc "contextless"()->bool {
 when BOX3D_HOST_ENABLED {return bg.module_profile()!=0} else {return false}
}
@(private)
box3d_web_gate_enter :: proc "c"(_:rawptr)->bg.Status {
 if !box3d_web_on_thread(){return bg.UNSUPPORTED}
 script_access_enter();return bg.OK
}
@(private)
box3d_web_gate_leave :: proc "c"(_:rawptr){script_access_leave()}
@(private)
box3d_web_protected :: proc "c"(_:rawptr)->bg.Status {
 if !box3d_web_on_thread(){return bg.UNSUPPORTED}
 return web_script_access_depth>0?bg.OK:bg.INCOMPATIBLE
}
@(private)
box3d_web_pin :: proc "contextless"(code:rawptr){
 if code!=&box3d_web_image||!box3d_web_image.alive||box3d_web_image.references==max(u64){intrinsics.trap()}
 box3d_web_image.references+=1
}
@(private)
box3d_web_unpin :: proc "contextless"(code:rawptr){
 if code!=&box3d_web_image||box3d_web_image.references==0{intrinsics.trap()}
 box3d_web_image.references-=1
}
@(private)
box3d_web_code_retain :: proc "c"(_:rawptr,code:rawptr){box3d_web_pin(code)}
@(private)
box3d_web_code_drop :: proc "c"(_:rawptr,code:rawptr){box3d_web_unpin(code)}
@(private)
box3d_web_procedure :: proc "c"(_:rawptr,code,address:rawptr)->bg.Status {
 if code!=&box3d_web_image||!box3d_web_image.alive||address==nil{return bg.INCOMPATIBLE}
 index:=uintptr(address);base:=box3d_web_image.table_base;count:=box3d_web_image.table_size
 if count==0||index<base||index-base>=count{return bg.INCOMPATIBLE}
 return bg.OK
}

// All Core and script packages share one real permanent AOT image. The producer
// owns actual contexts/leases/accounting; permanence replaces loader retention,
// never the data/weak-instance/procedure-origin checks.
@(private)
box3d_web_initialize :: proc()->bool {
 when !BOX3D_HOST_ENABLED {return true} else {
  if !box3d_web_required(){return true}
  if box3d_web_image.alive{return true}
  actual,declared:bg.Domain_Contract
  if web_domain_get(&actual)!=bg.OK||bg.module_contract(&declared)!=bg.OK||actual!=declared{return false}
  if actual.cookie==0||actual.size!=size_of(bg.Domain_Contract)||actual.version!=1||actual.abi_version!=1||actual.logical_version!=4||actual.resource_version!=2||actual.recovery_version!=1||actual.pointer_bits!=32||actual.endian!=1{return false}
  base,count:=odin_box3d_table_base(),uintptr(odin_box3d_table_size())
  if count==0||base>max(uintptr)-count{return false}
  box3d_web_image={alive=true,thread=odin_box3d_thread_id(),table_base=base,table_size=count,references=1}
  api:=bg.Native_API{contract=actual,engine_stats=web_engine_stats,wrapper_stats=web_wrapper_stats,owner_open=web_owner_open,owner_set=web_owner_set,owner_close=web_owner_close,ledger_get=web_ledger_get}
  hooks:=bg.Core_Hooks{enter=box3d_web_gate_enter,leave=box3d_web_gate_leave,protected=box3d_web_protected,code_retain=box3d_web_code_retain,code_drop=box3d_web_code_drop,procedure=box3d_web_procedure}
  script_access_enter();defer script_access_leave()
  if bh.registry_init(api,hooks)!=bg.OK{box3d_web_image.alive=false;return false}
  service:bg.Service
  if bh.producer_create(&box3d_web_image,&service)!=bg.OK{_=bh.registry_shutdown();box3d_web_image.alive=false;return false}
  scope,status:=bh.origin_enter(service.user)
  if status!=bg.OK{_=bh.producer_destroy(service.user);_=bh.registry_shutdown();box3d_web_image.alive=false;return false}
  installed:=bg.module_install(&service)
  bh.origin_leave(scope)
  if installed!=bg.OK{_=bh.producer_destroy(service.user);_=bh.registry_shutdown();box3d_web_image.alive=false;return false}
  box3d_web_image.service=service
  backing:=web_aligned_allocator()
  if box3d_web_procedure(nil,&box3d_web_image,cast(rawptr)backing.procedure)!=bg.OK || meter.install_web_backing(backing)!=bg.OK {
   _=bh.producer_destroy(service.user);_=bh.registry_shutdown();box3d_web_image.alive=false;return false
  }
  if !managed_callable_web_install(){return false}
  return true
 }
}

@(private)
box3d_origin_enter :: proc "contextless"(opaque:rawptr,weak:u64=0)->(bg.Origin_Scope,bg.Status){
 if !box3d_web_required(){return {},bg.OK}
 if opaque!=&box3d_web_image||!box3d_web_image.alive{return {},bg.INCOMPATIBLE}
 return bh.origin_enter(box3d_web_image.service.user,weak)
}
@(private)
box3d_origin_leave :: proc "contextless"(scope:bg.Origin_Scope){bh.origin_leave(scope)}
@(private)
box3d_context_create :: proc "contextless"(opaque:rawptr)->u64 {
 if !box3d_web_required(){return 0}
 scope,status:=box3d_origin_enter(opaque);if status!=bg.OK{return 0};defer box3d_origin_leave(scope)
 token:u64;if bh.context_create(box3d_web_image.service.user,&token)!=bg.OK{return 0};return token
}
@(private)
box3d_context_bind :: proc "contextless"(token:u64,base:rawptr,size:u64){if token!=0&&base!=nil&&size!=0{_=bh.context_bind(token,base,size)}}
@(private)
box3d_context_invalidate :: proc "contextless"(token:u64){if token!=0{_=bh.context_invalidate(token)}}
@(private)
box3d_context_release :: proc "contextless"(token:u64){if token!=0{_=bh.context_release(token)}}
@(private)
box3d_typed_instance_allowed :: proc "contextless"(opaque:rawptr)->bool {
 if !box3d_web_required(){return true}
 return opaque==&box3d_web_image&&box3d_web_image.alive&&box3d_web_protected(nil)==bg.OK&&bh.current_realm()==box3d_web_image.service.realm
}
@(private)
box3d_host_shutdown :: proc()->bg.Status {
 when !BOX3D_HOST_ENABLED {return bg.OK} else {
  if !box3d_web_image.alive{return bg.OK}
  if !box3d_web_on_thread(){return bg.UNSUPPORTED}
  script_access_enter();defer script_access_leave()
  status:=bh.producer_destroy(box3d_web_image.service.user);if status!=bg.OK{stats:=bh.registry_stats();gd.print_str(fmt.tprintf("ODIN_BOX3D_WEB_SHUTDOWN_REFUSED status=%d producers=%d owners=%d capsules=%d contexts=%d marks=%d",i32(status),stats.producers,stats.owners,stats.capsules,stats.contexts,stats.marks));return status}
  status=bh.registry_shutdown();if status!=bg.OK{return status}
  box3d_web_image.service={};box3d_web_image.alive=false
  // The code itself remains linked for the page lifetime. Remaining class-map
  // references are real pins and may be dropped during final engine teardown.
  return bg.OK
 }
}
