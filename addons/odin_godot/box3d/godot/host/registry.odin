package box3d_host

import bg "godot:box3d/godot"
Status :: bg.Status
Domain_Contract :: bg.Domain_Contract
Allocation_Stats :: bg.Allocation_Stats
Ledger_Stats :: bg.Ledger_Stats
Owner_Info :: bg.Owner_Info
Owner :: bg.Owner
Data_Lease :: bg.Data_Lease
Request_Totals :: bg.Request_Totals
Capsule :: bg.Capsule
Capsule_Dispatch :: bg.Capsule_Dispatch
Service :: bg.Service
Native_API :: bg.Native_API
Core_Hooks :: bg.Core_Hooks
Origin_Scope :: bg.Origin_Scope
OK :: bg.OK
INVALID_ARGUMENT :: bg.INVALID_ARGUMENT
INVALID_HANDLE :: bg.INVALID_HANDLE
OUT_OF_MEMORY :: bg.OUT_OF_MEMORY
CAPACITY :: bg.CAPACITY
UNSUPPORTED :: bg.UNSUPPORTED
INCOMPATIBLE :: bg.INCOMPATIBLE
CORRUPT :: bg.CORRUPT
VERSION :: bg.VERSION
READ :: bg.READ
EXECUTE :: bg.EXECUTE
MANAGED_DATA :: bg.MANAGED_DATA
WEAK_INSTANCE :: bg.WEAK_INSTANCE
INDEPENDENT_CONTEXT :: bg.INDEPENDENT_CONTEXT
CAPSULE_DESTROY :: bg.CAPSULE_DESTROY
CAPSULE_CLONE :: bg.CAPSULE_CLONE

// This registry is instantiated only in stable Core. It is ownership bookkeeping
// around Core's existing gate/generation collector, not another dynamic loader.
// Fixed storage is charged once to the native ledger at registry_init.
MAX_PRODUCERS :: 128
MAX_OWNERS :: 1024
MAX_CAPSULES :: 1024
MAX_CONTEXTS :: 1024
MAX_CATEGORIES :: 16
MAX_MARKS :: 16

@(private)
Category :: struct {
    live, requested: u64,
}

@(private)
Mark :: struct {
    id, implicit: u64,
}

@(private)
Producer_Record :: struct {
    generation:                         u32,
    active:                             bool,
    code:                               rawptr,
    ledger:                             u64,
    categories:                         [MAX_CATEGORIES]Category,
    live, remaining, last_total, bound: u64,
    marks:                              [MAX_MARKS]Mark,
    depth:                              int,
    failed:                             bool,
}

@(private)
Owner_Record :: struct {
    generation:           u32,
    active, busy:         bool,
    producer, refs, weak: u64,
    data:                 Data_Lease,
}

@(private)
Capsule_Record :: struct {
    generation:            u32,
    active, busy, closing: bool,
    producer:              u64,
    owner:                 Owner,
    data:                  rawptr,
    dispatch:              Capsule_Dispatch,
}

@(private)
Context_Record :: struct {
    generation:     u32,
    active, alive:  bool,
    producer, refs: u64,
    borrowed_base:  rawptr,
    borrowed_size:  u64,
    source_present: bool,
}

@(private)
Registry :: struct {
    initialized:                                            bool,
    native:                                                 Native_API,
    hooks:                                                  Core_Hooks,
    core_token, host_requested, next_mark, budget_producer: u64,
    producers:                                              [MAX_PRODUCERS]Producer_Record,
    owners:                                                 [MAX_OWNERS]Owner_Record,
    capsules:                                               [MAX_CAPSULES]Capsule_Record,
    contexts:                                               [MAX_CONTEXTS]Context_Record,
}

@(private)
registry: Registry

when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
    @(private)
    active_producer: u64
    @(private)
    active_context: u64
} else {
    @(private, thread_local)
    active_producer: u64
    @(private, thread_local)
    active_context: u64
}

Registry_Stats :: struct {
    producers, owners, capsules, contexts, marks: u32,
    host_requests, storage_bytes:                 u64,
}

// Pointer-backed callback tokens reserve16 low index bits. On wasm32 retire
// a slot before its generation would truncate through uintptr; Native64 keeps
// the original full u32 generation range.
@(private)
POINTER_GENERATION_MAX :: u32(65535) when size_of(rawptr) == 4 else max(u32)

@(private)
id_of :: proc "contextless" (index: int, generation: u32) -> u64 {
    return u64(generation) << 16 | u64(index + 1)
}

@(private)
token_ptr :: proc "contextless" (id: u64) -> rawptr {
    return rawptr(uintptr(id))
}

@(private)
producer_find :: proc "contextless" (id: u64) -> ^Producer_Record {
    index := int(id & 65535) - 1

    if index < 0 || index >= MAX_PRODUCERS {
        return nil
    }

    p := &registry.producers[index]
    return p.active && u64(p.generation) == id >> 16 ? p : nil
}

@(private)
owner_find :: proc "contextless" (id: u64) -> ^Owner_Record {
    index := int(id & 65535) - 1

    if index < 0 || index >= MAX_OWNERS {
        return nil
    }

    p := &registry.owners[index]
    return p.active && u64(p.generation) == id >> 16 ? p : nil
}

@(private)
capsule_find :: proc "contextless" (id: u64) -> ^Capsule_Record {
    index := int(id & 65535) - 1

    if index < 0 || index >= MAX_CAPSULES {
        return nil
    }

    p := &registry.capsules[index]
    return p.active && u64(p.generation) == id >> 16 ? p : nil
}

@(private)
context_find :: proc "contextless" (id: u64) -> ^Context_Record {
    index := int(id & 65535) - 1

    if index < 0 || index >= MAX_CONTEXTS {
        return nil
    }

    p := &registry.contexts[index]
    return p.active && u64(p.generation) == id >> 16 ? p : nil
}

@(private)
protected :: proc "contextless" () -> Status {
    if !registry.initialized || registry.hooks.protected == nil {
        return INCOMPATIBLE
    }

    return registry.hooks.protected(registry.hooks.user)
}

@(private)
producer_guard :: proc "contextless" (user: rawptr) -> (^Producer_Record, Status) {
    s := protected()

    if s != OK {
        return nil, s
    }

    id := u64(uintptr(user))
    p := producer_find(id)

    if p == nil {
        return nil, INVALID_HANDLE
    }

    if active_producer != id {
        return nil, INCOMPATIBLE
    }

    return p, OK
}

registry_init :: proc "contextless" (native: Native_API, hooks: Core_Hooks) -> Status {
    if registry.initialized ||
       native.contract.cookie == 0 ||
       native.contract.size != size_of(Domain_Contract) ||
       native.contract.version != 1 ||
       native.engine_stats == nil ||
       native.wrapper_stats == nil ||
       native.owner_open == nil ||
       native.owner_set == nil ||
       native.owner_close == nil ||
       native.ledger_get == nil ||
       hooks.enter == nil ||
       hooks.leave == nil ||
       hooks.protected == nil ||
       hooks.code_retain == nil ||
       hooks.code_drop == nil ||
       hooks.procedure == nil {
        return INCOMPATIBLE
    }

    // Never reset slot generations: stale opaque tokens cannot alias new records.
    registry.native = native
    registry.hooks = hooks
    token: u64
    s := native.owner_open(native.contract.cookie, max(u64), max(u64), &token)

    if s != OK {
        return s
    }

    s = native.owner_set(native.contract.cookie, token, u64(size_of(Registry)), 0)

    if s != OK {
        _ = native.owner_close(native.contract.cookie, token)
        return s
    }

    registry.core_token = token
    registry.host_requested = u64(size_of(Registry))
    registry.initialized = true
    return OK
}

registry_shutdown :: proc "contextless" () -> Status {
    if !registry.initialized {
        return OK
    }

    s := registry_stats()

    if s.producers != 0 || s.owners != 0 || s.capsules != 0 || s.contexts != 0 {
        return CAPACITY
    }

    status := registry.native.owner_close(registry.native.contract.cookie, registry.core_token)

    if status != OK {
        return status
    }

    registry.initialized = false
    registry.core_token = 0
    active_producer = 0
    active_context = 0
    return OK
}

registry_stats :: proc "contextless" () -> Registry_Stats {
    r := Registry_Stats {
        host_requests = registry.host_requested,
        storage_bytes = u64(size_of(Registry)),
    }

    for p in registry.producers {
        if p.active {
            r.producers += 1
            r.marks += u32(p.depth)
        }
    }

    for p in registry.owners {
        if p.active {
            r.owners += 1
        }
    }

    for p in registry.capsules {
        if p.active {
            r.capsules += 1
        }
    }

    for p in registry.contexts {
        if p.active {
            r.contexts += 1
        }
    }

    return r
}

producer_create :: proc "contextless" (code: rawptr, out: ^Service) -> Status {
    if !registry.initialized || code == nil || out == nil {
        return INVALID_ARGUMENT
    }

    for &p, i in registry.producers {
        if !p.active && p.generation < POINTER_GENERATION_MAX {
            gen := p.generation + 1
            id := id_of(i, gen)
            token: u64
            s := registry.native.owner_open(registry.native.contract.cookie, id, 1, &token)

            if s != OK {
                return s
            }

            p = {
                generation = gen,
                active     = true,
                code       = code,
                ledger     = token,
            }
            out^ = Service {
                size             = u32(size_of(Service)),
                version          = VERSION,
                realm            = id,
                domain           = registry.native.contract,
                user             = token_ptr(id),
                domain_check     = service_domain_check,
                owner_create     = service_owner_create,
                account          = service_account,
                request_totals   = service_totals,
                budget_begin     = service_budget_begin,
                budget_reconcile = service_budget_reconcile,
                budget_end       = service_budget_end,
                legacy_extra     = service_legacy_extra,
                capsule_create   = service_capsule_create,
            }
            return OK
        }
    }

    return CAPACITY
}

producer_destroy :: proc "contextless" (user: rawptr) -> Status {
    p := producer_find(u64(uintptr(user)))

    if p == nil {
        return INVALID_HANDLE
    }

    if p.depth != 0 || p.live != 0 || p.remaining != 0 {
        return CAPACITY
    }

    id := u64(uintptr(user))

    for o in registry.owners {
        if (o.active || o.busy) && o.producer == id {
            return CAPACITY
        }
    }

    for c in registry.capsules {
        if c.active && c.producer == id {
            return CAPACITY
        }
    }

    for c in registry.contexts {
        if c.active && c.producer == id {
            return CAPACITY
        }
    }

    s := registry.native.owner_close(registry.native.contract.cookie, p.ledger)

    if s != OK {
        return s
    }

    p.active = false
    return OK
}

origin_enter :: proc "contextless" (user: rawptr, weak: u64 = 0) -> (Origin_Scope, Status) {
    s := protected()

    if s != OK {
        return {}, s
    }

    id := u64(uintptr(user))
    p := producer_find(id)

    if p == nil {
        return {}, INVALID_HANDLE
    }

    if weak != 0 {
        c := context_find(weak)

        if c == nil || c.producer != id || !c.alive {
            return {}, INVALID_HANDLE
        }
    }

    previous := Origin_Scope{active_producer, active_context}
    active_producer = id
    active_context = weak
    return previous, OK
}

origin_leave :: proc "contextless" (scope: Origin_Scope) {
    active_producer = scope.producer
    active_context = scope.ctx
}

context_create :: proc "contextless" (user: rawptr, out: ^u64) -> Status {
    if out == nil {
        return INVALID_ARGUMENT
    }

    _, s := producer_guard(user)

    if s != OK {
        return s
    }

    for &c, i in registry.contexts {
        if !c.active && c.generation < max(u32) {
            gen := c.generation + 1
            c = {
                generation     = gen,
                active         = true,
                alive          = true,
                source_present = true,
                producer       = u64(uintptr(user)),
            }
            out^ = id_of(i, gen)
            return OK
        }
    }

    return CAPACITY
}

context_bind :: proc "contextless" (token: u64, base: rawptr, size: u64) -> Status {
    c := context_find(token)

    if c == nil || !c.alive || base == nil || size == 0 {
        return INVALID_ARGUMENT
    }

    status := protected()

    if status != OK {
        return status
    }

    if c.borrowed_base != nil {
        return INCOMPATIBLE
    }

    if size > u64(max(uintptr)) - u64(uintptr(base)) {
        return INVALID_ARGUMENT
    }

    c.borrowed_base = base
    c.borrowed_size = size
    return OK
}

context_invalidate :: proc "contextless" (token: u64) -> Status {
    if token == 0 {
        return OK
    }

    c := context_find(token)

    if c == nil {
        return INVALID_HANDLE
    }

    s := protected()

    if s != OK {
        return s
    }

    c.alive = false

    if c.refs == 0 && !c.source_present {
        c.active = false
    }

    return OK
}

// Core calls this only after the actual source allocation has been freed.
context_release :: proc "contextless" (token: u64) -> Status {
    if token == 0 {
        return OK
    }

    c := context_find(token)

    if c == nil {
        return INVALID_HANDLE
    }

    status := protected()

    if status != OK {
        return status
    }

    c.alive = false
    c.source_present = false

    if c.refs == 0 {
        c.active = false
    }

    return OK
}

@(private)
service_domain_check :: proc "c" (user: rawptr, cookie: u64) -> Status {
    _, s := producer_guard(user)

    if s != OK {
        return s
    }

    return cookie == registry.native.contract.cookie ? OK : INCOMPATIBLE
}

@(private)
owner_guard :: proc "contextless" (user: rawptr, access: u32) -> (^Owner_Record, Status) {
    if access > EXECUTE {
        return nil, INVALID_ARGUMENT
    }

    s := protected()

    if s != OK {
        return nil, s
    }

    o := owner_find(u64(uintptr(user)))

    if o == nil || o.busy {
        return nil, INVALID_HANDLE
    }

    if active_producer != o.producer {
        return nil, INCOMPATIBLE
    }

    if access == EXECUTE && o.weak != 0 {
        c := context_find(o.weak)

        if c == nil || !c.alive {
            return nil, INVALID_HANDLE
        }
    }

    return o, OK
}

@(private)
owner_check :: proc "c" (user: rawptr, access: u32) -> Status {
    _, s := owner_guard(user, access)
    return s
}

@(private)
owner_retain :: proc "c" (user: rawptr) -> Status {
    o, s := owner_guard(user, READ)

    if s != OK {
        return s
    }

    if o.refs == max(u64) {
        return CAPACITY
    }

    o.refs += 1
    return OK
}

@(private)
owner_drop :: proc "c" (user: rawptr) -> Status {
    o, s := owner_guard(user, READ)

    if s != OK {
        return s
    }

    if o.refs == 0 {
        return INVALID_HANDLE
    }

    if o.refs > 1 {
        o.refs -= 1
        return OK
    }

    p := producer_find(o.producer)

    if p == nil {
        return INVALID_HANDLE
    }

    o.busy = true

    if o.data.user != nil {
        s = o.data.drop(o.data.user)

        if s != OK {
            o.busy = false
            return s
        }
    }

    if o.weak != 0 {
        c := context_find(o.weak)

        if c != nil {
            if c.refs == 0 {
                return CORRUPT
            }

            c.refs -= 1

            if !c.alive && !c.source_present && c.refs == 0 {
                c.active = false
            }
        }
    }

    o.active = false
    o.busy = false
    o.refs = 0
    registry.hooks.code_drop(registry.hooks.user, p.code)
    return OK
}

@(private)
service_owner_create :: proc "c" (user: rawptr, require_live: u32, data: ^Data_Lease, out: ^Owner) -> Status {
    if out == nil || require_live > 1 {
        return INVALID_ARGUMENT
    }

    p, status := producer_guard(user)

    if status != OK {
        return status
    }

    lease := Data_Lease{}

    if data != nil {
        lease = data^
    }

    if (lease.user != nil && (lease.retain == nil || lease.drop == nil)) ||
       (lease.user == nil && (lease.retain != nil || lease.drop != nil)) {
        return UNSUPPORTED
    }

    if lease.user != nil {
        for source in registry.contexts {
            address := u64(uintptr(lease.user))
            base := u64(uintptr(source.borrowed_base))

            if source.active &&
               source.source_present &&
               source.borrowed_base != nil &&
               address >= base &&
               address - base < source.borrowed_size {
                return UNSUPPORTED
            }
        }

        if lease.retain == owner_retain && lease.drop == owner_drop {
            parent := owner_find(u64(uintptr(lease.user)))

            if parent == nil || parent.producer != active_producer {
                return INCOMPATIBLE
            }
        } else if registry.hooks.procedure(registry.hooks.user, p.code, cast(rawptr)lease.retain) != OK ||
           registry.hooks.procedure(registry.hooks.user, p.code, cast(rawptr)lease.drop) != OK {
            return INCOMPATIBLE
        }
    }

    weak := u64(0)

    if require_live != 0 {
        c := context_find(active_context)

        if c == nil || !c.alive || c.producer != active_producer {
            return INVALID_HANDLE
        }

        if c.refs == max(u64) {
            return CAPACITY
        }

        weak = active_context
    }

    slot: ^Owner_Record
    index: int

    for &candidate, i in registry.owners {
        if !candidate.active && !candidate.busy && candidate.generation < POINTER_GENERATION_MAX {
            slot = &candidate
            index = i
            break
        }
    }

    if slot == nil {
        return CAPACITY
    }

    // Pin the code and weak tombstone before a managed retain callback can
    // synchronously free its source or reenter another owner constructor.
    slot.busy = true
    slot.producer = active_producer

    if weak != 0 {
        context_find(weak).refs += 1
    }

    registry.hooks.code_retain(registry.hooks.user, p.code)

    if lease.user != nil {
        status = lease.retain(lease.user)

        if status != OK {
            if weak != 0 {
                c := context_find(weak)
                c.refs -= 1

                if !c.alive && !c.source_present && c.refs == 0 {
                    c.active = false
                }
            }

            slot.busy = false
            registry.hooks.code_drop(registry.hooks.user, p.code)
            return status
        }
    }

    generation := slot.generation + 1
    slot^ = {
        generation = generation,
        active     = true,
        producer   = active_producer,
        refs       = 1,
        weak       = weak,
        data       = lease,
    }
    caps := MANAGED_DATA | INDEPENDENT_CONTEXT

    if weak != 0 {
        caps = MANAGED_DATA | WEAK_INSTANCE
    }

    out^ = Owner {
        user         = token_ptr(id_of(index, generation)),
        realm        = active_producer,
        context_caps = caps,
        check        = owner_check,
        retain       = owner_retain,
        drop         = owner_drop,
    }
    return OK
}

@(private)
totals :: proc "contextless" (out: ^Request_Totals) -> Status {
    e, w: Allocation_Stats
    s := registry.native.engine_stats(&e)

    if s != OK {
        return s
    }

    s = registry.native.wrapper_stats(&w)

    if s != OK {
        return s
    }

    if e.total_bytes > max(u64) - w.total_bytes || e.total_bytes + w.total_bytes > max(u64) - registry.host_requested {
        return CAPACITY
    }

    out^ = {
        e.total_bytes,
        w.total_bytes,
        registry.host_requested,
        e.total_bytes + w.total_bytes + registry.host_requested,
    }
    return OK
}

@(private)
service_totals :: proc "c" (user: rawptr, out: ^Request_Totals) -> Status {
    if out == nil {
        return INVALID_ARGUMENT
    }

    _, s := producer_guard(user)

    if s != OK {
        return s
    }

    return totals(out)
}

@(private)
sync_budget :: proc "contextless" (p: ^Producer_Record, live: u64) -> Status {
    remaining := p.remaining
    exhausted := false

    if p.depth > 0 {
        t: Request_Totals
        s := totals(&t)

        if s != OK {
            return s
        }

        if t.total < p.last_total {
            return CORRUPT
        }

        delta := t.total - p.last_total
        p.last_total = t.total

        if delta > remaining {
            remaining = 0
            exhausted = true
            p.failed = true
        } else {
            remaining -= delta
        }
    }

    s := registry.native.owner_set(registry.native.contract.cookie, p.ledger, live, remaining)

    if s != OK {
        if p.depth > 0 {
            p.failed = true
        }

        return s
    }

    p.live = live
    p.remaining = remaining

    if exhausted || (p.depth > 0 && p.failed) {
        return CAPACITY
    }

    return OK
}

@(private)
service_account :: proc "c" (user: rawptr, category: u32, live, requested: u64) -> Status {
    p, s := producer_guard(user)

    if s != OK {
        return s
    }

    if category == 0 || category > MAX_CATEGORIES {
        return INVALID_ARGUMENT
    }

    c := &p.categories[category - 1]

    if registry.budget_producer != 0 &&
       registry.budget_producer != u64(uintptr(user)) &&
       (live > c.live || requested > c.requested) {
        return UNSUPPORTED
    }

    if requested < c.requested {
        return INVALID_ARGUMENT
    }

    delta := requested - c.requested

    if delta > max(u64) - registry.host_requested || live > max(u64) - (p.live - c.live) {
        return CAPACITY
    }

    // Record successful/observed allocation requests even when admission fails;
    // caller must then unwind. Never infer requests from a net-live difference.
    registry.host_requested += delta
    c.requested = requested
    proposed := p.live - c.live + live
    s = sync_budget(p, proposed)

    if s == OK || p.live == proposed {
        c.live = live
    }

    return s
}

@(private)
service_budget_begin :: proc "c" (user: rawptr, bytes: u64, out: ^u64) -> Status {
    if out == nil {
        return INVALID_ARGUMENT
    }

    p, s := producer_guard(user)

    if s != OK {
        return s
    }

    if registry.budget_producer != 0 && registry.budget_producer != u64(uintptr(user)) {
        return UNSUPPORTED
    }

    if bytes == 0 || p.depth == MAX_MARKS || registry.next_mark == max(u64) {
        return CAPACITY
    }

    if p.depth > 0 {
        s = sync_budget(p, p.live)

        if s != OK {
            return s
        }

        if bytes > p.bound {
            return CAPACITY
        }
    } else {
        t: Request_Totals
        s = totals(&t)

        if s != OK {
            return s
        }

        s = registry.native.owner_set(registry.native.contract.cookie, p.ledger, p.live, bytes)

        if s != OK {
            return s
        }

        p.bound = bytes
        p.remaining = bytes
        p.last_total = t.total
        p.failed = false
        registry.budget_producer = u64(uintptr(user))
    }

    registry.next_mark += 1
    id := registry.next_mark
    p.marks[p.depth] = Mark {
        id = id,
    }
    p.depth += 1
    out^ = id
    return OK
}

@(private)
find_mark :: proc "contextless" (p: ^Producer_Record, mark: u64) -> bool {
    return p.depth > 0 && mark != 0 && p.marks[p.depth - 1].id == mark
}

@(private)
service_budget_reconcile :: proc "c" (user: rawptr, mark: u64) -> Status {
    p, s := producer_guard(user)

    if s != OK {
        return s
    }

    if !find_mark(p, mark) {
        return INVALID_HANDLE
    }

    return sync_budget(p, p.live)
}

@(private)
service_budget_end :: proc "c" (user: rawptr, mark: u64) -> Status {
    p, s := producer_guard(user)

    if s != OK {
        return s
    }

    if !find_mark(p, mark) {
        return INVALID_HANDLE
    }

    result := sync_budget(p, p.live)
    p.depth -= 1

    if p.depth == 0 {
        s = registry.native.owner_set(registry.native.contract.cookie, p.ledger, p.live, 0)

        if s != OK {
            return s
        }

        p.bound = 0
        p.remaining = 0
        p.failed = false
        registry.budget_producer = 0
    }

    return result
}

@(private)
service_legacy_extra :: proc "c" (user: rawptr, mark, implicit, additional: u64, out: ^u64) -> Status {
    if out == nil {
        return INVALID_ARGUMENT
    }

    p, status := producer_guard(user)

    if status != OK {
        return status
    }

    if mark != 0 && !find_mark(p, mark) {
        return INVALID_HANDLE
    }

    if implicit != 0 && mark == 0 {
        return INVALID_ARGUMENT
    }

    status = sync_budget(p, p.live)

    if status != OK {
        return status
    }

    covered := u64(0)
    projected := additional

    if implicit != 0 {
        m := &p.marks[p.depth - 1]

        if implicit > p.bound || (m.implicit != 0 && m.implicit != implicit) {
            return INVALID_ARGUMENT
        }

        for parent in p.marks[:p.depth - 1] {
            if parent.implicit != 0 {
                return INVALID_ARGUMENT
            }
        }

        // Native C still adds its complete reserve. Never subtract more promise
        // than actually remains held; the gap remains a conservative native check.
        covered = min(implicit, p.remaining)
    } else if mark == 0 && p.depth > 0 {
        if additional > p.remaining {
            return CAPACITY
        }

        // Proposed bytes are already covered by the current remaining promise.
        projected = 0
    }

    all: Ledger_Stats
    status = registry.native.ledger_get(registry.native.contract.cookie, &all)

    if status != OK {
        return status
    }

    if covered > all.host_reserved_bytes {
        return INVALID_ARGUMENT
    }

    total := all.host_live_bytes
    remaining := all.host_reserved_bytes - covered

    if remaining > max(u64) - total || projected > max(u64) - total - remaining {
        return CAPACITY
    }

    if implicit != 0 {
        p.marks[p.depth - 1].implicit = implicit
    }

    out^ = total + remaining + projected
    return OK
}

@(private)
service_capsule_create :: proc "c" (
    user: rawptr,
    owner: ^Owner,
    data: rawptr,
    dispatch: Capsule_Dispatch,
    out: ^Capsule,
) -> Status {
    if owner == nil || data == nil || dispatch == nil || out == nil {
        return INVALID_ARGUMENT
    }

    _, s := producer_guard(user)

    if s != OK {
        return s
    }

    o, s2 := owner_guard(owner.user, READ)

    if s2 != OK {
        return s2
    }

    if owner.realm != o.producer ||
       owner.realm != active_producer ||
       owner.check != owner_check ||
       owner.retain != owner_retain ||
       owner.drop != owner_drop {
        return INCOMPATIBLE
    }

    p := producer_find(active_producer)

    if p == nil || registry.hooks.procedure(registry.hooks.user, p.code, cast(rawptr)dispatch) != OK {
        return INCOMPATIBLE
    }

    for &c, i in registry.capsules {
        if !c.active && c.generation < POINTER_GENERATION_MAX {
            s = owner_retain(owner.user)

            if s != OK {
                return s
            }

            gen := c.generation + 1
            id := id_of(i, gen)
            c = {
                generation = gen,
                active     = true,
                producer   = active_producer,
                owner      = owner^,
                data       = data,
                dispatch   = dispatch,
            }
            out^ = Capsule{token_ptr(id), active_producer, capsule_invoke, capsule_destroy}
            return OK
        }
    }

    return CAPACITY
}

@(private)
capsule_call :: proc "contextless" (user: rawptr, operation: u32, args: rawptr, destroy: bool) -> Status {
    if !registry.initialized {
        return INCOMPATIBLE
    }

    status := registry.hooks.enter(registry.hooks.user)

    if status != OK {
        return status
    }

    defer registry.hooks.leave(registry.hooks.user)
    c := capsule_find(u64(uintptr(user)))

    if c == nil || c.busy || (c.closing && !destroy) {
        return INVALID_HANDLE
    }

    if operation == CAPSULE_CLONE && registry.budget_producer != 0 && registry.budget_producer != c.producer {
        return UNSUPPORTED
    }

    p := producer_find(c.producer)

    if p == nil {
        return INVALID_HANDLE
    }

    registry.hooks.code_retain(registry.hooks.user, p.code)
    defer registry.hooks.code_drop(registry.hooks.user, p.code)
    previous := Origin_Scope{active_producer, active_context}
    active_producer = c.producer
    o := owner_find(u64(uintptr(c.owner.user)))

    if o == nil {
        return INVALID_HANDLE
    }

    active_context = o.weak
    defer origin_leave(previous)
    c.busy = true
    defer c.busy = false

    if !c.closing {
        status = c.dispatch(c.data, operation, args)

        if status != OK {
            return status
        }
    }

    if destroy {
        // A declining data-lease drop must never cause a second typed destructor
        // or a read of already-freed payload. Keep only an owned cleanup tombstone.
        c.closing = true
        c.data = nil
        c.dispatch = nil
        status = owner_drop(c.owner.user)

        if status != OK {
            return status
        }

        c.active = false
    }

    return OK
}

@(private)
capsule_invoke :: proc "c" (user: rawptr, operation: u32, args: rawptr) -> Status {
    if operation == CAPSULE_DESTROY {
        return INVALID_ARGUMENT
    }

    return capsule_call(user, operation, args, false)
}

@(private)
capsule_destroy :: proc "c" (user: rawptr) -> Status {
    return capsule_call(user, CAPSULE_DESTROY, nil, true)
}

// Core-only query. Producer copies of this package cannot activate Core TLS.
current_realm :: proc "contextless" () -> u64 {
    return active_producer
}

// Core-only metadata query for stable adapters such as Godot custom Callables.
// It invokes NO producer procedure and exposes no typed payload or allocator.
// Possession of a Capsule is still ownership; this query does not clone it.
Capsule_Inspection :: struct {
    realm:        u64,
    execute_live: bool,
}

capsule_inspect :: proc "contextless" (value: ^Capsule) -> (Capsule_Inspection, Status) {
    if value == nil {
        return {}, INVALID_ARGUMENT
    }

    status := protected()

    if status != OK {
        return {}, status
    }

    if value.invoke != capsule_invoke || value.destroy != capsule_destroy {
        return {}, INCOMPATIBLE
    }

    c := capsule_find(u64(uintptr(value.user)))

    if c == nil || c.closing || c.busy {
        return {}, INVALID_HANDLE
    }

    if value.realm != c.producer || producer_find(c.producer) == nil {
        return {}, INCOMPATIBLE
    }

    owner := owner_find(u64(uintptr(c.owner.user)))

    if owner == nil || owner.busy {
        return {}, INVALID_HANDLE
    }

    live := true

    if owner.weak != 0 {
        weak := context_find(owner.weak)
        live = weak != nil && weak.alive
    }

    return {realm = c.producer, execute_live = live}, OK
}
