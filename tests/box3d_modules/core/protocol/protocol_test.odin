package host_protocol_test
import "core:testing"
import bg "godot:box3d/godot"
NATIVE :: #config(BOX3D_LIBRARY, "")
foreign import native {"system:" + NATIVE}

when ODIN_OS == .Linux {
    foreign import math "system:m"
    foreign import pthread "system:pthread"
}

foreign native {@(link_name = "ogb3_domain_contract_get")
    get :: proc(_: ^bg.Domain_Contract) -> bg.Status ---
}

EXPECTED_FP :: #config(HOST_PROTOCOL_FINGERPRINT, u64(0))
REJECT :: #config(TEST_EXPECTED_REJECT, false)
installed: int

hook :: proc "c" (_: ^bg.Service) -> bg.Status {
    installed += 1
    return bg.OK
}

check :: proc "c" (_: rawptr, _: u64) -> bg.Status {
    return bg.OK
}

owner :: proc "c" (_: rawptr, _: u32, _: ^bg.Data_Lease, _: ^bg.Owner) -> bg.Status {
    return bg.OK
}

account :: proc "c" (_: rawptr, _: u32, _: u64, _: u64) -> bg.Status {
    return bg.OK
}

totals :: proc "c" (_: rawptr, _: ^bg.Request_Totals) -> bg.Status {
    return bg.OK
}

begin :: proc "c" (_: rawptr, _: u64, _: ^u64) -> bg.Status {
    return bg.OK
}

mark :: proc "c" (_: rawptr, _: u64) -> bg.Status {
    return bg.OK
}

legacy :: proc "c" (_: rawptr, _: u64, _: u64, _: u64, _: ^u64) -> bg.Status {
    return bg.OK
}

capsule :: proc "c" (_: rawptr, _: ^bg.Owner, _: rawptr, _: bg.Capsule_Dispatch, _: ^bg.Capsule) -> bg.Status {
    return bg.OK
}

@(test)
preboot_expected_identity_and_C_ABI :: proc(t: ^testing.T) {
    testing.expect_value(t, bg.module_profile(), u32(0))
    testing.expect_value(t, bg.protocol_fingerprint(), EXPECTED_FP)
    testing.expect_value(t, bg.module_register(get, hook), bg.OK)
    testing.expect_value(t, bg.module_register(get, hook), bg.INVALID_ARGUMENT)
    testing.expect_value(t, bg.module_add_hook(hook), bg.OK)
    testing.expect_value(t, bg.module_profile(), u32(1))
    actual: bg.Domain_Contract
    testing.expect_value(t, get(&actual), bg.OK)
    discovered := actual
    discovered.cookie = 777
    status := bg.module_contract(&discovered)

    when REJECT {
        testing.expect_value(t, status, bg.INCOMPATIBLE)
        testing.expect_value(t, discovered.cookie, u64(777))
        testing.expect_value(t, installed, 0)
        return
    }

    testing.expect_value(t, status, bg.OK)
    testing.expect_value(t, discovered, actual)
    service := bg.Service {
        size             = u32(size_of(bg.Service)),
        version          = bg.VERSION,
        realm            = 123,
        domain           = actual,
        user             = rawptr(uintptr(123)),
        domain_check     = check,
        owner_create     = owner,
        account          = account,
        request_totals   = totals,
        budget_begin     = begin,
        budget_reconcile = mark,
        budget_end       = mark,
        legacy_extra     = legacy,
        capsule_create   = capsule,
    }
    bad := service
    bad.domain.cookie += 1
    testing.expect_value(t, bg.module_install(&bad), bg.INCOMPATIBLE)
    testing.expect_value(t, installed, 0)
    bad = service
    bad.budget_end = nil
    testing.expect_value(t, bg.module_install(&bad), bg.INCOMPATIBLE)
    testing.expect_value(t, installed, 0)
    testing.expect_value(t, bg.module_install(&service), bg.OK)
    testing.expect_value(t, installed, 2)
    testing.expect_value(t, bg.service_get(), service)
    testing.expect_value(t, bg.module_install(&service), bg.INCOMPATIBLE)
}
