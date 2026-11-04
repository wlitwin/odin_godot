package script_runtime
import bg "godot:box3d/godot"

@(private)
managed_api: Managed_Callable_API
@(export)
odin_scripts_managed_callable_protocol :: proc "c" () -> u64 {return managed_callable_fingerprint(
		
	)}
@(export)
odin_scripts_set_managed_callable_api :: proc "c" (api: ^Managed_Callable_API) -> bg.Status {
	if api == nil ||
	   api.size != size_of(Managed_Callable_API) ||
	   api.version != MANAGED_CALLABLE_VERSION ||
	   api.fingerprint != managed_callable_fingerprint() ||
	   api.create == nil ||
	   api.close == nil ||
	   api.collect == nil ||
	   api.stats == nil {return bg.INCOMPATIBLE}
	if managed_api.create != nil {return bg.INCOMPATIBLE}
	managed_api = api^
	return bg.OK
}
managed_callable_create :: proc "contextless" (
	capsule: ^bg.Capsule,
	operation: u32,
) -> (
	handle: Managed_Callable,
	status: bg.Status,
) {
	if managed_api.create == nil {return {}, bg.UNSUPPORTED}
	status = managed_api.create(capsule, operation, &handle)
	return
}
managed_callable_close :: proc "contextless" (handle: ^Managed_Callable) -> bg.Status {
	if handle == nil {return bg.INVALID_ARGUMENT}
	if handle.token == 0 {return bg.OK}
	if managed_api.close == nil {return bg.UNSUPPORTED}
	return managed_api.close(handle)
}
managed_callable_collect :: proc "contextless" () -> bg.Status {
	if managed_api.collect == nil {return bg.UNSUPPORTED}
	return managed_api.collect()
}
managed_callable_stats :: proc "contextless" (
) -> (
	stats: Managed_Callable_Stats,
	status: bg.Status,
) {
	if managed_api.stats == nil {return {}, bg.UNSUPPORTED}
	status = managed_api.stats(&stats)
	return
}
