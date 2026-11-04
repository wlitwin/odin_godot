package script_runtime

import bg "godot:box3d/godot"
import gd "godot:godot"

// Separate optional C handoff; Host Service200/Native contracts are unchanged.
MANAGED_CALLABLE_VERSION :: u32(1)
MANAGED_CALLABLE_BUSY :: bg.Status(8)
MANAGED_CALLABLE_MAX_ARGS :: i32(32)

Managed_Call_Error :: struct {
    error, argument, expected: i32,
}

Managed_Callable_Args :: struct {
    variants: [^]rawptr,
    count:    i32,
    reserved: u32,
    result:   rawptr,
    error:    ^Managed_Call_Error,
}

// One owning handle. value is borrowed for connect/disconnect; only close frees
// its Callable reference. Plain assignment aliases ownership, not a clone.
Managed_Callable :: struct {
    value: gd.Callable,
    token: u64,
}

Managed_Callable_Stats :: struct {
    live_records, open_records, pending_records, inflight_calls: u64,
    storage_bytes, calls, rejected_calls, declined_drops:        u64,
}

Managed_Callable_API :: struct {
    size, version: u32,
    fingerprint:   u64,
    create:        proc "c" (_: ^bg.Capsule, _: u32, _: ^Managed_Callable) -> bg.Status,
    close:         proc "c" (_: ^Managed_Callable) -> bg.Status,
    collect:       proc "c" () -> bg.Status,
    stats:         proc "c" (_: ^Managed_Callable_Stats) -> bg.Status,
}

managed_callable_fingerprint :: proc "contextless" () -> u64 {
    values := [?]uintptr {
        uintptr(MANAGED_CALLABLE_VERSION),
        size_of(gd.Callable),
        align_of(gd.Callable),
        size_of(Managed_Callable),
        align_of(Managed_Callable),
        offset_of(Managed_Callable, token),
        size_of(Managed_Call_Error),
        offset_of(Managed_Call_Error, argument),
        offset_of(Managed_Call_Error, expected),
        size_of(Managed_Callable_Args),
        align_of(Managed_Callable_Args),
        offset_of(Managed_Callable_Args, count),
        offset_of(Managed_Callable_Args, reserved),
        offset_of(Managed_Callable_Args, result),
        offset_of(Managed_Callable_Args, error),
        size_of(Managed_Callable_Stats),
        size_of(Managed_Callable_API),
        offset_of(Managed_Callable_API, fingerprint),
        offset_of(Managed_Callable_API, create),
        offset_of(Managed_Callable_API, close),
        offset_of(Managed_Callable_API, collect),
        offset_of(Managed_Callable_API, stats),
    }
    h := u64(14695981039346656037)

    for value in values {
        v := u64(value)

        for _ in 0 ..< 8 {
            h = (h ~ (v & 255)) * 1099511628211
            v >>= 8
        }
    }

    return h
}
