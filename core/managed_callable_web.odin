#+build wasm32, wasm64p32
package core

import bg "godot:box3d/godot"
import rt "godot:runtime"

// Metadata can be finalized by a Godot worker. Its actual mutex lives in the
// same permanent C image; no producer callback runs from that free path.
Managed_Mutex :: struct {}
MANAGED_GENERATION_MAX :: u32(65535)
managed_lock :: proc "contextless"(){when BOX3D_HOST_ENABLED{odin_box3d_managed_lock()}}
managed_unlock :: proc "contextless"(){when BOX3D_HOST_ENABLED{odin_box3d_managed_unlock()}}
managed_platform_storage_bytes :: proc "contextless"()->u64{when BOX3D_HOST_ENABLED{return u64(odin_box3d_managed_mutex_bytes())}else{return 0}}
managed_host_ready :: proc "contextless"()->bool{return box3d_web_image.alive}
managed_host_on_thread :: proc "contextless"()->bool{return box3d_web_on_thread()}
managed_host_protected :: proc "contextless"()->bg.Status{return box3d_web_protected(nil)}
managed_host_enter :: proc "contextless"()->bg.Status{return box3d_web_gate_enter(nil)}
managed_host_leave :: proc "contextless"(){box3d_web_gate_leave(nil)}
managed_host_domain_get :: proc "contextless"(out:^bg.Domain_Contract)->bg.Status{when BOX3D_HOST_ENABLED{return web_domain_get(out)}else{return bg.UNSUPPORTED}}
managed_host_owner_open :: proc "contextless"(cookie,producer,component:u64,out:^u64)->bg.Status{when BOX3D_HOST_ENABLED{return web_owner_open(cookie,producer,component,out)}else{return bg.UNSUPPORTED}}
managed_host_owner_set :: proc "contextless"(cookie,token,live,reserved:u64)->bg.Status{when BOX3D_HOST_ENABLED{return web_owner_set(cookie,token,live,reserved)}else{return bg.UNSUPPORTED}}
managed_host_owner_close :: proc "contextless"(cookie,token:u64)->bg.Status{when BOX3D_HOST_ENABLED{return web_owner_close(cookie,token)}else{return bg.UNSUPPORTED}}
managed_callable_web_install :: proc()->bool{
 if !box3d_web_image.alive{return true}
 if managed_initialize()!=bg.OK{return false}
 api:=rt.Managed_Callable_API{size=size_of(rt.Managed_Callable_API),version=rt.MANAGED_CALLABLE_VERSION,fingerprint=rt.managed_callable_fingerprint(),create=managed_callable_core_create,close=managed_callable_core_close,collect=managed_callable_core_collect,stats=managed_callable_core_stats}
 return rt.odin_scripts_set_managed_callable_api(&api)==bg.OK
}
