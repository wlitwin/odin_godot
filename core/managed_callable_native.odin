#+build darwin, linux, windows
package core

import "core:sync"
import bg "godot:box3d/godot"
import rt "godot:runtime"

Managed_Mutex :: sync.Mutex
MANAGED_GENERATION_MAX :: max(u32)
managed_lock :: proc "contextless"(){sync.lock(&managed_state.mutex)}
managed_unlock :: proc "contextless"(){sync.unlock(&managed_state.mutex)}
managed_platform_storage_bytes :: proc "contextless"()->u64{return 0}
managed_host_ready :: proc "contextless"()->bool{return box3d_initialized}
managed_host_on_thread :: proc "contextless"()->bool{return sync.current_thread_id()==box3d_main_thread}
managed_host_protected :: proc "contextless"()->bg.Status{return box3d_protected(nil)}
managed_host_enter :: proc "contextless"()->bg.Status{return box3d_gate_enter(nil)}
managed_host_leave :: proc "contextless"(){box3d_gate_leave(nil)}
managed_host_domain_get :: proc "contextless"(out:^bg.Domain_Contract)->bg.Status{return box3d_native.ogb3_domain_contract_get(out)}
managed_host_owner_open :: proc "contextless"(cookie,producer,component:u64,out:^u64)->bg.Status{return box3d_native.ogb3_host_owner_open(cookie,producer,component,out)}
managed_host_owner_set :: proc "contextless"(cookie,token,live,reserved:u64)->bg.Status{return box3d_native.ogb3_host_owner_set(cookie,token,live,reserved)}
managed_host_owner_close :: proc "contextless"(cookie,token:u64)->bg.Status{return box3d_native.ogb3_host_owner_close(cookie,token)}

// Called only after the generation's Host Service has been installed. No
// optional managed callbacks are installed into default/native-free modules.
managed_callable_generation_install :: proc(gen: ^Script_Generation) -> bool {
	if gen == nil || gen.box3d_service.realm == 0 {return true}
	dll := &gen.dll
	if dll.odin_scripts_managed_callable_protocol == nil &&
	   dll.odin_scripts_set_managed_callable_api == nil {return true}
	if dll.odin_scripts_managed_callable_protocol == nil ||
	   dll.odin_scripts_set_managed_callable_api == nil ||
	   dll.odin_scripts_managed_callable_protocol() !=
		   rt.managed_callable_fingerprint() {return false}
	if managed_initialize() != bg.OK {return false}
	api := rt.Managed_Callable_API {
		size        = size_of(rt.Managed_Callable_API),
		version     = rt.MANAGED_CALLABLE_VERSION,
		fingerprint = rt.managed_callable_fingerprint(),
		create      = managed_callable_core_create,
		close       = managed_callable_core_close,
		collect     = managed_callable_core_collect,
		stats       = managed_callable_core_stats,
	}
	return dll.odin_scripts_set_managed_callable_api(&api) == bg.OK
}

