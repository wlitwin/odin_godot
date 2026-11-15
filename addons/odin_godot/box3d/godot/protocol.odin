package box3d_godot

// Pure C-shaped host protocol. No native, Godot, framework, typeid or allocator
// crosses this boundary. Copies of this package in producers only call the
// stable Core function pointers received in Service.
Status :: distinct i32
OK :: Status(0)
INVALID_ARGUMENT :: Status(1)
INVALID_HANDLE :: Status(2)
OUT_OF_MEMORY :: Status(3)
CAPACITY :: Status(4)
UNSUPPORTED :: Status(5)
INCOMPATIBLE :: Status(6)
CORRUPT :: Status(7)
VERSION :: u32(1)

Domain_Contract :: struct {
    cookie:                                                                                                u64,
    size, version, abi_version, logical_version, resource_version, recovery_version, pointer_bits, endian: u32,
    build, target:                                                                                         [32]u8,
}

Allocation_Stats :: struct {
    total_calls, total_bytes, live_bytes, high_water_bytes: u64,
}

Ledger_Stats :: struct {
    engine_live_bytes,
    snapshot_live_bytes,
    host_live_bytes,
    host_reserved_bytes,
    live_bytes,
    admitted_bytes,
    limit_bytes,
    committed_peak_bytes,
    successful_updates,
    ledger_storage_bytes: u64,
    owner_count,
    owner_capacity:                                                                                                                                                           u32,
}

Owner_Info :: struct {
    producer, component, live_bytes, reserved_bytes: u64,
}

READ :: u32(0)
EXECUTE :: u32(1)
MANAGED_DATA :: u32(1)
WEAK_INSTANCE :: u32(2)
INDEPENDENT_CONTEXT :: u32(4)

Owner :: struct {
    user:                   rawptr,
    realm:                  u64,
    context_caps, reserved: u32,
    check:                  proc "c" (_: rawptr, _: u32) -> Status,
    retain:                 proc "c" (_: rawptr) -> Status,
    drop:                   proc "c" (_: rawptr) -> Status,
}

// Null data means no borrowed context. A nonnull data/allocator context MUST
// provide paired producer C retain/drop callbacks, independent of weak self.
Data_Lease :: struct {
    user:         rawptr,
    retain, drop: proc "c" (_: rawptr) -> Status,
}

Origin_Scope :: struct {
    producer, ctx: u64,
}

Request_Totals :: struct {
    native, wrapper, host, total: u64,
}

CATEGORY_KIT_CORE :: u32(1)
CATEGORY_KIT_PROVIDER :: u32(2)
CATEGORY_KIT_CODEC :: u32(3)
CATEGORY_REPLAY_CORE :: u32(4)
CATEGORY_REPLAY_PROVIDER :: u32(5)
CATEGORY_REPLAY_CODEC :: u32(6)
CAPSULE_DESTROY :: u32(0)
CAPSULE_CLONE :: u32(1)
// All typed payload casts occur inside this originating C dispatcher, after
// Core acquired the execution gate, generation call pin and protected origin.
Capsule_Dispatch :: proc "c" (data: rawptr, operation: u32, args: rawptr) -> Status

Capsule :: struct {
    user:    rawptr,
    realm:   u64,
    invoke:  proc "c" (_: rawptr, _: u32, _: rawptr) -> Status,
    destroy: proc "c" (_: rawptr) -> Status,
}

Capsule_Clone_Args :: struct {
    out: ^Capsule,
}

Service :: struct {
    size, version:                u32,
    realm:                        u64,
    domain:                       Domain_Contract,
    user:                         rawptr,
    domain_check:                 proc "c" (_: rawptr, _: u64) -> Status,
    owner_create:                 proc "c" (_: rawptr, _: u32, _: ^Data_Lease, _: ^Owner) -> Status,
    account:                      proc "c" (_: rawptr, _: u32, _: u64, _: u64) -> Status,
    request_totals:               proc "c" (_: rawptr, _: ^Request_Totals) -> Status,
    budget_begin:                 proc "c" (_: rawptr, _: u64, _: ^u64) -> Status,
    budget_reconcile, budget_end: proc "c" (_: rawptr, _: u64) -> Status,
    legacy_extra:                 proc "c" (_: rawptr, _: u64, _: u64, _: u64, _: ^u64) -> Status,
    capsule_create:               proc "c" (
        _: rawptr,
        _: ^Owner,
        _: rawptr,
        _: Capsule_Dispatch,
        _: ^Capsule,
    ) -> Status,
}

Native_API :: struct {
    contract:                    Domain_Contract,
    engine_stats, wrapper_stats: proc "c" (_: ^Allocation_Stats) -> Status,
    owner_open:                  proc "c" (_: u64, _: u64, _: u64, _: ^u64) -> Status,
    owner_set:                   proc "c" (_: u64, _: u64, _: u64, _: u64) -> Status,
    owner_close:                 proc "c" (_: u64, _: u64) -> Status,
    ledger_get:                  proc "c" (_: u64, _: ^Ledger_Stats) -> Status,
}

// Hooks point into stable Core, extending its existing reload gate/refcounts.
Core_Hooks :: struct {
    user:                   rawptr,
    enter:                  proc "c" (_: rawptr) -> Status,
    leave:                  proc "c" (_: rawptr),
    protected:              proc "c" (_: rawptr) -> Status,
    code_retain, code_drop: proc "c" (_: rawptr, _: rawptr),
    procedure:              proc "c" (_: rawptr, _: rawptr, _: rawptr) -> Status,
}

Module_Discover :: proc "c" (_: ^Domain_Contract) -> Status
Module_Install :: proc "c" (_: ^Service) -> Status
@(private)
module_discover: Module_Discover
@(private)
module_hooks: [8]Module_Install
@(private)
module_hook_count: int
@(private)
module_service: Service
@(private)
REQUIRE_DOMAIN :: #config(BOX3D_REQUIRE_DOMAIN, false)
@(private)
EXPECTED_BUILD :: #config(BOX3D_EXPECTED_BUILD, "")
@(private)
EXPECTED_TARGET :: #config(BOX3D_EXPECTED_TARGET, "")

@(private)
expected_digest :: proc "contextless" (text: string, actual: [32]u8) -> bool {
    encoded := text

    if len(encoded) >= 7 && encoded[:7] == "sha256:" {
        encoded = encoded[7:]
    }

    if len(encoded) != 64 {
        return false
    }

    for i in 0 ..< 32 {
        value := u8(0)

        for j in 0 ..< 2 {
            c := encoded[2 * i + j]
            n: u8

            if c >= '0' && c <= '9' {
                n = c - '0'
            } else if c >= 'a' && c <= 'f' {
                n = c - 'a' + 10
            } else if c >= 'A' && c <= 'F' {
                n = c - 'A' + 10
            } else {
                return false
            }

            value = value * 16 + n
        }

        if actual[i] != value {
            return false
        }
    }

    return true
}

module_register :: proc "contextless" (discover: Module_Discover, install: Module_Install) -> Status {
    if discover == nil || install == nil || module_discover != nil {
        return INVALID_ARGUMENT
    }

    if module_hook_count == len(module_hooks) {
        return CAPACITY
    }

    module_discover = discover
    module_hooks[module_hook_count] = install
    module_hook_count += 1
    return OK
}

module_add_hook :: proc "contextless" (install: Module_Install) -> Status {
    if install == nil {
        return INVALID_ARGUMENT
    }

    if module_hook_count == len(module_hooks) {
        return CAPACITY
    }

    module_hooks[module_hook_count] = install
    module_hook_count += 1
    return OK
}

module_profile :: proc "contextless" () -> u32 {
    return module_discover != nil ? 1 : 0
}

module_contract :: proc "c" (out: ^Domain_Contract) -> Status {
    if out == nil {
        return INVALID_ARGUMENT
    }

    if module_discover == nil {
        return UNSUPPORTED
    }

    actual: Domain_Contract
    s := module_discover(&actual)

    if s != OK {
        return s
    }

    when REQUIRE_DOMAIN {
        if !expected_digest(EXPECTED_BUILD, actual.build) || !expected_digest(EXPECTED_TARGET, actual.target) {
            return INCOMPATIBLE
        }
    }

    out^ = actual
    return OK
}

module_install :: proc "c" (service: ^Service) -> Status {
    if service == nil ||
       service.size != size_of(Service) ||
       service.version != VERSION ||
       service.realm == 0 ||
       service.user == nil ||
       service.domain_check == nil ||
       service.owner_create == nil ||
       service.account == nil ||
       service.request_totals == nil ||
       service.budget_begin == nil ||
       service.budget_reconcile == nil ||
       service.budget_end == nil ||
       service.legacy_extra == nil ||
       service.capsule_create == nil {
        return INCOMPATIBLE
    }

    if module_service.realm != 0 {
        return INCOMPATIBLE
    }

    actual: Domain_Contract
    status := module_contract(&actual)

    if status != OK {
        return status
    }

    if actual != service.domain {
        return INCOMPATIBLE
    }

    for hook in module_hooks[:module_hook_count] {
        s := hook(service)

        if s != OK {
            return s
        }
    }

    module_service = service^
    return OK
}

service_get :: proc "contextless" () -> Service {
    return module_service
}

// Fingerprint includes actual sizes/offsets of every host-owned public record.
protocol_fingerprint :: proc "contextless" () -> u64 {
    values := [?]uintptr {
        uintptr(VERSION),
        size_of(Domain_Contract),
        align_of(Domain_Contract),
        offset_of(Domain_Contract, build),
        offset_of(Domain_Contract, target),
        size_of(Owner),
        align_of(Owner),
        offset_of(Owner, realm),
        offset_of(Owner, context_caps),
        offset_of(Owner, check),
        offset_of(Owner, retain),
        offset_of(Owner, drop),
        size_of(Data_Lease),
        offset_of(Data_Lease, retain),
        offset_of(Data_Lease, drop),
        size_of(Request_Totals),
        size_of(Capsule),
        offset_of(Capsule, realm),
        offset_of(Capsule, invoke),
        offset_of(Capsule, destroy),
        size_of(Capsule_Clone_Args),
        size_of(Service),
        align_of(Service),
        offset_of(Service, realm),
        offset_of(Service, domain),
        offset_of(Service, user),
        offset_of(Service, domain_check),
        offset_of(Service, owner_create),
        offset_of(Service, account),
        offset_of(Service, request_totals),
        offset_of(Service, budget_begin),
        offset_of(Service, budget_reconcile),
        offset_of(Service, budget_end),
        offset_of(Service, legacy_extra),
        offset_of(Service, capsule_create),
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
