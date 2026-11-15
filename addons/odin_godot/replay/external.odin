package replay

import intrinsics "base:intrinsics"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import "core:mem"
import "base:runtime"

// Optional managed state participation. This package has no native dependency.
// Images own all mutable-state dependencies; executions are disposable working
// copies. Callbacks must clean partial outputs on error and never mutate images.
External :: struct {
    owner:                                 Owner, // nil standalone; SDK owner requires active protected origin realm
    owner_allocator_data, owner_user_data: rawptr, // exact retained contexts, never inferred spans
    identity:                              u64, // provider kind, nonzero
    contract:                              u64, // immutable exact build/target/content/config identity
    valid_value:                           proc(_: typeid) -> bool, // optional provider-specific value restrictions
    reserve:                               proc(image: rawptr, bytes: u64) -> Error, // optional global game/container ownership charge
    unreserve:                             proc(bytes: u64),
    preflight:                             proc(image: rawptr, usage: External_Usage) -> Error, // optional before core allocations
    clone:                                 proc(image: rawptr) -> (rawptr, Error),
    release:                               proc(image: rawptr),
    open:                                  proc(image: rawptr) -> (rawptr, Error),
    close:                                 proc(execution: rawptr),
    capture:                               proc(execution: rawptr) -> (image: rawptr, bytes: u64, error: Error),
    equal:                                 proc(a, b: rawptr) -> (bool, Error),
    // Called before/after capture and before publication. Backend-specific counts,
    // assets, allocations and scratch reservations belong here.
    admit:                                 proc(
        execution: rawptr,
        phase: External_Phase,
        usage: External_Usage,
    ) -> Error,
    clock:                                 proc() -> u64, // monotonic ns, outside simulation
    limits:                                External_Limits,
    require_step:                          bool, // concrete fixed-step provider requires exactly one claim per tick
}

External_Limits :: struct {
    history_frames:       int, // zero accepts ordinary configured history
    max_prediction_ticks: u64,
    max_repair_ticks:     u64,
    max_audit_ticks:      u64, // zero defaults to retained history minus predecessor
    max_bytes:            u64,
}

// Work is preparation through admission. Total additionally includes publication,
// retired execution/image release and failed-stage cleanup. Observations only.
// Per-stage totals/counts/errors describe the most recent transaction. Model
// includes the entire step callback (including accepted-action savepoints);
// capture counts staged-record captures, so these are partial/nested values.
// A zero sample count means unobserved, not zero cost. Never subtract these
// phases from the whole public operation's wall-time measurement.
// Errors count invalid/overflowing clock observations, not backend failures.
// Operation failures remain in Result and never depend on these diagnostics.
External_Phase_Timing :: struct {
    total_ns, samples, errors: u64,
}

External_Profile :: struct {
    last_work_ns, peak_work_ns, last_total_ns, peak_total_ns: u64,
    open, model, capture:                                     External_Phase_Timing,
}

@(private)
external_timing_finish :: proc(timing: ^External_Phase_Timing, clock: proc() -> u64, started: u64) {
    if clock == nil {
        return
    }

    ended := clock()

    if ended < started || ended - started > max(u64) - timing.total_ns {
        timing.errors += 1
        return
    }

    timing.total_ns += ended - started
    timing.samples += 1
}

External_Phase :: enum {
    Initial,
    Advance,
    Revision,
    Audit,
    Reset,
    Savepoint,
    Export,
}

External_Usage :: struct {
    runtime_bytes, image_bytes, savepoint_bytes: u64,
}

// A borrowed capability exists only inside the current step callback. Retaining
// it in typed State is rejected by value_supported. Helpers detect stale scopes.
Execution :: struct {
    _run:        ^External_Run,
    _generation: u64,
    _validate:   proc(run: ^External_Run, nonce: u64) -> bool,
}

@(private)
External_Run :: struct {
    external:   External,
    value:      rawptr,
    phase:      External_Phase,
    started:    u64,
    active:     bool,
    generation: u64,
    usage:      External_Usage,
    step_count: u32,
    error:      Error,
}

// Savepoints are callback-local owners. Use release on every path; the network
// model helper below pairs them with its existing State/event savepoint.
External_Savepoint :: struct {
    image:       rawptr,
    bytes:       u64,
    _run:        ^External_Run,
    _generation: u64,
}

external_enabled :: proc(t: ^Timeline($S, $I, $E)) -> bool {
    return t.external.identity != 0
}

// Nonces are runtime borrow identity, never canonical simulation data. Native
// callers use an atomic sequence; freestanding WASM is a single-caller domain.
@(private)
external_scope_nonce: u64

when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
    @(private)
    external_active_run: ^External_Run
    @(private)
    external_active_nonce: u64
} else {
    @(private)
    @(thread_local)
    external_active_run: ^External_Run
    @(private)
    @(thread_local)
    external_active_nonce: u64
}

@(private)
external_next_scope :: proc() -> (u64, Error) {
    when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
        if external_scope_nonce == max(u64) {
            return 0, .Resource_Limit
        }

        external_scope_nonce += 1
        return external_scope_nonce, .None
    } else {
        for {
            previous := intrinsics.atomic_load_explicit(&external_scope_nonce, .Relaxed)

            if previous == max(u64) {
                return 0, .Resource_Limit
            }

            _, exchanged := intrinsics.atomic_compare_exchange_strong_explicit(
                &external_scope_nonce,
                previous,
                previous + 1,
                .Relaxed,
                .Relaxed,
            )

            if exchanged {
                return previous + 1, .None
            }
        }
    }
}

@(private)
external_scope_valid :: proc(run: ^External_Run, nonce: u64) -> bool {
    // This callback belongs to the originating core image. A gameplay module may
    // contain its own pure Replay code, but validation still uses the owner's TLS.
    return nonce != 0 && nonce == external_active_nonce && run == external_active_run
}

@(private)
execution_run :: proc(capability: Execution) -> ^External_Run {
    // Validate the live thread/scope BEFORE dereferencing a borrowed owner.
    if capability._validate == nil || !capability._validate(capability._run, capability._generation) {
        return nil
    }

    run := capability._run

    if run == nil || !run.active || run.generation != capability._generation || run.value == nil {
        return nil
    }

    return run
}

execution_pointer :: proc(capability: Execution, identity: u64) -> (rawptr, Error) {
    run := execution_run(capability)

    if run == nil {
        return nil, .Stale_Execution
    }

    if identity == 0 || run.external.identity != identity {
        return nil, .External_State
    }

    if run.error != .None {
        return nil, run.error
    }

    return run.value, .None
}

execution_identity :: proc(capability: Execution) -> u64 {
    run := execution_run(capability)
    return run != nil ? run.external.identity : 0
}

execution_generation :: proc(capability: Execution) -> u64 {
    return execution_run(capability) != nil ? capability._generation : 0
}

// Provider command failures poison this unpublished callback even if gameplay
// ignores the returned status. A predicate rejection still restores its savepoint.
execution_fail :: proc(capability: Execution, error: Error) -> Error {
    run := execution_run(capability)

    if run == nil {
        return .Stale_Execution
    }

    if error != .None && run.error == .None {
        run.error = error
    }

    return error
}

execution_claim_step :: proc(capability: Execution) -> Error {
    run := execution_run(capability)

    if run == nil {
        return .Stale_Execution
    }

    if run.step_count != 0 {
        run.error = .Step_Limit
        return .Step_Limit
    }

    run.step_count = 1
    return .None
}

@(private)
external_valid :: proc(external: External) -> bool {
    return(
        external.identity != 0 &&
        external.clone != nil &&
        external.release != nil &&
        external.open != nil &&
        external.close != nil &&
        external.capture != nil &&
        external.equal != nil &&
        external.admit != nil &&
        ((external.reserve == nil) == (external.unreserve == nil)) \
    )
}

@(private)
external_compatible :: proc(a, b: External) -> bool {
    // Owned images may have callbacks in a retained producer module. Mixing
    // callback realms in an existing ring needs an explicit migration contract.
    return(
        a.owner.realm == b.owner.realm &&
        a.identity == b.identity &&
        a.contract == b.contract &&
        a.clone == b.clone &&
        a.release == b.release &&
        a.open == b.open &&
        a.close == b.close &&
        a.capture == b.capture &&
        a.reserve == b.reserve &&
        a.unreserve == b.unreserve \
    )
}

@(private)
external_usage_check :: proc(run: ^External_Run, phase: External_Phase) -> Error {
    if run.external.identity == 0 {
        return .None
    }

    limits := run.external.limits

    if limits.max_bytes != 0 {
        if run.usage.runtime_bytes > limits.max_bytes ||
           run.usage.image_bytes > limits.max_bytes - run.usage.runtime_bytes ||
           run.usage.savepoint_bytes > limits.max_bytes - run.usage.runtime_bytes - run.usage.image_bytes {
            return .Resource_Limit
        }
    }

    return run.external.admit(run.value, phase, run.usage)
}

@(private)
external_release_record :: proc(t: ^Timeline($S, $I, $E), record: ^Record(S, I, E)) {
    if record.image != nil {
        t.external.release(record.image)
        assert(t.image_bytes >= record.image_bytes)
        t.image_bytes -= record.image_bytes
        record.image = nil
        record.image_bytes = 0
    }
}

@(private)
external_begin :: proc(t: ^Timeline($S, $I, $E), image: rawptr, phase: External_Phase, steps: u64 = 0) -> Error {
    if error := owner_access(t.owner, .Execute); error != .None {
        return error
    }

    if !external_enabled(t) {
        return .None
    }

    if image == nil {
        return .Incomplete_State
    }

    if phase == .Revision && t.external.limits.max_repair_ticks != 0 && steps > t.external.limits.max_repair_ticks {
        return .Repair_Limit
    }

    if phase == .Audit {
        limit := t.external.limits.max_audit_ticks != 0 ? t.external.limits.max_audit_ticks : u64(len(t.records) - 1)

        if steps > limit {
            return .Audit_Limit
        }
    }

    assert(t.run.value == nil)
    // Do not retain partial phase values from an earlier transaction when a
    // disabled clock or failed preparation leaves a phase unobserved.
    t.external_profile.open = {}
    t.external_profile.model = {}
    t.external_profile.capture = {}
    t.run.external = t.external
    t.run.phase = phase
    t.run.usage = {t.runtime_bytes, t.image_bytes, 0}
    profile_clock := t.external.clock
    t.run.started = profile_clock != nil ? profile_clock() : 0
    value, err := t.external.open(image)
    external_timing_finish(&t.external_profile.open, profile_clock, t.run.started)

    if err != .None {
        if value != nil {
            t.external.close(value)
        }

        return err
    }

    if value == nil {
        return .External_State
    }

    t.run.value = value

    if err := external_usage_check(&t.run, phase); err != .None {
        t.external.close(t.run.value)
        t.run.value = nil
        return err
    }

    return .None
}

@(private)
external_finish :: proc(t: ^Timeline($S, $I, $E)) {
    if !external_enabled(t) {
        return
    }

    t.run.active = false

    if t.run.value != nil {
        t.external.close(t.run.value)
        t.run.value = nil
    }

    for &record in t.staged {
        external_release_record(t, &record)
    }

    if t.external.clock != nil {
        now := t.external.clock()
        t.external_profile.last_total_ns = now >= t.run.started ? now - t.run.started : 0
        t.external_profile.peak_total_ns = max(t.external_profile.peak_total_ns, t.external_profile.last_total_ns)
    }
}

@(private)
external_prepare :: proc(t: ^Timeline($S, $I, $E)) -> Error {
    if !external_enabled(t) {
        return .None
    }

    if t.external.clock != nil {
        now := t.external.clock()
        t.external_profile.last_work_ns = now >= t.run.started ? now - t.run.started : 0
        t.external_profile.peak_work_ns = max(t.external_profile.peak_work_ns, t.external_profile.last_work_ns)
    }

    t.run.usage.image_bytes = t.image_bytes

    if t.run.usage.savepoint_bytes != 0 {
        return .External_State
    }

    return external_usage_check(&t.run, t.run.phase)
}

@(private)
external_publish :: proc(t: ^Timeline($S, $I, $E)) {
    if !external_enabled(t) {
        return
    }

    old := t.execution
    t.execution = t.run.value
    t.run.value = nil

    if old != nil {
        t.external.close(old)
    }
}

@(private)
external_capture_record :: proc(t: ^Timeline($S, $I, $E), dst: ^Record(S, I, E)) -> Error {
    if !external_enabled(t) {
        return .None
    }

    t.run.usage.image_bytes = t.image_bytes

    if err := external_usage_check(&t.run, t.run.phase); err != .None {
        return err
    }

    profile_clock := t.external.clock
    profile_started: u64

    if profile_clock != nil {
        profile_started = profile_clock()
    }

    image, bytes, err := t.external.capture(t.run.value)
    external_timing_finish(&t.external_profile.capture, profile_clock, profile_started)

    if err != .None {
        if image != nil {
            t.external.release(image)
        }

        return err
    }

    if image == nil || bytes > max(u64) - t.image_bytes {
        if image != nil {
            t.external.release(image)
        }

        return .Resource_Limit
    }

    dst.image, dst.image_bytes = image, bytes
    t.image_bytes += bytes
    t.run.usage.image_bytes = t.image_bytes
    return external_usage_check(&t.run, t.run.phase)
}

execution_savepoint :: proc(capability: Execution) -> (point: External_Savepoint, error: Error) {
    identity := execution_identity(capability)
    value, err := execution_pointer(capability, identity)

    if err != .None {
        return {}, err
    }

    run := capability._run

    if err := external_usage_check(run, .Savepoint); err != .None {
        return {}, err
    }

    image, bytes, capture_err := run.external.capture(value)

    if capture_err != .None {
        if image != nil {
            run.external.release(image)
        }

        return {}, capture_err
    }

    if image == nil || bytes > max(u64) - run.usage.savepoint_bytes {
        if image != nil {
            run.external.release(image)
        }

        return {}, .Resource_Limit
    }

    point = {image, bytes, run, capability._generation}
    run.usage.savepoint_bytes += bytes

    if err := external_usage_check(run, .Savepoint); err != .None {
        execution_savepoint_release(&point)
        return {}, err
    }

    return point, .None
}

execution_savepoint_release :: proc(point: ^External_Savepoint) {
    if point == nil || point.image == nil {
        return
    }

    run := point._run
    run.external.release(point.image)
    assert(run.usage.savepoint_bytes >= point.bytes)
    run.usage.savepoint_bytes -= point.bytes
    point^ = {}
}

execution_savepoint_restore :: proc(capability: Execution, point: ^External_Savepoint) -> Error {
    if point == nil ||
       point.image == nil ||
       point._run != capability._run ||
       point._generation != capability._generation {
        return .Stale_Execution
    }

    _, err := execution_pointer(capability, execution_identity(capability))

    if err != .None {
        return err
    }

    run := point._run
    value, open_err := run.external.open(point.image)

    if open_err != .None {
        if value != nil {
            run.external.close(value)
        }

        return open_err
    }

    if value == nil {
        return .External_State
    }

    old := run.value
    run.value = value
    run.external.close(old)
    return external_usage_check(run, .Savepoint)
}

// Optional SDK owner boundary. This C-shaped metadata contains no native/Godot
// dependency. Code residency and actual retained data/allocator context are
// composed by stable Core; a raw pointer alone is never an owning context.
Owner :: bg.Owner // pure protocol only; importing does not register a physics module
OWNER_MANAGED_DATA :: u32(1)
OWNER_WEAK_INSTANCE :: u32(2)
OWNER_INDEPENDENT_CONTEXT :: u32(4)

Owner_Access :: enum u32 {
    Read    = 0,
    Execute = 1,
}

@(private)
installed_owner_realm: u64

// Called once by the optional module host hook before instances exist. Realm is
// process/module lifetime identity, never canonical game or wire data.
owner_realm_install :: proc(realm: u64) -> Error {
    if realm == 0 {
        return .Invalid_Config
    }

    when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
        if installed_owner_realm != 0 && installed_owner_realm != realm {
            return .External_State
        }

        installed_owner_realm = realm
        return .None
    } else {
        old, changed := intrinsics.atomic_compare_exchange_strong_explicit(
            &installed_owner_realm,
            0,
            realm,
            .Acq_Rel,
            .Acquire,
        )
        return changed || old == realm ? Error.None : Error.External_State
    }
}

owner_realm :: proc() -> u64 {
    when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
        return installed_owner_realm
    } else {
        return intrinsics.atomic_load_explicit(&installed_owner_realm, .Acquire)
    }
}

owner_is_nil :: proc(owner: Owner) -> bool {
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

owner_access :: proc(owner: Owner, access: Owner_Access = .Read) -> Error {
    if owner_is_nil(owner) {
        return .None
    }

    if owner.reserved != 0 ||
       owner.realm == 0 ||
       owner.check == nil ||
       owner.retain == nil ||
       owner.drop == nil ||
       owner.context_caps & OWNER_MANAGED_DATA == 0 ||
       owner.context_caps &~ u32(7) != 0 ||
       (owner.context_caps & (OWNER_WEAK_INSTANCE | OWNER_INDEPENDENT_CONTEXT)) == 0 {
        return .Invalid_Config
    }

    // Do this before invoking producer type metadata, allocators, or callbacks.
    if owner.realm != owner_realm() {
        return .External_State
    }

    if owner.check(owner.user, u32(access)) != bg.OK {
        return .External_State
    }

    return .None
}

owner_retain :: proc(owner: Owner) -> Error {
    if error := owner_access(owner); error != .None {
        return error
    }

    if owner_is_nil(owner) {
        return .None
    }

    return owner.retain(owner.user) == bg.OK ? Error.None : Error.External_State
}

owner_drop :: proc(owner: ^Owner) -> Error {
    if owner == nil {
        return .Invalid_Config
    }

    if error := owner_access(owner^); error != .None {
        return error
    }

    if owner_is_nil(owner^) {
        return .None
    }

    if owner.drop(owner.user) != bg.OK {
        return .External_State
    }

    owner^ = {}
    return .None
}

// Nonnil SDK owners may use only explicitly declared retained contexts. This
// never infers that a containing object's lease covers an arbitrary subfield.
owner_contexts_check :: proc(external: External, allocator: mem.Allocator, user: rawptr = nil) -> Error {
    if owner_is_nil(external.owner) {
        return .None
    }

    if error := owner_access(external.owner); error != .None {
        return error
    }

    when #config(BOX3D_REQUIRE_DOMAIN, false) {
        if !meter.is_allocator(allocator) {
            return .Unsupported_Value
        }
    }

    if allocator.data != nil && allocator.data != external.owner_allocator_data {
        return .Unsupported_Value
    }

    if allocator.data == nil && !owner_builtin_allocator(allocator) {
        return .Unsupported_Value
    }

    if user != nil && user != external.owner_user_data {
        return .Unsupported_Value
    }

    return .None
}

// Nil data alone is not evidence that a custom allocator has no borrowed global
// context. Only the known builtin implementation is implicitly safe.
owner_builtin_allocator :: proc(allocator: mem.Allocator) -> bool {
    when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
        return(
            allocator.data == nil &&
            (allocator.procedure == runtime.heap_allocator_proc ||
                    allocator.procedure == runtime.wasm_allocator_proc) \
        )
    } else {
        return allocator.data == nil && allocator.procedure == runtime.heap_allocator_proc
    }
}

// Fixed, process-local ownership declarations for framework containers. These
// are deliberately absent from canonical values and wire schemas.
Owned_Context :: struct {
    owner: Owner,
    data:  rawptr,
}

Owner_Retains :: struct {
    owners: [16]Owner,
    count:  int,
}

owned_context_access :: proc(
    binding: Owned_Context,
    data: rawptr,
    required: bool = false,
    access: Owner_Access = .Read,
) -> Error {
    if error := owner_access(binding.owner, access); error != .None {
        return error
    }

    if data != nil &&
       ((!owner_is_nil(binding.owner) && binding.data != data) || (required && owner_is_nil(binding.owner))) {
        return .Unsupported_Value
    }

    return .None
}

owner_retains_acquire :: proc(retains: ^Owner_Retains, owners: []Owner) -> Error {
    for owner in owners {
        if owner_is_nil(owner) {
            continue
        }

        if retains.count >= len(retains.owners) {
            return .Resource_Limit
        }

        if error := owner_retain(owner); error != .None {
            return error
        }

        retains.owners[retains.count] = owner
        retains.count += 1
    }

    return .None
}

owner_retains_access :: proc(retains: ^Owner_Retains, access: Owner_Access = .Read) -> Error {
    for owner in retains.owners[:retains.count] {
        if error := owner_access(owner, access); error != .None {
            return error
        }
    }

    return .None
}

// Call with a LOCAL copy after clearing the containing owner. The last drop
// may free that container's block; no write through it is permitted afterward.
// On failure the remaining local handles form a cleanup-only retry tombstone.
owner_retains_drop :: proc(retains: ^Owner_Retains) -> Error {
    for index in 0 ..< retains.count {
        if error := owner_drop(&retains.owners[index]); error != .None {
            return error
        }
    }

    retains^ = {}
    return .None
}
