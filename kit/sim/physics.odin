package kit_sim

// Optional whole-world participant. This file imports no native backend. Every
// opaque image owns complete solver+typed Side state; field bytes stay in Kit's
// existing prediction/history path. Callers must not copy owning checkpoints.
import "base:runtime"
import "core:mem"
import "core:reflect"
import "core:time"
import bd "godot:box3d/diagnostics"
import bg "godot:box3d/godot"
import knet "godot:kit/net"
import ksess "godot:kit/session"

WORLD_HISTORY_FRAMES :: 128
WORLD_REPAIR_TICKS :: 8
WORLD_EFFECTS_PER_TICK :: 32
WORLD_EFFECT_BYTES :: 128
WORLD_WORK_NS :: u64(4_000_000)
WORLD_MEMORY_BYTES :: u64(64 * 1024 * 1024)

World_Error :: enum {
    Ok,
    Invalid,
    Unsupported,
    Incompatible,
    History_Missing,
    Missing_Attachment,
    Prediction_Limit,
    Repair_Limit,
    Capacity,
    Allocation_Failed,
    Step_Failed,
    Rejected,
    Busy,
    Budget,
    Settled,
    Conflict,
}

World_Admission :: struct {
    prediction_ticks, correction_ticks:                                         u32,
    additional_owned_bytes, reserved_bytes, normal_work_ns, correction_work_ns: u64,
}

World_Budget :: struct {
    user:           rawptr,
    begin:          proc "c" (_: rawptr, _: u64, _: ^u64) -> bg.Status,
    reconcile, end: proc "c" (_: rawptr, _: u64) -> bg.Status,
}

World_Provider :: struct {
    budget:                   World_Budget,
    user_owner, author_owner: World_Owner,
    effect_owner:             World_Owner,
    effect_user:              rawptr,
    owner:                    World_Owner, // live producer/allocator/user context
    detached_owner:           World_Owner, // independent complete/diagnostic owner context
    user:                     rawptr, // managed owner/config, never uncheckpointed game state
    side_type:                typeid,
    asset_id:                 u64,
    initial_execution:        rawptr, // ownership transfers only on successful attach
    capture:                  proc(user, execution: rawptr) -> (rawptr, World_Error),
    clone:                    proc(image: rawptr) -> (rawptr, World_Error),
    equal:                    proc(left, right: rawptr) -> (bool, World_Error),
    release:                  proc(image: rawptr), // self-contained; source provider may be gone
    open:                     proc(user, image: rawptr) -> (rawptr, World_Error),
    close:                    proc(execution: rawptr),
    bind:                     proc(user, execution: rawptr),
    publish:                  proc(user, execution: rawptr), // infallible selection, no allocation
    step:                     proc(user, execution: rawptr, tick: u64) -> World_Error,
    admit:                    proc(user, execution: rawptr, request: World_Admission) -> World_Error,
    admit_detached:           proc(additional_owned_bytes, reserved_bytes: u64) -> World_Error,
}

World_Field_Type :: struct {
    id:   knet.Net_Id,
    type: typeid,
}

world_field_type :: proc(id: knet.Net_Id, $T: typeid) -> World_Field_Type {
    return {id, T}
}

// Alpha proxies are fixed pointer-free state structs, not arbitrary Godot nodes.
world_value_supported :: proc(t: typeid) -> bool {
    return world_value_info_supported(type_info_of(t))
}

@(private)
world_value_info_supported :: proc(source: ^reflect.Type_Info) -> bool {
    if source == nil {
        return false
    }

    info := reflect.type_info_base(source)

    if info == nil {
        return false
    }

    #partial switch v in info.variant {
    case reflect.Type_Info_Integer, reflect.Type_Info_Rune, reflect.Type_Info_Float, reflect.Type_Info_Boolean:
        return true
    case reflect.Type_Info_Enum:
        return world_value_info_supported(v.base)
    case reflect.Type_Info_Bit_Set:
        return world_value_info_supported(v.underlying)
    case reflect.Type_Info_Array:
        return world_value_info_supported(v.elem)
    case reflect.Type_Info_Enumerated_Array:
        return world_value_info_supported(v.elem)
    case reflect.Type_Info_Struct:
        if v.soa_kind != .None || .raw_union in v.flags {
            return false
        }

        for t in v.types[:v.field_count] {
            if !world_value_info_supported(t) {
                return false
            }
        }

        return true
    }

    return false
}

World_Effect_Proc :: proc(user: rawptr, tick, key: u64, args: []u8)

World_Effect :: struct {
    kind:  u16, // immutable network catalog ID; zero only in local-only mode
    key:   u64,
    fire:  World_Effect_Proc,
    user:  rawptr,
    count: int,
    args:  [WORLD_EFFECT_BYTES]u8,
}

World_Frame :: struct {
    tick:         u64,
    valid:        bool,
    image:        rawptr,
    fields:       []u8,
    effect_count: int,
    effects:      [WORLD_EFFECTS_PER_TICK]World_Effect,
}

World_Checkpoint :: struct {
    budget:                          World_Budget,
    effect_owner:                    World_Owner,
    owner:                           World_Owner,
    effects_known:                   bool,
    effect_count:                    int,
    effects:                         [WORLD_EFFECTS_PER_TICK]World_Effect,
    tick, asset_id, field_schema:    u64,
    side_type:                       typeid,
    image:                           rawptr,
    fields:                          []u8,
    clone:                           proc(_: rawptr) -> (rawptr, World_Error),
    release:                         proc(_: rawptr),
    equal:                           proc(left, right: rawptr) -> (bool, World_Error),
    allocator:                       mem.Allocator,
    admit_detached:                  proc(additional_owned_bytes, reserved_bytes: u64) -> World_Error,
    charge_bytes, reservation_bytes: u64,
}

@(private)
g_world_checkpoint_bytes: u64
@(private)
g_world_diagnostic_bytes: u64

World_Binding :: struct {
    id:           knet.Net_Id,
    entity:       rawptr,
    desc:         ^knet.Entity_Desc,
    hist:         ^History,
    offset, size: int,
}

World_Input_Backup :: struct {
    data:       []u8,
    tick:       []u64,
    scratch:    []u8,
    head, tail: u64,
}

World_Config :: struct {
    settle:                 Step_Proc, // after fixed native step, before authority-only pass
    additional_owned_bytes: u64, // nonduplicated game/proxy/runtime ownership for this Lane only
    reservation_bytes:      u64, // measured upper allowance BEFORE open/capture
}

World_History :: struct {
    budget_lane:                          ^Lane,
    budget_next:                          ^World_History,
    budget_registered:                    bool,
    network:                              ^World_Network,
    provider:                             World_Provider,
    config:                               World_Config,
    allocator:                            mem.Allocator,
    published, candidate:                 rawptr,
    head, confirmed, field_schema:        u64,
    epoch:                                u64,
    work:                                 World_Work_Stats,
    status:                               World_Error,
    busy, publishing, presenting, resync: bool,
    field_bytes:                          int,
    bindings:                             []World_Binding,
    live_backup:                          []u8,
    input_backup:                         []World_Input_Backup,
    frames:                               [WORLD_HISTORY_FRAMES]World_Frame,
    staged:                               [WORLD_REPAIR_TICKS + 1]World_Frame,
    staged_count:                         int,
    current_effect_count:                 int,
    current_effects:                      [WORLD_EFFECTS_PER_TICK]World_Effect,
}

World_Work_Stats :: struct {
    normal_latest_ns, correction_latest_ns, normal_peak_ns, correction_peak_ns: u64,
}

lane_world_work_stats :: proc(l: ^Lane) -> World_Work_Stats {
    return l.world != nil ? l.world.work : World_Work_Stats{}
}

lane_world_epoch :: proc(l: ^Lane) -> u64 {
    return l.world != nil ? l.world.epoch : 0
}

lane_world_confirmed :: proc(l: ^Lane) -> u64 {
    return l.world != nil ? l.world.confirmed : 0
}

// Requested external ownership used in shared alpha observation; excludes RSS.
lane_world_owned_bytes :: proc(l: ^Lane) -> u64 {
    return l.world != nil ? world_external_bytes(l) : 0
}

lane_world_status :: proc(l: ^Lane) -> World_Error {
    return l.world != nil ? l.world.status : .Unsupported
}

lane_world_needs_resync :: proc(l: ^Lane) -> bool {
    return l.world != nil && l.world.resync
}

lane_world_busy :: proc(l: ^Lane) -> bool {
    return l.world != nil && (l.world.busy || l.world.presenting)
}

// Unsupported operations call this BEFORE touching tracks, commands or scenes.
lane_world_refuse :: proc(l: ^Lane) -> bool {
    if l.world == nil {
        return false
    }

    l.world.status = .Unsupported
    l.world.resync = true
    return true
}

lane_world_fail :: proc(l: ^Lane, error: World_Error) {
    if l.world != nil && error != .Ok {
        l.world.status = error
    }
}

@(private)
world_field_guard :: proc(user: rawptr) -> bool {
    w := cast(^World_History)user

    if !w.publishing {
        w.status = .Unsupported
        w.resync = true
        return false
    }

    return true
}

@(private)
world_local_owned_bytes :: proc(l: ^Lane) -> u64 {
    w := l.world
    n := u64(size_of(World_History) + len(w.bindings) * size_of(World_Binding) + len(w.live_backup))
    n += w.config.additional_owned_bytes

    for b in w.bindings {
        n += u64(size_of(History) + len(b.hist.data) + len(b.hist.tick) * size_of(u64))
    }

    for f in w.frames {
        n += u64(len(f.fields))
    }

    for f in w.staged {
        n += u64(len(f.fields))
    }

    for b in w.input_backup {
        n += u64(len(b.data) + len(b.tick) * 8 + len(b.scratch))
    }

    n += u64(size_of(Lane) + cap(l.tracked) * size_of(Tracked) + cap(l.entries) * size_of(Entry))

    for ic in l.inputs {
        n += u64(size_of(Input_Class) + len(ic.ring.ring.data) + len(ic.ring.ring.tick) * 8 + len(ic.scratch))
    }

    if w.network != nil {
        n += world_network_bytes(w.network)
    }

    return n
}

// Same-producer bookkeeping only, not global simulation state. P4 still
// requires a shared-domain ledger across separately compiled producer images.
// Intrusive nodes reference only attached stable Lanes, never detached owners.
@(private)
g_world_budget_head: ^World_History

@(private)
world_budget_register :: proc(l: ^Lane) {
    w := l.world
    assert(w != nil && !w.budget_registered)
    w.budget_lane = l
    w.budget_next = g_world_budget_head
    w.budget_registered = true
    g_world_budget_head = w
}

@(private)
world_budget_unregister :: proc(w: ^World_History) {
    if !w.budget_registered {
        return
    }

    previous: ^World_History
    node := g_world_budget_head

    for node != nil && node != w {
        previous = node
        node = node.budget_next
    }

    assert(node == w)

    if previous == nil {
        g_world_budget_head = w.budget_next
    } else {
        previous.budget_next = w.budget_next
    }

    w.budget_registered = false
    w.budget_lane = nil
    w.budget_next = nil
}

@(private)
world_all_owned_bytes :: proc() -> u64 {
    total := g_world_checkpoint_bytes + g_world_diagnostic_bytes
    node := g_world_budget_head

    for node != nil {
        assert(node.budget_registered && node.budget_lane != nil)
        total += world_local_owned_bytes(node.budget_lane)
        node = node.budget_next
    }

    return total
}

@(private)
world_external_bytes :: proc(l: ^Lane) -> u64 {
    total := world_all_owned_bytes()

    // Successful attach is registered only after all fallible work; during its
    // private construction the candidate's local allocations must also be charged.
    if !l.world.budget_registered {
        total += world_local_owned_bytes(l)
    }

    return total
}

@(private)
world_capture_fields :: proc(w: ^World_History, dst: []u8) {
    for b in w.bindings {
        predict_capture(dst[b.offset:b.offset + b.size], b.entity, b.desc)
    }
}

@(private)
world_restore_fields :: proc(w: ^World_History, src: []u8) {
    for b in w.bindings {
        predict_restore(b.entity, b.desc, src[b.offset:b.offset + b.size])
    }
}

@(private)
world_record :: proc(w: ^World_History, tick: u64) -> ^World_Frame {
    f := &w.frames[tick % WORLD_HISTORY_FRAMES]
    return f.valid && f.tick == tick ? f : nil
}

@(private)
world_inputs_save :: proc(l: ^Lane) {
    for ic, i in l.inputs {
        b := &l.world.input_backup[i]
        copy(b.data, ic.ring.ring.data)
        copy(b.tick, ic.ring.ring.tick)
        copy(b.scratch, ic.scratch)
        b.head = ic.ring.head
        b.tail = ic.ring.tail
    }
}

@(private)
world_inputs_restore :: proc(l: ^Lane) {
    for &ic, i in l.inputs {
        b := &l.world.input_backup[i]
        copy(ic.ring.ring.data, b.data)
        copy(ic.ring.ring.tick, b.tick)
        copy(ic.scratch, b.scratch)
        ic.ring.head = b.head
        ic.ring.tail = b.tail
    }
}

@(private)
world_fields_free :: proc(w: ^World_History) {
    context.allocator = w.allocator

    for &f in w.frames {
        if f.image != nil {
            w.provider.release(f.image)
        }

        delete(f.fields)
    }

    for &f in w.staged {
        if f.image != nil {
            w.provider.release(f.image)
        }

        delete(f.fields)
    }

    for b in w.input_backup {
        delete(b.data)
        delete(b.tick)
        delete(b.scratch)
    }

    delete(w.input_backup)
    delete(w.bindings)
    delete(w.live_backup)
}

// Register every proxy's full pointer-free value type. Tracking, owner changes,
// generated tick thunks and scheduled verbs stay unavailable while attached.
lane_world_attach :: proc(
    l: ^Lane,
    provider: World_Provider,
    types: []World_Field_Type,
    cfg := World_Config{},
) -> World_Error {
    if cfg.additional_owned_bytes > WORLD_MEMORY_BYTES || cfg.reservation_bytes > WORLD_MEMORY_BYTES {
        return .Budget
    }

    if l.world != nil ||
       l.ses == nil ||
       provider.initial_execution == nil ||
       provider.asset_id == 0 ||
       provider.side_type == nil ||
       !world_value_supported(provider.side_type) ||
       provider.capture == nil ||
       provider.clone == nil ||
       provider.equal == nil ||
       provider.release == nil ||
       provider.open == nil ||
       provider.close == nil ||
       provider.bind == nil ||
       provider.publish == nil ||
       provider.step == nil ||
       provider.admit == nil ||
       provider.admit_detached == nil {
        return .Invalid
    }

    if e := world_owner_check(provider.owner, WORLD_OWNER_EXECUTE); e != .Ok {
        return e
    }

    if e := world_owner_check(provider.detached_owner); e != .Ok {
        return e
    }

    if e := world_owner_check(provider.effect_owner); e != .Ok {
        return e
    }

    if e := world_owner_check(provider.user_owner); e != .Ok {
        return e
    }

    if e := world_owner_check(provider.author_owner); e != .Ok {
        return e
    }

    if provider.effect_user != nil &&
       (world_owner_is_empty(provider.effect_owner) ||
               provider.effect_owner.context_caps & WORLD_OWNER_INDEPENDENT_CONTEXT == 0) {
        return .Unsupported
    }

    if !world_owner_is_empty(provider.owner) && world_owner_is_empty(provider.detached_owner) {
        return .Unsupported
    }

    if len(l.entries) > 35 ||
       l.ticker.tick != 0 ||
       l.slots != WORLD_HISTORY_FRAMES ||
       abs(l.ticker.dt - 1.0 / 60.0) > 1e-12 ||
       l.echo_on ||
       l.tolerance != 0 ||
       l.step_auth != nil ||
       len(l.cmd_in) != 0 ||
       len(l.cmd_out) != 0 ||
       len(types) != len(l.entries) ||
       len(l.pending) != 0 {
        return .Unsupported
    }

    for tr in l.tracked {
        if tr.watched || tr.tick != nil || tr.set != nil || tr.born != 0 {
            return .Unsupported
        }
    }

    for &e in l.entries {
        found := false

        for t in types {
            if t.id == e.id {
                if found || !world_value_supported(t.type) {
                    return .Unsupported
                }

                for f in e.hist.desc.fields {
                    if .Predicted in f.flags {
                        if f.size <= 0 ||
                           f.offset > uintptr(type_info_of(t.type).size) ||
                           uintptr(f.size) > uintptr(type_info_of(t.type).size) - f.offset {
                            return .Invalid
                        }
                    }
                }

                found = true
            }
        }

        if !found {
            return .Invalid
        }
    }

    field_bytes := 0
    estimate := u64(size_of(World_History) + size_of(Lane)) + cfg.additional_owned_bytes + world_all_owned_bytes()

    for e in l.entries {
        if e.hist.size < 0 || e.hist.size > int(WORLD_MEMORY_BYTES / 256) {
            return .Budget
        }

        field_bytes += e.hist.size
        estimate += u64(size_of(World_Binding) + size_of(History) + len(e.hist.data) + 8 * len(e.hist.tick))
    }

    estimate += u64(field_bytes) * u64(WORLD_HISTORY_FRAMES + WORLD_REPAIR_TICKS + 2)

    for ic in l.inputs {
        estimate += u64(
            size_of(Input_Class) +
            2 * len(ic.ring.ring.data) +
            16 * len(ic.ring.ring.tick) +
            2 * len(ic.scratch) +
            size_of(World_Input_Backup),
        )
    }

    estimate += u64(cap(l.tracked) * size_of(Tracked) + cap(l.entries) * size_of(Entry))

    if estimate > WORLD_MEMORY_BYTES {
        return .Budget
    }

    if status := provider.admit(
        provider.user,
        provider.initial_execution,
        World_Admission{additional_owned_bytes = estimate, reserved_bytes = cfg.reservation_bytes},
    ); status != .Ok {
        return status
    }

    if e := world_owner_retain(provider.owner); e != .Ok {
        return e
    }

    owner_transferred := false

    defer {
        if !owner_transferred {
            _ = world_owner_drop(provider.owner)
        }
    }

    if e := world_owner_retain(provider.detached_owner); e != .Ok {
        return e
    }

    detached_transferred := false

    defer {
        if !detached_transferred {
            _ = world_owner_drop(provider.detached_owner)
        }
    }

    if e := world_owner_retain(provider.effect_owner); e != .Ok {
        return e
    }

    effects_transferred := false

    defer {
        if !effects_transferred {
            _ = world_owner_drop(provider.effect_owner)
        }
    }

    if e := world_owner_retain(provider.user_owner); e != .Ok {
        return e
    }

    user_transferred := false

    defer {
        if !user_transferred {
            _ = world_owner_drop(provider.user_owner)
        }
    }

    if e := world_owner_retain(provider.author_owner); e != .Ok {
        return e
    }

    author_transferred := false

    defer {
        if !author_transferred {
            _ = world_owner_drop(provider.author_owner)
        }
    }

    w, err := new(World_History, l.allocator)

    if err != nil {
        return .Allocation_Failed
    }

    w.allocator = l.allocator
    w.provider = provider
    w.config = cfg
    w.published = provider.initial_execution
    w.head = l.ticker.tick
    w.confirmed = w.head
    w.epoch = 1
    w.field_schema = 0xcbf29ce484222325
    allocation_failed := false
    w.bindings, err = make([]World_Binding, len(l.entries), l.allocator)

    if err != nil {
        free(w, l.allocator)
        return .Allocation_Failed
    }

    for e, i in l.entries {
        w.bindings[i] = {e.id, e.entity, e.hist.desc, e.hist, w.field_bytes, e.hist.size}
        w.field_bytes += e.hist.size
        w.field_schema = (w.field_schema ~ u64(e.id)) * 0x100000001b3
        w.field_schema = (w.field_schema ~ u64(e.hist.size)) * 0x100000001b3

        for t in types {
            if t.id == e.id {
                w.field_schema = (w.field_schema ~ u64(cast(uintptr)type_info_of(t.type))) * 0x100000001b3
            }
        }

        for f in e.hist.desc.fields {
            if .Predicted in f.flags {
                w.field_schema = (w.field_schema ~ u64(f.offset)) * 0x100000001b3
                w.field_schema = (w.field_schema ~ u64(f.size)) * 0x100000001b3
            }
        }
    }

    if u64(w.field_bytes) > WORLD_MEMORY_BYTES / u64(WORLD_HISTORY_FRAMES + WORLD_REPAIR_TICKS + 2) {
        world_fields_free(w)
        free(w, l.allocator)
        return .Budget
    }

    w.live_backup, err = make([]u8, w.field_bytes, l.allocator)
    allocation_failed = err != nil

    for &f in w.frames {
        f.fields, err = make([]u8, w.field_bytes, l.allocator)
        allocation_failed = allocation_failed || err != nil
    }

    for &f in w.staged {
        f.fields, err = make([]u8, w.field_bytes, l.allocator)
        allocation_failed = allocation_failed || err != nil
    }

    w.input_backup, err = make([]World_Input_Backup, len(l.inputs), l.allocator)
    allocation_failed = allocation_failed || err != nil

    if !allocation_failed {
        for ic, i in l.inputs {
            b := &w.input_backup[i]
            b.data, err = make([]u8, len(ic.ring.ring.data), l.allocator)
            allocation_failed = allocation_failed || err != nil
            b.tick, err = make([]u64, len(ic.ring.ring.tick), l.allocator)
            allocation_failed = allocation_failed || err != nil
            b.scratch, err = make([]u8, len(ic.scratch), l.allocator)
            allocation_failed = allocation_failed || err != nil
        }
    }

    if allocation_failed {
        world_fields_free(w)
        free(w, l.allocator)
        return .Allocation_Failed
    }

    l.world = w
    request := World_Admission {
        additional_owned_bytes = world_external_bytes(l),
        reserved_bytes         = cfg.reservation_bytes,
    }
    status := provider.admit(provider.user, w.published, request)
    image: rawptr

    if status == .Ok {
        image, status = provider.capture(provider.user, w.published)
    }

    if status == .Ok {
        request.reserved_bytes = 0
        status = provider.admit(provider.user, w.published, request)
    }

    if status != .Ok {
        if image != nil {
            provider.release(image)
        }

        world_fields_free(w)
        free(w, l.allocator)
        l.world = nil
        return status
    }

    f := &w.frames[w.head % WORLD_HISTORY_FRAMES]
    f.tick = w.head
    f.valid = true
    f.image = image
    world_capture_fields(w, f.fields)
    w.publishing = true

    for b in w.bindings {
        b.hist.write_guard = world_field_guard
        b.hist.guard_user = w
        history_note_bytes(b.hist, w.head, f.fields[b.offset:b.offset + b.size])
    }

    w.publishing = false
    provider.bind(provider.user, w.published)
    provider.publish(provider.user, w.published)
    w.provider.initial_execution = nil
    l.anchored = true
    world_budget_register(l)
    owner_transferred = true
    detached_transferred = true
    effects_transferred = true
    user_transferred = true
    author_transferred = true
    return .Ok
}

lane_world_detach :: proc(l: ^Lane) -> World_Error {
    if l.world == nil {
        return .Ok
    }

    w := l.world

    if w.busy || w.presenting {
        return .Busy
    }

    if e := world_owner_check(w.provider.owner); e != .Ok {
        return e
    }

    owner := w.provider.owner
    detached_owner := w.provider.detached_owner
    effect_owner := w.provider.effect_owner
    user_owner, author_owner := w.provider.user_owner, w.provider.author_owner
    world_budget_unregister(w)
    _ = lane_world_network_detach(l)

    for b in w.bindings {
        b.hist.write_guard = nil
        b.hist.guard_user = nil
    }

    world_fields_free(w)
    w.provider.close(w.published)
    w.provider.bind(w.provider.user, nil)
    w.provider.publish(w.provider.user, nil)
    free(w, w.allocator)
    l.world = nil

    if e := world_owner_drop(effect_owner); e != .Ok {
        return e
    }

    if e := world_owner_drop(author_owner); e != .Ok {
        return e
    }

    if e := world_owner_drop(user_owner); e != .Ok {
        return e
    }

    if e := world_owner_drop(detached_owner); e != .Ok {
        return e
    }

    return world_owner_drop(owner)
}

lane_world_checkpoint :: proc(l: ^Lane, tick: u64) -> (checkpoint: World_Checkpoint, error: World_Error) {
    if l.world == nil {
        return {}, .Unsupported
    }

    w := l.world

    if w.busy || w.presenting {
        return {}, .Busy
    }

    if e := world_owner_check(w.provider.owner); e != .Ok {
        return {}, e
    }

    f := world_record(w, tick)

    if f == nil {
        return {}, .History_Missing
    }

    mark, budget_error := world_budget_begin(w.provider.budget, w.config.reservation_bytes)

    if budget_error != .Ok {
        return {}, budget_error
    }

    defer world_budget_end(w.provider.budget, &mark)
    owner := w.provider.detached_owner

    if !world_owner_is_empty(owner) &&
       f.effect_count > 0 &&
       owner.context_caps & WORLD_OWNER_INDEPENDENT_CONTEXT == 0 {
        return {}, .Unsupported
    }

    charge := u64(len(f.fields) + size_of(World_Checkpoint))

    if g_world_checkpoint_bytes > WORLD_MEMORY_BYTES || charge > WORLD_MEMORY_BYTES - g_world_checkpoint_bytes {
        return {}, .Budget
    }

    if e := w.provider.admit_detached(world_all_owned_bytes() + charge, w.config.reservation_bytes); e != .Ok {
        return {}, e
    }

    if e := world_owner_retain(owner); e != .Ok {
        return {}, e
    }

    owner_transferred := false

    defer {
        if !owner_transferred {
            _ = world_owner_drop(owner)
        }
    }

    if e := world_owner_retain(w.provider.effect_owner); e != .Ok {
        return {}, e
    }

    effects_transferred := false

    defer {
        if !effects_transferred {
            _ = world_owner_drop(w.provider.effect_owner)
        }
    }

    image, status := w.provider.clone(f.image)

    if status != .Ok {
        return {}, status
    }

    fields, err := make([]u8, len(f.fields), w.allocator)

    if err != nil {
        w.provider.release(image)
        return {}, .Allocation_Failed
    }

    copy(fields, f.fields)
    checkpoint = {
        effect_owner      = w.provider.effect_owner,
        owner             = owner,
        tick              = tick,
        asset_id          = w.provider.asset_id,
        field_schema      = w.field_schema,
        side_type         = w.provider.side_type,
        image             = image,
        fields            = fields,
        clone             = w.provider.clone,
        release           = w.provider.release,
        equal             = w.provider.equal,
        allocator         = w.allocator,
        admit_detached    = w.provider.admit_detached,
        effects_known     = true,
        effect_count      = f.effect_count,
        effects           = f.effects,
        charge_bytes      = charge,
        reservation_bytes = w.config.reservation_bytes,
    }
    g_world_checkpoint_bytes += charge
    owner_transferred = true
    effects_transferred = true

    if e := w.provider.admit_detached(world_all_owned_bytes(), 0); e != .Ok {
        world_checkpoint_destroy(&checkpoint)
        return {}, e
    }

    checkpoint.budget = w.provider.budget

    if e := world_budget_reconcile(checkpoint.budget, mark); e != .Ok {
        world_checkpoint_destroy(&checkpoint)
        return {}, e
    }

    return checkpoint, .Ok
}

world_checkpoint_clone :: proc(source: ^World_Checkpoint) -> (checkpoint: World_Checkpoint, error: World_Error) {
    if source == nil || source.image == nil || source.clone == nil {
        return {}, .Invalid
    }

    if e := world_owner_check(source.owner); e != .Ok {
        return {}, e
    }

    mark, budget_error := world_budget_begin(source.budget, source.reservation_bytes)

    if budget_error != .Ok {
        return {}, budget_error
    }

    defer world_budget_end(source.budget, &mark)

    if g_world_checkpoint_bytes > WORLD_MEMORY_BYTES ||
       source.charge_bytes > WORLD_MEMORY_BYTES - g_world_checkpoint_bytes {
        return {}, .Budget
    }

    if e := source.admit_detached(world_all_owned_bytes() + source.charge_bytes, source.reservation_bytes); e != .Ok {
        return {}, e
    }

    if e := world_owner_retain(source.owner); e != .Ok {
        return {}, e
    }

    owner_transferred := false

    defer {
        if !owner_transferred {
            _ = world_owner_drop(source.owner)
        }
    }

    if e := world_owner_retain(source.effect_owner); e != .Ok {
        return {}, e
    }

    effects_transferred := false

    defer {
        if !effects_transferred {
            _ = world_owner_drop(source.effect_owner)
        }
    }

    image, status := source.clone(source.image)

    if status != .Ok {
        return {}, status
    }

    fields, err := make([]u8, len(source.fields), source.allocator)

    if err != nil {
        source.release(image)
        return {}, .Allocation_Failed
    }

    copy(fields, source.fields)
    checkpoint = source^
    checkpoint.image = image
    checkpoint.fields = fields
    g_world_checkpoint_bytes += checkpoint.charge_bytes
    owner_transferred = true
    effects_transferred = true

    if e := source.admit_detached(world_all_owned_bytes(), 0); e != .Ok {
        world_checkpoint_destroy(&checkpoint)
        return {}, e
    }

    if e := world_budget_reconcile(source.budget, mark); e != .Ok {
        world_checkpoint_destroy(&checkpoint)
        return {}, e
    }

    return checkpoint, .Ok
}

world_checkpoint_equal :: proc(left, right: ^World_Checkpoint) -> (bool, World_Error) {
    if left == nil || right == nil || left.image == nil || right.image == nil {
        return false, .Missing_Attachment
    }

    if e := world_owner_check(left.owner); e != .Ok {
        return false, e
    }

    if e := world_owner_check(right.owner); e != .Ok {
        return false, e
    }

    if left.tick != right.tick ||
       left.asset_id != right.asset_id ||
       left.side_type != right.side_type ||
       left.field_schema != right.field_schema ||
       len(left.fields) != len(right.fields) {
        return false, .Incompatible
    }

    if mem.compare(left.fields, right.fields) != 0 {
        return false, .Ok
    }

    if left.effects_known != right.effects_known ||
       (left.effects_known &&
               !world_effects_equal(left.effects[:left.effect_count], right.effects[:right.effect_count])) {
        return false, .Ok
    }

    return left.equal(left.image, right.image)
}

world_checkpoint_destroy :: proc(checkpoint: ^World_Checkpoint) -> World_Error {
    if checkpoint == nil {
        return .Ok
    }

    if e := world_owner_check(checkpoint.owner); e != .Ok {
        return e
    }

    owner := checkpoint.owner
    effect_owner := checkpoint.effect_owner

    if e := world_owner_check(effect_owner); e != .Ok {
        return e
    }

    if checkpoint.image != nil {
        context.allocator = checkpoint.allocator
        checkpoint.release(checkpoint.image)
        delete(checkpoint.fields)
        assert(g_world_checkpoint_bytes >= checkpoint.charge_bytes)
        g_world_checkpoint_bytes -= checkpoint.charge_bytes
    }

    // A declining final Data_Lease drop leaves a cleanup-only capability. Do
    // not invoke a freed image/allocator twice or lose the still-owned code pin.
    checkpoint^ = {
        owner        = owner,
        effect_owner = effect_owner,
    }

    if e := world_owner_drop(effect_owner); e != .Ok {
        return e
    }

    checkpoint.effect_owner = {}

    if e := world_owner_drop(owner); e != .Ok {
        return e
    }

    checkpoint^ = {}
    return .Ok
}

world_checkpoint_owned_bytes :: proc() -> u64 {
    return g_world_checkpoint_bytes
}

// Read-only backend image for the concrete provider's immutable pose cache.
world_checkpoint_owner_check :: proc "contextless" (checkpoint: ^World_Checkpoint) -> World_Error {
    if checkpoint == nil {
        return .Invalid
    }

    return world_owner_check(checkpoint.owner)
}

world_checkpoint_image :: proc(checkpoint: ^World_Checkpoint) -> rawptr {
    if world_checkpoint_owner_check(checkpoint) != .Ok {
        return nil
    }

    return checkpoint != nil ? checkpoint.image : nil
}

lane_world_emit :: proc(l: ^Lane, key: u64, fire: World_Effect_Proc, user: rawptr, args: []u8 = nil) -> World_Error {
    if l.world == nil || !l.world.busy || fire == nil || key == 0 {
        return .Invalid
    }

    w := l.world

    if !world_owner_is_empty(w.provider.owner) && user != nil {
        if user != w.provider.effect_user ||
           world_owner_is_empty(w.provider.effect_owner) ||
           w.provider.effect_owner.context_caps & WORLD_OWNER_INDEPENDENT_CONTEXT == 0 {
            w.status = .Unsupported
            return .Unsupported
        }

        if e := world_owner_check(w.provider.effect_owner); e != .Ok {
            w.status = e
            return e
        }
    }

    kind := u16(0)

    if w.network != nil {
        for def in w.network.effects {
            if def.fire == fire && def.user == user {
                if len(args) != def.codec.local_bytes {
                    w.status = .Invalid
                    return .Invalid
                }

                canonical: [WORLD_EFFECT_BYTES]u8

                if error := def.codec.encode(def.codec.user, args, canonical[:def.codec.wire_bytes]); error != .Ok {
                    w.status = error
                    return error
                }

                kind = def.kind
                break
            }
        }

        if kind == 0 {
            w.status = .Unsupported
            return .Unsupported
        }
    }

    if len(args) > WORLD_EFFECT_BYTES || w.current_effect_count >= WORLD_EFFECTS_PER_TICK {
        w.status = .Capacity
        return .Capacity
    }

    for e in w.current_effects[:w.current_effect_count] {
        if e.key == key {
            w.status = .Invalid
            return .Invalid
        }
    }

    e := &w.current_effects[w.current_effect_count]
    e^ = {
        kind  = kind,
        key   = key,
        fire  = fire,
        user  = user,
        count = len(args),
    }
    copy(e.args[:], args)
    w.current_effect_count += 1
    return .Ok
}

// Optional accepted-input/complete-state protocol. All local pointer-bearing
// codecs remain process-local. Only their canonical descriptors enter identity.
WORLD_NETWORK_REV :: u32(2)
WORLD_NETWORK_BYTES :: 1024 * 1024
WORLD_NETWORK_CHUNK :: 32 * 1024
WORLD_NETWORK_DRIVERS :: 16
WORLD_NETWORK_QUEUE :: 16
WORLD_NETWORK_TRANSFERS :: 8 // complete receive staging, not simulation/history depth
SIM_WORLD_INPUT :: u8(16)
SIM_WORLD_ACCEPTED :: u8(17)
SIM_WORLD_CHUNK :: u8(18)
SIM_WORLD_REQUEST :: u8(19)
SIM_WORLD_SIGNATURE :: u8(21)

World_Value_Codec :: struct {
    owner:                   World_Owner,
    acquire, release:        proc(user: rawptr) -> World_Error,
    user:                    rawptr,
    local_bytes, wire_bytes: int,
    descriptor:              []u8, // canonical schema, no offsets/type_info addresses
    encode:                  proc(user: rawptr, local, wire: []u8) -> World_Error,
    decode:                  proc(user: rawptr, wire, local: []u8) -> World_Error,
}

World_Wire_Field :: struct {
    id:    knet.Net_Id,
    codec: World_Value_Codec,
}

World_Input_Prediction :: enum u8 {
    Hold,
    Neutral,
}

World_Wire_Input :: struct {
    class:      u16,
    codec:      World_Value_Codec,
    prediction: World_Input_Prediction,
}

World_Driver :: struct {
    player: knet.Player_Id,
    class:  u16,
}

World_Effect_Def :: struct {
    kind:  u16,
    fire:  World_Effect_Proc,
    user:  rawptr,
    codec: World_Value_Codec,
}

World_Wire_Codec :: struct {
    owner:           World_Owner,
    user:            rawptr,
    admit:           proc(user, execution: rawptr) -> (int, World_Error), // optional idle-execution probe; full writer fallback
    // Solver is the complete normalized logical dump; recovery_encode is the
    // separate canonical import attachment. Side and
    // Observations are canonical typed bytes; Game is composed by Kit.
    recovery_encode: proc(user, image: rawptr, out: []u8) -> (int, World_Error),
    encode:          proc(user, image: rawptr, part: bd.Part, out: []u8) -> (int, World_Error),
    decode:          proc(user: rawptr, solver, side, observations: []u8) -> (rawptr, World_Error),
    fields:          []World_Wire_Field,
    inputs:          []World_Wire_Input,
}

World_Network_Config :: struct {
    identity: bd.Identity,
    codec:    World_Wire_Codec,
    drivers:  []World_Driver, // immutable ordered roster, no AOI/contact filtering
    effects:  []World_Effect_Def,
    epoch:    u64,
}

World_Transfer_Mode :: enum u8 {
    Welcome,
    Correction,
    Reset,
}

World_Input_Origin :: enum u8 {
    Unknown,
    Submitted,
    Held,
    Authority,
}

World_Input_Row :: struct {
    tick:     u64,
    valid:    bool,
    sequence: [WORLD_NETWORK_DRIVERS]u64,
    origin:   [WORLD_NETWORK_DRIVERS]World_Input_Origin,
}

World_Net_Packet :: struct {
    from:  knet.Player_Id,
    kind:  u8,
    bytes: []u8,
    peer:  ksess.Peer_Id, // original authenticated peer, never later reconstructed
}

// v2 normal traffic carries no recovery image. A receipt is local proposal
// validation, not an accepted gameplay outcome or remote delivery certificate.
World_Protocol_Status :: struct {
    wire_revision:                                                                        u32,
    bootstrap_sequence, matched_signature_tick, pending_signature_tick, accepted_through: u64,
    signatures_sent, signatures_matched, full_states_sent, full_states_received:          u64,
    receipt_available:                                                                    bool,
    receipt_player:                                                                       knet.Player_Id,
    receipt_proposal_tick, receipt_authority_tick:                                        u64,
    scale:                                                                                f64,
    error:                                                                                World_Error,
}

@(private)
World_Protocol_Receipt :: struct {
    valid, available:                         bool,
    peer:                                     ksess.Peer_Id,
    epoch, bootstrap_sequence, proposal_tick: u64,
    value_count:                              int,
    value:                                    [MAX_INPUT_SIZE]u8,
}

@(private)
World_Protocol_State :: struct {
    bootstrap_sequence, matched_signature_tick, accepted_through, authority_tick: u64,
    canonical_floor:                                                              u64,
    signatures_sent, signatures_matched, full_states_sent, full_states_received:  u64,
    signatures:                                                                   [WORLD_REPAIR_TICKS]bd.Signature,
    signature_head, signature_count:                                              int,
    receipts:                                                                     [WORLD_NETWORK_DRIVERS]World_Protocol_Receipt,
    receipt_available:                                                            bool,
    receipt_player:                                                               knet.Player_Id,
    receipt_proposal_tick, receipt_authority_tick, receipt_bootstrap:             u64,
    error:                                                                        World_Error,
}

World_Completed_Transfer :: struct {
    bytes:                 []u8,
    hash:                  bd.Digest,
    sequence, epoch, tick: u64,
    mode:                  World_Transfer_Mode,
    chunks:                int,
}

World_Network :: struct {
    protocol:                                               World_Protocol_State,
    owned_codecs:                                           [35 + WORLD_NETWORK_DRIVERS + WORLD_EFFECTS_PER_TICK]World_Value_Codec,
    owned_codec_count:                                      int,
    wire_owned:                                             bool,
    config:                                                 World_Network_Config,
    drivers:                                                []World_Driver,
    effects:                                                []World_Effect_Def,
    offsets:                                                [WORLD_NETWORK_DRIVERS]int,
    value_bytes:                                            int,
    // These are input ledgers, not another simulation/history runtime.
    accepted, proposed, used:                               [WORLD_HISTORY_FRAMES]World_Input_Row,
    accepted_data, proposed_data, used_data:                []u8,
    incoming:                                               [WORLD_REPAIR_TICKS]World_Input_Row,
    incoming_count:                                         int,
    check_signature:                                        bd.Signature,
    backup:                                                 [WORLD_HISTORY_FRAMES]World_Input_Row,
    backup_data:                                            []u8,
    staged:                                                 [WORLD_REPAIR_TICKS + 1]World_Input_Row,
    staged_data:                                            []u8,
    stage_count:                                            int,
    queue:                                                  [WORLD_NETWORK_QUEUE]World_Net_Packet,
    queue_count:                                            int,
    queue_bytes:                                            int,
    transfer:                                               []u8,
    transfer_seen:                                          [32]bool,
    transfer_hash:                                          bd.Digest,
    transfer_sequence, transfer_epoch, transfer_tick:       u64,
    transfer_mode:                                          World_Transfer_Mode,
    transfer_chunks, transfer_received:                     int,
    completed:                                              [WORLD_NETWORK_TRANSFERS]World_Completed_Transfer,
    completed_head, completed_count:                        int,
    applying_transfer:                                      World_Completed_Transfer,
    outbound_bytes:                                         u64,
    epoch, sequence, received_sequence, submitted_sequence: u64,
    // Obsolete ordinary transfers observed while unready, not validated receipts.
    ignored_correction_epoch, ignored_correction_sequence:  u64,
    ready, applying:                                        bool,
    authority:                                              bool,
    local_player:                                           knet.Player_Id,
    status:                                                 World_Error,
    last_signature:                                         bd.Signature,
    trace:                                                  bd.Trace,
    duplicates, conflicts, rejected, accepted_batches:      u64,
}

World_Network_Status :: struct {
    ready, needs_resync:                                                       bool,
    error:                                                                     World_Error,
    epoch, confirmed, head, accepted_batches, duplicates, conflicts, rejected: u64,
    owned_bytes:                                                               u64,
}

lane_world_network_status :: proc(l: ^Lane) -> World_Network_Status {
    if l == nil || l.world == nil || l.world.network == nil {
        return {error = .Unsupported}
    }

    w := l.world
    n := w.network
    return {
        n.ready,
        w.resync,
        n.status,
        n.epoch,
        w.confirmed,
        w.head,
        n.accepted_batches,
        n.duplicates,
        n.conflicts,
        n.rejected,
        world_network_bytes(n),
    }
}

lane_world_protocol_status :: proc(l: ^Lane) -> World_Protocol_Status {
    status := World_Protocol_Status {
        wire_revision = WORLD_NETWORK_REV,
        error         = .Unsupported,
        scale         = 1,
    }

    if l == nil || l.world == nil || l.world.network == nil {
        return status
    }

    n := l.world.network
    v := &n.protocol
    status = {
        wire_revision          = WORLD_NETWORK_REV,
        bootstrap_sequence     = v.bootstrap_sequence,
        matched_signature_tick = v.matched_signature_tick,
        accepted_through       = v.accepted_through,
        signatures_sent        = v.signatures_sent,
        signatures_matched     = v.signatures_matched,
        full_states_sent       = v.full_states_sent,
        full_states_received   = v.full_states_received,
        receipt_player         = v.receipt_player,
        receipt_proposal_tick  = v.receipt_proposal_tick,
        receipt_authority_tick = v.receipt_authority_tick,
        scale                  = l.ticker.scale,
        error                  = n.status == .Ok ? v.error : n.status,
    }

    if v.signature_count > 0 {
        status.pending_signature_tick = v.signatures[v.signature_head].tick
    }

    status.receipt_available = world_protocol_receipt_fresh(l)
    return status
}

@(private)
world_effects_equal :: proc(a, b: []World_Effect) -> bool {
    if len(a) != len(b) {
        return false
    }

    for &x, i in a {
        y := &b[i]

        if x.kind != y.kind ||
           x.key != y.key ||
           x.count != y.count ||
           mem.compare(x.args[:x.count], y.args[:y.count]) != 0 {
            return false
        }
    }

    return true
}

// One immutable diagnostic owner, with all five detached canonical byte parts.
// Assignment aliases ownership: use clone for a second owner. Treat view.parts
// as read-only. Allocator data and producer code (including the origin callbacks)
// must remain live until destruction; P4 supplies the actual module lease bridge.
// No native world, source Lane, or recovery attachment is retained.
World_Diagnostic_Frame :: struct {
    owner:     World_Owner,
    view:      bd.Frame_View,
    signature: bd.Signature,
    _owner:    rawptr,
    _clone:    proc "contextless" (owner: rawptr) -> (World_Diagnostic_Frame, World_Error),
    _release:  proc "contextless" (owner: rawptr) -> World_Error,
}

@(private)
World_Diagnostic_Owner :: struct {
    budget:    World_Budget,
    lifetime:  World_Owner,
    view:      bd.Frame_View,
    signature: bd.Signature,
    storage:   []u8,
    allocator: mem.Allocator,
    charge:    u64,
    admit:     proc(additional, reserved: u64) -> World_Error,
}

world_diagnostic_frame_owned_bytes :: proc "contextless" () -> u64 {
    return g_world_diagnostic_bytes
}

@(private)
world_diagnostic_release :: proc "contextless" (opaque: rawptr) -> World_Error {
    context = runtime.default_context()
    owner := cast(^World_Diagnostic_Owner)opaque

    if owner == nil {
        return .Ok
    }

    if e := world_owner_check(owner.lifetime); e != .Ok {
        return e
    }

    allocator, charge := owner.allocator, owner.charge
    delete(owner.storage, allocator)
    free(owner, allocator)
    assert(g_world_diagnostic_bytes >= charge)
    g_world_diagnostic_bytes -= charge
    return .Ok
}

// Idempotent on an empty owner. Release executes in the originating code image
// and uses its allocator/counter; no Lane callback or native object is needed.
world_diagnostic_frame_destroy :: proc "contextless" (frame: ^World_Diagnostic_Frame) -> World_Error {
    if frame == nil {
        return .Ok
    }

    if e := world_owner_check(frame.owner); e != .Ok {
        return e
    }

    lifetime := frame.owner

    if frame._owner != nil {
        if e := frame._release(frame._owner); e != .Ok {
            return e
        }
    }

    frame^ = {
        owner = lifetime,
    }

    if e := world_owner_drop(lifetime); e != .Ok {
        return e
    }

    frame^ = {}
    return .Ok
}

// Transactional replacement, including clone(&x,&x). Failed cloning leaves the
// source and the previous destination owner exactly as they were.
world_diagnostic_frame_clone :: proc "contextless" (
    source: ^World_Diagnostic_Frame,
    out: ^World_Diagnostic_Frame,
) -> World_Error {
    if source == nil || out == nil || source._owner == nil || source._clone == nil {
        return .Invalid
    }

    if e := world_owner_check(source.owner); e != .Ok {
        return e
    }

    if e := world_owner_check(out.owner); e != .Ok {
        return e
    }

    candidate, error := source._clone(source._owner)

    if error != .Ok {
        return error
    }

    if error := world_diagnostic_frame_destroy(out); error != .Ok {
        _ = world_diagnostic_frame_destroy(&candidate)
        return error
    }

    out^ = candidate
    return .Ok
}

@(private)
world_diagnostic_clone_owner :: proc "contextless" (opaque: rawptr) -> (World_Diagnostic_Frame, World_Error) {
    context = runtime.default_context()
    owner := cast(^World_Diagnostic_Owner)opaque

    if owner == nil {
        return {}, .Invalid
    }

    // Mutation is outside the immutable-owner contract; never clone an internally
    // inconsistent part/signature pair into another apparently valid owner.
    if e := world_owner_check(owner.lifetime); e != .Ok {
        return {}, e
    }

    signature, error := bd.sign(owner.view)

    if error != .None || bd.compare(signature, owner.signature) != .Match {
        return {}, .Invalid
    }

    return world_diagnostic_copy(
        owner.view,
        owner.signature,
        owner.allocator,
        owner.admit,
        world_all_owned_bytes(),
        owner.lifetime,
        owner.budget,
    )
}

@(private)
world_diagnostic_copy :: proc(
    view: bd.Frame_View,
    signature: bd.Signature,
    allocator: mem.Allocator,
    admit: proc(additional, reserved: u64) -> World_Error,
    additional: u64,
    lifetime: World_Owner = {},
    budget: World_Budget = {},
) -> (
    frame: World_Diagnostic_Frame,
    error: World_Error,
) {
    mark, budget_error := world_budget_begin(budget, 2 * 1024 * 1024)

    if budget_error != .Ok {
        return {}, budget_error
    }

    defer world_budget_end(budget, &mark)
    total := 0

    for part in view.parts {
        if len(part) > WORLD_NETWORK_BYTES - total {
            return {}, .Capacity
        }

        total += len(part)
    }

    charge := u64(size_of(World_Diagnostic_Owner) + total)

    if charge > WORLD_MEMORY_BYTES ||
       g_world_diagnostic_bytes > WORLD_MEMORY_BYTES - charge ||
       additional > WORLD_MEMORY_BYTES - charge {
        return {}, .Budget
    }

    if e := admit(additional + charge, 0); e != .Ok {
        return {}, e
    }

    if e := world_owner_retain(lifetime); e != .Ok {
        return {}, e
    }

    owner_transferred := false

    defer {
        if !owner_transferred {
            _ = world_owner_drop(lifetime)
        }
    }

    owner, allocation_error := new(World_Diagnostic_Owner, allocator)

    if allocation_error != nil || owner == nil {
        return {}, .Allocation_Failed
    }

    owner^ = {
        budget    = budget,
        lifetime  = lifetime,
        view      = view,
        signature = signature,
        allocator = allocator,
        charge    = u64(size_of(World_Diagnostic_Owner)),
        admit     = admit,
    }
    g_world_diagnostic_bytes += owner.charge
    owner_transferred = true
    storage, storage_error := make([]u8, total, allocator)
    owner.storage = storage
    owner.charge += u64(len(storage))
    g_world_diagnostic_bytes += u64(len(storage))

    if storage_error != nil || len(storage) != total {
        world_diagnostic_release(owner)
        _ = world_owner_drop(lifetime)
        return {}, .Allocation_Failed
    }

    at := 0

    for p in bd.Part {
        part := view.parts[p]
        copy(storage[at:at + len(part)], part)
        owner.view.parts[p] = storage[at:at + len(part)]
        at += len(part)
    }

    assert(owner.charge == charge)
    frame = {lifetime, owner.view, signature, owner, world_diagnostic_clone_owner, world_diagnostic_release}

    if e := admit(additional + charge, 0); e != .Ok {
        world_diagnostic_frame_destroy(&frame)
        return {}, e
    }

    if e := world_budget_reconcile(budget, mark); e != .Ok {
        world_diagnostic_frame_destroy(&frame)
        return {}, e
    }

    return frame, .Ok
}

// Optional producer lifetime capability. It is C-shaped; no native/Godot import
// enters this package. Core owns these hooks and provides an OUTERMOST origin
// call scope. A producer-local defer/leave is not a substitute for that scope.
// Code residency is distinct from retained allocator/FX/user data ownership.
World_Owner :: bg.Owner
WORLD_OWNER_READ :: u32(0)
WORLD_OWNER_EXECUTE :: u32(1)
WORLD_OWNER_MANAGED_DATA :: u32(1)
WORLD_OWNER_WEAK_INSTANCE :: u32(2)
WORLD_OWNER_INDEPENDENT_CONTEXT :: u32(4)
@(private)
g_world_owner_realm: u64

// Install once per producer code image. Tokens are process-local lifetime
// provenance, never canonical Game/Side/wire identifiers.
world_owner_realm_install :: proc "contextless" (realm: u64) -> World_Error {
    if realm == 0 {
        return .Invalid
    }

    if g_world_owner_realm != 0 && g_world_owner_realm != realm {
        return .Incompatible
    }

    g_world_owner_realm = realm
    return .Ok
}

@(private)
world_host_status :: proc "contextless" (status: bg.Status) -> World_Error {
    switch status {
    case bg.OK:
        return .Ok
    case bg.CAPACITY:
        return .Budget
    case bg.OUT_OF_MEMORY:
        return .Allocation_Failed
    case bg.INCOMPATIBLE:
        return .Incompatible
    case bg.UNSUPPORTED:
        return .Unsupported
    case:
        return .Rejected
    }
}

@(private)
world_budget_begin :: proc "contextless" (budget: World_Budget, bound: u64) -> (u64, World_Error) {
    if budget.begin == nil {
        if budget.reconcile != nil || budget.end != nil || budget.user != nil {
            return 0, .Invalid
        }

        return 0, .Ok
    }

    if budget.user == nil || budget.reconcile == nil || budget.end == nil {
        return 0, .Invalid
    }

    mark: u64
    status := budget.begin(budget.user, bound, &mark)

    if status != bg.OK {
        return 0, world_host_status(status)
    }

    if mark == 0 {
        return 0, .Invalid
    }

    return mark, .Ok
}

@(private)
world_budget_reconcile :: proc "contextless" (budget: World_Budget, mark: u64) -> World_Error {
    if mark == 0 {
        return .Ok
    }

    return world_host_status(budget.reconcile(budget.user, mark))
}

@(private)
world_budget_end :: proc(budget: World_Budget, mark: ^u64) {
    if mark == nil || mark^ == 0 {
        return
    }

    value := mark^
    mark^ = 0
    status := budget.end(budget.user, value)
    assert(status == bg.OK || status == bg.CAPACITY, "invalid or out-of-order operation budget end")
}

world_owner_is_empty :: proc "contextless" (owner: World_Owner) -> bool {
    return(
        owner.user == nil &&
        owner.realm == 0 &&
        owner.context_caps == 0 &&
        owner.reserved == 0 &&
        owner.check == nil &&
        owner.retain == nil &&
        owner.drop == nil \
    )
}

// Realm check occurs before a producer-specific cast/callback/allocator access.
// A valid nonnil capability must retain actual managed data (or explicitly no
// data) and identify either a weak live instance or an independent context.
world_owner_check :: proc "contextless" (owner: World_Owner, access: u32 = WORLD_OWNER_READ) -> World_Error {
    if world_owner_is_empty(owner) {
        return .Ok
    }

    if owner.reserved != 0 ||
       owner.realm == 0 ||
       owner.check == nil ||
       owner.retain == nil ||
       owner.drop == nil ||
       access > WORLD_OWNER_EXECUTE {
        return .Invalid
    }

    if owner.realm != g_world_owner_realm {
        return .Incompatible
    }

    if owner.context_caps & WORLD_OWNER_MANAGED_DATA == 0 ||
       owner.context_caps & (WORLD_OWNER_WEAK_INSTANCE | WORLD_OWNER_INDEPENDENT_CONTEXT) == 0 ||
       owner.context_caps &
               ~(WORLD_OWNER_MANAGED_DATA | WORLD_OWNER_WEAK_INSTANCE | WORLD_OWNER_INDEPENDENT_CONTEXT) !=
           0 {
        return .Invalid
    }

    return owner.check(owner.user, access) == 0 ? .Ok : .Rejected
}

world_owner_retain :: proc "contextless" (owner: World_Owner) -> World_Error {
    if e := world_owner_check(owner); e != .Ok {
        return e
    }

    if world_owner_is_empty(owner) {
        return .Ok
    }

    return owner.retain(owner.user) == 0 ? .Ok : .Rejected
}

world_owner_drop :: proc "contextless" (owner: World_Owner) -> World_Error {
    if e := world_owner_check(owner); e != .Ok {
        return e
    }

    if world_owner_is_empty(owner) {
        return .Ok
    }

    return owner.drop(owner.user) == 0 ? .Ok : .Rejected
}
