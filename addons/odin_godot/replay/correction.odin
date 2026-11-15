package replay

import "core:reflect"
import "core:mem"

// Optional correction-time prediction policy. It may use call-local scratch in
// user; the timeline owns only the resulting value inputs, never this callback.
// External side effects in apply are not part of the timeline transaction.
Input_Rewrite :: struct($Input: typeid) {
    user:       rawptr,
    apply:      proc(user: rawptr, tick: u64, original: Input) -> Input,
    // Optional, checked complete revisions only: true when a and b drive the
    // step identically (byte-different metadata the step never reads). Nil
    // means byte equality.
    equivalent: proc(user: rawptr, a, b: ^Input) -> bool,
}

read_input :: proc(t: ^Timeline($State, $Input, $Event), tick: u64) -> (input: Input, ok: bool) {
    record := record_at(t, tick)

    if record == nil || !record.has_input {
        return {}, false
    }

    return record.input, true
}

// Restore occurrences attached to a freshly initialized/reset checkpoint.
// This cannot rewrite a simulated or nonempty committed tick.
seed_checkpoint_events :: proc(t: ^Timeline($S, $I, $E), events: []Occurrence(E)) -> Error {
    if err := available(t); err != .None {
        return err
    }

    base := record_at(t, t.head)

    if t.head != t.confirmed || base == nil || base.has_input || base.count != 0 {
        return .Committed
    }

    if len(events) > len(base.events) {
        return .Event_Capacity
    }

    for event, i in events {
        if event.id.epoch != t.epoch || event.id.tick != t.head {
            return .Invalid_Event
        }

        for prior in events[:i] {
            if prior.id == event.id {
                return .Duplicate_Event
            }
        }
    }

    copy(base.events, events)
    base.count = len(events)
    return .None
}

// Replace a speculative suffix from recorded/received decisions without
// advancing confirmation. P2P input arrival is not authority state correction.
revise_inputs :: proc(t: ^Timeline($State, $Input, $Event), first: u64, rewrite: Input_Rewrite(Input)) -> Result {
    check: Revision_Check(State, Event)
    return revise_inputs_impl(t, first, rewrite, check, false)
}

// The callback borrows a complete independently owned clone at exactly tick.
// Core destroys that clone after return. Do not modify/consume/destroy the borrow;
// explicitly complete_checkpoint_clone it to retain another owner. User is an
// operation-local context and is never retained in Timeline or provider state.
Revision_Check :: struct($State, $Event: typeid) {
    tick:  u64,
    user:  rawptr,
    check: proc(user: rawptr, checkpoint: ^Complete_Checkpoint(State, Event)) -> Error,
}

revise_inputs_checked :: proc(
    t: ^Timeline($State, $Input, $Event),
    first: u64,
    rewrite: Input_Rewrite(Input),
    check: Revision_Check(State, Event),
) -> Result {
    return revise_inputs_impl(t, first, rewrite, check, true)
}

@(private)
revise_inputs_impl :: proc(
    t: ^Timeline($State, $Input, $Event),
    first: u64,
    rewrite: Input_Rewrite(Input),
    check: Revision_Check(State, Event),
    checked: bool,
) -> Result {
    if err := available(t); err != .None {
        return {error = err, tick = first}
    }

    if checked && (check.check == nil || check.tick < first || check.tick > t.head || !external_enabled(t)) {
        return {error = .Invalid_Config, tick = check.tick}
    }

    if checked {
        check_record := record_at(t, check.tick)

        if check_record == nil || !check_record.has_input {
            return {error = .History_Missing, tick = check.tick}
        }
    }

    if first <= t.confirmed {
        return {error = .Committed, tick = first}
    }

    if first > t.head || rewrite.apply == nil {
        return {error = .History_Missing, tick = first}
    }

    base := record_at(t, first - 1)

    if base == nil {
        return {error = .History_Missing, tick = first - 1}
    }

    n := int(t.head - first + 1)
    t.busy = true
    defer t.busy = false

    if checked {
        return revise_inputs_skipping(t, first, n, rewrite, check)
    }

    if err := external_begin(t, base.image, .Revision, u64(n)); err != .None {
        return {error = err, tick = first}
    }

    defer external_finish(t)
    before := base.frame
    checks := 0

    for i in 0 ..< n {
        tick := first + u64(i)
        original := record_at(t, tick)

        if original == nil || !original.has_input {
            return {error = .History_Missing, steps = i, tick = tick}
        }

        input := rewrite.apply(rewrite.user, tick, original.input)

        if err := simulate(t, &t.staged[i], before, input); err != .None {
            return {error = err, steps = i, tick = tick}
        }

        if checked && tick == check.tick {
            owned, clone_error := clone_record_complete(&t.staged[i], t.external, t.epoch, t.allocator)

            if clone_error != .None {
                return {error = clone_error, steps = i + 1, tick = tick}
            }

            if owned._image_bytes > max(u64) - owned._owned_bytes {
                complete_checkpoint_destroy(&owned)
                return {error = .Resource_Limit, steps = i + 1, tick = tick}
            }

            usage := t.run.usage
            t.run.usage.image_bytes = t.image_bytes
            t.run.usage.savepoint_bytes = owned._image_bytes + owned._owned_bytes
            admission_error := external_usage_check(&t.run, .Revision)
            t.run.usage = usage

            if admission_error != .None {
                complete_checkpoint_destroy(&owned)
                return {error = admission_error, steps = i + 1, tick = tick}
            }

            checks += 1
            callback_error := check.check(check.user, &owned)
            complete_checkpoint_destroy(&owned)

            if callback_error != .None {
                return {error = callback_error, steps = i + 1, tick = tick}
            }
        }

        before = t.staged[i].frame
    }

    if checked && checks != 1 {
        return {error = .Invalid_Config, steps = n, tick = check.tick}
    }

    if err := external_prepare(t); err != .None {
        return {error = err, steps = n, tick = t.head}
    }

    for i in 0 ..< n {
        commit(t, &t.staged[i])
    }

    external_publish(t)
    return {steps = n, tick = t.head}
}

// Complete-state revision that executes only from the first tick whose
// rewritten input differs from the recorded one. A complete Timeline step is a
// pure function of the predecessor image and the tick input (the provider
// contract that confirmation signatures already verify), so an unchanged prefix
// re-derives byte-identical records. When every input matches, the published
// execution and records stay as they are and only the requested check runs, on
// the committed record. Rewriters are still called once per tick, in order.
// Result.steps counts the ticks actually executed.
@(private)
revise_inputs_skipping :: proc(
    t: ^Timeline($State, $Input, $Event),
    first: u64,
    n: int,
    rewrite: Input_Rewrite(Input),
    check: Revision_Check(State, Event),
) -> Result {
    // staged[i].input is scratch for the rewritten value of tick first+i; no
    // staged record owns an image outside an active run.
    divergent := -1

    for i in 0 ..< n {
        tick := first + u64(i)
        original := record_at(t, tick)

        if original == nil || !original.has_input {
            return {error = .History_Missing, tick = tick}
        }

        t.staged[i].input = rewrite.apply(rewrite.user, tick, original.input)

        if divergent < 0 && !correction_bytes_equal(&t.staged[i].input, &original.input) {
            if rewrite.equivalent == nil || !rewrite.equivalent(rewrite.user, &t.staged[i].input, &original.input) {
                divergent = i
            }
        }
    }

    resume := divergent < 0 ? n : divergent
    checks := 0

    // A check inside the unchanged prefix reads the committed record.
    if int(check.tick - first) < resume {
        record := record_at(t, check.tick)
        run := t.run
        run.value = t.execution
        error := revision_check_record(t, record, &run, check)

        if error != .None {
            return {error = error, tick = check.tick}
        }

        checks += 1
    }

    if resume == n {
        revise_record_prefix(t, first, n)
        return {steps = 0, tick = t.head}
    }

    base := record_at(t, first + u64(resume) - 1)

    if base == nil {
        return {error = .History_Missing, tick = first + u64(resume) - 1}
    }

    if err := external_begin(t, base.image, .Revision, u64(n - resume)); err != .None {
        return {error = err, tick = first + u64(resume)}
    }

    defer external_finish(t)
    before := base.frame

    for i in resume ..< n {
        tick := first + u64(i)
        input := t.staged[i].input
        slot := &t.staged[i] // keeps prefix scratch inputs [0, resume) intact

        if err := simulate(t, slot, before, input); err != .None {
            return {error = err, steps = i - resume, tick = tick}
        }

        if tick == check.tick {
            if error := revision_check_record(t, slot, &t.run, check); error != .None {
                return {error = error, steps = i - resume + 1, tick = tick}
            }

            checks += 1
        }

        before = slot.frame
    }

    if checks != 1 {
        return {error = .Invalid_Config, steps = n - resume, tick = check.tick}
    }

    if err := external_prepare(t); err != .None {
        return {error = err, steps = n - resume, tick = t.head}
    }

    for i in resume ..< n {
        commit(t, &t.staged[i])
    }

    external_publish(t)
    revise_record_prefix(t, first, resume)
    return {steps = n - resume, tick = t.head}
}

// Record the rewritten (accepted) inputs of an unexecuted equivalent prefix.
// Their frames, images and events are already the ones those inputs produce.
@(private)
revise_record_prefix :: proc(t: ^Timeline($State, $Input, $Event), first: u64, count: int) {
    for i in 0 ..< count {
        record_at(t, first + u64(i)).input = t.staged[i].input
    }
}

// Clone, admit, and borrow one record to a revision check. `run` supplies the
// execution the provider admits against: the staged run, or the published one.
@(private)
revision_check_record :: proc(
    t: ^Timeline($State, $Input, $Event),
    record: ^Record(State, Input, Event),
    run: ^External_Run,
    check: Revision_Check(State, Event),
) -> Error {
    owned, clone_error := clone_record_complete(record, t.external, t.epoch, t.allocator)

    if clone_error != .None {
        return clone_error
    }

    defer complete_checkpoint_destroy(&owned)

    if owned._image_bytes > max(u64) - owned._owned_bytes {
        return .Resource_Limit
    }

    usage := run.usage
    run.usage.image_bytes = t.image_bytes
    run.usage.savepoint_bytes = owned._image_bytes + owned._owned_bytes
    admission_error := external_usage_check(run, .Revision)
    run.usage = usage

    if admission_error != .None {
        return admission_error
    }

    return check.check(check.user, &owned)
}

// Ingest a COMPLETE authoritative frame and its complete occurrence batch.
// The caller authenticates authority, epoch, schema, and game invariants before
// calling. Replay every later input in scratch, then atomically commit both the
// checkpoint and its suffix. An optional Input_Rewrite replaces guesses while
// staging. Failure leaves inputs/state/events/confirmation unchanged.
correct :: proc {
    correct_plain,
    correct_rewrite,
}

@(private)
correct_plain :: proc(
    t: ^Timeline($State, $Input, $Event),
    truth: Frame(State),
    events: []Occurrence(Event),
) -> Result {
    return correct_rewrite(t, truth, events, Input_Rewrite(Input){})
}

@(private)
correct_rewrite :: proc(
    t: ^Timeline($State, $Input, $Event),
    truth: Frame(State),
    events: []Occurrence(Event),
    rewrite: Input_Rewrite(Input),
) -> Result {
    return correct_impl(t, truth, events, rewrite, nil)
}

// Explicit deterministic reuse. Complete mutable dependencies belong in State;
// external configuration and the step callback must remain unchanged. Audit and
// ordinary correct still execute every step. Rewriters are always called once
// per visited input. Byte equality is deliberately stricter than float equality.
correct_reusing :: proc {
    correct_reusing_plain,
    correct_reusing_rewrite,
}

@(private)
correct_reusing_plain :: proc(t: ^Timeline($S, $I, $E), truth: Frame(S), events: []Occurrence(E)) -> (Result, int) {
    return correct_reusing_rewrite(t, truth, events, Input_Rewrite(I){})
}

@(private)
correct_reusing_rewrite :: proc(
    t: ^Timeline($S, $I, $E),
    truth: Frame(S),
    events: []Occurrence(E),
    rewrite: Input_Rewrite(I),
) -> (
    result: Result,
    reused: int,
) {
    result = correct_impl(t, truth, events, rewrite, &reused)
    return
}

@(private)
correction_bytes_equal :: proc(a: ^$T, b: ^T) -> bool {
    if a == b {
        return true
    }

    x := (cast([^]u8)a)[:size_of(T)]
    y := (cast([^]u8)b)[:size_of(T)]
    return mem.compare(x, y) == 0
}

@(private)
correct_impl :: proc(
    t: ^Timeline($State, $Input, $Event),
    truth: Frame(State),
    events: []Occurrence(Event),
    rewrite: Input_Rewrite(Input),
    reuse_count: ^int,
    truth_image: rawptr = nil,
    truth_bytes: u64 = 0,
    complete: bool = false,
) -> Result {
    if err := available(t); err != .None {
        return {error = err, tick = truth.tick}
    }

    if external_enabled(t) {
        if reuse_count != nil {
            return {error = .Reuse_Disabled, tick = truth.tick}
        }

        if !complete || truth_image == nil {
            return {error = .Incomplete_State, tick = truth.tick}
        }
    }

    if truth.tick < t.confirmed {
        return {error = .Committed, tick = truth.tick}
    }

    base := record_at(t, truth.tick)

    if base == nil {
        return {error = .History_Missing, tick = truth.tick}
    }

    if len(events) > len(base.events) {
        return {error = .Event_Capacity, tick = truth.tick}
    }

    for event, i in events {
        if event.id.epoch != t.epoch || event.id.tick != truth.tick {
            return {error = .Invalid_Event, tick = truth.tick}
        }

        for previous in events[:i] {
            if previous.id == event.id {
                return {error = .Duplicate_Event, tick = truth.tick}
            }
        }
    }

    if truth.tick == t.confirmed {
        if !reflect.equal(base.frame.state, truth.state) || !reflect.equal(base.events[:base.count], events, true) {
            return {error = .Committed, tick = truth.tick}
        }

        if external_enabled(t) {
            equal, err := t.external.equal(base.image, truth_image)

            if err != .None {
                return {error = err, tick = truth.tick}
            }

            if !equal {
                return {error = .Committed, tick = truth.tick}
            }
        }

        return {tick = truth.tick} // identical replay of a settled checkpoint
    }

    t.busy = true
    defer t.busy = false

    if err := external_begin(t, truth_image, .Revision, t.head - truth.tick); err != .None {
        return {error = err, tick = truth.tick}
    }

    defer external_finish(t)
    checkpoint := &t.staged[0]
    external_release_record(t, checkpoint)

    if external_enabled(t) {
        image, err := t.external.clone(truth_image)

        if err != .None {
            if image != nil {
                t.external.release(image)
            }

            return {error = err, tick = truth.tick}
        }

        if image == nil {
            return {error = .External_State, tick = truth.tick}
        }

        if truth_bytes > max(u64) - t.image_bytes {
            t.external.release(image)
            return {error = .Resource_Limit, tick = truth.tick}
        }

        checkpoint.image, checkpoint.image_bytes = image, truth_bytes
        t.image_bytes += truth_bytes
    }

    checkpoint.valid = true
    checkpoint.has_input = false // the generating authority input is not known here
    checkpoint.input = {}
    checkpoint.frame = truth
    checkpoint.count = len(events)
    copy(checkpoint.events, events)
    n := int(t.head - truth.tick)
    reused := 0
    before := &checkpoint.frame

    for i in 0 ..< n {
        at := truth.tick + u64(i) + 1
        original := record_at(t, at)

        if original == nil {
            return {error = .History_Missing, steps = i, tick = at}
        }

        if !original.has_input {
            return {error = .Initial_Frame, steps = i, tick = at}
        }

        dst := &t.staged[i + 1]
        input := original.input

        if rewrite.apply != nil {
            input = rewrite.apply(rewrite.user, at, input)
        }

        can_reuse := false

        if reuse_count != nil {
            previous := record_at(t, at - 1)
            can_reuse =
                previous != nil &&
                correction_bytes_equal(&before.state, &previous.frame.state) &&
                correction_bytes_equal(&input, &original.input)
        }

        if can_reuse {
            // The existing record already contains the required input/state/events.
            // Leave it untouched at commit, and never alias its event slice in scratch.
            dst.valid = false
            before = &original.frame
            reused += 1
        } else {
            if err := simulate(t, dst, before^, input); err != .None {
                return {error = err, steps = i, tick = at}
            }

            before = &dst.frame
        }
    }

    if err := external_prepare(t); err != .None {
        return {error = err, steps = n, tick = t.head}
    }

    for i in 0 ..= n {
        if t.staged[i].valid {
            commit(t, &t.staged[i])
        }
    }

    external_publish(t)

    if reuse_count != nil {
        reuse_count^ = reused
    }

    t.confirmed = truth.tick
    return {steps = n, tick = t.head}
}

// Explicit resync/recovery. Reuses allocations and discards old speculative
// input/event history. A same-epoch snapshot cannot move behind confirmed state;
// a new authorized epoch may resume an older checkpoint (e.g. host migration).
// An epoch counter alone does not establish legitimate authority.
reset_checkpoint :: proc(t: ^Timeline($State, $Input, $Event), frame: Frame(State), epoch: u64) -> Error {
    if err := available(t); err != .None {
        return err
    }

    if external_enabled(t) {
        return .Incomplete_State
    }

    if epoch == 0 || epoch < t.epoch {
        return .Invalid_Epoch
    }

    if epoch == t.epoch && frame.tick < t.confirmed {
        return .Committed
    }

    for &record in t.records {
        record.valid = false
        record.count = 0
    }

    for &record in t.staged {
        record.valid = false
        record.count = 0
    }

    t.epoch, t.head, t.confirmed = epoch, frame.tick, frame.tick
    base := &t.records[frame.tick % u64(len(t.records))]
    base.valid = true
    base.has_input = false
    base.input = {}
    base.frame = frame
    return .None
}
