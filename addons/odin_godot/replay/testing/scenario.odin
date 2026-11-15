package replay_testing

import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import sc "godot:replay/schema"

Phase :: enum {
    Invalid,
    Initialize,
    Prediction,
    Correction,
    Checkpoint,
    Restore,
    Continue,
    Audit,
    Compare,
    Complete,
}

Report :: struct {
    phase:         Phase,
    tick:          u64,
    frame_error:   r.Error,
    network_error: net.Error,
    hash:          u64,
}

Outcome :: struct($State: typeid) {
    before, after: r.Frame(State),
    report:        Report,
}

// Scripted prediction vs authoritative decisions. Inputs are indexed from the
// initial frame's next tick. Correction replaces the complete suffix once it
// arrives; both state and event streams must equal the uninterrupted reference.
correction :: proc(
    initial: r.Frame($State),
    step: proc(_: ^State, _: $Input, _: ^r.Step($Event)),
    predicted, actual: []Input,
    first: u64,
    cfg := r.DEFAULT_CONFIG,
) -> Outcome(State) {
    result: Outcome(State)

    if len(actual) == 0 ||
       len(actual) != len(predicted) ||
       first <= initial.tick ||
       first > initial.tick + u64(len(actual)) ||
       len(actual) >= cfg.history_frames {
        return result
    }

    a, b: r.Timeline(State, Input, Event)
    defer r.destroy(&a)
    defer r.destroy(&b)

    for tl in ([2]^r.Timeline(State, Input, Event){&a, &b}) {
        if error := r.init(tl, initial, step, cfg = cfg); error != .None {
            result.report = {
                phase       = .Initialize,
                frame_error = error,
            }
            return result
        }
    }

    for input, i in predicted {
        if x := r.advance(&a, input); x.error != .None {
            result.report = {
                phase       = .Prediction,
                tick        = x.tick,
                frame_error = x.error,
            }
            return result
        }

        if x := r.advance(&b, actual[i]); x.error != .None {
            result.report = {
                phase       = .Prediction,
                tick        = x.tick,
                frame_error = x.error,
            }
            return result
        }
    }

    result.before, _ = r.current(&a)

    Rewrite :: struct {
        inputs: []Input,
        base:   u64,
    }

    rewrite := Rewrite{actual, initial.tick + 1}
    x := r.revise_inputs(&a, first, r.Input_Rewrite(Input) {
        user = &rewrite,
        apply = proc(raw: rawptr, tick: u64, prior: Input) -> Input {
            data := cast(^Rewrite)raw
            return data.inputs[tick - data.base]
        },
    })

    if x.error != .None {
        result.report = {
            phase       = .Correction,
            tick        = x.tick,
            frame_error = x.error,
        }
        return result
    }

    result.after, _ = r.current(&a)

    if x := r.audit(&a, first); x.error != .None {
        result.report = {
            phase       = .Audit,
            tick        = x.tick,
            frame_error = x.error,
        }
        return result
    }

    result.report = compare(&a, &b, initial.tick + 1, result.after.tick, cfg.events_per_tick)
    return result
}

// In-memory network checkpoint roundtrip and epoch takeover. The drive callback
// scripts server inputs/actions identically on the reference and restored owner.
// No transport or permit service is emulated; use real-peer tests for those.
takeover :: proc(
    initial: r.Frame($S),
    model: net.Model(S, $C, $A, $E, $N),
    cfg: net.Config,
    at, steps: u32,
    drive: proc(_: ^net.Server(S, C, A, E, N), _: u64) -> net.Error,
) -> Outcome(S) {
    result: Outcome(S)

    if at == 0 || steps <= at || steps - at >= u32(cfg.history) || cfg.epoch == max(u64) {
        return result
    }

    s, resumed: net.Server(S, C, A, E, N)
    defer net.server_destroy(&s)
    defer net.server_destroy(&resumed)

    if error := net.server_init(&s, initial, model, {}, cfg, local_seat = 1); error != .None {
        result.report = {
            phase         = .Initialize,
            network_error = error,
        }
        return result
    }

    if error := net.server_set_local_token(&s, net.Token{0 = 31}); error != .None {
        result.report = {
            phase         = .Initialize,
            network_error = error,
        }
        return result
    }

    for i in 1 ..= at {
        if drive != nil {
            if error := drive(&s, initial.tick + u64(i)); error != .None {
                result.report = {
                    phase         = .Prediction,
                    network_error = error,
                }
                return result
            }
        }

        if error := net.server_step(&s); error != .None {
            result.report = {
                phase         = .Prediction,
                network_error = error,
            }
            return result
        }
    }

    cp, decoded: net.Checkpoint(S, C, A, N)
    defer net.checkpoint_destroy(&cp)
    defer net.checkpoint_destroy(&decoded)

    if error := net.checkpoint_capture(&s, &cp); error != .None {
        result.report = {
            phase         = .Checkpoint,
            network_error = error,
        }
        return result
    }

    result.before = cp.frame
    bytes, error := net.checkpoint_encode(&cp, model)
    defer delete(bytes)

    if error != .None {
        result.report = {
            phase         = .Checkpoint,
            network_error = error,
        }
        return result
    }

    if error := net.checkpoint_decode(&decoded, bytes, model, cfg.content); error != .None {
        result.report = {
            phase         = .Checkpoint,
            network_error = error,
        }
        return result
    }

    epoch := cfg.epoch + 1

    if error := net.server_restore(&resumed, &decoded, model, {}, {epoch = epoch, local_seat = 1}); error != .None {
        result.report = {
            phase         = .Restore,
            network_error = error,
        }
        return result
    }

    // The uninterrupted reference receives the same authority-epoch observation.
    s.cfg.epoch, s.timeline.epoch = epoch, epoch

    for i in at + 1 ..= steps {
        for owner in ([2]^net.Server(S, C, A, E, N){&s, &resumed}) {
            if drive != nil {
                if error := drive(owner, initial.tick + u64(i)); error != .None {
                    result.report = {
                        phase         = .Continue,
                        network_error = error,
                    }
                    return result
                }
            }

            if error := net.server_step(owner); error != .None {
                result.report = {
                    phase         = .Continue,
                    network_error = error,
                }
                return result
            }
        }
    }

    result.after, _ = r.current(&resumed.timeline)
    first := initial.tick + u64(at) + 1

    if x := r.audit(&resumed.timeline, first); x.error != .None {
        result.report = {
            phase       = .Audit,
            tick        = x.tick,
            frame_error = x.error,
        }
        return result
    }

    result.report = compare(&s.timeline, &resumed.timeline, first, result.after.tick, net.WIRE_EVENTS)
    return result
}

@(private)
compare :: proc(a, b: ^r.Timeline($S, $I, $E), first, last: u64, event_capacity: int) -> Report {
    events_a, events_b := make([]r.Occurrence(E), event_capacity), make([]r.Occurrence(E), event_capacity)
    defer delete(events_a)
    defer delete(events_b)

    for tick in first ..= last {
        x, ok := r.read(a, tick)
        y, other := r.read(b, tick)

        if !ok || !other || !reflect.equal(x, y) {
            return {phase = .Compare, tick = tick}
        }

        n, error := r.copy_events(a, tick, events_a)
        m, other_error := r.copy_events(b, tick, events_b)

        if error != .None || other_error != .None || n != m {
            return {phase = .Compare, tick = tick}
        }

        for event, i in events_a[:n] {
            if !reflect.equal(event, events_b[i]) {
                return {phase = .Compare, tick = tick}
            }
        }
    }

    frame, _ := r.current(a)
    schema: sc.Schema
    defer sc.destroy(&schema)

    if sc.init(&schema, S).error != .None {
        return {phase = .Compare, tick = last}
    }

    bytes := make([]u8, schema.wire_size)
    defer delete(bytes)

    if sc.encode(&schema, frame.state, bytes).error != .None {
        return {phase = .Compare, tick = last}
    }

    return {phase = .Complete, tick = last, hash = sc.digest(bytes)}
}
