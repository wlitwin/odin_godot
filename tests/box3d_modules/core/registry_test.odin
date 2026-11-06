package host_core_test

import rt "base:runtime"
import "core:mem"
import "core:testing"
import bg "godot:box3d/godot"
import bh "godot:box3d/godot/host"

NATIVE :: #config(BOX3D_LIBRARY, "/tmp/odin-box3d-goal-t4jbbj4v/box3d-native-p4/cache/build/Release/libogb3.a")
foreign import native {"system:" + NATIVE}

when ODIN_OS == .Linux {
    foreign import math "system:m"
    foreign import pthread "system:pthread"
}

foreign native {
    @(link_name = "ogb3_domain_contract_get")
    contract_get :: proc(_: ^bg.Domain_Contract) -> bg.Status ---
    @(link_name = "ogb3_engine_allocation_stats")
    engine_stats :: proc(_: ^bg.Allocation_Stats) -> bg.Status ---
    @(link_name = "ogb3_snapshot_allocation_stats")
    wrapper_stats :: proc(_: ^bg.Allocation_Stats) -> bg.Status ---
    @(link_name = "ogb3_host_owner_open")
    owner_open :: proc(_: u64, _: u64, _: u64, _: ^u64) -> bg.Status ---
    @(link_name = "ogb3_host_owner_set")
    owner_set :: proc(_: u64, _: u64, _: u64, _: u64) -> bg.Status ---
    @(link_name = "ogb3_host_owner_close")
    owner_close :: proc(_: u64, _: u64) -> bg.Status ---
    @(link_name = "ogb3_host_ledger_get")
    ledger_get :: proc(_: u64, _: ^bg.Ledger_Stats) -> bg.Status ---
    @(link_name = "ogb3_world_create")
    world_create :: proc(_: ^World_Def, _: ^u32) -> bg.Status ---
    @(link_name = "ogb3_world_destroy")
    world_destroy :: proc(_: u32) -> bg.Status ---
    @(link_name = "ogb3_snapshot_capture")
    capture :: proc(_: u32, _: ^rawptr) -> bg.Status ---
    @(link_name = "ogb3_snapshot_release")
    release :: proc(_: rawptr) ---
    @(link_name = "ogb3_state_dump")
    state_dump :: proc(_: u32, _: [^]u8, _: u64, _: ^u64) -> bg.Status ---
}

World_Def :: struct {
    gravity:           [3]f32,
    sleep, continuous: u32,
}

Code :: struct {
    refs, drops: int,
}

Fixture :: struct {
    depth:          int,
    allowed:        bool,
    deny_proc:      bool,
    code_a, code_b: Code,
}

g: Fixture

enter :: proc "c" (_: rawptr) -> bg.Status {
    if !g.allowed {
        return bg.UNSUPPORTED
    }

    g.depth += 1
    return bg.OK
}

leave :: proc "c" (_: rawptr) {
    g.depth -= 1
}

protected :: proc "c" (_: rawptr) -> bg.Status {
    if !g.allowed {
        return bg.UNSUPPORTED
    }

    return g.depth > 0 ? bg.OK : bg.INCOMPATIBLE
}

retain_code :: proc "c" (_: rawptr, code: rawptr) {
    (cast(^Code)code).refs += 1
}

drop_code :: proc "c" (_: rawptr, code: rawptr) {
    c := cast(^Code)code
    c.refs -= 1
    c.drops += 1
}

origin_proc :: proc "c" (_: rawptr, _: rawptr, _: rawptr) -> bg.Status {
    return g.deny_proc ? bg.INCOMPATIBLE : bg.OK
}

Managed :: struct {
    refs:             int,
    in_dispatch:      bool,
    drop_in_dispatch: bool,
    deny_drop:        bool,
    deny_retain:      bool,
    destroyed:        int,
}

retain_data :: proc "c" (user: rawptr) -> bg.Status {
    if (cast(^Managed)user).deny_retain {
        return bg.CAPACITY
    }

    (cast(^Managed)user).refs += 1
    return bg.OK
}

drop_data :: proc "c" (user: rawptr) -> bg.Status {
    d := cast(^Managed)user

    if d.deny_drop {
        return bg.CAPACITY
    }

    d.drop_in_dispatch = d.drop_in_dispatch || d.in_dispatch
    d.refs -= 1
    return bg.OK
}

Payload :: struct {
    owner:   bg.Owner,
    service: bg.Service,
    managed: ^Managed,
    value:   u64,
}

Read_Args :: struct {
    value: u64,
}

dispatch :: proc "c" (data: rawptr, op: u32, args: rawptr) -> bg.Status {
    context = rt.default_context()
    p := cast(^Payload)data

    if p.owner.check(p.owner.user, bg.READ) != bg.OK {
        return bg.INCOMPATIBLE
    }

    managed := p.managed
    managed.in_dispatch = true
    defer managed.in_dispatch = false

    switch op {
    case bg.CAPSULE_DESTROY:
        p.managed.destroyed += 1
        s := p.owner.drop(p.owner.user)

        if s != bg.OK {
            return s
        }

        free(p)
        return bg.OK
    case bg.CAPSULE_CLONE:
        a := cast(^bg.Capsule_Clone_Args)args

        if a == nil || a.out == nil {
            return bg.INVALID_ARGUMENT
        }

        s := p.owner.retain(p.owner.user)

        if s != bg.OK {
            return s
        }

        clone := new(Payload)
        clone^ = p^
        s = p.service.capsule_create(p.service.user, &clone.owner, clone, dispatch, a.out)

        if s != bg.OK {
            _ = clone.owner.drop(clone.owner.user)
            free(clone)
        }

        return s
    case 2:
        if args == nil {
            return bg.INVALID_ARGUMENT
        }

        (cast(^Read_Args)args).value = p.value
        return bg.OK
    case 3:
        return p.owner.check(p.owner.user, bg.EXECUTE)
    }

    return bg.UNSUPPORTED
}

@(test)
actual_native_ledger_origin_lifetime_and_complete_capsule :: proc(t: ^testing.T) {
    g = {
        allowed = true,
    }
    testing.expect_value(t, bg.module_profile(), u32(0)) // pure type import is inert
    c: bg.Domain_Contract
    testing.expect_value(t, contract_get(&c), bg.OK)
    api := bg.Native_API{c, engine_stats, wrapper_stats, owner_open, owner_set, owner_close, ledger_get}
    hooks := bg.Core_Hooks {
        enter       = enter,
        leave       = leave,
        protected   = protected,
        code_retain = retain_code,
        code_drop   = drop_code,
        procedure   = origin_proc,
    }
    testing.expect_value(t, bh.registry_init(api, hooks), bg.OK)
    a, b: bg.Service
    testing.expect_value(t, bh.producer_create(&g.code_a, &a), bg.OK)
    testing.expect_value(t, bh.producer_create(&g.code_b, &b), bg.OK)
    testing.expect(t, a.realm != b.realm && a.realm != 0 && b.realm != 0)
    testing.expect_value(t, a.domain_check(a.user, c.cookie), bg.INCOMPATIBLE)
    testing.expect_value(t, enter(nil), bg.OK)
    scope, status := bh.origin_enter(a.user)
    testing.expect_value(t, status, bg.OK)
    testing.expect_value(t, a.domain_check(a.user, c.cookie), bg.OK)
    testing.expect_value(t, a.domain_check(a.user, c.cookie + 1), bg.INCOMPATIBLE)
    weak: u64
    testing.expect_value(t, bh.context_create(a.user, &weak), bg.OK)
    bh.origin_leave(scope)
    scope, status = bh.origin_enter(a.user, weak)
    testing.expect_value(t, status, bg.OK)
    source, err := mem.alloc(64)
    testing.expect(t, err == nil && source != nil)
    testing.expect_value(t, bh.context_bind(weak, source, 64), bg.OK)
    bad_lease := bg.Data_Lease{source, retain_data, drop_data}
    rejected_owner := bg.Owner {
        user = rawptr(uintptr(777)),
    }
    testing.expect_value(t, a.owner_create(a.user, 1, &bad_lease, &rejected_owner), bg.UNSUPPORTED)
    testing.expect_value(t, rejected_owner.user, rawptr(uintptr(777)))
    managed := new(Managed)
    lease := bg.Data_Lease{managed, retain_data, drop_data}
    owner: bg.Owner
    g.deny_proc = true
    testing.expect_value(t, a.owner_create(a.user, 1, &lease, &owner), bg.INCOMPATIBLE)
    testing.expect_value(t, managed.refs, 0)
    testing.expect_value(t, g.code_a.refs, 0)
    g.deny_proc = false
    managed.deny_retain = true
    testing.expect_value(t, a.owner_create(a.user, 1, &lease, &owner), bg.CAPACITY)
    testing.expect_value(t, managed.refs, 0)
    testing.expect_value(t, g.code_a.refs, 0)
    managed.deny_retain = false
    testing.expect_value(t, a.owner_create(a.user, 1, &lease, &owner), bg.OK)
    testing.expect_value(t, owner.context_caps, bg.MANAGED_DATA | bg.WEAK_INSTANCE)
    testing.expect_value(t, managed.refs, 1)
    testing.expect_value(t, g.code_a.refs, 1)
    p := new(Payload, rt.default_context().allocator)
    p^ = {owner, a, managed, 123456}
    capsule: bg.Capsule
    testing.expect_value(t, a.capsule_create(a.user, &owner, p, dispatch, &capsule), bg.OK)
    bh.origin_leave(scope)
    leave(nil)
    // No active origin: direct typed/owner use cannot reach payload/type metadata.
    testing.expect_value(t, owner.check(owner.user, bg.READ), bg.INCOMPATIBLE)
    testing.expect_value(t, owner.drop(owner.user), bg.INCOMPATIBLE)
    testing.expect_value(t, enter(nil), bg.OK)
    foreign_scope, fs := bh.origin_enter(b.user)
    testing.expect_value(t, fs, bg.OK)
    testing.expect_value(t, owner.check(owner.user, bg.READ), bg.INCOMPATIBLE)
    // Core OUTERMOST dispatch changes B->A, holds the code through callback return.
    read: Read_Args
    testing.expect_value(t, capsule.invoke(capsule.user, 2, &read), bg.OK)
    testing.expect_value(t, read.value, u64(123456))
    testing.expect_value(t, b.domain_check(b.user, c.cookie), bg.OK) // restored caller realm
    bh.origin_leave(foreign_scope)
    leave(nil)
    // Actual source memory dies. Only the independent retained data context lives.
    testing.expect_value(t, enter(nil), bg.OK)
    scope, status = bh.origin_enter(a.user, weak)
    testing.expect_value(t, status, bg.OK)
    testing.expect_value(t, bh.context_invalidate(weak), bg.OK)
    testing.expect_value(t, a.owner_create(a.user, 0, &bad_lease, &rejected_owner), bg.UNSUPPORTED)
    mem.free(source)
    testing.expect_value(t, bh.context_release(weak), bg.OK)
    bh.origin_leave(scope)
    leave(nil)
    testing.expect_value(t, capsule.invoke(capsule.user, 3, nil), bg.INVALID_HANDLE)
    testing.expect_value(t, capsule.invoke(capsule.user, 2, &read), bg.OK)
    clone: bg.Capsule
    args := bg.Capsule_Clone_Args{&clone}
    testing.expect_value(t, capsule.invoke(capsule.user, bg.CAPSULE_CLONE, &args), bg.OK)
    testing.expect_value(t, clone.invoke(clone.user, 2, &read), bg.OK)
    testing.expect_value(t, capsule.destroy(capsule.user), bg.OK)
    testing.expect_value(t, capsule.destroy(capsule.user), bg.INVALID_HANDLE)
    managed.deny_drop = true
    testing.expect_value(t, clone.destroy(clone.user), bg.CAPACITY)
    testing.expect_value(t, managed.destroyed, 2)
    testing.expect_value(t, managed.refs, 1)
    testing.expect_value(t, clone.invoke(clone.user, 2, &read), bg.INVALID_HANDLE)
    managed.deny_drop = false
    testing.expect_value(t, clone.destroy(clone.user), bg.OK)
    testing.expect_value(t, managed.destroyed, 2)
    testing.expect_value(t, managed.refs, 0)
    testing.expect(t, !managed.drop_in_dispatch)
    testing.expect_value(t, g.code_a.refs, 0)
    testing.expect_value(t, g.depth, 0)
    free(managed)
    // Unsupported threads cannot acquire a gate or mutate/destroy an owner.
    g.allowed = false
    testing.expect_value(t, clone.invoke(clone.user, 2, &read), bg.UNSUPPORTED)
    g.allowed = true
    testing.expect_value(t, bh.producer_destroy(a.user), bg.OK)
    testing.expect_value(t, bh.producer_destroy(b.user), bg.OK)
    testing.expect_value(t, bh.registry_shutdown(), bg.OK)
    ls: bg.Ledger_Stats
    testing.expect_value(t, ledger_get(c.cookie, &ls), bg.OK)
    testing.expect_value(
        t,
        ls.host_live_bytes + ls.host_reserved_bytes + ls.engine_live_bytes + ls.snapshot_live_bytes,
        u64(0),
    )
    testing.expect_value(t, ls.owner_count, u32(0))
}

@(test)
composite_budget_consumes_cumulative_requests_and_exact_limit :: proc(t: ^testing.T) {
    g = {
        allowed = true,
    }
    c: bg.Domain_Contract
    testing.expect_value(t, contract_get(&c), bg.OK)
    api := bg.Native_API{c, engine_stats, wrapper_stats, owner_open, owner_set, owner_close, ledger_get}
    hooks := bg.Core_Hooks {
        enter       = enter,
        leave       = leave,
        protected   = protected,
        code_retain = retain_code,
        code_drop   = drop_code,
        procedure   = origin_proc,
    }
    testing.expect_value(t, bh.registry_init(api, hooks), bg.OK)
    a, b: bg.Service
    testing.expect_value(t, bh.producer_create(&g.code_a, &a), bg.OK)
    testing.expect_value(t, bh.producer_create(&g.code_b, &b), bg.OK)
    testing.expect_value(t, enter(nil), bg.OK)
    scope, s := bh.origin_enter(a.user)
    testing.expect_value(t, s, bg.OK)
    initial: bg.Request_Totals
    testing.expect_value(t, a.request_totals(a.user, &initial), bg.OK)
    mark: u64
    testing.expect_value(t, a.budget_begin(a.user, 4 * 1024 * 1024, &mark), bg.OK)
    // These allocations are freed before observation; net live is zero, requests
    // still consume the promise, together with actual engine/wrapper allocations.
    bytes, e := mem.alloc(400)
    testing.expect(t, e == nil)
    mem.free(bytes)
    testing.expect_value(t, a.account(a.user, bg.CATEGORY_KIT_CORE, 0, 400), bg.OK)
    wd := World_Def {
        gravity           = {0, -10, 0},
        enable_sleep      = 1,
        enable_continuous = 1,
    }
    world: u32
    image: rawptr
    testing.expect_value(t, world_create(&wd, &world), bg.OK)
    testing.expect_value(t, capture(world, &image), bg.OK)
    release(image)
    testing.expect_value(t, world_destroy(world), bg.OK)
    after: bg.Request_Totals
    testing.expect_value(t, a.request_totals(a.user, &after), bg.OK)
    testing.expect(
        t,
        after.native > initial.native && after.wrapper > initial.wrapper && after.host == initial.host + 400,
    )
    testing.expect_value(t, a.budget_reconcile(a.user, mark), bg.OK)
    ls: bg.Ledger_Stats
    testing.expect_value(t, ledger_get(c.cookie, &ls), bg.OK)
    remaining := u64(4 * 1024 * 1024) - (after.total - initial.total)
    testing.expect_value(t, ls.host_reserved_bytes, remaining)
    pure_extra: u64
    testing.expect_value(t, a.legacy_extra(a.user, 0, 0, remaining, &pure_extra), bg.OK)
    testing.expect_value(t, pure_extra, ls.host_live_bytes + remaining)
    testing.expect_value(t, a.legacy_extra(a.user, 0, 0, remaining + 1, &pure_extra), bg.CAPACITY)
    nested: u64
    testing.expect_value(t, a.budget_begin(a.user, 4 * 1024 * 1024, &nested), bg.OK)
    testing.expect_value(t, a.budget_end(a.user, mark), bg.INVALID_HANDLE)
    extra: u64
    testing.expect_value(t, a.legacy_extra(a.user, nested, 100, 7, &extra), bg.OK)
    testing.expect_value(t, extra, ls.host_live_bytes + remaining - 100 + 7)
    testing.expect_value(t, a.legacy_extra(a.user, nested, 101, 7, &extra), bg.INVALID_ARGUMENT)
    testing.expect_value(t, a.budget_end(a.user, nested), bg.OK)
    testing.expect_value(t, a.budget_end(a.user, mark), bg.OK)
    testing.expect_value(t, a.budget_end(a.user, mark), bg.INVALID_HANDLE)
    // Two published worlds must retain all normalized future-affecting bytes
    // when B is denied before an allocation budget, not merely their poses.
    world_a, world_b: u32
    wd.gravity = {1, -10, 0}
    testing.expect_value(t, world_create(&wd, &world_a), bg.OK)
    wd.gravity = {-1, -5, 0}
    testing.expect_value(t, world_create(&wd, &world_b), bg.OK)
    old_a := world_bytes(t, world_a)
    old_b := world_bytes(t, world_b)
    defer delete(old_a)
    defer delete(old_b)
    new_a := make([]u8, len(old_a))
    new_b := make([]u8, len(old_b))
    defer delete(new_a)
    defer delete(new_b)
    // Exact domain limit across two producers: B owns10 live bytes, A holds
    // the remaining promise. Another producer allocation budget is Unsupported.
    bh.origin_leave(scope)
    scope, s = bh.origin_enter(b.user)
    testing.expect_value(t, s, bg.OK)
    bmark: u64
    testing.expect_value(t, b.budget_begin(b.user, 10, &bmark), bg.OK)
    testing.expect_value(t, b.account(b.user, bg.CATEGORY_REPLAY_CORE, 10, 10), bg.OK)
    testing.expect_value(t, b.budget_end(b.user, bmark), bg.OK)
    bh.origin_leave(scope)
    scope, s = bh.origin_enter(a.user)
    testing.expect_value(t, s, bg.OK)
    testing.expect_value(t, ledger_get(c.cookie, &ls), bg.OK)
    headroom := ls.limit_bytes - ls.live_bytes
    testing.expect_value(t, a.budget_begin(a.user, headroom, &mark), bg.OK)
    testing.expect_value(t, ledger_get(c.cookie, &ls), bg.OK)
    testing.expect_value(t, ls.admitted_bytes, ls.limit_bytes)
    before := ls
    bh.origin_leave(scope)
    scope, s = bh.origin_enter(b.user)
    testing.expect_value(t, s, bg.OK)
    rejected := u64(123)
    testing.expect_value(t, b.budget_begin(b.user, 1, &rejected), bg.UNSUPPORTED)
    testing.expect_value(t, rejected, u64(123))
    testing.expect_value(t, b.account(b.user, bg.CATEGORY_REPLAY_CORE, 11, 11), bg.UNSUPPORTED)
    testing.expect_value(t, ledger_get(c.cookie, &ls), bg.OK)
    testing.expect_value(t, ls, before)
    size_a, size_b: u64
    testing.expect_value(t, state_dump(world_a, raw_data(new_a), u64(len(new_a)), &size_a), bg.OK)
    testing.expect_value(t, state_dump(world_b, raw_data(new_b), u64(len(new_b)), &size_b), bg.OK)
    testing.expect_value(t, size_a, u64(len(old_a)))
    testing.expect_value(t, size_b, u64(len(old_b)))
    testing.expect_value(t, mem.compare(old_a, new_a), 0)
    testing.expect_value(t, mem.compare(old_b, new_b), 0)
    bh.origin_leave(scope)
    scope, s = bh.origin_enter(a.user)
    testing.expect_value(t, s, bg.OK)
    testing.expect_value(t, a.budget_end(a.user, mark), bg.OK)
    testing.expect_value(t, a.budget_begin(a.user, headroom + 1, &rejected), bg.CAPACITY)
    bh.origin_leave(scope)
    scope, s = bh.origin_enter(b.user)
    testing.expect_value(t, s, bg.OK)
    testing.expect_value(t, b.account(b.user, bg.CATEGORY_REPLAY_CORE, 0, 10), bg.OK)
    bh.origin_leave(scope)
    scope, s = bh.origin_enter(a.user)
    testing.expect_value(t, s, bg.OK)
    testing.expect_value(t, world_destroy(world_a), bg.OK)
    testing.expect_value(t, world_destroy(world_b), bg.OK)
    // Too-small promise fails even when memory was freed and no live delta remains.
    testing.expect_value(t, a.budget_begin(a.user, 10, &mark), bg.OK)
    testing.expect_value(t, a.account(a.user, bg.CATEGORY_KIT_CORE, 0, 411), bg.CAPACITY)
    testing.expect_value(t, a.budget_end(a.user, mark), bg.CAPACITY)
    testing.expect_value(t, ledger_get(c.cookie, &ls), bg.OK)
    testing.expect_value(t, ls.host_reserved_bytes, u64(0))
    bh.origin_leave(scope)
    leave(nil)
    testing.expect_value(t, bh.producer_destroy(a.user), bg.OK)
    testing.expect_value(t, bh.producer_destroy(b.user), bg.OK)
    testing.expect_value(t, bh.registry_shutdown(), bg.OK)
    testing.expect_value(t, ledger_get(c.cookie, &ls), bg.OK)
    testing.expect_value(t, ls.owner_count, u32(0))
    testing.expect_value(t, ls.admitted_bytes, u64(0))
}

world_bytes :: proc(t: ^testing.T, world: u32) -> []u8 {
    n: u64
    testing.expect_value(t, state_dump(world, nil, 0, &n), bg.OK)
    bytes := make([]u8, int(n))
    testing.expect_value(t, state_dump(world, raw_data(bytes), n, &n), bg.OK)
    return bytes
}
