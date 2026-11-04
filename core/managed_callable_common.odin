package core

import bg "godot:box3d/godot"
import bh "godot:box3d/godot/host"
import "godot:gdext"
import "godot:godot"
import rt "godot:runtime"

// Shared callable ownership policy; platform files supply only gate/thread,
// native ledger and metadata-mutex operations.
managed_storage_bytes :: proc "contextless" () -> u64 {
    return u64(size_of(Managed_Callable_State)) + managed_platform_storage_bytes()
}

// Only Core callbacks enter Godot. Tokens never point at producer storage.
MANAGED_CALLABLE_CAPACITY :: 256

Managed_Callable_Record :: struct {
    generation:                                           u32,
    active, closed, cleaning, engine_alive, handle_alive: bool,
    inflight:                                             u32,
    capsule:                                              bg.Capsule,
    operation:                                            u32,
    value:                                                godot.Callable, // borrowed bits; the public handle owns the reference
}

Managed_Callable_State :: struct {
    mutex:                     Managed_Mutex,
    initialized:               bool,
    ledger_token, cookie:      u64,
    records:                   [MANAGED_CALLABLE_CAPACITY]Managed_Callable_Record,
    calls, rejected, declined: u64,
}

@(private)
managed_state: Managed_Callable_State

@(private)
managed_find :: proc "contextless" (token: u64) -> ^Managed_Callable_Record {
    index := token & 0xffff

    if index == 0 || index > MANAGED_CALLABLE_CAPACITY {
        return nil
    }

    r := &managed_state.records[index - 1]

    if !r.active || u64(r.generation) != (token >> 16) {
        return nil
    }

    return r
}

@(private)
managed_token :: proc "contextless" (index: int, r: ^Managed_Callable_Record) -> u64 {
    return (u64(r.generation) << 16) | u64(index + 1)
}

@(private)
managed_recycle :: proc "contextless" (r: ^Managed_Callable_Record) {
    if !r.cleaning && r.inflight == 0 && !r.engine_alive && !r.handle_alive && r.capsule.user == nil {
        r.active = false
    }
}

@(private)
managed_initialize :: proc() -> bg.Status {
    if managed_state.initialized {
        return bg.OK
    }

    if !managed_host_ready() || !managed_host_on_thread() {
        return bg.UNSUPPORTED
    }

    contract: bg.Domain_Contract
    s := managed_host_domain_get(&contract)

    if s != bg.OK {
        return s
    }

    token: u64
    s = managed_host_owner_open(contract.cookie, max(u64), max(u64) - 1, &token)

    if s != bg.OK {
        return s
    }

    s = managed_host_owner_set(contract.cookie, token, managed_storage_bytes(), 0)

    if s != bg.OK {
        _ = managed_host_owner_close(contract.cookie, token)
        return s
    }

    managed_state.cookie = contract.cookie
    managed_state.ledger_token = token
    managed_state.initialized = true
    return bg.OK
}

managed_callable_core_create :: proc "c" (
    source: ^bg.Capsule,
    operation: u32,
    out: ^rt.Managed_Callable,
) -> bg.Status {
    context = gdext.godot_context()

    if source == nil || out == nil || operation <= 1 {
        return bg.INVALID_ARGUMENT
    }

    if out.token != 0 || transmute([size_of(godot.Callable)]u8)out.value != ([size_of(godot.Callable)]u8{}) {
        return bg.INVALID_ARGUMENT
    }

    if !managed_state.initialized {
        return bg.UNSUPPORTED
    }

    s := managed_host_protected()

    if s != bg.OK {
        return s
    }

    info, status := bh.capsule_inspect(source)

    if status != bg.OK {
        return status
    }

    if !info.execute_live || bh.current_realm() != info.realm {
        return bg.INCOMPATIBLE
    }

    managed_lock()
    index := -1

    for &r, i in managed_state.records {
        if !r.active && r.generation < MANAGED_GENERATION_MAX {
            index = i
            break
        }
    }

    if index < 0 {
        managed_unlock()
        return bg.CAPACITY
    }

    r := &managed_state.records[index]
    generation := r.generation + 1
    r^ = Managed_Callable_Record {
        generation = generation,
        active     = true,
        cleaning   = true,
    }
    token := managed_token(index, r)
    managed_unlock()
    value: godot.Callable
    custom := gdext.ExtensionCallableCustomInfo2 {
        callable_userdata = rawptr(uintptr(token)),
        token             = rawptr(gdext.library),
        call_func         = managed_callable_call,
        is_valid_func     = managed_callable_valid,
        free_func         = managed_callable_free,
    }
    gdext.callable_custom_create2(&value, &custom)
    // Godot's constructor is infallible for a valid info table; validity consults
    // our Core metadata only after the record has been published below.
    managed_lock()
    r.capsule = source^
    r.operation = operation
    r.value = value
    r.engine_alive = true
    r.handle_alive = true
    r.cleaning = false
    source^ = {}
    out^ = {
        value = value,
        token = token,
    }
    managed_unlock()
    return bg.OK
}

// Shared cleanup path: after whole producer return, never from an off-main free.
@(private)
managed_cleanup :: proc(token: u64) -> bg.Status {
    managed_lock()
    r := managed_find(token)

    if r == nil {
        managed_unlock()
        return bg.INVALID_HANDLE
    }

    if r.cleaning || r.inflight != 0 {
        managed_unlock()
        return rt.MANAGED_CALLABLE_BUSY
    }

    if r.capsule.user == nil {
        managed_recycle(r)
        managed_unlock()
        return bg.OK
    }

    r.cleaning = true
    capsule := r.capsule
    managed_unlock()
    // Both pointers were validated against Core at construction. Capsule.destroy
    // owns origin/code/data through its entire producer destructor and return.
    status := capsule.destroy(capsule.user)
    managed_lock()
    r = managed_find(token)

    if status == bg.OK {
        r.capsule = {}
    } else {
        managed_state.declined += 1
    }

    r.cleaning = false
    managed_recycle(r)
    managed_unlock()
    return status
}

managed_callable_core_close :: proc "c" (handle: ^rt.Managed_Callable) -> bg.Status {
    context = gdext.godot_context()

    if handle == nil {
        return bg.INVALID_ARGUMENT
    }

    if handle.token == 0 {
        return bg.OK
    }

    if !managed_state.initialized || !managed_host_on_thread() {
        return bg.UNSUPPORTED
    }

    s := managed_host_enter()

    if s != bg.OK {
        return s
    }

    defer managed_host_leave()
    managed_lock()
    r := managed_find(handle.token)

    if r == nil ||
       !r.handle_alive ||
       transmute([size_of(godot.Callable)]u8)r.value != transmute([size_of(godot.Callable)]u8)handle.value {
        managed_unlock()
        return bg.INVALID_HANDLE
    }

    // Conservative single-caller policy: no parent can partially close a set of
    // signal handles while any managed producer callback is still on the stack.
    for other in managed_state.records {
        if other.inflight != 0 || other.cleaning {
            managed_unlock()
            return rt.MANAGED_CALLABLE_BUSY
        }
    }

    r.closed = true
    token := handle.token
    managed_unlock()
    s = managed_cleanup(token)

    if s != bg.OK {
        return s
    }

    managed_lock()
    r = managed_find(token)
    value := r.value
    r.handle_alive = false
    r.value = {}
    managed_unlock()
    godot.free_callable(value) // may synchronously call Core free_func
    managed_lock()
    r = managed_find(token)

    if r != nil {
        managed_recycle(r)
    }

    handle^ = {}
    managed_unlock()
    return bg.OK
}

// Godot may finalize its final copy on a worker thread. Never execute producer
// procedures, Godot API calls, allocation or the generation collector here.
managed_callable_free :: proc "c" (user: rawptr) {
    token := u64(uintptr(user))
    managed_lock()
    r := managed_find(token)

    if r != nil {
        r.engine_alive = false
        r.closed = true
        // Final engine ref implies the original owning reference has also retired.
        // With the supported API this was already set by cooperative close.
        r.handle_alive = false
        r.value = {}
        managed_recycle(r)
    }

    managed_unlock()
}

managed_callable_valid :: proc "c" (user: rawptr) -> bool {
    if !managed_host_on_thread() {
        return false
    }

    token := u64(uintptr(user))
    managed_lock()
    r := managed_find(token)
    valid := r != nil && !r.closed && !r.cleaning && r.engine_alive
    capsule: bg.Capsule

    if valid {
        capsule = r.capsule
    }

    managed_unlock()

    if !valid {
        return false
    }

    if managed_host_enter() != bg.OK {
        return false
    }

    defer managed_host_leave()
    info, s := bh.capsule_inspect(&capsule)
    return s == bg.OK && info.execute_live
}

managed_callable_call :: proc "c" (
    user: rawptr,
    variants: [^]gdext.VariantPtr,
    count: i64,
    result: gdext.VariantPtr,
    error: ^gdext.CallError,
) {
    context = gdext.godot_context()

    if result != nil {
        gdext.variant_new_nil(result)
    }

    if error != nil {
        error^ = gdext.CallError {
            error = .Invalid_Method,
        }
    }

    if !managed_host_on_thread() {
        return
    }

    token := u64(uintptr(user))
    managed_lock()
    r := managed_find(token)

    if r == nil ||
       r.closed ||
       r.cleaning ||
       !r.engine_alive ||
       count < 0 ||
       count > i64(rt.MANAGED_CALLABLE_MAX_ARGS) ||
       (count != 0 && variants == nil) {
        managed_state.rejected += 1
        managed_unlock()
        return
    }

    r.inflight += 1
    capsule := r.capsule
    operation := r.operation
    managed_state.calls += 1
    managed_unlock()
    s := managed_host_enter()
    entered := s == bg.OK

    if entered {
        info, checked := bh.capsule_inspect(&capsule)

        if checked == bg.OK && info.execute_live {
            if error != nil {
                error^ = {}
            }

            args := rt.Managed_Callable_Args {
                variants = cast([^]rawptr)variants,
                count    = i32(count),
                result   = rawptr(result),
                error    = cast(^rt.Managed_Call_Error)error,
            }
            s = capsule.invoke(capsule.user, operation, &args)
        } else {
            s = checked

            if s == bg.OK {
                s = bg.INCOMPATIBLE
            }
        }

        if s != bg.OK && error != nil {
            error^ = gdext.CallError {
                error = .Invalid_Method,
            }
        }
    }

    managed_lock()
    r = managed_find(token)
    r.inflight -= 1
    pending := r.closed && r.inflight == 0

    if s != bg.OK {
        managed_state.rejected += 1
    }

    managed_unlock()

    if pending && entered {
        _ = managed_cleanup(token)
    }

    if entered {
        managed_host_leave()
    }
}

managed_callable_core_collect :: proc "c" () -> bg.Status {
    context = gdext.godot_context()

    if !managed_state.initialized {
        return bg.OK
    }

    if !managed_host_on_thread() {
        return bg.UNSUPPORTED
    }

    s := managed_host_enter()

    if s != bg.OK {
        return s
    }

    defer managed_host_leave()
    status := bg.OK

    for i in 0 ..< MANAGED_CALLABLE_CAPACITY {
        managed_lock()
        r := &managed_state.records[i]
        pending := r.active && r.closed && r.inflight == 0 && !r.cleaning
        token := managed_token(i, r)
        managed_unlock()

        if pending {
            checked := managed_cleanup(token)

            if checked != bg.OK {
                status = checked
            }
        }
    }

    return status
}

managed_callable_core_stats :: proc "c" (out: ^rt.Managed_Callable_Stats) -> bg.Status {
    if out == nil {
        return bg.INVALID_ARGUMENT
    }

    managed_lock()
    defer managed_unlock()
    value := rt.Managed_Callable_Stats {
        calls          = managed_state.calls,
        rejected_calls = managed_state.rejected,
        declined_drops = managed_state.declined,
    }

    if managed_state.initialized {
        value.storage_bytes = managed_storage_bytes()
    }

    for r in managed_state.records {
        if r.active {
            value.live_records += 1
            value.inflight_calls += u64(r.inflight)

            if r.closed {
                value.pending_records += 1
            } else {
                value.open_records += 1
            }
        }
    }

    out^ = value
    return bg.OK
}

managed_callable_shutdown :: proc() -> bg.Status {
    if !managed_state.initialized {
        return bg.OK
    }

    s := managed_callable_core_collect()

    if s != bg.OK {
        return s
    }

    stats: rt.Managed_Callable_Stats
    _ = managed_callable_core_stats(&stats)

    if stats.live_records != 0 {
        return bg.CAPACITY
    }

    s = managed_host_owner_close(managed_state.cookie, managed_state.ledger_token)

    if s != bg.OK {
        return s
    }

    managed_state.initialized = false
    managed_state.ledger_token = 0
    managed_state.cookie = 0
    return bg.OK
}

managed_callable_language_frame :: proc "c" (
    instance: gdext.ExtensionClassInstancePtr,
    args: [^]gdext.TypePtr,
    ret: gdext.TypePtr,
) {
    _ = managed_callable_core_collect()
    lv_frame(instance, args, ret)
}
