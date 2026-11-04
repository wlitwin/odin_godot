//gd:extends Node
//gd:class CallbackSource
package callback_source

import "base:runtime"
import "core:fmt"
import "core:mem"
import b "godot:box3d"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import gd "godot:godot"
import "godot:gdext"
import rt "godot:runtime"

CallbackSource :: struct {
    owner:  gd.Node,
    handle: rt.Managed_Callable,
    bulk:   [256]rt.Managed_Callable,
}

Payload :: struct {
    allocator: mem.Allocator,
    handle:    rt.Managed_Callable,
    calls:     i64,
    brand:     i64,
}

BRAND :: #config(BOX3D_RELOAD_BRAND, 1)
decline_drop: bool
retains, drops, destructors: u64

lease_retain :: proc "c" (user: rawptr) -> bg.Status {
    context = runtime.default_context()
    retains += 1
    return meter.retain(cast(^meter.Context)user)
}

lease_drop :: proc "c" (user: rawptr) -> bg.Status {
    context = runtime.default_context()

    if decline_drop {
        decline_drop = false
        fmt.println("CALLBACK_DROP_DECLINED")
        return bg.CAPACITY
    }

    drops += 1
    ctx := cast(^meter.Context)user
    return meter.destroy(&ctx)
}

dispatch :: proc "c" (user: rawptr, operation: u32, opaque: rawptr) -> bg.Status {
    context = runtime.default_context()
    p := cast(^Payload)user

    if operation == bg.CAPSULE_DESTROY {
        destructors += 1
        fmt.printf("CALLBACK_DESTRUCTOR_BEGIN brand=%d count=%d\n", p.brand, destructors)
        allocator := p.allocator
        free(p, allocator)
        fmt.println("CALLBACK_DESTRUCTOR_RETURN")
        return bg.OK
    }

    if operation != 2 || opaque == nil {
        return bg.INVALID_ARGUMENT
    }

    args := cast(^rt.Managed_Callable_Args)opaque

    if args.reserved != 0 ||
       args.count != 1 ||
       args.variants == nil ||
       args.variants[0] == nil ||
       args.result == nil ||
       args.error == nil {
        return bg.INVALID_ARGUMENT
    }

    value := gd.variant_to_int(cast(^gd.Variant)args.variants[0])
    p.calls += 1
    answer := p.brand * 1000 + p.calls + value

    if value == -7 {
        original := p.handle
        candidate := original
        status := rt.managed_callable_close(&candidate)

        if status != rt.MANAGED_CALLABLE_BUSY || transmute([5]u64)candidate != transmute([5]u64)original {
            return bg.CORRUPT
        }

        fmt.println("CALLBACK_REENTRANT_BUSY_PRESERVED")
        answer = 8008
    }

    // result points into engine-owned Variant storage: construct through its API,
    // never copy the SDK oversized storage wrapper into the borrowed buffer.
    gdext.get_variant_from_type_constructor(.Int)(gdext.VariantPtr(args.result), &answer)
    fmt.printf("CALLBACK_INVOKED brand=%d calls=%d value=%d\n", p.brand, p.calls, value)
    return bg.OK
}

@(gd_method)
source_brand :: proc(self: ^CallbackSource) -> gd.Int {
    return BRAND
}

@(gd_method)
source_make :: proc(self: ^CallbackSource, decline: bool, weak: bool) -> gd.Int {
    if self.handle.token != 0 {
        return 1
    }

    // Force actual SDK profile registration; all module imports use one native DSO.
    _, native_status := b.domain_contract_get()

    if native_status != .Ok {
        return gd.Int(native_status)
    }

    service := bg.service_get()
    ctx, status := meter.create(service, bg.CATEGORY_REPLAY_CORE)

    if status != bg.OK {
        return gd.Int(status)
    }

    defer meter.destroy(&ctx)
    allocator := meter.allocator(ctx)
    p, error := new(Payload, allocator)

    if error != nil {
        return gd.Int(bg.CAPACITY)
    }

    p^ = {
        allocator = allocator,
        brand     = BRAND,
    }
    data := bg.Data_Lease{ctx, lease_retain, lease_drop}
    owner: bg.Owner
    status = service.owner_create(service.user, weak ? 1 : 0, &data, &owner)

    if status != bg.OK {
        free(p, allocator)
        return gd.Int(status)
    }

    defer owner.drop(owner.user)
    capsule: bg.Capsule
    status = service.capsule_create(service.user, &owner, p, dispatch, &capsule)

    if status != bg.OK {
        free(p, allocator)
        return gd.Int(status)
    }

    handle, created := rt.managed_callable_create(&capsule, 2)

    if created != bg.OK {
        capsule.destroy(capsule.user)
        return gd.Int(created)
    }

    if capsule.user != nil {
        return gd.Int(bg.CORRUPT)
    }

    p.handle = handle
    self.handle = handle
    decline_drop = decline
    return 0
}

@(gd_method = "owned_return")
source_take :: proc(self: ^CallbackSource) -> gd.Packed_Byte_Array {
    result := gd.new_packed_byte_array()
    gd.packed_byte_array_resize(&result, size_of(rt.Managed_Callable))
    bytes := transmute([size_of(rt.Managed_Callable)]u8)self.handle
    copy(gd.packed_byte_array_view(&result), bytes[:])
    self.handle = {}
    return result
}

@(gd_method)
source_clear :: proc(self: ^CallbackSource) -> gd.Int {
    return gd.Int(rt.managed_callable_close(&self.handle))
}

@(gd_method)
source_bounds :: proc(self: ^CallbackSource) -> gd.Int {
    service := bg.service_get()
    ctx, status := meter.create(service, bg.CATEGORY_REPLAY_CORE)

    if status != bg.OK {
        return gd.Int(status)
    }

    defer meter.destroy(&ctx)
    allocator := meter.allocator(ctx)
    data := meter.data_lease(ctx)
    owner: bg.Owner
    status = service.owner_create(service.user, 0, &data, &owner)

    if status != bg.OK {
        return gd.Int(status)
    }

    defer owner.drop(owner.user)
    stale: rt.Managed_Callable

    for i in 0 ..= 256 {
        p, error := new(Payload, allocator)

        if error != nil {
            return -1
        }

        p^ = {
            allocator = allocator,
            brand     = BRAND,
        }
        capsule: bg.Capsule
        status = service.capsule_create(service.user, &owner, p, dispatch, &capsule)

        if status != bg.OK {
            free(p, allocator)
            return gd.Int(status)
        }

        original := capsule
        handle, created := rt.managed_callable_create(&capsule, 2)

        if i == 256 {
            if created != bg.CAPACITY || handle.token != 0 || capsule != original {
                return -2
            }

            if capsule.destroy(capsule.user) != bg.OK {
                return -3
            }
        } else {
            if created != bg.OK || capsule.user != nil {
                return -4
            }

            self.bulk[i] = handle
        }
    }

    stale = self.bulk[0]

    for &handle in self.bulk {
        if rt.managed_callable_close(&handle) != bg.OK {
            return -5
        }
    }

    p, error := new(Payload, allocator)

    if error != nil {
        return -6
    }

    p^ = {
        allocator = allocator,
        brand     = BRAND,
    }
    capsule: bg.Capsule

    if service.capsule_create(service.user, &owner, p, dispatch, &capsule) != bg.OK {
        return -7
    }

    original := capsule
    // Foreign function pointer / bad operation are rejected before ownership move.
    invalid := capsule
    invalid.invoke = nil
    _, status = rt.managed_callable_create(&invalid, 2)

    if status != bg.INCOMPATIBLE || invalid.user != capsule.user {
        return -8
    }

    _, status = rt.managed_callable_create(&capsule, 1)

    if status != bg.INVALID_ARGUMENT || capsule != original {
        return -9
    }

    current, created := rt.managed_callable_create(&capsule, 2)

    if created != bg.OK {
        return -10
    }

    saved := stale

    if rt.managed_callable_close(&stale) != bg.INVALID_HANDLE || stale != saved {
        return -11
    }

    return gd.Int(rt.managed_callable_close(&current))
}
