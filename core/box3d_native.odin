#+build darwin, linux, windows
package core

import "core:dynlib"
import "core:strings"
import "core:sync"
import bg "godot:box3d/godot"
import bh "godot:box3d/godot/host"

// Native-free unless the coordinator's optional build profile enables this.
// The backend is resolved ONLY beside the actual Core image, never PATH/env.
@(private)
BOX3D_HOST_ENABLED :: #config(BOX3D_HOST_ENABLED, false)
@(private)
Box3D_Native :: struct {
	__handle:                                                     dynlib.Library,
	ogb3_domain_contract_get:                                     proc "c" (
		_: ^bg.Domain_Contract,
	) -> bg.Status,
	ogb3_engine_allocation_stats, ogb3_snapshot_allocation_stats: proc "c" (
		_: ^bg.Allocation_Stats,
	) -> bg.Status,
	ogb3_host_owner_open:                                         proc "c" (
		_: u64,
		_: u64,
		_: u64,
		_: ^u64,
	) -> bg.Status,
	ogb3_host_owner_set:                                          proc "c" (
		_: u64,
		_: u64,
		_: u64,
		_: u64,
	) -> bg.Status,
	ogb3_host_owner_close:                                        proc "c" (
		_: u64,
		_: u64,
	) -> bg.Status,
	ogb3_host_ledger_get:                                         proc "c" (
		_: u64,
		_: ^bg.Ledger_Stats,
	) -> bg.Status,
}
@(private)
box3d_native: Box3D_Native
@(private)
box3d_main_thread: int
@(private)
box3d_initialized: bool
@(private)
box3d_gate_enter :: proc "c" (_: rawptr) -> bg.Status {
	if sync.current_thread_id() != box3d_main_thread {return bg.UNSUPPORTED}
	script_access_enter()
	return bg.OK
}
@(private)
box3d_gate_leave :: proc "c" (_: rawptr) {script_access_leave()
	script_generations_collect_pending()}
@(private)
box3d_protected :: proc "c" (_: rawptr) -> bg.Status {
	if sync.current_thread_id() != box3d_main_thread {return bg.UNSUPPORTED}
	if g_script_access_depth == 0 && !g_script_reload_writer {return bg.INCOMPATIBLE}
	return bg.OK
}
@(private)
box3d_code_retain :: proc "c" (_: rawptr, code: rawptr) {script_generation_retain(code)}
@(private)
box3d_code_drop :: proc "c" (_: rawptr, code: rawptr) {script_generation_release(code)}
@(private)
box3d_native_initialize :: proc() -> bool {
	when !BOX3D_HOST_ENABLED {return false}
	if box3d_initialized {return true}
	when ODIN_OS == .Windows {return false} 	// initial production target pair only
	dir, ok := core_dll_dir()
	if !ok {return false}
	defer delete(dir)
	filename := "libogb3.dylib" when ODIN_OS == .Darwin else "libogb3.so"
	path := strings.concatenate({dir, "/", filename})
	defer delete(path)
	native: Box3D_Native
	_, loaded := dynlib.initialize_symbols(&native, path, "", "__handle")
	if !loaded ||
	   native.__handle == nil ||
	   native.ogb3_domain_contract_get == nil ||
	   native.ogb3_engine_allocation_stats == nil ||
	   native.ogb3_snapshot_allocation_stats == nil ||
	   native.ogb3_host_owner_open == nil ||
	   native.ogb3_host_owner_set == nil ||
	   native.ogb3_host_owner_close == nil ||
	   native.ogb3_host_ledger_get == nil {
		if native.__handle != nil {_ = dynlib.unload_library(native.__handle)}
		gdext_print("ODIN_BOX3D_NATIVE_REJECTED", path)
		return false
	}
	contract: bg.Domain_Contract
	if native.ogb3_domain_contract_get(&contract) != bg.OK ||
	   contract.abi_version != 1 ||
	   contract.logical_version != 4 ||
	   contract.resource_version != 2 ||
	   contract.recovery_version != 1 {
		_ = dynlib.unload_library(native.__handle)
		return false
	}
	if !box3d_core_native_expected(contract) {
		_ = dynlib.unload_library(native.__handle)
		gdext_print(
			"ODIN_BOX3D_CORE_NATIVE_IDENTITY_REJECTED",
			"controlled Native differs from Core compiled build/target",
		)
		return false
	}
	api := bg.Native_API {
		contract      = contract,
		engine_stats  = native.ogb3_engine_allocation_stats,
		wrapper_stats = native.ogb3_snapshot_allocation_stats,
		owner_open    = native.ogb3_host_owner_open,
		owner_set     = native.ogb3_host_owner_set,
		owner_close   = native.ogb3_host_owner_close,
		ledger_get    = native.ogb3_host_ledger_get,
	}
	hooks := bg.Core_Hooks {
		enter       = box3d_gate_enter,
		leave       = box3d_gate_leave,
		protected   = box3d_protected,
		code_retain = box3d_code_retain,
		code_drop   = box3d_code_drop,
		procedure   = box3d_procedure_origin,
	}
	if bh.registry_init(api, hooks) != bg.OK {_ = dynlib.unload_library(native.__handle)
		return false}
	box3d_native = native
	box3d_main_thread = sync.current_thread_id()
	box3d_initialized = true
	return true
}
@(private)
box3d_candidate_check :: proc(dll: ^Scripts_Dll) -> bool {
	if dll == nil {return false}
	when BOX3D_HOST_ENABLED {
		// Opted-in SDK modules must explicitly declare even a native-free profile.
		// Older ABI-compatible modules cannot bypass native admission by omitting it.
		if dll.odin_scripts_box3d_profile == nil ||
		   dll.odin_scripts_box3d_protocol == nil ||
		   dll.odin_scripts_box3d_protocol() != bg.protocol_fingerprint() {return false}
	}
	if dll.odin_scripts_box3d_profile == nil || dll.odin_scripts_box3d_profile() == 0 {return true}
	if dll.odin_scripts_box3d_profile() != 1 ||
	   dll.odin_scripts_box3d_protocol == nil ||
	   dll.odin_scripts_box3d_protocol() != bg.protocol_fingerprint() ||
	   dll.odin_scripts_box3d_contract == nil ||
	   dll.odin_scripts_box3d_install == nil ||
	   !box3d_native_initialize() {return false}
	declared, actual: bg.Domain_Contract
	// Module discovery also checks its compile-expected BUILD/TARGET before boot.
	if dll.odin_scripts_box3d_contract(&declared) != bg.OK ||
	   box3d_native.ogb3_domain_contract_get(&actual) != bg.OK {return false}
	return declared == actual
}
@(private)
box3d_generation_install :: proc(gen: ^Script_Generation) -> bool {
	if gen == nil ||
	   gen.dll.odin_scripts_box3d_profile == nil ||
	   gen.dll.odin_scripts_box3d_profile() == 0 {return true}
	service: bg.Service
	if bh.producer_create(gen, &service) != bg.OK {return false}
	script_access_enter()
	defer script_access_leave()
	scope, status := bh.origin_enter(service.user)
	if status != bg.OK {_ = bh.producer_destroy(service.user)
		return false}
	defer bh.origin_leave(scope)
	if gen.dll.odin_scripts_box3d_install(&service) != bg.OK {_ = bh.producer_destroy(service.user)
		return false}
	gen.box3d_service = service
	return true
}
@(private)
box3d_origin_enter :: proc "contextless" (
	opaque: rawptr,
	weak: u64 = 0,
) -> (
	bg.Origin_Scope,
	bg.Status,
) {
	gen := cast(^Script_Generation)opaque
	if gen == nil || gen.box3d_service.realm == 0 {return {}, bg.OK}
	return bh.origin_enter(gen.box3d_service.user, weak)
}
@(private)
box3d_origin_leave :: proc "contextless" (scope: bg.Origin_Scope) {bh.origin_leave(scope)}
@(private)
box3d_context_create :: proc "contextless" (opaque: rawptr) -> u64 {
	gen := cast(^Script_Generation)opaque
	if gen == nil || gen.box3d_service.realm == 0 {return 0}
	scope, s := bh.origin_enter(gen.box3d_service.user)
	if s != bg.OK {return 0}
	defer bh.origin_leave(scope)
	token: u64
	if bh.context_create(gen.box3d_service.user, &token) != bg.OK {return 0}
	return token
}
@(private)
box3d_context_invalidate :: proc "contextless" (token: u64) {if token != 0 {_ =
			bh.context_invalidate(token)}}
// Called by the existing writer-gate collector BEFORE unloading that generation.
@(private)
box3d_generation_close :: proc(gen: ^Script_Generation) -> bool {
	if gen == nil || gen.box3d_service.realm == 0 {return true}
	if bh.producer_destroy(gen.box3d_service.user) != bg.OK {return false}
	gen.box3d_service = {}
	return true
}

// Scene-deinit hook owned by Core. Denial leaves live owners/native objects
// intact; it never forces release through stale producer/allocator contexts.
box3d_host_shutdown :: proc() -> bg.Status {
	when !BOX3D_HOST_ENABLED {return bg.OK}
	if !box3d_initialized {return bg.OK}
	if sync.current_thread_id() != box3d_main_thread ||
	   !script_reload_can_begin() {return bg.INCOMPATIBLE}
	stats: bg.Ledger_Stats
	contract: bg.Domain_Contract
	status := box3d_native.ogb3_domain_contract_get(&contract)
	if status != bg.OK {return status}
	status = box3d_native.ogb3_host_ledger_get(contract.cookie, &stats)
	if status != bg.OK {return status}
	if stats.engine_live_bytes != 0 ||
	   stats.snapshot_live_bytes != 0 {gdext_print("ODIN_BOX3D_SHUTDOWN_LIVE_NATIVE", "")
		return bg.CAPACITY}
	script_reload_begin()
	defer script_reload_end()
	for gen in g_script_generations {if gen != nil && gen.box3d_service.realm != 0 {
			if gen.instance_refs != 0 ||
			   !box3d_generation_close(
					   gen,
				   ) {gdext_print("ODIN_BOX3D_SHUTDOWN_LIVE_OWNER", gen.module_name)
				return bg.CAPACITY}
		}}
	status = bh.registry_shutdown()
	if status != bg.OK {return status}
	box3d_initialized = false
	// Dependency references of still-mapped current script images may retain the
	// native image. Only release Core's own loader reference, after all owners.
	if box3d_native.__handle != nil {_ = dynlib.unload_library(box3d_native.__handle)}
	box3d_native = {}
	return bg.OK
}

@(private)
box3d_procedure_origin :: proc "c" (_: rawptr, code: rawptr, address: rawptr) -> bg.Status {
	gen := cast(^Script_Generation)code
	if gen == nil || address == nil {return bg.INCOMPATIBLE}
	when ODIN_OS == .Darwin || ODIN_OS == .Linux {
		actual, expected: Dl_info
		if dladdr(address, &actual) != 0 &&
		   dladdr(cast(rawptr)gen.dll.odin_scripts_abi_version, &expected) != 0 &&
		   actual.dli_fbase == expected.dli_fbase {return bg.OK}
	}
	return bg.INCOMPATIBLE
}
@(private)
box3d_context_bind :: proc "contextless" (token: u64, base: rawptr, size: u64) {if token != 0 &&
	   base != nil &&
	   size != 0 {_ = bh.context_bind(token, base, size)}}

@(private)
box3d_typed_instance_allowed :: proc "contextless" (opaque: rawptr) -> bool {
	gen := cast(^Script_Generation)opaque
	if gen == nil || gen.box3d_service.realm == 0 {return true}
	return box3d_protected(nil) == bg.OK && bh.current_realm() == gen.box3d_service.realm
}

@(private)
box3d_context_release :: proc "contextless" (token: u64) {if token != 0 {_ = bh.context_release(
			token,
		)}}
