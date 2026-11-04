package core

// Compiled with an exact scratch copy of Core; no test hook/export is added to
// production. Godot owns finalization timing, so these direct state controls
// exercise its deferred-final-free ordering without violating public ownership.
import "base:runtime"
import "core:dynlib"
import "core:sync"
import "core:testing"
import "core:thread"
import bg "godot:box3d/godot"
import "godot:gdext"
import rt "godot:runtime"

internal_destroyed: u32
internal_declines: u32
internal_off_main: bool
internal_destroy :: proc "c" (user: rawptr) -> bg.Status {
	context = runtime.default_context()
	internal_off_main = sync.current_thread_id() != box3d_main_thread
	r := managed_find(u64(uintptr(user)))
	assert(r != nil && r.cleaning && r.inflight == 0)
	if internal_declines != 0 {internal_declines -= 1; return bg.CAPACITY}
	internal_destroyed += 1
	return bg.OK
}
@(test)
automatic_finalization_order :: proc(t: ^testing.T) {
	// No Native/Godot API calls are used by this metadata-only deferred path.
	box3d_main_thread = sync.current_thread_id()
	managed_state.initialized = true
	internal_destroyed = 0; internal_declines = 1; internal_off_main = false
	r := &managed_state.records[0]
	r^ = Managed_Callable_Record {
		generation = 1,
		active = true,
		engine_alive = true,
		handle_alive = true,
		inflight = 1,
		capsule = {user = rawptr(uintptr(65537)), realm = 1, destroy = internal_destroy},
	}
	token := managed_token(0, r)
	handle := rt.Managed_Callable {
		token = token,
	}
	testing.expect(
		t,
		managed_callable_core_close(&handle) == rt.MANAGED_CALLABLE_BUSY &&
		handle.token == token &&
		!r.closed,
	)
	managed_callable_free(rawptr(uintptr(token)))
	testing.expect(t, internal_destroyed == 0 && r.closed && r.active && r.inflight == 1)
	testing.expect(t, managed_callable_core_collect() == bg.OK && internal_destroyed == 0)
	// Producer callback has NOW returned to Core. First drop declines and keeps the
	// exact cleanup token; a later main collection retries without stale access.
	r.inflight = 0
	testing.expect(
		t,
		managed_callable_core_collect() == bg.CAPACITY && r.active && r.capsule.user != nil,
	)
	testing.expect(
		t,
		managed_callable_core_collect() == bg.OK &&
		internal_destroyed == 1 &&
		!r.active &&
		!internal_off_main,
	)
	// Worker final free must only write Core metadata; producer cleanup runs later
	// on the main thread under the same outer execution gate.
	r^ = Managed_Callable_Record {
		generation = 2,
		active = true,
		engine_alive = true,
		handle_alive = true,
		capsule = {user = rawptr(uintptr(131073)), realm = 1, destroy = internal_destroy},
	}
	token = managed_token(0, r)
	worker := thread.create(proc(t: ^thread.Thread) {managed_callable_free(t.data)})
	worker.data = rawptr(
		uintptr(token),
	); thread.start(worker); thread.join(worker); thread.destroy(worker)
	testing.expect(
		t,
		internal_destroyed == 1 && r.active && r.closed && !r.engine_alive && !r.handle_alive,
	)
	testing.expect(
		t,
		managed_callable_core_collect() == bg.OK &&
		internal_destroyed == 2 &&
		!r.active &&
		!internal_off_main,
	)
	// Old engine userdata cannot finalize a newer slot generation.
	r^ = Managed_Callable_Record {
		generation   = 3,
		active       = true,
		engine_alive = true,
		handle_alive = true,
	}
	managed_callable_free(rawptr(uintptr(token)))
	testing.expect(t, r.active && r.engine_alive && r.handle_alive && !r.closed)
	// Invalid C64 engine counts / nil variant vector never enter producer code.
	error: gdext.CallError
	counts := [?]i64{-1, 1, 33, 1 << 40}
	for count in counts {
		managed_callable_call(rawptr(uintptr(managed_token(0, r))), nil, count, nil, &error)
		testing.expect(
			t,
			error.error == .Invalid_Method && r.inflight == 0 && internal_destroyed == 2,
		)
	}
	r.active = false
	managed_state.initialized = false
}

NATIVE_LEDGER_LIBRARY :: #config(MANAGED_TEST_NATIVE, "")
@(test)
static_table_charge_once :: proc(t: ^testing.T) {
	// Optional actual Native ledger control; no engine/world object is allocated.
	when NATIVE_LEDGER_LIBRARY != "" {
		native: Box3D_Native
		_, ok := dynlib.initialize_symbols(&native, NATIVE_LEDGER_LIBRARY, "", "__handle")
		testing.expect(t, ok && native.__handle != nil)
		if !ok {return}
		defer dynlib.unload_library(native.__handle)
		box3d_native = native
		box3d_initialized = true
		box3d_main_thread = sync.current_thread_id()
		contract: bg.Domain_Contract
		testing.expect(t, native.ogb3_domain_contract_get(&contract) == bg.OK)
		before: bg.Ledger_Stats
		testing.expect(t, native.ogb3_host_ledger_get(contract.cookie, &before) == bg.OK)
		testing.expect(t, managed_initialize() == bg.OK && managed_initialize() == bg.OK)
		charged: bg.Ledger_Stats
		testing.expect(t, native.ogb3_host_ledger_get(contract.cookie, &charged) == bg.OK)
		testing.expect(
			t,
			charged.owner_count == before.owner_count + 1 &&
			charged.host_live_bytes == before.host_live_bytes + size_of(Managed_Callable_State),
		)
		testing.expect(t, managed_callable_shutdown() == bg.OK)
		after: bg.Ledger_Stats
		testing.expect(t, native.ogb3_host_ledger_get(contract.cookie, &after) == bg.OK)
		testing.expect(
			t,
			after.owner_count == before.owner_count &&
			after.host_live_bytes == before.host_live_bytes &&
			after.host_reserved_bytes == before.host_reserved_bytes,
		)
		box3d_native = {}; box3d_initialized = false
	} else {testing.skip(t, "supply MANAGED_TEST_NATIVE for actual native ledger control")}
}
