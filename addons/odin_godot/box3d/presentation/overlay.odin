package box3d_presentation

// Fixed scratch formatter: no heap/temp allocation, even for35 body views.
// The caller may reuse one label/buffer; short buffers are left untouched.
@(private)
Text :: struct {
    bytes: [2048]u8,
    count: int,
}

@(private)
put :: proc "contextless" (text: ^Text, value: string) {
    bytes := transmute([]u8)value

    for byte in bytes {
        text.bytes[text.count] = byte
        text.count += 1
    }
}

@(private)
number :: proc "contextless" (text: ^Text, value: u64) {
    digits: [20]u8
    at := len(digits)
    v := value

    for {
        at -= 1
        digits[at] = u8(v % 10) + '0'
        v /= 10

        if v == 0 {
            break
        }
    }

    for byte in digits[at:] {
        text.bytes[text.count] = byte
        text.count += 1
    }
}

@(private)
label_number :: proc "contextless" (text: ^Text, label: string, value: u64) {
    put(text, label)
    number(text, value)
}

@(private)
boolean :: proc "contextless" (text: ^Text, value: bool) {
    put(text, value ? "true" : "false")
}

status_text :: proc "contextless" (status: Status, out: []u8) -> (required: u32, error: Error) {
    if !status_valid(status) {
        return 0, .Invalid
    }

    text: Text
    label_number(&text, "Physics epoch ", status.epoch)
    label_number(&text, " | head ", status.head)
    label_number(&text, " | confirmed ", status.confirmed)
    put(&text, "\nAccepted frontier ")

    if status.accepted_frontier_available {
        number(&text, status.accepted_frontier)
    } else {
        put(&text, "unknown")
    }

    put(&text, " | predicted frontier ")

    if status.predicted_frontier_available {
        number(&text, status.predicted_frontier)
    } else {
        put(&text, "unknown")
    }

    put(&text, "\nReady ")
    boolean(&text, status.ready)
    put(&text, " | hold ")
    boolean(&text, status.hold)
    put(&text, " | resync ")
    boolean(&text, status.resync)
    put(&text, " | error ")

    if status.error_code < 0 {
        put(&text, "-")
        number(&text, u64(-i64(status.error_code)))
    } else {
        number(&text, u64(status.error_code))
    }

    put(&text, "\nObserved repair depth ")

    if status.repair_depth_available {
        number(&text, u64(status.repair_depth))
    } else {
        put(&text, "unavailable")
    }

    put(&text, " | profile ")

    if status.profile_available {
        number(&text, status.profile)
    } else {
        put(&text, "unavailable")
    }

    put(&text, "\nComplete solver digest ")

    if status.complete_available {
        number(&text, status.complete_solver_digest)
    } else {
        put(&text, "unavailable")
    }

    put(&text, " | motion-only digest ")

    if status.motion_available {
        number(&text, status.motion_digest)
    } else {
        put(&text, "unavailable")
    }

    if status.resources_available {
        label_number(&text, "\nTracked bytes native ", status.native_live_bytes)
        label_number(&text, " / wrapper ", status.wrapper_live_bytes)
        label_number(&text, " / host ", status.host_live_bytes)
        label_number(&text, " / reserved ", status.reserved_bytes)
        label_number(&text, " | peak ", status.tracked_peak_bytes)
    } else {
        put(&text, "\nTracked bytes unavailable")
    }

    if status.timing_available {
        label_number(&text, "\nObserved CPU peak ns normal ", status.normal_peak_ns)
        label_number(&text, " / repair ", status.repair_peak_ns)
        put(&text, " | latest ")

        if status.latest_timing_available {
            number(&text, status.normal_ns)
            label_number(&text, " / ", status.repair_ns)
        } else {
            put(&text, "unavailable")
        }
    } else {
        put(&text, "\nObserved CPU unavailable")
    }

    put(&text, "\nTiming is observational; same-build/same-target physics. Motion is not complete equality.\n")

    if len(out) < text.count {
        return u32(text.count), .Capacity
    }

    copy(out, text.bytes[:text.count])
    return u32(text.count), .None
}

Impairment_Feature :: enum u8 {
    Latency,
    Jitter,
    Loss,
    Duplicate,
    Reorder,
}

Impairment_Features :: bit_set[Impairment_Feature;u32]

impairment_supported :: proc "contextless" (request: Impairment, features: Impairment_Features) -> Error {
    if !impairment_valid(request) {
        return .Invalid
    }

    if (request.latency_ms > 0 && .Latency not_in features) ||
       (request.jitter_ms > 0 && .Jitter not_in features) ||
       (request.loss_permyriad > 0 && .Loss not_in features) ||
       (request.duplicate_permyriad > 0 && .Duplicate not_in features) ||
       (request.reorder && .Reorder not_in features) {
        return .Unsupported
    }

    return .None
}
