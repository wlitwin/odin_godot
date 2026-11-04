package managed_callable_protocol_test
import "core:testing"
import bg "godot:box3d/godot"
import rt "godot:runtime"
C_FINGERPRINT :: #config(MANAGED_C_FINGERPRINT, u64(0))

create :: proc "c" (source: ^bg.Capsule, op: u32, out: ^rt.Managed_Callable) -> bg.Status {
    if source == nil || out == nil {
        return bg.INVALID_ARGUMENT
    }

    out.token = 99
    source^ = {}
    return bg.OK
}

close :: proc "c" (owner: ^rt.Managed_Callable) -> bg.Status {
    owner^ = {}
    return bg.OK
}

collect :: proc "c" () -> bg.Status {
    return bg.OK
}

stats :: proc "c" (out: ^rt.Managed_Callable_Stats) -> bg.Status {
    out^ = {
        storage_bytes = 123,
    }
    return bg.OK
}

@(test)
optional_handoff :: proc(t: ^testing.T) {
    testing.expect(t, C_FINGERPRINT != 0 && rt.managed_callable_fingerprint() == C_FINGERPRINT)
    source := bg.Capsule {
        user  = rawptr(uintptr(17)),
        realm = 1,
    }
    before := source
    h, s := rt.managed_callable_create(&source, 2)
    testing.expect(t, s == bg.UNSUPPORTED && h.token == 0 && source == before)
    api := rt.Managed_Callable_API {
        size        = size_of(rt.Managed_Callable_API),
        version     = rt.MANAGED_CALLABLE_VERSION,
        fingerprint = C_FINGERPRINT,
        create      = create,
        close       = close,
        collect     = collect,
        stats       = stats,
    }
    testing.expect(t, rt.odin_scripts_set_managed_callable_api(nil) == bg.INCOMPATIBLE)

    for bad in 0 ..< 7 {
        invalid := api

        switch bad {
        case 0:
            invalid.size -= 1
        case 1:
            invalid.version += 1
        case 2:
            invalid.fingerprint ~= 1
        case 3:
            invalid.create = nil
        case 4:
            invalid.close = nil
        case 5:
            invalid.collect = nil
        case 6:
            invalid.stats = nil
        }

        testing.expect(t, rt.odin_scripts_set_managed_callable_api(&invalid) == bg.INCOMPATIBLE)
    }

    testing.expect(t, rt.odin_scripts_set_managed_callable_api(&api) == bg.OK)
    testing.expect(t, rt.odin_scripts_set_managed_callable_api(&api) == bg.INCOMPATIBLE)
    h, s = rt.managed_callable_create(&source, 2)
    testing.expect(t, s == bg.OK && h.token == 99 && source.user == nil)
    testing.expect(t, rt.managed_callable_close(&h) == bg.OK && h.token == 0)
    testing.expect(t, rt.managed_callable_close(nil) == bg.INVALID_ARGUMENT)
    value, status := rt.managed_callable_stats()
    testing.expect(t, status == bg.OK && value.storage_bytes == 123 && rt.managed_callable_collect() == bg.OK)
}
