package replay_diagnostic

import "core:mem"
import "core:reflect"
import r "godot:replay"

RECORDING_VERSION :: 1
MAX_RECORDING_BYTES :: 16 * 1024 * 1024
MAX_RECORDING_MEMORY :: 64 * 1024 * 1024

Recording_Error :: enum {
    None,
    Invalid,
    Occupied,
    Context,
    Capacity,
    History,
    Schema,
    Codec,
    Model,
    Replay,
}

Recording_Result :: struct {
    error:  Recording_Error,
    replay: r.Result,
}

// Application-defined identifiers for content and executable/model configuration.
// These must change when the corresponding replay contract changes.
Recording_Context :: struct {
    content, build: u64,
    tick_hz:        u32,
}

Recording_Header :: struct {
    version, ticks, events, event_capacity: u32,
    identity:                               Recording_Context,
    first, head, total_bytes:               u64,
}

Recorded_Tick :: struct($S, $I: typeid) {
    frame:                    r.Frame(S),
    input:                    I,
    event_start, event_count: u32,
}

// Independent diagnostic owner. Destroy before reuse; do not copy this owner.
Recording :: struct($S, $I, $E: typeid) {
    allocator: mem.Allocator,
    ready:     bool,
    epoch:     u64,
    header:    Recording_Header,
    base:      r.Frame(S),
    ticks:     []Recorded_Tick(S, I),
    events:    []r.Occurrence(E),
}

Recording_Model :: struct($S, $I, $E: typeid) {
    step:        proc(_: ^S, _: I, _: ^r.Step(E)),
    state_valid: proc(_: S) -> bool,
    input_valid: proc(_: I) -> bool,
    input_check: proc(_: I, _: u64, _: rawptr) -> bool, // optional context-aware preflight, before any step
    user:        rawptr, // caller-owned immutable assets/configuration, never serialized
}

recording_destroy :: proc(a: ^Recording($S, $I, $E)) {
    if a == nil {
        return
    }

    delete(a.ticks, a.allocator)
    delete(a.events, a.allocator)
    a^ = {}
}

@(private)
recording_empty :: proc(a: ^Recording($S, $I, $E)) -> bool {
    return a != nil && !a.ready && len(a.ticks) == 0 && len(a.events) == 0
}

@(private)
recording_context_valid :: proc(c: Recording_Context) -> bool {
    return c.content != 0 && c.build != 0 && c.tick_hz > 0 && c.tick_hz <= 10000
}

@(private)
recording_header_valid :: proc(h: Recording_Header) -> bool {
    return(
        h.version == RECORDING_VERSION &&
        recording_context_valid(h.identity) &&
        h.ticks < 4096 &&
        h.event_capacity <= 4096 &&
        h.events <= h.ticks * h.event_capacity &&
        h.first <= h.head &&
        h.head - h.first == u64(h.ticks) \
    )
}

@(private)
recording_memory_valid :: proc(h: Recording_Header, $S, $I, $E: typeid) -> bool {
    return(
        u64(size_of(S)) +
            u64(h.ticks) * u64(size_of(Recorded_Tick(S, I))) +
            u64(h.events) * u64(size_of(r.Occurrence(E))) <=
        MAX_RECORDING_MEMORY \
    )
}

// Capture the newest replayable suffix, stopping at a correction/checkpoint.
// It copies recorded values without invoking the model or changing the timeline.
// A checkpoint-only timeline produces a valid zero-step recording.
recording_capture :: proc(
    a: ^Recording($S, $I, $E),
    t: ^r.Timeline(S, I, E),
    identity: Recording_Context,
    max_ticks: int = 120,
    allocator := context.allocator,
) -> Recording_Result {
    if !recording_empty(a) {
        return {error = .Occupied}
    }

    if !recording_context_valid(identity) || max_ticks < 1 || max_ticks > 4095 {
        return {error = .Invalid}
    }

    if t == nil {
        return {error = .History, replay = {error = .Not_Initialized}}
    }

    if r.external_enabled(t) {
        return {error = .Context, replay = {error = .Incomplete_State}}
    }

    cfg, config_error := r.timeline_config(t)

    if config_error != .None {
        return {error = .History, replay = {error = config_error}}
    }

    from, to, error := r.audit_window(t, max_ticks)

    if error != .Initial_Frame && error != .None {
        return {error = .History, replay = {error = error, tick = to}}
    }

    count := error == .Initial_Frame ? 0 : int(to - from) + 1
    first := count == 0 ? to : from - 1
    tmp := Recording(S, I, E) {
        allocator = allocator,
        epoch = t.epoch,
        header = {
            version = RECORDING_VERSION,
            ticks = u32(count),
            event_capacity = u32(cfg.events_per_tick),
            identity = identity,
            first = first,
            head = to,
        },
    }
    tmp.base, _ = r.read(t, first)

    for tick := first; tick < to; {
        tick += 1
        n, err := r.copy_events(t, tick, nil)

        if err != .None && err != .Output_Too_Small {
            return {error = .History, replay = {error = err, tick = tick}}
        }

        tmp.header.events += u32(n)
    }

    if !recording_memory_valid(tmp.header, S, I, E) {
        return {error = .Capacity}
    }

    tmp.ticks = make([]Recorded_Tick(S, I), count, allocator)
    tmp.events = make([]r.Occurrence(E), tmp.header.events, allocator)
    committed := false

    defer if !committed {
        recording_destroy(&tmp)
    }

    at := 0

    for &entry, index in tmp.ticks {
        tick := first + u64(index) + 1
        entry.frame, _ = r.read(t, tick)
        input, ok := r.read_input(t, tick)

        if !ok {
            return {error = .History, replay = {error = .History_Missing, tick = tick}}
        }

        entry.input = input
        n, event_error := r.copy_events(t, tick, tmp.events[at:])

        if event_error != .None {
            return {error = .History, replay = {error = event_error, tick = tick}}
        }

        entry.event_start, entry.event_count = u32(at), u32(n)
        at += n
    }

    tmp.ready = true
    a^ = tmp
    committed = true
    return {}
}

@(private)
recording_valid :: proc(a: ^Recording($S, $I, $E)) -> bool {
    if a == nil ||
       !a.ready ||
       a.epoch == 0 ||
       !recording_header_valid(a.header) ||
       !recording_memory_valid(a.header, S, I, E) ||
       len(a.ticks) != int(a.header.ticks) ||
       len(a.events) != int(a.header.events) ||
       a.base.tick != a.header.first {
        return false
    }

    at := 0

    for entry, index in a.ticks {
        if entry.frame.tick != a.base.tick + u64(index) + 1 ||
           entry.event_start != u32(at) ||
           entry.event_count > a.header.event_capacity ||
           int(entry.event_count) > len(a.events) - at {
            return false
        }

        events := a.events[at:at + int(entry.event_count)]

        for event, i in events {
            if event.id.epoch != a.epoch || event.id.tick != entry.frame.tick {
                return false
            }

            for prior in events[:i] {
                if prior.id == event.id {
                    return false
                }
            }
        }

        at += int(entry.event_count)
    }

    return at == len(a.events)
}

// Re-execute with the supplied code/assets in an isolated two-frame timeline.
// Compare every complete state and ordered occurrence batch using core equality.
// The first mismatch is owned by capture, compatible with audit_text.
recording_verify :: proc(
    a: ^Recording($S, $I, $E),
    identity: Recording_Context,
    model: Recording_Model(S, I, E),
    capture: ^r.Audit_Capture(S, I, E),
    allocator := context.allocator,
) -> Recording_Result {
    if !recording_valid(a) || model.step == nil {
        return {error = .Invalid}
    }

    if a.header.identity != identity {
        return {error = .Context}
    }

    if capture == nil || capture.ready || len(capture.expected_events) != 0 || len(capture.actual_events) != 0 {
        return {error = .Occupied}
    }

    if model.state_valid != nil && !model.state_valid(a.base.state) {
        return {error = .Model, replay = {tick = a.base.tick}}
    }

    // Validate all imported values before the first model callback.
    for &entry in a.ticks {
        if model.state_valid != nil && !model.state_valid(entry.frame.state) ||
           model.input_valid != nil && !model.input_valid(entry.input) ||
           model.input_check != nil && !model.input_check(entry.input, entry.frame.tick, model.user) {
            return {error = .Model, replay = {tick = entry.frame.tick}}
        }
    }

    timeline: r.Timeline(S, I, E)
    defer r.destroy(&timeline)

    if err := r.init(&timeline, a.base, model.step, {2, int(a.header.event_capacity)}, a.epoch, allocator, model.user);
       err != .None {
        return {error = .Replay, replay = {error = err}}
    }

    events := make([]r.Occurrence(E), a.header.event_capacity, allocator)
    defer delete(events, allocator)

    for &entry, index in a.ticks {
        parent, _ := r.current(&timeline)
        result := r.advance(&timeline, entry.input)

        if result.error != .None {
            result.steps = index
            return {error = .Replay, replay = result}
        }

        actual, _ := r.current(&timeline)
        n, _ := r.copy_events(&timeline, actual.tick, events)
        expected := a.events[entry.event_start:entry.event_start + entry.event_count]
        error: r.Error

        if !reflect.equal(actual.state, entry.frame.state) {
            error = .Diverged_State
        } else if !reflect.equal(expected, events[:n], true) {
            error = .Diverged_Event
        }

        if error != .None {
            result = {
                error = error,
                tick  = actual.tick,
                steps = index + 1,
            }
            capture.allocator = allocator
            capture.result = result
            // These are complete no-reference values in disjoint owned storage. Avoid
            // expanding several large aggregates into tens of thousands of WASM locals.
            mem.copy_non_overlapping(&capture.parent, &parent, size_of(parent))
            mem.copy_non_overlapping(&capture.expected, &entry.frame, size_of(entry.frame))
            mem.copy_non_overlapping(&capture.actual, &actual, size_of(actual))
            mem.copy_non_overlapping(&capture.input, &entry.input, size_of(entry.input))
            capture.expected_events = make([]r.Occurrence(E), len(expected), allocator)
            copy(capture.expected_events, expected)
            capture.actual_events = make([]r.Occurrence(E), n, allocator)
            copy(capture.actual_events, events[:n])
            capture.ready = true
            return {error = .Replay, replay = result}
        }
    }

    return {replay = {steps = len(a.ticks), tick = a.header.head}}
}
